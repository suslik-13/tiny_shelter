
In general, files in here ought to provide exactly tow functions:
```
    yl_speak_up.input_fs_<FILE_NAME> = function(player, formname, fields)
        -- react to whatever input the player supplied;
        -- usually show another formspec
        return
    end
```
and:
```
    yl_speak_up.get_fs_<FILE_NAME> = function(player, param)
        -- return a formspec string
        return formspec_string
    end
```

The actual displaying of the formspecs and calling of these functions happens
in `show_fs.lua`.

There may be no function for handling input if the formspec only displays
something and only offers a back button or buttons to other formspecs.

Additional (local) helper functions may be included if they are only used
by those two functions above and not used elsewhere in the mod.
That is not a technical requirement but mostly for keeping things clean.
These functions are usually *not* declared as local and may be overridden
from outside if needed.

An exception to the above rule are the functions
```
    yl_speak_up.show_precondition
    yl_speak_up.show_action
    yl_speak_up.show_effect
```
because in those cases it was better for readability and context to have them
in their respective `fs/fs_edit_<precondition|action|effect>.lua` files.
These functions are called in debug mode when excecuting the preconditions,
actions and effects as well.

Another exception is `exec_actions.lua` as the respective `get_fs_*` and
`input_*` functions there are only called when an action is executed and not
via `show_fs.lua` at all.
