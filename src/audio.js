// Suoni sintetizzati: nessun file audio da caricare.
export class Sfx {
  constructor() { this.ctx = null; this.on = true; this.crowdG = null; }
  init() {
    if (this.ctx || !this.on) return;
    try {
      const C = window.AudioContext || window.webkitAudioContext; this.ctx = new C();
      const c = this.ctx, len = c.sampleRate * 3, buf = c.createBuffer(1, len, c.sampleRate), d = buf.getChannelData(0);
      let l = 0; for (let i = 0; i < len; i++) { const w = Math.random() * 2 - 1; l = l * 0.97 + w * 0.03; d[i] = l * 6; }
      this.noise = buf;
      const src = c.createBufferSource(); src.buffer = buf; src.loop = true;
      const f = c.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 700; f.Q.value = 0.6;
      this.crowdG = c.createGain(); this.crowdG.gain.value = 0;
      src.connect(f); f.connect(this.crowdG); this.crowdG.connect(c.destination); src.start();
      this.crowdF = f;
    } catch (e) { this.ctx = null; }
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
  kick(v) { const k = Math.min(1, (v || 15) / 30); this.tone(150, 0.09, 'sine', 0.25 + k * 0.3, 55); this.burst(0.05, 1800, 0.12 + k * 0.15); }
  whistle(long) { const d = long ? 0.7 : 0.28; this.tone(2850, d, 'square', 0.05); this.tone(3020, d, 'square', 0.05); }
  post() { this.tone(820, 0.35, 'triangle', 0.3, 760); }
  goal() { this.burst(2.6, 1100, 0.9); this.burst(2.2, 500, 0.6); if (this.crowdG && this.ctx) { const t = this.ctx.currentTime; this.crowdG.gain.cancelScheduledValues(t); this.crowdG.gain.setValueAtTime(0.5, t); this.crowdG.gain.setTargetAtTime(0.16, t + 2, 1); } }
  ooh() { this.burst(0.9, 600, 0.45); }
  click() { this.tone(520, 0.05, 'triangle', 0.12); }
}
