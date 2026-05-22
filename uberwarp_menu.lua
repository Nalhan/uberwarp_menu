--[[
* uberwarp_menu - Searchable travel menu for all 10 major travel systems using Uberwarp
* Author: Antigravity
* Version: 1.2
--]]

addon.name      = 'uberwarp_menu';
addon.author    = 'Antigravity';
addon.version   = '1.2';
addon.desc      = 'Searchable ImGui menu for all 10 major travel systems supported by Uberwarp.';
addon.link      = '';

require 'common';

local imgui    = require 'imgui';
local settings = require 'settings';
local chat     = require 'chat';

-- Default Settings
local default_settings = T{
    auto_open  = false,
    auto_close = false,
    auto_open_uncollected = true,
    alpha      = 0.95,
    scale      = 1.0,
    collected  = {},
    synced_systems = {},
};

-- Supported Uberwarp Systems Configuration
local systems = {
    hp = {
        key = 'hp',
        name = 'Home Points',
        xml = 'homepoint.xml',
        command = '/uw hp ',
        npc_patterns = { 'Home Point' }
    },
    sg = {
        key = 'sg',
        name = 'Survival Guides',
        xml = 'survivalguide.xml',
        command = '/uw sg ',
        npc_patterns = { 'Survival Guide' }
    },
    wp = {
        key = 'wp',
        name = 'Waypoints',
        xml = 'waypoint.xml',
        command = '/uw wp ',
        npc_patterns = { 'Waypoint', 'Geomagnetic Fount' }
    },
    pw = {
        key = 'pw',
        name = 'Proto-Waypoints',
        xml = 'protowaypoint.xml',
        command = '/uw pw ',
        npc_patterns = { 'Proto-Waypoint' }
    },
    uc = {
        key = 'uc',
        name = 'Unity Concord',
        xml = 'unitywarp.xml',
        command = '/uw uc ',
        npc_patterns = { 'Shiftrix', 'Irena', 'Concord', 'Assault Director' }
    },
    ep = {
        key = 'ep',
        name = 'Eschan Portals',
        xml = 'eschanportal.xml',
        command = '/uw ep ',
        npc_patterns = { 'Eschan Portal', 'Ethereal Ingress' }
    },
    ab = {
        key = 'ab',
        name = 'Abyssea Confluxes',
        xml = 'abysseaconflux.xml',
        command = '/uw ab ',
        npc_patterns = { 'Conflux' }
    },
    aw = {
        key = 'aw',
        name = 'Abyssea Warps',
        xml = 'abysseawarp.xml',
        command = '/uw aw ',
        npc_patterns = { 'Horst', 'Vincent', 'Ivan', 'Cavernous Maw' }
    },
    rp = {
        key = 'rp',
        name = 'Runic Portals',
        xml = 'runicportal.xml',
        command = '/uw rp ',
        npc_patterns = { 'Runic Portal', 'Runic Transfer' }
    },
    ev = {
        key = 'ev',
        name = 'Elvorseal',
        xml = 'elvorseal.xml',
        command = '/uw ev ',
        npc_patterns = { 'Dimensional Portal', 'Eschan Portal', 'Ethereal Ingress' }
    }
};

-- Deterministic tab render order
local system_order = { 'hp', 'sg', 'wp', 'pw', 'uc', 'ep', 'ab', 'aw', 'rp', 'ev' };

-- State Variables
local state = {
    is_open            = { false },
    search_text        = { '' },
    locations          = {}, -- Map of key -> locations list
    proximity          = {}, -- Map of key -> proximity state
    active_tab         = 'hp',
    npc_trigger_active = false, -- Remembers if auto-open has already triggered for this encounter
    settings           = settings.load(default_settings),
    collected_dirty    = false,
};

-- Uberwarp CHECK output system names map to internal keys
local check_system_map = {
    ['HomePoint'] = 'hp',
    ['SurvivalGuide'] = 'sg',
    ['Waypoint'] = 'wp',
    ['UnityWarp'] = 'uc',
    ['ProtoWaypoint'] = 'pw',
    ['EschanPortal'] = 'ep',
    ['AbysseaConflux'] = 'ab',
    ['RunicPortal'] = 'rp'
};

local function sync_warp_nodes()
    local check_commands = {
        '/uw hp check',
        '/uw sg check',
        '/uw wp check',
        '/uw uc check',
        '/uw pw check',
        '/uw ep check',
        '/uw ab check',
        '/uw rp check'
    };
    for _, cmd in ipairs(check_commands) do
        AshitaCore:GetChatManager():QueueCommand(-1, cmd);
    end
    print(chat.header(addon.name) .. chat.message("Syncing all collected nodes with Uberwarp in the background..."));
end

-- Ensure collected settings table is initialized
if not state.settings.collected then
    state.settings.collected = {};
end

if not state.settings.synced_systems then
    state.settings.synced_systems = {};
end

if state.settings.auto_open_uncollected == nil then
    state.settings.auto_open_uncollected = true;
end

-- Initialize locations and proximity structures
for _, key in ipairs(system_order) do
    state.locations[key] = {};
    state.proximity[key] = {
        near = false,
        closest_name = '',
        closest_dist = 999.0
    };
end

--[[
* Loads and parses locations from the corresponding XML resource file
--]]
local function load_system_locations(key)
    local sys = systems[key];
    if not sys then return end;

    state.locations[key] = {};
    local install_path = AshitaCore:GetInstallPath();
    local xml_path = install_path .. 'resources/ashitahelper/uberwarp/' .. sys.xml;
    local f = io.open(xml_path, 'r');
    if not f then
        -- Silently fail or don't complain if resource isn't present
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
            
            local px_str = line:match('posx="([^"]+)"');
            local py_str = line:match('posy="([^"]+)"');
            local pz_str = line:match('posz="([^"]+)"');
            
            table.insert(state.locations[key], {
                alias = alias,
                zone_id = zone_id,
                zone_name = zone_name,
                x = px_str and tonumber(px_str) or 0.0,
                y = py_str and tonumber(py_str) or 0.0,
                z = pz_str and tonumber(pz_str) or 0.0,
            });
            count = count + 1;
        end
    end
    f:close();
    
    if count > 0 then
        print(chat.header(addon.name) .. chat.message(string.format("Successfully loaded %d %s warp locations.", count, sys.name)));
    end
end

--[[
* Scans all active entities to detect proximity to configured NPC types
--]]
local function update_proximity()
    local player = GetPlayerEntity();
    if not player then
        for _, key in ipairs(system_order) do
            state.proximity[key].near = false;
            state.proximity[key].closest_name = '';
            state.proximity[key].closest_dist = 999.0;
        end
        state.npc_trigger_active = false;
        return;
    end

    local closest_dists = {};
    local closest_names = {};
    local found_any = {};

    for _, key in ipairs(system_order) do
        closest_dists[key] = 999999.0;
        closest_names[key] = '';
        found_any[key] = false;
    end

    for i = 0, 2304 do
        local ent = GetEntity(i);
        if ent and ent.Name then
            local name = ent.Name:trimend('\x00');
            for _, key in ipairs(system_order) do
                local sys = systems[key];
                if #state.locations[key] > 0 then
                    local matched = false;
                    for _, pattern in ipairs(sys.npc_patterns) do
                        if name:find(pattern, 1, true) then
                            matched = true;
                            break;
                        end
                    end
                    if matched then
                        local dist_sq = ent.Distance; -- ent.Distance is distance squared
                        if dist_sq < closest_dists[key] then
                            closest_dists[key] = dist_sq;
                            closest_names[key] = name;
                            found_any[key] = true;
                        end
                    end
                end
            end
        end
    end

    -- Process distances and set proximity flags
    for _, key in ipairs(system_order) do
        local prox = state.proximity[key];
        if found_any[key] then
            local actual_dist = math.sqrt(closest_dists[key]);
            prox.closest_dist = actual_dist;
            prox.closest_name = closest_names[key];
            prox.near = (actual_dist < 6.0);
        else
            prox.near = false;
            prox.closest_name = '';
            prox.closest_dist = 999.0;
        end
    end

    -- Check for first-time system synchronization when encountering a node type
    for _, key in ipairs(system_order) do
        if state.proximity[key].near and not state.settings.synced_systems[key] then
            state.settings.synced_systems[key] = true;
            settings.save();
            
            local sys = systems[key];
            if sys then
                AshitaCore:GetChatManager():QueueCommand(-1, sys.command .. 'CHECK');
                print(chat.header(addon.name) .. chat.message(string.format("First encounter with %s NPC. Initializing obtained node list from Uberwarp...", sys.name)));
            end
        end
    end

    -- Smart Proximity Latch: Auto-open / auto-close behavior based on proximity to any active system NPC
    local any_near = false;
    for _, key in ipairs(system_order) do
        if #state.locations[key] > 0 and state.proximity[key].near then
            any_near = true;
            break;
        end
    end

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

    -- Check for nearby uncollected nodes
    local current_zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    local party = AshitaCore:GetMemoryManager():GetParty();
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();
    local myIndex = party:GetMemberTargetIndex(0);
    
    local closest_uncollected_dist = 999.0;
    local closest_uncollected_node = nil;
    
    if myIndex and myIndex >= 0 then
        local px = entMgr:GetLocalPositionX(myIndex);
        local py = entMgr:GetLocalPositionY(myIndex);
        local pz = entMgr:GetLocalPositionZ(myIndex);
        
        for _, key in ipairs(system_order) do
            local sys = systems[key];
            if #state.locations[key] > 0 then
                for _, loc in ipairs(state.locations[key]) do
                    if loc.zone_id == current_zone then
                        local dx = px - loc.x;
                        local dy = py - loc.y;
                        local dz = pz - loc.z;
                        local dist = math.sqrt(dx*dx + dy*dy + dz*dz);
                        
                        if dist < 12.0 then
                            -- Ensure that a real NPC for this travel system is actually loaded and nearby.
                            -- This prevents false alerts for non-existent crystals (e.g. Upper Jeuno HP #4 on HorizonXI).
                            local npc_near = (state.proximity[key].closest_dist < 15.0);
                            if npc_near then
                                local is_collected = false;
                                if state.settings.collected[key] and state.settings.collected[key][loc.alias] then
                                    is_collected = true;
                                end
                                
                                if not is_collected then
                                    if dist < closest_uncollected_dist then
                                        closest_uncollected_dist = dist;
                                        closest_uncollected_node = {
                                            key = key,
                                            alias = loc.alias,
                                            dist = dist,
                                            system_name = sys.name
                                        };
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if closest_uncollected_node then
        state.uncollected_near = closest_uncollected_node;
        
        -- Chat alert once per encounter
        local alert_key = closest_uncollected_node.key .. '_' .. closest_uncollected_node.alias;
        if state.last_chat_alert ~= alert_key then
            print(chat.header(addon.name) .. chat.warning(string.format("Ran past uncollected %s: %s!", closest_uncollected_node.system_name, closest_uncollected_node.alias)));
            state.last_chat_alert = alert_key;
        end

        -- Auto-open the window if configured and not already open
        if state.settings.auto_open_uncollected and state.last_uncollected_trigger ~= alert_key then
            state.last_uncollected_trigger = alert_key;
            if not state.is_open[1] then
                state.is_open[1] = true;
            end
        end
    else
        state.uncollected_near = nil;
        state.last_chat_alert = nil;
        state.last_uncollected_trigger = nil;
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

-- Search Expansion / Regional / Expansion Aliases mapping
local search_aliases = {
    -- Jeuno / Rulude
    ['jeuno'] = { 'lower jeuno', 'port jeuno', 'upper jeuno', 'ru\'lude' },
    ['rulude'] = { 'jeuno', 'lower jeuno', 'port jeuno', 'upper jeuno' },
    
    -- Bastok
    ['bastok'] = { 'bastok markets', 'bastok mines', 'port bastok', 'metalworks' },
    ['basty'] = { 'bastok', 'bastok markets', 'bastok mines', 'port bastok', 'metalworks' },
    
    -- San d'Oria
    ['san d\'oria'] = { 'southern san d\'oria', 'northern san d\'oria', 'port san d\'oria', 'chateau d\'oraguille' },
    ['sandy'] = { 'san d\'oria', 'southern san d\'oria', 'northern san d\'oria', 'port san d\'oria', 'chateau d\'oraguille' },
    
    -- Windurst
    ['windurst'] = { 'windurst woods', 'windurst waters', 'windurst walls', 'port windurst', 'heavens tower' },
    ['windy'] = { 'windurst', 'windurst woods', 'windurst waters', 'windurst walls', 'port windurst', 'heavens tower' },
    
    -- Zilart / RoZ
    ['zilart'] = { 'norg', 'rabao', 'kazham', 'ru\'aun gardens', 'the sanctuary of zi\'tah', 'ro\'maeve', 'temple of uggalepih' },
    ['roz'] = { 'zilart', 'norg', 'rabao', 'kazham', 'ru\'aun gardens', 'the sanctuary of zi\'tah', 'ro\'maeve', 'temple of uggalepih' },
    ['norg'] = { 'zilart' },
    ['rabao'] = { 'zilart' },
    ['kazham'] = { 'zilart' },
    
    -- Promathia / CoP
    ['promathia'] = { 'tavnazian safehold', 'lufaise meadows', 'misareaux coast', 'phomiuna aqueducts', 'sacrarium', 'al\'taieu', 'grand palace of hu\'xzoi', 'the garden of ru\'hmet' },
    ['cop'] = { 'promathia', 'tavnazian safehold', 'lufaise meadows', 'misareaux coast', 'phomiuna aqueducts', 'sacrarium', 'al\'taieu', 'grand palace of hu\'xzoi', 'the garden of ru\'hmet' },
    ['tavnazia'] = { 'tavnazian safehold', 'promathia' },
    
    -- Aht Urhgan / ToAU
    ['aht urhgan'] = { 'aht urhgan whitegate', 'al zahbi', 'nashmau', 'wajaom woodlands', 'bhaflau thickets', 'caedarva mire', 'mount zhayolm', 'halvung', 'mamook', 'arrapago reef' },
    ['toau'] = { 'aht urhgan', 'aht urhgan whitegate', 'al zahbi', 'nashmau', 'wajaom woodlands', 'bhaflau thickets', 'caedarva mire', 'mount zhayolm', 'halvung', 'mamook', 'arrapago reef' },
    ['whitegate'] = { 'aht urhgan' },
    ['nashmau'] = { 'aht urhgan' },
    
    -- Shadowreign / WotG
    ['shadowreign'] = { '[s]' },
    ['wotg'] = { '[s]', 'shadowreign' },
    
    -- Adoulin / SoA
    ['adoulin'] = { 'western adoulin', 'eastern adoulin', 'celennia memorial library', 'yahse wildwood', 'ceizak battlegrounds', 'foret de hennetiel', 'morimar basalt fields', 'marjami ravine', 'yorcia weald', 'kamihr drifts', 'doh gates', 'sih gates', 'moh gates' },
    ['soa'] = { 'adoulin', 'western adoulin', 'eastern adoulin', 'celennia memorial library', 'yahse wildwood', 'ceizak battlegrounds', 'foret de hennetiel', 'morimar basalt fields', 'marjami ravine', 'yorcia weald', 'kamihr drifts', 'doh gates', 'sih gates', 'moh gates' },
    
    -- Escha
    ['escha'] = { 'escha - zi\'tah', 'escha - ru\'aun', 'reisenjima' },
    ['reisenjima'] = { 'escha' },
    
    -- Abyssea
    ['abyssea'] = { 'abyssea - attohwa', 'abyssea - konschtat', 'abyssea - la theine', 'abyssea - tahrongi', 'abyssea - vunkerl', 'abyssea - misareaux', 'abyssea - altepa', 'abyssea - uleguerand', 'abyssea - grauberg' },
};

--[[
* Renders a list of locations grouped by zone and applies proximity locking
--]]
--[[
* Renders a list of locations grouped by zone and applies proximity locking
--]]
local function render_locations_list(system_key, locations_table, is_near_npc, command_prefix)
    local scale = state.settings.scale or 1.0;
    local query = state.search_text[1]:gsub('%z', ''):trim():lower();
    local grouped = {};
    local zones_ordered = {};

    -- Precompute query search terms including aliases
    local search_terms = { query };
    if query ~= "" then
        for k, list in pairs(search_aliases) do
            if k:find(query, 1, true) then
                for _, term in ipairs(list) do
                    table.insert(search_terms, term);
                end
            end
        end
    end

    for _, loc in ipairs(locations_table) do
        local matches = true;
        if query ~= "" then
            local matched_any = false;
            local alias_lower = loc.alias:lower();
            local zone_lower = loc.zone_name:lower();
            for _, term in ipairs(search_terms) do
                if alias_lower:find(term, 1, true) or zone_lower:find(term, 1, true) then
                    matched_any = true;
                    break;
                end
            end
            matches = matched_any;
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
                        -- Prepend checkmark depending on collected status
                        local is_collected = false;
                        if state.settings.collected[system_key] and state.settings.collected[system_key][loc.alias] then
                            is_collected = true;
                        end

                        local is_clickable = is_near_npc and is_collected;

                        -- Dim/Disable button colors if not clickable
                        if not is_clickable then
                            imgui.PushStyleColor(ImGuiCol_Button, { 0.12, 0.12, 0.12, 0.6 });
                            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.12, 0.12, 0.12, 0.6 });
                            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.12, 0.12, 0.12, 0.6 });
                            imgui.PushStyleColor(ImGuiCol_Text, { 0.45, 0.45, 0.45, 0.7 });
                        end

                        if imgui.Button(loc.alias .. '##Btn_' .. command_prefix .. loc.alias, { -1, 26 * scale }) then
                            if is_clickable then
                                -- Auto-collect when successfully warped (redundant backup)
                                if not state.settings.collected[system_key] then
                                    state.settings.collected[system_key] = {};
                                end
                                state.settings.collected[system_key][loc.alias] = true;
                                state.collected_dirty = true;
                                
                                AshitaCore:GetChatManager():QueueCommand(-1, command_prefix .. loc.alias);
                            elseif not is_near_npc then
                                print(chat.header(addon.name) .. chat.error("Cannot warp: You must be near the appropriate NPC."));
                            else
                                print(chat.header(addon.name) .. chat.error("Cannot warp: You have not unlocked this destination yet."));
                            end
                        end

                        if not is_clickable then
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
    if state.collected_dirty then
        settings.save();
        state.collected_dirty = false;
    end

    update_proximity();

    if not state.is_open[1] then
        return;
    end

    push_custom_styles();

    local scale = state.settings.scale or 1.0;
    imgui.SetNextWindowSize({ 380 * scale, 520 * scale }, ImGuiCond_FirstUseEver);
    if imgui.Begin('Uberwarp Menu##UWM_Window', state.is_open, ImGuiWindowFlags_NoCollapse) then
        
        -- Proximity Status Bar based on Active Tab
        local active_sys = systems[state.active_tab];
        local is_near = false;
        local npc_name = '';
        local npc_dist = 999.0;
        
        if active_sys then
            local prox = state.proximity[state.active_tab];
            is_near = prox.near;
            npc_name = prox.closest_name;
            npc_dist = prox.closest_dist;
        end

        if is_near then
            imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.10, 0.25, 0.12, 0.8 });
            imgui.BeginChild('##StatusChild', { 0, 36 * scale }, ImGuiChildFlags_Borders);
                imgui.SetCursorPosX(10 * scale);
                imgui.SetCursorPosY(8 * scale);
                imgui.TextColored({ 0.2, 1.0, 0.3, 1.0 }, 'READY');
                imgui.SameLine();
                imgui.TextColored({ 0.9, 0.9, 0.9, 1.0 }, string.format('- Near %s (%.1f yalms)', npc_name, npc_dist));
            imgui.EndChild();
            imgui.PopStyleColor(1);
        else
            imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.25, 0.10, 0.10, 0.8 });
            imgui.BeginChild('##StatusChild', { 0, 36 * scale }, ImGuiChildFlags_Borders);
                imgui.SetCursorPosX(10 * scale);
                imgui.SetCursorPosY(8 * scale);
                imgui.TextColored({ 1.0, 0.3, 0.2, 1.0 }, 'WARNING');
                imgui.SameLine();
                if npc_name ~= '' then
                    imgui.TextColored({ 0.9, 0.9, 0.9, 1.0 }, string.format('- Too far from %s (%.1f/6.0y)', npc_name, npc_dist));
                else
                    local sys_name = active_sys and active_sys.name or "appropriate";
                    imgui.TextColored({ 0.9, 0.9, 0.9, 1.0 }, string.format('- No %s NPC detected nearby.', sys_name));
                end
            imgui.EndChild();
            imgui.PopStyleColor(1);
        end

        imgui.Spacing();

        -- Uncollected Node Alert Banner
        if state.uncollected_near then
            imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.35, 0.20, 0.05, 0.8 });
            imgui.BeginChild('##UncollectedAlertChild', { 0, 36 * scale }, ImGuiChildFlags_Borders);
                imgui.SetCursorPosX(10 * scale);
                imgui.SetCursorPosY(8 * scale);
                imgui.TextColored({ 1.0, 0.7, 0.2, 1.0 }, '⚠️ UNCOLLECTED:');
                imgui.SameLine();
                imgui.TextColored({ 0.95, 0.95, 0.95, 1.0 }, string.format('%s (%.1fy)', state.uncollected_near.alias, state.uncollected_near.dist));
                
                -- Collect Button on the right
                imgui.SameLine();
                local btn_width = 80 * scale;
                imgui.SetCursorPosX(imgui.GetWindowWidth() - btn_width - 8 * scale);
                imgui.SetCursorPosY(5 * scale);
                imgui.PushStyleColor(ImGuiCol_Button, { 0.5, 0.3, 0.05, 1.0 });
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.65, 0.4, 0.1, 1.0 });
                imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.8, 0.5, 0.15, 1.0 });
                if imgui.Button('Collect##AlertBtn', { btn_width, 24 * scale }) then
                    local ukey = state.uncollected_near.key;
                    local ualias = state.uncollected_near.alias;
                    if not state.settings.collected[ukey] then
                        state.settings.collected[ukey] = {};
                    end
                    state.settings.collected[ukey][ualias] = true;
                    settings.save();
                    print(chat.header(addon.name) .. chat.message(string.format("Marked %s: %s as collected!", state.uncollected_near.system_name, ualias)));
                end
                imgui.PopStyleColor(3);
            imgui.EndChild();
            imgui.PopStyleColor(1);
            imgui.Spacing();
        end

        -- Search Box with Clear Button
        local active_sys_name = active_sys and active_sys.name or "Locations";
        local placeholder = string.format('Search %s:', active_sys_name);
        imgui.TextColored({ 0.7, 0.8, 1.0, 1.0 }, placeholder);
        imgui.InputText('##SearchInput', state.search_text, 64);
        imgui.SameLine();
        if imgui.Button('Clear##ClearSearch', { 50 * scale, 0 }) then
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

            local auto_open_uncol_tbl = { state.settings.auto_open_uncollected };
            if imgui.Checkbox('Auto-Open on Uncollected Node', auto_open_uncol_tbl) then
                state.settings.auto_open_uncollected = auto_open_uncol_tbl[1];
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

            imgui.Text('Menu Scale:');
            local scale_tbl = { state.settings.scale or 1.0 };
            if imgui.SliderFloat('##scaleSlider', scale_tbl, 0.5, 2.0, '%.2f') then
                state.settings.scale = scale_tbl[1];
                settings.save();
            end
            
            imgui.Separator();
            
            -- Collection Stats
            local total_nodes = 0;
            local collected_nodes = 0;
            for _, key in ipairs(system_order) do
                total_nodes = total_nodes + #state.locations[key];
                if state.settings.collected[key] then
                    for k, _ in pairs(state.settings.collected[key]) do
                        collected_nodes = collected_nodes + 1;
                    end
                end
            end
            
            imgui.Text(string.format('Collection Progress: %d / %d (%.1f%%)', collected_nodes, total_nodes, total_nodes > 0 and (collected_nodes / total_nodes * 100) or 0.0));
            
            if imgui.Button('Sync with Uberwarp##SyncColl', { -1, 24 * scale }) then
                sync_warp_nodes();
            end
            
            if imgui.Button('Reset Collection Data##ResetColl', { -1, 24 * scale }) then
                state.settings.collected = {};
                state.settings.synced_systems = {};
                settings.save();
                print(chat.header(addon.name) .. chat.message("Reset all warp collection data and sync history."));
            end
            imgui.Unindent();
            imgui.Separator();
        end

        imgui.Spacing();

        -- Tabs for each travel system (only rendered if they contain locations)
        if imgui.BeginTabBar('##WarpTabs') then
            for _, key in ipairs(system_order) do
                local sys = systems[key];
                if #state.locations[key] > 0 then
                    if imgui.BeginTabItem(sys.name .. '##Tab_' .. key) then
                        state.active_tab = key;
                        render_locations_list(key, state.locations[key], state.proximity[key].near, sys.command);
                        imgui.EndTabItem();
                    end
                end
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
    for _, key in ipairs(system_order) do
        load_system_locations(key);
    end

    -- Default active tab to first successfully loaded system
    for _, key in ipairs(system_order) do
        if #state.locations[key] > 0 then
            state.active_tab = key;
            break;
        end
    end
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

-- Clean and strip colors/control codes from chat messages
local function strip_color_codes(str)
    if not str then return '' end
    local cleaned = str:gsub('|c%x%x%x%x%x%x%x%x|', ''):gsub('|r|', '');
    cleaned = cleaned:gsub('\x1e%x', ''):gsub('\x1f%x', ''):gsub('\x07', '');
    return cleaned:trim();
end

-- Intercept and parse Uberwarp check commands output
ashita.events.register('text_in', 'uberwarp_menu_text_in_cb', function (e)
    local cleaned = strip_color_codes(e.message);
    if cleaned == '' then return end
    
    -- Match format: [Uberwarp:<SystemName>] <Alias> : <Status>
    local system_name, alias, status = cleaned:match('%[Uberwarp:([%a]+)%]%s*(.-)%s*:%s*(%a+)');
    if system_name and alias and status then
        local key = check_system_map[system_name];
        if key then
            local is_unlocked = (status:lower() == 'unlocked');
            if is_unlocked then
                if not state.settings.collected[key] then
                    state.settings.collected[key] = {};
                end
                state.settings.collected[key][alias] = true;
                state.collected_dirty = true;
            end
        end
    end
end);

--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'present_cb', render_ui);
