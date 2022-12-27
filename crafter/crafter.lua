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
local settings  = require 'settings';
local json = require('json');


local recipeList = T { };

--Master Recipe list
local masterRecipe = T { };

--[[
* Inventory Related Function Definitions
--]]
ffi.cdef[[
    typedef void        (__cdecl *sell_item_f)(const uint32_t slotNum);
    typedef void        (__cdecl *move_item_f)(const uint32_t toSlot, const uint32_t fromSlot, const uint32_t count);
    typedef void        (__cdecl *use_slot_f)(const uint32_t slotNum, const uint32_t useType);
	typedef void        (__cdecl *buy_item_f)(const uint32_t slotNum);
	typedef void		(__cdecl *interact_f)(const uint32_t objId);

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
        char        name_[64];          // The craft name.
		uint32_t	level_mod;			// actual level = level_mod * 0x100 + level
		uint32_t    level;              // The craft level. [ie. Unique id if used.]
		uint32_t	index;				//index in TDL?
		char		unknown1[24];
		uint32_t	unknownIndex;
		char		unknown[64];		// unknown for now
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
			if (item.name:contains(itemName)) then
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
			if (craft.name:contains(craftName)) then
				return craft.level_mod * 0x100 + craft.level;
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

--[[
* Interact with an object
--]]
daoc.items.interact = function (objId)
    ffi.cast('interact_f', hook.pointers.get('daoc.items.interact'))(objId);
end

local savePacket = T{ };
local saveItemId = 0;

-- inventory Variables
local default_settings = T{
	simpleToggle = T { false },
    isCrafting = T{ false, },
	logItemId = T { false, },
    minSlotBuf = { '40' },
    minSlotBufSize = 4,
    maxSlotBuf = { '79' },
    maxSlotBufSize = 4,
    findItemNameBuf = {''},
    findItemNameBufSize = 100,
	craftLvlDiffBuf = { '20' },
	craftLvlDiffSize = 10,
	numMatsBuf = {'30'},
	numMatsSize = 10,
    sortDelay = 0.25,
	currentTier = 0,
    realm_id = T{0},
	server_id = T{1}, -- 0 = live, 1 = eden
	ismoving = false,
	dest_x = 0,
	dest_y = 0,
	stopDist = 50,
	movementToggle = T { true },
	movetargetvendor = T { false },
	movetargetcraft = T { false },
	movetargettrain = T { false },
	buyingMats = false;
	isTraining = false;
	useTrainer = T{ false, };
    vendorTargNameBuf = { 'Alastar MacDonnell' },
    vendorTargNameSize = 30,
    craftTargNameBuf = { 'Alchemy Table' },
    craftTargNameSize = 30,
	trainTargNameBuf = { 'Laisren' },
	trainTargNameSize = 30,
	vendor_xLocBuf = { '28053' },
    vendor_xLocSize = 10,
	vendor_yLocBuf = { '51726' },
    vendor_yLocSize = 10,
    craft_xLocBuf = { '28355' },
    craft_xLocSize = 10,
    craft_yLocBuf = { '53136' },
    craft_yLocSize = 10,
    train_xLocBuf = { '28355' },
    train_xLocSize = 10,
    train_yLocBuf = { '53136' },
    train_yLocSize = 10,
	haveMats = false,
	currTier = 0,
	currCraft = 0,
	selectedCraft = T { 11 };
};

local crafter = settings.load(default_settings);

--pause time to buy mats and interact with vendor
local tick_holder = hook.time.tick();
local tick_interval = 5000;

--pause time to start crafting after moving
local craft_tick_holder = hook.time.tick();
local craft_interval = 5000;

--combo box for current craft
--local crafter.selectedCraft = T { 11 };
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
	'Spellcraft',
	'Woodworking',
	'Bountycrafting',
	'Basic Crafting',
};

local entList = T{ };

--[[
* Event invoked when a settings table has been changed within the settings library.
*
* Note: This callback only affects the default 'settings' table.
--]]
settings.register('settings', 'settings_update', function (e)
    -- Update the local copy of the 'settings' settings table..
    crafter = e;

    -- Ensure settings are saved to disk when changed..
    settings.save();
end);

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

    --Interact pointer
	--Address of signature = game.dll + 0x0002AE06 0x42ae06
    local ptr = hook.pointers.add('daoc.items.interact', 'game.dll', '558BEC83EC??833D28980401??7E??68????????68????????E8????????5959C9C3833D00829900??75??56', 0,0);
    if (ptr == 0) then
        error('Failed to locate interact function pointer.');
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

	crafter.realm_id[1] = player.realm_id - 1;

	--load movement addon
	daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, '/addon load hashiru');

end);

--[[
* event: unload
* desc : Called when the addon is being unloaded.
--]]
hook.events.register('unload', 'unload_cb', function ()
	--turn off
	crafter.isCrafting[1] = false;
	crafter.simpleToggle[1] = false;
	crafter.ismoving = false;
	crafter.isTraining = false;
	--save settings when unloading
	settings.save();
end);

--[[
* event: packet_recv
* desc : Called when the game is handling a received packet.
--]]
hook.events.register('packet_recv', 'packet_recv_cb', function (e)
    -- OpCode: Message
    if (e.opcode == 0xAF) then
		if (e.data_modified:contains('You have reached')) then
			crafter.isCrafting[1] = false;
			-- if eden, go visit the trainer
			if not crafter.simpleToggle[1] and crafter.useTrainer[1] then
				daoc.chat.msg(daoc.chat.message_mode.help, ('Reached max'));
				crafter.isTraining = true;
				crafter.buyingMats = false;
				visitTrainer();
			end
		end
        if (e.data_modified:contains('fail') or e.data_modified:contains('successfully')) then
			if (crafter.isCrafting[1]) then
				if (crafter.simpleToggle[1]) then
					local sendPkt = struct.pack('>H',saveItemId):totable();
					sendCraft(sendPkt);
				else
					doCraft();	
				end
			end
		end
		if (crafter.isCrafting[1] and e.data_modified:contains('missing')) then
			if not crafter.simpleToggle[1] and crafter.isCrafting[1] then
				crafter.haveMats = false;
				checkMats();
			end
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
		--numstr = e.data:join();
		--Get short in big endian mode to match crf file
		saveItemId = struct.unpack('>H', e.data);
		if (crafter.logItemId[1]) then
			daoc.chat.msg(daoc.chat.message_mode.help, ('itemId: %d'):fmt(saveItemId));
		end
		
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
		for i = 0, 14 do
			local craft = daoc.items.get_craft(i);
			if craft ~= nil then
				daoc.chat.msg(daoc.chat.message_mode.help, ('craft: %s, index: %d'):fmt(craft.name, craft.unknownIndex));
			end
		end
        return;
    end
end);

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_move', function ()

    --get player entity
    local playerEnt = daoc.entity.get(daoc.entity.get_player_index());
    if playerEnt == nil then
        return;
    end

	if (crafter.ismoving) then
		tick_interval = math.random(8000,12000);
		if (hook.time.tick() >= (tick_holder + tick_interval) ) then	
			tick_holder = hook.time.tick();
			--daoc.chat.msg(daoc.chat.message_mode.help, ('Do Tick'));
			if (crafter.dest_x == 0 or crafter.dest_y == 0) then return; end
			local dist = math.distance2d(playerEnt.loc_x, playerEnt.loc_y, crafter.dest_x, crafter.dest_y);
			--daoc.chat.msg(daoc.chat.message_mode.help, ('p: %d %d - t %d %d - d %d'):fmt(playerEnt.loc_x, playerEnt.loc_y, crafter.dest_x, crafter.dest_y, dist) );
			if (dist < crafter.stopDist) then
				craft_tick_interval = math.random(3000,5000);
				if (hook.time.tick() >= (craft_tick_holder + craft_tick_interval) ) then	
					craft_tick_holder = hook.time.tick();

					crafter.ismoving = false;
					--crafter.dest_x = 0;
					--crafter.dest_y = 0;
					--sleep 3 seconds to stop
					if (crafter.buyingMats) then
						daoc.chat.msg(daoc.chat.message_mode.help, ('Buying Mats'));
						checkMats();
					elseif (crafter.isTraining) then
						daoc.chat.msg(daoc.chat.message_mode.help, ('Training'));
						visitTrainer();
					else
						daoc.chat.msg(daoc.chat.message_mode.help, ('Done running do craft'));
						doCraft();
					end
				end
			end
		end
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
				imgui.Text('Crafter Main Menu - Start with empty inventory');
				imgui.Checkbox('Toggle', crafter.isCrafting);
				imgui.SameLine();
				imgui.Checkbox('Log ItemId', crafter.logItemId);

				if (crafter.isCrafting[1]) then
					imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Crafting');
				else
					imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Not Crafting');
				end
				local server_pos = { crafter.server_id[1] };
				if (imgui.Combo('##selServer', server_pos, 'Live\0Eden\0\0')) then
					crafter.server_id[1] = server_pos[1];
				end
				local realm_pos = { crafter.realm_id[1] };
				if (imgui.Combo('##selRealm', realm_pos, 'Albion\0Midgard\0Hibernia\0\0')) then
					crafter.realm_id[1] = realm_pos[1];
				end
				local craft_pos = { crafter.selectedCraft[1] };
				if (imgui.Combo('##selCraft', craft_pos, 'Weaponcraft\0Armorcraft\0Siegecraft\0Alchemy\0Metalworking\0Leatherworking\0Clothworking\0Gemcutting\0Herbcraft\0Tailoring\0Fletching\0Spellcrafting\0Woodworking\0Bountycrafting\0Basic Crafting\0\0')) then
					crafter.selectedCraft[1] = craft_pos[1];
				end
				if (imgui.Button('Start', { 55, 20 })) then
					load_recipes();
					load_paths();
					--check if inventory is empty or only 1 or 2 slots (in case you leave bind stone in)
					if (empty_slots(crafter.minSlotBuf[1], crafter.maxSlotBuf[1]) > 36) then
						checkMats();
					else
						doCraft();
					end
					
				end
				imgui.SameLine();
                if (imgui.Button('Save', { 55, 20 })) then
                    settings.save();
					daoc.chat.msg(daoc.chat.message_mode.help, ('Settings saved'));
                end
				imgui.SameLine();
                if (imgui.Button('Reload', { 55, 20 })) then
                    settings.reload();
					daoc.chat.msg(daoc.chat.message_mode.help, ('Settings reloaded'));
                end
				imgui.SameLine();
                if (imgui.Button('Reset', { 55, 20 })) then
                    settings.reset();
					daoc.chat.msg(daoc.chat.message_mode.help, ('Settings reset'));
                end
				imgui.Text('Craft Lvl Diff:');
				imgui.SameLine();
				imgui.InputText('##craftlvldiff', crafter.craftLvlDiffBuf, crafter.craftLvlDiffSize );
				imgui.Text('Amount of mats:');
				imgui.SameLine();
				imgui.InputText('##nummats', crafter.numMatsBuf, crafter.numMatsSize);
				imgui.Checkbox('Toggle Movement', crafter.movementToggle);
				if (crafter.movementToggle[1]) then
					imgui.Checkbox('Toggle Vendor Move Type', crafter.movetargetvendor);
					if (crafter.movetargetvendor[1]) then
						imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Moving vendor with target');
					else
						imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Moving vendor with loc');
					end
					imgui.Text("Target:")
					imgui.SameLine();
					imgui.PushItemWidth(200);
					imgui.InputText("##vendorname", crafter.vendorTargNameBuf, crafter.vendorTargNameSize);
					imgui.SameLine();
					imgui.Text("Vendor target name is required");
					imgui.Text("X:")
					imgui.SameLine();
					imgui.PushItemWidth(100);
					imgui.InputText("##vendorx", crafter.vendor_xLocBuf, crafter.vendor_xLocSize);
					imgui.SameLine();
					imgui.Text("Y:")
					imgui.SameLine();
					imgui.PushItemWidth(100);
					imgui.InputText("##vendory", crafter.vendor_yLocBuf, crafter.vendor_yLocSize);


					imgui.Checkbox('Toggle Craft Spot Move Type', crafter.movetargetcraft);
					imgui.SameLine();
					if (crafter.movetargetcraft[1]) then
						imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Moving craft loc with target');
					else
						imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Moving craft loc with loc');
					end

					imgui.Text("Target:")
					imgui.SameLine();
					imgui.PushItemWidth(200);
					imgui.InputText("##craftname", crafter.craftTargNameBuf, crafter.craftTargNameSize);
					imgui.Text("X:")
					imgui.SameLine();
					imgui.PushItemWidth(100);
					imgui.InputText("##craftx", crafter.craft_xLocBuf, crafter.craft_xLocSize);
					imgui.SameLine();
					imgui.Text("Y:")
					imgui.SameLine();
					imgui.PushItemWidth(100);
					imgui.InputText("##crafty", crafter.craft_yLocBuf, crafter.craft_yLocSize);

					imgui.Checkbox('Toggle Trainer Move Type', crafter.movetargettrain);
					imgui.SameLine();
					if (crafter.movetargettrain[1]) then
						imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Moving trainer with target');
					else
						imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Moving trainer with loc');
					end
					
					imgui.Text("Target:")
					imgui.SameLine();
					imgui.PushItemWidth(200);
					imgui.InputText("##trainname", crafter.trainTargNameBuf, crafter.trainTargNameSize);
					imgui.Text("X:")
					imgui.SameLine();
					imgui.PushItemWidth(100);
					imgui.InputText("##trainx", crafter.train_xLocBuf, crafter.train_xLocSize);
					imgui.SameLine();
					imgui.Text("Y:")
					imgui.SameLine();
					imgui.PushItemWidth(100);
					imgui.InputText("##trainy", crafter.train_yLocBuf, crafter.train_yLocSize);
						
				else
					imgui.Text("Merchant window must be open");
				end
				imgui.EndTabItem();
			end
			if (imgui.BeginTabItem("Repeat Only")) then
				imgui.Text('Enable checkbox, then start a craft and addon will loop that craft')
				imgui.Checkbox('Simple Toggle', crafter.simpleToggle);
				
				if (crafter.simpleToggle[1]) then
					crafter.isCrafting[1] = true;
				else
					crafter.isCrafting[1] = false;
				end

				if (crafter.isCrafting[1]) then
					imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Crafting');
				else
					imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Not Crafting');
				end
				imgui.EndTabItem()
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
			if (imgui.BeginTabItem("Debug")) then
				imgui.Text(('buyingMats: %s'):fmt(crafter.buyingMats));
				imgui.Text(('isTraining: %s'):fmt(crafter.isTraining));
				imgui.Text(('isMoving: %s'):fmt(crafter.ismoving))
				imgui.Text(('isCrafting: %s'):fmt(crafter.isCrafting[1]));
				imgui.EndTabItem()
			end
			imgui.EndTabBar();
		end
    end
    imgui.End();
end);

function sellByName(itemName)
	--only sell 2nd bag+
	for i = 40, 79 do
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
	local selCraft = crafter.selectedCraft[1] + 1;
	local clvl = daoc.items.get_craft_level(craftStrings[selCraft])
	if clvl == nil then
		daoc.chat.msg(daoc.chat.message_mode.help, ('%s level not found'):fmt(craftStrings[selCraft]));
		return;
	end
	--figure out which recipe we should be making, next one is oj when receipe level - current level < 15
	local tier = 1;
	--adjust tier based on clvl
	if clvl > 99 and clvl < 1000 then
		tier = tonumber(tostring(clvl)[1]) + 1;
	elseif clvl >= 1000 then
		tier = 11;
	end
	--if our tier switched, sell our entire inventory
	if crafter.currentTier > 0 and tier > crafter.currentTier then
		sellBySlots(crafter.minSlotBuf[1], crafter.maxSlotBuf[1]);
		crafter.currentTier = tier;
	else
		crafter.currentTier = tier;
	end
	--remove the 100s place
	clvl = clvl:mod(100);
	local currentCraft = 0;
	local serverId = crafter.server_id[1] + 1;
	local realmId = crafter.realm_id[1] + 1;
	daoc.chat.msg(daoc.chat.message_mode.help, ('craft %d, clvl: %d, server: %d, realm: %d, tier %d'):fmt(selCraft, clvl, serverId, realmId, tier))
	--daoc.chat.msg(daoc.chat.message_mode.help, ('table: %s'):fmt(recipeList[selCraft]:join()))
	for x = 1, recipeList[selCraft][realmId][tier]:len() do
		local recipe = recipeList[selCraft][realmId][tier][x];
		--daoc.chat.msg(daoc.chat.message_mode.help, ('Item %s - %d - Clvl %d'):fmt(recipe.name, recipe.level, clvl))
		local craftLvlDiff = tonumber(crafter.craftLvlDiffBuf[1])
		if craftLvlDiff == 0 then craftLvlDiff = 20; end
		if recipe.level - clvl < craftLvlDiff then
			currentCraft = x;
		end
	end
	if currentCraft > 0 then
		return tier, currentCraft;
	else
		daoc.chat.msg(daoc.chat.message_mode.help, ('ItemId not found. Clvl %d, realm %d, tier %d'):fmt(clvl, realmId, tier));
		return nil, nil;
	end
end

function doCraft ()
	--Get current craft level
	local selCraft = crafter.selectedCraft[1] + 1;
	--only get a new craft if we don't have mats
	if (crafter.haveMats == false) then
		crafter.currTier, crafter.currCraft = get_current_craft();
		crafter.haveMats = true;
	end
	if crafter.currTier ~= nil and crafter.currCraft ~= nil then
		--Check if we need to sell
		local tempSlots = empty_slots(crafter.minSlotBuf[1], crafter.maxSlotBuf[1])
		--daoc.chat.msg(daoc.chat.message_mode.help, ('Empty slots %d'):fmt(tempSlots));
		--Try to sell all tier items just in case we had extras of others
		local realmId = crafter.realm_id[1] + 1;
		if (tempSlots < 2) then
			--Make sure we are at vendor
			if (crafter.movementToggle[1]) then
				if (not sellDistCheck()) then
					return;
				else
					targetByName(crafter.vendorTargNameBuf[1])
					--get target entity
					local target = daoc.entity.get(daoc.entity.get_target_index());
					if target == nil then
						return;
					end
					daoc.items.interact(target.object_id);
				end
			end
			for x = 1, recipeList[selCraft][realmId][crafter.currTier]:len() do
				sellByName(recipeList[selCraft][realmId][crafter.currTier][x].name);
			end
		end
		if (crafter.movementToggle[1]) then
			--check that we are at the craft spot
			if (not craftDistCheck()) then
				return;
			end
		end
		daoc.chat.msg(daoc.chat.message_mode.help, ('Send Item %s'):fmt(recipeList[selCraft][realmId][crafter.currTier][crafter.currCraft].name));
		if crafter.isCrafting[1] then
			--get the craft name
			local craftname = recipeList[selCraft][realmId][crafter.currTier][crafter.currCraft].name;
			--Get base material in first index, rest of name in second index
			local basemat = craftname:psplit(' ', 1, false);
			local category = craftname:replace(basemat[1]..' ', '', 1);
			--get the id
			local craftId = get_craftid(craftStrings[selCraft], basemat[1], category);
			--daoc.chat.msg(daoc.chat.message_mode.help, ('craftId: %d'):fmt(craftId));
			local sendPkt = struct.pack('>H', craftId):totable();
			sendCraft(sendPkt);
		end
	else
		daoc.chat.msg(daoc.chat.message_mode.help, ('Could not find item'));
	end
end

function sendCraft(packet)
	--daoc.chat.msg(daoc.chat.message_mode.help, ('sendcraft %s'):fmt(packet:join()));
	daoc.game.send_packet(0xED, packet, 0);
end

function sellDistCheck() 
	--get player entity
	local playerEnt = daoc.entity.get(daoc.entity.get_player_index());
	if playerEnt == nil then
		return;
	end
	
	if (crafter.movetargetvendor[1]) then
		targetByName(crafter.vendorTargNameBuf[1]);
		--get target
		local target = daoc.entity.get(daoc.entity.get_target_index());
		if target == nil then
			return false;
		end
		
		local dist = math.distance2d(playerEnt.x, playerEnt.y, target.x, target.y);
		if (dist > crafter.stopDist) then
			crafter.dest_x = target.loc_x;
			crafter.dest_y = target.loc_y;
			daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, '/movetarget');
			crafter.ismoving = true;
			return false;
		else
			return true;
		end
	else 
		crafter.dest_x = crafter.vendor_xLocBuf[1];
		crafter.dest_y = crafter.vendor_yLocBuf[1];
		local dist = math.distance2d(playerEnt.loc_x, playerEnt.loc_y, crafter.dest_x, crafter.dest_y);
		if (dist > crafter.stopDist) then
			crafter.ismoving = true;
			daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, ('/movexy %d %d'):fmt(crafter.dest_x, crafter.dest_y));
			return false;
		else
			return true;
		end
	end
	return true;
end

function craftDistCheck() 
	--get player entity
	local playerEnt = daoc.entity.get(daoc.entity.get_player_index());
	if playerEnt == nil then
		return;
	end
	
	if (crafter.isCrafting[1] and crafter.movetargetcraft[1]) then
		targetByName(crafter.craftTargNameBuf[1]);
		--get target
		local target = daoc.entity.get(daoc.entity.get_target_index());
		if target == nil then
			return false;
		end
		
		local dist = math.distance2d(playerEnt.x, playerEnt.y, target.x, target.y);
		if (dist > crafter.stopDist) then
			crafter.ismoving = true;
			crafter.dest_x = target.loc_x;
			crafter.dest_y = target.loc_y;
			--daoc.chat.msg(daoc.chat.message_mode.help, ('%d %d'):fmt(target.x, target.y));
			daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, '/movetarget');
			return false;
		else
			return true;
		end
	elseif crafter.isCrafting[1] then
		crafter.dest_x = crafter.craft_xLocBuf[1];
		crafter.dest_y = crafter.craft_yLocBuf[1];
		local dist = math.distance2d(playerEnt.loc_x, playerEnt.loc_y, crafter.dest_x, crafter.dest_y);
		if (dist > crafter.stopDist) then
			crafter.ismoving = true;
			daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, ('/movexy %d %d'):fmt(crafter.dest_x, crafter.dest_y));
			return false;
		else
			return true;
		end
	end
	return true;
end

function checkMats()
	--Make sure we are at vendor
	if (crafter.isCrafting[1] and crafter.movementToggle[1]) then
		if (not sellDistCheck()) then
			crafter.buyingMats = true;
			daoc.chat.msg(daoc.chat.message_mode.help, ('Too far from vendor to buy mats'));
			return;
		else
			targetByName(crafter.vendorTargNameBuf[1])
			--get target entity
			local target = daoc.entity.get(daoc.entity.get_target_index());
			if target == nil then
				return;
			end
			coroutine.sleep(0.5);
			daoc.chat.msg(daoc.chat.message_mode.help, ('Interact %s - %d'):fmt(target.name, target.object_id));
			daoc.items.interact(target.object_id);
			coroutine.sleep(0.5);
		end
	end


	--What materials do we need?
	crafter.currTier, crafter.currCraft = get_current_craft();
	--local mats = recipeList[selCraft][crafter.server_id[1]][crafter.realm_id[1]][tier][currentCraft].mats;
	--daoc.chat.msg(daoc.chat.message_mode.help, ('mats needed %s'):fmt(mats:tostring()));
	--For each item in mats table, buy 40x of the material
	local serverId = crafter.server_id[1] + 1;
	local realmId = crafter.realm_id[1] + 1;
	local selCraft = crafter.selectedCraft[1] + 1;
	daoc.chat.msg(daoc.chat.message_mode.help, ('%d, %d, %d, %d, %d'):fmt(selCraft, serverId, realmId, crafter.currTier, crafter.currCraft));
	--daoc.chat.msg(daoc.chat.message_mode.help, ('name: %s'):fmt(recipeList[selCraft][serverId][realmId][tier][currentCraft]));
	--Sell before we buy
	if crafter.isCrafting[1] then
		sellBySlots(crafter.minSlotBuf[1], crafter.maxSlotBuf[1]);
		if crafter.currTier == nil or crafter.currCraft == nil then
			daoc.chat.msg(daoc.chat.message_mode.help, ('Tried to buy mats, but craft was nil'));
			crafter.isCrafting[1] = false;
		end
		--get the craft name
		local craftname = recipeList[selCraft][realmId][crafter.currTier][crafter.currCraft].name;
        --Get base material in first index, rest of name in second index
        local basemat = craftname:psplit(' ', 1, false);
        local category = craftname:replace(basemat[1]..' ', '', 1);
        --lookup the materials
		local matList = get_materials(craftStrings[selCraft], basemat[1], category);
		if matList == nil then
			daoc.chat.msg(daoc.chat.message_mode.help, ('Failed matlist for %s, %s, %s'):fmt(craftStrings[selCraft], basemat[1], category));
			return;
		end
		for i=1, matList:len() do
			local matname = matList[i].base_material_name .. ' ' .. matList[i].name;
			--if the matname ends in an s, remove it
			if matname:endswith('s') then
				--daoc.chat.msg(daoc.chat.message_mode.help, ('remove s'));
				matname = matname:sub(1, -2);
			end
			--trim whitespace
			matname = matname:clean();
			local matval = matList[i].count;
			--daoc.chat.msg(daoc.chat.message_mode.help, ('buy %s %s'):fmt(matval, matname));
			local numMats = 30
			if crafter.numMatsBuf[1]:len() > 0 then
				numMats = tonumber(crafter.numMatsBuf[1]);
			end
			local matCount = matval * numMats;
			while matCount >= 100 do
				if (buyMats(matname, 100)) then
					matCount = matCount - 100;
				else
					return;
				end
			end
			if matCount > 0 and matCount < 100 then
				if not buyMats(matname, matCount) then
					return;
				end
			end
			coroutine.sleep(1);
		end

		crafter.buyingMats = false;
		if crafter.movementToggle[1] then
			coroutine.sleep(math.random(5, 10));
		end

		doCraft();
	end

end

function buyMats(matName, count)
	local slotNum = 0;
	if matName:len() > 0 then
		slotNum = daoc.items.get_merchant_slot(matName);
	end

	if slotNum ~= nil then
		--daoc.chat.msg(daoc.chat.message_mode.help, ('buy %d %s from slot %d'):fmt(count, itemName, slotNum));
		buyItem(slotNum, count)
		return true;
	else
		daoc.chat.msg(daoc.chat.message_mode.help, ('No %s in merchant list'):fmt(matName));
		return false;
	end
	return false;
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
	return true;
end

function trainDistCheck() 
	--get player entity
	local playerEnt = daoc.entity.get(daoc.entity.get_player_index());
	if playerEnt == nil then
		return;
	end
	
	if (crafter.movetargettrain[1]) then
		targetByName(crafter.trainTargNameBuf[1]);
		--get target
		local target = daoc.entity.get(daoc.entity.get_target_index());
		if target == nil then
			return false;
		end
		
		local dist = math.distance2d(playerEnt.x, playerEnt.y, target.x, target.y);
		if (dist > crafter.stopDist) then
			crafter.dest_x = target.loc_x;
			crafter.dest_y = target.loc_y;
			daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, '/movetarget');
			crafter.ismoving = true;
			return false;
		else
			return true;
		end
	else 
		crafter.dest_x = crafter.train_xLocBuf[1];
		crafter.dest_y = crafter.train_yLocBuf[1];
		local dist = math.distance2d(playerEnt.loc_x, playerEnt.loc_y, crafter.dest_x, crafter.dest_y);
		if (dist > crafter.stopDist) then
			crafter.ismoving = true;
			daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, ('/movexy %d %d'):fmt(crafter.dest_x, crafter.dest_y));
			return false;
		else
			return true;
		end
	end
end

function visitTrainer()
	daoc.chat.msg(daoc.chat.message_mode.help, ('Visit trainer'));
	--Make sure we are at vendor
	if (crafter.movementToggle[1]) then
		if (not trainDistCheck()) then
			daoc.chat.msg(daoc.chat.message_mode.help, ('Too far from trainer to train'));
			return;
		else
			targetByName(crafter.trainTargNameBuf[1])
			--get target entity
			local target = daoc.entity.get(daoc.entity.get_target_index());
			if target == nil then
				return;
			end
			coroutine.sleep(0.5);
			daoc.chat.msg(daoc.chat.message_mode.help, ('Interact %s - %d'):fmt(target.name, target.object_id));
			daoc.items.interact(target.object_id);
			crafter.isTraining = false;
			crafter.isCrafting[1] = true;
			doCraft();
		end
	end
end

function targetByName(targName)
	for i = 1, daoc.entity.get_count() do
		if (daoc.entity.is_valid(i)) then
			local ent = daoc.entity.get(i);
			if (ent ~= nil and i ~= daoc.entity.get_player_index()) then
				if (ent.name:lower():ieq(targName)) then
					daoc.entity.set_target(i, 1);
				end
			end
		end
	end
end

function get_craftid(craftName, baseMat, category)
    local craftid = 0;

	--live spellcrafting put basemat into name: field with a +x modifier based on status granted.
	if crafter.server_id[1] == 0 and craftName:contains('Spellcraft') then
		--daoc.chat.msg(daoc.chat.message_mode.help, ('live'));
		masterRecipe:each(function (v, k)
			v:each(function (_, kk)
				--daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(kk));
				if (_['profession'] == craftName) then
					--daoc.chat.msg(daoc.chat.message_mode.help, ('base: %s %s, cat: %s %s'):fmt(_['name'], baseMat, _['category'], category));
					if (_['name']:lower():contains(baseMat:lower()) and _['category']:lower():contains(category:lower())) then
						--daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(_['category']));
						craftid = _['id'];
					end
				end
			end);
		end);	
	--alchemy doesn't use base material/category only name
	elseif craftName:contains('Alchemy') then
		local name = baseMat .. ' ' .. category;
		masterRecipe:each(function (v, k)
			--daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(k));
			v:each(function (_, kk)
				if (_['profession']:lower():contains(craftName:lower())) then
					--daoc.chat.msg(daoc.chat.message_mode.help, ('%s %s'):fmt(_['category'], category));
					if (_['name']:ieq(name)) then
						
						craftid = _['id'];
					end
				end
			end);
		end);		
	--eden uses base_material_name + category
	--elseif crafter.server_id[1] == 1 then
	else
		masterRecipe:each(function (v, k)
			--daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(k));
			v:each(function (_, kk)
				if (_['profession']:lower():contains(craftName:lower())) then
					--daoc.chat.msg(daoc.chat.message_mode.help, ('incoming: %s %s | list: %s %s'):fmt(baseMat, category, _['base_material_name'], _['category']:lower()));
					if (_['base_material_name']:ieq(baseMat) and _['category']:lower():contains(category:lower())) then
						--daoc.chat.msg(daoc.chat.message_mode.help, ('%s %s'):fmt(_['category'], category));
						craftid = _['id'];
					end
				end
			end);
		end);
	end

    return craftid;
end

function get_materials(craftName, baseMat, category)
    local matTable;
	daoc.chat.msg(daoc.chat.message_mode.help, ('%d, %s, %s, %s'):fmt(crafter.server_id[1], craftName, baseMat, category));
	
	--live spellcrafting put basemat into name: field with a +x modifier based on status granted.
	if crafter.server_id[1] == 0 and craftName:contains('Spellcraft') then
		--daoc.chat.msg(daoc.chat.message_mode.help, ('live'));
		masterRecipe:each(function (v, k)
			v:each(function (_, kk)
				--daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(kk));
				if (_['profession'] == craftName) then
					--daoc.chat.msg(daoc.chat.message_mode.help, ('base: %s %s, cat: %s %s'):fmt(_['name'], baseMat, _['category'], category));
					if (_['name']:lower():contains(baseMat:lower()) and _['category']:lower():contains(category:lower())) then
						--daoc.chat.msg(daoc.chat.message_mode.help, ('base: %s %s, cat: %s %s'):fmt(_['name'], baseMat, _['category'], category));
						matTable = _['materials'];
					end
				end
			end);
		end);	
	--alchemy doesn't use base material
	elseif craftName:contains('Alchemy') then
		local name = baseMat .. ' ' .. category;
		masterRecipe:each(function (v, k)
			--daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(k));
			v:each(function (_, kk)
				if (_['profession']:lower():contains(craftName:lower())) then
					--daoc.chat.msg(daoc.chat.message_mode.help, ('%s %s'):fmt(_['name'], name));
					if (_['name']:ieq(name)) then
						matTable = _['materials'];
					end
				end
			end);
		end);		
	--eden/other crafts uses base_material_name + category
	--elseif crafter.server_id[1] == 1 then
	else
		masterRecipe:each(function (v, k)
			--daoc.chat.msg(daoc.chat.message_mode.help, ('%s'):fmt(k));
			v:each(function (_, kk)
				if (_['profession']:lower():contains(craftName:lower())) then
					--daoc.chat.msg(daoc.chat.message_mode.help, ('incoming: %s %s | list: %s %s'):fmt(baseMat, category, _['base_material_name'], _['category']:lower()));
					if (_['base_material_name']:ieq(baseMat) and _['category']:lower():contains(category:lower())) then
						--daoc.chat.msg(daoc.chat.message_mode.help, ('%s %s'):fmt(_['category'], category));
						matTable = _['materials'];
					end
				end
			end);
		end);
	end

    return matTable;
end

function load_recipes()
	local filename;
	--live
	if crafter.server_id[1] == 0 then
		filename = 'liverecipes.json';
	elseif crafter.server_id[1] == 1 then
		filename = 'edenrecipes.json';
	else
		error('Bad server id when loading recipes');
	end
	--load in the recipe list
	local f = io.open(addon.path .. '/data/' .. filename, 'rb');
	if (f == nil) then
		error('Failed to load spell list file. (/data/' .. filename .. ')');
	end

	-- Read the full file contents..
	local c = f:read("*all");
	f:close();

	-- Parse the spell json data..
	masterRecipe = T(json.decode(c) or {});
end

function load_paths()
	--Recipe leveling lists based on server
	local servername;
	if crafter.server_id[1] == 0 then
		servername = 'live';
	elseif crafter.server_id[1] == 1 then
		servername = 'eden';
	end

	local path = addon.path .. '/profiles/' .. servername .. '/';
	local tailorRecipe = dofile(path .. 'tailoring.lua');
	local fletchRecipe = dofile(path .. 'fletching.lua');
	local spellRecipe = dofile(path .. 'spellcraft.lua');
	local metalRecipe = dofile(path .. 'metalworking.lua');
	local weaponRecipe = dofile(path .. 'weaponcrafting.lua');
	local alchRecipe = dofile(path .. 'alchemy.lua');

	--local tailorRecipe = require('tailoring');
	--local armorRecipe = require('armorcrafting');
	--local fletchRecipe = require('fletching');
	--local spellRecipe = require('spellcraft');

	--Append to the recipe list - index correlates to combobox, crafter.selectedCraft[1] + 1
	recipeList:append(weaponRecipe);
	recipeList:append(T{'Armorcraft'});
	recipeList:append(T{'Siegecraft'});
	recipeList:append(alchRecipe);
	recipeList:append(metalRecipe);
	recipeList:append(T{'Leatherworking'});
	recipeList:append(T{'Clothworking'});
	recipeList:append(T{'Gemcutting'});
	recipeList:append(T{'Herbcraft'});
	recipeList:append(tailorRecipe);
	recipeList:append(fletchRecipe);
	recipeList:append(spellRecipe)
	recipeList:append(T{'Woodworking'});
	recipeList:append(T{'Bountycrafting'});
	recipeList:append(T{'Basic Crafting'});
end