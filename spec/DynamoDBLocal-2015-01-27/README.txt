README
========

For an overview of DynamoDB Local please refer to the documentation at http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Tools.DynamoDBLocal.html


Enhancements in this release
-----------------------------

http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/Welcome.html

* Add support for online indexing

Note the following difference in DynamoDBLocal:

* Local's exception messages may differ from those returned by the service. 



Running DynamoDB Local (There are two new command line options available for running DynamoDB Local)
---------------------------------------------------------------

java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar [options]

For more information on available options, run with the -help option:
  java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar -help
