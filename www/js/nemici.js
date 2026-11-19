// Settore Zero — comparsa e intelligenza dei nemici
'use strict';
/* ===== enemies ===== */
const BUILD={
 robot(e,T){if(!MODELS.robot)return BUILD.human(e,ET.brute);const src=MODELS.robot,r=e.root,inner=THREE.SkeletonUtils.clone(src.scene),mm={};inner.scale.setScalar(T.sc);r.add(inner);blob(r,.8);e.mats=[];
  inner.traverse(m=>{if(m.isMesh){const k=m.material.name;if(!mm[k]){mm[k]=m.material.clone();if(k==='Main')mm[k].color.copy(lc(0x56616e));else if(k==='Grey')mm[k].color.copy(lc(0x2c3036));else{mm[k].emissive=lc(0xff7a20);mm[k].emissiveIntensity=.8;}mm[k].metalness=.65;mm[k].roughness=.42;e.mats.push(mm[k]);}m.material=mm[k];m.castShadow=false;m.frustumCulled=false;m.raycast=()=>{};if(m.isSkinnedMesh){e.hn=e.hn||[];if(!e.hn.includes(m.parent))e.hn.push(m.parent);}}});
  e.mx=new THREE.AnimationMixer(inner);e.act={};for(const n of['Idle','Walking','Running','Punch','Death'])e.act[n]=e.mx.clipAction(THREE.AnimationClip.findByName(src.animations,n));e.act.Idle.play();e.act.Walking.play();e.act.Walking.setEffectiveWeight(0);e.act.Punch.setLoop(THREE.LoopOnce);e.act.Death.setLoop(THREE.LoopOnce);e.act.Death.clampWhenFinished=true;
  const hb=(geo,sx,sy,sz,y,head)=>{const m=new THREE.Mesh(GEO[geo],M.inv);m.scale.set(sx,sy,sz);m.position.y=y;if(head)m.userData.head=1;r.add(m);};hb('box',1.3,1.25,.9,.75);hb('sph',1.15,.95,1.05,1.85,1);
  e.rob=1;e.w0=0;e.cy=1;e.hy=1.85;e.mz=new THREE.Object3D();e.mz.position.set(0,1.2,.6);r.add(e.mz);},
 human(e,T){if(MODELS[T.mdl||'sol'])return soldier(e,T);const r=e.root,am=new THREE.MeshStandardMaterial({color:lc(T.col),roughness:.55,metalness:.35}),cm=new THREE.MeshStandardMaterial({color:lc(0x1d2025),roughness:.85,metalness:.1}),vm=new THREE.MeshStandardMaterial({color:lc(0x101010),emissive:lc(T.vis),emissiveIntensity:2,roughness:.3});e.mats=[am,cm];
  const body=new THREE.Group();body.position.y=.95;r.add(body);P('box',cm,.4,.55,.22,0,.3,0,body);P('box',am,.46,.32,.28,0,.42,.01,body);P('box',am,.38,.14,.25,0,.08,0,body);P('box',cm,.3,.36,.14,0,.36,-.18,body);
  const head=new THREE.Group();head.position.y=.72;body.add(head);for(const m of[P('sph',cm,.22,.25,.22,0,0,0,head),P('sph',am,.27,.2,.28,0,.055,-.012,head),P('box',vm,.19,.06,.06,0,0,.105,head)])m.userData.head=1;
  const arm=sx=>{const g=new THREE.Group();g.position.set(sx*.29,.5,0);body.add(g);P('sph',am,.18,.16,.18,0,.02,0,g);P('cyl',cm,.1,.3,.1,0,-.17,0,g);P('cyl',cm,.09,.28,.09,0,-.44,0,g);P('sph',cm,.1,.1,.1,0,-.6,0,g);return g;};
  const leg=sx=>{const g=new THREE.Group();g.position.set(sx*.11,.95,0);r.add(g);P('cyl',cm,.15,.46,.15,0,-.23,0,g);P('box',am,.14,.2,.06,0,-.2,.07,g);P('cyl',cm,.13,.46,.13,0,-.69,0,g);P('box',cm,.14,.1,.26,0,-.9,.05,g);return g;};
  const gun=new THREE.Group();gun.position.set(.17,.3,.26);body.add(gun);P('box',M.dark,.06,.1,.55*(T.laser?1.5:1),0,0,.1,gun);P('box',M.dark,.05,.13,.07,0,-.09,-.05,gun);const mz=new THREE.Object3D();mz.position.set(0,0,.4*(T.laser?1.5:1));gun.add(mz);
  if(T.gren){const tk=P('cyl',am,.2,.4,.2,0,.38,-.3,body);tk.rotation.z=0;P('sph',vm,.08,.08,.08,0,.62,-.3,body);}
  if(T.melee){for(const sx of[-1,1]){P('box',am,.3,.14,.34,sx*.36,.6,0,body);P('cyl',M.steel,.05,.2,.05,sx*.4,.74,0,body);}gun.visible=false;P('box',am,.5,.3,.1,0,.42,.16,body);}
  e.h={body,head,armL:arm(-1),armR:arm(1),legL:leg(-1),legR:leg(1),gun,mz};r.scale.setScalar(T.sc);e.cy=1.3*T.sc;e.hy=1.68*T.sc;e.mz=mz;},
 drone(e){const r=e.root,bm=new THREE.MeshStandardMaterial({color:lc(0x4a505a),roughness:.4,metalness:.7}),em=new THREE.MeshStandardMaterial({color:lc(0x200000),emissive:lc(0xff2a1a),emissiveIntensity:2.5});e.mats=[bm];
  P('sph',bm,.5,.42,.5,0,0,0,r);P('sph',em,.18,.18,.18,0,0,.2,r);e.rot=[];for(const[a,b]of[[1,1],[-1,1],[1,-1],[-1,-1]]){const ar=P('box',bm,.5,.04,.06,a*.3,.08,b*.3,r);ar.rotation.y=Math.atan2(-b,a);const ro=P('cyl',M.dark,.34,.015,.34,a*.48,.13,b*.48,r);e.rot.push(ro);}
  P('box',M.dark,.12,.1,.12,0,-.24,0,r);e.cy=0;e.hy=0;},
 turret(e){const r=e.root,bm=new THREE.MeshStandardMaterial({color:lc(0x5a626c),roughness:.45,metalness:.7}),em=new THREE.MeshStandardMaterial({color:lc(0x200000),emissive:lc(0xff2a1a),emissiveIntensity:2});e.mats=[bm];
  P('cyl',M.dark,.7,.18,.7,0,.09,0,r);P('cyl',bm,.16,.75,.16,0,.55,0,r);const hd=new THREE.Group();hd.position.y=1.02;r.add(hd);P('box',bm,.5,.34,.6,0,0,0,hd);P('box',M.dark,.52,.1,.4,0,.2,-.05,hd);
  for(const sx of[-.13,.13]){const b=P('cyl',M.dark,.09,.5,.09,sx,-.02,.5,hd);b.rotation.x=Math.PI/2;}P('box',em,.1,.05,.05,0,.12,.3,hd);const mz=new THREE.Object3D();mz.position.set(0,0,.78);hd.add(mz);e.hd=hd;e.mz=mz;e.cy=1;e.hy=1.05;},
 mech(e){const r=e.root,bm=new THREE.MeshStandardMaterial({color:lc(0x403a58),roughness:.45,metalness:.65}),pm=new THREE.MeshStandardMaterial({color:lc(0x26222f),roughness:.6,metalness:.5}),em=new THREE.MeshStandardMaterial({color:lc(0x300020),emissive:lc(0xff3ac8),emissiveIntensity:2.5});e.mats=[bm,pm];
  e.legs=[];for(const sx of[-1,1]){const g=new THREE.Group();g.position.set(sx*.75,1.5,0);r.add(g);P('box',pm,.5,.8,.6,0,-.4,0,g);P('box',bm,.56,.75,.7,0,-1.05,.05,g);P('box',pm,.7,.2,1,0,-1.4,.12,g);e.legs.push(g);}
  const b=new THREE.Group();b.position.y=1.6;r.add(b);P('box',pm,1.8,.45,1,0,0,0,b);P('box',bm,2.3,1.4,1.4,0,.95,0,b);P('box',pm,2.0,.3,1.5,0,1.72,0,b);const core=P('sph',em,.72,.72,.5,0,.85,.62,b);core.userData.head=1;
  P('box',pm,.7,.42,.6,0,2.1,.1,b);P('box',em,.5,.08,.05,0,2.12,.41,b);e.mzs=[];for(const sx of[-1,1]){P('box',bm,.62,.62,1.6,sx*1.55,1.05,.25,b);const c=P('cyl',M.dark,.3,.7,.3,sx*1.55,1.05,1.3,b);c.rotation.x=Math.PI/2;const mz=new THREE.Object3D();mz.position.set(sx*1.55,1.05,1.7);b.add(mz);e.mzs.push(mz);}
  e.mz=e.mzs[0];e.cy=2.45;e.hy=2.45;}
};
function soldier(e,T){const xb=T.mdl==='xbot',src=MODELS[T.mdl||'sol'],r=e.root,inner=THREE.SkeletonUtils.clone(src.scene);inner.rotation.y=xb?0:Math.PI;r.add(inner);blob(r,.5);e.mats=[];
 inner.traverse(m=>{if(m.isMesh){m.material=m.material.clone();m.castShadow=false;m.frustumCulled=false;m.raycast=()=>{};if(xb){if(/joint/i.test(m.name+m.material.name)){m.material.color.copy(lc(0x101012));m.material.emissive=lc(T.vis);m.material.emissiveIntensity=.9;}else{m.material.color.copy(lc(T.tint));m.material.metalness=.6;m.material.roughness=.42;e.mats.push(m.material);}}else if(/visor/i.test(m.name)){m.material.emissive=lc(T.vis);m.material.emissiveIntensity=.3;}else{m.material.color.multiply(lc(T.tint));e.mats.push(m.material);}}});
 e.mx=new THREE.AnimationMixer(inner);e.act={};for(const n of['Idle','Run','Walk']){const a=e.mx.clipAction(src.animations.find(q=>q.name.toLowerCase()===n.toLowerCase()));a.play();a.setEffectiveWeight(n==='Idle'?1:0);e.act[n]=a;}e.w=[1,0,0];
 e.bn={};inner.traverse(o=>{if(o.isBone)e.bn[o.name.replace('mixamorig','')]=o;});
 const hb=(geo,sx,sy,sz,y,head)=>{const m=new THREE.Mesh(GEO[geo],M.inv);m.scale.set(sx,sy,sz);m.position.y=y;if(head)m.userData.head=1;r.add(m);};hb('box',.54,.78,.36,1.13);hb('box',.46,.8,.32,.42);hb('sph',.32,.32,.32,1.67,1);
 const gun=new THREE.Group();r.add(gun);const gl=T.laser?1.5:1,mz=new THREE.Object3D(),gk=T.laser?'g_sniper':T.shield?'g_suomi':'g_m4';
 if(MODELS[gk]){const gm=noRay(MODELS[gk].scene.clone(true));gm.rotation.y=Math.PI;gm.position.z=T.laser?.185:-.025;gm.traverse(o=>{if(o.isMesh)o.castShadow=true;});gun.add(gm);mz.position.set(0,.03,T.laser?.72:.52);}
 else{P('box',M.dark,.05,.09,.6*gl,0,0,.05,gun);P('box',M.dark,.04,.12,.06,0,-.09,-.12,gun);P('box',M.dark,.035,.035,.25*gl,0,.02,.45*gl,gun);mz.position.set(0,.02,.6*gl);}gun.add(mz);if(T.melee)gun.visible=false;
 e.sol={gun};r.scale.setScalar(T.sc);e.cy=1.3*T.sc;e.hy=1.67*T.sc;e.mz=mz;}
function poseSol(e,run,aimT,dt){const T=e.T,b=e.bn;e.root.position.y=(e.by||0)-.62*e.cr*T.sc;
 const tw=run>=1&&(!T.melee||T.fast)?[0,1,0]:run>0?[0,0,1]:[1,0,0];for(let i=0;i<3;i++)e.w[i]+=(tw[i]-e.w[i])*Math.min(1,dt*8);e.act.Idle.setEffectiveWeight(e.w[0]);e.act.Run.setEffectiveWeight(e.w[1]);e.act.Walk.setEffectiveWeight(e.w[2]);e.mx.update(dt);
 e.aimK+=(aimT-e.aimK)*Math.min(1,dt*10);const a=e.aimK;e.root.updateMatrixWorld(true);e.root.getWorldQuaternion(RQ);
 if(T.melee){if(a>.02){aimBone(b.RightArm,-.3,1,.25,a);aimBone(b.LeftArm,.3,1,.25,a);}return;}
 const L=(p,q)=>p+(q-p)*a;
 aimBone(b.RightArm,L(-.1,-.13),L(-.92,-.76),L(.35,.63),1);aimBone(b.RightForeArm,L(.45,.57),L(-.25,.42),L(.8,.71),1);
 aimBone(b.LeftArm,L(.1,.12),L(-.88,-.55),L(.42,.75),1);aimBone(b.LeftForeArm,L(-.5,-.55),L(-.15,.25),L(.8,.75),1);
 const g=e.sol.gun;g.position.set(-.03,L(1.06,1.36),L(.42,.5));g.rotation.x=L(.45,0);}
function spawnE(type,slot,pos){PF.m.push('sp:'+type);const T=ET[type],e={t:type,T,root:new THREE.Group(),state:'enter',st:0,slot,dead:false,fl:0,an:Math.random()*6,cr:0,aimK:0,tok:false,tele:0,teleT:1,burst:0,bt:0,sx:Math.random()*6,cnt:true,dt:0,atk:0,shotN:0,fol:0,cyc:rnd(3),rc:-1,frz:0};
 e.hp=e.mhp=T.hp*G.hs*(type==='boss'?1+.5*(G.L/5-1):1);e.root.rotation.order='YXZ';BUILD[T.m](e,T);e.root.position.copy(pos);enG.add(e.root);e.root.traverse(m=>{m.userData.e=e;});
 if(T.shield){e.shm=P('box',M.shield,.8,1.3,.05,0,.95,.5,e.root);e.shm.userData.shield=1;e.root.traverse(m=>{m.userData.e=e;});}e.shK=0;e.las=new THREE.Mesh(GEO.box,M.las);e.las.visible=false;fxG.add(e.las);if(slot)slot.used=e;G.en.push(e);
 if(T.m==='turret'||T.m==='mech')e.state=T.m==='mech'?'enter':'hide',e.st=1.5;if(type==='boss'){G.boss=e;musicStart('boss');}
 TV.copy(pos);TV.y+=1;glow(TV,3,0x80d0ff,.35,2);return e;}
function spawnWave(st){return seeded(G.L*131+st.i*17+st.wi*5+3,()=>spawnWave0(st));}
function spawnWave0(st){const types=st.waves[st.wi++],b=G.L*977+st.i*53+st.wi*100;if(st.boss||window.NOSTAG)types.forEach((t,k)=>seeded(b+k,()=>spawnOne(st,t)));else st.q=(st.q||[]).concat(types.map((t,k)=>[t,b+k]));}
function spawnOne(st,t){const D=st.depth,vx=(lim,z)=>{for(let t=0;t<10;t++){const x=rr(-lim,lim);if(st.ok(x,z))return x;}return 0;};{const T=ET[t];
  if(t==='drone'){const z=-Math.min(rr(17,20),D-1.5);spawnE(t,null,new V3(vx(3.5,z),rr(2.6,3.8),z));return;}
  if(T.melee){const z=-Math.min(rr(16,19),D-2);spawnE(t,null,new V3(safeX(st,vx(2,z),z),0,z));return;}
  if(t==='boss'){spawnE(t,null,new V3(0,0,-Math.min(20,D-2.5)));return;}
  let free=st.slots.filter(q=>!q.used);if(t==='turret'||T.shield)free=free.filter(q=>!q.cover||q.cover.dead);else{const el=free.filter(q=>q.el);if(el.length&&(T.far||Math.random()<.5))free=el;else{const cv=free.filter(q=>q.cover&&!q.cover.dead);if(cv.length&&Math.random()<.8)free=cv;}}
  if(st.boss)free=free.filter(q=>q.z>-10.5&&!q.el);
  if(T.far&&!st.boss&&free.length>1)free.sort((a,b)=>a.z-b.z),free.length=Math.ceil(free.length/2);
  if(t==='turret')free=free.filter(q=>st.los(q.x,1,q.z));let sl=free[rnd(free.length)]||!st.boss&&t!=='turret'&&st.rndSlot(rr(6,15)*Math.min(1,(D-2.4)/15.5),false);if(!sl){sl=openSlot(st,null,rnd(8),t==='turret'?1:0);sl.used=null;st.slots.push(sl);}
  const sp=new V3(sl.x,0,sl.z);if(t!=='turret')for(let k=0;k<6;k++){const x=sl.x+rr(-1.5,1.5),z=sl.z-rr(3,4.5);if(st.ok(x,z)&&!blk(st,x,z,.45)){sp.set(x,0,z);break;}}if(st.spawn&&t!=='turret'&&!sl.el&&Math.random()<.75){const q=st.spawn[rnd(st.spawn.length)],cq=st.r2c(q[0],q[1]);sp.set(cq[0],0,cq[1]);}
  if(sl.el){sp.set(sl.x,sl.y,sl.z);const e=spawnE(t,sl,sp);e.by=sl.y;e.state='hide';e.st=rr(.6,1.6);}else spawnE(t,sl,sp);}}
function relTok(e){if(e.tok){e.tok=false;G.aimers--;}}
const _ls=new THREE.Raycaster(),_lo=new V3(),_lt=new V3();
function eSeen(e){const p=e.root.position;_lo.set(0,1.62,G.cz-.15);for(const h of[e.cy,e.hy]){_lt.set(p.x,(e.by||0)+h,p.z).sub(_lo);const d=_lt.length();if(d<.5)return true;_ls.set(_lo,_lt.divideScalar(d));_ls.far=d-.25;let ok=true;for(const q of _ls.intersectObject(world,true)){const u=q.object.userData;if(u.e||u.proj||(u.prop&&u.prop.dead))continue;ok=false;break;}if(ok)return true;}return false;}
function eyePos(o){return o.set(0,mix(1.38,1.62,G.lean),G.cz-.15*G.lean);}
function startBurst(e){const T=e.T;e.state='fire';e.burst=T.m==='mech'&&e.atk===2?3:T.m==='human'&&!T.laser&&!T.gren?2+rnd(4):T.burst;e.bt=0;e.shotN=0;e.fol=0;e.rc=-1;}
function eShoot(e){const T=e.T,a=e.mz.getWorldPosition(new V3());
 if(T.gren||e.atk===2){eProj(e.atk===2?'rock':'gren',a,e);return;}
 snd(T.laser?'esnipe':'eshot');const ex=G.lean>.4,ramp=T.laser?1:Math.min(1.15,.45+.22*(e.shotN||0)),hit=ex&&Math.random()<T.acc*ramp,b=eyePos(new V3());
 if(hit)b.y-=.15;else if(ex){b.x+=rr(-.7,.7);b.y+=rr(-.1,.5);snd('whiz');}else{b.set(rr(-1.1,1.1),rr(.9,1.19),G.cz-.52);bits(b,3,M.spark,2.5,.03,.25);snd('cover');if(Math.random()<.25)snd('ric');}
 tracer(a,b,M.etr);glow(a,.5,0xffb060,.06);if(hit)hurt(T.dmg*G.ds);}
function eProj(type,a,e){const m=new THREE.Group();if(type==='gren'){if(MODELS.g_frag){P('sph',M.inv,.36,.36,.36,0,0,0,m);const v=noRay(MODELS.g_frag.scene.clone(true));v.scale.setScalar(2.6);v.position.y=-.13;m.add(v);}else P('sph',M.dark,.22,.22,.22,0,0,0,m);P('sph',M.doorL,.08,.08,.08,0,.16,0,m);}else{const c=P('cyl',M.steel,.14,.55,.14,0,0,0,m);c.rotation.x=Math.PI/2;P('sph',M.doorL,.14,.14,.14,0,0,.28,m);}
 m.position.copy(a);prG.add(m);const pr={type,m,v:new V3(),g:0,dead:false,tl:9,dE:(type==='gren'?18:12)*G.ds,dC:(type==='gren'?8:6)*G.ds};m.traverse(o=>{o.userData.proj=pr;});
 const tx_=rr(-.5,.5),tz=G.cz-.2;if(type==='gren'){const T=rr(2.1,2.5);pr.g=9.8;pr.v.set((tx_-a.x)/T,(.2-a.y+.5*9.8*T*T)/T,(tz-a.z)/T);pr.tl=T;snd('throw');}else{pr.v.set(tx_-a.x,1.3-a.y,tz-a.z).normalize().multiplyScalar(9);m.lookAt(tx_,1.3,tz);snd('rocket');}
 G.eproj.push(pr);}
function detProj(pr,byPlayer){if(pr.dead)return;pr.dead=true;if(G.qte&&G.qte.own===pr){if(byPlayer){G.qte=null;qsHide();}else qteEnd(false);}prG.remove(pr.m);const p=pr.m.position.clone();if(byPlayer){explode(p,3,45*G.hs);}else{explode(p,2.5,0);if(!pr.dod)hurt(G.lean>.4?pr.dE:pr.dC,true);}}
function poseRob(e,run,aimT,dt){const w=run>0?1:0;e.w0+=(w-e.w0)*Math.min(1,dt*8);e.act.Walking.setEffectiveWeight(e.w0);e.act.Idle.setEffectiveWeight(1-e.w0);
 if(aimT&&!e.pw){e.pw=1;const p=e.act.Punch;p.reset();p.timeScale=p.getClip().duration/Math.max(.4,e.teleT+.15);p.setEffectiveWeight(4);p.play();}else if(!aimT&&e.state!=='wind')e.pw=0;e.mx.update(dt);}
function poseH(e,run,aimT,dt){if(e.rob)return poseRob(e,run,aimT,dt);if(e.sol)return poseSol(e,run,aimT,dt);const h=e.h,t=e.an,T=e.T;e.root.position.y=(e.by||0)-.62*e.cr*T.sc;const sw=Math.sin(t)*.8*run;h.legL.rotation.x=sw;h.legR.rotation.x=-sw;h.body.position.y=.95+Math.abs(Math.cos(t))*.04*run;
 e.aimK+=(aimT-e.aimK)*Math.min(1,dt*10);const a=e.aimK;if(T.melee){h.armR.rotation.x=mix(-sw*.6,-2.6,a);h.armL.rotation.x=mix(sw*.6,-2.6,a);return;}
 h.armR.rotation.x=mix(-sw*.5-.5,-1.45,a);h.armL.rotation.x=mix(sw*.5-.5,-1.3,a);h.armL.rotation.z=mix(0,.5,a);h.gun.rotation.x=mix(.8,0,a);h.gun.position.y=mix(.12,.42,a);}
function updEnemy(e,dt){const T=e.T,r=e.root,pz=G.cz;if(e.fl>0){e.fl-=dt;const k=Math.max(0,e.fl)*5;for(const m of e.mats)m.emissive.setScalar(k);}
 if(e.frz>0&&!e.dead){e.frz-=dt;const on=e.frz>0;for(const m of e.mats){if(on)m.emissive.setRGB(0,.22,.55);else m.emissive.setScalar(0);}if(on)return;}
 if(e.dead){e.dt+=dt;if(e.rob){e.mx.update(dt);r.position.y=Math.min(0,(2.4-e.dt))*.9;if(e.hn){if(!e.hd){r.updateMatrixWorld(true);e.hd=e.hn.map((h,i)=>{const p=h.parent,a=p.worldToLocal(p.getWorldPosition(new V3())),b=p.worldToLocal(p.getWorldPosition(new V3()).add(new V3((i?1:-1)*.18,-1,.25)));return{h,p0:h.position.clone(),dl:b.sub(a),r0:h.rotation.z};});}const k=clamp((e.dt-.12)/.5,0,1),q=k*k,bn=k>=1?Math.max(0,Math.sin((e.dt-.62)*14))*Math.exp(-(e.dt-.62)*7)*.12:0;for(const o of e.hd){o.h.position.copy(o.p0).addScaledVector(o.dl,q*1.02-bn);o.h.rotation.z=o.r0+q*.5;}}}else if(T.m==='human'){r.rotation.x=-Math.min(1.5,e.dt*5);r.position.y=(e.by||0)+Math.min(0,(2.2-e.dt))*.6;}if(e.dt>3){enG.remove(r);freeE(r);e.gone=true;}return;}
 const fight=G.phase==='fight';
 if(T.m==='drone'){e.an+=dt;for(const ro of e.rot)ro.rotation.y+=dt*40;const tx_=Math.sin(e.an*1.7+e.sx)*Math.min(2.2,(pz-r.position.z)*.12),ty=1.5+Math.sin(e.an*2.3)*.45;TV.set(tx_,ty,pz-.4).sub(r.position);const d=TV.length();
  if(d<1.3){explode(r.position.clone(),2,0);hurt(T.dmg*G.ds,true);kill(e,true);return;}{const k=Math.min(1,T.spd*dt/d),yy=r.position.y;r.position.addScaledVector(TV,k);r.position.y=yy+clamp(ty-yy,-4.5*dt,4.5*dt);}r.rotation.y=Math.atan2(-r.position.x,pz-r.position.z);r.rotation.z=Math.sin(e.an*3)*.15;return;}
 r.rotation.y=Math.atan2(-r.position.x,pz-r.position.z);
 if(T.melee){if(e.mo===undefined){const S_=G.stages[G.si],us=G.en.filter(o=>o!==e&&o.T.melee&&!o.dead&&o.mo!==undefined).map(o=>o.mo),ok=[0,-1.15,1.15,-2.25,2.25].filter(v=>!blk(S_,v,pz-2.3,.5)),f=ok.find(v=>!us.includes(v));e.mo=f===undefined?ok[rnd(ok.length)]||0:f;e.mb=f===undefined?1.5:0;}const tz=pz-2.3-(e.mb||0),dz=Math.hypot(r.position.x-e.mo,tz-r.position.z);let run=0,a=0;
  if(dz>.3){goTo(e,e.mo,tz,T.spd*dt,T.fast?.42:.5);turn(e,dt);e.an+=dt*6;run=e.sol&&!T.fast?.5:1;}
  else if(e.state!=='wind'){e.st-=dt;if(e.st<=0){if(G.qte||G.wnd&&G.wnd!==e&&!G.wnd.dead)e.st=.25;else{G.wnd=e;e.state='wind';e.tele=e.teleT=T.fast?1.15:1.35;e.dod=0;e.q=0;e.qd=rnd(2)?'L':'R';}}}else{a=1;if(!e.q&&e.tele<=.5){if(qteStart(e.qd,Math.max(.2,e.tele),()=>{e.dod=1;},false,T.fast?'ASSALTO — SCHIVA':e.rob?'PUGNO — SCHIVA':'MAZZATA — SCHIVA')){e.q=1;G.qte.own=e;G.qte.src=e.root.position;}}if(e.q||e.tele>.5)e.tele-=dt;if(e.tele<=0){if(G.qte&&G.qte.own===e)qteEnd(false);if(G.wnd===e)G.wnd=null;e.state='hit';e.st=1.8;if(!e.dod)hurt(T.dmg*G.ds,true);G.shake=.5;TV.set(0,1.1,pz-.8);bits(TV,8,M.spark,3,.04,.4);snd('crash');}}
  poseH(e,run,a,dt);return;}
 if(T.m==='mech')return updBoss(e,dt,fight,pz);
 const cover=e.slot&&e.slot.cover&&!e.slot.cover.dead;let crT=0,a=0,run=0;
 switch(e.state){
  case'enter':{const dx=e.slot.x-r.position.x,dz=e.slot.z-r.position.z,d=Math.hypot(dx,dz);if(d<.15){e.state='hide';e.st=rr(.8,2.4);e.et=0;e.ry=undefined;}else{e.et=(e.et||0)+dt;if(e.et>14){r.position.x=e.slot.x;r.position.z=e.slot.z;}else goTo(e,e.slot.x,e.slot.z,T.spd*dt,.42);turn(e,dt);e.an+=dt*11;run=1;}break;}
  case'hide':if(e.slot&&!e.by&&T.m!=='turret'&&Math.hypot(e.slot.x-r.position.x,e.slot.z-r.position.z)>(cover?.5:1.4)){e.state='enter';e.et=0;e.path=null;break;}crT=cover?1:0;if(!cover&&T.m==='human'){e.sx+=dt;const nx=clamp(e.slot.x+Math.sin(e.sx*1.3)*.9,-4.3,4.3),S=G.stages[G.si];if(!blk(S,nx,r.position.z,.4)&&S.los(nx,1.35,r.position.z)){r.position.x+=clamp(nx-r.position.x,-1.6*dt,1.6*dt);e.an+=dt*6;run=.5;}}
   e.st-=dt;if(e.st<=0&&fight&&T.m!=='mech'&&!eSeen(e)){e.nv=(e.nv||0)+1;const mob=e.slot&&!e.by&&T.m!=='turret';if(mob||e.nv<6){e.st=rr(.4,.9);if(mob&&e.nv>=2){e.nv=0;e.slot.used=null;e.slot=openSlot(G.stages[G.si],e,rnd(8));e.state='enter';e.et=0;e.path=null;}break;}}
   if(e.st<=0&&fight&&(T.m==='mech'||G.aimers<G.maxAim)){e.nv=0;e.state='aim';if(T.m==='mech'){e.atk=(e.atk||0)%4+1;if(e.atk===4){e.dod=0;qteStart('U',1.45,()=>{e.dod=1;});}if(e.atk===3){for(let i=0;i<2;i++){const d=spawnE('drone',null,new V3(r.position.x+rr(-2,2),rr(3,4),r.position.z));d.cnt=false;}e.state='hide';e.st=2;break;}e.mz=e.mzs[rnd(2)];}else{e.tok=true;G.aimers++;}
    e.tele=e.teleT=(T.m==='mech'&&e.atk===2?.8:T.m==='mech'&&e.atk===4?1.5/G.tsc:T.tele)*G.tsc*(T.m==='mech'&&e.atk===4?1:rr(.8,1.25));snd('tele');}break;
  case'aim':a=1;e.tele-=dt;if(e.tele<=0&&T.m==='mech'&&e.atk===4){G.shake=.8;snd('boom');TV.set(0,.4,-4);glow(TV,7,0xff60d0,.4,4);bits(TV,14,M.spark,6,.05,.6);if(!e.dod)hurt(18*G.ds,true);e.state='hide';e.st=2;break;}
   if(e.tele<=0){if(T.m==='human'&&!T.gren&&G.lean<.4){e.state='watch';e.st=rr(1.2,T.laser?3.2:2.2);e.rc=-1;}else startBurst(e);}break;
  case'watch':a=1;e.st-=dt;if(G.lean>.5){if(e.rc<0)e.rc=e.rcT=rr(.28,.5)*(T.laser?1.3:1);e.rc-=dt;if(e.rc<=0)startBurst(e);}
   else{e.rc=-1;if(e.st<=0){if(!T.laser&&Math.random()<.5){startBurst(e);e.burst=Math.min(e.burst,2);}else{e.state='hide';e.st=T.cool*rr(.4,.9);relTok(e);}}}break;
  case'fire':a=1;e.bt-=dt;if(e.bt<=0){const mb=T.m==='mech'&&e.atk===2;if(e.burst>0){eShoot(e);e.burst--;e.shotN++;e.bt=(mb?.45:T.bint)*rr(.8,1.35);}
    else if(T.m==='human'&&!T.gren&&!T.laser&&e.fol<1&&Math.random()<.4){e.fol++;e.burst=2+rnd(3);e.shotN=1;e.bt=rr(.3,.55);}
    else{e.cyc++;e.state='hide';e.st=T.cool*rr(.6,1.4)+(T.m==='human'&&e.cyc%3===0?2.2:0);relTok(e);}}break;}
 e.cr+=(crT-e.cr)*Math.min(1,dt*9);if(e.shm){e.shK+=((e.state==='fire'?1:0)-e.shK)*Math.min(1,dt*8);e.shm.position.x=-.62*e.shK;e.shm.rotation.y=.9*e.shK;}
 if(T.m==='human')poseH(e,run,a,dt);else if(T.m==='turret'){e.hd.rotation.x=a?-.05:.25;}
 const ls=(e.state==='aim'||e.state==='watch')&&T.m!=='mech'||(T.m==='mech'&&e.state==='aim'&&e.atk===1);e.las.visible=ls;if(ls){const p0=e.mz.getWorldPosition(TV),p1=TV2.set(0,1.3,G.cz-1.1).lerp(p0,.45);seg(e.las,p0,p1,T.laser?.03:.014);}}
