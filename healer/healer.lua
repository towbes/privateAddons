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
    heal1nameBuf = { '' }, --small heal
    heal1nameSize = 50,
    heal1valBuf = { '' },
    heal1valSize = 5,
    heal2nameBuf = { '' }, -- big heal
    heal2nameSize = 50,
    heal2valBuf = { '' },
    heal2valSize = 5,
    heal3nameBuf = { '' }, --emergency heal
    heal3nameSize = 50,
    heal3valBuf = { '' },
    heal3valSize = 5,
    heal4nameBuf = { '' }, -- small group heal
    heal4nameSize = 50,
    heal4valBuf = { '' },
    heal4valSize = 5,
    heal5nameBuf = { '' }, -- big grp heal
    heal5nameSize = 50,
    heal5valBuf = { '' },
    heal5valSize = 5,
    heal6nameBuf = { '' },-- single insta
    heal6nameSize = 50,
    heal6valBuf = { '' },
    heal6valSize = 5,
    heal7nameBuf = { '' }, -- grp insta
    heal7nameSize = 50,
    heal7valBuf = { '' },
    heal7valSize = 5,
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
            local pavghp = party_avg_hp();
            if (pavghp < tonumber(healer.heal7valBuf[1])) then
                local idx = daoc.data.get_skill(healer.heal7nameBuf[1])
                if (idx ~= nil) then
                    daoc.game.use_skill(idx, 1);
                end                
            elseif (pavghp < tonumber(healer.heal5valBuf[1])) then
                --cast regular group heal
                local idx = daoc.data.get_skill(healer.heal5nameBuf[1])
                if (idx ~= nil and player.unknown43[0] == 0) then
                    daoc.game.use_skill(idx, 1);
                end
            elseif (pavghp < tonumber(healer.heal4valBuf[1])) then
                --cast spreadheal
                local idx = daoc.data.get_skill(healer.heal4nameBuf[1])
                if (idx ~= nil and player.unknown43[0] == 0) then
                    daoc.game.use_skill(idx, 1);
                end
            end
            if (member.name:len() > 0 and php > 0 and php < 100) then
                if (member.health < tonumber(healer.heal6valBuf[1])) then
                    daoc.entity.set_target(daoc.entity.get_index_by_id(daoc.party.get_member_object_id(pidx)))
                    local idx = daoc.data.get_skill(healer.heal6nameBuf[1])
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));
                    if (idx ~= nil) then
                        daoc.game.use_skill(idx, 1);
                    end
                elseif (member.health < tonumber(healer.heal3valBuf[1])) then
                    daoc.entity.set_target(daoc.entity.get_index_by_id(daoc.party.get_member_object_id(pidx)))
                    local idx = daoc.data.get_skill(healer.heal3nameBuf[1])
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));
                    if (idx ~= nil and player.unknown43[0] == 0) then
                        daoc.game.use_skill(idx, 1);
                    end
                elseif (member.health < tonumber(healer.heal2valBuf[1])) then
                    daoc.entity.set_target(daoc.entity.get_index_by_id(daoc.party.get_member_object_id(pidx)))
                    local idx = daoc.data.get_skill(healer.heal2nameBuf[1])
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));
                    if (idx ~= nil and player.unknown43[0] == 0) then
                        daoc.game.use_skill(idx, 1);
                    end
                elseif (member.health < tonumber(healer.heal1valBuf[1])) then
                    daoc.entity.set_target(daoc.entity.get_index_by_id(daoc.party.get_member_object_id(pidx)))
                    local idx = daoc.data.get_skill(healer.heal1nameBuf[1])
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));    
                    if (idx ~= nil and player.unknown43[0] == 0) then
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
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('%s idx %d'):fmt(petent.name, petent.object_id));
                    if (petent.health < 40) then
                        daoc.entity.set_target(daoc.entity.get_index_by_id(petent.object_id))
                        local idx = daoc.data.get_skill(healer.heal3nameBuf[1])
                        --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));
                        if (idx ~= nil and player.unknown43[0] == 0) then
                            daoc.game.use_skill(idx, 1);
                        end
                    elseif (petent.health < 65) then
                        daoc.entity.set_target(daoc.entity.get_index_by_id(petent.object_id))
                        local idx = daoc.data.get_skill(healer.heal2nameBuf[1])
                        --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));
                        if (idx ~= nil and player.unknown43[0] == 0) then
                            daoc.game.use_skill(idx, 1);
                        end
                    elseif (petent.health < 90) then
                        daoc.entity.set_target(daoc.entity.get_index_by_id(petent.object_id))
                        local idx = daoc.data.get_skill(healer.heal1nameBuf[1])
                        --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));    
                        if (idx ~= nil and player.unknown43[0] == 0) then
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

        local pavghp = party_avg_hp();
        
        if (healer.is_checked[1]) then
            imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, ('Running! Party HP: %.0f'):fmt(pavghp));
        else
            imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Off');
        end
        if (imgui.BeginTable('##find_items_list2', 3, bit.bor(ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersH, ImGuiTableFlags_BordersV, ImGuiTableFlags_ContextMenuInBody, ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit))) then
            imgui.TableSetupColumn('Type', ImGuiTableColumnFlags_WidthFixed, 120.0, 0);
            imgui.TableSetupColumn('Name', ImGuiTableColumnFlags_WidthFixed, 200.0, 0);
            imgui.TableSetupColumn('Threshold', ImGuiTableColumnFlags_WidthStretch, 0, 0);
            imgui.TableHeadersRow();
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.Text("Small Heal")
            imgui.PushItemWidth(170);
            imgui.TableNextColumn();
            imgui.InputText("##heal1name", healer.heal1nameBuf, healer.heal1nameSize);
            imgui.TableNextColumn();
            imgui.InputText("##heal1val", healer.heal1valBuf, healer.heal1valSize);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.Text("Big Heal")
            imgui.TableNextColumn();
            imgui.InputText("##heal2name", healer.heal2nameBuf, healer.heal2nameSize);
            imgui.TableNextColumn();
            imgui.InputText("##heal2val", healer.heal2valBuf, healer.heal2valSize);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.Text("Emerg Heal")
            imgui.TableNextColumn();
            imgui.InputText("##heal3name", healer.heal3nameBuf, healer.heal3nameSize);
            imgui.TableNextColumn();
            imgui.InputText("##heal3val", healer.heal3valBuf, healer.heal3valSize);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.Text("Small Grp Heal")
            imgui.TableNextColumn();
            imgui.InputText("##heal4name", healer.heal4nameBuf, healer.heal4nameSize);
            imgui.TableNextColumn();
            imgui.InputText("##heal4val", healer.heal4valBuf, healer.heal4valSize);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.Text("Big Grp Heal")
            imgui.TableNextColumn();
            imgui.InputText("##heal5name", healer.heal5nameBuf, healer.heal5nameSize);
            imgui.TableNextColumn();
            imgui.InputText("##heal5val", healer.heal5valBuf, healer.heal5valSize);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.Text("Single Insta")
            imgui.TableNextColumn();
            imgui.InputText("##heal6name", healer.heal6nameBuf, healer.heal6nameSize);
            imgui.TableNextColumn();
            imgui.InputText("##heal6val", healer.heal6valBuf, healer.heal6valSize);
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.Text("Grp Insta")
            imgui.TableNextColumn();
            imgui.InputText("##heal7name", healer.heal7nameBuf, healer.heal7nameSize);
            imgui.TableNextColumn();
            imgui.InputText("##heal7val", healer.heal7valBuf, healer.heal7valSize);
            imgui.EndTable();
        end
        if healer.pet_toggle[1] then
            imgui.Text("Pet name:")
            imgui.SameLine();
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

function party_avg_hp()
    local totalhp = 0;
    local count = 0;
    local player = daoc.entity.get(daoc.entity.get_player_index());
    if player == nil then
        error('Failed to get player entity.');
		return 100;
    end

    local party = daoc.party.get_members();
    if party == nil then
        return 100;
    end
    for x = 0, 7 do
        local member = party[x];
        --daoc.chat.msg(daoc.chat.message_mode.help, ('member %s'):fmt(member.name));    
        if member.name:len() > 0 then
            local dist = math.distance2d(player.loc_x, player.loc_y, member.x, member.y);
            if (dist < healer.healRange and member.health > 0) then
                totalhp = totalhp + member.health;
                count = count + 1;
                
            end
        end
    end
    if count == 0 then count = 1; end
    local partyavg = totalhp / count;
    return partyavg;
end