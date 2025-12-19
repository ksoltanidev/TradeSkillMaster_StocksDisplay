# TradeSkillMaster_StocksDisplay

A TradeSkillMaster addon module that displays a compact, draggable window showing your tracked item stocks at a glance.

![Interface: 30300](https://img.shields.io/badge/Interface-30300-blue)
![WoW Version: WotLK 3.3.5](https://img.shields.io/badge/WoW-WotLK%203.3.5-orange)

## Features

- **Floating Stock Window** - A compact, draggable window showing item icons with stock counts
- **Group Organization** - Create custom groups to organize your tracked items
- **Quick Add** - Alt+Click any item in your bags or chat links to add it to the display
- **Auto-Refresh** - Stock counts update automatically every 2 seconds
- **Comprehensive Tracking** - Shows totals from bags, banks, guild bank, personal bank, realm bank, and auctions
- **Export Functionality** - Export your tracked items and groups for backup or sharing

## Requirements

- [TradeSkillMaster](https://github.com/ksoltanidev/TradeSkillMaster_Ascension) (core addon)
- [TradeSkillMaster_ItemTracker](https://github.com/ksoltanidev/TradeSkillMaster_Ascension) (provides stock data)

## Installation

1. Download the addon
2. Extract to your WoW AddOns folder:
   ```
   World of Warcraft/Interface/AddOns/TradeSkillMaster_StocksDisplay/
   ```
3. Restart WoW or type `/reload` if in-game

## Usage

### Opening the Window

- Type `/tsm stocks` in chat
- Or click the StocksDisplay icon in the TSM sidebar

### Adding Items

**Alt+Click** on any item to add it to the display:
- Items in your bags
- Item links in chat
- Items in the auction house
- Any item tooltip

### Managing Items

- **Right-click** an item icon to open the context menu:
  - Move to a group
  - Remove from tracking

### Groups

Groups help organize your tracked items into categories (e.g., "Herbs", "Ores", "Enchants").

- Click **Add Group** in the header to create a new group
- Use **▲/▼** buttons to reorder groups
- Click **X** to delete a group (items move back to ungrouped)
- Right-click items to move them between groups

### Window Controls

- **Drag** the header to move the window
- Click **-** to collapse (shows only the header)
- Click **+** to expand
- Window position is saved between sessions

### Stock Count Format

Large numbers are abbreviated:
- `1k` = 1,000
- `2k5` = 2,500
- `10k` = 10,000

### Export

Click **Export** to generate a shareable string of your tracked items and groups. The format is:
```
ungrouped_id1,ungrouped_id2
GroupName1:id1,id2,id3
GroupName2:id4,id5
```

## Slash Commands

| Command       | Description                     |
|---------------|---------------------------------|
| `/tsm stocks` | Toggle the stock display window |

## Stock Sources

The addon aggregates item counts from all sources tracked by TSM_ItemTracker:

- Player inventory (bags)
- Player bank
- Alt characters
- Guild bank
- Personal bank (Ascension)
- Realm bank (Ascension)
- Active auctions

---

## Contributing

### Project Structure

```
TradeSkillMaster_StocksDisplay/
├── TradeSkillMaster_StocksDisplay.lua   # Main addon code
├── TradeSkillMaster_StocksDisplay.toc   # Addon metadata
├── Locale/
│   └── enUS.lua                         # English localization
└── README.md
```

### Architecture

The addon uses the AceAddon-3.0 framework and integrates with TSM via `TSMAPI:NewModule()`.

**Key Components:**

| Component          | Description                               |
|--------------------|-------------------------------------------|
| `TSM.db`           | AceDB-3.0 saved variables (profile-based) |
| `TSM.stockFrame`   | Main display window                       |
| `TSM.groupDialog`  | Group creation dialog                     |
| `TSM.contextMenu`  | Right-click item menu                     |
| `TSM.exportDialog` | Export text dialog                        |

**Saved Variables Structure:**

```lua
AscensionTSM_StocksDisplayDB = {
    profile = {
        trackedItems = {
            ["item:12345"] = "GroupName",  -- or "" for ungrouped
        },
        groups = { "Group1", "Group2" },   -- ordered list
        windowPos = { point = "CENTER", x = 0, y = 0 },
        collapsed = false,
    }
}
```

### Key Functions

| Function | Purpose |
|----------|---------|
| `TSM:AddTrackedItem(itemString)` | Add item to tracking |
| `TSM:RemoveTrackedItem(itemString)` | Remove item from tracking |
| `TSM:CreateGroup(name)` | Create a new group |
| `TSM:DeleteGroup(name)` | Delete a group |
| `TSM:SetItemGroup(itemString, groupName)` | Move item to group |
| `TSM:RefreshDisplay()` | Redraw the window |
| `TSM:ToggleWindow()` | Show/hide window |

### Adding Localization

1. Create a new file in `Locale/` (e.g., `deDE.lua`)
2. Copy the structure from `enUS.lua`
3. Replace the locale code and translate strings:
   ```lua
   local L = LibStub("AceLocale-3.0"):NewLocale("TradeSkillMaster_StocksDisplay", "deDE")
   if not L then return end

   L["Stocks"] = "Vorräte"
   -- etc.
   ```
4. Add the file to the `.toc` before the main lua file

### Testing

- No automated tests; test in-game
- Use `/reload` after code changes
- Check for Lua errors in the chat frame

### Code Style

- Use local variables where possible
- Follow existing naming conventions
- Add locale strings for any user-facing text
- Items are stored as TSM item strings (`"item:12345"`)

### Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test in-game on Ascension WoW
5. Submit a pull request with a clear description

## License

All Rights Reserved - See license information included with the TradeSkillMaster addon.
