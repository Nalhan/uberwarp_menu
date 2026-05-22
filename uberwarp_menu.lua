--[[
* uberwarp_menu - Searchable Home Point and Survival Guide warp list using Uberwarp
* Author: Antigravity
* Version: 1.1
--]]

addon.name      = 'uberwarp_menu';
addon.author    = 'Antigravity';
addon.version   = '1.1';
addon.desc      = 'Searchable ImGui menu of Home Point and Survival Guide warp locations using Uberwarp.';
addon.link      = '';

require 'common';

local imgui    = require 'imgui';
local settings = require 'settings';
local chat     = require 'chat';

-- Default Settings
local default_settings = T{
    auto_open  = false,
    auto_close = false,
    alpha      = 0.95,
};

-- State Variables
local state = {
    is_open            = { false },
    search_text        = { '' },
    homepoints         = {},
    survivalguides     = {},
    near_hp            = false,
    near_sg            = false,
    closest_hp_name    = '',
    closest_hp_dist    = 999.0,
    closest_sg_name    = '',
    closest_sg_dist    = 999.0,
    active_tab         = 'hp', -- 'hp' or 'sg'
    npc_trigger_active = false, -- Remembers if auto-open has already triggered for this encounter
    settings           = settings.load(default_settings),
};

--[[
* Loads and parses home points from resources/ashitahelper/uberwarp/homepoint.xml
--]]
local function load_homepoints()
    state.homepoints = {};
    local install_path = AshitaCore:GetInstallPath();
    local xml_path = install_path .. 'resources/ashitahelper/uberwarp/homepoint.xml';
    local f = io.open(xml_path, 'r');
    if not f then
        print(chat.header(addon.name) .. chat.error("Could not find 'resources/ashitahelper/uberwarp/homepoint.xml'! Make sure Uberwarp is loaded/installed."));
        return;
    end

    local count = 0;
    for line in f:lines() do
        local alias = line:match('alias="([^"]+)"');
        local zone_str = line:match('zone="([%d]+)"');
        if alias and zone_str then
            local zone_id = tonumber(zone_str);
            local zone_name = AshitaCore:GetResourceManager():GetString('zones.names', zone_id);
            if not zone_name or zone_name == "" then
                zone_name = "Unknown Zone (" .. zone_id .. ")";
            else
                -- Trim trailing null bytes and whitespace
                zone_name = zone_name:trimend('\x00'):trim();
            end
            table.insert(state.homepoints, {
                alias = alias,
                zone_id = zone_id,
                zone_name = zone_name
            });
            count = count + 1;
        end
    end
    f:close();
    print(chat.header(addon.name) .. chat.message("Successfully loaded " .. count .. " Home Point warp locations."));
end

--[[
* Loads and parses survival guides from resources/ashitahelper/uberwarp/survivalguide.xml
--]]
local function load_survivalguides()
    state.survivalguides = {};
    local install_path = AshitaCore:GetInstallPath();
    local xml_path = install_path .. 'resources/ashitahelper/uberwarp/survivalguide.xml';
    local f = io.open(xml_path, 'r');
    if not f then
        print(chat.header(addon.name) .. chat.error("Could not find 'resources/ashitahelper/uberwarp/survivalguide.xml'! Make sure Uberwarp is loaded/installed."));
        return;
    end

    local count = 0;
    for line in f:lines() do
        local alias = line:match('alias="([^"]+)"');
        local zone_str = line:match('zone="([%d]+)"');
        if alias and zone_str then
            local zone_id = tonumber(zone_str);
            local zone_name = AshitaCore:GetResourceManager():GetString('zones.names', zone_id);
            if not zone_name or zone_name == "" then
                zone_name = "Unknown Zone (" .. zone_id .. ")";
            else
                -- Trim trailing null bytes and whitespace
                zone_name = zone_name:trimend('\x00'):trim();
            end
            table.insert(state.survivalguides, {
                alias = alias,
                zone_id = zone_id,
                zone_name = zone_name
            });
            count = count + 1;
        end
    end
    f:close();
    print(chat.header(addon.name) .. chat.message("Successfully loaded " .. count .. " Survival Guide warp locations."));
end

--[[
* Scans all active entities to detect proximity to a "Home Point" or "Survival Guide" NPC
--]]
local function update_proximity()
    local player = GetPlayerEntity();
    if not player then
        state.near_hp = false;
        state.near_sg = false;
        state.closest_hp_name = '';
        state.closest_hp_dist = 999.0;
        state.closest_sg_name = '';
        state.closest_sg_dist = 999.0;
        state.npc_trigger_active = false;
        return;
    end

    local closest_hp_dist = 999999.0;
    local closest_hp_name = '';
    local found_hp = false;

    local closest_sg_dist = 999999.0;
    local closest_sg_name = '';
    local found_sg = false;

    for i = 0, 2304 do
        local ent = GetEntity(i);
        if ent and ent.Name then
            local name = ent.Name:trimend('\x00');
            if name:sub(1, 10) == "Home Point" then
                local dist_sq = ent.Distance; -- ent.Distance is distance squared
                if dist_sq < closest_hp_dist then
                    closest_hp_dist = dist_sq;
                    closest_hp_name = name;
                    found_hp = true;
                end
            elseif name:sub(1, 14) == "Survival Guide" then
                local dist_sq = ent.Distance; -- ent.Distance is distance squared
                if dist_sq < closest_sg_dist then
                    closest_sg_dist = dist_sq;
                    closest_sg_name = name;
                    found_sg = true;
                end
            end
        end
    end

    -- Process Home Points
    if found_hp then
        local actual_dist = math.sqrt(closest_hp_dist);
        state.closest_hp_dist = actual_dist;
        state.closest_hp_name = closest_hp_name;
        state.near_hp = (actual_dist < 6.0);
    else
        state.near_hp = false;
        state.closest_hp_name = '';
        state.closest_hp_dist = 999.0;
    end

    -- Process Survival Guides
    if found_sg then
        local actual_dist = math.sqrt(closest_sg_dist);
        state.closest_sg_dist = actual_dist;
        state.closest_sg_name = closest_sg_name;
        state.near_sg = (actual_dist < 6.0);
    else
        state.near_sg = false;
        state.closest_sg_name = '';
        state.closest_sg_dist = 999.0;
    end

    -- Auto-open / auto-close behavior based on proximity to EITHER NPC type
    local any_near = state.near_hp or state.near_sg;
    if any_near then
        if not state.npc_trigger_active then
            state.npc_trigger_active = true;
            if state.settings.auto_open and not state.is_open[1] then
                state.is_open[1] = true;
            end
        end
    else
        state.npc_trigger_active = false;
        if state.settings.auto_close and state.is_open[1] then
            state.is_open[1] = false;
        end
    end
end

--[[
* Pushes custom ImGui styles for premium modern aesthetics
--]]
local function push_custom_styles()
    -- Custom sleek dark theme with deep navy/indigo accents
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.07, 0.08, 0.11, state.settings.alpha });
    imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.11, 0.13, 0.20, 1.0 });
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.15, 0.18, 0.27, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Button, { 0.14, 0.19, 0.32, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.20, 0.27, 0.45, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.25, 0.34, 0.58, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Header, { 0.12, 0.16, 0.25, 1.0 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.18, 0.24, 0.38, 1.0 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.23, 0.30, 0.48, 1.0 });
    imgui.PushStyleColor(ImGuiCol_FrameBg, { 0.10, 0.11, 0.14, 1.0 });
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, { 0.15, 0.17, 0.22, 1.0 });
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, { 0.19, 0.21, 0.27, 1.0 });
    
    -- Smooth rounded corners for a premium feel
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 8.0);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 4.0);
    imgui.PushStyleVar(ImGuiStyleVar_GrabRounding, 4.0);
end

--[[
* Pops custom ImGui styles
--]]
local function pop_custom_styles()
    imgui.PopStyleColor(12);
    imgui.PopStyleVar(3);
end

--[[
* Renders a list of locations grouped by zone and applies proximity locking
--]]
local function render_locations_list(locations_table, is_near_npc, command_prefix)
    local query = state.search_text[1]:gsub('%z', ''):trim():lower();
    local grouped = {};
    local zones_ordered = {};

    for _, loc in ipairs(locations_table) do
        local matches = true;
        if query ~= "" then
            local alias_match = loc.alias:lower():find(query, 1, true) ~= nil;
            local zone_match = loc.zone_name:lower():find(query, 1, true) ~= nil;
            matches = alias_match or zone_match;
        end

        if matches then
            if not grouped[loc.zone_name] then
                grouped[loc.zone_name] = {};
                table.insert(zones_ordered, loc.zone_name);
            end
            table.insert(grouped[loc.zone_name], loc);
        end
    end
    table.sort(zones_ordered);

    -- Searchable Child Window
    imgui.BeginChild('##WarpListChild_' .. command_prefix, { 0, 0 }, ImGuiChildFlags_Borders);
        
        if #zones_ordered == 0 then
            imgui.TextColored({ 0.6, 0.6, 0.6, 1.0 }, 'No matching locations found.');
        else
            local tree_flags = query ~= "" and ImGuiTreeNodeFlags_DefaultOpen or ImGuiTreeNodeFlags_None;
            
            for _, zone_name in ipairs(zones_ordered) do
                if imgui.CollapsingHeader(zone_name .. '##Header_' .. command_prefix .. zone_name, tree_flags) then
                    imgui.Indent();
                    for _, loc in ipairs(grouped[zone_name]) do
                        -- Dim/Disable button colors if not near NPC
                        if not is_near_npc then
                            imgui.PushStyleColor(ImGuiCol_Button, { 0.15, 0.15, 0.15, 0.5 });
                            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.15, 0.15, 0.15, 0.5 });
                            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.15, 0.15, 0.15, 0.5 });
                            imgui.PushStyleColor(ImGuiCol_Text, { 0.5, 0.5, 0.5, 0.8 });
                        end

                        if imgui.Button(loc.alias .. '##Btn_' .. command_prefix .. loc.alias, { -1, 26 }) then
                            if is_near_npc then
                                AshitaCore:GetChatManager():QueueCommand(-1, command_prefix .. loc.alias);
                            else
                                print(chat.header(addon.name) .. chat.error("Cannot warp: You must be near the appropriate NPC."));
                            end
                        end

                        if not is_near_npc then
                            imgui.PopStyleColor(4);
                        end
                    end
                    imgui.Unindent();
                end
            end
        end

    imgui.EndChild();
end

--[[
* Renders the searchable list and proximity status
--]]
local function render_ui()
    update_proximity();

    if not state.is_open[1] then
        return;
    end

    push_custom_styles();

    imgui.SetNextWindowSize({ 380, 520 }, ImGuiCond_FirstUseEver);
    if imgui.Begin('Uberwarp Menu##UWM_Window', state.is_open, ImGuiWindowFlags_NoCollapse) then
        
        -- Proximity Status Bar based on Active Tab
        local is_near = false;
        local npc_name = '';
        local npc_dist = 999.0;
        
        if state.active_tab == 'hp' then
            is_near = state.near_hp;
            npc_name = state.closest_hp_name;
            npc_dist = state.closest_hp_dist;
        elseif state.active_tab == 'sg' then
            is_near = state.near_sg;
            npc_name = state.closest_sg_name;
            npc_dist = state.closest_sg_dist;
        end

        if is_near then
            imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.10, 0.25, 0.12, 0.8 });
            imgui.BeginChild('##StatusChild', { 0, 36 }, ImGuiChildFlags_Borders);
                imgui.SetCursorPosX(10);
                imgui.SetCursorPosY(8);
                imgui.TextColored({ 0.2, 1.0, 0.3, 1.0 }, 'READY');
                imgui.SameLine();
                imgui.TextColored({ 0.9, 0.9, 0.9, 1.0 }, string.format('- Near %s (%.1f yalms)', npc_name, npc_dist));
            imgui.EndChild();
            imgui.PopStyleColor(1);
        else
            imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.25, 0.10, 0.10, 0.8 });
            imgui.BeginChild('##StatusChild', { 0, 36 }, ImGuiChildFlags_Borders);
                imgui.SetCursorPosX(10);
                imgui.SetCursorPosY(8);
                imgui.TextColored({ 1.0, 0.3, 0.2, 1.0 }, 'WARNING');
                imgui.SameLine();
                if npc_name ~= '' then
                    imgui.TextColored({ 0.9, 0.9, 0.9, 1.0 }, string.format('- Too far from %s (%.1f/6.0y)', npc_name, npc_dist));
                else
                    local npc_type_str = (state.active_tab == 'hp') and "Home Point" or "Survival Guide";
                    imgui.TextColored({ 0.9, 0.9, 0.9, 1.0 }, string.format('- No %s detected nearby.', npc_type_str));
                end
            imgui.EndChild();
            imgui.PopStyleColor(1);
        end

        imgui.Spacing();

        -- Search Box with Clear Button
        local placeholder = (state.active_tab == 'hp') and 'Search Home Points:' or 'Search Survival Guides:';
        imgui.TextColored({ 0.7, 0.8, 1.0, 1.0 }, placeholder);
        imgui.InputText('##SearchInput', state.search_text, 64);
        imgui.SameLine();
        if imgui.Button('Clear##ClearSearch', { 50, 0 }) then
            state.search_text[1] = '';
        end

        imgui.Separator();
        imgui.Spacing();

        -- Addon Configuration Collapsing Header
        if imgui.CollapsingHeader('Addon Settings##SettingsHeader', ImGuiTreeNodeFlags_None) then
            imgui.Indent();
            local auto_open_tbl = { state.settings.auto_open };
            if imgui.Checkbox('Auto-Open near NPC', auto_open_tbl) then
                state.settings.auto_open = auto_open_tbl[1];
                settings.save();
            end

            local auto_close_tbl = { state.settings.auto_close };
            if imgui.Checkbox('Auto-Close when leaving NPC', auto_close_tbl) then
                state.settings.auto_close = auto_close_tbl[1];
                settings.save();
            end
            
            imgui.Text('Menu Transparency:');
            local alpha_tbl = { state.settings.alpha };
            if imgui.SliderFloat('##alphaSlider', alpha_tbl, 0.3, 1.0, '%.2f') then
                state.settings.alpha = alpha_tbl[1];
                settings.save();
            end
            imgui.Unindent();
            imgui.Separator();
        end

        imgui.Spacing();

        -- Tabs for Home Points and Survival Guides
        if imgui.BeginTabBar('##WarpTabs') then
            if imgui.BeginTabItem('Home Points##Tab_HP') then
                state.active_tab = 'hp';
                render_locations_list(state.homepoints, state.near_hp, '/uw hp ');
                imgui.EndTabItem();
            end
            if imgui.BeginTabItem('Survival Guides##Tab_SG') then
                state.active_tab = 'sg';
                render_locations_list(state.survivalguides, state.near_sg, '/uw sg ');
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end

    end
    imgui.End();

    pop_custom_styles();
end

--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load', 'load_cb', function ()
    load_homepoints();
    load_survivalguides();
end);

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args == 0) then
        return;
    end

    local command = string.lower(args[1]);
    if (command == '/uwm') or (command == '/uwmenu') then
        e.blocked = true;
        state.is_open[1] = not state.is_open[1];
        return;
    end
end);

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', render_ui);
