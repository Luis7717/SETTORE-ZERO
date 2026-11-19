// Settore Zero — corridoi procedurali: curve, rampe, pericoli
'use strict';
/* ===== corridoi procedurali: curve, rampe, pericoli leggibili ===== */
const CWC=[0x8c9aa6,0xa9b8b4,0x8a6c5a,0x5c7a52,0x8fb2c8,0x7c8cb4,0x72798c,0x8c8676,0x6c5c8e],CM={},CW=2.6,CHT=4.2,PA={x:0,z:0,dx:0,dz:-1};
function corrM(ci){return CM[ci]||(CM[ci]={w:pMat(CWC[ci],.62,.35),f:pMat(0x40454d,.7,.45),c:pMat(0x24272c,.8,.3),r:pMat(0x1a1d22,.5,.65),s:pMat(0x8a9098,.35,.9),e:bEm(BOSS[ci].gl,1.7),e2:bEm(0xfff2d8,1.25)});}
function nsh(q){q.castShadow=false;return q;}
function PM(geo,mat,sx,sy,sz){const q=new THREE.Mesh(GEO[geo],mat);q.scale.set(sx,sy,sz);q.castShadow=true;return q;}
function corrPiece(cg,A,yaw,len,y0,y1,m,i0){const g=new THREE.Group();g.position.set(A[0],0,A[1]);g.rotation.y=yaw;cg.add(g);const n=Math.max(1,Math.round(len/2.6)),tl=len/n,dy=y1-y0,pit=Math.atan2(dy,len),hh=CHT+Math.abs(dy)+.5;
 for(let i=0;i<n;i++){const t=(i+.5)/n,z=-t*len,y=y0+dy*t;nsh(P('box',m.f,CW*2,.3,tl+.04,0,y-.15,z,g)).rotation.x=pit;nsh(P('box',m.c,CW*2,.3,tl+.04,0,y+CHT+.15,z,g)).rotation.x=pit;
  for(const sx of[-1,1]){nsh(P('box',m.w,.3,hh,tl,sx*(CW+.15),(y0+y1)/2+CHT/2,z,g));nsh(P('box',m.e,.05,.05,tl*.8,sx*(CW-.06),y+.07,z,g)).rotation.x=pit;nsh(R_(m.r,.14,.5,tl,sx*(CW-.05),y+1.15,z,g)).rotation.x=pit;}
  if((i+i0)%2===0){for(const sx of[-1,1])nsh(R_(m.r,.34,CHT,.34,sx*(CW-.17),y+CHT/2,z,g));nsh(R_(m.r,CW*2,.32,.34,0,y+CHT-.16,z,g));}else nsh(P('box',m.e2,1.5,.05,.34,0,y+CHT-.03,z,g)).rotation.x=pit;
  nsh(C_(m.s,.16,tl+.04,-(CW-.32),y+3.45,z,g,'z')).rotation.x=Math.PI/2+pit;nsh(C_(m.r,.1,tl+.04,CW-.3,y+3.6,z,g,'z')).rotation.x=Math.PI/2+pit;}}
function corrCorner(cg,C,yaw,s,y,m){const g=new THREE.Group(),a=CW*2;g.position.set(C[0],0,C[1]);g.rotation.y=yaw;cg.add(g);nsh(P('box',m.f,a,.3,a,0,y-.15,0,g));nsh(P('box',m.c,a,.3,a,0,y+CHT+.15,0,g));
 nsh(P('box',m.w,a+.6,CHT+.5,.3,0,y+CHT/2,-(CW+.15),g));nsh(P('box',m.w,.3,CHT+.5,a,-s*(CW+.15),y+CHT/2,0,g));nsh(R_(m.r,.42,CHT,.42,s*(CW-.2),y+CHT/2,CW-.2,g));nsh(R_(m.r,.42,CHT,.42,-s*(CW-.2),y+CHT/2,-(CW-.2),g));nsh(P('box',m.e2,1.5,.05,1.5,0,y+CHT-.03,0,g));
 for(let i=0;i<3;i++)for(const d of[-1,1]){const c=nsh(P('box',m.e,.09,.62,.05,s*(-1+i*.95),y+2.1+d*.2,-(CW-.02),g));c.rotation.z=s*d*.78;}}
function doorWall(g,z,s,y,m){for(const sx of[-1,1])nsh(P('box',m.w,CW-1.45+.3,CHT+.5,.3,sx*(1.45+(CW-1.45+.3)/2),y+CHT/2,z,g));nsh(P('box',m.w,2.9,CHT-3.3+.5,.3,0,y+3.3+(CHT-3.3+.5)/2,z,g));for(const sx of[-1,1])nsh(R_(m.r,.14,3.4,.2,sx*1.5,y+1.7,z+s*.18,g));nsh(R_(m.r,3.14,.14,.2,0,y+3.37,z+s*.18,g));
 const dg=new THREE.Group();dg.position.y=y;g.add(dg);return mkDoor(dg,z,s);}
function pathDist(P,x,z){let best=1e9,bd=0,acc=0;for(let i=1;i<P.length;i++){const ax=P[i-1][0],az=P[i-1][1],dx=P[i][0]-ax,dz=P[i][1]-az,l2=dx*dx+dz*dz,t=l2?clamp(((x-ax)*dx+(z-az)*dz)/l2,0,1):0,d=Math.hypot(x-ax-dx*t,z-az-dz*t),l=Math.sqrt(l2);if(d<best){best=d;bd=acc+l*t;}acc+=l;}return bd;}
function runY(st,s){const a=st.ys;if(!a)return 0;for(let i=1;i<a.length;i++)if(s<=a[i][0]){const l=a[i][0]-a[i-1][0];return l>1e-4?a[i-1][1]+(a[i][1]-a[i-1][1])*clamp((s-a[i-1][0])/l,0,1):a[i][1];}return a[a.length-1][1];}
const HZN={laserU:'LASER',laserD:'LASER',barrel:'BARILE ESPLOSIVO',brute:'MAZZATA',automa:'PUGNO',rocket:'RAZZO',drone:'DRONE',gap:'VORAGINE',beam:'TRAVE CADUTA',pipe:'TUBO',shut:'SARACINESCA'},DZM=new THREE.MeshBasicMaterial({color:0xff2020,transparent:true,opacity:.4,depthWrite:false});
function hl(h,o,x,y,z,ry){o.position.set(x,y,z);if(ry!==undefined)o.rotation.y=ry;h.g.add(o);return o;}
function hw(h,x,y,z){return h.g.localToWorld(new V3(x,y,z));}
function hzLas2(h,ys,ph){for(const y of ys)nsh(hl(h,PM('box',M.doorL,5,.07,.07),0,y,0));for(const sx of[-1,1])hl(h,box(.3,ph,.3,M.dark,0,0,0),sx*2.42,ph/2,0);h.src=new V3(0,ys[0],0);}
const HV=new V3(),sms=x=>x*x*(3-2*x);let PUNK=.75;function pwl(a,x){if(x>=a[0][0])return a[0][1];for(let i=1;i<a.length;i++)if(x>=a[i][0]){const t=(x-a[i][0])/(a[i-1][0]-a[i][0]);return a[i][1]+(a[i-1][1]-a[i][1])*t;}return a[a.length-1][1];}
const HZ2={
 laserU:{snd:'zap',b(h){hzLas2(h,[.38],.7);}},laserD:{snd:'zap',b(h){hzLas2(h,[1.5,1.78],2.1);}},
 beam:{b(h){const b=hl(h,box(5.1,.42,.5,M.steel,0,0,0,1),0,.21,0);b.rotation.z=.02;for(const sx of[-1.7,1.4])hl(h,box(rr(.5,.9),.3,rr(.5,.8),M.mcrate,0,0,0),sx,.56,rr(-.1,.1),rr(0,1));h.src=new V3(0,.4,0);}},
 pipe:{b(h){const b=hl(h,box(5.1,.34,.5,M.steel,0,0,0,1),0,1.68,0);b.rotation.z=-.05;for(const sx of[-1.6,.4,1.8])hl(h,PM('box',M.dark,.05,rr(.4,.9),.05),sx,1.25,0);h.src=new V3(0,1.7,0);}},
 gap:{b(h){nsh(hl(h,box(5.2,.05,1.7,M.hole0,0,0,0),0,.03,0));for(const dz of[-.88,.88])nsh(hl(h,PM('box',dmat('lava',0xff6a10,{emissiveIntensity:2.2}),5.2,.05,.09),0,.05,dz));for(const sx of[-2.35,2.35])hl(h,box(.4,.5,1.9,M.hazard,0,0,0),sx,.25,0);h.src=new V3(0,.15,0);},t(h,k,dt){if(Math.random()<dt*9)bits(hw(h,rr(-2,2),.1,rr(-.7,.7)),2,M.spark,3,.03,.4);}},
 shut:{b(h){const g=h.pan=new THREE.Group();g.add(box(5.2,3.2,.22,M.door,0,0,0,2),box(5.2,.2,.26,M.hazard,0,-1.6,0,2));hl(h,g,0,4.75,0);for(const sx of[-1,1])hl(h,box(.3,4.2,.5,M.dark,0,0,0),sx*2.45,2.1,0);h.src=new V3(0,2.6,0);},on(){snd('metal');},t(h,k){h.pan.position.y=4.75-1.75*Math.min(1,k);h.src.y=h.pan.position.y-1.5;},end(h){h.pan.position.y=2.2;}},
 barrel:{hd:1,b(h){const bx=h.bx=h.side*1.75;if(MODELS.bar)for(const o of[[0,0],[h.side*.5,-.7]]){const v=noRay(MODELS.bar.scene.clone(true));v.scale.setScalar(.0132);hl(h,v,bx+o[0],0,o[1]);}h.lamp=nsh(hl(h,PM('sph',M.doorL,.24,.24,.24),bx,1.25,0));h.src=new V3(bx,1,0);},t(h,k,dt,d){h.lamp.visible=!h.bm&&Math.sin(G.t*(14+26*Math.min(1,k)))>0;if(!h.bm&&d<1.05){h.bm=1;explode(hw(h,h.bx,1,0),3,0);}}},
 brute:{hd:1.4,snd:'crash',b(h){const d=h.dm=mkDummy('brute'),x=h.side*1.2;hl(h,d.root,x,0,-.5,0);const c=h.club=new THREE.Group();c.rotation.order='YXZ';P('box',M.dark,.09,.09,2.5,0,0,1.05,c);P('box',M.hazard,.115,.115,.34,0,0,.1,c);P('box',M.steel,.4,.4,.52,0,0,2.2,c);
   for(const q of[[0,.32,0],[0,-.32,Math.PI],[.32,0,-Math.PI/2],[-.32,0,Math.PI/2]]){const sp=P('cone',M.steel,.17,.26,.17,q[0],q[1],2.2,c);sp.rotation.z=q[2];}c.traverse(o=>{if(o.isMesh){o.castShadow=true;o.raycast=()=>{};}});hl(h,c,x,1.5,-.2);h.src=new V3(x,1.9,-.5);HZ2.brute.pose(h,0,-.62,.016);},
  pose(h,th,p,dt){const d=h.dm,c=h.club,b=d.bn;d.root.rotation.y=th;poseH(d,0,0,dt);if(b&&b.RightArm&&b.RightHand){const y=Math.sin(p),z=Math.cos(p);aimBone(b.RightArm,-.2,y,z,1);aimBone(b.RightForeArm,.14,y,z,1);aimBone(b.LeftArm,.2,y,z,1);aimBone(b.LeftForeArm,-.14,y,z,1);d.root.updateMatrixWorld(true);b.RightHand.getWorldPosition(TV);b.LeftHand.getWorldPosition(HV);TV.add(HV).multiplyScalar(.5);h.g.worldToLocal(TV);c.position.copy(TV);}
   c.rotation.set(-p,th,0);h.src.set(c.position.x+Math.sin(th)*Math.cos(p)*2.2,c.position.y+Math.sin(p)*2.2,c.position.z+Math.cos(th)*Math.cos(p)*2.2);},
  on(){snd('metal');},idle(h,dt){HZ2.brute.pose(h,0,-.62,dt);},
  t(h,k,dt,d){const sd=h.side,q=sms(Math.min(1,k));let th,p;if(d>=1.9){th=sd*.55*q;p=mix(-.62,1.15,q);}else{const u=clamp((1.9-d)/1.5,0,1);th=sd*mix(.55,-3.4,u);p=mix(1.15,-.3,clamp(u*4,0,1));if(d<.55){p=mix(-.3,-.7,clamp((.55-d)/.3,0,1));if(!h.slam&&d<.28){h.slam=1;snd('metal');G.shake=Math.max(G.shake,.35);bits(hw(h,h.src.x,.1,h.src.z),10,M.spark,5,.04,.5);}}
    if(!h.wsh&&u>.15){h.wsh=1;snd('throw');}}HZ2.brute.pose(h,th,p,dt*(G.mv&&G.mv.ts||1));}},
 automa:{hd:.75,snd:'crash',b(h){const d=h.dm=mkDummy('automa');hl(h,d.root,h.side*.95,0,-4.8,0);h.src=new V3(h.side*.4,1.4,-4.8);if(d.act&&d.act.Running){d.act.Running.play();d.act.Running.setEffectiveWeight(0);}},
  on(h){snd('metal');const d=h.dm;if(d.act){const p=d.act.Punch;p.reset();p.play();p.paused=true;p.setEffectiveWeight(0);}},idle(h,dt){if(h.dm.mx)h.dm.mx.update(dt);},
  t(h,k,dt,d){const dm=h.dm,z=d>=1.9?mix(-4.8,-1,Math.min(1,k)):pwl([[1.9,-1],[.5,-.15],[-.8,.9],[-2.6,3]],d);dm.root.position.z=z;h.src.z=z;
   if(dm.act){const a=dm.act,pk=clamp((2.7-d)/2.1,0,1);a.Running.setEffectiveWeight(1);a.Idle.setEffectiveWeight(0);a.Walking.setEffectiveWeight(0);a.Punch.setEffectiveWeight(pk>0?6:0);a.Punch.paused=true;a.Punch.time=a.Punch.getClip().duration*Math.min(.98,pk*PUNK);dm.mx.update(dt*(G.mv&&G.mv.ts||1)*1.4);}}},
 rocket:{hd:.8,b(h){const d=h.dm=mkDummy('turret');hl(h,d.root,h.side*1.7,0,-3.7,-h.side*.4);h.src=new V3(h.side*1.7,1.1,-3.7);},on(h){const m=h.rk=new THREE.Group(),c=P('cyl',M.steel,.18,.7,.18,0,0,0,m);c.rotation.x=Math.PI/2;P('sph',M.doorL,.19,.19,.19,0,0,.36,m);for(let i=0;i<4;i++){const f=P('box',M.dark,.3,.02,.2,0,0,-.3,m);f.rotation.z=i*Math.PI/4;}hl(h,m,h.side*1.5,1.1,-3);snd('rocket');glow(hw(h,h.side*1.5,1.1,-3),1.4,0xffb060,.15,3);},
  t(h,k,dt,d){if(h.gone||!h.rk)return;const m=h.rk,q=Math.min(1,k),z=d>=1.9?mix(-3,-.4,q):pwl([[1.9,-.4],[.8,.55],[-1,3.4]],d);m.position.set(h.side*mix(1.5,.2,Math.min(1,q*1.25)),mix(1.1,1.42,q),z);m.rotation.z+=dt*9;m.rotation.y=-h.side*.45*(1-q);h.src.copy(m.position);if(Math.random()<.7)glow(hw(h,m.position.x,m.position.y,z-.45),.5,0xffa040,.3,2);if(d<-1){h.gone=1;explode(hw(h,m.position.x,m.position.y,z),2.6,0);h.g.remove(m);}},
  end(h){if(!h.ok&&h.rk&&!h.gone){h.gone=1;explode(hw(h,h.rk.position.x,h.rk.position.y,h.rk.position.z),2.6,0);h.g.remove(h.rk);}}},
 drone:{hd:.9,b(h){const d=h.dm=mkDummy('drone');hl(h,d.root,0,2.7,-5,0);h.src=new V3(0,2.7,-5);},on(){snd('tele');},idle(h,dt){for(const r of h.dm.rot)r.rotation.y+=dt*40;h.dm.root.position.y=2.7+Math.sin(G.t*3)*.15;},
  t(h,k,dt,d){const dm=h.dm;if(h.gone)return;for(const r of dm.rot)r.rotation.y+=dt*46;const q=Math.min(1,k),z=d>=1.9?mix(-5,-.6,q):pwl([[1.9,-.6],[.9,.6],[.3,1.5],[-1.2,3.6]],d);h.src.set(0,mix(2.7,1.52,Math.min(1,q*1.15)),z);dm.root.position.copy(h.src);dm.root.rotation.x=.55;
   if(d<-1.2){h.gone=1;explode(hw(h,0,1.5,z),2,0);dm.root.visible=false;}},end(h){if(!h.ok&&!h.gone){h.gone=1;explode(hw(h,h.src.x,h.src.y,h.src.z),2,0);h.dm.root.visible=false;}}},
 lock:{b(){}}};
function buildRun(st,L){const ci=chI(L),m=corrM(ci),rk=st.rk,esc=rk==='e'||rk==='m',rg=st.rg=new THREE.Group(),cg=new THREE.Group();rg.add(cg);
 st.pose={x:0,z:0,th:0,i:0,o:1};st.pc=1;st.cob=[];st.obs=[];st.c2r=st.r2c=(x,z)=>[x,z];st.put=(o,x,y,z,ry)=>{o.position.set(x,y,z);o.rotation.y=ry||0;rg.add(o);return o;};st.hit=()=>false;st.ok=()=>true;st.los=()=>true;st.depth=20;st.haz=[];
 const nh=esc?2:3,pcs=[],pool=HZP[rk].slice(),ypt=[[0,0,0]],P_=[[0,esc?-1:0]];for(let i=0;i<nh;i++){pcs.push({len:i===0&&esc?19.5:14.5,hz:1});if(i<nh-1&&rnd(3)>0)pcs.push({len:9.5,dy:(rnd(2)?1:-1)*rr(1.3,1.8)});}
 let x=0,z=0,y=0,yaw=0,lt=0,cnt=0;const sg=new THREE.Group();rg.add(sg);st.door0=doorWall(sg,1.9,-1,0,m);nsh(P('box',m.f,CW*2,.3,2,0,-.15,1,sg));nsh(P('box',m.c,CW*2,.3,2,0,CHT+.15,1,sg));for(const sx of[-1,1])nsh(P('box',m.w,.3,CHT+.5,2,sx*(CW+.15),CHT/2,1,sg));
 pcs.forEach((pc,i)=>{const fx=-Math.sin(yaw),fz=-Math.cos(yaw),first=i===0,last=i===pcs.length-1,a0=first?0:CW,a1=last?0:CW,y1=y+(pc.dy||0);corrPiece(cg,[x+fx*a0,z+fz*a0],yaw,pc.len-a0-a1,y,y1,m,i);ypt.push([x+fx*a0,z+fz*a0,y],[x+fx*(pc.len-a1),z+fz*(pc.len-a1),y1]);
  if(!pc.dy)for(let k=0;k<2;k++){const dd=rr(a0+1,pc.len-a1-1),sx=rnd(2)?1:-1,hd=first&&esc?15.6:8.6;if(pc.hz&&Math.abs(dd-hd)<3.4||first&&dd<3)continue;const c=box(.95,.95,.95,rnd(2)?M.mcrate:M.wood,0,0,0,1);c.castShadow=true;st.put(c,x+fx*dd-fz*sx*1.95,y+.475,z+fz*dd+fx*sx*1.95,yaw+rr(-.3,.3));if(rnd(2)){const c2=box(.6,.55,.6,M.mcrate,0,0,0,1);st.put(c2,x+fx*dd-fz*sx*1.95,y+1.22,z+fz*dd+fx*sx*1.95,yaw+rr(0,1));}}
  if(pc.hz){const d=first&&esc?15.6:8.6,last2=st.haz.length===nh-1;let k=rnd(pool.length);let kind=pool.splice(k,1)[0];if((rk==='c'||rk==='q')&&last2)kind='lock';const side=rnd(2)?1:-1,g=new THREE.Group();g.position.set(x+fx*d,y,z+fz*d);g.rotation.y=yaw;rg.add(g);
   const h={st,g,kind,side,dir:HZD[kind]||(side>0?'L':'R'),s:0,ok:0,lab:HZL[kind],nm:HZN[kind],px:x+fx*d,pz:z+fz*d};st.haz.push(h);HZ2[kind].b(h);if(kind!=='lock')h.dzm=nsh(hl(h,PM('box',DZM,4.9,.02,.55),0,.04,.9));if(h.dzm)h.dzm.visible=false;}
  x+=fx*pc.len;z+=fz*pc.len;y=y1;
  if(!last){let t=rnd(2)?1:-1;if(t===lt){if(++cnt>2){t=-t;cnt=1;}}else cnt=1;lt=t;corrCorner(cg,[x,z],yaw,t,y,m);P_.push([x-fx*1.25,z-fz*1.25]);yaw-=t*Math.PI/2;P_.push([x-Math.sin(yaw)*1.25,z-Math.cos(yaw)*1.25]);}
  else{P_.push([x-fx*1.9,z-fz*1.9]);const eg=new THREE.Group();eg.position.set(x,0,z);eg.rotation.y=yaw;rg.add(eg);st.door=doorWall(eg,0,1,y,m);const lk=st.haz.find(h=>h.kind==='lock');
   if(lk){lk.pn=nsh(P('box',M.doorL,.6,.6,.1,0,y+1.7,.34,eg));eg.updateMatrixWorld(true);lk.tp=eg.localToWorld(new V3(0,y+1.7,.4));lk.px=x-fx*5.6;lk.pz=z-fz*5.6;}}});
 bake(cg);for(const h of st.haz)h.sd=pathDist(P_,h.px,h.pz);st.ys=ypt.map(q=>[pathDist(P_,q[0],q[1]),q[2]]).sort((a,b)=>a[0]-b[0]);st.inP=st.outP=P_;}
function runHaz(m,sp,dt){const rs=G.stages[G.si],esc=rs.rk==='e'||rs.rk==='m',tot=m.tot||(m.tot=pathLen(m.P)),s=clamp(m.t,0,1)*tot;G.py=runY(rs,s);if(esc&&!(m.lb>0))escFx(dt);let slow=0;G.lookT=null;
 for(let hi=0;hi<rs.haz.length;hi++){const h=rs.haz[hi],Z=HZ2[h.kind],pv=hi?rs.haz[hi-1]:null,d=h.sd-s;
  if(!h.s){if(Z.idle)Z.idle(h,dt);if(!(m.lb>0)&&(!pv||pv.s>=2)){
    if(h.kind==='lock'){if(d<.2&&qteStart('T',3,()=>{h.ok=1;},true,h.lab)){h.s=1;m.hold=1;G.qte.pos=h.tp;rs.door.o=0;sub((rs.rk==='q'?'KROSS':'VARR')+':Porta sigillata. Addio, agente.',2600);}}
    else if(d<6.4&&qteStart(h.dir,clamp((d-1.9)/(sp*.34),1,2.4),()=>{h.ok=1;},true,' ')){h.s=1;h.d0=d;h.w=new V3();G.qte.src=h.w;G.qte.h=h;G.qte.nm=h.nm;if(Z.on)Z.on(h);}}}
  if(h.kind==='lock'){if(h.s===1){h.pn.visible=Math.sin(G.t*14)>-.3;if(!G.qte){h.s=3;m.hold=0;rs.door.o=1;h.pn.visible=false;if(h.ok)explode(h.tp.clone(),1.5,0);else{hurt(14*G.ds,true);G.shake=.6;snd('zap');}}}continue;}
  if(h.s>=1&&h.s<4){if(Z.t)Z.t(h,clamp(1-(d-1.9)/Math.max(.1,h.d0-1.9),0,1.6),dt,d);h.w.copy(h.src);h.g.localToWorld(h.w);h.dzm.visible=h.s===1&&Math.sin(G.t*16)>-.2;}
  if((h.s===1||h.s===2)&&d>.75)G.lookT=h.w;if(h.s===2&&Z.t&&d>-.4)slow=Math.max(slow,.5);
  if(h.s===1){if(G.qte&&G.qte.h===h)slow=1;if(d<1.9){h.s=2;if(G.qte&&G.qte.h===h)qteEnd(false);if(h.ok){snd('throw');G.inv=Math.max(G.inv,.75);}if(Z.pass)Z.pass(h);}}
  if(h.s>=2&&h.s<4&&h.ok)G.dg={dir:h.dir,man:1,k:h.dir==='U'?Math.sin(Math.PI*clamp((1.9-d)/3.6,0,1)):sms(clamp((1.9-d)/1,0,1))*(1-sms(clamp((-.7-d)/1.2,0,1)))};
  if(h.s===2&&d<(Z.hd||0)){h.s=3;h.dzm.visible=false;if(!h.ok){hurt(16*G.ds,true);G.shake=.7;snd(Z.snd||'crash');}if(Z.end)Z.end(h);if(state!=='play')return;}
  if(h.s===3&&d<-2.6){h.s=4;if(G.dg&&G.dg.man)G.dg=null;}}
 const ts=m.ts===undefined?1:m.ts;m.ts=ts+((slow>=1?.3:slow?.62:1)-ts)*Math.min(1,dt*(slow?7:3.5));
 if(tot-s<5.5&&!rs.haz.some(h=>h.kind==='lock'&&h.s<3))rs.door.o=1;}
function escFx(dt){G.fxT=(G.fxT||0)-dt;G.shake=Math.max(G.shake,.2);if(G.fxT<=0){G.fxT=rr(.3,.55);const l=Math.hypot(PP.dx,PP.dz)||1,fx=PP.dx/l,fz=PP.dz/l,d=rr(6,11),sx=rnd(2)?1:-1,o=sx*rr(.8,2.1),y=G.py||0;TV.set(G.px+fx*d-fz*o,y+rr(3,3.9),G.pz+fz*d+fx*o);bits(TV,5,rnd(2)?M.scrap:M.spark,2.5,.09,1.1);
  if(rnd(3)===0){TV.set(G.px+fx*d-fz*sx*2.4,y+rr(1,3),G.pz+fz*d+fx*sx*2.4);glow(TV,rr(2,3.4),0xff8030,.35,4);glow(TV,1.6,0xfff0c0,.18,5);snd('boom');}}}
