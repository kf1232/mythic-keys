Season data lives in data/key-data/season-config.lua.
Change `active` in season-config.lua to switch the live season.
Each season entry includes a display name and dungeon list.
Each dungeon entry includes map id, name, short label, icon texture FileID, and teleport spell IDs.
The season dungeon list does not discover dungeons from the live client at login.
SeasonDungeons reads the active season and exposes dungeons, name, and teleport lookups.
Dungeon teleport spell lookup reads from the active season dungeon entries.
Each season dungeon column order matches the party and target views.
Run /keyf dumpseason after login to print live icon FileIDs for the active season in season-config.lua.
Run /keyf dumpmaps after login to print every MapChallengeMode id, name, and icon from the client.
Change `active` in season-config.lua to switch between stored season configs (e.g. midnight-s1, midnight-s2).
The addon warns once when header icons are missing from the active season config.
