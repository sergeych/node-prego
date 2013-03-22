
exports.Sync = class Sync
  constructor: (done) ->
    @errors = null
    @waitCount = 0
    @finished = false
    @handlers = if done? then [done] else []

  doneCallback: (originalDone) ->
    @waitCount++
    @finished = false
    called = false

    (err, data) =>
      originalDone?(err, data)
      return console.log 'Warning: ignored Sync callback called more than once' if called
      called = true
      (@errors ?= []).push(err) if err
      if --@waitCount == 0
        @finished = true
        @fireDone()

  wait: (done) ->
    @handlers.push done
    @fireDone() if @finished

  fireDone: ->
    @finished = true
    done(@errors) for done in @handlers
    @handlers = []
    @errors = null

  subsync: ->
    d = @doneCallback()
    new Sync (res) ->
      d(res)

