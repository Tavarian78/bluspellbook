local function create_messages(state, imgui, should_hide, save_settings,
        mob_tracker, get_blue_mage_level, get_blue_magic_skill,
        get_minimum_blue_magic_skill)
    local learned_font = nil;
    local used_font = nil;
    local is_addon_hide_menu_open = should_hide;
    local get_mob_learnable_spell_names = mob_tracker.learnable_spell_names;
    local is_blue_spell_known = mob_tracker.is_spell_known;
    local get_blue_spell_state = mob_tracker.spell_state;

local function get_learnable_spell_color(spell_name, blue_mage_level,
        blue_magic_skill)
    if (is_blue_spell_known(spell_name)) then return 'FF59FF73'; end
    local spell = get_blue_spell_state(spell_name);
    if (spell ~= nil and blue_mage_level ~= nil and
            blue_magic_skill >= get_minimum_blue_magic_skill(spell.level)) then
        return 'FFFFD129';
    end
    return 'FFFF4747';
end

local function set_message_font_visible(font, visible)
    if (font == nil) then
        return false;
    end

    -- Ashita versions use different names for this setting.
    local attempts = {
        function () font:SetVisible(visible); end,
        function () font:SetVisibility(visible); end,
        function () font.Visible = visible; end,
        function () font.Visibility = visible; end,
        function () font.visible = visible; end,
        function () font.visibility = visible; end,
    };
    for _, attempt in ipairs(attempts) do
        if (pcall(attempt)) then
            return true;
        end
    end
    return false;
end


local function create_message_font(alias, position, color)
    local manager = AshitaCore:GetFontManager();
    pcall(function () manager:Delete(alias); end);
    local font = manager:Create(alias);
    if (font == nil) then
        return nil;
    end

    font:SetFontFamily('Arial');
    font:SetFontHeight(16);
    font:SetColor(color);
    font:SetBold(false);
    font:SetAutoResize(true);
    font:SetPadding(0);
    font:SetPositionX(position[1]);
    font:SetPositionY(position[2]);
    font:SetLocked(true);
    font:SetText('');
    set_message_font_visible(font, false);
    pcall(function () font:GetBackground():SetColor(0x00000000); end);
    return font;
end


local function create_message_fonts()
    learned_font = create_message_font(
        'bluspellbook_learned_message', state.learn_message_position, 0xFF59FF73
    );
    used_font = create_message_font(
        'bluspellbook_used_message', state.mob_spell_message_position, 0xFFFFD129
    );
end


local function update_used_message_background()
    if (used_font == nil) then return; end
    local opacity = math.max(0.0, math.min(1.0,
        state.mob_list_background_opacity[1]));
    local alpha = math.floor(opacity * 255 + 0.5);
    local background = nil;
    pcall(function () background = used_font:GetBackground(); end);
    if (background == nil) then return; end
    pcall(function () background:SetColor(alpha * 0x1000000); end);
    -- Ashita versions use different names for this setting.
    local visible = opacity > 0.0;
    local visible_ok = pcall(function () background:SetVisible(visible); end);
    if (not visible_ok) then
        pcall(function () background:SetVisibility(visible); end);
    end
end


local function read_font_position(font, position)
    if (font == nil) then
        return;
    end
    local ok, x, y = pcall(function ()
        return font:GetPositionX(), font:GetPositionY();
    end);
    if (ok and type(x) == 'number' and type(y) == 'number') then
        position[1] = x;
        position[2] = y;
    end
end


local function update_message_fonts()
    if (learned_font == nil or used_font == nil) then
        return;
    end

    if (is_addon_hide_menu_open()) then
        set_message_font_visible(learned_font, false);
        set_message_font_visible(used_font, false);
        return;
    end

    local learned_visible = state.learn_message_test or
        (state.learn_message_enabled[1] and state.learn_message ~= '' and
         os.time() < state.learn_message_until);
    if (not state.learn_message_test and state.learn_message ~= '' and
            os.time() >= state.learn_message_until) then
        state.learn_message = '';
    end
    learned_font:SetFontHeight(math.max(8, math.floor(13 * state.learn_message_scale[1] + 0.5)));
    local learned_text = state.learn_message_test and
        'Blue Magic learned: Test Spell! (drag to move)' or state.learn_message;
    learned_font:SetText(learned_visible and learned_text or '');
    learned_font:SetLocked(not state.learn_message_test);
    set_message_font_visible(learned_font, learned_visible);
    if (state.learn_message_test) then
        read_font_position(learned_font, state.learn_message_position);
    end

    local used_lines = {};
    if (state.mob_spell_message_test) then
        used_lines[1] = state.show_mob_ids[1] and
            'Walking Sapling [ID: BCD] - drag to move' or
            'Walking Sapling - drag to move';
        used_lines[2] = '  Sprout Smack (2)';
        used_lines[3] = '';
        used_lines[4] = state.show_mob_ids[1] and
            'Young Quadav [ID: BCE]' or 'Young Quadav';
        used_lines[5] = '  No Blue Magic used';
    else
        local blue_mage_level = get_blue_mage_level();
        local blue_magic_skill = get_blue_magic_skill();
        for _, actor_id in ipairs(state.mob_spell_tracker_order) do
            local tracker = state.mob_spell_trackers[actor_id];
            if (tracker ~= nil) then
                if (#used_lines > 0) then
                    used_lines[#used_lines + 1] = '';
                end
                if (state.show_mob_ids[1]) then
                    used_lines[#used_lines + 1] = ('%s [ID: %03X]'):fmt(
                        tracker.name, tracker.actor_id % 0x1000
                    );
                else
                    used_lines[#used_lines + 1] = tracker.name;
                end
                local learnable_names = get_mob_learnable_spell_names(tracker.name);
                if (#learnable_names > 0) then
                    local colored_names = {};
                    for _, spell_name in ipairs(learnable_names) do
                        local color = get_learnable_spell_color(
                            spell_name, blue_mage_level, blue_magic_skill
                        );
                        colored_names[#colored_names + 1] =
                            ('|c%s|%s|r'):fmt(color, spell_name);
                    end
                    used_lines[#used_lines + 1] = '  Learnable: ' ..
                        table.concat(colored_names, ', ');
                end
                if (#tracker.spell_order == 0) then
                    used_lines[#used_lines + 1] = '  No Blue Magic used';
                else
                    for _, spell_name in ipairs(tracker.spell_order) do
                        used_lines[#used_lines + 1] = ('  %s (%d)'):fmt(
                            spell_name, tracker.counts[spell_name]
                        );
                    end
                end
            end
        end
    end
    local used_visible = state.mob_spell_message_test or
        (state.mob_spell_message_enabled[1] and #used_lines > 0);
    local shift_down = false;
    pcall(function ()
        local io = imgui.GetIO();
        shift_down = io.KeyShift == true;
    end);
    used_font:SetFontHeight(math.max(8, math.floor(13 * state.mob_spell_message_scale[1] + 0.5)));
    used_font:SetPadding(math.max(0,
        math.floor(5 * state.mob_spell_message_scale[1] + 0.5)));
    used_font:SetText(used_visible and table.concat(used_lines, '\n') or '');
    -- Changing the text may reset the background.
    update_used_message_background();
    used_font:SetLocked(not state.mob_spell_message_test and not shift_down);
    set_message_font_visible(used_font, used_visible);
    if (state.mob_spell_message_test or shift_down) then
        read_font_position(used_font, state.mob_spell_message_position);
    end
    if (state.mob_move_shift_active and not shift_down) then
        save_settings();
    end
    state.mob_move_shift_active = shift_down;
end


local function toggle_message_tests()
    local testing = not (state.learn_message_test and state.mob_spell_message_test);
    state.learn_message_test = testing;
    state.mob_spell_message_test = testing;
    print(('[BluSpellbook] Message test %s.'):fmt(
        testing and 'enabled - drag both messages to move them' or
        'disabled and positions saved'
    ));
    if (not testing) then
        save_settings();
    end
end

    local function save_positions()
        read_font_position(learned_font, state.learn_message_position);
        read_font_position(used_font, state.mob_spell_message_position);
    end

    local function destroy()
        local manager = AshitaCore:GetFontManager();
        pcall(function () manager:Delete('bluspellbook_learned_message'); end);
        pcall(function () manager:Delete('bluspellbook_used_message'); end);
    end

    return {
        create = create_message_fonts,
        update = update_message_fonts,
        toggle_tests = toggle_message_tests,
        save_positions = save_positions,
        destroy = destroy,
    };
end

return create_messages;
