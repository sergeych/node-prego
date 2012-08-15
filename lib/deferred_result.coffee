###

DeferedResult is not used anymore for the sake of effectiveness.
Could be still used to perform things like:

  someOp().success ->...
    .end ...
    .error
DeferredResult could be pipelined to track another DeferredResult or PG e
query events emitter (row, end, error). If deverredResult.mdel is set, it
would also produce .data(cback(modelInstance)) with one model instance at
a time.

Still, it is less effeccitve than plain callbacks
###

exports.DeferredResult = class DeferredResult
  constructor: (emitter) ->
    @rowHandlers = []
    @dataHandlers = []
    @doneHandlers = []
    @errorHandlers = []
    @successHandlers = []
    @pipeEmitter(emitter) if emitter

  row: (cb) ->
    @rowHandlers.push cb
    @

  end: (cb) ->
    @doneHandlers.push cb
    @


  success: (cb) ->
    @successHandlers.push cb
    @

  error: (cb) ->
    @errorHandlers.push cb
    @

  data: (cb) ->
    @dataHandlers.push cb
    @

  fireError: (err) ->
    cb(err) for cb in @errorHandlers

  fireEnd: (result) ->
    cb(result) for cb in @doneHandlers

  fireSuccess: (result) ->
    cb(result) for cb in @successHandlers

  fireRow: (row, result) ->
    cb(row, result) for cb in @rowHandlers
    if @model
      data = new @model().loadRow(row)
      cb(data) for cb in @dataHandlers

  pipeEmitter: (emitter) ->
    emitter.on 'row', (row, result) =>
      @fireRow(row, result)

    errors = false
    emitter.on 'error', (err) =>
      @fireError(err)
      errors = true

    emitter.on 'end', (result) =>
      @fireEnd(result)
      @fireSuccess(result) unless errors

  pipeDeferredResult: (dr) ->
    dr
      .row (row, result) =>
        @fireRow(row, result)
      .success (result) =>
        @fireSuccess(result)
      .end (result) =>
        @fireEnd(result)
      .error (err) =>
        @fireError(err)
