exports.Set = class Set

  constructor: (data) ->
    @clear()
    @addAll(data) if data

  clear: ->
    @list = []
    @set = {}
    @length = 0

  ## create a deep copy of a set
  clone: ->
    s = new Set(@list)

  ## Add all elements from an array or a set
  addAll: (data) ->
    @add x for x in data

  add: (x) ->
    unless @set[x]
      @set[x] = @list.length
      @list.push x
      @length = @list.length

  push: (x) ->
    @add x

  remove: (x) ->
    if (i=@set[x])
      list.splice i, 1
      delete @set[x]
      @length = @list.length

  ## Remove all elements from an array or a set
  removeAll: (data) ->
    @remove x for x in data

  toArray: -> @list[..]

  has: (x) -> @set[x]?

  hasAll: (data) ->
    data = data.list if data instanceof Set
    return false for d in data when !@has(d)
    true

  hasAny: (data) ->
      data = data.list if data instanceof Set
      return true for d in data when @has(d)
      false

  and: (set2) ->
    res = new Set
    [a, b] = if @length < set2.length then [@,set2] else [set2, @]
    res.add(x) for x in a.list when b.has(x)
    res

  intersection: (data)  ->
    @and(data)

  or: (set2) ->
    res = @clone()
    res.add x for x in set2.list
    res

  xor: (set2) ->
    res = new Set
    for x in @list
      res.add x unless set2.has(x)
    for x in set2.list
      res.add x unless @has(x)
    res

  isEqual: (collection) ->
    return false if collection.length != @length
    collection = collection.list if collection instanceof Set
    return false for x in collection when ! @has(x)
    true
