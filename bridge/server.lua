

Bridge = Bridge or {}

local ESX, QBCore
local useOxInventory = GetResourceState('ox_inventory') == 'started'
local useQSInventory = GetResourceState('qs-inventory') == 'started'
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
    print('[ic3d_chess] No framework detected on server. Continuing with limited features.')
end

if useOxInventory then
    print('[ic3d_chess] Using ox_inventory')
elseif useQSInventory then
    print('[ic3d_chess] Using qs-inventory')
else
    print('[ic3d_chess] Using framework default inventory')
end

function Bridge.GetIdentifier(src)
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.identifier and xPlayer.identifier ~= '' then
            return xPlayer.identifier
        end
    end

    if (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.citizenid and Player.PlayerData.citizenid ~= '' then
            return Player.PlayerData.citizenid
        end
    end

    local license = nil
    if GetPlayerIdentifierByType then
        license = GetPlayerIdentifierByType(src, 'license')
    end
    if not license or license == '' then
        local ids = GetPlayerIdentifiers(src)
        if ids then
            for _, id in ipairs(ids) do
                if type(id) == 'string' and id:sub(1, 8) == 'license:' then
                    license = id
                    break
                end
            end
        end
    end
    if license and license ~= '' then return license end

    local ids = GetPlayerIdentifiers(src)
    if ids then
        for _, id in ipairs(ids) do
            if type(id) == 'string' and (id:sub(1,6) == 'steam:' or id:sub(1,8) == 'discord:' or id:sub(1,6) == 'fivem:') then
                return id
            end
        end
    end
    return 'player:' .. tostring(src)
end

function Bridge.GetPlayerName(src)
    local name = GetPlayerName(src)
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.getName then
            return xPlayer.getName()
        end
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.charinfo then
            return (Player.PlayerData.charinfo.firstname or '') .. ' ' .. (Player.PlayerData.charinfo.lastname or '')
        end
    end
    return name
end

function Bridge.GetPlayerGroup(src)
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.getGroup and xPlayer:getGroup() or (xPlayer and xPlayer.getGroup and xPlayer.getGroup() or 'user')
    elseif (useQBCore or useQBXCore) and QBCore then
        if QBCore.Functions.GetPermission then
            return QBCore.Functions.GetPermission(src)
        end
        local Player = QBCore.Functions.GetPlayer(src)
        return Player and Player.PlayerData and Player.PlayerData.group or 'user'
    end
    return 'user'
end

function Bridge.GetPlayerJob(src)
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.getJob then
            local job = xPlayer.getJob()
            local gradeNum = job.grade
            if type(job.grade) == 'table' then
                gradeNum = job.grade.level or job.grade.grade or 0
            end
            return {
                name = job.name,
                label = job.label,
                grade = tonumber(gradeNum) or 0,
                grade_name = job.grade_name,
                grade_label = job.grade_label
            }
        end
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.job then
            local job = Player.PlayerData.job
            return {
                name = job.name,
                label = job.label,
                grade = job.grade and job.grade.level or 0,
                grade_name = job.grade and job.grade.name or '',
                grade_label = job.grade and job.grade.name or ''
            }
        end
    end
    return nil
end

function Bridge.IsAdmin(src)
    local group = Bridge.GetPlayerGroup(src)
    if type(Config.AdminGroups) == 'table' then
        for _, g in ipairs(Config.AdminGroups) do
            if g == group then return true end
        end
    end

    if (useQBCore or useQBXCore) and QBCore and QBCore.Functions.HasPermission then
        if QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god') then
            return true
        end
    end

    if IsPlayerAceAllowed(src, 'ic3d_chess.admin') then
        return true
    end

    return false
end

function Bridge.AddMoney(src, account, amount)
    amount = tonumber(amount or 0) or 0
    if amount <= 0 then return false, 'invalid_amount' end

    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false, 'player_not_found' end
        account = (account == 'cash' and 'money') or (account or 'money')
        if xPlayer.addAccountMoney and (account == 'bank' or account == 'money') then
            xPlayer.addAccountMoney(account, amount)
            return true
        elseif xPlayer.addMoney and account == 'money' then
            xPlayer.addMoney(amount)
            return true
        end
        return false, 'esx_no_method'
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false, 'player_not_found' end
        account = (account == 'money' and 'cash') or (account or 'cash')
        if Player.Functions.AddMoney then
            local ok = Player.Functions.AddMoney(account, amount)
            return ok and true or false
        end
        return false, 'qb_no_method'
    end
    return false, 'no_framework'
end

function Bridge.AddItem(src, item, count, metadata)
    item = tostring(item or '')
    count = tonumber(count or 1) or 1
    if item == '' or count <= 0 then return false, 'invalid_item' end

    if useOxInventory then
        local ok = exports.ox_inventory:AddItem(src, item, count, metadata)
        return ok and true or false
    end

    if useQSInventory then
        local ok = exports['qs-inventory']:AddItem(src, item, count, nil, metadata)
        return ok and true or false
    end

    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false, 'player_not_found' end
        if xPlayer.addInventoryItem then
            xPlayer.addInventoryItem(item, count, metadata)
            return true
        end
        return false, 'esx_no_method'
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false, 'player_not_found' end
        if Player.Functions.AddItem then
            local ok = Player.Functions.AddItem(item, count, nil, metadata)
            return ok and true or false
        end
        return false, 'qb_no_method'
    end
    return false, 'no_framework'
end

function Bridge.RewardPlayer(src, reward)
    if type(reward) ~= 'table' then return false, 'invalid_reward' end
    if reward[1] ~= nil and reward.type == nil then
        for i = 1, #reward do
            local ok, err = Bridge.RewardPlayer(src, reward[i])
            if not ok then return false, err or ('reward_failed_' .. tostring(i)) end
        end
        return true
    end
    if not reward.type then return false, 'invalid_reward' end
    local t = reward.type
    if t == 'text' then
        return true
    elseif t == 'money' then
        return Bridge.AddMoney(src, reward.account or 'bank', tonumber(reward.amount or 0) or 0)
    elseif t == 'item' then
        return Bridge.AddItem(src, reward.item or reward.name, tonumber(reward.count or 1) or 1, reward.metadata)
    end
    return false, 'unknown_type'
end

function Bridge.GetItemCount(src, item)
    item = tostring(item or '')
    if item == '' then return 0 end

    if useOxInventory then
        local count = exports.ox_inventory:Search(src, 'count', item)
        return tonumber(count or 0) or 0
    end

    if useQSInventory then
        local count = exports['qs-inventory']:GetItemTotalAmount(src, item)
        return tonumber(count or 0) or 0
    end

    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return 0 end
        if xPlayer.getInventoryItem then
            local inv = xPlayer.getInventoryItem(item)
            return (inv and (inv.count or inv.amount)) or 0
        end
        return 0
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return 0 end
        if Player.Functions.GetItemByName then
            local it = Player.Functions.GetItemByName(item)
            return it and (it.amount or it.count or 0) or 0
        end
        return 0
    end

    return 0
end

function Bridge.RemoveItem(src, item, count)
    item = tostring(item or '')
    count = tonumber(count or 0) or 0
    if item == '' or count <= 0 then return false, 'invalid_item' end

    if useOxInventory then
        local ok = exports.ox_inventory:RemoveItem(src, item, count)
        return ok and true or false, ok and nil or 'ox_remove_failed'
    end

    if useQSInventory then
        local ok = exports['qs-inventory']:RemoveItem(src, item, count)
        return ok and true or false, ok and nil or 'qs_remove_failed'
    end

    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false, 'player_not_found' end
        if xPlayer.removeInventoryItem then
            xPlayer.removeInventoryItem(item, count)
            return true
        end
        return false, 'esx_no_method'
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false, 'player_not_found' end
        if Player.Functions.RemoveItem then
            local ok = Player.Functions.RemoveItem(item, count)
            return ok and true or false, ok and nil or 'qb_remove_failed'
        end
        return false, 'qb_no_method'
    end

    return false, 'no_framework'
end

function Bridge.GetFullName(src)
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            if xPlayer.getName then
                return xPlayer.getName()
            elseif xPlayer.name then
                return xPlayer.name
            end
        end
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.charinfo then
            local charinfo = Player.PlayerData.charinfo
            return (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
        end
    end
    return GetPlayerName(src) or ('Player ' .. tostring(src))
end

function Bridge.GetBank(src)
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local account = xPlayer.getAccount('bank')
            return account and account.money or 0
        end
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.money then
            return Player.PlayerData.money.bank or 0
        end
    end
    return 0
end

function Bridge.GetCash(src)
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local account = xPlayer.getAccount('money')
            if account then return account.money or 0 end
            if xPlayer.getMoney then return xPlayer.getMoney() or 0 end
        end
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.money then
            return Player.PlayerData.money.cash or 0
        end
    end
    return 0
end

function Bridge.RemoveBank(src, amount)
    amount = tonumber(amount or 0) or 0
    if amount <= 0 then return false end
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local account = xPlayer.getAccount('bank')
            if account and account.money >= amount then
                xPlayer.removeAccountMoney('bank', amount)
                return true
            end
        end
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.Functions.RemoveMoney then
            return Player.Functions.RemoveMoney('bank', amount)
        end
    end
    return false
end

function Bridge.RemoveCash(src, amount)
    amount = tonumber(amount or 0) or 0
    if amount <= 0 then return false end
    if useESX and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            if xPlayer.getMoney and xPlayer.getMoney() >= amount then
                xPlayer.removeMoney(amount)
                return true
            end
        end
    elseif (useQBCore or useQBXCore) and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.Functions.RemoveMoney then
            return Player.Functions.RemoveMoney('cash', amount)
        end
    end
    return false
end
