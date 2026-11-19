// Settore Zero — un mirino per ogni arma e cannocchiale del cecchino
'use strict';
/* ===== mirini =====
   Ogni mirino è un tracciato disegnato due volte: contorno scuro largo + tratto colorato sottile,
   così si legge sia su sfondi chiari sia scuri. La grandezza segue la dispersione reale dell'arma
   (spread in radianti, ridotto dal livello come in wst()) convertita in pixel sullo schermo.
   Quando colpisci il mirino diventa rosso (oro alla testa) e compare una piccola "X" di conferma.
   Niente allocazioni per fotogramma: un solo oggetto di appoggio (MR_S) e funzioni di tracciato fisse. */
const MR_DARK='rgba(0,0,0,.55)',MR_WHITE='rgba(255,255,255,.94)',MR_TAU=6.2832;
const MR_S={col:MR_WHITE,ac:MR_WHITE,sp:0,bl:0,pel:8};// stato di appoggio riusato a ogni disegno
// tracciati di base (aggiungono sottotracciati al percorso corrente)
function MR_cross(g,x,y,a,b){g.moveTo(x-b,y);g.lineTo(x-a,y);g.moveTo(x+a,y);g.lineTo(x+b,y);g.moveTo(x,y-b);g.lineTo(x,y-a);g.moveTo(x,y+a);g.lineTo(x,y+b);}
function MR_circ(g,x,y,r){g.moveTo(x+r,y);g.arc(x,y,r,0,MR_TAU);}
// due passate sullo stesso percorso: contorno scuro + colore
function MR_stroke(g,col,w){g.lineWidth=w+2.6;g.strokeStyle=MR_DARK;g.stroke();g.lineWidth=w;g.strokeStyle=col;g.stroke();}
function MR_dot(g,x,y,r,col){g.beginPath();g.arc(x,y,r+1.4,0,MR_TAU);g.fillStyle=MR_DARK;g.fill();g.beginPath();g.arc(x,y,r,0,MR_TAU);g.fillStyle=col;g.fill();}
// "X" di colpo a segno
function MR_hit(g,x,y,col){g.beginPath();for(let i=0;i<4;i++){const cx=i&1?1:-1,cy=i&2?1:-1;g.moveTo(x+cx*8,y+cy*8);g.lineTo(x+cx*13,y+cy*13);}MR_stroke(g,col,2);}
// pixel per radiante al centro dello schermo (tiene conto dello zoom del cannocchiale)
function MR_ppr(){return innerHeight*.5/Math.tan(cam.fov*Math.PI/360)*SCP.z;}

/* tabella dei mirini per tipo d'arma: d(g,x,y,s) disegna; zoom = ingrandimento del cannocchiale */
const MIR={
 // pistola: punto + croce corta
 pistol:{d(g,x,y,s){const a=Math.max(4,s.sp*.8)+s.bl*2;g.beginPath();MR_cross(g,x,y,a,a+6);MR_stroke(g,s.col,2);MR_dot(g,x,y,1.6,s.col);}},
 // revolver (Luger): croce che attraversa un cerchio piccolo
 revolver:{d(g,x,y,s){const r=Math.max(7,s.sp+3)+s.bl*1.5;g.beginPath();MR_circ(g,x,y,r);MR_cross(g,x,y,r-3,r+8);MR_stroke(g,s.col,1.8);MR_dot(g,x,y,1.3,s.col);}},
 // mitraglietta: croce dinamica che si apre mentre spari
 smg:{d(g,x,y,s){const a=s.sp*.55*(1+.5*s.bl)+3;g.beginPath();MR_cross(g,x,y,a,a+8);MR_stroke(g,s.col,2);MR_dot(g,x,y,1.4,s.col);}},
 // fucile a pompa: ellisse larga quanto la rosa dei pallini (orizzontale = spread, verticale = 0.7 spread come in fire()) + un puntino per pallino
 shotgun:{d(g,x,y,s){const rx=Math.max(20,s.sp)*(1+.06*s.bl),ry=rx*.7;g.beginPath();g.ellipse(x,y,rx,ry,0,0,MR_TAU);
   g.moveTo(x-rx,y);g.lineTo(x-rx+7,y);g.moveTo(x+rx,y);g.lineTo(x+rx-7,y);g.moveTo(x,y-ry);g.lineTo(x,y-ry+6);g.moveTo(x,y+ry);g.lineTo(x,y+ry-6);MR_circ(g,x,y,4);MR_stroke(g,s.col,1.6);
   g.beginPath();for(let i=0;i<s.pel;i++){const a=i*MR_TAU/s.pel+.39,px=x+Math.cos(a)*rx*.55,py=y+Math.sin(a)*ry*.55;g.moveTo(px+1.7,py);g.arc(px,py,1.7,0,MR_TAU);}
   g.lineWidth=2.4;g.strokeStyle=MR_DARK;g.stroke();g.fillStyle=s.col;g.fill();}},
 // fucile d'assalto: 4 tacche spesse, apertura secondo lo spread
 rifle:{d(g,x,y,s){const a=s.sp*.7+3+s.bl*3;g.beginPath();MR_cross(g,x,y,a,a+9);MR_stroke(g,s.col,2.4);MR_dot(g,x,y,1.5,s.col);}},
 // AK: 4 tacche più aperte (spread maggiore) + chevron sotto al centro
 minigun:{d(g,x,y,s){const a=s.sp*.5+4+s.bl*5;g.beginPath();MR_cross(g,x,y,a,a+9);g.moveTo(x-6,y+12);g.lineTo(x,y+6);g.lineTo(x+6,y+12);MR_stroke(g,s.col,2.2);MR_dot(g,x,y,1.4,s.col);}},
 // lanciaplasma: anello con tre archi di energia che ruotano + punto azzurro
 plasma:{ac:'#5fe3ff',d(g,x,y,s){g.beginPath();MR_circ(g,x,y,13);MR_stroke(g,s.col,1.8);const t=G.t*2.4;g.beginPath();for(let i=0;i<3;i++){const a=t+i*2.0944;g.moveTo(x+Math.cos(a)*19,y+Math.sin(a)*19);g.arc(x,y,19,a,a+.8);}MR_stroke(g,s.ac,2);MR_dot(g,x,y,3.2,s.ac);}},
 // Minigun: anello + tre tacche che girano con le canne + arco esterno = giri delle canne (G.gsp, armi-ambienti.js)
 gatling:{d(g,x,y,s){const r=clamp(s.sp*.65,20,36),k=G.gsp||0,a0=G.gang||0;g.beginPath();MR_circ(g,x,y,r);for(let i=0;i<3;i++){const a=a0+i*2.0944,c=Math.cos(a),n=Math.sin(a);g.moveTo(x+c*r*.38,y+n*r*.38);g.lineTo(x+c*r*.72,y+n*r*.72);}MR_stroke(g,s.col,1.7);
   g.lineWidth=5;g.strokeStyle=MR_DARK;g.beginPath();g.arc(x,y,r+6,0,MR_TAU);g.stroke();if(k>.01){g.lineWidth=3;g.strokeStyle=k>.97?'#ff5a3a':'#ffb040';g.beginPath();g.arc(x,y,r+6,-1.5708,-1.5708+MR_TAU*k);g.stroke();}MR_dot(g,x,y,1.5,s.col);}},
 // lanciarazzi: cerchio, staffe laterali e tacche di distanza sotto (più strette = più lontano)
 rocket:{d(g,x,y,s){g.beginPath();MR_circ(g,x,y,6);g.moveTo(x-14,y-9);g.lineTo(x-18,y-9);g.lineTo(x-18,y+9);g.lineTo(x-14,y+9);g.moveTo(x+14,y-9);g.lineTo(x+18,y-9);g.lineTo(x+18,y+9);g.lineTo(x+14,y+9);
   g.moveTo(x,y+10);g.lineTo(x,y+40);g.moveTo(x-9,y+18);g.lineTo(x+9,y+18);g.moveTo(x-6,y+27);g.lineTo(x+6,y+27);g.moveTo(x-3.5,y+36);g.lineTo(x+3.5,y+36);MR_stroke(g,s.col,1.8);MR_dot(g,x,y,1.4,s.col);}},
 // laser: punto rosso sottile con alone e capelli sottili
 laser:{col:'#ff3c5a',d(g,x,y,s){g.fillStyle='rgba(255,60,90,.25)';g.beginPath();g.arc(x,y,6,0,MR_TAU);g.fill();g.beginPath();MR_cross(g,x,y,5,10);MR_stroke(g,s.col,1);MR_dot(g,x,y,1.8,s.col);}},
 // cecchino: croce sottile lunga quando spari d'istinto; tenendo premuto entra il cannocchiale (scopeDraw)
 sniper:{zoom:3,d(g,x,y,s){const e=SCP.e;if(e>.5){MR_dot(g,x,y,1.8,G.hitM>0?s.col:'#ff2a2a');return;}g.globalAlpha=1-e*2;g.beginPath();MR_cross(g,x,y,6,22);MR_circ(g,x,y,3);MR_stroke(g,s.col,1.3);g.globalAlpha=1;}}
};
// disegna il mirino dell'arma in mano nel punto (x,y); chiamata da drawOv() in hud.js
function mirDraw(g,x,y){const w=cw(),t=WT[w.t],m=MIR[w.t]||MIR.pistol,s=MR_S,hm=G.hitM>0;
 s.col=hm?(G.hitHead?'#ffd65a':'#ff4040'):(m.col||MR_WHITE);s.ac=hm?s.col:(m.ac||s.col);
 s.sp=(t.spread||0)*Math.max(.3,1-.07*(w.l||0))*MR_ppr();s.bl=Math.min(1,G.kick);s.pel=t.pel||8;
 m.d(g,x,y,s);if(hm)MR_hit(g,x,y,s.col);}

/* ===== cannocchiale del cecchino =====
   Tenendo premuto col cecchino la visuale si ingrandisce (MIR.sniper.zoom = 3, cioè campo visivo 1/3) con
   cam.setViewOffset: si inquadra un rettangolo W/z x H/z dell'immagine normale, scelto in modo che il punto mirato
   resti esattamente sotto il reticolo (che sta dove tocchi, 58px sopra il dito). Lo sparo usa ndc (= reticolo) con la
   stessa camera, quindi il raggio passa esattamente per il centro del reticolo (RC.setFromCamera usa la proiezione
   con l'offset). Al tocco la camera non ruota verso il dito (lo fa con le altre armi): ciò che tocchi resta sotto il
   reticolo. Trascinando il dito il reticolo lo segue e la mira si sposta di MR_KS/zoom pixel per pixel (mira più fine,
   la visuale scorre piano nel verso opposto).
   Il respiro fa ondeggiare piano la visuale sotto il reticolo (il colpo va sempre dove sta il reticolo).
   Lo zoom si toglie subito in corsa/porta/QTE/cinematica/schivata, cambiando arma, in pausa e a fine livello;
   rilasciando il dito sfuma in pochi centesimi di secondo. */
const MR_KS=1.6,MR_V=new V3();
const SCP={k:0,e:0,z:1,dx:0,dy:0,px:0,py:0,rx:0,ry:0,sx:0,sy:0,qx:0,qy:0,id:null,hid:false,p0:new V3()};
function scopeZoom(){if(state!=='play'||!G||G.mv||G.cine||G.qte||G.dg||G.phase==='end')return 0;const w=cw(),m=w&&MIR[w.t];return m&&m.zoom||0;}
// chiamata da update() PRIMA di orientare la camera: tocco/trascinamento, quantità di zoom e SRN (rotazione della camera)
function scopeTick(dt){const Z=scopeZoom(),rx=(ndc.x+1)*.5*innerWidth,ry=(1-ndc.y)*.5*innerHeight;
 if(!Z){if(SCP.k>0||SCP.hid||(cam.view&&cam.view.enabled))scopeOff(false);SRN.copy(ndc);SCP.px=rx;SCP.py=ry;return;}
 const want=aim.down;
 // nuovo tocco: il punto del mondo che si vedeva sotto il reticolo (un solo raggio per tocco) diventa la mira (SCP.p0);
 // la camera smette di ruotare verso il dito, così mentre esci dal riparo e lo zoom entra quel punto resta sotto il reticolo
 if(want&&aim.id!==SCP.id){SCP.id=aim.id;SCP.dx=SCP.dy=0;if(SCP.k<=0){SCP.sx=SRN.x;SCP.sy=SRN.y;}
  RC.setFromCamera(ndc,cam);const h=cast(cam.position,RC.ray.direction);SCP.p0.copy(cam.position).addScaledVector(RC.ray.direction,h?h.h.distance:40);}
 else if(want){const f=1+(MR_KS/Z-1)*SCP.e;SCP.dx+=(rx-SCP.px)*f;SCP.dy+=(ry-SCP.py)*f;}
 else SCP.id=null;// rilasciando la mira resta dov'era mentre lo zoom sfuma
 SCP.px=rx;SCP.py=ry;SCP.rx=rx;SCP.ry=ry;
 SCP.k+=((want?1:0)-SCP.k)*Math.min(1,dt*(want?9:14));if(!want&&SCP.k<.01)SCP.k=0;
 const k=SCP.k,e=k*k*(3-2*k);SCP.e=e;SCP.z=1+(Z-1)*e;
 // orientamento della camera: fermo mentre tieni premuto, torna a seguire la mira mentre lo zoom sfuma
 const wr=want?1:e;SRN.set(ndc.x+(SCP.sx-ndc.x)*wr,ndc.y+(SCP.sy-ndc.y)*wr);
 const hide=e>.55;if(hide!==SCP.hid){SCP.hid=hide;WG.visible=!hide;}}
// proiezione di p sull'immagine normale (senza zoom) con la camera già aggiornata -> SCP.qx/qy (pixel)
function MR_proj(p){MR_V.copy(p).applyMatrix4(cam.matrixWorldInverse);const d=-MR_V.z;if(d<.05)return false;const ty=Math.tan(cam.fov*Math.PI/360),tx=ty*cam.aspect;
 SCP.qx=(MR_V.x/d/tx+1)*.5*innerWidth;SCP.qy=(1-MR_V.y/d/ty)*.5*innerHeight;return true;}
// chiamata da update() DOPO cam.updateMatrixWorld() e prima di sparare: offset di vista (zoom) ancorato al reticolo
function scopeView(){const e=SCP.e;if(e<=0){if(cam.view&&cam.view.enabled)cam.clearViewOffset();return;}
 const W=innerWidth,H=innerHeight,rx=SCP.rx,ry=SCP.ry,z=SCP.z,t=G.t;
 // punto mirato (pixel dell'immagine normale) = punto agganciato + trascinamento, più respiro e rinculo (la visuale sale e torna)
 let ax=rx,ay=ry;if(MR_proj(SCP.p0)){ax=SCP.qx+SCP.dx;ay=SCP.qy+SCP.dy;}
 const ux=rx+(ax-rx)*e+(Math.sin(t*1.1)*1.5+Math.sin(t*2.3)*.5)*e,uy=ry+(ay-ry)*e+(Math.sin(t*.8+1)*1.1+Math.sin(t*1.9)*.4-G.kick*6)*e;
 cam.setViewOffset(W,H,ux-rx/z,uy-ry/z,W/z,H/z);}
// toglie lo zoom all'istante; redraw: ridisegna una volta la scena senza zoom (pausa, fine livello)
function scopeOff(redraw){const was=SCP.k>0||!!(cam.view&&cam.view.enabled);SCP.k=0;SCP.e=0;SCP.z=1;SCP.id=null;
 if(cam.view&&cam.view.enabled)cam.clearViewOffset();if(SCP.hid){SCP.hid=false;WG.visible=true;}SRN.copy(ndc);
 if(redraw&&was&&G){try{renderer.render(scene,cam);og.setTransform(1,0,0,1,0,0);og.clearRect(0,0,ov.width,ov.height);}catch(err){console.warn('cannocchiale',err);}}}
// vignettatura del cannocchiale: gradiente centrato in 0,0 tenuto in cache (cambia solo se cambia il raggio)
let MR_VG=null,MR_VR=0;
function MR_vig(g,r){if(MR_VG&&MR_VR===r)return MR_VG;const v=g.createRadialGradient(0,0,r*.55,0,0,r);v.addColorStop(0,'rgba(0,0,0,0)');v.addColorStop(.72,'rgba(0,0,0,.22)');v.addColorStop(1,'rgba(0,0,0,.92)');MR_VG=v;MR_VR=r;return v;}
// overlay del cannocchiale: nero attorno al cerchio, vignettatura, riflesso, reticolo fine con mil-dot e pali spessi
function scopeDraw(g){const e=SCP.e;if(e<=0)return;const W=innerWidth,H=innerHeight,x=SCP.rx,y=SCP.ry,R=Math.round(Math.min(W,H)*.47),r=R*(1+.9*(1-e));
 g.save();g.globalAlpha=Math.min(1,e*1.5);g.fillStyle='#000';g.beginPath();g.rect(0,0,W,H);g.moveTo(x+r,y);g.arc(x,y,r,0,MR_TAU,true);g.fill();
 g.translate(x,y);const sc=r/R;g.scale(sc,sc);
 g.fillStyle='rgba(30,70,110,.07)';g.beginPath();g.arc(0,0,R,0,MR_TAU);g.fill();g.fillStyle=MR_vig(g,R);g.fill();
 // riflesso della lente in alto a sinistra
 g.lineCap='round';g.strokeStyle='rgba(190,220,255,.11)';g.lineWidth=R*.05;g.beginPath();g.arc(0,0,R*.85,3.55,4.45);g.stroke();g.strokeStyle='rgba(190,220,255,.06)';g.lineWidth=R*.02;g.beginPath();g.arc(0,0,R*.74,3.75,4.2);g.stroke();
 // anello del tubo
 g.strokeStyle='#080808';g.lineWidth=8;g.beginPath();g.arc(0,0,R,0,MR_TAU);g.stroke();g.strokeStyle='rgba(120,130,140,.35)';g.lineWidth=1.2;g.beginPath();g.arc(0,0,R-4.5,0,MR_TAU);g.stroke();
 // reticolo: alone chiaro sottile (si legge sullo scuro) + linee nere fini; pali spessi verso il bordo
 const pin=R*.5,st=R*.085;g.lineCap='butt';g.beginPath();g.moveTo(-R,0);g.lineTo(R,0);g.moveTo(0,-R);g.lineTo(0,R);
 g.strokeStyle='rgba(255,255,255,.22)';g.lineWidth=3;g.stroke();g.strokeStyle='#000';g.lineWidth=1.2;g.stroke();
 g.beginPath();g.moveTo(-R,0);g.lineTo(-pin,0);g.moveTo(pin,0);g.lineTo(R,0);g.moveTo(0,pin);g.lineTo(0,R);g.moveTo(0,-R);g.lineTo(0,-pin);g.strokeStyle='rgba(255,255,255,.18)';g.lineWidth=7;g.stroke();g.strokeStyle='#000';g.lineWidth=5;g.stroke();
 g.beginPath();for(let i=1;i<=5;i++){const d=i*st;g.moveTo(d+2,0);g.arc(d,0,2,0,MR_TAU);g.moveTo(-d+2,0);g.arc(-d,0,2,0,MR_TAU);g.moveTo(2,d);g.arc(0,d,2,0,MR_TAU);g.moveTo(2,-d);g.arc(0,-d,2,0,MR_TAU);}
 g.strokeStyle='rgba(255,255,255,.22)';g.lineWidth=1.6;g.stroke();g.fillStyle='#000';g.fill();
 g.restore();g.lineCap='round';}
