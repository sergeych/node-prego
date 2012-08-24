db = require './db'
Table = require('./table').Table
Sync = require('./sync').Sync

exports.Transaction = class Transaction

  constructor: ->
    @sync = new Sync
    @tables = []

  begin: (arg, done) ->
    if arg instanceof Table
      @connection = arg.constructor.getConnection().clone()
      arg.constructor.connection = @connection
      arg._transaction = @
    else
      @connection = arg
      @connection = db.connection.clone() unless @connection instanceof db.Connection

    @open = true
    @connection.query 'BEGIN', @sync.doneCallback (err) =>
      @connection.pauseDrain()
      return done(err) if err
      done null, @

  attach: (table) ->
    table.constructor.connection = @connection
    table._transaction = @

  commit: (done) ->
    @sync.wait =>
      @_commit done

  _commit: (done) ->
    return unless @open
    @open = false
    @failed = false
    @connection.query 'COMMIT', done
    @_cleanup()

  rollback: (done) ->
    @sync.wait =>
      @_rollback done

  _rollback: (done) ->
    return unless @open
    @open = false
    @failed = true
    @connection.query 'ROLLBACK', done
    @_cleanup()


  _cleanup: ->
    t._transaction = null for t in @tables
    @connection.resumeDrain()

  check: (callback) ->
    @sync.doneCallback (err, args...) =>
      if err
        @rollback (err1) =>
          callback err
      else
        callback null, args...

  close: (done) ->
    @sync.wait (errs) =>
      if errs
        @_rollback errs, done
      else
        @_commit errs, done


exports.transaction = (arg, done) ->
  [arg, done] = [null, arg] unless done
  new Transaction().begin(arg, done)



