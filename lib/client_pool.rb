require 'thread'

class ClientPool

  ClientPoolCreateError = Class.new(StandardError)
  ClientPoolTimeoutError = Class.new(StandardError)

  attr_accessor :instanciatable, :params, :size, :timeout, :checked_out, :clients

  # Create a new client pool
  #
  # *args
  # first: Class of client to pool
  # last : options hash
  # other: any parameters needed for client initialisation

  def initialize(*args)
    @instanciatable = args.shift
    @instanciate_method = [:new,:call].select{|s| @instanciatable.respond_to?(s)}.first
    raise ArgumentError, "#{@instanciatable.inspect} must have a new() or a call() method" if @instanciate_method.nil?
    opts = args.pop || {}
    @params = args
    @no_params == (_ = *@params).nil?

    # Pool size and timeout.
    @size      = opts[:size] || 4
    @timeout   = opts[:timeout]   || 5.0
    @eager     = (opts[:eager] || 2).to_i

    # Mutex for synchronizing pool access
    @connection_mutex = Mutex.new

    # Condition variable for signal and wait
    @queue = ConditionVariable.new

    @clients      = []
    @pids         = {}
    @checked_out  = []

    initialize_clientpool if @eager
  end

  def close
    @clients.each do |inst|
      begin
        inst.close
      rescue => ex
        warn "Error when attempting to close client #{@instanciatable.name}, connected to #{@params.inspect}: #{ex.inspect}"
      end if inst.respond_to?(:close)
    end
    @params = nil
    @clients.clear
    @pids.clear
    @checked_out.clear
  end
  # Return a client to the pool.
  # Allow for closing a client
  def checkin(inst, close=false)
    @connection_mutex.synchronize do
      if close && inst.respond_to?(:close)
        @clients.delete(inst)
        @checked_out.delete(inst)
        @pids.delete(inst)
        inst.close
        sock = checkout_new_socket
      end
      @checked_out.delete(inst)
      @queue.signal
    end
    true
  end

  # Adds a new client to the pool and checks it out.
  def checkout_new_client
    client = create_new_client
    @checked_out << client
    client
  end

  # Checks out the first available client from the pool.
  #
  # If the pid has changed, remove the client and check out
  # new one.
  #
  # This method is called exclusively from #checkout;
  # therefore, it runs within a mutex.
  def checkout_existing_client
    client = (@clients - @checked_out).first
    if @pids[client.object_id] != Process.pid
       @pids[client] = nil
       @clients.delete(client)
       client.close if client.respond_to?(:close)
       checkout_new_client
    else
      @checked_out << client
      client
    end
  end

  # Check out an existing client or create a new client if the maximum
  # pool size has not been exceeded. Otherwise, wait for the next
  # available client.
  def checkout
    start_time = Time.now
    loop do
      if (Time.now - start_time) > @timeout
        raise ClientPoolTimeoutError, "could not checkout client within #{@timeout} seconds. The max pool size is currently #{@size}; consider increasing the pool size or timeout."
      end
      @connection_mutex.synchronize do
        if @checked_out.size < @clients.size
          return checkout_existing_client
        elsif @clients.size < @size
          return checkout_new_client
        else # Otherwise, wait
          @queue.wait(@connection_mutex)
        end
      end
    end
  end

  private

  def create_new_client
    _clone = nil
    begin
      client = unless @no_params
        _clone = @params.is_a?(Hash) ? {}.merge!(@params) : @params.dup
        @instanciatable.send(@instanciate_method, *_clone)
      else
        @instanciatable.send(@instanciate_method)
      end
    rescue => ex
      err_msg = "Failed to create client via #{@instanciatable}"
      err_msg << ", with parameters #{_clone.inspect}" unless @no_params
      err_msg << ": #{ex.inspect}"
      raise ClientPoolCreateError, err_msg
    end
    @clients << client
    @pids[client.object_id] = Process.pid
    client
  end

  def initialize_clientpool
    begin
      @eager.times{ create_new_client }
    ensure
      @checked_out = []
    end
  end
end
