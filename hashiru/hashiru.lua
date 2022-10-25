--[[
* daochook - Copyright (c) 2022 atom0s [atom0s@live.com]
* Contact: https://www.atom0s.com/
* Contact: https://discord.gg/UmXNvjq
* Contact: https://github.com/atom0s
*
* This file is part of daochook.
*
* daochook is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* daochook is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero General Public License for more details.
*
* You should have received a copy of the GNU Affero General Public License
* along with daochook.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name    = 'hashiru';
addon.author  = 'towbes';
addon.desc    = 'Movement Library';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';

local imgui = require 'imgui';
local ffi = require 'ffi';

local settings = T {
    stopDist = 50,
    moving = false;
    target = false;
    pos = true;
};

local runSpeed = T {
    normal = 238,
    hasten = 324,
}

local realmStr = T {'Alb', 'Mid', 'Hib' }

local entList = T { };

--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
    --Sell item pointer
    --Address of signature = game.dll + 0x0002B2E3


end);

--[[
* event: unload
* desc : Called when the addon is being unloaded.
--]]
hook.events.register('unload', 'unload_cb', function ()
    --[[
    Event has no arguments.
    --]]
end);

--[[
* Prints the addon specific help information.
*
* @param {err} err - Flag that states if this function was called due to an error.
--]]
local function print_help(err)
    err = err or false;

    local mode = daoc.chat.message_mode.help;
    if (err) then
        daoc.chat.msg(mode, 'Invalid command syntax for inventory addon');
    else
        daoc.chat.msg(mode, 'Available commands for the inventory addon are:');
    end

    local help = daoc.chat.msg:compose(function (cmd, desc)
        return mode, ('  %s - %s'):fmt(cmd, desc);
    end);

    help('/hunter', 'Sell items between slots (must be between 40 and 79)');
end

--[[
* event: command
* desc : Called when the game is handling a command.
--]]
hook.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.modified_command:args();
    if (#args == 0) then
        return;
    end

    -- Command: /inv
    if ((args[1]:ieq('movetarget') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/movetarget')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        settings.movepos = false;

        settings.movetarg =  true;


        return;
    end

    -- Command: /inv
    if ((args[1]:ieq('movexy') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/movexy')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        
        settings.movetarg = false
        settings.movepos =  true;



        --in game locs
        settings.loc_x = tonumber(args[2]);
        settings.loc_y = tonumber(args[3]);

        daoc.chat.msg(daoc.chat.message_mode.help, ('x %d : y %d'):fmt(settings.loc_x, settings.loc_y));
        return;
    end

        -- Command: /inv
        if ((args[1]:ieq('movestop') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/movestop')) then
            -- Mark the command as handled, preventing the game from ever seeing it..
            e.blocked = true;
            settings.movepos = false;
    
            settings.movetarg =  false;
    
    
            return;
        end

end);

--[[
* event: d3d_present_1 for imgui
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_1', function ()
    --[[
    Event has no arguments.
    --]]

    --clear the table
    entList:clear();
    --get player object
    local player = daoc.states.get_player_state();
    if player == nil then
        return;
    end

    --get player entity
    local playerEnt = daoc.entity.get(daoc.entity.get_player_index());
    if playerEnt == nil then
        return;
    end

    --get target
    local target = daoc.entity.get(daoc.entity.get_target_index());
    if target == nil then
        return;
    end

    if (settings.movetarg) then

        local dist = math.distance2d(target.x, target.y, player.x, player.y);
        local heading = GetGameHeading(player.x, player.y, target.x, target.y);
        if (dist > settings.stopDist) then
            player.heading = heading;
            player.velocity_x = runSpeed.normal;
        else 
            settings.movetarg = false;
        end
    elseif (settings.movepos) then;

        local dist = math.distance2d(playerEnt.loc_x, playerEnt.loc_y, settings.loc_x, settings.loc_y);
        local heading = GetGameHeading(playerEnt.loc_x, playerEnt.loc_y, settings.loc_x, settings.loc_y);
        player.heading = heading;
        if (dist > settings.stopDist) then
            if (player.heading - heading > 100) then
                player.heading = heading;
            end
            player.velocity_x = runSpeed.normal;
        else 
            settings.movepos = false;
        end

    end

    -- Render a custom example window via ImGui..
    --imgui.SetNextWindowSize(T{ 350, 200, }, ImGuiCond_Always);
    --if (imgui.Begin('RunSpeed')) then
    --    imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, ('xvel: %.01f'):fmt(player.velocity_x));
    --end
    --imgui.End();

end);   


function GetGameHeading(playerX, playerY, targX, targY)
    local dx = targX - playerX;
    local dy = targY - playerY;

    local heading = math.atan2(-dx, dy) * (180.0 / math.pi) * (4096.0 / 360.0);

    if (heading < 0) then
        heading = heading + 4096;
    end

    return heading;
end