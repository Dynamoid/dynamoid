module DynamoDBLocal
  def self.delete_all_specified_tables!
    if !Dynamoid.adapter.tables.empty?
      Dynamoid.adapter.list_tables.each do |table|
        Dynamoid.adapter.delete_table(table) if table =~ /^#{Dynamoid::Config.namespace}/
      end
      Dynamoid.adapter.tables.clear
    end
  end
end
