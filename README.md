### Backbone.HookSync

The basic idea:
 
```coffeescript
    class MyAwesomeModel extends Backbone.Model
      sync: Backbone.HookSync.make
        create: myAwesomeCreator
        update: 'create'
        delete: 'default'
        read: 
          do: myAwesomeReader
          build: (method, model, options) ->
            model.attributes
```

### More Details

See the [Annotated Source](./sync.coffee)
