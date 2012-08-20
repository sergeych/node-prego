#
# This test is used to debug internals, no use to run it manually
#
prego = require '../lib/db'
prego.connectionString = "postgres://localhost:5432/prego_test"

class Order extends prego.Table

class Person extends prego.Table
  fullName: ->
    "#{@firstName || ''} #{@lastName || ''}"

#x = new Person({firstName: 'Jane'})

s = new prego.Sync()

#x.save -> s.doneCallback()

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'

Person.fetchColumns s.doneCallback ->
#  console.log 'Gotta cols'


s.wait ->
  process.exit 0