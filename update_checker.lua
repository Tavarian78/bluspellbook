local checker = {};

local api_url = 'https://api.github.com/repos/Tavarian78/bluspellbook/releases/latest';

local function version_parts(version)
    local parts = {};
    for value in tostring(version or ''):gmatch('%d+') do
        parts[#parts + 1] = tonumber(value);
    end
    return parts;
end

local function is_newer(candidate, installed)
    local left = version_parts(candidate);
    local right = version_parts(installed);
    local count = math.max(#left, #right);
    for index = 1, count do
        local a = left[index] or 0;
        local b = right[index] or 0;
        if (a ~= b) then
            return a > b;
        end
    end
    return false;
end

function checker.new(state, json, installed_version)
    local api = {};

    function api.check()
        state.update_checking = true;
        state.update_status = 'Checking GitHub...';

        local loaded, http, ltn12 = pcall(function ()
            return require('socket.http'), require('socket.ltn12');
        end);
        if (not loaded) then
            state.update_checking = false;
            state.update_status = 'Update check is not supported by this Ashita install.';
            return;
        end

        local response = {};
        http.TIMEOUT = 5;
        local requested, _, code = pcall(function ()
            return http.request({
                url = api_url,
                method = 'GET',
                headers = {
                    ['Accept'] = 'application/vnd.github+json',
                    ['User-Agent'] = 'BluSpellbook/' .. installed_version,
                },
                sink = ltn12.sink.table(response),
            });
        end);

        state.update_checking = false;
        if (not requested or tonumber(code) ~= 200) then
            state.update_status = tonumber(code) == 404 and
                'No published GitHub release was found.' or
                'Unable to check for updates.';
            return;
        end

        local decoded, release = pcall(function ()
            return json.decode(table.concat(response));
        end);
        if (not decoded or type(release) ~= 'table' or
                type(release.tag_name) ~= 'string') then
            state.update_status = 'GitHub returned an unreadable version.';
            return;
        end

        state.update_available = is_newer(release.tag_name, installed_version);
        state.update_status = state.update_available and
            ('Update available: %s'):fmt(release.tag_name) or
            ('Up to date: v%s'):fmt(installed_version);
    end

    return api;
end

return checker;
