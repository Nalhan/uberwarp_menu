# Uberwarp Menu

A searchable, modern ImGui travel menu addon for **FFXI Ashita v4** designed to interface seamlessly with the **Uberwarp** plugin.

## 🌟 Features

* **All 10 Travel Systems**: Supports Home Points, Survival Guides, Waypoints, Proto-Waypoints, Unity Concord, Eschan Portals, Abyssea Confluxes, Abyssea Warps, Runic Portals, and Elvorseal.
* **Smart Dynamic Tabs**: Automatically scans for local Uberwarp XML files and only displays tabs for the systems you actually have configured.
* **Proximity Locking**: Dynamically checks proximity and locks destination buttons to prevent accidental clicks unless you are within 6.0 yalms of the respective NPC.
* **Search Aliasing**: Built-in colloquial and regional search filters (e.g., searching `sandy` matches San d'Oria, `cop` matches Promathia, `toau` matches Aht Urhgan).
* **Robust Customization**: Features live transparency adjustments and dynamic menu/layout scaling slider designed to bypass Ashita ImGui font scaling limits.
* **Smart Latch**: Remembers manual window closures so the menu stays closed until you walk away and re-enter NPC proximity.

## ⌨️ Slash Commands

| Command | Action |
|---|---|
| `/uwm` | Toggle the menu visibility |
| `/uwmenu` | Toggle the menu visibility |

## ⚙️ Installation & Usage

1. Copy the `uberwarp_menu` folder into your Ashita `addons/` directory.
2. In-game, load the addon:
   ```text
   /addon load uberwarp_menu
   ```
3. Open the menu with `/uwm`. Enjoy!
