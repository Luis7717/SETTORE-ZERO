'use strict';
/* =====================================================================
   SPARA ALLA SERRATURA — versione moderna
   Negli inseguimenti chi scappa sigilla la porta: prima c'era un quadrato rosso piatto
   che lampeggiava e un cerchio giallo a schermo. Qui:
   - sulla porta c'è una serratura elettronica credibile (telaio metallico, display, LED,
     tastierino, nucleo da colpire, strisce di pericolo) e degli emettitori sugli stipiti;
   - quando la porta viene sigillata i laser di sigillo si chiudono da destra e sinistra,
     il display passa a "SIGILLATA" con il conto alla rovescia;
   - a schermo: angoli che si stringono sul pannello, anello a segmenti che si svuota,
     etichetta "SPARA ALLA SERRATURA" e secondi rimasti;
   - successo: il pannello salta in pezzi con scintille e fumo, i laser si spengono e gli
     emettitori diventano verdi (porta sbloccata); fallimento: scarica elettrica, laser che
     sfarfallano e scritta "TEMPO SCADUTO".
   Niente modifiche ai file degli altri: si avvolgono buildLevel, update, drawOv, qteStart, qteEnd.
   La logica (3 s, raggio di tocco, danni) resta quella di runHaz/comandi.js.
   ===================================================================== */
const PO={cur:null,res:null,mats:null,texs:[],tor:null,sparkT:0};
const PO_W=.6,PO_H=.8,PO_DOORX=1.42,PO_BEAMY=[.5,1.0,2.4,2.9],PO_SEAL=.45;
const poClamp=(v,a,b)=>v<a?a:v>b?b:v,poOut=k=>1-Math.pow(1-poClamp(k,0,1),3);

/* ---------- materiali condivisi (creati una volta) ---------- */
function poMats(){if(PO.mats)return PO.mats;
 const hz=document.createElement('canvas');hz.width=128;hz.height=16;const c=hz.getContext('2d');c.fillStyle='#e8b81c';c.fillRect(0,0,128,16);c.fillStyle='#14161a';for(let x=-16;x<140;x+=16){c.beginPath();c.moveTo(x,16);c.lineTo(x+8,16);c.lineTo(x+16,0);c.lineTo(x+8,0);c.closePath();c.fill();}
 const ht=new THREE.CanvasTexture(hz);ht.encoding=THREE.sRGBEncoding;
 PO.tor=new THREE.TorusGeometry(.098,.013,6,28);
 PO.mats={frame:new THREE.MeshStandardMaterial({color:lc(0x9aa3ad),roughness:.32,metalness:.88}),
  body:new THREE.MeshStandardMaterial({color:lc(0x262b33),roughness:.5,metalness:.6}),
  black:new THREE.MeshStandardMaterial({color:lc(0x07090c),roughness:.25,metalness:.4}),
  key:new THREE.MeshStandardMaterial({color:lc(0x444b55),roughness:.45,metalness:.5}),
  bolt:new THREE.MeshStandardMaterial({color:lc(0xc3c9d0),roughness:.25,metalness:.95}),
  hazard:new THREE.MeshStandardMaterial({map:ht,roughness:.6,metalness:.2}),
  burnt:new THREE.MeshStandardMaterial({color:lc(0x15130f),roughness:.9,metalness:.2})};
 return PO.mats;}
function poMesh(geo,mat,sx,sy,sz,x,y,z,par){const m=new THREE.Mesh(geo,mat);m.scale.set(sx,sy,sz);m.position.set(x,y,z);m.castShadow=false;par.add(m);return m;}
const poBasic=(col,o)=>new THREE.MeshBasicMaterial(Object.assign({color:col,toneMapped:false},o||{}));

/* ---------- display del pannello (canvas 256x128) ---------- */
function poDisp(po,mode,fr){const key=mode+'|'+(mode==='seal'?Math.ceil(fr*30)+'|'+(Math.floor(G.t*6)&1):'');if(po.dk===key)return;po.dk=key;
 const c=po.cx,W=256,H=128,col=mode==='seal'?'#ff3346':mode==='fail'?'#cfeaff':'#3fd8ff';
 c.fillStyle='#02060a';c.fillRect(0,0,W,H);
 if(mode==='dead'){c.strokeStyle='#3a4450';c.lineWidth=2;c.beginPath();for(let i=0;i<9;i++){const a=i*.7+.3;c.moveTo(150,58);c.lineTo(150+Math.cos(a)*180,58+Math.sin(a)*120);}c.stroke();c.fillStyle='#1b232c';c.beginPath();c.arc(150,58,10,0,7);c.fill();po.tex.needsUpdate=true;return;}
 const g=c.createLinearGradient(0,0,0,H);g.addColorStop(0,col+'33');g.addColorStop(1,col+'05');c.fillStyle=g;c.fillRect(0,0,W,H);
 c.fillStyle=col+'2a';c.fillRect(0,0,W,24);c.fillStyle=col;c.font='bold 14px system-ui,sans-serif';c.textAlign='left';c.textBaseline='middle';c.fillText('SEC-LOCK · Z9',10,12);
 c.beginPath();c.arc(W-14,12,5,0,7);c.fill();
 const dim=mode==='seal'&&(Math.floor(G.t*6)&1);c.textAlign='center';c.fillStyle=dim?col+'99':col;c.font='900 38px system-ui,sans-serif';
 c.fillText(mode==='seal'?'SIGILLATA':mode==='fail'?'SCARICA':'STANDBY',W/2,mode==='seal'?62:66);
 if(mode==='seal'){c.fillStyle=col+'33';c.fillRect(14,94,170,14);c.fillStyle=col;c.fillRect(14,94,170*fr,14);c.font='900 22px system-ui,sans-serif';c.textAlign='right';c.fillText((3*fr).toFixed(1)+'s',W-12,102);}
 else{c.font='bold 13px system-ui,sans-serif';c.fillStyle=col+'cc';c.fillText(mode==='fail'?'SOVRACCARICO':'ACCESSO CONTROLLATO',W/2,104);}
 c.fillStyle='rgba(0,0,0,.28)';for(let y=0;y<H;y+=3)c.fillRect(0,y,W,1);po.tex.needsUpdate=true;}

/* ---------- costruzione della serratura al posto del vecchio quadrato ---------- */
function poBuild(h){const old=h.pn;if(!old||h.po||!old.parent)return;const par=old.parent,M_=poMats();
 const g=new THREE.Group();g.position.copy(old.position);g.quaternion.copy(old.quaternion);par.add(g);par.remove(old);
 const body=new THREE.Group();g.add(body);
 const cv=document.createElement('canvas');cv.width=256;cv.height=128;const tex=new THREE.CanvasTexture(cv);tex.encoding=THREE.sRGBEncoding;PO.texs.push(tex);
 const led=poBasic(new THREE.Color(.1,1,.45)),eye=poBasic(new THREE.Color(.1,1,.45)),disp=poBasic(0xffffff,{map:tex});
 // piastra, telaio a cornice, viti
 poMesh(GEO.box,M_.body,PO_W,PO_H,.06,0,0,-.01,body);
 poMesh(GEO.box,M_.frame,PO_W+.04,.05,.08,0,PO_H/2,0,body);poMesh(GEO.box,M_.frame,PO_W+.04,.05,.08,0,-PO_H/2,0,body);
 for(const sx of[-1,1]){poMesh(GEO.box,M_.frame,.05,PO_H,.08,sx*PO_W/2,0,0,body);for(const sy of[-1,1])poMesh(GEO.cyl,M_.bolt,.025,.012,.025,sx*.25,sy*.35,.026,body).rotation.x=Math.PI/2;
  poMesh(GEO.box,led,.012,.46,.012,sx*(PO_W/2-.045),.02,.03,body);}
 // display con cornice nera
 poMesh(GEO.box,M_.black,.5,.27,.02,0,.22,.026,body);poMesh(GEO.box,disp,.46,.23,.005,0,.22,.038,body);
 // nucleo della serratura (il bersaglio): ghiera, anello LED, occhio
 const core=poMesh(GEO.cyl,M_.bolt,.17,.05,.17,0,0,.035,body);core.rotation.x=Math.PI/2;
 poMesh(PO.tor,led,1,1,1,0,0,.062,body);const ey=poMesh(GEO.cyl,eye,.07,.02,.07,0,0,.064,body);ey.rotation.x=Math.PI/2;
 // tastierino 3x3, striscia di pericolo, LED in alto, condotto dei cavi verso l'architrave
 for(let i=0;i<3;i++)for(let j=0;j<3;j++)poMesh(GEO.box,M_.key,.05,.035,.018,-.19+i*.06,-.17-j*.045,.03,body);
 poMesh(GEO.box,M_.hazard,.5,.05,.01,0,-.345,.03,body);
 for(let i=0;i<4;i++)poMesh(GEO.box,led,.035,.016,.012,.08+i*.05,-.2,.03,body);
 const cond=poMesh(GEO.cyl,M_.frame,.035,1.3,.035,.21,PO_H/2+.65,-.02,body);poMesh(GEO.box,M_.body,.08,.06,.05,.21,PO_H/2+.02,-.01,body);
 // laser di sigillo ed emettitori sugli stipiti (gruppo separato: restano quando il pannello salta)
 const lz=new THREE.Group();lz.position.copy(g.position);lz.quaternion.copy(g.quaternion);par.add(lz);
 const em=poBasic(new THREE.Color(.5,.25,.02)),bm=poBasic(new THREE.Color(1,.12,.16),{transparent:true,blending:THREE.AdditiveBlending,depthWrite:false}),bg=poBasic(new THREE.Color(1,.08,.1),{transparent:true,opacity:.22,blending:THREE.AdditiveBlending,depthWrite:false});
 const fy=-1.7,beams=[];
 for(const by of PO_BEAMY)for(const sx of[-1,1]){poMesh(GEO.box,M_.body,.09,.08,.08,sx*PO_DOORX,fy+by,0,lz);poMesh(GEO.box,em,.012,.03,.03,sx*(PO_DOORX-.048),fy+by,.0,lz);
  const b=poMesh(GEO.box,bm,1,.016,.016,0,fy+by,.02,lz),b2=poMesh(GEO.box,bg,1,.07,.07,0,fy+by,.02,lz);b.visible=b2.visible=false;beams.push({b,b2,sx,y:fy+by});}
 const po=h.po={g,body,cond,lz,par,led,eye,em,bm,bg,disp,tex,cv,cx:cv.getContext('2d'),beams,st:'idle',t0:0,fy:old.position.y-1.7,deb:[],fxT:0,dk:''};
 for(const m of[led,eye,em,bm,bg,disp])m.userData.po=1;
 h.pn=new THREE.Object3D();// runHaz continua a far lampeggiare/nascondere h.pn: ora è un segnaposto invisibile
 poDisp(po,'idle',1);}
function poUpgrade(){if(!G||!G.stages)return;for(const st of G.stages)if(st&&st.haz)for(const h of st.haz)if(h.kind==='lock'&&!h.po)poBuild(h);}

/* ---------- laser ---------- */
function poBeams(po,len,alpha){for(const q of po.beams){const on=len>.01&&alpha>0;q.b.visible=q.b2.visible=on;if(!on)continue;const x=q.sx*(PO_DOORX-len/2);q.b.position.x=q.b2.position.x=x;q.b.scale.x=q.b2.scale.x=len;}
 po.bm.opacity=alpha;po.bg.opacity=.22*alpha;}
function poWorld(po,x,y,z,o){return po.lz.localToWorld((o||new V3()).set(x,y,z));}

/* ---------- pezzi che volano via quando il pannello salta ---------- */
function poBreak(po,good){const M_=poMats();po.body.visible=false;poDisp(po,'dead',0);po.g.updateMatrix();
 const P_=[[.5,.27,.03,M_.black,0,.22,po.disp],[.24,.17,.04,M_.body,-.13,-.18],[.17,.17,.05,M_.bolt,0,0],[PO_W,.05,.06,M_.frame,0,PO_H/2],[.05,PO_H,.06,M_.frame,-PO_W/2,0],[.05,PO_H*.6,.06,M_.frame,PO_W/2,-.1],[.5,.05,.02,M_.hazard,0,-.345],[.1,.07,.05,M_.burnt,.15,-.05],[.08,.05,.04,M_.burnt,-.05,.1]];
 const qq=po.g.quaternion,sp=good?1:.55;
 for(const p of P_){const m=poMesh(GEO.box,p[3],p[0],p[1],p[2],0,0,0,po.par);m.position.set(p[4],p[5],.03).applyMatrix4(po.g.matrix);
  if(p[6]){const f=poMesh(GEO.box,p[6],.92,.85,.2,0,0,.55,m);f.userData.keep=1;}
  const sx=p[4]?Math.sign(p[4]):(Math.random()<.5?-1:1),v=new V3(sx*rr(1.2,2.6),rr(-.3,1.4)*sp,rr(.5,1.4)*sp).applyQuaternion(qq);// verso i lati e in basso: a terra prima che arrivi il giocatore
  po.deb.push({m,v,w:new V3(rr(-9,9),rr(-9,9),rr(-9,9)),hy:Math.min(p[0],p[1],p[2])/2,rest:0});}}
// fallimento: la scarica brucia gli attacchi e il pannello intero si stacca e cade a terra davanti alla porta
function poDrop(po){po.drop=1;po.cond.visible=false;poDisp(po,'dead',0);po.led.color.setRGB(.05,.02,.02);po.eye.color.setRGB(.08,.02,.02);
 po.deb.push({m:po.g,v:new V3(0,-1.6,.5).applyQuaternion(po.g.quaternion),w:new V3(rr(2.6,3.4),0,rr(-.6,.6)),hy:.05,rest:0});}
function poDebris(po,dt){for(const d of po.deb){if(d.rest||!d.m.parent)continue;const m=d.m;d.v.y-=9.8*dt;m.position.addScaledVector(d.v,dt);m.rotation.x+=d.w.x*dt;m.rotation.y+=d.w.y*dt;m.rotation.z+=d.w.z*dt;
  const fl=po.fy+d.hy;if(m.position.y<fl){m.position.y=fl;if(Math.abs(d.v.y)<1.1){d.rest=1;m.rotation.x=Math.round(m.rotation.x/(Math.PI/2))*Math.PI/2;m.rotation.z=Math.round(m.rotation.z/(Math.PI/2))*Math.PI/2;continue;}
   d.v.set(d.v.x*.45,-d.v.y*.32,d.v.z*.45);d.w.multiplyScalar(.5);if(Math.random()<.5)snd('metal');}}}

/* ---------- animazione per fotogramma ---------- */
const PO_TV=new V3();
function poTick(dt){if(!G||!G.stages)return;const st=G.stages[G.si];if(!st||!st.haz)return;
 for(const h of st.haz){if(h.kind!=='lock')continue;if(!h.po){poBuild(h);if(!h.po)continue;}const po=h.po,q=G.qte&&G.qte.dir==='T'&&G.qte.pos===h.tp?G.qte:null;
  if(po.st==='idle'){if(h.s===1){po.st='seal';po.t0=G.t;PO.cur=h;snd('metal');po.em.color.setRGB(1,.1,.12);}
   else{const k=.55+.45*Math.sin(G.t*2.4);po.led.color.setRGB(.08*k,1*k,.45*k);po.eye.color.setRGB(.06,.7+.3*k,.35);}}
  if(po.st==='seal'){const e=G.t-po.t0,fr=q?poClamp(q.t/q.T,0,1):0;
   poBeams(po,PO_DOORX*poOut(e/PO_SEAL),.8+.2*Math.sin(G.t*55));
   const bl=Math.sin(G.t*(fr<.34?26:13))>0;po.led.color.setRGB(bl?1:.25,bl?.08:.02,bl?.1:.03);po.eye.color.setRGB(1,.12+.5*(bl?1:0)*(1-fr),.12);poDisp(po,'seal',fr);
   if(e<PO_SEAL&&(PO.sparkT-=dt)<=0){PO.sparkT=.05;const L=PO_DOORX*poOut(e/PO_SEAL),q2=po.beams[(Math.random()*po.beams.length)|0];bits(poWorld(po,q2.sx*(PO_DOORX-L),q2.y,.02,PO_TV),1,M.spark,1.4,.02,.25);}
   if(h.s>=3){po.t0=G.t;if(h.ok){po.st='ok';poBreak(po,true);po.em.color.setRGB(.15,1,.5);po.fxT=1.6;snd('metal');}else{po.st='fail';poDisp(po,'fail',0);po.em.color.setRGB(.25,.6,1);
     const c=po.g.localToWorld(new V3(0,0,.1));glow(c,1.3,0x7fc8ff,.25,3);bits(c,10,M.spark,3.5,.03,.5);}
    if(PO.cur===h)PO.cur=null;}}
  else if(po.st==='ok'){const e=G.t-po.t0;poBeams(po,PO_DOORX*(1-poOut(e/.25)),e<.25&&Math.sin(G.t*70)>0?1:.5*(1-e/.25));
   if(po.fxT>0){po.fxT-=dt;if((PO.sparkT-=dt)<=0){PO.sparkT=.11;const c=po.g.localToWorld(PO_TV.set(rr(-.15,.15),rr(-.2,.2),.05));bits(c,2,M.spark,2.2,.025,.45);if(Math.random()<.35){const s=glow(c,.5,0x5a5650,1.1,1.6,false);if(s)s.fade=.35;}if(Math.random()<.25)glow(c,.35,0xffa050,.12,2);}}
   poDebris(po,dt);}
  else if(po.st==='fail'){const e=G.t-po.t0;poBeams(po,PO_DOORX*(1-poOut((e-.15)/.3)),Math.random()<.5?1:.2);
   if(e<.15){po.led.color.setRGB(.6,.85,1);if((PO.sparkT-=dt)<=0){PO.sparkT=.06;bits(po.g.localToWorld(PO_TV.set(rr(-.25,.25),rr(-.3,.3),.06)),1,M.spark,2.5,.02,.3);}}
   else if(!po.drop){poDrop(po);po.em.color.setRGB(.12,.03,.03);}
   poDebris(po,dt);}}}

/* ---------- disegno a schermo ---------- */
function poRR(g,x,y,w,h,r){g.beginPath();g.moveTo(x+r,y);g.lineTo(x+w-r,y);g.arcTo(x+w,y,x+w,y+r,r);g.lineTo(x+w,y+h-r);g.arcTo(x+w,y+h,x+w-r,y+h,r);g.lineTo(x+r,y+h);g.arcTo(x,y+h,x,y+h-r,r);g.lineTo(x,y+r);g.arcTo(x,y,x+r,y,r);g.closePath();}
function poFont(w,s){return w+' '+s+'px '+(typeof HFONT==='string'?HFONT:'-apple-system,system-ui,sans-serif');}
// rettangolo a schermo del pannello (dai 4 angoli proiettati); se non disponibile, un quadrato attorno al punto
function poBox(h,p){const out={x0:p[0]-34,x1:p[0]+34,y0:p[1]-44,y1:p[1]+44};if(!h||!h.po)return out;const po=h.po;let ok=0,x0=1e9,x1=-1e9,y0=1e9,y1=-1e9;
 for(const sx of[-1,1])for(const sy of[-1,1]){const s=proj2(po.g.localToWorld(PO_TV.set(sx*(PO_W/2+.06),sy*(PO_H/2+.06),.05)));if(!s)continue;ok++;x0=Math.min(x0,s[0]);x1=Math.max(x1,s[0]);y0=Math.min(y0,s[1]);y1=Math.max(y1,s[1]);}
 return ok===4?{x0,x1,y0,y1}:out;}
function poBrackets(g,b,ex,col,lw){const L=Math.max(12,Math.min(26,(b.x1-b.x0)*.32));g.lineCap='square';
 for(const pass of[0,1]){g.lineWidth=pass?lw:lw+3;g.strokeStyle=pass?col:'rgba(0,0,0,.5)';g.beginPath();
  for(const sx of[-1,1])for(const sy of[-1,1]){const x=(sx<0?b.x0:b.x1)+sx*ex,y=(sy<0?b.y0:b.y1)+sy*ex;g.moveTo(x-sx*L,y);g.lineTo(x,y);g.lineTo(x,y-sy*L);}g.stroke();}
 g.lineCap='round';}
function poPill(g,x,y,txt,col,sub,a){g.save();g.globalAlpha=a;g.font=poFont(800,15);const w=Math.max(g.measureText(txt).width+52,sub?120:0),hh=sub?44:32,x0=x-w/2;
 poRR(g,x0,y-hh/2,w,hh,6);g.fillStyle='rgba(6,10,16,.82)';g.fill();g.lineWidth=1.2;g.strokeStyle=col;g.globalAlpha=a*.7;g.stroke();g.globalAlpha=a;
 g.fillStyle=col;g.fillRect(x0,y-hh/2+6,3,hh-12);
 // lucchetto stilizzato
 const lx=x0+20,ly=y-(sub?6:0);g.lineWidth=2;g.strokeStyle=col;g.beginPath();g.arc(lx,ly-3,4.5,Math.PI,0);g.stroke();g.fillRect(lx-6.5,ly-2,13,10);
 g.textAlign='left';g.textBaseline='middle';g.fillStyle='#fff';g.fillText(txt,x0+36,y-(sub?7:0));
 if(sub){g.font=poFont(700,11);g.fillStyle=col;g.fillText(sub,x0+36,y+11);}
 g.textAlign='center';g.textBaseline='alphabetic';g.restore();}
function poTarget(q){const g=og,h=PO.cur&&PO.cur.tp===q.pos?PO.cur:null,p=proj2(PO_TV.copy(q.pos)),W=innerWidth,H=innerHeight;
 g.setTransform(ODPR,0,0,ODPR,0,0);const e=h&&h.po?G.t-h.po.t0:1,fr=poClamp(q.t/q.T,0,1),urg=fr<.34,bl=Math.sin(G.t*18)>0,col=urg?(bl?'#ff3b30':'#ff7a6a'):'#ffd24a';
 // bordo rosso che pulsa nell'ultimo secondo
 if(urg){const k=(.5+.5*Math.sin(G.t*12))*(1-fr/.34),gr=g.createRadialGradient(W/2,H/2,H*.32,W/2,H/2,H*.78);gr.addColorStop(0,'rgba(255,0,0,0)');gr.addColorStop(1,'rgba(255,30,20,'+(.32*k).toFixed(3)+')');g.fillStyle=gr;g.fillRect(0,0,W,H);}
 if(!p){poPill(g,W/2,H*.3,'SPARA ALLA SERRATURA',col,null,1);return;}
 const b=poBox(h,p),cx=p[0],cy=p[1],R=poClamp(Math.hypot(b.x1-b.x0,b.y1-b.y0)*.5+14,46,120),k0=poOut(e/.35);
 // anello a segmenti che si svuota col tempo (parte dall'alto, in senso orario)
 const N=30,lit=Math.ceil(fr*N),shown=Math.ceil(N*poClamp(e/.3,0,1)),seg=Math.PI*2/N;g.lineCap='butt';
 g.lineWidth=7;g.strokeStyle='rgba(0,0,0,.45)';g.beginPath();g.arc(cx,cy,R,0,Math.PI*2);g.stroke();
 for(let i=0;i<shown;i++){const a0=-Math.PI/2+i*seg+seg*.14,a1=a0+seg*.72;g.lineWidth=i<lit?4.5:3;g.strokeStyle=i<lit?col:'rgba(255,255,255,.16)';g.beginPath();g.arc(cx,cy,R,a0,a1);g.stroke();}
 g.lineCap='round';
 // onda che si allarga: "tocca qui"
 const ph=(G.t*1.25)%1;g.lineWidth=2;g.strokeStyle=urg?'rgba(255,70,50,'+(.6*(1-ph)).toFixed(3)+')':'rgba(255,210,74,'+(.55*(1-ph)).toFixed(3)+')';g.beginPath();g.arc(cx,cy,R+4+ph*26,0,Math.PI*2);g.stroke();
 // angoli che si stringono sul pannello
 poBrackets(g,b,(1-k0)*70+(1+Math.sin(G.t*8))*1.5,col,2.5);
 // mirino centrale sottile
 g.lineWidth=1.6;g.strokeStyle='rgba(255,255,255,.85)';g.beginPath();for(const [dx,dy] of[[1,0],[-1,0],[0,1],[0,-1]]){g.moveTo(cx+dx*9,cy+dy*9);g.lineTo(cx+dx*17,cy+dy*17);}g.stroke();
 g.fillStyle=col;g.beginPath();g.arc(cx,cy,2.6,0,Math.PI*2);g.fill();
 // etichetta e secondi
 const ly=Math.max(64,cy-R-38);poPill(g,cx<W/2?Math.max(cx,118):Math.min(cx,W-118),ly+(1-k0)*10,'SPARA ALLA SERRATURA',col,'PORTA SIGILLATA',k0);
 g.font=poFont(900,26);g.lineWidth=4;g.strokeStyle='rgba(0,0,0,.7)';const ty=Math.min(H-150,cy+R+34),tt=q.t.toFixed(1);g.strokeText(tt,cx,ty);g.fillStyle=col;g.fillText(tt,cx,ty);
 g.font=poFont(700,11);g.fillStyle='rgba(255,255,255,.75)';g.fillText('SECONDI',cx,ty+15);}
function poResult(){const r=PO.res;if(!r)return;r.t=G.t-r.t0;if(r.t>1.1||r.t<0){PO.res=null;return;}const g=og,W=innerWidth,H=innerHeight;g.setTransform(ODPR,0,0,ODPR,0,0);
 const p=r.pos?proj2(PO_TV.copy(r.pos)):null,cx=p?p[0]:W/2,cy=p?p[1]:H*.4,a=r.t<.8?1:1-(r.t-.8)/.3,col=r.good?'#5fe08f':'#ff4a3a';
 if(!r.good&&r.t<.35){g.fillStyle='rgba(255,40,30,'+(.28*(1-r.t/.35)).toFixed(3)+')';g.fillRect(0,0,W,H);}
 const R=(r.R||60)+poOut(r.t/.5)*60;g.globalAlpha=Math.max(0,1-r.t/.6);g.lineWidth=4;g.strokeStyle=col;g.beginPath();g.arc(cx,cy,R,0,Math.PI*2);g.stroke();g.lineWidth=2;g.beginPath();g.arc(cx,cy,R*.7,0,Math.PI*2);g.stroke();g.globalAlpha=1;
 if(r.box){const s=poOut(r.t/.4)*(r.good?40:-12);poBrackets(g,r.box,s,col,2.5);}
 const sc=r.t<.15?1.25-.25*(r.t/.15):1;g.save();const ly=Math.max(64,(r.ly||cy-100));g.translate(cx<W/2?Math.max(cx,118):Math.min(cx,W-118),ly);g.scale(sc,sc);
 poPill(g,0,0,r.good?'SERRATURA DISTRUTTA':'TEMPO SCADUTO',col,r.good?'PORTA SBLOCCATA':'SCARICA ELETTRICA',Math.max(0,a));g.restore();}

/* ---------- agganci alle funzioni esistenti ---------- */
const PO_buildLevel0=buildLevel;
buildLevel=function(L){for(const t of PO.texs)t.dispose();PO.texs.length=0;PO.cur=null;PO.res=null;const r=PO_buildLevel0(L);try{poUpgrade();}catch(e){console.warn('porta',e);}return r;};
const PO_update0=update;
update=function(dt){PO_update0(dt);try{if(state==='play')poTick(dt);}catch(e){console.warn('porta',e);}};
const PO_qteStart0=qteStart;
qteStart=function(dir,T,ok,defer,lab){const r=PO_qteStart0(dir,T,ok,defer,lab);if(r&&dir==='T')QS.el.style.display='none';return r;};// etichetta e barra le disegna poTarget
const PO_qteEnd0=qteEnd;
qteEnd=function(good){const q=G&&G.qte;let box=null,R=60,ly=null;
 if(q&&q.dir==='T'&&q.pos){const p=proj2(PO_TV.copy(q.pos));if(p){const h=PO.cur&&PO.cur.tp===q.pos?PO.cur:null;box=poBox(h,p);R=poClamp(Math.hypot(box.x1-box.x0,box.y1-box.y0)*.5+14,46,120);ly=p[1]-R-38;}}
 PO_qteEnd0(good);
 if(q&&q.dir==='T'){G.qres=null;PO.res={good,t:0,t0:G.t,pos:q.pos?q.pos.clone():null,box,R,ly};}};
const PO_drawOv0=drawOv;
drawOv=function(){const q=G&&G.qte;
 if(q&&q.dir==='T'){q.dir='T_';try{PO_drawOv0();}finally{q.dir='T';}try{poTarget(q);}catch(e){console.warn('porta',e);}return;}
 PO_drawOv0();try{poResult();}catch(e){console.warn('porta',e);}};
