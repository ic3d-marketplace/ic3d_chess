





local E = ChessEngine

local Loc      = {}   
local States   = {}   
local seated   = nil  
local chessCam = nil
local legalMap = {}   
local selectedSq = nil
local dragging = false
local dragHover = nil
local lastResultLoc = nil
local menuLoc = nil
local pending = nil 
local menuScreen = 'root' 

local DEFAULT_BOARD = E.boardToList(E.newGame().board)

local useTarget = (Config.Interact == 'target')
    or (Config.Interact == 'auto' and GetResourceState('ox_target') == 'started')

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
local function round(v) return math.floor(v + 0.5) end


local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 500 do Wait(0); tries = tries + 1 end
    return HasModelLoaded(hash) and hash or nil
end

local function loadAnim(dict)
    RequestAnimDict(dict)
    local tries = 0
    while not HasAnimDictLoaded(dict) and tries < 200 do Wait(0); tries = tries + 1 end
end


local function squareOffset(sq)
    local f = sq % 8
    local r = math.floor(sq / 8)
    return Config.SquareOrigin.x + f * Config.SquareStep,
           Config.SquareOrigin.y + r * Config.SquareStep,
           Config.SquareOrigin.z
end

local function cellWorld(board, sq, extraZ)
    local ox, oy, oz = squareOffset(sq)
    return GetOffsetFromEntityInWorldCoords(board, ox, oy, oz + (extraZ or 0.0))
end

local function pieceHeading(code)
    return (string.sub(code, 1, 1) == 'w') and Config.PieceHeading.white or Config.PieceHeading.black
end

local function attachPieceToCell(board, ent, sq, code, extraZ)
    local ox, oy, oz = squareOffset(sq)
    AttachEntityToEntity(ent, board, 0, ox, oy, oz + (extraZ or 0.0),
        0.0, 0.0, pieceHeading(code), false, false, false, false, 2, true)
end


local function spawnPiece(locId, sq, code, extraZ)
    local l = Loc[locId]
    if not l or not l.board or not DoesEntityExist(l.board) then return nil end
    local color = string.sub(code, 1, 1)
    local ptype = string.sub(code, 2, 2)
    local model = (color == 'w') and Config.Models.white[ptype] or Config.Models.black[ptype]
    local hash = loadModel(model)
    if not hash then return nil end

    local bc = GetEntityCoords(l.board)
    local obj = CreateObject(hash, bc.x, bc.y, bc.z + 1.0, false, false, false)
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(hash)
    attachPieceToCell(l.board, obj, sq, code, extraZ)
    return obj
end

local function renderBoard(locId, boardList)
    local l = Loc[locId]
    if not l or not l.board or not DoesEntityExist(l.board) then return end
    l.pieces = l.pieces or {}
    for sq = 0, 63 do
        local code = boardList[sq + 1]
        if code == false or code == nil then code = nil end
        local cur = l.pieces[sq]
        if not code then
            if cur then
                if DoesEntityExist(cur.ent) then DeleteEntity(cur.ent) end
                l.pieces[sq] = nil
            end
        elseif not (cur and cur.code == code and DoesEntityExist(cur.ent)) then
            if cur and DoesEntityExist(cur.ent) then DeleteEntity(cur.ent) end
            local ent = spawnPiece(locId, sq, code)
            if ent then l.pieces[sq] = { ent = ent, code = code } end
        end
    end
end

local function clearPieces(locId)
    local l = Loc[locId]
    if not l or not l.pieces then return end
    for sq, p in pairs(l.pieces) do
        if DoesEntityExist(p.ent) then DeleteEntity(p.ent) end
        l.pieces[sq] = nil
    end
end


local FULL = { P = 8, N = 2, B = 2, R = 2, Q = 1 }
local ORDER = { 'Q', 'R', 'B', 'N', 'P' }

local function renderCaptured(locId, boardList)
    if not Config.Captured.enabled then return end
    local l = Loc[locId]
    if not l or not l.board or not DoesEntityExist(l.board) then return end

    local presW, presB = {}, {}
    for sq = 0, 63 do
        local c = boardList[sq + 1]
        if c and c ~= false then
            local col, t = string.sub(c, 1, 1), string.sub(c, 2, 2)
            if col == 'w' then presW[t] = (presW[t] or 0) + 1 else presB[t] = (presB[t] or 0) + 1 end
        end
    end

    local whiteLost, blackLost = {}, {}
    for _, t in ipairs(ORDER) do
        for _ = 1, (FULL[t] - (presW[t] or 0)) do whiteLost[#whiteLost + 1] = 'w' .. t end
        for _ = 1, (FULL[t] - (presB[t] or 0)) do blackLost[#blackLost + 1] = 'b' .. t end
    end

    local sig = table.concat(whiteLost) .. '|' .. table.concat(blackLost)
    if sig == l.capturedSig then return end
    l.capturedSig = sig

    l.captured = l.captured or {}
    for _, e in ipairs(l.captured) do if DoesEntityExist(e) then DeleteEntity(e) end end
    l.captured = {}

    local C = Config.Captured
    local function placeList(list, sideSign)
        for i, code in ipairs(list) do
            local idx = i - 1
            local col = math.floor(idx / C.perCol)
            local row = idx % C.perCol
            local x = sideSign * (C.baseX + col * C.colStep)
            local y = -0.21 + row * C.stepY
            local model = (string.sub(code, 1, 1) == 'w') and Config.Models.white[string.sub(code, 2, 2)]
                or Config.Models.black[string.sub(code, 2, 2)]
            local hash = loadModel(model)
            if hash then
                local bc = GetEntityCoords(l.board)
                local obj = CreateObject(hash, bc.x, bc.y, bc.z + 1.0, false, false, false)
                SetEntityCollision(obj, false, false)
                SetModelAsNoLongerNeeded(hash)
                AttachEntityToEntity(obj, l.board, 0, x, y, Config.SquareOrigin.z,
                    0.0, 0.0, pieceHeading(code), false, false, false, false, 2, true)
                l.captured[#l.captured + 1] = obj
            end
        end
    end
    placeList(whiteLost, 1.0)   
    placeList(blackLost, -1.0)  
end


local function playSeatAnim(ped, clip, loop)
    loadAnim(Config.Anim.dict)
    TaskPlayAnim(ped, Config.Anim.dict, clip, 8.0, -8.0, -1, loop and 1 or 0, 0.0, false, false, false)
end

local function seatPedAtChair(ped, chair, pedOff)
    pedOff = pedOff or vector3(0.0, 0.0, -0.65)
    local pos = GetOffsetFromEntityInWorldCoords(chair, pedOff.x, pedOff.y, pedOff.z)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(chair))
    FreezeEntityPosition(ped, true)
    playSeatAnim(ped, Config.Anim.idle, true)
end


local function removeNpc(locId)
    local l = Loc[locId]
    if l and l.npc then
        if DoesEntityExist(l.npc) then DeleteEntity(l.npc) end
        l.npc = nil
    end
end

local function ensureNpc(locId, pub)
    local l = Loc[locId]
    if not l then return end
    if not (pub.active and pub.vsNpc and pub.npc) then removeNpc(locId); return end
    local chair = (pub.npc == 'w') and l.chairWhite or l.chairBlack
    if not chair or not DoesEntityExist(chair) then return end
    if not l.npc or not DoesEntityExist(l.npc) then
        local hash = loadModel(Config.NPC.model)
        if not hash then return end
        local seat = (pub.npc == 'w') and Config.Seats.white or Config.Seats.black
        local off = seat.ped or vector3(0.0, 0.0, -0.65)
        local pos = GetOffsetFromEntityInWorldCoords(chair, off.x, off.y, off.z)
        local ped = CreatePed(4, hash, pos.x, pos.y, pos.z, GetEntityHeading(chair), false, false)
        SetModelAsNoLongerNeeded(hash)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        l.npc = ped
    end
    local clip = (pub.turn == pub.npc and not pub.ended) and Config.Anim.move or Config.Anim.idle
    playSeatAnim(l.npc, clip, true)
end


local function spawnChair(tableObj, seat)
    local hash = loadModel(Config.Models.chair)
    if not hash then return nil end
    local pos = GetOffsetFromEntityInWorldCoords(tableObj, seat.chair.x, seat.chair.y, seat.chair.z)
    local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 5.0, false)
    if found then pos = vector3(pos.x, pos.y, gz) end
    local chair = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(chair, GetEntityHeading(tableObj) + seat.heading)
    PlaceObjectOnGroundProperly(chair)
    FreezeEntityPosition(chair, true)
    return chair
end

local openMenu 

local function addTarget(locId, ent)
    if not useTarget then return end
    exports.ox_target:addLocalEntity(ent, {
        {
            name = 'ic3d_chess_' .. locId,
            icon = 'fas fa-chess',
            label = Config.L('menu_title'),
            distance = Config.InteractDist,
            canInteract = function() return seated == nil end,
            onSelect = function() openMenu(locId) end,
        },
    })
end

local function spawnLocationProps(locId)
    local loc = Config.Locations[locId]
    if not loc or Loc[locId] then return end
    local tableHash = loadModel(Config.Models.table)
    local boardHash = loadModel(Config.Models.board)
    if not tableHash or not boardHash then return end

    local c = loc.coords
    local z = c.z
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 3.0, false)
    if found then z = gz end

    local tableObj = CreateObject(tableHash, c.x, c.y, z, false, false, false)
    SetEntityHeading(tableObj, loc.heading or 0.0)
    PlaceObjectOnGroundProperly(tableObj)
    FreezeEntityPosition(tableObj, true)
    SetModelAsNoLongerNeeded(tableHash)

    local tc = GetEntityCoords(tableObj)
    local boardObj = CreateObject(boardHash, tc.x, tc.y, tc.z + 1.0, false, false, false)
    SetEntityCollision(boardObj, false, false)
    AttachEntityToEntity(boardObj, tableObj, 0,
        Config.BoardOffset.x, Config.BoardOffset.y, Config.BoardOffset.z,
        0.0, 0.0, 0.0, false, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(boardHash)

    Loc[locId] = {
        table = tableObj, board = boardObj,
        chairWhite = spawnChair(tableObj, Config.Seats.white),
        chairBlack = spawnChair(tableObj, Config.Seats.black),
        pieces = {}, captured = {}, npc = nil,
    }
    addTarget(locId, tableObj)

    local pub = States[locId]
    if pub and pub.active then
        renderBoard(locId, pub.board); renderCaptured(locId, pub.board); ensureNpc(locId, pub)
    else
        renderBoard(locId, DEFAULT_BOARD); renderCaptured(locId, DEFAULT_BOARD)
    end
end

local function despawnLocationProps(locId)
    if seated and seated.locId == locId then return end
    local l = Loc[locId]
    if not l then return end
    clearPieces(locId)
    removeNpc(locId)
    for _, e in ipairs(l.captured or {}) do if DoesEntityExist(e) then DeleteEntity(e) end end
    if useTarget and l.table and DoesEntityExist(l.table) then
        exports.ox_target:removeLocalEntity(l.table, 'ic3d_chess_' .. locId)
    end
    for _, key in ipairs({ 'chairWhite', 'chairBlack', 'board', 'table' }) do
        if l[key] and DoesEntityExist(l[key]) then DeleteEntity(l[key]) end
    end
    Loc[locId] = nil
end


local function computeLegalMap(pub, role)
    legalMap = {}
    if not pub or not pub.active or pub.ended or pub.waiting then return end
    if pub.turn ~= role then return end
    local st = {
        board = E.listToBoard(pub.board),
        turn = pub.turn,
        castling = pub.castling or { wK = false, wQ = false, bK = false, bQ = false },
        enPassant = pub.enPassant,
    }
    local moves = E.generateLegalMoves(st)
    for i = 1, #moves do
        local m = moves[i]
        legalMap[m.from] = legalMap[m.from] or {}
        local e = legalMap[m.from][m.to] or { promo = false }
        if m.promo then e.promo = true end
        legalMap[m.from][m.to] = e
    end
end


local function startCam(board, role)
    local center = GetOffsetFromEntityInWorldCoords(board, 0.0, 0.0, 0.0)
    local sign = (role == 'w') and -1.0 or 1.0
    local cp = GetOffsetFromEntityInWorldCoords(board, 0.0, sign * Config.Camera.back, Config.Camera.height)
    chessCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cp.x, cp.y, cp.z, 0.0, 0.0, 0.0, Config.Camera.fov, false, 0)
    PointCamAtCoord(chessCam, center.x, center.y, center.z)
    SetCamActive(chessCam, true)
    RenderScriptCams(true, true, Config.Camera.transitionMs, true, true)
end

local function stopCam()
    if chessCam then
        RenderScriptCams(false, true, Config.Camera.transitionMs, true, true)
        DestroyCam(chessCam, false)
        chessCam = nil
    end
end



local function showResultShard(outcome, sub)
    local sf = RequestScaleformMovie('MP_BIG_MESSAGE_FREEMODE')
    local t0 = GetGameTimer()
    while not HasScaleformMovieLoaded(sf) and GetGameTimer() - t0 < 2000 do Wait(0) end
    if not HasScaleformMovieLoaded(sf) then return end

    local title = (outcome == 'win' and Config.L('result_win'))
        or (outcome == 'lose' and Config.L('result_lose'))
        or Config.L('result_draw')

    if outcome == 'lose' then
        BeginScaleformMovieMethod(sf, 'SHOW_SHARD_WASTED_MP_MESSAGE')
        ScaleformMovieMethodAddParamPlayerNameString(title)
        ScaleformMovieMethodAddParamPlayerNameString(sub or '')
        EndScaleformMovieMethod()
    else
        BeginScaleformMovieMethod(sf, 'SHOW_SHARD_CENTERED_MP_MESSAGE')
        ScaleformMovieMethodAddParamPlayerNameString(title)
        ScaleformMovieMethodAddParamPlayerNameString(sub or '')
        EndScaleformMovieMethod()
    end

    CreateThread(function()
        local stop = GetGameTimer() + 5000
        while GetGameTimer() < stop do
            DrawScaleformMovieFullscreen(sf, 255, 255, 255, 255, 0)
            Wait(0)
        end
        SetScaleformMovieAsNoLongerNeeded(sf)
    end)
end


local function hudPayload(pub, role)
    return {
        role      = role,
        whiteName = pub.whiteName,
        blackName = pub.blackName,
        turn      = pub.turn,
        status    = pub.status,
        ended     = pub.ended,
        waiting   = pub.waiting,
        vsNpc     = pub.vsNpc,
        npc       = pub.npc,
    }, pub.clock
end

local function showHud(pub, role)
    local h, c = hudPayload(pub, role)
    SendNUIMessage({ action = 'showHud', hud = h, clock = c })
end

local function updateHud(pub, role)
    local h, c = hudPayload(pub, role)
    SendNUIMessage({ action = 'updateHud', hud = h, clock = c })
end

local function hideHud()
    SendNUIMessage({ action = 'hideHud' })
end


local function lowerSelected()
    if selectedSq == nil then return end
    local l = Loc[seated and seated.locId]
    local pc = l and l.pieces[selectedSq]
    if pc and DoesEntityExist(pc.ent) then attachPieceToCell(l.board, pc.ent, selectedSq, pc.code, 0.0) end
end

local function clearSelection()
    lowerSelected()
    selectedSq = nil
    dragging = false
    dragHover = nil
end

local promotionMenu 

local function sendMove(from, to, promo)
    TriggerServerEvent('ic3d_chess:move', seated.locId, from, to, promo)
    selectedSq = nil
    dragging = false
    dragHover = nil
end

local function doMove(from, to)
    local entry = legalMap[from] and legalMap[from][to]
    if entry and entry.promo and not Config.AutoPromoteQueen then
        promotionMenu(from, to)
        return
    end
    sendMove(from, to, (entry and entry.promo) and 'Q' or nil)
end

promotionMenu = function(from, to)
    local opts = {}
    local map = { Q = 'Queen', R = 'Rook', B = 'Bishop', N = 'Knight' }
    for _, t in ipairs({ 'Q', 'R', 'B', 'N' }) do
        opts[#opts + 1] = { title = map[t], icon = 'chess-' .. map[t]:lower(),
            onSelect = function() sendMove(from, to, t) end }
    end
    lib.registerContext({ id = 'ic3d_chess_promo', title = Config.L('promote_title'), options = opts })
    lib.showContext('ic3d_chess_promo')
end

local function setSelected(sq)
    if selectedSq ~= nil and selectedSq ~= sq then lowerSelected() end
    selectedSq = sq
    dragging = true
    dragHover = sq
    local l = Loc[seated.locId]
    local pc = l and l.pieces[sq]
    if pc and DoesEntityExist(pc.ent) then attachPieceToCell(l.board, pc.ent, sq, pc.code, Config.Cursor.liftHeight) end
end

local function isTarget(from, to)
    return from ~= nil and legalMap[from] and legalMap[from][to] ~= nil
end

local function onPress(hovered)
    if hovered == nil then if selectedSq then clearSelection() end return end
    if selectedSq ~= nil then
        if isTarget(selectedSq, hovered) then doMove(selectedSq, hovered)
        elseif legalMap[hovered] then setSelected(hovered)
        else clearSelection() end
    else
        if legalMap[hovered] then setSelected(hovered) end
    end
end

local function onRelease(hovered)
    if not dragging then return end
    dragging = false
    if selectedSq ~= nil and hovered ~= nil and hovered ~= selectedSq and isTarget(selectedSq, hovered) then
        doMove(selectedSq, hovered)
    else
        lowerSelected() 
    end
end


local function drawHighlights(board, hovered)
    local H = Config.Highlights
    local function mark(sq, col)
        if sq == nil then return end
        local w = cellWorld(board, sq, 0.012)
        DrawMarker(1, w.x, w.y, w.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            H.size, H.size, 0.04, col[1], col[2], col[3], col[4], false, false, 2, false, nil, nil, false)
    end
    local pub = States[seated.locId]
    if pub and pub.lastMove then mark(pub.lastMove.from, H.last); mark(pub.lastMove.to, H.last) end
    if selectedSq ~= nil then
        mark(selectedSq, H.selected)
        local targets = legalMap[selectedSq]
        if targets then
            local boardList = pub and pub.board or DEFAULT_BOARD
            for to in pairs(targets) do
                local occupied = boardList[to + 1] and boardList[to + 1] ~= false
                mark(to, occupied and H.capture or H.move)
            end
        end
    end
    if hovered ~= nil then
        mark(hovered, H.hover)
        
        if Config.ShowHoverPointer then
            local c = H.pointer or { 181, 129, 255, 235 }
            local w = cellWorld(board, hovered, 0.20)
            DrawMarker(0, w.x, w.y, w.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.09, 0.09, 0.13, c[1], c[2], c[3], c[4], true, false, 2, false, nil, nil, false)
        end
    end
end

local function seatedLoop(locId, role)
    local cursorF = 3.5
    local cursorR = (role == 'w') and 1.5 or 5.5
    CreateThread(function()
        while seated and seated.locId == locId do
            local l = Loc[locId]
            local pub = States[locId]
            if l and l.board and DoesEntityExist(l.board) and pub then
                DisableAllControlActions(0)
                local waiting = pub.waiting and not pub.vsNpc

                
                local lookPos
                if waiting and Config.Camera.waitOrbit.enabled then
                    local o = Config.Camera.waitOrbit
                    seated.orbit = (seated.orbit or 0.0) + o.speed * GetFrameTime()
                    local c = GetEntityCoords(l.board)
                    local a = math.rad(seated.orbit)
                    seated.camPos = vector3(c.x + math.cos(a) * o.radius, c.y + math.sin(a) * o.radius, c.z + o.height)
                    lookPos = vector3(c.x, c.y, c.z - 0.05)
                else
                    local sign = (role == 'w') and -1.0 or 1.0
                    local desired = GetOffsetFromEntityInWorldCoords(l.board, 0.0, sign * Config.Camera.back, Config.Camera.height)
                    if not seated.camPos then seated.camPos = desired end
                    seated.camPos = seated.camPos + (desired - seated.camPos) * 0.1
                    lookPos = GetEntityCoords(l.board)
                end
                if chessCam then
                    SetCamCoord(chessCam, seated.camPos.x, seated.camPos.y, seated.camPos.z)
                    PointCamAtCoord(chessCam, lookPos.x, lookPos.y, lookPos.z)
                end

                if not waiting then
                    SetEntityLocallyInvisible(PlayerPedId()) 

                    
                    local dx = GetDisabledControlNormal(0, 1) * Config.Cursor.sensitivity
                    local dy = GetDisabledControlNormal(0, 2) * Config.Cursor.sensitivity
                    if Config.Cursor.invertX then dx = -dx end
                    if Config.Cursor.invertY then dy = -dy end
                    if role == 'w' then cursorF = cursorF + dx; cursorR = cursorR - dy
                    else cursorF = cursorF - dx; cursorR = cursorR + dy end
                    cursorF = clamp(cursorF, 0.0, 7.0)
                    cursorR = clamp(cursorR, 0.0, 7.0)
                    local hovered = clamp(round(cursorR), 0, 7) * 8 + clamp(round(cursorF), 0, 7)
                    local myTurn = (not pub.ended) and pub.turn == role

                    if IsDisabledControlJustPressed(0, Config.Controls.pick) and myTurn then onPress(hovered) end
                    if IsDisabledControlJustReleased(0, Config.Controls.pick) then onRelease(hovered) end

                    if dragging and selectedSq ~= nil and hovered ~= dragHover then
                        dragHover = hovered
                        local pc = l.pieces[selectedSq]
                        if pc and DoesEntityExist(pc.ent) then
                            attachPieceToCell(l.board, pc.ent, hovered, pc.code, Config.Cursor.liftHeight)
                        end
                    end
                    drawHighlights(l.board, hovered)
                end

                if IsDisabledControlJustPressed(0, Config.Controls.leave) then
                    TriggerServerEvent('ic3d_chess:leave', locId)
                    exitSeat()
                    break
                end
            end
            Wait(0)
        end
    end)
end


function exitSeat()
    if not seated then return end
    local locId = seated.locId
    clearSelection()
    stopCam()
    hideHud()
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    if seated.prev then SetEntityCoords(ped, seated.prev.x, seated.prev.y, seated.prev.z, false, false, false, false) end
    seated = nil
    legalMap = {}
    
    local pub = States[locId]
    if Loc[locId] then
        if pub and pub.active then renderBoard(locId, pub.board); renderCaptured(locId, pub.board)
        else renderBoard(locId, DEFAULT_BOARD); renderCaptured(locId, DEFAULT_BOARD) end
    end
end

local function enterSeat(locId, role)
    local l = Loc[locId]
    if not l then return end
    local seat = (role == 'w') and Config.Seats.white or Config.Seats.black
    local chair = (role == 'w') and l.chairWhite or l.chairBlack
    if not chair or not DoesEntityExist(chair) then return end

    local ped = PlayerPedId()
    seated = { locId = locId, role = role, prev = GetEntityCoords(ped) }
    selectedSq = nil; dragging = false; lastResultLoc = nil
    seatPedAtChair(ped, chair, seat.ped)
    startCam(l.board, role)
    seatedLoop(locId, role)
    local pub = States[locId] or { whiteName = 'White', blackName = '...', turn = 'w', waiting = true }
    showHud(pub, role)
    TriggerServerEvent('ic3d_chess:requestSync', locId)
end


local function fetchAndSendRating()
    if not Config.Ranking.enabled then return end
    lib.callback('ic3d_chess:getMyRating', false, function(r)
        if not r then return end
        local t = Config.TitleFor(r.elo)
        SendNUIMessage({
            action = 'myRating', label = Config.L('your_rating'),
            elo = r.elo, title = t.name, short = t.short, color = t.color,
            ranked = r.ranked, wins = r.wins, losses = r.losses, draws = r.draws,
        })
    end)
end

local function sendMenu(screen, sub, desc, opts, canBack)
    menuScreen = screen
    SendNUIMessage({ action = 'openMenu', sub = sub, desc = desc, options = opts, canBack = canBack or false })
end

local function renderRootMenu(locId)
    local pub = States[locId]
    local opts = {}
    if not pub or not pub.active then
        opts[#opts + 1] = { value = 'create', title = Config.L('play_vs_player'), desc = Config.L('play_vs_player_desc'), icon = 'fa-users' }
        if Config.NPC.enabled then
            opts[#opts + 1] = { value = 'npc', title = Config.L('play_vs_computer'), desc = Config.L('play_vs_computer_desc'), icon = 'fa-robot' }
        end
    elseif pub.waiting then
        local desc = Config.L('join_match_desc')
        if pub.bet and pub.bet > 0 then desc = Config.L('join_bet', Config.Betting.currency, pub.bet) end
        opts[#opts + 1] = { value = 'join', title = Config.L('join_match'), desc = desc, icon = 'fa-chess-pawn' }
    end
    if Config.Ranking.enabled then
        opts[#opts + 1] = { value = 'leaderboard', title = Config.L('menu_leaderboard'), desc = Config.L('menu_leaderboard_desc'), icon = 'fa-ranking-star' }
    end
    sendMenu('root', Config.L('menu_title'), Config.L('menu_desc'), opts, false)
    fetchAndSendRating()
end

openMenu = function(locId)
    if seated then return end
    pending = nil
    menuLoc = locId
    SetNuiFocus(true, true)
    renderRootMenu(locId)
end

local function closeMenu()
    menuLoc = nil
    pending = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
end

local function showDifficultyMenu()
    local opts = {}
    for _, d in ipairs({ { 'easy', 'diff_easy' }, { 'medium', 'diff_medium' }, { 'hard', 'diff_hard' } }) do
        if Config.NPC.difficulties[d[1]] then
            opts[#opts + 1] = { value = 'diff_' .. d[1], title = Config.L(d[2]), desc = '', icon = 'fa-robot' }
        end
    end
    sendMenu('difficulty', Config.L('diff_title'), '', opts, true)
end

local function showSideMenu()
    sendMenu('side', Config.L('side_title'), '', {
        { value = 'side_w', title = Config.L('side_white'), desc = Config.L('side_white_desc'), icon = 'fa-chess-king' },
        { value = 'side_b', title = Config.L('side_black'), desc = Config.L('side_black_desc'), icon = 'fa-chess-king' },
        { value = 'side_random', title = Config.L('side_random'), desc = Config.L('side_random_desc'), icon = 'fa-dice' },
    }, true)
end

local function showBetMenu()
    local opts = {}
    for _, amt in ipairs(Config.Betting.amounts) do
        if amt == 0 then
            opts[#opts + 1] = { value = 'bet_0', title = Config.L('bet_none'), desc = Config.L('bet_none_desc'), icon = 'fa-handshake' }
        else
            opts[#opts + 1] = { value = 'bet_' .. amt, title = Config.Betting.currency .. amt, desc = Config.L('bet_amount_desc'), icon = 'fa-coins' }
        end
    end
    sendMenu('bet', Config.L('bet_title'), '', opts, true)
end

local function bettingFor(mode)
    if not Config.Betting.enabled then return false end
    if mode == 'npc' then return Config.Betting.allowVsNpc end
    return true
end

local function finalizeMatch()
    local locId = menuLoc
    if not pending or not locId then closeMenu(); return end
    local p = pending
    closeMenu()
    if p.mode == 'pvp' then
        TriggerServerEvent('ic3d_chess:requestSeat', locId, 'create', p.side, p.bet or 0)
    elseif p.mode == 'npc' then
        TriggerServerEvent('ic3d_chess:startVsNpc', locId, p.difficulty, p.side, p.bet or 0)
    end
end

RegisterNUICallback('menuClose', function(_, cb)
    closeMenu(); cb('ok')
end)

RegisterNUICallback('menuBack', function(_, cb)
    cb('ok')
    if not menuLoc then return end
    if menuScreen == 'side' then
        if pending and pending.mode == 'npc' then showDifficultyMenu() else renderRootMenu(menuLoc) end
    elseif menuScreen == 'difficulty' then
        renderRootMenu(menuLoc)
    elseif menuScreen == 'bet' then
        showSideMenu()
    else
        renderRootMenu(menuLoc)
    end
end)

RegisterNUICallback('menuSelect', function(data, cb)
    cb('ok')
    local v = data and data.value
    if not menuLoc or not v then return end

    if v == 'create' then
        pending = { mode = 'pvp' }; showSideMenu()
    elseif v == 'npc' then
        pending = { mode = 'npc' }; showDifficultyMenu()
    elseif v:sub(1, 5) == 'diff_' then
        if pending then pending.difficulty = v:sub(6) end; showSideMenu()
    elseif v:sub(1, 5) == 'side_' then
        if pending then
            local s = v:sub(6)
            pending.side = (s == 'w' or s == 'b') and s or 'random'
            if bettingFor(pending.mode) then showBetMenu() else finalizeMatch() end
        end
    elseif v:sub(1, 4) == 'bet_' then
        if pending then pending.bet = tonumber(v:sub(5)) or 0; finalizeMatch() end
    elseif v == 'join' then
        local locId = menuLoc
        closeMenu()
        TriggerServerEvent('ic3d_chess:requestSeat', locId, 'join')
    elseif v == 'leaderboard' then
        lib.callback('ic3d_chess:getLeaderboard', false, function(rows)
            rows = rows or {}
            for i = 1, #rows do
                local t = Config.TitleFor(rows[i].elo)
                rows[i].title = t.name; rows[i].short = t.short; rows[i].color = t.color
            end
            SendNUIMessage({
                action = 'showLeaderboard', rows = rows,
                title = Config.L('lb_title'), subtitle = Config.L('lb_subtitle'), back = Config.L('lb_back'),
                empty = Config.L('lb_empty'),
                colPlayer = Config.L('col_player'), colRating = Config.L('col_rating'), colRecord = Config.L('col_record'),
            })
        end)
    end
end)


RegisterNetEvent('ic3d_chess:notify', function(msg)
    lib.notify({ title = Config.L('notify_title'), description = msg, position = 'top' })
end)

RegisterNetEvent('ic3d_chess:youAre', function(locId, role)
    if not Loc[locId] then spawnLocationProps(locId) end
    enterSeat(locId, role)
end)

RegisterNetEvent('ic3d_chess:sync', function(locId, pub)
    States[locId] = pub
    if not Loc[locId] then
        if (seated and seated.locId == locId) and not pub.active then exitSeat() end
        return
    end

    if not pub.active then
        renderBoard(locId, DEFAULT_BOARD)
        renderCaptured(locId, DEFAULT_BOARD)
        removeNpc(locId)
        if seated and seated.locId == locId then exitSeat() end
        return
    end

    renderBoard(locId, pub.board)
    renderCaptured(locId, pub.board)
    ensureNpc(locId, pub)

    if seated and seated.locId == locId then
        computeLegalMap(pub, seated.role)
        updateHud(pub, seated.role)
        if selectedSq ~= nil and not legalMap[selectedSq] then clearSelection() end
        if pub.ended and lastResultLoc ~= locId then
            lastResultLoc = locId
            local outcome = (pub.winner == 'draw' and 'draw') or (pub.winner == seated.role and 'win') or 'lose'
            local reasonKey = ({ checkmate = 'result_checkmate', stalemate = 'result_stalemate',
                time = 'result_time', resign = 'result_resign', left = 'result_resign' })[pub.reason or '']
            showResultShard(outcome, reasonKey and Config.L(reasonKey) or '')
        end
    end
end)


CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        for i, loc in ipairs(Config.Locations) do
            local dist = #(pc - loc.coords)
            if dist < 100.0 and not Loc[i] then spawnLocationProps(i)
            elseif dist >= 120.0 and Loc[i] then despawnLocationProps(i) end
        end
        Wait(1500)
    end
end)


if not useTarget then
    CreateThread(function()
        local shown = false
        while true do
            local sleep = 500
            if not seated and not menuLoc then
                local pc = GetEntityCoords(PlayerPedId())
                local near
                for i, loc in ipairs(Config.Locations) do
                    if Loc[i] and #(pc - loc.coords) < Config.InteractDist then near = i break end
                end
                if near then
                    sleep = 0
                    if not shown then
                        lib.showTextUI('[E] ' .. Config.L('menu_title'), {
                            position = 'right-center',
                            icon = 'chess',
                            style = { borderRadius = 6, backgroundColor = '#140c23', color = 'white' },
                        })
                        shown = true
                    end
                    if IsControlJustPressed(0, Config.InteractKey) then openMenu(near) end
                elseif shown then
                    lib.hideTextUI(); shown = false
                end
            elseif shown then
                lib.hideTextUI(); shown = false
            end
            Wait(sleep)
        end
    end)
end


if Config.DrawTableInfo then
    CreateThread(function()
        while true do
            local sleep = 800
            if not seated then
                local pc = GetEntityCoords(PlayerPedId())
                for i, loc in ipairs(Config.Locations) do
                    local pub = States[i]
                    if Loc[i] and pub and pub.active and #(pc - loc.coords) < 6.0 then
                        sleep = 0
                        local line
                        if pub.ended then
                            line = pub.winner == 'draw' and 'Draw'
                                or ((pub.winner == 'w' and (pub.whiteName or 'White') or (pub.blackName or 'Black')) .. ' wins')
                        else
                            line = (pub.turn == 'w' and (pub.whiteName or 'White') or (pub.blackName or 'Black')) .. ' to move'
                            if pub.status == 'check' then line = line .. ' (check)' end
                        end
                        local tc = GetEntityCoords(Loc[i].table)
                        SetDrawOrigin(tc.x, tc.y, tc.z + 1.15, 0)
                        SetTextScale(0.32, 0.32); SetTextFont(4); SetTextColour(255, 255, 255, 215)
                        SetTextOutline(); SetTextCentre(true); SetTextEntry('STRING')
                        AddTextComponentString(('%s  vs  %s~n~%s'):format(pub.whiteName or 'White', pub.blackName or 'Black', line))
                        DrawText(0.0, 0.0)
                        ClearDrawOrigin()
                    end
                end
            end
            Wait(sleep)
        end
    end)
end


AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if seated then stopCam(); local p = PlayerPedId(); ClearPedTasksImmediately(p); FreezeEntityPosition(p, false) end
    seated = nil
    SetNuiFocus(false, false)
    pcall(function() lib.hideTextUI() end)
    for i in pairs(Loc) do despawnLocationProps(i) end
end)
