# DEValueTooltip

A WoW Forever addon that adds disenchant (DE) results and Auctionator auction house prices directly to item tooltips.

## Features

- Shows what an item disenchants into (dust, essences, shards, Nexus Crystals)
- Shows the percentage chance for each possible result
- Pulls live AH prices for enchanting materials from **Auctionator's** saved data
- Displays average expected value based on quantity range
- Works on all uncommon (green), rare (blue), and epic (purple) armor and weapons
- Handles armor vs. weapon drop rate differences correctly:
  - **Armor:** 75% dust / 20% essence / ~4% shard
  - **Weapons:** 20% dust / 75% essence / ~4% shard

## Installation

1. Download or copy the `DEValueTooltip` folder.
2. Place it in your WoW Forever addons directory:
   ```
   World of Warcraft\_forever_\Interface\AddOns\DEValueTooltip\
   ```
3. Restart WoW or type `/reload` in-game.
4. **Auctionator must be installed and have scanned the AH** at least once for price data to appear.

## Requirements

- **WoW Forever** (Classic-era, level 60 cap)
- **Auctionator** addon installed and with at least one AH scan completed

## Disenchant Table (WoW Forever)

Data sourced from [wow-professions.com/forever/disenchanting-guide](https://www.wow-professions.com/forever/disenchanting-guide).

| Required Level | Dust | Essence | Shard / Crystal |
|---|---|---|---|
| 1–10 | Strange Dust (1–2) | Lesser Magic Essence (1–2) | — |
| 11–15 | Strange Dust (2–3) | Greater Magic Essence (1–2) | Small Glimmering Shard |
| 16–20 | Strange Dust (4–6) | Lesser Astral Essence (1–2) | Small Glimmering Shard |
| 21–25 | Soul Dust (1–2) | Greater Astral Essence (1–2) | Large Glimmering Shard |
| 26–30 | Soul Dust (2–5) | Lesser Mystic Essence (1–2) | Small Glowing Shard |
| 31–35 | Vision Dust (1–2) | Greater Mystic Essence (1–2) | Large Glowing Shard |
| 36–40 | Vision Dust (2–5) | Lesser Nether Essence (1–2) | Small Radiant Shard |
| 41–45 | Dream Dust (1–2) | Greater Nether Essence (1–2) | Large Radiant Shard |
| 46–50 | Dream Dust (2–5) | Lesser Eternal Essence (1–2) | Small Brilliant Shard |
| 51–55 | Illusion Dust (1–2) | Greater Eternal Essence (1–2) | Large Brilliant Shard / Nexus Crystal |
| 56–60 | Illusion Dust (2–5) | Greater Eternal Essence (1–3) | Large Brilliant Shard / Nexus Crystal |

Blues always give 1 shard. High-level epics (51+) give a Nexus Crystal. Epics ≤50 give a shard.

## Auctionator Compatibility

The addon reads `AUCTIONATOR_PRICE_DATABASE`, the global SavedVariable that Auctionator writes after AH scans. It tries three key formats used across Auctionator versions:

1. Flat `["Item Name"] = copper` (older versions)
2. Nested `["RealmName-Faction"]["Item Name"] = copper` (common classic format)
3. Nested `["RealmName"]["Item Name"] = copper` (some ports)

If prices don't show up, make sure Auctionator has done a full scan recently.

## Tooltip Display Example

```
[Disenchant]  ilvl 42
Vision Dust x1-2 (75%)
    AH: 3s 50c ea  avg value: 5s 25c
Greater Mystic Essence x1-2 (20%)
    AH: 45s 00c ea  avg value: 67s 50c
Large Glowing Shard (4%)
    AH: 2g 10s ea
```

## Notes

- The addon hooks `OnTooltipSetItem` on `GameTooltip`, `ItemRefTooltip`, `ShoppingTooltip1`, and `ShoppingTooltip2`.
- No configuration needed; it works automatically on load.
- The disenchant data is hardcoded from the published WoW Forever DE table. If Blizzard changes drop rates in a patch, the `DE_TABLE` in `DEValueTooltip.lua` will need updating.
