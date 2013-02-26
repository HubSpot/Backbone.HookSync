  # ### Backbone.HookSync
  #
  # This file provides a function, `make` for building a new
  # sync function for your Backbone.Model which will call the methods
  # you define.  It is particularily useful for integrating Backbone
  # with the JavaScript API interface of your choice.
  #
  # The basic idea:
  #
  #     class MyAwesomeModel extends Backbone.Model
  #       sync: Backbone.HookSync.make
  #         create: myAwesomeCreator
  #         update: 'create'
  #         delete: 'default'
  #         read: 
  #           do: myAwesomeReader
  #           build: (method, model, options) ->
  #             model.attributes
  # 
  # The file also provides two functions to add a new sync method to
  # your existing classes.
  #
  # `bind` adds the method to an existing class:
  #
  #     class MyAwesomeModel extends Backbone.Model
  #       # Model Dets Here
  #
  #     Backbone.HookSync.bind MyAwesomeModel,
  #       create: newCreator
  #
  #       # Reads, Updates and Deletes will continue to use the
  #       # models sync, or if one is not defined, Backbone.Sync
  #
  # `wrap` returns a new copy of your class with the sync method replaced:
  #
  #     class MyAwesomeModel extends Backbone.Model
  #       # Some Modeling..
  #
  #     MoreAwesomeModel = Backbone.HookSync.wrap MyAwesomeModel,
  #       update: _.noop
  #
  # #### Options
  #
  # All three methods expect an object containing 1-4 of the CRUD methods:
  #
  #  - create
  #  - read
  #  - update
  #  - delete
  #
  # Optionally, a `sync` method which will be used with requests which
  # do not match one of the provided methods (or for methods defined as
  # 'default').
  #
  # Optionally, a `defaults` object which provides defaults to the four
  # CRUD methods.
  #
  # Each of the CRUD method keys can have any of the following values:
  #
  #  - A function (to do the action)
  #  - A string referring to another CRUD method who's value should be used
  #  - 'default', `null`, or `undefined` representing the default sync behavior
  #  - An object
  #
  # If an object is used it can have the following attributes:
  #  - `function do` - The function to be called (make sure you use string notation ["do"] if
  #           you're not writing CoffeeScript)
  #  - `function build(method, model, options)` - A function used to build the request passed
  #           into do.  Defaults to `model.toJSON()`.
  #  - `boolean expandArguments[false]` - Should the array returned by `build` be
  #           expanded and passed into do as seperate arguments?
  #  - `boolean returnsPromise[false]` - Does do return a Deferred object?  If so
  #           it's done and fail methods will trigger the success and error
  #           callbacks (and the default callbacks will be disabled).
  #  - `boolean addOptions[true]` - Should the options hash be merged in with
  #           the return value of build?
  #
  # If you're using expandArguments, addOptions: false is implied.
  # 

  CRUD = ['create', 'read', 'update', 'delete']

  HANDLER_DEFAULTS =
    addOptions: true

  # Returns a copy of the class with sync extended by the handlers.
  wrap = (cls, handlers) ->
    nCls = cls
    nCls:: = _.clone cls::

    bind nCls, handlers

    nCls

  # Mutates an existing class to replace sync with a new sync
  # method powered by the handlers.
  #
  # Preserves a reference to the existing sync, so any method
  # not handled will fall through to the original.
  bind = (cls, handlers) ->
    if cls::sync
      # make knows to look at handlers.sync if the sync method
      # is not bound in the handlers (or is bound as 'default').
      # 
      # If there is no cls::sync (the default case for Backbone), 
      # make will use Backbone.sync.
      handlers.sync ?= cls::sync

    cls::sync = make handlers
    
    cls

  # Build a sync function compatable with Backbone out of one or more
  # CRUD functions.  Anything you don't override will get passed through
  # to the default sync function.
  make = (handlers) ->
    # Handlers is a map of CRUD methods to the functions which should
    # handle them + some other options.

    # Replace all of the string handler pointers with
    # the actual handlers they point to.  Replace 'default'
    # with null
    resolveHandlers handlers

    # Normalize the handler to always be an object with a 
    # make method.
    handlersToObjects handlers

    # `handlers.defaults` can contain default options for
    # all of the handlers
    applyDefaults handlers


    # This is the sync-replacement we'll be returning
    (method, model, options) ->
      handler = handlers[method]

      if handler
        request = buildRequest handler, method, model, options

        makeRequest handler, request, options

      else
        # This method is most likely gonna be overriding the
        # model's sync method, so calling @sync would recurse, so
        # we let the fall-through sync be passed in as an option.
        #
        # `wrap` and `bind` do this for you, automatically preserving the
        # previous sync in handlers.
        (handlers.sync or Backbone.sync) method, model, options

  # In this context, a request is the object which will be passed
  # into the `do` function passed in as a handler.  Based on the
  # `expandArguments` property, it can either be a single object,
  # or an array of arguments.
  #
  # Unless you set handler.addOptions to false, the options object will be
  # automatically merged with the attributes your return.
  # 
  # The build function defaults to `model.toJSON`.
  buildRequest = (handler, method, model, options) ->
    builder = handler.build ? model.toJSON
    
    req = builder method, model, options

    if handler.addOptions and not handler.expandArguments
      req = _.extend {}, options, req

    req
      
  # Do it!
  # 
  # handler.returnsPromise gives you a convenient way to
  # convert a method which normally returns a promise to
  # work with Backbone's success and error handlers.
  # 
  # It will replace the passed-in success and error handlers
  # with noops so they are not called twice.
  makeRequest = (handler, request, options) ->
    if handler.returnsPromise
      oldOptions = _.pick options, 'success', 'error'
      options.success = options.error = ->

    if handler.expandArguments
      resp = handler.do request...
    else
      resp = handler.do request
     
    if handler.returnsPromise
      resp.done (data) ->
        oldOptions.success data

      resp.fail (err) ->
        oldOptions.error err

  # Handler can be passed in as either functions, or
  # objects which have some more options and functions.
  # To make it easier, lets make them objects all of the time.
  #
  # It modifies the passed in object in-place.
  handlersToObjects = (handlers) ->
    for type, handler of handlers when type in CRUD
      if _.isFunction handler
        handlers[type] =
          do: handler

  # Use handlers.defaults as the defaults for all of the other
  # handlers.
  #
  # Modifies the passed-in object in-place.
  applyDefaults = (handlers) ->
    for type, handler of handlers when type in CRUD
      handlers[type] = _.extend {}, HANDLER_DEFAULTS, handlers.defaults, handler

  # Handlers can be string references to the keys of other handlers,
  # or 'default'.
  #
  # Modifies the passed in object in-place.
  resolveHandlers = (handlers) ->
    for type, handler of handlers when type in CRUD
      switch handler
        when 'default'
          # In this context, `default` means pass request through to
          # `handlers.sync` or `Backbone.sync`.
          #
          # For convenience, normalize default to be falsy
          # as we also support simply skipping the handler type to
          # signify 'default'
          handlers[type] = null
        when 'create', 'update', 'read', 'delete'
          # You can alias the handler to another handler.
          #
          # The most common usage of this is to map create to the same thing
          # as update, e.g.:
          #
          #     make
          #       create: myHandler
          #       update: 'create'
          #
          # This is only going to reliably work to one level of depth,
          # you can't reference references.
          handlers[type] = handlers[handler]

  exports = {make, wrap, bind}
  Backbone?.HookSync = exports
