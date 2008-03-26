module Kato
  class PoolSupervisor
    attr_accessor :config, :pool_managers
    
    def initialize(config)
      @config = config
      @pool_managers = []
    end
    
    def run
      threads = []
      config[:service_pools].each do |service_pool|
        threads << Thread.new(service_pool) do |pool_config|
          pool_manager = PoolManager.new(pool_config, config[:aws])
          @pool_managers << pool_manager
          pool_manager.run
        end
        threads.each { |thread| thread.join }
      end
    end
  end
end