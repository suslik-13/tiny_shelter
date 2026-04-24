# Ingame Editor for letting NPC talk in Minetest (like in RPGs/point&click) [npc\_talk\_edit]

This mod allows you to edit the dialogs of NPC ingame without a server restart.
Players can edit their own NPC and grant others the right to edit them as well.

Author: Sokomine (based on AliasAlreadyTaken/aka Bastrabun's work)

This is just the editor.

You will need the following additional mods in order to make it work:

* <a href="https://gitea.your-land.de/Sokomine/yl_speak_up">yl_speak_up</a> -
  the actual mod/library that lets the NPC talk (required)
* <a href="https://gitea.your-land.de/Sokomine/npc_talk">npc_talk</a> -
  some NPC for your world that make use of the mod
  (technicly optional but highly recommended unless you write your own mod)
* <a href="https://content.minetest.net/packages/TenPlus1/mobs/">mobs_redo</a> -
  a mod from TenPlus1 that adds lassos and better NPC handling
  (optional but highly recommended; also the base of a lot of other mobs, monsters and animals)
* <a href="https://content.minetest.net/packages/TenPlus1/mobs_npc/">mobs_npc</a> -
  a mod from TenPlus1 that adds NPC that spawn on their own in your world, can be tamed with
  bread and even reproduce (optional; recommended)

To get started, best install `yl_speak_up`, `npc_talk_edit`, `npc_talk`, `mobs_redo` and `mobs_npc` in your world.

Note: About the only time when you may not wish to install this mod alongside
<a href="https://gitea.your-land.de/Sokomine/yl_speak_up">yl_speak_up</a>
might be when you're creating your own adventure game and want to ship it
in a state where players of your game don't need to edit the NPC (players
may still install this mod here after they've played your adventure and
want to change/extend your game on their own).


## Quick installation

License: GPLv3.0 or later (see LICENSE)
License of textures: no textures or media included

Reporting bugs: Please report issues <a href="https://gitea.your-land.de/Sokomine/npc_talk_edit">here</a>.

Clone via i.e. `git clone https://gitea.your-land.de/Sokomine/npc_talk_edit`
or install via <a href="https://content.minetest.net/">ContentDB</a>.

For documentation, please refer to the documentention of
<a href="https://gitea.your-land.de/Sokomine/yl_speak_up/readme.md">yl_speak_up</a>.

