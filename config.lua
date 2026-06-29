Config = {}

-- ============================================================
-- GENERAL
-- ============================================================
Config.Debug   = false          -- extra prints
Config.Locale  = 'en'           -- 'en' | 'pt'

-- Groups treated as admin (used by the shared bridge -> Bridge.IsAdmin)
Config.AdminGroups = { 'admin', 'god' }

-- ============================================================
-- INTERACTION
-- ============================================================
-- How players interact with a chess table.
--   'target'  -> ox_target (if the resource is started)
--   'auto'    -> use ox_target when available, otherwise a [E] marker
Config.Interact      = 'textui'  -- 'textui' (AFK-style [E] prompt) | 'target' (ox_target)
Config.InteractKey   = 38        -- control id for the [E] prompt (INPUT_PICKUP)
Config.InteractDist  = 2.0       -- how close to the table to open the menu
Config.DrawTableInfo = true      -- floating 3D text above active tables (for onlookers)

-- ============================================================
-- CHESS CLOCK (shown on screen for both players)
-- ============================================================
Config.Clock = {
    enabled          = true,
    minutes          = 10,   -- starting time per player
    incrementSeconds = 2,    -- Fischer increment added after each move
}

-- ============================================================
-- MONEY BETTING (optional wager on Player-vs-Player matches)
-- ============================================================
Config.Betting = {
    enabled    = true,
    account    = 'bank',                 -- 'bank' | 'cash'
    amounts    = { 0, 100, 500, 1000, 5000 }, -- selectable stakes (0 = no bet)
    houseCut   = 0.0,                    -- fraction taken from the pot (0.05 = 5%)
    allowVsNpc = false,                  -- allow betting against the computer
    currency   = '$',
}

-- ============================================================
-- RANKING / LEADERBOARD (ELO + chess.com style titles)
-- Requires oxmysql for persistence. Without it, ranking is disabled.
-- ============================================================
Config.Ranking = {
    enabled         = true,
    startElo        = 1000,
    kFactor         = 32,        -- how fast ratings move
    rateVsNpc       = false,     -- also rate games against the computer
    npcElo          = { easy = 800, medium = 1200, hard = 1600 },
    leaderboardSize = 25,

    -- Showcase entries shown when there is no real ranking data yet
    -- (e.g. before any rated games, or when oxmysql isn't running).
    -- Set to an empty table {} to disable.
    mockData = {
        { name = 'Magnus C.',   elo = 2540, wins = 184, losses = 12, draws = 41 },
        { name = 'Hikaru N.',   elo = 2418, wins = 142, losses = 23, draws = 18 },
        { name = 'Beth Harmon', elo = 2236, wins = 98,  losses = 19, draws = 11 },
        { name = 'Alireza F.',  elo = 2057, wins = 76,  losses = 28, draws = 9  },
        { name = 'Jorge Silva', elo = 1864, wins = 51,  losses = 33, draws = 7  },
        { name = 'Maria Costa', elo = 1672, wins = 40,  losses = 31, draws = 6  },
        { name = 'Tó Zé',       elo = 1488, wins = 28,  losses = 26, draws = 4  },
        { name = 'Newbie Joe',  elo = 1213, wins = 14,  losses = 19, draws = 2  },
        { name = 'Pedro M.',    elo = 1042, wins = 6,   losses = 15, draws = 1  },
        { name = 'Rook E.',     elo = 870,  wins = 2,   losses = 12, draws = 0  },
    },

    -- ELO thresholds -> title tag (highest first). short/colour used in the UI.
    titles = {
        { min = 2400, name = 'Grandmaster',          short = 'GM',  color = '#ff4d4d' },
        { min = 2200, name = 'International Master',  short = 'IM',  color = '#ff8c42' },
        { min = 2000, name = 'FIDE Master',          short = 'FM',  color = '#ffd43b' },
        { min = 1800, name = 'Candidate Master',     short = 'CM',  color = '#b581ff' },
        { min = 1600, name = 'Expert',               short = 'EXP', color = '#74c0fc' },
        { min = 1400, name = 'Advanced',             short = 'ADV', color = '#63e6be' },
        { min = 1200, name = 'Intermediate',         short = 'INT', color = '#a9e34b' },
        { min = 1000, name = 'Casual',               short = 'CAS', color = '#ced4da' },
        { min = 800,  name = 'Apprentice',           short = 'APP', color = '#adb5bd' },
        { min = 0,    name = 'Novice',               short = 'NOV', color = '#868e96' },
    },
}

-- Returns the title table for a given ELO.
function Config.TitleFor(elo)
    elo = tonumber(elo) or Config.Ranking.startElo
    for _, t in ipairs(Config.Ranking.titles) do
        if elo >= t.min then return t end
    end
    return Config.Ranking.titles[#Config.Ranking.titles]
end

-- ============================================================
-- PROP / MODEL NAMES  (from the bzzz_chess pack - do not rename)
-- ============================================================
Config.Models = {
    table = 'bzzz_chess_table_a',
    board = 'bzzz_chess_board_a',
    chair = 'bzzz_chess_chair_a',
    -- White (light) pieces
    white = {
        P = 'bzzz_chess_color_a1', -- pawn
        R = 'bzzz_chess_color_a2', -- rook
        N = 'bzzz_chess_color_a3', -- knight
        B = 'bzzz_chess_color_a4', -- bishop
        Q = 'bzzz_chess_color_a5', -- queen
        K = 'bzzz_chess_color_a6', -- king
    },
    -- Black (dark) pieces
    black = {
        P = 'bzzz_chess_color_b1',
        R = 'bzzz_chess_color_b2',
        N = 'bzzz_chess_color_b3',
        B = 'bzzz_chess_color_b4',
        Q = 'bzzz_chess_color_b5',
        K = 'bzzz_chess_color_b6',
    },
}

-- ============================================================
-- PLACEMENT / OFFSETS  (authoritative values from bzzz_chess/data)
-- ============================================================
-- Board is attached to the table at this local offset (offsets_table.lua).
-- If the board floats or sinks on your build, tweak the Z here.
Config.BoardOffset = vector3(0.0, 0.0, 0.40)

-- Board square layout (offsets_board.lua): a1 = (-0.21,-0.21), step 0.06.
Config.SquareOrigin = vector3(-0.21, -0.21, 0.002)
Config.SquareStep   = 0.06

-- Heading applied to pieces so they face the opponent (degrees, board-local).
Config.PieceHeading = { white = 0.0, black = 180.0 }

-- Seats (table-local). White sits on the -Y side (rank 1), black on +Y (rank 8).
-- `ped` = where the seated ped is placed relative to the chair. Lower the Z
-- (more negative) if the player/NPC floats above the chair.
Config.Seats = {
    -- chair  = where the chair object is placed relative to the table
    -- heading = chair heading offset from the table heading
    white = { chair = vector3(0.0, -0.595, -0.180), heading = 0.0,   ped = vector3(0.0, 0.02, -0.68) },
    black = { chair = vector3(0.0,  0.595, -0.180), heading = 180.0, ped = vector3(0.0, 0.02, -0.68) },
}

-- ============================================================
-- ANIMATIONS  (from bzzz_chess/data/anim.txt)
-- ============================================================
Config.Anim = {
    dict = 'bzzz_chess_animations',
    idle = 'bzzz_chess_sit_a', -- waiting for opponent / not your move
    move = 'bzzz_chess_sit_b', -- making a move
}

-- ============================================================
-- 3D PLAY (overhead camera + mouse pick-and-place on the real board)
-- ============================================================
Config.Camera = {
    fov          = 38.0,  -- lower = more zoomed in on the board
    back         = 0.62,  -- how far behind your own side the camera sits (table-local m)
    height       = 1.05,  -- camera height above the board
    transitionMs = 700,   -- blend time when sitting down / standing up

    -- While waiting for an opponent the camera orbits the table so you can
    -- see yourself and the surroundings.
    waitOrbit = {
        enabled = true,
        radius  = 2.4,    -- distance from the table centre
        height  = 1.45,   -- height above the table
        speed   = 16.0,   -- degrees per second
    },
}

-- The mouse moves a pointer across the board squares.
Config.Cursor = {
    sensitivity = 4.5,    -- higher = the pointer crosses the board faster
    liftHeight  = 0.06,   -- how high a grabbed piece floats while dragging
    invertX     = false,  -- flip if left/right feels reversed
    invertY     = false,  -- flip if up/down feels reversed
}

-- 3D highlight markers drawn on the board squares.
Config.Highlights = {
    size     = 0.052,
    selected = { 124, 92, 255, 200 },
    move     = { 45, 212, 191, 150 },
    capture  = { 239, 71, 103, 180 },
    hover    = { 255, 255, 255, 150 },
    last     = { 255, 210, 90, 110 },
    pointer  = { 181, 129, 255, 235 }, -- the bobbing pointer above the hovered square
}

-- Show the bouncing pointer marker above the square you're hovering.
Config.ShowHoverPointer = false

-- Captured pieces are stacked beside the board.
Config.Captured = {
    enabled = true,
    baseX   = 0.30,   -- distance from board centre to the trophy columns
    stepY   = 0.06,   -- spacing between stacked pieces
    colStep = 0.05,   -- spacing between overflow columns
    perCol  = 8,
}

-- Promotion: true = always auto-queen (fully in-world, no menu).
-- false = pop a small 4-option chooser when a pawn promotes.
Config.AutoPromoteQueen = true

-- Controls while seated (FiveM control ids, control group 0).
Config.Controls = {
    pick  = 24,   -- INPUT_ATTACK  (left mouse) - grab / place a piece
    leave = 177,  -- INPUT_FRONTEND_CANCEL (Backspace) - stand up / resign
}

-- ============================================================
-- COMPUTER OPPONENT (NPC)
-- ============================================================
Config.NPC = {
    enabled  = true,
    model    = 'a_m_y_business_01', -- opponent ped model
    -- Search depth per difficulty. Higher = stronger but heavier on the server.
    difficulties = {
        easy   = 1, -- blunders sometimes
        medium = 2,
        hard   = 3, -- noticeable thinking time
    },
    defaultDifficulty = 'medium',
    -- Fake "thinking" delay before the computer plays (ms).
    thinkTime = { min = 700, max = 2000 },
}

-- ============================================================
-- WINNING REWARDS  (optional - uses the shared bridge: Bridge.RewardPlayer)
-- ============================================================
Config.Rewards = {
    enabled = false,
    -- Given to the winner of a Player-vs-Player game.
    vsPlayerWin = {
        { type = 'money', account = 'bank', amount = 500 },
    },
    -- Given to a human who beats the computer (kept empty to avoid farming).
    vsNpcWin = {},
}

-- How long the final position stays on the board before it resets / you stand up (ms).
Config.ResetDelay = 4500

-- ============================================================
-- TABLE LOCATIONS
-- A chess table spawns at each of these on resource start.
-- ============================================================
Config.Locations = {
    { label = 'Legion Square',   coords = vector3(195.27, -933.77, 30.69), heading = 145.0 },
    { label = 'Vespucci Beach',  coords = vector3(-1296.6, -1448.3, 4.39), heading = 35.0  },
    { label = 'Mirror Park',     coords = vector3(1140.2, -641.4, 56.71),  heading = 250.0 },
}

-- ============================================================
-- TRANSLATIONS
-- ============================================================
Config.Text = {
    ['en'] = {
        menu_title          = 'Chess',
        menu_desc           = 'Play against another player or challenge the computer.',
        play_vs_player      = '👥 Play vs Player',
        play_vs_player_desc = 'Sit as White and wait for an opponent',
        play_vs_computer    = '🤖 Play vs Computer',
        play_vs_computer_desc = 'Play a solo game against the AI',
        join_as_black       = '♟️ Join as Black',
        join_as_black_desc  = 'A game is waiting for an opponent',
        spectate            = '👁️ Spectate',
        spectate_desc       = 'Watch the current game',
        open_board          = '♚ Open Board',
        open_board_desc     = 'Return to your game',
        diff_title          = 'Select Difficulty',
        diff_easy           = '🟢 Easy',
        diff_medium         = '🟡 Medium',
        diff_hard           = '🔴 Hard',
        notify_title        = 'Chess',
        game_full           = 'This table is already in use.',
        game_started        = 'Waiting for an opponent to sit down...',
        opponent_joined     = '%s joined the game. You play White.',
        you_joined          = 'You joined as Black against %s.',
        not_your_turn       = "It is not your turn.",
        illegal_move        = 'Illegal move.',
        check               = 'Check!',
        you_win             = 'Checkmate - you win! 🏆',
        you_lose            = 'Checkmate - you lose.',
        stalemate           = 'Stalemate - the game is a draw.',
        draw                = 'The game is a draw.',
        opponent_resigned   = 'Your opponent resigned. You win! 🏆',
        you_resigned        = 'You resigned.',
        opponent_left       = 'Your opponent left the game.',
        reward_received     = 'You received a reward for winning!',
        no_npc              = 'Computer opponents are disabled.',
        your_turn           = 'Your move',
        opp_turn            = "Opponent's move",
        waiting_opponent    = 'Waiting for an opponent…',
        thinking            = 'Computer is thinking…',
        in_check            = 'You are in check!',
        hud_grab            = 'Move the mouse to a piece and hold [Left Click] to move it',
        hud_leave           = '[Backspace] Stand up',
        promote_title       = 'Promote pawn to',
        result_win          = 'VICTORY',
        result_lose         = 'DEFEAT',
        result_draw         = 'DRAW',
        result_checkmate    = 'Checkmate',
        result_stalemate    = 'Stalemate',
        result_resign       = 'by resignation',
        result_time         = 'on time',
        menu_leaderboard    = '🏆 Leaderboard',
        menu_leaderboard_desc = 'Top rated players',
        lb_title            = 'LEADERBOARD',
        lb_subtitle         = 'Top players by rating',
        lb_back             = 'Back',
        lb_empty            = 'No ranked games played yet',
        your_rating         = 'Your rating',
        rating_change       = 'Rating: %d (%+d)',
        col_player          = 'Player',
        col_rating          = 'Rating',
        col_record          = 'W / L / D',
        side_title          = 'Choose your side',
        side_white          = '♔ White',
        side_white_desc     = 'You move first',
        side_black          = '♚ Black',
        side_black_desc     = 'Your opponent moves first',
        side_random         = '🎲 Random',
        side_random_desc    = 'Let fate decide',
        bet_title           = 'Place your bet',
        bet_none            = 'No bet',
        bet_none_desc       = 'Play a friendly match',
        bet_amount_desc     = 'Winner takes the pot',
        bet_insufficient    = 'You do not have enough money to bet that.',
        bet_won             = 'You won the pot: %s%s!',
        bet_refunded        = 'Your bet of %s%s was refunded.',
        join_bet            = 'Stake: %s%s — winner takes the pot',
        join_match          = '♟️ Join Match',
        join_match_desc     = 'Take the open seat',
    },
    ['pt'] = {
        menu_title          = 'Xadrez',
        menu_desc           = 'Joga contra outro jogador ou desafia o computador.',
        play_vs_player      = '👥 Jogar vs Jogador',
        play_vs_player_desc = 'Senta-te como Brancas e espera por um adversário',
        play_vs_computer    = '🤖 Jogar vs Computador',
        play_vs_computer_desc = 'Joga sozinho contra a IA',
        join_as_black       = '♟️ Entrar como Pretas',
        join_as_black_desc  = 'Um jogo está à espera de adversário',
        spectate            = '👁️ Assistir',
        spectate_desc       = 'Vê o jogo atual',
        open_board          = '♚ Abrir Tabuleiro',
        open_board_desc     = 'Volta ao teu jogo',
        diff_title          = 'Escolhe a Dificuldade',
        diff_easy           = '🟢 Fácil',
        diff_medium         = '🟡 Médio',
        diff_hard           = '🔴 Difícil',
        notify_title        = 'Xadrez',
        game_full           = 'Esta mesa já está a ser usada.',
        game_started        = 'À espera que um adversário se sente...',
        opponent_joined     = '%s entrou no jogo. Jogas com as Brancas.',
        you_joined          = 'Entraste como Pretas contra %s.',
        not_your_turn       = 'Não é a tua vez.',
        illegal_move        = 'Jogada ilegal.',
        check               = 'Xeque!',
        you_win             = 'Xeque-mate - ganhaste! 🏆',
        you_lose            = 'Xeque-mate - perdeste.',
        stalemate           = 'Empate por afogamento (stalemate).',
        draw                = 'O jogo terminou empatado.',
        opponent_resigned   = 'O teu adversário desistiu. Ganhaste! 🏆',
        you_resigned        = 'Desististe.',
        opponent_left       = 'O teu adversário saiu do jogo.',
        reward_received     = 'Recebeste uma recompensa por venceres!',
        no_npc              = 'Adversários de computador estão desativados.',
        your_turn           = 'A tua jogada',
        opp_turn            = 'Jogada do adversário',
        waiting_opponent    = 'À espera de um adversário…',
        thinking            = 'O computador está a pensar…',
        in_check            = 'Estás em xeque!',
        hud_grab            = 'Move o rato até uma peça e mantém [Botão Esquerdo] para a mover',
        hud_leave           = '[Backspace] Levantar',
        promote_title       = 'Promover peão para',
        result_win          = 'VITÓRIA',
        result_lose         = 'DERROTA',
        result_draw         = 'EMPATE',
        result_checkmate    = 'Xeque-mate',
        result_stalemate    = 'Stalemate',
        result_resign       = 'por desistência',
        result_time         = 'por tempo',
        menu_leaderboard    = '🏆 Classificação',
        menu_leaderboard_desc = 'Melhores jogadores',
        lb_title            = 'CLASSIFICAÇÃO',
        lb_subtitle         = 'Melhores jogadores por rating',
        lb_back             = 'Voltar',
        lb_empty            = 'Ainda não há jogos ranqueados',
        your_rating         = 'O teu rating',
        rating_change       = 'Rating: %d (%+d)',
        col_player          = 'Jogador',
        col_rating          = 'Rating',
        col_record          = 'V / D / E',
        side_title          = 'Escolhe o teu lado',
        side_white          = '♔ Brancas',
        side_white_desc     = 'Jogas primeiro',
        side_black          = '♚ Pretas',
        side_black_desc     = 'O adversário joga primeiro',
        side_random         = '🎲 Aleatório',
        side_random_desc    = 'Deixa a sorte decidir',
        bet_title           = 'Faz a tua aposta',
        bet_none            = 'Sem aposta',
        bet_none_desc       = 'Jogo amigável',
        bet_amount_desc     = 'O vencedor leva o pote',
        bet_insufficient    = 'Não tens dinheiro suficiente para apostar isso.',
        bet_won             = 'Ganhaste o pote: %s%s!',
        bet_refunded        = 'A tua aposta de %s%s foi devolvida.',
        join_bet            = 'Aposta: %s%s — o vencedor leva o pote',
        join_match          = '♟️ Entrar no Jogo',
        join_match_desc     = 'Ocupa o lugar livre',
    },
}

function Config.L(key, ...)
    local pack = Config.Text[Config.Locale] or Config.Text['en']
    local s = pack[key] or (Config.Text['en'][key]) or key
    if select('#', ...) > 0 then
        return string.format(s, ...)
    end
    return s
end
