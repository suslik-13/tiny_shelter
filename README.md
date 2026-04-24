# tiny SHELTER - Minetest/Luanti Server

## Description

**tiny SHELTER** is Small cozy PvE Lunati/Minetest server for peaceful building and exploration. Perfect for relaxed gameplay with friends.

### Server Features:
 - PvE focused with optional PvP
 - Building and exploration focus
 - Cooperative gameplay
 - Chat translator
 - Discord relay

**Discord community:** https://discord.gg/JUFdNDWAcu

## Server Launch

### Requirements
- Docker
- Docker Compose

### Launch Commands

To start the server use:

```bash
docker compose up
```

To start in background mode:

```bash
docker compose up -d
```

To stop the server:

```bash
docker compose down
```

### Fixing Permission Issues

If you encounter errors related to file configuration or log access permissions during startup, such as:

```
ERROR[Main]: Failed to open "/home/minetest/.minetest/debug.txt": Permission denied
ERROR[Main]: Could not read configuration from "/home/minetest/.minetest/minetest.conf"
```

Run the following command to fix access permissions:

```bash
sudo chmod -R 777 ./luanti_files
```

This command sets full access permissions (read/write/execute) to all files and directories inside `luanti_files`, allowing the Docker container to work freely with configuration, worlds, and mods.

## Project Structure

```
.
├── docker-compose.yml         # Docker Compose configuration
├── luanti_files/              # Server data (mounted in container)
│   ├── minetest.conf          # Main server config
│   ├── games/                 # Game mods and resources
│   │   └── minetest_game/     # Main game with mods
│   ├── worlds/                # Saved worlds
│   │   └── tiny_shelter/      # tiny SHELTER server world
│   ├── mod_data/              # Mods data
└── README.md                  # This file
```

## Network Ports

The server uses the following ports:
- **30003/udp** — main game port
- **30003/tcp** — additional TCP port

Make sure these ports are open in your firewall if you want players to connect from outside.

## Configuration

The main configuration file is located at `./luanti_files/minetest.conf`. You can edit server settings by modifying this file.

After changing the configuration, restart the server:

```bash
docker compose restart
```

## Mods

The server uses many mods, including:
- **3d_armor** — armor and protection
- **mobs_monster, mobs_animal** — mobs and creatures
- **farming** — agriculture
- **techpack** — technical mods
- **stamina** — stamina system
- **awards** — achievements
- And many more...

Full list of mods can be found in the `./luanti_files/games/minetest_game/mods/` directory.

### Discord relay (discordmt)

⚠️ **Important:** To configure Discord Relay, you need to create and configure a config file for the **discordmt** mod

```bash
luanti_files/games/minetest_game/mods/relay.conf
```

more info: https://content.luanti.org/packages/archfan7411/discordmt/

## Support

If you have problems or questions, join our Discord server: https://discord.gg/JUFdNDWAcu

---
