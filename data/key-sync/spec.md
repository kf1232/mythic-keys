Party keystone sync uses the `KeyF` addon message prefix on PARTY or RAID channels.
The local player broadcasts `K:<level>:<mapChallengeModeID>` or `K:0:0` when no key is owned.
Sending `R` requests peers to re-broadcast their current key payload.
Roster changes debounce a sync push and a follow-up request 3 seconds later.
Inbound messages are accepted only from current group members on PARTY or RAID channels.
Party keystone requests from key sync also request data from every active external provider.
Inbound level and map values are validated before updating the party keystone cache.
The local player's key always comes from bag/API scan, never from inbound sync.
Leaving the group clears cached party keystones and local sync state.
Party keystones are stored in the owned-keystone cache keyed by member GUID.
