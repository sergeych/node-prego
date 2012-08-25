prego = require '../lib/main'

prego.enableSqlLog true

prego.setConnectionString("postgres://localhost:5432/prego_test")

console.log 'DB!', prego.db

c = new prego.Connection()

prego.transaction c, (err, tr) ->
  console.log 'TRR!!', tr
  tr.close()
