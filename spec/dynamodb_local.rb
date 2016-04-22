class DynamoDBLocal
  DIST_DIR = File.join(File.dirname(__FILE__), 'DynamoDBLocal-latest')
  PIDFILE = "#{DIST_DIR}/dynamodb.pid"

  def self.ensure_is_running!
    if File.exists? PIDFILE
      begin
        pid = File.read(PIDFILE).gsub(/\n/,'').to_i
        Process.kill(0, pid)
      rescue Errno::ESRCH
        STDERR.puts "The #{PIDFILE} exist but the process was not running"
        self.start!
      end
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
end
