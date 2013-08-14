require 'sinatra'

class IntegrationTestComponent < Sinatra::Base
  # Polled by the integration test component runner to determine
  # when a component is up and ready to receive requests.
  get '/info' do
    [200, {}, '']
  end
end

class FakeServiceBroker < Sinatra::Base
  use IntegrationTestComponent

  use Rack::Auth::Basic, 'Restricted Area' do |_, password|
    password == 'opensesame'
  end

  # Queried by Cloud Controller to determine if this is a real,
  # API-compliant service broker.
  get '/v3' do
    [200, {}, '["OK"]']
  end
end
