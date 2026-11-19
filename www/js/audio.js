// Settore Zero — audio: suoni e musiche registrati (www/assets/audio/, scaricati a pezzi da js/caricamento.js) con ripiego sintetizzato (Web Audio)
'use strict';
/* ===== audio: effetti sintetizzati con riverbero (usati come ripiego e come strato aggiuntivo) ===== */
let AC=null,MG=null,SFX=null,REV=null,MUS=null,NB=null,silentEl=null;const sndLast={};
function abuild(ctx){AC=ctx;const comp=AC.createDynamicsCompressor();comp.threshold.value=-14;comp.ratio.value=5;comp.attack.value=.003;comp.release.value=.2;MG=AC.createGain();MG.gain.value=.7;MG.connect(comp);comp.connect(AC.destination);
 SFX=AC.createGain();SFX.connect(MG);MUS=AC.createGain();MUS.gain.value=0;MUS.connect(MG);
 const len=AC.sampleRate*1.8|0,ib=AC.createBuffer(2,len,AC.sampleRate);for(let c=0;c<2;c++){const d=ib.getChannelData(c);let lp=0;for(let i=0;i<len;i++){const t=i/len;lp+=((Math.random()*2-1)-lp)*(.6-.45*t);d[i]=lp*Math.pow(1-t,2.6)*(i<300?i/300:1);}}
 const rvb=AC.createConvolver();rvb.buffer=ib;REV=AC.createGain();REV.gain.value=.55;REV.connect(rvb);rvb.connect(MG);
 NB=AC.createBuffer(1,AC.sampleRate*2,AC.sampleRate);const d=NB.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;}
function ainit(){try{if(!AC){abuild(new(window.AudioContext||window.webkitAudioContext)());recLoad();
  try{const n=4000,b=new Uint8Array(44+n),dv=new DataView(b.buffer),W=(o,s)=>{for(let i=0;i<s.length;i++)b[o+i]=s.charCodeAt(i);};W(0,'RIFF');dv.setUint32(4,36+n,true);W(8,'WAVEfmt ');dv.setUint32(16,16,true);dv.setUint16(20,1,true);dv.setUint16(22,1,true);dv.setUint32(24,8000,true);dv.setUint32(28,8000,true);dv.setUint16(32,1,true);dv.setUint16(34,8,true);W(36,'data');dv.setUint32(40,n,true);b.fill(128,44);
   let s='';for(let i=0;i<b.length;i++)s+=String.fromCharCode(b[i]);silentEl=new Audio('data:audio/wav;base64,'+btoa(s));silentEl.loop=true;silentEl.volume=.01;}catch(e){}}
 if(AC.state==='suspended')AC.resume();if(silentEl&&silentEl.paused){const p=silentEl.play();if(p&&p.catch)p.catch(()=>{});}}catch(e){}}
function aout(node,rev){node.connect(SFX);if(rev){const g=AC.createGain();g.gain.value=rev;node.connect(g);g.connect(REV);}}
function nz(o){const s=AC.createBufferSource();s.buffer=NB;s.loop=true;const f=AC.createBiquadFilter();f.type=o.type||'lowpass';f.Q.value=o.q||.7;const t=AC.currentTime+(o.t||0);f.frequency.setValueAtTime(o.f0,t);if(o.f1)f.frequency.exponentialRampToValueAtTime(o.f1,t+o.dur);
 const g=AC.createGain();g.gain.setValueAtTime(.0001,t);g.gain.linearRampToValueAtTime(o.vol,t+(o.atk||.002));g.gain.exponentialRampToValueAtTime(.0001,t+o.dur);s.connect(f);f.connect(g);aout(g,o.rev);s.start(t,Math.random()*1.5);s.stop(t+o.dur+.03);}
function osc(o){const s=AC.createOscillator(),g=AC.createGain(),t=AC.currentTime+(o.t||0);s.type=o.type||'sine';s.frequency.setValueAtTime(o.f0,t);if(o.f1)s.frequency.exponentialRampToValueAtTime(o.f1,t+o.dur);g.gain.setValueAtTime(.0001,t);g.gain.linearRampToValueAtTime(o.vol,t+(o.atk||.003));g.gain.exponentialRampToValueAtTime(.0001,t+o.dur);s.connect(g);aout(g,o.rev);s.start(t);s.stop(t+o.dur+.03);}
function tone(f0,f1,dur,type,vol,dl){osc({t:dl||0,dur,vol,type,f0,f1:f1===f0?0:f1});}
function gun(p){const k=p.k||1;nz({dur:.035,vol:p.crack*k,type:'highpass',f0:1800,rev:p.rev*.6});nz({dur:p.bd,vol:p.body*k,f0:p.lp||4200,f1:260,rev:p.rev});osc({dur:p.td||.12,vol:p.thump*k,f0:p.tf||170,f1:42,rev:p.rev*.5});if(!p.lite)nz({t:.03,dur:p.bd*2.4,vol:p.body*k*.22,f0:900,f1:150,rev:p.rev});}
function clk(t,f,v){nz({t,dur:.018,vol:v||.2,type:'bandpass',f0:f,q:2.5});}
const GUNS={pistol:{crack:.5,body:.4,bd:.14,thump:.5,tf:190,rev:.35},revolver:{crack:.55,body:.5,bd:.19,thump:.65,tf:155,rev:.5},smg:{crack:.4,body:.3,bd:.09,thump:.35,tf:200,rev:.25,lite:1},
 shotgun:{crack:.5,body:.8,bd:.32,thump:.9,tf:120,td:.22,rev:.65,lp:3000},rifle:{crack:.6,body:.45,bd:.13,thump:.5,tf:170,rev:.4},sniper:{crack:.7,body:.85,bd:.42,thump:.9,tf:105,td:.3,rev:.95},minigun:{crack:.5,body:.38,bd:.1,thump:.5,tf:150,rev:.3,lite:1}};
function sndSyn(n){try{
 if(n.charCodeAt(0)===119&&n.charCodeAt(1)===95){const k=n.slice(2),g=GUNS[k];if(g){gun(g);if(k==='shotgun'){clk(.3,1500,.25);clk(.44,2100,.22);}else if(k==='sniper'){clk(.5,1700,.2);clk(.72,2300,.18);}return;}
  if(k==='plasma'){osc({dur:.2,vol:.22,type:'sawtooth',f0:760,f1:130,rev:.4});nz({dur:.16,vol:.2,type:'bandpass',f0:2400,f1:500,q:2,rev:.4});return;}
  if(k==='rocket'){nz({dur:.6,vol:.45,type:'bandpass',f0:300,f1:2000,q:1.2,rev:.5});osc({dur:.25,vol:.5,f0:110,f1:45});return;}
  osc({dur:.06,vol:.07,type:'sawtooth',f0:1500,f1:1250});return;}
 switch(n){
 case'eshot':gun({crack:.16,body:.3,bd:.13,thump:.22,tf:150,rev:.8,lp:1900});break;
 case'esnipe':gun({crack:.3,body:.6,bd:.35,thump:.5,tf:110,td:.25,rev:1,lp:2400});break;
 case'zap':osc({dur:.07,vol:.07,type:'sawtooth',f0:1500,f1:1250});break;
 case'boom':nz({dur:1.2,vol:.9,f0:1400,f1:70,rev:.9});osc({dur:.8,vol:.9,f0:75,f1:26,rev:.3});nz({dur:.06,vol:.6,type:'highpass',f0:1200,rev:.5});for(let i=0;i<5;i++)nz({t:.1+Math.random()*.5,dur:.03,vol:.15,type:'bandpass',f0:1500+Math.random()*2000,q:3,rev:.5});break;
 case'ric':osc({dur:.28,vol:.12,f0:2400+Math.random()*900,f1:900+Math.random()*500,rev:.5});nz({dur:.04,vol:.3,type:'bandpass',f0:4200,q:6});break;
 case'whiz':nz({dur:.15,vol:.45,type:'bandpass',f0:3600,f1:800,q:4});break;
 case'cover':nz({dur:.05,vol:.42,type:'bandpass',f0:2100,q:2.5,rev:.3});osc({dur:.06,vol:.14,type:'triangle',f0:900,f1:280});break;
 case'rel':clk(0,3200,.5);clk(.16,1800,.55);osc({t:.16,dur:.04,vol:.08,type:'square',f0:300,f1:120});break;
 case'step':nz({dur:.07,vol:.32,f0:240});nz({dur:.012,vol:.1,type:'highpass',f0:2500});break;
 case'hurt':osc({dur:.17,vol:.55,f0:125,f1:48});nz({dur:.09,vol:.32,f0:900,f1:200});break;
 case'kill':osc({dur:.04,vol:.05,type:'triangle',f0:1100});nz({t:.28,dur:.13,vol:.2,f0:300,rev:.3});osc({t:.28,dur:.1,vol:.22,f0:90,f1:45});break;
 case'head':osc({dur:.13,vol:.22,type:'triangle',f0:2100,rev:.3});osc({dur:.09,vol:.07,f0:3150});break;
 case'crash':nz({dur:.26,vol:.5,f0:2500,f1:300,rev:.4});for(let i=0;i<4;i++)nz({t:.03+Math.random()*.2,dur:.03,vol:.2,type:'bandpass',f0:900+Math.random()*1500,q:3});break;
 case'metal':nz({dur:.3,vol:.4,type:'bandpass',f0:1300,q:5,rev:.6});osc({dur:.5,vol:.12,f0:420,rev:.6});osc({dur:.4,vol:.08,f0:633,rev:.6});break;
 case'chest':clk(0,2600,.22);for(let i=0;i<3;i++)osc({t:.08+i*.09,dur:.3,vol:.17,type:'triangle',f0:[660,880,1320][i],rev:.6});break;
 case'pick':osc({dur:.13,vol:.16,type:'triangle',f0:880,f1:1320,rev:.4});break;
 case'secret':for(let i=0;i<4;i++)osc({t:i*.08,dur:.5,vol:.14,f0:[660,990,1320,1980][i],rev:.8});break;
 case'tele':clk(0,2500,.38);clk(.07,3100,.28);break;
 case'throw':nz({dur:.26,vol:.5,type:'bandpass',f0:600,f1:1700,q:2});break;
 case'rocket':nz({dur:.6,vol:.4,type:'bandpass',f0:300,f1:1800,q:1.2,rev:.5});osc({dur:.25,vol:.4,f0:95,f1:48});break;
 case'slow':osc({dur:.9,vol:.2,f0:500,f1:60,rev:.7});break;
 case'win':for(let i=0;i<4;i++)osc({t:i*.14,dur:.6,vol:.2,type:'triangle',f0:[392,494,587,784][i],rev:.7});break;
 case'lose0':osc({dur:.25,vol:.2,type:'sawtooth',f0:180,f1:90});break;
 case'lose':for(let i=0;i<3;i++)osc({t:i*.22,dur:.7,vol:.2,type:'sawtooth',f0:[196,165,110][i],f1:[185,150,80][i],rev:.8});break;}}catch(e){}}
/* ===== suoni registrati (www/assets/audio/*.mp3, scaricati da js/caricamento.js dentro SUONI) =====
   Gli effetti arrivano in sottofondo dopo il menu, la musica all'ingresso dei livelli (quella del boss solo nei livelli col boss).
   Si decodificano una volta sola (al primo tocco, quando nasce l'AudioContext, o appena arrivano) e i buffer si riusano.
   Se un suono manca o non si decodifica, snd() usa la versione sintetizzata qui sopra (sndSyn). */
const REC={buf:{},fail:{},busy:0,started:0},VOX={};
// nome usato dal gioco -> varianti registrate (f), volume (v), voci contemporanee (lim), variazione di intonazione (pr),
// riverbero (rev), syn:1 = suona anche lo strato sintetizzato, then = suoni da aggiungere dopo [nome,ritardo,volume]
const SMAP={
 w_pistol:{f:['w_pistol'],v:.9,lim:4,rev:.12},
 w_revolver:{f:['w_revolver'],v:1,lim:3,rev:.15},
 w_smg:{f:['w_smg'],v:.7,lim:5,pr:.06,rev:.08},
 w_shotgun:{f:['w_shotgun'],v:1,lim:3,rev:.18,then:[['pump',.36,.5]]},
 w_rifle:{f:['w_rifle'],v:.85,lim:5,rev:.1},
 w_sniper:{f:['w_sniper'],v:1,lim:2,rev:.2,then:[['rel',.62,.45]]},
 w_minigun:{f:['w_minigun'],v:.55,lim:6,pr:.07,rev:.06},
 w_plasma:{f:['plasma'],v:.6,lim:3,rev:.25},
 w_rocket:{f:['rocket'],v:.75,lim:2,rev:.25},
 eshot:{f:['eshot'],v:.5,lim:4,pr:.08,rev:.15},
 esnipe:{f:['esnipe'],v:.7,lim:2,rev:.2},
 zap:{f:['zap'],v:.3,lim:3,pr:.08},
 boom:{f:['boom'],v:1,lim:3,pr:.1,rev:.3},
 ric:{f:['ric1','ric2'],v:.4,lim:3,pr:.1,syn:1},
 cover:{f:['cover1','cover2'],v:.5,lim:4,pr:.08,rev:.1},
 rel:{f:['rel'],v:.6,lim:2},
 step:{f:['step1','step2','step3'],v:.3,lim:2,pr:.06},
 hurt:{f:['hurt1','hurt2'],v:.75,lim:1,pr:.05},
 kill:{f:['kill1','kill2'],v:.5,lim:3,pr:.08,rev:.15},
 head:{f:['head'],v:.4,lim:2,pr:.05},
 crash:{f:['crash'],v:.7,lim:3,pr:.08,rev:.15},
 metal:{f:['metal'],v:.6,lim:3,pr:.06,rev:.2},
 chest:{f:['chest'],v:.6,lim:2,syn:1},
 pick:{f:['pick'],v:.45,lim:2},
 tele:{f:['tele'],v:.5,lim:2,pr:0},
 throw:{f:['throw'],v:.6,lim:3,pr:.08},
 rocket:{f:['rocket'],v:.7,lim:3,pr:.06,rev:.25},
 slow:{f:['slow'],v:.6,lim:1,pr:0},
 win:{f:['win'],v:.6,lim:1,pr:0,syn:1,voice:'v_win'},
 lose0:{f:['lose0'],v:.45,lim:1,pr:0},
 lose:{f:['v_lose'],v:.8,lim:1,pr:0,syn:1}
};
// musica registrata: durata esatta del loop (campioni a 44100 Hz) e margine prima/dopo nel file
const MREC={level:{k:'mus_level',len:2731378/44100,pad:.3,v:.85},boss:{k:'mus_boss',len:2839609/44100,pad:.3,v:.85}};
const MXF=1.6; // secondi di dissolvenza incrociata tra musica dei livelli e del boss
// dati da decodificare: ArrayBuffer scaricato (o stringa base64 dei vecchi suoni/*.js incorporati)
function recData(k){const D=window.SUONI,v=D&&D[k];return typeof v==='string'||v instanceof ArrayBuffer?v:null;}
// file audio che esistono (assets/elenco.js) anche se non ancora scaricati: niente musica sintetizzata di ripiego per loro
REC.known={};for(const k in((window.ELENCO_ASSET||{}).audio||{}))REC.known[k]=1;for(const k in(window.SUONI||{}))REC.known[k]=1;
function b64buf(s){const bin=atob(s),n=bin.length,u=new Uint8Array(n);for(let i=0;i<n;i++)u[i]=bin.charCodeAt(i);return u.buffer;}
// toglie il silenzio iniziale che alcuni decoder MP3 aggiungono (ritardo dell'encoder): gli spari partono subito
function trimLead(b){const d=b.getChannelData(0),max=Math.min(d.length,b.sampleRate*.12|0);let i=0;while(i<max&&Math.abs(d[i])<.003)i++;i=Math.max(0,i-16);if(i<32)return b;
 const o=AC.createBuffer(b.numberOfChannels,b.length-i,b.sampleRate);for(let c=0;c<b.numberOfChannels;c++)o.getChannelData(c).set(b.getChannelData(c).subarray(i));return o;}
function recDecode(k,cb){const s=recData(k);if(!s||!AC){cb(null);return;}let done=0;const fin=b=>{if(done)return;done=1;cb(b);};
 try{const p=AC.decodeAudioData(typeof s==='string'?b64buf(s):s,b=>fin(b),()=>fin(null));if(p&&p.catch)p.catch(()=>fin(null));}catch(e){fin(null);}}
// decodifica tutti gli effetti, poi la musica dei livelli e infine quella del boss (una alla volta per non sovraccaricare l'iPhone)
function recLoad(){if(REC.started||!AC)return;REC.started=1;const D=window.SUONI;if(!D)return;
 for(const k of Object.keys(D)){if(k.indexOf('mus_')===0||!recData(k))continue;recFx(k);}
 recMusic('level',()=>recMusic('boss',null));}
function recFx(k){const D=window.SUONI;REC.busy++;recDecode(k,b=>{REC.busy--;if(b){REC.buf[k]=trimLead(b);delete D[k];}else REC.fail[k]=1;});}
function recHasMus(tr){const m=MREC[tr];return !!(m&&(MU.rb[tr]||(!MU.rf[tr]&&(recData(m.k)||REC.known[m.k]))));}
const recTrack=k=>Object.keys(MREC).find(t=>MREC[t].k===k)||null;
// dal caricatore: file audio arrivato. Risolve quando è decodificato (musica) o subito (effetti, o se manca ancora l'AudioContext)
function recAdd(k,buf){if(buf==null)return Promise.resolve();window.SUONI[k]=buf;REC.known[k]=1;if(!AC||!REC.started)return Promise.resolve();
 const tr=recTrack(k);if(tr)return new Promise(res=>recMusic(tr,res));if(!REC.buf[k])recFx(k);return Promise.resolve();}
// dal caricatore: file audio mancante o rotto -> ripiego sintetizzato come prima
function recMiss(k){delete REC.known[k];const tr=recTrack(k);if(!tr){REC.fail[k]=1;return;}MU.rf[tr]=1;if(MU.track===tr&&!MU.src){if(MU.fail)mLive();else musicPrep();}}
// cambio livello: libera la musica che non serve (mai quella che sta suonando). true = liberata
function recFree(k){const tr=recTrack(k);if(!tr||MU.track===tr||MU.rbusy[tr])return false;delete MU.rb[tr];delete window.SUONI[k];return true;}
// fetch=1: se il brano esiste ma non è ancora scaricato, chiede al caricatore di scaricarlo (parte appena pronto)
function recMusic(tr,next,fetch){const m=MREC[tr];if(!m||MU.rb[tr]||MU.rf[tr]||MU.rbusy[tr]){if(next)next();return;}
 if(!recData(m.k)){if(!REC.known[m.k])MU.rf[tr]=1;else if(fetch&&typeof carAudio==='function')carAudio(m.k);if(next)next();return;}
 MU.rbusy[tr]=1;recDecode(m.k,b=>{MU.rbusy[tr]=0;
  if(b&&b.duration>=m.pad+m.len){MU.rb[tr]=b;delete window.SUONI[m.k];if(MU.track===tr&&S.mus!==0)mPlay(tr,MU.src?MXF:.8);}
  else{MU.rf[tr]=1;if(MU.track===tr&&!MU.src){if(MU.fail)mLive();else musicPrep();}}
  if(next)setTimeout(next,200);});}
// limita le voci contemporanee per lo stesso suono (spari rapidi): sfuma e ferma la più vecchia
function voxAdd(n,lim,s,g){const a=VOX[n]||(VOX[n]=[]);while(a.length>=lim){const o=a.shift();try{o.g.gain.setTargetAtTime(0,AC.currentTime,.012);o.s.stop(AC.currentTime+.08);}catch(e){}}
 const it={s,g};a.push(it);s.onended=()=>{const i=a.indexOf(it);if(i>=0)a.splice(i,1);};}
function recOne(k,vol,rate,dl,rev,n,lim){const b=REC.buf[k];if(!b)return false;const s=AC.createBufferSource(),g=AC.createGain();s.buffer=b;s.playbackRate.value=rate;g.gain.value=vol;s.connect(g);aout(g,rev);
 s.start(AC.currentTime+(dl||0));voxAdd(n,lim,s,g);return true;}
function recPlay(n,m){const ok=m.f.filter(k=>REC.buf[k]);if(!ok.length)return false;const k=ok[Math.random()*ok.length|0],pr=m.pr==null?.04:m.pr,
  rate=1+(Math.random()*2-1)*pr,vol=m.v*(1+(Math.random()*2-1)*.1);recOne(k,vol,rate,0,m.rev||0,n,m.lim||4);
 if(m.then)for(const t of m.then)recOne(t[0],t[2],rate,t[1],m.rev||0,n+'+',2);
 if(m.voice&&typeof state!=='undefined'&&state==='end')recOne(m.voice,.85,1,.25,0,'voce',1);
 return true;}
function snd(n){if(!AC||!S.snd)return;const now=AC.currentTime;if(sndLast[n]&&now-sndLast[n]<.035)return;sndLast[n]=now;
 try{const m=SMAP[n];if(m&&recPlay(n,m)){if(m.syn)sndSyn(n);return;}}catch(e){}sndSyn(n);}

/* ----- colonna sonora: brani registrati in loop (MREC); ripiego: metal/industrial sintetizzato, renderizzato una volta e poi in loop ----- */
const MU={track:null,vol:.3,buf:{},rb:{},rf:{},rbusy:{},src:null,sg:null,fail:0,step:0,next:0,timer:null,live:null,busy:0};
const hz=m=>440*Math.pow(2,(m-69)/12);let MX=null,MB=null;
const MOF={m:1,a:3,b:5,n:6,c:7,d:8,e:10,E:12};
function mCurve(k){const n=2048,c=new Float32Array(n);for(let i=0;i<n;i++)c[i]=Math.tanh(k*(i/(n-1)*2-1));return c;}
function mBusMk(X,dest){const B={},G=v=>{const g=X.createGain();g.gain.value=v;return g;},F=(ty,fr,q,gn)=>{const f=X.createBiquadFilter();f.type=ty;f.frequency.value=fr;if(q)f.Q.value=q;if(gn)f.gain.value=gn;return f;},so=window.MSOLO;
 B.out=G(.62);const lim=X.createWaveShaper();lim.curve=mCurve(1.5);B.out.connect(lim);lim.connect(dest);
 B.nb=X.createBuffer(1,X.sampleRate*2,X.sampleRate);{const d=B.nb.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;}
 const len=X.sampleRate*1.2|0,ib=X.createBuffer(2,len,X.sampleRate);for(let c=0;c<2;c++){const d=ib.getChannelData(c);let lp=0;for(let i=0;i<len;i++){const t=i/len;lp+=((Math.random()*2-1)-lp)*.5;d[i]=lp*Math.pow(1-t,3)*(i<200?i/200:1);}}
 const cv=X.createConvolver();cv.buffer=ib;B.rev=G(.5);B.rev.connect(cv);cv.connect(B.out);
 const mg=X.createChannelMerger(2),gt=G(so&&so!=='g'?0:1);mg.connect(gt);gt.connect(B.out);const gr=G(.1);gt.connect(gr);gr.connect(B.rev);
 const side=ch=>{const i=G(2.1),ws=X.createWaveShaper(),o=G(.33);ws.curve=mCurve(3);const a=F('highpass',95),b=F('peaking',1150,.9,5),c=F('lowpass',4300,.6);i.connect(ws);ws.connect(a);a.connect(b);b.connect(c);c.connect(o);o.connect(mg,0,ch);return i;};B.gL=side(0);B.gR=side(1);
 B.bass=G(1.8);const bw=X.createWaveShaper();bw.curve=mCurve(2);const bo=G(so&&so!=='b'?0:.27);B.bass.connect(bw);bw.connect(bo);bo.connect(B.out);
 B.dr=G(so&&so!=='d'?0:1.12);B.dr.connect(B.out);B.drv=G(.3);B.drv.connect(B.rev);
 const sy=G(so&&so!=='s'?0:1.7);sy.connect(B.out);B.ld=G(1);B.ld.connect(sy);const lr=G(.3);B.ld.connect(lr);lr.connect(B.rev);
 const dl=X.createDelay(1),ds=G(.26),fb=G(.34),df=F('lowpass',2600);B.dl=dl;B.ld.connect(ds);ds.connect(dl);dl.connect(df);df.connect(fb);fb.connect(dl);df.connect(sy);
 B.ar=G(1);B.ar.connect(sy);const ar=G(.4);B.ar.connect(ar);ar.connect(B.rev);return B;}
function mEnv(g,t,a,d,v,r){g.gain.setValueAtTime(.0001,t);g.gain.linearRampToValueAtTime(v,t+a);g.gain.setValueAtTime(v,t+Math.max(a,d));g.gain.exponentialRampToValueAtTime(.0001,t+d+r);}
function mOsc(type,m,det,t,end,to){const s=MX.createOscillator();s.type=type;s.frequency.value=hz(m);s.detune.value=det;s.connect(to);s.start(t);s.stop(end);return s;}
function mGtr(t,dur,m,pm,v){const X=MX;for(let k=0;k<2;k++){const g=X.createGain(),f=X.createBiquadFilter(),tt=t+k*.005,det=k?7:-7,end=tt+dur+.06;f.type='lowpass';
  if(pm){f.frequency.setValueAtTime(1800,tt);f.frequency.exponentialRampToValueAtTime(360,tt+dur);g.gain.setValueAtTime(.0001,tt);g.gain.linearRampToValueAtTime(v,tt+.003);g.gain.exponentialRampToValueAtTime(.0001,tt+dur);}
  else{f.frequency.value=5200;mEnv(g,tt,.004,dur,v,.03);}
  mOsc('sawtooth',m,det,tt,end,f);mOsc('sawtooth',m+7,det*1.3,tt,end,f);if(!pm)mOsc('sawtooth',m+12,-det,tt,end,f);f.connect(g);g.connect(k?MB.gR:MB.gL);}}
function mBass(t,dur,m,v){const X=MX,g=X.createGain(),f=X.createBiquadFilter(),e=t+dur+.06;f.type='lowpass';f.Q.value=2;f.frequency.setValueAtTime(950,t);f.frequency.exponentialRampToValueAtTime(240,t+Math.min(dur,.16));mEnv(g,t,.004,dur,v,.03);mOsc('sawtooth',m,0,t,e,f);mOsc('square',m+12,4,t,e,f);f.connect(g);g.connect(MB.bass);}
function mNz(t,dur,v,hp,rev){const X=MX,s=X.createBufferSource();s.buffer=MB.nb;const f=X.createBiquadFilter();f.type='highpass';f.frequency.value=hp;const g=X.createGain();g.gain.setValueAtTime(v,t);g.gain.exponentialRampToValueAtTime(.001,t+dur);s.connect(f);f.connect(g);g.connect(MB.dr);if(rev)g.connect(MB.drv);s.start(t,Math.random());s.stop(t+dur+.02);}
function mKick(t,v){const X=MX,o=X.createOscillator(),g=X.createGain();o.frequency.setValueAtTime(175,t);o.frequency.exponentialRampToValueAtTime(46,t+.085);g.gain.setValueAtTime(v,t);g.gain.exponentialRampToValueAtTime(.001,t+.2);o.connect(g);g.connect(MB.dr);o.start(t);o.stop(t+.22);mNz(t,.018,v*.45,3200);}
function mSnare(t,v){mNz(t,.2,v,950,1);const X=MX,o=X.createOscillator(),g=X.createGain();o.type='triangle';o.frequency.setValueAtTime(230,t);o.frequency.exponentialRampToValueAtTime(150,t+.07);g.gain.setValueAtTime(v*.8,t);g.gain.exponentialRampToValueAtTime(.001,t+.11);o.connect(g);g.connect(MB.dr);o.start(t);o.stop(t+.13);}
function mTom(t,f0,v){const X=MX,o=X.createOscillator(),g=X.createGain();o.frequency.setValueAtTime(f0,t);o.frequency.exponentialRampToValueAtTime(f0*.55,t+.2);g.gain.setValueAtTime(v,t);g.gain.exponentialRampToValueAtTime(.001,t+.26);o.connect(g);g.connect(MB.dr);g.connect(MB.drv);o.start(t);o.stop(t+.28);}
function mLead(t,dur,m,v){const X=MX,g=X.createGain(),f=X.createBiquadFilter(),e=t+dur+.16,lf=X.createOscillator(),lg=X.createGain(),q=X.createGain();f.type='lowpass';f.Q.value=2.5;f.frequency.setValueAtTime(900,t);f.frequency.exponentialRampToValueAtTime(3600,t+.05);mEnv(g,t,.012,dur,v,.12);
 lf.frequency.value=5.8;lg.gain.setValueAtTime(0,t);lg.gain.setValueAtTime(0,t+.16);lg.gain.linearRampToValueAtTime(16,t+.4);lf.connect(lg);lf.start(t);lf.stop(e);for(const d of[-11,11])lg.connect(mOsc('sawtooth',m,d,t,e,f).detune);q.gain.value=.4;mOsc('square',m-12,0,t,e,q);q.connect(f);f.connect(g);g.connect(MB.ld);}
function mArp(t,dur,m,v){const X=MX,g=X.createGain(),f=X.createBiquadFilter();f.type='lowpass';f.Q.value=3;f.frequency.setValueAtTime(4200,t);f.frequency.exponentialRampToValueAtTime(700,t+dur);g.gain.setValueAtTime(.0001,t);g.gain.linearRampToValueAtTime(v,t+.004);g.gain.exponentialRampToValueAtTime(.0001,t+dur+.05);mOsc('square',m,0,t,t+dur+.08,f);mOsc('sawtooth',m,9,t,t+dur+.08,f);f.connect(g);g.connect(MB.ar);}
function mPad(t,dur,notes,v,atk){const X=MX,g=X.createGain(),f=X.createBiquadFilter(),e=t+dur+.3;f.type='lowpass';f.frequency.value=2300;mEnv(g,t,atk,dur,v,.22);for(const m of notes)for(const d of[-9,9])mOsc('sawtooth',m,d,t,e,f);f.connect(g);g.connect(MB.ar);}
function mRise(t,dur,v){const X=MX,s=X.createBufferSource(),f=X.createBiquadFilter(),g=X.createGain();s.buffer=MB.nb;s.loop=true;f.type='bandpass';f.Q.value=1.2;f.frequency.setValueAtTime(350,t);f.frequency.exponentialRampToValueAtTime(7000,t+dur);g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(v,t+dur*.95);g.gain.linearRampToValueAtTime(.0001,t+dur);s.connect(f);f.connect(g);g.connect(MB.dr);g.connect(MB.drv);s.start(t);s.stop(t+dur+.02);}
const rp4=(a)=>a.concat(a);
const TRK={
 level:{bpm:150,bars:16,root:40,
  riff:rp4(['0000a-00b-00a-0.','0000a-00b-00n-m-','0000a-00b-00a-0.','0000a-00b-c-d-e-']).concat(['d--d--d--d--d-d-','e--e--e--e--e-e-','E--E--E--E--E-E-','E--E--E-c-c-b-b-','b--b--b--b--b-b-','c--c--c--c--c-c-','d--d--d--d--d-d-','e-e-e-e-eeeeeeee']),
  kick:rp4(['x.xx..xxx.xx..x.','x.xx..xxx.xxx.x.','x.xx..xxx.xx..x.','x.xx..xxx.x.x.x.']).concat(['x..x..x..x..x.x.','x..x..x..x..x.x.','x..x..x..x..x.x.','x..x..x.x.x.xoxo','xoxoxoxoxoxoxoxo','xoxoxoxoxoxoxoxo','xoxoxoxoxoxoxoxo','x.x.x.x.xoxoxoxo']),
  snr:['....x.......x...','....x.......x...','....x.......x...','....x.......x.x.','....x.......x...','....x.......x...','....x.......x...','....x.......x...','....x.......x...','....x.......x...','....x.......x...','....x.......x...','....x.......x...','....x.......x...','....x.......x...','....x...12345678'],
  hat:'eeeeeeeeqqqqqqqq',cr:[0,4,8,10,12,14],tom:{7:'.............123',11:'............1234'},rise:{7:[8,8],15:[0,16]},
  ld:{4:[[0,76,3],[3,79,3],[6,81,2],[8,83,6],[14,81,2]],5:[[0,79,6],[6,76,2],[8,79,4],[12,82,2],[14,77,2]],6:[[0,76,3],[3,79,3],[6,81,2],[8,83,4],[12,86,4]],7:[[0,88,6],[6,86,2],[8,81,2],[10,83,2],[12,84,2],[14,86,2]],
   8:[[0,84,8],[8,83,4],[12,79,4]],9:[[0,86,8],[8,81,4],[12,78,4]],10:[[0,88,12],[12,86,2],[14,83,2]],11:[[0,91,8],[8,88,4],[12,86,4]],12:[[0,81,6],[6,84,2],[8,88,8]],13:[[0,87,6],[6,83,2],[8,90,8]],14:[[0,91,8],[8,88,4],[12,84,4]],15:[[0,86,4],[4,90,4],[8,93,8]]},
  ar:{8:[72,76,79,84],9:[74,78,81,86],10:[76,79,83,88],11:[76,79,83,88],12:[69,72,76,81],13:[71,75,78,83],14:[72,76,79,84],15:[74,78,81,86]},pad:1},
 boss:{bpm:172,bars:16,root:38,
  riff:rp4(['00m000a-00m0n-b-','00m000a-00m0d-c-','00m000a-00m0n-b-','00m000a-n-b-a-m-']).concat(['0---------0-m---','d---------d-c---','n---------n-b---','c-------c-c-cccc','0a0a0b0b0c0c0d0d','0d0d0e0e0E0E0e0e','0a0b0c0d0e0E0e0d','E-E-E-E-EEEEEEEE']),
  kick:['xoxoxoxoxoxoxoxo','xoxoxoxoxoxoxoxo','xoxoxoxoxoxoxoxo','xoxoxoxox.x.x.x.','x...x...x...x.oo','x...x...x...x.oo','x...x...x...x.oo','x...x...x.x.x.x.','x.........x.x...','x.........x.xoxo','x.........x.x...','x.......x.x.xoxo','xoxoxoxoxoxoxoxo','xoxoxoxoxoxoxoxo','xoxoxoxoxoxoxoxo','x.x.x.x.xoxoxoxo'],
  snr:['....x.......x...','....x.......x...','....x.......x...','....x...........','..x...x...x...x.','..x...x...x...x.','..x...x...x...x.','..x...x.........','........x.......','........x.......','........x.......','........x.x.3579','....x.......x...','....x.......x...','..x...x...x...x.','....x...12345678'],
  hat:'eeeeeeeeqqqqeeee',cr:[0,2,4,6,8,9,10,11,12,14],tom:{3:'........1.2.3.4.',7:'........1.2.3.4.'},rise:{11:[8,8],15:[0,16]},
  ld:{4:[[0,74,6],[6,75,2],[8,77,8]],5:[[0,80,4],[4,79,4],[8,82,4],[12,81,4]],6:[[0,86,6],[6,87,2],[8,89,8]],7:[[0,92,4],[4,91,4],[8,89,4],[12,87,4]],15:[[0,86,8],[8,89,4],[12,93,4]]},
  sir:{8:[86,80],9:[89,82],10:[87,80],11:[88,81]},run:[12,13,14],stab:{0:[62,65,69],2:[62,65,69],4:[62,65,69],6:[62,65,69]},padc:{8:[62,65,69],9:[58,62,65],10:[56,59,62],11:[57,61,64]}}};
const MARP=[0,1,2,3,2,1,2,3,0,1,2,3,2,1,2,3],MTOM=[0,230,180,140,105];
function mStep(tr,n,t){const T=TRK[tr],sd=60/T.bpm/4,st=n%16,bar=(n/16|0)%T.bars,rf=T.riff[bar],c=rf[st];
 if(c!=='-'&&c!=='.'){let len=1;while(st+len<16&&rf[st+len]==='-')len++;const pm=c==='0',m=T.root+(pm?0:MOF[c]);mGtr(t,pm?sd*.82:sd*(len-.14),m,pm,pm?.55:.6);mBass(t,pm?sd*.7:sd*(len-.2),m-12,pm?.5:.6);
  if(!pm&&T.run&&T.run.includes(bar))mLead(t,sd*1.7,m+36,.075);}
 const k=T.kick[bar][st],s=T.snr[bar][st];if(k==='x')mKick(t,.95);else if(k==='o')mKick(t,.6);if(s==='x')mSnare(t,.5);else if(s>='1'&&s<='9')mSnare(t,.12+.045*(+s));
 const h=T.hat[bar];if(h==='q'){if(st%4===0)mNz(t,.17,.1,6500);else if(st%2===0)mNz(t,.035,.07,7500);}else if(st%2===0)mNz(t,.035,st%4===0?.1:.065,7500);
 if(st===0&&T.cr.includes(bar))mNz(t,1.3,.2,3800,1);const tm=T.tom&&T.tom[bar];if(tm&&tm[st]!=='.')mTom(t,MTOM[+tm[st]],.6);
 const rs=T.rise&&T.rise[bar];if(rs&&rs[0]===st)mRise(t,sd*rs[1],.2);
 const ld=T.ld&&T.ld[bar];if(ld)for(const q of ld)if(q[0]===st)mLead(t,sd*q[2]*.94,q[1],.085);
 const ar=T.ar&&T.ar[bar];if(ar){mArp(t,sd*.9,ar[MARP[st]],.05);if(st===0&&T.pad)mPad(t,sd*15.4,[ar[0]-12,ar[1]-12,ar[2]-12],.016,.05);}
 const si=T.sir&&T.sir[bar];if(si&&st%2===0)mArp(t,sd*1.8,si[(st/2)%2],.075);
 const sb=T.stab&&T.stab[bar];if(sb&&st===0)mPad(t,.28,sb,.03,.005);const pc=T.padc&&T.padc[bar];if(pc&&st===0)mPad(t,sd*15.4,pc,.022,.03);}
function mRender(tr,cb){const OC=window.OfflineAudioContext||window.webkitOfflineAudioContext;if(!OC)return cb(null);const T=TRK[tr],sd=60/T.bpm/4,sr=44100,N=T.bars*16,loop=Math.round(N*sd*sr),tail=Math.round(2.2*sr);let X,done=0;
 const fin=r=>{if(done)return;done=1;try{const out=X.createBuffer(2,loop,sr);let pk=0;for(let c=0;c<2;c++){const a=r.getChannelData(c),o=out.getChannelData(c);for(let i=0;i<loop;i++){const v=a[i]+(i<tail?a[loop+i]:0);o[i]=v;const w=v<0?-v:v;if(w>pk)pk=w;}}
   const k=pk>0?.9/pk:1;MU.k=k;for(let c=0;c<2;c++){const o=out.getChannelData(c);for(let i=0;i<loop;i++)o[i]*=k;}cb(out);}catch(e){cb(null);}};
 try{X=new OC(2,loop+tail,sr);const pX=MX,pB=MB;MX=X;MB=mBusMk(X,X.destination);MB.dl.delayTime.value=sd*3;try{for(let n=0;n<N;n++)mStep(tr,n,n*sd);}finally{MX=pX;MB=pB;}
  X.oncomplete=e=>fin(e.renderedBuffer);const p=X.startRendering();if(p&&p.then)p.then(fin,()=>{if(!done){done=1;cb(null);}});}catch(e){if(!done){done=1;cb(null);}}}
function musicPrep(){if(MU.busy||MU.fail||window.NOMUS)return;const need=t=>!MU.buf[t]&&!recHasMus(t),tr=need('level')?'level':need('boss')?'boss':null;if(!tr)return;MU.busy=1;mRender(tr,b=>{MU.busy=0;if(!b){MU.fail=1;if(MU.track&&!MU.src)mLive();return;}MU.buf[tr]=b;if(MU.track===tr&&AC&&!MU.src)mPlay(tr);setTimeout(musicPrep,300);});}
// ferma la traccia attuale con una dissolvenza di f secondi
function mCut(f){if(!MU.src)return;const s=MU.src,g=MU.sg,t=AC.currentTime;f=f||.09;try{g.gain.cancelScheduledValues(t);g.gain.setValueAtTime(g.gain.value,t);g.gain.linearRampToValueAtTime(0,t+f);s.stop(t+f+.05);}catch(e){}MU.src=MU.sg=null;}
// suona una traccia in loop; xf = secondi di dissolvenza incrociata con quella che sta suonando
// (le tracce registrate usano loopStart/loopEnd: nel file c'è un margine prima e dopo il ciclo)
function mPlay(tr,xf){const rb=MU.rb[tr],b=rb||MU.buf[tr];if(!b||S.mus===0){mCut();return 0;}mCut(xf||.09);const s=AC.createBufferSource(),g=AC.createGain(),t=AC.currentTime+.03,m=rb?MREC[tr]:null,v=m?m.v:1;let off=0;s.buffer=b;s.loop=true;
 if(m){s.loopStart=m.pad;s.loopEnd=m.pad+m.len;off=m.pad;}
 if(xf){g.gain.setValueAtTime(.0001,t);g.gain.linearRampToValueAtTime(v,t+xf);}else g.gain.value=v;
 s.connect(g);g.connect(MUS);s.start(t,off);MU.src=s;MU.sg=g;return 1;}
function mLive(){if(!AC||MU.timer)return;MU.live=mBusMk(AC,MUS);MU.step=0;MU.next=AC.currentTime+.15;MU.timer=setInterval(()=>{if(!MU.track||MU.rb[MU.track]||state!=='play'||S.mus===0)return;const T=TRK[MU.track],sd=60/T.bpm/4,until=AC.currentTime+.3;if(MU.next<AC.currentTime)MU.next=AC.currentTime+.05;MX=AC;MB=MU.live;MB.dl.delayTime.value=sd*3;let gd=0;while(MU.next<until&&gd++<64){mStep(MU.track,MU.step,MU.next);MU.next+=sd;MU.step++;}},60);}
function musicStart(tr){if(!AC)return;if(MU.track===tr)return;const prev=MU.track;MU.track=tr;MU.step=0;MU.next=AC.currentTime+.15;const g=MUS.gain,t=AC.currentTime;g.cancelScheduledValues(t);g.setValueAtTime(g.value,t);g.linearRampToValueAtTime(S.mus===0?0:MU.vol,t+.4);
 const xf=prev&&MU.src?MXF:0;
 if(recHasMus(tr)){if(MU.rb[tr])mPlay(tr,xf);else recMusic(tr,null,1);return;}// ancora in decodifica: parte appena pronta
 if(MU.fail)mLive();else if(!mPlay(tr,xf))musicPrep();}
function musicStop(){if(!AC||!MU.track)return;MU.track=null;const g=MUS.gain,t=AC.currentTime;g.cancelScheduledValues(t);g.setValueAtTime(g.value,t);g.linearRampToValueAtTime(0,t+.5);mCut(.5);}
function musicVol(){if(!AC)return;const t=AC.currentTime;MUS.gain.cancelScheduledValues(t);MUS.gain.setValueAtTime(S.mus===0||!MU.track?0:MU.vol,t);if(MU.track&&S.mus!==0&&!MU.src&&(MU.rb[MU.track]||!MU.fail))mPlay(MU.track,.5);if(S.mus===0)mCut();}
