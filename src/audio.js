// Suoni: file veri da www/assets/ quando ci sono (caricati a pezzi, vedi assets.js),
// altrimenti suoni sintetizzati. Un file che manca non blocca nulla: si usa il sintetizzato.
// il file del pubblico è più piano del rumore sintetizzato: lo si alza per avere lo stesso livello
const CROWD_SAMPLE_GAIN = 3.5;
const KICK_SAMPLE_GAIN = 3; // la registrazione del calcio è molto piano
const SAMPLE_IDS = ['crowd', 'goal', 'ooh', 'whistle', 'whistle_long', 'kick', 'post', 'net', 'music'];

export class Sfx {
  constructor() { this.ctx = null; this.on = true; this.crowdG = null; this.buf = {}; this.raw = {}; this.musicSrc = null; this.musicWanted = false; }
  init() {
    if (this.ctx || !this.on) return;
    try {
      const C = window.AudioContext || window.webkitAudioContext; this.ctx = new C();
      const c = this.ctx, len = c.sampleRate * 3, buf = c.createBuffer(1, len, c.sampleRate), d = buf.getChannelData(0);
      let l = 0; for (let i = 0; i < len; i++) { const w = Math.random() * 2 - 1; l = l * 0.97 + w * 0.03; d[i] = l * 6; }
      this.noise = buf;
      this.crowdG = c.createGain(); this.crowdG.gain.value = 0; this.crowdG.connect(c.destination);
      this.startCrowd(null);
      this.decodePending();
    } catch (e) { this.ctx = null; }
  }
  // pubblico di sottofondo: il file 'crowd' se c'è, altrimenti rumore filtrato
  startCrowd(sample) {
    const c = this.ctx; if (!c) return;
    if (this.crowdSrc) { try { this.crowdSrc.stop(); } catch (_) { } this.crowdSrc.disconnect(); }
    const src = c.createBufferSource(); src.buffer = sample || this.noise; src.loop = true;
    if (sample) { const boost = c.createGain(); boost.gain.value = CROWD_SAMPLE_GAIN; src.connect(boost); boost.connect(this.crowdG); }
    else { const f = c.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 700; f.Q.value = 0.6; src.connect(f); f.connect(this.crowdG); }
    src.start(); this.crowdSrc = src;
  }
  // riceve i file scaricati (ArrayBuffer) e li decodifica appena c'è il contesto audio
  useAssets(assets) {
    for (const id of SAMPLE_IDS) if (!this.buf[id] && !this.raw[id] && assets.has(id)) this.raw[id] = assets.get(id);
    this.decodePending();
  }
  decodePending() {
    const c = this.ctx; if (!c) return;
    for (const id of Object.keys(this.raw)) {
      const data = this.raw[id]; delete this.raw[id];
      const ok = b => { this.buf[id] = b; if (id === 'crowd') this.startCrowd(b); if (id === 'music' && this.musicWanted) this.music(true); };
      try { const p = c.decodeAudioData(data.slice(0), ok, () => { }); if (p && p.catch) p.catch(() => { }); } catch (_) { }
    }
  }
  play(id, vol = 1, rate = 1) {
    const b = this.buf[id]; if (!b || !this.ctx || !this.on) return false;
    const c = this.ctx, s = c.createBufferSource(), g = c.createGain();
    s.buffer = b; s.playbackRate.value = rate; g.gain.value = vol; s.connect(g); g.connect(c.destination); s.start();
    return true;
  }
  music(on) {
    this.musicWanted = on;
    if (!on || !this.on) { if (this.musicSrc) { try { this.musicSrc.stop(); } catch (_) { } this.musicSrc = null; } return; }
    if (this.musicSrc || !this.ctx || !this.buf.music) return;
    const c = this.ctx, s = c.createBufferSource(), g = c.createGain();
    s.buffer = this.buf.music; s.loop = true; g.gain.value = 0.35; s.connect(g); g.connect(c.destination); s.start(); this.musicSrc = s;
  }
  resume() { if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume(); }
  crowd(level) { if (this.ctx && this.crowdG) this.crowdG.gain.setTargetAtTime(this.on ? level : 0, this.ctx.currentTime, 0.4); }
  tone(freq, dur, type, vol, slide) {
    if (!this.ctx || !this.on) return; const c = this.ctx, t = c.currentTime, o = c.createOscillator(), g = c.createGain();
    o.type = type || 'sine'; o.frequency.setValueAtTime(freq, t); if (slide) o.frequency.exponentialRampToValueAtTime(slide, t + dur);
    g.gain.setValueAtTime(vol || 0.2, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g); g.connect(c.destination); o.start(t); o.stop(t + dur + 0.02);
  }
  burst(dur, freq, vol) {
    if (!this.ctx || !this.on) return; const c = this.ctx, t = c.currentTime, s = c.createBufferSource(), f = c.createBiquadFilter(), g = c.createGain();
    s.buffer = this.noise; f.type = 'bandpass'; f.frequency.value = freq; f.Q.value = 0.8;
    g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    s.connect(f); f.connect(g); g.connect(c.destination); s.start(t, Math.random() * 2, dur + 0.05);
  }
  kick(v) { const k = Math.min(1, (v || 15) / 30); if (this.play('kick', (0.4 + k * 0.6) * KICK_SAMPLE_GAIN, 0.9 + k * 0.2)) return; this.tone(150, 0.09, 'sine', 0.25 + k * 0.3, 55); this.burst(0.05, 1800, 0.12 + k * 0.15); }
  whistle(long) { if (this.play(long ? 'whistle_long' : 'whistle', 0.7)) return; const d = long ? 0.7 : 0.28; this.tone(2850, d, 'square', 0.05); this.tone(3020, d, 'square', 0.05); }
  post() { if (this.play('post', 0.8)) return; this.tone(820, 0.35, 'triangle', 0.3, 760); }
  goal() {
    this.play('net', 0.8);
    if (!this.play('goal', 1)) { this.burst(2.6, 1100, 0.9); this.burst(2.2, 500, 0.6); }
    if (this.crowdG && this.ctx) { const t = this.ctx.currentTime; this.crowdG.gain.cancelScheduledValues(t); this.crowdG.gain.setValueAtTime(0.5, t); this.crowdG.gain.setTargetAtTime(0.16, t + 2, 1); }
  }
  ooh() { if (this.play('ooh', 0.9)) return; this.burst(0.9, 600, 0.45); }
  click() { this.tone(520, 0.05, 'triangle', 0.12); }
}
