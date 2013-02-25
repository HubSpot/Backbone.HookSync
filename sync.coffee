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
    #

    # Normalize the handler to always be an object with a 
    # make method.
    handlersToObjects handlers

    # Replace all of the string handler pointers with
    # the actual handlers they point to.  Replace 'default'
    # with null
    resolveHandlers handlers

    # This is the sync-replacement we'll be returning
    (method, model, options) ->
      handler = handlers[method]

      if handler
        # The handler can optionally include a build method
        # which is used to construct the request.
        request = buildRequest handler

        makeRequest handler, request

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
  buildRequest = (handler) ->
    if handler.build?
      handler.build method, model, options
    else
      options
      
  # Do it!
  makeRequest = (handler, request) ->
    # Adding `expandArguments` to your handler will let make
    # know that you intend to pass an array of arguments to do,
    # rather than a single object.
    if handler.expandArguments
      handler.do request...
    else
      handler.do request
      
  # Handler can be passed in as either functions, or
  # objects which have some more options and functions.
  # To make it easier, lets make them objects all of the time.
  #
  # It modifies the passed in object in-place.
  #
  # The conical shape of this function is critical to its
  # success.
  handlersToObjects = (handlers) ->
    for type, handler of handlers
      if _.isFunction handler
        handlers[handler] =
          do: handler

  # Handlers can be string references to the keys of other handlers,
  # or 'default'.
  #
  # Modifies the passed in object in-place.
  resolveHandlers = (handlers) ->
    for type, handler of handlers
      switch handler
        when 'default'
          # In this context, `default` means pass request through to
          # `handlers.sync` or `Backbone.sync`.
          #
          # For convenience, normalize default to be falsy
          # as we also support simply skipping the handler type to
          # signify 'default'
          handlers[type] = null
        when 'create', 'read', 'update', 'delete'
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
