pg = require('pg').native
require './string_utils'
exports.Sync = require('./sync').Sync

exports.connectionString = null

sqlLog = null

statementCounter = 0
statementNames = {}

statementName = (statement) ->
  name = statementNames[statement]
  if !name
    name = "stmt_#{statementCounter++}"
    statementNames[statement] = name

client = exports.client = (callback) ->

  exports.connectionString ?= loadDbConfiguration()

  throw Error('DB connection string is not set') if !exports.connectionString
  pg.connect exports.connectionString, (err, client) ->
    if err
      console.log 'Unable to get PG client for', exports.connectionString
      console.log ': ', err
      callback err
    else
      callback null, client

query = exports.query = (statement, callback) ->
  sqlLog? statement
  client (err, client) ->
    return callback(err) if err
    client.query statement, callback

execute = exports.execute = (query, params, done) ->
  [done, params] = [ params, [] ] if !params
  client (err, client) ->
    return done?(err) if err
    sqlLog? query, params, done?
    client.query { name: statementName(query), text: query, values: params}, done

executeEach = exports.executeEach = (query, params, done) ->
  [done, params] = [ params, [] ] if !params
  client (err, client) ->
    return done(err) if err
    sqlLog? query, params, done?

    query = client.query { name: statementName(query), text: query, values: params}
    query.on 'row', (row, result) ->
      done null, row
    query.on 'error', (err) ->
      done err
    query.on 'end', (result) ->
      done null, null, result

executeRow = exports.executeRow = (query, params, callback) ->
  execute query, params, (err, rs) ->
    if err
      callback? err
    else
      callback? null, if rs.rowCount == 1 then rs.rows[0] else null


# ----------------------------------------------- Table class

exports.Table = class Table

  @getTableName = ->
    if !@tableName
      @tableName = @name.pluralize().camelToSnakeCase();
    @tableName

  @fetchColumns = (done) ->
    if @columns
      done null, @columns
    else
      query "select column_name, data_type from information_schema.columns where table_name='#{@getTableName()}'", (err, rs) =>
        return done(err) if err
        @columns = {}
        @columns[m.column_name] = m.data_type for m in rs.rows
        done null, @columns

  @all = (done) ->
    @allFromSql "SELECT * FROM #{@getTableName()}", done

  @each = (done) ->
    @eachFromSql "SELECT * FROM #{@getTableName()}", done

  @allFromSql = (statement, values, done) ->
    [done, values] = [values, []] unless done?
    execute statement, values, (err, rs) =>
      if err
        done err
      else
        done null, (new @().loadRow(r) for r in rs.rows)

  @eachFromSql = (statement, values, done) ->
    [values, done] = [ [], values] if !done
    query = executeEach statement, values, (err, row) =>
      return done(err) if err
      done null, if row then new @().loadRow(row) else null

  @findById = (id, done) ->
    @_findByIdClause ?= "SELECT #{@getTableName()}.* FROM #{@getTableName()} WHERE id=$1 LIMIT 1"
    executeRow @_findByIdClause, [id], (err, row) =>
      if err
        done err, null
      else
        done null, if row then new @().loadRow(row) else null

  @findBySql = (statement, values, done) ->
    [done, values] = [values, []] unless done?
    statement += ' limit 1' if !statement.match /LIMIT 1/i
    executeRow statement, values, (err, row) =>
      return done err if err
      done null, if row then new @(row) else null


  constructor: (attributes) ->
    @[key] = value for key, value of attributes
    @_loaded = {}

  loadRow: (attrs) ->
    # loaded are always in db case (snake), object attributes are in snakeCase
    @_loaded = attrs
    for key, value of attrs
      @[key.snakeToCamelCase()] = value
    @

  delete: (done) ->
    throw Error("Can't delete record that is not saved/has no id") if !@id
    execute "DELETE FROM #{@constructor.tableName} WHERE id=$1", [@id], done

  ## Changes: caluclate db field that has been changed
  #
  changes: (done) ->
    changes = {}
    count = 0

    @constructor.fetchColumns (err, cols) =>
      return done(err) if err

      # It should be object field that match columns and differs from loaded
      for key, value of @ when @hasOwnProperty(key)
        # loaded are in db case (snake)
        dbKey = key.camelToSnakeCase()
        lastValue = @_loaded[dbKey]
        if cols[dbKey] && (lastValue == undefined || lastValue != value)
          changes[dbKey] = [lastValue, value]
          count++
      done null, if count > 0 then changes else null

  save: (done) ->
    @changes (err, changes) =>
      return done?(err) if err
      return done?(null,null) if !changes
      sqlLog? changes
      console.log 1
      values = []
      parts = []
      cnt = 1
      if @id
        for key, value of changes
          parts.push "#{key}=$#{cnt++}"
          values.push value[1]
        values.push @id
        clause = "UPDATE #{@constructor.tableName} SET #{parts.join ' '} WHERE id=$#{cnt}"
        executeRow clause, values, done
      else
        loaded = {}
        for key, value of changes
          parts.push key
          values.push value[1]
          loaded[key] = value
        clause = "INSERT INTO #{@constructor.tableName}(#{parts.join ','}) values(#{ ("$#{n}" for n in [1..parts.length]) }) RETURNING id"
        executeRow clause, values, (err, row) =>
          unless err
            @id = loaded.id = row.id
            @_loaded = loaded
          done? err, @


exports.enableSqlLog = (enable) ->
  sqlLog = if enable then (args...) -> console.log 'SQL:', args... else null


# ------------------------------------------------- Configuration
fs = require 'fs'
path = require 'path'

loadDbConfiguration = ->
  # Check config.coffee or config.js
  if fs.existsSync('./config.coffee') || fs.existsSync('./config.js')
    console.log 'Loading from config module'
    m = require path.resolve('./config')
    s = m.dbConnection || m.dbConnectionString
    console.log 'Connection string:', s
    return s
  console.log 'Existing methods can not detect PG DB connection string'
  null


