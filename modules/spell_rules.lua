local rules = {};

rules.ranges = {
    { 1, 10 }, { 11, 20 }, { 21, 30 }, { 31, 40 },
    { 41, 50 }, { 51, 60 }, { 61, 70 }, { 71, 75 },
    { 1, 75, 'ALL' },
};

rules.element_names = {
    [0] = 'Fire', [1] = 'Ice', [2] = 'Wind', [3] = 'Earth',
    [4] = 'Lightning', [5] = 'Water', [6] = 'Light', [7] = 'Dark',
    [15] = 'None',
};

rules.level_overrides = {
    ['Auroral Drape'] = 42,
    ['Vanity Dive'] = 28,
};

rules.excluded_spells = {
    ['Asuran Claws'] = true, ['Battery Charge'] = true,
    ['Corrosive Ooze'] = true, ['Everyone. Grudge'] = true,
    ["Everyone's Grudge"] = true, ['Goblin Rush'] = true,
    ['Rail Cannon'] = true, ['Regurgitation'] = true,
    ['Seedspray'] = true, ['Spiral Spin'] = true,
    ['Stinking Gas'] = true, ['Sub-zero Smash'] = true,
    ['Triumphant Roar'] = true,
};

function rules.get_minimum_blue_magic_skill(level)
    local cap;
    if (level <= 50) then
        cap = ((level - 1) * 3) + 6;
    elseif (level <= 60) then
        cap = ((level - 50) * 5) + 153;
    elseif (level <= 70) then
        cap = math.floor(((level - 60) * 4.85) + 203);
    else
        cap = ((level - 70) * 5) + 251;
    end
    return math.max(0, cap - 31);
end

return rules;
