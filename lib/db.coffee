pg = require('pg').native
fs = require 'fs'
path = require 'path'

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

class Connection

  constructor: (@connectionString) ->

  clone: ->
    return new @.constructor(@connectionString)

  client: (callback) ->

    return callback(null, @_client) if @_client

    @connectionString ?= exports.connectionString
    unless @connectionString
      # Check config.coffee or config.js
      console.log 'ch1'
      if fs.existsSync('./config.coffee') || fs.existsSync('./config.js')
        console.log 'Loading from config module'
        m = require path.resolve('./config')
        s = m.dbConnection || m.dbConnectionString
        console.log 'Connection string detected:', s
        @connectionString = exports.connectionString = s
      if !exports.connectionString
        throw Error('DB connection string is not found/not set')

    pg.connect @connectionString, (err, client) =>
      if err
        console.log 'Unable to get PG client for', exports.connectionString
        console.log ': ', err
        callback err
      else
        @_client = client
        console.log 'Connection created:', exports.connectionString
        callback null, client

  pauseDrain: ->
    @_client.pauseDrain()

  resumeDrain: ->
    @_client.resumeDrain()

  query: (statement, callback) ->
    sqlLog? statement
    @client (err, client) ->
      return callback(err) if err
      client.query statement, callback

  execute: (query, params, done) ->
    [done, params] = [ params, [] ] if !params
    @client (err, client) ->
      return done?(err) if err
      sqlLog? query, params, done?
      client.query { name: statementName(query), text: query, values: params}, done

  executeEach: (query, params, done) ->
    [done, params] = [ params, [] ] if !params
    @client (err, client) ->
      return done(err) if err
      sqlLog? query, params, done?

      query = client.query { name: statementName(query), text: query, values: params}
      query.on 'row', (row, result) ->
        done null, row
      query.on 'error', (err) ->
        done err
      query.on 'end', (result) ->
        done null, null, result

  executeRow: (query, params, callback) ->
    @execute query, params, (err, rs) ->
      if err
        callback? err
      else
        callback? null, if rs.rowCount == 1 then rs.rows[0] else null

exports.db = new Connection()
exports.Connection = Connection
