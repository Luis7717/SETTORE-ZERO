'use strict';
/* ===== Bauli nelle corse con le schivate =====
   Nelle tappe di corsa (st.run, corridoi di corridoi.js) compaiono 1-3 bauli con le monete, tra un pericolo e l'altro.
   Stanno nell'angolo ESTERNO delle curve, contro il muro di fondo, o a lato della porta d'uscita: così si vedono per
   tutto il rettilineo che ci porta (i rettilinei sono corti e un baule a lato si vedrebbe solo all'ultimo) e restano
   lontani dal percorso, che in curva taglia sul lato interno e alla porta passa nel mezzo.
   Si aprono TOCCANDOLI mentre corri: fire() non spara durante il movimento (G.mv), quindi il "colpo al baule" è
   gestito qui con un ascoltatore proprio sul tocco.
   - posizioni fisse per livello: generatore seeded proprio, che non consuma i numeri casuali del livello
     (pericoli, durate e resto del livello restano identici)
   - si mette un baule solo dove c'è abbastanza rettilineo libero da schivate per toccarlo con calma
   - il tocco sullo slider delle schivate o sul pannello della serratura (qualsiasi G.qte attivo) non li tocca;
     niente bauli colpibili mentre si guarda indietro (m.lb) o durante le scene (G.cine)
   - sono "locked": spari ed esplosioni non li aprono (anche quando il corridoio resta visibile dietro la porta)
   - geometrie e materiali riusati (mkChest usa GEO/M condivisi; monete: una sola geometria), nessuna luce nuova */
const BC_OUT=1.55,           // distanza del baule dal centro della curva, in avanti e verso l'esterno (muri a 2.6, pilone d'angolo da 2.19)
 BC_TAPMIN=3,                // metri di rettilineo, senza slider sullo schermo, in cui il baule si vede e si può toccare
 BC_TAP_R=80,BC_FAR=17,BC_GOLD_P=.12,BC_MAX=3,
 BC_CR=16,BC_CR_GOLD=45;     // crediti base (bauli delle sale: 25 e 60), poi x(1+.15*L)
const BC={g:null,coins:[],fl:[],hit:[]},BC_V=new V3(),BC_V2=new V3(),BC_RC=new THREE.Raycaster();
let BC_COIN=null;

/* curve del corridoio ricavate dal percorso originale di buildRun: [inizio, (entrata, uscita) per ogni curva, fine];
   entrata = centro - f*1.25, uscita = centro + f'*1.25 */
function BC_corners(P){const D=[0];for(let i=1;i<P.length;i++)D.push(D[i-1]+Math.hypot(P[i][0]-P[i-1][0],P[i][1]-P[i-1][1]));const out=[];if((P.length-2)%2)return out;
 for(let i=1;i+1<P.length-1;i+=2){const A=P[i-1],I=P[i],O=P[i+1],N=P[i+2];let fx=I[0]-A[0],fz=I[1]-A[1],l=Math.hypot(fx,fz);if(l<1e-3)continue;fx/=l;fz/=l;
  let gx=N[0]-O[0],gz=N[1]-O[1];l=Math.hypot(gx,gz);if(l<1e-3)continue;gx/=l;gz/=l;const rx=-fz,rz=fx,s=Math.sign(gx*rx+gz*rz);if(!s)continue;
  out.push({cx:I[0]+fx*1.25,cz:I[1]+fz*1.25,fx,fz,rx,rz,s,sIn:D[i],sOut:D[i+1]});}return out;}

/* metri (tra a e b sul percorso) in cui il baule si vede e nessuno slider è sullo schermo: il tratto libero più lungo.
   Schivate: lo slider compare a 6.4 m dal pericolo e con il rallentatore si completa entro circa 2 m (resta al massimo fino a 1.9 m); serratura: il giocatore si ferma davanti al pannello finché non lo colpisce.
   Fughe: i primi metri si fanno guardando indietro, poi la visuale impiega ancora un po' a girarsi in avanti. */
function BC_freeLen(st,L,a,b){const esc=st.rk==='e'||st.rk==='m',spd=(esc?5.5:5)+Math.min(1.5,L*.035);a=Math.max(a,esc?spd*2.3:1.5);if(b<=a)return 0;
 const cut=st.haz.map(h=>h.kind==='lock'?[h.sd-.4,h.sd+1]:[h.sd-6.4,h.sd-4.4]).sort((p,q)=>p[0]-q[0]);let best=0;
 for(const[q0,q1]of cut){if(q1<=a)continue;if(q0>=b)break;best=Math.max(best,q0-a);a=Math.max(a,q1);}return Math.max(best,b-a);}

/* scatole (già nel mondo del corridoio) di casse, pericoli e porte: il baule non deve toccarle */
function BC_obst(st){const out=[],rg=st.rg;rg.updateMatrixWorld(true);for(let i=1;i<rg.children.length;i++){const b=new THREE.Box3().setFromObject(rg.children[i]);if(!b.isEmpty())out.push(b);}return out;}

/* posti possibili: l'angolo esterno di ogni curva (si vede per tutto il rettilineo che porta alla curva) e l'angolo
   accanto alla porta d'uscita (si vede per tutto l'ultimo rettilineo); ognuno con il tratto in cui si può toccare */
function BC_spots(st){const P=st.inP,C=BC_corners(P),out=[];
 C.forEach((c,k)=>{const a=BC_OUT+rr(-.05,.05),dx=-c.fx+.6*c.s*c.rx,dz=-c.fz+.6*c.s*c.rz;/* il davanti (serratura) guarda chi arriva, un po' verso l'interno della curva */
  out.push({x:c.cx+c.fx*a-c.s*c.rx*a,z:c.cz+c.fz*a-c.s*c.rz*a,y:runY(st,c.sIn+.9),ry:Math.atan2(dx,dz),a:k?C[k-1].sOut-.5:0,b:c.sIn-1.5,s:c.sIn,r:.55});});
 const n=P.length,A=P[n-2],E=P[n-1];let fx=E[0]-A[0],fz=E[1]-A[1];const l=Math.hypot(fx,fz);if(l>1e-3){fx/=l;fz/=l;const tot=pathLen(P),lh=st.haz.filter(h=>h.kind!=='lock').pop(),sd=st.rk==='m'?-1:lh&&lh.sd>(C.length?C[C.length-1].sOut:0)?lh.side:Math.random()<.5?1:-1,f=1.9-.9,w=1.85;
  /* lato: con Marsh (che corre sul lato +1.4) quello opposto; altrimenti il lato dell'ultimo pericolo del rettilineo, verso cui la visuale si gira */
  /* porta d'uscita: il muro è 1.9 m oltre la fine del percorso; il baule sta a 0.9 m dal muro, a lato dell'apertura (larga ±1.45) */
  out.push({x:E[0]+fx*f-sd*fz*w,z:E[1]+fz*f+sd*fx*w,y:runY(st,tot),ry:Math.atan2(-fx,-fz),a:C.length?C[C.length-1].sOut-.5:0,b:tot-3.5,s:tot,r:.45});}
 return out;}

function BC_place(st,L){st.bc=[];const obs=BC_obst(st),cb=new THREE.Box3(),cand=BC_spots(st).filter(p=>BC_freeLen(st,L,p.a,p.b)>=BC_TAPMIN);
 for(let i=cand.length-1;i>0;i--){const j=Math.random()*(i+1)|0;[cand[i],cand[j]]=[cand[j],cand[i]];}
 const n=Math.min(cand.length,BC_MAX,2+(Math.random()<.35?1:0));
 for(const p of cand){if(st.bc.length>=n)break;cb.min.set(p.x-p.r,p.y+.05,p.z-p.r);cb.max.set(p.x+p.r,p.y+.9,p.z+p.r);if(obs.some(b=>b.intersectsBox(cb)))continue;
  const ch=mkChest(st,p.x,p.z,p.ry+rr(-.1,.1),Math.random()<BC_GOLD_P,false);ch.mesh.position.y=p.y;ch.cp.set(p.x,p.y+.3,p.z);ch.locked=true;ch.bc=1;ch.s=p.s;ch.fy=p.y;st.bc.push(ch);obs.push(cb.clone());}
 st.bc.sort((p,q)=>p.s-q.s);}

/* costruzione: dopo buildRun (quello valido, ridefinito in corridoi.js), con un seme proprio per livello e tappa */
const BC_buildRun0=buildRun;
buildRun=function(st,L){BC_buildRun0(st,L);try{seeded(L*104729+st.i*7907+31,()=>BC_place(st,L));}catch(err){console.warn('bauli corsa',err);st.bc=[];}};

/* visibilità dal punto di vista (niente bauli "attraverso" i muri in curva) */
function BC_los(c){BC_V.copy(c.cp);BC_V.y+=.15;BC_V2.subVectors(BC_V,cam.position);const d=BC_V2.length();if(d<.3)return true;BC_RC.set(cam.position,BC_V2.divideScalar(d));BC_RC.far=d;
 const hs=BC_RC.intersectObject(world,true);for(const h of hs){if(h.object.userData.prop===c)return true;if(h.object.material&&h.object.material.visible===false)continue;return h.distance>d-.5;}return true;}

function BC_canTap(){const m=G&&G.mv;return state==='play'&&!!m&&m.kind==='run'&&!G.qte&&!G.cine&&!(m.lb>0);}

/* tocco: ascoltatore in "capture", quindi gira PRIMA di comandi.js (che con la serratura chiude il QTE nello stesso tocco) */
function BC_tap(e){if(!G||!BC_canTap())return;const t=e.target;if(!t||(t.id!=='touch'&&t!==hud))return;/* pulsanti, slider, pausa: niente */
 const st=G.stages[G.si];if(!st||!st.bc||!st.bc.length)return;let best=null,bd=1e9;
 for(const c of st.bc){if(c.dead)continue;const dist=c.cp.distanceTo(cam.position);if(dist>BC_FAR)continue;const q=proj2(BC_V.copy(c.cp).setY(c.cp.y+.05));if(!q)continue;
  const d=Math.min(Math.hypot(e.clientX-q[0],e.clientY-q[1]),Math.hypot(e.clientX-q[0],e.clientY-58-q[1]));if(d<BC_TAP_R+clamp(300/dist,0,60)&&d<bd&&BC_los(c)){bd=d;best=c;}}
 if(best)BC_open(best);}
hud.addEventListener('pointerdown',BC_tap,true);

function BC_open(c){c.dead=true;c.open=1;snd('chest');snd('w_'+cw().t);G.kick=1;G.mflash=.06;G.idle=0;
 if(G.muz){const mz=G.muz.getWorldPosition(new V3());tracer(mz.lerp(c.cp,Math.min(.5,1.6/Math.max(.1,mz.distanceTo(c.cp)))),c.cp.clone(),G.wr>=2?M.trR[G.wr]:undefined);}
 BC_V.copy(c.cp);BC_V.y+=.3;glow(BC_V,c.gold?2.6:1.9,c.gold?0xffd040:0xfff0c0,.45,2);bits(BC_V,4,M.spark,2.5,.03,.3);
 const cr=Math.round((c.gold?BC_CR_GOLD:BC_CR)*(1+.15*G.L)*rr(.85,1.2)*(1+.1*pk('cr')));G.earn+=cr;
 BC_coins(c,c.gold?18:10);BC.fl.push({p:c.cp.clone().setY(c.cp.y+.7),txt:'+'+cr+' ◈',life:1.3,ml:1.3,gold:c.gold});
 const q=proj2(BC_V.copy(c.cp));if(q)BC.hit.push({x:q[0],y:q[1],life:.35});
 toast((c.gold?'★ ':'')+'<span style="color:#ffd65a">+'+cr+' ◈</span>',1500);}

/* monete: saltano fuori dal baule, rimbalzano sul pavimento e poi volano verso il giocatore */
function BC_coins(c,n){if(!BC_COIN){BC_COIN=new THREE.CylinderGeometry(.07,.07,.016,12);}
 for(let i=0;i<n;i++){const m=new THREE.Mesh(BC_COIN,M.gold);m.castShadow=false;m.position.set(c.cp.x+rr(-.2,.2),c.cp.y+.25,c.cp.z+rr(-.2,.2));m.rotation.set(rr(0,6),rr(0,6),rr(0,6));fxG.add(m);
  BC.coins.push({m,v:new V3(rr(-1.3,1.3),rr(2.6,4.4),rr(-1.3,1.3)),t:0,fly:rr(.5,.75),fy:c.fy+.02,sp:rr(8,16)});}}

function BC_tick(dt){if(!G)return;if(BC.g!==G){for(const k of BC.coins)if(k.m.parent)k.m.parent.remove(k.m);BC.g=G;BC.coins=[];BC.fl=[];BC.hit=[];}
 for(let i=BC.coins.length-1;i>=0;i--){const k=BC.coins[i],m=k.m;k.t+=dt;m.rotation.x+=k.sp*dt;m.rotation.y+=k.sp*.6*dt;
  if(k.t<k.fly){m.position.addScaledVector(k.v,dt);k.v.y-=9.8*dt;if(m.position.y<k.fy){m.position.y=k.fy;k.v.set(k.v.x*.5,-k.v.y*.35,k.v.z*.5);}}
  else{BC_V.set(0,-.35,-.5).applyQuaternion(cam.quaternion).add(cam.position);m.position.lerp(BC_V,Math.min(1,dt*9));m.scale.multiplyScalar(Math.pow(.25,dt));
   if(m.position.distanceTo(BC_V)<.25||k.t>k.fly+1){if(m.parent)m.parent.remove(m);BC.coins.splice(i,1);if(i%4===0)snd('pick');}}}
 for(let i=BC.fl.length-1;i>=0;i--){BC.fl[i].life-=dt;if(BC.fl[i].life<=0)BC.fl.splice(i,1);}
 for(let i=BC.hit.length-1;i>=0;i--){BC.hit[i].life-=dt;if(BC.hit[i].life<=0)BC.hit.splice(i,1);}
 /* visibilità per l'anello di richiamo: controllata ogni 0.12 s per baule (raggio sul mondo: costa poco ma non a ogni fotogramma) */
 const st=G.stages[G.si];if(!(G.mv&&G.mv.kind==='run'&&st&&st.bc))return;for(const c of st.bc){if(c.dead){c.vis=0;continue;}c.vt=(c.vt||0)-dt;if(c.vt<=0){c.vt=.12;c.vis=c.cp.distanceTo(cam.position)<BC_FAR&&BC_los(c)?1:0;}}}
const BC_update0=update;
update=function(dt){BC_update0(dt);try{BC_tick(dt*(G&&G.sl||1));}catch(err){console.warn('bauli corsa',err);}};

/* disegno sul livello HUD (drawOv durante le corse si ferma presto): anello che invita a toccare, lampo del colpo, "+crediti" */
const BC_drawOv0=drawOv;
drawOv=function(){BC_drawOv0();try{BC_draw();}catch(err){console.warn('bauli corsa',err);}};
function BC_draw(){if(!G||!G.mv||G.mv.kind!=='run')return;const g=og,st=G.stages[G.si];g.setTransform(ODPR,0,0,ODPR,0,0);g.textAlign='center';
 if(st&&st.bc&&BC_canTap()){const p=.5+.5*Math.sin(G.t*7);for(const c of st.bc){if(c.dead||!c.vis)continue;const q=proj2(BC_V.copy(c.cp).setY(c.cp.y+.05));if(!q)continue;const d=c.cp.distanceTo(cam.position),r=clamp(320/d,16,46)*(1+.12*p);
   g.lineWidth=4;g.strokeStyle='rgba(0,0,0,.4)';g.beginPath();g.arc(q[0],q[1],r,0,7);g.stroke();g.lineWidth=2;g.strokeStyle=c.gold?'rgba(255,200,64,'+(.6+.4*p)+')':'rgba(255,214,90,'+(.45+.4*p)+')';g.beginPath();g.arc(q[0],q[1],r,0,7);g.stroke();
   if(d<11){g.font='800 12px '+HFONT;g.lineWidth=3;g.strokeStyle='rgba(0,0,0,.7)';g.strokeText('TOCCA',q[0],q[1]-r-6);g.fillStyle='#ffd65a';g.fillText('TOCCA',q[0],q[1]-r-6);}}}
 for(const h of BC.hit){const k=1-h.life/.35,r=18+30*k;g.globalAlpha=1-k;g.lineWidth=3;g.strokeStyle='#ffd65a';g.beginPath();g.arc(h.x,h.y,r,0,7);for(const[a,b]of[[1,0],[-1,0],[0,1],[0,-1]]){g.moveTo(h.x+a*(r+3),h.y+b*(r+3));g.lineTo(h.x+a*(r+10),h.y+b*(r+10));}g.stroke();}
 g.font='900 18px '+HFONT;for(const f of BC.fl){const q=proj2(BC_V.copy(f.p));if(!q)continue;const k=f.life/f.ml,y=q[1]-(1-k)*46;g.globalAlpha=Math.min(1,k*2.5);g.fillStyle='#000';g.fillText(f.txt,q[0]+1,y+1);g.fillStyle=f.gold?'#ffc840':'#ffd65a';g.fillText(f.txt,q[0],y);}
 g.globalAlpha=1;}
