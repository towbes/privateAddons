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

addon.name    = 'slash';
addon.author  = 'towbes';
addon.desc    = 'Slash commands for styles/spells';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';

local imgui = require 'imgui';
local ffi = require 'ffi';
local settings  = require 'settings';

--[[
* Data Related Structure Definitions
--]]
ffi.cdef[[
    //useSpell_t plyrUseSpellTable[150];
    typedef struct {
        char name_[64];
        short spellLevel;
        short unknown1;
        int tickCount;
        int unknown2;
        int unknown3;
        int unknown4;
        int unknown5;
        int unknown6;
    } loaded_spell_t;

    //array start address is 0x161d9f0
    //6968 bytes total = 0x1B38
    typedef struct  {
        char categoryName[64];
        loaded_spell_t spellArray[75];
        int alignBuf;
    } spellCategory_t;

    typedef struct  {
        spellCategory_t categories[15];
    } spell_cat_list_t;

    ////Skills
    //useSkill_t plyrUseSkillTable[150];
    typedef struct  {
        unsigned char name_[64];
        int unknown1;
        int unknown2;
        int tickCount;
    } skill_t;

    typedef struct  {
        skill_t skills[150];
    } skill_list_t;
]];


--[[
* Spell Related Helper Metatype Definitions
--]]

ffi.metatype('loaded_spell_t', T{
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
* Spell Related Helper Metatype Definitions
--]]

ffi.metatype('spellCategory_t', T{
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
* Spell Related Helper Metatype Definitions
--]]

ffi.metatype('skill_t', T{
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
* Returns list of spell categories
--]]
daoc.data.get_spell_categories = function ()

    local ptr = hook.pointers.get('daoc.data.loadedspells');
    if (ptr == 0) then return nil; end
	ptr = hook.memory.read_uint32(ptr);
    if (ptr == 0) then return nil; end

    return ffi.cast('spell_cat_list_t*', ptr);
end

--[[
* Returns category , spell level of a spell
--]]
daoc.data.get_spell = function (spellName)
    if (spellName == nil) then
        return nil, nil;
    end

    local spellCats = daoc.data.get_spell_categories();
    if spellCats == nil then return; end

    spellName = spellName:lower();
    for cat=0, 15 do
        for x = 0, 75 do
            local spell = spellCats.categories[cat].spellArray[x]
            local spellname = ffi.string(spell.name);
            if (spellname ~= nil and spellname:len() > 0) then
                
                if (spellname:lower():ieq(spellName)) then
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('cat: %d, lvl: %d name: %s'):fmt(cat, spell.spellLevel, spellname));
                    return cat, spell.spellLevel;
                end
            end
        end
    end

    return nil, nil;
end

--[[
* Returns list of skills
--]]
daoc.data.get_skill_list= function ()

    local ptr = hook.pointers.get('daoc.data.loadedskills');
    if (ptr == 0) then return nil; end
	ptr = hook.memory.read_uint32(ptr);
    if (ptr == 0) then return nil; end

    return ffi.cast('skill_list_t*', ptr);
end

--[[
* Returns index of skill
--]]
daoc.data.get_skill = function (skillName)
    if (skillName == nil) then
        return nil;
    end

    local skillList = daoc.data.get_skill_list();
    if skillList == nil then
        return nil;
    end

    skillName = skillName:lower();
    for x = 0, 150 do
        local skill = skillList.skills[x];
        local skillname = skill.name;
        if (skillname ~= nil and skillname:len() > 0) then
            --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d name: %s'):fmt(x, skillname));
            if (skillname:ieq(skillName)) then
                --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d name: %s'):fmt(x, skillname));
                return x;
            end
        end
    end

    return nil;
end

-- healer Variables
local default_settings = T{
    is_checked = T{ false, },
    nameBuf = { '' },
    nameSize = 50,
    rangeBuf = { '350' },
    rangeSize = 5,
    heal1Buf = { '' },
    heal1Size = 50,
    buff1Buf = { '' },
    buff1Size = 50,
    buff2Buf = { '' },
    buff2Size = 50,
    buff3Buf = { '' },
    buff3Size = 50,
    buff4Buf = { '' },
    buff4Size = 50,
    buff5Buf = { '' },
    buff5Size = 50,
    buff6Buf = { '' },
    buff6Size = 50,
    buff7Buf = { '' },
    buff7Size = 50,
    buff8Buf = { '' },
    buff8Size = 50,
    buff9Buf = { '' },
    buff9Size = 50,
    buff10Buf = { '' },
    buff10Size = 50,
    currDist = 1000,
    doneBuffing = false,
};

local assist = settings.load(default_settings);

--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('load', 'load_cb', function ()
    --Spell table pointer
    --Address of signature = game.dll + 0x0001F67C  +0x1
    local ptr = hook.pointers.add('daoc.data.loadedspells', 'game.dll', '3D????????7C??EB??C645FC', 1,0);
    if (ptr == 0) then
        error('Failed to locate spell table pointer.');
    end

    --Address of signature = game.dll + 0x0001EF56
    local ptr = hook.pointers.add('daoc.data.loadedskills', 'game.dll', 'BF????????F3??891D', 1,0);
    if (ptr == 0) then
        error('Failed to locate skill table pointer.');
    end

    assist.doneBuffing = false;

end);

--[[
* Event invoked when a settings table has been changed within the settings library.
*
* Note: This callback only affects the default 'settings' table.
--]]
settings.register('settings', 'settings_update', function (e)
    -- Update the local copy of the 'settings' settings table..
    assist = e;

    -- Ensure settings are saved to disk when changed..
    settings.save();
end);


--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('unload', 'unload_cb', function ()

    assist.is_checked[1] = false;
    settings.save();

end);


--pause time to buy mats and interact with vendor
local tick_holder = hook.time.tick();
local tick_interval = 1200;
local buff_holder = hook.time.tick();
local buff_interval = 5000;

local currTarget = 0;

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_heal', function ()
    -- Render a custom example healer via ImGui..
    --get player object for realm id
    local player = daoc.entity.get(daoc.entity.get_player_index());
    if player == nil then
        error('Failed to get player entity.');
		return;
    end



    if (hook.time.tick() >= (tick_holder + tick_interval) ) then	
        tick_holder = hook.time.tick();
        if (assist.is_checked[1]) then

            
            

            -- Obtain the players current target entity..
            local target = daoc.entity.get(daoc.entity.get_target_index());
            if (target == nil or target.initialized_flag == 0) then
                targetByName(assist.nameBuf[1])
                assist.currDist = 1000;
                return;
            end

            --only heal if we are targetting the assist
            if (target.object_type == daoc.entity.type.player) then
                if (hook.time.tick() >= (buff_holder + buff_interval) ) then
                    buff_holder = hook.time.tick();
                    checkBuffs();
                end
                if not assist.doneBuffing then
                    return
                end
                if player.health < 100 then
                    --first target ourself
                    daoc.entity.set_target(daoc.entity.get_player_index(), 1);
                    if (assist.heal1Buf[1]:len() > 0) then
                        local idx = daoc.data.get_skill(assist.heal1Buf[1])
                        if (idx ~= nil) then
                            --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
                            daoc.game.use_skill( idx, 1 );
                        end
                    end
                    return
                end
            end

            --Look for enemies around us
            for i = 1, daoc.entity.get_count() do
                if (daoc.entity.is_valid(i) and i ~= daoc.entity.get_player_index()) then
                    local ent = daoc.entity.get(i);
                    if (ent ~= nil  and ent.name ~= 'horse' and ent.health > 0 and ent.object_type == daoc.entity.type.npc and ent.realm_id ~= player.realm_id) then
                        dist = math.distance2d(ent.x, ent.y, player.x, player.y)
                        if dist < tonumber(assist.rangeBuf[1]) and dist < assist.currDist and i ~= daoc.entity.get_player_index() then
                            assist.currDist = dist;
                            currTarget = i;
                            daoc.entity.set_target(i, 1);
                        end
                    end
                    ::continue::
                end
            end
            
            daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, '/stick');
            if target.object_type == daoc.entity.type.npc then
                local idx = daoc.data.get_skill('Excommunicate')
                if (idx ~= nil) then
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
                    daoc.game.use_skill( idx, 1 );
                end
                idx = nil;
                idx = daoc.data.get_skill('Holy Staff')
                if (idx ~= nil) then
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
                    daoc.game.use_skill( idx, 1 );
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
    -- Render a custom example healer via ImGui..
    imgui.SetNextWindowSize(T{ 350, 200, }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('Assister')) then
        imgui.Text('Auto assist');
        imgui.Checkbox('Assist Toggle', assist.is_checked);
        imgui.Text(('DoneBuffing: %s'):fmt(assist.doneBuffing))

        if (assist.is_checked[1]) then
            imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, ('Running!'):fmt(pavghp));
        else
            imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Off');
        end
        if (imgui.BeginTable('##assist', 2, bit.bor(ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersH, ImGuiTableFlags_BordersV, ImGuiTableFlags_ContextMenuInBody, ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedSame))) then
            imgui.TableSetupColumn('Type', ImGuiTableColumnFlags_WidthFixed, 100.0, 0);
            imgui.TableSetupColumn('Name', ImGuiTableColumnFlags_WidthStretch, 0, 0);
            imgui.TableHeadersRow();
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Assist Name")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##assistName", assist.nameBuf, assist.nameSize);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Assist Dist")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##assistDist", assist.rangeBuf, assist.rangeSize);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Assist Dist")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##heal1", assist.heal1Buf, assist.heal1Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff One")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff1", assist.buff1Buf, assist.buff1Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff Two")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff2", assist.buff2Buf, assist.buff2Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff Three")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff3", assist.buff3Buf, assist.buff3Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff Four")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff4", assist.buff4Buf, assist.buff4Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff Five")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff5", assist.buff5Buf, assist.buff5Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff Six")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff6", assist.buff6Buf, assist.buff6Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff Seven")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff7", assist.buff7Buf, assist.buff7Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff Eight")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff8", assist.buff8Buf, assist.buff8Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff Nine")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff9", assist.buff9Buf, assist.buff9Size);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);;
            imgui.Text("Buff Ten")
            --imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##buff10", assist.buff10Buf, assist.buff10Size);
            imgui.EndTable();
        end
        if (imgui.Button('Save', { 55, 20 })) then
            settings.save();
            daoc.chat.msg(daoc.chat.message_mode.help, ('Settings saved'));
        end

    end
    imgui.End();
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
    if ((args[1]:ieq('skill') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/skill')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
		if (args[2]:len() > 0) then
			local idx = daoc.data.get_skill(args[2])
			if (idx ~= nil) then
				--daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
				daoc.game.use_skill( idx, 1 );
			end
		end
        return;
    end

    if ((args[1]:ieq('toggle') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/toggle')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        if (assist.is_checked[1]) then
            --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
            daoc.chat.msg(daoc.chat.message_mode.help, ('Toggle off'));
            assist.is_checked[1] = false;
        else
            daoc.chat.msg(daoc.chat.message_mode.help, ('Toggle on'));
            assist.is_checked[1] = true
        end
        return;
    end

    -- Command: /inv
    if ((args[1]:ieq('exochain') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/exochain')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, '/stick');
        local idx = daoc.data.get_skill('Excommunicate')
        if (idx ~= nil) then
            --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
            daoc.game.use_skill( idx, 1 );
        end
        idx = nil;
        idx = daoc.data.get_skill('Holy Staff')
        if (idx ~= nil) then
            --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
            daoc.game.use_skill( idx, 1 );
        end
       

        return;
    end
    if ((args[1]:ieq('slow') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/slow')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, '/stick');
        local idx = daoc.data.get_skill('Defender\'s Fury')
        if (idx ~= nil) then
            --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
            daoc.game.use_skill( idx, 1 );
        end
       
        return;
    end
    if ((args[1]:ieq('snare') and e.imode == daoc.chat.input_mode.slash) or args[1]:ieq('/snare')) then
        -- Mark the command as handled, preventing the game from ever seeing it..
        e.blocked = true;
        daoc.chat.exec(daoc.chat.command_mode.typed, daoc.chat.input_mode.normal, '/stick');
        local idx = daoc.data.get_skill('Friar\'s Friend')
        if (idx ~= nil) then
            --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
            daoc.game.use_skill( idx, 1 );
        end
       
        return;
    end
end);

function checkBuffs()
    --get player object forcasting time
    local mybuffs = T { };
    local confbuffs = T { };

    local player = daoc.entity.get(daoc.entity.get_player_index());
    if player == nil then
        error('Failed to get player entity.');
		return;
    end

    assist.doneBuffing = false;

    local mybuffs = daoc.buffs.get_buffs();
    
    --Get buffs from UI
    confbuffs:append(assist.buff1Buf[1]);
    confbuffs:append(assist.buff2Buf[1]);
    confbuffs:append(assist.buff3Buf[1]);
    confbuffs:append(assist.buff4Buf[1]);
    confbuffs:append(assist.buff5Buf[1]);
    confbuffs:append(assist.buff6Buf[1]);
    confbuffs:append(assist.buff7Buf[1]);
    confbuffs:append(assist.buff8Buf[1]);
    confbuffs:append(assist.buff9Buf[1]);
    confbuffs:append(assist.buff10Buf[1]);
    local bcheck = false;
    for i=1, confbuffs:len() do
        --check if we have the buff
        bcheck = false;
        for n=0, 74 do
            if mybuffs[n].name:len() > 0 and mybuffs[n].name:ieq(confbuffs[i]) then
                bcheck = true;
            end
        end
        --if we didn't find the buff, cast it
        if bcheck == false then
            local idx = daoc.data.get_skill(confbuffs[i]);
            if idx ~= nil and player.unknown43[0] == 0 then
                daoc.game.use_skill(idx, 1);
            end
        end
    end
    --if bcheck true after going through all the buffs we can be done buffing
    if bcheck then
        assist.doneBuffing = true;
    end
end

function targetByName(targName)
	for i = 1, daoc.entity.get_count() do
		if (daoc.entity.is_valid(i)) then
			local ent = daoc.entity.get(i);
			if (ent ~= nil and ent.object_id > 0) then
                --daoc.chat.msg(daoc.chat.message_mode.help, ('idx %d, id %d'):fmt(i, ent.object_id));    
				if (ent.name:lower():ieq(targName)) then
					daoc.entity.set_target(i, 1);
				end
            end
		end
	end
end

function entityByName(entName)
	for i = 1, daoc.entity.get_count() do
		if (daoc.entity.is_valid(i)) then
			local ent = daoc.entity.get(i);
			if (ent ~= nil and ent.object_id > 0) then
                --daoc.chat.msg(daoc.chat.message_mode.help, ('idx %d, id %d'):fmt(i, ent.object_id));    
				if (ent.name:lower():ieq(entName)) then
					return daoc.entity.get(i);
				end
			end
		end
	end
    return nil;
end
