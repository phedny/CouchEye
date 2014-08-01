CouchEye
========

The CouchEye tool can be used to monitor changes in one or more CouchDb databases and send notifications to topics in the Amazon Simple Notification Service (SNS). Multiple databases can be monitored by one running CouchEye instance and changes can be routed to multiple topics, which may even be in different regions or require diferrent credentials.

To use CouchEye, simple install is using `npm`:

```sh
npm install --save coucheye
```

Below you'll find an example configuration using CoffeeScript syntax.

Configuration options
---------------------

| Key                          | Description                                                                             |
|------------------------------|-----------------------------------------------------------------------------------------|
| redis                        | Object as returned by `createClient` in the [redis] package                             |
| redisUrl                     | URL of the Redis server; required unless `redis` option is given                        |
| redisPrefix                  | Sequence numbers for a feed are stored under `#{redisPrefix}#{feedName}`                |
| feeds                        | A set of CouchDb feeds                                                                  |
| feeds.{name}.*               | Properties as accepted by the [follow] package                                          |
| endpoints                    | A set of Amazon AWS endpoints, including credentials                                    |
| endpoints.{name}.*           | Properties as accepted by the [aws-sdk] package                                         |
| topics                       | A set of SNS topics to which changes can be published                                   |
| topics.{name}.arn            | ARN of an SNS topic                                                                     |
| pipes                        | A set of pipes that connect feeds, endpoints and topics                                 |
| pipes.{name}.feed            | Name of the feed to draw change from                                                    |
| pipes.{name}.endpoint        | Name of the endpoint to send notifications to                                           |
| pipes.{name}.topic           | Name of the topic to send notifications to                                              |
| pipes.{name}.transformChange | Function to transform a change object                                                   |
| pipes.{name}.transformDoc    | Function to transform a change document; depends on `feeds.<name>.include_docs` options |

The `pipes.<name>.transformChange` and `pipes.<name>.transformDoc` options are not required, but are mutually exclusive. When either of those is used, the return value is used as content for the notification. If `null` or `undefined` is returned, not notification is published.

Example configuration
---------------------

```coffee-script
coucheye = (require 'coucheye')
    redisUrl: 'redis://username:password@redis.domain:9356/'
    redisPrefix: 'coucheye.'
    feeds:
        examples:
            db: 'https://username:password@couchdb.domain/examples'
            include_docs: true
        extensions:
            db: 'https://username:password@couchdb.domain/extensions'
            include_docs: true
    endpoints:
        sns:
            accessKeyId: 'akid'
            secretAccessKey: 'secret'
            region: 'eu-west-1'
    topics:
        exampleUpdated: 'arn:aws:sns:eu-west-1:123456789012:ExampleUpdated'
        exampleCompleted: 'arn:aws:sns:eu-west-1:123456789012:ExampleCompleted'
        extensionCreated: 'arn:aws:sns:eu-west-1:123456789012:ExtensionCreated'
        extensionApproved: 'arn:aws:sns:eu-west-1:123456789012:ExtensionApproved'
    pipes:
        exampleUpdated:
            feed: 'examples'
            endpoint: 'sns'
            topic: 'exampleUpdated'
            transformChange: (change) ->
                # Ignore deletions
                return null if change.deleted
                exampleId: change.id
        exampleCompleted:
            feed: 'examples'
            endpoint: 'sns'
            topic: 'exampleCompleted'
            transformDocument: (doc) ->
                # Only notify for completed example
                return null unless doc.status is 'COMPLETED'
                exampleId: doc._id
        extentionCreated:
            feed: 'extensions'
            endpoint: 'sns'
            topic: 'extensionCreated'
            transformDocument: (doc) ->
                # First revision means document has just been created
                return null unless doc._rev.match(/^1-/)?
                extensionId: doc._id
        extensionApproved:
            feed: 'extensions'
            endpoint: 'sns'
            topic: 'extensionApproved'
            transformDocument: (doc) ->
                # Require an approval
                return null unless doc.approval?
                # But not an error
                return null if doc.error?
                extensionId: doc._id

coucheye.on 'error', (err) ->
    console.err err
    process.exit 1

coucheye.start()

```

[redis]: https://www.npmjs.org/package/redis
[follow]: https://www.npmjs.org/package/follow
[aws-sdk]: https://www.npmjs.org/package/aws-sdk
