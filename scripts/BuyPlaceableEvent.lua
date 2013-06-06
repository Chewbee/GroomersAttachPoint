local modName = g_currentModName;

BuyPlaceableEvent = {};
BuyPlaceableEvent_mt = Class(BuyPlaceableEvent, Event);

InitEventClass(BuyPlaceableEvent, "BuyPlaceableEvent");

function BuyPlaceableEvent:emptyNew()
    local self = Event:new(BuyPlaceableEvent_mt);
    return self;
end;

function BuyPlaceableEvent:new(filename, x,y,z, rx,ry,rz)
    local self = BuyPlaceableEvent:emptyNew()
    self.filename = filename;
    self.x = x;
    self.y = y;
    self.z = z;
    self.rx = rx;
    self.ry = ry;
    self.rz = rz;
    return self;
end;

function BuyPlaceableEvent:newServerToClient(successful)
    local self = BuyPlaceableEvent:emptyNew()
    self.successful = successful;
    return self;
end;

function BuyPlaceableEvent:readStream(streamId, connection)
    if not connection:getIsServer() then
        self.filename = Utils.convertFromNetworkFilename(streamReadString(streamId));
        self.x = streamReadFloat32(streamId);
        self.y = streamReadFloat32(streamId);
        self.z = streamReadFloat32(streamId);
        self.rx = streamReadFloat32(streamId);
        self.ry = streamReadFloat32(streamId);
        self.rz = streamReadFloat32(streamId);
    else
        self.successful = streamReadBool(streamId);
    end;
    self:run(connection);
end;

function BuyPlaceableEvent:writeStream(streamId, connection)
    if connection:getIsServer() then
        streamWriteString(streamId, Utils.convertToNetworkFilename(self.filename));
        streamWriteFloat32(streamId, self.x);
        streamWriteFloat32(streamId, self.y);
        streamWriteFloat32(streamId, self.z);
        streamWriteFloat32(streamId, self.rx);
        streamWriteFloat32(streamId, self.ry);
        streamWriteFloat32(streamId, self.rz);
    else
        streamWriteBool(streamId, self.successful);
    end;
end;

function BuyPlaceableEvent:run(connection)
    if not connection:getIsServer() then
        self.filename = self.filename:lower(); -- make sure the filename is lower case (e.g. due to convertFromNetworkFilename)

        local dataStoreItem = nil;
        for i=1, table.getn(StoreItemsUtil.storeItems) do
            local item = StoreItemsUtil.storeItems[i];
            local filename = item.xmlFilename:lower();
            if filename == self.filename then
                dataStoreItem = item;
                break;
            end;
        end;
        local sent = false;
        local successful = false;
        if dataStoreItem ~= nil then
            local placeable = PlacementScreen.loadPlaceableFromXML(dataStoreItem.xmlFilename, self.x,self.y,self.z, self.rx,self.ry,self.rz, false);
            successful = (placeable ~= nil);
            if successful then
                g_currentMission:addMoney(-dataStoreItem.price, g_currentMission:findUserIdByConnection(connection), "constructionCost");
            end;
        end;
        connection:sendEvent(BuyPlaceableEvent:newServerToClient(successful));
    else
        if self.successful then
            g_placementScreen:onPlaceableBought();
        else
            g_placementScreen:onPlaceableBuyFailed();
        end;
    end;
end;