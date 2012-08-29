Set = require('../lib/set').Set
assert = require 'assert'

a = new Set [1,2,3]
b = new Set [3,4,'cool']

assert.ok a.has(3)
assert.ok !a.has 'cool'
assert.ok b.has 'cool'
assert.ok !b.has(2)

assert.ok (a.or b).isEqual([1,2,3,4,'cool'])
assert.ok (a.or b).isEqual(new Set [1,2,3,4,'cool'])

assert.deepEqual a.and(b).list, [3]

assert.ok a.xor(b).isEqual([1,2,4,'cool'])

assert.ok !a.hasAll([2,3,4])
assert.ok a.hasAny([2,3,4])
assert.ok a.hasAll([2,3,1])
assert.ok !a.hasAny([233,443,54])

sw = (fn, name) ->
  x = new Date().getTime()
  fn()
  console.log Math.floor(new Date().getTime() - x), name


a = []
b = new Set

sw ->
  for x in [0..600000]
    a.push x

sw ->
  for x in [0..600000]
    b.add x

ca = 0
cb = 0

sw ->
  for x in [0..60]
    ca++ if x in a
    ca++ if 75000*x in a

sw ->
  for x in [0..60]
    cb++ if b.has x
    cb++ if b.has 75000*x

assert.equal ca, cb
