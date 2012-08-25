assert = require 'assert'

prego = require '../lib/main'


sync = new prego.Sync

tablesDone = sync.doneCallback()
assocsDone = sync.doneCallback()
polyAssocsDone = sync.doneCallback()

prego.enableSqlLog true

prego.setConnectionString("postgres://localhost:5432/prego_test")

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

      s2 = new prego.Sync

      x = new Person { firstName: 'John', lastName: 'Doe' }
      x1 = new Person { firstName: 'Jane', lastName: 'Doe' }

      assert.ok !x.id

      prego.transaction x, (err, t)->
        assert.equal err, null
        x.save()
        t.attach x1
        x1.save()
        t.commit s2.doneCallback()

      s2.wait ->
        assert.ok !!x.id, "SAVE1"
        assert.ok !!x1.id, "SAVE2"

        prego.transaction (err, tr) ->
          assert.equal err, null
          tr.connection.executeRow 'SELECT sum(id) FROM persons', [], (err,res) ->
            assert.equal err, null
            console.log "\n\nSUM!", res.sum
            console.log "\n\n"


        Person.findById x.id, (err, y) ->
          assert.equal y.fullName(), "John Doe"
          tablesDone()

        c = x.comments_create {text: 'Hello comment!'}, ->
          x.comments_all (err,comments) ->
            assert.equal err, null
            assert.equal comments[0].text, 'Hello comment!'
            com = comments[0]
            com.commentable (err, p) ->
              assert.equal err, null
              assert.equal p.fullName(), 'John Doe'
              polyAssocsDone()
          x1.comments_all (err,comments) ->
            assert.equal err, null
            assert.deepEqual comments, []

        x.orders_all (err, data) ->
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
                  assert.equal err, null
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

            prego.db.executeRow 'select count(*) from persons', [], sync.doneCallback (err,data) ->
              assert.equal err, null
              console.log data
              assert.equal data.count, 2

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

