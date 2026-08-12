Optional bridges consume party keystone data from other addons and merge it into the owned-keystone cache.
LibKeystone (bundled with DBM-Core) registers a callback for party keystone updates.
LibOpenRaid (bundled with Details) registers for KeystoneUpdate callbacks and can import cached party keystone info on login.
ExternalKeystones validates sender, level, and map before calling OwnedKeystone.SetParty.
External sources use the same party-member checks and Validate rules as native KeyF sync.
Party keystone requests from key sync also request data from every active external provider.
Providers are detected lazily on addon load and PLAYER_ENTERING_WORLD.
DBM-Core and Details are optional; the addon works without them via KeyF sync.
