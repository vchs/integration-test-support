require_relative 'component_runner'

class ScRunner < ComponentRunner

  def start
    Dir.chdir "#{tmp_dir}/service_controller" do
      Bundler.with_clean_env do
        prepare_sc
        add_pid Process.spawn "./bin/rails server", log_options(:sc)
      end
    end
    wait_for_http_ready("SC", 3000, '')
  end

  def stop
    super
  ensure
    cleanup_sc
  end

  private

  def prepare_sc
    Dir.chdir "#{tmp_dir}/service_controller" do
      sh "rake db:migrate"
    end
  end

  def cleanup_sc
    Dir.chdir "#{tmp_dir}/service_controller" do
      sh "git reset --hard && git clean -dffx"
    end
  end
end
