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

addon.name    = 'logitems';
addon.author  = 'towbes';
addon.desc    = 'code from packetlogger - log items for crafter addon';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';
local ffi = require 'ffi';

local doLog = false;
local currentItemId = 0;
local currentItem = T { };
local currentMats = T { };

-- Prepare the logs output folder..
local path = ('%s\\logs\\'):fmt(hook.get_hook_path());
hook.fs.create_dir(path);

-- Prepare the output file name based on the current date information..
local time = hook.time.get_local_time();
local file = ('%s\\itemlog_%02d.%02d.%02d.log'):fmt(path, time['day'], time['month'], time['year']);
daoc.chat.msg(daoc.chat.message_mode.help, ('[Packet Log] Packets will save to:\n%s'):fmt(file));

--[[
* Writes the given string to the current packet log file.
--]]
local function log(str)
    local f = io.open(file, 'a');
    if (f == nil) then
        return;
    end

    f:write(str);
    f:flush();
    f:close();
end

--[[
* event: packet_recv
* desc : Called when the game is handling a received packet.
--]]
hook.events.register('packet_recv', 'packet_recv_cb', function (e)
    --if (e.opcode ~= 0xA1 and e.opcode ~= 0xA9) then
    if (e.opcode == 0xAF) then
		local packet = ffi.cast('uint8_t*', e.data_modified_raw);
        --Find the string 'Total Utility:' and get right most index
        if (e.data:contains('minimum necessary')) then
			currentItem:clear();
			currentMats:clear();
			return;
		end
		--Append item name
		if (e.data:contains('ingredients to make the')) then
			local itemNameSplit = e.data:psplit('ingredients to make the ', 0, false);
			local itemName = itemNameSplit[2]:sub(1, -3)
			currentItem:append(('T{level = xx, name = \'%s\', '):fmt(itemName));
		end
		
		if (e.data:sub(2,4):contains('(')) then
			local matSplit = e.data:psplit('%) ', 0, false);
			local matValue = matSplit[1]:psplit('%(', 0, false)
			local matName = matSplit[2]:sub(1, -2);
			local currMat = T { };
			currMat['name'] = matName;
			currMat['value'] = matValue[2];
			currentMats:append(currMat);
		end

        --log(e.data:hexdump() .. '\n');
    end
end);

--[[
* event: packet_send
* desc : Called when the game is sending a packet.
--]]
hook.events.register('packet_send', 'packet_send_cb', function (e)
    --if (e.opcode ~= 0xA9 and e.opcode ~= 0xA3) then
    if (e.opcode == 0xED) then
		local newItemId = struct.unpack('I4', e.data);
        if currentItem:len() > 0 and currentMats:len() > 0 then
			currentItem:append(('mats = T{'))
			for k,v in pairs(currentMats) do
				currentItem:append(('T{ name = \'%s\', value = %d},'):fmt(v.name, v.value));
			end
			currentItem:append('},');
			currentItem:append(('itemId = %d},\n'):fmt(currentItemId));
			log(currentItem:join());
			--currentItemId = newItemId;
			currentItem:clear();
			currentMats:clear();
			currentItemId = newItemId;
		else
			currentItemId = newItemId;
		end
 
    end
end);

--[[
* event: packet_send
* desc : Called when the game is sending a packet.
--]]
hook.events.register('packet_send_udp', 'packet_send_cb', function (e)
    --log(('[C -> S UDP] OpCode: %02X | Size: %d | Param: %08X\n'):fmt(e.opcode, e.size, e.parameter));
    --log(e.data:hexdump() .. '\n');
end);

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
    if ((args[1]:ieq('logitem') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/logitem')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
		doLog = true;
		doCraft(currentItemId);
        return;
    end

    -- Command: /inv
    if ((args[1]:ieq('stop') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/stop')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
		doLog = false;
		daoc.chat.msg(daoc.chat.message_mode.help, ('Log Off'));
        return;
    end
end);

function doCraft(itemId) 
	--daoc.chat.msg(daoc.chat.message_mode.help, ('Send Item %d'):fmt(recipeList[selCraft][serverId][crafter.realm_id][tier][currentCraft].itemId));
	local sendPkt = struct.pack('I4', itemId):totable();
	daoc.game.send_packet(0xED, sendPkt, 0);
end
