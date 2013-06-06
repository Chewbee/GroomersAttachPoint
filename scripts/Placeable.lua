local modName = g_currentModName;
local modDir = g_currentModDirectory;

Placeable = {};

Placeable.placeables = {};
function Placeable.addPlaceable(placeable)
    local xmlFilename = placeable.configFileName:lower();
    local list = Placeable.placeables[xmlFilename];
    if list == nil then
        list = {};
        Placeable.placeables[xmlFilename] = list;
    end;
    list[placeable] = placeable;
end;
function Placeable.removePlaceable(placeable)
    local xmlFilename = placeable.configFileName:lower();
    local list = Placeable.placeables[xmlFilename];
    if list ~= nil then
        list[placeable] = nil;
    end;
end;
function Placeable.getNumPlaceables(xmlFilename)
    local num = 0;
    local xmlFilename = xmlFilename:lower();
    local list = Placeable.placeables[xmlFilename];
    if list ~= nil then
        for k in pairs(list) do
            num = num+1;
        end;
    end;
    return num;
end;

function Placeable.prerequisitesPresent(specializations)
    return true;
end;

function Placeable:load(xmlFile)

    self.placementSizeX = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.placement#sizeX"), 1);
    self.placementSizeZ = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.placement#sizeZ"), 1);
    self.placementTestSizeX = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.placement#testSizeX"), 1);
    self.placementTestSizeZ = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.placement#testSizeZ"), 1);
    self.useRandomYRotation = Utils.getNoNil(getXMLBool(xmlFile, "vehicle.placement#useRandomYRotation"), false);
    self.useManualYRotation = Utils.getNoNil(getXMLBool(xmlFile, "vehicle.placement#useManualYRotation"), false);

    self.isPlaceableNonTabbable = true;

    for _, component in pairs(self.components) do
        g_currentMission:addNodeObject(component.node, self);
    end;

end;

function Placeable:delete()
    Placeable.removePlaceable(self);
    for _, component in pairs(self.components) do
        g_currentMission:removeNodeObject(component.node);
    end;
end;

function Placeable:readStream(streamId, connection)
    if connection:getIsServer() then

        for _, component in pairs(self.components) do
            g_currentMission:addNodeObject(component.node, self);
        end;
        Placeable.addPlaceable(self);
    end;
end;

function Placeable:writeStream(streamId, connection)
end;

function Placeable:readUpdateStream(streamId, timestamp, connection)
end;

function Placeable:writeUpdateStream(streamId, connection, dirtyMask)
end;

function Placeable:mouseEvent(posX, posY, isDown, isUp, button)
end;

function Placeable:keyEvent(unicode, sym, modifier, isDown)
end;

function Placeable:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)

    local numMovingTools = getXMLInt(xmlFile, key.."#numMovingTools");
    if self.movingTools ~= nil and numMovingTools ~= nil then
        numMovingTools = math.min(numMovingTools, table.getn(self.movingTools));
        for i=1, numMovingTools do
            local tool = self.movingTools[i];
            local toolKey = key..string.format(".movingTool%d", i);
            local changed = false;
            if tool.transSpeed ~= nil then
                local newTrans = getXMLFloat(xmlFile, toolKey.."#curTrans");
                if newTrans ~= nil and math.abs(newTrans - tool.curTrans[tool.translationAxis]) > 0.0001 then
                    tool.curTrans[tool.translationAxis] = newTrans;
                    setTranslation(tool.node, unpack(tool.curTrans));
                    changed = true;
                end;
            end;
            if tool.rotSpeed ~= nil then
                local newRot = getXMLFloat(xmlFile, toolKey.."#curRot");
                if newRot ~= nil and math.abs(newRot - tool.curRot[tool.rotationAxis]) > 0.0001 then
                    tool.curRot[tool.rotationAxis] = newRot;
                    setRotation(tool.node, unpack(tool.curRot));
                    changed = true;
                end;
            end;
            if changed then
                Cylindered.setDirty(self, tool);
            end;
        end;
    end;
    return BaseMission.VEHICLE_LOAD_OK;
end

function Placeable:getSaveAttributesAndNodes(nodeIdent)

    local attributes = "";
    local nodes = "";
    if self.movingTools ~= nil then
        local numMovingTools = table.getn(self.movingTools);
        attributes = 'numMovingTools="'..numMovingTools..'"';
        for i=1, numMovingTools do
            local tool = self.movingTools[i];

            if i>1 then
                nodes = nodes.."\n";
            end;
            nodes = nodes..nodeIdent..'<movingTool'..string.format("%d", i);
            if tool.transSpeed ~= nil then
                nodes = nodes..' curTrans="'..tool.curTrans[tool.translationAxis]..'"';
            end;
            if tool.rotSpeed ~= nil then
                nodes = nodes..' curRot="'..tool.curRot[tool.rotationAxis]..'"';
            end;
            nodes = nodes..' />';
        end;
    end;
    return attributes,nodes;
end

function Placeable:update(dt)
end;

function Placeable:updateTick(dt)
end;

function Placeable:draw()
end;


--function Placeable:testScope(x,y,z, coeff)
--end;

--function Placeable:getUpdatePriority(skipCount, x, y, z, coeff, connection)
--end;

--function Placeable:onGhostRemove()
--end;

--function Placeable:onGhostAdd()
--end;

PlaceableEventListener = {};
PlaceableEventListener.guiModified = false;
PlaceableEventListener.tabPlaceablesElement = nil;
PlaceableEventListener.tabPlaceables = false;

function PlaceableEventListener.toggleTabPlaceablesOnClick(state)
    PlaceableEventListener.tabPlaceables = state;
end;

function PlaceableEventListener:loadMap(name)
    if not PlaceableEventListener.guiModified then
        PlaceableEventListener.guiModified = true;

        local oldOnCreate = g_inGameMenu.showHotelsElement.onCreate;
        g_inGameMenu.showHotelsElement.onCreate = nil; -- don't call onCreate again
        local tabPlaceablesElement = g_inGameMenu.showHotelsElement:clone(g_inGameMenu.showHotelsElement.parent);
        g_inGameMenu.showHotelsElement.onCreate = oldOnCreate;

        tabPlaceablesElement:setPosition(tabPlaceablesElement.position[1], tabPlaceablesElement.position[2] - 0.07);
        tabPlaceablesElement.onClick = PlaceableEventListener.toggleTabPlaceablesOnClick;
        tabPlaceablesElement.target = nil;

        local settingsElement = g_inGameMenu.modeGUIElements[InGameMenu.MODE_SETTINGS];
        local hotelText = g_i18n:getText("ShowHotelsOnPDA");
        for _, element in pairs(settingsElement.elements) do
            if element.text ~= nil and element.text == hotelText then
                local textElement = element:clone(element.parent);
                textElement:setPosition(textElement.position[1], textElement.position[2] - 0.07);
                textElement:setText(g_i18n:getText("TabPlaceables"));
                break;
            end;
        end;
        PlaceableEventListener.tabPlaceablesElement = tabPlaceablesElement;



        local InGameMenu_updateGUI = InGameMenu.updateGUI;
        InGameMenu.updateGUI = function (self)
            InGameMenu_updateGUI(self);
            if PlaceableEventListener.tabPlaceablesElement ~= nil then
                PlaceableEventListener.tabPlaceablesElement:setIsChecked(PlaceableEventListener.tabPlaceables);
            end;
        end;

    end;
end;

function PlaceableEventListener:deleteMap()
end;

function PlaceableEventListener:mouseEvent(posX, posY, isDown, isUp, button)
end;

function PlaceableEventListener:keyEvent(unicode, sym, modifier, isDown)
end;

function PlaceableEventListener:update(dt)
end;

function PlaceableEventListener:draw()
end;


addModEventListener(PlaceableEventListener);


local BaseMission_toggleVehicle = BaseMission.toggleVehicle;

function BaseMission:toggleVehicle(delta)

    if not PlaceableEventListener.tabPlaceables then
        for _, vehicle in pairs(self.steerables) do
            if vehicle.isPlaceableNonTabbable then
                vehicle.isBrokenOld = vehicle.isBroken;
                vehicle.isBroken = true;
            end;
        end;
    end;

    BaseMission_toggleVehicle(self, delta);

    if not PlaceableEventListener.tabPlaceables then
        for _, vehicle in pairs(self.steerables) do
            if vehicle.isPlaceableNonTabbable then
                vehicle.isBroken = vehicle.isBrokenOld;
                vehicle.isBrokenOld = nil;
            end;
        end;
    end;

end;

local WSRCareerMissionInfo_saveToXML = WSRCareerMissionInfo.saveToXML;
local WSRCareerMissionInfo_loadFromMission = WSRCareerMissionInfo.loadFromMission;
local WSRBaseMission_setMissionInfo = WSRBaseMission.setMissionInfo;

function WSRCareerMissionInfo:saveToXML()

    if self.xmlKey ~= nil and self.isValid then
        setXMLBool(self.xmlFile, self.xmlKey.."#tabPlaceables", Utils.getNoNil(self.tabPlaceables, false));
    end;

    WSRCareerMissionInfo_saveToXML(self);
end;

function WSRCareerMissionInfo:loadFromMission(mission)
    WSRCareerMissionInfo_loadFromMission(self, mission);

    self.tabPlaceables = PlaceableEventListener.tabPlaceables;
end;


function WSRBaseMission:setMissionInfo(missionInfo, missionDynamicInfo)
    WSRBaseMission_setMissionInfo(self, missionInfo, missionDynamicInfo);

    -- we can't use the loadXML function from career savegame, since the script was not loaded at that time
    if missionInfo.isValid and missionInfo.xmlKey ~= nil then
        missionInfo.tabPlaceables = Utils.getNoNil(getXMLBool(missionInfo.xmlFile, missionInfo.xmlKey .. "#tabPlaceables"), false);
    end;
    PlaceableEventListener.tabPlaceables = Utils.getNoNil(missionInfo.tabPlaceables, false);
end;
