pg = require('pg')
fs = require 'fs'
path = require 'path'
util = require 'util'

require './string_utils'

exports.connectionString = null

exports.sqlLog = sqlLog = null

exports.enableSqlLog = enableLog = (enable) ->
  sqlLog = exports.sqlLog = if enable then (args...) -> console.log('SQL:', args...) else null

statementCounter = 0
statementNames = {}

statementName = (statement) ->
  name = statementNames[statement]
  if !name
    name = "stmt_#{statementCounter++}"
    statementNames[statement] = name


icount = 0

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
        console.log 'Connection string detected:', s
        @connectionString = exports.connectionString = s
      if !exports.connectionString
        throw Error('DB connection string is not found/not set')

    if @_client?
      console.log 'reuse cached client', @_id, @_lockCount
      callback null, @_client
    else
      pg.connect @connectionString, (err, client, connDone) =>
        if err
          console.log 'Unable to get PG client for', exports.connectionString
          console.log ': ', err
          callback err
        else
          @_id = icount++
          @_client = client
          @_done = connDone
          console.log 'Connection created:', @_id
          callback null, client

  free: ->
    if @_lockCount < 1 && @_client
      console.log 'Connection freed', @_id
      @_done()
      @_client = null
      @_lockCount = 0

  lock: ->
    @_lockCount++

  unlock: ->
    if --@_lockCount < 1
      console.log 'unlock FREE', @_id
      @free()
    else
      console.log 'Unlock #', @_id, @_lockCount

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
    sqlLog? @_id, statement
    @lockedClient (err, client) =>
      return callback(err) if err
      client.query statement, (args...) =>
        callback(args...)
        @unlock()

  execute: (query, params, done) ->
    [done, params] = [ params, [] ] if !params
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

exports.db = new Connection()
exports.Connection = Connection
