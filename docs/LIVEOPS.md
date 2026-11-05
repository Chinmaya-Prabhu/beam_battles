# LiveOps

How Anime Clash stays fresh after launch without republishing. Code: `src/shared/LiveOps.lua` (data and
maths), `src/server/Services/LiveOpsService.lua` (runs it), `src/client/EventsPanel.lua` (EVENTS window),
`tools/liveops/push.py` (changes it from your terminal).

## The five parts

| Part | What players see | Where it lives |
|---|---|---|
| Event calendar | One event a week, rotating. Banner when it starts, chip at the top with the countdown | `LiveOps.Order`, `LiveOps.defaultEvent` |
| Remote config | Events, announcement and featured deals change live on every server | DataStore `LiveOps` / `config`, MessagingService topic `LiveOps` |
| Banner + panel | EVENTS tile: the running event, what's next, the announcement, weekly quests | `EventsPanel.lua`, `Events.lua` chip |
| Weekly quests | 5 quests every Monday (same for everyone), CLAIM each, all 5 open a chest with a Legendary fighter | `LiveOps.QuestPool`, `LiveOps.quests(week)` |
| Limited fighters | Bleach / JoJo fighters drop at the hub altars only during their event (20% of drops of a rarity they have). Index has a **Limited** page | `LiveOps.Events[*].fighters`, `DropService.eventFighter` |

## Events

| Key | Effect | When (default calendar) |
|---|---|---|
| DoubleDrops | altar luck ×2 | Fri 18:00 → Mon 00:00 UTC |
| SoulSociety | Bleach fighters, luck ×1.5 | whole week |
| MutationWeek | mutation chance ×3 | Fri 18:00 → Mon |
| GoldenRush | stand cash ×2 | Fri 18:00 → Mon |
| Bizarre | JoJo fighters, mutation ×1.5 | whole week |
| TrainingFrenzy | training ×2 | Fri 18:00 → Mon |

Weeks start Monday 00:00 UTC. The rotation repeats every 6 weeks. Effects reach the game through
ReplicatedStorage attributes `Live_dropLuck`, `Live_mutationLuck`, `Live_cash`, `Live_train`
(read with `LiveOps.mult(name)`).

## Changing things live (you run this, with your own key)

```bash
export ROBLOX_API_KEY=...      # Open Cloud key: DataStore read+write, Messaging publish, this universe only
export ROBLOX_UNIVERSE=<id>    # Creator Dashboard → the experience → Universe ID
python3 tools/liveops/push.py show
python3 tools/liveops/push.py event SoulSociety 2026-11-07T18:00 2026-11-10T00:00   # UTC
python3 tools/liveops/push.py clear-events
python3 tools/liveops/push.py announce "Bleach invasion this weekend!"
python3 tools/liveops/push.py feature SummonMythic ProBundle ServerLuck
python3 tools/liveops/push.py code SPIRIT boost cash --expires 2026-11-14T17:00   # a new code, live
python3 tools/liveops/push.py uncode SPIRIT
python3 tools/liveops/push.py update 2026-11-07T17:00 "SPIRIT TEMPLE" "Final Aizen awaits"   # the hub board
python3 tools/liveops/push.py clear-update
```

Codes (`src/shared/Codes.lua`, the CODES tile) and the update board (`src/client/UpdateBoard.lua`, left of the
spawn path; it counts down to every Saturday 17:00 UTC by default) are part of the same config. The weekly
plan is in `docs/CONTENT_CALENDAR.md`.

A scheduled event overrides the default calendar while it runs. Servers reload within seconds (MessagingService)
or within a minute (polling). Config format:

```json
{ "schedule": [ { "key": "DoubleDrops", "start": 1793000000, "finish": 1793259200 } ],
  "announcement": "Bleach week starts Friday!",
  "featured": [ "SummonMythic", "ProBundle" ] }
```

`featured` takes product keys from `src/shared/Products.lua`. They show as **THIS WEEK'S DEALS** at the top of
the shop's FEATURED tab (hidden when empty).

## Adding content

- **A new event:** add it to `LiveOps.Events` (title, desc, color, effects, optional fighters) and to `LiveOps.Order`.
- **New limited fighters:** add them to `tools/pack/launch.json` as exclusives (kept out of normal pools), then list
  them in the event's `fighters`.
- **New quests:** add to `LiveOps.QuestPool`. `metric` is any `Goals.metric` name; progress counts from the week's start.

## Studio testing (server command bar)

```lua
workspace:SetAttribute("DebugEvent", "SoulSociety")                 -- run an event for 30 min ("" clears)
workspace:SetAttribute("DebugFeatured", "SummonMythic,ProBundle")   -- stand-in for the config's deals
game.Players:GetPlayers()[1]:SetAttribute("DebugWeekly", true)     -- fill this week's quests
```

MessagingService doesn't work in Studio without API access. The service carries on without it.

## Verified in Play (2026-10-22)

Event chip and banner, the EVENTS window (event card, coming up, quests, reset timer), the deals row,
the Index Limited page (0/17), claiming all 5 quests (rewards paid), and the weekly chest (Legendary reveal).
Not yet seen live: a limited fighter dropping (20% roll), and push.py against the real universe.
