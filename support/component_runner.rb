require 'socket'
require_relative 'ccng_client'

class ComponentRunner < Struct.new(:tmp_dir, :rspec_example)
  include CcngClient

  def start
    raise NotImplementedError
  end

  def stop
    puts "Killing #{self.class.name}..."
    pids.reverse.each do |pid|
      begin
        Timeout::timeout(3) do
          Process.kill "TERM", pid
          Process.wait(pid)
        end
      rescue Timeout::Error
        Process.kill("KILL", pid) rescue Errno::ESRCH
      end
    end
    clear_pids
    puts "Killing threads #{self.class.name}..."
    threads.reverse.each do |thread|
      Thread.kill thread
    end
    clear_threads
  end

  def threads
    @threads ||= []
  end

  def add_thread(thread)
    threads << thread
  end

  def clear_threads
    @threads = nil
  end

  def pids
    @pids ||= []
  end

  def add_pid(pid)
    pids << pid
  end

  def clear_pids
    @pids = nil
  end

  def log_options(name)
    out = "#{name}.out"
    err = "#{name}.err"

    start_message = "\n\n#{'='*80}\nStarting the service...\n#{'='*80}\n\n"
    append_to_log_file(out, start_message)
    append_to_log_file(err, start_message)

    {:out => log_file(out), :err => log_file(err)}
  end

  def log_file(name)
    "#{tmp_dir}/log/#{name}"
  end

  def append_to_log_file(file_name, text)
    FileUtils.mkdir_p("#{tmp_dir}/log")
    file_location = log_file(file_name)
    File.open(file_location, 'a') do |f|
      f.write(text)
    end
  end

  def asset(file_name, root=File.expand_path('..', File.dirname(__FILE__)))
    File.expand_path(File.join(root, 'assets', file_name))
  end

  def wait_for_http_ready(label, port)
    print "Waiting for #{label}..."
    retries = 30
    begin
      response = client.get("http://localhost:#{port}/info")
      raise "Failed to connect, status: #{response.status}" unless response.ok?
      puts "ready!"
    rescue
      print "."
      sleep 0.3
      retries -= 1
      if retries > 0
        retry
      else
        puts
        raise
      end
    end
  end

  def wait_for_tcp_ready(label, port, retries=30)
    print "Waiting for #{label}..."
    begin
      sock = TCPSocket.new("localhost", port)
      sock.close
      puts "ready!"
    rescue
      print "."
      sleep 0.3
      retries -= 1
      if retries > 0
        retry
      else
        puts
        raise
      end
    end
  end

  def create_service_auth_token(label, service_token, provider='core')
    ccng_post("/v2/service_auth_tokens", {label: label, provider: provider, token: service_token})
  end

  def sh(cmd)
    raise "Unable to run #{cmd} in #{Dir.pwd}" unless system(cmd)
  end


  def ensure_no_local_changes
    unless `git status -s`.empty?
      raise 'There are outstanding changes in cloud controller. Need to set NO_CHECKOUT env'
    end
  end

  def ensure_no_local_commits(branch)
    if `git merge-base HEAD #{branch}` != `git rev-parse HEAD`
      raise "There un-pushed commits when running #{self.class.name}. Need to set NO_CHECKOUT env"
    end
  end

  def client
    HTTPClient.new
  end
end
