Keys history is stored in KeyBetaDB.keysHistory.
A snapshot is created when you enter a mythic dungeon (difficulty 23) or mythic keystone instance (difficulty 8).
A snapshot is created or updated when a challenge mode keystone starts.
Each run is a distinct history entry for the current dungeon visit.
GetInstanceInfo instance id is only a dungeon map id, so it is not used alone to match prior runs.
The first mythic enter/key start for a visit creates the run snapshot and marks it active.
Leaving the mythic dungeon clears the active visit; entering again creates a new run even for the same dungeon.
Later GROUP_ROSTER_UPDATE events merge newly present other players into the active visit only, without clearing existing marks.
UI reload inside the same mythic visit resumes the active entry.
A manual refresh (`/keyf h refresh` or the Refresh button) re-snapshots the current group and removes anyone no longer present, keeping marks for players who remain.
When a run has more than 4 other players, individual players can be deleted from that run for cleanup.
The local player is never snapshotted and never shown in keys history.
Each snapshotted player stores name, realm, class, season mythic rating, item level, and an optional review mark.
Player identity is shown as `Name - Realm`.
Player item levels for party members are filled in via inspect after the snapshot when possible.
Review marks are pass, fail, neutral, or cleared (no input).
Vote summaries score pass as +1, neutral as 0, and fail as -1 across all marked history rows for a player.
History keeps the newest 100 runs.
