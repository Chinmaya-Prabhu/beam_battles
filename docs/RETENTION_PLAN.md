# Anime Clash — retention features (decided 2026-10-21)

1. **Free playtime gifts.** Each session restarts the timers. Gifts unlock at 5, 10, 15, 25, 40, 60 and 90 minutes: Ki, Cash, 2x Training, Ki, Cash, an Epic fighter, and at 90 minutes a **Legendary fighter** with the summon reveal.
   - The game always tells players about the 90-minute gift: a pop-up when they join and a "FREE LEGENDARY IN mm:ss" chip at the top of the HUD.
   - Code: `shared/Rewards.lua`, `server/Services/RewardsService.lua`, `client/Gifts.lua`.
2. **Daily streak.** One claim per UTC day, over 7 days: Cash, Ki, 2x Training, Cash, an Epic fighter, Ki, and a **Mythic fighter** on day 7.
   - Missing a day starts the streak again at day 1. After day 7 it keeps paying day 7.
   - The DAILY window opens itself when a claim is waiting.
3. **Server events.** Both run on the server clock, so every server runs them at the same time. Settings are in `Config.Events`; code is `server/Services/EventService.lua` and `client/Events.lua`.
   - **Secret Rush** at :07, :22, :37 and :52 past each hour. A hub altar is announced 30 seconds ahead, with a guide beam for everyone and a countdown over it. It then drops a guaranteed Mythic, or a Secret 25% of the time.
   - **Luck Storm** for the first 5 minutes of every hour: drops roll 3x rarer and the sky shifts colour.
4. **Training numbers and leaderboards.**
   - Click numbers heat up with a combo counter (colour and size grow with the combo).
   - Four all-time global boards by the spawn: Power, Steals, Cash collected and Rebirths, using OrderedDataStore. Code: `server/Services/LeaderboardService.lua`.
5. **Index.** A book of all 148 fighters by series, with silhouettes for ones never owned and pips for each mutation found.
   - Completing a series gives **+10% cash forever** and a **badge floating over the player's base**.
   - Code: `shared/Collection.lua`, `client/Index.lua`, `PlotService.setBadges`.
6. **Auras (next).**
   - Toolbox VFX packs, keeping only particles, beams and textures, with any scripts removed.
   - 7 aura tiers on the body.
   - Weights glow from Steel up, and the rebirth and premium weights get big effects.
   - At high Power the aura comes from both the body and the weights.

Studio tests (from the server command bar):
- `workspace:SetAttribute("DebugRush", true)` starts a Secret Rush now.
- `workspace:SetAttribute("DebugStorm", true)` starts a Luck Storm now.
