local settings = {};

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value));
end

function settings.new(state, json, path)
    local api = {};

    function api.load()
        local file = io.open(path, 'rb');
        if (file == nil) then return; end
        local contents = file:read('*all');
        file:close();

        local ok, saved = pcall(function () return json.decode(contents); end);
        if (not ok or type(saved) ~= 'table') then return; end

        if (type(saved.ui_scale) == 'number') then
            state.ui_scale[1] = clamp(saved.ui_scale, 0.50, 1.75);
        end
        local boolean_values = {
            auto_hide_combat = state.auto_hide_combat,
            auto_hide_main_menu = state.auto_hide_main_menu,
            show_on_load = state.show_on_load,
            learn_message_enabled = state.learn_message_enabled,
            mob_spell_message_enabled = state.mob_spell_message_enabled,
            detect_known_spells = state.detect_known_spells,
            show_mob_ids = state.show_mob_ids,
            update_check_enabled = state.update_check_enabled,
        };
        for key, destination in pairs(boolean_values) do
            if (type(saved[key]) == 'boolean') then destination[1] = saved[key]; end
        end
        if (type(saved.readme_dismissed) == 'boolean') then
            state.readme_dismissed = saved.readme_dismissed;
            state.show_readme_window[1] = not saved.readme_dismissed;
        end
        if (type(saved.learn_message_x) == 'number' and
                type(saved.learn_message_y) == 'number') then
            state.learn_message_position = { saved.learn_message_x, saved.learn_message_y, };
        end
        if (type(saved.learn_message_scale) == 'number') then
            state.learn_message_scale[1] = clamp(saved.learn_message_scale, 0.75, 2.50);
        end
        if (type(saved.mob_list_background_opacity) == 'number') then
            state.mob_list_background_opacity[1] =
                clamp(saved.mob_list_background_opacity, 0.0, 1.0);
        end
        if (type(saved.mob_spell_message_scale) == 'number') then
            state.mob_spell_message_scale[1] =
                clamp(saved.mob_spell_message_scale, 0.75, 2.50);
        end
        if (type(saved.mob_spell_message_x) == 'number' and
                type(saved.mob_spell_message_y) == 'number') then
            state.mob_spell_message_position = {
                saved.mob_spell_message_x, saved.mob_spell_message_y,
            };
        end
    end

    function api.save()
        local saved = {
            ui_scale = state.ui_scale[1],
            auto_hide_combat = state.auto_hide_combat[1],
            auto_hide_main_menu = state.auto_hide_main_menu[1],
            show_on_load = state.show_on_load[1],
            readme_dismissed = state.readme_dismissed,
            learn_message_x = state.learn_message_position[1],
            learn_message_y = state.learn_message_position[2],
            learn_message_scale = state.learn_message_scale[1],
            learn_message_enabled = state.learn_message_enabled[1],
            mob_spell_message_enabled = state.mob_spell_message_enabled[1],
            detect_known_spells = state.detect_known_spells[1],
            show_mob_ids = state.show_mob_ids[1],
            update_check_enabled = state.update_check_enabled[1],
            mob_list_background_opacity = state.mob_list_background_opacity[1],
            mob_spell_message_scale = state.mob_spell_message_scale[1],
            mob_spell_message_x = state.mob_spell_message_position[1],
            mob_spell_message_y = state.mob_spell_message_position[2],
        };
        local ok, contents = pcall(function () return json.encode(saved); end);
        if (not ok or contents == nil) then
            state.settings_message = 'Unable to encode settings.';
            return false;
        end
        local file = io.open(path, 'wb');
        if (file == nil) then
            state.settings_message = 'Unable to open the settings file.';
            return false;
        end
        file:write(contents);
        file:close();
        state.settings_message = 'Settings saved.';
        return true;
    end

    function api.reset()
        state.ui_scale[1] = 0.75;
        state.view_mode[1] = 2;
        state.trait_level_filter[1] = 0;
        state.trait_name_filter[1] = 0;
        state.auto_hide_combat[1] = false;
        state.auto_hide_main_menu[1] = false;
        state.show_on_load[1] = true;
        state.readme_dismissed = false;
        state.readme_do_not_show_again[1] = false;
        state.show_readme_window[1] = true;
        state.learn_message_enabled[1] = true;
        state.learn_message_scale[1] = 1.25;
        state.learn_message_position = { 20, 120, };
        state.mob_spell_message_enabled[1] = true;
        state.detect_known_spells[1] = false;
        state.show_mob_ids[1] = true;
        state.update_check_enabled[1] = true;
        state.mob_list_background_opacity[1] = 0.50;
        state.mob_spell_message_scale[1] = 1.25;
        state.mob_spell_message_position = { 20, 170, };
        state.learn_message_test = false;
        state.mob_spell_message_test = false;
        api.save();
        state.settings_message = 'All settings reset to defaults.';
    end

    return api;
end

return settings;
