local function register_events(context)
    local state = context.state;
    local menu_detection = context.menu_detection;
    local load_settings = context.load_settings;
    local load_readme_contents = context.load_readme_contents;
    local create_readme_banner = context.create_readme_banner;
    local create_message_fonts = context.create_message_fonts;
    local load_locations = context.load_locations;
    local load_spells = context.load_spells;
    local refresh_known_spells = context.refresh_known_spells;
    local select_current_level_range = context.select_current_level_range;
    local toggle_message_tests = context.toggle_message_tests;
    local print_command_help = context.print_command_help;
    local remove_mob_spell_tracker = context.remove_mob_spell_tracker;
    local find_blue_spell_in_text = context.find_blue_spell_in_text;
    local ensure_mob_spell_tracker = context.ensure_mob_spell_tracker;
    local increment_mob_spell = context.increment_mob_spell;
    local get_party_server_ids = context.get_party_server_ids;
    local track_party_enmity_action = context.track_party_enmity_action;
    local record_mob_blue_spell = context.record_mob_blue_spell;
    local track_party_battle_targets = context.track_party_battle_targets;
    local update_mob_spell_tracker = context.update_mob_spell_tracker;
    local draw_readme_window = context.draw_readme_window;
    local draw_window = context.draw_window;
    local update_message_fonts = context.update_message_fonts;
    local messages = context.messages;
    local save_settings = context.save_settings;
    local gui_shell = context.gui_shell;
    local check_for_updates = context.check_for_updates;

ashita.events.register('load', 'load_cb', function ()
    load_settings();
    state.is_open[1] = state.show_on_load[1];
    load_readme_contents();
    create_readme_banner();
    create_message_fonts();
    load_locations();
    load_spells();
    refresh_known_spells();
    select_current_level_range();
    state.load_refresh_at = os.clock() + 1.0;
    state.known_refresh_at = os.clock() + 0.5;
    if (state.update_check_enabled[1]) then
        check_for_updates();
    end
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if (#args > 0 and args[1]:any('/sea', '/search')) then
        menu_detection.arm_player_search();
        return;
    end
    if (#args == 0 or not args[1]:any('/bluspellbook', '/bluspells', '/bsb')) then
        return;
    end

    e.blocked = true;
    if (#args == 1 or args[2]:any('toggle')) then
        state.is_open[1] = not state.is_open[1];
    elseif (args[2]:any('show', 'open')) then
        state.is_open[1] = true;
    elseif (args[2]:any('hide', 'close')) then
        state.is_open[1] = false;
    elseif (args[2]:any('refresh')) then
        load_spells();
    elseif (args[2]:any('test', 'testdisplay')) then
        toggle_message_tests();
    elseif (args[2]:any('help', '?')) then
        print_command_help();
    end
end);

-- Chat text is a backup when the game does not provide a reliable move number.
ashita.events.register('text_in', 'text_in_cb', function (e)
    if (e.injected) then return; end
    local message = e.message_modified;
    if (type(message) ~= 'string' or message == '') then
        message = e.message;
    end
    if (type(message) ~= 'string') then return; end
    local lower_message = message:lower();

    if (lower_message:find(' defeats ', 1, true) ~= nil or
            lower_message:find('falls to the ground', 1, true) ~= nil or
            lower_message:find(' is defeated', 1, true) ~= nil) then
        for tracker_index = #state.mob_spell_tracker_order, 1, -1 do
            local actor_id = state.mob_spell_tracker_order[tracker_index];
            local tracker = state.mob_spell_trackers[actor_id];
            if (tracker ~= nil and type(tracker.name) == 'string' and
                    lower_message:find(tracker.name:lower(), 1, true) ~= nil) then
                remove_mob_spell_tracker(actor_id);
            end
        end
    end

    local is_monster_move = lower_message:find(' uses ', 1, true) ~= nil or
        lower_message:find(' readies ', 1, true) ~= nil;
    if (not is_monster_move) then return; end

    local spell_name = find_blue_spell_in_text(lower_message);
    if (spell_name == nil) then return; end

    local tracker = nil;
    local pending_tracker = nil;
    if (state.pending_mob_move_actor_id ~= nil and
            os.clock() <= state.pending_mob_move_until) then
        pending_tracker = state.mob_spell_trackers[state.pending_mob_move_actor_id] or
            ensure_mob_spell_tracker(state.pending_mob_move_actor_id);
        if (pending_tracker ~= nil and type(pending_tracker.name) == 'string' and
                lower_message:find(pending_tracker.name:lower(), 1, true) ~= nil) then
            tracker = pending_tracker;
        end
    end

    if (tracker == nil) then
        for _, actor_id in ipairs(state.mob_spell_tracker_order) do
            local candidate = state.mob_spell_trackers[actor_id];
            if (candidate ~= nil and type(candidate.name) == 'string' and
                    lower_message:find(candidate.name:lower(), 1, true) ~= nil) then
                tracker = candidate;
                break;
            end
        end
    end
    if (tracker == nil) then
        tracker = pending_tracker;
    end
    increment_mob_spell(tracker, spell_name);
end);

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if (e.id == 0x000E) then
        local entity_index = struct.unpack('H', e.data_modified, 0x08 + 0x01);
        local flags = struct.unpack('B', e.data_modified, 0x0A + 0x01);
        if (flags % 4 >= 2) then
            local claim_id = struct.unpack('L', e.data_modified, 0x2C + 0x01);
            local party_ids = get_party_server_ids();
            if (party_ids[claim_id]) then
                local entity = AshitaCore:GetMemoryManager():GetEntity();
                local ok, server_id = pcall(function ()
                    return entity:GetServerId(entity_index);
                end);
                if (ok and server_id ~= nil and server_id ~= 0) then
                    ensure_mob_spell_tracker(server_id);
                end
            end
        end
        return;
    end

    -- The game uses 7 when a move starts and 11 when it finishes.
    if (e.id == 0x0028) then
        local category = ashita.bits.unpack_be(e.data_raw, 82, 4);
        local target_count = ashita.bits.unpack_be(e.data_raw, 72, 10);
        local actor_id = ashita.bits.unpack_be(e.data_raw, 40, 32);
        if (target_count > 0) then
            local first_target_id = ashita.bits.unpack_be(e.data_raw, 150, 32);
            track_party_enmity_action(actor_id, first_target_id);
        end
        if (category == 7 or category == 11) then
            local ability_id = ashita.bits.unpack_be(e.data_raw, 86, 16);
            state.pending_mob_move_actor_id = actor_id;
            state.pending_mob_move_until = os.clock() + 8.0;
            record_mob_blue_spell(actor_id, ability_id);
        end
        return;
    end

    if (e.id == 0x0029) then
        local message_id = struct.unpack('H', e.data_modified, 0x18 + 0x01) % 0x8000;
        local actor_id = struct.unpack('L', e.data_modified, 0x04 + 0x01);
        local target_id = struct.unpack('L', e.data_modified, 0x08 + 0x01);
        local is_death_message = message_id == 6 or message_id == 20 or
            message_id == 113 or message_id == 406 or message_id == 605 or
            message_id == 646;
        if (is_death_message) then
            if (state.mob_spell_trackers[target_id] ~= nil) then
                remove_mob_spell_tracker(target_id);
            end
            if (state.mob_spell_trackers[actor_id] ~= nil) then
                remove_mob_spell_tracker(actor_id);
            end
        end
        if (message_id == 419) then
            local spell_id = struct.unpack('L', e.data_modified, 0x0C + 0x01);

            for _, spell in ipairs(state.spells) do
                if (spell.id == spell_id) then
                    spell.known = true;
                    state.learned_refresh_at = os.clock() + 1.0;
                    state.learned_refresh_spell_id = spell_id;
                    state.learn_message = ('Blue Magic learned: %s!'):fmt(spell.name);
                    state.learn_message_until = os.time() + 5;
                    break;
                end
            end
        end
        return;
    end

    if (e.id == 0x00AA) then
        load_spells();
    end
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    if (state.load_refresh_at ~= nil and os.clock() >= state.load_refresh_at) then
        state.load_refresh_at = nil;
        load_spells();
        select_current_level_range();
    end

    if (state.known_refresh_at ~= nil and os.clock() >= state.known_refresh_at) then
        refresh_known_spells();
        -- Known spells may not be ready immediately after an addon reload.
        state.known_refresh_at = os.clock() + 2.0;
    end

    if (state.learned_refresh_at ~= nil and os.clock() >= state.learned_refresh_at) then
        local learned_spell_id = state.learned_refresh_spell_id;
        state.learned_refresh_at = nil;
        state.learned_refresh_spell_id = nil;
        load_spells();
        for _, spell in ipairs(state.spells) do
            if (spell.id == learned_spell_id) then
                spell.known = true;
                break;
            end
        end
    end
    track_party_battle_targets();
    update_mob_spell_tracker();
    draw_readme_window();
    draw_window();
    update_message_fonts();
end);

ashita.events.register('unload', 'unload_cb', function ()
    messages.save_positions();
    save_settings();
    messages.destroy();
    gui_shell.destroy();
end);
end

return register_events;
