/* ============================================================
   IRON FRONTLINE — realistic top-down tactical defense
   Pure canvas + WebAudio, no external assets.
   ============================================================ */
'use strict';

// ---------- canvas & world ----------
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
const W = 960, H = 624, TILE = 48;
const COLS = W / TILE, ROWS = H / TILE;
canvas.width = W; canvas.height = H;

const GRAV = 1700;   // px/s^2 for artillery shells

// ---------- road path (pixel waypoints) ----------
const PATH = [
  { x: -40,  y: 300 },
  { x: 230,  y: 300 },
  { x: 230,  y: 150 },
  { x: 470,  y: 150 },
  { x: 470,  y: 430 },
  { x: 710,  y: 430 },
  { x: 710,  y: 230 },
  { x: 1020, y: 230 },
];
const BASE = { x: 920, y: 230, r: 46 };
const ROAD_W = 46;

// ---------- small utils ----------
const clamp = (v, a, b) => v < a ? a : (v > b ? b : v);
const dist = (x1, y1, x2, y2) => Math.hypot(x2 - x1, y2 - y1);
const angTo = (x1, y1, x2, y2) => Math.atan2(y2 - y1, x2 - x1);
const lerp = (a, b, t) => a + (b - a) * t;

function segDist(px, py, x1, y1, x2, y2) {
  const dx = x2 - x1, dy = y2 - y1;
  const l2 = dx * dx + dy * dy;
  if (l2 === 0) return dist(px, py, x1, y1);
  let t = ((px - x1) * dx + (py - y1) * dy) / l2;
  t = clamp(t, 0, 1);
  return dist(px, py, x1 + t * dx, y1 + t * dy);
}
function distToPath(x, y) {
  let m = Infinity;
  for (let i = 0; i < PATH.length - 1; i++) m = Math.min(m, segDist(x, y, PATH[i].x, PATH[i].y, PATH[i + 1].x, PATH[i + 1].y));
  return m;
}

// deterministic pseudo-random for decorations
let seed = 7;
function rng() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }

// ---------- weapon definitions ----------
const WEAPONS = {
  mg:      { name: 'MG Nest',        cost: 110, range: 190, rof: 0.09, dmg: 7,   kind: 'bullet',    icon: '⚙',
              desc: 'Rapid suppressing fire. Light damage, cheap.' },
  flame:   { name: 'Flamethrower',   cost: 160, range: 120, rof: 0.12, dmg: 11,  kind: 'flame',    icon: '🔥',
              desc: 'Short-range cone of fire. Burns infantry.' },
  missile: { name: 'Missile Pod',    cost: 190, range: 270, rof: 1.5,  dmg: 52,  kind: 'missile',  icon: '🚀',
              desc: 'Homing missiles. Deadly vs vehicles & drones.' },
  cannon:  { name: 'Field Cannon',   cost: 220, range: 255, rof: 1.8,  dmg: 85,  kind: 'shell',    icon: '💥',
              desc: 'Arcing high-explosive shells with splash damage.' },
  railgun: { name: 'Railgun',        cost: 330, range: 370, rof: 2.5,  dmg: 175, kind: 'rail',     icon: '⚡',
              desc: 'Long-range penetrator. Pierces multiple targets.' },
};
const WKEYS = Object.keys(WEAPONS);
const MAXLVL = 5;

// ---------- enemy definitions ----------
const ENEMIES = {
  infantry: { hp: 30,  speed: 72,  r: 7,  reward: 8,  dmg: 1,   armor: 1 },
  scout:    { hp: 45,  speed: 140, r: 9,  reward: 11, dmg: 1.5, armor: 1 },
  drone:    { hp: 60,  speed: 108, r: 8,  reward: 13, dmg: 1,   armor: 0.7 },
  armored:  { hp: 215, speed: 42,  r: 14, reward: 24, dmg: 3,   armor: 3 },
  heavy:    { hp: 580, speed: 30,  r: 17, reward: 48, dmg: 5,   armor: 5 },
};

// damage-class resistance tables (multiplier vs armor)
const DMGCLASS = ['bullet', 'explosive', 'missile', 'rail', 'fire'];
const RESIST = {
  infantry: { bullet: 1.0, explosive: 0.7, missile: 1.25, rail: 1.4, fire: 1.5 },
  scout:    { bullet: 1.0, explosive: 0.8, missile: 1.1, rail: 1.2, fire: 1.2 },
  drone:    { bullet: 0.8, explosive: 0.6, missile: 1.4, rail: 1.2, fire: 1.3 },
  armored:  { bullet: 0.45, explosive: 0.9, missile: 1.1, rail: 0.9, fire: 0.7 },
  heavy:    { bullet: 0.4, explosive: 0.75, missile: 1.0, rail: 0.85, fire: 0.5 },
};

// ---------- game state ----------
let state = 'menu';          // menu | playing | paused | over | won
let supplies = 160;
let integrity = 100;
let wave = 0;
let waveQueue = [];          // enemies to spawn in current wave
let spawnTimer = 0;
let buildMode = null;        // weapon key being placed
let selectedId = null;       // id of selected placed tower
let nextId = 1;
let time = 0;
let shake = 0;
let speed = 1;

const towers = [];
const enemies = [];
const bullets = [];
const shells = [];
const missiles = [];
const particles = [];
const flashes = [];
const beams = [];             // railgun beam lines
const floats = [];           // floating combat text

// wave roster (counts per type)
const WAVE_PLAN = [];
function buildWavePlan() {
  for (let w = 1; w <= 25; w++) {
    const plan = [];
    plan.push(['infantry', Math.floor(6 + w * 1.3)]);
    if (w >= 3)  plan.push(['scout', Math.floor(2 + w * 0.4)]);
    if (w >= 5)  plan.push(['drone', Math.floor(1 + w * 0.4)]);
    if (w >= 7)  plan.push(['armored', Math.floor(1 + (w - 6) * 0.5)]);
    if (w >= 13) plan.push(['heavy', w >= 20 ? 2 : 1]);
    WAVE_PLAN.push(plan);
  }
}
buildWavePlan();

// ---------- audio ----------
// Real CC0 sound effects downloaded from Kenney.nl into assets/audio/.
// Each SFX call tries a real sample first; if the sample set isn't loaded yet
// (e.g. the page was opened straight from disk without a local server, so fetch
// is unavailable), it automatically falls back to the synthesized sound below.
// Audio can never break.
const SAMPLE_FILES = {
  cannon: [
    'assets/audio/impact-sounds/Audio/impactPlate_heavy_001.ogg',
    'assets/audio/impact-sounds/Audio/impactMetal_heavy_002.ogg',
    'assets/audio/impact-sounds/Audio/impactPunch_heavy_003.ogg',
    'assets/audio/impact-sounds/Audio/impactPlate_heavy_004.ogg',
  ],
  boom: [
    'assets/audio/impact-sounds/Audio/impactMetal_heavy_000.ogg',
    'assets/audio/impact-sounds/Audio/impactPlate_heavy_002.ogg',
    'assets/audio/impact-sounds/Audio/impactPunch_heavy_000.ogg',
    'assets/audio/impact-sounds/Audio/impactPlate_heavy_003.ogg',
  ],
  bullet: [
    'assets/audio/impact-sounds/Audio/impactMetal_light_001.ogg',
    'assets/audio/impact-sounds/Audio/impactGeneric_light_000.ogg',
    'assets/audio/impact-sounds/Audio/impactTin_medium_002.ogg',
    'assets/audio/impact-sounds/Audio/impactMetal_light_004.ogg',
  ],
  rail: [
    'assets/audio/impact-sounds/Audio/impactMetal_medium_001.ogg',
    'assets/audio/impact-sounds/Audio/impactPunch_heavy_002.ogg',
    'assets/audio/impact-sounds/Audio/impactMetal_medium_003.ogg',
  ],
  hit: [
    'assets/audio/impact-sounds/Audio/impactGeneric_light_002.ogg',
    'assets/audio/impact-sounds/Audio/impactWood_light_001.ogg',
    'assets/audio/impact-sounds/Audio/impactGeneric_light_004.ogg',
  ],
  place: [
    'assets/audio/interface-sounds/Audio/click_002.ogg',
    'assets/audio/interface-sounds/Audio/confirmation_002.ogg',
    'assets/audio/interface-sounds/Audio/drop_001.ogg',
    'assets/audio/interface-sounds/Audio/click_005.ogg',
  ],
  sell: [
    'assets/audio/interface-sounds/Audio/drop_003.ogg',
    'assets/audio/interface-sounds/Audio/close_002.ogg',
    'assets/audio/interface-sounds/Audio/drop_001.ogg',
  ],
  upgrade: [
    'assets/audio/interface-sounds/Audio/confirmation_001.ogg',
    'assets/audio/interface-sounds/Audio/click_004.ogg',
    'assets/audio/interface-sounds/Audio/confirmation_003.ogg',
  ],
};
const SFX = {
  ctx: null, enabled: true, noise: null, master: null,
  buf: {}, _loading: false, _loaded: false,
  ensure() {
    if (this.ctx) return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    this.ctx = new AC();
    this.master = this.ctx.createGain();
    this.master.gain.value = 0.55;
    this.master.connect(this.ctx.destination);
    const len = this.ctx.sampleRate * 1;
    this.noise = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const d = this.noise.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    this.loadSamples();
  },
  async loadSamples() {
    if (!this.ctx || this._loading || this._loaded) return;
    this._loading = true;
    try {
      for (const [key, paths] of Object.entries(SAMPLE_FILES)) {
        const arr = [];
        for (const p of paths) {
          try {
            const res = await fetch(p);
            if (!res.ok) continue;
            arr.push(await this.ctx.decodeAudioData(await res.arrayBuffer()));
          } catch (e) { /* offline / decode failure -> keep fallback */ }
        }
        if (arr.length) this.buf[key] = arr;
      }
    } finally { this._loading = false; this._loaded = true; }
  },
  sample(key) {
    if (!this.enabled || !this.ctx) return false;
    const arr = this.buf[key];
    if (!arr || !arr.length) return false;
    const b = arr[(Math.random() * arr.length) | 0];
    const src = this.ctx.createBufferSource();
    src.buffer = b;
    const g = this.ctx.createGain();
    const t = this.ctx.currentTime;
    g.gain.setValueAtTime(0.9, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + b.duration - 0.02);
    src.connect(g).connect(this.master);
    src.start(t);
    return true;
  },
  noiseBurst(dur, filterType, freq, q, gain) {
    if (!this.enabled || !this.ctx) return;
    const src = this.ctx.createBufferSource();
    src.buffer = this.noise;
    const f = this.ctx.createBiquadFilter();
    f.type = filterType; f.frequency.value = freq; f.Q.value = q;
    const g = this.ctx.createGain();
    const t = this.ctx.currentTime;
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    src.connect(f).connect(g).connect(this.master);
    src.start(t); src.stop(t + dur + 0.02);
  },
  tone(freq, dur, type, gain, slideTo) {
    if (!this.enabled || !this.ctx) return;
    const o = this.ctx.createOscillator();
    o.type = type; o.frequency.setValueAtTime(freq, this.ctx.currentTime);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, this.ctx.currentTime + dur);
    const g = this.ctx.createGain();
    const t = this.ctx.currentTime;
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g).connect(this.master);
    o.start(t); o.stop(t + dur + 0.02);
  },
  shoot(kind) {
    switch (kind) {
      case 'bullet': if (this.sample('bullet')) return; this.noiseBurst(0.07, 'bandpass', 1500, 1.2, 0.5); this.tone(220, 0.05, 'square', 0.08, 80); break;
      case 'cannon': if (this.sample('cannon')) return; this.noiseBurst(0.25, 'lowpass', 700, 0.8, 0.9); this.tone(90, 0.3, 'sine', 0.7, 40); break;
      case 'missile': this.tone(160, 0.5, 'sawtooth', 0.12, 700); break;
      case 'rail': if (this.sample('rail')) return; this.noiseBurst(0.12, 'highpass', 3000, 2, 0.6); this.tone(60, 0.1, 'square', 0.2, 900); break;
      case 'flame': this.noiseBurst(0.15, 'lowpass', 500, 0.6, 0.25); break;
    }
  },
  boom(big) {
    if (this.sample('boom')) return;
    this.noiseBurst(big ? 0.6 : 0.4, 'lowpass', big ? 400 : 600, 0.6, big ? 1.0 : 0.7);
    this.tone(big ? 70 : 90, big ? 0.5 : 0.35, 'sine', big ? 0.9 : 0.6, 35);
  },
  missileExplode() { if (this.sample('boom')) return; this.noiseBurst(0.3, 'lowpass', 900, 0.7, 0.6); this.tone(110, 0.25, 'sine', 0.4, 50); },
  hit() { if (this.sample('hit')) return; this.noiseBurst(0.03, 'highpass', 2500, 1, 0.2); },
  alarm() { this.tone(320, 0.35, 'square', 0.12, 240); this.tone(420, 0.35, 'square', 0.08, 300); },
  horn() { this.tone(140, 0.9, 'sawtooth', 0.18, 110); this.tone(180, 0.9, 'triangle', 0.14, 130); },
  place() { if (this.sample('place')) return; this.tone(300, 0.08, 'triangle', 0.2, 500); },
  sell() { if (this.sample('sell')) return; this.noiseBurst(0.15, 'lowpass', 800, 0.8, 0.5); },
  upgrade() { if (this.sample('upgrade')) return; this.tone(400, 0.1, 'triangle', 0.2, 700); },
};
function ensureAudio() { SFX.ensure(); }
canvas.addEventListener('pointerdown', ensureAudio, { once: true });

// ---------- terrain / background ----------
const bgCanvas = document.createElement('canvas');
bgCanvas.width = W; bgCanvas.height = H;
const bctx = bgCanvas.getContext('2d');
const occupied = [];   // grid bool: road/base
for (let r = 0; r < ROWS; r++) occupied.push(new Array(COLS).fill(false));

function buildBackground() {
  // base grass
  bctx.fillStyle = '#3d4a2f';
  bctx.fillRect(0, 0, W, H);
  // mottled noise patches
  for (let i = 0; i < 1400; i++) {
    const x = rng() * W, y = rng() * H;
    const tone = 0.85 + rng() * 0.3;
    const g = Math.floor(72 * tone) + (rng() < 0.5 ? 6 : -6);
    bctx.fillStyle = `rgba(${Math.floor(50*tone)},${g},${Math.floor(34*tone)},0.5)`;
    bctx.fillRect(x, y, 3 + rng() * 6, 3 + rng() * 6);
  }
  // subtle grid / terrain cracks
  bctx.strokeStyle = 'rgba(0,0,0,0.06)';
  bctx.lineWidth = 1;
  for (let i = 0; i < 90; i++) {
    const x = rng() * W, y = rng() * H;
    bctx.beginPath(); bctx.moveTo(x, y);
    bctx.bezierCurveTo(x + rng()*40 - 20, y + rng()*40 - 20, x + rng()*60 - 30, y + rng()*60 - 30, x + rng()*80 - 40, y + rng()*80 - 40);
    bctx.stroke();
  }

  // road
  bctx.lineCap = 'round'; bctx.lineJoin = 'round';
  bctx.strokeStyle = '#6b5a3e'; bctx.lineWidth = ROAD_W;
  bctx.beginPath();
  bctx.moveTo(PATH[0].x, PATH[0].y);
  for (let i = 1; i < PATH.length; i++) bctx.lineTo(PATH[i].x, PATH[i].y);
  bctx.stroke();
  bctx.strokeStyle = '#5a4b33'; bctx.lineWidth = ROAD_W - 10;
  bctx.stroke();
  // road tracks / center dashes
  bctx.strokeStyle = 'rgba(220,205,150,0.35)'; bctx.lineWidth = 3;
  bctx.setLineDash([14, 18]);
  bctx.beginPath();
  bctx.moveTo(PATH[0].x, PATH[0].y);
  for (let i = 1; i < PATH.length; i++) bctx.lineTo(PATH[i].x, PATH[i].y);
  bctx.stroke();
  bctx.setLineDash([]);

  // mark occupancy
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const x = c * TILE + TILE / 2, y = r * TILE + TILE / 2;
      if (distToPath(x, y) < ROAD_W / 2 + 6) occupied[r][c] = true;
      if (dist(x, y, BASE.x, BASE.y) < BASE.r + 12) occupied[r][c] = true;
    }
  }

  // decorations on grass
  const deco = [];
  for (let i = 0; i < 60; i++) {
    const x = rng() * W, y = rng() * H;
    if (distToPath(x, y) > 55 && dist(x, y, BASE.x, BASE.y) > BASE.r + 40) deco.push([x, y, rng()]);
  }
  for (const [x, y, r] of deco) {
    if (r < 0.4) { // tuft of grass
      bctx.strokeStyle = 'rgba(60,80,45,0.8)'; bctx.lineWidth = 2;
      for (let k = 0; k < 4; k++) {
        bctx.beginPath(); bctx.moveTo(x, y);
        bctx.lineTo(x + (rng()*20-10), y - 6 - rng()*10); bctx.stroke();
      }
    } else if (r < 0.7) { // bush
      bctx.fillStyle = 'rgba(48,66,40,0.9)';
      bctx.beginPath(); bctx.arc(x, y, 8 + rng()*5, 0, 7); bctx.fill();
      bctx.fillStyle = 'rgba(60,80,50,0.85)';
      bctx.beginPath(); bctx.arc(x + 5, y + 3, 6 + rng()*4, 0, 7); bctx.fill();
    } else { // rock
      bctx.fillStyle = 'rgba(110,110,100,0.9)';
      bctx.beginPath(); bctx.arc(x, y, 6 + rng()*4, 0, 7); bctx.fill();
      bctx.fillStyle = 'rgba(130,130,118,0.9)';
      bctx.beginPath(); bctx.arc(x - 2, y - 2, 3.5, 0, 7); bctx.fill();
    }
  }

  // base pad
  bctx.fillStyle = 'rgba(40,44,38,0.9)';
  bctx.beginPath(); bctx.arc(BASE.x, BASE.y, BASE.r + 6, 0, 7); bctx.fill();
  bctx.strokeStyle = 'rgba(200,190,140,0.6)'; bctx.lineWidth = 3;
  bctx.stroke();
  bctx.fillStyle = 'rgba(70,74,60,1)';
  bctx.beginPath(); bctx.arc(BASE.x, BASE.y, BASE.r - 6, 0, 7); bctx.fill();
  // HQ structure
  bctx.fillStyle = '#4f5648';
  bctx.fillRect(BASE.x - 18, BASE.y - 18, 36, 36);
  bctx.fillStyle = '#6a7360';
  bctx.fillRect(BASE.x - 14, BASE.y - 14, 28, 28);
  bctx.fillStyle = '#3b4132';
  bctx.fillRect(BASE.x - 16, BASE.y - 22, 32, 6); // roof
  bctx.strokeStyle = 'rgba(230,220,170,0.9)'; bctx.lineWidth = 2;
  // flag
  bctx.fillStyle = '#c8462e';
  bctx.fillRect(BASE.x + 20, BASE.y - 26, 16, 10);
  bctx.strokeStyle = '#a8a088'; bctx.beginPath(); bctx.moveTo(BASE.x + 22, BASE.y - 26); bctx.lineTo(BASE.x + 22, BASE.y - 8); bctx.stroke();
}
buildBackground();

// ---------- helpers: facing rendering ----------
function drawShadow(x, y, r) {
  ctx.fillStyle = 'rgba(0,0,0,0.28)';
  ctx.beginPath(); ctx.ellipse(x + 3, y + 4, r, r * 0.7, 0, 0, 7); ctx.fill();
}

// ---------- particles ----------
function addParticle(o) {
  o.life = o.life || 0.6; o.maxLife = o.life; o.alpha = o.alpha === undefined ? 1 : o.alpha;
  particles.push(o);
}
function smoke(x, y, n, big) {
  for (let i = 0; i < n; i++) {
    const a = rng() * Math.PI * 2, sp = (big ? 30 : 18) * (0.4 + rng());
    addParticle({
      x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 12,
      type: 'smoke', size: (big ? 10 : 6) + rng() * 6,
      life: 0.6 + rng() * 0.8, drag: 0.92,
    });
  }
}
function sparks(x, y, n, color) {
  for (let i = 0; i < n; i++) {
    const a = rng() * Math.PI * 2, sp = 60 + rng() * 180;
    addParticle({
      x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
      type: 'spark', size: 1.5 + rng() * 2, color: color || '#ffd98a',
      life: 0.25 + rng() * 0.3, drag: 0.9,
    });
  }
}
function flash(x, y, r, color) {
  flashes.push({ x, y, r, life: 0.12, max: 0.12, color: color || '#fff0c0' });
}

function explode(x, y, radius, dmg, classLabel, fromTower) {
  flash(x, y, radius * 0.8);
  sparks(x, y, 20, '#ffcf7d');
  smoke(x, y, 12, radius > 55);
  shake = Math.min(24, shake + radius * 0.3);
  SFX.boom(radius > 55);
  for (const e of enemies) {
    const d = dist(x, y, e.x, e.y);
    if (d < radius + e.r) {
      const falloff = 1 - d / (radius + e.r);
      damageEnemy(e, dmg * falloff, classLabel, fromTower);
    }
  }
}

function addFloat(x, y, txt, color) {
  floats.push({ x, y, txt, color, life: 0.9, max: 0.9 });
}

// ---------- enemies ----------
function makeEnemy(type) {
  const cfg = ENEMIES[type];
  const hpScale = 1 + (wave - 1) * 0.06;
  return {
    id: nextId++,
    type,
    hp: cfg.hp * hpScale, maxHp: cfg.hp * hpScale,
    speed: cfg.speed * (0.9 + rng() * 0.2),
    r: cfg.r, reward: cfg.reward, dmg: cfg.dmg,
    seg: 0, t: 0,
    x: PATH[0].x, y: PATH[0].y,
    angle: 0, dead: false, arrived: false,
    fireT: rng() * 0.5,
    hover: rng() * 6.28,
  };
}
function advanceEnemy(e, dt) {
  let step = e.speed * dt;
  while (step > 0) {
    const a = PATH[e.seg], b = PATH[e.seg + 1];
    const segLen = dist(a.x, a.y, b.x, b.y);
    const remaining = (1 - e.t) * segLen;
    if (step >= remaining) {
      step -= remaining;
      e.seg++;
      e.t = 0;
      if (e.seg >= PATH.length - 1) {
        e.t = 1;
        // reached base
        integrity = Math.max(0, integrity - e.dmg);
        SFX.alarm();
        addFloat(BASE.x, BASE.y - 30, '-' + e.dmg + ' INTEGRITY', '#e06a4f');
        e.arrived = true;
        e.dead = true;
        shake = Math.max(shake, 8);
        return;
      }
    } else {
      e.t += step / segLen;
      step = 0;
    }
  }
  const a = PATH[e.seg], b = PATH[e.seg + 1];
  const nx = lerp(a.x, b.x, e.t), ny = lerp(a.y, b.y, e.t);
  e.angle = angTo(e.x, e.y, nx, ny);
  e.x = nx; e.y = ny;
}
function damageEnemy(e, amt, classLabel, fromTower) {
  if (e.dead) return;
  const mult = RESIST[e.type][classLabel] || 1;
  const dmg = amt * mult;
  e.hp -= dmg;
  e.fireT = 0.15;
  if (e.hp <= 0) {
    e.dead = true;
    supplies += e.reward;
    sparks(e.x, e.y, 10, '#b98a4e');
    smoke(e.x, e.y, 4, false);
    addFloat(e.x, e.y - 12, '+' + e.reward, '#9fcb6e');
    SFX.hit();
  } else {
    SFX.hit();
  }
}

// ---------- towers ----------
function makeTower(key, x, y) {
  const w = WEAPONS[key];
  return {
    id: nextId++, key, x, y, lvl: 1,
    angle: 0, cd: 0, target: null,
    cost: w.cost, recoil: 0, fireT: 0,
  };
}
function towerStats(t) {
  const w = WEAPONS[t.key];
  const f = 1 + (t.lvl - 1) * 0.35;
  return {
    range: w.range * (1 + (t.lvl - 1) * 0.06),
    rof: w.rof / f,
    dmg: w.dmg * f,
    splash: w.splash ? w.splash * (1 + (t.lvl - 1) * 0.08) : 0,
  };
}
function upgradeCost(t) {
  return Math.round(WEAPONS[t.key].cost * 0.8 * t.lvl);
}
function sellValue(t) {
  let v = WEAPONS[t.key].cost;
  for (let l = 2; l <= t.lvl; l++) v += upgradeCost({ key: t.key, lvl: l - 1 });
  return Math.round(v * 0.7);
}
function findTarget(t) {
  const s = towerStats(t);
  let best = null, bd = s.range;
  for (const e of enemies) {
    if (e.dead) continue;
    const d = dist(t.x, t.y, e.x, e.y);
    if (d < bd) { bd = d; best = e; }
  }
  return best;
}

function fireTower(t, target) {
  const s = towerStats(t);
  const w = WEAPONS[t.key];
  t.recoil = 1;
  t.cd = s.rof;
  t.angle = angTo(t.x, t.y, target.x, target.y);
  SFX.shoot(w.kind === 'shell' ? 'cannon' : w.kind);

  switch (w.kind) {
    case 'bullet': {
      const sp = 950;
      bullets.push({
        x: t.x + Math.cos(t.angle) * 18, y: t.y + Math.sin(t.angle) * 18,
        vx: Math.cos(t.angle) * sp, vy: Math.sin(t.angle) * sp,
        dmg: s.dmg, life: s.range / sp, fromTower: t.id,
        trail: [{ x: t.x, y: t.y }],
      });
      flash(t.x + Math.cos(t.angle) * 20, t.y + Math.sin(t.angle) * 20, 8, '#ffe9a8');
      break;
    }
    case 'flame': {
      // continuous DoT handled in update when in range
      break;
    }
    case 'missile': {
      missiles.push({
        x: t.x, y: t.y, target,
        angle: t.angle, speed: 200,
        dmg: s.dmg, life: 3.5, fromTower: t.id,
      });
      break;
    }
    case 'shell': {
      const D = dist(t.x, t.y, target.x, target.y);
      const flightT = D / 420;
      shells.push({
        x: t.x + Math.cos(t.angle) * 16, y: t.y + Math.sin(t.angle) * 16,
        vx: (target.x - t.x) / flightT,
        vy: GRAV * flightT / 2,
        t: 0, flightT, dmg: s.dmg, radius: s.splash || 60,
        fromTower: t.id,
      });
      break;
    }
    case 'rail': {
      // hitscan pierce
      const ex = Math.cos(t.angle), ey = Math.sin(t.angle);
      let hits = 0;
      beams.push({
        x1: t.x + ex * 18, y1: t.y + ey * 18,
        x2: t.x + ex * s.range, y2: t.y + ey * s.range,
        life: 0.14, max: 0.14,
      });
      flash(t.x + ex * 30, t.y + ey * 30, 14, '#cfeaff');
      for (const e of enemies) {
        if (e.dead || hits >= 6) continue;
        const rx = e.x - t.x, ry = e.y - t.y;
        const proj = rx * ex + ry * ey;
        if (proj < 0 || proj > s.range) continue;
        const perp = Math.abs(rx * ey - ry * ex);
        if (perp < e.r + 5) { hits++; damageEnemy(e, s.dmg, 'rail', t.id); }
      }
      break;
    }
  }
}

// ---------- spawn / waves ----------
function startWave() {
  wave++;
  document.getElementById('wave').textContent = wave;
  const plan = WAVE_PLAN[wave - 1] || [];
  waveQueue = [];
  for (const [type, count] of plan) {
    for (let i = 0; i < count; i++) waveQueue.push({ type, delay: i * (0.25 + rng() * 0.3) });
  }
  waveQueue.sort((a, b) => a.delay - b.delay);
  spawnTimer = 0;
  let maxDelay = 0;
  for (const q of waveQueue) maxDelay = Math.max(maxDelay, q.delay);
  setTimeout(() => { if (state === 'playing') SFX.horn(); }, Math.max(0, (maxDelay - 2.5)) * 1000);
}

// ---------- update ----------
function update(dt) {
  time += dt;

  // spawn
  if (state === 'playing' && waveQueue.length) {
    spawnTimer += dt;
    while (waveQueue.length && waveQueue[0].delay <= spawnTimer) {
      const q = waveQueue.shift();
      enemies.push(makeEnemy(q.type));
    }
  }

  // enemies
  for (let i = enemies.length - 1; i >= 0; i--) {
    const e = enemies[i];
    if (e.dead) { enemies.splice(i, 1); continue; }
    advanceEnemy(e, dt);
    e.fireT = Math.max(0, e.fireT - dt);
  }

  // towers
  for (const t of towers) {
    t.cd -= dt;
    t.recoil = Math.max(0, t.recoil - dt * 4);
    t.fireT = Math.max(0, t.fireT - dt);
    if (state !== 'playing') continue;
    const target = findTarget(t);
    const w = WEAPONS[t.key];
    if (w.kind === 'flame') {
      // flamethrower: continuous cone
      t.cd -= dt; // keep firing
      if (target) {
        t.angle = angTo(t.x, t.y, target.x, target.y);
        const cone = 0.7;
        let fired = false;
        for (const e of enemies) {
          if (e.dead) continue;
          const d = dist(t.x, t.y, e.x, e.y);
          if (d > towerStats(t).range) continue;
          const a = angTo(t.x, t.y, e.x, e.y);
          let da = a - t.angle;
          while (da > Math.PI) da -= 2 * Math.PI;
          while (da < -Math.PI) da += 2 * Math.PI;
          if (Math.abs(da) < cone) {
            damageEnemy(e, towerStats(t).dmg * dt * 8, 'fire', t.id);
            fired = true;
            // flame particles
            addParticle({
              x: t.x + Math.cos(a) * d * 0.7, y: t.y + Math.sin(a) * d * 0.7,
              vx: Math.cos(a) * 30, vy: Math.sin(a) * 30 - 20,
              type: 'flame', size: 4 + rng() * 4, life: 0.3, color: '#ff8c2a',
            });
          }
        }
        if (fired && t.fireT <= 0) { SFX.shoot('flame'); t.fireT = 0.12; }
      }
      continue;
    }
    if (target && t.cd <= 0) fireTower(t, target);
  }

  // bullets
  for (let i = bullets.length - 1; i >= 0; i--) {
    const b = bullets[i];
    b.x += b.vx * dt; b.y += b.vy * dt;
    b.life -= dt;
    b.trail.push({ x: b.x, y: b.y });
    if (b.trail.length > 4) b.trail.shift();
    let hit = false;
    for (const e of enemies) {
      if (e.dead) continue;
      if (dist(b.x, b.y, e.x, e.y) < e.r + 3) {
        damageEnemy(e, b.dmg, 'bullet', b.fromTower);
        hit = true; break;
      }
    }
    if (hit || b.life <= 0 || b.x < -20 || b.x > W + 20 || b.y < -20 || b.y > H + 20) {
      bullets.splice(i, 1);
    }
  }

  // shells (arc)
  for (let i = shells.length - 1; i >= 0; i--) {
    const s = shells[i];
    s.t += dt;
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    s.vy -= GRAV * dt;
    if (s.t >= s.flightT) {
      explode(s.x, s.y, s.radius, s.dmg, 'explosive', s.fromTower);
      shells.splice(i, 1);
    }
  }

  // missiles (homing)
  for (let i = missiles.length - 1; i >= 0; i--) {
    const m = missiles[i];
    m.life -= dt;
    m.speed = Math.min(520, m.speed + 260 * dt);
    if (m.target && !m.target.dead) {
      const want = angTo(m.x, m.y, m.target.x, m.target.y);
      let da = want - m.angle;
      while (da > Math.PI) da -= 2 * Math.PI;
      while (da < -Math.PI) da += 2 * Math.PI;
      m.angle += clamp(da, -3.2 * dt, 3.2 * dt);
    }
    m.x += Math.cos(m.angle) * m.speed * dt;
    m.y += Math.sin(m.angle) * m.speed * dt;
    // smoke trail
    if (Math.random() < 0.5) addParticle({
      x: m.x, y: m.y, vx: 0, vy: -8,
      type: 'smoke', size: 3 + rng() * 3, life: 0.5, drag: 0.94,
    });
    let boom = false;
    if (m.target && !m.target.dead && dist(m.x, m.y, m.target.x, m.target.y) < m.target.r + 10) {
      explode(m.x, m.y, 38, m.dmg, 'missile', m.fromTower);
      boom = true;
    } else if (m.life <= 0 || m.x < -10 || m.x > W + 10 || m.y < -10 || m.y > H + 10) {
      explode(m.x, m.y, 30, m.dmg * 0.5, 'missile', m.fromTower);
      boom = true;
    }
    if (boom) missiles.splice(i, 1);
  }

  // particles
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    p.life -= dt;
    if (p.life <= 0) { particles.splice(i, 1); continue; }
    p.x += p.vx * dt; p.y += p.vy * dt;
    p.vx *= p.drag; p.vy *= p.drag;
    if (p.type === 'smoke') p.size += 18 * dt;
  }
  // flashes
  for (let i = flashes.length - 1; i >= 0; i--) {
    flashes[i].life -= dt;
    if (flashes[i].life <= 0) flashes.splice(i, 1);
  }
  // floats
  for (let i = floats.length - 1; i >= 0; i--) {
    const f = floats[i];
    f.life -= dt; f.y -= 26 * dt;
    if (f.life <= 0) floats.splice(i, 1);
  }

  // beams
  for (let i = beams.length - 1; i >= 0; i--) {
    beams[i].life -= dt;
    if (beams[i].life <= 0) beams.splice(i, 1);
  }

  // shake decay
  shake = Math.max(0, shake - dt * 40);

  // wave complete check
  if (state === 'playing' && !waveQueue.length && !enemies.length) {
    if (wave >= 25) { endGame(true); }
    else { startWave(); }
  }
}

// ---------- rendering ----------
function render() {
  ctx.save();
  if (shake > 0.3) ctx.translate((Math.random() - 0.5) * shake, (Math.random() - 0.5) * shake);

  // background
  ctx.drawImage(bgCanvas, 0, 0);

  // railgun beams
  for (const b of beams) {
    const a = b.life / b.max;
    ctx.strokeStyle = `rgba(180,225,255,${0.55*a})`;
    ctx.lineWidth = 2.5;
    ctx.beginPath(); ctx.moveTo(b.x1, b.y1); ctx.lineTo(b.x2, b.y2); ctx.stroke();
    ctx.strokeStyle = `rgba(255,255,255,${0.9*a})`;
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(b.x1, b.y1); ctx.lineTo(b.x2, b.y2); ctx.stroke();
  }

  // build-mode range preview
  if (buildMode && state === 'playing') {
    // ghost at mouse
    if (mouse.x != null) {
      const key = buildMode;
      const r = WEAPONS[key].range;
      ctx.fillStyle = 'rgba(255,255,255,0.03)';
      ctx.strokeStyle = 'rgba(216,196,122,0.5)';
      ctx.setLineDash([6, 6]);
      ctx.beginPath(); ctx.arc(mouse.x, mouse.y, r, 0, 7); ctx.fill(); ctx.stroke();
      ctx.setLineDash([]);
    }
  }

  // enemies (draw below towers)
  for (const e of enemies) drawEnemy(e);

  // towers
  for (const t of towers) drawTower(t);

  // ghost placed preview
  if (buildMode && state === 'playing' && mouse.x != null) {
    const gx = Math.floor(mouse.x / TILE) * TILE + TILE / 2;
    const gy = Math.floor(mouse.y / TILE) * TILE + TILE / 2;
    const ok = canPlace(gx, gy);
    ctx.globalAlpha = 0.55;
    ctx.strokeStyle = ok ? 'rgba(159,203,110,0.9)' : 'rgba(224,106,79,0.9)';
    ctx.lineWidth = 2;
    ctx.strokeRect(gx - 18, gy - 18, 36, 36);
    ctx.globalAlpha = 1;
  }

  // tracers
  for (const b of bullets) {
    ctx.strokeStyle = 'rgba(255,230,170,0.9)';
    ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(b.x, b.y);
    ctx.lineTo(b.x - b.vx * 0.03, b.y - b.vy * 0.03); ctx.stroke();
    ctx.fillStyle = 'rgba(255,240,200,1)';
    ctx.beginPath(); ctx.arc(b.x, b.y, 2, 0, 7); ctx.fill();
  }
  // shells (trajectory spark)
  for (const s of shells) {
    ctx.fillStyle = 'rgba(60,60,60,0.9)';
    ctx.beginPath(); ctx.arc(s.x, s.y, 3.5, 0, 7); ctx.fill();
    ctx.fillStyle = 'rgba(255,180,110,0.5)';
    ctx.beginPath(); ctx.arc(s.x, s.y, 5, 0, 7); ctx.fill();
  }
  // missiles
  for (const m of missiles) {
    ctx.save();
    ctx.translate(m.x, m.y); ctx.rotate(m.angle);
    ctx.fillStyle = '#4a505a';
    ctx.fillRect(-8, -2.5, 16, 5);
    ctx.fillStyle = '#e8b24a';
    ctx.beginPath(); ctx.moveTo(-8, 0); ctx.lineTo(-13, -4); ctx.lineTo(-13, 4); ctx.closePath(); ctx.fill();
    ctx.restore();
  }

  // particles
  for (const p of particles) {
    const a = clamp(p.life / p.maxLife, 0, 1);
    if (p.type === 'smoke') {
      ctx.fillStyle = `rgba(70,70,66,${0.5 * a})`;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, 7); ctx.fill();
    } else if (p.type === 'spark') {
      ctx.fillStyle = p.color || '#ffd98a';
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size * a, 0, 7); ctx.fill();
    } else if (p.type === 'flame') {
      ctx.fillStyle = `rgba(255,${Math.floor(120 + 100*a)},50,${0.8*a})`;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size * a, 0, 7); ctx.fill();
    }
  }

  // flashes
  for (const f of flashes) {
    const a = f.life / f.max;
    const grad = ctx.createRadialGradient(f.x, f.y, 0, f.x, f.y, f.r);
    grad.addColorStop(0, `rgba(255,255,255,${a})`);
    grad.addColorStop(0.4, `rgba(${f.color || '255,240,192'},${0.7*a})`);
    grad.addColorStop(1, 'rgba(255,180,80,0)');
    ctx.fillStyle = grad;
    ctx.beginPath(); ctx.arc(f.x, f.y, f.r, 0, 7); ctx.fill();
  }

  // base integrity overlay when damaged
  if (integrity < 40) {
    ctx.fillStyle = 'rgba(224,60,40,0.12)';
    ctx.fillRect(0, 0, W, H);
  }

  // floats
  for (const f of floats) {
    const a = clamp(f.life / f.max, 0, 1);
    ctx.font = 'bold 13px "Segoe UI", sans-serif';
    ctx.textAlign = 'center';
    ctx.globalAlpha = a;
    ctx.fillStyle = f.color;
    ctx.fillText(f.txt, f.x, f.y);
    ctx.globalAlpha = 1;
  }

  // muzzle flash on selected / firing towers
  ctx.restore();
}

function drawEnemy(e) {
  const tk = 0.5 + 0.5 * Math.sin(e.hover);
  drawShadow(e.x, e.y, e.r);
  ctx.save();
  ctx.translate(e.x, e.y);
  ctx.rotate(e.angle);
  if (e.dead) return;

  if (e.type === 'infantry' || e.type === 'scout') {
    // soldier / jeep
    if (e.type === 'infantry') {
      // legs
      ctx.strokeStyle = '#4a523c'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(-2, 2); ctx.lineTo(-2, 7); ctx.moveTo(2, 2); ctx.lineTo(2, 7); ctx.stroke();
      // body
      ctx.fillStyle = '#5b6446';
      ctx.fillRect(-3, -3, 6, 6);
      // rifle
      ctx.strokeStyle = '#2c2c2c'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(3, 0); ctx.lineTo(11, 1); ctx.stroke();
      // helmet
      ctx.fillStyle = '#6b6f55';
      ctx.beginPath(); ctx.arc(0, -4, 4, 0, 7); ctx.fill();
      ctx.fillStyle = '#4d513d';
      ctx.beginPath(); ctx.arc(0, -5, 3, 0, 7); ctx.fill();
    } else {
      // scout jeep
      ctx.fillStyle = '#5a5f4a';
      ctx.fillRect(-10, -5, 20, 10);
      ctx.fillStyle = '#3d4133';
      ctx.fillRect(-10, -8, 9, 6);
      // wheels
      ctx.fillStyle = '#222';
      ctx.beginPath(); ctx.arc(-7, 7, 2.5, 0, 7); ctx.arc(7, 7, 2.5, 0, 7); ctx.fill();
    }
  } else if (e.type === 'drone') {
    // hovering quad
    const r = e.r + 2 * tk;
    ctx.fillStyle = '#3d4148';
    ctx.fillRect(-r, -1.5, r * 2, 3);
    ctx.fillRect(-1.5, -r, 3, r * 2);
    ctx.fillStyle = '#555c66';
    ctx.beginPath(); ctx.arc(-r, -r, 3, 0, 7); ctx.arc(r, -r, 3, 0, 7);
    ctx.arc(-r, r, 3, 0, 7); ctx.arc(r, r, 3, 0, 7); ctx.fill();
    // rotors
    ctx.strokeStyle = 'rgba(255,255,255,0.35)'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(-r, -r, 5, 0, 7); ctx.arc(r, -r, 5, 0, 7);
    ctx.arc(-r, r, 5, 0, 7); ctx.arc(r, r, 5, 0, 7); ctx.stroke();
  } else {
    // tank / heavy
    const isHeavy = e.type === 'heavy';
    // tracks
    ctx.fillStyle = '#2b2b2b';
    ctx.fillRect(-15, -8, 30, 16);
    ctx.fillStyle = '#333';
    for (let i = -2; i <= 2; i++) {
      ctx.beginPath(); ctx.arc(i * 6, -8, 2.5, 0, 7); ctx.arc(i * 6, 8, 2.5, 0, 7); ctx.fill();
    }
    // hull
    ctx.fillStyle = isHeavy ? '#4c5144' : '#5d6350';
    ctx.fillRect(-13, -5, 26, 10);
    // turret
    ctx.fillStyle = isHeavy ? '#585d50' : '#6a7158';
    ctx.beginPath(); ctx.arc(0, 0, isHeavy ? 8 : 6, 0, 7); ctx.fill();
    // barrel
    ctx.strokeStyle = isHeavy ? '#3c4036' : '#4b5040'; ctx.lineWidth = isHeavy ? 5 : 4;
    ctx.beginPath(); ctx.moveTo(2, 0); ctx.lineTo(isHeavy ? 20 : 16, 0); ctx.stroke();
  }
  ctx.restore();

  // health bar
  if (e.hp < e.maxHp) {
    const w = e.r * 2.2;
    const pct = clamp(e.hp / e.maxHp, 0, 1);
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.fillRect(e.x - w / 2, e.y - e.r - 12, w, 4);
    ctx.fillStyle = pct > 0.5 ? '#9fcb6e' : (pct > 0.25 ? '#e0c765' : '#e06a4f');
    ctx.fillRect(e.x - w / 2, e.y - e.r - 12, w * pct, 4);
  }
}

function drawTower(t) {
  drawShadow(t.x, t.y + 2, 16);
  ctx.save();
  ctx.translate(t.x, t.y);
  const w = WEAPONS[t.key];
  const sel = t.id === selectedId;
  const rec = t.recoil;

  if (sel) {
    ctx.strokeStyle = 'rgba(216,196,122,0.7)';
    ctx.lineWidth = 1.5;
    ctx.setLineDash([5, 5]);
    ctx.beginPath(); ctx.arc(0, 0, 21, 0, 7); ctx.stroke();
    ctx.setLineDash([]);
    // range ring
    const r = towerStats(t).range;
    ctx.fillStyle = 'rgba(255,255,255,0.03)';
    ctx.beginPath(); ctx.arc(0, 0, r, 0, 7); ctx.fill();
  }

  switch (t.key) {
    case 'mg': {
      // sandbag nest
      ctx.fillStyle = '#7a745e';
      ctx.beginPath(); ctx.arc(0, 0, 14, 0, 7); ctx.fill();
      ctx.fillStyle = '#8d866d';
      for (let i = 0; i < 8; i++) {
        const a = i / 8 * 6.28;
        ctx.beginPath(); ctx.arc(Math.cos(a) * 11, Math.sin(a) * 11, 5, 0, 7); ctx.fill();
      }
      ctx.fillStyle = '#4f5744';
      ctx.beginPath(); ctx.arc(0, 0, 9, 0, 7); ctx.fill();
      // crew
      ctx.fillStyle = '#6b6f55';
      ctx.beginPath(); ctx.arc(-2, 3, 3.5, 0, 7); ctx.fill();
      // gun
      ctx.save(); ctx.rotate(t.angle);
      ctx.strokeStyle = '#2f2f2a'; ctx.lineWidth = 3.5;
      ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(14 + rec * -3, 0); ctx.stroke();
      ctx.restore();
      break;
    }
    case 'flame': {
      ctx.fillStyle = '#5a604a';
      ctx.beginPath(); ctx.arc(0, 0, 12, 0, 7); ctx.fill();
      ctx.fillStyle = '#6d7455';
      ctx.fillRect(-10, -8, 20, 14);
      // tanks
      ctx.fillStyle = '#b04a3a';
      ctx.fillRect(-6, -4, 6, 8);
      ctx.fillStyle = '#c65a48';
      ctx.fillRect(-5, -3, 4, 6);
      // nozzle
      ctx.save(); ctx.rotate(t.angle);
      ctx.fillStyle = '#333';
      ctx.fillRect(6, -3, 12, 6);
      ctx.fillStyle = '#e8b24a';
      ctx.beginPath(); ctx.arc(18, 0, 2.5, 0, 7); ctx.fill();
      ctx.restore();
      break;
    }
    case 'missile': {
      ctx.fillStyle = '#4a5046';
      ctx.fillRect(-12, -12, 24, 24);
      ctx.fillStyle = '#5d6352';
      ctx.fillRect(-10, -10, 20, 20);
      // tubes
      ctx.fillStyle = '#2f332b';
      ctx.fillRect(-7, -7, 14, 5);
      ctx.fillRect(-7, 2, 14, 5);
      // angled
      ctx.save(); ctx.rotate(-0.4);
      ctx.fillStyle = '#2f332b';
      ctx.fillRect(2, -6, 6, 12);
      ctx.restore();
      break;
    }
    case 'cannon': {
      // base
      ctx.fillStyle = '#5a6050';
      ctx.beginPath(); ctx.arc(0, 0, 13, 0, 7); ctx.fill();
      ctx.fillStyle = '#6a7158';
      ctx.beginPath(); ctx.arc(0, 0, 10, 0, 7); ctx.fill();
      // mount
      ctx.save(); ctx.rotate(t.angle);
      ctx.fillStyle = '#4a4f40';
      ctx.fillRect(-4, -6, 8, 12);
      // barrel
      ctx.fillStyle = '#3c4136';
      ctx.fillRect(-4, -4, 26, 8);
      ctx.fillStyle = '#4b5044';
      ctx.fillRect(8, -3, 12, 6);
      ctx.fillStyle = '#2e322b';
      ctx.beginPath(); ctx.arc(22 - rec * 2, 0, 5, 0, 7); ctx.fill();
      ctx.restore();
      break;
    }
    case 'railgun': {
      // tripod
      ctx.fillStyle = '#4c5146';
      ctx.beginPath(); ctx.arc(0, 0, 12, 0, 7); ctx.fill();
      ctx.strokeStyle = '#3a3f34'; ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(-8, 6); ctx.lineTo(-2, -2);
      ctx.moveTo(8, 6); ctx.lineTo(2, -2);
      ctx.moveTo(0, 8); ctx.lineTo(0, -2);
      ctx.stroke();
      // long barrel
      ctx.save(); ctx.rotate(t.angle);
      ctx.fillStyle = '#33373a';
      ctx.fillRect(-3, -3.5, 34, 7);
      ctx.fillStyle = '#4a515b';
      ctx.fillRect(8, -2.5, 20, 5);
      ctx.fillStyle = '#1d2024';
      ctx.fillRect(32, -4, 4, 8);
      // coil rings
      ctx.strokeStyle = '#6a7a8a'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(10, -3.5); ctx.lineTo(10, 3.5);
      ctx.moveTo(16, -3.5); ctx.lineTo(16, 3.5);
      ctx.moveTo(22, -3.5); ctx.lineTo(22, 3.5);
      ctx.stroke();
      ctx.restore();
      break;
    }
  }
  ctx.restore();

  // level pips
  ctx.fillStyle = '#e0c765';
  for (let i = 0; i < t.lvl && i < 5; i++) {
    ctx.fillRect(t.x - 12 + i * 6, t.y + 18, 4, 4);
  }
}

// ---------- input ----------
let mouse = { x: null, y: null };
function canvasPos(ev) {
  const r = canvas.getBoundingClientRect();
  return {
    x: (ev.clientX - r.left) * (W / r.width),
    y: (ev.clientY - r.top) * (H / r.height),
  };
}
function canPlace(x, y) {
  const c = Math.floor(x / TILE), r = Math.floor(y / TILE);
  if (c < 0 || c >= COLS || r < 0 || r >= ROWS) return false;
  if (occupied[r][c]) return false;
  for (const t of towers) if (Math.abs(t.x - x) < TILE * 0.8 && Math.abs(t.y - y) < TILE * 0.8) return false;
  return true;
}

canvas.addEventListener('pointermove', (ev) => {
  const p = canvasPos(ev); mouse.x = p.x; mouse.y = p.y;
});
canvas.addEventListener('pointerleave', () => { mouse.x = null; mouse.y = null; });
canvas.addEventListener('pointerdown', (ev) => {
  ensureAudio();
  const p = canvasPos(ev);
  if (state !== 'playing') return;
  // check clicking existing tower
  for (const t of towers) {
    if (dist(p.x, p.y, t.x, t.y) < 24) {
      selectedId = t.id;
      showPanel(t);
      return;
    }
  }
  selectedId = null; hidePanel();
  if (buildMode) {
    const gx = Math.floor(p.x / TILE) * TILE + TILE / 2;
    const gy = Math.floor(p.y / TILE) * TILE + TILE / 2;
    const w = WEAPONS[buildMode];
    if (canPlace(gx, gy) && supplies >= w.cost) {
      supplies -= w.cost;
      towers.push(makeTower(buildMode, gx, gy));
      SFX.place();
      updateBar();
    } else {
      addFloat(p.x, p.y - 10, canPlace(gx, gy) ? 'INSUFFICIENT SUPPLIES' : 'BLOCKED', '#e06a4f');
    }
  }
});

// ---------- UI ----------
const $ = id => document.getElementById(id);
function updateBar() {
  const bar = $('towerBar');
  bar.innerHTML = '';
  for (const key of WKEYS) {
    const w = WEAPONS[key];
    const btn = document.createElement('button');
    btn.className = 'tower-btn' + (buildMode === key ? ' selected' : '') + (supplies < w.cost ? ' cant' : '');
    btn.innerHTML = `<span class="icon">${w.icon}</span><span class="name">${w.name}</span><span class="cost">◆${w.cost}</span>`;
    btn.onclick = (e) => {
      e.stopPropagation();
      ensureAudio();
      if (buildMode === key) { buildMode = null; }
      else { buildMode = key; }
      selectedId = null; hidePanel();
      updateBar();
    };
    bar.appendChild(btn);
  }
}
function updateHUD() {
  $('supply').textContent = supplies;
  $('integrity').textContent = Math.ceil(integrity);
  $('wave').textContent = wave;
}
function showPanel(t) {
  const w = WEAPONS[t.key];
  const s = towerStats(t);
  const up = upgradeCost(t);
  $('tpName').textContent = w.name;
  $('tpLvl').textContent = 'Lv ' + t.lvl;
  const canUp = t.lvl < MAXLVL && supplies >= up;
  $('tpStats').innerHTML =
    `<span>Damage</span> <b>${Math.round(s.dmg)}</b><br>` +
    `<span>Range</span> <b>${Math.round(s.range)}</b><br>` +
    `<span>Fire rate</span> <b>${(1 / s.rof).toFixed(1)}/s</b><br>` +
    (s.splash ? `<span>Splash</span> <b>${Math.round(s.splash)}</b><br>` : '') +
    `<span class="dim">${w.desc}</span>`;
  $('towerPanel').hidden = false;
  const btnUp = $('btnUpgrade');
  btnUp.textContent = t.lvl >= MAXLVL ? 'MAX' : '▲ Retrofit ◆' + up;
  btnUp.disabled = !canUp;
  $('btnSell').textContent = 'Scrap ◆' + sellValue(t);
}
function hidePanel() { $('towerPanel').hidden = true; }

// ---------- game flow ----------
function startGame() {
  towers.length = 0; enemies.length = 0; bullets.length = 0; shells.length = 0;
  missiles.length = 0; particles.length = 0; flashes.length = 0; floats.length = 0;
  supplies = 160; integrity = 100; wave = 0; buildMode = null; selectedId = null;
  shake = 0; speed = 1;
  $('speed').textContent = '1×';
  $('startOverlay').hidden = true;
  $('endOverlay').hidden = true;
  hidePanel();
  state = 'playing';
  startWave();
  updateBar(); updateHUD();
}
function endGame(won) {
  state = won ? 'won' : 'over';
  $('endTitle').textContent = won ? 'Mission Complete' : 'Base Overrun';
  $('endSub').textContent = won ? 'All 25 hostile waves eliminated. Sector secured.' : 'The forward base has fallen. Sector lost.';
  $('endOverlay').hidden = false;
}

$('btnPlay').onclick = () => { ensureAudio(); startGame(); };
$('btnRestart').onclick = () => { ensureAudio(); startGame(); };
$('btnStart').onclick = () => {
  if (state === 'menu' || state === 'over' || state === 'won') { ensureAudio(); startGame(); }
  else if (state === 'paused') { state = 'playing'; $('btnStart').textContent = '▶ Deploy'; }
};
$('btnPause').onclick = () => {
  if (state === 'playing') { state = 'paused'; $('btnPause').textContent = '▶'; $('btnStart').textContent = '▶ Deploy'; }
  else if (state === 'paused') { state = 'playing'; $('btnPause').textContent = '⏸'; $('btnStart').textContent = '⏸'; }
};
$('btnSpeed').onclick = () => {
  speed = speed === 1 ? 2 : (speed === 2 ? 3 : 1);
  $('btnSpeed').textContent = speed + '×';
};
$('btnMute').onclick = () => {
  SFX.enabled = !SFX.enabled;
  $('btnMute').textContent = SFX.enabled ? '🔊' : '🔇';
};
$('btnUpgrade').onclick = () => {
  ensureAudio();
  if (selectedId == null) return;
  const t = towers.find(t => t.id === selectedId);
  if (!t || t.lvl >= MAXLVL) return;
  const up = upgradeCost(t);
  if (supplies < up) return;
  supplies -= up; t.lvl++; SFX.upgrade();
  showPanel(t); updateBar(); updateHUD();
};
$('btnSell').onclick = () => {
  ensureAudio();
  if (selectedId == null) return;
  const i = towers.findIndex(t => t.id === selectedId);
  if (i < 0) return;
  supplies += sellValue(towers[i]);
  towers.splice(i, 1);
  selectedId = null; hidePanel();
  SFX.sell(); updateBar(); updateHUD();
};

// ---------- main loop ----------
let last = performance.now();
function loop(now) {
  let dt = (now - last) / 1000;
  last = now;
  dt = Math.min(dt, 0.05);
  if (state === 'playing') update(dt * speed);
  else if (state === 'paused') { /* frozen */ }
  render();
  updateHUD();
  requestAnimationFrame(loop);
}

updateBar();
updateHUD();
requestAnimationFrame(loop);
