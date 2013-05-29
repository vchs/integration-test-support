require_relative 'integration_example_group'

class UaaRunner < ComponentRunner
  S3_BUCKET_URL = 'https://s3.amazonaws.com/services-blobs'
  JETTY_FILE_NAME = 'jetty-runner.jar'
  UAA_FILE_NAME='uaa-1.4.0.war'

  def start
    download_file_from_s3(JETTY_FILE_NAME)
    download_file_from_s3(UAA_FILE_NAME)
    ensure_uaa_database_exists
    setup_environment_variables
    run_uaa
    wait_for_tcp_ready('UAA server', port, 50)
  end

  def port
    7777
  end

  private

  def run_uaa
    add_pid Process.spawn("java -jar #{tmp_dir}/jetty-runner.jar --port #{port} #{tmp_dir}/uaa-1.4.0.war", log_options(:uaa))
  end

  def tmp_dir
    IntegrationExampleGroup.tmp_dir
  end

  def download_file_from_s3(file_name)
    Dir.chdir(tmp_dir) do
      `wget -q #{S3_BUCKET_URL}/#{file_name}` unless File.exist?(file_name)
    end
  end

  def asset_path
    File.expand_path("../assets", File.dirname(__FILE__))
  end

  def ensure_uaa_database_exists
    system("createdb uaadb -U postgres -O postgres") unless `psql -U postgres -c '\\l' | cut -d' ' -f2`.include?("uaadb")
  end

  def setup_environment_variables
    ENV["CLOUD_FOUNDRY_CONFIG_PATH"] = asset_path
  end
end