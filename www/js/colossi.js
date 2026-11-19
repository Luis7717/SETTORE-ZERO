// Settore Zero — boss: nove macchine diverse
'use strict';
/* ===== Colossi: nove macchine diverse ===== */
GEO.cone=new THREE.ConeGeometry(.5,1,12);GEO.tor=new THREE.TorusGeometry(.5,.07,8,28);
const bMat=(c,r,m)=>new THREE.MeshStandardMaterial({map:M.steel&&M.steel.map||null,color:lc(c),roughness:r===undefined?.45:r,metalness:m===undefined?.65:m});
const bEm=(c,i)=>new THREE.MeshStandardMaterial({color:lc(0x120a10),emissive:lc(c),emissiveIntensity:i||1.5});
function bLegs(e,g,m1,m2,list,h,w){for(const[x,z]of list){const l=new THREE.Group();l.position.set(x,h,z);g.add(l);P('box',m2,w*.8,h*.5,w*.9,0,-h*.25,0,l);P('box',m1,w,h*.5,w*1.15,0,-h*.72,.04,l);P('box',m2,w*1.3,.18,w*1.9,0,-h+.09,.12,l);P('cyl',M.dark,w*.7,w*1.02,w*.7,0,-h*.5,0,l).rotation.z=Math.PI/2;e.legs.push(l);}}
function bMz(e,g,x,y,z){const o=new THREE.Object3D();o.position.set(x,y,z);g.add(o);e.mzs.push(o);return o;}
function bGun(e,g,m,x,y,z,len,r){const c=P('cyl',M.dark,r,len,r,x,y,z+len/2,g);c.rotation.x=Math.PI/2;P('cyl',m,r*1.5,len*.35,r*1.5,x,y,z+len*.2,g).rotation.x=Math.PI/2;return bMz(e,g,x,y,z+len+.1);}
function bCore(g,em,s,x,y,z){const c=P('sph',em,s,s,s*.7,x,y,z,g);c.userData.head=1;P('tor',M.dark,s*1.25,s*1.25,s*1.2,x,y,z-.02,g);return c;}
const BOSS=[
{t:'IL CARRO D\'ASSALTO',c:0x7a3a22,c2:0x2a2220,gl:0xff7a20,amp:2.2,sw:.4,ls:2.4,cool:1.9,burst:12,seq:()=>['gun','charge','gun','stomp'],
 b(e,g,A,B,E){bLegs(e,g,A,B,[[-1,.9],[1,.9],[-1,-.9],[1,-.9]],1.15,.5);P('box',A,2.5,1.25,2.9,0,1.8,0,g);P('box',B,2.7,.3,3.1,0,1.25,0,g);P('box',B,2.1,.5,1.6,0,2.6,-.5,g);P('box',A,1.6,1.05,.9,0,1.75,1.75,g);P('box',M.hazard,2.1,.95,.26,0,1.55,2.3,g);
  for(const sx of[-1,1]){const h=P('cone',M.steel,.5,1.6,.5,sx*.95,2.35,2.2,g);h.rotation.set(1.25,0,-sx*.45);P('cyl',B,.45,.5,.45,sx*1.5,1.9,-.9,g).rotation.z=Math.PI/2;bGun(e,g,A,sx*1.55,2.05,.6,1.1,.2);P('box',E,.5,.07,.06,sx*.4,2.05,2.21,g);}
  bCore(g,E,.85,0,3.0,.15);e.cy=1.8;e.hy=3.0;}},
{t:'LA LAMA CHIRURGICA',c:0xd4dce0,c2:0x35444c,gl:0x30ffe0,amp:3,sw:.75,ls:5,cool:1.4,burst:9,swl:'LAMA — GIÙ',seq:()=>['beam','sweep','gun','sweep'],
 b(e,g,A,B,E){bLegs(e,g,A,B,[[-.45,0],[.45,0]],2.05,.26);P('box',B,1.1,.35,.6,0,2.2,0,g);P('box',A,.85,1.5,.6,0,3.1,0,g);P('box',B,1.3,.25,.7,0,3.85,0,g);P('sph',A,.55,.6,.6,0,4.35,.05,g);P('box',E,.42,.08,.06,0,4.38,.33,g);bMz(e,g,0,4.38,.4);e.mb=e.mzs[0];
  for(const sx of[-1,1]){const a=new THREE.Group();a.position.set(sx*.8,3.75,0);g.add(a);P('box',B,.2,.2,1.2,0,-.1,.55,a);P('box',A,.05,.42,2.3,0,-.25,2.2,a);P('box',E,.02,.06,2.3,0,-.48,2.2,a);a.rotation.x=.55;if(sx>0)e.arm=a;else e.arm2=a;}
  bMz(e,g,0,3.1,.5);bCore(g,E,.55,0,3.15,.32);for(const y of[2.6,2.9,3.4])P('box',B,.9,.04,.64,0,y,0,g);e.cy=3.1;e.hy=3.15;}},
{t:'IL MARTELLO DELLA FONDERIA',c:0x4a4a52,c2:0x232326,gl:0xff7a10,amp:1.8,sw:.3,ls:1.8,cool:2,rk:3,mn:3,swl:'MAGLIO — GIÙ',seq:()=>['mortar','stomp','rock','sweep'],
 b(e,g,A,B,E){bLegs(e,g,A,B,[[-.95,0],[.95,0]],1.5,.62);P('box',B,2.2,.5,1.3,0,1.6,0,g);P('box',A,2.9,1.5,1.7,0,2.55,.1,g);P('box',M.hazard,2.95,.3,1.75,0,1.95,.1,g);P('box',B,1,.6,.8,0,3.5,.2,g);P('box',E,.6,.09,.05,0,3.5,.61,g);
  for(const x of[-.8,0,.8]){P('cyl',B,.36,1.1,.36,x,3.75,-.6,g);P('cyl',E,.3,.05,.3,x,4.31,-.6,g);}
  const a=e.arm=new THREE.Group();a.position.set(1.85,3,0);g.add(a);P('box',B,.5,.5,2,0,0,1,a);P('box',A,1.15,1.15,1.35,0,0,2.4,a);P('box',M.hazard,1.2,.25,1.4,0,0,2.4,a);P('box',M.steel,1.25,1.25,.12,0,0,3.1,a);a.rotation.x=.25;
  bGun(e,g,A,-1.85,3,.2,1.5,.34);e.mt=bMz(e,g,0,4.4,-.6);bCore(g,E,.85,0,2.55,.95);for(const x of[-.25,0,.25])P('box',M.dark,.05,.8,.05,x,2.55,1.3,g);e.cy=2.5;e.hy=2.55;}},
{t:'LA MADRE DELLO SCIAME',c:0x24401c,c2:0x121a10,gl:0x80ff30,amp:2.8,sw:.5,ls:3,cool:1.7,dn:3,mn:3,hov:1,seq:()=>['drones','mortar','beam','drones','gun'],
 b(e,g,A,B,E){P('sph',A,2.5,2.2,2.9,0,2.7,-.6,g);for(let i=0;i<7;i++){const a=i*.9;P('sph',E,.42,.42,.42,Math.cos(a)*1.05,2.2+Math.sin(a*1.7)*.7,-.6+Math.sin(a)*1.25,g);}P('sph',B,1.5,1.3,1.5,0,3.2,1,g);P('sph',A,.9,.8,.9,0,3.3,1.95,g);for(const sx of[-1,1]){P('sph',E,.22,.22,.22,sx*.28,3.4,2.32,g);const m=P('cone',B,.14,.9,.14,sx*.3,2.9,2.3,g);m.rotation.x=2.6;}
  e.ring=P('tor',M.steel,4.4,4.4,3,0,2.7,-.6,g);e.ring.rotation.x=Math.PI/2;e.wings=[];for(const sx of[-1,1]){const w=new THREE.Group();w.position.set(sx*.6,3.9,.6);g.add(w);P('box',bEm(0x80ff30,.5),2.6,.03,1,sx*1.3,0,0,w).material.transparent=true;w.children[0].material.opacity=.35;e.wings.push(w);}
  for(let i=0;i<6;i++){const sx=i%2?1:-1;P('box',B,.1,1.5,.1,sx*(.6+.25*(i>>1)),1.3,.2-.5*(i>>1),g).rotation.z=sx*.25;}
  bMz(e,g,0,3.25,2.45);e.mb=e.mzs[0];e.mt=bMz(e,g,0,1.7,-.4);bCore(g,E,.8,0,3.15,1.72);e.cy=2.8;e.hy=3.15;}},
{t:'IL RAGNO DEL GELO',c:0xb4d0e4,c2:0x40607c,gl:0x60d0ff,amp:3,sw:.55,ls:3.4,cool:1.7,burst:10,mn:4,brl:'GELO — RIPARATI!',seq:()=>['breath','mortar','beam','gun'],
 b(e,g,A,B,E){for(const sx of[-1,1])for(const z of[-.9,0,.9]){const l=new THREE.Group();l.position.set(sx*1.1,1.5,z);g.add(l);const u=P('box',B,1.5,.2,.2,sx*.65,.35,0,l);u.rotation.z=sx*.55;const d=P('box',A,.18,1.9,.18,sx*1.45,-.25,0,l);d.rotation.z=-sx*.18;P('cone',E,.2,.4,.2,sx*1.62,-1.3,0,l).rotation.z=Math.PI;e.legs.push(l);}
  P('box',A,2.3,.8,2.8,0,1.5,0,g);P('box',B,1.7,.5,2.2,0,2.05,-.2,g);for(let i=0;i<6;i++){const c=P('cone',E,.3+.2*(i%3),.9+.5*(i%2),.3+.2*(i%3),-.7+.28*i,2.6+.15*(i%2),-.9+.25*(i%3),g);c.rotation.set(-.3,0,(i-2.5)*.14);}
  const c=P('cyl',B,.42,2.4,.42,0,2.35,1,g);c.rotation.x=Math.PI/2;P('tor',E,.95,.95,.8,0,2.35,2.15,g);P('tor',E,.8,.8,.8,0,2.35,1.4,g);e.mb=e.mf=bMz(e,g,0,2.35,2.3);for(const sx of[-1,1])bGun(e,g,A,sx*.95,1.55,1.2,.7,.14);e.mt=bMz(e,g,0,2.9,-.5);
  bCore(g,E,.7,0,1.5,1.42);e.cy=1.7;e.hy=1.5;}},
{t:'IL CUORE DEL REATTORE',c:0x5a2a1a,c2:0x241c1e,gl:0xff5a10,amp:1.5,sw:.28,ls:1.5,cool:1.9,rk:4,mn:4,brl:'FIAMME — RIPARATI!',seq:()=>['breath','mortar','rock','stomp'],
 b(e,g,A,B,E){bLegs(e,g,A,B,[[-.9,0],[.9,0]],1.1,.75);P('cyl',A,3.1,2.4,3.1,0,2.3,0,g);P('sph',B,3.1,1.4,3.1,0,3.5,0,g);for(const y of[1.4,2.3,3.2])P('tor',B,3.25,3.25,1.6,0,y,0,g).rotation.x=Math.PI/2;
  for(const[x,z,h]of[[-.8,-.5,1.5],[.8,-.5,1.5],[0,-1,2.1]]){P('cyl',B,.5,h,.5,x,3.9+h/2,z,g);P('cyl',E,.42,.06,.42,x,3.93+h,z,g);}
  for(const sx of[-1,1]){const c=P('cyl',B,.36,1.6,.36,sx*1.95,2.5,.8,g);c.rotation.x=Math.PI/2;P('cyl',E,.3,.06,.3,sx*1.95,2.5,1.62,g).rotation.x=Math.PI/2;bMz(e,g,sx*1.95,2.5,1.75);}e.mf=e.mzs[0];e.mt=bMz(e,g,0,6,-1);
  bCore(g,E,1.15,0,2.1,1.42);for(const x of[-.4,-.13,.13,.4])P('box',M.dark,.07,1.15,.07,x,2.1,1.8,g);e.cy=2.4;e.hy=2.1;}},
{t:'LA SENTINELLA DEL PONTE',c:0x1c2a4a,c2:0xb8962e,gl:0xffd040,amp:1.6,sw:.3,ls:1.8,cool:1.8,burst:14,rk:3,seq:()=>['gun','beam','rock','stomp'],
 b(e,g,A,B,E){bLegs(e,g,A,B,[[-.6,0],[.6,0]],1.9,.5);P('box',B,1.5,.4,.9,0,2.05,0,g);P('box',A,1.9,1.7,1.15,0,3.05,0,g);P('box',B,2.0,.12,1.2,0,3.5,0,g);for(const sx of[-1,1]){P('sph',B,1,.9,1,sx*1.25,3.85,0,g);P('cone',B,.3,.8,.3,sx*1.25,4.5,0,g);}
  P('box',A,.75,.8,.75,0,4.35,.05,g);P('box',E,.08,.5,.06,0,4.3,.44,g);P('box',E,.5,.08,.06,0,4.45,.44,g);P('cone',B,.25,.9,.25,0,5.1,0,g);
  e.sh=[];for(const sx of[-1,1]){const s=new THREE.Group();g.add(s);const p=P('box',A,1.35,2.9,.14,0,0,0,s);p.userData.shield=1;P('box',B,1.4,.14,.16,0,1.2,0,s).userData.shield=1;P('box',B,.14,2.9,.16,sx*.62,0,0,s).userData.shield=1;P('box',E,.3,.3,.02,0,.2,.09,s);s.userData.sx=sx;s.position.set(sx*.7,2.7,1.15);e.sh.push(s);}
  bGun(e,g,A,1.3,4.2,.2,1.5,.22);e.mb=bGun(e,g,B,-1.3,4.2,.2,1.2,.3);bCore(g,E,.75,0,3.1,.6);e.cy=3;e.hy=3.1;},
 anim(e,dt){const op=e.state==='idle'||e.state==='enter'?0:1;e.shk=(e.shk||0)+(op-e.shk)*Math.min(1,dt*5);for(const s of e.sh){s.position.x=s.userData.sx*(.7+1.6*e.shk);s.position.z=1.15-.7*e.shk;s.rotation.y=-s.userData.sx*.5*e.shk;}}},
{t:'IL CACCIA DI VARR',c:0xd8d8e4,c2:0x2a2a36,gl:0xff30c0,amp:3.2,sw:.9,ls:6.5,cool:1.2,burst:10,rk:4,swl:'LAMA — GIÙ',seq:()=>['rock','charge','gun','sweep','rock','sweep'],
 b(e,g,A,B,E){for(const sx of[-1,1]){const l=new THREE.Group();l.position.set(sx*.7,2,0);g.add(l);P('box',B,.34,1,.4,0,-.45,.2,l).rotation.x=-.5;P('box',A,.3,1.2,.36,0,-1.35,.05,l).rotation.x=.45;P('box',B,.42,.16,.9,0,-1.92,.2,l);e.legs.push(l);}
  P('box',B,1.2,.4,.8,0,2.1,0,g);const t=P('box',A,1.6,1.25,1.1,0,2.9,.05,g);t.rotation.x=.12;P('box',B,1.2,.5,1.4,0,3.1,-.75,g);for(const sx of[-1,1]){const f=P('box',A,.06,1.4,.9,sx*.5,3.9,-1.1,g);f.rotation.x=-.5;P('box',B,.85,.75,1,sx*1.3,3.5,-.1,g);for(const o of[[-.2,.15],[.2,.15],[-.2,-.15],[.2,-.15]])P('cyl',M.dark,.14,.1,.14,sx*1.3+o[0],3.5+o[1],.42,g).rotation.x=Math.PI/2;bMz(e,g,sx*1.3,3.5,.6);}
  const a=e.arm=new THREE.Group();a.position.set(1.05,2.9,.2);g.add(a);P('box',B,.22,.22,1,0,0,.5,a);P('box',A,.05,.3,2.4,0,0,2.1,a);P('box',E,.02,.06,2.4,0,-.17,2.1,a);a.rotation.x=.35;bGun(e,g,A,-1.05,2.8,.3,1.1,.16);
  bCore(g,E,.75,0,3.0,.58);P('box',E,.9,.05,.05,0,3.55,.58,g);e.cy=2.8;e.hy=3.0;}},
{t:'L\'ULTIMA ARMA DI KROSS',c:0x16161c,c2:0x7a5c12,gl:0xc050ff,sc:1.28,amp:2.2,sw:.3,ls:2.4,cool:1.6,burst:16,rk:4,mn:4,dn:3,brl:'PLASMA — RIPARATI!',
 seq(e){const k=e.hp/e.mhp,ph=k>.66?1:k>.33?2:3;if(ph!==e.ph){if(e.ph)toast('<b style="color:#c9f">Titano Zero cambia assetto!</b>',2600);e.ph=ph;e.ai=0;e.rage=ph===3;}return ph===1?['gun','rock','stomp']:ph===2?['beam','drones','mortar','charge']:['beam','charge','rock','breath','stomp'];},
 b(e,g,A,B,E){bLegs(e,g,A,B,[[-.8,0],[.8,0]],1.55,.62);P('box',B,1.9,.45,1.05,0,1.65,0,g);P('box',A,2.4,1.45,1.45,0,2.6,0,g);P('box',B,2.5,.14,1.5,0,2.2,0,g);P('box',B,2.1,.3,1.55,0,3.4,0,g);P('box',A,.75,.5,.65,0,3.82,.1,g);P('box',E,.55,.09,.05,0,3.84,.44,g);
  for(let i=0;i<5;i++){const c=P('cone',B,.14,.5+.2*(i===2),.14,-.3+.15*i,4.25+.1*(i===2),.05,g);}
  for(const sx of[-1,1]){P('box',A,.66,.66,1.7,sx*1.6,2.7,.25,g);bGun(e,g,B,sx*1.6,2.7,1.05,.8,.3);P('box',B,.8,.5,.9,sx*1.25,3.75,-.2,g);const c=P('cyl',M.dark,.3,1.5,.3,sx*1.25,3.95,.4,g);c.rotation.x=Math.PI/2;}
  e.mb=e.mf=bMz(e,g,0,2.6,.85);e.mt=bMz(e,g,-1.25,3.95,1.2);e.ring=P('tor',B,3.6,3.6,1.6,0,3,-.95,g);bCore(g,E,.9,0,2.6,.68);e.cy=2.5;e.hy=2.6;}}];
BUILD.mech=function(e,T,ci){ci=ci===undefined?(G?chI(G.L):0):ci;const B=e.B=BOSS[ci],A=bMat(B.c),C=bMat(B.c2,.6,.5),E=bEm(B.gl),g=e.g=new THREE.Group();e.root.add(g);e.mats=[A,C];e.legs=[];e.mzs=[];B.b(e,g,A,C,E);const s=B.sc||1;g.scale.setScalar(s);e.cy*=s;e.hy*=s;e.mz=e.mzs[0];};
function bLas(e,w,p1){const p0=e.mz.getWorldPosition(TV);e.las.visible=true;seg(e.las,p0,p1||TV2.set(0,1.3,G.cz-1.1).lerp(p0,.45),w);}
function bQ(e,r,dir,lab,defer){if(e.qs||r>.5)return;e.qs=1;if(qteStart(dir,Math.max(.2,r),()=>{e.dod=1;},defer,lab)){e.dod=0;G.qte.own=e;G.qte.src=e.root.position;}else e.dod=1;}
const BATK={
 gun:{T:1.15,init(e){e.mz=e.mzs[rnd(e.mzs.length)];},tele(e){bLas(e,.02);},start(e){e.burst=e.B.burst||12;e.bt=0;e.shotN=0;},act(e,dt){e.bt-=dt;if(e.bt<=0){if(e.burst<=0)return true;e.atk=0;eShoot(e);e.burst--;e.shotN++;e.bt=.09;}return false;}},
 rock:{T:.8,init(e){e.mz=e.mzs[rnd(e.mzs.length)];},start(e){e.burst=e.B.rk||3;e.bt=0;},act(e,dt){e.bt-=dt;if(e.bt<=0){if(e.burst<=0)return true;e.mz=e.mzs[e.burst%e.mzs.length];eProj('rock',e.mz.getWorldPosition(new V3()),e);e.burst--;e.bt=.45;}return false;}},
 drones:{T:.9,tele(e){if(Math.random()<.3){ePos(e,TV,true);glow(TV,2.5,e.B.gl,.3,2);}},start(e){for(let i=0;i<(e.B.dn||2);i++){const d=spawnE('drone',null,new V3(e.root.position.x+rr(-2,2),rr(3,4.2),e.root.position.z+.5));d.cnt=false;}},act(){return true;}},
 stomp:{T:1.5,init(e){e.lock=1;e.dod=0;e.qs=0;},tele(e,dt,k){bQ(e,e.tele,'U','ONDA D\'URTO — SALTA',false);e.g.position.y=.5*k*k;if(e.legs[0])e.legs[0].rotation.x=-.9*k;},
  start(e){if(G.qte&&G.qte.own===e)qteEnd(false);e.g.position.y=0;G.shake=.9;snd('boom');for(let i=1;i<=3;i++){TV.set(0,.3,e.root.position.z+(G.cz-e.root.position.z)*i/3.2);glow(TV,5+i,e.B.gl,.35+.1*i,4);}TV.set(0,.4,-3);bits(TV,14,M.spark,6,.05,.6);if(!e.dod)hurt(18*G.ds,true);},act(){return true;}},
 charge:{T:1.25,init(e){e.lock=1;e.qd=rnd(2)?'L':'R';e.dod=0;e.qs=0;e.cp=0;},tele(e,dt,k){const p=e.root.position;p.x+=clamp(-p.x,-5*dt,5*dt);e.g.rotation.x=.22*k;if(e.legs[1])e.legs[1].rotation.x=Math.sin(e.an*14)*.5;},start(){snd('rocket');},
  act(e,dt,pz){const p=e.root.position;if(!e.cp){bQ(e,(pz-3.4-p.z)/21,e.qd,'CARICA — SCHIVA',true);p.z+=21*dt;if(Math.random()<.5){TV.set(p.x+rr(-1,1),.2,p.z-1);bits(TV,2,M.spark,3,.04,.3);}if(p.z>=pz-3.4){e.cp=1;e.g.rotation.x=0;if(G.qte&&G.qte.own===e)qteEnd(false);if(e.dod)startDodge(e.qd);else hurt(24*G.ds,true);G.shake=1;snd('crash');TV.set(0,1,pz-1.2);bits(TV,16,M.spark,6,.05,.5);}return false;}
   p.z-=4.6*dt;e.legs.forEach((l,i)=>l.rotation.x=Math.sin(e.an*6+i*Math.PI)*.35);return p.z<=pz-13;}},
 sweep:{T:1.3,init(e){e.lock=1;e.dod=0;e.qs=0;e.cp=0;},
  tele(e,dt,k,pz){bQ(e,e.tele,'D',e.B.swl||'COLPO — GIÙ',true);const p=e.root.position;p.x+=clamp(.9-p.x,-6*dt,6*dt);p.z+=clamp(pz-5.2-p.z,-9*dt,9*dt);if(e.arm){e.arm.rotation.y=-1.5*k;e.arm.rotation.x=-.15;}e.legs.forEach((l,i)=>l.rotation.x=Math.sin(e.an*9+i*Math.PI)*.35);},
  start(e){if(G.qte&&G.qte.own===e)qteEnd(false);if(e.dod)startDodge('D');else hurt(20*G.ds,true);G.shake=.8;snd('crash');e.sw=0;},
  act(e,dt,pz){e.sw+=dt;if(e.arm)e.arm.rotation.y=-1.5+Math.min(1,e.sw/.22)*3;if(e.sw<.55)return false;const p=e.root.position;p.z-=5.5*dt;e.legs.forEach((l,i)=>l.rotation.x=Math.sin(e.an*7+i*Math.PI)*.35);if(p.z<=pz-13){if(e.arm){e.arm.rotation.y=0;e.arm.rotation.x=.4;}return true;}return false;}},
 beam:{T:1.7,init(e){e.mz=e.mb||e.mzs[0];G.warn=1.75;G.warnTxt='RAGGIO — RIPARATI!';snd('tele');},tele(e,dt,k){bLas(e,.012);if(Math.random()<.4){e.mz.getWorldPosition(TV2);glow(TV2,.6+1.6*k,e.B.gl,.12,2);}},start(e){snd('esnipe');snd('zap');e.bt=0;},
  act(e,dt){const x=Math.sin(e.st*7)*1.1;TV2.set(x,1.02,G.cz-.95);bLas(e,.11,TV2);if(Math.random()<.7)bits(TV2,2,M.spark,3,.04,.3);glow(TV2,.9,e.B.gl,.1,2);G.shake=Math.max(G.shake,.25);e.bt-=dt;if(e.bt<=0){e.bt=.15;hurt(8*G.ds);}return e.st>.95;}},
 mortar:{T:.9,init(e){e.mz=e.mt||e.mzs[0];},start(e){e.burst=e.B.mn||3;e.bt=0;},act(e,dt){e.bt-=dt;if(e.bt<=0){if(e.burst<=0)return true;eProj('gren',e.mz.getWorldPosition(new V3()),e);const pr=G.eproj[G.eproj.length-1];pr.lab='COLPO IN ARRIVO — SCHIVA';const m=P('sph',bEm(e.B.gl,3),.5,.5,.5,0,0,0,pr.m);m.userData.proj=pr;e.burst--;e.bt=.6;}return false;}},
 breath:{T:1.25,init(e){e.mz=e.mf||e.mzs[0];G.warn=1.3;G.warnTxt=e.B.brl||'FIAMME — RIPARATI!';snd('tele');},tele(e,dt,k){if(Math.random()<.5){e.mz.getWorldPosition(TV2);glow(TV2,.5+k,e.B.gl,.15,2);}},start(e){e.bt=0;snd('rocket');},
  act(e,dt){const a=e.mz.getWorldPosition(TV);for(let i=0;i<2;i++){const t=Math.random();TV2.set(rr(-1.5,1.5),rr(.9,1.6),G.cz-.8).lerp(a,1-t);glow(TV2,.6+2.2*t,e.B.gl,.3,2.5);}if(Math.random()<.2)glow(TV2,1.5,0xfff0d0,.12,3);G.shake=Math.max(G.shake,.15);e.bt-=dt;if(e.bt<=0){e.bt=.25;hurt(6.5*G.ds);if(Math.random()<.4)snd('whiz');}return e.st>2.2;}}};
function updBoss(e,dt,fight,pz){const r=e.root,p=r.position,B=e.B,home=pz-13;e.an+=dt;e.las.visible=false;if(B.anim)B.anim(e,dt);
 if(e.ring)e.ring.rotation.z+=dt*(B.hov?2.2:.8);if(e.wings)for(const w of e.wings)w.rotation.z=Math.sin(e.an*38)*.35;if(B.hov)e.g.position.y=.55+Math.sin(e.an*1.7)*.3;
 if(e.state==='enter'){if(p.z<home-.2){p.z+=2*dt;e.legs.forEach((l,i)=>l.rotation.x=Math.sin(e.an*4+i*Math.PI)*.4);}else{e.state='idle';e.st=1.3;}r.rotation.y=Math.atan2(-p.x,pz-p.z);return;}
 if(!e.lock){const tx=Math.sin(e.an*B.sw)*B.amp;p.x+=clamp(tx-p.x,-B.ls*dt,B.ls*dt);p.z+=clamp(home-p.z,-3*dt,3*dt);e.legs.forEach((l,i)=>l.rotation.x=Math.sin(e.an*(B.ls>3?5:2.2)+i*Math.PI)*.25);}
 r.rotation.y=Math.atan2(-p.x,pz-p.z);
 switch(e.state){
  case'idle':e.st-=dt;if(e.st<=0&&fight){const q=B.seq(e);e.at=q[(e.ai||0)%q.length];e.ai=(e.ai||0)+1;const A=BATK[e.at];e.state='tele';e.tele=e.teleT=A.T*(e.rage?.85:1);if(A.init)A.init(e);else snd('tele');}break;
  case'tele':{const A=BATK[e.at];e.tele-=dt;if(A.tele)A.tele(e,dt,1-Math.max(0,e.tele)/e.teleT,pz);if(e.tele<=0){e.state='act';e.st=0;if(A.start)A.start(e,pz);}break;}
  case'act':e.st+=dt;if(BATK[e.at].act(e,dt,pz)){e.state='idle';e.lock=0;e.st=B.cool*rr(.8,1.2)*(e.rage?.65:1);}break;}}
