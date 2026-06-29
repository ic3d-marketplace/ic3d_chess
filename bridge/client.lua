

Bridge = Bridge or {}

local ESX, QBCore
local useESX = GetResourceState('es_extended') == 'started'
local useQBCore = GetResourceState('qb-core') == 'started'
local useQBXCore = (GetResourceState('qbx-core') == 'started') or (GetResourceState('qbx_core') == 'started')

if useESX then
    ESX = exports['es_extended']:getSharedObject()
elseif useQBCore or useQBXCore then
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('qbx-core') == 'started' then
        QBCore = exports['qbx-core']:GetCoreObject()
    elseif GetResourceState('qbx_core') == 'started' then
        QBCore = exports['qbx_core']:GetCoreObject()
    end
else
    print('[ic3d_chess] No framework detected on client. Continuing with limited features.')
end

function Bridge.GetLocalPlayerName()
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerData()
        if xPlayer and xPlayer.firstName then
            return xPlayer.firstName .. ' ' .. (xPlayer.lastName or '')
        end
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayerData()
        if Player and Player.charinfo then
            return (Player.charinfo.firstname or '') .. ' ' .. (Player.charinfo.lastname or '')
        end
    end
    return GetPlayerName(PlayerId())
end

function Bridge.GetIdentifier()
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerData()
        if xPlayer and xPlayer.identifier then
            return xPlayer.identifier
        end
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayerData()
        if Player and Player.citizenid then
            return Player.citizenid
        end
    end
    return nil
end

local useOxInventory = GetResourceState('ox_inventory') == 'started'
local useQSInventory = GetResourceState('qs-inventory') == 'started'

function Bridge.GetItemLabel(itemName)
    if not itemName then return 'Unknown Item' end

    if useOxInventory then
        local itemData = exports.ox_inventory:Items(itemName)
        if itemData and itemData.label then
            return itemData.label
        end
    end

    if useQSInventory then
        local success, itemData = pcall(function()
            return exports['qs-inventory']:GetItemData(itemName)
        end)
        if success and itemData and itemData.label then
            return itemData.label
        end
    end

    if (useQBCore or useQBXCore) and QBCore then
        local items = QBCore.Shared.Items
        if items and items[itemName] and items[itemName].label then
            return items[itemName].label
        end
    end

    if useESX and ESX then
        local success, items = pcall(function()
            return ESX.GetItems and ESX.GetItems() or nil
        end)
        if success and items and items[itemName] and items[itemName].label then
            return items[itemName].label
        end
    end

    return itemName:gsub("^%l", string.upper):gsub("_", " ")
end

function Bridge.GetItemCount(itemName)
    if not itemName then return 0 end

    if useOxInventory then
        local count = exports.ox_inventory:Search('count', itemName)
        return tonumber(count or 0) or 0
    end

    if useQSInventory then
        local success, inv = pcall(function()
            return exports['qs-inventory']:getUserInventory()
        end)
        if success and inv then
            for _, v in pairs(inv) do
                if v.name == itemName then
                    return tonumber(v.amount or v.count or 0) or 0
                end
            end
        end
        return 0
    end

    if (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayerData()
        if Player and Player.items then
            for _, v in pairs(Player.items) do
                if v.name == itemName then return tonumber(v.amount or v.count or 0) or 0 end
            end
        end
        return 0
    end

    return 0
end
