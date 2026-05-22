# Uberwarp ImGui Menu (`uberwarp_menu`)

An extremely polished, premium, and aesthetically rich Ashita v4 addon that displays a searchable, interactive ImGui menu of all valid **Home Point** and **Survival Guide** warp locations in *Final Fantasy XI*.

When a player is near an NPC, they can search for a destination and click it to execute a warp via the `Uberwarp` plugin commands `/uw hp <destination>` or `/uw sg <destination>`.

---

## 🌟 Key Features

1. **Dual System Integration (Home Points & Survival Guides)**:
   - Separate tabs inside a single consolidated ImGui window let you switch systems instantly.
   - Loads and parses `homepoint.xml` and `survivalguide.xml` automatically from your Uberwarp resources.
   - Resolves all FFXI zone IDs to their official game names dynamically.

2. **Advanced Tabbed UI**:
   - Integrated a modern tab bar (`BeginTabBar` / `BeginTabItem`) for clean segmentation.
   - Adaptable search input placeholder and descriptive text (e.g. `Search Home Points:` or `Search Survival Guides:`).
   - Unified listing rendering logic using a robust DRY helper for performance and visual consistency.

3. **Active Dual Proximity Locking & Smart Latch**:
   - A background scanner constantly runs entity tracking for **both** `"Home Point"` and `"Survival Guide"` NPCs in range.
   - **Smart Latch**: If you manually close the menu (clicking "X" or using `/uwm`) while standing next to an NPC, the addon respects your choice and stays closed! The auto-open will only trigger again once you leave and re-enter the 6.0 yalms NPC range.
   - The top status bar dynamically updates to match the **currently selected tab** (showing distance/status for Home Points when that tab is active, and for Survival Guides when that tab is active).
   - If not within 6.0 yalms of the selected NPC type, destinations are automatically dimmed, and their buttons are locked to prevent accidental command issues.

4. **Rich Custom Styling**:
   - Sophisticated dark theme with deep navy/indigo accents.
   - Curated HSL colors, smooth 8px window rounding, and 4px button/frame padding for a premium, non-generic look.

5. **Dynamic Automation Settings**:
   - **Auto-Open**: Automatically pop open the menu as soon as you approach any Home Point or Survival Guide NPC in the world!
   - **Auto-Close**: Automatically close the menu when walking away from both NPC types.
   - **Alpha Transparency**: A slider to adjust the window transparency on the fly.

---

## ⌨️ Slash Commands

| Command | Action |
|---|---|
| `/uwm` | Toggles the Uberwarp ImGui Menu visibility |
| `/uwmenu` | Toggles the Uberwarp ImGui Menu visibility |

---

## 🔍 Installation & Usage

1. Place the `uberwarp_menu` folder inside your Ashita `addons/` directory.
2. Load/reload the addon in the game console:
   ```text
   /addon load uberwarp_menu
   ```
3. Open the menu using:
   ```text
   /uwm
   ```
4. Click between the **Home Points** and **Survival Guides** tabs to switch systems.
5. Use the search input box to instantly filter by zone name (e.g., `"Jeuno"`) or specific alias (e.g., `"Ru'Lude"`). Collapsing headers will auto-expand to show matches!
6. Approach a warp NPC and click any highlighted destination to instantly warp!
