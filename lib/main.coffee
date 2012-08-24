db = require './db'
migr = require './migrations'
table = require './table'

exports.db = db.db

exports.migrate = migr.migrate
exports.rollback = migr.rollback

exports.Table = require('./table').Table
exports.Sync = require('./sync').Sync

exports.setConnectionString = (str) ->
  db.connectionString = str
