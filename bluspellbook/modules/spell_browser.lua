local function create_browser(context)
    local state = context.state;
    local required_spells = context.required_spells;
    local recommended_spells = context.recommended_spells;
    local get_blue_mage_level = context.get_blue_mage_level;
    local get_minimum_blue_magic_skill = context.get_minimum_blue_magic_skill;

    local function matches(spell, range, search_text)
        local visible = range[3] == 'ALL' or state.view_mode[1] == 2 or
            required_spells[spell.name] or
            (state.view_mode[1] == 1 and recommended_spells[spell.name]);
        local search = (search_text or ''):lower();
        return visible and
            (search == '' or spell.name:lower():find(search, 1, true) ~= nil) and
            spell.level >= range[1] and spell.level <= range[2];
    end

    local function get_selected_spell()
        if (state.selected_spell_id == nil) then return nil; end
        for _, spell in ipairs(state.spells) do
            if (spell.id == state.selected_spell_id) then return spell; end
        end
        return nil;
    end

    local function count_range(range, search_text)
        local count = 0;
        for _, spell in ipairs(state.spells) do
            if (matches(spell, range, search_text)) then count = count + 1; end
        end
        return count;
    end

    local function find_first(search_text)
        local search = (search_text or ''):lower();
        if (search == '') then return nil; end
        for _, spell in ipairs(state.spells) do
            if (spell.name:lower():find(search, 1, true) ~= nil) then
                return spell.id;
            end
        end
        return nil;
    end

    local function is_range_complete(range)
        local spell_count = 0;
        for _, spell in ipairs(state.spells) do
            if (spell.level >= range[1] and spell.level <= range[2]) then
                spell_count = spell_count + 1;
                if (not spell.known) then return false; end
            end
        end
        return spell_count > 0;
    end

    local function range_has_learnable_spell(range, blue_magic_skill)
        if (get_blue_mage_level() == nil) then return false; end
        for _, spell in ipairs(state.spells) do
            if (not spell.known and spell.level >= range[1] and
                    spell.level <= range[2] and blue_magic_skill >=
                    get_minimum_blue_magic_skill(spell.level)) then
                return true;
            end
        end
        return false;
    end

    local function group_locations(locations)
        local zones = {};
        for _, entry in ipairs(locations) do
            if (zones[entry.zone] == nil) then
                zones[entry.zone] = { min_level = entry.level_min, monsters = {} };
            end
            zones[entry.zone].min_level = math.min(
                zones[entry.zone].min_level, entry.level_min
            );
            zones[entry.zone].monsters[#zones[entry.zone].monsters + 1] = entry;
        end
        local zone_names = {};
        for zone_name in pairs(zones) do
            zone_names[#zone_names + 1] = zone_name;
        end
        table.sort(zone_names, function (left, right)
            return zones[left].min_level < zones[right].min_level or
                (zones[left].min_level == zones[right].min_level and left < right);
        end);
        return zones, zone_names;
    end

    return {
        matches = matches,
        get_selected_spell = get_selected_spell,
        count_range = count_range,
        find_first = find_first,
        is_range_complete = is_range_complete,
        range_has_learnable_spell = range_has_learnable_spell,
        group_locations = group_locations,
    };
end

return { new = create_browser };
