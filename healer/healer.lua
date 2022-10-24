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

--[[
* Data Related Structure Definitions
--]]
ffi.cdef[[
    //useSpell_t plyrUseSpellTable[150];
    typedef struct {
        char name_[64];
        short level;
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
    typedef struct  {
        char name_[64];
        short level;
        short unknown1;
        int tickCount;
        int unknown2;
        int unknown3;
        int unknown4;
        int unknown5;
        int unknown6;
    } skill_t;

    //array start address is 0x163FA50
    //6968 bytes total = 0x1B38
    typedef struct  {
        char categoryName[64];
        skill_t skillArray[75];
        int alignBuf;
    } skill_category_t;

    typedef struct  {
        skill_category_t categories[15];
    } skill_cat_list_t;
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
                    daoc.chat.msg(daoc.chat.message_mode.help, ('cat: %d, lvl: %d name: %s'):fmt(cat, spell.level, spellname));
                    return cat, spell.level;
                end
            end
        end
    end

    return nil, nil;
end

--[[
* Returns list of skills
--]]
daoc.data.get_skill_categories = function ()

    local ptr = hook.pointers.get('daoc.data.loadedskills');
    if (ptr == 0) then return nil; end
	ptr = hook.memory.read_uint32(ptr);
    if (ptr == 0) then return nil; end

    return ffi.cast('skill_cat_list_t*', ptr);
end

--[[
* Returns index of skill
--]]
daoc.data.get_skill = function (skillName)
    if (skillName == nil) then
        return nil;
    end

    local skillCats = daoc.data.get_skill_categories();
    if skillCats == nil then return; end


    skillName = skillName:lower();
    for cat=0, 15 do
        for x = 0, 75 do
            local skill = skillCats.categories[cat].skillArray[x]
            local skillname = ffi.string(skill.name);
            if (skillname ~= nil and skillname:len() > 0) then
                
                if (skillname:lower():ieq(skillName)) then
                    daoc.chat.msg(daoc.chat.message_mode.help, ('cat: %d, lvl: %d name: %s'):fmt(cat, skill.level, skillname));
                    return cat, skill.level;
                end
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
    --Address of signature = game.dll + 0x0001F738 +0x1
    local ptr = hook.pointers.add('daoc.data.loadedskills', 'game.dll', '68????????68????????E8????????5959C9C3837D08', 1,0);
    if (ptr == 0) then
        error('Failed to locate skill table pointer.');
    end

end);

-- Window Variables
local window = T{
    is_checked = T{ false, },
    spellNameBuf = { '' },
    spellNameSize = 50,
    otherbuf = {''},
    otherbufsize = 2,
};

--pause time to buy mats and interact with vendor
local tick_holder = hook.time.tick();
local tick_interval = 100;

--[[
* event: d3d_present
* desc : Called when the Direct3D device is presenting a scene.
--]]
hook.events.register('d3d_present', 'd3d_present_heal', function ()
    -- Render a custom example window via ImGui..
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

    if (hook.time.tick() >= (tick_holder + tick_interval) ) then	
        tick_holder = hook.time.tick();
        if (window.is_checked[1]) then
            for x = 0, 7 do
                local member = party[x];
                --daoc.chat.msg(daoc.chat.message_mode.help, ('member %s'):fmt(member.name));    
                if (member.health < 95) then
                    
                    local idx = daoc.data.get_skill('Resuscitation')
                    --daoc.chat.msg(daoc.chat.message_mode.help, ('heal %s with %d'):fmt(member.name, idx));    
                    daoc.game.use_skill(idx, 1);
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
    imgui.SetNextWindowSize(T{ 350, 200, }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('Healer')) then
        imgui.Text('Auto heal party addon');
        imgui.Checkbox('Toggle', window.is_checked);

        
        if (window.is_checked[1]) then
            imgui.TextColored(T{ 0.0, 1.0, 0.0, 1.0, }, 'Running!');
        else
            imgui.TextColored(T{ 1.0, 0.0, 0.0, 1.0, }, 'Off');
        end
        imgui.Text("Name:")
        imgui.SameLine();
        imgui.PushItemWidth(200);
        imgui.InputText("##skillname", window.spellNameBuf, window.spellNameSize);
        imgui.PushItemWidth(50);
        imgui.Text("id2:")
        imgui.InputText("##otherid", window.otherbuf, window.otherbufsize);
        if (imgui.Button('Spell')) then
            if (window.spellNameBuf[1]:len() > 0) then
                local cat, lvl = daoc.data.get_spell(window.spellNameBuf[1])
                if (cat ~= nil and lvl ~= nil) then
                    daoc.chat.msg(daoc.chat.message_mode.help, ('cat: %d, lvl %d'):fmt(cat,lvl));    
                    daoc.game.use_spell(cat, lvl);
                end
                
            end
        end
        imgui.SameLine();
        if (imgui.Button('Skill')) then
            if (window.spellNameBuf[1]:len() > 0) then
                local cat, lvl = daoc.data.get_skill(window.spellNameBuf[1])
                if (cat ~= nil and lvl ~= nil) then
                    daoc.chat.msg(daoc.chat.message_mode.help, ('cat: %d, lvl %d'):fmt(cat,lvl));    
                    daoc.game.use_skill(cat, lvl);
                end
            end
        end

        local party = daoc.party.get_members();
        if party == nil then
            error('Failed to get party.');
        end
    
        for x = 0, 7 do
            local member = party[x];
            imgui.Text(('Group %d: %s'):fmt(x, member.name))
        end 
    end
    imgui.End();
end);
