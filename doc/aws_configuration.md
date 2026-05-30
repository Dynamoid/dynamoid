### AWS Configuration

Configure AWS access:
[Reference](https://github.com/aws/aws-sdk-ruby)

For example, to configure AWS access:

Create `config/initializers/aws.rb` as follows:

```ruby
Aws.config.update(
  region: 'us-west-2',
  credentials: Aws::Credentials.new('REPLACE_WITH_ACCESS_KEY_ID', 'REPLACE_WITH_SECRET_ACCESS_KEY'),
)
```

Alternatively, if you don't want AWS connection settings to be
overwritten for your entire project, you can specify connection settings
for Dynamoid only, by setting those in the `Dynamoid.configure` clause:

```ruby
require 'dynamoid'
Dynamoid.configure do |config|
  config.access_key = 'REPLACE_WITH_ACCESS_KEY_ID'
  config.secret_key = 'REPLACE_WITH_SECRET_ACCESS_KEY'
  config.region = 'us-west-2'
end
```

Additionally, if you would like to pass in pre-configured AWS credentials
(e.g. you have an IAM role credential, you configure your credentials
elsewhere in your project, etc.), you may do so:

```ruby
require 'dynamoid'

credentials = Aws::AssumeRoleCredentials.new(
  region: region,
  access_key_id: key,
  secret_access_key: secret,
  role_arn: role_arn,
  role_session_name: 'our-session'
)

Dynamoid.configure do |config|
  config.region = 'us-west-2'
  config.credentials = credentials
end
```

For a full list of the DDB regions, you can go
[here](http://docs.aws.amazon.com/general/latest/gr/rande.html#ddb_region).

Then you need to initialize Dynamoid config to get it going. Put code
similar to this somewhere (a Rails initializer would be a great place
for this if you're using Rails):

```ruby
require 'dynamoid'
Dynamoid.configure do |config|
  # To namespace tables created by Dynamoid from other tables you might have.
  # Set to nil to avoid namespacing.
  config.namespace = 'dynamoid_app_development'

  # [Optional]. If provided, it communicates with the DB listening at the endpoint.
  # This is useful for testing with [DynamoDB Local](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html).
  config.endpoint = 'http://localhost:3000'
end
```
