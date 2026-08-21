local menu = {};

local ffxi = nil;
pcall(function () ffxi = require 'ffxi'; end);

local game_menu_pointer = ashita.memory.find(
    'FFXiMain.dll', 0, '8B480C85C974??8B510885D274??3B05', 16, 0
);

local hidden_menu_types = {
    equip = true, inventor = true, mnstorag = true,
    iuse = true, map0 = true, maplist = true, mapframe = true,
    scanlist = true, cnqframe = true, conf2win = true, cfilter = true,
    textcol1 = true, confyn = true, conf5m = true, conf5win = true,
    conf5w1 = true, conf5w2 = true, conf11m = true, conf11l = true,
    conf11s = true, conf3win = true, conf6win = true, conf12wi = true,
    conf13wi = true, fxfilter = true, conf7 = true, conf4 = true,
    link1 = true, link2 = true, link3 = true, link4 = true,
    link5 = true, link6 = true, link7 = true, link8 = true,
    link9 = true, link10 = true, link11 = true, link12 = true,
    link13 = true, fulllog = true,
    scresult = true, evitem = true, statcom2 = true,
    itmsortw = true, sortyn = true, itemctrl = true,
    mcr1edlo = true, mcr2edlo = true, mcrbedit = true, mcresed = true,
    bank = true, quest00 = true, quest01 = true, miss00 = true,
    meritcat = true, merit1 = true, merit2 = true, merit3 = true,
    merityn = true, shop = true, bluequip = true, blueequip = true,
    blueset = true, blumagic = true, blumgc = true, bluspell = true,
    mapv2 = true,
    mapv3 = true, inspect = true,
};

local main_menu_patterns = {
    'menuwind', 'socialme', 'configwi', 'mogcont', 'missionm',
    'auc[%d]', 'itmstora', 'itmsort', 'sortyn', 'region',
    'merit[%d]', 'mnstorag', 'prty[%d]', 'alarm', 'scoption',
};

local battle_command_menus = {
    command = true, playermo = true, chatctrl = true,
    magselec = true, magic = true, abiselec = true,
    ability = true, mount = true,
};

local main_menu_latched = false;
local main_menu_transition_until = 0;
local blue_magic_menu_latched = false;
local blue_magic_transition_until = 0;
local system_list_menu_latched = false;
local player_search_menu_latched = false;
local player_search_command_armed_until = 0;
local player_search_menu_seen = false;
local player_search_transition_hold_until = 0;

function menu.get_name()
    local menu_base = game_menu_pointer or 0;
    if (menu_base == 0) then
        game_menu_pointer = ashita.memory.find(
            'FFXiMain.dll', 0, '8B480C85C974??8B510885D274??3B05', 16, 0
        );
        menu_base = game_menu_pointer or 0;
    end
    if (menu_base == 0) then
        local ok, value = pcall(function ()
            return AshitaCore:GetPointerManager():Get('menu');
        end);
        if (ok and value ~= nil) then menu_base = value; end
    end
    if (menu_base == 0) then return ''; end

    local ok, name = pcall(function ()
        local pointer = ashita.memory.read_uint32(menu_base);
        if (pointer == nil or pointer == 0) then return ''; end
        local value = ashita.memory.read_uint32(pointer);
        if (value == nil or value == 0) then return ''; end
        local header = ashita.memory.read_uint32(value + 4);
        if (header == nil or header == 0) then return ''; end
        return ashita.memory.read_string(header + 0x46, 16) or '';
    end);
    if (not ok) then return ''; end

    name = name:gsub('\x00', '');
    if (#name >= 9) then name = name:sub(9); end
    return name:gsub(' ', ''):gsub('^%s+', ''):gsub('%s+$', '');
end

local function neutral(name)
    return name == 'inline' or name == 'menuwind' or
        name == 'menu' or name == 'command';
end

local function chat_input_open()
    local ok, open = pcall(function ()
        return AshitaCore:GetChatManager():IsInputOpen();
    end);
    return ok and open == true;
end

local function game_menu_open()
    local ok, open = pcall(function ()
        return AshitaCore:GetMemoryManager():GetTarget():GetIsMenuOpen();
    end);
    if (not ok or open == nil) then return nil; end
    if (open == true) then return true; end
    local value = tonumber(open);
    return value ~= nil and value ~= 0;
end

local function name_contains(name, patterns)
    for _, pattern in ipairs(patterns) do
        if (name:find(pattern, 1, true) ~= nil) then return true; end
    end
    return false;
end

local function blue_magic_menu_name(name)
    if (name == '') then return false; end
    if (name:find('bluequip', 1, true) or
            name:find('blueequip', 1, true) or
            name:find('blueset', 1, true)) then
        return true;
    end
    local is_blue_menu = name:find('blu', 1, true) ~= nil;
    return is_blue_menu and (
        name:find('magic', 1, true) ~= nil or
        name:find('spell', 1, true) ~= nil or
        name:find('equip', 1, true) ~= nil or
        name:find('set', 1, true) ~= nil
    );
end

function menu.is_main_open()
    local name = menu.get_name():lower();
    if (chat_input_open()) then
        main_menu_latched = false;
        return false;
    end
    local menu_flag = game_menu_open();
    if (menu_flag == true and battle_command_menus[name] and
            not main_menu_latched) then
        return false;
    end
    if (menu_flag == true) then
        main_menu_latched = true;
        return true;
    end
    for _, pattern in ipairs(main_menu_patterns) do
        if (name:match(pattern)) then
            main_menu_latched = true;
            main_menu_transition_until = os.clock() + 0.75;
            return true;
        end
    end
    if (main_menu_latched) then
        if (chat_input_open()) then
            main_menu_latched = false;
            return false;
        end
        local still_open = game_menu_open();
        if (still_open ~= nil) then
            if (still_open) then return true; end
            main_menu_latched = false;
            return false;
        end
        if (name ~= '' and not neutral(name)) then
            main_menu_transition_until = os.clock() + 0.75;
            return true;
        end
        if (os.clock() < main_menu_transition_until) then
            return true;
        end
        main_menu_latched = false;
    end
    return false;
end

local function blue_magic_setting_open(name)
    if (blue_magic_menu_name(name)) then
        blue_magic_menu_latched = true;
        blue_magic_transition_until = os.clock() + 0.75;
        return true;
    end
    if (blue_magic_menu_latched) then
        if (chat_input_open()) then
            blue_magic_menu_latched = false;
            return false;
        end
        local still_open = game_menu_open();
        if (still_open ~= nil) then
            if (still_open) then return true; end
            blue_magic_menu_latched = false;
            return false;
        end
        if (name ~= '' and not neutral(name)) then
            blue_magic_transition_until = os.clock() + 0.75;
            return true;
        end
        if (os.clock() < blue_magic_transition_until) then
            return true;
        end
        blue_magic_menu_latched = false;
    end
    return false;
end

local function map_open(name)
    if (name ~= '' and (name:find('map', 1, true) or
            name:find('region', 1, true) or name:find('widescan', 1, true) or
            name:find('wide', 1, true))) then return true; end
    if (ffxi ~= nil) then
        local ok, open = pcall(function () return ffxi.IsMapOpen(); end);
        if (ok and open) then return true; end
    end
    return false;
end

local function system_list_open(name)
    if (name == '' or neutral(name)) then
        system_list_menu_latched = false;
        return false;
    end
    if (system_list_menu_latched) then return true; end
    if (name_contains(name, {
            'mission', 'quest', 'keyitem', 'keyitm', 'viewhouse',
            'moghouse', 'mogmenu', 'mogcont', 'furnish', 'layout',
            'storage', 'bazaar', 'bazar', 'macro',
        })) then
        system_list_menu_latched = true;
        return true;
    end
    return false;
end

local function player_search_open(name)
    if (name == '' or neutral(name)) then
        if (name == '' and player_search_menu_latched and
                not player_search_menu_seen and
                os.clock() < player_search_command_armed_until) then return true; end
        if (name == '' and player_search_menu_latched and
                player_search_menu_seen and
                os.clock() < player_search_transition_hold_until) then return true; end
        player_search_menu_latched = false;
        player_search_command_armed_until = 0;
        player_search_menu_seen = false;
        player_search_transition_hold_until = 0;
        return false;
    end
    if (player_search_menu_latched) then
        player_search_menu_seen = true;
        player_search_transition_hold_until = os.clock() + 1.25;
        return true;
    end
    if (name_contains(name, { 'search', 'srch', 'shresult', 'searchres', 'playerfind' })) then
        player_search_menu_latched = true;
        player_search_menu_seen = true;
        player_search_transition_hold_until = os.clock() + 1.25;
        return true;
    end
    return false;
end

function menu.arm_player_search()
    player_search_menu_latched = true;
    player_search_menu_seen = false;
    player_search_command_armed_until = os.clock() + 5.0;
    player_search_transition_hold_until = 0;
end

function menu.should_hide()
    -- Used Metrics as a reference for hiding the GUI.
    local name = menu.get_name():lower();
    if (hidden_menu_types[name]) then return true; end
    if (blue_magic_setting_open(name)) then return true; end
    if (map_open(name)) then return true; end
    if (name:find('equip', 1, true) or name:find('eqp', 1, true)) then return true; end
    if (name:find('item', 1, true) or name:find('itm', 1, true)) then return true; end
    if (name:find('curr', 1, true) or name:find('pointlist', 1, true) or
            name:find('points', 1, true)) then return true; end
    if (name_contains(name, {
            'config', 'scoption', 'optionwi', 'keyassign', 'keybind',
            'gamepad', 'controller', 'keyboard', 'mousecfg', 'chatcfg',
            'windowcfg', 'fontcfg', 'effectcfg', 'miscfg', 'filtercfg',
        })) then return true; end
    if (name_contains(name, {
            'sortyn', 'itmsort', 'mgcsort', 'abisort', 'autosort',
            'manualsort', 'sortmenu', 'sortwi',
        })) then return true; end
    if (name ~= '' and not neutral(name) and
            (name:match('^link%d+$') or name:find('linkshell', 1, true))) then
        return true;
    end
    return system_list_open(name) or player_search_open(name);
end

return menu;
