#
# Rails-like 2 way migrations. Use CLI 'pmigrate {upd|down}' to perform all pending migrations
# or roll back most recent
#
db = new require('./db').db
fs = require 'fs'
path = require 'path'


exports.migrate = (migrationsPath, done) ->
  migrationsPath = path.resolve migrationsPath

  # Check what migrations are done and what ones are not

  # Ensure there is a migrations table and get a list of existing migrations
  db.execute 'SELECT * FROM _migrations order by created_at', [], (err, rs) ->
    if err
      console.log 'There is no migrations table, creating'
      db.query 'create table _migrations(file_name VARCHAR PRIMARY KEY,created_at TIMESTAMP DEFAULT NOW());
                                        create index ix__migrations_time on _migrations(created_at)', (err) ->
        if err
          console.log "Can't create migrations table:", err
          process.exit 100
        else
          checkMigrations migrationsPath, [], done
    else
      checkMigrations migrationsPath, rs.rows, done


exports.rollback = (mpath, done) ->
  mpath = path.resolve mpath
  db.executeRow 'SELECT file_name FROM _migrations order by created_at desc limit 1', [], (err, row) ->
    name = row?.file_name
    if name
      console.log 'Request to rollback', name
    else
      console.log 'Nothing to rollback'
      return done null
    db.client (err, client) ->
      return done(err) if err
      fullPath = "#{mpath}/#{name}"
      migr = require fullPath
      client.query 'BEGIN', (err) ->
        return done(err) if err
        migr.down client, (err) ->
          if err
            client.query 'ROLLBACK', ->
              console.log 'Failed to rollback a migration'
              return done(err)
          else
            db.execute 'DELETE FROM _migrations WHERE file_name = $1', [name], ->
              client.query 'COMMIT', ->
                console.log 'rolled back'
                done null


checkMigrations = (migrationsPath, list, done) ->
  migrate = (client)->
    name = todo.shift()

    if !name
      console.log 'Migrations passed'
      done null
      return

    console.log 'Migrating', name

    fullPath = "#{migrationsPath}/#{name}"
    migr = require fullPath

    client.query 'BEGIN', (err) ->
      return done(err) if err
      migr.up client, (err, rs) ->
        if err
          console.log 'migration fault:', err
          client.query 'ROLLBACK', -> done err
          return
        else
          client.query 'insert into _migrations(file_name) values($1)', [name], (err) ->
            return done err if err
            client.query 'COMMIT', (err) ->
              return done(err) if err
              migrate(client)

  ready = {}
  ready[r.file_name] = 1 for r in list

  files = []
  for name in fs.readdirSync(migrationsPath)
    if m = name.match /.*\.(js|coffee)$/
      files.push m[0]

  todo = (f for f in files when !ready[f]).sort()
  if todo.length == 0
    console.log 'Nothing to do'
    return done null

  db.client (err, client) ->
    if err
      console.log 'Failed to get db client:', err
    else
      migrate(client)


#console.log args
#console.log __dirname


