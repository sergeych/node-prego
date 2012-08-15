require './lib/string_utils'
assert = require 'assert'

pluralizeSamples = [
  [ "some_table", "some_tables"]
  [ "bad_axis", 'bad_axes' ]
  [ "octopus", "octopi" ]
  [ "virus", "viri" ]
  [ "viri", "viri" ]
  [ "octopi", "octopi" ]
  [ "buffalo", 'buffaloes' ]
  [ 'autobus', 'autobuses' ]
  [ 'tomato', 'tomatoes' ]
  [ 'auditorium', 'auditoria' ]
  [ 'datum', 'data' ]
  [ 'data', 'data' ]
  [ 'status', 'statuses' ]
  [ 'state', 'states' ]
  [ 'alias', 'aliases' ]
  [ 'basis', 'bases' ]
  [ 'wolf', 'wolves']
  [ 'dwarf', 'dwarves']
  [ 'hive', 'hives']
  [ 'fly', 'flies']
  [ 'boy', 'boys']
  [ 'box', 'boxes' ]
  [ 'boss', 'bosses' ]
  [ 'couch', 'couches']
  [ 'bash', 'bashes']
  [ 'vertex', 'vertices']
  [ 'matrix', 'matrices']
  [ 'index', 'indices']
  [ 'louse', 'lice']
  [ 'mouse', 'mice']
  [ 'mice', 'mice']
  [ 'blouse', 'blouses']
  [ 'ox', 'oxen']
  [ 'oxen', 'oxen']
  [ 'quiz', 'quizzes']
]

for [s, p] in pluralizeSamples
  assert.equal s.pluralize(), p


assert.equal 'theColumnName'.camelToSnakeCase(), 'the_column_name'
assert.equal 'the_column_name'.snakeToCamelCase(), 'theColumnName'
assert.equal 'tiTLe_caSe'.toTitleCase(), 'Title_case'





