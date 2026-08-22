local reader = {};

local offset = nil;
pcall(function ()
    local ffi = require 'ffi';
    local address = ashita.memory.find(
        0, 0,
        'C1E1032BC8B0018D????????????B9????????F3A55F5E5B',
        10, 0
    );
    if (address ~= 0) then
        offset = ffi.cast('uint32_t*', address);
    end
end);

function reader.get_names()
    local names = {};
    local found_buffer = false;
    if (offset == nil) then
        return names, false;
    end

    local ok = pcall(function ()
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        local is_main = player:GetMainJob() == 16;
        local is_sub = player:GetSubJob() == 16;
        if (not is_main and not is_sub) then
            return;
        end

        local pointer = ashita.memory.read_uint32(
            AshitaCore:GetPointerManager():Get('inventory')
        );
        if (pointer == 0) then
            return;
        end
        pointer = ashita.memory.read_uint32(pointer);
        if (pointer == 0) then
            return;
        end

        local start = pointer + offset[0] + (is_main and 0x04 or 0xA0);
        local spells = ashita.memory.read_array(start, 0x14);
        found_buffer = true;
        local resources = AshitaCore:GetResourceManager();
        for _, value in pairs(spells) do
            if (value ~= 0) then
                local spell = resources:GetSpellById(value + 512);
                if (spell ~= nil and spell.Name ~= nil) then
                    local name = spell.Name[1];
                    if (type(name) == 'string' and name ~= '') then
                        names[name] = true;
                    end
                end
            end
        end
    end);

    return names, ok and found_buffer;
end

return reader;
