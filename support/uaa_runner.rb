require_relative 'component_runner'
require_relative 'integration_example_group'

class UaaRunner < ComponentRunner
  S3_BUCKET_URL = 'https://s3.amazonaws.com/services-blobs'
  JETTY_FILE_NAME = 'jetty-runner.jar'
  JETTY_CHECKSUM = 'd40d36c3e8473df607f3458691e9f778'
  UAA_FILE_NAME = 'uaa-1.4.0.war'
  UAA_CHECKSUM = 'd4880876e69b6f4f97b92e761d479257'

  def start
    download_file_from_s3(JETTY_FILE_NAME, JETTY_CHECKSUM)
    download_file_from_s3(UAA_FILE_NAME, UAA_CHECKSUM)
    ensure_uaa_database_exists
    setup_environment_variables
    run_uaa
    wait_for_tcp_ready('UAA server', port, 200)
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

  def download_file_from_s3(file_name, expected_checksum)
    Dir.chdir(tmp_dir) do
      unless File.exist?(file_name)
        print "Downloading #{file_name}..."
        `wget -q #{S3_BUCKET_URL}/#{file_name}`
        puts 'done!'
      end

      actual_checksum = `md5 -q #{file_name}`.strip
      unless actual_checksum == expected_checksum
        raise "Checksum for #{file_name} does not match. Expected #{expected_checksum}, received #{actual_checksum}."
      end
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
