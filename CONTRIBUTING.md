# Contributing


## Setup

1. Clone Dynamoid's Git repository (swap for your fork, if you took that route):
    ```
    $ git clone https://github.com/Dynamoid/dynamoid.git
    $ cd dynamoid
    ```
2. Run `bin/setup` to install dependencies - including gems and _dynamodb-local_'s JAR.

Local development is mostly based on _dynamodb-local_ so it should be
installed and launched when you need either to run specs or to work in
a REPL. See the [dynamodb-local](#dynamodb-local) section below for more details.


## Specs

The specs are written with RSpec and are supposed to be run against
_dynamodb-local_ only.

Use the following command to run specs:

```
$ bin/rspec
```

_dynamodb-local_ should be installed and run beforehand.

> [!NOTE]
> It's common to have a separate table per a test case but it's very slow
> to create a new table in a real AWS account so this is impractically slow
> to run the whole specs suite against a real AWS account.
>
> The other option would be to use a small number of preexisting tables.
> This way they should be created just once and cleared before running
> each test case. This approach was actually used but made it difficult
> evolve specs and add test cases that require different primary key
> schemas, global/local secondary indices and fields types and options.


### Model per test case

It's useful to be able easily define a model class for a
context/describe section or even for a particular test case without
defining a new constant etc.

Use a `new_class` helper method:

```ruby
describe 'validation' do
  let(:klass_with_validation) do
    new_class do
      field :name
      validates :name, length: { minimum: 4 }
    end
  end

  it 'does not save invalid model' do
    obj = klass_with_validation.create(name: 'Theodor')
    expect(obj).to be_persisted

    obj = klass_with_validation.create(name: 'Mo')
    expect(obj).not_to be_persisted
  end
end
```


### Logging

Use `log_level: :debug` RSpec tag to have all requests and responses
made and received during a test printed into console:

```ruby
it 'deletes an item completely', log_level: :debug do
  @user = User.create(name: 'Josh')
  @user.destroy

  expect(Dynamoid.adapter.read('dynamoid_tests_users', @user.id)).to be_nil
end
```


### Changing global config per test

Use `config: {...}` RSpec tag to modify a global config before a test
starts and roll it back after test finishing:

```ruby
it '...', config: { store_boolean_as_native: true } do
  klass = new_class do
    field :active, :boolean
  end

  obj = klass.create(active: true)

  expect(raw_attributes(obj)[:active]).to eql(true)
  expect(reload(obj).active).to eql(true)
end
```


## REPL

Use the following command to run IRB session with loaded and configured Dynamoid:

```
$ bin/console
```


# dynamodb-local

_dynamodb-local_ is software provided by Amazon to emulate DynamoDB and
run it locally. See [official documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html) to install it.

To run _dynamodb-local_ using a Docker image use the following command
(installs the Docker image automatically):

```
$ docker run --rm -d -p 8000:8000 amazon/dynamodb-local
```

A Docker Compose file is also provided.

To run _dynamodb-local_ as a JAR (that should be already downloaded)
there are the following scripts to run and stop it:

- `bin/start_dynamodblocal`
- `bin/stop_dynamodblocal`


## Pull Requests

There are the following requirements for new Pull Requests:

- commits should be atomic and named properly
- new specs should be present for bug fixes and new features or changes
  in existing ones
- new public methods should be documented with inlined RDoc comments
- new configuration option should be documented in README.md
- a Pull Request description on GitHub should contain helpful information for reviewers
  to understand the purpose of changes

> [!NOTE]
> The CodeClimate check on GitHub is useful but not mandatory. It isn't
> necessary to blindly follow its recommendations if it hurts readability
> or simplicity of code.

