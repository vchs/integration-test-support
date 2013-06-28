require_relative 'component_runner'

class CollectorRunner < ComponentRunner
  attr_writer :reaction_blk

  def checkout_collector
    Dir.chdir tmp_dir do
      FileUtils.mkdir_p "log"
      sh "git clone --recursive git://github.com/cloudfoundry/collector.git" unless Dir.exist?("collector")
      Dir.chdir "collector" do
        if ENV['NO_CHECKOUT'].nil? || ENV['NO_CHECKOUT'].empty?
          `git fetch`
          ensure_no_local_changes
          ensure_no_local_commits('origin/master')
          sh "git reset --hard origin/master && git submodule update --init"
        end

        Bundler.with_clean_env do
          sh "bundle install >> #{tmp_dir}/log/bundle.out"
        end
      end
      $checked_out_collector = true
    end
  end

  def start
    start_fake_tsdb
    checkout_collector unless $checked_out_collector
    Dir.chdir "#{tmp_dir}/collector" do
      Bundler.with_clean_env do
        add_pid Process.spawn(
          {"CONFIG_FILE" => asset("collector.yml")},
          "bundle exec ./bin/collector", log_options(:collector)
        )
      end
    end
  end

  private
  def start_fake_tsdb
    add_thread Thread.new {
      Socket.tcp_server_loop(4242) do |s, client_addrinfo|
        begin
          puts "Listening to port 4242 for Collector (OpenTSDB) data..."
          while true
            data = s.readline
            if @reaction_blk
              @reaction_blk.call(data)
            end
          end
        rescue EOFError => e
          puts "Stream closed! #{e}"
        rescue => e
          p e
          puts e.backtrace.join("\n  ")
        ensure
          s.close
        end
      end
    }
  end
end
