db = require './db'

exports.Table = class Table
  @getTableName = ->
    if !@tableName
      @tableName = @name.pluralize().camelToSnakeCase();
    @tableName
    
  @getConnection = ->
    if !@connection
      @connection = db.db
    @connection

  @fetchColumns = (done) ->
    if @columns
      console.log 'rdy'
      done null, @columns
    else
      if @waitColumns
        @waitColumns.push done
        return
      @waitColumns = [done]
      @getConnection().query "select column_name, data_type from information_schema.columns where table_name='#{@getTableName()}'", (err, rs) =>
        return done(err) if err
        @columns = {}
        @columns[m.column_name] = m.data_type for m in rs.rows
        [d null, @columns for d in @waitColumns]
        @waitColumns = undefined

  @all = (done) ->
    @allFromSql "SELECT * FROM #{@getTableName()}", done

  @each = (done) ->
    @eachFromSql "SELECT * FROM #{@getTableName()}", done

  @allFromSql = (statement, values, done) ->
    [done, values] = [values, []] unless done?
    statement = "SELECT * FROM #{@getTableName()} WHERE #{statement}" unless statement.match /^select/i
    @getConnection().execute statement, values, (err, rs) =>
      if err
        done err
      else
        done null, (new @().loadRow(r) for r in rs.rows)

  @eachFromSql = (statement, values, done) ->
    [values, done] = [ [], values] if !done
    statement = "SELECT * FROM #{@getTableName()} WHERE #{statement}" unless statement.match /^select/i
    query = @getConnection().executeEach statement, values, (err, row) =>
      return done(err) if err
      done null, if row then new @().loadRow(row) else null

  @findById = (id, done) ->
    @_findByIdClause ?= "SELECT #{@getTableName()}.* FROM #{@getTableName()} WHERE id=$1 LIMIT 1"
    @getConnection().executeRow @_findByIdClause, [id], (err, row) =>
      if err
        done err, null
      else
        done null, if row then new @().loadRow(row) else null

  @findBySql = (statement, values, done) ->
    [done, values] = [values, []] unless done?
    statement = "SELECT * FROM #{@getTableName()} WHERE #{statement}" unless statement.match /^select/i
    statement += ' limit 1' if !statement.match /LIMIT 1/i
    @getConnection().executeRow statement, values, (err, row) =>
      return done err if err
      done null, if row then new @().loadRow(row) else null

  @deleteAll = (done) ->
    @getConnection().executeRow "DELETE FROM #{@getTableName()}", [], done

  @hasMany = (model, params) ->
    poly = params?.as
    foreignField = (params?.foreignKey || (@name + "Id")).toLowerCamelCase()
    foreignKey = foreignField.camelToSnakeCase()
    if poly
      polyId = "#{poly}_id"
      polyType = "#{poly}_type"
      baseSql = "SELECT x.* FROM #{model.getTableName()} x WHERE #{polyId} = $1 AND x.#{polyType}='#{@getTableName()}'"
      polyId = polyId.snakeToCamelCase()
      polyType = polyType.snakeToCamelCase()
    else
      baseSql = "SELECT x.* FROM #{model.getTableName()} x WHERE #{foreignKey} = $1"

    modelTable = model.getTableName()

    @::[modelTable + '_all'] = (params, done) ->
      [params, done] = [ {}, params ] if !done
      sql = baseSql
      sql += " AND #{params.where}" if params.where
      vals = params.values || []
      vals.unshift @id
      model.allFromSql sql, vals, done

    @::[modelTable + '_each'] = (params, done) ->
      [params, done] = [ {}, params ] if !done
      sql = baseSql
      sql += " AND #{params.where}" if params.where
      vals = params.values || []
      vals.unshift @id
      model.eachFromSql sql, vals, done

    @::[modelTable + '_build'] = build = (params) ->
      if poly
        params[polyId] = @id
        params[polyType] = @constructor.getTableName()
      else
        params[foreignKey] = @id
      new model(params)

    @::[modelTable + '_create'] = (params, done) ->
      build.call(@,params).save(done)

    if poly
      model._knownTypes ||= {}
      model._knownTypes[@getTableName()] = @
      model::[poly] = (done) ->
        obj = @constructor._knownTypes[@[polyType]]
        obj.findById @[polyId], done
    else
      owner = @
      model::[@name.toLowerCamelCase()] = (done) ->
        owner.findById @[foreignField], done

  loaded: ->
    @_loaded || {}

  constructor: (attributes) ->
    @[key] = value for key, value of attributes

  loadRow: (attrs) ->
    # loaded are always in db case (snake), object attributes are in snakeCase
    @_loaded = attrs
    for key, value of attrs
      @[key.snakeToCamelCase()] = value
    @

  delete: (done) ->
    throw Error("Can't delete record that is not saved/has no id") if !@id
    @constructor.getConnection().execute "DELETE FROM #{@constructor.tableName} WHERE id=$1", [@id], done

  ## Changes: caluclate db field that has been changed
  #
  changes: (done) ->
    changes = {}
    count = 0

    @constructor.fetchColumns (err, cols) =>
      return done(err) if err

      # It should be object field that match columns and differs from loaded
      for key, value of @ when @hasOwnProperty(key)
        # loaded are in db case (snake)
        dbKey = key.camelToSnakeCase()
        lastValue = @loaded()[dbKey]
        if cols[dbKey] && (lastValue == undefined || lastValue != value)
          changes[dbKey] = [lastValue, value]
          count++
      done null, if count > 0 then changes else null

  save: (_done) ->
    if @_transaction
      conn = @_transaction.connection
      done = @_transaction.check(_done)
    else
      conn = @constructor.getConnection()
      done = _done

    @changes (err, changes) =>
      return done?(err) if err
      return done?(null,null) if !changes
      values = []
      parts = []
      cnt = 1
      if @id
        for key, value of changes
          parts.push "#{key}=$#{cnt++}"
          values.push value[1]
        values.push @id
        clause = "UPDATE #{@constructor.tableName} SET #{parts.join ' '} WHERE id=$#{cnt}"
        conn.executeRow clause, values, done
      else
        loaded = {}
        for key, value of changes
          parts.push key
          values.push value[1]
          loaded[key] = value
        clause = "INSERT INTO #{@constructor.tableName}(#{parts.join ','}) values(#{ ("$#{n}" for n in [1..parts.length]) }) RETURNING id"
        conn.executeRow clause, values, (err, row) =>
          unless err
            @id = loaded.id = row.id
            @_loaded = loaded
          done? err, @

