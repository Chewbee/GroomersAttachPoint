local modName = g_currentModName;

SellPlaceableEvent = {};
SellPlaceableEvent_mt = Class(SellPlaceableEvent, Event);

InitEventClass(SellPlaceableEvent, "SellPlaceableEvent");

function SellPlaceableEvent:emptyNew()
    local self = Event:new(SellPlaceableEvent_mt);
    return self;
end;

function SellPlaceableEvent:new(placeable)
    local self = SellPlaceableEvent:emptyNew()
    self.placeable = placeable;
    return self;
end;

function SellPlaceableEvent:newServerToClient(successful)
    local self = SellPlaceableEvent:emptyNew()
    self.successful = successful;
    return self;
end;

function SellPlaceableEvent:readStream(streamId, connection)
    if not connection:getIsServer() then
        local id = streamReadInt32(streamId);
        self.placeable = networkGetObject(id);
    else
        self.successful = streamReadBool(streamId);
    end;
    self:run(connection);
end;

function SellPlaceableEvent:writeStream(streamId, connection)
    if connection:getIsServer() then
        streamWriteInt32(streamId, networkGetObjectId(self.placeable));
    else
        streamWriteBool(streamId, self.successful);
    end;
end;

function SellPlaceableEvent:run(connection)
    if not connection:getIsServer() then
        local xmlFilename = self.placeable.configFileName:lower(); -- make sure the filename is lower case (e.g. due to convertFromNetworkFilename)
        local successful = false;
        if self.placeable ~= nil then
            local dataStoreItem = nil;
            if connection:getIsLocal() or g_currentMission.allowClientsSellVehicles then
                for i=1, table.getn(StoreItemsUtil.storeItems) do
                    local item = StoreItemsUtil.storeItems[i];
                    local filename = item.xmlFilename:lower();
                    if filename == xmlFilename then
                        dataStoreItem = item;
                        break;
                    end;
                end;
            end;
            if dataStoreItem ~= nil then
                if not self.placeable.isControlled or (self.placeable.isEntered and self.placeable.owner == connection) then
                    g_currentMission:removeVehicle(self.placeable);
                    g_currentMission:addSharedMoney(g_shopScreen:getSellPrice(dataStoreItem), "other");
                    successful = true;
                end;
            end;
        end;
        connection:sendEvent(SellPlaceableEvent:newServerToClient(successful));
    else
        if self.successful then
            g_placementScreen:onPlaceableSold();
        else
            g_placementScreen:onPlaceableSellFailed();
        end;
    end;
end;