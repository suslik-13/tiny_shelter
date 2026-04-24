# Let NPC talk in Minetest (like in RPGs/point&click) [yl_speak_up]

This mod allows to set RPG-like texts for NPC where the NPC "says" something
to the player and the player can reply with a selection of given replies -
which most of the time lead to the next dialog.

Original author: AliasAlreadyTaken/aka Bastrabun
Massive rewrite/extension: Sokomine

## Quick installation

License: From now (24.03.2024) on (but not past versions), this mod (minus the editor,
         which is now a seperate mod) is available under the MIT license.
License of textures (`yl_speak_up_bg_dialog*.png` plus masks): AliasAlreadyTaken/aka Bastrabun CC0

Reporting bugs: Please report issues <a href="https://gitea.your-land.de/Sokomine/yl_speak_up">here</a>.

Clone via i.e. `git clone https://gitea.your-land.de/Sokomine/yl_speak_up`
or install via <a href="https://content.minetest.net/">ContentDB</a>.

In order to be able to edit the dialogs of the NPC ingame, please install
<a href="https://gitea.your-land.de/Sokomine/npc_talk_edit">npc_talk_edit</a>.
The only situation where you might not need this extra mod is when you
design your own adventure game and your players are not expected to edit
the NPC.

Optional dependency:
<a href="https://content.minetest.net/packages/TenPlus1/mobs/">mobs_redo</a>
is highly recommended. You may be able to use other mob mods with
manual adjustments as well (This is for very advanced users).

This mod here does not provide any NPC as such. You need a mod that does so.
The mod <a href="https://gitea.your-land.de/Sokomine/npc_talk">npc_talk</a> adds the actual NPC.
It is highly recommended to use `npc_talk` or to create your own according to your needs.

You might also wish to use <a href="https://content.minetest.net/packages/TenPlus1/mobs_npc/">mobs_npc</a>
from TenPlus1 as that mod provides very useful actual NPC and will be used by
<a href="https://gitea.your-land.de/Sokomine/npc_talk">npc_talk</a> if installed.

To get started, best install `yl_speak_up`, `npc_talk_edit`, `npc_talk`, `mobs_redo` and `mobs_npc` in your world.


## Table of Content

1. [For players: How to use it as a player](#1-for-players-how-to-use-it-as-a--player)
   1. [1.1 Terminology](#11-terminology)
   1. [1.2 How it works](#12-how-it-works)
   1. [1.3 How to configure NPC and add dialogs](#13-how-to-configure-npc-and-add_dialogs)
   1. [1.4 Skin](#14-skin)
   1. [1.5 Mute](#15-mute)
   1. [1.6 Chat Commands for players](#16-chat-commands-for-players)
   1. [1.7 Simple replacements (NPC name, player name etc)](#17-simple-replacements-npc-name-player-name-etc)
   1. [1.8 Alternate Text](#18-alternate-text)
   1. [1.9 Autoselect/Autoanswer](#19-autoselectautoanswer)
   1. [1.10 Random Dialogs](#110-random-dialogs)
   1. [1.11 Maximum recursion depth](#111-max-recursion-depth)
   1. [1.12 Changing the start dialog](#112-changing-the-start-dialog)
   1. [1.13 Special dialogs](#113-special-dialogs)
   1. [1.14 Trading (simple)](#114-trading-simple)
   1. [1.15 Quest items](#115-quest-items)
   1. [1.16 Entering Passwords](#116-entering-passwords)
   1. [1.17 Giving things to the NPC](#117-giving-things-to-the-npc)
   1. [1.18 Quests](#118-quests)
   1. [1.19 Properties](#119-properties)
   1. [1.20 Logging](#120-logging)
   1. [1.21 Export/Import](#121-exportimport)
   1. [1.22 Storing internal notes](#122-storing-internal-notes)
   1. [1.23 Counting visits to dialogs and options](#123-counting-visits-to-dialog-and-options)

2. [For moderators: Generic NPCs](#2-for-moderators-generic-npcs)
   1. [2.1 Generic behaviour](#21-generic-behaviour)
   1. [2.2 Chat Commands for moderators](#22-chat-commands-for-moderators)

3. [For server owners: What to consider as a server owner](#3-server-owners-what-to-consider-as-a-server-owner)
   1. [3.1 Tutorial](#31-tutorial)
   1. [3.2 The privs](#32-the-privs)
   1. [3.3 Chat Commands for server owners](#33-chat-commands-for-server-owners)
   1. [3.4 Reload mod without server restart](#34-reload-mod-without-server-restart)
   1. [3.5 Restoring a lost NPC](#35-restoring-a-lost-npc)
   1. [3.6 Tools](#36-tools)
   1. [3.7 Configuration](#37-configuration)
   1. [3.8 Adding local overrides for your server](#38-adding-local-overrides-for-your-server)
   1. [3.9 Data saved in modstorage](#39-data-saved-in-modstorage)
   1. [3.10 Files generated in world folder](#310-files-generated-in-world-folder)
   1. [3.11 Additional custom replacements (in addition to NPC name, player name etc)](#311-additional-custom-replacements-in-addition-to-npc-name-player-name-etc)
   1. [3.12 Custom Preconditions, Actions and Effects](#312-custom-preconditions-actions-and-effects)
   1. [3.13 Integration into your own NPC/mob mods](#313-integration-into-your-own-npcmob-mods)
   1. [3.14 Dynamic dialog](#314-dynamic-dialog)

4. [Future](#4-future)


## 1. For players: How to use it as a player
<a name="for-players"></a>

You need:
* the `npc_talk_owner` [priv](#privs)
* an actual NPC of which you are owner
* to be able to right-click your NPC

### 1.1 Terminology
<a name="terminology"></a>

 | Word used      | What it means [and how it's called; names and numbers are assigned automaticly] |
 | -------------- | ------------------------------------------------------------------------------- |
 | dialog         | A text said by the NPC, with diffrent replys the player can select from. [`d_<nr>`] |
 | option         | A reply/answer to the text the NPC said. The player selects one by clicking on it. [`o_<nr>`] |
 | precondition/<br>prerequirement | All listed preconditions have to be true in order for the NPC to offer an option. [`p_<nr>`] |
 | action         | An action the player may (or may not) take, i.e. trading, taking an item from the NPC, giving the NPC something, entering the right password etc. The action happens after the option is selected by the player. [`a_<nr>`] |
 | effect/result  | Further effects (like setting variables, handing out items) that take place after the action was successful. If there was no action, the effects/results will be executed directly after selecting the option. [`r_<nr>`]|
 | alternate text | Text shown instead of the normal dialog text. This is useful when you have a dialog with a lot of questions and want the player to be able to easily select the next question without having to create a new dialog for each option. [-] |


### 1.2 How it works
<a name="how-it-works"></a>

When someone right-clicks your NPC, the NPC will show a _dialog_. Remember: The _dialog_ is the text the
NPC says to the player plus the _options_ (or answers, choices) offered to the player.

Some texts, like i.e. the name of the NPC or its owner, can be [automaticly replaced](#simple-variables) in the dialog text and the text of the options/answers.

The dialog that is to be shown is selected this way:
* At first, the NPC will usually show the [start dialog](#start_dialog).
* If the player selected an option, the target dialog of that option is shown.
* If the NPC inherits some [generic behaviour](#generic_behaviour), it may show another dialog or additional options.<br>*Note:* As a player, you have no influence on this.
* [Autoselect/Autoanswer](#autoselect_autoanswer) may select an option automaticly if all preconditions are met and switch to a diffrent dialog.
* If the options are set to [random Dialog](#random_dialogs), then an option is choosen randomly and the appropriate dialog will be shown.

Not all options of a dialog will be shown in all situations. An option/answer can have one or more _preconditions_. _All preconditions of an option have to be true_ in order for the option to be offered to the player. A _precondition_ is something that can be either true or false. This can be:
* _check_ an internal state (i.e. of a [quest](#quests)) - based on a system of [variables](#variables)
* _check_ the value of a [property of the NPC](#properties) (for [generic NPC](#generic_behaviour))
* something that has to be calculated or evaluated (=call a function); this can be extended with [custom functions](#precon_action_effect) on the server
* a block somewhere (i.e. that block is cobble, or not dirt, or air, or...)
* a [trade](#trading-simple) - Is the trade possible?
* the inventory of the player (contains an item or does not, has room for item etc.)
* the inventory of the NPC (similar to the player's inventory above)
* the inventory of a block somewhere (for chests, furnaces etc; similar to the player's inventory above)
* an item the player offered/gave to the NPC (react to [the last thing the player gave to the NPC](#npc_wants))
* execute Lua code (requires `npc_master` [priv](#privs)) - extremly powerful and dangerous
* The preconditions of another dialog option are fulfilled/not fulfilled.
* nothing - always true (useful for generic dialogs)
* nothing - always false (useful for temporally deactivating an option)

If the preconditions of the option the player clicked on are all true, operation proceeds with that option.

If the preconditions are not fullfilled, the NPC can show an alternate text or a greyed out text. That option cannot be selected by the player then but is visible.

There may be _one_ _action_ defined. Actions are situations where the NPC shows a formspec to the player and expects some reaction. When the player reacts, the NPC evaluates the action as either successful (i.e. gave the right thing, right password) or a failure. Possible actions are:
* No action (default)
* Normal [trade](#trading-simple) - one item(stack) for another item(stack)
* The NPC gives something to the player (i.e. a [quest item](#quest-items)) out of its inventory.
* The player is expected to give something to the NPC (i.e. a [quest item](#quest-items)). The NPC will store it in his inventory.
* The player has to manually [enter a password or passphrase or some other text](#quest-passwords).
* Show something [custom (has to be provided by the server)](#precon_action_effect).
The NPC may react diffrently when the action failed and show a diffrent dialog. It's also possible to limit how often a player may guess wrongly withhin a given timespan and how often an action may be repeated withhin a given timespan.

If the action was successful (or there was no action at all), then the _effects_/results are executed. Possible effects are:
* _change_ an internal state (i.e. of a [quest](#quests)) - based on a system of [variables](#variables)
* _change_ the value of a [property of the NPC](#properties) (for [generic NPC](#generic_behaviour))
* something that has to be calculated or evaluated (=call a function); this can be extended with [custom functions](#precon_action_effect) on the server; Example: Set a variable to a random number.
* _place_, _dig_, _punch_ or _right-click_ a block somewhere
* put item from the NPC's inventory into a chest etc.
* take item from a chest etc. and put it into the NPC's inventory
* _deal with_ (accept or refuse) an item the player offered to the NPC - [the last thing the player gave to the NPC](#npc_wants))
* NPC crafts something with the things he has in its inventory
* go to other dialog if the previous _effect_ failed
* send a chat message to all players
* give item (created out of thin air) to player (requires extra [privs](#privs) for you _and_ the NPC)
* take item from player and destroy it (requires extra [privs](#privs) for you _and_ the NPC)
* move the player to a given position (requires extra [privs](#privs) for you _and_ the NPC)
* execute any Lua code (requires extra [privs](#privs) for you _and_ the NPC)

The _effects_ also contain a special effect named _dialog_. This effect determines which dialog will be shown next if the player selected this option and all went well. The target _dialog_ is usually set in other parts of the formspec and not set manually as an _effect_.

It is possible to show an [alternate text](#alternate_text) instead of the normal dialog text when the target _dialog_ is shown. This may help in situations where the NPC may have to answer a lot of questions and an extra dialog for each answer seems impractical.


### 1.3 How to configure NPC and add dialogs
<a name="how-to-configure"></a>

Just talk to the NPC and click on the `"I am your owner"`-Dialog. This opens up
a menu where you can edit most things.

Most of the basic configuration and adding of new dialogs and options can be done
in the menu that pops up on rightclick. However, more advanced things such as
_preconditions_, _actions_ and _effects_ can only be set in the _Edit options_
menu. You can reach it by clicking on the button of the option, i.e. on `o_1`.

*Hint*: The command `/npc_talk debug <npc_id>` allows you to get debug
      information regarding preconditions and effects. You can turn it
      off with `/npc_talk debug off`. The NPC ID can be seen in the
      setup dialog for preconditions and effects.

The text the NPC says is written in the markup language Minetest uses. See
<a href="https://github.com/minetest/minetest/blob/master/doc/lua_api.md">lua_api.md</a>
for more details. You can use the elements of that markup language for the
text that the NPC says, i.e.
    `<img name=default_cobble.png width=100 height=100>`
will display the image `default_cobble.png`.


### 1.4 Skin
<a name="skin"></a>

The skin and what the NPC wields can be changed via the `"Edit Skin"` button.
It is also possible to set the animation the NPC shows (sitting, lying down,
walking, mining etc.) if that is [configured for this NPC](#integration).


### 1.5 Mute
<a name="mute"></a>

When you edit an NPC, you might want to stop it from talking to other players
and spoiling unifinished texts/options to the player. 

For this case, the NPC can be muted. This works by selecting the appropriate
option in the talk menu after having started edit mode by claiming to be the
NPC's owner.


### 1.6 Chat Commands for players
<a name="chat-commands-players"></a>

In general, chat commands used by this mod have the form `/npc_talk <command> [<optional parameters>]`.

 | Command | Description |
 | ------- | ----------- |
 | `style <nr>`       | Allows to select the formspec version with `<nr>` beeing 1, 2 or 3. Important for very old clients.|
 | `list`             | Shows a list of all your NPC and where they are.|
 | `debug [<npc_id>]` | Toggle debug mode for NPC `<npc_id>`. Warning: May scroll a lot.|
 | `debug off`        | Turn debug mode off again.|
 | `force_edit`       | Toggles edit mode for you.<br> From now on (until you issue this command again), all NPC you talk to will be in edit mode (provided you are allowed to edit them). This is useful if something's wrong with your NPC like i.e. you made it select a dialog automaticly and let that dialog lead to `d_end`. |

There are [additional commands](#chat-commands-server) that require [further privs](#privs) for some special functionality (i.e. [generic NPC behaviour](#generic_behaviour)).


### 1.7 Simple replacements (NPC name, player name etc)
<a name="simple-variables"></a>

If you want to let your NPC greet the player by name, you can do so. Some
variables/texts are replaced appropriately in the text the NPC says and
in the options the player can select from:

 | Variable        | will be replaced with.. |
 | --------------- | ----------------------- |
 | `$MY_NAME$`     | ..the name of the NPC|
 | `$NPC_NAME$`    | ..same as above (name of the NPC)|
 | `$OWNER_NAME$`  | ..the name of the owner of the NPC|
 | `$PLAYER_NAME$` | ..the name of the player talking to the NPC|
 | `$GOOD_DAY$`    | ..`"Good morning"`, `"Good afternoon"` or `"Good evening"` - depending on the ingame time of day|
 | `$good_DAY$`    | ..same as above, but starts with a lowercase letter (i.e. `"good morning"`)|

The replacements will not be applied in edit mode.

Servers can define [additional custom replacements](#add-simple-variables).

It is also possible to insert the *value* of variables into the text. Only variables the owner of the NPC has read access to can be replaced. Example: The variable "Example Variable Nr. 3" (without blanks would be a better name, i.e. "example\_variable\_nr\_3"), created by "exampleplayer", could be inserted by inserting the following text into dialog texts and options:
    $VAR exampleplayer Example Variable Nr. 3$ 
It will be replaced by the *value* that variable has for the player that is talking to the NPC.

Properties can be replaced in a similar way. The value of the property "job" of the NPC for example could thus be shown:
    $PROP job$

Variables and properties can only be replaced if their *name* contains only alphanumeric signs (a-z, A-Z, 0-9), spaces, "\_", "-" and/or ".".


### 1.8 Alternate Text
<a name="alternate_text"></a>

Sometimes you may encounter a situation where your NPC ought to answer to
several questions and the player likely wanting an answer to each. In such
a situation, you might create a dialog text for each possible option/answer
and add an option to each of these new dialogs like "I have more questions.".
That is sometimes impractical. Therefore, you can add alternate texts.

These alternate texts can be shown instead of the normal dialog text when the
player selected an option/answer. Further alternate texts can be shown if
the action (provided there is one defined for the option) or an effect failed.

The alternate text will override the text of the dialog (what the NPC says)
but offer the same options/answers as the dialog normally would.

Alternate texts can be converted to normal dialogs, and normal dialogs can
vice versa be converted to alternate texts if only one option/answer points
to them.


### 1.9 Autoselect/Autoanswer
<a name="autoselect_autoanswer"></a>

Sometimes you may wish to i.e. greet the player who has been sent on a mission
or who is well known to the NPC in a diffrent way.
For that purpose, you can use the option in the edit options menu right next to
`"..the player may answer with this text [dialog option "o_<nr>"]:"` and switch that
from `"by clicking on it"` to `"automaticly"`.
When the NPC shows a dialog, it will evaluate all preconditions of all options. But
once it hits an option where selecting has been set to `"automaticly"` and all other
preconditions are true, it will abort processing the current dialog and move on to
the dialog stated in the automaticly selected option/answer and display that one.


### 1.10 Random Dialogs
<a name="random_dialogs"></a>

If you want the NPC to answer with one of several texts (randomly selected), then
add a new dialog with options/answers that lead to your random texts and edit one
of these options so that it is `"randomly"` selected.
Note that random selection affects the entire dialog! That dialogs' text isn't shown
anymore, and neither are the texts of the options/answers shown. Whenever your NPC
ends up at this dialog, he'll automaticly choose one of the options/answers randomly
and continue there!

There is no way to assign weights to the options. All are choosen with equal probability.

### 1.11 Maximum recursion depth
<a name="max_recursion_depth"></a>

Autoselect/autoanswer and random dialogs may both lead to further dialogs with further
autoanswers and/or random selections. As this might create infinite loops, there's a
maximum number of "redirections" through autoanswer and random selection that your NPC
can take. It is configured in config.lua as
	`yl_speak_up.max_allowed_recursion_depth`
and usually set to 5.


### 1.12 Changing the start dialog]
<a name="start_dialog"></a>

The _start dialog_ is usually the _first_ dialog of the NPC: `d_1`. It may sometimes become
necessary to change that when your NPC gets a new (temporary?) job or when you're designing
a [generic NPC](#generic_behaviour). You can change the _start dialog_ easily with the
options the NPC offers you when you talk to it as owner.


### 1.13 Special dialogs
<a name="special-dialogs"></a>

In general, dialogs follow the naming schem `d_<nr>`. However, some few have a
special meaning:
 | Dialog           | Meaning |
 | ---------------- | ------- |
 | `d_<nr>`         | Normal dialog. They are automaticly numbered. |
 | `d_end`          | End the conversation (i.e. after teleporting the player). |
 | `d_got_item`     | The NPC [got something](#npc_wants) and is trying to decide what to do with it. |
 | `d_trade`        | [Trade](#trading-simple)-specific options. I.e. crafting new items when stock is low.|
 | `d_dynamic`      | [Dynamic dialog](#dynamic-dialog) that is changed on the fly. Each NPC has exactly one. |


### 1.14 Trading (simple)
<a name="trading-simple"></a>

The NPC can trade item(stacks) with other players.
Only undammaged items can be traded.
Items that contain metadata (i.e. written books, petz, ..) cannot be traded.
Dammaged items and items containing metadata cannot be given to the NPC.

Trades can either be attached to dialog options (and show up as results there)
via the edit options dialog or just be trades that are shown in a trade list.
The trade list can be accessed from the NPC's inventory.

If there are trades that ought to show up in the general trade list (i.e. not
only be attached to dialog options), then a button "Let's trade" will be shown
as option for the first dialog.

Trades that are attached to the trade list (and not dialog options) can be
added and deleted without entering edit mode (`"I am your owner. ..."`).

If unsure where to put your trades: If your NPC wants to tell players a story
about what he sells (or if it is i.e. a barkeeper), put your trades in the
options of dialogs. If you just want to sell surplus items to other players
and have the NPC act like a shop, then use the trade list.


### 1.15 Quest items
<a name="quest-items"></a>

[Quest](#quests) items can be _created_ to some degree as part of the _action_ of an
_option_ through the edit options menu.

<a href="https://github.com/minetest/minetest">MineTest</a>
does not allow to create truely new items on a running server on
the fly. What can be done is giving specific items (i.e. _that_ one apple,
_that_ piece of paper, _that_ stack of wood, ..) a new description that
makes it diffrent from all other items of the same type (i.e. all other
apples).

A new description alone may also be set by the player with the engraving
table (provided that mod is installed):
	<a href="https://forum.minetest.net/viewtopic.php?t=17482">See Minetest Forum Engraving Table Topic</a>

In order to distinguish items created by your NPC and those created through
the engraving table or other mods, you can set a special ID. That ID will
also contain the name of the player to which the NPC gave the item. Thus,
players can't just take the quest items of other players from their bones
and solve quests that way.

The actions _npc_gives_ and _npc_wants_ are responsible for handling of
quest items. They can of course also handle regular items.

If an NPC creates a special quest item for a player in the _npc_gives_
action, it takes the item out of its inventory from a stack of ordinary
items of that type and applies the necessary modifications (change
description, set special quest ID, set information which player got it).

If the NPC gets such a quest item in an _npc_wants_ action, it will check
the given parameters. If all is correct, it will strip those special
parameters from the item, call the action a success and store the item
in its inventory without wasting space (the item will likely stack if it
is _not_ a quest item).


### 1.16 Entering Passwords
<a name="quest-passwords"></a>

Another useful method for [quests](#quests) is the _text_input_ action. It allows the
NPC to ask for a passwort or the answer to a question the NPC just asked.
The player's answer is checked against the _expected answer_ that you give
when you set up this action.


### 1.17 Giving things to the NPC
<a name="npc_wants"></a>

There are several ways of giving items to the NPC:
* selecting `"Show me your inventory"` and putting it directly into the NPC's inventory (as owner)
* [trading](#trading-simple)
* using an action where the NPC wants a more or less special item
* or an effect/result where the NPC just removes the item from the player's inventory and thrashes it (requires `npc_talk_admin` [priv](#privs) - or whichever priv you set in config.lua as `yl_speak_up.npc_privs_priv`).

Using an action might work in many situations. There may be situations where it
would be far more convenient for the player to just give the items to the NPC and let
it deal with it. This is what the special dialog `d_got_item` is for.

In order to activate this functionality, just enter edit mode and select the option
	`"I want to give you something.".`
A new dialog named `d_got_item` will be created and an option shown to players in the
very first dialog where they can tell the NPC that they want to give it something.

The dialog `d_got_item` can have options like any other dialog - except that [autoselect](#autoselect_autoanswer)
will be activated for each option. If there are no options/answers to this dialog or
none fits, the NPC will offer the items back automaticly.

Please make sure each option of the dialog `d_got_item` has..
* a precondition that inspects what was offered:<br>`"an item the player offered/gave to the NPC" (precondition)`
* and an effect/result that deals with the item:<br>`"an item the player offered to the NPC" (effect)`
Else the items will just be offered back to the player.

It is also possible to examine the item the NPC got using the precondition `"an item the player offered/gave to the NPC"`.


### 1.18 Quests
<a name="quests"></a>

NPC love handing out quests! Especially if they got any complex quests.
A simple "bring me 10 dead rats" may not excite players or NPC much.
But a true riddle, something that involves some thinking and puzzling - that's great!
Every NPC which got such a quest will be proud (just search for "Epic NPC man" on youtube).

Quest handling is far from optimal yet and will be improved in the future.

In order to manage a quest, you need to store information about a player.
You can _create_ _variables_ that will hold data for each player. That way
you can remember which _quest step_ the player has already completed.

Variables can be created and managed by adding and editing _preconditions_
and _effects_ of the type `"an internal state (i.e. of a quest)"`.

Inside a _precondition_, you can _check_ the _value of a variable_ (it's always
evaluated for the current player that clicked on your NPC), and in an _effect_
you can _change_ the _value of the variable_ for that player.

You can also grant access to a variable you've created to other players so that
they may use it in their quests and NPC.

You can also check the values for all players (regarding your own variables)
and edit those values if needed.

Checking and setting quest progress currently has to be done manually.
It's ongoing work to move that to the _edit options menu_ (only partially
implemented so far).


### 1.19 Properties
<a name="properties"></a>

NPC may have _properties_. A _property_ is a _value a particular NPC has_. It
does not depend on any player and will remain the same until you change
it for this NPC. You can view and change properties via the `"Edit"` button
and then clicking on `"Edit properties"`. There are preconditions for
checking properties and effects for changing them.

Properties prefixed by the text `"self."` originate from the NPC itself,
i.e. `self.order` (as used by many `mobs_redo` NPC for either following their
owner, standing around or wandering randomly). They usually cannot be
changed - unless you write a function for them. See
	`yl_speak_up.custom_property_handler`
and
	`custom_functions_you_can_override.lua`
You can also react to or limit normal property changes this way.

Properties starting with `"server"` can only be changed by players who have
the `npc_talk_admin` priv.

Example for a property: Mood of the NPC (raises when treated well, gets
lowered when treated badly).

Properties are also extremly important for generic behaviour. Depending
on the properties of the NPC, a particular [generic behaviour](#generic_behaviour) might fit
or not fit to the NPC.


### 1.20 Logging
<a name="logging"></a>

The trade list view provides access to a log file where all changes to the
NPC, inventory movements and purchases are logged.

The log shows the date but not the time of the action. Players can view the
logs of their own NPC.

Admins can keep an NPC from logging by setting the property
	`server_nolog_effects`	to i.e	`true`
That way, the NPC will no longer log or send debug messages when executing
effects.


### 1.21 Export/Import
<a name="export"></a>

It's possible to export the full dialog data of an NPC and to view it in more
human-readable form. It's also possible to export it in some degree in the
format the mod simple\_dialogs uses (minus preconditions, actions, effects and
all other special things).

Players with the `privs` priv can also import those dialogs into an NPC in
their local singleplayer game. But be warned: The dialog is *not* checked for
consistency or anything yet! That is why it requires the `privs` priv. Don't
just import any NPC data someone sends to you!

It is planned to check the dialog (.json format) more fully in the future so
that players can import data on a server as well. However, we are not that far
yet.


### 1.22 Storing internal notes
<a name="notes"></a>

It's possible to take internal notes on your NPC by clicking on the "Notes"
button. You can help your memory and store information about your plans with
this NPC - its character, how it behaves and talks, who his friends are etc.
These internal notes are only shown to players who can edit this NPC.


### 1.23 Counting visits to dialogs and options
<a name="visit-counter"></a>

Whenever a dialog text is displayed to the player and whenever the player
selects an option which is successful (no aborted actions or `on_failure`
effects inbetween), a counter called `visits` is increased by one for that
dialog or option.

This information is *not* persistent! When the player leaves the talk by
choosing `Farewell!` or pressing ESC all visit information is lost.

The feature can be used to help players see which options they've tried
and which path they've followed. If an option is set to `*once*` instead
of the default `often` in the edit options dialog, that option can only
be selected *once* each time the player talks to this NPC. After that the
option gets greyed out and displays "[Done]" followed by the normal option
text.

Visits are not counted in edit mode and not counted for generic dialogs.

There are custom preconditions for checking the number of visits to a dialog
and/or option.


## 2. For moderators: Generic NPCs
<a name="for-moderators"></a>

You need:
* the `npc_talk_admin` [priv](#privs)

With this priv you can edit and maintain NPC that show [generic behaviuor](#geeric_behaviour)
and which may influence or override all other NPC on the server.


### 2.1 Generic behaviour
<a name="generic_behaviour"></a>

Sometimes you may have a group of NPC that ought to show a common behaviour - like for example guards, smiths, bakers, or inhabitants of a town, or other NPC that have something in common. Not each NPC may warrant its own, individual dialogs.

The [Tutoial](#tutorial) is another example: Not each NPC needs to present the player with a tutorial, but those that are owned and where the owner tries to program them ought to offer some help.

That's where _generic dialogs_ come in. You can create a new type of generic dialog with any NPC. That NPC can from then on only be used for this one purpose and ought not to be found in the _"normal"_ world! Multiple such generic dialogs and NPC for their creation can exist.

[Properties](#properties) are very helpful for determining if a particular NPC ought
to offer a generic dialog.

The _`entity_type`_ precondition can also be helpful in this case. It allows to add dialogs for specific types of mobs only (i.e. `npc_talk:talking_npc`).

Requirements for a generic dialog to work:
* _Generic dialogs_ have to [start with a dialog](#start_dialog) with _just one option_.
* This _option_ has to be set to _"automaticly"_ (see [Autoanswer](#autoselect_autoanswer)).
* The _preconditions_ of this option are very important: They determine if this particular generic dialog fits to this particular NPC or not. If it fits, all dialogs that are part of this NPC that provides the generic dialog will be added to the _"normal"_ dialogs the importing actual NPC offers. If it doesn't fit, these generic dialogs will be ignored here.
* The creator of a generic dialog can't know all situations where NPC may want to use his dialogs and where those NPC will be standing and by whom they are owned. Therefore only a limited amount of types of preconditions are allowed for the preconditions of this first automatic option: `state`, `property`, `player_inv` and `custom`.
* The other dialogs that follow after this first automatic dialog may contain a few more types of preconditions: `player_offered_item`, `function` and `other` are allowed here as well, while `block`, `trade`, `npc_inv` and `block_inv` make no sense and are not available.
* All types of actions are allowed.
* Regarding effects/results, the types `block`, `put_into_block_inv`, `take_from_block_inv` and `craft` are not supported.

The `"automaticly"` selected only option from the [start dialog](#start_dialog) leads via the usual `"dialog"` effect to the actual [start dialog](#start_dialog) for the imported dialogs from that NPC. The options found there will be added into the target NPC and the dialog text will be appended to its dialog text.

The chat command `/npc_talk generic` (requires `npc_talk_admin` [priv](#privs)) is used to list, add or remove NPC from the list of generic dialog/behaviour providers.


### 2.2 Chat Commands for moderators
<a name="chat-commands-moderators"></a>

In general, chat commands used by this mod have the form `/npc_talk <command> [<optional parameters>]`.

The [chat commands for players](#chat-commands-players) are still important and valid. In addition,
commands for managing [generic NPC](#generic_behaviour) become available:

 | Command | Description |
 | ------- | ----------- |
 | `generic list`                 | list all NPC that provide generic dialogs|
 | `generic add <npc_id>`         | add NPC `<npc_id>` as a new provider of generic dialogs|
 | `generic remove <npc_id>`      | remove NPC `<npc_id>` as a provider of generic dialogs|
 | `generic reload`               | reload data regarding generic dialogs|







## 3. For server owners: What to consider as a server owner
<a name="server-owners"></a>


### 3.1 Tutorial
<a name="tutorial"></a>

There is an NPC that explains a few things and adds as a tutuor.

The savefile is: `n_1.json`

Copy that file to the folder
	`<your world folder>/yl_speak_up_dialogs/n_1.json`
(replace the 1 with a higher number if you already have some NPC defined).

The first NPC in your world will now become a tutor (after you spawned it
and set its name).



### 3.2 The privs
<a name="privs"></a>

 | Minetest priv     | what this priv grants the player who has it |
 | ----------------- | ------------------------------------------- |
 | `npc_talk_owner`  | will allow players to edit their *own* NPC by talking to them. Ought to be given to all players.|
 | `npc_talk_master` | allows players to edit *any* NPC supported by this mod.<br>Ought to be given to selected trusted players who want to help others with their NPC configuration and/or support NPCs owned by the server.|
 | `npc_talk_admin`  | Generic maintenance of NPC.<br>Allows to use the the command `/npc_talk generic` and add or remove an NPC from the list of generic dialog providers.<br>Also allows to set and change NPC properties starting with the prefix "server".|
 | `npc_master`      | allows players to edit *any* NPC supported by this mod. *Does* include usage of the staffs (now part of `yl_npc`).<br>This is very powerful and allows to enter and execute lua code without restrictions.<br>Only grant this to staff members you ***really*** trust. The priv is usually not needed.|
 | `privs`           | Necessary for the commands<br>`/npc_talk privs`    - grant NPC privs like e.g. execute lua and <br>`/npc_talk_reload`   - reload code of this mod|

NPC can have privs as well:
 | NPC priv             | The NPC.. |
 | -------------------- | --------- |
 | `precon_exec_lua`    | ..is allowed to excecute lua code as a precondition|
 | `effect_exec_lua`    | ..is allowed to execute lua code as an effect|
 | `effect_give_item`   | ..can give items to the player, created out of thin air|
 | `effect_take_item`   | ..can accept and destroy items given to it by a player|
 | `effect_move_player` | ..can move the player to another position|


### 3.3 Chat Commands for server owners
<a name="chat-commands-owners"></a>

The [chat commands for players](#chat-commands-players) and the [chat commands for moderators](#chat-commands-moderators) are still important and valid. In addition, commands for managing [privs](#privs) become available:

In general, chat commands used by this mod have the form `/npc_talk <command> [<optional parameters>]`.

 | Command | Description |
 | ------- | ----------- |
 | `privs list`                    | List the privs of all NPC. NPC need privs for some dangerous things like executing lua code.|
 | `privs grant <npc_id> <priv>`   | grant NPC `<npc_id>` the priv `<priv>`|
 | `privs revoke <npc_id> <priv>`  | revoke priv `<priv>` for NPC `<npc_id>`|

* NPC need privs for some dangerous things like executing lua code.<br>Example: `/npc_talk privs grant n_3 effect_exec_lua`<br>grants NPC n_3 the right to execute lua code as an effect/result.<br>Note: If a precondition or effect originates from a generic NPC, the priv will be considered granted if either the executing NPC or the the generic NPC has the priv.


### 3.4 Reload mod without server restart
<a name="hotreload"></a>

The mod doesn't define any items or NPC itself. It is designed in a way that you can
_reload the code of this mod without having to restart the server_.

The command  `/npc_talk_reload` reloads almost all of the code of this mod.

When you add new [custom functions](#precon_action_effect) to this mod or change a custom function - or even code of the mod itself! -, you can reload this mod without having to restart the server. If you made an error and the files can't load then your server will crash - so please _test on a test server_ first! Requires the _privs_ priv.


### 3.5 Restoring a lost NPC
<a name="npc_restore"></a>

Sometimes (hopefully rarely!) an NPC entity and its egg may get lost. It may have got lost due to someone having misplaced its egg (happens). Or it might have been killed somehow.

In that case, you can run `/npc_talk force_restore_npc <id> [<copy_from_id>]`

The optional parameter `<copy_from_id>` is only used when the NPC is _not_ listed in `/npc_talk list`. You won't need it. It's for legacy NPC.

*WARNING*: If the egg or the NPC turns up elsewhere, be sure to have only *one* NPC with that ID standing around! Else you'll get chaos.


### 3.6 Tools
<a name="tools"></a>

There are no more tools (=staffs) provided. You can do all you could do
with them with the staffs by just talking to the NPC. The staffs are deprecated.

Use `/npc_talk force_edit` if the NPC is broken and cannot be talked to normally anymore.





### 3.7 Configuration
<a name="configuration"></a>

Please make sure that the tables
```
yl_speak_up.blacklist_effect_on_block_<type> with <type>:<interact|place|dig|punch|right_click|put|take>
```
contain all the blocks which do not allow the NPCs this kind of interaction.
<br>You may i.e. set the `put` and `take` tables for blocks that do extensive
checks on the player object which the NPC simply can't provide.


```
yl_speak_up.blacklist_effect_tool_use
```
is a similar table. Please let it contain a list of all the tool item names that NPC are _not_ allowed to u se.

_Note_: The best way to deal with local adjustments may be to create your
      own mod, i.e. `yl_speak_up_addons`, and let that mod depend on this
      one, `yl_speak_up`, and do the necessary calls. This is very useful
      for i.e. adding your own textures or doing configuration. You can
      then still update the mod without loosing local configuration.


### 3.8 Adding local overrides for your server
<a name="server_overrides"></a>

* You can override and add config values by creating and adding a file
```
local_server_config.lua
```
in the mod folder of this mod. It will be executed after the file `config.lua` has been executed. This happens at startup and each time after the command `/npc_talk_reload` has been given.

* If you want to add or override existing functions (i.e. functions from/for `custom_functions_you_can_override.lua`), you can create a file named
```
local_server_do_on_reload.lua
```
in the mod folder of this mod. It will be executed at startup and each time `/npc_talk_reload` is executed.

* Note: If you want to register things (call minetest.register_-functions), you have to do that in the file
```
local_server_do_once_on_startup.lua
```
which will be executed only _once_ after server start and _not_ when `/npc_talk_reload` is executed.


### 3.9 Data saved in modstorage
<a name="modstorage"></a>

 | Variable           | Usage   |
 | ------------------ | ------- |
 | `status`           | Set this to 2 to globally deactivate all NPC. |
 | `amount`           | Number of NPCs generated in this world. This is needed to create a uniqe ID for each NPC. |
 | `generic_npc_list` | List of NPC ids whose dialogs shall be used as generic dialogs. |


### 3.10 Files generated in world folder
<a name="files_generated"></a>

 | Path/File name                      | Content |
 | ----------------------------------- | ------- |
 | `yl_speak_up.path`                  | Directory containing the JSON files containing the stored dialogs of the NPC. |
 | `yl_speak_up.inventory_path`        | Directory containing the detatched inventories of the NPC. |
 | `yl_speak_up.log_path`              | Directory containing the logfiles of the NPC. |
 | `yl_speak_up.quest_path`            | Directory containing information about quests. |
 | `yl_speak_up_npc_privs.data`        | File containing the privs of the NPC. |
 | `yl_speak_up.player_vars_save_file` | JSON file containing information about quest progress and quest data for individual players. |


### 3.11 Additional custom replacements (in addition to NPC name, player name etc)
<a name="simple-variables"></a>

In addition to the [simple replacements (NPC name, player name etc)](#simple-variables),
a server owner can add server-specific replacements as needed.

In order to do this, add the following in your own mod:
```lua
local old_function = yl_speak_up.replace_vars_in_text
yl_speak_up.replace_vars_in_text = function(text, dialog, pname)
	-- do not forget to call the old function
	text = old_function(text, dialog, pname)
	-- do your own replacements
	text = string.gsub(text, "$TEXT_TO_REPLACE$", "new text")
	-- do not forget to return the new text
	return text
end
```

### 3.12 Custom Preconditions, Actions and Effects
<a name="precon_action_effect"></a>

You can define custom actions and provide up to ten parameters. The file
	`custom_functions_you_can_override.lua`
holds examplexs. Please do not edit that file directly. Just take a look
there and override functions as needed in your own files! That way it is
much easier to update.

In general, the table
	`yl_speak_up.custom_functions_p_[ descriptive_name ]`
holds information about the parameters for display in the formspec (when
setting up a precondition, action or effect) and contains the function
that shall be executed.


### 3.13 Integration into your own NPC/mob mods
<a name="integration"></a>

In order to talk to NPC, you need to call
```lua
	if(minetest.global_exists("yl_speak_up") and yl_speak_up.talk) then
		yl_speak_up.talk(self, clicker)
		return
	end
```
in the function that your NPC executes in `on_rightclick`.
Note that capturing and placing of your NPC is *not* handled by `yl_speak_up`!
Use i.e. the lasso that came with your NPC mod.

You also need to make sure that the textures of your mob can be edited. In order to do so,
* add an entry in `yl_speak_up.mesh_data[<model.b3d>]` for your model
* add an entry in `yl_speak_up.mob_skins[<entity_name>] = {"skin1.png", "skin2.png", "another_skin.png"}`
* call `table.insert(yl_speak_up.emulate_orders_on_rightclick, <entity_name>)` if your mob is a `mobs_redo` one and can stand, follow (its owner) and walk around randomly. As you override `on_rightclick`, this setting will make sure to add buttons to emulate previous behaviour shown when clicking on the NPC.


### 3.14 Dynamic dialogs
<a name="dynamic-dialog"></a>

Sometimes you may have to generate a dialog on the fly and/or wish for more dynamic texts and answers.

Each NPC has a `d_dynamic` dialog that will never be saved with the NPC data and that can be changed each time the player selected an option.

This is particulary useful for using external functions for generating dialog texts and options/answers plus their reactions.

Warning: This feature is not finished yet and undergoing heavy changes. Do not rely on its functionality yet!


## 4. Future
<a name="future"></a>

Creating quests is possible but not very convincing yet. It is too tedious and errorprone. I'm working on a better mechanism.


