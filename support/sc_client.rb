require 'httpclient'
require 'yajl'

module ScClient
  UnsuccessfulResponse = Class.new(RuntimeError)

  [:get, :post, :put, :delete].each do |act|
    define_method("sc_#{act}".to_sym) do |*args|
      make_sc_request(act, *args)
    end
  end

  def sc_create_instance
    create_instance_request = {
      "service_plan_id" => "core_mysql_200",
      "status" => "stopped",
      "owner_email" => "admin@example.com",
      "description" => "MySQL 5.6",
      "properties" => {
        "size" => "1024MB",
        "deployment_mode" => "shared",
      }.to_json
    }

    sc_post("/api/v1/service_instances", create_instance_request)
  end

  def sc_delete_instance(guid)
    sc_delete("/api/v1/service_instances/#{guid}")
  end

  private

  def gen_token(user, pass)
    auth_string = "#{user}:#{pass}"
    encoded = Base64.encode64(auth_string)
    "Basic #{encoded}"
  end

  def make_sc_request(method, resource_path, body_hash=nil)
    uri = URI.parse("http://127.0.0.1:3000/")
    uri.path = resource_path
    header = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'Authorization' => gen_token("a@b.c", "abc"),
    }
    response = client.public_send(method,
                                  uri,
                                  header: header,
                                  body: Yajl::Encoder.encode(body_hash)
                                 )
    raise UnsuccessfulResponse.new("Unexpected response from #{resource_path}: #{response.inspect}") unless response.ok?
    Yajl::Parser.parse(response.body)
  end

  def client
    HTTPClient.new
  end
end
