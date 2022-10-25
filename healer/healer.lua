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

addon.name    = 'healer';
addon.author  = 'towbes';
addon.desc    = 'Autoheal addon';
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
                    daoc.chat.msg(daoc.chat.message_mode.help, ('cat: %d, lvl: %d name: %s'):fmt(x, spell.spellLevel, spellname));
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

    --Skill table pointer
    --Address of signature = game.dll + 0x0001EEC8 + 0x1
    --local ptr = hook.pointers.add('daoc.data.loadedskills', 'game.dll', 'BA????????803A', 1,0);
    --if (ptr == 0) then
    --    error('Failed to locate skill table pointer.');
    --end

    --Address of signature = game.dll + 0x0001EF56
    local ptr = hook.pointers.add('daoc.data.loadedskills', 'game.dll', 'BF????????F3??891D', 1,0);
    if (ptr == 0) then
        error('Failed to locate skill table pointer.');
    end

end);



-- healer Variables
local default_settings = T{
    is_checked = T{ false, },
    heal1nameBuf = { '' },
    heal1nameSize = 50,
    heal2nameBuf = { '' },
    heal2nameSize = 50,
    heal3nameBuf = { '' },
    heal3nameSize = 50,
    grpHealnameBuf = { '' },
    grpHealnameSize = 50,
    petHealNameBuf = { '' },
    petHealSize = 50,
    pet_toggle = T{ false, },
    healRange = 2000,
};

local healer = settings.load(default_settings);

--pause time to buy mats and interact with vendor
local tick_holder = hook.time.tick();
local tick_interval = 100;

--[[
* Event invoked when a settings table has been changed within the settings library.
*
* Note: This callback only affects the default 'settings' table.
--]]
settings.register('settings', 'settings_update', function (e)
    -- Update the local copy of the 'settings' settings table..
    healer = e;

    -- Ensure settings are saved to disk when changed..
    settings.save();
end);


--[[
* event: load
* desc : Called when the addon is being loaded.
--]]
hook.events.register('unload', 'unload_cb', function ()

    healer.is_checked[1] = false;
    settings.save();

end);

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


    local party = daoc.party.get_members();
    if party == nil then
        error('Failed to get party.');
    end


    --entity unknown43[1] is casting countdown


    if (hook.time.tick() >= (tick_holder + tick_interval) ) then	
        tick_holder = hook.time.tick();
        
        if (healer.is_checked[1]) then
            local pidx, php = lowest_party_hp();
            local member = party[pidx];
            if (member.name:len() > 0 and php > 0) then
                if (member.health < 40) then
                    targetByName(member.name);
                    local idx = daoc.data.get_skill(healer.heal3nameBuf[1])
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));
                    if (player.unknown43[0] == 0) then
                        daoc.game.use_skill(idx, 1);
                    end
                elseif (member.health < 65) then
                    targetByName(member.name);
                    local idx = daoc.data.get_skill(healer.heal2nameBuf[1])
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));
                    if (player.unknown43[0] == 0) then
                        daoc.game.use_skill(idx, 1);
                    end
                elseif (member.health < 90) then
                    targetByName(member.name);
                    local idx = daoc.data.get_skill(healer.heal1nameBuf[1])
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));    
                    if (player.unknown43[0] == 0) then
                        daoc.game.use_skill(idx, 1);
                    end
                end
            end
            if healer.pet_toggle[1] then
                if healer.petHealNameBuf[1]:len() > 0 then
                    --get target entity
                    local petent = entityByName(healer.petHealNameBuf[1]);
                    if petent == nil then
                        return;
                    end
                    if (petent.health < 40) then
                        targetByName(petent.name);
                        local idx = daoc.data.get_skill(healer.heal3nameBuf[1])
                        --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));
                        if (player.unknown43[0] == 0) then
                            daoc.game.use_skill(idx, 1);
                        end
                    elseif (petent.health < 65) then
                        targetByName(petent.name);
                        local idx = daoc.data.get_skill(healer.heal2nameBuf[1])
                        --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));
                        if (player.unknown43[0] == 0) then
                            daoc.game.use_skill(idx, 1);
                        end
                    elseif (petent.health < 90) then
                        targetByName(petent.name);
                        local idx = daoc.data.get_skill(healer.heal1nameBuf[1])
                        --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));    
                        if (player.unknown43[0] == 0) then
                            daoc.game.use_skill(idx, 1);
                        end
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
    -- Render a custom example healer via ImGui..
    imgui.SetNextWindowSize(T{ 350, 200, }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('Healer')) then
        imgui.Text('Auto heal party addon');
        imgui.Checkbox('Heal Toggle', healer.is_checked);
        imgui.SameLine();
        imgui.Checkbox('Pet Heal Toggle', healer.pet_toggle);


        
        if (healer.is_checked[1]) then
            imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Running!');
        else
            imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Off');
        end
        imgui.Text("Small Heal:")
        imgui.SameLine();
        imgui.PushItemWidth(200);
        imgui.InputText("##heal1name", healer.heal1nameBuf, healer.heal1nameSize);
        imgui.Text("Big Heal:")
        imgui.SameLine();
        imgui.PushItemWidth(200);
        imgui.InputText("##heal2name", healer.heal2nameBuf, healer.heal2nameSize);
        imgui.Text("Emerg Heal:")
        imgui.SameLine();
        imgui.PushItemWidth(200);
        imgui.InputText("##heal3name", healer.heal3nameBuf, healer.heal3nameSize);
        if healer.pet_toggle[1] then
            imgui.Text("Pet name:")
            imgui.SameLine();
            imgui.PushItemWidth(200);
            imgui.InputText("##petname", healer.petHealNameBuf, healer.petHealSize);
        end
        if (imgui.Button('Spell')) then
            if (healer.spellNameBuf[1]:len() > 0) then
                local cat, lvl = daoc.data.get_spell(healer.spellNameBuf[1])
                if (cat ~= nil and lvl ~= nil) then
                    daoc.chat.msg(daoc.chat.message_mode.help, ('cat: %d, lvl %d'):fmt(cat,lvl));    
                    daoc.game.use_spell(cat, lvl);
                end
                
            end
        end
        imgui.SameLine();
        if (imgui.Button('Skill')) then
            if (healer.spellNameBuf[1]:len() > 0) then
                local idx = daoc.data.get_skill(healer.spellNameBuf[1])
                if (idx ~= nil) then
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('idx: %d'):fmt(idx));
                    daoc.game.use_skill( idx, 1 );
                end
            end
        end
        imgui.SameLine();
        if (imgui.Button('Save', { 55, 20 })) then
            settings.save();
            daoc.chat.msg(daoc.chat.message_mode.help, ('Settings saved'));
        end

        local party = daoc.party.get_members();
        if party == nil then
            error('Failed to get party.');
        end
    
        for x = 0, 7 do
            local member = party[x];
            imgui.Text(('Group %d: %s - %d - %d %d'):fmt(x, member.name, member.health, member.x, member.y))
        end 

        local player = daoc.entity.get(daoc.entity.get_player_index());
        if player == nil then
            error('Failed to get player entity.');
            return;
        end
        imgui.Text(('castCountdown: %d'):fmt(player.unknown43[0]))
    end
    imgui.End();
end);

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

function entityByName(entName)
	for i = 1, daoc.entity.get_count() do
		if (daoc.entity.is_valid(i)) then
			local ent = daoc.entity.get(i);
			if (ent ~= nil and i ~= daoc.entity.get_player_index()) then
				if (ent.name:lower():ieq(entName)) then
					return daoc.entity.get(i);
				end
			end
		end
	end
    return nil;
end

function lowest_party_hp()
    local lowhp = 100;
    local curIdx = 0;

    local player = daoc.entity.get(daoc.entity.get_player_index());
    if player == nil then
        error('Failed to get player entity.');
		return;
    end


    local party = daoc.party.get_members();
    if party == nil then
        return curIdx, lowhp;
    end
    for x = 0, 7 do
        local member = party[x];
        --daoc.chat.msg(daoc.chat.message_mode.help, ('member %s'):fmt(member.name));    
        if member.name:len() > 0 then
            local dist = math.distance2d(player.loc_x, player.loc_y, member.x, member.y);
            if (dist < healer.healRange and member.health > 0 and member.health < lowhp) then
                curIdx = x;
                lowhp = member.health;
            end
        end
    end
    return curIdx, lowhp;
end