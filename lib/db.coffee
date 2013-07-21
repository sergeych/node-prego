pg = require('pg')
fs = require 'fs'
path = require 'path'
util = require 'util'

require './string_utils'

exports.connectionString = null

exports.sqlLog = sqlLog = null

exports.enableSqlLog = enableLog = (enable) ->
  sqlLog = exports.sqlLog = if enable then (args...) -> console.log('SQL:', args...) else null


# Trace debug stuff for this only module
#dtrace = console.log
dtrace = null
    
statementCounter = 0
statementNames = {}

statementName = (statement) ->
  name = statementNames[statement]
  if !name
    name = "stmt_#{statementCounter++}"
    statementNames[statement] = name


icount = 0
activeClients = {}
closedClientsCount = 0


class Connection

  constructor: (@connectionString) ->
    @_lockCount = 0

  clone: ->
    return new @.constructor(@connectionString)

  client: (callback) ->

    @connectionString ?= exports.connectionString
    unless @connectionString
      # Check config.coffee or config.js
      if fs.existsSync('./config.coffee') || fs.existsSync('./config.js')
        m = require path.resolve('./config')
        s = m.dbConnection || m.dbConnectionString
        dtrace? 'Connection string detected:', s
        @connectionString = exports.connectionString = s
      else if process.env.DB_URL
        @connectionString = exports.connectionString = process.env.DB_URL
      if !exports.connectionString
        throw Error('DB connection string is not found/not set')

    if @_client?
      dtrace? 'reuse cached client', @_id, @_lockCount
      callback null, @_client
    else
      pg.connect @connectionString, (err, client, connDone) =>
        if err
          dtrace? 'Unable to get PG client for', exports.connectionString
          dtrace? ': ', err
          callback err
        else
          @_id = icount++
          activeClients[@_id]=1
          @_client = client
          @_done = connDone
          dtrace? 'Connection created:', @_id
          callback null, client

  free: ->
    if @_lockCount < 1 && @_client
      dtrace? 'Connection freed', @_id
      @_done()
      @_client = null
      @_lockCount = 0
      delete activeClients[@_id]

  lock: ->
    dtrace? 'Lock:', @_id, @_lockCount
    @_lockCount++
    @

  unlock: ->
    if --@_lockCount < 1
      dtrace? 'unlock FREE', @_id
      @free()
    else
      dtrace? 'Unlock #', @_id, @_lockCount
    @

  lockedClient: (cb) ->
    @client (err, cl) =>
      @lock() unless err
      cb(err, cl)


  pauseDrain: ->
    console.warn "prego.Connection.pauseDrain is deprecated, use lock/unlock unstead"
    @lock()

  resumeDrain: ->
    console.warn "prego.Connection.resumeDrain is deprecated, use lock/unlock unstead"
    @unlock()

  query: (statement, callback) ->
    @lockedClient (err, client) =>
      sqlLog? @_id, statement
      return callback(err) if err
      client.query statement, (args...) =>
        callback(args...)
        @unlock()

  execute: (query, params, done) ->
    [done, params] = [ params, [] ] if !done
    @lockedClient (err, client) =>
      return done?(err) if err
      sqlLog? @_id, query, params, done?
      client.query { name: statementName(query), text: query, values: params}, (args...) =>
        done(args...)
        @unlock()

  executeEach: (query, params, done) ->
    [done, params] = [ params, [] ] if !params
    @lockedClient (err, client) =>
      return done(err) if err
      sqlLog? @_id, query, params, done?

      query = client.query { name: statementName(query), text: query, values: params}
      query.on 'row', (row, result) ->
        done null, row
      query.on 'error', (err) ->
        done err
        @unlock()
      query.on 'end', (result) =>
        done null, null, result
        @unlock()

  executeRow: (query, params, callback) ->
    @execute query, params, (err, rs) ->
      if err
        callback? err
      else
        callback? null, if rs.rowCount == 1 then rs.rows[0] else null

  @printStats = ->
    console.log 'In use:', activeClients
    console.log 'Closed:', closedClientsCount

  @clientsInUse = ->
    count = 0
    count++ for _,_ of activeClients
    count

exports.db = new Connection()
exports.Connection = Connection
