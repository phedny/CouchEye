{EventEmitter} = require 'events'
url = require 'url'

redis = require 'redis'

setup = require './setup'

class CouchEye extends EventEmitter

    constructor: (options) ->

        # Setup the feeds and pipes
        if options._feeds? and options._pipes?
            @_feeds = options._feeds
            @_pipes = options._pipes
        else
            {feeds: @_feeds, pipes: @_pipes} = setup options

        # Setup Redis client
        if options.redis?
            @_redis = options.redis
        else
            rtg = url.parse options.redisUrl
            @_redis = redis.createClient rtg.port, rtg.hostname
            @_redis.auth rtg.auth.split(':')[1]

        # Look up last seen sequence numbers
        feedOrder = []
        batch = @_redis.multi()
        for name, feed of @_feeds
            batch = batch.get("#{options.redisPrefix or ''}#{name}")
            feedOrder.push feed
        batch.exec (err, replies) =>
            return @emit 'error', err if err?
            return @emit new Error 'Unexpected Redis reply count' unless feedOrder.length is replies.length
            feedOrder[i].since = reply for reply, i in replies when reply?
            @_ready = true
            @start() if @_started

        # Emit any error that occurs on a feed
        for name, feed of @_feeds then do (name) =>
            feed.on 'error', (err) =>
                err.message = "On #{name}: #{err.message}"
                @emit 'error', err

        # Handle changes
        for name, pipe of @_pipes then do (name, pipe) =>
            pipe.feed.on 'change', (change) =>
                sequence = change.seq
                return unless (change = pipe.transform change)?
                pipe.endpoint.publish
                    TopicArn: pipe.topic.arn
                    Message: JSON.stringify change
                , (err, data) =>
                    return @emit 'error', err if err?
                    @_redis.set "#{options.redisPrefix}#{pipe.feedName}", sequence, (err, result) ->
                        return @emit 'error', err if err?

    start: =>
        if @_ready
            feed.follow() for name, feed of @_feeds
        else
            @_started = true

module.exports = (options) -> new CouchEye options
