Owned keystones are cached by player GUID so party member keys can be added later.

The player's keystone is persisted in `KeyBetaDB.ownedKeystone` after a successful capture.

On login the persisted player key is restored until a complete bag or API scan replaces it.

The player's keystone is discovered by scanning bag item links for a keystone hyperlink.

Bag scans use Guard on container APIs and prefer C_Item/C_ChallengeMode parsing over regex.

Bag scans run only while the player is out of combat.

Bag and keystone-related events mark the cache dirty and debounce a rescan.

If a scan is requested during combat, it runs on leaving combat.

If no keystone link is found in bags, the Mythic Plus owned-keystone challenge-map API is used as a fallback when available.

An incomplete scan (bags or API not ready) does not clear the last known player key.

Owned keystone level and map values are validated before cache or broadcast use.

Party member keystones arrive via key sync and are stored with a source (`keyf`, `libkeystone`, `libopenraid`, or `sync`).

A lower-priority source cannot change a party member's already-known key.

An empty party key (`K:0:0`) is ignored unless it stays empty for a short delay.

The local player's keystone is never overwritten by party sync.

Roster rebind updates unit tokens only. Stale party keys are pruned after the roster is complete and stable.

Holders for a dungeon come from the owned-keystone cache and are not hidden when a unit token is briefly missing.

Callers can request the current key for a unit and the list of holders for a dungeon map id.

`GetSyncPayload()` returns the wire-format key message for party broadcast.


