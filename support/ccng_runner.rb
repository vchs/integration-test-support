require_relative 'component_runner'

class CcngRunner < ComponentRunner
  attr_reader :org_guid, :space_guid

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

  def start
    checkout_ccng unless $checked_out
    FileUtils.mkdir_p("#{tmp_dir}/config")
    database_file = File.join(tmp_dir, "cloud_controller.db")
    FileUtils.rm_f(database_file)
    Dir.chdir "#{tmp_dir}/cloud_controller_ng" do
      File.open("#{tmp_dir}/config/cloud_controller.yml", "w") do |f|
        f.write YAML.dump(YAML.load_file("config/cloud_controller.yml").merge({
          "db" => {
            "database" => "sqlite://#{database_file}",
            "max_connections" => 32,
            "pool_timeout" => 10,
          },
          "logging" => {
            "file" => "#{tmp_dir}/log/cloud_controller.log",
            "level" => "debug2",
          },
        }))
      end
      Bundler.with_clean_env do
        config_file_path = "#{tmp_dir}/config/cloud_controller.yml"
        puts "running bundle exec rake db:migrate"
        db_migrate_log_options = log_options(:cc_db_migrate)
        sh "CLOUD_CONTROLLER_NG_CONFIG=#{config_file_path} bundle exec rake db:migrate >> #{db_migrate_log_options[:out]} 2>> #{db_migrate_log_options[:err]}"
        sh %Q{sqlite3 #{database_file} 'INSERT INTO quota_definitions(guid, created_at, name, non_basic_services_allowed, total_services, memory_limit) VALUES("test_quota", "2010-01-01", "free", 1, 100, 1024)'}
        add_pid Process.spawn "bundle exec ./bin/cloud_controller --config #{config_file_path}", log_options(:cloud_controller)
      end
    end
    wait_for_http_ready("CCNG", 8181)

    setup_ccng_orgs_and_spaces
  end

  private

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
