/opt/install/aws/dynamodb.tar.gz:
  file.managed:
    - source: https://s3-us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_2019-02-07.tar.gz
    - source_hash: sha256=3281b5403d0d397959ce444b86a83b44bc521e8b40077a3c2094fa17c9eb3c43
    - makedirs: True

/vagrant/spec/DynamoDBLocal-latest:
  file.directory:
    - name: /vagrant/spec/DynamoDBLocal-latest
    - user: vagrant
    - group: vagrant

dynamodb.install:
  cmd.wait:
    - name: cd /vagrant/spec/DynamoDBLocal-latest && tar xfz /opt/install/aws/dynamodb.tar.gz
    - watch:
      - file: /opt/install/aws/dynamodb.tar.gz
