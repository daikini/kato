require 'right_aws'

module Kato
  class PoolManager
    attr_accessor :config, :aws_config, :instances
    
    def initialize(config, aws_config)
      @config = config
      @aws_config = aws_config
      @keep_running = true
      @instances = []
    end
    
    def run
      add_existing_instances if config[:find_existing_instances?]
        
      # fire up the minimum servers first. They take a least 2 minutes to start up
      minimum_number_of_instances = config[:minimum_number_of_instances]
      launch_instances(minimum_number_of_instances - instances.size) if minimum_number_of_instances > instances.size
			
      # used to track time pool has no idle capacity
			start_busy_interval = 0
			
			# used to track time pool has spare capacity
			start_idle_interval = 0
			
			# loopey
			while @keep_running do
			  messages = status_queue.receive_messages(config[:receive_count] || 20)
			  messages.each do |message|
			    break unless @keep_running
			    
          instance_status = InstanceStatus.parse(message.body)
		      if instance = instances.find { |i| i.id == instance_status.instance_id }
		        if instance_status.state == "busy"
              instance.last_busy_interval = instance_status.last_interval
	          elsif instance_status.state == "idle"
              instance.last_idle_interval = instance_status.last_interval
            end
		        
		        instance.last_report_time = Time.now
						instance.update_load
	        end
	        
	        message.delete
		    end
		    
        # for servers that haven't reported recently, bump idle interval...
        instances.each do |instance|
          # if more than a minute (arbitrarily) has gone by without a report,
          # increase the last_idle_interval, and recalc the load_estimate
					if instance.last_report_time < (Time.now - config[:idle_bump_interval])
						instance.last_idle_interval += config[:idle_bump_interval]
						instance.last_report_time = Time.now
						instance.update_load
					end
        end
        
        # calculate pool load average
        sum = instances.inject(0) { |sum, instance| sum + instance.load_estimate }
        number_of_instances = instances.size
        pool_load = number_of_instances == 0 ? 0 : (sum / number_of_instances)
        STDERR.puts "Pool Load Average: #{pool_load}"
        
        # now, see if were full busy, or somewhat idle
        if pool_load > 75 # Busy
          start_busy_interval = Time.now if start_busy_interval == 0
					start_idle_interval = 0
        else
          start_idle_interval = Time.now if start_idle_interval == 0
					start_busy_interval = 0
        end
        
        queue_depth = work_queue.size
        STDERR.puts "Queue Depth: #{queue_depth}"
        
        # fast exit
        break unless @keep_running
        
        # now, based on busy/idle timers and queue depth, make a call on
        # whether to start or terminate servers
        idle_interval = start_idle_interval == 0 ? 0 : (Time.now - start_idle_interval)
        busy_interval = start_busy_interval == 0 ? 0 : (Time.now - start_busy_interval)

        # idle interval has elapsed
        minimum_number_of_instances = config[:minimum_number_of_instances]
        if idle_interval >= config[:ramp_down_delay]
          if number_of_instances > minimum_number_of_instances
            # terminate as many servers (up to the interval)
						number_of_instances_to_kill = [config[:ramp_down_interval], number_of_instances].min
						
            # ensure we don't kill too many servers (not below min)
						if (number_of_instances - number_of_instances_to_kill) < minimum_number_of_instances
						  number_of_instances_to_kill -= (minimum_number_of_instances - (number_of_instances - number_of_instances_to_kill))
						end
						
            # if there are still messages in work queue, leave an idle server
            # (this helps prevent cyclic launching and terminating of servers)
						if queue_depth >= 1 && (number_of_instances_to_kill == number_of_instances)
							number_of_instances_to_kill -= 1
						end
						
						if number_of_instances_to_kill > 0
              # terminate the instances with the lowest load estimate
              instances_sorted_by_lowest_load_estimate = instances.sort do |a,b|
                # Compare the elapsed lifetime status. If the status differs, instances
                # that have lived beyond the minimum lifetime will be sorted earlier.
          			if a.minimum_lifetime_elapsed? != b.minimum_lifetime_elapsed?
          				if a.minimum_lifetime_elapsed?
                    # This instance has lived long enough, the other hasn't
          					-1
          				else
                    # The other instance has lived long enough, this one hasn't
          					1
          				end
          			else
          			  a.load_estimate - b.load_estimate
        			  end
              end
              
              terminate_instances(instances_sorted_by_lowest_load_estimate[0...number_of_instances_to_kill], false)
						end
						
						# reset
						start_idle_interval = 0
          end
        end
        
        # busy interval has elapsed
        maximum_number_of_instances = config[:maximum_number_of_instances]
        if busy_interval >= config[:ramp_up_delay]
					if number_of_instances < maximum_number_of_instances
					  number_of_instances_to_launch = config[:ramp_up_interval]
					  size_factor = config[:queue_size_factor]
					  
            # use queue_depth to adjust the number_of_instances_to_launch
						number_of_instances_to_launch = number_of_instances_to_launch * ((queue_depth / (size_factor < 1 ? 1 :size_factor).to_f) +1 ).to_i
						if (number_of_instances + number_of_instances_to_launch) > maximum_number_of_instances
							number_of_instances_to_launch -= ((number_of_instances + number_of_instances_to_launch) - maximum_number_of_instances)
						end
						
						if number_of_instances_to_launch > 0
							launch_instances(number_of_instances_to_launch)
						end
				  end
				end
				
        # this test will get instances started if there is work and zero instances.
				if number_of_instances == 0 && queue_depth > 0 && maximum_number_of_instances > 0
					launch_instances(config[:ramp_up_interval])
					start_idle_interval = 0
					start_busy_interval = 0
				end
				
				sleep 2
		  end
    end
    
    def shutdown
      @keep_running = false
    end
    
    def status_queue
      @status_queue ||= sqs.queue(config[:queue_prefix] + config[:pool_status_queue])
    end
    
    def work_queue
      @work_queue ||= sqs.queue(config[:queue_prefix] + config[:service_work_queue])
    end
    
    def sqs
      @sqs ||= RightAws::Sqs.new(aws_config[:access_id], aws_config[:access_key], :server => aws_config[:sqs][:server], :port => aws_config[:sqs][:port], :protocol => aws_config[:sqs][:protocol])
    end
    
    def ec2
      @ec2 ||= RightAws::Ec2.new(aws_config[:access_id], aws_config[:access_key], :server => aws_config[:ec2][:server], :port => aws_config[:ec2][:port], :protocol => aws_config[:ec2][:protocol])
    end
    
    def add_existing_instances
      ec2.describe_instances.each do |instance|
        if instance[:aws_image_id] == config[:service_ami] && %w[pending running].include?(instance[:aws_state])
          instances << Instance.new(instance[:aws_instance_id], config[:minimum_lifetime_in_minutes])
        end
      end
    end
    
    def launch_instances(number_of_instances_to_launch)
      launched_instances = ec2.run_instances(config[:service_ami], 1, number_of_instances_to_launch, nil, config[:key_pair_name], config[:user_data])

			if launched_instances.size < number_of_instances_to_launch
			  STDERR.puts "Failed to launch desired number of instances. (#{launched_instances.size} instead of #{number_of_instances_to_launch})"
			end
			
			launched_instances.each do |launched_instance|
			  instances << Instance.new(launched_instance[:aws_instance_id], config[:minimum_lifetime_in_minutes])
			  STDERR.puts "launched instance #{launched_instance[:aws_instance_id]}"
		  end
    end
    
    def terminate_instances(instances_to_terminate, force = false)
      instances_to_terminate = instances_to_terminate.find_all do |instance|
        # Don't stop instances before minimum_lifetime_in_minutes
        force || instance.minimum_lifetime_elapsed?
      end
      
      instances_to_terminate.each do |instance|
        STDERR.puts "Terminating instance #{instance.id}"
        instances.delete instance
      end

      ec2.terminate_instances(instances_to_terminate.collect { |instance| instance.id.to_s }) if instances_to_terminate.any?
    end
  end
  
  class Instance
    attr_accessor :id, :load_estimate, :last_idle_interval, :last_busy_interval, :last_report_time, :startup_time, :minimum_lifetime_in_minutes
    
    def initialize(id, minimum_lifetime_in_minutes = 55)
      @id = id
      @minimum_lifetime_in_minutes = minimum_lifetime_in_minutes
      @load_estimate = 0
			@last_idle_interval = 0
			@last_busy_interval = 0
			@last_report_time = Time.now
			@startup_time = Time.now
    end
    
    def update_load
      @load_estimate = (last_busy_interval.to_i / (last_idle_interval.to_i + last_busy_interval.to_i).to_f * 100)
    end
    
    def minimum_lifetime_elapsed?
      (Time.now - startup_time) > (minimum_lifetime_in_minutes * 60)
    end
  end
  
  class InstanceStatus
    attr_accessor :instance_id, :state, :last_interval, :timestamp
    
    def initialize(instance_id, state, last_interval, timestamp)
      @instance_id, @state, @last_interval, @timestamp = instance_id, state, last_interval, timestamp
    end
    
    def self.parse(xml_or_yaml)
      if xml_or_yaml =~ /<InstanceStatus>/
        # FIXME Parse the xml
      else
        status = YAML.load(xml_or_yaml)
        new(status[:instance_id], status[:state], status[:last_interval], status[:timestamp])
      end
    end
  end
end
