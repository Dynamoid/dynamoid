/opt/install/aws/dynamodb.tar.gz:
  file.managed:
    - source: https://s3-us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_2017-02-16.tar.gz
    - source_hash: sha256=d79732d7cd6e4b66fbf4bb7a7fc06cb75abbbe1bbbfb3d677a24815a1465a0b2
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
