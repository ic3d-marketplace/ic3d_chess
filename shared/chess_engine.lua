






ChessEngine = {}
local E = ChessEngine


local floor = math.floor

local function fileOf(sq) return sq % 8 end
local function rankOf(sq) return floor(sq / 8) end          
local function onBoard(f, r) return f >= 0 and f <= 7 and r >= 0 and r <= 7 end
local function sqOf(f, r) return r * 8 + f end
local function colorOf(p) return p and string.sub(p, 1, 1) or nil end
local function typeOf(p) return p and string.sub(p, 2, 2) or nil end
local function opp(c) return c == 'w' and 'b' or 'w' end

E.opp = opp
E.fileOf = fileOf
E.rankOf = rankOf

function E.squareName(sq)
    return string.char(97 + fileOf(sq)) .. tostring(rankOf(sq) + 1)
end

function E.nameToSq(name)
    local f = string.byte(name, 1) - 97
    local r = tonumber(string.sub(name, 2)) - 1
    return r * 8 + f
end


local START = {
    'wR','wN','wB','wQ','wK','wB','wN','wR',
    'wP','wP','wP','wP','wP','wP','wP','wP',
    false,false,false,false,false,false,false,false,
    false,false,false,false,false,false,false,false,
    false,false,false,false,false,false,false,false,
    false,false,false,false,false,false,false,false,
    'bP','bP','bP','bP','bP','bP','bP','bP',
    'bR','bN','bB','bQ','bK','bB','bN','bR',
}

function E.newGame()
    local board = {}
    for sq = 0, 63 do board[sq] = START[sq + 1] end
    return {
        board     = board,
        turn      = 'w',
        castling  = { wK = true, wQ = true, bK = true, bQ = true },
        enPassant = nil,        
        halfmove  = 0,          
        fullmove  = 1,
        status    = 'active',
    }
end

function E.clone(s)
    local b = {}
    for sq = 0, 63 do b[sq] = s.board[sq] end
    return {
        board     = b,
        turn      = s.turn,
        castling  = { wK = s.castling.wK, wQ = s.castling.wQ, bK = s.castling.bK, bQ = s.castling.bQ },
        enPassant = s.enPassant,
        halfmove  = s.halfmove,
        fullmove  = s.fullmove,
        status    = s.status,
    }
end


function E.boardToList(board)
    local list = {}
    for sq = 0, 63 do list[sq + 1] = board[sq] or false end
    return list
end

function E.listToBoard(list)
    local board = {}
    for sq = 0, 63 do
        local v = list[sq + 1]
        board[sq] = (v == false or v == nil) and false or v
    end
    return board
end


local KN    = { {1,2},{2,1},{2,-1},{1,-2},{-1,-2},{-2,-1},{-2,1},{-1,2} }
local DIAG  = { {1,1},{1,-1},{-1,1},{-1,-1} }
local ORTH  = { {1,0},{-1,0},{0,1},{0,-1} }
local KING8 = { {1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1} }


function E.isSquareAttacked(board, sq, by)
    local f, r = fileOf(sq), rankOf(sq)

    
    local pr = (by == 'w') and (r - 1) or (r + 1)
    local pawn = by .. 'P'
    if onBoard(f - 1, pr) and board[sqOf(f - 1, pr)] == pawn then return true end
    if onBoard(f + 1, pr) and board[sqOf(f + 1, pr)] == pawn then return true end

    
    local knight = by .. 'N'
    for i = 1, #KN do
        local af, ar = f + KN[i][1], r + KN[i][2]
        if onBoard(af, ar) and board[sqOf(af, ar)] == knight then return true end
    end

    
    local king = by .. 'K'
    for i = 1, #KING8 do
        local af, ar = f + KING8[i][1], r + KING8[i][2]
        if onBoard(af, ar) and board[sqOf(af, ar)] == king then return true end
    end

    
    for i = 1, #DIAG do
        local af, ar = f + DIAG[i][1], r + DIAG[i][2]
        while onBoard(af, ar) do
            local p = board[sqOf(af, ar)]
            if p then
                if colorOf(p) == by and (typeOf(p) == 'B' or typeOf(p) == 'Q') then return true end
                break
            end
            af, ar = af + DIAG[i][1], ar + DIAG[i][2]
        end
    end

    
    for i = 1, #ORTH do
        local af, ar = f + ORTH[i][1], r + ORTH[i][2]
        while onBoard(af, ar) do
            local p = board[sqOf(af, ar)]
            if p then
                if colorOf(p) == by and (typeOf(p) == 'R' or typeOf(p) == 'Q') then return true end
                break
            end
            af, ar = af + ORTH[i][1], ar + ORTH[i][2]
        end
    end

    return false
end

local function findKing(board, color)
    local k = color .. 'K'
    for sq = 0, 63 do
        if board[sq] == k then return sq end
    end
    return nil
end
E.findKing = findKing


local function applyToBoardCopy(board, m)
    local b = {}
    for sq = 0, 63 do b[sq] = board[sq] end
    local piece = b[m.from]
    b[m.from] = false
    if m.flag == 'enpassant' then b[m.capturedSq] = false end
    if m.promo then piece = colorOf(piece) .. m.promo end
    b[m.to] = piece
    if m.flag == 'castle' then
        local rook = b[m.rookFrom]
        b[m.rookFrom] = false
        b[m.rookTo] = rook
    end
    return b
end


local function addPawnMove(moves, from, to, color, promoRank, isCap)
    if promoRank then
        local types = { 'Q', 'R', 'B', 'N' }
        for i = 1, 4 do
            moves[#moves + 1] = { from = from, to = to, piece = color .. 'P', flag = 'promo', promo = types[i] }
        end
    else
        moves[#moves + 1] = { from = from, to = to, piece = color .. 'P', flag = isCap and 'capture' or 'normal' }
    end
end

local function genCastle(state, color, moves)
    local board = state.board
    local cr = state.castling
    if color == 'w' then
        if not E.isSquareAttacked(board, 4, 'b') then
            if cr.wK and not board[5] and not board[6] and board[7] == 'wR'
                and not E.isSquareAttacked(board, 5, 'b') and not E.isSquareAttacked(board, 6, 'b') then
                moves[#moves + 1] = { from = 4, to = 6, piece = 'wK', flag = 'castle', rookFrom = 7, rookTo = 5 }
            end
            if cr.wQ and not board[3] and not board[2] and not board[1] and board[0] == 'wR'
                and not E.isSquareAttacked(board, 3, 'b') and not E.isSquareAttacked(board, 2, 'b') then
                moves[#moves + 1] = { from = 4, to = 2, piece = 'wK', flag = 'castle', rookFrom = 0, rookTo = 3 }
            end
        end
    else
        if not E.isSquareAttacked(board, 60, 'w') then
            if cr.bK and not board[61] and not board[62] and board[63] == 'bR'
                and not E.isSquareAttacked(board, 61, 'w') and not E.isSquareAttacked(board, 62, 'w') then
                moves[#moves + 1] = { from = 60, to = 62, piece = 'bK', flag = 'castle', rookFrom = 63, rookTo = 61 }
            end
            if cr.bQ and not board[59] and not board[58] and not board[57] and board[56] == 'bR'
                and not E.isSquareAttacked(board, 59, 'w') and not E.isSquareAttacked(board, 58, 'w') then
                moves[#moves + 1] = { from = 60, to = 58, piece = 'bK', flag = 'castle', rookFrom = 56, rookTo = 59 }
            end
        end
    end
end

local function slide(board, sq, p, color, dirs, moves)
    local f, r = fileOf(sq), rankOf(sq)
    for i = 1, #dirs do
        local af, ar = f + dirs[i][1], r + dirs[i][2]
        while onBoard(af, ar) do
            local tsq = sqOf(af, ar)
            local tp = board[tsq]
            if not tp then
                moves[#moves + 1] = { from = sq, to = tsq, piece = p }
            else
                if colorOf(tp) ~= color then
                    moves[#moves + 1] = { from = sq, to = tsq, piece = p }
                end
                break
            end
            af, ar = af + dirs[i][1], ar + dirs[i][2]
        end
    end
end

local function genPiece(state, sq, p, moves)
    local board = state.board
    local color = colorOf(p)
    local t = typeOf(p)
    local f, r = fileOf(sq), rankOf(sq)

    if t == 'P' then
        if color == 'w' then
            if r + 1 <= 7 and not board[sqOf(f, r + 1)] then
                addPawnMove(moves, sq, sqOf(f, r + 1), 'w', r + 1 == 7, false)
                if r == 1 and not board[sqOf(f, 3)] then
                    moves[#moves + 1] = { from = sq, to = sqOf(f, 3), piece = p, flag = 'double', ep = sqOf(f, 2) }
                end
            end
            for _, dfp in ipairs({ -1, 1 }) do
                local cf, cr = f + dfp, r + 1
                if onBoard(cf, cr) then
                    local tsq = sqOf(cf, cr)
                    local tp = board[tsq]
                    if tp and colorOf(tp) == 'b' then
                        addPawnMove(moves, sq, tsq, 'w', r + 1 == 7, true)
                    elseif state.enPassant and tsq == state.enPassant then
                        moves[#moves + 1] = { from = sq, to = tsq, piece = p, flag = 'enpassant', capturedSq = sqOf(cf, r) }
                    end
                end
            end
        else
            if r - 1 >= 0 and not board[sqOf(f, r - 1)] then
                addPawnMove(moves, sq, sqOf(f, r - 1), 'b', r - 1 == 0, false)
                if r == 6 and not board[sqOf(f, 4)] then
                    moves[#moves + 1] = { from = sq, to = sqOf(f, 4), piece = p, flag = 'double', ep = sqOf(f, 5) }
                end
            end
            for _, dfp in ipairs({ -1, 1 }) do
                local cf, cr = f + dfp, r - 1
                if onBoard(cf, cr) then
                    local tsq = sqOf(cf, cr)
                    local tp = board[tsq]
                    if tp and colorOf(tp) == 'w' then
                        addPawnMove(moves, sq, tsq, 'b', r - 1 == 0, true)
                    elseif state.enPassant and tsq == state.enPassant then
                        moves[#moves + 1] = { from = sq, to = tsq, piece = p, flag = 'enpassant', capturedSq = sqOf(cf, r) }
                    end
                end
            end
        end
    elseif t == 'N' then
        for i = 1, #KN do
            local af, ar = f + KN[i][1], r + KN[i][2]
            if onBoard(af, ar) then
                local tsq = sqOf(af, ar)
                local tp = board[tsq]
                if not tp or colorOf(tp) ~= color then
                    moves[#moves + 1] = { from = sq, to = tsq, piece = p }
                end
            end
        end
    elseif t == 'B' then
        slide(board, sq, p, color, DIAG, moves)
    elseif t == 'R' then
        slide(board, sq, p, color, ORTH, moves)
    elseif t == 'Q' then
        slide(board, sq, p, color, DIAG, moves)
        slide(board, sq, p, color, ORTH, moves)
    elseif t == 'K' then
        for i = 1, #KING8 do
            local af, ar = f + KING8[i][1], r + KING8[i][2]
            if onBoard(af, ar) then
                local tsq = sqOf(af, ar)
                local tp = board[tsq]
                if not tp or colorOf(tp) ~= color then
                    moves[#moves + 1] = { from = sq, to = tsq, piece = p }
                end
            end
        end
        genCastle(state, color, moves)
    end
end


function E.generateLegalMoves(state, fromOnly)
    local color = state.turn
    local pseudo = {}
    for sq = 0, 63 do
        if (not fromOnly) or sq == fromOnly then
            local p = state.board[sq]
            if p and colorOf(p) == color then
                genPiece(state, sq, p, pseudo)
            end
        end
    end

    local legal = {}
    for i = 1, #pseudo do
        local m = pseudo[i]
        local nb = applyToBoardCopy(state.board, m)
        local ksq = findKing(nb, color)
        if ksq and not E.isSquareAttacked(nb, ksq, opp(color)) then
            legal[#legal + 1] = m
        end
    end
    return legal
end


function E.insufficientMaterial(board)
    local minors, others = 0, 0
    for sq = 0, 63 do
        local p = board[sq]
        if p then
            local t = typeOf(p)
            if t ~= 'K' then
                if t == 'B' or t == 'N' then
                    minors = minors + 1
                else
                    others = others + 1
                end
            end
        end
    end
    if others > 0 then return false end
    return minors <= 1
end

function E.computeStatus(state)
    local color = state.turn
    local ksq = findKing(state.board, color)
    local inCheck = ksq and E.isSquareAttacked(state.board, ksq, opp(color)) or false
    local legal = E.generateLegalMoves(state)
    if #legal == 0 then
        return inCheck and 'checkmate' or 'stalemate'
    end
    if state.halfmove >= 100 then return 'draw' end
    if E.insufficientMaterial(state.board) then return 'draw' end
    return inCheck and 'check' or 'active'
end



function E.applyMove(state, m, skipStatus)
    local ns = E.clone(state)
    local board = ns.board
    local color = colorOf(m.piece)

    local isCapture = (board[m.to] and true) or m.flag == 'enpassant'
    local isPawn = typeOf(m.piece) == 'P'

    board[m.from] = false
    if m.flag == 'enpassant' then board[m.capturedSq] = false end
    local placed = m.piece
    if m.promo then placed = color .. m.promo end
    board[m.to] = placed
    if m.flag == 'castle' then
        local rook = board[m.rookFrom]
        board[m.rookFrom] = false
        board[m.rookTo] = rook
    end

    
    if typeOf(m.piece) == 'K' then
        if color == 'w' then ns.castling.wK = false; ns.castling.wQ = false
        else ns.castling.bK = false; ns.castling.bQ = false end
    end
    if m.from == 0 or m.to == 0 then ns.castling.wQ = false end
    if m.from == 7 or m.to == 7 then ns.castling.wK = false end
    if m.from == 56 or m.to == 56 then ns.castling.bQ = false end
    if m.from == 63 or m.to == 63 then ns.castling.bK = false end

    ns.enPassant = (m.flag == 'double') and m.ep or nil
    ns.halfmove  = (isCapture or isPawn) and 0 or (ns.halfmove + 1)
    if color == 'b' then ns.fullmove = ns.fullmove + 1 end
    ns.turn = opp(color)

    if not skipStatus then
        ns.status = E.computeStatus(ns)
    else
        ns.status = nil
    end
    return ns
end


function E.findMove(state, from, to, promo)
    local legal = E.generateLegalMoves(state, from)
    for i = 1, #legal do
        local m = legal[i]
        if m.from == from and m.to == to then
            if m.promo then
                if m.promo == promo then return m end
            else
                return m
            end
        end
    end
    return nil
end


function E.winner(state)
    if state.status == 'checkmate' then
        return opp(state.turn) 
    elseif state.status == 'stalemate' or state.status == 'draw' then
        return 'draw'
    end
    return nil
end
