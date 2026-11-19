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
// luce ambiente: cielo = colore del tema (attenuato in setTheme), terreno quasi nero → più contrasto e volume
const HEMI_K=.72,hemi=new THREE.HemisphereLight(0xffffff,0x07070a,.38);scene.add(hemi);
// mappa d'ambiente (riflessi + luce indiretta dei materiali PBR): luce dall'alto, pareti e pavimento scuri
// (prima era molto chiara e appiattiva tutto, rendendo la scena sovraesposta)
(function(){try{const pm=new THREE.PMREMGenerator(renderer),sc=new THREE.Scene(),mk=(c,k,w,h,d,x,y,z,bs)=>{const m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),new THREE.MeshBasicMaterial({color:new THREE.Color(c).multiplyScalar(k),side:bs?THREE.BackSide:THREE.FrontSide}));m.position.set(x,y,z);sc.add(m);};
 mk(0x2e333c,.06,10,6,10,0,0,0,1);mk(0xfff4e6,1.05,1.2,.1,6,-2.5,2.9,0);mk(0xfff4e6,1.05,1.2,.1,6,2.5,2.9,0);mk(0xffa860,.28,.1,3,8,-4.9,.3,0);mk(0x6aa8ff,.24,.1,3,8,4.9,.3,0);mk(0x000000,0,9.8,.1,9.8,0,-2.95,0);
 scene.environment=pm.fromScene(sc,.04).texture;pm.dispose();}catch(e){}})();
const spot=new THREE.SpotLight(0xffffff,1.5,70,1.0,.75,1);spot.castShadow=true;spot.shadow.mapSize.set(1024,1024);spot.shadow.bias=-.002;spot.shadow.camera.near=1;spot.shadow.camera.far=50;scene.add(spot,spot.target);
// luci di stanza con caduta più rapida (pozze di luce e ombre invece di una luce uniforme che appiattiva la scena)
const pl1=new THREE.PointLight(0xffffff,.9,18,2),pl2=new THREE.PointLight(0xffffff,1.2,24,2.2),mfl=new THREE.PointLight(0xffc880,0,9,2),xl=new THREE.PointLight(0xff9a40,0,16,2);scene.add(pl1,pl2,mfl,xl);
let DPR=1;
function resize(){const w=innerWidth,h=innerHeight;DPR=Math.min(devicePixelRatio||1,S.gfx===0?1:2);renderer.setPixelRatio(DPR);renderer.setSize(w,h,false);cam.aspect=w/h;cam.fov=w<h?70:55;cam.updateProjectionMatrix();ODPR=Math.min(DPR,1.5);ov.width=w*ODPR;ov.height=h*ODPR;renderer.shadowMap.needsUpdate=true;spot.castShadow=S.gfx!==0;}
addEventListener('resize',resize);

/* ===== procedural textures (color + normal) ===== */
const NZ=[];for(let o=0;o<6;o++){const s=4<<o,a=new Float32Array(s*s);for(let i=0;i<a.length;i++)a[i]=Math.random();NZ.push([s,a]);}
function vn(o,u,v){const s=NZ[o][0],a=NZ[o][1],x=u*s,y=v*s,xf=Math.floor(x),yf=Math.floor(y);let fx=x-xf,fy=y-yf;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);
 const x0=((xf%s)+s)%s,y0=((yf%s)+s)%s,x1=(x0+1)%s,y1=(y0+1)%s,A=a[y0*s+x0],B=a[y0*s+x1],C=a[y1*s+x0],D=a[y1*s+x1];return A+(B-A)*fx+(C-A)*fy+(A-B-C+D)*fx*fy;}
function fbm(u,v,st,n){let t=0,a=.5,w=0;for(let i=0;i<n;i++){t+=vn(Math.min(5,st+i),u,v)*a;w+=a;a*=.5;}return t/w;}
const edge=(t,w)=>Math.min(1,Math.min(t,1-t)/w);
// PXW = larghezza di un pixel della texture in coordinate uv (serve per bordi anti-scalino)
let PXW=1/256;const sstep=(a,b,x)=>{const t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t);};
// banda morbida: 1 dentro [a,b], 0 fuori, bordo largo ~1.5 pixel (niente scalini quando la texture è ingrandita)
const band=(x,a,b,w)=>{w=w||PXW*1.5;return sstep(a-w,a+w,x)*(1-sstep(b-w,b+w,x));};
function makeTex(n,fn,ns){PXW=1/n;const c=document.createElement('canvas');c.width=c.height=n;const g=c.getContext('2d'),im=g.createImageData(n,n),d=im.data,h=new Float32Array(n*n),o=[0,0,0,0];
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
 // riparo: lamiera verniciata grigio-verde con banda di pericolo giallo/nera consumata, scanalature e rivetti
 hazard:()=>(u,v,o)=>{const n=fbm(u,v,1,4),wear=fbm(u*2+.37,v*2+.61,1,3),br=vn(4,u*2,v*28)*.5+vn(3,u,v*14)*.5,
   f=(u*10+v*10)%1,w=PXW*14,stp=band(f,.02,.52,w),inB=1-sstep(.3-PXW*2,.3+PXW*2,v),
   gr=Math.max(band(v,.296,.318),band(v,.69,.705)),rv=Math.hypot((u*8%1)-.5,(v-.345)*8*1.4)<.11?1:0,
   chip=sstep(.66,.8,wear+.08*inB*(1-band(v,.04,.27,.04)))*.8;
   let r=mix(88,206,stp),g=mix(90,160,stp),b=mix(86,26,stp);r=mix(78,r,inB);g=mix(84,g,inB);b=mix(80,b,inB);
   const k=(.8+n*.3+br*.06)*(1-gr*.55);r*=k;g*=k;b*=k;const m=118+n*40;r=mix(r,m,chip*.85);g=mix(g,m,chip*.85);b=mix(b,m*.96,chip*.85);
   if(rv){r=r*.6+30;g=g*.6+30;b=b*.6+30;}
   o[0]=r;o[1]=g;o[2]=b;o[3]=n*.2-gr*.6+rv*.45-chip*.06;},
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
const M={};let curTh=-1;const STRIPC=new THREE.Color(1,1,1);
function baseMats(){if(M.wood)return;
 // texture a 512 px per gli oggetti che si vedono da vicino (ripari, casse): a 256 px apparivano pixelate
 M.wood=sMat(tx('wood',512,PAT.wood(),4),{roughness:.85});M.mcrate=sMat(tx('mcrate',512,PAT.mcrate([70,96,84]),4),{roughness:.55,metalness:.5});
 M.mcrateB=sMat(tx('mcrateB',512,PAT.mcrate([58,84,124]),4),{roughness:.55,metalness:.5});M.mcrateR=sMat(tx('mcrateR',512,PAT.mcrate([128,72,52]),4),{roughness:.6,metalness:.45});
 M.hazard=sMat(tx('hazard2',512,PAT.hazard(),3),{roughness:.62,metalness:.35});M.barrel=sMat(tx('barrel',256,PAT.barrel(),4),{roughness:.5,metalness:.45});
 M.locker=sMat(tx('locker',256,PAT.locker(0),4),{roughness:.5,metalness:.55});M.lockerC=sMat(tx('lockerC',256,PAT.locker(1),5),{roughness:.6,metalness:.5});
 M.steel=new THREE.MeshStandardMaterial({color:lc(0x8a9098),roughness:.4,metalness:.8});M.dark=new THREE.MeshStandardMaterial({color:lc(0x1a1c20),roughness:.7,metalness:.3});
 M.shield=new THREE.MeshStandardMaterial({color:lc(0x2a3442),roughness:.55,metalness:.6});
 M.gold=new THREE.MeshStandardMaterial({color:lc(0xffc040),roughness:.3,metalness:.85,emissive:lc(0x664400),emissiveIntensity:.5});M.purple=new THREE.MeshStandardMaterial({color:lc(0xb45cff),roughness:.4,metalness:.5,emissive:lc(0x5a1faa),emissiveIntensity:.8});
 // plafoniera: cornice scura + diffusore con lamelle (prima era un rettangolo bianco piatto che, vicino alla camera, appariva come una "forma bianca" in alto)
 M.stripT=cTex(128,64,(g,w,h)=>{g.fillStyle='#16181c';g.fillRect(0,0,w,h);const gr=g.createLinearGradient(0,10,0,h-10);gr.addColorStop(0,'#9a9890');gr.addColorStop(.5,'#ffffff');gr.addColorStop(1,'#9a9890');g.fillStyle=gr;g.fillRect(7,10,w-14,h-20);
  g.fillStyle='rgba(20,22,26,.55)';for(let x=7+12;x<w-8;x+=12)g.fillRect(x,10,2,h-20);g.strokeStyle='#3a3d44';g.lineWidth=2;g.strokeRect(5,8,w-10,h-16);},true);
 M.strip=new THREE.MeshBasicMaterial({color:lc(0xffffff),map:M.stripT});M.door=new THREE.MeshBasicMaterial({color:lc(0x40ffa0)});M.doorL=new THREE.MeshBasicMaterial({color:lc(0xff4050)});
 // scintille additive (scie luminose orientate lungo la velocità, vedi bits/updParts)
 M.spark=new THREE.MeshBasicMaterial({color:new THREE.Color(1,.78,.42),transparent:true,blending:THREE.AdditiveBlending,depthWrite:false});M.gore=new THREE.MeshBasicMaterial({color:lc(0x7a1010)});M.chip=new THREE.MeshStandardMaterial({color:lc(0x9a6c3c),roughness:.9});M.scrap=new THREE.MeshStandardMaterial({color:lc(0x60666e),roughness:.5,metalness:.6});
 M.tracer=new THREE.MeshBasicMaterial({color:lc(0xffe6a0),transparent:true,opacity:.9,blending:THREE.AdditiveBlending,depthWrite:false});
 M.etr=new THREE.MeshBasicMaterial({color:lc(0xff5a30),transparent:true,opacity:.95,blending:THREE.AdditiveBlending,depthWrite:false});
 M.las=new THREE.MeshBasicMaterial({color:lc(0xff2020),transparent:true,opacity:.55,blending:THREE.AdditiveBlending,depthWrite:false});
 M.beam=new THREE.MeshBasicMaterial({color:lc(0xff5a78),transparent:true,opacity:.85,blending:THREE.AdditiveBlending,depthWrite:false});
 M.inv=new THREE.MeshBasicMaterial({visible:false});M.hole0=new THREE.MeshBasicMaterial({color:0x000000});
 M.trR=RAR.map(r=>new THREE.MeshBasicMaterial({color:lc(r.c),transparent:true,opacity:.85,blending:THREE.AdditiveBlending,depthWrite:false}));M.arc=new THREE.MeshBasicMaterial({color:lc(0x80e8ff),transparent:true,opacity:.9,blending:THREE.AdditiveBlending,depthWrite:false});
 // foro di proiettile: nucleo nero, anello ammaccato con crepe, alone di bruciatura sfumato
 M.holeT=cTex(64,64,(g)=>{const gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'rgba(0,0,0,1)');gr.addColorStop(.2,'rgba(8,7,6,1)');gr.addColorStop(.3,'rgba(70,66,60,.9)');gr.addColorStop(.42,'rgba(20,18,16,.6)');gr.addColorStop(1,'rgba(10,9,8,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);
  g.strokeStyle='rgba(0,0,0,.55)';g.lineWidth=1.2;for(let i=0;i<7;i++){const a=i*.9+Math.random()*.5,r1=8,r2=rr(15,26);g.beginPath();g.moveTo(32+Math.cos(a)*r1,32+Math.sin(a)*r1);g.lineTo(32+Math.cos(a+.15)*r2*.6,32+Math.sin(a+.15)*r2*.6);g.lineTo(32+Math.cos(a)*r2,32+Math.sin(a)*r2);g.stroke();}},true);
 M.hole=new THREE.MeshBasicMaterial({map:M.holeT,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2});
 // alone luminoso con nucleo caldo (vampe, esplosioni, bagliori)
 M.glowT=cTex(64,64,(g)=>{const gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'rgba(255,255,255,1)');gr.addColorStop(.12,'rgba(255,255,255,.95)');gr.addColorStop(.3,'rgba(255,255,255,.45)');gr.addColorStop(.6,'rgba(255,255,255,.12)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);});
 // vampa di sparo a stella (4-6 punte irregolari + nucleo)
 M.flashT=cTex(128,128,(g)=>{g.translate(64,64);g.globalCompositeOperation='lighter';for(let i=0;i<7;i++){const a=i/7*Math.PI*2+rr(-.2,.2),L=rr(38,62),W=rr(5,9);g.save();g.rotate(a);const gr=g.createLinearGradient(0,0,L,0);gr.addColorStop(0,'rgba(255,255,255,.9)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.beginPath();g.moveTo(0,-W);g.lineTo(L,0);g.lineTo(0,W);g.fill();g.restore();}
  const gr=g.createRadialGradient(0,0,0,0,0,40);gr.addColorStop(0,'rgba(255,255,255,1)');gr.addColorStop(.35,'rgba(255,255,255,.6)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(-64,-64,128,128);});
 // sbuffo di fumo/polvere irregolare e palla di fuoco (rumore a macchie)
 const puff=(g,w,hot)=>{g.globalCompositeOperation='source-over';for(let i=0;i<22;i++){const a=Math.random()*6.28,d=Math.random()*w*.22,x=w/2+Math.cos(a)*d,y=w/2+Math.sin(a)*d,r=rr(w*.12,w*.26),gr=g.createRadialGradient(x,y,0,x,y,r);
  gr.addColorStop(0,hot?'rgba(255,255,255,.8)':'rgba(255,255,255,.32)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(0,0,w,w);}};
 M.smokeT=cTex(64,64,(g,w)=>puff(g,w,0));M.fireT=cTex(64,64,(g,w)=>{puff(g,w,1);const gr=g.createRadialGradient(32,32,0,32,32,20);gr.addColorStop(0,'rgba(255,255,255,.8)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);});}
// texture disegnata su canvas 2D (srgb=true per le texture di colore, false per le maschere di luce)
function cTex(w,h,draw,srgb){const c=document.createElement('canvas');c.width=w;c.height=h;draw(c.getContext('2d'),w,h);const t=new THREE.CanvasTexture(c);if(srgb)t.encoding=THREE.sRGBEncoding;return t;}
function setTheme(i){baseMats();if(i===curTh)return;curTh=i;const t=TH[i];for(const k of['wall','floor','ceil'])if(M[k]){M[k].map.dispose();M[k].normalMap.dispose();M[k].dispose();}
 M.wall=sMat(makeTex(512,(t.met?PAT.plate:PAT.concrete)(t.wall),t.met?3:4),t.met?{roughness:.5,metalness:.45}:{roughness:.9});
 M.floor=sMat(makeTex(512,PAT.floor(t.floor),4),{roughness:.7,metalness:.15});M.ceil=sMat(makeTex(512,PAT.plate(t.ceil),3),{roughness:.7,metalness:.3});
 scene.fog=new THREE.FogExp2(t.fog,.02);scene.background=new THREE.Color(t.fog);hemi.color.set(t.amb).multiplyScalar(HEMI_K);spot.color.set(t.l1);pl1.color.set(t.l1);pl2.color.set(t.l2);M.strip.color.set(t.l1);STRIPC.copy(M.strip.color);
 hmTheme(t);}
// modello "sala": pareti meno bianche e meno lucide (prima riflettevano tutta la luce e sembravano bruciate).
// Separata da setTheme perché la sala ora può arrivare dopo (caricamento a pezzi): modelPrep la riapplica.
function hmTheme(t){if(HM.Wall_Roof_White){const c=a=>new THREE.Color(a[0]/255,a[1]/255,a[2]/255).convertSRGBToLinear();HM.Wall_Roof_White.color.copy(c(t.wall)).multiplyScalar(.6).lerp(new THREE.Color(1,1,1),.05);HM.Wall_Roof_White.roughness=.56;
  HM.Wall_Black.color.copy(lc(0x07090c));HM.Wall_Black.roughness=.42;HM.Wall_Black.metalness=.5;HM.lambert1.color.copy(c(t.floor)).multiplyScalar(.85);HM.lambert1.roughness=.6;
  HM.Floor_and_vent.color.copy(lc(0x101317));HM.Floor_and_vent.roughness=.5;HM.Floor_and_vent.metalness=.75;HM.Floor_vent.roughness=.55;
  HM.Wall_blue.emissive.copy(lc(t.l2));HM.Vent_light.emissive.copy(lc(t.l1));HM.Glass.opacity=.1;scene.fog.density=.012;}}

/* ===== geometry helpers ===== */
const GEO={box:new THREE.BoxGeometry(1,1,1),sph:new THREE.SphereGeometry(.5,14,10),cyl:new THREE.CylinderGeometry(.5,.5,1,12),disc:new THREE.CircleGeometry(.5,10)};
function box(w,h,d,mat,x,y,z,ts){const g=new THREE.BoxGeometry(w,h,d);if(ts){const uv=g.attributes.uv,dm=[[d,h],[d,h],[w,d],[w,d],[w,h],[w,h]];for(let f=0;f<6;f++)for(let i=0;i<4;i++){const k=f*4+i;uv.setXY(k,uv.getX(k)*dm[f][0]/ts,uv.getY(k)*dm[f][1]/ts);}}
 const m=new THREE.Mesh(g,mat);m.position.set(x,y,z);m.receiveShadow=true;m.userData.own=1;return m;}
function P(geo,mat,sx,sy,sz,x,y,z,par){const m=new THREE.Mesh(GEO[geo],mat);m.scale.set(sx,sy,sz);m.position.set(x,y,z);m.castShadow=true;par.add(m);return m;}
function clearGroup(g){for(let i=g.children.length-1;i>=0;i--){const c=g.children[i];g.remove(c);c.traverse(m=>{if(m.geometry&&m.userData.own)m.geometry.dispose();if(m.material&&m.userData.ownMat)m.material.dispose();if(m.isSkinnedMesh&&m.skeleton&&m.skeleton.boneTexture)m.skeleton.dispose();});}}

/* ===== particles / fx ===== */
const parts=[];
const GLP=[[],[],[]];
function pAdd(m,v,life,g,o){fxG.add(m);const p=Object.assign({m,v,life,ml:life,g},o);parts.push(p);return p;}
// limiti per non pesare sull'iPhone: oltre MAXP particelle si saltano gli effetti secondari
const MAXP=220,MAXP_SOFT=150,_pv=new V3(),_boomP=new V3(),FIREC=[0xffb347,0xff8c2a,0xff6a1a,0xd8460e];let _boomT=0;
function bits(pt,n,mat,sp,sz,life){const sk=mat===M.spark;if(parts.length>MAXP)n=Math.min(n,2);
 for(let i=0;i<n;i++){const m=new THREE.Mesh(GEO.box,mat),s=sz*rr(.5,1.3);m.scale.set(s,s,s);m.position.copy(pt);
  // le scintille sono scie sottili e veloci che si allungano nella direzione del moto
  if(sk)pAdd(m,new V3(rr(-1,1)*sp*1.3,rr(.3,1.6)*sp,rr(-1,1)*sp*1.3),life*rr(.4,.9),9.8,{streak:s,fade:1});
  else pAdd(m,new V3(rr(-1,1)*sp,rr(.2,1.4)*sp,rr(-1,1)*sp),life*rr(.6,1.2),9.8,{spin:rr(4,12),shrink:1});}
 if(parts.length>MAXP_SOFT||n>=10)return;
 // lampo d'impatto + sbuffo di polvere (scintille), nebbia rossa (sangue), polvere più grossa (schegge)
 if(sk){glow(pt,.22+sz*5,0xffb860,.07);if(n<=4){const q=glow(pt,.32+sz*3,0x6e6a64,.55,2.2,false);if(q)q.fade=.32;}}
 else if(mat===M.gore){const q=glow(pt,.38,0x5a0a08,.32,2.6,false);if(q)q.fade=.55;}
 else if(mat===M.chip||mat===M.scrap){const q=glow(pt,.5+sz*2,0x7a7268,.8,1.8,false);if(q)q.fade=.4;}}
// sprite con materiale riciclato: pool 0 = additivo (luce), 1 = normale (fumo), 2 = normale senza tone mapping (fuoco saturo)
function spr(pt,size,color,life,grow,pool,map){const mt=GLP[pool].pop()||new THREE.SpriteMaterial({map:M.glowT,transparent:true,depthWrite:false,blending:pool?THREE.NormalBlending:THREE.AdditiveBlending,toneMapped:pool!==2});
 mt.map=map;mt.color.set(color);mt.opacity=1;mt.rotation=map===M.glowT?0:rr(0,6.28);const s=new THREE.Sprite(mt);s.userData.pool=pool;s.scale.set(size,size,1);s.position.copy(pt);
 return pAdd(s,new V3(0,pool?.6:0,0),life,0,{fade:1,grow:grow||0,rot:map===M.glowT?0:rr(-1.2,1.2)});}
function glow(pt,size,color,life,grow,add){if(parts.length>170&&life<.6)return null;
 if(add===false)return spr(pt,size,color,life,grow,1,M.smokeT);
 const p=spr(pt,size,color,life,grow,0,M.glowT),big=(grow||0)>=3.5&&size>=2.4;
 // esplosione (bagliore grande che si espande in fretta): bagliore meno "bianco" + palle di fuoco irregolari che salgono (una volta sola per esplosione)
 if(big){p.fade=.65;const now=performance.now();if(now-_boomT<60&&_boomP.distanceToSquared(pt)<2)return p;_boomT=now;_boomP.copy(pt);}
 // palle di fuoco "solide" (fusione normale: restano arancioni anche su pareti chiare, dove un bagliore additivo diventa bianco)
 if(big&&parts.length<MAXP_SOFT){for(let i=0;i<4;i++){_pv.set(pt.x+rr(-.3,.3)*size*.3,pt.y+rr(-.1,.3)*size*.3,pt.z+rr(-.3,.3)*size*.3);const q=spr(_pv,size*rr(.22,.36),FIREC[i],life*rr(1.1,1.7),1.9,2,M.fireT);q.v.set(rr(-.5,.5),rr(.6,1.5),rr(-.5,.5));q.fade=.95;}}
 return p;}
function seg(m,a,b,th){m.position.copy(a).add(b).multiplyScalar(.5);m.lookAt(b);m.scale.set(th,th,Math.max(.01,a.distanceTo(b)));}
// tracciante: una scia che viaggia dalla canna al bersaglio (prima era un segmento fisso per 55 ms)
function tracer(a,b,mat){mat=mat||M.tracer;const m=new THREE.Mesh(GEO.box,mat);if(mat===M.etr){const d=a.distanceTo(b);b=a.clone().lerp(b,Math.max(.3,1-2.2/d));}
 if(mat===M.arc){seg(m,a,b,.02);pAdd(m,new V3(),.07,0,{});return;}
 const d=a.distanceTo(b),th=mat===M.etr?.028:.02;seg(m,a,b,th);pAdd(m,new V3(),clamp(d/160,.05,.11),0,{tr:{a:a.clone(),b:b.clone(),d,len:Math.min(d,1.4+d*.12),th}});}
const _ta=new V3(),_tb=new V3();
function updParts(dt){fxFrame(dt);for(let i=parts.length-1;i>=0;i--){const p=parts[i];p.life-=dt;if(p.life<=0){fxG.remove(p.m);if(p.m.userData.pool!==undefined){if(GLP[p.m.userData.pool].length<120)GLP[p.m.userData.pool].push(p.m.material);}else if(p.m.userData.ownMat)p.m.material.dispose();parts.splice(i,1);continue;}
 const k=p.life/p.ml;
 if(p.tr){const t=p.tr,h=Math.min(1,(1-k)*1.35),hd=h*t.d,tl=Math.max(0,hd-t.len);_ta.copy(t.a).lerp(t.b,tl/t.d);_tb.copy(t.a).lerp(t.b,hd/t.d);seg(p.m,_ta,_tb,t.th*(.6+.4*k));continue;}
 p.m.position.addScaledVector(p.v,dt);if(p.g){p.v.y-=p.g*dt;if(p.m.position.y<.03){p.m.position.y=.03;p.v.set(p.v.x*.4,-p.v.y*.3,p.v.z*.4);}}
 if(p.streak){const sp=p.v.length();_ta.copy(p.m.position).add(p.v);p.m.lookAt(_ta);const s=p.streak*(.3+.7*k);p.m.scale.set(s*.45,s*.45,s*(1.5+sp*.9*k));}
 if(p.spin){p.m.rotation.x+=p.spin*dt;p.m.rotation.z+=p.spin*dt*.7;}if(p.rot)p.m.material.rotation+=p.rot*dt;
 if(p.fade&&!p.streak)p.m.material.opacity=k*p.fade;if(p.grow)p.m.scale.multiplyScalar(1+p.grow*dt);if(p.shrink&&k<.3)p.m.scale.multiplyScalar(.9);}}
// effetti per fotogramma: vampa a stella che ruota, fumo dalla canna a ogni colpo, plafoniere spente/rosse nelle stanze buie/in allarme
let _mfPrev=0,_mfT=0;
function fxFrame(dt){if(typeof G==='undefined'||!G)return;
 if(G.mfs){const mt=G.mfs.material;if(mt.map!==M.flashT){mt.map=M.flashT;mt.needsUpdate=true;}if(G.mfs.visible){mt.rotation=rr(0,6.28);G.mfs.scale.multiplyScalar(1.2);}}
 const mf=G.mflash||0;_mfT-=dt;if(mf>_mfPrev&&G.muz&&_mfT<=0&&parts.length<MAXP_SOFT){_mfT=.09;G.muz.getWorldPosition(_pv);const q=glow(_pv,.18,0x9a948c,.5,2.6,false);if(q){q.fade=.22;q.v.set(rr(-.1,.1),.35,rr(-.1,.1));}}_mfPrev=mf;
 litFx(G.lit||0,G.t||0);}
// plafoniere secondo lo stato luci della stanza: 0 normali, 1 allarme (rosse pulsanti), 2 guaste (quasi spente). Chiamata anche dal menu con 0.
function litFx(lit,t){const al=.45+.55*(.5+.5*Math.sin(t*5));
 if(lit===2)M.strip.color.copy(STRIPC).multiplyScalar(.06);else if(lit===1)M.strip.color.setRGB(1,.16,.1).multiplyScalar(al);else M.strip.color.copy(STRIPC);
 // plafoniere dei corridoi/sale (materiale e2 di corrM, corridoi.js): stessa texture a lamelle e stesso comportamento buio/allarme
 if(typeof CM!=='undefined')for(const k in CM){const e=CM[k]&&CM[k].e2;if(!e)continue;if(e.userData.ei0===undefined){e.userData.ei0=e.emissiveIntensity;e.userData.ec0=e.emissive.clone();e.emissiveMap=M.stripT;e.needsUpdate=true;}
  if(lit===2){e.emissive.copy(e.userData.ec0);e.emissiveIntensity=e.userData.ei0*.05;}else if(lit===1){e.emissive.setRGB(1,.14,.08);e.emissiveIntensity=e.userData.ei0*al;}else{e.emissive.copy(e.userData.ec0);e.emissiveIntensity=e.userData.ei0;}}
 // luci del modello "sala" rosse e pulsanti durante l'allarme
 if(HM.Vent_light&&curTh>=0){if(lit===1)HM.Vent_light.emissive.setRGB(1,.12,.06).multiplyScalar(al);else HM.Vent_light.emissive.set(TH[curTh].l1).convertSRGBToLinear();}
 // le sale ritagliate usano copie dei materiali (livelli.js, st.clip.mats): aggiorno anche le copie delle luci
 if(typeof G!=='undefined'&&G&&G.stages)for(const st of G.stages)if(st&&st.clip&&st.clip.mats)for(const[a,b]of st.clip.mats){if(!b||!b.emissive||a===b)continue;
  if(a===HM.Vent_light||(a.userData&&a.userData.ei0!==undefined)){b.emissive.copy(a.emissive);b.emissiveIntensity=a.emissiveIntensity;if(b.emissiveMap!==a.emissiveMap){b.emissiveMap=a.emissiveMap;b.needsUpdate=true;}}}}
const holes=[];
function decal(h){if(!h.face)return;const n=h.face.normal.clone().transformDirection(h.object.matrixWorld);let m;if(holes.length>=36){m=holes.shift();}else{m=new THREE.Mesh(GEO.disc,M.hole);fxG.add(m);}
 holes.push(m);const s=rr(.11,.16);m.scale.set(s,s,s);m.position.copy(h.point).addScaledVector(n,.012);m.lookAt(h.point.clone().add(n));m.rotateZ(rr(0,6.28));}

/* ===== modelli 3D ===== */
const MODELS={},HM={};let modelsReady=false;
function noRay(o){o.traverse(m=>{m.raycast=()=>{};});return o;}
function b64buf(s){const bin=atob(s),u=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);return u.buffer;}
// I modelli arrivano a pezzi da www/assets (js/caricamento.js): modelPrep li prepara appena caricati, come faceva prima modelsP.
// modelsP resta per compatibilità: si risolve quando è pronta la scena del menu (NON vuol dire "tutti i modelli caricati").
const modelsP=new Promise(res=>{CAR.menuRes=res;});
function modelPrep(k,gl){if(/^g_(ak|shotgun|flare|frag|luger)$/.test(k))gl.scene.traverse(m=>{if(m.isMesh&&m.material.normalScale)m.material.normalScale.y*=-1;});
 if(k==='hall'){gl.scene.traverse(m=>{if(m.isMesh){HM[m.material.name]=m.material;m.receiveShadow=true;}});if(curTh>=0)hmTheme(TH[curTh]);}}
const RQ=new THREE.Quaternion(),_q=new THREE.Quaternion(),_pq=new THREE.Quaternion(),_Y=new V3(0,1,0),_d=new V3();
const AX=new WeakMap();
function aimBone(b,dx,dy,dz,k){let ax=AX.get(b);if(!ax){const c=b.children.find(o=>o.isBone);ax=c&&c.position.lengthSq()>1e-6?c.position.clone().normalize():_Y;AX.set(b,ax);}_d.set(dx,dy,dz).normalize().applyQuaternion(RQ);b.parent.updateWorldMatrix(true,false);b.parent.getWorldQuaternion(_pq);_q.setFromUnitVectors(ax,_d).premultiply(_pq.invert());b.quaternion.slerp(_q,k);}
