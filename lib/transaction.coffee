db = require './db'
Table = require('./table').Table
Sync = require('./sync').Sync

class Transaction

  constructor: ->
    @sync = new Sync
    @tables = []
    @open = false

  begin: (arg, done) ->
    @open = true
    if arg instanceof Table
#      console.log 'Transaction for table!'
      @connection = arg.constructor.getConnection().clone()
      arg.constructor.connection = @connection
      arg._transaction = @
    else if arg instanceof db.Connection
#      console.log 'Transaction for connection!'
      @connection = arg
    else if arg?
#      console.log 'Transaction for connstr'
      @connection = new db.Connection(arg)
    else
#      console.log 'Cloning default'
      @connection = db.db.clone()

    @open = true
    @connection.lock()
    @connection.query 'BEGIN', @sync.doneCallback (err) =>
      return done(err) if err
      done null, @

  attach: (table) ->
    throw Error('transaction is closed/not started') unless @open
    table.constructor.connection = @connection
    table._transaction = @

  commit: (done) ->
    @sync.wait =>
      @_commit done

  _commit: (done) ->
    return unless @open
    @failed = false
    @connection.query 'COMMIT', done
    @_cleanup()

  rollback: (done) ->
    @sync.wait =>
      @_rollback done

  _rollback: (done) ->
    return unless @open
    @failed = true
    @connection.query 'ROLLBACK', =>
      @_cleanup()
      done?()


  _cleanup: ->
    @open = false
    t._transaction = null for t in @tables
    @connection.unlock()

  check: (callback) ->
    @sync.doneCallback (err, args...) =>
      if err
        @rollback (err1) =>
          callback? err
      else
        callback? null, args...

  close: (done) ->
    @sync.wait (errs) =>
      if errs
        @_rollback errs, done
      else
        @_commit errs, done
      done errs


exports.transaction = (arg, done) ->
  [arg, done] = [null, arg] unless done
  new Transaction().begin(arg, done)



