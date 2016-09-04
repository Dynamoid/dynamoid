module DynamoDBLocal
  DIST_DIR = File.join(File.dirname(__FILE__), 'DynamoDBLocal-latest')
  PIDFILE = "#{DIST_DIR}/dynamodb.pid"

  def self.raise_unless_running!
    pid = File.read(PIDFILE).gsub(/\n/,'').to_i
    Process.kill(0, pid) # Does nothing if process is running, fails if not running
  end

  def self.ensure_is_running!
    if File.exists? PIDFILE
      begin
        self.raise_unless_running!
      rescue Errno::ESRCH
        STDERR.puts "The #{PIDFILE} exist but the process was not running"
        self.start!
        return false
      end
    else
      self.start!
      return true
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
    Dynamoid.adapter.list_tables.each do |table|
      Dynamoid.adapter.delete_table(table) if table =~ /^#{Dynamoid::Config.namespace}/
    end
    Dynamoid.adapter.tables.clear
  end
end
