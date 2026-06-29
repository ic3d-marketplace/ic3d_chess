





local E = ChessEngine









local Games = {}


local function dbg(...)
    if Config.Debug then print('[ic3d_chess]', ...) end
end

local function validLoc(locId)
    return type(locId) == 'number' and Config.Locations[locId] ~= nil
end

local function notify(src, key, ...)
    if not src or src == 'NPC' then return end
    TriggerClientEvent('ic3d_chess:notify', src, Config.L(key, ...))
end


local function isWaiting(g)
    return (not g.vsNpc) and (g.white == nil or g.black == nil)
end


local function clockLive(g)
    
    return Config.Clock.enabled and g.clockOn and not g.ended and not isWaiting(g)
end

local function startClock(g)
    if not Config.Clock.enabled then return end
    local secs = Config.Clock.minutes * 60
    g.wClock = secs
    g.bClock = secs
    g.clockOn = true
    g.clockLast = GetGameTimer()
end


local function accrue(g)
    if not clockLive(g) or not g.clockLast then return end
    local now = GetGameTimer()
    local dt = (now - g.clockLast) / 1000.0
    g.clockLast = now
    if g.state.turn == 'w' then g.wClock = g.wClock - dt else g.bClock = g.bClock - dt end
    if g.wClock < 0 then g.wClock = 0 end
    if g.bClock < 0 then g.bClock = 0 end
end


local function clockAfterMove(g, color)
    if not Config.Clock.enabled then return end
    accrue(g)
    local inc = Config.Clock.incrementSeconds or 0
    if color == 'w' then g.wClock = g.wClock + inc else g.bClock = g.bClock + inc end
    g.clockLast = GetGameTimer()
end

local function publicState(g)
    if not g then return { active = false } end
    local clock = nil
    if Config.Clock.enabled and g.wClock then
        clock = {
            w = math.max(0, math.floor(g.wClock)),
            b = math.max(0, math.floor(g.bClock)),
            running = clockLive(g) and g.state.turn or nil,
        }
    end
    return {
        active    = true,
        ended     = g.ended or false,
        reason    = g.endReason,
        vsNpc     = g.vsNpc or false,
        npc       = g.npcColor,            
        whiteName = g.whiteName or (g.white == nil and not g.vsNpc and 'Waiting...' or 'White'),
        blackName = g.blackName or (g.vsNpc and 'Computer' or 'Waiting...'),
        waiting   = isWaiting(g),
        board     = E.boardToList(g.state.board),
        turn      = g.state.turn,
        status    = g.state.status,
        castling  = g.state.castling,
        enPassant = g.state.enPassant,
        lastMove  = g.lastMove,
        winner    = g.winner,
        clock     = clock,
        bet       = g.bet or 0,
    }
end

local function broadcast(locId)
    local g = Games[locId]
    TriggerClientEvent('ic3d_chess:sync', -1, locId, publicState(g))
end

local function broadcastInactive(locId)
    TriggerClientEvent('ic3d_chess:sync', -1, locId, { active = false })
end


local function assignRole(src, locId, role)
    TriggerClientEvent('ic3d_chess:youAre', src, locId, role)
end

local function colorOfSrc(g, src)
    if g.white == src then return 'w' end
    if g.black == src then return 'b' end
    return nil
end


local useSql = GetResourceState('oxmysql') == 'started'

if Config.Ranking.enabled and useSql then
    CreateThread(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `ic3d_chess_ratings` (
                `identifier` VARCHAR(64) NOT NULL,
                `name` VARCHAR(64) DEFAULT NULL,
                `elo` INT NOT NULL DEFAULT 1000,
                `wins` INT NOT NULL DEFAULT 0,
                `losses` INT NOT NULL DEFAULT 0,
                `draws` INT NOT NULL DEFAULT 0,
                `games` INT NOT NULL DEFAULT 0,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`identifier`)
            )
        ]])
    end)
end

local function rankingOn() return Config.Ranking.enabled and useSql end

local function expectedScore(a, b) return 1.0 / (1.0 + 10.0 ^ ((b - a) / 400.0)) end


local function writeElo(identifier, name, myElo, oppElo, score, row, src)
    local k = Config.Ranking.kFactor
    local newElo = math.floor(myElo + k * (score - expectedScore(myElo, oppElo)) + 0.5)
    if newElo < 0 then newElo = 0 end
    local wins   = (row and row.wins or 0) + (score == 1 and 1 or 0)
    local losses = (row and row.losses or 0) + (score == 0 and 1 or 0)
    local draws  = (row and row.draws or 0) + (score == 0.5 and 1 or 0)
    local games  = (row and row.games or 0) + 1
    MySQL.prepare.await([[
        INSERT INTO `ic3d_chess_ratings` (identifier,name,elo,wins,losses,draws,games)
        VALUES (?,?,?,?,?,?,?)
        ON DUPLICATE KEY UPDATE name=VALUES(name), elo=VALUES(elo),
            wins=VALUES(wins), losses=VALUES(losses), draws=VALUES(draws), games=VALUES(games)
    ]], { identifier, name, newElo, wins, losses, draws, games })
    if src then notify(src, 'rating_change', newElo, newElo - myElo) end
end


local function ratedResult(g, winnerColor)
    if not rankingOn() then return end

    if g.vsNpc then
        if not Config.Ranking.rateVsNpc or not g.whiteId then return end
        local oppElo = Config.Ranking.npcElo[g.difficulty] or Config.Ranking.startElo
        local score = (winnerColor == 'draw') and 0.5 or (winnerColor == 'w' and 1 or 0)
        CreateThread(function()
            local row = MySQL.single.await('SELECT * FROM `ic3d_chess_ratings` WHERE identifier=?', { g.whiteId })
            writeElo(g.whiteId, g.whiteName, row and row.elo or Config.Ranking.startElo, oppElo, score, row,
                type(g.white) == 'number' and g.white or nil)
        end)
        return
    end

    if not g.whiteId or not g.blackId then return end
    local wScore = (winnerColor == 'draw') and 0.5 or (winnerColor == 'w' and 1 or 0)
    local bScore = 1.0 - wScore
    CreateThread(function()
        local wRow = MySQL.single.await('SELECT * FROM `ic3d_chess_ratings` WHERE identifier=?', { g.whiteId })
        local bRow = MySQL.single.await('SELECT * FROM `ic3d_chess_ratings` WHERE identifier=?', { g.blackId })
        local wElo = wRow and wRow.elo or Config.Ranking.startElo
        local bElo = bRow and bRow.elo or Config.Ranking.startElo
        writeElo(g.whiteId, g.whiteName, wElo, bElo, wScore, wRow, type(g.white) == 'number' and g.white or nil)
        writeElo(g.blackId, g.blackName, bElo, wElo, bScore, bRow, type(g.black) == 'number' and g.black or nil)
    end)
end

if lib and lib.callback then
    lib.callback.register('ic3d_chess:getLeaderboard', function()
        local rows
        if rankingOn() then
            rows = MySQL.query.await([[
                SELECT name, elo, wins, losses, draws, games
                FROM `ic3d_chess_ratings` ORDER BY elo DESC, games DESC LIMIT ?
            ]], { Config.Ranking.leaderboardSize })
        end
        
        if not rows or #rows == 0 then
            return Config.Ranking.mockData or {}
        end
        return rows
    end)

    lib.callback.register('ic3d_chess:getMyRating', function(src)
        if not rankingOn() then return { elo = Config.Ranking.startElo, games = 0, ranked = false } end
        local id = Bridge.GetIdentifier(src)
        local row = MySQL.single.await('SELECT elo,wins,losses,draws,games FROM `ic3d_chess_ratings` WHERE identifier=?', { id })
        if row then row.ranked = true; return row end
        return { elo = Config.Ranking.startElo, wins = 0, losses = 0, draws = 0, games = 0, ranked = false }
    end)
end


local function giveRewards(g, winnerColor)
    if not Config.Rewards.enabled then return end
    if winnerColor ~= 'w' and winnerColor ~= 'b' then return end
    local winSrc = (winnerColor == 'w') and g.white or g.black
    if type(winSrc) ~= 'number' then return end 

    local reward = g.vsNpc and Config.Rewards.vsNpcWin or Config.Rewards.vsPlayerWin
    if reward and #reward > 0 then
        local ok = Bridge.RewardPlayer(winSrc, reward)
        if ok then notify(winSrc, 'reward_received') end
    end
end


local function curr() return Config.Betting.currency or '$' end

local function takeStake(src, amount)
    if amount <= 0 then return true end
    if Config.Betting.account == 'cash' then return Bridge.RemoveCash(src, amount) end
    return Bridge.RemoveBank(src, amount)
end

local function payout(src, amount)
    if amount <= 0 then return end
    Bridge.AddMoney(src, Config.Betting.account, amount)
end


local function refundStakes(g)
    if not g.bet or g.bet <= 0 then return end
    local stake = g.bet
    g.bet = 0
    if type(g.white) == 'number' and g.whitePaid then payout(g.white, stake); notify(g.white, 'bet_refunded', curr(), stake) end
    if type(g.black) == 'number' and g.blackPaid then payout(g.black, stake); notify(g.black, 'bet_refunded', curr(), stake) end
end


local function settleBets(g, winnerColor)
    if not g.bet or g.bet <= 0 then return end
    local stake = g.bet
    g.bet = 0
    if winnerColor == 'draw' then
        if type(g.white) == 'number' and g.whitePaid then payout(g.white, stake); notify(g.white, 'bet_refunded', curr(), stake) end
        if type(g.black) == 'number' and g.blackPaid then payout(g.black, stake); notify(g.black, 'bet_refunded', curr(), stake) end
        return
    end
    local potBase = stake
    if (g.whitePaid and g.blackPaid) or (g.vsNpc and (g.whitePaid or g.blackPaid)) then potBase = stake * 2 end
    local cut = math.floor(potBase * (Config.Betting.houseCut or 0))
    local winnings = potBase - cut
    local winSrc = (winnerColor == 'w') and g.white or g.black
    if type(winSrc) == 'number' then payout(winSrc, winnings); notify(winSrc, 'bet_won', curr(), winnings) end
end


local function endGame(locId, winnerColor, reason)
    local g = Games[locId]
    if not g or g.ended then return end
    g.ended = true
    g.winner = winnerColor
    g.endReason = reason
    g.clockOn = false

    local whiteSrc = type(g.white) == 'number' and g.white or nil
    local blackSrc = type(g.black) == 'number' and g.black or nil

    if reason == 'checkmate' or reason == 'time' then
        if winnerColor == 'w' then
            notify(whiteSrc, 'you_win'); notify(blackSrc, 'you_lose')
        else
            notify(blackSrc, 'you_win'); notify(whiteSrc, 'you_lose')
        end
    elseif reason == 'stalemate' then
        notify(whiteSrc, 'stalemate'); notify(blackSrc, 'stalemate')
    elseif reason == 'draw' then
        notify(whiteSrc, 'draw'); notify(blackSrc, 'draw')
    elseif reason == 'resign' then
        if winnerColor == 'w' then
            notify(whiteSrc, 'opponent_resigned'); notify(blackSrc, 'you_resigned')
        else
            notify(blackSrc, 'opponent_resigned'); notify(whiteSrc, 'you_resigned')
        end
    elseif reason == 'left' then
        if winnerColor == 'w' then notify(whiteSrc, 'opponent_resigned')
        elseif winnerColor == 'b' then notify(blackSrc, 'opponent_resigned') end
    end

    giveRewards(g, winnerColor)
    ratedResult(g, winnerColor)
    settleBets(g, winnerColor)

    
    broadcast(locId)
    SetTimeout(Config.ResetDelay, function()
        if Games[locId] == g then
            Games[locId] = nil
            broadcastInactive(locId)
        end
    end)
end

local function checkGameOver(locId)
    local g = Games[locId]
    if not g then return false end
    local st = g.state.status
    if st == 'checkmate' then
        endGame(locId, E.winner(g.state), 'checkmate'); return true
    elseif st == 'stalemate' then
        endGame(locId, 'draw', 'stalemate'); return true
    elseif st == 'draw' then
        endGame(locId, 'draw', 'draw'); return true
    end
    return false
end


local function scheduleAi(locId)
    local g = Games[locId]
    if not g or g.ended or not g.vsNpc then return end
    if g.state.turn ~= g.npcColor then return end
    if g.thinking then return end
    g.thinking = true

    local think = math.random(Config.NPC.thinkTime.min, Config.NPC.thinkTime.max)
    SetTimeout(think, function()
        local game = Games[locId]
        if not game or game ~= g or game.ended then return end
        if game.state.turn ~= game.npcColor then game.thinking = false; return end

        local depth = Config.NPC.difficulties[game.difficulty] or 2
        local randomize = (game.difficulty == 'easy')
        local move = ChessAI.choose(game.state, depth, randomize)
        game.thinking = false
        if not move then
            
            game.state.status = E.computeStatus(game.state)
            broadcast(locId)
            checkGameOver(locId)
            return
        end

        clockAfterMove(game, game.state.turn)
        game.state = E.applyMove(game.state, move, false)
        game.lastMove = { from = move.from, to = move.to }
        broadcast(locId)
        checkGameOver(locId)
    end)
end



local function validBet(amount, allowedList)
    amount = tonumber(amount) or 0
    if amount <= 0 then return 0 end
    for _, a in ipairs(allowedList) do if a == amount then return amount end end
    return 0
end


RegisterNetEvent('ic3d_chess:requestSeat', function(locId, mode, side, bet)
    local src = source
    if not validLoc(locId) then return end
    local g = Games[locId]

    if mode == 'create' then
        if g then notify(src, 'game_full'); return end

        side = (side == 'w' or side == 'b') and side or (math.random(2) == 1 and 'w' or 'b')
        bet = Config.Betting.enabled and validBet(bet, Config.Betting.amounts) or 0
        if bet > 0 and not takeStake(src, bet) then notify(src, 'bet_insufficient'); return end

        local game = {
            state = E.newGame(), vsNpc = false,
            bet = bet, account = Config.Betting.account,
        }
        local name, id = Bridge.GetFullName(src), Bridge.GetIdentifier(src)
        if side == 'w' then
            game.white = src; game.whiteId = id; game.whiteName = name; game.whitePaid = (bet > 0)
        else
            game.black = src; game.blackId = id; game.blackName = name; game.blackPaid = (bet > 0)
        end
        Games[locId] = game
        assignRole(src, locId, side)
        notify(src, 'game_started')
        broadcast(locId)

    elseif mode == 'join' then
        if not g or g.vsNpc or not isWaiting(g) or g.white == src or g.black == src then
            notify(src, 'game_full'); return
        end
        if g.bet and g.bet > 0 and not takeStake(src, g.bet) then notify(src, 'bet_insufficient'); return end

        local name, id = Bridge.GetFullName(src), Bridge.GetIdentifier(src)
        local role, oppSrc
        if g.white == nil then
            g.white = src; g.whiteId = id; g.whiteName = name; g.whitePaid = (g.bet or 0) > 0
            role, oppSrc = 'w', g.black
        else
            g.black = src; g.blackId = id; g.blackName = name; g.blackPaid = (g.bet or 0) > 0
            role, oppSrc = 'b', g.white
        end
        startClock(g)
        assignRole(src, locId, role)
        notify(src, 'you_joined', (role == 'w') and g.blackName or g.whiteName)
        notify(oppSrc, 'opponent_joined', name)
        broadcast(locId)
    end
end)

RegisterNetEvent('ic3d_chess:startVsNpc', function(locId, difficulty, side, bet)
    local src = source
    if not validLoc(locId) then return end
    if not Config.NPC.enabled then notify(src, 'no_npc'); return end
    if Games[locId] then notify(src, 'game_full'); return end
    if not Config.NPC.difficulties[difficulty] then
        difficulty = Config.NPC.defaultDifficulty
    end

    local playerSide = (side == 'w' or side == 'b') and side or (math.random(2) == 1 and 'w' or 'b')
    local npcColor = E.opp(playerSide)
    bet = (Config.Betting.enabled and Config.Betting.allowVsNpc) and validBet(bet, Config.Betting.amounts) or 0
    if bet > 0 and not takeStake(src, bet) then notify(src, 'bet_insufficient'); return end

    local game = {
        state = E.newGame(), vsNpc = true, npcColor = npcColor, difficulty = difficulty,
        bet = bet, account = Config.Betting.account,
    }
    local name, id = Bridge.GetFullName(src), Bridge.GetIdentifier(src)
    local botName = 'Computer (' .. difficulty .. ')'
    if playerSide == 'w' then
        game.white = src; game.whiteId = id; game.whiteName = name; game.whitePaid = (bet > 0)
        game.black = 'NPC'; game.blackName = botName
    else
        game.black = src; game.blackId = id; game.blackName = name; game.blackPaid = (bet > 0)
        game.white = 'NPC'; game.whiteName = botName
    end
    Games[locId] = game
    startClock(game)
    assignRole(src, locId, playerSide)
    broadcast(locId)
    if npcColor == game.state.turn then scheduleAi(locId) end 
end)

RegisterNetEvent('ic3d_chess:move', function(locId, from, to, promo)
    local src = source
    if not validLoc(locId) then return end
    local g = Games[locId]
    if not g or g.ended then return end

    local color = colorOfSrc(g, src)
    if not color then return end
    if isWaiting(g) then return end 
    if g.state.turn ~= color then notify(src, 'not_your_turn'); return end
    if type(from) ~= 'number' or type(to) ~= 'number' then return end

    local move = E.findMove(g.state, from, to, promo)
    if not move then notify(src, 'illegal_move'); return end

    clockAfterMove(g, color)
    g.state = E.applyMove(g.state, move, false)
    g.lastMove = { from = from, to = to }
    broadcast(locId)

    if checkGameOver(locId) then return end

    if g.state.status == 'check' then
        local toMove = (g.state.turn == 'w') and g.white or g.black
        notify(toMove, 'check')
    end

    if g.vsNpc then scheduleAi(locId) end
end)

RegisterNetEvent('ic3d_chess:resign', function(locId)
    local src = source
    if not validLoc(locId) then return end
    local g = Games[locId]
    if not g or g.ended then return end
    local color = colorOfSrc(g, src)
    if not color then return end
    endGame(locId, E.opp(color), 'resign')
end)

RegisterNetEvent('ic3d_chess:leave', function(locId)
    local src = source
    if not validLoc(locId) then return end
    local g = Games[locId]
    if not g then return end
    local color = colorOfSrc(g, src)
    if not color then return end

    if g.ended then return end

    
    if g.vsNpc or isWaiting(g) then
        refundStakes(g)
        Games[locId] = nil
        broadcastInactive(locId)
        return
    end

    
    endGame(locId, E.opp(color), 'left')
end)


RegisterNetEvent('ic3d_chess:requestSync', function(locId)
    local src = source
    if not validLoc(locId) then return end
    TriggerClientEvent('ic3d_chess:sync', src, locId, publicState(Games[locId]))
end)


AddEventHandler('playerDropped', function()
    local src = source
    for locId, g in pairs(Games) do
        if not g.ended then
            local color = colorOfSrc(g, src)
            if color then
                if g.vsNpc or isWaiting(g) then
                    refundStakes(g)
                    Games[locId] = nil
                    broadcastInactive(locId)
                else
                    endGame(locId, E.opp(color), 'left')
                end
            end
        end
    end
end)


if Config.Clock.enabled then
    CreateThread(function()
        while true do
            Wait(1000)
            for locId, g in pairs(Games) do
                if clockLive(g) then
                    accrue(g)
                    if g.wClock <= 0 then
                        endGame(locId, 'b', 'time')
                    elseif g.bClock <= 0 then
                        endGame(locId, 'w', 'time')
                    end
                end
            end
        end
    end)
end


RegisterCommand('chessreset', function(source, args)
    if source ~= 0 and not Bridge.IsAdmin(source) then return end
    local locId = tonumber(args[1])
    if locId and validLoc(locId) then
        Games[locId] = nil
        broadcastInactive(locId)
        print(('[ic3d_chess] table %d reset'):format(locId))
    else
        for id in pairs(Games) do
            Games[id] = nil
            broadcastInactive(id)
        end
        print('[ic3d_chess] all tables reset')
    end
end, false)

dbg('server loaded')
