module.exports = ->
    feeds:
        db1: 'http://user:pass@host/db1'
        db2:
            db: 'http://user:pass@host/db2'
            include_docs: true
            filter: 'app/important'
        unusedDb: 'http://otherHost/db'

    endpoints:
        endpoint1:
            accessKeyId: 'akid'
            secretAccessKey: 'secret'
            region: 'us-east-1'

    topics:
        topic1: 'arn:aws:sns:us-east-1:123456789012:MyNewTopic'
        topic2:
            endpoint: 'endpoint1'
            arn: 'arn:aws:sns:us-east-1:123456789012:MyNewTopic2'
        topic3:
            endpoint: 'endpoint1'
            arn: 'arn:aws:sns:us-east-1:123456789012:MyNewTopic3'

    pipes:
        pipe1:
            feed: 'db1'
            endpoint: 'endpoint1'
            topic: 'topic1'
        pipe2:
            feed: 'db2'
            topic: 'topic2'
            transformDocument: (doc) ->
                doc.key2 = doc.key1
                delete doc.key1
                doc
        pipe3:
            feed: 'db2'
            topic: 'topic3'
            transformChange: (change) ->
                sourceId: change.id
                exists: not change.deleted
