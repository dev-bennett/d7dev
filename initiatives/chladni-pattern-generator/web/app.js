// Chladni reactive pattern generator — evolutionary build.
// Reads CHLADNI_DATA from data.js. Per frame: weighted superposition
// of modes via Lorentzian kernel, rendered as zero-contour lines,
// |ψ| shaded magma, or migrating sand particles. Web Audio plays
// the driving frequency. Keyboard, URL state, click-to-snap,
// material+geometry rescaling, PNG export.

(() => {
  "use strict";
  const DATA = window.CHLADNI_DATA;
  if (!DATA) { console.error("data.js not loaded"); return; }

  // -- Decode circular fields once (base64 → Float32Array)
  function decodeBase64Float32(b64) {
    const bin = atob(b64);
    const buf = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
    return new Float32Array(buf.buffer);
  }
  for (const m of DATA.circle.modes) {
    m.field = decodeBase64Float32(m.field_b64);
    delete m.field_b64;
  }

  // -- Constants
  const SQ_GRID = 192;
  const CI_GRID = DATA.circle.grid;
  const CANVAS_PX = 1024;
  const N_PARTICLES = 4000;

  // -- Material registry (matches python MATERIALS)
  const MATERIALS = {
    steel:    { E: 200e9, rho: 7850, nu: 0.30 },
    aluminum: { E:  69e9, rho: 2700, nu: 0.33 },
    brass:    { E: 110e9, rho: 8500, nu: 0.34 },
    glass:    { E:  70e9, rho: 2500, nu: 0.22 },
  };

  // -- State
  const state = {
    shape: "square",
    style: "lines",
    superposition: "+",
    freq: 1916,
    Q: 30,
    intensity: 1.0,
    on: true,
    amplitude: 1.0,
    audio: false,
    material: "steel",
    side: 0.20,         // square side OR circle diameter (we use side/2 for radius)
    thick: 0.001,
    sqMaxF: 8000,
    ciMaxF: 8000,
  };

  // -- Frequency scaling --------------------------------------------------
  // Bank f_default values are computed at default plate (steel, side=0.20,
  // h=0.001). For other (material, side, thick), scale every f by:
  //   F = (h / h0) * sqrt(E / (rho * (1 - nu^2))) / sqrt(E0 / (rho0 * (1-nu0^2))) * (L0 / L)^2
  // Same formula works for square (where the scale comes from the prefactor
  // of f_nm = prefactor * (n^2 + m^2)) and for circle (where f = (lam^2 /
  // (2*pi*R^2)) * sqrt(D/(rho*h)), and D ~ E*h^3, so the dependence is
  // f ~ h * sqrt(E/(rho(1-nu^2))) / size^2 — identical to the square form).
  const DEFAULT_MAT = MATERIALS.steel;
  const DEFAULT_SIDE_SQ = DATA.square.L;
  const DEFAULT_SIDE_CI = DATA.circle.R * 2; // we treat circle "side" as diameter for the slider
  const DEFAULT_THICK = DATA.square.h;

  function freqScaleSquare() {
    const mat = MATERIALS[state.material];
    const m0 = DEFAULT_MAT;
    const k_mat = Math.sqrt(mat.E / (mat.rho * (1 - mat.nu*mat.nu))) /
                  Math.sqrt(m0.E / (m0.rho * (1 - m0.nu*m0.nu)));
    const k_h   = state.thick / DEFAULT_THICK;
    const k_L   = (DEFAULT_SIDE_SQ / state.side) ** 2;
    return k_mat * k_h * k_L;
  }
  function freqScaleCircle() {
    const mat = MATERIALS[state.material];
    const m0 = DEFAULT_MAT;
    const k_mat = Math.sqrt(mat.E / (mat.rho * (1 - mat.nu*mat.nu))) /
                  Math.sqrt(m0.E / (m0.rho * (1 - m0.nu*m0.nu)));
    const k_h   = state.thick / DEFAULT_THICK;
    const k_R   = (DEFAULT_SIDE_CI / state.side) ** 2;
    return k_mat * k_h * k_R;
  }
  function freqScale() {
    return state.shape === "square" ? freqScaleSquare() : freqScaleCircle();
  }

  // Effective f for a given mode under current material/geometry
  function modeFreq(mode) { return mode.f * freqScale(); }

  function maxFreqForShape(shape) {
    const modes = (shape === "square") ? DATA.square.modes : DATA.circle.modes;
    return modes[modes.length - 1].f * freqScale();
  }

  // -- Square cos lookup -------------------------------------------------
  const SQ_COS = new Map();
  function getCosArray(n) {
    let a = SQ_COS.get(n);
    if (!a) {
      a = new Float32Array(SQ_GRID);
      for (let i = 0; i < SQ_GRID; i++) {
        a[i] = Math.cos(n * Math.PI * (i / (SQ_GRID - 1)));
      }
      SQ_COS.set(n, a);
    }
    return a;
  }

  // -- Lorentzian weights -----------------------------------------------
  function computeWeights(modes, fTarget, Q) {
    const f2 = fTarget * fTarget;
    const gf2 = (fTarget / Q * fTarget) ** 2;
    const items = new Array(modes.length);
    for (let i = 0; i < modes.length; i++) {
      const fn = modeFreq(modes[i]);
      const dr = f2 - fn * fn;
      items[i] = { mode: modes[i], fn, w: 1 / (dr*dr + gf2) };
    }
    items.sort((a, b) => b.w - a.w);
    const top = items.slice(0, 8);
    let s = 0; for (const x of top) s += x.w;
    for (const x of top) x.w /= s;
    return top;
  }

  // -- Field evaluation --------------------------------------------------
  const sqField = new Float32Array(SQ_GRID * SQ_GRID);
  const ciField = new Float32Array(CI_GRID * CI_GRID);

  function evalSquare(weights, supSign) {
    const N = SQ_GRID;
    sqField.fill(0);
    for (const { mode, w } of weights) {
      const cN_x = getCosArray(mode.n);
      const cM_y = getCosArray(mode.m);
      if (mode.diagonal) {
        for (let j = 0; j < N; j++) {
          const cy = cM_y[j], row = j * N;
          for (let i = 0; i < N; i++) sqField[row + i] += w * cN_x[i] * cy;
        }
      } else {
        const cM_x = getCosArray(mode.m);
        const cN_y = getCosArray(mode.n);
        for (let j = 0; j < N; j++) {
          const cmy = cM_y[j], cny = cN_y[j], row = j * N;
          for (let i = 0; i < N; i++) {
            sqField[row + i] += w * (cN_x[i] * cmy + supSign * cM_x[i] * cny);
          }
        }
      }
    }
    return sqField;
  }
  function evalCircle(weights) {
    ciField.fill(0);
    for (const { mode, w } of weights) {
      const f = mode.field, len = f.length;
      for (let i = 0; i < len; i++) ciField[i] += w * f[i];
    }
    return ciField;
  }

  // -- Magma colormap ----------------------------------------------------
  const MAGMA = [
    [0,0,3],[9,7,32],[23,15,61],[40,17,89],[60,16,109],[80,18,124],
    [99,21,136],[118,27,144],[136,33,148],[154,40,150],[171,47,148],
    [188,55,143],[204,64,135],[219,75,124],[232,89,112],[243,104,99],
    [251,121,86],[255,141,73],[254,162,62],[251,184,55],[245,205,57],
    [241,224,68],[243,238,90],[252,253,191]
  ];
  const MAGMA_LEN = MAGMA.length;
  function magma(t, out, idx) {
    if (t < 0) t = 0; else if (t > 1) t = 1;
    const x = t * (MAGMA_LEN - 1);
    const i = x | 0;
    const f = x - i;
    const c1 = MAGMA[i], c2 = MAGMA[Math.min(i + 1, MAGMA_LEN - 1)];
    out[idx]     = c1[0] + (c2[0] - c1[0]) * f;
    out[idx + 1] = c1[1] + (c2[1] - c1[1]) * f;
    out[idx + 2] = c1[2] + (c2[2] - c1[2]) * f;
    out[idx + 3] = 255;
  }

  // -- Marching squares (zero contour) ----------------------------------
  function contour(field, grid) {
    const segs = [];
    const N = grid;
    for (let j = 0; j < N - 1; j++) {
      for (let i = 0; i < N - 1; i++) {
        const idx = j * N + i;
        const v0 = field[idx], v1 = field[idx + 1],
              v2 = field[idx + 1 + N], v3 = field[idx + N];
        let mask = 0;
        if (v0 > 0) mask |= 1;
        if (v1 > 0) mask |= 2;
        if (v2 > 0) mask |= 4;
        if (v3 > 0) mask |= 8;
        if (mask === 0 || mask === 15) continue;
        const e_b = i + v0 / (v0 - v1);
        const e_r = j + v1 / (v1 - v2);
        const e_t = i + v3 / (v3 - v2);
        const e_l = j + v0 / (v0 - v3);
        switch (mask) {
          case 1: case 14: segs.push(e_b, j, i, e_l); break;
          case 2: case 13: segs.push(e_b, j, i+1, e_r); break;
          case 3: case 12: segs.push(i, e_l, i+1, e_r); break;
          case 4: case 11: segs.push(i+1, e_r, e_t, j+1); break;
          case 5: segs.push(e_b, j, i, e_l); segs.push(i+1, e_r, e_t, j+1); break;
          case 6: case 9: segs.push(e_b, j, e_t, j+1); break;
          case 7: case 8: segs.push(i, e_l, e_t, j+1); break;
          case 10: segs.push(e_b, j, i+1, e_r); segs.push(i, e_l, e_t, j+1); break;
        }
      }
    }
    return segs;
  }

  // -- Sand particles ---------------------------------------------------
  // Particles in normalized [0,1]^2 (square) or unit disk (circle).
  // Per frame: sample ψ at particle pos via bilinear interp;
  // gradient via finite differences; particle drifts toward |ψ|=0
  // at speed proportional to amplitude * |ψ|; jitter scales with (1 - amplitude).
  const particles = new Float32Array(N_PARTICLES * 2);
  function initParticles(shape) {
    for (let i = 0; i < N_PARTICLES; i++) {
      let x, y;
      if (shape === "square") {
        x = Math.random();
        y = Math.random();
      } else {
        // uniform on unit disk
        const r = Math.sqrt(Math.random());
        const t = Math.random() * Math.PI * 2;
        x = 0.5 + 0.5 * r * Math.cos(t);
        y = 0.5 + 0.5 * r * Math.sin(t);
      }
      particles[i*2]     = x;
      particles[i*2 + 1] = y;
    }
  }
  initParticles("square");

  function sampleField(field, grid, x, y) {
    // bilinear sample at fractional grid coords
    const fx = x * (grid - 1);
    const fy = y * (grid - 1);
    const i0 = fx | 0, j0 = fy | 0;
    const i1 = Math.min(i0 + 1, grid - 1);
    const j1 = Math.min(j0 + 1, grid - 1);
    const tx = fx - i0, ty = fy - j0;
    const v00 = field[j0 * grid + i0];
    const v10 = field[j0 * grid + i1];
    const v01 = field[j1 * grid + i0];
    const v11 = field[j1 * grid + i1];
    const v0 = v00 * (1 - tx) + v10 * tx;
    const v1 = v01 * (1 - tx) + v11 * tx;
    return v0 * (1 - ty) + v1 * ty;
  }
  function gradField(field, grid, x, y) {
    const eps = 1 / (grid - 1);
    const ex = Math.min(0.999, Math.max(0.001, x));
    const ey = Math.min(0.999, Math.max(0.001, y));
    const gx = (sampleField(field, grid, Math.min(1, ex + eps), ey)
              - sampleField(field, grid, Math.max(0, ex - eps), ey)) / (2 * eps);
    const gy = (sampleField(field, grid, ex, Math.min(1, ey + eps))
              - sampleField(field, grid, ex, Math.max(0, ey - eps))) / (2 * eps);
    return [gx, gy];
  }

  function updateParticles(field, grid, dt) {
    const amp = state.amplitude;
    // When DRIVING (amp→1): step toward the contour (descend |ψ|^2),
    //   particles converge onto nodal lines. Jitter is small.
    // When PAUSED (amp→0): no field force, big jitter, particles drift back to uniform.
    const stepK = 0.7 * amp;
    const jitter = 0.0035 * (1.0 - amp) + 0.0008;
    for (let p = 0; p < N_PARTICLES; p++) {
      let x = particles[p*2], y = particles[p*2 + 1];
      // Field-aligned motion: move toward |ψ|=0, i.e., dpos = -k * 2*ψ*∇ψ
      if (stepK > 0.001) {
        const v = sampleField(field, grid, x, y);
        const [gx, gy] = gradField(field, grid, x, y);
        const gn2 = gx*gx + gy*gy + 1e-6;
        // Newton-style step: dx = -v * g / |g|^2, capped
        let dx = -v * gx / gn2 * stepK * dt * 60;
        let dy = -v * gy / gn2 * stepK * dt * 60;
        const mag2 = dx*dx + dy*dy;
        if (mag2 > 0.0009) {
          const k = 0.03 / Math.sqrt(mag2);
          dx *= k; dy *= k;
        }
        x += dx; y += dy;
      }
      // Random walk
      x += (Math.random() - 0.5) * jitter;
      y += (Math.random() - 0.5) * jitter;
      // Boundary
      if (state.shape === "square") {
        if (x < 0.001) x = 0.001 + Math.random() * 0.01;
        if (x > 0.999) x = 0.999 - Math.random() * 0.01;
        if (y < 0.001) y = 0.001 + Math.random() * 0.01;
        if (y > 0.999) y = 0.999 - Math.random() * 0.01;
      } else {
        const dx = x - 0.5, dy = y - 0.5;
        const r2 = dx*dx + dy*dy;
        if (r2 > 0.245) {
          const r = Math.sqrt(r2);
          const sc = (0.49 - 0.005 - Math.random()*0.005) / r;
          x = 0.5 + dx * sc;
          y = 0.5 + dy * sc;
        }
      }
      particles[p*2] = x;
      particles[p*2 + 1] = y;
    }
  }

  // -- Rendering --------------------------------------------------------
  const canvas = document.getElementById("plate");
  const ctx = canvas.getContext("2d", { alpha: false });

  const offSquare = document.createElement("canvas");
  offSquare.width = SQ_GRID; offSquare.height = SQ_GRID;
  const offSquareCtx = offSquare.getContext("2d");
  const sqImageData = offSquareCtx.createImageData(SQ_GRID, SQ_GRID);

  const offCircle = document.createElement("canvas");
  offCircle.width = CI_GRID; offCircle.height = CI_GRID;
  const offCircleCtx = offCircle.getContext("2d");
  const ciImageData = offCircleCtx.createImageData(CI_GRID, CI_GRID);

  function fillBg() {
    ctx.fillStyle = "#08080a";
    ctx.fillRect(0, 0, CANVAS_PX, CANVAS_PX);
  }
  function clipDisk() {
    ctx.save();
    ctx.beginPath();
    ctx.arc(CANVAS_PX/2, CANVAS_PX/2, CANVAS_PX/2 - 10, 0, Math.PI*2);
    ctx.clip();
  }
  function strokeDisk() {
    ctx.beginPath();
    ctx.arc(CANVAS_PX/2, CANVAS_PX/2, CANVAS_PX/2 - 10, 0, Math.PI*2);
    ctx.lineWidth = 1;
    ctx.strokeStyle = "rgba(180, 180, 195, 0.18)";
    ctx.stroke();
  }

  function renderLines(field, grid, amp) {
    fillBg();
    if (state.shape === "circle") clipDisk();
    if (amp <= 0.005) {
      if (state.shape === "circle") { ctx.restore(); strokeDisk(); }
      return;
    }
    const segs = contour(field, grid);
    const inset = state.shape === "circle" ? 10 : 0;
    const cell = (CANVAS_PX - 2*inset) / (grid - 1);
    // Soft glow underneath
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.globalCompositeOperation = "lighter";
    ctx.strokeStyle = `rgba(245, 230, 210, ${(amp * 0.18).toFixed(3)})`;
    ctx.lineWidth = 4.5;
    ctx.beginPath();
    for (let k = 0; k < segs.length; k += 4) {
      ctx.moveTo(inset + segs[k]*cell,   inset + segs[k+1]*cell);
      ctx.lineTo(inset + segs[k+2]*cell, inset + segs[k+3]*cell);
    }
    ctx.stroke();
    // Crisp main stroke
    ctx.globalCompositeOperation = "source-over";
    ctx.strokeStyle = `rgba(246, 239, 226, ${amp.toFixed(3)})`;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    for (let k = 0; k < segs.length; k += 4) {
      ctx.moveTo(inset + segs[k]*cell,   inset + segs[k+1]*cell);
      ctx.lineTo(inset + segs[k+2]*cell, inset + segs[k+3]*cell);
    }
    ctx.stroke();
    if (state.shape === "circle") { ctx.restore(); strokeDisk(); }
  }

  function renderShaded(field, grid, amp) {
    const off = state.shape === "circle" ? offCircleCtx : offSquareCtx;
    const offImg = state.shape === "circle" ? offCircle : offSquare;
    const imgData = state.shape === "circle" ? ciImageData : sqImageData;
    const pixels = imgData.data;
    let maxAbs = 1e-9;
    for (let i = 0; i < field.length; i++) {
      const a = field[i] < 0 ? -field[i] : field[i];
      if (a > maxAbs) maxAbs = a;
    }
    const scale = (1 / maxAbs) * state.intensity * amp;
    const isCirc = state.shape === "circle";
    const cx = (grid - 1) / 2, cy = (grid - 1) / 2;
    const r2 = (grid / 2 - 0.5) ** 2;
    for (let j = 0; j < grid; j++) {
      const row = j * grid;
      for (let i = 0; i < grid; i++) {
        const idx = (row + i) * 4;
        if (isCirc) {
          const dx = i - cx, dy = j - cy;
          if (dx*dx + dy*dy > r2) {
            pixels[idx]=8; pixels[idx+1]=8; pixels[idx+2]=10; pixels[idx+3]=255;
            continue;
          }
        }
        const v = field[row + i];
        const t = (v < 0 ? -v : v) * scale;
        magma(t, pixels, idx);
      }
    }
    off.putImageData(imgData, 0, 0);
    fillBg();
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
    if (isCirc) {
      clipDisk();
      ctx.drawImage(offImg, 10, 10, CANVAS_PX - 20, CANVAS_PX - 20);
      ctx.restore();
      strokeDisk();
    } else {
      ctx.drawImage(offImg, 0, 0, CANVAS_PX, CANVAS_PX);
    }
  }

  function renderSand(field, grid, dt, amp) {
    fillBg();
    if (state.shape === "circle") clipDisk();
    updateParticles(field, grid, dt);
    const inset = state.shape === "circle" ? 10 : 0;
    const span  = CANVAS_PX - 2*inset;
    // Draw all particles as soft dots
    ctx.globalCompositeOperation = "lighter";
    ctx.fillStyle = `rgba(228, 207, 168, ${(0.55 * (0.4 + 0.6 * amp)).toFixed(3)})`;
    for (let p = 0; p < N_PARTICLES; p++) {
      const x = inset + particles[p*2] * span;
      const y = inset + particles[p*2 + 1] * span;
      // micro variation in particle size for grain feel
      const r = 0.7 + ((p & 7) * 0.07);
      ctx.fillRect(x - r * 0.5, y - r * 0.5, r, r);
    }
    ctx.globalCompositeOperation = "source-over";
    if (state.shape === "circle") { ctx.restore(); strokeDisk(); }
  }

  // -- Web Audio --------------------------------------------------------
  let audioCtx = null, oscNode = null, gainNode = null;
  function ensureAudio() {
    if (audioCtx) return;
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      audioCtx = new Ctx();
      oscNode = audioCtx.createOscillator();
      gainNode = audioCtx.createGain();
      oscNode.type = "sine";
      oscNode.frequency.value = state.freq;
      gainNode.gain.value = 0;
      oscNode.connect(gainNode).connect(audioCtx.destination);
      oscNode.start();
    } catch (e) { console.error("Web Audio init failed", e); }
  }
  function updateAudio(now) {
    if (!audioCtx) return;
    const t = audioCtx.currentTime;
    const targetGain = state.audio ? (0.10 * state.intensity * state.amplitude) : 0;
    gainNode.gain.setTargetAtTime(targetGain, t, 0.05);
    oscNode.frequency.setTargetAtTime(state.freq, t, 0.04);
  }

  // -- Frame loop -------------------------------------------------------
  let lastT = performance.now();
  let lastShapeForParticles = "square";
  function frame(now) {
    const dt = Math.min(0.05, (now - lastT) / 1000);
    lastT = now;

    // Animate amplitude
    const target = state.on ? 1.0 : 0.0;
    const tau = state.on ? 0.18 : 0.45;
    const k = 1 - Math.exp(-dt / tau);
    state.amplitude += (target - state.amplitude) * k;
    if (Math.abs(state.amplitude - target) < 0.0008) state.amplitude = target;

    // Field
    const modes = state.shape === "square" ? DATA.square.modes : DATA.circle.modes;
    const weights = computeWeights(modes, state.freq, state.Q);
    const supSign = state.superposition === "+" ? 1 : -1;
    let field, grid;
    if (state.shape === "square") { field = evalSquare(weights, supSign); grid = SQ_GRID; }
    else                          { field = evalCircle(weights);          grid = CI_GRID; }

    // Reset particles when shape changes
    if (state.shape !== lastShapeForParticles) {
      initParticles(state.shape);
      lastShapeForParticles = state.shape;
    }

    // Render
    if (state.style === "lines")       renderLines(field, grid, state.amplitude);
    else if (state.style === "shaded") renderShaded(field, grid, state.amplitude);
    else                                renderSand(field, grid, dt, state.amplitude);

    updateOverlay(weights);
    updateAudio(now);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  // -- DOM refs ---------------------------------------------------------
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => Array.from(document.querySelectorAll(sel));
  const freqInput = $("#freq");
  const freqLabel = $("#freq-label");
  const freqMinEl = $("#freq-min");
  const freqMaxEl = $("#freq-max");
  const readout = $("#readout");
  const ovMode = $("#ov-mode");
  const ovFreq = $("#ov-freq");
  const plateWrap = $("#plate-wrap");
  const plateMeta = $("#plate-meta");
  const plateSummary = $("#plate-summary");
  const tickCanvas = $("#freq-ticks");
  const tickCtx = tickCanvas.getContext("2d");
  const tickTip = $("#tick-tip");
  const onoffBtn = $("#onoff");
  const audioBtn = $("#audio-toggle");
  const qval = $("#qval");
  const qvalNum = $("#qval-num");
  const ampInput = $("#amp");
  const ampNum = $("#amp-num");
  const sideInput = $("#side");
  const sideNum = $("#side-num");
  const thickInput = $("#thick");
  const thickNum = $("#thick-num");

  function updateOverlay(weights) {
    if (!weights || !weights.length) { ovMode.textContent="—"; readout.textContent="—"; return; }
    const top = weights[0];
    const detuning = Math.abs(top.fn - state.freq) / state.freq;
    const locked = detuning < 0.005 && top.w > 0.85;
    plateWrap.dataset.locked = locked ? "true" : "false";
    ovMode.textContent = `(${top.mode.n},${top.mode.m})`;
    ovFreq.textContent = state.freq.toFixed(state.freq < 200 ? 1 : 0);
    let html = `<span class="${locked ? "accent" : "strong"}">(${top.mode.n},${top.mode.m})</span> · ` +
               `${top.fn.toFixed(1)} Hz · ${(top.w * 100).toFixed(0)}%`;
    if (weights[1] && weights[1].w > 0.10) {
      html += ` · (${weights[1].mode.n},${weights[1].mode.m}) ${(weights[1].w * 100).toFixed(0)}%`;
    }
    readout.innerHTML = html;
  }

  function refreshFreqRange() {
    const mx = Math.min(8000, Math.ceil(maxFreqForShape(state.shape)));
    state.sqMaxF = Math.ceil(maxFreqForShape("square"));
    state.ciMaxF = Math.ceil(maxFreqForShape("circle"));
    freqInput.max = mx;
    freqMaxEl.textContent = mx + " Hz";
    if (state.freq > mx) {
      state.freq = mx;
      freqInput.value = mx;
      freqLabel.textContent = mx;
    }
    drawTicks();
  }

  function drawTicks() {
    const dpr = window.devicePixelRatio || 1;
    const w = tickCanvas.clientWidth;
    const h = 22;
    if (w === 0) { requestAnimationFrame(drawTicks); return; }
    tickCanvas.width = w * dpr; tickCanvas.height = h * dpr;
    tickCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
    tickCtx.clearRect(0, 0, w, h);
    const fmin = parseFloat(freqInput.min), fmax = parseFloat(freqInput.max);
    const modes = state.shape === "square" ? DATA.square.modes : DATA.circle.modes;
    // Mode ticks
    tickCtx.strokeStyle = "rgba(120, 120, 130, 0.45)";
    tickCtx.lineWidth = 1;
    for (const m of modes) {
      const f = modeFreq(m);
      if (f < fmin || f > fmax) continue;
      const x = ((f - fmin) / (fmax - fmin)) * w;
      tickCtx.beginPath();
      tickCtx.moveTo(x + 0.5, 0);
      tickCtx.lineTo(x + 0.5, 7);
      tickCtx.stroke();
    }
    // Current freq
    const x = ((state.freq - fmin) / (fmax - fmin)) * w;
    tickCtx.strokeStyle = "rgba(241, 163, 102, 0.95)";
    tickCtx.lineWidth = 1.5;
    tickCtx.beginPath();
    tickCtx.moveTo(x + 0.5, 0);
    tickCtx.lineTo(x + 0.5, 12);
    tickCtx.stroke();
  }
  window.addEventListener("resize", drawTicks);

  function modesArray() {
    return state.shape === "square" ? DATA.square.modes : DATA.circle.modes;
  }
  function nearestMode(f) {
    let best = null, bestD = Infinity;
    for (const m of modesArray()) {
      const fn = modeFreq(m);
      const d = Math.abs(fn - f);
      if (d < bestD) { bestD = d; best = m; }
    }
    return best;
  }
  function stepToAdjacentMode(direction) {
    const sorted = modesArray().map(m => modeFreq(m)).sort((a, b) => a - b);
    if (direction > 0) {
      for (const fn of sorted) if (fn > state.freq + 0.5) { setFreq(fn); return; }
    } else {
      for (let i = sorted.length - 1; i >= 0; i--) if (sorted[i] < state.freq - 0.5) { setFreq(sorted[i]); return; }
    }
  }
  function setFreq(f) {
    f = Math.max(parseFloat(freqInput.min), Math.min(parseFloat(freqInput.max), f));
    state.freq = f;
    freqInput.value = f;
    freqLabel.textContent = f.toFixed(f < 200 ? 1 : 0);
    drawTicks();
    saveURL();
  }

  // -- Tick interactions: click to snap, hover to label
  tickCanvas.addEventListener("click", (e) => {
    const rect = tickCanvas.getBoundingClientRect();
    const xpx = e.clientX - rect.left;
    const fmin = parseFloat(freqInput.min), fmax = parseFloat(freqInput.max);
    const f = fmin + (xpx / rect.width) * (fmax - fmin);
    const m = nearestMode(f);
    if (m) setFreq(modeFreq(m));
  });
  tickCanvas.addEventListener("mousemove", (e) => {
    const rect = tickCanvas.getBoundingClientRect();
    const xpx = e.clientX - rect.left;
    const fmin = parseFloat(freqInput.min), fmax = parseFloat(freqInput.max);
    const f = fmin + (xpx / rect.width) * (fmax - fmin);
    const m = nearestMode(f);
    if (!m) { tickTip.classList.remove("show"); return; }
    const fn = modeFreq(m);
    const proximityPx = Math.abs(((fn - fmin) / (fmax - fmin)) * rect.width - xpx);
    if (proximityPx > 12) { tickTip.classList.remove("show"); return; }
    tickTip.textContent = `(${m.n},${m.m}) · ${fn.toFixed(1)} Hz`;
    const fxFromLeft = ((fn - fmin) / (fmax - fmin)) * rect.width;
    tickTip.style.left = fxFromLeft + "px";
    tickTip.classList.add("show");
  });
  tickCanvas.addEventListener("mouseleave", () => tickTip.classList.remove("show"));

  // -- Slider events ----------------------------------------------------
  freqInput.addEventListener("input", (e) => setFreq(parseFloat(e.target.value)));
  qval.addEventListener("input", (e) => {
    state.Q = parseFloat(e.target.value); qvalNum.textContent = state.Q; saveURL();
  });
  ampInput.addEventListener("input", (e) => {
    state.intensity = parseFloat(e.target.value);
    ampNum.textContent = Math.round(state.intensity * 100) + "%";
    saveURL();
  });
  sideInput.addEventListener("input", (e) => {
    state.side = parseFloat(e.target.value);
    sideNum.textContent = (state.side * 100).toFixed(1) + " cm";
    refreshFreqRange();
    updatePlateMeta();
    saveURL();
  });
  thickInput.addEventListener("input", (e) => {
    state.thick = parseFloat(e.target.value);
    thickNum.textContent = (state.thick * 1000).toFixed(2) + " mm";
    refreshFreqRange();
    updatePlateMeta();
    saveURL();
  });

  // -- On/off + audio --------------------------------------------------
  onoffBtn.addEventListener("click", () => {
    state.on = !state.on;
    onoffBtn.setAttribute("aria-pressed", state.on);
    document.body.dataset.driving = state.on;
    saveURL();
  });
  audioBtn.addEventListener("click", () => {
    if (!audioCtx) ensureAudio();
    if (audioCtx && audioCtx.state === "suspended") audioCtx.resume();
    state.audio = !state.audio;
    audioBtn.setAttribute("aria-pressed", state.audio);
    saveURL();
  });

  // -- Segmented buttons -----------------------------------------------
  $$(".segmented").forEach(group => {
    group.querySelectorAll(".seg").forEach(btn => {
      btn.addEventListener("click", () => {
        group.querySelectorAll(".seg").forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        if (btn.dataset.shape) {
          state.shape = btn.dataset.shape;
          document.body.dataset.shape = btn.dataset.shape;
          refreshFreqRange();
          updatePlateMeta();
        } else if (btn.dataset.style) {
          state.style = btn.dataset.style;
          document.body.dataset.style = btn.dataset.style;
        } else if (btn.dataset.sup) {
          state.superposition = btn.dataset.sup;
        } else if (btn.dataset.material) {
          state.material = btn.dataset.material;
          refreshFreqRange();
          updatePlateMeta();
        }
        saveURL();
      });
    });
  });

  function updatePlateMeta() {
    const matName = state.material[0].toUpperCase() + state.material.slice(1);
    const sizeStr = state.shape === "square"
      ? `${(state.side*100).toFixed(1)} × ${(state.side*100).toFixed(1)} × ${(state.thick*1000).toFixed(1)} mm`
      : `⌀ ${(state.side*100).toFixed(1)} × ${(state.thick*1000).toFixed(1)} mm`;
    plateMeta.textContent = `${matName} · ${sizeStr}`;
    plateSummary.textContent = `${matName} · ${sizeStr}`;
  }

  // -- 3D tilt on plate hover ------------------------------------------
  plateWrap.addEventListener("mousemove", (e) => {
    const r = plateWrap.getBoundingClientRect();
    const cx = r.left + r.width / 2;
    const cy = r.top + r.height / 2;
    const dx = (e.clientX - cx) / (r.width / 2);
    const dy = (e.clientY - cy) / (r.height / 2);
    const tilt = 3.5;
    plateWrap.style.transform = `rotateY(${dx * tilt}deg) rotateX(${-dy * tilt}deg)`;
  });
  plateWrap.addEventListener("mouseleave", () => {
    plateWrap.style.transform = "";
  });

  // -- Keyboard shortcuts -----------------------------------------------
  document.addEventListener("keydown", (e) => {
    if (e.target.tagName === "INPUT" && e.target.type !== "range") return;
    switch (e.key) {
      case " ":
      case "Space":
        e.preventDefault(); onoffBtn.click(); break;
      case "ArrowLeft":  e.preventDefault(); stepToAdjacentMode(-1); break;
      case "ArrowRight": e.preventDefault(); stepToAdjacentMode(+1); break;
      case "ArrowUp":    e.preventDefault(); state.Q = Math.min(200, state.Q + 5); qval.value = state.Q; qvalNum.textContent = state.Q; saveURL(); break;
      case "ArrowDown":  e.preventDefault(); state.Q = Math.max(5,   state.Q - 5); qval.value = state.Q; qvalNum.textContent = state.Q; saveURL(); break;
      case "s": case "S": cycleStyle(); break;
      case "m": case "M": cycleShape(); break;
      case "a": case "A": audioBtn.click(); break;
      case "d": case "D": exportPNG(); break;
    }
  });
  function cycleStyle() {
    const order = ["lines", "shaded", "sand"];
    const i = (order.indexOf(state.style) + 1) % order.length;
    const btn = document.querySelector(`.seg[data-style="${order[i]}"]`);
    if (btn) btn.click();
  }
  function cycleShape() {
    const order = ["square", "circle"];
    const i = (order.indexOf(state.shape) + 1) % order.length;
    const btn = document.querySelector(`.seg[data-shape="${order[i]}"]`);
    if (btn) btn.click();
  }

  // -- PNG export -------------------------------------------------------
  function exportPNG() {
    const link = document.createElement("a");
    const fname = `chladni_${state.shape}_${Math.round(state.freq)}hz_${state.style}.png`;
    link.download = fname;
    link.href = canvas.toDataURL("image/png");
    link.click();
  }
  $("#btn-snapshot").addEventListener("click", exportPNG);

  // -- URL hash state ---------------------------------------------------
  function saveURL() {
    const params = new URLSearchParams();
    params.set("f", state.freq.toFixed(1));
    params.set("q", state.Q);
    params.set("i", state.intensity.toFixed(2));
    params.set("shape", state.shape);
    params.set("style", state.style);
    params.set("sup", state.superposition);
    params.set("on", state.on ? 1 : 0);
    params.set("audio", state.audio ? 1 : 0);
    params.set("mat", state.material);
    params.set("side", state.side.toFixed(3));
    params.set("h", state.thick.toFixed(4));
    history.replaceState(null, "", "#" + params.toString());
  }
  function loadURL() {
    const hash = window.location.hash.slice(1);
    if (!hash) return;
    const p = new URLSearchParams(hash);
    if (p.has("f"))     state.freq = parseFloat(p.get("f"));
    if (p.has("q"))     state.Q = parseFloat(p.get("q"));
    if (p.has("i"))     state.intensity = parseFloat(p.get("i"));
    if (p.has("shape")) state.shape = p.get("shape");
    if (p.has("style")) state.style = p.get("style");
    if (p.has("sup"))   state.superposition = p.get("sup");
    if (p.has("on"))    state.on = p.get("on") === "1";
    if (p.has("audio")) state.audio = p.get("audio") === "1";
    if (p.has("mat"))   state.material = p.get("mat");
    if (p.has("side"))  state.side = parseFloat(p.get("side"));
    if (p.has("h"))     state.thick = parseFloat(p.get("h"));
  }

  function syncControlsFromState() {
    freqInput.value = state.freq;
    freqLabel.textContent = state.freq.toFixed(state.freq < 200 ? 1 : 0);
    qval.value = state.Q; qvalNum.textContent = state.Q;
    ampInput.value = state.intensity; ampNum.textContent = Math.round(state.intensity*100)+"%";
    sideInput.value = state.side; sideNum.textContent = (state.side*100).toFixed(1)+" cm";
    thickInput.value = state.thick; thickNum.textContent = (state.thick*1000).toFixed(2)+" mm";
    onoffBtn.setAttribute("aria-pressed", state.on);
    audioBtn.setAttribute("aria-pressed", state.audio);
    document.body.dataset.shape = state.shape;
    document.body.dataset.style = state.style;
    document.body.dataset.driving = state.on;
    document.querySelectorAll(".seg").forEach(b => {
      if (b.dataset.shape && b.dataset.shape === state.shape) b.classList.add("active");
      else if (b.dataset.shape) b.classList.remove("active");
      if (b.dataset.style && b.dataset.style === state.style) b.classList.add("active");
      else if (b.dataset.style) b.classList.remove("active");
      if (b.dataset.sup && b.dataset.sup === state.superposition) b.classList.add("active");
      else if (b.dataset.sup) b.classList.remove("active");
      if (b.dataset.material && b.dataset.material === state.material) b.classList.add("active");
      else if (b.dataset.material) b.classList.remove("active");
    });
    refreshFreqRange();
    updatePlateMeta();
  }

  // -- Init -------------------------------------------------------------
  loadURL();
  syncControlsFromState();
  freqMinEl.textContent = freqInput.min + " Hz";
  freqMaxEl.textContent = freqInput.max + " Hz";
})();
