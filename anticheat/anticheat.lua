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

addon.name    = 'anticheat';
addon.author  = 'atom0s';
addon.desc    = 'Prevents the client from sending cheat flag on ping packets.';
addon.link    = 'https://atom0s.com';
addon.version = '1.0';

require 'common';
local ffi   = require 'ffi';

--[[
* event: packet_send
* desc : Called when the game is sending a packet.
--]]

hook.events.register('packet_send', 'packet_send_cb', function (e)
    if (e.opcode == 0xA3 and e.size >= 0x0B) then
        local packet = ffi.cast('uint8_t*', e.data_modified_raw);
        packet[0x0B] = 0;
    end
end);
