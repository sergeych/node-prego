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

  create table comments(
    id serial primary key,
    commentable_id integer not null,
    commentable_type varchar(64),
    text TEXT
  );

  create index ix_comments on comments(commentable_id, commentable_type);
'''

exports.up = (client, done) ->
  client.query createSql, done

exports.down = (client, done) ->
  client.query "drop table if exists comments; drop table orders; drop table persons;", done

