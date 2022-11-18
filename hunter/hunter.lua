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

addon.name    = 'hunter';
addon.author  = 'towbes';
addon.desc    = 'Mob Finder';
addon.link    = '';
addon.version = '1.0';

require 'common';
require 'daoc';

local imgui = require 'imgui';
local ffi = require 'ffi';

local hunter = T {
    findNameBuf = {''},
    findNameBufSize = 100,
    playersOnly = T { false, },
    selected_item = T {0,},
    --chkBoxFilter_Objects = T { false, },
    --chkBoxFilter_Mobs = T { false, },
    --chkBoxFilter_Players = T { false, },
};


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
* Prints the addon specific help information.
*
* @param {level} level - Players current level
* @param {comparelevel} comparelevel - Entitys current level
--]]
local function GetConColor(level, comparelevel)
       
    local constep = math.max(1, (level + 9) / 10);
    local stepping = 1.0 / constep;
    local leveldiff = level - comparelevel;

    local concolor = 0 - leveldiff * stepping
    
    --daoc.chat.msg(daoc.chat.message_mode.help, "Level: " .. level .. " CompareLevel: " .. comparelevel .. " Con Color: " .. concolor);

    return concolor;

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

    for i = 1, daoc.entity.get_count() do
        if (daoc.entity.is_valid(i)) then
            local ent = daoc.entity.get(i);
            if (ent ~= nil and ent.health > 0 and i ~= daoc.entity.get_player_index()) then
                local heading = GetGameHeading(player.x, player.y, ent.x, ent.y);
                local direction = '';
                if (heading < 0) then
				    heading = heading + 4096
                end
                if (heading >= 3840 or heading <= 256) then
                    direction = "South";
                elseif (heading > 256 and heading < 768) then
                    direction = "SW";
                elseif (heading >= 768 and heading <= 1280) then
                    direction = "West";
                elseif (heading > 1280 and heading < 1792) then
                    direction = "NW";
                elseif (heading >= 1792 and heading <= 2304) then
                    direction = "North";
                elseif (heading > 2304 and heading < 2816) then
                    direction = "NE";
                elseif (heading >= 2816 and heading <= 3328) then
                    direction = "East";
                elseif (heading > 3328 and heading < 3840) then
                    direction = "SE";
                end

                if (hunter.playersOnly[1]) then
                    if (ent.object_type ~= daoc.entity.type.player) then
                        goto continue;
                    end
                end
                entList:append(T{index = i, 
                                name = ent.name,
                                x = ent.x,
                                y = ent.y,
                                realm = ent.realm_id, 
                                dist = math.distance2d(ent.x, ent.y, player.x, player.y),
                                heading = direction,
                                level = ent.level,
                                health = ent.health});
                
            end
            ::continue::
        end
        --imgui.Text(("index %d, %s\n"):fmt(i, itemTemp.id, itemTemp.name));
    end
    -- Render a custom example inventory via ImGui..
    imgui.SetNextWindowSize(T{ 350, 200, }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('Hunter')) then
        if (imgui.BeginTabBar('##hunter_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
            if (imgui.BeginTabItem('Find', nil)) then
                
                imgui.Checkbox('PlayersOnly', hunter.playersOnly);
                imgui.Text("Search name:")
                imgui.SameLine();
                imgui.PushItemWidth(350);
                imgui.InputText("##FindName", hunter.findNameBuf, hunter.findNameBufSize);
                if (imgui.BeginTable('##hunter_list', 7, bit.bor(ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersH, ImGuiTableFlags_BordersV, ImGuiTableFlags_ContextMenuInBody, ImGuiTableFlags_ScrollX, ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit))) then
                    imgui.TableSetupColumn('Idx', ImGuiTableColumnFlags_WidthFixed, 30.0, 0);
                    imgui.TableSetupColumn('Distance', ImGuiTableColumnFlags_WidthFixed, 50.0, 0);
                    imgui.TableSetupColumn('Direction', ImGuiTableColumnFlags_WidthFixed, 50.0, 0);
                    imgui.TableSetupColumn('Realm', ImGuiTableColumnFlags_WidthFixed, 30.0, 0);
                    imgui.TableSetupColumn('HP', ImGuiTableColumnFlags_WidthFixed, 30.0, 0);
                    imgui.TableSetupColumn('Level', ImGuiTableColumnFlags_WidthFixed, 30.0, 0);
                    imgui.TableSetupColumn('Name', ImGuiTableColumnFlags_WidthStretch, 0, 0);
                    imgui.TableSetupScrollFreeze(0, 1);
                    imgui.TableHeadersRow();
                    entList:sort(function (a, b)
                        if (a.name == nil or b.name == nil) then return; end
                        return (a.dist < b.dist) or (a.dist == b.dist and a.index < b.index);
                    end);

                    for x = 1, entList:len() do
                        if (entList[x].name ~= nil and entList[x].name:len() > 0 and (entList[x].name:lower():contains(hunter.findNameBuf[1]:lower()))) then 
                            imgui.PushID(x);
                            imgui.TableNextRow();
                            imgui.TableSetColumnIndex(0);

                            -- Set the row as selectable..
                            if (imgui.Selectable(('%d##%d'):fmt(entList[x].index, x), x == hunter.selected_item[1], bit.bor(ImGuiSelectableFlags_SpanAllColumns, ImGuiSelectableFlags_AllowItemOverlap), { 0, 0, })) then
                                hunter.selected_item[1] = x;
                                daoc.entity.set_target(entList[x].index, 1);
                            end
                            imgui.TableNextColumn();
                            imgui.Text(('%d'):fmt(entList[x].dist));
                            imgui.TableNextColumn();
                            imgui.Text(('%s'):fmt(entList[x].heading));
                            imgui.TableNextColumn();
                            if (realmStr[entList[x].realm] ~= nil) then
                                imgui.Text(('%s'):fmt(realmStr[entList[x].realm]));
                            end
                            imgui.TableNextColumn();
                            imgui.Text(('%d'):fmt(entList[x].health));
                            imgui.TableNextColumn();
                            imgui.Text(('%d'):fmt(entList[x].level));
                            imgui.TableNextColumn();
                            imgui.Text(('%s'):fmt(entList[x].name));
                            imgui.PopID();
                        end
                    end
                    --entList:each(function (v,k)
                    --    if (v.name == nil or v.name == nil) then return; end
                    --    if (v.name:lower():contains(hunter.findNameBuf[1]:lower())) then
                    
                    --    end
                    --end);
                    imgui.EndTable();
                end
                imgui.EndTabItem();
            end
        end
    end

    local wSizeX = 530;
    local wSizeY = 530;
    local MaxDist = 4000;

    --// Radar Map Code
    imgui.SetNextWindowSize(T{ wSizeX, wSizeY, }, ImGuiCond_FirstUseEver);
    if (imgui.Begin('Info', ImGuiWindowFlags_NoMouseInputs )) then
        local scale = 1
        imgui.SetWindowFontScale(scale)
        local draw_list = imgui.GetWindowDrawList();
        local mouseX, mouseY = imgui.GetCursorScreenPos();
        
        --imgui.Text("Filters: ");
        --imgui.SameLine();
        --imgui.Checkbox('Hide Objects', hunter.chkBoxFilter_Objects);
        --imgui.SameLine();
        --imgui.Checkbox('Hide Mobs', hunter.chkBoxFilter_Mobs);
        --imgui.SameLine();
        --imgui.Checkbox('Hide Players', hunter.chkBoxFilter_Players);
        
        local playerDotColor = imgui.GetColorU32({1, 0.3, 0.4, 1});
        draw_list:AddCircle({(mouseX + wSizeX/2), (mouseY + wSizeY/2)}, 3, playerDotColor, 6, 3 );
        
        --draw_list:AddTriangleFilled(ImVec2(50, 100), ImVec2(100, 50), ImVec2(150, 100), ImColor(255, 0, 0))
       
        for x=1, entList:len() do
                --if (entList[x].name == "horse") then goto continue; end

                -- Eliminates crashing if an object doesn't have a name. -randomc0der
                if (entList[x].name ~= nil) then

                --daoc.chat.msg(daoc.chat.message_mode.help, "Object Type: " .. entList[x]. .. " Mob Name: " .. entList[x].name);

                --Offset offset = CalculateOffset(p);
                local offx, offy = CalcOffset(entList[x].x, entList[x].y, player.x, player.y)
                if offx == nil or offy == nil then
                    goto continue;
                end

                --// don't need to draw players out of range
                if (offx > MaxDist or offx < -MaxDist or offy > MaxDist or offy < -MaxDist) then goto continue; end

                --// gui position of player
                local entityNameLoc = {mouseX + wSizeX / 2 + offx / (MaxDist / (wSizeX / 2) + 1), mouseY + wSizeY / 2 + offy / (MaxDist / (wSizeY / 2))}
                local entityNameColor = imgui.GetColorU32({1, 1, 1, 1});

                draw_list:AddText(entityNameLoc, entityNameColor, entList[x].name .. "(" .. entList[x].level .. ")");
                
                --// Calculate entity position on the map
                local entityDotLoc = {mouseX + wSizeX / 2 + offx / (MaxDist / (wSizeX / 2)), mouseY + wSizeY / 2 + offy / (MaxDist / (wSizeY / 2))}
                
                --// Default enity color to yellow, if a realm ID is found color code it.
                local entityDotColor = imgui.GetColorU32({.98, .75, 0, 1}); -- default to yellow

                --// Convert RealmID to Name and Color
                if (realmStr[entList[x].realm] == "Alb") then
                    entityDotColor = imgui.GetColorU32({1, .15, .15, 1}); -- Red color
                elseif  (realmStr[entList[x].realm] == "Hib") then
                    entityDotColor = imgui.GetColorU32({.29, .98, .0, 1}); -- Green Color
                elseif  (realmStr[entList[x].realm] == "Mid") then
                    entityDotColor = imgui.GetColorU32({0, .26, .98, 1});  -- Blue color
                else
                    entityDotColor = imgui.GetColorU32({.98, .75, 0, 1}); -- Yellow color
                end
                
                --// Draw enity on the map
                draw_list:AddCircle(entityDotLoc, 3, entityDotColor, 6, 3 );
                   
            end
            ::continue::                   
        end
    end

    imgui.End();

end);   

function GetGameHeading(playerX, playerY, targX, targY)
    local dx = targX - playerX;
    local dy = targY - playerY;

    local heading = math.atan2(-dx, dy) * (180.0 / math.pi) * (4096.0 / 360.0);

    if (heading < 0) then
        heading = heading +4096;
    end

    return heading;
end

function CalcOffset(x1, y1, x2, y2)
    if x1 == nil or y1 == nil or x2 == nil or y2 == nil then return nil, nil end
    return y2 - y1, x2 - x1
end

--[[
* function: Sort
* desc : Sort items in the game
--]]
function Sort(minSlot, maxSlot)
    daoc.chat.msg(daoc.chat.message_mode.help, 'Starting sort');
    --Return if arguments weren't passed properly
    if minSlot == nil or maxSlot == nil then return; end

    --if the first slotNum of alpha items does not equal the min Slot Num, move items
    for i=1, sortItems:length() do
        --if (sortItems[i].slot ~= i + (minSlot - 1)) then
            daoc.items.move_item(i + (minSlot - 1), sortItems[i].slot, 0);
            --sleep to prevent spam
            coroutine.sleep(inventory.sortDelay);
        --end
    end
    daoc.chat.msg(daoc.chat.message_mode.help, 'Sorting finished!');
end

function next_empty_slot(minSlot, maxSlot)
    for i = minSlot, maxSlot do
        --Split based on slots, ie equipped gear, inventory, vault, house vault
        local itemTemp = daoc.items.get_item(i);
        if (itemTemp.name:empty()) then
            return i;
        end
    end
    return nil;
end