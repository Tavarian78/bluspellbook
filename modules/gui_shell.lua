local function create_shell(context)
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

local readme_banner = nil;

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
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8 * scale, 8 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 4 * scale, 3 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8 * scale, 4 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_ItemInnerSpacing, { 4 * scale, 4 * scale });
    imgui.PushStyleVar(ImGuiStyleVar_IndentSpacing, 21 * scale);
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarSize, 14 * scale);
    imgui.PushStyleVar(ImGuiStyleVar_GrabMinSize, 10 * scale);
    return 7;
end

local function push_title_bar_style()
    imgui.PushStyleColor(ImGuiCol_TitleBg, { 0.012, 0.031, 0.09, 1.0 });
    imgui.PushStyleColor(ImGuiCol_TitleBgActive, { 0.0, 0.42, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_TitleBgCollapsed, { 0.0, 0.24, 0.78, 1.0 });
end

local function push_control_style()
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.165, 0.255, 0.405, 0.94 });
    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.190, 0.245, 0.340, 0.92 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.12, 0.30, 0.52, 0.72 });
    imgui.PushStyleColor(ImGuiCol_Text, { 0.93, 0.97, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_TextDisabled, { 0.62, 0.86, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_FrameBg, { 0.043, 0.071, 0.125, 1.0 });
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, { 0.055, 0.24, 0.48, 1.0 });
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, { 0.0, 0.48, 0.84, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Button, { 0.063, 0.094, 0.153, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.055, 0.30, 0.60, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.0, 0.52, 0.82, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Header, { 0.078, 0.13, 0.24, 1.0 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.055, 0.30, 0.60, 1.0 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.0, 0.48, 0.78, 1.0 });
    imgui.PushStyleColor(ImGuiCol_CheckMark, { 0.30, 0.92, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_SliderGrab, { 0.0, 0.66, 0.92, 1.0 });
    imgui.PushStyleColor(ImGuiCol_SliderGrabActive, { 0.30, 0.92, 1.0, 1.0 });
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.190, 0.245, 0.340, 0.97 });
    return 18;
end

local function push_gold_button_style()
    imgui.PushStyleColor(ImGuiCol_Button, { 0.57, 0.40, 0.05, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.91, 0.71, 0.21, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 1.0, 0.80, 0.24, 1.0 });
end

local function push_red_button_style()
    imgui.PushStyleColor(ImGuiCol_Button, { 0.48, 0.09, 0.25, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.84, 0.18, 0.40, 1.0 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.94, 0.27, 0.49, 1.0 });
end

local function push_scaled_font(scale)
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
    if (imgui.Button(label .. '##main_tab', { 120 * scale, 24 * scale })) then
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

    if (is_addon_hide_menu_open()) then
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
    imgui.SetNextWindowSize({ 900 * scale, 520 * scale });
    if (imgui.Begin('Blue Mage Spellbook', state.is_open, ImGuiWindowFlags_NoResize)) then
        draw_main_tab_button('Spell Browser', 1, scale,
            { 0.09, 0.38, 0.54, 1.0 }, { 0.16, 0.59, 0.75, 1.0 },
            { 0.13, 0.52, 0.68, 1.0 }, { 0.95, 0.98, 1.00, 1.0 });
        imgui.SameLine();
        draw_main_tab_button('Job Traits', 2, scale,
            { 0.05, 0.22, 0.43, 1.0 }, { 0.08, 0.42, 0.68, 1.0 },
            { 0.07, 0.34, 0.62, 1.0 }, { 0.97, 0.99, 1.00, 1.0 });
        imgui.SameLine();
        draw_main_tab_button('Options', 3, scale,
            { 0.12, 0.17, 0.25, 1.0 }, { 0.15, 0.31, 0.48, 1.0 },
            { 0.10, 0.39, 0.62, 1.0 }, { 0.97, 0.99, 1.00, 1.0 });
        imgui.Separator();

            if (state.active_tab == 1) then
                imgui.SetNextItemWidth(150 * scale);
                if (imgui.Combo('##priority_filter', state.view_mode, 'Required\0Recommended\0All\0\0')) then
                    state.selected_spell_id = nil;
                end
                imgui.SameLine();
                if (imgui.Button('Refresh')) then
                    load_spells();
                end
                imgui.SameLine();
                imgui.TextColored({ 0.35, 1.0, 0.45, 1.0 }, 'Green learned');
                imgui.SameLine();
                imgui.TextDisabled('|');
                imgui.SameLine();
                imgui.TextColored({ 1.0, 0.82, 0.16, 1.0 }, 'Yellow ready');
                imgui.SameLine();
                imgui.TextDisabled('|');
                imgui.SameLine();
                imgui.TextColored({ 1.0, 0.28, 0.28, 1.0 }, 'Red locked');
                imgui.SameLine();
                local wiki_button_width = 170 * scale;
                local wiki_button_x = imgui.GetWindowWidth() - wiki_button_width - (10 * scale);
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
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Interface Scale');
                imgui.TextWrapped('Adjust the entire Blue Mage Spellbook proportionally, including text, spacing, columns, controls, and the window itself.');
                imgui.Checkbox('Open GUI when addon loads', state.show_on_load);
                imgui.Spacing();
                imgui.SetNextItemWidth(300 * scale);
                imgui.SliderFloat('GUI Scale', state.ui_scale, 0.50, 1.75, '%.2fx');
                imgui.SameLine();
                push_red_button_style();
                if (imgui.Button('Reset')) then
                    state.ui_scale[1] = 0.75;
                end
                imgui.PopStyleColor(3);
                imgui.Separator();
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Combat Behavior');
                imgui.Checkbox('Auto-hide while engaged', state.auto_hide_combat);
                imgui.TextWrapped('When enabled, the window hides during combat and automatically returns after disengaging.');
                imgui.Separator();
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Menu Behavior');
                imgui.Checkbox('Auto-hide while the main menu is open', state.auto_hide_main_menu);
                imgui.TextWrapped('Hides only for the right-side FFXI main menu. The lower-left Attack, Magic, Abilities, Items, and Disengage command menu will not hide the spellbook.');
                imgui.Separator();
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Learned Spell Message');
                imgui.TextWrapped('Adjust the size of the five-second learned-spell notification. Use /bsb test to preview and move it.');
                imgui.Checkbox('Enable learned-spell message', state.learn_message_enabled);
                imgui.SetNextItemWidth(300 * scale);
                imgui.SliderFloat('Message Scale', state.learn_message_scale, 0.75, 2.50, '%.2fx');
                imgui.SameLine();
                push_red_button_style();
                if (imgui.Button('Message Reset')) then
                    state.learn_message_scale[1] = 1.25;
                end
                imgui.PopStyleColor(3);
                imgui.Separator();
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Blue Magic Used Message');
                imgui.TextWrapped('Adjust the persistent monster Blue Magic use counter. Use /bsb test or Test Messages to preview and move it.');
                imgui.TextWrapped('During normal use, hold Shift and click-drag the list to move it. The position saves when Shift is released.');
                imgui.Checkbox('Enable Blue Magic used message', state.mob_spell_message_enabled);
                imgui.Checkbox('Detect spells even when already known', state.detect_known_spells);
                imgui.TextWrapped('When enabled, mobs and move counters remain eligible even after their Blue Magic spell has been learned.');
                imgui.Checkbox('Show mob IDs', state.show_mob_ids);
                imgui.SetNextItemWidth(300 * scale);
                imgui.SliderFloat('List Background Opacity', state.mob_list_background_opacity, 0.0, 1.0, '%.2f');
                imgui.SetNextItemWidth(300 * scale);
                imgui.SliderFloat('Used Message Scale', state.mob_spell_message_scale, 0.75, 2.50, '%.2fx');
                imgui.SameLine();
                push_red_button_style();
                if (imgui.Button('Used Reset')) then
                    state.mob_spell_message_scale[1] = 1.25;
                end
                imgui.PopStyleColor(3);
                imgui.Separator();
                imgui.Spacing();
                local test_label = state.learn_message_test and state.mob_spell_message_test and
                    'Stop Message Test' or 'Test Messages';
                if (imgui.Button(test_label, { 150 * scale, 34 * scale })) then
                    toggle_message_tests();
                end
                imgui.SameLine();
                push_gold_button_style();
                if (imgui.Button('Save Settings', { 150 * scale, 34 * scale })) then
                    save_settings();
                end
                imgui.PopStyleColor(3);
                imgui.SameLine();
                push_red_button_style();
                if (imgui.Button('Reset All Settings', { 170 * scale, 34 * scale })) then
                    reset_settings_to_defaults();
                end
                imgui.PopStyleColor(3);
                imgui.SameLine();
                if (imgui.Button('README', { 120 * scale, 34 * scale })) then
                    state.readme_do_not_show_again[1] = false;
                    state.show_readme_window[1] = true;
                end
                if (state.settings_message ~= '') then
                    imgui.TextColored({ 0.35, 1.0, 0.45, 1.0 }, state.settings_message);
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
    if (is_addon_hide_menu_open()) then
        return;
    end

    local scale = state.ui_scale[1];
    local style_count = push_scaled_style(scale);
    local font_state = push_scaled_font(scale);
    local control_color_count = push_control_style();
    push_title_bar_style();
    imgui.SetNextWindowSize({ 1050 * scale, 700 * scale });
    if (imgui.Begin('BluSpellbook README', state.show_readme_window,
            ImGuiWindowFlags_NoResize + ImGuiWindowFlags_NoBackground)) then
        local banner_drawn = false;
        if (readme_banner ~= nil) then
            local cursor_x, cursor_y = imgui.GetCursorScreenPos();
            local banner_width = 748 * scale;
            local banner_height = banner_width / 3.0;
            readme_banner.position_x = cursor_x + (200 * scale);
            readme_banner.position_y = cursor_y;
            readme_banner.scale_x = banner_width / 1024.0;
            readme_banner.scale_y = banner_height / 341.0;
            readme_banner.visible = true;
            imgui.Dummy({ 0, banner_height });
            banner_drawn = true;
        end
        if (not banner_drawn) then
            imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 },
                'Welcome to BluSpellbook');
        end
        imgui.Separator();
        imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.165, 0.255, 0.405, 0.94 });
        imgui.BeginChild('##bluspellbook_readme_scroll',
            { 0, -48 * scale }, 1, 0);
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
        imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.165, 0.255, 0.405, 0.94 });
        imgui.BeginChild('##bluspellbook_readme_footer',
            { 0, 36 * scale }, 0, 0);
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
