
const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'ic3d_chess';

const PIECE = { w: '♔', b: '♚' }; 

const menuEl = document.getElementById('menu');
const hudEl = document.getElementById('hud');
const cardsEl = document.getElementById('cards');

function post(name, data) {
  return fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}

const panelView = document.getElementById('panel');
const lbView = document.getElementById('leaderboard');

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function showMenu() {
  menuEl.classList.remove('hidden');
  void menuEl.offsetWidth; 
  menuEl.classList.add('in');
}
function hideMenu() {
  menuEl.classList.remove('in');
  setTimeout(() => menuEl.classList.add('hidden'), 320);
}

function renderMenu(payload) {
  lbView.classList.add('hidden');
  panelView.classList.remove('hidden');
  document.getElementById('backBtn').classList.toggle('hidden', !payload.canBack);
  document.getElementById('menuSub').textContent = payload.sub || 'Choose a game mode';
  document.getElementById('menuDesc').textContent = payload.desc || '';
  cardsEl.innerHTML = '';
  (payload.options || []).forEach((opt, i) => {
    const card = document.createElement('div');
    card.className = 'card';
    card.style.animationDelay = (i * 60) + 'ms';
    card.innerHTML = `
      <div class="card-icon"><i class="fas ${opt.icon || 'fa-chess'}"></i></div>
      <div class="card-content">
        <div class="card-name">${escapeHtml(opt.title)}</div>
        <div class="card-desc">${escapeHtml(opt.desc || '')}</div>
      </div>
      <div class="card-arrow"><i class="fas fa-chevron-right"></i></div>`;
    card.onclick = () => post('menuSelect', { value: opt.value });
    cardsEl.appendChild(card);
  });
}

function setRating(d) {
  const badge = document.getElementById('ratingBadge');
  document.getElementById('rbLabel').textContent = d.label || 'Your rating';
  document.getElementById('rbElo').textContent = d.elo;
  const tag = document.getElementById('rbTag');
  tag.textContent = d.short || '';
  tag.title = d.title || '';
  if (d.color) tag.style.background = d.color;
  badge.classList.remove('hidden');
}

function renderLeaderboard(d) {
  document.getElementById('lbTitle').textContent = d.title || 'LEADERBOARD';
  document.getElementById('lbSubtitle').textContent = d.subtitle || '';
  document.getElementById('lbBack').textContent = d.back || 'Back';
  document.getElementById('lbColPlayer').textContent = d.colPlayer || 'Player';
  document.getElementById('lbColRating').textContent = d.colRating || 'Rating';
  document.getElementById('lbColRecord').textContent = d.colRecord || 'W / L / D';

  const list = document.getElementById('lbList');
  const rows = d.rows || [];
  list.innerHTML = '';
  if (!rows.length) {
    list.innerHTML = `<div class="lb-empty"><i class="fas fa-trophy"></i>${escapeHtml(d.empty || 'No ranked games yet')}</div>`;
  } else {
    rows.forEach((r, i) => {
      const row = document.createElement('div');
      row.className = 'lb-row' + (i < 3 ? ' top-' + (i + 1) : '');
      row.style.animationDelay = (i * 45) + 'ms';
      const tagStyle = r.color ? `style="background:${r.color}"` : '';
      row.innerHTML = `
        <div class="lb-rank">${i + 1}</div>
        <div class="lb-player">
          <div class="lb-name">${escapeHtml(r.name || 'Unknown')}</div>
          <div class="lb-tag" ${tagStyle} title="${escapeHtml(r.title || '')}">${escapeHtml(r.short || '')}</div>
        </div>
        <div class="lb-rating">${r.elo}</div>
        <div class="lb-record">${r.wins || 0} / ${r.losses || 0} / ${r.draws || 0}</div>`;
      list.appendChild(row);
    });
  }
  panelView.classList.add('hidden');
  lbView.classList.remove('hidden');
}

function closeLeaderboard() {
  lbView.classList.add('hidden');
  panelView.classList.remove('hidden');
}

let hud = null;        
let clock = null;      
let clockBase = 0;     
let tickTimer = null;

function fmt(t) {
  t = Math.max(0, Math.floor(t));
  const m = Math.floor(t / 60), s = t % 60;
  return `${m}:${s < 10 ? '0' : ''}${s}`;
}

function paintHud() {
  if (!hud) return;
  const role = hud.role;
  const topRole = role === 'b' ? 'w' : 'b';   
  const botRole = role === 'b' ? 'b' : 'w';
  const nameOf = (c) => (c === 'w' ? (hud.whiteName || 'White') : (hud.blackName || 'Black'));

  document.getElementById('topName').textContent = nameOf(topRole);
  document.getElementById('botName').textContent = nameOf(botRole);
  document.getElementById('topPiece').textContent = PIECE[topRole];
  document.getElementById('botPiece').textContent = PIECE[botRole];

  
  let wRem = clock ? clock.w : 0;
  let bRem = clock ? clock.b : 0;
  if (clock && clock.running && !hud.ended) {
    const elapsed = (performance.now() - clockBase) / 1000;
    if (clock.running === 'w') wRem -= elapsed; else bRem -= elapsed;
  }
  const remOf = (c) => (c === 'w' ? wRem : bRem);
  document.getElementById('topTime').textContent = clock ? fmt(remOf(topRole)) : '--:--';
  document.getElementById('botTime').textContent = clock ? fmt(remOf(botRole)) : '--:--';

  const topActive = !hud.ended && hud.turn === topRole;
  const botActive = !hud.ended && hud.turn === botRole;
  const topCard = document.getElementById('topClock');
  const botCard = document.getElementById('botClock');
  topCard.classList.toggle('active', topActive);
  botCard.classList.toggle('active', botActive);
  topCard.classList.toggle('low', clock && remOf(topRole) <= 30);
  botCard.classList.toggle('low', clock && remOf(botRole) <= 30);

  
  const pill = document.getElementById('statusPill');
  const txt = document.getElementById('statusText');
  pill.classList.remove('check');
  let s;
  if (hud.ended) {
    s = 'Game over';
  } else if (hud.waiting) {
    s = 'Waiting for opponent…';
  } else if (hud.vsNpc && hud.turn === hud.npc) {
    s = 'Computer is thinking…';
  } else if (hud.turn === role) {
    if (hud.status === 'check') { s = 'You are in check!'; pill.classList.add('check'); }
    else s = 'Your move';
  } else {
    s = "Opponent's move";
  }
  txt.textContent = s;
}

function startTicker() {
  if (tickTimer) return;
  tickTimer = setInterval(paintHud, 250);
}
function stopTicker() {
  if (tickTimer) { clearInterval(tickTimer); tickTimer = null; }
}

window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.action) {
    case 'openMenu':
      renderMenu(d);
      showMenu();
      break;
    case 'myRating':
      setRating(d);
      break;
    case 'showLeaderboard':
      renderLeaderboard(d);
      break;
    case 'closeMenu':
      hideMenu();
      break;
    case 'showHud':
      hud = d.hud;
      clock = d.clock || null;
      clockBase = performance.now();
      hudEl.classList.remove('hidden');
      paintHud();
      startTicker();
      break;
    case 'updateHud':
      hud = d.hud;
      clock = d.clock || null;
      clockBase = performance.now();
      paintHud();
      break;
    case 'hideHud':
      hudEl.classList.add('hidden');
      stopTicker();
      hud = null; clock = null;
      break;
  }
});

document.addEventListener('keyup', (e) => {
  if (e.key === 'Escape' && !menuEl.classList.contains('hidden')) post('menuClose');
});

if (!window.invokeNative) {
  renderMenu({
    sub: 'Choose a game mode',
    desc: 'Play against another player or challenge the computer.',
    options: [
      { value: 'create', title: 'Play vs Player', desc: 'Sit as White and wait for an opponent', icon: 'fa-users' },
      { value: 'npc', title: 'Play vs Computer', desc: 'Challenge the AI (3 difficulties)', icon: 'fa-robot' },
      { value: 'leaderboard', title: '🏆 Leaderboard', desc: 'Top rated players', icon: 'fa-ranking-star' },
    ],
  });
  setRating({ label: 'Your rating', elo: 1284, title: 'Intermediate', short: 'INT', color: '#a9e34b' });
  showMenu();
  window.__demoLb = () => renderLeaderboard({
    title: 'LEADERBOARD', subtitle: 'Top players by rating', back: 'Back',
    colPlayer: 'Player', colRating: 'Rating', colRecord: 'W / L / D',
    rows: [
      { name: 'Magnus C.', elo: 2531, short: 'GM', color: '#ff4d4d', title: 'Grandmaster', wins: 142, losses: 11, draws: 30 },
      { name: 'Hikaru N.', elo: 2402, short: 'IM', color: '#ff8c42', title: 'International Master', wins: 98, losses: 20, draws: 14 },
      { name: 'Beth H.', elo: 2188, short: 'FM', color: '#ffd43b', title: 'FIDE Master', wins: 60, losses: 22, draws: 9 },
      { name: 'Dave', elo: 1740, short: 'EXP', color: '#74c0fc', title: 'Expert', wins: 30, losses: 25, draws: 5 },
      { name: 'Rookie Joe', elo: 1010, short: 'CAS', color: '#ced4da', title: 'Casual', wins: 4, losses: 12, draws: 1 },
    ],
  });
  hud = { role: 'w', whiteName: 'You', blackName: 'Computer (medium)', turn: 'w', status: 'active', ended: false, waiting: false, vsNpc: true, npc: 'b' };
  clock = { w: 600, b: 583, running: 'w' };
  clockBase = performance.now();
  hudEl.classList.remove('hidden');
  paintHud();
  startTicker();
}
