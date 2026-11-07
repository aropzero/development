/* =====================================================================
   SIEGE: FALLEN GATE — 3D tactical defense (top-down / orbit camera)
   3D models: CC0 packs downloaded from Kenney.nl (see assets/3d/).
   three.js is vendored locally (js/vendor/) — no CDN needed at runtime.
   ===================================================================== */
import * as THREE from 'three';
import { GLTFLoader } from './vendor/GLTFLoader.js';

const $ = id => document.getElementById(id);
const clamp = (v, a, b) => v < a ? a : (v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;

// ---------- world ----------
const ROAD_W = 7;
const PATH = [
  [-6, -34], [-5, -20], [-1, -10], [3, -2], [4, 8], [2, 20], [0, 30],
];
const GATE = { x: 0, z: 30.5 };

function segDist(px, pz, x1, z1, x2, z2) {
  const dx = x2 - x1, dz = z2 - z1;
  const l2 = dx * dx + dz * dz;
  if (l2 === 0) return Math.hypot(px - x1, pz - z1);
  let t = ((px - x1) * dx + (pz - z1) * dz) / l2;
  t = clamp(t, 0, 1);
  return Math.hypot(px - (x1 + t * dx), pz - (z1 + t * dz));
}
function distToPath(x, z) {
  let m = Infinity;
  for (let i = 0; i < PATH.length - 1; i++) m = Math.min(m, segDist(x, z, PATH[i][0], PATH[i][1], PATH[i + 1][0], PATH[i + 1][1]));
  return m;
}

// ---------- asset paths (space encoded as %20) ----------
const GLB = p => 'assets/3d/' + p.replace(/ /g, '%20');
const CHAR_MODELS = 'abcdefgh'.split('').map(c => `blocky-characters/Models/GLB format/character-${c}.glb`);
const WEAPONS = {
  ballista: { name: 'Ballista', cost: 120, model: GLB('castle-kit/Models/GLB format/siege-ballista.glb'), h: 3.2, kind: 'bolt', range: 26, rof: 0.55, dmg: 16, splash: 0, rate: 30 },
  catapult: { name: 'Catapult', cost: 190, model: GLB('castle-kit/Models/GLB format/siege-catapult.glb'), h: 4.0, kind: 'shell', range: 23, rof: 2.3, dmg: 46, splash: 6.5, rate: 7 },
  trebuchet: { name: 'Trebuchet', cost: 280, model: GLB('castle-kit/Models/GLB format/siege-trebuchet.glb'), h: 5.2, kind: 'shell', range: 38, rof: 4.6, dmg: 95, splash: 9.5, rate: 7 },
};
const WKEYS = Object.keys(WEAPONS);

const ENEMIES = {
  foot: { hp: 60, speed: 4.1, s: 1.0, reward: 10, dmg: 2, tint: 0x7a8a4f, armor: 1 },
  runner: { hp: 34, speed: 7.2, s: 0.92, reward: 12, dmg: 1.5, tint: 0xc8a03a, armor: 1 },
  brute: { hp: 210, speed: 2.7, s: 1.45, reward: 26, dmg: 4, tint: 0x8e4433, armor: 0.6 },
  siege: { hp: 430, speed: 1.7, s: 1.8, reward: 52, dmg: 6, tint: 0x4a4f5e, armor: 0.35 },
};
const EKEYS = Object.keys(ENEMIES);

// ---------- audio (synthesized) ----------
const AudioSys = {
  ctx: null, master: null, on: true,
  ensure() {
    if (this.ctx) return;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    this.ctx = new AC();
    this.master = this.ctx.createGain();
    this.master.gain.value = 0.5;
    this.master.connect(this.ctx.destination);
  },
  tone(f, d, type, g, slide) {
    if (!this.on || !this.ctx) return;
    const o = this.ctx.createOscillator(), v = this.ctx.createGain();
    const t0 = this.ctx.currentTime;
    o.type = type; o.frequency.setValueAtTime(f, t0);
    if (slide) o.frequency.exponentialRampToValueAtTime(slide, t0 + d);
    v.gain.setValueAtTime(g, t0);
    v.gain.exponentialRampToValueAtTime(0.001, t0 + d);
    o.connect(v).connect(this.master);
    o.start(t0); o.stop(t0 + d + 0.03);
  },
  noise(d, f, q, g) {
    if (!this.on || !this.ctx) return;
    const len = Math.floor(this.ctx.sampleRate * d);
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    const src = this.ctx.createBufferSource(); src.buffer = buf;
    const flt = this.ctx.createBiquadFilter(); flt.type = 'lowpass'; flt.frequency.value = f; flt.Q.value = q;
    const v = this.ctx.createGain(); const t0 = this.ctx.currentTime;
    v.gain.setValueAtTime(g, t0); v.gain.exponentialRampToValueAtTime(0.001, t0 + d);
    src.connect(flt).connect(v).connect(this.master);
    src.start(t0); src.stop(t0 + d + 0.03);
  },
  boom() { this.noise(0.55, 420, 0.6, 0.85); this.tone(72, 0.5, 'sine', 0.7, 34); },
  shoot(kind) {
    if (kind === 'bolt') this.noise(0.12, 1400, 1.2, 0.4);
    else this.noise(0.22, 700, 0.8, 0.7);
  },
  place() { this.tone(300, 0.08, 'triangle', 0.18, 520); },
  sell() { this.noise(0.15, 800, 0.8, 0.4); },
  upgrade() { this.tone(400, 0.1, 'triangle', 0.16, 720); },
  horn() { this.tone(140, 0.9, 'sawtooth', 0.16, 110); this.tone(180, 0.9, 'triangle', 0.12, 130); },
  alarm() { this.tone(320, 0.35, 'square', 0.1, 240); },
};

// ---------- state ----------
const G = {
  state: 'menu', supplies: 200, integrity: 100, wave: 0, speed: 1, start: true,
  waveQueue: [], spawnTimer: 0, selected: null, buildMode: null,
  dragging: false, dragMoved: false, pointerDown: null,
  camA: 0.9, camE: 0.55, camDist: 62, target: new THREE.Vector3(0, 0, 2),
  ghost: null, loading: true,
};
const towers = []; const enemies = []; const projectiles = []; const parts = [];
const towerGroups = [];       // meshes for raycast selection

// ---------- renderer / scene ----------
const canvas = $('game3d');
const createRenderer = (window.__CREATE_RENDERER__) ? window.__CREATE_RENDERER__ : (c) => new THREE.WebGLRenderer({ canvas: c, antialias: true });
const renderer = createRenderer(canvas);
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x10141c);
scene.fog = new THREE.Fog(0x10141c, 90, 170);

const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 400);

const hemi = new THREE.HemisphereLight(0xdfe9ff, 0x3c3a2e, 0.9);
scene.add(hemi);
const sun = new THREE.DirectionalLight(0xffe6ba, 1.4);
sun.position.set(30, 45, 15);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -60; sun.shadow.camera.right = 60;
sun.shadow.camera.top = 60; sun.shadow.camera.bottom = -60;
sun.shadow.camera.far = 120;
scene.add(sun);

// ---------- ground / road ----------
const ground = new THREE.Mesh(
  new THREE.PlaneGeometry(140, 100),
  new THREE.MeshStandardMaterial({ color: 0x4a5640, roughness: 1 })
);
ground.rotation.x = -Math.PI / 2;
ground.receiveShadow = true;
scene.add(ground);

const roadGeo = new THREE.PlaneGeometry(ROAD_W, 68, 24, 1);
const roadPos = roadGeo.attributes.position;
// shape road along z with x from PATH (simple interpolated lane)
for (let i = 0; i <= 24; i++) {
  const t = i / 24;
  const z = -34 + t * 68;
  // find x along path via piecewise linear over z
  let x = -6;
  for (let k = 0; k < PATH.length - 1; k++) {
    const z1 = PATH[k][1], z2 = PATH[k + 1][1];
    if (z >= Math.min(z1, z2) && z <= Math.max(z1, z2)) {
      const tt = (z - z1) / ((z2 - z1) || 1);
      x = lerp(PATH[k][0], PATH[k + 1][0], clamp(tt, 0, 1));
      break;
    }
  }
  roadPos.setX(i * 2, x);
  roadPos.setX(i * 2 + 1, x);
}
roadGeo.computeVertexNormals();
const road = new THREE.Mesh(roadGeo, new THREE.MeshStandardMaterial({ color: 0x6b5c40, roughness: 0.95 }));
road.rotation.x = -Math.PI / 2;
road.position.y = 0.02;
road.receiveShadow = true;
scene.add(road);

// ---------- low-level helpers ----------
function fitToHeight(mesh, h) {
  mesh.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
  mesh.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(mesh);
  const size = new THREE.Vector3(); box.getSize(size);
  const s = h / (size.y || 1);
  mesh.scale.setScalar(s);
  mesh.updateMatrixWorld(true);
  const box2 = new THREE.Box3().setFromObject(mesh);
  mesh.position.y -= box2.min.y;
  return mesh;
}
function loadGLB(url) {
  const abs = new URL(url, document.baseURI || location.href).href;
  return new Promise((res, rej) => {
    new GLTFLoader().load(abs, g => res(g.scene), undefined, rej);
  });
}

// ---------- built-in 3D primitives (shared) ----------
const boltGeo = new THREE.SphereGeometry(0.5, 8, 8);
const boltMat = new THREE.MeshStandardMaterial({ color: 0x3a3f2e, roughness: 0.7 });
const stoneGeo = new THREE.SphereGeometry(0.9, 10, 10);
const stoneMat = new THREE.MeshStandardMaterial({ color: 0x4e4a42, roughness: 1 });
const partGeo = new THREE.SphereGeometry(0.35, 6, 6);
const flashGeo = new THREE.SphereGeometry(1, 8, 8);
const flashMat = new THREE.MeshBasicMaterial({ color: 0xffd27a, transparent: true, opacity: 0.9, depthWrite: false });

function makeHPSprite() {
  const cv = document.createElement('canvas');
  cv.width = 96; cv.height = 14;
  const tex = new THREE.CanvasTexture(cv);
  const spr = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false }));
  spr.scale.set(3.4, 0.5, 1);
  spr.position.y = 2.8;
  return { spr, cv, tex, w: 96, h: 14, hp: 1 };
}
function paintHP(hp, maxHp) {
  const c = hp.cv.getContext('2d');
  const ratio = clamp(hp.hp / maxHp, 0, 1);
  c.clearRect(0, 0, hp.w, hp.h);
  c.fillStyle = 'rgba(10,12,14,0.85)';
  c.fillRect(0, 0, hp.w, hp.h);
  c.fillStyle = ratio > 0.5 ? '#6fae4f' : (ratio > 0.25 ? '#d8a33a' : '#c0432f');
  c.fillRect(1, 2, Math.round((hp.w - 2) * ratio), hp.h - 4);
  c.strokeStyle = 'rgba(220,220,200,0.5)';
  c.strokeRect(0.5, 0.5, hp.w - 1, hp.h - 1);
  hp.tex.needsUpdate = true;
}

// ---------- terrain decoration (loaded asynchronously) ----------
async function buildDecor(assets) {
  const place = (mesh, x, z, ry = 0, sc = 1) => {
    mesh.position.set(x, 0, z);
    mesh.rotation.y = ry;
    mesh.scale.multiplyScalar(sc);
    scene.add(mesh);
  };
  // wall lines flanking the approach
  for (const side of [-1, 1]) {
    const wall = assets.wall.clone(true);
    fitToHeight(wall, 4);
    place(wall, side * 7, 26, side > 0 ? Math.PI / 2 : -Math.PI / 2);
    const wall2 = assets.wall.clone(true);
    fitToHeight(wall2, 4);
    place(wall2, side * 7, 20, side > 0 ? Math.PI / 2 : -Math.PI / 2);
  }
  // towers behind gate
  for (const side of [-1, 1]) {
    const tw = assets.tower.clone(true);
    fitToHeight(tw, 7);
    place(tw, side * 8, 34, side * 0.4);
  }
  // scatter rocks / trees away from road
  let placed = 0;
  for (let i = 0; i < 26 && placed < 26; i++) {
    const x = (Math.random() * 2 - 1) * 55;
    const z = (Math.random() * 2 - 1) * 40;
    if (distToPath(x, z) < 12) continue;
    const type = Math.random() < 0.55 ? 'tree' : 'rock';
    const m = (type === 'tree' ? assets.tree : assets.rock).clone(true);
    fitToHeight(m, type === 'tree' ? 5 : 2);
    place(m, x, z, Math.random() * 6.28, 0.8 + Math.random() * 0.8);
    placed++;
  }
}
function buildGate(assets) {
  const gate = assets.gate.clone(true);
  fitToHeight(gate, 7);
  gate.position.set(GATE.x, 0, GATE.z);
  gate.rotation.y = Math.PI; // face toward -Z (enemies)
  scene.add(gate);
  return gate;
}

// ---------- flag ----------
const _enemies = [];
const baseChar = {};   // name -> normalized factory mesh
let charPatches = [];
let gateMesh = null;

let WAVE_PLAN = [];
(function buildWaves() {
  for (let w = 1; w <= 20; w++) {
    const plan = [];
    plan.push(['foot', Math.floor(5 + w * 1.4)]);
    if (w >= 3) plan.push(['runner', Math.floor(2 + w * 0.4)]);
    if (w >= 6) plan.push(['brute', Math.floor(1 + (w - 5) * 0.45)]);
    if (w >= 11) plan.push(['siege', w >= 16 ? 2 : 1]);
    WAVE_PLAN.push(plan);
  }
})();

function makeEnemy(type, variant) {
  const def = ENEMIES[type];
  const mesh = baseChar[CHAR_MODELS[variant % CHAR_MODELS.length]].clone(true);
  fitToHeight(mesh, 2.4 * def.s);
  mesh.traverse(o => { if (o.isMesh && o.material) { o.material = o.material.clone(); o.material.color.set(def.tint); } });
  const hp = makeHPSprite();
  mesh.add(hp.spr);
  const e = { type, def, hp: def.hp, maxHp: def.hp, wp: 0, x: PATH[0][0], z: PATH[0][1],
    speed: def.speed, alive: true, mesh, hpSpr: hp, atGate: false };
  mesh.position.set(e.x, 0, e.z);
  scene.add(mesh);
  paintHP(hp, e.maxHp);
  return e;
}

// ---------- towers ----------
let nextId = 1;
function makeTower(key, x, z) {
  const w = WEAPONS[key];
  const group = new THREE.Group();
  const mesh = w._mesh.clone(true);
  fitToHeight(mesh, w.h);
  group.add(mesh);
  group.position.set(x, 0, z);
  scene.add(group);
  const t = { id: nextId++, key, x, z, lvl: 1, cd: 0, angle: 0, group, mesh,
    cost: w.cost };
  towerGroups.push(group);
  return t;
}
function towerStats(t) {
  const w = WEAPONS[t.key];
  const f = 1 + (t.lvl - 1) * 0.35;
  return { range: w.range * (1 + (t.lvl - 1) * 0.06), rof: w.rof / f, dmg: w.dmg * f, splash: w.splash };
}
function upgradeCost(t) { return Math.round(WEAPONS[t.key].cost * 0.8 * t.lvl); }
function sellValue(t) { let v = WEAPONS[t.key].cost; for (let l = 2; l <= t.lvl; l++) v += upgradeCost({ key: t.key, lvl: l - 1 }); return Math.round(v * 0.7); }

function findTarget(t) {
  const s = towerStats(t);
  let best = null, bd = s.range;
  for (const e of enemies) {
    if (!e.alive) continue;
    const d = Math.hypot(e.x - t.x, e.z - t.z);
    if (d < bd) { bd = d; best = e; }
  }
  return best;
}
function fireTower(t, target) {
  const s = towerStats(t);
  const w = WEAPONS[t.key];
  t.cd = s.rof;
  t.angle = Math.atan2(-(target.x - t.x), -(target.z - t.z));
  t.group.rotation.y = t.angle;
  AudioSys.shoot(w.kind);
  const ox = t.x, oz = t.z;
  if (w.kind === 'bolt') {
    const tx = target.x, tz = target.z;
    const d = Math.hypot(tx - ox, tz - oz) || 1;
    const vx = (tx - ox) / d * w.rate, vz = (tz - oz) / d * w.rate;
    const m = new THREE.Mesh(boltGeo, boltMat);
    m.position.set(ox, 2, oz);
    scene.add(m);
    projectiles.push({ kind: 'bolt', mesh: m, x: ox, y: 2, z: oz, vx, vz, dmg: s.dmg, d: 0, from: t.id });
  } else {
    const tx = target.x, tz = target.z;
    const d = Math.hypot(tx - ox, tz - oz) || 1;
    const flightT = clamp(d / w.rate, 0.7, 2.6);
    const vx = (tx - ox) / flightT, vz = (tz - oz) / flightT;
    const vy = 20 * flightT * 0.5;
    const m = new THREE.Mesh(stoneGeo, stoneMat);
    m.position.set(ox, 2.5, oz);
    scene.add(m);
    projectiles.push({ kind: 'shell', mesh: m, x: ox, y: 2.5, z: oz, vx, vy, vz, dmg: s.dmg, splash: s.splash, t: 0, flightT, from: t.id });
  }
}

// ---------- effects ----------
function explode(x, z, radius, dmg, fromTower) {
  AudioSys.boom();
  for (let i = 0; i < 14; i++) {
    const p = new THREE.Mesh(partGeo, new THREE.MeshStandardMaterial({ color: 0x4a3a2a }));
    const a = Math.random() * Math.PI * 2;
    const r = radius * (0.2 + Math.random() * 0.8);
    p.position.set(x + Math.cos(a) * r, 0.3 + Math.random() * 1.2, z + Math.sin(a) * r);
    scene.add(p);
    parts.push({ mesh: p, life: 0.9 + Math.random() * 0.6, max: 1.5, vy: 3 + Math.random() * 4 });
  }
  const fl = new THREE.Mesh(flashGeo, flashMat);
  fl.position.set(x, 1.5, z);
  fl.scale.setScalar(radius * 0.5);
  scene.add(fl);
  parts.push({ mesh: fl, life: 0.25, max: 0.25, flash: true });
  for (const e of enemies) {
    if (!e.alive) continue;
    const d = Math.hypot(e.x - x, e.z - z);
    if (d < radius + 1) damageEnemy(e, dmg, fromTower);
  }
}
function damageEnemy(e, amt, fromTower) {
  if (!e.alive) return;
  const mult = e.def.armor;
  e.hp -= amt * mult;
  if (e.hp <= 0) {
    e.alive = false;
    scene.remove(e.mesh);
    G.supplies += e.def.reward;
    updateHUD();
    e.mesh.traverse(o => { if (o.isMesh) o.material && o.material.dispose && o.material.dispose(); });
  } else {
    paintHP(e.hpSpr, e.maxHp);
  }
}

// ---------- waves ----------
function startWave() {
  G.wave++;
  $('wave3d').textContent = G.wave;
  const plan = WAVE_PLAN[G.wave - 1] || [];
  G.waveQueue = [];
  for (const [type, count] of plan) {
    for (let i = 0; i < count; i++) G.waveQueue.push({ type, delay: i * (0.3 + Math.random() * 0.35), v: Math.floor(Math.random() * 18) });
  }
  G.spawnTimer = 0;
}

function spawnFromQueue(dt) {
  if (!G.waveQueue.length) return;
  G.spawnTimer -= dt;
  if (G.spawnTimer <= 0) {
    const first = G.waveQueue.shift();
    enemies.push(makeEnemy(first.type, first.v));
    G.spawnTimer = 0.5; // fixed gap between spawns keeps waves readable
  }
}

// ---------- camera / raycast ----------
const ndc = { x: 0, y: 0 };
function updateCamera() {
  const radA = G.camA, radE = clamp(G.camE, 0.2, 1.4);
  const cx = G.target.x + G.camDist * Math.sin(radA) * Math.cos(radE);
  const cy = G.target.y + G.camDist * Math.sin(radE);
  const cz = G.target.z + G.camDist * Math.cos(radA) * Math.cos(radE);
  camera.position.set(cx, cy, cz);
  camera.lookAt(G.target);
}
const ray = new THREE.Raycaster();
function raycastGround() {
  ray.setFromCamera(new THREE.Vector2(ndc.x, ndc.y), camera);
  const hits = ray.intersectObject(ground, false);
  return hits.length ? hits[0].point : null;
}

// ---------- placement ----------
function canPlace(x, z) {
  if (Math.abs(x) > 52 || Math.abs(z) > 44) return false;
  if (distToPath(x, z) < ROAD_W / 2 + 3.2) return false;
  if (Math.hypot(x - GATE.x, z - GATE.z) < 10) return false;
  for (const t of towers) if (Math.hypot(t.x - x, t.z - z) < 5) return false;
  return true;
}

// ---------- HUD ----------
function updateHUD() {
  $('supply3d').textContent = Math.floor(G.supplies);
  $('integrity3d').textContent = Math.max(0, Math.ceil(G.integrity));
  $('wave3d').textContent = G.wave;
}
function toast(msg) {
  const t = $('toast');
  t.textContent = msg; t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 1400);
}
function renderWeaponBar() {
  const bar = $('towerBar3d');
  bar.innerHTML = '';
  for (const key of WKEYS) {
    const w = WEAPONS[key];
    const b = document.createElement('button');
    b.className = 'tower-btn' + (G.buildMode === key ? ' selected' : '') + (G.supplies < w.cost ? ' cant' : '');
    b.innerHTML = `<span class="icon">⚒</span><span class="name">${w.name}</span><span class="cost">◆${w.cost}</span>`;
    b.onclick = (e) => {
      e.stopPropagation();
      AudioSys.ensure();
      if (G.buildMode === key) G.buildMode = null;
      else G.buildMode = key;
      G.selected = null; hidePanel();
      syncGhost();
      renderWeaponBar();
    };
    bar.appendChild(b);
  }
}
function showPanel(t) {
  const w = WEAPONS[t.key];
  const s = towerStats(t);
  const up = upgradeCost(t);
  $('pnName3d').textContent = w.name + ' · Lv ' + t.lvl;
  $('pnStats3d').innerHTML =
    `<div class="row"><span>Damage</span><b>${Math.round(s.dmg)}</b></div>` +
    `<div class="row"><span>Range</span><b>${Math.round(s.range)}</b></div>` +
    `<div class="row"><span>Fire rate</span><b>${(1 / s.rof).toFixed(1)}/s</b></div>` +
    (s.splash ? `<div class="row"><span>Splash</span><b>${s.splash}</b></div>` : '') +
    `<div class="row"><span>Scrap</span><b>◆${sellValue(t)}</b></div>`;
  $('panel3d').classList.remove('hidden');
  $('btnUp3d').textContent = t.lvl >= 5 ? 'MAX' : '▲ Retrofit ◆' + up;
  $('btnUp3d').disabled = !(t.lvl < 5 && G.supplies >= up);
}
function hidePanel() { $('panel3d').classList.add('hidden'); }
function syncGhost() {
  if (G.ghost) { scene.remove(G.ghost); G.ghost = null; }
  if (G.buildMode) {
    const w = WEAPONS[G.buildMode];
    if (w._mesh) {
      G.ghost = w._mesh.clone(true);
      G.ghost.traverse(o => { if (o.isMesh) { o.material = o.material.clone(); o.material.transparent = true; o.material.opacity = 0.5; } });
      fitToHeight(G.ghost, w.h);
      scene.add(G.ghost);
    }
  }
}

// ---------- game flow ----------
function startGame() {
  for (const t of towers.slice()) {
    towerGroups.splice(towerGroups.indexOf(t.group), 1);
    scene.remove(t.group);
  }
  towers.length = 0;
  for (const e of enemies.slice()) scene.remove(e.mesh);
  enemies.length = 0;
  for (const p of projectiles) scene.remove(p.mesh);
  projectiles.length = 0;
  for (const p of parts) scene.remove(p.mesh);
  parts.length = 0;
  G.supplies = 200; G.integrity = 100; G.wave = 0; G.buildMode = null; G.selected = null;
  G.speed = 1; $('btnSpeed3d').textContent = '1×';
  $('btnPause3d').textContent = '⏸';
  $('startOverlay3d').classList.add('hidden');
  $('endOverlay3d').classList.add('hidden');
  hidePanel(); syncGhost();
  G.state = 'playing';
  startWave();
  renderWeaponBar(); updateHUD();
  AudioSys.horn();
}
function endGame(won) {
  G.state = won ? 'won' : 'over';
  $('endTitle3d').textContent = won ? 'Victory' : 'The Gate Falls';
  $('endSub3d').textContent = won ? 'All 20 waves repelled. The keep stands.' : 'The gate has been breached. The keep is lost.';
  $('endOverlay3d').classList.remove('hidden');
}

// ---------- update ----------
function update(dt) {
  // spawn
  spawnFromQueue(dt);
  // enemies move
  for (const e of enemies) {
    if (!e.alive) continue;
    const wp = PATH[e.wp];
    const d = Math.hypot(wp[0] - e.x, wp[1] - e.z);
    if (d < 0.4) {
      if (e.wp < PATH.length - 1) { e.wp++; }
      else {
        // reached gate
        e.alive = false;
        scene.remove(e.mesh);
        G.integrity -= e.def.dmg;
        AudioSys.alarm();
        updateHUD();
        if (G.integrity <= 0) { G.integrity = 0; endGame(false); return; }
        continue;
      }
    }
    const nx = PATH[e.wp][0], nz = PATH[e.wp][1];
    const dx = nx - e.x, dz = nz - e.z;
    const len = Math.hypot(dx, dz) || 1;
    const step = e.speed * dt;
    e.x += dx / len * step; e.z += dz / len * step;
    e.mesh.position.set(e.x, 0, e.z);
    e.mesh.rotation.y = Math.atan2(-dx, -dz);
  }
  // towers fire
  for (const t of towers) {
    t.cd -= dt;
    if (t.cd <= 0) {
      const target = findTarget(t);
      if (target) fireTower(t, target);
    }
  }
  // projectiles
  for (let i = projectiles.length - 1; i >= 0; i--) {
    const p = projectiles[i];
    if (p.kind === 'bolt') {
      p.x += p.vx * dt; p.z += p.vz * dt; p.d += Math.hypot(p.vx, p.vz) * dt;
      p.mesh.position.set(p.x, 2, p.z);
      if (p.d > 40) { scene.remove(p.mesh); projectiles.splice(i, 1); continue; }
      let hit = false;
      for (const e of enemies) {
        if (!e.alive) continue;
        if (Math.hypot(e.x - p.x, e.z - p.z) < 1.6) {
          damageEnemy(e, p.dmg, p.from); hit = true; break;
        }
      }
      if (hit) { scene.remove(p.mesh); projectiles.splice(i, 1); }
    } else {
      p.t += dt;
      p.x += p.vx * dt; p.z += p.vz * dt; p.y += p.vy * dt; p.vy -= 14 * dt;
      if (p.y <= 0) {
        p.y = 0;
        explode(p.x, p.z, p.splash, p.dmg, p.from);
        scene.remove(p.mesh);
        projectiles.splice(i, 1);
      } else {
        p.mesh.position.set(p.x, p.y, p.z);
      }
    }
  }
  // particles
  for (let i = parts.length - 1; i >= 0; i--) {
    const p = parts[i];
    p.life -= dt;
    if (p.life <= 0) { scene.remove(p.mesh); parts.splice(i, 1); continue; }
    if (!p.flash) {
      p.vy -= 8 * dt;
      p.mesh.position.y += p.vy * dt;
      p.mesh.scale.multiplyScalar(1 + dt * 0.4);
      p.mesh.material.opacity = clamp(p.life / p.max, 0, 1);
      p.mesh.material.transparent = true;
    } else {
      p.mesh.material.opacity = clamp(p.life / p.max, 0, 1);
      p.mesh.scale.multiplyScalar(1 + dt * 6);
    }
  }
  // if wave cleared and queue empty and no enemies -> next wave
  if (G.waveQueue.length === 0 && !enemies.some(e => e.alive)) {
    if (G.wave >= 20) { endGame(true); return; }
    startWave();
    AudioSys.horn();
  }
  // ghost placement
  if (G.ghost && G.buildMode) {
    const pt = raycastGround();
    if (pt) {
      const gx = Math.round(pt.x / 3) * 3, gz = Math.round(pt.z / 3) * 3;
      G.ghost.position.set(gx, 0, gz);
      G.ghost.rotation.y = 0.3;
    }
  }
}

// ---------- pointer / input ----------
function onCanvasPointerDown(e) {
  AudioSys.ensure();
  const r = canvas.getBoundingClientRect();
  ndc.x = ((e.clientX - r.left) / r.width) * 2 - 1;
  ndc.y = -((e.clientY - r.top) / r.height) * 2 + 1;
  G.dragging = true; G.dragMoved = false;
  G.pointerDown = { x: e.clientX, y: e.clientY };
}
function onCanvasPointerMove(e) {
  const r = canvas.getBoundingClientRect();
  ndc.x = ((e.clientX - r.left) / r.width) * 2 - 1;
  ndc.y = -((e.clientY - r.top) / r.height) * 2 + 1;
  if (G.dragging) {
    const dx = e.clientX - G.pointerDown.x, dy = e.clientY - G.pointerDown.y;
    if (Math.abs(dx) + Math.abs(dy) > 5) G.dragMoved = true;
    G.camA += dx * 0.005;
    G.camE += dy * 0.005;
    G.pointerDown = { x: e.clientX, y: e.clientY };
    updateCamera();
  }
}
function onCanvasPointerUp(e) {
  const wasDrag = G.dragMoved;
  G.dragging = false;
  if (wasDrag || G.state !== 'playing') return;
  // click -> placement / selection
  const pt = raycastGround();
  if (!pt) return;
  // check if clicking a tower
  ray.setFromCamera(new THREE.Vector2(ndc.x, ndc.y), camera);
  const hits = ray.intersectObjects(towerGroups, true);
  if (hits.length) {
    const g = hits[0].object;
    let owner = null;
    for (const t of towers) {
      if (t.group === g || t.group.getObjectById(g.id)) { owner = t; break; }
    }
    if (owner) { G.selected = owner; showPanel(owner); return; }
  }
  G.selected = null; hidePanel();
  if (G.buildMode) {
    const w = WEAPONS[G.buildMode];
    const gx = Math.round(pt.x / 3) * 3, gz = Math.round(pt.z / 3) * 3;
    if (canPlace(gx, gz) && G.supplies >= w.cost) {
      G.supplies -= w.cost;
      towers.push(makeTower(G.buildMode, gx, gz));
      AudioSys.place();
      renderWeaponBar(); updateHUD();
    } else {
      toast(canPlace(gx, gz) ? 'INSUFFICIENT SUPPLIES' : 'BLOCKED — place on open ground');
    }
  }
}
function onWheel(e) {
  e.preventDefault();
  G.camDist = clamp(G.camDist + e.deltaY * 0.04, 20, 130);
  updateCamera();
}

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

// ---------- UI binding ----------
$('btnPlay3d').onclick = () => { AudioSys.ensure(); startGame(); };
$('btnRestart3d').onclick = () => { AudioSys.ensure(); startGame(); };
$('btnStart3d').onclick = () => {
  AudioSys.ensure();
  if (G.state === 'menu' || G.state === 'over' || G.state === 'won') startGame();
  else if (G.state === 'paused') { G.state = 'playing'; $('btnStart3d').textContent = '▶ Deploy'; }
};
$('btnPause3d').onclick = () => {
  if (G.state === 'playing') { G.state = 'paused'; $('btnPause3d').textContent = '▶'; $('btnStart3d').textContent = '▶ Deploy'; }
  else if (G.state === 'paused') { G.state = 'playing'; $('btnPause3d').textContent = '⏸'; $('btnStart3d').textContent = '⏸'; }
};
$('btnSpeed3d').onclick = () => {
  G.speed = G.speed === 1 ? 2 : (G.speed === 2 ? 3 : 1);
  $('btnSpeed3d').textContent = G.speed + '×';
};
$('btnMute3d').onclick = () => { AudioSys.on = !AudioSys.on; $('btnMute3d').textContent = AudioSys.on ? '🔊' : '🔇'; };
$('btnUp3d').onclick = () => {
  if (!G.selected) return;
  const t = G.selected;
  const up = upgradeCost(t);
  if (t.lvl < 5 && G.supplies >= up) { G.supplies -= up; t.lvl++; AudioSys.upgrade(); showPanel(t); renderWeaponBar(); updateHUD(); }
};
$('btnSell3d').onclick = () => {
  if (!G.selected) return;
  const t = G.selected;
  G.supplies += sellValue(t);
  AudioSys.sell();
  towerGroups.splice(towerGroups.indexOf(t.group), 1);
  scene.remove(t.group);
  towers.splice(towers.indexOf(t), 1);
  G.selected = null; hidePanel();
  renderWeaponBar(); updateHUD();
};

canvas.addEventListener('pointerdown', onCanvasPointerDown);
window.addEventListener('pointermove', onCanvasPointerMove);
window.addEventListener('pointerup', onCanvasPointerUp);
canvas.addEventListener('wheel', onWheel, { passive: false });

// ---------- load assets & boot ----------
async function boot() {
  try {
    const loader = (u) => loadGLB(u);
    const [charArr, ballista, catapult, trebuchet, gate, wall, tower, tree, rock] = await Promise.all([
      Promise.all(CHAR_MODELS.map(loader)),
      loader(WEAPONS.ballista.model), loader(WEAPONS.catapult.model), loader(WEAPONS.trebuchet.model),
      loader(GLB('castle-kit/Models/GLB format/metal-gate.glb')),
      loader(GLB('castle-kit/Models/GLB format/wall.glb')),
      loader(GLB('castle-kit/Models/GLB format/tower-square.glb')),
      loader(GLB('castle-kit/Models/GLB format/tree-large.glb')),
      loader(GLB('castle-kit/Models/GLB format/rocks-large.glb')),
    ]);
    CHAR_MODELS.forEach((name, i) => {
      const m = charArr[i];
      m.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
      baseChar[name] = m;
    });
    WEAPONS.ballista._mesh = ballista;
    WEAPONS.catapult._mesh = catapult;
    WEAPONS.trebuchet._mesh = trebuchet;
    buildDecor({ wall, tower, tree, rock });
    gateMesh = buildGate({ gate });
    updateCamera();
    syncGhost();
    renderWeaponBar(); updateHUD();
    $('loading').classList.add('hidden');
    G.loading = false;
  } catch (err) {
    $('loading').textContent = 'Failed to load 3D assets: ' + (err && err.message || err);
    console.error(err);
  }
}

let last = performance.now();
function loop(now) {
  requestAnimationFrame(loop);
  const dt = Math.min((now - last) / 1000, 0.05);
  last = now;
  if (G.state === 'playing') update(dt * G.speed);
  renderer.render(scene, camera);
}
requestAnimationFrame(loop);
boot();
