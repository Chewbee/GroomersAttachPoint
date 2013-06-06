-- @author  Stefan Geiger
-- @date  26/04/11
--
-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.

local modName = g_currentModName;
local modDir = g_currentModDirectory;

PlacementScreen = {};
PlacementScreen.objectCollisionMask = 32+64+128+256+4096;

local PlacementScreen_mt = Class(PlacementScreen);


--[[PlacementScreen.placeableTypes = {};
function PlacementScreen.registerPlaceableType(typeName, classObject)
    PlacementScreen.placeableTypes[typeName] = classObject;
end;]]

function PlacementScreen:new()
    local self = {};
    self = setmetatable(self, PlacementScreen_mt);

    self.cameraX = 0;
    self.cameraZ = 0;

    self.moveX = 0;
    self.moveZ = 0;
    self.mousePosX = 0.5;
    self.mousePosY = 0.5;
    self.zoomFactor = 1;
    self.targetZoomFactor = 1;
    self.zoomFactorUpdateDt = 0;
    self.isDown = false;
    self.placeablePositionValid = false;
    self.placeablePositionInvalidWarningTime = 0;

    self.placeableRotY = 0;
    self.placeableRotationSpeed = 0.003;

    self.isMouseMode = true;

    self.camera = createCamera("PlacementCamera", 60, 1, 4000);
    setRotation(self.camera, math.rad(-60), 0,0);


    self.crossHair = createImageOverlay(modDir.."cross_hair.png");
    setOverlayColor(self.crossHair, 1.0, 1.0, 1.0, 1.0);

    self.moveArrowLeft = createImageOverlay(modDir.."moveArrow.png");
    setOverlayColor(self.moveArrowLeft, 1.0, 1.0, 1.0, 1.0);
    setOverlayUVs(self.moveArrowLeft, 1,0, 0,0, 1,1, 0,1);

    self.moveArrowRight = createImageOverlay(modDir.."moveArrow.png");
    setOverlayColor(self.moveArrowRight, 1.0, 1.0, 1.0, 1.0);
    setOverlayUVs(self.moveArrowRight, 0,1, 1,1, 0,0, 1,0);

    self.moveArrowUp = createImageOverlay(modDir.."moveArrow.png");
    setOverlayColor(self.moveArrowUp, 1.0, 1.0, 1.0, 1.0);
    setOverlayUVs(self.moveArrowUp, 0,1, 0,0, 1,1, 1,0);

    self.moveArrowDown = createImageOverlay(modDir.."moveArrow.png");
    setOverlayColor(self.moveArrowDown, 1.0, 1.0, 1.0, 1.0);



    self.messageTextSpeed = 500;
    self.messageTextTime = 0;
    self.messageTextColorDirection = 1;
    self.messageTextColor1 = { 1, 1, 1, 1 };
    self.messageTextColor2 = { 1, 1, 1, 1 };

    self.showMessageForceTime = 0;

    self.time = 0;
    self.isSelling = false;
    self.isBuying = false;

    self.isSellMode = false;
    return self;
end;

function PlacementScreen:onOpen()
    self.prevCamera = getCamera();
    self:updateCameraPosition();
    g_currentMission:addSpecialCamera(self.camera);
    setCamera(self.camera);
    InputBinding.setShowMouseCursor(true);
    self.placeablePositionValid = false;


    self:updateCapitalText();
    self.lastMoney = g_currentMission.missionStats.money;
    self.messageText.text = "";

    -- load instance of placement item
    if self.placementItem ~= nil then
        self.placeable = PlacementScreen.loadPlaceableFromXML(self.placementItem.xmlFilename, 0,-500,0, 0,0,0, true);
        if self.placeable ~= nil then
            if self.placeable.useRandomYRotation then
                self.placeableRotY = math.random()*math.pi*2;
                setRotation(self.placeable.components[1].node, 0, self.placeableRotY, 0);
            else
                self.placeableRotY = 0;
            end;
        end;
    end;
end;

function PlacementScreen:onClose()
    setCamera(self.prevCamera);
    g_currentMission:removeSpecialCamera(self.camera);
    if self.placeable ~= nil then
        self.placeable:delete();
        self.placeable = nil;
    end;
    InputBinding.setShowMouseCursor(false);
end;

function PlacementScreen:onCreateCapitalText(element)
    self.capitalText = element;
end;

function PlacementScreen:onCreateMessageText(element)
    self.messageText = element;
end;

function PlacementScreen:updateCapitalText()
    if g_currentMission ~= nil then
        self.capitalText:setText(g_i18n:getText("Capital") .. ": " .. g_i18n:formatMoney(g_currentMission.missionStats.money));
    end;
end;

function PlacementScreen.loadPlaceableFromXML(xmlFilename, x,y,z, rx,ry,rz, moveMode)
    local xmlFile = loadXMLFile("TempConfig", xmlFilename);
    local typeName = getXMLString(xmlFile, "vehicle#type");
    delete(xmlFile);
    if typeName ~= nil then
        local placeable = PlacementScreen.loadPlaceable(typeName, xmlFilename, x,y,z, rx,ry,rz, moveMode);
        return placeable;
    else
        print("Error loadPlaceable: invalid vehicle config file '"..xmlFilename.."', no type specified");
    end;

    return nil;
end;

function PlacementScreen.loadPlaceable(typeName, xmlFilename, x,y,z, rx,ry,rz, moveMode)
    local placeable = nil;
    local typeDef = VehicleTypeUtil.vehicleTypes[typeName];
    local modName, baseDirectory = getModNameAndBaseDirectory(xmlFilename);
    if modName ~= nil then
        if g_modIsLoaded[modName] == nil or not g_modIsLoaded[modName] then
            print("Error: Mod '"..modName.."' of placeable '"..xmlFilename.."'");
            print("       is not loaded. This placeable will not be loaded.");
            return;
        end;
        if typeDef == nil then
            typeName = modName.."."..typeName;
            typeDef = VehicleTypeUtil.vehicleTypes[typeName];
        end;
    end;
    if typeDef == nil then
        print("Error loadVehicle: unknown type '"..typeName.."' in '"..xmlFilename.."'");
    else
        local vehicleClass = getClassObject(typeDef.className);
        if vehicleClass ~= nil then

            placeable = vehicleClass:new(g_currentMission:getIsServer(), g_currentMission:getIsClient());
            local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z);
            placeable:load(xmlFilename, x, y-terrainHeight, z, ry, typeName);
            if placeable.placementTestSizeX == nil or placeable.placementTestSizeZ == nil or placeable.placementSizeX == nil or placeable.placementSizeZ == nil then
                placeable:delete();
                placeable = nil;
            else
                if moveMode then
                    for _, component in pairs(placeable.components) do
                        removeFromPhysics(component.node);
                    end;
                else
                    assert(g_currentMission:getIsServer());
                    if PlacementScreen.isInsidePlacementPlaces(g_currentMission.storeSpawnPlaces, placeable, x,y,z) or PlacementScreen.isInsidePlacementPlaces(g_currentMission.loadSpawnPlaces, placeable, x,y,z) or PlacementScreen.hasObjectOverlap(placeable, x,y,z,ry) then
                        placeable:delete();
                        placeable = nil;
                    else
                        placeable.isVehicleSaved = true;
                        Placeable.addPlaceable(placeable);
                        placeable:register();
                    end;
                end;
            end;
        end;
    end;


    --[[local placeable = nil;
    local classObject = PlacementScreen.placeableTypes[placeableType];
    if classObject ~= nil then
        placeable = classObject:new(g_currentMission:getIsServer(), g_currentMission:getIsClient());
    end;
    if placeable ~= nil then
        if placeable:load(xmlFilename, x,y,z, rx,ry,rz, moveMode) then
            if not moveMode then
                assert(g_currentMission:getIsServer());
                if PlacementScreen.isInsidePlacementPlaces(g_currentMission.storeSpawnPlaces, placeable, x,y,z) or PlacementScreen.isInsidePlacementPlaces(g_currentMission.loadSpawnPlaces, placeable, x,y,z) or PlacementScreen.hasObjectOverlap(placeable, x,y,z,ry) then
                    placeable:delete();
                    placeable = nil;
                else
                    placeable:register();
                end
            end;
        else
            placeable:delete();
            placeable = nil;
        end
    end;]]
    return placeable;
end;

--[[function PlacementScreen:onCreateText(element)
    self.textElement = element;
end;]]

function PlacementScreen:onCloseClick()
    g_gui:showGui("ShopScreen");
end;

function PlacementScreen:updateCameraPosition()

    local dist = 2;

    local h = g_currentMission.waterY;

    -- sample the terrain height around the camera
    for x=-dist, dist, dist do
        for z=-dist, dist, dist do
            local h1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.cameraX+x, 0, self.cameraZ+z);
            h = math.max(h, h1);
        end;
    end;
    local cameraY = self.zoomFactor*35 + 30;
    local rotationX = self.zoomFactor*-20 - 40;
    setRotation(self.camera, math.rad(rotationX), 0,0);
    setTranslation(self.camera, self.cameraX, h+cameraY, self.cameraZ);
end;

function PlacementScreen:update(dt)

    self.time = self.time + dt;
    self.messageTextTime = self.messageTextTime + self.messageTextColorDirection * dt;

    if self.messageTextTime > self.messageTextSpeed then
        self.messageTextTime = self.messageTextSpeed;
        self.messageTextColorDirection = -self.messageTextColorDirection;
    end;
    if self.messageTextTime < 0 then
        self.messageTextTime = 0;
        self.messageTextColorDirection = -self.messageTextColorDirection;
    end;

    local messageTextColorAlpha = self.messageTextTime / self.messageTextSpeed;
    for i = 1, 4 do
        self.messageText.textColor[i] = (1 - messageTextColorAlpha) * self.messageTextColor1[i] + self.messageTextColor2[i] * messageTextColorAlpha;
    end;


    -- update camera position
    local moveMarginStartX = 0.09*0.75;
    local moveMarginEndX = 0.01*0.75;
    local moveMarginStartY = 0.09;
    local moveMarginEndY = 0.01;
    local moveX = 0;
    local moveZ = 0;

    if InputBinding.isPressed(InputBinding.CAMERA_ZOOM_IN) then
        if InputBinding.getInputTypeOfDigitalAction(InputBinding.CAMERA_ZOOM_IN) == InputBinding.INPUTTYPE_MOUSE_WHEEL then
            self.targetZoomFactor = math.max(self.targetZoomFactor-0.2, 0);
        else
            self.targetZoomFactor = math.max(self.targetZoomFactor-0.002*dt, 0);
        end;
    elseif InputBinding.isPressed(InputBinding.CAMERA_ZOOM_OUT) then
        if InputBinding.getInputTypeOfDigitalAction(InputBinding.CAMERA_ZOOM_OUT) == InputBinding.INPUTTYPE_MOUSE_WHEEL then
            self.targetZoomFactor = math.min(self.targetZoomFactor+0.2, 1);
        else
            self.targetZoomFactor = math.min(self.targetZoomFactor+0.002*dt, 1);
        end;
    end;

    if InputBinding.isPressed(InputBinding.MENU_UP) then
        moveZ = moveZ + 1;
    end;
    if InputBinding.isPressed(InputBinding.MENU_DOWN) then
        moveZ = moveZ - 1;
    end;
    if InputBinding.isPressed(InputBinding.MENU_RIGHT) then
        moveX = moveX + 1;
    end;
    if InputBinding.isPressed(InputBinding.MENU_LEFT) then
        moveX = moveX - 1;
    end;


    if self.placeable ~= nil and self.placeable.useManualYRotation then
        local delta = self.placeableRotationSpeed*dt;

        local moveScale = InputBinding.getDigitalInputAxis(InputBinding.AXIS_MOVE_SIDE_VEHICLE);
        if InputBinding.isAxisZero(moveScale) then
            moveScale = InputBinding.getAnalogInputAxis(InputBinding.AXIS_MOVE_SIDE_VEHICLE);
        end;

        if not InputBinding.isAxisZero(moveScale) then
            self.placeableRotY = self.placeableRotY - moveScale*delta;
            setRotation(self.placeable.components[1].node, 0, self.placeableRotY, 0);
        end;
    end;



    if moveX == 0 and moveZ == 0 then
        if self.mousePosX >= 1-moveMarginStartX then
            moveX = math.min((moveMarginStartX - (1-self.mousePosX))/(moveMarginStartX - moveMarginEndX), 1);
        elseif self.mousePosX <= moveMarginStartX then
            moveX = -math.min((moveMarginStartX - self.mousePosX)/(moveMarginStartX - moveMarginEndX), 1);
        end;
        if self.mousePosY >= 1-moveMarginStartY then
            moveZ = math.min((moveMarginStartY - (1-self.mousePosY))/(moveMarginStartY - moveMarginEndY), 1);
        elseif self.mousePosY <= moveMarginStartY then
            moveZ = -math.min((moveMarginStartY - self.mousePosY)/(moveMarginStartY - moveMarginEndY), 1);
        end;
    else
        self.isMouseMode = false;
    end;

    if moveX ~= 0 or moveZ ~= 0 or math.abs(self.zoomFactor - self.targetZoomFactor) > 0.001 then
        self.cameraX = self.cameraX + moveX * dt * 0.1;
        self.cameraZ = self.cameraZ - moveZ * dt * 0.1;
        self.zoomFactorUpdateDt = self.zoomFactorUpdateDt + dt;
        while self.zoomFactorUpdateDt > 30 do
            self.zoomFactorUpdateDt = self.zoomFactorUpdateDt - 30;
            self.zoomFactor = self.zoomFactor*0.9 + self.targetZoomFactor*0.1;
        end;

        self:updateCameraPosition();
    end;

    if not self.isMouseMode then
        self.mousePosX = 0.5;
        self.mousePosY = 0.5;
    end;

    if InputBinding.hasEvent(InputBinding.JUMP) then
        if self.isSellMode then
            self:trySellAt(self.mousePosX, self.mousePosY);
        else
            self:buyPlaceable();
        end;
    end;

    if self.placeable ~= nil and not self.isSellMode then

        self.placeablePositionValid = false;
        local x,y,z = getTranslation(self.camera);
        local wx,wy,wz = unProject(self.mousePosX, self.mousePosY, 1);
        local dx,dy,dz = wx-x, wy-y, wz-z;
        raycastClosest(x, y, z, dx, dy, dz, "placementRaycastCallback", 500, self, PlacementScreen.objectCollisionMask);

        if not self.placeablePositionValid then
            setTranslation(self.placeable.components[1].node, 0,-500,0);
        end;


        self.showMessageForceTime = self.showMessageForceTime - dt;
        local placeablePositionInvalidWarningTimeLimit = 2000;
        if not self.placeablePositionValid then
            self.placeablePositionInvalidWarningTime = self.placeablePositionInvalidWarningTime + dt;

            if self.placeablePositionInvalidWarningTime > placeablePositionInvalidWarningTimeLimit then
                self.messageTextColor1 = { 1, 1, 0.25, 1 };
                self.messageTextColor2 = { 0.75, 0, 0, 1 };
                self.messageText.text = g_i18n:getText("InvalidPlacementPosition");
            end;
        else
            if self.showMessageForceTime <= 0 then
                self.messageText.text = "";
            end;
            self.placeablePositionInvalidWarningTime = 0;
        end
    end;

    if self.lastMoney ~= g_currentMission.missionStats.money then
        self:onMoneyChanged();
    end;

	if (InputBinding.hasEvent(InputBinding.MENU, true) or InputBinding.hasEvent(InputBinding.MENU_CANCEL, true)) then
        InputBinding.hasEvent(InputBinding.MENU, true);         -- remove menu events for other components
        InputBinding.hasEvent(InputBinding.MENU_CANCEL, true);
		self:onCloseClick();
	end;
end;

function PlacementScreen:draw()
    if not self.isMouseMode then
        local crossHairSize = 0.08;
        local crossHairSizeHalf = crossHairSize*0.5;
        renderOverlay(self.crossHair, 0.5-crossHairSizeHalf*0.75, 0.5-crossHairSizeHalf, crossHairSize*0.75, crossHairSize);
    end;
    local arrowHeight = 0.09;
    local arrowWidth = 0.06;
    local arrowWidthHalf = arrowWidth*0.5;
    renderOverlay(self.moveArrowDown, 0.5-arrowWidthHalf, 0, arrowWidth, arrowHeight);
    renderOverlay(self.moveArrowUp, 0.5-arrowWidthHalf, 1-arrowHeight, arrowWidth, arrowHeight);

    renderOverlay(self.moveArrowLeft, 0, 0.5-arrowWidthHalf, arrowHeight * 0.8, arrowWidth * 1.3);
    renderOverlay(self.moveArrowRight, 1-arrowHeight*0.8, 0.5-arrowWidthHalf, arrowHeight * 0.8, arrowWidth * 1.3);
end;

function PlacementScreen:mouseEvent(posX, posY, isDown, isUp, button)
    if button == Input.MOUSE_BUTTON_LEFT then
        if isDown then
            self.isDown = true;
        end;
        if self.isDown and isUp then
            self.isDown = false;
            if self.isSellMode then
                self:trySellAt(posX, posY);
            else
                -- place an object
                self:buyPlaceable();
            end;
        end;
    end;

    self.mousePosX = posX;
    self.mousePosY = posY;

    self.isMouseMode = true;
end;

function PlacementScreen:keyEvent(unicode, sym, modifier, isDown)
end;

function PlacementScreen:onMoneyChanged()
    self:updateCapitalText();
    self.lastMoney = g_currentMission.missionStats.money;
end;


function PlacementScreen:onPlaceableBought()
    --self.messageTextColor1 = { 1, 1, 1, 1 };
    --self.messageTextColor2 = { 0, 0.85, 0.15, 1 };
    -- TODO correct i18n
    --self.messageText.text = g_i18n:getText("StorePurchaseReady");

    self.isBuying = false;
end;
function PlacementScreen:onPlaceableBuyFailed()
    self.messageTextColor1 = { 1, 1, 0.25, 1 };
    self.messageTextColor2 = { 0.75, 0, 0, 1 };
    self.showMessageForceTime = 1000;
    self.messageText.text = g_i18n:getText("InvalidPlacementPosition");

    self.isBuying = false;
end;

function PlacementScreen:onPlaceableSold()

    self.isSelling = false;
end;

function PlacementScreen:onPlaceableSellFailed()

    self.isSelling = false;
end;

function PlacementScreen:buyPlaceable()
    if self.placeable ~= nil and self.placeablePositionValid and not self.isBuying and not self.isSelling and g_currentMission.missionStats.money >= self.placementItem.price then
        self.isBuying = true;

        --self.messageTextColor1 = { 1, 1, 1, 1 };
        --self.messageTextColor2 = { 0, 0.85, 0.15, 1 };
        -- TODO correct i18n
        --self.messageText.text = g_i18n:getText("StoreBuyingVehicle");
        local x,y,z = getTranslation(self.placeable.components[1].node);
        local rx,ry,rz = getRotation(self.placeable.components[1].node);
        if self.placeable.useRandomYRotation then
            self.placeableRotY = math.random()*math.pi*2;
            setRotation(self.placeable.components[1].node, 0, self.placeableRotY, 0);
        end;
        g_client:getServerConnection():sendEvent(BuyPlaceableEvent:new(self.placementItem.xmlFilename, x,y,z, rx,ry,rz));
    end;
end;

function PlacementScreen:trySellAt(posX, posY)
    local x,y,z = getTranslation(self.camera);
    local wx,wy,wz = unProject(posX, posY, 1);
    local dx,dy,dz = wx-x, wy-y, wz-z;
    raycastClosest(x, y, z, dx, dy, dz, "sellRaycastCallback", 500, self, PlacementScreen.objectCollisionMask);
end;

function PlacementScreen:sellPlaceable(placeable)
    if not self.isBuying and not self.isSelling then
        self.isSelling = true;

        --self.messageTextColor1 = { 1, 1, 1, 1 };
        --self.messageTextColor2 = { 0, 0.85, 0.15, 1 };
        -- TODO correct i18n
        --self.messageText.text = g_i18n:getText("StoreSellingVehicle");
        g_client:getServerConnection():sendEvent(SellPlaceableEvent:new(placeable));
    end;
end;

function PlacementScreen:setPlacementItem(item, isSellMode)
    if self.placeable ~= nil then
        self.placeable:delete();
        self.placeable = nil;
    end;
    self.placementItem = item;
    self.isSellMode = isSellMode;
end;

function PlacementScreen:placementRaycastCallback(hitObjectId, x, y, z, distance)
    if hitObjectId == g_currentMission.terrainRootNode and not PlacementScreen.isInsidePlacementPlaces(g_currentMission.storeSpawnPlaces, self.placeable, x,y,z) and not PlacementScreen.isInsidePlacementPlaces(g_currentMission.loadSpawnPlaces, self.placeable, x,y,z) and not PlacementScreen.hasObjectOverlap(self.placeable, x,y,z,self.placeableRotY) then
        self.placeablePositionValid = true;

        local distX = self.placeable.placementSizeX*0.5;
        local distZ = self.placeable.placementSizeZ*0.5;

        local cosRot = math.cos(self.placeableRotY);
        local sinRot = math.sin(self.placeableRotY);

        local h = y;
        for xi=-distX, distX, distX*0.25 do
            for zi=-distZ, distZ, distZ*0.25 do
                local xi2 = cosRot*xi + sinRot*zi;
                local zi2 = -sinRot*xi + cosRot*zi;

                local h1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x+xi2, 0, z+zi2);

                h = math.max(h, h1);
            end;
        end;
        setTranslation(self.placeable.components[1].node, x,h,z);
    end;
end;

function PlacementScreen:sellRaycastCallback(hitObjectId, x, y, z, distance)
    local object = g_currentMission:getNodeObject(hitObjectId);
    if object ~= nil and object.configFileName ~= nil and object.configFileName:lower() == self.placementItem.xmlFilename:lower() then
        self:sellPlaceable(object);
    end;
end;

function PlacementScreen.isInsidePlacementPlaces(places, placeable, x,y,z)
    local distanceLimit = 10 + math.sqrt(placeable.placementTestSizeX*placeable.placementTestSizeX*0.25 + placeable.placementTestSizeZ*placeable.placementTestSizeZ*0.25);
    for k,place in pairs(places) do

        -- find distance to line segment
        local dx = place.dirX;
        local dz = place.dirZ;
        local sx = place.startX;
        local sz = place.startZ;

        local width = place.width

        local t = (x-sx)*dx + (z-sz)*dz; -- position of projected point

        local distance;
        if t >= 0 and t <= width then
            -- nearest point is equal to the projected point
            distance = math.abs((sz-z)*dx-(sx-x)*dz);
        elseif t < 0 then
            distance = math.sqrt( (sx-x)*(sx-x) + (sz-z)*(sz-z));
        else
            local ex = place.startX + width*dx;
            local ez = place.startZ + width*dz;
            distance = math.sqrt( (ex-x)*(ex-x) + (ez-z)*(ez-z));
        end;

        if distance < distanceLimit then
            return true;
        end;
    end;
    return false;
end;

function PlacementScreen.hasObjectOverlap(placeable, x,y,z, rotY)
    local distX = placeable.placementTestSizeX*0.5;
    local distZ = placeable.placementTestSizeZ*0.5;

    local cosRot = math.cos(rotY);
    local sinRot = math.sin(rotY);

    PlacementScreen.tempHasObjectOverlap = false;
    overlapBox(x, y, z, 0,rotY,0, placeable.placementTestSizeX*0.5, 15, placeable.placementTestSizeZ*0.5, "objectOverlapCallback", PlacementScreen)

    if PlacementScreen.tempHasObjectOverlap then
        return true;
    end;

    -- test using raycast for other objects than vehicles
    for xi=-distX, distX, distX*0.2 do
        for zi=-distZ, distZ, distZ*0.2 do
            local xi2 = cosRot*xi + sinRot*zi;
            local zi2 = -sinRot*xi + cosRot*zi;

            raycastClosest(x+xi2, y+30, z+zi2, 0, -1, 0, "objectOverlapRaycastCallback", 40, PlacementScreen, PlacementScreen.objectCollisionMask);
            if PlacementScreen.tempHasObjectOverlap then
                return true;
            end;
        end;
    end;
end;

function PlacementScreen:objectOverlapCallback(transformId)
    if g_currentMission.nodeToVehicle[transformId] ~= nil or g_currentMission.players[transformId] ~= nil then
        PlacementScreen.tempHasObjectOverlap = true;
    end;
end;

function PlacementScreen:objectOverlapRaycastCallback(hitObjectId, x, y, z, distance)
    if hitObjectId ~= g_currentMission.terrainRootNode then
        PlacementScreen.tempHasObjectOverlap = true;
    end;
end;

g_placementScreen = PlacementScreen:new();
g_gui:loadGui(g_currentModDirectory.."PlacementScreen.xml", modName..".PlacementScreen", g_placementScreen);