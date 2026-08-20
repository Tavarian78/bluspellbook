local function create_views(context)
    local state = context.state;
    local imgui = context.imgui;
    local ranges = context.ranges;
    local required_spells = context.required_spells;
    local recommended_spells = context.recommended_spells;
    local element_names = context.element_names;
    local job_traits = context.job_traits;
    local get_blue_mage_level = context.get_blue_mage_level;
    local get_blue_magic_skill = context.get_blue_magic_skill;
    local get_minimum_blue_magic_skill = context.get_minimum_blue_magic_skill;

local function get_selected_spell()
    if (state.selected_spell_id == nil) then
        return nil;
    end

    for _, spell in ipairs(state.spells) do
        if (spell.id == state.selected_spell_id) then
            return spell;
        end
    end

    return nil;
end

local function count_range(range, search_text)
    local count = 0;
    local search = (search_text or ''):lower();
    for _, spell in ipairs(state.spells) do
        local visible = range[3] == 'ALL' or state.view_mode[1] == 2 or
            required_spells[spell.name] or
            (state.view_mode[1] == 1 and recommended_spells[spell.name]);
        local matches_search = search == '' or
            spell.name:lower():find(search, 1, true) ~= nil;
        if (visible and matches_search and
                spell.level >= range[1] and spell.level <= range[2]) then
            count = count + 1;
        end
    end
    return count;
end

local function is_range_complete(range)
    local spell_count = 0;
    for _, spell in ipairs(state.spells) do
        if (spell.level >= range[1] and spell.level <= range[2]) then
            spell_count = spell_count + 1;
            if (not spell.known) then
                return false;
            end
        end
    end
    return spell_count > 0;
end

local function range_has_learnable_spell(range, blue_magic_skill)
    if (get_blue_mage_level() == nil) then
        return false;
    end
    for _, spell in ipairs(state.spells) do
        if (not spell.known and spell.level >= range[1] and spell.level <= range[2] and
                blue_magic_skill >= get_minimum_blue_magic_skill(spell.level)) then
            return true;
        end
    end
    return false;
end

local function draw_range_column()
    local scale = state.ui_scale[1];
    local blue_magic_skill = get_blue_magic_skill();
    imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, '1. Level Range');
    -- Ashita 4.3 needs numbers here instead of named settings.
    imgui.BeginChild('##range_list', { 125 * scale, -1 }, 1, 0);
    for index, range in ipairs(ranges) do
        local complete = is_range_complete(range);
        local has_learnable = range_has_learnable_spell(range, blue_magic_skill);
        if (complete) then
            imgui.PushStyleColor(ImGuiCol_Button, { 0.12, 0.55, 0.22, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.18, 0.68, 0.30, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.22, 0.78, 0.36, 1.0 });
        elseif (has_learnable) then
            imgui.PushStyleColor(ImGuiCol_Button, { 0.68, 0.50, 0.06, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.86, 0.66, 0.10, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 1.0, 0.78, 0.16, 1.0 });
        else
            imgui.PushStyleColor(ImGuiCol_Button, { 0.55, 0.10, 0.14, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.72, 0.16, 0.21, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.86, 0.22, 0.28, 1.0 });
        end

        local range_label = range[3] or ('%d-%d'):fmt(range[1], range[2]);
        local label = ('%s##range%d'):fmt(range_label, index);
        if (imgui.Button(label, { 105 * scale, 34 * scale })) then
            state.selected_range = index;
            state.selected_spell_id = nil;
        end

        imgui.PopStyleColor(3);

    end
    imgui.EndChild();
end

local function draw_spell_list()
    local scale = state.ui_scale[1];
    local blue_magic_skill = get_blue_magic_skill();
    local blue_mage_level = get_blue_mage_level();
    local range = ranges[state.selected_range];
    local search = state.spell_search[1]:match('^%s*(.-)%s*$');
    local total = count_range(range, search);

    imgui.TextColored(
        { 1.0, 0.72, 0.30, 1.0 },
        ('2. Learning Target  (%d)'):fmt(total)
    );
    imgui.Text('Search:');
    imgui.SameLine();
    imgui.SetNextItemWidth(120 * scale);
    if (imgui.InputText('##spell_search', state.spell_search, 64)) then
        search = state.spell_search[1]:match('^%s*(.-)%s*$');
        if (search ~= '') then
            state.selected_range = #ranges;
            range = ranges[state.selected_range];
            local search_lower = search:lower();
            state.selected_spell_id = nil;
            for _, spell in ipairs(state.spells) do
                if (spell.name:lower():find(search_lower, 1, true) ~= nil) then
                    state.selected_spell_id = spell.id;
                    break;
                end
            end
        end
    end
    if (search ~= '') then
        imgui.SameLine();
        if (imgui.Button('Clear##spell_search', { 48 * scale, 0 })) then
            state.spell_search[1] = '';
            search = '';
        end
    end
    imgui.BeginChild('##spell_list', { 255 * scale, -1 }, 1, 0);

    for _, spell in ipairs(state.spells) do
        local visible = range[3] == 'ALL' or state.view_mode[1] == 2 or
            required_spells[spell.name] or
            (state.view_mode[1] == 1 and recommended_spells[spell.name]);
        local matches_search = search == '' or
            spell.name:lower():find(search:lower(), 1, true) ~= nil;
        if (visible and matches_search and
                spell.level >= range[1] and spell.level <= range[2]) then
            local selected = state.selected_spell_id == spell.id;
            local status_color;
            if (spell.known) then
                status_color = { 0.35, 1.0, 0.45, 1.0 };
            elseif (blue_mage_level ~= nil and
                    blue_magic_skill >= get_minimum_blue_magic_skill(spell.level)) then
                status_color = { 1.0, 0.82, 0.16, 1.0 };
            else
                status_color = { 1.0, 0.28, 0.28, 1.0 };
                if (selected) then
                    imgui.PushStyleColor(ImGuiCol_Header, { 0.42, 0.07, 0.11, 1.0 });
                    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.62, 0.10, 0.16, 1.0 });
                    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.78, 0.14, 0.20, 1.0 });
                end
            end
            imgui.PushStyleColor(ImGuiCol_Text, status_color);

            local marker = selected and '> ' or '  ';
            local known_mark = spell.known and '✓' or 'X';
            local label = ('%s[%s] Lv.%02d  %s##spell%d'):fmt(marker, known_mark, spell.level, spell.name, spell.id);
            if (imgui.Selectable(label, selected)) then
                state.selected_spell_id = spell.id;
            end
            imgui.PopStyleColor();
            if (selected and not spell.known and
                    (blue_mage_level == nil or
                    blue_magic_skill < get_minimum_blue_magic_skill(spell.level))) then
                imgui.PopStyleColor(3);
            end
        end
    end

    imgui.EndChild();
end

local function show_value(label, value)
    imgui.TextColored({ 0.78, 0.82, 0.90, 1.0 }, label);
    imgui.SameLine();
    imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, tostring(value));
end

local function draw_location_column()
    imgui.TextColored({ 1.0, 0.72, 0.30, 1.0 }, '3. Learn Locations');
    imgui.BeginChild('##learn_locations', { 0, -1 }, 1, 0);

    local spell = get_selected_spell();
    if (spell == nil) then
        imgui.TextWrapped('Select the spell you are currently trying to learn. Its monster and zone options will appear here.');
        imgui.Spacing();
        imgui.Spacing();
        imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 0.82, 0.16, 1.0 });
        imgui.TextWrapped('Not all locations could be verified, and some may be missing. To report a location or an issue with the addon, contact Tavarian on the HorizonXI Discord.');
        imgui.PopStyleColor();
        imgui.EndChild();
        return;
    end

    local resource = AshitaCore:GetResourceManager():GetSpellById(spell.id);
    if (resource == nil) then
        imgui.TextColored({ 1.0, 0.25, 0.25, 1.0 }, 'Spell resource data is unavailable.');
        imgui.EndChild();
        return;
    end

    imgui.TextColored({ 0.45, 0.82, 1.0, 1.0 }, ('Currently Learning: %s'):fmt(spell.name));
    imgui.PushTextWrapPos(0);
    imgui.TextWrapped(resource.Description[1] or 'No spell description is available.');
    imgui.PopTextWrapPos();
    imgui.Separator();
    show_value('Level:', spell.level);
    show_value('Element:', element_names[spell.element] or tostring(spell.element));
    show_value('Minimum Blue Magic Skill:', get_minimum_blue_magic_skill(spell.level));
    if (imgui.Button('Open HorizonXI Wiki Page')) then
        local page_name = spell.name:gsub(' ', '_');
        ashita.misc.open_url(('https://horizonffxi.wiki/%s'):fmt(page_name));
    end
    imgui.Separator();

    local locations = state.locations[tostring(spell.id)];
    if (locations ~= nil and type(locations.status) == 'string') then
        imgui.TextColored({ 1.0, 0.78, 0.28, 1.0 }, locations.status);
    elseif (locations == nil or #locations == 0) then
        imgui.TextWrapped('No known location - will update when available');
    else
        local zones = {};
        for _, entry in ipairs(locations) do
            if (zones[entry.zone] == nil) then
                zones[entry.zone] = { min_level = entry.level_min, monsters = {} };
            end
            zones[entry.zone].min_level = math.min(zones[entry.zone].min_level, entry.level_min);
            zones[entry.zone].monsters[#zones[entry.zone].monsters + 1] = entry;
        end

        local zone_names = {};
        for zone_name in pairs(zones) do
            zone_names[#zone_names + 1] = zone_name;
        end
        table.sort(zone_names, function (a, b)
            return zones[a].min_level < zones[b].min_level or
                (zones[a].min_level == zones[b].min_level and a < b);
        end);

        for _, zone_name in ipairs(zone_names) do
            imgui.TextColored({ 1.0, 0.78, 0.28, 1.0 }, zone_name);
            for _, entry in ipairs(zones[zone_name].monsters) do
                local level_text = entry.level_unknown and 'Unknown' or
                    (entry.level_min == entry.level_max and
                    tostring(entry.level_min) or
                    ('%d-%d'):fmt(entry.level_min, entry.level_max));
                local location_note = type(entry.note) == 'string' and
                    entry.note ~= '' and ('  %s'):fmt(entry.note) or '';
                imgui.BulletText(('%s  (Lv.%s)%s'):fmt(
                    entry.monster, level_text, location_note
                ));
            end
            imgui.Spacing();
        end
    end

    imgui.EndChild();
end

local function draw_job_traits()
    local scale = state.ui_scale[1];
    local player_level = get_blue_mage_level() or 0;

    local known_spells = {};
    local spell_levels = {};
    for _, spell in ipairs(state.spells) do
        known_spells[spell.name] = spell.known;
        spell_levels[spell.name] = tonumber(spell.level);
    end

    local function get_priority_spells(trait, maximum_level)
        local groups = { {}, {}, {} };
        local spell_limit = trait[1] == 'Auto Refresh' and 3 or 2;
        for value in trait[3]:gmatch('[^,]+') do
            local item = value:match('^%s*(.-)%s*$');
            local name = item:gsub('%s*%(%d+%)%s*$', '');
            local spell_level = spell_levels[name];
            if (spell_level ~= nil and spell_level <= maximum_level) then
                local group = required_spells[name] and 1 or (recommended_spells[name] and 2 or 3);
                groups[group][#groups[group] + 1] = {
                    item = item,
                    name = name,
                    priority = group,
                };
            end
        end

        local selected = {};
        for priority = 1, 3 do
            for _, spell in ipairs(groups[priority]) do
                selected[#selected + 1] = spell;
                if (#selected == spell_limit) then
                    return selected;
                end
            end
        end
        return selected;
    end

    local function has_trait_spell_requirements(trait, maximum_level)
        local known_count = 0;
        local known_points = 0;
        local uses_points = false;
        for value in trait[3]:gmatch('[^,]+') do
            local item = value:match('^%s*(.-)%s*$');
            local points = tonumber(item:match('%((%d+)%)%s*$'));
            local name = item:gsub('%s*%(%d+%)%s*$', '');
            if (points ~= nil) then
                uses_points = true;
            else
                points = 1;
            end
            if (known_spells[name] and spell_levels[name] ~= nil and
                    spell_levels[name] <= maximum_level) then
                known_count = known_count + 1;
                known_points = known_points + points;
            end
        end

        return uses_points and known_points >= 8 or (not uses_points and known_count >= 2);
    end

    imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, 'Blue Mage Job Traits (Level 75)');
    imgui.TextDisabled('Active traits are blue. Learned spells are green. Unavailable traits are red.');
    imgui.SetNextItemWidth(170 * scale);
    imgui.Combo(
        '##trait_level_filter',
        state.trait_level_filter,
        'All\0Current Level\0\0'
    );
    imgui.SameLine();
    imgui.TextDisabled('Show all traits or only those currently available');
    imgui.Separator();
    imgui.BeginChild('##job_trait_list', { 0, -1 }, 1, 0);

    imgui.Columns(3, '##trait_columns', true);
    imgui.SetColumnWidth(0, 190 * scale);
    imgui.SetColumnWidth(1, 130 * scale);
    imgui.TextColored({ 1.0, 0.72, 0.30, 1.0 }, 'Trait');
    imgui.NextColumn();
    imgui.TextColored({ 1.0, 0.72, 0.30, 1.0 }, 'Available Level');
    imgui.NextColumn();
    imgui.TextColored({ 1.0, 0.72, 0.30, 1.0 }, 'Spell Contributors');
    imgui.NextColumn();
    imgui.Separator();

    for _, trait in ipairs(job_traits) do
        local filter_index = state.trait_level_filter[1];
        local visible = filter_index == 0 or trait[2] <= player_level;
        if (visible) then
            local can_acquire = player_level >= trait[2] and
                has_trait_spell_requirements(trait, player_level);
            if (not can_acquire) then
                imgui.TextColored({ 1.0, 0.28, 0.28, 1.0 }, trait[1]);
            else
                imgui.TextColored({ 0.35, 0.75, 1.0, 1.0 }, trait[1]);
            end
            imgui.NextColumn();
            if (not can_acquire) then
                imgui.TextColored({ 1.0, 0.28, 0.28, 1.0 }, ('Lv.%d'):fmt(trait[2]));
            else
                imgui.Text(('Lv.%d'):fmt(trait[2]));
            end
            imgui.NextColumn();
            imgui.PushTextWrapPos(0);
            local contributor_level = filter_index == 0 and 75 or player_level;
            for _, spell in ipairs(get_priority_spells(trait, contributor_level)) do
                local text = spell.item;
                if (known_spells[spell.name]) then
                    imgui.TextColored({ 0.35, 1.0, 0.45, 1.0 }, text);
                else
                    imgui.Text(text);
                end
            end
            imgui.PopTextWrapPos();
            imgui.NextColumn();
            imgui.Separator();
        end
    end

    imgui.Columns(1);
    imgui.EndChild();
end

    return {
        draw_ranges = draw_range_column,
        draw_spells = draw_spell_list,
        draw_locations = draw_location_column,
        draw_traits = draw_job_traits,
    };
end

return create_views;

