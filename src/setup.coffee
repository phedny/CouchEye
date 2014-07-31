AWS = require 'aws-sdk'
follow = require 'follow'

module.exports = (options) ->
    feeds = {}
    pipes = {}
    for name, pipeOptions of options.pipes
        feed = feeds[feedName = pipeOptions.feed] or feeds[pipeOptions.feed] = new follow.Feed options.feeds[pipeOptions.feed]
        topic = options.topics[topicName = pipeOptions.topic]
        endpoint = options.endpoints[endpointName = pipeOptions.endpoint or topic.endpoint]
        pipes[name] =
            feedName: feedName
            feed: feed
            endpointName: endpointName
            endpoint: new AWS.SNS endpoint
            topicName: topicName
            topic: arn: topic.arn or topic
            transform: if pipeOptions.transformChange?
                pipeOptions.transformChange
            else if pipeOptions.transformDocument?
                do (t = pipeOptions.transformDocument) ->
                    (obj) -> t obj.doc
            else
                (obj) -> obj
            toString: do (name, feedName, topicName, endpointName) ->
                -> "[Pipe #{name} from #{feedName} to #{topicName} in #{endpointName}]"

    feeds: feeds
    pipes: pipes
