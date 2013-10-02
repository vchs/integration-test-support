module ComponentRegistry
  class << self
    def register(name, instance)
      raise "Component #{name} already registered" if components.has_key?(name)
      components[name] = instance
      instance
    end

    def fetch(name)
      components.fetch(name)
    end

    def clear!
      @components = {}
    end

    def reset!
      components.values.reverse.each { |component| component.stop }
      clear!
    end

    private

    def components
      @components ||= {}
    end
  end
end
