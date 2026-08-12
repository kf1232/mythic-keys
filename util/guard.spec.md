The guard wraps WoW API calls that may return secret values.
The guard returns scrubbed values that are safe to compare and format in Lua.
The guard reports when a call failed.
The guard reports when a return value was secret even if it was scrubbed.
The guard passes raw return values through for widget APIs that accept secrets natively.
The guard checks whether a value you already hold is usable in Lua logic.
The guard scrubs values without calling an API.
The party list uses the guard when reading player names and class colors.
The key data layer uses the guard when reading Mythic+ rating summaries.
The season dungeon list uses the guard when reading challenge mode map info.
