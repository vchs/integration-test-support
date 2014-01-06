require_relative 'component_runner'
require_relative 'integration_example_group'

class ScUaaRunner < ComponentRunner

  def start
    ensure_uaa_database_exists
    run_uaa
    wait_for_tcp_ready('UAA server', port, 200)
    sh "#{File.expand_path("..", __FILE__)}/poststart_uaa.sh"
  end

  def port
    8080
  end

  private

  def run_uaa
    add_pid Process.spawn(
      "java -jar #{tmp_dir}/webapp_runner.jar #{tmp_dir}/uaa.war --path '/uaa'",
      log_options(:uaa))
  end

  def ensure_uaa_database_exists
    sh "psql -c 'DROP DATABASE IF EXISTS uaadb;' -U postgres"
    sh "createdb -U postgres uaadb"
  end
end
