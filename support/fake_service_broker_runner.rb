require_relative 'component_runner'

class FakeServiceBrokerRunner < ComponentRunner
  def start
    Dir.chdir(File.join(File.dirname(__FILE__), '..', 'assets', 'fake_service_broker')) do
      Bundler.with_clean_env do
        sh 'bundle install'
        add_pid Process.spawn 'bundle exec rackup -p 54329 > /dev/null 2>&1'
      end
    end
    wait_for_http_ready('Fake Service Broker', 54329)
  end
end
