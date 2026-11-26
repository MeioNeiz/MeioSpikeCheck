# Meio Spike Check

Game stuttering? Meio Spike Check names the addon behind each freeze, worst first.

For WoW Forever.

![The MeioSpikeCheck window: frames over 50 and 100 ms for the whole game, then the addons
with the most long frames, Questie first in orange with its worst frame of 182 ms and memory
up 3.5 MB, each with a Turn off button](docs/hero.png)

## What it does

Type `/spikes start`, play as usual, then `/spikes` opens the report.

- The addons with the most long frames, worst first, with each one's worst frame and how
  much its memory grew
- **Turn off** an addon for the next reload, right from the report, to see if the stutter
  goes; **Turn on** puts it back
- The report from before your last `/reload` stays in the window until you start again
- Each frame over 100 ms is printed in chat with the time, so you can match it to what you
  were doing; `(combat)` marks the ones in a fight
- Idle until you start it; loading screens don't count
- Per-addon counts need the game's addon profiler: the window has a button that turns it
  on and reloads

![The same report in chat](docs/report-chat.png)

- `/spikes`: open the report window
- `/spikes start [ms]`: start counting; print each frame over ms (100 by default)
- `/spikes report`: the report in chat
- `/spikes stop`: stop printing frames (counting goes on)
- `/spikes off`: stop counting
- Settings (print each frame, threshold): Esc > Options > AddOns > MeioSpikeCheck

## Install

Use your addon manager (CurseForge, Wago), or unzip a GitHub release into
`World of Warcraft\_forever_\Interface\AddOns` and restart WoW fully.

## Feedback

Bugs, ideas or just a thumbs up: leave a comment on the CurseForge or Wago page you got it from. [GitHub issues](https://github.com/MeioNeiz/MeioSpikeCheck/issues) are welcome too.

## More Meio addons

[Meio Trainer Compare](https://www.curseforge.com/wow/addons/trainercompare) | [Meio Next Stop](https://www.curseforge.com/wow/addons/leavebutton) | [Meio Auto Rank](https://www.curseforge.com/wow/addons/meio-autorank) | [Meio Meter Hover](https://www.curseforge.com/wow/addons/meterhover) | [Meio Map](https://addons.wago.io/addons/meiomap) | [Meio Alts](https://addons.wago.io/addons/meioalts) | [Meio DPS](https://addons.wago.io/addons/meiodps) | [Meio Nameplates](https://addons.wago.io/addons/meioplates) | [Meio Hub](https://addons.wago.io/addons/meiohub) | [Meio Pets](https://addons.wago.io/addons/meiopets) | [Meio XP Meter](https://addons.wago.io/addons/meiostats) | [Meio Bags](https://addons.wago.io/addons/meiobags) | [Meio Fixes](https://addons.wago.io/addons/meiofixes) | [Meio Flight Times](https://addons.wago.io/addons/meioflighttimes) | [Meio Tooltips](https://addons.wago.io/addons/meiotooltipfold) | [Meio Autorun](https://addons.wago.io/addons/meioautorunturn) | [Meio Mail](https://addons.wago.io/addons/meiomail) | [Meio QoL](https://addons.wago.io/addons/meioqol) | [Meio TSM Browse](https://addons.wago.io/addons/tsmbrowse) | [Meio Shards](https://addons.wago.io/addons/meioshards) | [Meionomics](https://www.curseforge.com/wow/addons/meionomics) | [Meio BiS Extras](https://addons.wago.io/addons/meiobisextras) | [Meio Buff Thanks](https://addons.wago.io/addons/meiobuffthanks) | [Meio Flare Fixes](https://addons.wago.io/addons/meioflarefixes) | [Meio Flare Questie](https://addons.wago.io/addons/meioflarequestie)

## Licence

[MIT](LICENSE)
