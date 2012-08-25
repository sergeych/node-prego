db = require './db'
migr = require './migrations'
table = require './table'

exports.db = db.db
exports.Connection = db.Connection

exports.migrate = migr.migrate
exports.rollback = migr.rollback

exports.transaction = require('./transaction').transaction
exports.Table = require('./table').Table
exports.Sync = require('./sync').Sync

exports.setConnectionString = (str) ->
  db.connectionString = str

exports.enableSqlLog = (show) ->
  db.enableSqlLog show

exports.client = (args...) ->
  db.db.client(args...)

exports.query = (args...) ->
  db.db.query(args...)

exports.execute = (args...) ->
  db.db.execute(args...)

exports.executeRow = (args...) ->
  db.db.executeRow(args...)

exports.executeEach  = (args...) ->
  db.db.executeEach(args...)
