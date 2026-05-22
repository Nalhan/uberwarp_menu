# uberwarp_menu

A searchable, interactive ImGui menu for FFXI Ashita v4 that integrates with the **Uberwarp** plugin to teleport using **Home Points** and **Survival Guides**.

## Features
* **Dual Tabs**: Switch between Home Points and Survival Guides instantly.
* **Proximity Locking**: Warp buttons are locked unless you are within 6.0 yalms of the selected NPC type.
* **Smart Latch**: Menu stays closed if manually dismissed next to an NPC, re-opening only when you leave and re-enter proximity.
* **Auto-open/close**: Configurable proximity-based menu visibility.
* **Fuzzy Filtering**: Instantly search by zone name or specific warp alias.

## Slash Commands
* `/uwm` or `/uwmenu` - Toggles menu visibility.

## Installation
1. Place the `uberwarp_menu` folder in your Ashita `addons/` directory.
2. Load it in-game:
   ```text
   /addon load uberwarp_menu
   ```
