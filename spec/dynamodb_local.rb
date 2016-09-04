module DynamoDBLocal
  DIST_DIR = File.join(File.dirname(__FILE__), 'DynamoDBLocal-latest')
  PIDFILE = "#{DIST_DIR}/dynamodb.pid"

  def self.raise_unless_running!
    pid = File.read(PIDFILE).gsub(/\n/,'').to_i
    Process.kill(0, pid) # Does nothing if process is running, fails if not running
  end

  def self.ensure_is_running!
    begin
      if File.exists? PIDFILE
        self.raise_unless_running!
      else
        STDERR.puts "The #{PIDFILE} did not exist. Starting Dynamo DB Local."
        self.start!
        sleep 1
        self.raise_unless_running!
        return true
      end
    rescue Errno::ESRCH
      STDERR.puts "The #{PIDFILE} exists but the process was not running"
      self.start!
      sleep 1
      retry
    end
  end

  def self.start!
    raise 'DynamoDBLocal requires JAVA_HOME to be set' unless ENV.has_key?('JAVA_HOME')
    output = `sh bin/start_dynamodblocal`
    STDERR.puts output
  end

  def self.stop!
    output = `sh bin/stop_dynamodblocal`
    STDERR.puts output
  end

  def self.delete_all_specified_tables!
    if !Dynamoid.adapter.tables.empty?
      Dynamoid.adapter.list_tables.each do |table|
        Dynamoid.adapter.delete_table(table) if table =~ /^#{Dynamoid::Config.namespace}/
      end
      Dynamoid.adapter.tables.clear
    end
  end
end
