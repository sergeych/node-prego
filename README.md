Prego postgres access module
============================

*ATTENTION*

Prego is under early development. It is published only to extend testing base, it is not yet ready
for any usage. I'm going to extend the interfaces a long way and may very likely change a bit existing ones.
And for the same reason there is yet no doces.

Prego is a tiny coffeescript library to simplify Postgres database access and manipulation, built for speed in both
development and execution, to the extent that first condition allow to meet the second ;)

Main prego features:

* Callback-style, fast and easy

* reversible migrations, in plain postgres SQL (well any js/coffee code could be added, too), executed in transactions
  and reversible if 'down' routine exists.

* DB access functions like prego.client(), prego.execute(), prego.executeRow() with automatic SQL statement preparation.
  Uses 'pg' connection pool

* prego.query to execute multiline parameterless queries without statement preparing. Uses same connection pool.

* Table base class that simplifies basic operation to access tables, like obtaining from SQL or by id (you should
  provide field to each table you want to use this feature), track and save changes, convert snake_case column names
  in db to table.camelCase in objects, load series of rows converting to a Model class (that inherits from Table)
  automatically, either all the returning row or row-by-row in a callback.

* Some utility classes to perform parallel operations and manipulate strings, etc.

Configuration
=============

Currently, prego looks for ./config(.js|.coffee), imports it and looks for @exports.dbConnectionString@ where should
be a suitable for pg module connection string, such as

    exports.dbConnectionString = "postgres://user:passw@localhost:5432/mydbname"

Config module could do whatever logic you need to caluclate suitable connection string, say, depending on the
deployment target, debug mode or whatever you like.


Table class
===========

Use it as a base class for your models. Have 'id' column as serial primary key. It may not work very well wiythout it
yet, but I'll fix it later. For example:

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
            @tableName = persons

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

This form attempts to perform all pending migrations and will stop at first error or when there is nothing left to
migrate (exit status code is 0 only if everything os fine and there is nothing to do). Each migration works in
separate transaction that commits on success.

To roll back last migrations, use

    $ pmigrate back

It will attempt to rollback last migration only. If you need more to revert, call it once again until happy or there
will be no migrations left.

Migrations are stored in the _migrations table that would be created automatically. Do not change it. Programming
interface is on the way so it would be possible to check and pass migration in the server startup code, for
example.

Migration file names
--------------------

Names should be formatted in any way that makest older migration file name be comparable and always smaller in the
string comparison context than newer migrations. You can easily achieve it using createion date-time or serial
number as a prefix file name:

    0001_initial_tables.coffee
    0002_add_some_mode_indexes.coffee

or

    20120501T180001_creating_tables.coffee
    20120517T221010_add_customers_table.coffee

Second form is more appropriate. Note that forst form actually limit your project to 10000 migrations as lexical
comparison may and will give wrong results when 4-digit numbers will be overflowed. Of course you can optimistically
evade it using 000000000_initial_migration pattern ;)

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
