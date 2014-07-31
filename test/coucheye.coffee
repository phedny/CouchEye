expect = require 'expect.js'
sinon = require 'sinon'

coucheye = require '../src/coucheye'

mockDb = ->
    follow: sinon.stub().returnsThis()
    on: sinon.stub().returnsThis()

describe 'CouchEye', ->

    db1 = null
    multi = null
    options = null
    beforeEach ->
        multi =
            get: sinon.stub().returnsThis()
            exec: sinon.stub().callsArgWithAsync 0, null, ['seq1', null, 'seq2']
        db1 = mockDb()
        options =
            redis:
                set: sinon.stub().callsArgWithAsync 2, null, 'OK'
                multi: -> multi
            redisPrefix: 'prefix.'
            feeds:
                db1: db1
                db2: mockDb()
                db3: mockDb()
            pipes:
                pipe1:
                    feedName: 'db1'
                    feed: db1
                    endpointName: 'endpoint1'
                    endpoint:
                        publish: sinon.stub().callsArgWithAsync 1, null, MessageId: 'msgId'
                    topicName: 'topic1'
                    topic:
                        arn: 'arn:aws:sns:us-east-1:123456789012:MyNewTopic'
                    transform: sinon.stub().returns transformed: true

    it 'retrieves the last seen sequence numbers from Redis', ->
        # when
        coucheye options
        # then
        expect(multi.get.args).to.eql [
            ['prefix.db1']
            ['prefix.db2']
            ['prefix.db3']
        ]

    it 'sets the sequence numbers on the feeds', (done) ->
        # when
        coucheye options
        # then
        process.nextTick ->
            expect(options.feeds.db1.since).to.be 'seq1'
            expect(options.feeds.db2.since).to.be undefined
            expect(options.feeds.db3.since).to.be 'seq2'
            done()

    it 'does not yet follow the feeds when sequence numbers are known, but start() isn\'t called yet', (done) ->
        # when
        coucheye options
        # then
        process.nextTick ->
            expect(options.feeds.db1.follow.called).to.be false
            done()

    it 'follows the feeds when start() is called and sequence numbers are known', (done) ->
        # when
        cy = coucheye options
        process.nextTick ->
            cy.start()
            # then
            expect(options.feeds.db1.follow.called).to.be true
            done()

    it 'does not yet follow the feeds when start() is, but sequence numbers aren\'t known yet', ->
        # when
        cy = coucheye options
        cy.start()
        # then
        expect(options.feeds.db1.follow.called).to.be false

    it 'follows the feeds when sequence numbers are received and start() has already been invoked', ->
        # when
        cy = coucheye options
        cy.start()
        process.nextTick ->
            # then
            expect(options.feeds.db1.follow.called).to.be true

    it 'emits an error when a feed emits an error', (done) ->
        # given
        cy = coucheye options
        error = null
        cy.on 'error', (err) -> error = err
        process.nextTick ->
            # when
            errorListener = (args[1] for args in db1.on.args when args[0] is 'error')[0]
            errorListener new Error 'error message'
            # then
            expect(error.message).to.be 'On db1: error message'
            done()

    it 'transforms a received change', ->
        # given
        coucheye options
        changeListener = (args[1] for args in db1.on.args when args[0] is 'change')[0]
        change =
            id: ':id'
            seq: 'seq3'
            doc: {}
        # when
        changeListener change
        # then
        expect(options.pipes.pipe1.transform.calledWith change).to.be true

    it 'publishes the transformed change to SNS', ->
        # given
        coucheye options
        changeListener = (args[1] for args in db1.on.args when args[0] is 'change')[0]
        change =
            id: ':id'
            seq: 'seq3'
            doc: {}
        # when
        changeListener change
        # then
        expectedPublish =
            TopicArn: 'arn:aws:sns:us-east-1:123456789012:MyNewTopic'
            Message: '{"transformed":true}'
        expect(options.pipes.pipe1.endpoint.publish.calledWith expectedPublish).to.be true

    it 'does not publish the transformed change to SNS when it is null', ->
        # given
        coucheye options
        changeListener = (args[1] for args in db1.on.args when args[0] is 'change')[0]
        change =
            id: ':id'
            seq: 'seq3'
            doc: {}
        options.pipes.pipe1.transform = sinon.stub().returns null
        # when
        changeListener change
        # then
        expect(options.pipes.pipe1.endpoint.publish.called).to.be false

    it 'emits an error when publishing to SNS fails', (done) ->
        # given
        cy = coucheye options
        changeListener = (args[1] for args in db1.on.args when args[0] is 'change')[0]
        change =
            id: ':id'
            seq: 'seq3'
            doc: {}
        options.pipes.pipe1.endpoint.publish = sinon.stub().callsArgWithAsync 1, new Error 'error message'
        error = null
        cy.on 'error', (err) -> error = err
        # when
        changeListener change
        # then
        process.nextTick ->
            expect(error.message).to.be 'error message'
            done()

    it 'updates the last seen sequence number in Redis after publishing to SNS', (done) ->
        # given
        cy = coucheye options
        changeListener = (args[1] for args in db1.on.args when args[0] is 'change')[0]
        change =
            id: ':id'
            seq: 'seq3'
            doc: {}
        # when
        changeListener change
        # then
        process.nextTick ->
            expect(options.redis.set.calledWith 'prefix.db1', 'seq3').to.be true
            done()
