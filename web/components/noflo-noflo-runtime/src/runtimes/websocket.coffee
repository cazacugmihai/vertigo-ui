Base = require './base'

class WebSocketRuntime extends Base
  constructor: (definition) ->
    @connecting = false
    @connection = null
    @protocol = 'noflo'
    @buffer = []
    super definition

  getElement: ->
    # DOM visualization for remote runtime output
    console = document.createElement 'pre'

    @on 'network', (message) ->
      return unless message.command is 'output'
      console.innerHTML = "#{console.innerHTML}#{message.payload.message}\n"
      console.scrollTop = console.scrollHeight
    @on 'disconnected', ->
      console.innerHTML = ''

    console

  connect: ->
    return if @connection or @connecting

    @connection = new WebSocket @getAddress() #, @protocol
    @connection.addEventListener 'open', =>
      @connecting = false
      @emit 'status',
        online: true
        label: 'connected'
      @emit 'connected'
      @flush()
    , false
    @connection.addEventListener 'message', @handleMessage, false
    @connection.addEventListener 'error', @handleError, false
    @connection.addEventListener 'close', =>
      @connection = null
      @emit 'status',
        online: false
        label: 'disconnected'
      @emit 'disconnected'
    , false
    @connecting = true

  disconnect: ->
    return unless @connection
    @connecting = false
    @connection.close()

  send: (protocol, command, payload) ->
    if @connecting
      @buffer.push
        protocol: protocol
        command: command
        payload: payload
      return

    return unless @connection
    @connection.send JSON.stringify
      protocol: protocol
      command: command
      payload: payload

  handleError: (error) =>
    @connection = null
    @connecting = false

  handleMessage: (message) =>
    that = this
    reader = new FileReader;
    reader.addEventListener "loadend", (e)->
      contents = e.target.result
      msg = JSON.parse contents
      switch msg.protocol
        when 'graph' then that.recvGraph msg.command, msg.payload
        when 'network' then that.recvNetwork msg.command, msg.payload
        when 'component' then that.recvComponent msg.command, msg.payload
    reader.readAsText(message.data)

  flush: ->
    for item in @buffer
      @send item.protocol, item.command, item.payload
    @buffer = []

module.exports = WebSocketRuntime
