
require 'thread'

class ClientPool

  Error = Class.new(StandardError)
  TimeoutError = Class.new(StandardError)
  attr_accessor :klass, :params, :size, :timeout, :checked_out

  # Create a new client pool
  #
  # *args
  # first: Class of client to pool
  # last : options hash
  # other: any parameters needed for client initialisation

  def initialize(*args)
    @klass = args.shift
    opts = args.pop
    @params = args
    # Pool size and timeout.
    @size      = opts[:size] || 2
    @timeout   = opts[:timeout]   || 5.0
    @eager      = opts[:eager] || false

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
        warn "Error when attempting to close client #{@klass.name}, connected to #{@params.inspect}: #{ex.inspect}"
      end
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
    begin
      client = @klass.new(*@params)
    rescue => ex
      raise Error, "Failed to create client #{@klass.name}, connected to #{@params.inspect}: #{ex.inspect}"
    end

    @checked_out << client
    @clients << client
    @pids[client] = Process.pid
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
    if @pids[client] != Process.pid
       @pids[client] = nil
       @clients.delete(client)
       client.close
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
          raise TimeoutError, "could not checkout client within " +
            "#{@timeout} seconds. The max pool size is currently #{@size}; " +
            "consider increasing the pool size or timeout."
      end

      @connection_mutex.synchronize do
        client = if @checked_out.size < @clients.size
                   checkout_existing_client
                 elsif @clients.size < @size
                   checkout_new_client
                 end

        if client
          return client
        else
          # Otherwise, wait
          @queue.wait(@connection_mutex)
        end
      end
    end
  end

  private

  def initialize_clientpool
    begin
      @size.times{ checkout_new_client }
    ensure
      @checked_out = []
    end
  end
end
