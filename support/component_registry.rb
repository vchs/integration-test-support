module ComponentRegistry
  def self.register(name, instance)
    @components ||= {}
    raise "Component #{name} already registered" if @components.has_key?(name)
    @components[name] = instance
    instance
  end

  def self.fetch(name)
    @components.fetch(name)
  end

  def self.clear!
    @components = {}
  end

  def self.reset!
    @components.values.reverse.each { |component| component.stop }
    clear!
  end
end
