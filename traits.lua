local spell_names = dofile(addon.path .. '/modules/spell_names.lua');

local traits = {
    { 'Beast Killer', 4, 'Wild Oats, Sprout Smack, 1000 Needles', { 2, 4, 6 } },
    { 'Auto Regen', 16, 'Sheep Song, Healing Breeze', { 2 } },
    { 'Lizard Killer', 20, 'Foot Kick, Claw Cyclone, Ram Charge', { 2, 4 } },
    { 'Conserve MP', 20, 'Metallic Body, Blood Drain, Chaotic Eye, Digest, Zephyr Mantle, Firespit, Frost Breath (2)', { 2, 4, 6 } },
    { 'Clear Mind', 24, 'Poison Breath, Soporific, Venom Shell, Awful Eye, Filamented Hold, Maelstrom, Feather Tickle, Sandspray, Warm-Up, Lowing, Mind Blast', { 2, 4, 6 } },
    { 'Magic Accuracy', 28, 'Bomb Toss, Blitzstrahl, Infrasonics, Cursed Sphere', { 2, 4, 6 } },
    { 'Resist Sleep', 30, 'Pollen, Wild Carrot, Magic Fruit, Yawn, Exuviation', { 2, 4 } },
    { 'Magic Attack Bonus', 32, 'Blastbomb, Sound Blast, Blank Gaze, Eyes On Me, Memento Mori, Heat Breath', { 2, 4, 6 } },
    { 'Undead Killer', 34, 'Bludgeon, Smite of Rage', { 2 } },
    { 'Attack Bonus', 38, 'Battle Dance, Uppercut, Death Scissors, Spinal Cleave, Temporal Shift', { 2, 4, 6 } },
    { 'Rapid Shot', 38, 'Feather Storm, Jet Stream, Hydro Shot', { 2 } },
    { 'Evasion Bonus', 38, 'Screwdriver, Occultation, Hysteric Barrage', { 2, 4, 6 } },
    { 'Defense Bonus', 40, 'Grand Slam, Terror Touch, Quad. Continuum, Saline Coat, Vertical Cleave', { 2, 4, 6 } },
    { 'Max HP Boost', 40, 'Empty Trash, Flying Hip Press, Body Slam, Frypan, Mysterious Light, Hecatomb Wave', { 2, 4, 6 } },
    { 'Plantoid Killer', 44, 'Power Attack, Mandibular Bite', { 2, 4 } },
    { 'Auto Refresh', 50, 'Stinking Gas (1), Geist Wall (1), Cold Wave (1), Blood Saber (2), Self-Destruct (2), Frightful Roar (2), Winds of Promyvion (2), Light of Penance (3), Voracious Trunk (3), Actinic Burst (4), Plasma Charge (4)', { 8 } },
    { 'Magic Defense Bonus', 50, 'Magnetite Cloud, Ice Break, Reactor Cool', { 2, 4, 6 } },
    { 'Accuracy Bonus', 60, 'Vanity Dive, Dimensional Death, Disseverment', { 2, 4, 6 } },
    { 'Fast Cast', 61, 'Auroral Drape, Bad Breath', { 2, 4, 6 } },
    { 'Resist Gravity', 69, 'Feather Barrier', { 2 } },
    { 'Store TP', 69, 'Sickle Slash, Tail Slap', { 2, 4, 6 } },
    { 'Counter', 70, 'Enervation', { 2 } },
};

local function parse_contributor(value)
    local item = value:match('^%s*(.-)%s*$');
    local name = item:gsub('%s*%(%d+%)%s*$', '');
    local key = spell_names.key(name);
    return {
        name = name,
        key = key,
        points = tonumber(item:match('%((%d+)%)%s*$')) or 1,
    };
end

for _, trait in ipairs(traits) do
    trait.contributors = {};
    local maximum_points = 0;
    for value in trait[3]:gmatch('[^,]+') do
        local contributor = parse_contributor(value);
        trait.contributors[#trait.contributors + 1] = contributor;
        maximum_points = maximum_points + contributor.points;
    end
    while (#trait[4] > 0 and trait[4][#trait[4]] > maximum_points) do
        table.remove(trait[4]);
    end
end

function traits.get_contributors(trait, spell_levels, maximum_level,
        required_spells, recommended_spells, equipped_spells)
    local contributors = {};
    for _, cached in ipairs(trait.contributors) do
        local level = spell_levels[cached.key];
        if (level ~= nil and level <= maximum_level) then
            contributors[#contributors + 1] = {
                item = ('%s - %d %s'):fmt(
                    cached.name, cached.points,
                    cached.points == 1 and 'pt' or 'pts'
                ),
                name = cached.name,
                key = cached.key,
                points = cached.points,
                level = level,
                priority = required_spells[cached.name] and 1 or
                    (recommended_spells[cached.name] and 2 or 3),
            };
        end
    end
    table.sort(contributors, function (left, right)
        local left_equipped = equipped_spells[left.key] and 0 or 1;
        local right_equipped = equipped_spells[right.key] and 0 or 1;
        if (left_equipped ~= right_equipped) then
            return left_equipped < right_equipped;
        end
        if (left.priority ~= right.priority) then
            return left.priority < right.priority;
        end
        if (left.level ~= right.level) then
            return left.level < right.level;
        end
        return left.name < right.name;
    end);
    return contributors;
end

function traits.count_points(trait, spells, spell_levels, maximum_level)
    local total = 0;
    for _, contributor in ipairs(trait.contributors) do
        local level = spell_levels[contributor.key];
        if (spells[contributor.key] and level ~= nil and
                level <= maximum_level) then
            total = total + contributor.points;
        end
    end
    return total;
end

function traits.get_tier(trait, points)
    local tier = 0;
    for index, requirement in ipairs(trait[4]) do
        if (points >= requirement) then
            tier = index;
        end
    end
    return tier;
end

function traits.tier_text(tier)
    return ({ 'I', 'II', 'III', 'IV' })[tier] or tostring(tier);
end

function traits.available_level(trait, spell_levels, requirement)
    if (trait.level_cache_source == spell_levels and
            trait.level_cache[requirement] ~= nil) then
        local cached = trait.level_cache[requirement];
        return cached ~= false and cached or nil;
    end
    if (trait.level_cache_source ~= spell_levels) then
        trait.level_cache_source = spell_levels;
        trait.level_cache = {};
    end
    local contributors = {};
    for _, cached in ipairs(trait.contributors) do
        local level = spell_levels[cached.key];
        if (level ~= nil) then
            contributors[#contributors + 1] = {
                level = level,
                points = cached.points,
            };
        end
    end
    table.sort(contributors, function (left, right)
        return left.level < right.level;
    end);
    local points = 0;
    for _, contributor in ipairs(contributors) do
        points = points + contributor.points;
        if (points >= requirement) then
            local level = math.max(trait[2], contributor.level);
            trait.level_cache[requirement] = level;
            return level;
        end
    end
    trait.level_cache[requirement] = false;
    return nil;
end

return traits;
