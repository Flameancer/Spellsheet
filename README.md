# Spellsheet

A macOS spell sheet for Dungeons & Dragons 5th Edition. It loads classes, subclasses, and spells from the [5e.tools dataset](https://github.com/5etools-mirror-3/5etools-src) and opens each spell on [5e.tools](https://5e.tools/).

The site itself sits behind a browser check, so the app reads the same JSON the site publishes. Spell text stays on your Mac only as a cache and is still Wizards of the Coast material.

## What it tracks

- One or more classes, including 2014 and 2024 printings, subclasses, and named options such as a Land druid’s terrain.
- Ability scores, the class’s spellcasting ability, proficiency bonus, **spell save DC** (8 + proficiency + ability modifier), and **spell attack** (proficiency + ability modifier).
- Prepared or known spells, always-prepared subclass spells, and optional class lists from books such as Xanathar’s and Tasha’s.
- Spell slots from the multiclass caster-level table, with pact magic kept separate. Click a pip to spend or restore a slot. Long rest clears them.
- The spell description, and the higher-level or cantrip scaling text when the data includes it.

Eldritch Knight and Arcane Trickster use their subclass spell lists. Fighter and rogue do not cast until you pick one of those subclasses.

## Build and open

```sh
cd ~/Spellsheet
swift run SpellsheetChecks
./scripts/bundle-app.sh
open Spellsheet.app
```

The first launch downloads the class and spell JSON. Later launches use the cache in `~/Library/Application Support/Spellsheet` and refresh it after a week, or whenever you choose Refresh 5e.tools.

`SPELLSHEET_LIVE=1 swift run SpellsheetChecks` also downloads the live dataset and checks Fireball, its higher-level text, and the wizard’s Intelligence casting.
