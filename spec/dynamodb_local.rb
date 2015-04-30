class DynamoDBLocal
  DIST_DIR = 'DynamoDBLocal-2015-01-27'

  def self.start!
    raise 'DynamoDBLocal requires JAVA_HOME to be set' unless ENV.has_key?('JAVA_HOME')

    Dir.chdir(DIST_DIR) do
      pid = Kernel.spawn("#{ENV['JAVA_HOME']}/bin/java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -inMemory -delayTransientStatuses")
      STDERR.puts "Started DynamoDBLocal at pid #{pid}."
    end
  end

  def self.stop!
  end
end
