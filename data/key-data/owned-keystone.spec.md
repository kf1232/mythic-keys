Owned keystones are cached by player GUID so party member keys can be added later.

The player's keystone is discovered by scanning bag item links for a keystone hyperlink.

Bag scans use Guard on container APIs and prefer C_Item/C_ChallengeMode parsing over regex.

Bag scans run only while the player is out of combat.

Bag and keystone-related events mark the cache dirty and debounce a rescan.

If a scan is requested during combat, it runs on leaving combat.

If no keystone link is found in bags, the Mythic Plus owned-keystone API is used as a fallback when available.

Owned keystone level and map values are validated before cache or broadcast use.

Party member keystones arrive via key sync and are stored with source `sync`.

The local player's keystone is never overwritten by party sync.

Callers can request the current key for a unit and the list of holders for a dungeon map id.

`GetSyncPayload()` returns the wire-format key message for party broadcast.


