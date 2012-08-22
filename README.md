Prego postgres access module for Node.js
========================================

*Prego* is currently in a beta stage. Some interfaces may be changed and tests are not yet complete. You can expermient
and use it at your own risk. Prego it is in rapid development being a part of several projects in progress.

Prego is a tiny coffeescript library (usable with javascript too) that simplifies Postgres database access and
manipulation, built for speed in both development and execution, to the extent first condition allows ;)

Main prego features:

* Callback-style, fast and easy

* reversible migrations, plain postgres SQL + any js/coffee code, executed in transactions, convenient to deploy

* DB access helper functions like prego.client(), prego.execute(), prego.executeRow() with automatic SQL statement
  preparation and caching, and pg's connection pool
  Uses 'pg' connection pool

* Models: use prego.Table as base class to get automated loading from SQL or by id, access to attributes as camelCased
  properties `user.lastName`, save only changed attributes, minimal associations (hasMany), easy deletion and so on.

* Callback-style associations and polymorphic associations

* Some utility classes to perform parallel operations, manipulate strings, etc.

Conslult online docs for more: https://github.com/sergeych/prego/wiki

Installation
============

    npm install [-g] prego

Global installation is needed to run `pmigrate` command-line tool.

Configuration
=============

Currently, prego looks for ./config(.js|.coffee), imports it and checks @exports.dbConnectionString@ where should
be connection string suitable for the pg module, such as

    exports.dbConnectionString = "postgres://user:passw@localhost:5432/mydbname"

Config module could do whatever logic you need to calculate suitable connection string, say, depending on the
deployment target, debug mode or whatever you like.

Read more: https://github.com/sergeych/prego/wiki/Installation

Table class
===========

Use it as a base class for your models. The great isea is to have integer (serial for example) 'id' column as primary
key. It may not work very well without it yet. For example:

        prego = require 'prego'

        exports.User = class User extends prego.Table

          fullName: -> "#{@firstName||''} #{@lastName||''}"

        User.findById 1, (err, me) ->
            console.log me.fullName();
            me.accessCounter++
            me.save # only access_counter will be saved here

        User.allFromSql "select * from users where first_name ilike 'Jh%' limit 20", (err, users)
            console.log "5th user from array", users[5].lastName

        #User.eachFromSql "select * from users", (err, user) ->
        # or, better
        User.each (err, user) ->
            if err
                console.log 'Failed:', err
                return
            if user
                console.log 'Gotta user:', user.firstName
            else
                console.log 'No more users'

        u = new User { firstName: 'John', lastName: 'Doe' }

        # it won't be created in the DB until:
        u.save (err) ->
            if !err
                console.log 'New user just created in the db'


This will work if you create 'users' table with 'first_name', 'last_name' and 'id' columns. Say, with a migration.
You can ovveride table name (which defaults to your class name pluralized and snake cased):

        class User extends prego.Table
            @tableName = 'persons'

When using 'fromSql' functions, you can actually get more columns that table has, using joins and so on. You can then
access these as object properties just like table columns, but they won't be saved.


Migrations
==========

ActiveRecord style. You create ./migrations folder in your project, where put migration .js or .coffee files. Migration
file should provide at least exports.up() to perform actual work. It may also provide exports.down() to rollback a
migration. Typical migration should look somewhat like this:

    exports.up = (client, done) ->
      client.query '''
      	create table users(
      		id serial PRIMARY KEY,
      		first_name VARCHAR(128),
      		last_name  VARCHAR(128),
      		created_at TIMESTAMP DEFAULT NOW(),
      		email     VARCHAR,
      		admin	  BOOLEAN default FALSE
      	);

      	CREATE INDEX ix_users_email ON users(email);
      	'''

    exports.down = (db, done) ->
      db.query '''
        DROP TABLE IF EXISTS users;
        '''

Then, in the project root folder, execute

    $ pmigrate

To roll back last migration only, use

    $ pmigrate back

Consult online docs for more: https://github.com/sergeych/prego/wiki/Migrations

Associations
============

You can easily add one-to-many associations to your models:

    class Order extends prego.Table

    class Person extends prego.Table
        @hasMany Order

    person.orders_all (err,orders) ->
        return console.log('Cant get orders',err) if err
        return console.log('there is no orders') if orders.length == 0
        console.log 'First order qty:', orders[0].qty

You can also polymorphic associations as well (AR-style). Polymorphic asociation stores not only target object id,
but also target table name and restores proper model object (under construction).

Please consult online docs: https://github.com/sergeych/prego/wiki

Sync class
==========

Suppose you need some operations to work in parallel, and wait for all them to complete to go further. The probably
easiest way to do it is to ise prego Sync class

    sync = prego.Sync (err) ->
        console.log 'Everything is done', if err then "whith errors: #{errors}" else "with no errors"

    profile.save sync.doneCallback()
    user.save sync.doneCallback()

    orders = []
    # Not that Sync allow you to chain additional callback to its:
    Order.all sync.doneCallback (err, data) ->
        orders = data

    ready = sync.doneCallback()

    # ... some event
        ready()

    sync.wait ->
        # This one will be called too, when orders are all loaded, and user and profile, and some event happened
        # both saved.

Sync works well if you attach wait callback (sync.wait ->) after it is completed, the callback will be called
immediately.

If you want to reuse sync, be sure to reattach sync.wait callbacks and issue new sync.doneCallback().

If some doneCallback() will be called twice, it's second invocation will issue warning message in the log and
will not be counted.

And yes, I'm aware of the async module and many others. It's just the fast and convenient way I prefer such things
to happen.

String utilities
================

Ones used to convert column and table names.

        "snake_case_name".snakeToCamelCase() == 'snakeCaseName'

        "camelCaseSample".camelToSnakeCase() == 'camel_case_sample'

        'tiTLecaSe".toTitleCase() == 'Titlecase'

        'wolf'.pluralize() == 'wolves'

pluralize() works more or less fine hopefully with most regular forms of English words only, but it is rather fast
than correct and, though good enough for table names, is not too practical for any other usage. Still I'll improve it a
bit. By any chance it is not intended to cope with other languages or be correct for any word. It's built for speed.
