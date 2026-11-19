// Settore Zero — ciclo di gioco per ogni fotogramma
'use strict';
/* ===== update ===== */
function advance(){if(G.phase!=='clear')return;$('adv').style.display='none';const st=G.stages[G.si];G.mv={P:st.outP,t:0,kind:'out',last:G.si>=G.nS-1,dur:Math.max(.7,pathLen(st.outP)/(5.2*(1+.05*pk('sp'))))};G.phase='out';}
function update(dt){{const q=G.qte,tg=q&&q.dir!=='T'&&!(G.mv&&G.mv.kind==='run')?clamp(q.T/(2.4-.7*(G.L-1)/44),.17,1):1;G.sl=tg<1?tg:(G.sl||1)+(1-(G.sl||1))*Math.min(1,dt*9);dt*=G.sl;}G.t+=dt;const w=cw(),t=WT[w.t],ws=wst(w);
 const moving=!!G.mv,touch=aim.down||aim.hold>0,shoot=touch&&!moving&&!G.cine,want=moving||touch||G.cine?1:0;if(G.inv>0)G.inv-=dt;if(G.qte){G.qte.t-=dt;QS.bar.style.width=Math.max(0,G.qte.t/G.qte.T*100)+'%';if(G.qte.t<=0)qteEnd(false);}if(aim.hold>0)aim.hold-=dt;G.idle+=dt;if(G.cine){const c=G.cine;c.t-=dt;if(c.f&&c.t<c.ft){c.f();c.f=null;}if(c.t<=0){cineOff();G.phase='fight';G.lastK=G.t;}}
 G.lean=clamp(G.lean+(want?1:-1)*dt*G.lsp,0,1);G.cdw-=dt;G.kick=Math.max(0,G.kick-dt*7);G.mflash-=dt;G.beam-=dt;G.hitM-=dt;G.hurtFx=Math.max(0,G.hurtFx-dt);G.shake=Math.max(0,G.shake-dt*1.6);
 if(G.ammo[w.id]<ws.mag&&(G.lean<.2||G.ammo[w.id]<=0||G.idle>1.2)){G.rel+=dt/(ws.rel*(G.lean<.2?.7:1.3));if(G.rel>=1){G.ammo[w.id]=ws.mag;G.rel=0;snd('rel');}}else G.rel=0;
 // percorso
 if(G.mv){const m=G.mv;m.el=(m.el||0)+dt;if(m.lb>0){m.lb-=dt;escPre(m);}if(!m.hold)m.t+=dt/m.dur*(m.ts===undefined?1:m.ts);const k=clamp(m.t,0,1),q=k*k*(3-2*k),u=m.kind==='run'?k:q,tot=pathPos(m.P,u,PP);G.px=PP.x;G.pz=PP.z;let yt=pathYaw(m.P,u,tot,PP);if(m.kind==='in'){const b=clamp((q-.3)/.65,0,1);yt+=angd(0,yt)*b*b*(3-2*b);}if(m.lb>0)yt=Math.PI;
  if(m.kind==='run'){const sp=tot/m.dur;runHaz(m,sp,dt);if(state!=='play')return;let lp=0;if(G.lookT){const a=Math.atan2(-(G.lookT.x-G.px),-(G.lookT.z-G.pz));yt+=clamp(angd(a,yt),-.42,.42)*.8;lp=clamp(Math.atan2(G.lookT.y-(G.py+1.6),Math.hypot(G.lookT.x-G.px,G.lookT.z-G.pz))*.6,-.3,.3);}G.lookP=(G.lookP||0)+(lp-(G.lookP||0))*Math.min(1,dt*5);}G.bank=(G.bank||0)+(clamp(angd(yt,G.yaw)*.45,-.13,.13)-(G.bank||0))*Math.min(1,dt*5);G.yaw+=clamp(angd(yt,G.yaw)*Math.min(1,dt*7),-YAW_MAX*dt,YAW_MAX*dt);if(m.kind==='out'&&m.t>.01){const d=G.stages[G.si].door;if(d)d.o=1;}
  const d=Math.hypot(G.px,G.pz);G.cy=Math.abs(Math.sin(G.t*9))*.07+(G.pz<0&&d<1.7&&m.kind!=='run'?.85*Math.sin(Math.PI*d/1.7):0);G.stepT-=dt;if(G.stepT<=0){G.stepT=.3;snd('step');}
  {/* niente dissolvenza al nero nei passaggi tra stanze collegate: si vede la stanza successiva */const nx=G.stages[G.si+1],so=!!(nx&&nx.link&&!m.last),si=!!G.stages[G.si].link;$('fade').style.opacity=m.kind==='in'?(si?0:clamp(1-m.t*m.dur/.45,0,1)):m.kind==='run'?Math.max(si?0:clamp(1-m.el/.45,0,1),so?0:clamp(1-(1-k)*tot/2.5,0,1)):so?0:clamp(1-(1-q)*tot/2.5,0,1);}
  if(k>=1){G.cy=0;if(m.kind==='run'){if(G.si>=G.nS-1){G.mv=null;endLevel(true);return;}const yw=G.yaw,lk=G.stages[G.si+1].link;enterRoom(G.si+1);if(lk&&G.mv&&!(G.mv.lb>0))G.yaw=yw-lk.beta;}else if(m.kind==='in')startFight(G.stages[G.si]);else if(m.last){G.mv=null;endLevel(true);return;}else{G.hp=Math.min(G.mhp,G.hp+G.mhp*.15);const yw=G.yaw,lk=G.stages[G.si+1].link;enterRoom(G.si+1);if(lk&&G.mv&&!(G.mv.lb>0))G.yaw=yw-lk.beta;}}}
 else G.yaw+=angd(0,G.yaw)*Math.min(1,dt*7);
 let ox=0,oy=0,rz=0,rxd=0;if(G.dg){const dg=G.dg;let kk;if(dg.man)kk=dg.k;else{dg.t+=dt;kk=Math.sin(Math.PI*Math.min(1,dg.t/dg.d));}if(dg.dir==='L'){ox=-1.15*kk;rz=.16*kk;}else if(dg.dir==='R'){ox=1.15*kk;rz=-.16*kk;}else if(dg.dir==='U')oy=kk;else{oy=-.8*kk;if(dg.man){rxd=.2*kk;rz=.05*kk;}}if(!dg.man&&dg.t>=dg.d)G.dg=null;}
 scopeTick(dt);// cannocchiale del cecchino (mirini.js): zoom e punto mirato prima di orientare la camera e di sparare
 const sh=G.shake,fw=.15*G.lean,sy=Math.sin(G.yaw),cyw=Math.cos(G.yaw);cam.position.set(G.px-sy*fw+cyw*ox+rr(-1,1)*sh*.06,mix(1.38,1.62,G.lean)+G.cy+oy+rr(-1,1)*sh*.06,G.pz-cyw*fw-sy*ox);
 cam.rotation.set(SRN.y*.05*G.lean-(1-G.lean)*.03+G.kick*.012+rxd,G.yaw-SRN.x*.07*G.lean,rz+(G.mv?G.bank||0:0));if(G.mv&&G.mv.kind==='run'){cam.position.y+=G.py||0;cam.rotation.x+=G.lookP||0;}cam.updateMatrixWorld();scopeView();
 if(G.lit===1){const kk=.5+.5*Math.sin(G.t*5);pl1.color.setRGB(1,.12,.08);pl2.color.setRGB(1,.1,.06);pl1.intensity=.5+1.3*kk;pl2.intensity=.6+1.4*(1-kk);}else{pl1.color.set(TH[curTh].l1);pl2.color.set(TH[curTh].l2);pl1.intensity=G.lit===2?.1:.9;pl2.intensity=G.lit===2?.14:1.2;}
 if(G.lit===2){spot.angle=.2;spot.intensity=3.4;spot.position.copy(cam.position);RC.setFromCamera(ndc,cam);spot.target.position.copy(cam.position).addScaledVector(RC.ray.direction,12);}else{spot.angle=1;spot.intensity=MODELS.hall?1.05:1.5;spot.position.set(0,4.9,-4);spot.target.position.set(0,0,-17);}
 pl1.position.set(-2.5,3.6,-7);pl2.position.set(2,3.4,-22);const lw=lightFollow();if(lw>0){const l=Math.hypot(PP.dx,PP.dz)||1,fx=PP.dx/l,fz=PP.dz/l,y=G.py||0;pl1.position.lerp(TV.set(G.px+fx*3,y+3.3,G.pz+fz*3),lw);pl2.position.lerp(TV.set(G.px+fx*10,y+3.2,G.pz+fz*10),lw);spot.position.lerp(TV.set(G.px-fx,y+4,G.pz-fz),lw);spot.target.position.lerp(TV.set(G.px+fx*9,y,G.pz+fz*9),lw);}xl.intensity*=Math.pow(.001,dt);
 // arma
 const th=Math.tan(cam.fov*Math.PI/360),ax=ndc.x*th*cam.aspect*14-G.wx,ay=ndc.y*th*14-G.wy,g=WG,hid=1-G.lean;
 g.position.set(G.wx+hid*.05,G.wy-hid*.55+G.kick*.012,G.wz+G.kick*.05);g.rotation.set(Math.atan2(ay,14)+G.kick*.08-hid*.6,-Math.atan2(ax,14),0);g.updateMatrixWorld();
 if(G.aura)G.aura.material.opacity=.22+.12*Math.sin(G.t*4);
 if(G.orbs)for(let i=0;i<G.orbs.length;i++){const a=G.t*3.2+i*6.283/G.orbs.length;G.orbs[i].position.set(Math.cos(a)*.05,G.wby+Math.sin(a)*.05,G.wlen*(.25+.5*(.5+.5*Math.sin(G.t*1.3+i*1.7))));}
 if(G.wmat&&G.wr===5){G.wmat.emissive.setHSL((G.t*.3)%1,1,.5);G.wmat.emissiveIntensity=.09+.05*Math.sin(G.t*6);if(G.aura)G.aura.material.color.copy(G.wmat.emissive);}
 if(shoot&&G.lean>=.85&&fire()){G.idle=0;if(!aim.down)aim.hold=0;}
 G.mfs.visible=G.mflash>0&&!t.beam;if(G.mfs.visible){const q=rr(.25,.4)*(1+G.wr*.12);G.mfs.scale.set(q,q,1);}mfl.intensity=G.mflash>0?2.6:0;if(G.mflash>0)G.muz.getWorldPosition(mfl.position);
 BEAM.visible=G.beam>0&&!!G.beamEnd;if(BEAM.visible)seg(BEAM,G.muz.getWorldPosition(TV),G.beamEnd,.03);
 // ondate
 const st=G.stages[G.si],dtE=G.slow>0?dt*.3:dt;if(G.slow>0)G.slow-=dt;
 if(G.phase==='fight'){let alive=0;for(const e of G.en)if(!e.dead&&e.cnt)alive++;
  const qn=st.q&&st.q.length;if(qn){st.qt=(st.qt||0)-dt;if(st.qt<=0){st.qt=.17;const q=st.q.shift();seeded(q[1],()=>spawnOne(st,q[0]));}}
  if(st.wi<st.waves.length){if(alive<=(st.wi?1:0)&&!qn){st.wd-=dt;if(st.wd<=0){spawnWave(st);st.wd=1.3;G.lastK=G.t;}}}
  else if(alive===0&&!qn&&!G.eproj.length&&!G.bh.length){for(const e of G.en)if(!e.dead)kill(e,true);G.phase='clear';if((st.fl||'').includes('m')&&MODELS.xbot){const a=mkActor('marsh'),e=st.exitP||st.outP[st.outP.length-1],ax=e[1]<-6?e[0]:2.2,az=e[1]<-6?e[1]:-11;a.root.position.set(ax,0,az);a.path=navPath(st,ax,az,1.5,-2.9,.4);a.spd=5;a.look=1;sub(st.say,6000);}if(st.door)st.door.g=1;const a=$('adv');a.style.display='block';a.textContent=G.si>=G.nS-1?'USCITA ▶':'AVANZA ▶';snd('pick');}
  if(G.phase==='fight'&&alive>0&&G.t-(G.lastK||0)>22){G.lastK=G.t;let k=0;for(const e of G.en)if(!e.dead&&e.T.m==='human'&&!e.T.melee&&e.slot&&!e.by){relTok(e);e.slot.used=null;e.slot=openSlot(st,e,k++);e.by=0;e.state='enter';}}}
 for(const e of G.en)updEnemy(e,dtE);if(state!=='play')return;updActors(dt);updDoor(dt);if(G.warn>0)G.warn-=dt;G.en=G.en.filter(e=>!e.gone);
 for(const b of G.bh){if(!b.on){b.on=1;glow(b.p,3.2,0xb45cff,1.3,-.3);const m=new THREE.Mesh(GEO.sph,M.hole0);m.scale.setScalar(.9);m.position.copy(b.p);pAdd(m,new V3(),1.3,0,{});}b.t-=dt;
  for(const e of G.en)if(!e.dead&&e.T.spd&&e.t!=='boss'){ePos(e,TV);const d=TV.distanceTo(b.p);if(d<7&&d>.4&&!e.by){const nx=e.root.position.x+(b.p.x-TV.x)/d*5*dt,nz=e.root.position.z+(b.p.z-TV.z)/d*5*dt;if(e.T.m==='drone'||!blk(G.stages[G.si],nx,nz,.35)){e.root.position.x=nx;e.root.position.z=nz;}}}if(b.t<=0){b.dead=1;explode(b.p,4,b.dmg);}}G.bh=G.bh.filter(b=>!b.dead);
 for(const p of G.eproj){if(p.dead)continue;if(p.type==='gren'){p.tl-=dtE;if(!p.q){const P0=p.m.position,gy=p.g||0,vy=p.v.y,ty=gy>0?(vy+Math.sqrt(Math.max(0,vy*vy+2*gy*Math.max(0,P0.y-.15))))/gy:vy<0?(P0.y-.15)/-vy:9,tz=p.v.z>0?(-.9-P0.z)/p.v.z:9,rem=Math.max(0,Math.min(ty,tz));if(rem<.5){if(qteStart(rnd(2)?'L':'R',Math.max(.15,rem),()=>{p.dod=1;},false,p.lab||'GRANATA — SCHIVA')){p.q=1;G.qte.own=p;G.qte.src=p.m.position;}else if(rem<.08){p.q=1;p.dod=1;}}}}p.m.position.addScaledVector(p.v,dtE);p.v.y-=p.g*dtE;p.m.rotation.x+=dtE*5*(p.g?1:0);if(p.m.position.y<.15||p.m.position.z>-.9)detProj(p,false);if(state!=='play')return;}G.eproj=G.eproj.filter(p=>!p.dead);
 for(const p of G.pproj){const stp=p.spd*dt,h=cast(p.m.position,p.d,stp+.2);p.life-=dt;if(h||p.life<=0){const pt=h?h.h.point.clone():p.m.position.clone();if(h&&h.e)dmgE(h.e,p.dmg*.5,h.head,pt);explode(pt,p.r,p.dmg);fxG.remove(p.m);p.m.material.dispose();p.dead=true;}else p.m.position.addScaledVector(p.d,stp);}G.pproj=G.pproj.filter(p=>!p.dead);
 for(const p of G.props){if(p.type==='chest'&&p.open&&p.open<2){p.open=Math.min(2,p.open+dt*4);p.lid.rotation.x=-(p.open-1)*1.9;}
  if(p.type==='secret'&&!p.dead&&p.si===G.si){p.sp-=dt;if(p.sp<=0){p.sp=rr(2.5,5);TV.copy(p.cp);TV.y=rr(.6,1.7);TV.x*=.93;bits(TV,4,M.spark,1.6,.025,.35);}}}
 updParts(dt);
 G.hudT-=dt;if(G.hudT<=0){G.hudT=.08;hudUp();}}

/* quanto le luci seguono il giocatore: sempre nei corridoi; vicino alla porta d'uscita di una sala e nei primi metri
   della sala successiva passano gradualmente dalle posizioni fisse della sala a quelle che seguono il giocatore */
const LF_OUT=8,LF_FULL=2,LF_IN=6;
function lightFollow(){const m=G.mv;if(!m)return 0;if(m.kind==='run')return 1;const st=G.stages[G.si],k=clamp(m.t,0,1),q=k*k*(3-2*k),d=q*smoothPath(m.P).tot,sm=x=>{x=clamp(x,0,1);return x*x*(3-2*x);};
 if(m.kind==='out'&&st.tot0&&G.stages[G.si+1]&&G.stages[G.si+1].link)return sm((LF_OUT-(st.tot0-d))/(LF_OUT-LF_FULL));
 if(m.kind==='in'&&st.link)return 1-sm(d/LF_IN);return 0;}
