require_relative 'component_runner'

class CcngRunner < ComponentRunner
  attr_reader :org_guid, :space_guid

  def start
    checkout_ccng unless $checked_out
    Dir.chdir "#{tmp_dir}/cloud_controller_ng" do
      Bundler.with_clean_env do
        write_custom_cc_config_file
        prepare_cc_database
        add_pid Process.spawn "bundle exec ./bin/cloud_controller --config #{custom_cc_config_location}", log_options(:cloud_controller)
      end
    end
    wait_for_http_ready("CCNG", 8181)
    setup_ccng_orgs_and_spaces
  end

  def stop
    super
  ensure
    tear_down_cc_database
  end

  private

  def write_custom_cc_config_file
    FileUtils.mkdir_p("#{tmp_dir}/config")
    File.open(custom_cc_config_location, "w") do |f|
      f.write YAML.dump(YAML.load_file("config/cloud_controller.yml").merge({
        "db" => {
          "database" => "mysql2://root:@localhost:3306/#{cc_database_name}",
          "max_connections" => 32,
          "pool_timeout" => 10,
        },
        "logging" => {
          "file" => "#{tmp_dir}/log/cloud_controller.log",
          "level" => "debug2",
        },
        uaa: {
          url: "http://localhost:7777/",
          resource_id: "cloud_controller",
          symmetric_secret: "tokensecret"
        }
      }))
    end
  end

  def prepare_cc_database
    sh %Q{ echo 'CREATE DATABASE #{cc_database_name}' | mysql -u root }
    db_migrate_log_options = log_options(:cc_db_migrate)
    sh "CLOUD_CONTROLLER_NG_CONFIG=#{custom_cc_config_location} bundle exec rake db:migrate >> #{db_migrate_log_options[:out]} 2>> #{db_migrate_log_options[:err]}"
    insert_quota_def_statement = 'INSERT INTO quota_definitions(guid, created_at, name, non_basic_services_allowed, total_services, memory_limit) VALUES("test_quota", "2010-01-01", "free", 1, 100, 1024)'
    sh %Q{echo '#{insert_quota_def_statement}' | mysql -u root #{cc_database_name}}
  end

  def tear_down_cc_database
    sh %Q{ echo 'DROP DATABASE IF EXISTS #{cc_database_name}' | mysql -u root }
  end

  def cc_database_name
    @cc_database_name ||= "ccng_#{SecureRandom.uuid.gsub('-','')}"
  end

  def custom_cc_config_location
    "#{tmp_dir}/config/cloud_controller.yml"
  end

  def checkout_ccng
    cc_branch = ENV["CC_BRANCH"] || "origin/master"

    Dir.chdir tmp_dir do
      FileUtils.mkdir_p "log"
      sh "git clone --recursive git://github.com/cloudfoundry/cloud_controller_ng.git" unless Dir.exist?("cloud_controller_ng")
      Dir.chdir "cloud_controller_ng" do
        if ENV['NO_CHECKOUT'].nil? || ENV['NO_CHECKOUT'].empty?
          `git fetch`
          ensure_no_local_changes
          ensure_no_local_commits(cc_branch)
          sh "git reset --hard #{cc_branch} && git submodule update --init"
        end

        Bundler.with_clean_env do
          puts "running bundle install"
          sh "bundle install >> #{tmp_dir}/log/bundle.out"
        end
      end
      $checked_out = true
    end
  end

  def setup_ccng_orgs_and_spaces
    user_guid = '12345'
    @org_guid = ccng_post(
      "/v2/organizations",
      {name: 'test_org', user_guids: [user_guid]}
    ).fetch("metadata").fetch("guid")

    @space_guid = ccng_post(
      "/v2/spaces",
      {name: 'test_space', organization_guid: @org_guid}
    ).fetch("metadata").fetch("guid")

    ccng_put("/v2/spaces/#{@space_guid}/developers/#{user_guid}", {})
  end
end
