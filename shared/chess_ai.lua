





ChessAI = {}
local E = ChessEngine

local MAT = { P = 100, N = 320, B = 330, R = 500, Q = 900, K = 20000 }



local PST = {
    P = {
          0,  0,  0,  0,  0,  0,  0,  0,
          5, 10, 10,-20,-20, 10, 10,  5,
          5, -5,-10,  0,  0,-10, -5,  5,
          0,  0,  0, 20, 20,  0,  0,  0,
          5,  5, 10, 25, 25, 10,  5,  5,
         10, 10, 20, 30, 30, 20, 10, 10,
         50, 50, 50, 50, 50, 50, 50, 50,
          0,  0,  0,  0,  0,  0,  0,  0,
    },
    N = {
        -50,-40,-30,-30,-30,-30,-40,-50,
        -40,-20,  0,  5,  5,  0,-20,-40,
        -30,  5, 10, 15, 15, 10,  5,-30,
        -30,  0, 15, 20, 20, 15,  0,-30,
        -30,  5, 15, 20, 20, 15,  5,-30,
        -30,  0, 10, 15, 15, 10,  0,-30,
        -40,-20,  0,  0,  0,  0,-20,-40,
        -50,-40,-30,-30,-30,-30,-40,-50,
    },
    B = {
        -20,-10,-10,-10,-10,-10,-10,-20,
        -10,  5,  0,  0,  0,  0,  5,-10,
        -10, 10, 10, 10, 10, 10, 10,-10,
        -10,  0, 10, 10, 10, 10,  0,-10,
        -10,  5,  5, 10, 10,  5,  5,-10,
        -10,  0,  5, 10, 10,  5,  0,-10,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -20,-10,-10,-10,-10,-10,-10,-20,
    },
    R = {
          0,  0,  0,  5,  5,  0,  0,  0,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
          5, 10, 10, 10, 10, 10, 10,  5,
          0,  0,  0,  0,  0,  0,  0,  0,
    },
    Q = {
        -20,-10,-10, -5, -5,-10,-10,-20,
        -10,  0,  0,  0,  0,  5,  0,-10,
        -10,  0,  5,  5,  5,  5,  5,-10,
         -5,  0,  5,  5,  5,  5,  0, -5,
         -5,  0,  5,  5,  5,  5,  0, -5,
        -10,  0,  5,  5,  5,  5,  0,-10,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -20,-10,-10, -5, -5,-10,-10,-20,
    },
    K = {
         20, 30, 10,  0,  0, 10, 30, 20,
         20, 20,  0,  0,  0,  0, 20, 20,
        -10,-20,-20,-20,-20,-20,-20,-10,
        -20,-30,-30,-40,-40,-30,-30,-20,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
    },
}

local floor = math.floor

local function mirror(sq) 
    local f = sq % 8
    local r = floor(sq / 8)
    return (7 - r) * 8 + f
end


local function evaluate(state)
    local board = state.board
    local score = 0
    for sq = 0, 63 do
        local p = board[sq]
        if p then
            local c = string.sub(p, 1, 1)
            local t = string.sub(p, 2, 2)
            local idx = (c == 'w') and sq or mirror(sq)
            local val = MAT[t] + (PST[t] and PST[t][idx + 1] or 0)
            if c == 'w' then score = score + val else score = score - val end
        end
    end
    return (state.turn == 'w') and score or -score
end

local MATE = 1000000


local function orderMoves(state, moves)
    for i = 1, #moves do
        local m = moves[i]
        local victim = state.board[m.to]
        m._score = victim and (MAT[string.sub(victim, 2, 2)] or 0) or (m.promo and 90 or 0)
    end
    table.sort(moves, function(a, b) return a._score > b._score end)
end

local function negamax(state, depth, alpha, beta)
    local moves = E.generateLegalMoves(state)
    if #moves == 0 then
        local ksq = E.findKing(state.board, state.turn)
        if ksq and E.isSquareAttacked(state.board, ksq, E.opp(state.turn)) then
            return -MATE - depth 
        end
        return 0 
    end
    if depth <= 0 then
        return evaluate(state)
    end

    orderMoves(state, moves)
    local best = -math.huge
    for i = 1, #moves do
        local ns = E.applyMove(state, moves[i], true)
        local v = -negamax(ns, depth - 1, -beta, -alpha)
        if v > best then best = v end
        if best > alpha then alpha = best end
        if alpha >= beta then break end
    end
    return best
end




function ChessAI.choose(state, depth, randomize)
    local moves = E.generateLegalMoves(state)
    if #moves == 0 then return nil end

    orderMoves(state, moves)

    local bestVal = -math.huge
    local best = moves[1]
    local scored = {}
    local alpha = -math.huge
    for i = 1, #moves do
        local ns = E.applyMove(state, moves[i], true)
        local v = -negamax(ns, depth - 1, -math.huge, -alpha)
        scored[i] = { m = moves[i], v = v }
        if v > bestVal then
            bestVal = v
            best = moves[i]
        end
        if v > alpha then alpha = v end
    end

    if randomize then
        local margin = 70
        local pool = {}
        for i = 1, #scored do
            if scored[i].v >= bestVal - margin then
                pool[#pool + 1] = scored[i].m
            end
        end
        if #pool > 0 then
            return pool[math.random(#pool)]
        end
    end

    return best
end
