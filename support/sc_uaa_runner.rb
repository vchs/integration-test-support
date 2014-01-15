require_relative 'component_runner'
require_relative 'integration_example_group'

class ScUaaRunner < ComponentRunner
  def start
    add_pid Process.spawn("java -jar #{tmp_dir}/webapp_runner.jar " \
                          "#{tmp_dir}/uaa.war --path '/uaa'",
                          log_options(:sc_uaa))
    wait_for_tcp_ready('UAA server', 8080, 200)
    sh "#{File.expand_path("..", __FILE__)}/poststart_uaa.sh"
  end
end
