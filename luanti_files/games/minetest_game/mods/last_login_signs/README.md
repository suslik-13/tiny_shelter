# last_login_signs Luanti mod

This mod adds signs that show the last login of players that right-clicked them.

## API

### Registering a sign

Use `last_login_signs.register_sign(nodename, def)` like you would use
`core.register_node` or
[`signs_lib.register_sign`](https://github.com/mt-mods/signs_lib/blob/master/API.md#registering-a-sign).

Two definition settings are different from `signs_lib.register_sign`:

* `on_rightclick` defaults to `last_login_signs.rightclick_sign`
* `after_place_node` defaults to `last_login_signs.after_place_node`

### Functions

* `last_login_signs.register_sign(name, def)` described above
* `function last_login_signs.rightclick_sign(pos, node, player)` adds the player to the sign
* `function last_login_signs.after_place_node(pos, ...)` writes the initial text to the sign
* `function last_login_signs.update_sign(pos, node)` forces a sign update

## Contributing

[Send a patch](https://git-send-email.io) to [this mailing list](https://lists.sr.ht/~fgaz/public-inbox) a [pull request](https://docs.codeberg.org/collaborating/pull-requests-and-git-flow/) to [the Codeberg mirror](https://codeberg.org/fgaz/luanti-last_login_signs).

## License

Code is licensed under the EUPL-1.2-or-later.
You can find the text of this license in the LICENSE file or in multiple languages at https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12

Assets are licensed under the Creative Commons Attribution-ShareAlike 4.0 International License. To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
