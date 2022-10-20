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

addon.name    = 'crafter';
addon.author  = 'towbes';
addon.desc    = 'Craft repeater';
addon.link    = '';
addon.version = '1.0';

local ffi = require 'ffi';

require 'common';
require 'daoc';

local imgui = require 'imgui';
local ffi = require 'ffi';

--Tailoring receipes
local tailorRecipe = require('live-tailoring');

local leatherTiers = require('mats-leather');
local clothTiers = require('mats-cloth');

--[[
* Inventory Related Function Definitions
--]]
ffi.cdef[[
    typedef void        (__cdecl *sell_item_f)(const uint32_t slotNum);
    typedef void        (__cdecl *move_item_f)(const uint32_t toSlot, const uint32_t fromSlot, const uint32_t count);
    typedef void        (__cdecl *use_slot_f)(const uint32_t slotNum, const uint32_t useType);
	typedef void        (__cdecl *buy_item_f)(const uint32_t slotNum);

	//Credit to atom0s for reversing this structure
	typedef struct {
		uint32_t    model;
		uint32_t    unknown; // Set to 0 when read from packet.
		uint32_t    cost;
		uint32_t    level;
		uint32_t    value1;
		uint32_t    spd_abs;
		uint32_t    dpsaf_or_hand;
		uint32_t    damage_and_type;
		uint32_t    value2;
		uint32_t    can_use_flag;
		char        name_[64];
	} merchantitem_t;

	typedef struct {
        merchantitem_t      items[150];         // The array of items
    } merchantlist_t;
	
    typedef struct {
        char        name_[68];          // The craft name.
		uint32_t    level;              // The craft level. [ie. Unique id if used.]
		char		unknown[96];		// unknown for now
	} craft_t;

	typedef struct {
        craft_t      crafts[15];         // The array of crafts.
    } craftlevels_t;
]];

--[[
* Helpers for merchantitem_t
--]]
ffi.metatype('merchantitem_t', T{
    __index = function (self, k)
        return switch(k, {
            ['name']            = function () return ffi.string(self.name_); end,
            [switch.default]    = function () return nil; end
        });
    end,
    __newindex = function (self, k, v)
        error('read-only type');
    end,
    __tostring = function (self)
        return ffi.string(self.name_);
    end,
});

--[[
* Returns a craft by its array slot.
--]]
daoc.items.get_merchantitem = function (slotId)
    if (slotId < 0 or slotId > 149) then
        return nil;
    end

    local ptr = hook.pointers.get('game.ptr.merchant_list');
    if (ptr == 0) then return nil; end
	ptr = hook.memory.read_uint32(ptr);
    if (ptr == 0) then return nil; end

    return ffi.cast('merchantitem_t*', ptr + (slotId * ffi.sizeof('merchantitem_t')));
end

--[[
* Returns slot id for an item by name
--]]
daoc.items.get_merchant_slot = function (itemName)
	if (itemName == nil or itemName == '') then
		return nil;
	end
	for i=0, 150 do
		local item = daoc.items.get_merchantitem(i);
		if (item ~= nil) then
			if (item.name:ieq(itemName)) then
				return i;
			end
		end

	end
	return nil;
end

--[[
* Helpers for craft_t
--]]
ffi.metatype('craft_t', T{
    __index = function (self, k)
        return switch(k, {
            ['name']            = function () return ffi.string(self.name_); end,
            [switch.default]    = function () return nil; end
        });
    end,
    __newindex = function (self, k, v)
        error('read-only type');
    end,
    __tostring = function (self)
        return ffi.string(self.name_);
    end,
});

--[[
* Returns a craft by its array slot.
--]]
daoc.items.get_craft = function (slotId)
    if (slotId < 0 or slotId > 13) then
        return nil;
    end

    local ptr = hook.pointers.get('game.ptr.craft_levels');
    if (ptr == 0) then return nil; end
	ptr = hook.memory.read_uint32(ptr);
    if (ptr == 0) then return nil; end

    return ffi.cast('craft_t*', ptr + (slotId * ffi.sizeof('craft_t')));
end

--[[
* Returns current level of a craft searching by string name
--]]
daoc.items.get_craft_level = function (craftName)
	if (craftName == nil or craftName == '') then
		return nil;
	end
	for i=0, 15 do
		local craft = daoc.items.get_craft(i);
		if (craft ~= nil) then
			if (craft.name:ieq(craftName)) then
				return craft.level;
			end
		end

	end
	return nil;
end


--[[
* Sells the item
--]]
daoc.items.sell_item = function (slotNum)
    ffi.cast('sell_item_f', hook.pointers.get('daoc.items.sellitem'))(slotNum);
end

--[[
* Moves the item
--]]
daoc.items.move_item = function (toSlot, fromSlot, count)
    ffi.cast('move_item_f', hook.pointers.get('daoc.items.moveitem'))(toSlot, fromSlot, count);
end

--[[
* Uses the slot
--]]
daoc.items.use_slot = function (slotNum, useType)
    ffi.cast('use_slot_f', hook.pointers.get('daoc.items.useslot'))(slotNum, useType);
end

--[[
* Buys item from merchant
--]]
daoc.items.buy_item = function (slotNum)
    ffi.cast('buy_item_f', hook.pointers.get('daoc.items.buyitem'))(slotNum);
end

local savePacket = T{ };
local saveItemId = 0;

-- inventory Variables
local crafter = T{
    isCrafting = T{ false, },
    minSlotBuf = { '45' },
    minSlotBufSize = 4,
    maxSlotBuf = { '79' },
    maxSlotBufSize = 4,
    findItemNameBuf = {''},
    findItemNameBufSize = 100,
    sortDelay = 0.25,
	currentTier = 1,
    realm_id = 0,
};

--combo box for current craft
local selectedCraft = T { 9 };
local craftStrings = T {
	'Weaponcraft',
	'Armorcraft',
	'Siegecraft',
	'Alchemy',
	'Metalworking',
	'Leatherworking',
	'Clothworking',
	'Gemcutting',
	'Herbcraft',
	'Tailoring',
	'Fletching',
	'Spellcrafting',
	'Woodworking',
	'Bountycrafting',
	'Basic Crafting',
};

--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
    --Sell item pointer
    --Address of signature = game.dll + 0x0002B2E3
    local ptr = hook.pointers.add('daoc.items.sellitem', 'game.dll', '558BEC83EC??833D00829900??75??568B35????????D906E8????????D946??8945??E8????????8945??6A??58E8????????6689????668B????8D75??6689????E8????????6A??6A??8BC66A', 0,0);
    if (ptr == 0) then
        error('Failed to locate sell item function pointer.');
    end

    --Move item pointer
    --Address of signature = game.dll + 0x0002A976
    ptr = hook.pointers.add('daoc.items.moveitem', 'game.dll', '558BEC5151833D00829900??75??566A??58E8????????6689????668B????6689', 0,0);
    if (ptr == 0) then
        error('Failed to locate move item function pointer.');
    end

    --Use Slot
    --Address of signature = game.dll + 0x0002B6F5
    ptr = hook.pointers.add('daoc.items.useslot', 'game.dll', '558BEC83EC??833D00829900??0F85????????D905????????576A??33C0598D7D??F3??8B0D????????5FD941??DAE9DFE0F6C4??7B??804DFB??5333DB3859??5674??D905????????D941??DAE9DFE0F6C4??7B??804DFB??A1????????????????53E8????????84C05974??A1????????????????3BC375??804DFB??A1????????????????53E8????????84C05974??804DFB??D905????????D905????????DAE9DFE0F6C4??7B??E8????????84C074??804DFB??A1????????????????53E8????????84C05974??804DFB??A1????????????????6689????8B08894D??8B48??894D??8B48??8B40??8945??8A45??8845??8A45??8D75??894D??8845??E8????????536A??8BC66A??50E8????????83C4??5E5BC9C3558BEC51', 0,0);
    if (ptr == 0) then
        error('Failed to locate use slot function pointer.');
    end

    --Buy item pointer
	--Address of signature = game.dll + 0x0002AFBE
    local ptr = hook.pointers.add('daoc.items.buyitem', 'game.dll', '558BEC83EC??833D28980401??7E??68????????68????????E8????????5959C9C3833D00829900??75??83FF', 0,0);
    if (ptr == 0) then
        error('Failed to locate buy item function pointer.');
    end

    --Start of craftlevel array
	--Address of signature = game.dll + 0x0001F495
	--"B9????????8039??74??8B41"
    ptr = hook.pointers.add('game.ptr.craft_levels', 'game.dll', 'B9????????8039??74??8B41', 1,0);
    if (ptr == 0) then
        error('Failed to locate craft levels pointer.');
    end

	--Start of merchant array
	--Address of signature = game.dll + 0x0001C16B
    ptr = hook.pointers.add('game.ptr.merchant_list', 'game.dll', 'BE????????03FE3845', 1,0);
    if (ptr == 0) then
        error('Failed to locate merchant list pointer.');
    end

    --get player object for realm id
    local player = daoc.entity.get(daoc.entity.get_player_index());
    if player == nil then
        error('Failed to get player entity.');
		return;
    end

	crafter.realm_id = player.realm_id;

end);

--[[
* event: packet_recv
* desc : Called when the game is handling a received packet.
--]]
hook.events.register('packet_recv', 'packet_recv_cb', function (e)
    -- OpCode: Message
    if (e.opcode == 0xAF) then
        if (e.data:contains('fail') or e.data:contains('successfully')) then
			if (crafter.isCrafting[1]) then
				doCraft();
			end
		elseif (e.data:contains('maximum amount')) then
			daoc.chat.msg(daoc.chat.message_mode.help, ('Reached max'));
			crafter.isCrafting[1] = false;
		elseif (e.data:contains('missing')) then
			checkMats();
		end
    end
end);

--[[
* event: packet_send
* desc : Called when the game is sending a packet.
--]]
hook.events.register('packet_send', 'packet_send_cb', function (e)
    -- OpCode: Command
    if (e.opcode == 0xED) then
		--[C -> S] OpCode: ED | Size: 4 | Param: 00000000
		--0000  1C B8 00 00  
		--[itemId]
        -- Cast the raw packet pointer to a byte array via FFI..
        local packet = ffi.cast('uint8_t*', e.data_modified_raw);
		savePacket[1] = packet[0];
		savePacket[2] = packet[1];
		savePacket[3] = packet[2];
		savePacket[4] = packet[3];
		--numstr = e.data:join();
		saveItemId = struct.unpack('I4', e.data)
		daoc.chat.msg(daoc.chat.message_mode.help, ('itemId: %d'):fmt(saveItemId));
		
    end
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
    if ((args[1]:ieq('test') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/test')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        local selCraft = selectedCraft[1] + 1;
		daoc.chat.msg(daoc.chat.message_mode.help, ('%s level: %d'):fmt(craftStrings[selCraft], daoc.items.get_craft_level(craftStrings[selCraft])));

        return;
    end
end);

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_cb', function ()
    -- Render a custom example window via ImGui..
    imgui.SetNextWindowSize(T{ 500, 400, }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('Crafter')) then
        if (imgui.BeginTabBar('##crafter_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
			if (imgui.BeginTabItem('MainMenu', nil)) then
				imgui.Text('Crafter Main Menu');
				imgui.Checkbox('Toggle', crafter.isCrafting);

				if (crafter.isCrafting[1]) then
					imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Crafting');
				else
					imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Not Crafting');
				end
				local craft_pos = { selectedCraft[1] };
				if (imgui.Combo('##selCraft', craft_pos, 'Weaponcraft\0Armorcraft\0Siegecraft\0Alchemy\0Metalworking\0Leatherworking\0Clothworking\0Gemcutting\0Herbcraft\0Tailoring\0Fletching\0Spellcrafting\0Woodworking\0Bountycrafting\0Basic Crafting\0\0')) then
					selectedCraft[1] = craft_pos[1];
				end
				if (imgui.Button('Start')) then
					doCraft();
				end
				imgui.EndTabItem();
			end
			if (imgui.BeginTabItem("Inventory Tools")) then
				imgui.Text(("Backpack Start: %d , End: %d"):fmt(daoc.items.slots.vault_min, daoc.items.slots.vault_max));
				imgui.Text("MinSlot:")
				imgui.SameLine();
				imgui.PushItemWidth(35);
				imgui.InputText("##MinSlot", crafter.minSlotBuf, crafter.minSlotBufSize);
				imgui.SameLine()
				imgui.Text("MaxSlot:")
				imgui.SameLine();
				imgui.PushItemWidth(35);
				imgui.InputText("##MaxSlot", crafter.maxSlotBuf, crafter.maxSlotBufSize);
				local minSlot = tonumber(crafter.minSlotBuf[1]);
				local maxSlot = tonumber(crafter.maxSlotBuf[1]);
				if minSlot == nil then minSlot = 40; end;
				if maxSlot == nil then maxSlot = 79; end;
				--set min and max slots
				imgui.Text("Item name:")
				imgui.SameLine();
				imgui.PushItemWidth(350);
				imgui.InputText("##FindName", crafter.findItemNameBuf, crafter.findItemNameBufSize);
				if (imgui.Button('Sell')) then
					for i = minSlot, maxSlot do
						local item = daoc.items.get_item(i)
						if (item ~= nil and item.name:len() > 0) then
							daoc.items.sell_item(i);
						end
					end
				end
				imgui.SameLine();
				if (imgui.Button('Drop')) then
					for i = minSlot, maxSlot do
						local item = daoc.items.get_item(i)
						if (item ~= nil and item.name:len() > 0) then
							daoc.items.move_item(0, i, 0);
						end
					end
				end
				imgui.SameLine();
				if (imgui.Button('Destroy')) then
					daoc.chat.msg(daoc.chat.message_mode.help, 'Button was clicked!');
				end
				if (imgui.Button('Use Min Slot')) then
					local item = daoc.items.get_item(crafter.minSlotBuf[1])
					if (item ~= nil and item.name:len() > 0) then
						daoc.items.use_slot(tonumber(crafter.minSlotBuf[1]), 1);
					end
				end
				
				for i = minSlot, maxSlot do
					--Split based on slots, ie equipped gear, inventory, vault, house vault
					local itemTemp = daoc.items.get_item(i);
					if itemTemp.name:lower():contains(crafter.findItemNameBuf[1]:lower())then 
						imgui.Text(("Slot %d, ItemId - %u, ItemName - %s\n"):fmt(i, itemTemp.id, itemTemp.name));
					end
				end

				imgui.EndTabItem()
			end
			imgui.EndTabBar();
		end
    end
    imgui.End();
end);

function sellByName(itemName)
	--only sell 2nd bag+
	for i = 48, 79 do
		local item = daoc.items.get_item(i)
		if (item ~= nil and item.name:len() > 0) then
			if item.name:ieq(itemName) then
				daoc.items.sell_item(i);
			end
		end
	end
end

function sellBySlots(minSlot, maxSlot)
	for i = minSlot, maxSlot do
		local item = daoc.items.get_item(i)
		if (item ~= nil and item.name:len() > 0) then
				daoc.items.sell_item(i);
		end
	end
end

function empty_slots(minSlot, maxSlot)
	local emptySlots = 0;
	for i = minSlot, maxSlot do
		local item = daoc.items.get_item(i)
		if (item ~= nil and item.name:len() == 0) then
			emptySlots = emptySlots + 1;
		end
	end
	return emptySlots;
end

--[[
* function: get_current_craft
* desc : Returns current tier and craft id
--]]
function get_current_craft()
	--Get current craft level
	local selCraft = selectedCraft[1] + 1;
	local clvl = daoc.items.get_craft_level(craftStrings[selCraft])
	--figure out which recipe we should be making, next one is oj when receipe level - current level < 15
	local itemId = 0;
	local tier = 1;
	--adjust tier based on clvl
	if clvl > 99 and clvl < 1000 then
		tier = tonumber(tostring(clvl)[1]) + 1;
	elseif clvl >= 1000 then
		tier = 10;
	end
	--if our tier switched, sell our entire inventory
	if tier > crafter.currentTier then
		sellBySlots(crafter.minSlotBuf[1], crafter.maxSlotBuf[1]);
		crafter.currentTier = tier;
	end
	--remove the 100s place
	clvl = clvl:mod(100);
	local currentCraft = 0;
	--daoc.chat.msg(daoc.chat.message_mode.help, ('ItemId not found. Clvl %d, realm %d, tier %d'):fmt(clvl, crafter.realm_id, tier))
	--daoc.chat.msg(daoc.chat.message_mode.help, ('table: %s'):fmt(tailorRecipe[crafter.realm_id][tier][1]:join()))
	for x = 1, tailorRecipe[crafter.realm_id][tier]:len() do
		local recipe = tailorRecipe[crafter.realm_id][tier][x];
		--daoc.chat.msg(daoc.chat.message_mode.help, ('Item %s - %d - Clvl %d'):fmt(recipe.name, recipe.level, clvl))
		if recipe.level - clvl < 20 then
			itemId = recipe.itemId;
			currentCraft = x;
		end
	end
	if itemId > 0 and currentCraft > 0 then
		return tier, currentCraft;
	else
		daoc.chat.msg(daoc.chat.message_mode.help, ('ItemId not found. Clvl %d, realm %d, tier %d'):fmt(clvl, crafter.realm_id, selectedTier[1]));
		return nil, nil;
	end
end

function doCraft ()
	--Get current craft level
	local tier, currentCraft = get_current_craft();
	if tier ~= nil and currentCraft ~= nil then
		--Check if we need to sell
		local tempSlots = empty_slots(crafter.minSlotBuf[1], crafter.maxSlotBuf[1])
		--daoc.chat.msg(daoc.chat.message_mode.help, ('Empty slots %d'):fmt(tempSlots));
		--Try to sell all tier items just in case we had extras of others
		if (tempSlots <= 2) then
			for x = 1, tailorRecipe[crafter.realm_id][tier]:len() do
				sellByName(tailorRecipe[crafter.realm_id][tier][x].name);
			end
		end
		local sendPkt = struct.pack('I4', tailorRecipe[crafter.realm_id][tier][currentCraft].itemId):totable();
		sendCraft(sendPkt);
	else
		daoc.chat.msg(daoc.chat.message_mode.help, ('Could not find item'));
	end
end

function sendCraft(packet)
	--daoc.chat.msg(daoc.chat.message_mode.help, ('sendcraft %s'):fmt(packet:join()));
	daoc.game.send_packet(0xED, packet, 0);
end

function checkMats()

	
	--What materials do we need?
	local tier, currentCraft = get_current_craft();
	--local mats = tailorRecipe[crafter.realm_id][tier][currentCraft].mats;
	--daoc.chat.msg(daoc.chat.message_mode.help, ('mats needed %s'):fmt(mats:tostring()));
	--For each item in mats table, buy 40x of the material
	
	for k,v in pairs(tailorRecipe[crafter.realm_id][tier][currentCraft].mats) do
		--daoc.chat.msg(daoc.chat.message_mode.help, ('buy %s'):fmt(v));
		local matCount = v*30;
		while matCount > 100 do
			buyMats(tier, k, 100);
			matCount = matCount - 100;
		end
		if matCount > 0 and matCount < 100 then
			buyMats(tier, k, matCount);
		end
	end

	doCraft();
	----First find the slot id
	--for x=0, 149 do
	--	local merchitem = daoc.items.get_merchantitem(x);
	--	if merchitem ~= nil then
	--		
	--	end
	--end
end

function buyMats(tier, type, count)
	--daoc.chat.msg(daoc.chat.message_mode.help, ('buy %s'):fmt(type));
	local itemName = '';
	local slotNum = nil;
	if type:ieq('leather') then
		itemName = leatherTiers[tier] .. ' leather square';
		if (itemName:len() > 0) then
			slotNum = daoc.items.get_merchant_slot(itemName);
		else
			daoc.chat.msg(daoc.chat.message_mode.help, ('Failed to build leather itemname'));
		end
		if slotNum ~= nil then
			--daoc.chat.msg(daoc.chat.message_mode.help, ('buy %d %s from slot %d'):fmt(count, itemName, slotNum));
			buyItem(slotNum, count)
		else
			daoc.chat.msg(daoc.chat.message_mode.help, ('No %s in merchant list'):fmt(itemName));
		end
	elseif type:ieq('thread') then
		itemName = clothTiers[tier] .. ' heavy thread';
		if (itemName:len() > 0) then
			slotNum = daoc.items.get_merchant_slot(itemName);
		else
			daoc.chat.msg(daoc.chat.message_mode.help, ('Failed to build cloth itemname'));
		end
		if slotNum ~= nil then
			--daoc.chat.msg(daoc.chat.message_mode.help, ('buy %d %s from slot %d'):fmt(count, itemName, slotNum));
			buyItem(slotNum, count)
		else
			daoc.chat.msg(daoc.chat.message_mode.help, ('No %s in merchant list'):fmt(itemName));
		end
	end
end

function buyItem(slot, count)

	if slot == nil or count == nil then
		return;
	end

	if (daoc.items.get_merchantitem(0) == nil) then 
		daoc.chat.msg(daoc.chat.message_mode.help, ('You must open merchant window'));
		return; 
	end

    --get player object for realm id
    local player = daoc.entity.get(daoc.entity.get_player_index());
    if player == nil then
        error('Failed to get player entity.');
		return;
    end

	--Packet 0x78
	--int32 xpos
	--int32 ypos
	--int16 id (this is a merchant type ID) 04 is normal merchant
	--int16 slotNum
	--byte count
	--byte menuId - 0 for menu id
	--pack as big endian
	local sendpkt = struct.pack('>I4I4I2I2BBBB', player.loc_x, player.loc_y, 04, slot, count, 0, 0, 0):totable();
	daoc.game.send_packet(0x78, sendpkt, 0);
end