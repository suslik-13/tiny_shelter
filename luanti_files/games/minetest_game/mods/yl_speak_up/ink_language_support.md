# Limited ink support

Please don't hope for too much yet. This here is mostly an outline
of what is *planned* - not what is available yet!

The export works already. Import of knots works partially (no
preconditions, actions or effects).

Complex things will take their time.

In short: Take your NPC, use the "Export to ink" button, edit
the text of dialogs and options, add new knots or options,
rearrange the order of the lines of the options to affect
sorting - and then import it back and see how well it worked.


## Table of Content

1. [What is ink](#1-what-is-ink)
2. [Export to ink](#2-export-to-ink)
3. [Limitations](#3-limitations)

3. [Import from ink](#3-import-from-ink)
   1. [3.1 Supported elements](#31-supported-elements)
   1. [3.2 Supported inline elements](#32-supported-inline-elements)
   1. [3.3 Escape character](#33-escape-character)
   1. [3.4 Labels](#34-labels)
   1. [3.5 Structure of a choice](#35-structure-of-a-choice)
   1. [3.6 Special dialogs](#36-special-dialogs)

## 1. What is Ink

This mod has limited support for the
<a href="https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md">ink lanugage</a>.

That scripting language is intended for writing stories and quests
and help you write dialogs for NPC. You can use your favorite text
editor offline instead of clicking through the GUI of the NPC ingame.

You can also write, run and test those dialogs with an ink
interpreter like Inky instead of running a MineTest server.

## 2. Export to ink

NPC can export their dialogs. This is a good start in order to see
how things work. You can get there by clicking on "I am your owner"
in the NPC dialog, then on the "Export" button in the top row, and
then on "Ink language".

In theory, this export ought to work with interpreters for the ink
language, i.e. with inky. In practice, some small errors cannot
always be avoided. You may have to edit the export in such a case
until the ink interpreter is happy.

Currently, the visit counter (precondition, "something that has to
be calculated or evaluated", "counted dialog option/answers visits:"
tries its best to come up with a suitable name - but will most
likely fail. Please adjust manually! Often, the name of the
option/answer will do.


### 3. Limitations

Please note that the whole MineTest environment - the world, the
players, the mobs, the inventories etc - is *not* emulated in ink.

Most preconditions and effects therefore cannot be translated
to ink in a meaningful way. There's just no way to tell if e.g.
the player has a particular item in his inventory, or which block
sits at a given location. Those things don't exist in ink. They
could theoreticly be emulated, but - not in any feasible way in
a realistic amount of time.

The things that preconditions check and effects change in the
MineTest world could be simulated in ink via variables. That would
work - but it would also be pretty complex and make reading your
ink code and writing things for import not particulary easy.

Likewise, ink is a language of its own. The NPC support only a
very limited and restricted subset of the ink language and
expect certain special handling and knots.

The export function addas a wrapper dialog (in ink terminolgy:
a knot) to the ink script so that you can continue to run the
program even after you hit a d\_end in its dialogs.

See 3.6 Special Dialogs for more information.

## 3. Import from ink

The ink language is not as well defined as one might hope from the
documentation. As a user you might not run into these problems.

### 3.1 Supported elements

In general, most ink elements will end up becomming a dialog for the
NPC (so, in effect a knot) - no matter if the ink element is a knot,
stitch, gather or weave. NPC are only aware of dialogs and options.
The ink elements are nevertheless helpful for writing such dialogs.

So far, only *knots* are supported - not weaving.

In general, each ink language element has to start at the start of a
line in order for import to work - even if the ink language doesn't
demand this!

Supported (at least to a degree) elements are:
 | Ink symbol | Meaning of the smybol          |
 | ---------- | ------------------------------ |
 | ==         | knot                           |
 | *          | choice (can be selected only once) |
 | +          | sticky choice (can be selected multiple times) |

Partially supported (recognized but not imported):
 | Ink symbol | Meaning of the smybol          |
 | ---------- | ------------------------------ |
 | //         | Start of inline comment        |
 | \/*        | Start of multiline comment     |
 | \*/        | End of multiline comment       |
 | =          | stitch (sub-knot of a knot)    |
 | -          | gather                         |
 | {          | start of multiline alternative |
 | }          | end of multiline alternative   |
 | -          | gather                         |
 | ~          | code                           |
 | INCLUDE    | include file (not supported)   |
 | VAR        | declaration of a variable      |
 | CONST      | declaration of a constant      |

Not supported:
 | Ink symbol | Meaning of the smybol          |
 | ---------- | ------------------------------ |
 | <>         | glue                           |
 | #          | tag                            |


### 3.2 Supported inline elements

*Note*: None of this is implemented in the import yet. For this mod,
the text will for now just be printed as-is.

There is one main inline element that the ink language has: Text in
curly brackets: {inline}. The meaning of that inline element depends
a lot on context:

If it's a variable: The value of the variable is printed.

If it's something like {A|B|C|D}, then that's an alternative - the
first time the knot is visited, A is printed. The second time B,
third time C and so on.

 | Inline     | Meaning of inline text                               |
 | ---------- | ---------------------------------------------------- |
 | {variable} | print the *value* of a varialbe                      |
 | {A|B|C|D}  | alternative: show A on first visit, B on second etc. |
 | {&A|B|C|D} | cycle: start with A again after showing D            |
 | {!A|B|C|D} | once-only alternatives: display nothing after D      |
 | {~A|B|C|D} | shuffle:randomly A, B, C or D                        |
 | {cond:A|B} | if(cond) then A else B                               |

Note that shuffle will not just shuffle the elements and use them in
a random order but will decide randomly each time what to display.
This may be diffrent from what ink does (which might - or might not -
really show *all* shuffle elements, just in a random order). 


### 3.2 Escape character

The escape character is the backslash "\". With that, you can use
the special characters above and have them appear literally in
your text.



### 3.4 Labels

Choices *may* and *ought to* have *labels* in order for the import to
work satisfactorily. In ink, they are optional. For the import, you
kind of need them. Else the import function has no idea if you want to
add a new option/choice to a dialog, want to change the text of an
existing one or just re-arranged their order.

Knots and stitches already have names and can thus be mapped to
existing dialogs.

If a choice or gather doesn't have a label when importing, it's seen
as a *new* choice or gather.

If you create a new dialog and/or option, you don't have to add a
label to the option/choice yourself. You can write it without in ink,
then use the import function, then let the NPC export that again -
and use that processed export as the base for further editing.
Missing labels will be generated automaticly that way and bear the
right name.


### 3.4 Structure of a choice

By default, NPC use *sticky choices* (starting with a plus, "+") and
not the choices (starting with a star, "\*") ink prefers in general.

The difference is that the ink choices can be used *only once* in a
conversation. The NPCs have small memories and many people may
want to talk to them on a multiplayer server - so they don't remember
what has been used between conversations. Even non-sticky choices
will become available again if the player closes the dialog and talks
to the NPC again.

In ink, a choice may look as minimal as this:
 \* Hello!

For an NPC, it may end up looking more like this:
 \+ (o\_3) {cond1} {cond2} {cond3} [Hello!] Oh, nice that you're greeting me! -> start

The brackets [] around the text mean that ink won't repeat that text
when it outputs the reaction to the text. NPC by default don't repeat
such texts. The brackets [] are therefore there mostly so that the
ink output is halfway consistent.

(o\_3) is the label. It will be assigned automaticly by the NPC. When
you edit a choice, or move it around in the list of answers, the
import function will thus know which choice/option you refer to.
The label is not shown to the player talking to the player. It
does not affect the order in which options are shown. Always keep
the label the same - unless you want to add a *new* option!

{cond1} {cond2} {cond3} are conditions in ink. They all need to be
true in order for the choice/option to be available.

What is available between ink and the NPC is quite limited. It's
mostly accessing values of variables and the visit counter that
you may use here. *Note*: This isn't supported yet.

The ink export also puts setting of variables and effects as # tags
somewhere after the choice and before the divert.

The text after the closing square bracket "]" is interpreted as
alternate text by the NPC.


### 3.6 Special dialogs

NPC have some special dialogs:
 | Name        | Meaning of dialog name                                 |
 | ----------- | ------------------------------------------------------ |
 | d\_end      | end the conversation and close the formspec            |
 | d\_trade    | a special trading dialog with diffrent buttons         |
 | d\_dynamic  | dynamic dialog texts provided by server-side functions |
 | d\_got\_item| react to items the player gave to the NPC              |

The dialog target d\_end would normally end the conversation. That might
be pretty inconvenient when you're constructing a quest with many NPC
participating - or just want to test its dialogs without having to restart
it all the time. Therefore, a wrapper dialog is added by the export to ink
function. Example (for NPC n\_134, with start dialog START):
``
    -> n_134_d_end
    === n_134_d_end ===
    What do you wish to do?
    + Talk to n_134 -> n_134_START
    + End -> END
``

Actions in the NPC way of speaking are actions that have to be done by the
player. The player may succeed or fail at completing the action - or simply
click on the "Back" button. Ink has no way to know about such thing as
player inventories or the Minetest world around the player. Therefore,
actions are modelled as an additional dialog in *ink*. Example:

``
    === n_134_action_a_1_o_2_did_you_get_bone ===
    :action: a_1 The NPC wants "- default description -" ("default:chest") with ID "- no special ID -".
    + [Action was successful] -> n_134_thanks_for_bone
    + [Action failed] -> n_134_no_bone 
    + [Back] -> n_134_did_you_get_bone
``
The only thing that will vary in your actions is the name of the action, the
parameters in the text and the target dialogs for each possible outcome.

The same applies to effects. While there is no way to choose a back button
there, effects may still be either successful or fail:
``
    === n_134_effect_r_2_o_1_START ===
    :effect: r_2 If the *previous* effect failed, go to dialog "d_1".
    The previous effect was: r_1 Switch to dialog "d_2".
    + [Effect was successful] -> n_134_guarding_both
    + [Effect failed]
      Oh! Effect r_2 failed. Seems I ran out of bones. Please come back later!
    $TEXT$
      -> n_134_START
``

