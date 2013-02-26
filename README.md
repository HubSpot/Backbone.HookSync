### Backbone.HookSync

Get the CRUD out of your app.  Define functions for Backbone.Model create, read, update and delete.
 
```coffeescript
    class MyAwesomeModel extends Backbone.Model
      sync: Backbone.HookSync.make
        create: myAwesomeCreator
        
```

### More Details

See the [Annotated Source](http://github.hubspot.com/Backbone.HookSync/docs/sync.html)
