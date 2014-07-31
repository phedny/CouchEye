AWS = require 'aws-sdk'
expect = require 'expect.js'
follow = require 'follow'

setup = require '../src/setup'

exampleConfig = require '../fixtures/exampleConfig'

describe 'Setup.pipes', ->

    it 'is an object with keys corresponding to the configured pipe names', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(Object.keys(pipes).sort()).to.eql ['pipe1', 'pipe2', 'pipe3']

describe 'Setup.pipes element', ->

    it 'has a feed object created using the follow package', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe1.feed).to.be.a follow.Feed

    it 'has a feed object that is configured using the supplied options', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe1.feed.db).to.be 'http://user:pass@host/db1'

    it 'does not have duplicate feed objects when the same feed is used', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe2.feed is pipes.pipe3.feed).to.be true

    it 'has an endpoint object that is created using the aws-sdk package', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe1.endpoint).to.be.a AWS.SNS

    it 'has an endpoint object that is configurad using the supplied options', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe1.endpoint.config.region).to.be 'us-east-1'
        expect(pipes.pipe1.endpoint.config.credentials.accessKeyId).to.be 'akid'

    it 'has an endpoint object that is configured using the supplied options in alternative form', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe2.endpoint.config.region).to.be 'us-east-1'

    it 'has a topic configured with the supplied ARN', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe2.topic.arn).to.be 'arn:aws:sns:us-east-1:123456789012:MyNewTopic2'

    it 'has a topic configured with the supplied ARN in short form', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe1.topic.arn).to.be 'arn:aws:sns:us-east-1:123456789012:MyNewTopic'

    it 'has the identity as transform function if none was configured', ->
        # given
        inputObject = key: 'value'
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe1.transform inputObject).to.be inputObject

    it 'has the supplied transformDocument function as transform function', ->
        # given
        inputObject =
            id: ':id'
            doc:
                key1: 'value'
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe2.transform inputObject).to.eql key2: 'value'

    it 'has the supplied transformChange function as transform function', ->
        # given
        inputObject =
            id: ':id'
            deleted: true
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe3.transform inputObject).to.eql
            sourceId: ':id'
            exists: false

    it 'has a record of the names of the feed, endpoint and topic', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe1.feedName).to.be 'db1'
        expect(pipes.pipe1.endpointName).to.be 'endpoint1'
        expect(pipes.pipe1.topicName).to.be 'topic1'

    it 'returns a description from toString()', ->
        # when
        {pipes} = setup exampleConfig()
        # then
        expect(pipes.pipe1.toString()).to.be '[Pipe pipe1 from db1 to topic1 in endpoint1]'

describe 'Setup.feeds', ->

    it 'is an object of feeds that are used in a pipe', ->
        # when
        {feeds} = setup exampleConfig()
        # then
        expect(Object.keys(feeds).sort()).to.eql ['db1', 'db2']
