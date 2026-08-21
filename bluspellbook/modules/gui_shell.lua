local function create_shell(context)
    local theme = dofile(addon.path .. '/modules/theme.lua');
    local state = context.state;
    local imgui = context.imgui;
    local primitives = context.primitives;
    local get_blue_mage_level = context.get_blue_mage_level;
    local is_addon_hide_menu_open = context.is_addon_hide_menu_open;
    local is_main_menu_open = context.is_main_menu_open;
    local load_spells = context.load_spells;
    local draw_range_column = context.draw_range_column;
    local draw_spell_list = context.draw_spell_list;
    local draw_location_column = context.draw_location_column;
    local draw_job_traits = context.draw_job_traits;
    local toggle_message_tests = context.toggle_message_tests;
    local save_settings = context.save_settings;
    local reset_settings_to_defaults = context.reset_settings_to_defaults;
    local check_for_updates = context.check_for_updates;

local readme_banner = nil;
local main_window_collapsed = false;

local function create_readme_banner()
    if (primitives == nil or readme_banner ~= nil) then
        return;
    end

    local ok, banner = pcall(function ()
        local object = primitives.new({
            texture_offset_x = 0.0,
            texture_offset_y = 0.0,
            border_visible = false,
            visible = false,
            position_x = 0,
            position_y = 0,
            can_focus = false,
            locked = true,
            lockedz = false,
            scale_x = 1.0,
            scale_y = 1.0,
            width = 1024.0,
            height = 341.0,
            color = 0xFFFFFFFF,
        });
        object.texture = addon.path .. '/assets/bluspellbook-graffiti-banner.png';
        return object;
    end);
    if (ok) then
        readme_banner = banner;
    end
end

local function hide_readme_banner()
    if (readme_banner ~= nil) then
        readme_banner.visible = false;
    end
end

local function push_scaled_style(scale)
    local style = theme.layout.style;
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding,
        { style.window_padding[1] * scale, style.window_padding[2] * scale });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding,
        { style.frame_padding[1] * scale, style.frame_padding[2] * scale });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing,
        { style.item_spacing[1] * scale, style.item_spacing[2] * scale });
    imgui.PushStyleVar(ImGuiStyleVar_ItemInnerSpacing,
        { style.item_inner_spacing[1] * scale, style.item_inner_spacing[2] * scale });
    imgui.PushStyleVar(ImGuiStyleVar_IndentSpacing, style.indent * scale);
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarSize, style.scrollbar * scale);
    imgui.PushStyleVar(ImGuiStyleVar_GrabMinSize, style.grab * scale);
    return 7;
end

local function push_title_bar_style()
    imgui.PushStyleColor(ImGuiCol_TitleBg, theme.title.normal);
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, theme.title.active);
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, theme.title.collapsed);
end

local function push_control_style()
    imgui.PushStyleColor(ImGuiCol_WindowBg, theme.window.background);
    imgui.PushStyleColor(ImGuiCol_ChildBg, theme.window.child);
    imgui.PushStyleColor(ImGuiCol_Border, theme.window.border);
    imgui.PushStyleColor(ImGuiCol_Text, theme.text.normal);
    imgui.PushStyleColor(ImGuiCol_TextDisabled, theme.text.disabled);
    imgui.PushStyleColor(ImGuiCol_FrameBg, theme.frame.normal);
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, theme.frame.hover);
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, theme.frame.active);
    imgui.PushStyleColor(ImGuiCol_Button, theme.button.normal);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.button.hover);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.button.active);
    imgui.PushStyleColor(ImGuiCol_Header, theme.header.normal);
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, theme.header.hover);
    imgui.PushStyleColor(ImGuiCol_HeaderActive, theme.header.active);
    imgui.PushStyleColor(ImGuiCol_CheckMark, theme.accent.check);
    imgui.PushStyleColor(ImGuiCol_SliderGrab, theme.accent.slider);
    imgui.PushStyleColor(ImGuiCol_SliderGrabActive, theme.accent.slider_active);
    imgui.PushStyleColor(ImGuiCol_PopupBg, theme.window.popup);
    return 18;
end

local function push_gold_button_style()
    imgui.PushStyleColor(ImGuiCol_Button, theme.gold_button.normal);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.gold_button.hover);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.gold_button.active);
end

local function push_red_button_style()
    imgui.PushStyleColor(ImGuiCol_Button, theme.red_button.normal);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, theme.red_button.hover);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, theme.red_button.active);
end

local function push_scaled_font(scale)
    -- Redundant fallbacks are still an issue. Try to simplify this later.
    -- Use this addon's own font when Ashita makes one available.
    local current_font = imgui.GetFont();
    local current_size = imgui.GetFontSize();
    if (current_font ~= nil and type(current_size) == 'number') then
        local wanted_size = math.max(6, current_size * scale);
        local pushed = pcall(function ()
            imgui.PushFont(current_font, wanted_size);
        end);
        if (pushed) then
            return { font = current_font, dynamic_size = true };
        end
    end

    -- Otherwise, use the closest font Ashita already loaded.
    local io_ok, io = pcall(imgui.GetIO);
    if (io_ok and io ~= nil and current_font ~= nil and type(current_size) == 'number') then
        local atlas_ok, fonts = pcall(function () return io.Fonts.Fonts; end);
        if (atlas_ok and fonts ~= nil) then
            local wanted_size = current_size * scale;
            local best_font = nil;
            local best_distance = math.huge;
            local seen = {};
            for index = 0, 64 do
                local item_ok, candidate = pcall(function () return fonts[index]; end);
                if (item_ok and candidate ~= nil and not seen[candidate]) then
                    seen[candidate] = true;
                    local size_ok, candidate_size = pcall(function () return candidate.FontSize; end);
                    if (size_ok and type(candidate_size) == 'number') then
                        local distance = math.abs(candidate_size - wanted_size);
                        if (distance < best_distance) then
                            best_font = candidate;
                            best_distance = distance;
                        end
                    end
                end
            end
            if (best_font ~= nil) then
                local pushed = pcall(function () imgui.PushFont(best_font); end);
                if (pushed) then
                    return { font = best_font, atlas_font = true };
                end
            end
        end
    end

    -- Some Ashita versions accept a size change but do not apply it.
    local io_ok, io = pcall(imgui.GetIO);
    if (io_ok and io ~= nil) then
        local scale_ok, original_global_scale = pcall(function ()
            return io.FontGlobalScale;
        end);
        if (scale_ok and type(original_global_scale) == 'number') then
            local wanted_global_scale = original_global_scale * scale;
            local changed = pcall(function ()
                io.FontGlobalScale = wanted_global_scale;
            end);
            local verify_ok, applied_global_scale = pcall(function ()
                return io.FontGlobalScale;
            end);
            if (changed and verify_ok and type(applied_global_scale) == 'number' and
                math.abs(applied_global_scale - wanted_global_scale) < 0.001) then
                return {
                    io = io,
                    original_global_scale = original_global_scale,
                };
            end
            pcall(function () io.FontGlobalScale = original_global_scale; end);
        end
    end

    -- Older Ashita versions may only support font scaling.
    local font = imgui.GetFont();
    if (font == nil) then
        return nil;
    end

    local ok, original_scale = pcall(function ()
        return font.Scale;
    end);
    if (not ok or original_scale == nil) then
        return nil;
    end

    local wanted_scale = original_scale * scale;
    local changed = pcall(function ()
        font.Scale = wanted_scale;
    end);
    local verify_ok, applied_scale = pcall(function ()
        return font.Scale;
    end);
    if (not changed or not verify_ok or type(applied_scale) ~= 'number' or
        math.abs(applied_scale - wanted_scale) >= 0.001) then
        pcall(function () font.Scale = original_scale; end);
        return nil;
    end

    local pushed = pcall(function ()
        imgui.PushFont(font);
    end);
    if (not pushed) then
        pcall(function () font.Scale = original_scale; end);
        return nil;
    end

    return { font = font, original_scale = original_scale };
end


local function pop_scaled_font(font_state)
    if (font_state == nil) then
        return;
    end

    if (font_state.io ~= nil) then
        pcall(function ()
            font_state.io.FontGlobalScale = font_state.original_global_scale;
        end);
        return;
    end

    imgui.PopFont();
    if (font_state.atlas_font or font_state.dynamic_size) then
        return;
    end
    pcall(function ()
        font_state.font.Scale = font_state.original_scale;
    end);
end


local function draw_main_tab_button(label, index, scale, normal_color, hover_color,
        selected_color, text_color)
    local button_color = state.active_tab == index and selected_color or normal_color;
    imgui.PushStyleColor(ImGuiCol_Button, button_color);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, hover_color);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, selected_color);
    imgui.PushStyleColor(ImGuiCol_Text, text_color);
    local size = theme.layout.tab_button;
    if (imgui.Button(label .. '##main_tab',
            { size.width * scale, size.height * scale })) then
        state.active_tab = index;
    end
    imgui.PopStyleColor(4);
end

local function draw_window()
    if (not state.is_open[1]) then
        return;
    end

    if (get_blue_mage_level() == nil) then
        return;
    end

    if (state.auto_hide_main_menu[1] and is_addon_hide_menu_open()) then
        return;
    end

    if (state.auto_hide_combat[1]) then
        local player = GetPlayerEntity();
        if (player ~= nil and player.Status == 1) then
            return;
        end
    end

    if (state.auto_hide_main_menu[1] and is_main_menu_open()) then
        return;
    end

    local scale = state.ui_scale[1];
    local style_count = push_scaled_style(scale);
    local font_state = push_scaled_font(scale);
    local control_color_count = push_control_style();
    push_title_bar_style();
    local window = theme.layout.main_window;
    local window_width = main_window_collapsed and
        window.collapsed_width or window.width;
    imgui.SetNextWindowSize({ window_width * scale, window.height * scale });
    local window_visible = imgui.Begin(
        'Blue Mage Spellbook', state.is_open, ImGuiWindowFlags_NoResize
    );
    main_window_collapsed = not window_visible;
    if (window_visible) then
        draw_main_tab_button('Spell Browser', 1, scale,
            theme.tab.spell.normal, theme.tab.spell.hover,
            theme.tab.spell.active, theme.tab.spell.text);
        imgui.SameLine();
        draw_main_tab_button('Job Traits', 2, scale,
            theme.tab.traits.normal, theme.tab.traits.hover,
            theme.tab.traits.active, theme.tab.traits.text);
        imgui.SameLine();
        draw_main_tab_button('Options', 3, scale,
            theme.tab.options.normal, theme.tab.options.hover,
            theme.tab.options.active, theme.tab.options.text);
        imgui.Separator();

            if (state.active_tab == 1) then
                imgui.SetNextItemWidth(theme.layout.options.filter_width * scale);
                if (imgui.Combo('##priority_filter', state.view_mode, 'Required\0Recommended\0All\0\0')) then
                    state.selected_spell_id = nil;
                end
                imgui.SameLine();
                if (imgui.Button('Refresh')) then
                    load_spells();
                end
                imgui.SameLine();
                imgui.TextColored(theme.status.green, 'Green learned');
                imgui.SameLine();
                imgui.TextDisabled('|');
                imgui.SameLine();
                imgui.TextColored(theme.status.yellow, 'Yellow ready');
                imgui.SameLine();
                imgui.TextDisabled('|');
                imgui.SameLine();
                imgui.TextColored(theme.status.red, 'Red locked');
                imgui.SameLine();
                local wiki_button_width = theme.layout.wiki.width * scale;
                local wiki_button_x = imgui.GetWindowWidth() - wiki_button_width -
                    (theme.layout.wiki.right_margin * scale);
                imgui.SetCursorPosX(wiki_button_x);
                if (imgui.Button('HXI Blu Wiki', { wiki_button_width, 0 })) then
                    ashita.misc.open_url('https://horizonffxi.wiki/Blue_Mage');
                end
                imgui.Separator();

                imgui.BeginGroup();
                draw_range_column();
                imgui.EndGroup();
                imgui.SameLine();
                imgui.BeginGroup();
                draw_spell_list();
                imgui.EndGroup();
                imgui.SameLine();
                imgui.BeginGroup();
                draw_location_column();
                imgui.EndGroup();
            end

            if (state.active_tab == 2) then
                draw_job_traits();
            end

            if (state.active_tab == 3) then
                imgui.BeginChild('##options_scroll', { 0, -1 }, 0, 0);
                imgui.TextColored(theme.status.blue, 'Updates');
                imgui.Checkbox('Automatically check for updates', state.update_check_enabled);
                if (state.update_available) then
                    imgui.TextColored(theme.status.yellow, state.update_status);
                elseif (state.update_status:find('Up to date', 1, true) ~= nil) then
                    imgui.TextColored(theme.status.green, state.update_status);
                else
                    imgui.TextDisabled(state.update_status);
                end
                local update_button = state.update_checking and 'Checking...' or 'Check for Updates';
                if (imgui.Button(update_button, {
                        theme.layout.options.button_width * scale,
                        theme.layout.options.update_button_height * scale
                    }) and
                        not state.update_checking) then
                    check_for_updates();
                end
                imgui.SameLine();
                if (imgui.Button('Open Releases', {
                        theme.layout.options.releases_button_width * scale,
                        theme.layout.options.update_button_height * scale
                    })) then
                    ashita.misc.open_url('https://github.com/Tavarian78/bluspellbook/releases/latest');
                end
                imgui.TextWrapped('Updates are downloaded and installed manually so your settings are not overwritten while the addon is running.');
                imgui.Separator();
                if (imgui.CollapsingHeader('Interface and Scale')) then
                    imgui.TextWrapped('Adjust the entire Blue Mage Spellbook proportionally, including text, spacing, columns, controls, and the window itself.');
                    imgui.Checkbox('Open GUI when addon loads', state.show_on_load);
                    imgui.SetNextItemWidth(theme.layout.options.control_width * scale);
                    imgui.SliderFloat('GUI Scale', state.ui_scale, 0.50, 1.75, '%.2fx');
                    imgui.SameLine();
                    push_red_button_style();
                    if (imgui.Button('Reset')) then state.ui_scale[1] = 0.75; end
                    imgui.PopStyleColor(3);
                end
                if (imgui.CollapsingHeader('Combat Behavior')) then
                    imgui.Checkbox('Auto-hide while engaged', state.auto_hide_combat);
                    imgui.TextWrapped('When enabled, the window hides during combat and automatically returns after disengaging.');
                end
                if (imgui.CollapsingHeader('Menu Behavior')) then
                    imgui.Checkbox('Auto-hide while the main menu is open', state.auto_hide_main_menu);
                    imgui.TextWrapped('Hides for FFXI menus but not the lower-left Attack, Magic, Abilities, Items, and Disengage command menu.');
                end
                if (imgui.CollapsingHeader('Learned Spell Message')) then
                    imgui.TextWrapped('Adjust the five-second learned-spell notification. Use /bsb test to preview and move it.');
                    imgui.Checkbox('Enable learned-spell message', state.learn_message_enabled);
                    imgui.SetNextItemWidth(theme.layout.options.control_width * scale);
                    imgui.SliderFloat('Message Scale', state.learn_message_scale, 0.75, 2.50, '%.2fx');
                    imgui.SameLine();
                    push_red_button_style();
                    if (imgui.Button('Message Reset')) then state.learn_message_scale[1] = 1.25; end
                    imgui.PopStyleColor(3);
                end
                if (imgui.CollapsingHeader('Blue Magic Used Message')) then
                    imgui.TextWrapped('Adjust the monster Blue Magic use list. Use /bsb test or Test Messages to preview and move it.');
                    imgui.TextWrapped('Hold Shift and click-drag the list to move it. Its position saves when Shift is released.');
                    imgui.Checkbox('Enable Blue Magic used message', state.mob_spell_message_enabled);
                    imgui.Checkbox('Detect spells even when already known', state.detect_known_spells);
                    imgui.TextWrapped('Keeps mobs and move counters eligible after their Blue Magic spell has been learned.');
                    imgui.Checkbox('Show mob IDs', state.show_mob_ids);
                    imgui.SetNextItemWidth(theme.layout.options.control_width * scale);
                    imgui.SliderFloat('List Background Opacity', state.mob_list_background_opacity, 0.0, 1.0, '%.2f');
                    imgui.SetNextItemWidth(theme.layout.options.control_width * scale);
                    imgui.SliderFloat('Used Message Scale', state.mob_spell_message_scale, 0.75, 2.50, '%.2fx');
                    imgui.SameLine();
                    push_red_button_style();
                    if (imgui.Button('Used Reset')) then state.mob_spell_message_scale[1] = 1.25; end
                    imgui.PopStyleColor(3);
                end
                imgui.Separator();
                imgui.Spacing();
                local test_label = state.learn_message_test and state.mob_spell_message_test and
                    'Stop Message Test' or 'Test Messages';
                if (imgui.Button(test_label, {
                        theme.layout.options.button_width * scale,
                        theme.layout.options.button_height * scale
                    })) then
                    toggle_message_tests();
                end
                imgui.SameLine();
                push_gold_button_style();
                if (imgui.Button('Save Settings', {
                        theme.layout.options.button_width * scale,
                        theme.layout.options.button_height * scale
                    })) then
                    save_settings();
                end
                imgui.PopStyleColor(3);
                imgui.SameLine();
                push_red_button_style();
                if (imgui.Button('Reset All Settings', {
                        theme.layout.options.wide_button_width * scale,
                        theme.layout.options.button_height * scale
                    })) then
                    reset_settings_to_defaults();
                end
                imgui.PopStyleColor(3);
                imgui.SameLine();
                if (imgui.Button('README', {
                        theme.layout.tab_button.width * scale,
                        theme.layout.options.button_height * scale
                    })) then
                    state.readme_do_not_show_again[1] = false;
                    state.show_readme_window[1] = true;
                end
                if (state.settings_message ~= '') then
                    imgui.TextColored(theme.status.green, state.settings_message);
                end
                imgui.EndChild();
            end
    end
    imgui.End();
    imgui.PopStyleColor(3);
    imgui.PopStyleColor(control_color_count);
    pop_scaled_font(font_state);
    imgui.PopStyleVar(style_count);
end


local function draw_readme_window()
    hide_readme_banner();
    if (not state.show_readme_window[1]) then
        return;
    end
    if (state.auto_hide_main_menu[1] and is_addon_hide_menu_open()) then
        return;
    end

    local scale = state.ui_scale[1];
    local style_count = push_scaled_style(scale);
    local font_state = push_scaled_font(scale);
    local control_color_count = push_control_style();
    push_title_bar_style();
    local readme = theme.layout.readme_window;
    imgui.SetNextWindowSize({ readme.width * scale, readme.height * scale });
    if (imgui.Begin('BluSpellbook README', state.show_readme_window,
            ImGuiWindowFlags_NoResize + ImGuiWindowFlags_NoBackground)) then
        local banner_drawn = false;
        if (readme_banner ~= nil) then
            local cursor_x, cursor_y = imgui.GetCursorScreenPos();
            local banner_width = theme.layout.readme.banner_width * scale;
            local banner_height = banner_width / 3.0;
            readme_banner.position_x = cursor_x +
                (theme.layout.readme.banner_offset * scale);
            readme_banner.position_y = cursor_y;
            readme_banner.scale_x = banner_width / 1024.0;
            readme_banner.scale_y = banner_height / 341.0;
            readme_banner.visible = true;
            imgui.Dummy({ 0, banner_height });
            banner_drawn = true;
        end
        if (not banner_drawn) then
            imgui.TextColored(theme.status.blue,
                'Welcome to BluSpellbook');
        end
        imgui.Separator();
        imgui.PushStyleColor(ImGuiCol_ChildBg, theme.window.background);
        imgui.BeginChild('##bluspellbook_readme_scroll',
            { 0, -theme.layout.readme.scroll_footer_space * scale }, 1, 0);
        if (#state.readme_lines == 0) then
            imgui.TextWrapped('README.md is empty.');
        else
            for _, line in ipairs(state.readme_lines) do
                if (line == '') then
                    imgui.Spacing();
                else
                    imgui.TextWrapped(line);
                end
            end
        end
        imgui.EndChild();
        imgui.PopStyleColor(1);
        imgui.Separator();
        imgui.PushStyleColor(ImGuiCol_ChildBg, theme.window.background);
        imgui.BeginChild('##bluspellbook_readme_footer',
            { 0, theme.layout.readme.footer_height * scale }, 0, 0);
        if (imgui.Checkbox('Do not show again',
                state.readme_do_not_show_again) and
                state.readme_do_not_show_again[1]) then
            state.readme_dismissed = true;
            state.show_readme_window[1] = false;
            save_settings();
        end
        imgui.EndChild();
        imgui.PopStyleColor(1);
    end
    imgui.End();
    imgui.PopStyleColor(3);
    imgui.PopStyleColor(control_color_count);
    pop_scaled_font(font_state);
    imgui.PopStyleVar(style_count);
end

    local function destroy()
        if (readme_banner ~= nil) then
            pcall(function () readme_banner:destroy(); end);
            readme_banner = nil;
        end
    end

    return {
        create_banner = create_readme_banner,
        draw = draw_window,
        draw_readme = draw_readme_window,
        destroy = destroy,
    };
end

return create_shell;
