local function create_tracker(state)
local function find_entity_index(server_id)
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    if (entity == nil) then
        return nil;
    end

    for index = 0, 2303 do
        local ok, id = pcall(function ()
            return entity:GetServerId(index);
        end);
        if (ok and id == server_id) then
            return index;
        end
    end
    return nil;
end


local function get_english_resource_name(name_value)
    if (type(name_value) == 'string') then
        return name_value;
    end
    if (name_value == nil) then return nil; end
    local ok, value = pcall(function ()
        return name_value[1] or name_value[0];
    end);
    if (ok and type(value) == 'string') then
        return value;
    end
    return nil;
end

local spell_aliases = {
    ['Winds of Promy.'] = { 'Winds of Promyvion', },
    ['Quad. Continuum'] = { 'Quadratic Continuum', },
};


local function find_blue_spell_name(ability_name)
    ability_name = get_english_resource_name(ability_name);
    if (ability_name == nil or ability_name == '') then
        return nil;
    end

    for _, spell in ipairs(state.spells) do
        if (spell.name == ability_name) then return spell.name; end
        for _, alias in ipairs(spell_aliases[spell.name] or {}) do
            if (alias == ability_name) then return spell.name; end
        end
    end

    local wanted = ability_name:lower();
    for spell_id, _ in pairs(state.locations) do
        local resource = AshitaCore:GetResourceManager():GetSpellById(tonumber(spell_id));
        if (resource ~= nil and resource.Name ~= nil) then
            local resource_name = get_english_resource_name(resource.Name);
            if (type(resource_name) == 'string' and resource_name:lower() == wanted) then
                return resource_name;
            end
        end
    end
    return nil;
end

local function find_blue_spell_in_text(message)
    if (type(message) ~= 'string') then return nil; end
    local lower_message = message:lower();
    local best_name = nil;
    local best_length = 0;

    local function consider(name, alias)
        local candidate = alias or name;
        if (#candidate > best_length and
                lower_message:find(candidate:lower(), 1, true) ~= nil) then
            best_name = name;
            best_length = #candidate;
        end
    end

    for _, spell in ipairs(state.spells) do
        consider(spell.name);
        for _, alias in ipairs(spell_aliases[spell.name] or {}) do
            consider(spell.name, alias);
        end
    end

    for spell_id in pairs(state.locations) do
        local resource = AshitaCore:GetResourceManager():GetSpellById(tonumber(spell_id));
        if (resource ~= nil and resource.Name ~= nil) then
            local resource_name = get_english_resource_name(resource.Name);
            if (type(resource_name) == 'string') then consider(resource_name); end
        end
    end
    return best_name;
end


local function find_blue_spell_id(spell_name)
    for _, spell in ipairs(state.spells) do
        if (spell.name == spell_name) then
            return spell.id;
        end
    end
    local wanted = type(spell_name) == 'string' and spell_name:lower() or '';
    for spell_id, _ in pairs(state.locations) do
        local numeric_id = tonumber(spell_id);
        local resource = AshitaCore:GetResourceManager():GetSpellById(numeric_id);
        if (resource ~= nil and resource.Name ~= nil) then
            local resource_name = get_english_resource_name(resource.Name);
            if (type(resource_name) == 'string' and resource_name:lower() == wanted) then
                return numeric_id;
            end
        end
    end
    return nil;
end


local function is_blue_spell_known(spell_name)
    for _, spell in ipairs(state.spells) do
        if (spell.name == spell_name) then
            return spell.known == true;
        end
    end
    local spell_id = find_blue_spell_id(spell_name);
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if (spell_id ~= nil and player ~= nil) then
        local ok, known = pcall(function () return player:HasSpell(spell_id); end);
        if (ok) then return known == true; end
    end
    return false;
end


local mob_teaches_blue_spell = nil;


local function increment_mob_spell(tracker, spell_name)
    if (tracker == nil or spell_name == nil) then
        return false;
    end
    if (not state.detect_known_spells[1] and is_blue_spell_known(spell_name)) then
        return false;
    end
    if (mob_teaches_blue_spell == nil or
            not mob_teaches_blue_spell(tracker.name, spell_name)) then
        return false;
    end

    -- One move can arrive through more than one game message.
    tracker.last_spell_at = tracker.last_spell_at or {};
    local now = os.clock();
    local last = tracker.last_spell_at[spell_name];
    if (last ~= nil and now - last < 5.0) then
        return false;
    end
    tracker.last_spell_at[spell_name] = now;

    if (tracker.counts[spell_name] == nil) then
        tracker.counts[spell_name] = 0;
        tracker.spell_order[#tracker.spell_order + 1] = spell_name;
    end
    tracker.counts[spell_name] = tracker.counts[spell_name] + 1;
    return true;
end


local function remove_mob_spell_tracker(actor_id)
    state.mob_spell_trackers[actor_id] = nil;
    for index = #state.mob_spell_tracker_order, 1, -1 do
        if (state.mob_spell_tracker_order[index] == actor_id) then
            table.remove(state.mob_spell_tracker_order, index);
            break;
        end
    end
end


local function normalize_mob_name(name)
    if (type(name) ~= 'string') then return ''; end
    return name:lower():gsub('^the%s+', ''):gsub('^%s+', ''):gsub('%s+$', '');
end


mob_teaches_blue_spell = function (mob_name, spell_name)
    local wanted_mob = normalize_mob_name(mob_name);
    if (wanted_mob == '') then return false; end

    local spell_id = find_blue_spell_id(spell_name);
    if (spell_id == nil) then return false; end

    local entries = state.locations[tostring(spell_id)];
    if (type(entries) ~= 'table') then return false; end
    for _, entry in ipairs(entries) do
        if (normalize_mob_name(entry.monster) == wanted_mob) then
            return true;
        end
    end
    return false;
end


local function mob_has_learnable_blue_magic(name)
    local wanted = normalize_mob_name(name);
    if (wanted == '') then return false; end
    for spell_id, entries in pairs(state.locations) do
        if (type(entries) == 'table') then
            for _, entry in ipairs(entries) do
                if (normalize_mob_name(entry.monster) == wanted) then
                    if (state.detect_known_spells[1]) then
                        return true;
                    end
                    local numeric_id = tonumber(spell_id);
                    local found_display_spell = false;
                    for _, spell in ipairs(state.spells) do
                        if (spell.id == numeric_id and not spell.known) then
                            return true;
                        end
                        if (spell.id == numeric_id) then
                            found_display_spell = true;
                        end
                    end
                    if (not found_display_spell) then
                        local player = AshitaCore:GetMemoryManager():GetPlayer();
                        local known = false;
                        if (player ~= nil) then
                            local ok, value = pcall(function ()
                                return player:HasSpell(numeric_id);
                            end);
                            known = ok and value == true;
                        end
                        if (not known) then return true; end
                    end
                end
            end
        end
    end
    return false;
end


local function get_mob_learnable_spell_names(name)
    local wanted = normalize_mob_name(name);
    local names = {};
    local seen = {};
    if (wanted == '') then return names; end

    for spell_id, entries in pairs(state.locations) do
        if (type(entries) == 'table') then
            local teaches = false;
            for _, entry in ipairs(entries) do
                if (normalize_mob_name(entry.monster) == wanted) then
                    teaches = true;
                    break;
                end
            end
            if (teaches) then
                local numeric_id = tonumber(spell_id);
                local resource = AshitaCore:GetResourceManager():GetSpellById(numeric_id);
                local spell_name = resource ~= nil and
                    get_english_resource_name(resource.Name) or nil;
                if (type(spell_name) == 'string' and spell_name ~= '' and
                        not seen[spell_name] and
                        (state.detect_known_spells[1] or
                         not is_blue_spell_known(spell_name))) then
                    seen[spell_name] = true;
                    names[#names + 1] = spell_name;
                end
            end
        end
    end
    table.sort(names);
    return names;
end


local function ensure_mob_spell_tracker(actor_id)
    if (actor_id == nil or actor_id == 0) then
        return nil;
    end
    if (state.mob_spell_trackers[actor_id] ~= nil) then
        return state.mob_spell_trackers[actor_id];
    end

    local entity = AshitaCore:GetMemoryManager():GetEntity();
    local entity_index = find_entity_index(actor_id);
    if (entity == nil or entity_index == nil) then
        return nil;
    end

    -- Party and alliance members are never enemies.
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party ~= nil) then
        for member = 0, 17 do
            local id_ok, member_id = pcall(function ()
                return party:GetMemberServerId(member);
            end);
            if (id_ok and member_id == actor_id) then
                return nil;
            end
        end
    end

    local ok, name = pcall(function ()
        return entity:GetName(entity_index);
    end);
    if (not ok) then
        return nil;
    end
    if (not mob_has_learnable_blue_magic(name)) then
        return nil;
    end

    local tracker = {
        actor_id = actor_id,
        actor_index = entity_index,
        name = type(name) == 'string' and name ~= '' and name or ('Mob %08X'):fmt(actor_id),
        counts = {},
        spell_order = {},
        last_spell_at = {},
    };
    state.mob_spell_trackers[actor_id] = tracker;
    state.mob_spell_tracker_order[#state.mob_spell_tracker_order + 1] = actor_id;
    return tracker;
end


local function get_party_server_ids()
    local ids = {};
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return ids;
    end
    for member = 0, 17 do
        local ok, server_id = pcall(function ()
            return party:GetMemberServerId(member);
        end);
        if (ok and server_id ~= nil and server_id ~= 0) then
            ids[server_id] = true;
        end
    end
    return ids;
end


local function track_party_enmity_action(actor_id, target_id)
    if (actor_id == target_id) then
        return;
    end
    local party_ids = get_party_server_ids();
    if (party_ids[actor_id]) then
        ensure_mob_spell_tracker(target_id);
    elseif (party_ids[target_id]) then
        ensure_mob_spell_tracker(actor_id);
    end
end


local function track_party_battle_targets()
    local memory = AshitaCore:GetMemoryManager();
    local party = memory:GetParty();
    local entity = memory:GetEntity();
    if (party == nil or entity == nil) then
        return;
    end

    local party_entity_indices = {};
    for member = 0, 17 do
        local ok, server_id, member_index, member_status, target_index = pcall(function ()
            local index = party:GetMemberTargetIndex(member);
            return party:GetMemberServerId(member), index,
                entity:GetStatus(index), entity:GetTargetIndex(index);
        end);
        if (ok and server_id ~= nil and server_id ~= 0 and
                type(member_index) == 'number' and member_index > 0) then
            party_entity_indices[member_index] = true;
            if (member_status == 1 and target_index ~= nil and target_index ~= 0) then
                local id_ok, target_id = pcall(function ()
                    return entity:GetServerId(target_index);
                end);
                if (id_ok and target_id ~= nil and target_id ~= 0) then
                    ensure_mob_spell_tracker(target_id);
                end
            end
        end
    end

    if (os.clock() < state.enmity_scan_at) then
        return;
    end
    state.enmity_scan_at = os.clock() + 0.25;
    for entity_index = 0, 2303 do
        if (not party_entity_indices[entity_index]) then
            local ok, status, target_index, server_id = pcall(function ()
                return entity:GetStatus(entity_index), entity:GetTargetIndex(entity_index),
                    entity:GetServerId(entity_index);
            end);
            if (ok and status == 1 and party_entity_indices[target_index] and
                    server_id ~= nil and server_id ~= 0) then
                ensure_mob_spell_tracker(server_id);
            end
        end
    end
end


local function record_mob_blue_spell(actor_id, ability_id)
    local spell_name = nil;
    -- The same enemy move can use either of two resource numbers.
    local candidates = { ability_id, ability_id + 256 };
    if (ability_id >= 256) then
        candidates[#candidates + 1] = ability_id - 256;
    end
    for _, resource_id in ipairs(candidates) do
        local ability = AshitaCore:GetResourceManager():GetAbilityById(resource_id);
        if (ability ~= nil and ability.Name ~= nil) then
            local ability_name = get_english_resource_name(ability.Name);
            spell_name = find_blue_spell_name(ability_name);
            if (spell_name ~= nil) then
                break;
            end
        end
    end
    if (spell_name == nil) then return false; end

    local tracker = state.mob_spell_trackers[actor_id] or ensure_mob_spell_tracker(actor_id);
    if (tracker == nil) then
        return false;
    end
    return increment_mob_spell(tracker, spell_name);
end


local function update_mob_spell_tracker()
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    for index = #state.mob_spell_tracker_order, 1, -1 do
        local actor_id = state.mob_spell_tracker_order[index];
        local tracker = state.mob_spell_trackers[actor_id];
        for spell_index = #tracker.spell_order, 1, -1 do
            local spell_name = tracker.spell_order[spell_index];
            if (not state.detect_known_spells[1] and
                    is_blue_spell_known(spell_name)) then
                table.remove(tracker.spell_order, spell_index);
                tracker.counts[spell_name] = nil;
                tracker.last_spell_at[spell_name] = nil;
            end
        end
        local ok, server_id, entity_status = pcall(function ()
            return entity:GetServerId(tracker.actor_index),
                entity:GetStatus(tracker.actor_index);
        end);
        -- Health can briefly read as zero while an enemy is still alive.
        if (not ok or server_id ~= actor_id or
                entity_status == 2 or entity_status == 3 or
                not mob_has_learnable_blue_magic(tracker.name)) then
            remove_mob_spell_tracker(actor_id);
        end
    end
end

    return {
        ensure = ensure_mob_spell_tracker,
        remove = remove_mob_spell_tracker,
        party_ids = get_party_server_ids,
        track_enmity_action = track_party_enmity_action,
        scan_party_targets = track_party_battle_targets,
        record_spell = record_mob_blue_spell,
        update = update_mob_spell_tracker,
        increment = increment_mob_spell,
        learnable_spell_names = get_mob_learnable_spell_names,
        is_spell_known = is_blue_spell_known,
        spell_in_text = find_blue_spell_in_text,
    };
end

return create_tracker;
