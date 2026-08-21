local function create_views(context)
    local spell_names = dofile(addon.path .. '/modules/spell_names.lua');
    local theme = dofile(addon.path .. '/modules/theme.lua');
    local state = context.state;
    local imgui = context.imgui;
    local ranges = context.ranges;
    local required_spells = context.required_spells;
    local recommended_spells = context.recommended_spells;
    local element_names = context.element_names;
    local job_traits = context.job_traits;
    local get_equipped_spell_names = context.get_equipped_spell_names;
    local get_blue_mage_level = context.get_blue_mage_level;
    local get_blue_magic_skill = context.get_blue_magic_skill;
    local get_minimum_blue_magic_skill = context.get_minimum_blue_magic_skill;
    local browser = dofile(addon.path .. '/modules/spell_browser.lua').new({
        state = state,
        required_spells = required_spells,
        recommended_spells = recommended_spells,
        get_blue_mage_level = get_blue_mage_level,
        get_minimum_blue_magic_skill = get_minimum_blue_magic_skill,
    });
    local cached_spell_revision = -1;
    local cached_known_spells = {};
    local cached_spell_levels = {};

local function get_spell_maps()
    if (cached_spell_revision == state.spells_revision) then
        return cached_known_spells, cached_spell_levels;
    end
    local known_spells = {};
    local spell_levels = {};
    for _, spell in ipairs(state.spells) do
        local key = spell_names.key(spell.name);
        known_spells[key] = spell.known;
        spell_levels[key] = tonumber(spell.level);
    end
    cached_known_spells = known_spells;
    cached_spell_levels = spell_levels;
    cached_spell_revision = state.spells_revision;
    return cached_known_spells, cached_spell_levels;
end

local function draw_range_column()
    local scale = state.ui_scale[1];
    local blue_magic_skill = get_blue_magic_skill();
    imgui.TextColored(theme.status.blue, '1. Level Range');
    -- Ashita 4.3 needs numbers here instead of named settings.
    imgui.BeginChild('##range_list',
        { theme.layout.range.child_width * scale, -1 }, 1, 0);
    for index, range in ipairs(ranges) do
        local complete = browser.is_range_complete(range);
        local has_learnable = browser.range_has_learnable_spell(
            range, blue_magic_skill
        );
        local colors = complete and theme.range.green or
            (has_learnable and theme.range.yellow or theme.range.red);
        imgui.PushStyleColor(ImGuiCol_Button, colors.normal);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, colors.hover);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, colors.active);

        local range_label = range[3] or ('%d-%d'):fmt(range[1], range[2]);
        local label = ('%s##range%d'):fmt(range_label, index);
        if (imgui.Button(label, {
                theme.layout.range.button_width * scale,
                theme.layout.range.button_height * scale
            })) then
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
    local total = browser.count_range(range, search);

    imgui.TextColored(
        theme.text.heading,
        ('2. Learning Target  (%d)'):fmt(total)
    );
    imgui.Text('Search:');
    imgui.SameLine();
    imgui.SetNextItemWidth(theme.layout.search.input_width * scale);
    if (imgui.InputText('##spell_search', state.spell_search, 64)) then
        search = state.spell_search[1]:match('^%s*(.-)%s*$');
        if (search ~= '') then
            state.selected_range = #ranges;
            range = ranges[state.selected_range];
            state.selected_spell_id = browser.find_first(search);
        end
    end
    if (search ~= '') then
        imgui.SameLine();
        if (imgui.Button('Clear##spell_search',
                { theme.layout.search.clear_width * scale, 0 })) then
            state.spell_search[1] = '';
            search = '';
        end
    end
    imgui.BeginChild('##spell_list',
        { theme.layout.spell_list_width * scale, -1 }, 1, 0);

    for _, spell in ipairs(state.spells) do
        if (browser.matches(spell, range, search)) then
            local selected = state.selected_spell_id == spell.id;
            local status_color;
            if (spell.known) then
                status_color = theme.status.green;
            elseif (blue_mage_level ~= nil and
                    blue_magic_skill >= get_minimum_blue_magic_skill(spell.level)) then
                status_color = theme.status.yellow;
            else
                status_color = theme.status.red;
                if (selected) then
                    imgui.PushStyleColor(ImGuiCol_Header, theme.header.locked);
                    imgui.PushStyleColor(ImGuiCol_HeaderHovered, theme.header.locked_hover);
                    imgui.PushStyleColor(ImGuiCol_HeaderActive, theme.header.locked_active);
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
    imgui.TextColored(theme.text.label, label);
    imgui.SameLine();
    imgui.TextColored(theme.status.blue, tostring(value));
end

local function draw_location_column()
    imgui.TextColored(theme.text.heading, '3. Learn Locations');
    imgui.BeginChild('##learn_locations', { 0, -1 }, 1, 0);

    local spell = browser.get_selected_spell();
    if (spell == nil) then
        imgui.TextWrapped('Select the spell you are currently trying to learn. Its monster and zone options will appear here.');
        imgui.Spacing();
        imgui.Spacing();
        imgui.PushStyleColor(ImGuiCol_Text, theme.status.yellow);
        imgui.TextWrapped('Not all locations could be verified, and some may be missing. To report a location or an issue with the addon, contact Tavarian on the Game Discord.');
        imgui.PopStyleColor();
        imgui.EndChild();
        return;
    end

    local resource = AshitaCore:GetResourceManager():GetSpellById(spell.id);
    if (resource == nil) then
        imgui.TextColored(theme.text.error, 'Spell resource data is unavailable.');
        imgui.EndChild();
        return;
    end

    imgui.TextColored(theme.text.current, ('Currently Learning: %s'):fmt(spell.name));
    imgui.PushTextWrapPos(0);
    imgui.TextWrapped(resource.Description[1] or 'No spell description is available.');
    imgui.PopTextWrapPos();
    imgui.Separator();
    show_value('Level:', spell.level);
    show_value('Element:', element_names[spell.element] or tostring(spell.element));
    show_value('Minimum Blue Magic Skill:', get_minimum_blue_magic_skill(spell.level));
    if (imgui.Button('Open Game Wiki Page')) then
        local page_name = spell.name:gsub(' ', '_');
        ashita.misc.open_url(('https://horizonffxi.wiki/%s'):fmt(page_name));
    end
    imgui.Separator();

    local locations = state.locations[tostring(spell.id)];
    if (locations ~= nil and type(locations.status) == 'string') then
        imgui.TextColored(theme.text.warning, locations.status);
    elseif (locations == nil or #locations == 0) then
        imgui.TextWrapped('No known location - will update when available');
    else
        local zones, zone_names = browser.group_locations(locations);

        for _, zone_name in ipairs(zone_names) do
            imgui.TextColored(theme.text.warning, zone_name);
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

    local known_spells, spell_levels = get_spell_maps();
    local equipped_names, equipped_available = get_equipped_spell_names();
    local equipped_spells = {};
    for name, equipped in pairs(equipped_names) do
        if (equipped) then
            equipped_spells[spell_names.key(name)] = true;
        end
    end

    imgui.TextColored(theme.status.blue, 'Blue Mage Job Traits (Level 75)');
    if (equipped_available) then
        imgui.TextDisabled('Trait stacking uses points from your currently equipped Blue Magic spells.');
        imgui.TextDisabled('Active traits are green. Eligible traits are yellow. Unavailable traits are red.');
        imgui.TextDisabled('Equipped contributor spells are blue.');
    else
        imgui.TextColored(theme.status.yellow,
            'Equipped spell data is unavailable. Trait activity cannot be confirmed.');
    end
    imgui.SetNextItemWidth(theme.layout.trait.filter_width * scale);
    imgui.Combo(
        '##trait_level_filter',
        state.trait_level_filter,
        'Active\0Available\0All\0\0'
    );
    imgui.SameLine();
    imgui.TextDisabled('Show active, level-available, or all traits');
    local trait_names = { 'All Traits' };
    for _, trait in ipairs(job_traits) do
        trait_names[#trait_names + 1] = trait[1];
    end
    imgui.SetNextItemWidth(theme.layout.trait.name_filter_width * scale);
    imgui.Combo(
        '##trait_name_filter',
        state.trait_name_filter,
        table.concat(trait_names, '\0') .. '\0\0'
    );
    imgui.SameLine();
    imgui.TextDisabled('Choose one trait for its complete contributor list');
    imgui.Separator();
    imgui.BeginChild('##job_trait_list', { 0, -1 }, 1, 0);

    local selected_trait = state.trait_name_filter[1];
    local column_count = selected_trait == 0 and 2 or 3;
    imgui.Columns(column_count, '##trait_columns', true);
    imgui.SetColumnWidth(0, theme.layout.trait.name_column_width * scale);
    imgui.SetColumnWidth(1, selected_trait == 0 and
        theme.layout.trait.wide_tier_column_width * scale or
        theme.layout.trait.tier_column_width * scale);
    imgui.PushTextWrapPos(
        imgui.GetCursorPosX() + imgui.GetColumnWidth() -
            (theme.layout.trait.wrap_margin * scale)
    );
    imgui.TextColored(theme.text.heading, 'Trait and Current Tier');
    imgui.PopTextWrapPos();
    imgui.NextColumn();
    imgui.TextColored(theme.text.heading, 'Tier Requirements');
    if (selected_trait ~= 0) then
        imgui.NextColumn();
        imgui.TextColored(theme.text.heading, 'Spell Contributors');
    end
    imgui.NextColumn();
    imgui.Separator();

    for trait_index, trait in ipairs(job_traits) do
        local filter_index = state.trait_level_filter[1];
        local known_points = job_traits.count_points(
            trait, known_spells, spell_levels, player_level
        );
        local equipped_points = equipped_available and
            job_traits.count_points(
                trait, equipped_spells, spell_levels, player_level
            ) or 0;
        local active_tier = job_traits.get_tier(trait, equipped_points);
        local visible = selected_trait == 0 or selected_trait == trait_index;
        if (filter_index == 0) then
            visible = visible and active_tier > 0;
        elseif (filter_index == 1) then
            visible = visible and trait[2] <= player_level;
        end
        if (visible) then
            local can_acquire = player_level >= trait[2] and
                known_points >= trait[4][1];
            local trait_label = trait[1];
            imgui.PushTextWrapPos(
                imgui.GetCursorPosX() + imgui.GetColumnWidth() -
                    (theme.layout.trait.wrap_margin * scale)
            );
            if (active_tier > 0) then
                if (#trait[4] > 1) then
                    trait_label = ('%s %s (%d pts)'):fmt(
                        trait[1], job_traits.tier_text(active_tier), equipped_points
                    );
                else
                    trait_label = ('%s (%d pts)'):fmt(trait[1], equipped_points);
                end
                imgui.TextColored(theme.status.green, trait_label);
            elseif (not can_acquire) then
                imgui.TextColored(theme.status.red, trait_label);
            else
                imgui.TextColored(theme.status.yellow, trait_label);
            end
            imgui.PopTextWrapPos();
            imgui.NextColumn();
            imgui.PushTextWrapPos(
                imgui.GetCursorPosX() + imgui.GetColumnWidth() -
                    (theme.layout.trait.wrap_margin * scale)
            );
            for tier_index, requirement in ipairs(trait[4]) do
                local available_level = job_traits.available_level(
                    trait, spell_levels, requirement
                );
                local requirement_text = available_level ~= nil and
                    ('%s: %d pts - Lv.%d'):fmt(
                        job_traits.tier_text(tier_index), requirement, available_level
                    ) or
                    ('%s: %d pts'):fmt(job_traits.tier_text(tier_index), requirement);
                if (active_tier >= tier_index) then
                    imgui.TextColored(theme.status.green, requirement_text);
                elseif (available_level ~= nil and
                        player_level >= available_level and
                        known_points >= requirement) then
                    imgui.TextColored(theme.status.yellow, requirement_text);
                else
                    imgui.TextColored(theme.status.red, requirement_text);
                end
            end
            imgui.PopTextWrapPos();
            if (selected_trait ~= 0) then
                imgui.NextColumn();
                imgui.PushTextWrapPos(0);
                local contributor_level = filter_index == 2 and 75 or player_level;
                for _, spell in ipairs(job_traits.get_contributors(
                        trait, spell_levels, contributor_level, required_spells,
                        recommended_spells, equipped_spells)) do
                    local text = spell.item;
                    if (equipped_spells[spell.key]) then
                        imgui.TextColored(theme.status.blue, text);
                    elseif (known_spells[spell.key]) then
                        imgui.TextColored(theme.status.green, text);
                    else
                        imgui.TextColored(theme.status.red, text);
                    end
                end
                imgui.PopTextWrapPos();
            end
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
