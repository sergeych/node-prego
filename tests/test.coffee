assert = require 'assert'

require './strings.coffee'

prego = require '../lib/db'

prego.connectionString = "postgres://localhost:5432/prego_test"

sync = new prego.Sync()

tablesDone = sync.doneCallback()
assocsDone = sync.doneCallback()

prego.rollback './tests/migrations', ->
  prego.migrate './tests/migrations', ->

    class Order extends prego.Table

    class Person extends prego.Table
      fullName: ->
        "#{@firstName || ''} #{@lastName || ''}"

      orders = @hasMany(Order)

    Person.deleteAll sync.doneCallback ->
      console.log '2'

      x = new Person { firstName: 'John', lastName: 'Doe' }
      assert.ok !x.id
      console.log '3'

      x.save ->
        console.log 4
        assert.ok !!x.id
        Person.findById x.id, (err,y) ->
          assert.equal y.fullName(), "John Doe"
          tablesDone()

        x.orders.all {}, (err, data) ->
          assert.equal data.length, 0
          new Order({name: 'things', qty: 1,person_id: x.id}).save (err) ->
            assert.ok !err
            x.orders.all {}, (err, data) ->
              assert.equal data.length, 1
              o = data[0]
              assert.equal o.name, 'things'
              assert.equal o.qty, 1
              o.person (err,p) ->
                if err
                  console.log 'ERR:', err
                  assert.ok !err
                assert.equal p.fullName(), 'John Doe'
                assocsDone()




sync.wait ->
  console.log 'All tests are passed'
  process.exit 0

