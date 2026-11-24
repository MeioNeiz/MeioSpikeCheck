# Meio Spike Check

Finds out which addon is behind the stutters and freezes in your game.

![Chat after /spikes: each long frame printed with its time as it happened, one marked
(combat), then the report: frames over 50 and 100 ms for the whole game and for all addons,
and the addons with the most long frames, Questie first](docs/hero.png)

## What it does

Type `/spikes start`, play as usual, then type `/spikes` for a report of what was slow.

- Each frame over 100 ms is printed in chat with the time, so you can match it to what you
  were doing; `(combat)` marks the ones in a fight
- The report: long frames for the whole game, for all addons together, and the addons with
  the most, with each one's worst frame
- Idle until you start it; loading screens don't count
- Per-addon counts need the game's addon profiler: `/spikes` says how to turn it on

No settings.

- `/spikes start [ms]`: start counting; print each frame over ms (100 by default)
- `/spikes`: the report since start; before a start, how it works
- `/spikes stop`: stop printing frames (counting goes on)
- `/spikes off`: stop counting
- `/spikes help`

## Install

Use your addon manager (CurseForge, Wago), or unzip a GitHub release into
`World of Warcraft\_forever_\Interface\AddOns` and restart WoW fully.

## Feedback

Bugs and ideas: [GitHub issues](https://github.com/MeioNeiz/MeioSpikeCheck/issues)

## More Meio addons

[Meio TrainerCompare](https://www.curseforge.com/wow/addons/trainercompare) | [Meio Next Stop](https://www.curseforge.com/wow/addons/leavebutton) | [Meio AutoRank](https://www.curseforge.com/wow/addons/meio-autorank) | [Meio MeterHover](https://www.curseforge.com/wow/addons/meterhover) | [Meio Map](https://addons.wago.io/addons/meiomap) | [Meio Alts](https://addons.wago.io/addons/meioalts) | [Meio DPS](https://addons.wago.io/addons/meiodps) | [Meio Plates](https://addons.wago.io/addons/meioplates) | [Meio Hub](https://addons.wago.io/addons/meiohub) | [Meio Pets](https://addons.wago.io/addons/meiopets) | [Meio Stats](https://addons.wago.io/addons/meiostats) | [Meio Bags](https://addons.wago.io/addons/meiobags) | [Meio Fixes](https://addons.wago.io/addons/meiofixes) | [Meio Flight Times](https://addons.wago.io/addons/meioflighttimes)

## Licence

[MIT](LICENSE)
