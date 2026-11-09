# Launch check, 2026-11-07

## Fixed
- Offline earnings: WELCOME BACK showed an amount but COLLECT paid nothing (load event passed a copy of the save).
- The same bug: first zone visits weren't saved, so the Enter Blossom goal never finished, and the tutorial timer never started.
- Rejoining during the take-it-home step left the player with no arrow.
- Flicker layers: Blossom yard and plazas, base floors, running track, gym court, belt arrows, station mats.
- Ki missing from the HUD.
- The next-step line hid behind the NEW AREA card.

## Checked in Studio (desktop size, test save)
Tutorial start to finish, with some walking replaced by teleports; first fight; Blossom card and auto close; next-step line; arrow; first arrival at Ninja, Pirate and Walled.

## Not checked
- Phone-size screens
- Guardian and boss fights, and the guardian rewards
- Carrying block, second-tap training, and Rock Lee and Hellflame in the world
- Rebirth, real purchases, stealing and the lock tip
- The last fixes after the final scan: station mats, gym lines, belt arrows, NEW AREA line
- Vertical surfaces (the scan covers floors and tops only)

## Open
- About 52,000 flat parts in the world: check frame rate on a low-end phone.
- One fighter's whiskers texture fails to load (asset 578392296).
