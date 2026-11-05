# Anime Clash — UI art brief

Every UI image the game needs, as 10 sheets plus the store and marketing images. You generate the sheets; I cut them, clean them up and wire them in.

## How to deliver
- **Grid:** each sheet is a **4 columns × 3 rows** grid of **12 separate objects**, in the order listed (left to right, top to bottom). Objects must not touch each other or the cell edges.
- **Background:** plain **soft cream (#FBF3E4)**, completely flat: no gradient, no ground shadows. I flood-fill it away from the edges and the thick navy outline stops the fill, so every outline must be unbroken. Transparent PNG is even better if your generator supports it.
- **Size:** square, as large as the generator allows (2048×2048 ideal, 1024×1024 is fine).
- **Text:** none, except where a cell says so (the game font draws all labels).
- **View:** flat, front-facing; no perspective tilt on buttons and frames.
- **Where:** put the files in `art/ui_sheets/` named as below (`01_core_icons.png` …). If a generator mangles one cell, regenerate just that cell and send it separately.

**What I do with them:** cut each object, remove the background and trim it, then pack each sheet into one 1024 atlas for Roblox (fewer uploads; the game picks icons from it), and make the separate 512×512 store icons. Uploading to Roblox needs your account: either a Studio bulk import (you pick the folder) or a small upload script I write that you run with your own Open Cloud key.

## Art style (the same for every sheet)
- Chunky, glossy, toy-like 3D-rendered game icons, the look of the top Roblox simulator games: big readable shapes, soft rounded forms, bright top highlight, gentle bottom shade.
- **A thick dark navy outline (#1F2A44)** round every object, about 4% of the object's size. It matches the game's text outlines.
- Saturated colours with a light anime touch: small sparkles, a few speed lines on action icons, and a subtle LEGO stud detail where it fits (the world is all studded bricks).
- **Light and bright, no purple UI.** Windows and cards are white or warm cream with sky-blue or gold header bands, like the friendliest Roblox games.
- **Palette:** panel white #FFFFFF, cream #FFF6E0, sky blue #6EC8FF / light sky #CDEBFF, gold #FFCD3C, cash green #50C86E, red #F05A50, Ki cyan #6EE6FF, Power yellow-orange #FFB020, outline navy #1F2A44. (Purple appears only as the Epic rarity and Master aura colours, never on frames.)
- Readable at 48 px: one clear silhouette per icon, no tiny details.

**Style block — paste this at the start of every sheet prompt:**
> Game UI asset sheet for a bright Roblox anime simulator. Chunky glossy toy-like 3D-rendered icons, soft rounded shapes, strong top highlight, thick dark navy outline (#1F2A44) around every object, bright cheerful saturated colors, light airy palette, no purple, light anime sparkle accents, subtle LEGO-stud details. Exactly 12 separate objects arranged in a 4-column by 3-row grid, evenly spaced, each centered in its cell, not touching each other or the edges. Plain soft cream background (#FBF3E4), completely flat, no gradient, no ground shadows, no reflections, no scenery. Front view, no perspective. No text, letters or numbers unless specified. Square image.

---

## Sheet 01 — Core icons · `01_core_icons.png`
Used for HUD stats, goals, banners and prompts.

> [style block] The 12 icons in order: 1) a stack of green cash bills with a gold coin in front; 2) a yellow-orange lightning-bolt fist (Power); 3) a glowing cyan spirit flame inside a round orb (Ki energy); 4) a golden five-point star with a swirl of light around it (rebirth); 5) a white cartoon hand cursor clicking with small impact lines; 6) a round gold alarm clock (timer); 7) a chunky gold padlock, closed; 8) a blue heater shield with a gold rim; 9) a sneaky grabbing hand holding a small glowing orb (steal); 10) a gold trophy cup; 11) a gold crown with gems (champion); 12) a pair of crossed red boxing-style fists with an impact star (clash).

## Sheet 02 — Menu button icons · `02_menu_icons.png`
Icons sitting on the square HUD buttons (the button tiles are on sheet 03).

> [style block] The 12 icons in order: 1) a shop bag with a gold coin (shop); 2) a small red Japanese torii gate with a house roof behind it (home base); 3) a golden phoenix rising in a circle (rebirth); 4) a robot arm punching with a small gear (auto train); 5) an unrolled parchment scroll with a checkmark (goals/quests); 6) an open book with a fighter silhouette (index/collection); 7) a wrapped present with a gold bow (gifts); 8) a cog wheel (settings); 9) a bold white X in a red circle (close); 10) a white left-pointing arrow in a blue circle (back); 11) a white plus sign in a green circle (buy/add); 12) a white checkmark in a green circle (done).

## Sheet 03 — Frames and buttons (9-slice) · `03_frames.png`
Shapes only, no icons and no text, with even borders so they stretch cleanly.

> [style block] Empty UI frames, flat front view, perfectly symmetrical, uniform border thickness, no text, no icons. The 12 items in order: 1) a wide pill-shaped button, glossy gold; 2) the same pill button, cash green; 3) the same pill button, red; 4) the same pill button, cool grey (disabled); 5) a rounded-square icon button tile, white with a gold rim; 6) a rounded-square icon button tile, light sky blue with a white inner rim; 7) a large rounded-rectangle modal window, white body with a soft cream inner edge, a thick navy outline and a sky-blue header band across the top; 8) a rounded product card, warm cream with a gold rim; 9) a long empty progress bar track, light grey-blue, rounded ends; 10) the matching progress bar fill, glossy gold, rounded ends; 11) a white rounded speech bubble with a small tail at the bottom left; 12) a red circular notification badge (small dot).

## Sheet 04 — Store icons · `04_store_icons.png`
Shop cards in game, and the Creator Dashboard gamepass and product icons. Roblox shows gamepass icons cropped to a **circle**, so keep each icon inside a centred circle with margin.

> [style block] Store icons, each a bold emblem kept inside a centered circular area with margin. The 12 in order: 1) a golden VIP crown with the letters "VIP" on a ribbon; 2) a pile of green cash with a big glossy "2X" badge; 3) a lightning fist with a big glossy "2X" badge; 4) a robot fist punching a punching bag, a small gear (auto train); 5) a blurred running hand grabbing a glowing orb with speed lines (fast steal); 6) a golden four-leaf clover with sparkles and a "2X" badge (server luck); 7) a stopwatch with a lightning bolt (2x training, 15 minutes); 8) a glowing blue dome shield over a small house (base shield); 9) a small bundle of cash with a few coins (cash pack); 10) an overflowing treasure vault door with cash and coins (cash vault); 11) a gold pedestal with a "+" sparkle above it (next stand); 12) a gift box spilling stars (starter pack, for later).

## Sheet 05 — Rarity and mutation tags · `05_rarity_tags.png`
Small ribbons on nameplates, cards and drop banners (the game font writes the word).

> [style block] Empty horizontal ribbon banners and small badges, no text. The 12 in order: 1) a grey ribbon (Common); 2) a green ribbon (Uncommon); 3) a blue ribbon (Rare); 4) a purple ribbon with small sparkles (Epic); 5) a gold ribbon with a glow (Legendary); 6) a crimson-red ribbon with a flame edge (Mythic); 7) a white-and-rainbow holographic ribbon with stars (Secret); 8) a small round gold coin badge (Golden mutation); 9) a small cut-diamond badge, icy blue (Diamond mutation); 10) a small rainbow swirl badge (Rainbow mutation); 11) a small badge with a big upward arrow, orange (Huge mutation); 12) a plain white rounded tag (generic).

## Sheet 06 — Training gear icons · `06_gear_icons.png`
One per tier: wrist weights seen as a single chunky band.

> [style block] Chunky wrist training weights (a thick cuff band), one per cell, rising in quality: 1) wrapped white cloth bandage; 2) a wooden cuff with iron bands; 3) a rough grey stone cuff; 4) a dark iron cuff with rivets; 5) a polished steel cuff with a bright band; 6) a shining gold cuff; 7) a dark navy cuff with glowing cyan seal glyphs (chakra seals); 8) a teal sea-stone shackle with a short chain and a green glow; 9) a faceted crystal-diamond cuff, sparkling; 10) a black cuff with two glowing purple rings orbiting it (gravity rings); 11) the cuff as a dark locked silhouette with a small padlock (locked); 12) a question-mark silhouette cuff (unknown).

## Sheet 07 — Rank emblems · `07_rank_emblems.png`
The aura ranks, for the HUD, the overhead plate and power-up banners.

> [style block] Round emblem medallions for anime power ranks, each a circular badge with a stylized flame aura inside, rising in intensity: 1) a plain grey medallion with a small white wisp (Rookie); 2) a white wisp flame (Trainee); 3) a blue flame (Fighter); 4) a gold flame with sparks (Super); 5) a crimson flame with lightning (Elite); 6) a violet flame with a dust ring (Master); 7) a silver-white glowing flame with floating rocks (Ultra); 8) a rainbow flame with stars (God); 9) a gold rebirth star medallion; 10) a gold medallion with a laurel wreath (top player); 11) a red medallion with crossed fists (clash wins); 12) a teal medallion with a grabbing hand (master thief).

## Sheet 08 — Clash UI · `08_clash_ui.png`
The rally fight screen.

> [style block] Fighting-game UI pieces: 1) a big round DEFLECT action button, blue and glossy with a shield-burst symbol, no text; 2) a big round SMASH action button, orange-red with a fist-impact symbol, no text; 3) the same SMASH button fully charged, glowing gold with crackling energy; 4) a glowing white-blue energy orb (the projectile); 5) a thin glowing target ring (where to deflect); 6) a "VS" badge with lightning; 7) an empty round-win pip (dark circle); 8) a filled round-win pip (gold star in a circle); 9) a stylized letter "S" grade in gold with sparkles; 10) a stylized letter "A" grade in silver; 11) a stylized letter "B" grade in bronze; 12) a circular portrait frame (empty center, gold rim) for fighter faces.

## Sheet 09 — Tutorial and feedback · `09_ftue.png`
For the first-time experience and reward moments.

> [style block] Tutorial and reward pieces: 1) a white cartoon pointing hand, index finger tapping, with tap rings; 2) a big glossy green chevron arrow pointing down (ground marker); 3) a big glossy gold chevron arrow pointing right; 4) a closed gift box, red with a gold bow; 5) the same gift box bursting open with light and stars; 6) a closed wooden treasure chest with gold trim; 7) the same chest open, overflowing with coins and gems; 8) a starburst explosion shape, yellow (for "NEW!" pops); 9) a cluster of colorful confetti pieces and streamers; 10) a sparkle burst of white and gold four-point stars; 11) a red exclamation mark in a circle (attention); 12) a small glowing beacon pillar of light (marker over a target).

## Sheet 10 — Zone emblems · `10_zone_emblems.png`
Title cards, gate signs, goals and a future teleport menu.

> [style block] Round emblem medallions, one per location: 1) a red torii gate with a pagoda behind it (the hub, Sky Dojo); 2) a pink cherry blossom over a school building (Blossom Academy); 3) a ninja headband with a swirl leaf plate, crossed kunai (Ninja Village); 4) a pirate skull with a straw hat and crossed swords over waves (Pirate Bay); 5) a giant stone wall with a towering titan face peeking over (Walled City); 6) the same medallion shape, dark and locked with a padlock (locked zone); 7) a glowing swirling portal (travel); 8) a red boss skull with horns (boss); 9) a guardian helmet with a shield (guardian); 10) a dragon head coiled in a circle (the dragon, for events); 11) a question-mark medallion (coming soon); 12) a colosseum arena (main event).

---

## Marketing (separate images, not sheets)
- **Game icon (512×512, 1:1):**
  > Roblox game icon, bright glossy 3D cartoon style. A chunky blocky Roblox-style anime hero with a blazing gold aura, mid-punch toward the viewer, a beam clash of blue and red energy behind them, speed lines, a floating brick island with a pagoda in the background. Huge readable silhouette, thick dark outline, saturated colors, no text.
- **Thumbnails (1920×1080, 16:9), 3 of them:**
  1. Two blocky anime fighters in a beam clash over a glowing altar, a huge rainbow fighter dropping from the sky behind them, a crowd of players around.
  2. A player running across a rope bridge carrying a glowing stolen fighter over their head, another player chasing, bases on floating islands.
  3. A player with a giant rainbow aura and gravity-ring wrist weights, mid power-up scream, rocks floating, a shockwave on the ground.

  Same style, no text; I add the title text in-game style.

## What I'll do with them
- Replace the text buttons (SHOP, BASE, AUTO, REBIRTH) with icon tiles and labels.
- Rebuild the shop and rebirth windows with the frames and store icons.
- Add the stat icons to the HUD, rarity ribbons on nameplates and drop banners, gear icons in the stall prompts, rank emblems on the HUD and plates, and zone emblems on title cards.
- Use the clash buttons, orb, ring, pips and grade letters in the rally screen.
- Use the tutorial pieces for the FTUE (built next).
