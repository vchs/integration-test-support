require "uaa/token_coder"
require 'fileutils'
require 'active_support/core_ext'
Dir.glob(File.join(File.dirname(__FILE__), '*')).each do |file|
  require file
end

module IntegrationExampleGroup
  include CcngClient

  def self.tmp_dir
    @@tmp_dir or raise "No tmp_dir set. Please set one with #{self.name}.tmp_dir="
  end

  def self.tmp_dir=(new_value)
    @@tmp_dir = new_value
  end

  def tmp_dir
    IntegrationExampleGroup.tmp_dir
  end

  def login_to_ccng_as(user_guid, email)
    @login_info = {user_id: user_guid, email: email}
  end

  def self.included(base)
    base.instance_eval do
      metadata[:type] = :integration
      hook_on = metadata[:hook_on] || :each
      coms = metadata[:components] || []
      let(:mysql_root_connection) { component!(:mysql).mysql_root_connection }
      before hook_on do |example|
        coms.each do |component|
          instance = component(component, example)
          instance.start
        end
      end
      after(hook_on) { ComponentRegistry.reset! }
    end
  end

  def space_guid
    component!(:ccng).space_guid
  end

  def org_guid
    component!(:ccng).org_guid
  end

  def component(name, rspec_example)
    FileUtils.mkdir_p(tmp_dir)
    ComponentRegistry.register(name, self.class.const_get("#{name.to_s.camelize}Runner").new(tmp_dir, rspec_example))
  end

  def component!(name)
    ComponentRegistry.fetch(name)
  end

  def provision_mysql_instance(name)
    provision_service_instance(name, "mysql", "100")
  end

  def provision_service_instance(name, service_name, plan_name)
    inst_data = ccng_post "/v2/service_instances",
      name: name,
      space_guid: space_guid,
      service_plan_guid: plan_guid(service_name, plan_name)
    inst_data.fetch("metadata").fetch("guid")
  end

  def plan_guid(service_name, plan_name)
    plans_path = service_response(service_name).fetch("entity").fetch("service_plans_url")
    plan_response(plan_name, plans_path).fetch('metadata').fetch('guid')
  end

  private

  def plan_response(plan_name, plans_path)
    with_retries(30) do
      response = client.get "http://localhost:8181/#{plans_path}", header: { "AUTHORIZATION" => ccng_auth_token }
      res = Yajl::Parser.parse(response.body)
      res.fetch("resources").detect {|p| p.fetch('entity').fetch('name') == plan_name } or
        raise "Could not find plan with name #{plan_name.inspect} in response #{response.body}"
    end
  end

  def service_response(service_name)
    with_retries(30) do
      response = client.get "http://localhost:8181/v2/services", header: { "AUTHORIZATION" => ccng_auth_token }

      res = Yajl::Parser.parse(response.body)
      res.fetch("resources").detect {|service| service.fetch('entity').fetch('label') == service_name } or
        raise "Could not find a service with name #{service_name} in #{response.body}"
    end
  end

  def with_retries(retries, &block)
    begin
      block.call
    rescue
      retries -= 1
      sleep 0.3
      if retries > 0
        retry
      else
        raise
      end
    end
  end
end
