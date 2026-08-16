# PotatoUI

PotatoUI is a compact, opinionated interface addon built specifically for the [Emberveil](https://emberveil.org/) private World of Warcraft server. It replaces several parts of the default UI with a clean, space-efficient layout and includes a few quality-of-life features tailored to Emberveil's client.

> PotatoUI targets Emberveil and is not intended for retail WoW, Classic, or other private-server clients.

![PotatoUI interface](https://media.repulsion.co.uk/r/ZSNFI5.jpg?compress=false)

![PotatoUI interface and bags](https://media.repulsion.co.uk/r/UqG8pW.png?compress=false)

## Features

- Two-row central action bar with support for paging, stances/forms, and pet actions
- Custom player, target, party, and pet frames
- Buff and debuff displays with stack counts and duration timers
- Player cast bar and compact XP/rested-XP bar
- Combined bag window with free-space and money displays
- Draggable bag window with its position saved between sessions
- Equipped-bag management from the combined bag window
- Automatic sale of grey-quality items when visiting a merchant
- Automatic looting, including retry handling for Emberveil gathering nodes
- Simplified minimap with zone text and mouse-wheel zoom
- Gold, clock, FPS, and latency data text
- Revealed world-map overlays, including Emberveil's custom zones

## Installation

1. Download or clone this repository.
2. Place the addon folder in your Emberveil installation's `Interface\AddOns` directory.
3. Make sure the final path is `Interface\AddOns\PotatoUI\PotatoUI.toc`—not a nested directory such as `PotatoUI-main\PotatoUI`.
4. Restart the client, then enable **PotatoUI** from the AddOns menu on the character-selection screen.

To clone it directly into the addon directory:

```sh
git clone https://github.com/PotatoAnimation/PotatoUI.git PotatoUI
```

PotatoUI has no external addon dependencies.

## Commands

Use `/pui` or `/potatoui` in chat.

| Command | Description |
| --- | --- |
| `/pui` | Show the installed version and available commands |
| `/pui bags` | Toggle the combined bag window |
| `/pui scale 0.7-1.3` | Set the scale of the action, player, and target frames |
| `/pui reload` | Reload the user interface |
| `/pui reset` | Reset PotatoUI settings and reload the interface |

## Usage notes

- PotatoUI replaces the normal backpack and bag windows with one combined window. Drag its header to reposition it.
- Grey-quality items with a known vendor value are sold automatically when a merchant window opens.
- Loot is collected automatically. Hold **Shift** while looting—or while beginning a gathering cast—to use the normal manual loot window instead.
- Settings are stored per installation in the `PotatoUIDB` saved-variable table.

## Compatibility

The addon currently declares Emberveil interface version `11200` and is developed against the APIs exposed by the Emberveil client. Client updates may require corresponding addon changes.

## Feedback and contributions

Bug reports and contributions are welcome through the repository's [GitHub issues](https://github.com/PotatoAnimation/PotatoUI/issues) and pull requests. When reporting a problem, include the PotatoUI version, what you were doing when it occurred, and any Lua error text shown by the client.
