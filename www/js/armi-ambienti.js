// Settore Zero — armi e oggetti di scena con modelli 3D gratuiti (CC0, vedi crediti/modelli.md)
// Va caricato dopo js/sale.js e prima di js/menu.js. Tutte le globali hanno il prefisso AA_.
// Ripiego: se un modello n_* manca, resta la grafica vecchia.
'use strict';

/* ===== preparazione dei modelli n_* =====
   I modelli arrivano a pezzi (js/caricamento.js): appena n_barile o n_texture sono pronti li prepariamo qui;
   se uno viene liberato al cambio livello torniamo alla grafica vecchia per quel pezzo. */
const AA_KEYS=['n_pistola','n_cecchino','n_rpg','n_barile','n_texture'];
function AA_prep(){AA_prepBarile();AA_prepTex();}
CAR.hooks.push((k,ev)=>{
 if(ev==='pronto'&&(k==='n_barile'||k==='n_texture'))AA_prep();
 if(ev==='libera'&&k==='n_barile'&&AA_prepBarile.done){AA_prepBarile.done=0;if(AA_prepBarile.old)MODELS.bar=AA_prepBarile.old;else delete MODELS.bar;}
 if(ev==='libera'&&k==='n_texture')AA_TX=null;});

/* ===== armi in prima persona =====
   Convenzione dei modelli (come WM in definizioni.js): avanti = -z, misure in metri.
   by = altezza della canna, mz = z della volata, tz = spostamento indietro del modello.
   Le mani sono posizionate nel gruppo dell'arma (WG): trig = punto del grilletto (lì va la punta dell'indice),
   rake = inclinazione dell'impugnatura, hs = scala della mano, fore = appoggio della mano sinistra sotto l'astina,
   rear = seconda impugnatura verticale (lanciarazzi) tenuta dalla mano sinistra. */
const AA_W={
 pistol:{wm:{k:'n_pistola',tz:-.033,by:.062,mz:-.174,wz:-.44,wx:.1,wy:-.17},trig:[0,.026,-.02],rake:-.3,hs:1},
 sniper:{wm:{k:'n_cecchino',tz:.298,by:.05,mz:-.596},trig:[0,-.01,-.01],rake:-.75,hs:1.08,fore:[0,.012,-.4]},
 rocket:{wm:{k:'n_rpg',tz:-.177,by:.095,mz:-.5,wz:-.42,wx:.17,wy:-.21},trig:[0,.035,-.01],rake:-.12,hs:1.1,rear:[0,.035,.205]}
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
 for(const t in AA_W){const a=AA_W[t];if(MODELS[a.wm.k])WM[t]=a.wm;}
 AA_bw0();
 try{AA_afterWeapon();}catch(e){console.warn('mano/arma',e);}};
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
