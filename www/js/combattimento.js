// Settore Zero — sparo, danni, esplosioni, casse
'use strict';
/* ===== combat ===== */
function toast(h,ms){const d=document.createElement('div');d.innerHTML=h;$('toast').appendChild(d);while($('toast').children.length>3)$('toast').firstChild.remove();setTimeout(()=>d.remove(),ms||2300);}
const cw=()=>wget(S.eq[G.wi])||S.inv[0];
function buildWeapon(){const w=cw(),v=WV[w.t];const g=WG;clearGroup(g);const wm=WM[w.t];G.wz=-.55;G.wx=.21;G.wy=-.3;G.tr=w.x||null;G.wr=w.r;G.aura=null;G.orbs=null;G.wmat=null;
 if(wm&&MODELS[wm.k]){const m=noRay(MODELS[wm.k].scene.clone(true));if(wm.rot)m.rotation.y=Math.PI;m.position.set(wm.dx||0,0,-wm.tz);m.traverse(o=>{if(o.isMesh){o.castShadow=false;o.frustumCulled=false;}if(wm.hide&&wm.hide.includes(o.name))o.visible=false;});g.add(m);G.wz=wm.wz||-.55;G.wx=wm.wx||.21;G.wy=wm.wy||-.3;G.wlen=wm.mz-wm.tz;G.wby=wm.by;
  if(w.r>=3){let wmat=null;m.traverse(o=>{if(o.isMesh){if(!wmat){wmat=o.material.clone();wmat.emissive=lc(RAR[w.r].c);wmat.emissiveMap=null;wmat.emissiveIntensity=[0,0,0,.05,.08,.1][w.r];if(w.r===4){wmat.color.lerp(lc(0xffc85a),.55);wmat.metalness=1;wmat.roughness*=.6;}if(w.r===5){wmat.color.lerp(lc(0x1a0a10),.35);wmat.roughness*=.7;}}o.material=wmat;o.userData.ownMat=1;}});G.wmat=wmat;}
  if(w.r>=2){const am=new THREE.SpriteMaterial({map:M.glowT,color:lc(RAR[w.r].c),transparent:true,opacity:.3,depthWrite:false,blending:THREE.AdditiveBlending}),sz=[0,0,.22,.3,.4,.55][w.r];G.aura=new THREE.Sprite(am);G.aura.userData.ownMat=1;G.aura.scale.set(sz,sz,1);G.aura.position.set(0,wm.by,G.wlen*.45);g.add(G.aura);}
  if(w.r>=4){const om=new THREE.MeshBasicMaterial({color:lc(RAR[w.r].c)});G.orbs=[];for(let i=0;i<(w.r===5?4:2);i++){const o=P('sph',om,.014,.014,.014,0,0,0,g);o.castShadow=false;o.userData.ownMat=1;G.orbs.push(o);}}
  const rm=new THREE.MeshBasicMaterial({color:lc(RAR[w.r].c)}),rb=P('box',rm,.008,.008,.07,-.024,wm.by+.012,.03,g);rb.castShadow=false;rb.userData.ownMat=1;rb.visible=w.r>0;/* armi comuni: niente barretta (vicino alla camera sembrava un rettangolo grigio) */
  if(v.glow){const gm=new THREE.MeshBasicMaterial({color:lc(v.glow)}),o=P('sph',gm,.05,.05,.05,0,wm.by,wm.mz-wm.tz+.01,g);o.castShadow=false;o.userData.ownMat=1;}
  const hd=P('sph',M.dark,.1,.11,.12,.01,-.07,.035,g),fa=P('cyl',M.dark,.1,.6,.1,.08,-.33,.27,g);fa.rotation.set(-.9,0,-.25);hd.castShadow=fa.castShadow=false;
  G.muz=new THREE.Object3D();G.muz.position.set(0,wm.by,wm.mz-wm.tz-.02);g.add(G.muz);
  const fm=new THREE.SpriteMaterial({map:M.glowT,color:v.glow||(w.r>=3?RAR[w.r].c:0xffd080),transparent:true,depthWrite:false,blending:THREE.AdditiveBlending});G.mfs=new THREE.Sprite(fm);G.mfs.userData.ownMat=1;G.mfs.position.copy(G.muz.position);G.mfs.visible=false;g.add(G.mfs);
  if(!BEAM)BEAM=new THREE.Mesh(GEO.box,M.beam);BEAM.visible=false;fxG.add(BEAM);return;}
 const bm=new THREE.MeshStandardMaterial({color:lc(v.c),roughness:.42,metalness:.6}),rm=new THREE.MeshStandardMaterial({color:lc(RAR[w.r].c),emissive:lc(RAR[w.r].c),emissiveIntensity:.45,roughness:.4});
 const pp=(geo,mat,sx,sy,sz,x,y,z)=>{const m=P(geo,mat,sx,sy,sz,x,y,z,g);m.castShadow=false;return m;};
 const[bw,bh,bd]=v.b;pp('box',bm,bw,bh,bd,0,0,-bd/2);pp('box',M.dark,bw*.8,bh*.5,bd*.5,0,-bh*.2,-bd*.3);pp('box',rm,bw+.006,.014,bd*.7,0,bh*.18,-bd*.5);
 const gr=pp('box',M.dark,bw*.8,.13,.05,0,-bh/2-.05,-.04);gr.rotation.x=.3;if(v.mag)pp('box',M.dark,bw*.7,.14,.06,0,-bh/2-.06,-bd*.55);if(v.drum){const d=pp('cyl',M.steel,.07,.07,.07,0,.01,-bd*.6);d.rotation.x=Math.PI/2;}
 const off=v.n===2?[[-.024,0],[.024,0]]:v.n===3?[[-.03,-.02],[.03,-.02],[0,.03]]:[[0,0]];for(const o of off){const b=pp('cyl',M.dark,v.br*2,v.bl,v.br*2,o[0],bh*.15+o[1],-bd-v.bl/2);b.rotation.x=Math.PI/2;}
 pp('box',M.dark,.012,.03,.012,0,bh/2+.015,-bd+.02);if(v.scope){const s=pp('cyl',M.dark,.05,.26,.05,0,bh/2+.045,-bd*.5);s.rotation.x=Math.PI/2;const l=pp('cyl',rm,.04,.005,.04,0,bh/2+.045,-bd*.5+.132);l.rotation.x=Math.PI/2;}
 if(v.glow){const gm=new THREE.MeshBasicMaterial({color:lc(v.glow)});const o=pp('sph',gm,bw*.9,bw*.9,bw*.9,0,bh*.3,-bd*.7);o.userData.ownMat=1;}
 const hd=pp('sph',M.dark,.1,.1,.12,.01,-bh/2-.06,-.03),fa=pp('cyl',M.dark,.1,.6,.1,.08,-bh/2-.3,.22);fa.rotation.set(-.9,0,-.25);
 g.traverse(m=>{if(m.material===bm||m.material===rm)m.userData.ownMat=1;});
 G.muz=new THREE.Object3D();G.muz.position.set(0,bh*.15,-bd-v.bl-.02);g.add(G.muz);
 const fm=new THREE.SpriteMaterial({map:M.glowT,color:v.glow||0xffd080,transparent:true,depthWrite:false,blending:THREE.AdditiveBlending});G.mfs=new THREE.Sprite(fm);G.mfs.userData.ownMat=1;G.mfs.position.copy(G.muz.position);G.mfs.visible=false;g.add(G.mfs);
 if(!BEAM)BEAM=new THREE.Mesh(GEO.box,M.beam);BEAM.visible=false;fxG.add(BEAM);}
function swapW(){if(S.eq.length<2)return;G.wi=(G.wi+1)%S.eq.length;G.rel=0;G.cdw=.3;G.beam=0;buildWeapon();snd('rel');for(const id of['swap','wp']){const e=$(id);e.classList.remove('go');void e.offsetWidth;e.classList.add('go');}hudUp();}
function cast(o,d,far){RC.set(o,d);RC.far=far||140;const hs=RC.intersectObjects([world,enG,prG],true);for(const h of hs){const u=h.object.userData;if(u.e){if(u.e.dead)continue;if(u.px){const h2=hs.find(q=>q.object.userData.e===u.e&&q.object.userData.head&&q.distance<h.distance+1.6);if(h2)return{h:h2,e:u.e,head:true,shield:false};}return{h,e:u.e,head:!!u.head,shield:!!u.shield};}if(u.proj){if(u.proj.dead)continue;return{h,proj:u.proj};}if(u.prop){if(u.prop.type==='chest'&&(u.prop.dead||u.prop.locked))return{h};return{h,prop:u.prop};}return{h};}return null;}
function proj2(v){PV.copy(v).project(cam);return PV.z>1?null:[(PV.x*.5+.5)*innerWidth,(-PV.y*.5+.5)*innerHeight];}
function ePos(e,o,head){o.copy(e.root.position);o.y+=head?e.hy:e.cy;return o;}
function aimDir(){RC.setFromCamera(ndc,cam);const d=RC.ray.direction.clone(),h=cast(cam.position,d);if(h&&(h.e||h.proj))return d;
 let best=null,bd=38;const chk=p=>{const s=proj2(p);if(!s)return;const q=Math.hypot(s[0]-aim.cx,s[1]-aim.cy);if(q<bd){bd=q;best=p.clone();}};
 for(const e of G.en)if(!e.dead){chk(ePos(e,TV,true));chk(ePos(e,TV,false));}for(const p of G.eproj)if(!p.dead)chk(p.m.position);
 return best?best.sub(cam.position).normalize():d;}
function boomAt(p,dmg,ex){const r=2.4;for(const e of G.en.slice())if(!e.dead&&e!==ex){const d=ePos(e,TV).distanceTo(p);if(d<r+.4)dmgE(e,dmg*.55*(1-.5*Math.min(1,d/r)),false,null);}
 for(const q of G.props.slice())if(!q.dead&&q.si===G.si&&q.cp.distanceTo(p)<r)hitProp(q,dmg*.4,q.cp.clone().setY(.8));
 if(G.boomN>0&&G.t-(G.boomT||0)>.11){G.boomN--;G.boomT=G.t;glow(p,2.9,0xffa040,.24,5);glow(p,1.4,0xfff0c0,.13,6);glow(p,2,0x151312,.7,1.6,false).fade=.5;bits(p,5,M.spark,5,.045,.45);snd('boom');xl.position.copy(p);xl.intensity=2.6;}}
function traitHit(e,dmg,pt){const tr=G.tr;if(!tr)return;
 if(tr==='chain'){let n=0;for(const o of G.en){if(o===e||o.dead)continue;const q=ePos(o,new V3());if(q.distanceTo(pt)<7){tracer(pt.clone(),q,M.arc);dmgE(o,dmg*.6,false,q);if(++n>=3)break;}}}
 else if(tr==='vamp')G.hp=Math.min(G.mhp,G.hp+1);
 else if(tr==='ice'){if(!e.dead&&e.t!=='boss')e.frz=1.6;}}
function dmgE(e,d,head,pt){if(e.dead)return;const T=e.T;let c='#fff';if(head){d*=2;c='#ffd65a';}else if(T.armor)d*=T.armor;if(Math.random()<pk('ct')*.05){d*=2;c='#ff5a5a';}
 e.hp-=d;e.fl=.12;G.hitM=.15;G.hitHead=head;if(head)snd('head');if(pt){bits(pt,head?5:3,T.m==='human'?M.gore:M.spark,2.2,.035,.3);G.dn.push({p:pt.clone(),txt:Math.round(d),life:.7,c});}
 if(head&&(e.state==='aim'||e.state==='watch')&&T.m==='human'){e.state='hide';e.st=1.2;relTok(e);}if(e.hp<=0)kill(e);}
function kill(e,noRw){e.dead=true;if(G.qte&&G.qte.own===e){G.qte=null;qsHide();}if(G.wnd===e)G.wnd=null;relTok(e);e.las.visible=false;fxG.remove(e.las);if(e.slot)e.slot.used=null;if(e.cnt)G.kills++;G.lastK=G.t;const T=e.T,p=ePos(e,new V3());
 if(!noRw){const tr=G.tr,cr=Math.round(T.cr*(1+.1*G.L)*rr(.8,1.2)*(1+.1*pk('cr'))*(tr==='midas'?3:1));
  if(tr==='vamp')G.hp=Math.min(G.mhp,G.hp+8);else if(tr==='slow'){G.slow=2.5;snd('slow');}else if(tr==='hole'&&T.m!=='mech')G.bh.push({p:p.clone(),t:1.3,dmg:wst(cw()).dmg*2.5});
  else if(tr==='midas'&&e.mats)for(const m of e.mats){m.color.copy(lc(0xffc030));m.metalness=1;m.roughness=.25;m.map=null;m.needsUpdate=true;}
 G.earn+=cr;G.dn.push({p:p.clone().setY(p.y+.5),txt:'+'+cr+' ◈',life:1.1,c:'#ffd65a'});
  const r=Math.random();if(r<.1&&G.hp<G.mhp){G.hp=Math.min(G.mhp,G.hp+20);toast('<span style="color:#5fe08f">+20 vita</span>',1200);}else if(r<.16&&G.ar<150){G.ar=Math.min(150,G.ar+20);toast('<span style="color:#6cc4ff">+20 armatura</span>',1200);}}
 if(e.rob){snd('kill');snd('metal');for(const k in e.act)if(k!=='Death')e.act[k].stop();e.act.Death.reset().play();}else if(T.m==='human'){snd('kill');}else{if(!noRw)explode(p,T.m==='mech'?5:1.6,0);bits(p,T.m==='mech'?30:8,M.scrap,5,.12,1.4);enG.remove(e.root);e.gone=true;}
 if(e.t==='boss'){G.boss=null;for(const m of G.doorP)m.material=M.door;musicStart('level');toast('<b style="color:#6cf">'+chOf(G.L).boss+' abbattuto!</b>',3000);for(const o of G.en)if(!o.dead)kill(o,true);
  const ch=mkChest(G.stages[G.si],rr(-1,1),-9,0,true);ch.boss=true;}}
function explode(p,r,dmg){PF.m.push('ex');glow(p,r*1.6,0xffa040,.3,5);glow(p,r*.9,0xfff0c0,.16,6);for(let i=0;i<4;i++){TV.set(p.x+rr(-.5,.5)*r*.4,p.y+rr(0,.5),p.z+rr(-.5,.5)*r*.4);glow(TV,r*.9,0x151312,1.3,1.4,false).fade=.5;}bits(p,12,M.spark,6,.05,.6);
 snd('boom');xl.position.copy(p);xl.intensity=4;G.shake=Math.max(G.shake,clamp(5/Math.max(1,Math.abs(p.z-G.cz)),.08,.6));if(!dmg)return;
 for(const e of G.en.slice())if(!e.dead){const d=ePos(e,TV).distanceTo(p);if(d<r+.5)dmgE(e,dmg*(1-.6*Math.min(1,d/r)),false,null);}
 for(const q of G.props.slice())if(!q.dead&&q.si===G.si&&q.cp.distanceTo(p)<r+.3)hitProp(q,dmg*.8,q.cp.clone().setY(.8));
 for(const q of G.eproj.slice())if(!q.dead&&q.m.position.distanceTo(p)<r)detProj(q,true);}
function hitProp(p,d,pt){if(p.dead)return;switch(p.type){
 case'crate':if(p.hp==null){bits(pt,3,M.spark,2.5,.03,.25);if(Math.random()<.3)snd('ric');break;}p.hp-=d;bits(pt,3,M.chip,2,.05,.6);if(p.hp<=0){p.dead=true;p.mesh.parent.remove(p.mesh);bits(p.cp,14,M.chip,4,.16,1.4);snd('crash');}break;
 case'barrel':p.hp-=d;bits(pt,2,M.spark,2,.03,.2);if(p.hp<=0){p.dead=true;p.mesh.parent.remove(p.mesh);explode(p.cp.clone(),4.5,95*G.hs);}break;
 case'secret':p.hp-=d;bits(pt,3,M.spark,2.5,.03,.25);if(p.hp<=0){p.dead=true;p.mesh.parent.remove(p.mesh);bits(p.cp,14,M.scrap,4,.16,1.4);p.chest.locked=false;G.sfound++;snd('metal');snd('secret');toast('<span style="color:#ffd65a">★ Nascondiglio scoperto! Spara al baule</span>',2800);}break;
 case'chest':if(!p.locked)openChest(p);break;}}
function openChest(c){c.dead=true;c.open=1;snd('chest');TV.copy(c.cp);TV.y+=.3;glow(TV,2.2,c.gold?0xffd040:0xfff0c0,.5,2);
 const cr=Math.round((c.gold?60:25)*(1+.15*G.L)*rr(.8,1.3)*(1+.1*pk('cr')));G.earn+=cr;let msg=`<span style="color:#ffd65a">+${cr} ◈</span>`;
 if(c.gold||Math.random()<.4){const w=newWeapon(G.L*.06+(c.gold?1.2:0)+(c.boss?1.5:0),c.boss?1:0);if(S.eq.includes(w.id)&&G.ammo[w.id]==null)G.ammo[w.id]=wst(w).mag;msg+=` · ${wname(w)} <span style="color:${RAR[w.r].c}">[${RAR[w.r].n}]</span>`;if(!window.NOREV){state='reveal';aim.down=false;aim.hold=0;reveal(w,c.gold?'BAULE SEGRETO':'BAULE',()=>{state='play';});}}
 else if(G.hp<G.mhp){G.hp=Math.min(G.mhp,G.hp+25);msg+=' · <span style="color:#5fe08f">+25 vita</span>';}toast((c.gold?'★ ':'')+msg,3200);}
function shotRay(d,dmg,t,mz){const far=t.range?t.range*2:140,o=cam.position,hit=cast(o,d,far);let end;
 if(!hit)end=o.clone().addScaledVector(d,Math.min(far,60));else{end=hit.h.point;const fo=t.range&&hit.h.distance>t.range?Math.max(.25,1-(hit.h.distance-t.range)/t.range):1;
  if(hit.e&&hit.shield&&!t.pierce){bits(end,3,M.spark,2.5,.03,.25);snd('ric');if(G.tr==='boom')boomAt(end,dmg*fo,null);}
  else if(hit.e){dmgE(hit.e,dmg*fo,hit.head,end);traitHit(hit.e,dmg*fo,end);if(G.tr==='boom')boomAt(end,dmg*fo,hit.e);if(t.pierce){const h2=cast(end.clone().addScaledVector(d,.7),d,far);if(h2&&h2.e&&h2.e!==hit.e)dmgE(h2.e,dmg,h2.head,h2.h.point);}}
  else if(hit.proj)detProj(hit.proj,true);else if(hit.prop){hitProp(hit.prop,dmg*fo,end);if(G.tr==='boom')boomAt(end,dmg*fo,null);}else{if(G.tr==='boom')boomAt(end,dmg*fo,null);bits(end,2,M.spark,2,.025,.2);if(!t.beam&&hit.h.distance>1.6&&hit.h.object.material!==M.inv)decal(hit.h);}}
 if(t.beam){G.beamEnd=end.clone();}else{const a=mz.clone().lerp(end,Math.min(.5,1.6/Math.max(.1,mz.distanceTo(end))));tracer(a,end,G.wr>=2?M.trR[G.wr]:undefined);}}
function fire(){const w=cw(),t=WT[w.t];if(G.cdw>0||G.lean<.85||!(G.ammo[w.id]>0)||G.mv)return false;if(!t.inf&&G.tr!=='inf')G.ammo[w.id]--;G.mflash=.05;
 // Minigun (inf): colpi infiniti; la cadenza sale coi giri delle canne (G.gsp 0..1, armi-ambienti.js) e il resto del tempo si conserva, così la cadenza non dipende dagli fps
 if(t.inf){G.gshot=G.t;const r=t.rate/(.35+.65*(G.gsp||0));G.cdw=(G.cdw>-r?G.cdw:0)+r;G.kick=.45+Math.random()*.3;}else{G.cdw=t.rate;G.kick=t.beam?.25:1;}
 if(t.beam){G.beam=.08;if((G.lz=(G.lz||0)+1)%3===0)snd('zap');}else snd('w_'+w.t);const base=aimDir(),tri=G.tr==='tri',dmg=wst(w).dmg*(tri?.6:1),mz=G.muz.getWorldPosition(new V3()),right=tri?new V3(1,0,0).applyQuaternion(cam.quaternion):null;G.boomN=2;
 for(let f=0;f<(tri?3:1);f++){const b0=tri?base.clone().addScaledVector(right,(f-1)*.075).normalize():base;
  if(t.proj){const m=new THREE.Mesh(GEO.sph,new THREE.MeshBasicMaterial({color:t.proj==='plasma'?lc(0x80e8ff):lc(0xffb060)}));m.userData.ownMat=1;const q=t.proj==='plasma'?.22:.16;m.scale.set(q,q,q*2);m.position.copy(mz);m.lookAt(mz.clone().add(b0));fxG.add(m);G.pproj.push({m,d:b0,spd:t.proj==='plasma'?38:26,dmg,r:t.splash*2.1,life:3});}
  else for(let i=0,n=t.pel||1,sq=t.spread*Math.max(.3,1-.07*cw().l);i<n;i++){const d=b0.clone();d.x+=(Math.random()-.5)*2*sq;d.y+=(Math.random()-.5)*1.4*sq;d.z+=(Math.random()-.5)*2*sq;shotRay(d.normalize(),dmg,t,mz);}}
 return true;}
function hurt(d,force){if(G.inv>0||(!force&&G.lean<.4))return;if(G.ar>0){const a=Math.min(G.ar,d*.6);G.ar-=a;d-=a;}G.hp-=d;G.hurtFx=.5;G.shake=Math.max(G.shake,.25);snd('hurt');if(G.hp<=0){G.hp=0;endLevel(false);}}
