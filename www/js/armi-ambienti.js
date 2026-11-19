// Settore Zero — armi e oggetti di scena con modelli 3D gratuiti (CC0, vedi crediti/modelli.md)
// Va caricato dopo js/sale.js e prima di js/menu.js. Tutte le globali hanno il prefisso AA_.
// Ripiego: se un modello n_* manca, resta la grafica vecchia.
'use strict';

/* ===== caricamento dei modelli n_* =====
   Se i tag models/n_*.js stanno con gli altri modelli (prima di js/dati.js) li carica già grafica.js dentro modelsP;
   se stanno più in basso li carichiamo qui, appena modelsP ha finito. */
const AA_KEYS=['n_pistola','n_cecchino','n_rpg','n_barile','n_texture'];
function AA_prep(){AA_prepBarile();AA_prepTex();}
modelsP.then(()=>{AA_prep();// subito, prima che menu.js avvii il livello
 const todo=AA_KEYS.filter(k=>!MODELS[k]&&typeof ASSET!=='undefined'&&typeof ASSET[k]==='string');
 if(!todo.length||!THREE.GLTFLoader)return;const L=new THREE.GLTFLoader();
 for(const k of todo){try{L.parse(b64buf(ASSET[k]),'',gl=>{MODELS[k]=gl;ASSET[k]=null;AA_prep();},e=>console.warn('modello non caricato',k,e));}catch(e){console.warn('modello non caricato',k,e);}}});

/* ===== armi in prima persona =====
   Convenzione dei modelli (come WM in definizioni.js): avanti = -z, misure in metri.
   by = altezza della canna, mz = z della volata, tz = spostamento indietro del modello.
   Le mani sono posizionate nel gruppo dell'arma (WG): trig = punto del grilletto (lì va la punta dell'indice),
   rake = inclinazione dell'impugnatura, hs = scala della mano, fore = appoggio della mano sinistra sotto l'astina,
   rear = seconda impugnatura verticale (lanciarazzi) tenuta dalla mano sinistra. */
const AA_W={
 pistol:{wm:{k:'n_pistola',tz:-.033,by:.062,mz:-.174,wz:-.44,wx:.1,wy:-.17},trig:[0,.026,-.02],rake:-.3,hs:1},
 sniper:{wm:{k:'n_cecchino',tz:.298,by:.05,mz:-.596},trig:[0,-.01,-.01],rake:-.75,hs:1.08,fore:[0,.012,-.4]},
 rocket:{wm:{k:'n_rpg',tz:-.177,by:.095,mz:-.5,wz:-.42,wx:.17,wy:-.21},trig:[0,.035,-.01],rake:-.12,hs:1.1,rear:[0,.035,.205]},
 // Minigun: modello procedurale (AA_mkMinigun, più sotto), impugnatura posteriore per la destra e impugnatura anteriore per la sinistra
 gatling:{wm:{k:'n_minigun',tz:0,by:0,mz:-.62,wz:-.64,wx:.13,wy:-.21},trig:[-.002,-.118,.002],rake:-.25,hs:1.08,rear:[.002,-.121,-.218],
  piv:{k:.85,b:.13,x:-.03}} // piv: l'arma segue poco la mira in orizzontale e resta girata verso il centro, così si vede il fianco e non solo il retro
};
/* armi che restano con i modelli vecchi g_*: il grilletto di quei modelli sta già vicino all'origine del gruppo */
const AA_H={revolver:{trig:[0,.016,.003],rake:-.35,hs:1},smg:{trig:[0,-.036,0],rake:-.7,hs:1.05,fore:[0,-.025,-.1]},shotgun:{trig:[0,-.043,-.002],rake:-.6,hs:1.08,fore:[0,-.03,-.4]},
 rifle:{trig:[0,-.041,.002],rake:-.4,hs:1.06,fore:[0,-.02,-.24]},minigun:{trig:[0,-.053,.001],rake:-.4,hs:1.08,fore:[0,-.025,-.27]},plasma:{trig:[0,-.026,.001],rake:-.3,hs:1}};
let AA_handOn=true;

/* forme di base con cache (non vengono mai liberate: sono poche e riusate) */
const AA_GC={};
function AA_caps(r,l){const k='c'+r.toFixed(4)+'_'+l.toFixed(4);if(AA_GC[k])return AA_GC[k];const pts=[],n=5;
 for(let i=0;i<=n;i++){const a=-Math.PI/2+i/n*Math.PI/2;pts.push(new THREE.Vector2(Math.max(1e-4,r*Math.cos(a)),r*Math.sin(a)));}
 for(let i=0;i<=n;i++){const a=i/n*Math.PI/2;pts.push(new THREE.Vector2(Math.max(1e-4,r*Math.cos(a)),l+r*Math.sin(a)));}
 return AA_GC[k]=new THREE.LatheGeometry(pts,10);}
function AA_rbox(w,h,d,r){const k='r'+[w,h,d,r].map(v=>v.toFixed(4)).join('_');if(AA_GC[k])return AA_GC[k];const g=new THREE.BoxGeometry(w,h,d,4,4,4),p=g.attributes.position,v=new V3(),c=new V3();
 for(let i=0;i<p.count;i++){v.fromBufferAttribute(p,i);c.set(clamp(v.x,-w/2+r,w/2-r),clamp(v.y,-h/2+r,h/2-r),clamp(v.z,-d/2+r,d/2-r));v.sub(c);if(v.lengthSq()>1e-12)v.setLength(r);v.add(c);p.setXYZ(i,v.x,v.y,v.z);}
 g.computeVertexNormals();return AA_GC[k]=g;}
const _AAY=new V3(0,1,0),_AAd=new V3();
/* capsula da a a b (vettori locali) */
function AA_seg(par,mat,r,a,b){_AAd.subVectors(b,a);const l=_AAd.length(),m=new THREE.Mesh(AA_caps(r,l),mat);m.position.copy(a);m.quaternion.setFromUnitVectors(_AAY,_AAd.normalize());m.castShadow=false;m.frustumCulled=false;par.add(m);return m;}

/* materiali della mano: guanto tattico in pelle sintetica, nocche rinforzate, manica in tela */
let AA_HM=null;
function AA_handMats(){if(AA_HM)return AA_HM;
 const lea=makeTex(128,(u,v,o)=>{const n=fbm(u*2,v*2,2,4),p=vn(5,u*3,v*3);const k=.78+n*.32-(p>.82?.12:0);o[0]=44*k;o[1]=46*k;o[2]=50*k;o[3]=n*.6+(p>.82?-.3:0);},2.5);
 const fab=makeTex(128,(u,v,o)=>{const wx=Math.sin(u*Math.PI*2*24),wy=Math.sin(v*Math.PI*2*24),t=((Math.floor(u*24)+Math.floor(v*24))%2)?wx:wy,n=fbm(u,v,1,4);const k=.78+t*.08+n*.3;o[0]=78*k;o[1]=84*k;o[2]=66*k;o[3]=t*.5+.5+n*.3;},2);
 fab.map.repeat.set(3,5);fab.nm.repeat.set(3,5);
 AA_HM={glove:new THREE.MeshStandardMaterial({color:lc(0xffffff),map:lea.map,normalMap:lea.nm,roughness:.74,metalness:.05}),
  pad:new THREE.MeshStandardMaterial({color:lc(0x16171a),roughness:.42,metalness:.15}),
  sleeve:new THREE.MeshStandardMaterial({color:lc(0xffffff),map:fab.map,normalMap:fab.nm,roughness:.92,metalness:0}),
  cuff:new THREE.MeshStandardMaterial({color:lc(0x23252a),roughness:.6,metalness:.1})};
 return AA_HM;}

/* mano destra che stringe un'impugnatura verticale: origine = centro dell'impugnatura, y lungo l'impugnatura, -z avanti, +x a destra */
function AA_mkHand(){const H=AA_handMats(),g=new THREE.Group(),v=(x,y,z)=>new V3(x,y,z);
 const palm=new THREE.Mesh(AA_rbox(.032,.092,.07,.013),H.glove);palm.position.set(.017,-.016,.02);palm.rotation.y=.62;palm.frustumCulled=false;g.add(palm);
 const pad=new THREE.Mesh(AA_rbox(.012,.05,.05,.005),H.pad);pad.position.set(.034,.0,-.002);pad.rotation.y=.35;pad.frustumCulled=false;g.add(pad);
 // medio, anulare, mignolo: avvolgono il davanti dell'impugnatura
 [[-.012,.0098],[-.034,.0093],[-.055,.0083]].forEach(([y,r],i)=>{const s=1-i*.07;const k=v(.03,y,-.012),a=v(.014,y,-.036*s),b=v(-.011,y,-.035*s),c=v(-.022,y-.002,-.016);AA_seg(g,H.glove,r,k,a);AA_seg(g,H.glove,r*.95,a,b);AA_seg(g,H.glove,r*.9,b,c);});
 // indice sul grilletto
 {const k=v(.03,.012,-.01),a=v(.022,.017,-.042),b=v(.008,.016,-.058),c=v(-.002,.01,-.062);AA_seg(g,H.glove,.0095,k,a);AA_seg(g,H.glove,.009,a,b);AA_seg(g,H.glove,.0085,b,c);}
 // pollice lungo il lato sinistro
 {const k=v(.0,-.006,.034),a=v(-.02,.016,.012),b=v(-.024,.026,-.016);AA_seg(g,H.glove,.0115,k,a);AA_seg(g,H.glove,.0105,a,b);}
 // polso
 AA_seg(g,H.glove,.026,v(.018,-.045,.04),v(.03,-.085,.075));
 return g;}

/* aggiunge mano + manica al gruppo dell'arma: p = centro impugnatura (coordinate del gruppo), rake = inclinazione */
const AA_TIP=new V3(-.002,.01,-.062),_AAX=new V3(1,0,0);
function AA_addArm(g,T,rake,hs,mirror){const H=AA_handMats(),hand=AA_mkHand(),tip=AA_TIP.clone().multiplyScalar(hs).applyAxisAngle(_AAX,rake);if(mirror)tip.x=-tip.x;
 hand.position.set(T[0]-tip.x,T[1]-tip.y,T[2]-tip.z);hand.scale.set(mirror?-hs:hs,hs,hs);hand.rotation.x=rake;
 g.add(hand);hand.updateMatrix();
 const w=new V3(.03,-.085,.075).applyMatrix4(hand.matrix),dir=mirror?new V3(-.45,-.62,.64).normalize():new V3(.2,-.73,.66).normalize();
 const L=.62,sl=new THREE.Mesh(AA_GC.sleeve||(AA_GC.sleeve=new THREE.CylinderGeometry(.036,.047,1,14,1,true)),H.sleeve);sl.scale.set(1,L,1);
 sl.quaternion.setFromUnitVectors(_AAY,dir.clone().negate());sl.position.copy(w).addScaledVector(dir,L/2+.02);sl.frustumCulled=false;g.add(sl);
 const cf=new THREE.Mesh(AA_GC.cuff||(AA_GC.cuff=new THREE.CylinderGeometry(.032,.035,.05,14)),H.cuff);cf.quaternion.copy(sl.quaternion);cf.position.copy(w).addScaledVector(dir,.03);cf.frustumCulled=false;g.add(cf);
 for(const o of[hand,sl,cf])o.traverse(m=>{if(m.isMesh){m.castShadow=false;m.raycast=()=>{};}});return hand;}

/* mano sinistra sotto il calciolo/astina: dita che salgono sul lato destro, palmo sotto */
function AA_addSupport(g,p,hs){const H=AA_handMats(),h=new THREE.Group(),v=(x,y,z)=>new V3(x,y,z);h.position.set(p[0],p[1],p[2]);h.scale.setScalar(hs);g.add(h);
 const palm=new THREE.Mesh(AA_rbox(.075,.03,.085,.013),H.glove);palm.position.set(-.012,-.03,.0);palm.rotation.z=-.35;palm.frustumCulled=false;h.add(palm);
 [[-.03,.0095],[-.008,.0098],[.014,.0093],[.034,.0083]].forEach(([z,r])=>{const a=v(-.035,-.03,z),b=v(.018,-.032,z),c=v(.03,-.004,z),d=v(.022,.016,z);AA_seg(h,H.glove,r,a,b);AA_seg(h,H.glove,r*.95,b,c);AA_seg(h,H.glove,r*.9,c,d);});
 AA_seg(h,H.glove,.011,v(-.04,-.02,.03),v(-.03,.005,-.01));
 const w=v(-.04,-.05,.05),dir=v(-.3,-.62,.72).normalize();AA_seg(h,H.glove,.026,v(-.03,-.035,.035),w);
 h.updateMatrix();const wg=w.clone().applyMatrix4(h.matrix),L=.62;
 const sl=new THREE.Mesh(AA_GC.sleeve||(AA_GC.sleeve=new THREE.CylinderGeometry(.036,.047,1,14,1,true)),H.sleeve);sl.scale.set(1,L,1);sl.quaternion.setFromUnitVectors(_AAY,dir.clone().negate());sl.position.copy(wg).addScaledVector(dir,L/2+.02);sl.frustumCulled=false;g.add(sl);
 const cf=new THREE.Mesh(AA_GC.cuff||(AA_GC.cuff=new THREE.CylinderGeometry(.032,.035,.05,14)),H.cuff);cf.quaternion.copy(sl.quaternion);cf.position.copy(wg).addScaledVector(dir,.03);cf.frustumCulled=false;g.add(cf);
 for(const o of[h,sl,cf])o.traverse(m=>{if(m.isMesh){m.castShadow=false;m.raycast=()=>{};}});return h;}

/* rarità alte su modelli con più materiali: il codice originale mette un solo materiale su tutto il modello;
   qui ogni pezzo riprende la sua texture, con lo stesso bagliore (il colore emissivo è condiviso, così il mitico pulsa ovunque) */
function AA_fixRarity(m,src,w){if(!G.wmat)return;const orig=new Map();let base=null;src.traverse(o=>{if(o.isMesh){orig.set(o.name,o.material);if(!base)base=o.material;}});const cache=new Map();
 m.traverse(o=>{if(!o.isMesh)return;const om=orig.get(o.name);if(!om||om===base)return;let c=cache.get(om);
  if(!c){c=om.clone();c.emissive=G.wmat.emissive;c.emissiveMap=null;c.emissiveIntensity=G.wmat.emissiveIntensity;if(w.r===4){c.color.lerp(lc(0xffc85a),.55);c.metalness=1;c.roughness*=.6;}if(w.r===5){c.color.lerp(lc(0x1a0a10),.35);c.roughness*=.7;}cache.set(om,c);}
  if(o.material&&o.material!==G.wmat&&o.userData.ownMat)o.material.dispose();o.material=c;o.userData.ownMat=1;});}

const AA_bw0=buildWeapon;
buildWeapon=function(){
 if(!MODELS.n_minigun)try{MODELS.n_minigun=AA_mkMinigun();}catch(e){console.warn('minigun',e);}
 for(const t in AA_W){const a=AA_W[t];if(MODELS[a.wm.k])WM[t]=a.wm;}
 AA_bw0();G.gbar=WG.getObjectByName('mg_rot')||null;
 try{AA_afterWeapon();}catch(e){console.warn('mano/arma',e);}
 G.gpiv=null;const a=AA_W[cw().t];if(a&&a.piv&&WG.children.length){const pv=new THREE.Group();pv.rotation.order='YXZ';pv.rotation.set(a.piv.x,a.piv.b,0);for(const c of WG.children.slice())pv.add(c);WG.add(pv);G.gpiv=pv;}};
function AA_afterWeapon(){const w=cw(),a=AA_W[w.t],wm=WM[w.t],g=WG,mine=!!(a&&wm===a.wm&&MODELS[wm.k]);
 // modello caricato dal codice originale (primo figlio con mesh, senza materiale M.dark)
 if(mine&&w.r>=3){const mdl=g.children.find(o=>o.isObject3D&&!o.isMesh&&!o.isSprite);if(mdl)AA_fixRarity(mdl,MODELS[wm.k].scene,w);}
 if(!AA_handOn)return;
 // togli la vecchia mano nera (sfera + cilindro scuri)
 const old=g.children.filter(o=>o.isMesh&&o.material===M.dark&&(o.geometry===GEO.sph||(o.geometry===GEO.cyl&&Math.abs(o.rotation.x+.9)<.01)));
 if(old.length<2)return;const hd=old.find(o=>o.geometry===GEO.sph);for(const o of old)g.remove(o);
 let trig,rake,hs,fore=null,rear=null;const model=!!(wm&&MODELS[wm.k]);
 if(mine){trig=a.trig;rake=a.rake;hs=a.hs;fore=a.fore||null;rear=a.rear||null;}
 else if(model&&AA_H[w.t]){const h=AA_H[w.t];trig=h.trig;rake=h.rake;hs=h.hs;fore=h.fore||null;}
 else{trig=[0,hd.position.y+.05,hd.position.z-.03];rake=.3;hs=1;} // arma procedurale: impugnatura inclinata in avanti
 AA_addArm(g,trig,rake,hs);
 if(rear)AA_addArm(g,rear,rake,hs,true);
 if(fore)AA_addSupport(g,fore,hs);}

/* ===== Minigun (arma 'gatling') =====
   Modello costruito in codice: sei canne attorno a un asse (gruppo 'mg_rot', gira mentre spari), carcassa del rotore,
   corpo con motore elettrico, maniglia di trasporto, due impugnature, cassetta delle munizioni con nastro di cartucce.
   Misure in metri, avanti = -z, asse delle canne a y=0; l'origine è sopra l'impugnatura posteriore.
   Ogni mesh ha il nome del suo materiale: AA_fixRarity lo usa per ridare a ogni pezzo il suo materiale con il bagliore della rarità. */
function AA_mkMinigun(){const g=new THREE.Group(),rot=new THREE.Group();rot.name='mg_rot';
 const gmT=makeTex(256,(u,v,o)=>{const n=fbm(u*2,v*2,2,4),sc=vn(5,u*40,v*2)>.86,pit=vn(4,u*9,v*9)>.8;const k=.82+n*.3-(sc?.1:0)-(pit?.06:0);o[0]=60*k;o[1]=63*k;o[2]=68*k;o[3]=n*.5-(pit?.3:0)+(sc?.2:0);},2);
 const boxT=makeTex(256,(u,v,o)=>{const n=fbm(u*2,v*2,1,4),st=Math.abs(v-.5)<.06,ed=Math.min(u,1-u,v,1-v)<.04,lab=u>.18&&u<.62&&v>.66&&v<.84&&(Math.floor(u*42)%3!==0)&&(Math.floor(v*30)%3!==1);
  let c=[78,84,52];if(st)c=[176,146,40];if(lab)c=[200,196,170];const k=(.8+n*.32)*(ed?.7:1);o[0]=c[0]*k;o[1]=c[1]*k;o[2]=c[2]*k;o[3]=n*.6+(ed?.4:0)+(st?.1:0);},2.5);
 const mk=(nm,o)=>{const m=new THREE.MeshStandardMaterial(o);m.name=nm;return m;};
 const Mg={gun:mk('mg_gun',{color:lc(0xffffff),map:gmT.map,normalMap:gmT.nm,roughness:.46,metalness:.5}),
  bar:mk('mg_bar',{color:lc(0x6a6e75),map:gmT.map,roughness:.32,metalness:.6}),
  blk:mk('mg_blk',{color:lc(0x1b1c1f),roughness:.72,metalness:.12}),
  stl:mk('mg_stl',{color:lc(0x9aa0a8),roughness:.28,metalness:.9}),
  box:mk('mg_box',{color:lc(0xffffff),map:boxT.map,normalMap:boxT.nm,roughness:.66,metalness:.25}),
  brs:mk('mg_brs',{color:lc(0xc9a04a),roughness:.3,metalness:.92}),
  cu:mk('mg_cu',{color:lc(0xb4683a),roughness:.35,metalness:.85}),
  hole:mk('mg_hole',{color:lc(0x050505),roughness:1,metalness:0})};
 const put=(geo,mat,x,y,z,par,rx,ry,rz)=>{const m=new THREE.Mesh(geo,mat);m.name=mat.name;m.position.set(x,y,z);m.rotation.set(rx||0,ry||0,rz||0);m.castShadow=false;m.frustumCulled=false;(par||g).add(m);return m;};
 const cyl=(r1,r2,l,seg)=>{const k='mgc'+[r1,r2,l,seg].join('_');return AA_GC[k]||(AA_GC[k]=new THREE.CylinderGeometry(r1,r2,l,seg||20).rotateX(Math.PI/2));};// cilindro lungo z
 const rb=AA_rbox,Z=Math.PI/2;
 // corpo: il primo mesh è la carcassa (materiale di base per la rarità)
 put(rb(.088,.1,.2,.014),Mg.gun,0,-.004,-.02);
 g.add(rot);
 put(rb(.07,.012,.16,.004),Mg.blk,0,.05,-.02);                          // coperchio superiore
 for(let i=0;i<5;i++)put(rb(.004,.05,.012,.002),Mg.blk,.045,-.006,-.09+i*.028); // nervature laterali
 put(cyl(.053,.053,.075,28),Mg.gun,0,0,-.152);                          // carcassa del rotore
 put(cyl(.056,.056,.012,28),Mg.blk,0,0,-.118);
 put(cyl(.049,.045,.014,28),Mg.stl,0,0,-.196);
 put(cyl(.038,.036,.026,20),Mg.gun,0,0,.09);put(cyl(.026,.026,.008,16),Mg.stl,0,0,.106);  // coperchio posteriore
 // motore elettrico sul fianco destro, con alette
 put(cyl(.027,.027,.11,18),Mg.blk,.052,-.042,-.005);put(cyl(.022,.022,.012,16),Mg.stl,.052,-.042,.055);put(cyl(.02,.02,.01,16),Mg.stl,.052,-.042,-.064);
 for(let i=0;i<4;i++)put(cyl(.03,.03,.004,18),Mg.gun,.052,-.042,-.04+i*.022);
 put(rb(.03,.028,.04,.006),Mg.gun,.044,-.064,-.075);
 // finestra di alimentazione sul fianco sinistro
 put(rb(.034,.054,.075,.007),Mg.gun,-.056,-.018,-.035);put(rb(.006,.034,.05,.002),Mg.hole,-.073,-.016,-.035);
 // maniglia di trasporto
 put(rb(.016,.05,.018,.005),Mg.gun,0,.072,-.085);put(rb(.016,.05,.018,.005),Mg.gun,0,.072,.035);
 put(cyl(.012,.012,.15,14),Mg.blk,0,.099,-.025);
 // impugnatura posteriore (mano destra), grilletto e ponticello
 put(rb(.032,.112,.044,.013),Mg.blk,0,-.11,.07,null,-.25);
 for(let i=0;i<4;i++)put(rb(.034,.004,.03,.002),Mg.gun,0,-.14+i*.02,.077+(i*.02-.03)*.25,null,-.25);
 put(rb(.034,.022,.06,.006),Mg.gun,0,-.062,.04);
 put(rb(.006,.024,.007,.002),Mg.stl,0,-.112,-.006,null,-.35);
 put(rb(.01,.006,.06,.002),Mg.gun,0,-.148,.0);put(rb(.01,.08,.006,.002),Mg.gun,0,-.11,-.03);
 // impugnatura anteriore (mano sinistra) con fascetta sotto la carcassa del rotore
 put(rb(.04,.026,.06,.006),Mg.gun,0,-.058,-.152);put(rb(.03,.104,.04,.012),Mg.blk,0,-.115,-.152,null,-.25);
 // cassetta delle munizioni appesa sotto la carcassa (lato sinistro), maniglia sul fianco, nastro di cartucce che sale alla finestra
 put(rb(.07,.085,.1,.006),Mg.box,-.05,-.1,-.055);put(rb(.072,.006,.104,.002),Mg.blk,-.05,-.061,-.055);
 put(rb(.006,.008,.012,.002),Mg.blk,-.087,-.085,-.085);put(rb(.006,.008,.012,.002),Mg.blk,-.087,-.085,-.025);put(cyl(.0045,.0045,.07,8),Mg.blk,-.092,-.085,-.055);
 const cv=new THREE.CatmullRomCurve3([new V3(-.07,-.07,-.098),new V3(-.088,-.055,-.09),new V3(-.088,-.03,-.07),new V3(-.074,-.018,-.05)]);
 put(new THREE.TubeGeometry(cv,12,.016,10,false),Mg.blk,0,0,0);
 for(let i=0;i<=7;i++){const t=i/7,p=cv.getPoint(t),tg=cv.getTangent(t),c=new THREE.Group();c.position.copy(p).add(new V3(-.012,0,0));c.quaternion.setFromUnitVectors(new V3(0,1,0),tg);g.add(c);
  put(cyl(.0055,.0055,.03,10),Mg.brs,0,0,.004,c);put(cyl(.0012,.0048,.01,10),Mg.cu,0,0,-.016,c);}
 // fascio rotante: sei canne, asse centrale, fascette e anello di bocca
 const R=.03,z0=-.17,z1=-.6,L=z0-z1,zc=(z0+z1)/2;
 for(let i=0;i<6;i++){const a=i*Math.PI/3,x=Math.cos(a)*R,y=Math.sin(a)*R;put(cyl(.0085,.0085,L,14),Mg.bar,x,y,zc,rot);put(cyl(.0045,.0045,.006,10),Mg.hole,x,y,z1-.002,rot);put(cyl(.0098,.0098,.022,14),Mg.stl,x,y,z1+.012,rot);}
 put(cyl(.012,.012,L,12),Mg.gun,0,0,zc,rot);
 put(cyl(.046,.046,.016,28),Mg.gun,0,0,-.36,rot);put(cyl(.044,.044,.012,28),Mg.gun,0,0,-.2,rot);
 put(cyl(.046,.046,.026,28),Mg.blk,0,0,-.565,rot);
 for(let i=0;i<6;i++){const a=(i+.5)*Math.PI/3;put(rb(.008,.006,.02,.002),Mg.stl,Math.cos(a)*.044,Math.sin(a)*.044,-.36,rot,0,0,a+Z);}
 return{scene:g};}

/* giri delle canne (G.gsp 0..1): salgono mentre tieni premuto o spari, scendono dolcemente quando smetti.
   La cadenza della Minigun dipende da G.gsp (vedi fire() in combattimento.js); il ronzio del motore è gatHum (audio.js). */
const AA_GSPIN=22,AA_GSTEP=.45;// velocità massima (rad/s) e passo massimo per fotogramma (oltre, a bassi fps, sembrerebbe girare al contrario)
function AA_gatTick(dt){if(!G||!S.eq.length)return;const w=cw(),t=w&&WT[w.t];let k=G.gsp||0;
 if(t&&t.inf){const want=state==='play'&&!G.mv&&G.lean>.6&&(aim.down||G.t-(G.gshot==null?-9:G.gshot)<.15);k+=((want?1:0)-k)*Math.min(1,dt*(want?3.2:1.2));if(k<.003)k=0;}else k=0;
 if(G.gpiv&&t&&AA_W[w.t]&&AA_W[w.t].piv){const pv=AA_W[w.t].piv;G.gpiv.rotation.y=-WG.rotation.y*pv.k+pv.b;}
 G.gsp=k;G.gang=((G.gang||0)+Math.min(AA_GSTEP,k*AA_GSPIN*dt))%(Math.PI*2);if(G.gbar)G.gbar.rotation.z=G.gang;
 if(typeof gatHum==='function')gatHum(state==='play'?k:0);}
const AA_up0=update;
update=function(dt){AA_up0(dt);try{AA_gatTick(dt);}catch(e){console.warn('minigun',e);}};

/* ===== oggetti di scena =====
   Le casse restano scatole invisibili con le stesse misure (colpi, coperture e fisica non cambiano);
   l'aspetto è una cassa vera costruita sopra con texture CC0 (assi di legno o lamiera ondulata). */
let AA_TX=null,AA_CASSE=true; // AA_CASSE=false: casse di nuovo con le texture procedurali di grafica.js
function AA_prepTex(){const gl=MODELS.n_texture;if(!gl)return;const T={};gl.scene.traverse(o=>{if(o.isMesh&&o.material&&o.material.map)T[o.material.name]=o.material;});
 if(!T.legno||!T.lamiera)return;const tw=m=>{for(const t of[m.map,m.normalMap])if(t){t.wrapS=t.wrapT=THREE.RepeatWrapping;t.anisotropy=4;t.needsUpdate=true;}};tw(T.legno);tw(T.lamiera);
 const W=T.legno,S=T.lamiera,mk=(src,o)=>new THREE.MeshStandardMaterial(Object.assign({map:src.map,normalMap:src.normalMap},o));
 AA_TX={wood:mk(W,{color:lc(0xfff0dc).multiplyScalar(1.45),roughness:.84,metalness:0}),woodF:mk(W,{color:lc(0xd2ae80).multiplyScalar(1.3),roughness:.8,metalness:0,normalScale:new THREE.Vector2(1.3,1.3)}),
  green:mk(S,{color:lc(0x8aa878).multiplyScalar(2.3),roughness:.5,metalness:.15}),blue:mk(S,{color:lc(0x7c9cc6).multiplyScalar(2.3),roughness:.5,metalness:.15}),red:mk(S,{color:lc(0xc87a62).multiplyScalar(2.2),roughness:.55,metalness:.12}),
  steel:mk(S,{color:lc(0x8a8e94).multiplyScalar(1.6),roughness:.45,metalness:.45})};}

/* scatola con UV in metri (ts = metri per ripetizione della texture), trasformata da matrice */
function AA_bx(w,h,d,ts,mx){const g=new THREE.BoxGeometry(w,h,d),uv=g.attributes.uv,dm=[[d,h],[d,h],[w,d],[w,d],[w,h],[w,h]];
 for(let f=0;f<6;f++)for(let i=0;i<4;i++){const k=f*4+i;uv.setXY(k,uv.getX(k)*dm[f][0]/ts,uv.getY(k)*dm[f][1]/ts);}if(mx)g.applyMatrix4(mx);return g;}
function AA_merge(gs){let n=0,ni=0;for(const g of gs){n+=g.attributes.position.count;ni+=g.index.count;}const pos=new Float32Array(n*3),nor=new Float32Array(n*3),uv=new Float32Array(n*2),idx=new Uint32Array(ni);let o=0,oi=0;
 for(const g of gs){pos.set(g.attributes.position.array,o*3);nor.set(g.attributes.normal.array,o*3);uv.set(g.attributes.uv.array,o*2);const ia=g.index.array;for(let i=0;i<ia.length;i++)idx[oi+i]=ia[i]+o;o+=g.attributes.position.count;oi+=ia.length;g.dispose();}
 const r=new THREE.BufferGeometry();r.setAttribute('position',new THREE.BufferAttribute(pos,3));r.setAttribute('normal',new THREE.BufferAttribute(nor,3));r.setAttribute('uv',new THREE.BufferAttribute(uv,2));r.setIndex(new THREE.BufferAttribute(idx,1));r.computeBoundingSphere();return r;}
const _AAm=new THREE.Matrix4(),_AAq=new THREE.Quaternion(),_AAe=new THREE.Euler(),_AAs=new V3(1,1,1),_AAp=new V3();
function AA_mx(x,y,z,rx,ry,rz){_AAe.set(rx||0,ry||0,rz||0);_AAq.setFromEuler(_AAe);_AAp.set(x,y,z);return _AAm.clone().compose(_AAp,_AAq,_AAs);}

/* geometrie di una cassa (pannelli + telaio) per le misure date; metal = cassa in lamiera con telaio d'acciaio */
const AA_CC={};
function AA_crateGeo(w,h,d,metal){w=Math.round(w*100)/100;h=Math.round(h*100)/100;d=Math.round(d*100)/100;// misure al cm: meno geometrie diverse in cache
 const key=(metal?'m':'w')+w+'_'+h+'_'+d;if(AA_CC[key])return AA_CC[key];
 const mn=Math.min(w,h,d),t=clamp(mn*(metal?.075:.12),metal?.025:.03,metal?.07:.1),e=Math.min(.02,mn*.03),ts=metal?1.1:1;
 const pan=[AA_bx(w-2*e,h-2*e,d-2*e,ts)],fr=[];
 const X=w/2-t/2,Y=h/2-t/2,Z=d/2-t/2;
 for(const sy of[-1,1])for(const sz of[-1,1])fr.push(AA_bx(w,t,t,1,AA_mx(0,sy*Y,sz*Z)));
 for(const sx of[-1,1])for(const sz of[-1,1])fr.push(AA_bx(t,h-2*t,t,1,AA_mx(sx*X,0,sz*Z)));
 for(const sx of[-1,1])for(const sy of[-1,1])fr.push(AA_bx(t,t,d-2*t,1,AA_mx(sx*X,sy*Y,0)));
 if(!metal&&h>.4){// diagonali di rinforzo sulle quattro facce laterali
  const dz=d/2-e*.5,dx=w/2-e*.5,iw=w-2*t,ih=h-2*t,id=d-2*t;
  if(iw>.2&&ih>.2){const L=Math.hypot(iw,ih)-t*.7,an=Math.atan2(ih,iw);for(const s of[-1,1])fr.push(AA_bx(L,t*.85,e*1.6,1,AA_mx(0,0,s*dz,0,0,s*an)));}
  if(id>.2&&ih>.2){const L=Math.hypot(id,ih)-t*.7,an=Math.atan2(ih,id);for(const s of[-1,1])fr.push(AA_bx(e*1.6,t*.85,L,1,AA_mx(s*dx,0,0,s*an,0,0)));}}
 if(metal&&h>.5){// costola orizzontale a metà altezza
  for(const sz of[-1,1])fr.push(AA_bx(w-2*t,t*.6,e*1.4,1,AA_mx(0,0,sz*(d/2-e*.5))));for(const sx of[-1,1])fr.push(AA_bx(e*1.4,t*.6,d-2*t,1,AA_mx(sx*(w/2-e*.5),0,0)));}
 return AA_CC[key]={pan:AA_merge(pan),fr:AA_merge(fr)};}

function AA_crateVis(w,h,d,kind){const metal=kind!=='wood',G2=AA_crateGeo(w,h,d,metal),g=new THREE.Group();
 const a=new THREE.Mesh(G2.pan,AA_TX[kind]),b=new THREE.Mesh(G2.fr,metal?AA_TX.steel:AA_TX.woodF);
 for(const m of[a,b]){m.castShadow=true;m.receiveShadow=true;m.raycast=()=>{};g.add(m);}g.userData.aaVis=1;return g;}

const AA_box0=box;
box=function(w,h,d,mat,x,y,z,ts){
 if(!AA_CASSE||!AA_TX||!mat||!M.wood)return AA_box0(w,h,d,mat,x,y,z,ts);
 const kind=mat===M.wood?'wood':mat===M.mcrate?'green':mat===M.mcrateB?'blue':mat===M.mcrateR?'red':null;
 if(!kind)return AA_box0(w,h,d,mat,x,y,z,ts);
 const m=AA_box0(w,h,d,M.inv,x,y,z,ts);m.add(AA_crateVis(w,h,d,kind));return m;};

/* ===== barile esplosivo: Barrel_01 al posto del barile vecchio =====
   Il codice dei livelli scala MODELS.bar di .0132 con la base a y=0 e altezza .95: qui il nuovo modello viene avvolto
   in un gruppo con la scala inversa, così entra nello stesso cilindro di collisione (raggio .32, alto .95). */
function AA_prepBarile(){const gl=MODELS.n_barile;if(!gl||AA_prepBarile.done)return;AA_prepBarile.done=1;
 const inner=gl.scene,k=(.95/.873)/.0132,wrap=new THREE.Group();inner.scale.setScalar(k);inner.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;}});wrap.add(inner);
 AA_prepBarile.old=MODELS.bar;MODELS.bar={scene:wrap};}
