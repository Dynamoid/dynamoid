# Logging

There is a config option `logger`. Dynamoid writes requests and
responses to DynamoDB using this logger on the `debug` level. So in
order to troubleshoot and debug issues just set it:

```ruby
class User
  include Dynamoid::Document

  field name
end

Dynamoid.config.logger.level = :debug
Dynamoid.config.endpoint = 'http://localhost:8000'

User.create(name: 'Alex')

# => D, [2019-05-12T20:01:07.840051 #75059] DEBUG -- : put_item | Request "{\"TableName\":\"dynamoid_users\",\"Item\":{\"created_at\":{\"N\":\"1557680467.608749\"},\"updated_at\":{\"N\":\"1557680467.608809\"},\"id\":{\"S\":\"1227eea7-2c96-4b8a-90d9-77b38eb85cd0\"}},\"Expected\":{\"id\":{\"Exists\":false}}}" | Response "{}"

# => D, [2019-05-12T20:01:07.842397 #75059] DEBUG -- : (231.28 ms) PUT ITEM - ["dynamoid_users", {:created_at=>0.1557680467608749e10, :updated_at=>0.1557680467608809e10, :id=>"1227eea7-2c96-4b8a-90d9-77b38eb85cd0", :User=>nil}, {}]
```

The first line is a body of HTTP request and response. The second line -
Dynamoid internal logging of API call (`PUT ITEM` in our case) with
timing (231.28 ms).
