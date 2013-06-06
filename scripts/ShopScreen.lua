-- @author  Stefan Geiger
-- @date  26/04/11
--
-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.

local modName = g_currentModName;

local old_onSellClick = ShopScreen.onSellClick;
local old_onBuyClick = ShopScreen.onBuyClick;
local old_updateBuyAndSellButtons = ShopScreen.updateBuyAndSellButtons;

ShopScreen.onBuyClick = function(self, item, outsideBuy)
    if not self.isSelling then
        local dataStoreItem = item;
        if (g_currentMission.missionStats.money >= dataStoreItem.price) then
            if dataStoreItem.species ~= nil and dataStoreItem.species ~= "" then
                if dataStoreItem.species == "placeable" then
                    ShopScreen_startPlacementMode(self, dataStoreItem, false);
                end;
            end;
        end;
    end;

    old_onBuyClick(self, item, outsideBuy);
end;

ShopScreen.onSellClick = function(self, item)
    if not self.isSelling then

        local dataStoreItem = item;

        if dataStoreItem.species ~= nil and dataStoreItem.species ~= "" then
            if dataStoreItem.species == "placeable" then
                ShopScreen_startPlacementMode(self, dataStoreItem, true);
            end;
        end;
    end;

    old_onSellClick(self, item);
end;

ShopScreen.updateBuyAndSellButtons = function(self)
    old_updateBuyAndSellButtons(self);

    -- update sell buttons of placeable objects
    for _, sellButton in pairs(self.sellButtonList) do
        local dataStoreItem = sellButton.shopItem;
        if dataStoreItem.species ~= nil and dataStoreItem.species ~= "" then
            if dataStoreItem.species == "placeable" then
                local num = Placeable.getNumPlaceables(dataStoreItem.xmlFilename);
                if num > 0 then
                    sellButton.disabled = false;
                end;
            end;
        end;
    end;
end;

function ShopScreen_startPlacementMode(self, item, isSellingMode)
    g_placementScreen:setPlacementItem(item, isSellingMode);
    g_gui:showGui(modName..".PlacementScreen");
end;
