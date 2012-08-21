assert = require 'assert'

require './strings.coffee'

prego = require '../lib/db'

prego.connectionString = "postgres://localhost:5432/prego_test"

sync = new prego.Sync

tablesDone = sync.doneCallback()
assocsDone = sync.doneCallback()
polyAssocsDone = sync.doneCallback()

prego.rollback './tests/migrations', ->
  prego.migrate './tests/migrations', ->

    class Comment extends prego.Table

    class Order extends prego.Table

    class Person extends prego.Table
      fullName: ->
        "#{@firstName || ''} #{@lastName || ''}"

      @hasMany(Order)

      @hasMany Comment, {as: 'commentable'}

    Person.deleteAll sync.doneCallback (err) ->
      console.log 'ERR/D', err
      console.log '2'

      s2 = new prego.Sync

      x = new Person { firstName: 'John', lastName: 'Doe' }
      x1 = new Person { firstName: 'Jane', lastName: 'Doe' }

      assert.ok !x.id
      console.log '3'

      x.save s2.doneCallback()
      x1.save s2.doneCallback()

      s2.wait ->
        console.log 4
        assert.ok !!x.id
        assert.ok !!x1.id
        Person.findById x.id, (err, y) ->
          assert.equal y.fullName(), "John Doe"
          tablesDone()

        c = x.comments_create {text: 'Hello comment!'}, ->
          x.comments_all (err,comments) ->
            assert.equal err, null
            assert.equal comments[0].text, 'Hello comment!'
            com = comments[0]
            com.person (err, p) ->
              assert.equal err, null
              assert.equal p.fullName(), 'John Doe'
              polyAssocsDone()
          x1.comments_all (err,comments) ->
            assert.equal err, null
            assert.deepEqual comments, []

        x.orders_all (err, data) ->
          console.log 'E', err, 'D', data
          assert.equal data.length, 0
          new Order({name: 'things', qty: 1,personId: x.id}).save (err) ->
            assert.equal err, null

            x.orders_all (err, data) ->
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

            x1.orders_all (err, comments) ->
              assert.equal err, null
              assert.equal comments.length, 0

            x.orders_all { where: 'qty > $2', values: [10] }, sync.doneCallback (err, ary) ->
              assert.equal err, null
              assert.equal 0, ary.length
              console.log 'All/Query 1 passed'

            x.orders_all { where: 'qty > $2', values: [0] }, sync.doneCallback (err, ary) ->
              assert.equal err, null
              assert.equal 1, ary.length
              console.log 'All/Query 2 passed'

            doneEach = sync.doneCallback()
            data = []
            x.orders_each (err, x) ->
              assert.equal err, null
              if x
                data.push x
                assert.equal x.qty, 1
                assert.equal x.name, 'things'
              else
                assert.equal data.length, 1
                console.log 'Each passed'
                doneEach()






sync.wait ->
  console.log 'All tests are passed'
  process.exit 0

