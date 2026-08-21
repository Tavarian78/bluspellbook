addon.name = 'bluspellbook';
addon.author = 'Tavarian';
addon.version = '0.1.2';
addon.desc = 'Browse Game Blue Mage spells by level range in an Ashita 4.3 GUI.';
addon.link = 'https://github.com/Tavarian78/bluspellbook';

require 'common';

local imgui = require 'imgui';
local json = require 'json';
local primitives = nil;
pcall(function () primitives = require 'primitives'; end);
local priorities = dofile(addon.path .. '/modules/priorities.lua');
local job_traits = dofile(addon.path .. '/modules/traits.lua');
local equipped_spells = dofile(addon.path .. '/modules/equipped_spells.lua');
local spell_rules = dofile(addon.path .. '/modules/spell_rules.lua');
local menu_detection = dofile(addon.path .. '/modules/menu_detection.lua');
local settings_module = dofile(addon.path .. '/modules/settings.lua');
local update_checker_module = dofile(addon.path .. '/modules/update_checker.lua');

local state = {
    is_open = { true, },
    spells = {},
    spells_revision = 0,
    locations = {},
    selected_range = 1,
    selected_spell_id = nil,
    active_tab = 1,
    spell_search = { '', },
    ui_scale = { 0.75, },
    view_mode = { 2, },
    trait_level_filter = { 0, },
    trait_name_filter = { 0, },
    auto_hide_combat = { false, },
    auto_hide_main_menu = { false, },
    show_on_load = { true, },
    show_readme_window = { true, },
    readme_do_not_show_again = { false, },
    readme_dismissed = false,
    readme_lines = {},
    settings_message = '',
    update_check_enabled = { true, },
    update_checking = false,
    update_available = false,
    update_status = 'Not checked.',
    learned_refresh_at = nil,
    learned_refresh_spell_id = nil,
    load_refresh_at = nil,
    known_refresh_at = nil,
    enmity_scan_at = 0,
    learn_message = '',
    learn_message_until = 0,
    learn_message_enabled = { true, },
    learn_message_test = false,
    learn_message_scale = { 1.25, },
    learn_message_position = { 20, 120, },
    mob_spell_trackers = {},
    mob_spell_tracker_order = {},
    mob_spell_message_enabled = { true, },
    detect_known_spells = { false, },
    show_mob_ids = { true, },
    mob_list_background_opacity = { 0.50, },
    mob_spell_message_test = false,
    mob_spell_message_scale = { 1.25, },
    mob_spell_message_position = { 20, 170, },
    mob_move_shift_active = false,
    pending_mob_move_actor_id = nil,
    pending_mob_move_until = 0,
};

local settings = settings_module.new(state, json, addon.path .. '/settings.json');
local load_settings = settings.load;
local save_settings = settings.save;
local reset_settings_to_defaults = settings.reset;
local update_checker = update_checker_module.new(state, json, addon.version);
local function check_for_updates()
    if (state.update_checking) then return; end
    state.update_checking = true;
    ashita.tasks.once(0.1, function () update_checker.check(); end);
end

local function load_readme_contents()
    local file = io.open(addon.path .. '/README.md', 'rb');
    if (file == nil) then
        state.readme_lines = { 'README.md could not be opened.', };
        return;
    end
    local contents = file:read('*all') or '';
    file:close();
    state.readme_lines = {};
    for line in (contents .. '\n'):gmatch('(.-)\r?\n') do
        table.insert(state.readme_lines, line);
    end
end

local is_main_menu_open = menu_detection.is_main_open;
local is_addon_hide_menu_open = menu_detection.should_hide;

local required_spells = priorities.required;
local recommended_spells = priorities.recommended;

local ranges = spell_rules.ranges;
local element_names = spell_rules.element_names;
local horizon_level_overrides = spell_rules.level_overrides;
local excluded_spells = spell_rules.excluded_spells;
local get_minimum_blue_magic_skill = spell_rules.get_minimum_blue_magic_skill;

local function get_blue_mage_level()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then
        return nil;
    end

    local ok, main_job, main_level, sub_job, sub_level = pcall(function ()
        return player:GetMainJob(), player:GetMainJobLevel(),
            player:GetSubJob(), player:GetSubJobLevel();
    end);
    if (not ok) then
        return nil;
    end

    if (main_job == 16 and type(main_level) == 'number' and main_level > 0) then
        return math.min(main_level, 75);
    end
    if (sub_job == 16 and type(sub_level) == 'number' and sub_level > 0) then
        return math.min(sub_level, 75);
    end
    return nil;
end

local function get_blue_magic_skill()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then
        return 0;
    end

    local ok, skill = pcall(function ()
        return player:GetRawStructure().CombatSkills.BlueMagic:GetSkill();
    end);
    if (ok and type(skill) == 'number') then
        return skill;
    end
    return 0;
end

local function select_current_level_range()
    local level = get_blue_mage_level();
    if (level == nil) then
        return;
    end

    for index, range in ipairs(ranges) do
        if (level >= range[1] and level <= range[2]) then
            state.selected_range = index;
            state.selected_spell_id = nil;
            return;
        end
    end
end

local function load_spells()
    local spells = {};
    local resources = AshitaCore:GetResourceManager();
    local player = AshitaCore:GetMemoryManager():GetPlayer();

    for id = 0, 2048 do
        local resource = resources:GetSpellById(id);
        if (resource ~= nil and resource.Skill == 43) then
            local name = resource.Name[1];
            local level = horizon_level_overrides[name] or resource.LevelRequired[17];
            if (level ~= nil and level > 0 and level <= 75 and
                    not excluded_spells[name]) then
                spells[#spells + 1] = {
                    id = id,
                    name = name,
                    level = level,
                    element = resource.Element,
                    known = player ~= nil and player:HasSpell(id) or false,
                };
            end
        end
    end

    table.sort(spells, function (left, right)
        return left.level < right.level or
            (left.level == right.level and left.name < right.name);
    end);

    state.spells = spells;
    state.spells_revision = state.spells_revision + 1;
end

local function refresh_known_spells()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (player == nil) then
        return false;
    end

    for _, spell in ipairs(state.spells) do
        local ok, known = pcall(function ()
            return player:HasSpell(spell.id);
        end);
        if (ok) then
            local was_known = spell.known;
            spell.known = spell.known or known;
            if (spell.known ~= was_known) then
                state.spells_revision = state.spells_revision + 1;
            end
        end
    end
end

local function load_locations()
    local file = io.open(addon.path .. '/data/spells.json', 'rb');
    if (file == nil) then
        state.locations = {};
        return;
    end

    local contents = file:read('*all');
    file:close();
    state.locations = json.decode(contents) or {};
end

local gui_views_factory = dofile(addon.path .. '/modules/gui_views.lua');
local gui_views = gui_views_factory({
    state = state,
    imgui = imgui,
    ranges = ranges,
    required_spells = required_spells,
    recommended_spells = recommended_spells,
    element_names = element_names,
    job_traits = job_traits,
    get_equipped_spell_names = equipped_spells.get_names,
    get_blue_mage_level = get_blue_mage_level,
    get_blue_magic_skill = get_blue_magic_skill,
    get_minimum_blue_magic_skill = get_minimum_blue_magic_skill,
});
local draw_range_column = gui_views.draw_ranges;
local draw_spell_list = gui_views.draw_spells;
local draw_location_column = gui_views.draw_locations;
local draw_job_traits = gui_views.draw_traits;

local mob_tracker_factory = dofile(addon.path .. '/modules/mob_tracker.lua');
local mob_tracker = mob_tracker_factory(state);
local ensure_mob_spell_tracker = mob_tracker.ensure;
local remove_mob_spell_tracker = mob_tracker.remove;
local get_party_server_ids = mob_tracker.party_ids;
local track_party_enmity_action = mob_tracker.track_enmity_action;
local track_party_battle_targets = mob_tracker.scan_party_targets;
local record_mob_blue_spell = mob_tracker.record_spell;
local update_mob_spell_tracker = mob_tracker.update;
local increment_mob_spell = mob_tracker.increment;
local find_blue_spell_in_text = mob_tracker.spell_in_text;

local message_factory = dofile(addon.path .. '/modules/messages.lua');
local messages = message_factory(
    state, imgui, is_addon_hide_menu_open, save_settings, mob_tracker
);
local create_message_fonts = messages.create;
local update_message_fonts = messages.update;
local toggle_message_tests = messages.toggle_tests;



local function print_command_help()
    print('[BluSpellbook] Commands:');
    print('  /bsb - Toggle the main Spellbook GUI.');
    print('  /bsb show - Open the main GUI when BLU is main or subjob.');
    print('  /bsb hide - Close the main GUI.');
    print('  /bsb refresh - Refresh learned-spell status from client memory.');
    print('  /bsb test - Toggle both draggable on-screen message previews.');
    print('  /bsb help - Display this command list.');
end

local gui_shell_factory = dofile(addon.path .. '/modules/gui_shell.lua');
local gui_shell = gui_shell_factory({
    state = state,
    imgui = imgui,
    primitives = primitives,
    get_blue_mage_level = get_blue_mage_level,
    is_addon_hide_menu_open = is_addon_hide_menu_open,
    is_main_menu_open = is_main_menu_open,
    load_spells = load_spells,
    draw_range_column = draw_range_column,
    draw_spell_list = draw_spell_list,
    draw_location_column = draw_location_column,
    draw_job_traits = draw_job_traits,
    toggle_message_tests = toggle_message_tests,
    save_settings = save_settings,
    reset_settings_to_defaults = reset_settings_to_defaults,
    check_for_updates = check_for_updates,
});
local create_readme_banner = gui_shell.create_banner;
local draw_window = gui_shell.draw;
local draw_readme_window = gui_shell.draw_readme;

local register_events = dofile(addon.path .. '/modules/events.lua');
register_events({
    state = state,
    menu_detection = menu_detection,
    load_settings = load_settings,
    load_readme_contents = load_readme_contents,
    create_readme_banner = create_readme_banner,
    create_message_fonts = create_message_fonts,
    load_locations = load_locations,
    load_spells = load_spells,
    refresh_known_spells = refresh_known_spells,
    select_current_level_range = select_current_level_range,
    toggle_message_tests = toggle_message_tests,
    print_command_help = print_command_help,
    remove_mob_spell_tracker = remove_mob_spell_tracker,
    find_blue_spell_in_text = find_blue_spell_in_text,
    ensure_mob_spell_tracker = ensure_mob_spell_tracker,
    increment_mob_spell = increment_mob_spell,
    get_party_server_ids = get_party_server_ids,
    track_party_enmity_action = track_party_enmity_action,
    record_mob_blue_spell = record_mob_blue_spell,
    track_party_battle_targets = track_party_battle_targets,
    update_mob_spell_tracker = update_mob_spell_tracker,
    draw_readme_window = draw_readme_window,
    draw_window = draw_window,
    update_message_fonts = update_message_fonts,
    messages = messages,
    save_settings = save_settings,
    gui_shell = gui_shell,
    check_for_updates = check_for_updates,
});
