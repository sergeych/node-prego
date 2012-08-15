createSql = '''
  create table persons(
    id serial primary key,
    created_at timestamp default now(),
    first_name varchar,
    last_name varchar
  );

  create table orders(
    id serial primary key,
    person_id integer not null references persons on delete cascade,
    name varchar,
    qty integer);
'''


exports.up = (client, done) ->
  client.query createSql, done

exports.down = (client, done) ->
  client.query "drop table orders; drop table persons;", done

