// Settore Zero — renderer, texture procedurali, geometrie, particelle, caricamento modelli
'use strict';
/* ===== renderer ===== */
const rr=(a,b)=>a+Math.random()*(b-a),clamp=(v,a,b)=>v<a?a:v>b?b:v,mix=(a,b,t)=>a+(b-a)*t;
const V3=THREE.Vector3,lc=h=>new THREE.Color(h).convertSRGBToLinear();
const renderer=new THREE.WebGLRenderer({canvas:cv,antialias:(window.devicePixelRatio||1)<2,powerPreference:'high-performance'});
renderer.outputEncoding=THREE.sRGBEncoding;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.12;
renderer.shadowMap.enabled=true;renderer.localClippingEnabled=true;renderer.shadowMap.type=THREE.PCFShadowMap;renderer.shadowMap.autoUpdate=false;renderer.shadowMap.needsUpdate=true;
const scene=new THREE.Scene(),cam=new THREE.PerspectiveCamera(78,1,.05,160);cam.rotation.order='YXZ';scene.add(cam);
let world=new THREE.Group();const enG=new THREE.Group(),prG=new THREE.Group(),fxG=new THREE.Group();scene.add(world,enG,prG,fxG);
const hemi=new THREE.HemisphereLight(0xffffff,0x18181c,.38);scene.add(hemi);
(function(){try{const pm=new THREE.PMREMGenerator(renderer),sc=new THREE.Scene(),mk=(c,k,w,h,d,x,y,z,bs)=>{const m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),new THREE.MeshBasicMaterial({color:new THREE.Color(c).multiplyScalar(k),side:bs?THREE.BackSide:THREE.FrontSide}));m.position.set(x,y,z);sc.add(m);};
 mk(0x3a3e46,.1,10,6,10,0,0,0,1);mk(0xffffff,1.6,1.2,.1,6,-2.5,2.9,0);mk(0xffffff,1.6,1.2,.1,6,2.5,2.9,0);mk(0xffb070,.5,.1,3,8,-4.9,0,0);mk(0x70b0ff,.4,.1,3,8,4.9,0,0);
 scene.environment=pm.fromScene(sc,.04).texture;pm.dispose();}catch(e){}})();
const spot=new THREE.SpotLight(0xffffff,1.5,70,1.0,.75,1);spot.castShadow=true;spot.shadow.mapSize.set(1024,1024);spot.shadow.bias=-.002;spot.shadow.camera.near=1;spot.shadow.camera.far=50;scene.add(spot,spot.target);
const pl1=new THREE.PointLight(0xffffff,.9,28,1.5),pl2=new THREE.PointLight(0xffffff,1.2,34,1.5),mfl=new THREE.PointLight(0xffc880,0,16,1.5),xl=new THREE.PointLight(0xff9a40,0,24,1.5);scene.add(pl1,pl2,mfl,xl);
let DPR=1;
function resize(){const w=innerWidth,h=innerHeight;DPR=Math.min(devicePixelRatio||1,S.gfx===0?1:2);renderer.setPixelRatio(DPR);renderer.setSize(w,h,false);cam.aspect=w/h;cam.fov=w<h?70:55;cam.updateProjectionMatrix();ODPR=Math.min(DPR,1.5);ov.width=w*ODPR;ov.height=h*ODPR;renderer.shadowMap.needsUpdate=true;spot.castShadow=S.gfx!==0;}
addEventListener('resize',resize);

/* ===== procedural textures (color + normal) ===== */
const NZ=[];for(let o=0;o<6;o++){const s=4<<o,a=new Float32Array(s*s);for(let i=0;i<a.length;i++)a[i]=Math.random();NZ.push([s,a]);}
function vn(o,u,v){const s=NZ[o][0],a=NZ[o][1],x=u*s,y=v*s,xf=Math.floor(x),yf=Math.floor(y);let fx=x-xf,fy=y-yf;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);
 const x0=((xf%s)+s)%s,y0=((yf%s)+s)%s,x1=(x0+1)%s,y1=(y0+1)%s,A=a[y0*s+x0],B=a[y0*s+x1],C=a[y1*s+x0],D=a[y1*s+x1];return A+(B-A)*fx+(C-A)*fy+(A-B-C+D)*fx*fy;}
function fbm(u,v,st,n){let t=0,a=.5,w=0;for(let i=0;i<n;i++){t+=vn(Math.min(5,st+i),u,v)*a;w+=a;a*=.5;}return t/w;}
const edge=(t,w)=>Math.min(1,Math.min(t,1-t)/w);
function makeTex(n,fn,ns){const c=document.createElement('canvas');c.width=c.height=n;const g=c.getContext('2d'),im=g.createImageData(n,n),d=im.data,h=new Float32Array(n*n),o=[0,0,0,0];
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){fn(x/n,y/n,o);const i=y*n+x;d[i*4]=o[0];d[i*4+1]=o[1];d[i*4+2]=o[2];d[i*4+3]=255;h[i]=o[3];}
 g.putImageData(im,0,0);const map=new THREE.CanvasTexture(c);map.encoding=THREE.sRGBEncoding;map.wrapS=map.wrapT=THREE.RepeatWrapping;map.anisotropy=4;
 const c2=document.createElement('canvas');c2.width=c2.height=n;const g2=c2.getContext('2d'),im2=g2.createImageData(n,n),e=im2.data;
 for(let y=0;y<n;y++)for(let x=0;x<n;x++){const i=y*n+x,nx=(h[y*n+((x+n-1)%n)]-h[y*n+((x+1)%n)])*ns,ny=(h[((y+1)%n)*n+x]-h[((y+n-1)%n)*n+x])*ns,il=1/Math.hypot(nx,ny,1);e[i*4]=(nx*il*.5+.5)*255;e[i*4+1]=(ny*il*.5+.5)*255;e[i*4+2]=(il*.5+.5)*255;e[i*4+3]=255;}
 g2.putImageData(im2,0,0);const nm=new THREE.CanvasTexture(c2);nm.wrapS=nm.wrapT=THREE.RepeatWrapping;nm.anisotropy=4;return{map,nm};}
const PAT={
 concrete:b=>(u,v,o)=>{const pu=u*2%1,pv=v*2%1,s=Math.min(edge(pu,.014),edge(pv,.014)),n=fbm(u,v,1,5),st=fbm(u*8,v,2,3),pit=vn(5,u*2,v*2)>.9?.72:1,
   bolt=Math.hypot(Math.min(pu,1-pu)-.06,Math.min(pv,1-pv)-.06)<.016;let k=(.7+n*.5-st*.2)*pit*(.4+.6*s);if(bolt)k*=.45;
   o[0]=b[0]*k;o[1]=b[1]*k;o[2]=b[2]*k;o[3]=n*.35+s*.6-(bolt?.4:0)-(1-pit);},
 plate:b=>(u,v,o)=>{const pu=u*2%1,pv=v*4%1,s=Math.min(edge(pu,.01),edge(pv,.02)),br=vn(5,u,v*24)*.5+vn(4,u*3,v*40)*.5,n=fbm(u,v,1,4),rust=clamp((n-.66)*5,0,1)*.7,
   rv=Math.abs(pu*8%1-.5)<.1&&((pv>.04&&pv<.1)||(pv>.9&&pv<.96));let k=(.78+br*.22+n*.18)*(.35+.65*s);if(rv)k*=1.35;
   o[0]=mix(b[0]*k,140*k,rust);o[1]=mix(b[1]*k,78*k,rust);o[2]=mix(b[2]*k,46*k,rust);o[3]=.5*s+(rv?.5:0)+br*.06+rust*.12;},
 floor:b=>(u,v,o)=>{const pu=u*4%1,pv=v*4%1,s=Math.min(edge(pu,.022),edge(pv,.022)),n=fbm(u,v,0,5),g=fbm(u*2,v*2,2,4),sp=vn(5,u*4,v*4);
   const k=(.6+n*.45+sp*.14)*(.4+.6*s)*(g>.6?.72:1);o[0]=b[0]*k;o[1]=b[1]*k;o[2]=b[2]*k;o[3]=s*.6+n*.2+sp*.1;},
 wood:()=>(u,v,o)=>{const fr=Math.min(u,1-u,v,1-v)<.11,pl=fr?0:Math.floor(v*6),pv=v*6%1,gr=vn(5,u*2+pl*.37,v*14)*.6+vn(3,u+pl*.21,v*6)*.4,s=fr?1:edge(pv,.07),dg=!fr&&Math.abs(u-v)<.075;
   let k=(fr?.6:.8)+gr*.38;k*=.45+.55*s;if(dg)k*=.78;const nail=fr&&Math.hypot((u*6%1)-.5,(v*6%1)-.5)<.1&&(Math.min(u,1-u)<.09||Math.min(v,1-v)<.09);if(nail)k*=.35;
   o[0]=158*k;o[1]=112*k;o[2]=66*k;o[3]=(fr?.85:.45)+(dg?.28:0)+s*.2+gr*.14-(nail?.3:0);},
 mcrate:b=>(u,v,o)=>{const fr=Math.min(u,1-u,v,1-v)<.07,cor=Math.sin(u*Math.PI*2*12)*.5+.5,n=fbm(u,v,1,4),rust=clamp((n-.63)*5,0,1),lab=!fr&&u>.3&&u<.7&&v>.38&&v<.62,st=lab&&((u+v)*10%1<.5);
   let k=fr?.6+n*.2:.72+cor*.28+n*.12;let c=b;if(lab)c=st?[210,170,30]:[26,26,28];o[0]=mix(c[0]*k,130*k,rust);o[1]=mix(c[1]*k,74*k,rust);o[2]=mix(c[2]*k,44*k,rust);o[3]=fr?.9:cor*.5;},
 hazard:()=>(u,v,o)=>{const n=fbm(u,v,1,5),band=v<.3,st=(u*10+v*10)%1<.5,pit=vn(5,u*2,v*2)>.9?.85:1,k=(.72+n*.45)*pit;
   if(band){const c=st?[214,170,28]:[30,30,32];o[0]=c[0]*k;o[1]=c[1]*k;o[2]=c[2]*k;}else{o[0]=132*k;o[1]=130*k;o[2]=124*k;}o[3]=n*.4-(1-pit)+(Math.abs(v-.3)<.01?-.3:0);},
 barrel:()=>(u,v,o)=>{const rib=Math.abs(v-.32)<.022||Math.abs(v-.68)<.022,n=fbm(u,v,1,4),d=Math.abs((u*2%1)-.5)+Math.abs(v-.5),lab=d<.13,inn=d<.06,sc=vn(5,u*3,v*30)>.8;
   let k=.75+n*.4;if(rib)k*=.6;if(sc)k*=.8;let c=[168,36,28];if(lab)c=inn?[20,20,20]:[224,180,30];o[0]=c[0]*k;o[1]=c[1]*k;o[2]=c[2]*k;o[3]=(rib?.9:.4)+n*.1;},
 locker:cr=>(u,v,o)=>{const fr=Math.min(u,1-u,v,1-v)<.03,seam=Math.abs(u-.5)<.007,vent=v>.1&&v<.22&&(Math.abs(u-.25)<.15||Math.abs(u-.75)<.15)&&(v*50%1<.5),hd=Math.abs(v-.52)<.05&&(Math.abs(u-.45)<.012||Math.abs(u-.55)<.012),n=fbm(u,v,1,4),br=vn(5,u*30,v);
   let k=.8+n*.2+br*.1;if(fr||seam)k*=.4;if(vent)k*=.25;if(hd)k*=1.6;let h=.5+(fr?.3:0)-(seam?.4:0)-(vent?.3:0)+(hd?.4:0);
   if(cr){const c1=.28+.1*Math.sin(v*17)+.04*Math.sin(v*53),c2=.7+.07*Math.sin(v*23),dent=Math.hypot(u-.62,v-.62);if((v>.2&&Math.abs(u-c1)<.011)||(v>.4&&v<.9&&Math.abs(u-c2)<.008)){k*=.2;h-=.5;}if(dent<.2){k*=.65+dent*1.7;h-=(.2-dent)*2;}}
   o[0]=92*k;o[1]=106*k;o[2]=120*k;o[3]=h;}
};
const TXC={};
function tx(key,n,fn,ns){return TXC[key]||(TXC[key]=makeTex(n,fn,ns||3));}
function sMat(t,o){return new THREE.MeshStandardMaterial(Object.assign({map:t.map,normalMap:t.nm,roughness:.82,metalness:.08},o||{}));}
const TH=[
 {wall:[150,146,138],floor:[112,110,104],ceil:[86,86,90],fog:0x0c0d10,amb:0xa8b2c8,l1:0xffe0b0,l2:0xff9040,met:0},
 {wall:[186,196,200],floor:[140,150,156],ceil:[120,128,132],fog:0x0a1317,amb:0xc8ecff,l1:0xe4f8ff,l2:0x40d8e8,met:1},
 {wall:[150,100,82],floor:[104,80,70],ceil:[78,58,52],fog:0x150906,amb:0xffb888,l1:0xffb878,l2:0xff5020,met:0},
 {wall:[104,134,96],floor:[86,104,74],ceil:[62,80,60],fog:0x070e06,amb:0xc0ffb8,l1:0xe0ffb8,l2:0x80ff40,met:0},
 {wall:[130,160,192],floor:[104,130,160],ceil:[88,108,138],fog:0x0a1322,amb:0xb8d4ff,l1:0xd8ecff,l2:0x50a0ff,met:1},
 {wall:[112,92,140],floor:[86,70,112],ceil:[62,50,86],fog:0x0f0716,amb:0xd8b0ff,l1:0xf4d0ff,l2:0xff40d0,met:1}];
const M={};let curTh=-1;
function baseMats(){if(M.wood)return;
 M.wood=sMat(tx('wood',256,PAT.wood(),4),{roughness:.85});M.mcrate=sMat(tx('mcrate',256,PAT.mcrate([70,96,84]),4),{roughness:.55,metalness:.5});
 M.mcrateB=sMat(tx('mcrateB',256,PAT.mcrate([58,84,124]),4),{roughness:.55,metalness:.5});M.mcrateR=sMat(tx('mcrateR',256,PAT.mcrate([128,72,52]),4),{roughness:.6,metalness:.45});
 M.hazard=sMat(tx('hazard',256,PAT.hazard(),4),{roughness:.9});M.barrel=sMat(tx('barrel',256,PAT.barrel(),4),{roughness:.5,metalness:.45});
 M.locker=sMat(tx('locker',256,PAT.locker(0),4),{roughness:.5,metalness:.55});M.lockerC=sMat(tx('lockerC',256,PAT.locker(1),5),{roughness:.6,metalness:.5});
 M.steel=new THREE.MeshStandardMaterial({color:lc(0x8a9098),roughness:.4,metalness:.8});M.dark=new THREE.MeshStandardMaterial({color:lc(0x1a1c20),roughness:.7,metalness:.3});
 M.shield=new THREE.MeshStandardMaterial({color:lc(0x2a3442),roughness:.55,metalness:.6});
 M.gold=new THREE.MeshStandardMaterial({color:lc(0xffc040),roughness:.3,metalness:.85,emissive:lc(0x664400),emissiveIntensity:.5});M.purple=new THREE.MeshStandardMaterial({color:lc(0xb45cff),roughness:.4,metalness:.5,emissive:lc(0x5a1faa),emissiveIntensity:.8});
 M.strip=new THREE.MeshBasicMaterial({color:lc(0xffffff)});M.door=new THREE.MeshBasicMaterial({color:lc(0x40ffa0)});M.doorL=new THREE.MeshBasicMaterial({color:lc(0xff4050)});
 M.spark=new THREE.MeshBasicMaterial({color:lc(0xffe9a0)});M.gore=new THREE.MeshBasicMaterial({color:lc(0x7a1010)});M.chip=new THREE.MeshStandardMaterial({color:lc(0x9a6c3c),roughness:.9});M.scrap=new THREE.MeshStandardMaterial({color:lc(0x60666e),roughness:.5,metalness:.6});
 M.tracer=new THREE.MeshBasicMaterial({color:lc(0xfff0b0),transparent:true,opacity:.7,blending:THREE.AdditiveBlending,depthWrite:false});
 M.etr=new THREE.MeshBasicMaterial({color:lc(0xff6a40),transparent:true,opacity:.8,blending:THREE.AdditiveBlending,depthWrite:false});
 M.las=new THREE.MeshBasicMaterial({color:lc(0xff2020),transparent:true,opacity:.55,blending:THREE.AdditiveBlending,depthWrite:false});
 M.beam=new THREE.MeshBasicMaterial({color:lc(0xff5a78),transparent:true,opacity:.85,blending:THREE.AdditiveBlending,depthWrite:false});
 M.inv=new THREE.MeshBasicMaterial({visible:false});M.hole0=new THREE.MeshBasicMaterial({color:0x000000});
 M.trR=RAR.map(r=>new THREE.MeshBasicMaterial({color:lc(r.c),transparent:true,opacity:.85,blending:THREE.AdditiveBlending,depthWrite:false}));M.arc=new THREE.MeshBasicMaterial({color:lc(0x80e8ff),transparent:true,opacity:.9,blending:THREE.AdditiveBlending,depthWrite:false});
 M.hole=new THREE.MeshBasicMaterial({color:lc(0x050505),transparent:true,opacity:.75,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2});
 const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d'),gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'rgba(255,255,255,1)');gr.addColorStop(.35,'rgba(255,255,255,.55)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);M.glowT=new THREE.CanvasTexture(c);}
function setTheme(i){baseMats();if(i===curTh)return;curTh=i;const t=TH[i];for(const k of['wall','floor','ceil'])if(M[k]){M[k].map.dispose();M[k].normalMap.dispose();M[k].dispose();}
 M.wall=sMat(makeTex(512,(t.met?PAT.plate:PAT.concrete)(t.wall),t.met?3:4),t.met?{roughness:.5,metalness:.45}:{roughness:.9});
 M.floor=sMat(makeTex(512,PAT.floor(t.floor),4),{roughness:.7,metalness:.15});M.ceil=sMat(makeTex(256,PAT.plate(t.ceil),3),{roughness:.7,metalness:.3});
 scene.fog=new THREE.FogExp2(t.fog,.02);scene.background=new THREE.Color(t.fog);hemi.color.set(t.amb);spot.color.set(t.l1);pl1.color.set(t.l1);pl2.color.set(t.l2);M.strip.color.set(t.l1);
 if(HM.Wall_Roof_White){const c=a=>new THREE.Color(a[0]/255,a[1]/255,a[2]/255).convertSRGBToLinear();HM.Wall_Roof_White.color.copy(c(t.wall)).lerp(new THREE.Color(1,1,1),.35);HM.Wall_Roof_White.roughness=.38;
  HM.Wall_Black.color.copy(lc(0x07090c));HM.Wall_Black.roughness=.42;HM.Wall_Black.metalness=.5;HM.lambert1.color.copy(c(t.floor));HM.lambert1.roughness=.6;
  HM.Floor_and_vent.color.copy(lc(0x101317));HM.Floor_and_vent.roughness=.38;HM.Floor_and_vent.metalness=.8;HM.Floor_vent.roughness=.42;
  HM.Wall_blue.emissive.copy(lc(t.l2));HM.Vent_light.emissive.copy(lc(t.l1));HM.Glass.opacity=.1;scene.fog.density=.012;}}

/* ===== geometry helpers ===== */
const GEO={box:new THREE.BoxGeometry(1,1,1),sph:new THREE.SphereGeometry(.5,14,10),cyl:new THREE.CylinderGeometry(.5,.5,1,12),disc:new THREE.CircleGeometry(.5,10)};
function box(w,h,d,mat,x,y,z,ts){const g=new THREE.BoxGeometry(w,h,d);if(ts){const uv=g.attributes.uv,dm=[[d,h],[d,h],[w,d],[w,d],[w,h],[w,h]];for(let f=0;f<6;f++)for(let i=0;i<4;i++){const k=f*4+i;uv.setXY(k,uv.getX(k)*dm[f][0]/ts,uv.getY(k)*dm[f][1]/ts);}}
 const m=new THREE.Mesh(g,mat);m.position.set(x,y,z);m.receiveShadow=true;m.userData.own=1;return m;}
function P(geo,mat,sx,sy,sz,x,y,z,par){const m=new THREE.Mesh(GEO[geo],mat);m.scale.set(sx,sy,sz);m.position.set(x,y,z);m.castShadow=true;par.add(m);return m;}
function clearGroup(g){for(let i=g.children.length-1;i>=0;i--){const c=g.children[i];g.remove(c);c.traverse(m=>{if(m.geometry&&m.userData.own)m.geometry.dispose();if(m.material&&m.userData.ownMat)m.material.dispose();if(m.isSkinnedMesh&&m.skeleton&&m.skeleton.boneTexture)m.skeleton.dispose();});}}

/* ===== particles / fx ===== */
const parts=[];
const GLP=[[],[]];
function pAdd(m,v,life,g,o){fxG.add(m);const p=Object.assign({m,v,life,ml:life,g},o);parts.push(p);return p;}
function bits(pt,n,mat,sp,sz,life){for(let i=0;i<n;i++){const m=new THREE.Mesh(GEO.box,mat),s=sz*rr(.5,1.3);m.scale.set(s,s,s);m.position.copy(pt);pAdd(m,new V3(rr(-1,1)*sp,rr(.2,1.4)*sp,rr(-1,1)*sp),life*rr(.6,1.2),9.8,{spin:rr(4,12),shrink:1});}}
function glow(pt,size,color,life,grow,add){if(parts.length>170&&life<.6)return null;const pk_=add===false?1:0;let mt=GLP[pk_].pop();if(!mt)mt=new THREE.SpriteMaterial({map:M.glowT,transparent:true,depthWrite:false,blending:pk_?THREE.NormalBlending:THREE.AdditiveBlending});mt.color.set(color);mt.opacity=1;const s=new THREE.Sprite(mt);s.userData.pool=pk_;s.scale.set(size,size,1);s.position.copy(pt);return pAdd(s,new V3(0,add===false?.6:0,0),life,0,{fade:1,grow:grow||0});}
function seg(m,a,b,th){m.position.copy(a).add(b).multiplyScalar(.5);m.lookAt(b);m.scale.set(th,th,Math.max(.01,a.distanceTo(b)));}
function tracer(a,b,mat){const m=new THREE.Mesh(GEO.box,mat||M.tracer);if(mat===M.etr){const d=a.distanceTo(b);b=a.clone().lerp(b,Math.max(.3,1-2.2/d));}seg(m,a,b,.014);pAdd(m,new V3(),.055,0,{});}
function updParts(dt){for(let i=parts.length-1;i>=0;i--){const p=parts[i];p.life-=dt;if(p.life<=0){fxG.remove(p.m);if(p.m.userData.pool!==undefined){if(GLP[p.m.userData.pool].length<120)GLP[p.m.userData.pool].push(p.m.material);}else if(p.m.userData.ownMat)p.m.material.dispose();parts.splice(i,1);continue;}
 p.m.position.addScaledVector(p.v,dt);if(p.g){p.v.y-=p.g*dt;if(p.m.position.y<.03){p.m.position.y=.03;p.v.set(p.v.x*.4,-p.v.y*.3,p.v.z*.4);}}
 if(p.spin){p.m.rotation.x+=p.spin*dt;p.m.rotation.z+=p.spin*dt*.7;}const k=p.life/p.ml;if(p.fade)p.m.material.opacity=k*p.fade;if(p.grow)p.m.scale.multiplyScalar(1+p.grow*dt);if(p.shrink&&k<.3)p.m.scale.multiplyScalar(.9);}}
const holes=[];
function decal(h){if(!h.face)return;const n=h.face.normal.clone().transformDirection(h.object.matrixWorld);let m;if(holes.length>=36){m=holes.shift();}else{m=new THREE.Mesh(GEO.disc,M.hole);fxG.add(m);}
 holes.push(m);const s=rr(.07,.11);m.scale.set(s,s,s);m.position.copy(h.point).addScaledVector(n,.012);m.lookAt(h.point.clone().add(n));}

/* ===== modelli 3D ===== */
const MODELS={},HM={};let modelsReady=false;
function noRay(o){o.traverse(m=>{m.raycast=()=>{};});return o;}
function b64buf(s){const bin=atob(s),u=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);return u.buffer;}
const modelsP=new Promise(res=>{const ks=typeof ASSET==='undefined'||!THREE.GLTFLoader?[]:Object.keys(ASSET);let n=0;const done=()=>{if(++n>=ks.length){modelsReady=true;res();}};if(!ks.length){modelsReady=true;res();return;}
 const L=new THREE.GLTFLoader();ks.forEach(k=>{try{L.parse(b64buf(ASSET[k]),'',gl=>{MODELS[k]=gl;ASSET[k]=null;if(/^g_(ak|shotgun|flare|frag|luger)$/.test(k))gl.scene.traverse(m=>{if(m.isMesh&&m.material.normalScale)m.material.normalScale.y*=-1;});if(k==='hall')gl.scene.traverse(m=>{if(m.isMesh){HM[m.material.name]=m.material;m.receiveShadow=true;}});done();},()=>done());}catch(e){done();}});});
const RQ=new THREE.Quaternion(),_q=new THREE.Quaternion(),_pq=new THREE.Quaternion(),_Y=new V3(0,1,0),_d=new V3();
const AX=new WeakMap();
function aimBone(b,dx,dy,dz,k){let ax=AX.get(b);if(!ax){const c=b.children.find(o=>o.isBone);ax=c&&c.position.lengthSq()>1e-6?c.position.clone().normalize():_Y;AX.set(b,ax);}_d.set(dx,dy,dz).normalize().applyQuaternion(RQ);b.parent.updateWorldMatrix(true,false);b.parent.getWorldQuaternion(_pq);_q.setFromUnitVectors(ax,_d).premultiply(_pq.invert());b.quaternion.slerp(_q,k);}
