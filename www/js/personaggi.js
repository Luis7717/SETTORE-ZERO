// Settore Zero — personaggi rifiniti: equipaggiamento agganciato alle ossa, materiali, luce di contorno, scudo, automa
'use strict';
/* Caricato dopo sale.js e prima di menu.js. Tocca solo la grafica dei personaggi:
   - soldier()      → dopo il modello originale aggiunge l'equipaggiamento del tipo di nemico
   - BUILD.robot    → l'automa diventa un robot da combattimento corazzato
   - BUILD.turret/drone/mech → luce di contorno nel colore della minaccia
   - spawnE         → lo scudo nero piatto diventa uno scudo antisommossa
   - poseH          → la luce di contorno si accende quando il nemico prende la mira
   Hitbox, punti di mira (cy/hy), bocca dell'arma e animazioni restano quelli originali. */

/* ===== materiali condivisi ===== */
const PG_M={};
function PG_mat(k,c,r,m,tex){if(PG_M[k])return PG_M[k];const o={color:lc(c),roughness:r,metalness:m};
 if(tex){const t=plateTex();o.map=t.map;o.normalMap=t.nrm;o.normalScale=new THREE.Vector2(.55,.55);}
 const mt=new THREE.MeshStandardMaterial(o);mt.skinning=true;return PG_M[k]=mt;}
function PG_em(c,i){const k='em'+c+'_'+(i||2);if(PG_M[k])return PG_M[k];const mt=new THREE.MeshStandardMaterial({color:lc(0x08090b),emissive:lc(c),emissiveIntensity:i||2,roughness:.3,metalness:.2});mt.skinning=true;return PG_M[k]=mt;}
function PG_haz(){if(PG_M.haz)return PG_M.haz;const mt=new THREE.MeshStandardMaterial({color:M.hazard?0xffffff:lc(0xc8a020),map:M.hazard?M.hazard.map:null,roughness:.7,metalness:.3});mt.skinning=true;return PG_M.haz=mt;}
// corazza del singolo nemico: copia propria, così il lampo del colpo, il gelo e Mida colorano anche i pezzi aggiunti
function PG_armor(e,c,r,m){const mt=PG_mat('A'+c+'_'+r+'_'+m,c,r,m).clone();mt.skinning=true;e.mats.push(mt);return mt;}
const PG_DK=()=>PG_mat('dk',0x1d1f22,.85,.15),PG_ST=()=>PG_mat('st',0x7a828c,.32,.9),PG_GM=()=>PG_mat('gm',0x34383e,.45,.7),PG_CL=()=>PG_mat('cl',0x2c3127,.95,.02);

/* ===== luce di contorno: rende leggibile la sagoma e dice il colore della minaccia ===== */
function PG_rimSh(sh){sh.uniforms.pgRim={value:this.userData.pgRim};
 sh.fragmentShader='uniform vec3 pgRim;\n'+sh.fragmentShader.replace('gl_FragColor = vec4( outgoingLight, diffuseColor.a );','outgoingLight+=pgRim*pow(1.0-clamp(abs(dot(normal,normalize(vViewPosition))),0.0,1.0),2.4);\n\tgl_FragColor = vec4( outgoingLight, diffuseColor.a );');}
function PG_rim(e,mats,c,k){e.pgRim=e.pgRim||new THREE.Color();e.pgRimB=new THREE.Color(c).convertSRGBToLinear().multiplyScalar(k);e.pgRim.copy(e.pgRimB);
 for(const m of mats){if(!m||!m.isMeshStandardMaterial||m.userData.pgRim)continue;m.userData.pgRim=e.pgRim;m.onBeforeCompile=PG_rimSh;m.needsUpdate=true;}}
const PG_poseH0=poseH;
poseH=function(e,run,aimT,dt){PG_poseH0(e,run,aimT,dt);if(!e.pgRim)return;e.pgK=(e.pgK||0)+((aimT?1:0)-(e.pgK||0))*Math.min(1,dt*8);e.pgRim.copy(e.pgRimB).multiplyScalar(1+3*e.pgK);};

/* ===== equipaggiamento: tutti i pezzi di un materiale diventano UNA mesh con pelle rigida sullo scheletro =====
   Ogni pezzo: [osso, geometria, materiale, sx,sy,sz, x,y,z, rx,ry,rz, 'L'?]
   Coordinate in metri rispetto all'osso, con gli assi del personaggio nella posa di riposo
   (X = sinistra del personaggio, Y = su, Z = avanti); con 'L' si usano gli assi dell'osso. */
const _pgQ=new THREE.Quaternion(),_pgE=new THREE.Euler(),_pgV=new V3(),_pgS=new V3(),_pgN=new THREE.Matrix3();
function PG_kit(e,list,bones,host){let body=null;e.root.traverse(o=>{if(!body&&o.isSkinnedMesh)body=o;});if(!body)return 0;
 const sk=body.skeleton,r=e.root;r.updateMatrixWorld(true);const rq=r.getWorldQuaternion(new THREE.Quaternion()).invert(),rs=r.getWorldScale(new V3()).x,bi=body.bindMatrix.clone().invert(),cache={},by=new Map();
 for(const p of list){const b=bones[p[0]];if(!b)continue;let c=cache[p[0]];
  if(!c){const i=sk.bones.indexOf(b);if(i<0)continue;c=cache[p[0]]={i,qb:b.getWorldQuaternion(new THREE.Quaternion()).premultiply(rq).invert(),s:b.getWorldScale(new V3()).x/rs,B:sk.boneInverses[i].clone().invert().premultiply(bi)};}
  const loc=p[12]==='L',pos=new V3(p[6],p[7],p[8]),q=new THREE.Quaternion().setFromEuler(_pgE.set(p[9]||0,p[10]||0,p[11]||0));if(!loc){pos.applyQuaternion(c.qb);q.premultiply(c.qb);}
  pos.divideScalar(c.s);const M4=new THREE.Matrix4().compose(pos,q,_pgS.set(p[3],p[4],p[5]).divideScalar(c.s)).premultiply(c.B);
  let a=by.get(p[2]);if(!a)by.set(p[2],a=[]);a.push([GEO[p[1]],M4,c.i]);}
 let n=0;by.forEach((arr,mat)=>{let nv=0;const gs=arr.map(([g,m4,i])=>{const q=g.index?(g.userData.ni||(g.userData.ni=g.toNonIndexed())):g;nv+=q.attributes.position.count;return[q,m4,i];});
  const ps=new Float32Array(nv*3),ns=new Float32Array(nv*3),us=new Float32Array(nv*2),si=new Uint16Array(nv*4),sw=new Float32Array(nv*4);let o=0;
  for(const[q,m4,i]of gs){const pa=q.attributes.position,na=q.attributes.normal,ua=q.attributes.uv;_pgN.getNormalMatrix(m4);
   for(let k=0;k<pa.count;k++,o++){_pgV.fromBufferAttribute(pa,k).applyMatrix4(m4);ps[o*3]=_pgV.x;ps[o*3+1]=_pgV.y;ps[o*3+2]=_pgV.z;_pgV.fromBufferAttribute(na,k).applyMatrix3(_pgN).normalize();ns[o*3]=_pgV.x;ns[o*3+1]=_pgV.y;ns[o*3+2]=_pgV.z;
    if(ua){us[o*2]=ua.getX(k);us[o*2+1]=ua.getY(k);}si[o*4]=i;sw[o*4]=1;}}
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.BufferAttribute(ps,3));g.setAttribute('normal',new THREE.BufferAttribute(ns,3));g.setAttribute('uv',new THREE.BufferAttribute(us,2));
  g.setAttribute('skinIndex',new THREE.Uint16BufferAttribute(si,4));g.setAttribute('skinWeight',new THREE.BufferAttribute(sw,4));
  const m=new THREE.SkinnedMesh(g,mat);m.bind(sk,body.bindMatrix);m.frustumCulled=false;m.castShadow=false;m.raycast=()=>{};m.userData.own=1;m.userData.pgKit=1;(host||body.parent).add(m);n++;});
 return n;}
// pezzo doppio sinistra/destra: x, ry, rz specchiati
function PG_lr(L,bone,geo,mat,sx,sy,sz,x,y,z,rx,ry,rz){L.push(['Left'+bone,geo,mat,sx,sy,sz,x,y,z,rx||0,ry||0,rz||0],['Right'+bone,geo,mat,sx,sy,sz,-x,y,z,rx||0,-(ry||0),-(rz||0)]);}

/* ===== corredo per tipo di nemico (soldato Mixamo = trooper/gren/brute, androide Xbot = sniper/runner/scudo) ===== */
const PG_KIT={
 // fuciliere: zaino tattico con radio e antenna, caricatori sul petto, spallacci e ginocchiere color sabbia
 trooper(e,T,L){const A=PG_armor(e,0x8c8670,.6,.35),D=PG_DK(),G=PG_GM(),E=PG_em(T.vis,2.4);
  L.push(['Spine2','rb',D,.3,.34,.15,0,-.02,-.22],['Spine2','rb',G,.26,.08,.13,0,.17,-.22],['Spine2','rb',G,.1,.17,.07,.11,.04,-.32],['Spine2','c16',D,.014,.42,.014,.12,.33,-.32],['Spine2','sph2',E,.035,.035,.035,.12,.55,-.32],
   ['Spine2','rb',D,.36,.05,.05,0,-.17,-.12],['Spine1','rb',D,.07,.11,.05,-.075,.02,.16],['Spine1','rb',D,.07,.11,.05,0,.02,.165],['Spine1','rb',D,.07,.11,.05,.075,.02,.16],['Spine1','rb',G,.24,.025,.05,0,.08,.17],
   ['Head','rb',G,.05,.035,.04,.085,.19,.1],['Head','sph2',E,.032,.032,.02,.085,.19,.125]);
  PG_lr(L,'Arm','sph2',A,.2,.11,.21,.02,.08,0);PG_lr(L,'Arm','rb',D,.14,.03,.15,.03,.03,0);PG_lr(L,'Leg','rb',A,.1,.08,.045,0,-.01,.1);PG_lr(L,'Leg','rb',D,.11,.025,.05,0,-.06,.09);PG_lr(L,'UpLeg','rb',D,.09,.13,.06,.1,-.2,0);},
 // granatiere: zaino pesante con due bombole, bandoliera di granate, visore arancione
 gren(e,T,L){const A=PG_armor(e,0x9a5e2c,.6,.35),D=PG_DK(),G=PG_GM(),E=PG_em(T.vis,2.6),O=PG_mat('olv',0x3a4428,.6,.3);
  L.push(['Spine2','rb',D,.36,.4,.18,0,-.03,-.24],['Spine2','c16',G,.12,.42,.12,-.1,.02,-.37],['Spine2','c16',G,.12,.42,.12,.1,.02,-.37],['Spine2','c16',E,.125,.025,.125,-.1,.12,-.37],['Spine2','c16',E,.125,.025,.125,.1,.12,-.37],
   ['Spine2','cap',G,.13,.08,.13,-.1,.25,-.37],['Spine2','cap',G,.13,.08,.13,.1,.25,-.37],
   ['Spine1','rb',D,.5,.065,.06,0,.1,.15,0,0,.62],['Spine1','sph2',O,.075,.095,.075,-.13,.0,.19],['Spine1','sph2',O,.075,.095,.075,-.04,.06,.2],['Spine1','sph2',O,.075,.095,.075,.05,.12,.2],['Spine1','sph2',O,.075,.095,.075,.14,.18,.19],
   ['Head','rb',G,.22,.045,.04,0,.16,.11],['Head','rb',E,.19,.022,.02,0,.16,.13]);
  PG_lr(L,'Arm','sph2',A,.24,.13,.25,.02,.08,0);PG_lr(L,'Arm','rb',A,.16,.1,.17,.06,0,0,0,0,-.3);PG_lr(L,'Leg','rb',A,.13,.12,.08,0,-.02,.1);PG_lr(L,'UpLeg','rb',D,.1,.14,.07,.1,-.18,0);PG_lr(L,'UpLeg','sph2',O,.07,.09,.07,.1,-.08,.07);},
 // bruto: corazza da assalto, spallacci enormi, maschera con feritoia gialla, fasce di pericolo, tubi di scarico
 brute(e,T,L){const A=PG_armor(e,0x6e2622,.55,.5),D=PG_DK(),S=PG_ST(),H=PG_haz(),E=PG_em(T.vis,2.8);
  L.push(['Spine2','rb',H,.26,.045,.02,0,-.08,.165],['Spine2','rb',A,.4,.38,.12,0,0,-.17],['Spine2','c16',S,.07,.32,.07,-.11,.3,-.22],['Spine2','c16',S,.07,.32,.07,.11,.3,-.22],['Spine2','c16',E,.075,.02,.075,-.11,.46,-.22],['Spine2','c16',E,.075,.02,.075,.11,.46,-.22],
   ['Head','rb',A,.07,.06,.24,0,.24,-.02],['Spine','rb',D,.36,.08,.26,0,.02,0]);
  PG_lr(L,'Arm','dome',A,.25,.13,.26,.025,.06,0,0,0,-.25);PG_lr(L,'Arm','dome',A,.2,.1,.21,.075,.0,0,0,0,-.75);PG_lr(L,'Arm','rb',H,.05,.012,.2,.02,.125,0,0,0,-.25);
  PG_lr(L,'ForeArm','rb',A,.2,.11,.12,.14,0,0);PG_lr(L,'ForeArm','rb',S,.16,.025,.13,.14,.06,0);PG_lr(L,'UpLeg','rb',A,.12,.2,.05,0,-.2,.12);PG_lr(L,'Leg','rb',A,.11,.1,.06,0,-.01,.11);},
 // cecchino: cappuccio e mantellina scura, ottica rossa a un occhio, corazza leggera grafite
 sniper(e,T,L){const A=PG_armor(e,0x2a3038,.5,.55),D=PG_DK(),C=PG_CL(),G=PG_GM(),E=PG_em(T.vis,3);PG_droid(e,T,L,A,D,.8);
  L.push(['Head','sph2',C,.27,.29,.29,0,.11,-.035],['Neck','tor',C,.24,.24,.7,0,.02,0,Math.PI/2],['Head','c16',G,.085,.07,.085,.045,.11,.115,Math.PI/2],['Head','c16',E,.06,.02,.06,.045,.11,.15,Math.PI/2],['Head','rb',G,.12,.03,.05,-.03,.15,.11],
   ['Spine2','rb',C,.22,.3,.1,0,-.02,-.15],['Spine2','rb',G,.08,.2,.05,-.12,-.02,-.17],['Spine2','c16',D,.012,.3,.012,-.12,.22,-.17],['Spine2','sph2',E,.025,.025,.025,-.12,.37,-.17]);},
 // assaltatore: corazza leggera rossa, lame sugli avambracci, cresta luminosa, strisce luminose sui polpacci
 runner(e,T,L){const A=PG_armor(e,0x8a241e,.45,.6),D=PG_DK(),S=PG_ST(),E=PG_em(T.vis,3);PG_droid(e,T,L,A,D,.7);
  L.push(['Head','sph2',A,.25,.26,.27,0,.12,0],['Head','rb',E,.035,.05,.25,0,.25,-.01],['Head','rb',E,.17,.03,.03,0,.12,.13]);
  PG_lr(L,'ForeArm','wedge',S,.3,.02,.07,.2,.0,.07,0,0,0);PG_lr(L,'ForeArm','rb',E,.3,.012,.012,.2,.0,.105);PG_lr(L,'Leg','rb',E,.012,.22,.02,.045,-.2,.04);},
 // scudiero: corazza pesante blu, elmo con feritoia a T, batteria sulla schiena
 scudo(e,T,L){const A=PG_armor(e,0x2c4e7c,.5,.55),D=PG_DK(),G=PG_GM(),E=PG_em(T.vis,2.6);PG_droid(e,T,L,A,D,1.15);
  L.push(['Head','sph2',A,.27,.28,.29,0,.12,-.005],['Head','rb',A,.2,.1,.08,0,.06,.11],['Head','rb',E,.03,.1,.02,0,.12,.145],['Head','rb',E,.17,.025,.02,0,.15,.145],
   ['Spine2','rb',D,.28,.32,.12,0,0,-.17],['Spine2','rb',E,.04,.2,.02,-.08,0,-.235],['Spine2','rb',E,.04,.2,.02,.08,0,-.235]);
  PG_lr(L,'Arm','sph2',A,.22,.15,.23,.04,.07,0);}
};
// guscio corazzato comune agli androidi Xbot (k = spessore: leggero 0.7 … pesante 1.15)
function PG_droid(e,T,L,A,D,k){
 L.push(['Spine2','rb',A,.32*k,.24,.09*k,0,.05,.075],['Spine2','rb',A,.3*k,.26,.07*k,0,.04,-.075],['Hips','rb',D,.31,.05,.21,0,.04,0],['Hips','rb',A,.12,.08,.05,0,-.03,.11]);
 PG_lr(L,'Arm','sph2',A,.15*k,.1*k,.16*k,.045,.045,0);PG_lr(L,'ForeArm','rb',A,.17,.075*k,.085*k,.13,0,0);PG_lr(L,'UpLeg','rb',A,.1,.2,.05*k,0,-.2,.065);PG_lr(L,'Leg','rb',A,.09,.09,.05*k,0,0,.065);PG_lr(L,'Leg','rb',A,.08,.22,.04*k,0,-.22,.055);}

/* ===== soldati e androidi ===== */
soldier=function(e,T){soldier0(e,T);const t=e.t||Object.keys(ET).find(k=>ET[k]===T),f=PG_KIT[t];
 if(T.mdl==='xbot')for(const m of e.mats){m.color.copy(lc(t==='sniper'?0x24272c:0x30343b));m.roughness=.55;m.metalness=.45;}
 if(T.mdl!=='xbot')e.root.traverse(m=>{if(m.isMesh&&/visor/i.test(m.name)&&m.material.emissive)m.material.emissiveIntensity=1.2;});
 if(f){const L=[];f(e,T,L);PG_kit(e,L,e.bn);}
 PG_rim(e,e.mats,T.vis||0xffffff,.1);};

/* ===== automa: robot da combattimento corazzato (stesso scheletro, stesse animazioni e hitbox) ===== */
const PG_robot0=BUILD.robot;
BUILD.robot=function(e,T){PG_robot0(e,T);if(!e.rob)return;const bones={};e.root.traverse(o=>{if(o.isBone)bones[o.name]=o;});
 const A=PG_armor(e,0x4c5446,.5,.6),D=PG_DK(),S=PG_ST(),H=PG_haz(),E=PG_em(0xff3a1c,2.6);e.mats.length=0;e.mats.push(A);
 // materiali del modello: corazza oliva, acciaio scuro, lenti scure (il "Black" erano gli occhioni arancioni da cartone).
 // In three r128 un materiale non va condiviso tra mesh con pelle (le mani) e mesh rigide: due copie, una per tipo.
 const pl=plateTex(),seen=new Map(),inner=e.root.children[0],mk=(k,sk)=>{let n;
   if(k==='Main'){n=new THREE.MeshStandardMaterial({color:lc(0x5a6352),map:pl.map,normalMap:pl.nrm,roughness:.5,metalness:.62});e.mats.push(n);}
   else if(k==='Grey'){n=new THREE.MeshStandardMaterial({color:lc(0x2a2d31),roughness:.42,metalness:.78});e.mats.push(n);}
   else n=new THREE.MeshStandardMaterial({color:lc(0x121418),emissive:lc(0xff2a10),emissiveIntensity:.06,roughness:.12,metalness:.85});
   n.skinning=sk;return n;};
 inner.traverse(m=>{if(!m.isMesh||m.userData.pgKit)return;const key=m.material.name+(m.isSkinnedMesh?'|s':'');let n=seen.get(key);if(!n)seen.set(key,n=mk(m.material.name,!!m.isSkinnedMesh));m.material=n;});
 // testa un po' più piccola (prima era un testone da cartone): ora sta dentro la sfera della hitbox, che resta uguale
 const hn=inner.getObjectByName('Head');if(hn&&!hn.isBone)hn.scale.multiplyScalar(.85);
 const L=[['Torso_1','rb',A,.52,.3,.09,0,.13,.33],['Torso_1','rb',H,.54,.07,.08,0,-.07,.32],['Torso_1','rb',E,.18,.03,.02,0,.2,.38],
  ['Torso_1','rb',D,.5,.44,.22,0,.1,-.42],['Torso_1','rb',E,.06,.28,.02,-.12,.1,-.535],['Torso_1','rb',E,.06,.28,.02,.12,.1,-.535],['Torso_1','c16',S,.09,.32,.09,-.19,.43,-.44],['Torso_1','c16',S,.09,.32,.09,.19,.43,-.44],
  ['Head_1','tor',E,1.16,1.16,.55,0,.33,0,Math.PI/2],['Head_1','rb',A,.14,.1,.8,0,.78,-.02],['Head_1','c16',S,.025,.5,.025,.36,.85,-.2],['Head_1','sph2',E,.05,.05,.05,.36,1.1,-.2],['Head_1','rb',A,.26,.09,.12,0,.08,.6],
  ['LowerLegL','rb',A,.2,.17,.08,0,0,.16],['LowerLegR','rb',A,.2,.17,.08,0,0,.16],['UpperLegL','rb',D,.17,.22,.17,0,-.12,.03],['UpperLegR','rb',D,.17,.22,.17,0,-.12,.03],
  ['LowerArmL','rb',A,.22,.3,.22,0,.24,0,0,0,0,'L'],['LowerArmR','rb',A,.22,.3,.22,0,.24,0,0,0,0,'L'],['UpperArmL','c16',D,.12,.2,.12,0,.12,0,0,0,0,'L'],['UpperArmR','c16',D,.12,.2,.12,0,.12,0,0,0,0,'L'],
  ['ShoulderL','rb',A,.32,.14,.34,.06,.08,0,0,0,-.38],['ShoulderR','rb',A,.32,.14,.34,-.06,.08,0,0,0,.38],['ShoulderL','rb',H,.3,.04,.1,.07,.16,0,0,0,-.38],['ShoulderR','rb',H,.3,.04,.1,-.07,.16,0,0,0,.38]];
 PG_kit(e,L,bones,e.root);PG_rim(e,e.mats,0xff5a30,.12);};

/* ===== torrette, droni e colossi: solo luce di contorno (i dettagli sono in modelli.js) ===== */
for(const[k,c,s]of[['turret',0xff4020,.16],['drone',0xff4020,.18]]){const b0=BUILD[k];BUILD[k]=function(e,T){b0(e,T);PG_rim(e,e.mats,c,s);};}
{const m0=BUILD.mech;BUILD.mech=function(e,T,ci){m0(e,T,ci);PG_rim(e,e.mats,e.B?e.B.gl:0xff6020,.1);};}

/* ===== scudo antisommossa dello scudiero ===== */
function PG_shield(e){const s=e.shm;if(!s)return;const D=new THREE.MeshStandardMaterial({color:lc(0x16191d),roughness:.6,metalness:.5}),S=new THREE.MeshStandardMaterial({color:lc(0x8a929c),roughness:.3,metalness:.9}),
  W=new THREE.MeshStandardMaterial({color:lc(0x0a1420),emissive:lc(0x4a90ff),emissiveIntensity:.7,roughness:.1,metalness:.3}),E=new THREE.MeshStandardMaterial({color:lc(0x0a0a0c),emissive:lc(0x60a0ff),emissiveIntensity:2.6});
 const pl=plateTex();s.material=new THREE.MeshStandardMaterial({color:lc(0x3e5068),map:pl.map,normalMap:pl.nrm,roughness:.45,metalness:.7});s.userData.ownMat=1;
 const g=new THREE.Group();g.scale.set(1/s.scale.x,1/s.scale.y,1/s.scale.z);s.add(g);
 for(const[w,h,x,y]of[[.86,.07,0,.64],[.86,.07,0,-.64],[.07,1.34,.41,0],[.07,1.34,-.41,0]])R_(D,w,h,.09,x,y,0,g);
 R_(D,.56,.17,.05,0,.38,.02,g);R_(W,.48,.1,.03,0,.38,.04,g);R_(S,.3,.34,.05,0,-.04,.035,g);P('cyl',D,.12,.06,.12,0,-.04,.07,g).rotation.x=Math.PI/2;
 P('box',new THREE.MeshStandardMaterial({color:M.hazard?0xffffff:lc(0xc8a020),map:M.hazard?M.hazard.map:null,roughness:.7,metalness:.3}),.74,.09,.012,0,-.5,.032,g);for(const x of[-.34,.34]){P('sph',E,.05,.05,.03,x,.58,.05,g);for(const y of[.25,-.3])P('cyl',S,.04,.03,.04,x,y,.05,g).rotation.x=Math.PI/2;}
 R_(D,.12,.3,.08,0,0,-.06,g);bake(g);g.traverse(m=>{m.raycast=()=>{};m.castShadow=true;});}
const PG_spawnE0=spawnE;
spawnE=function(type,slot,pos){const e=PG_spawnE0(type,slot,pos);if(e&&e.shm)try{PG_shield(e);}catch(err){console.warn('PG scudo',err);}return e;};

/* ===== attori di scena: Maggiore Varr, Kross, Marsh (stesso Xbot, stesse animazioni idle/corsa) =====
   mkActor (livelli.js) resta com'è: qui si rifanno i materiali del corpo e si aggancia l'equipaggiamento alle ossa.
   Pezzi con pelle rigida (PG_kit): una mesh per materiale, materiali condivisi tra le istanze, niente ombre, non colpibili. */
// corpo: s = tuta [colore, ruvidità, metallo], j = giunture [colore, emissivo, intensità], rim = luce di contorno
const PG_ASTY={varr:{s:[0x2e2a36,.62,.32],j:[0x2a2432,0xff30c0,.06],rim:[0xff40c8,.14]},
 kross:{s:[0x1a1a1f,.5,.45],j:[0x121214,0xffa818,.5],rim:[0xffb030,.07]},
 marsh:{s:[0x3a4a4c,.7,.25],j:[0x1a2224,0x60f0e0,.5],rim:[0x60f0e0,.06]}};
const PG_ACT={
 // Maggiore Varr: capelli fucsia con coda alta e ciuffo asimmetrico, monocolo magenta, colletto alto, spalline con gradi,
 // corazza sagomata, giacca da ufficiale con falde sulle cosce, cintura, fondina con pistola sulla coscia destra, stivali alti
 varr(L){const H=PG_mat('vr_hair',0x6a1050,.78,.04),C=PG_mat('vr_coat',0x2a1a38,.72,.12),A=PG_mat('vr_arm',0x4a3c56,.38,.7,1),D=PG_mat('vr_dk',0x121016,.4,.35),G=PG_GM(),E=PG_em(0xff30c0,2.4);
  L.push(
   // capelli: calotta, nuca, ciuffo spazzato a sinistra, ciocca lunga sul lato sinistro (destra rasata), coda alta con anello luminoso
   ['Head','dome',H,.255,.23,.268,0,.122,-.008],['Head','sph2',H,.224,.21,.19,0,.1,-.06],['Head','cap',H,.07,.19,.055,.045,.185,.09,-.3,0,.96],['Head','cap',H,.04,.17,.05,.106,.075,.065,0,0,.06],
   ['Head','sph2',H,.085,.075,.085,0,.155,-.13],['Head','cap',H,.066,.32,.062,0,-.02,-.17,.26],['Head','tor',E,.11,.11,.6,0,.13,-.148,Math.PI/2+.26],
   // fascia-visore con fessura luminosa, monocolo sull'occhio destro, auricolare
   ['Head','c16',G,.25,.042,.248,0,.112,0],['Head','rb',E,.075,.01,.01,.04,.112,.124],
   ['Head','c16',G,.064,.03,.064,-.044,.112,.124,Math.PI/2],['Head','c16',E,.048,.012,.048,-.044,.112,.14,Math.PI/2],['Head','rb',G,.03,.06,.06,-.116,.1,.015],['Head','sph2',E,.016,.016,.016,-.132,.1,.015],
   // colletto alto da ufficiale
   ['Neck','tor',C,.2,.2,1,0,.03,-.008,Math.PI/2],['Neck','rb',C,.17,.12,.025,0,.065,-.075,-.25],
   // corazza sagomata sul petto, bordo luminoso, risvolti della giacca, gradi sul petto
   ['Spine2','rb',A,.27,.2,.07,0,.035,.085],['Spine2','sph2',PG_mat('vr_cui',0x4a3c56,.34,.7),.25,.15,.08,0,.03,.1],['Spine2','rb',E,.24,.012,.012,0,-.068,.122],
   ['Spine2','rb',C,.06,.22,.025,.135,.05,.105,0,0,-.22],['Spine2','rb',C,.06,.22,.025,-.135,.05,.105,0,0,.22],
   ['Spine2','rb',E,.035,.008,.012,.085,.13,.148],['Spine2','rb',E,.035,.008,.012,.085,.115,.148],['Spine2','rb',E,.035,.008,.012,.085,.1,.148],
   // schiena della giacca e mantellina corta
   ['Spine2','rb',C,.32,.36,.05,0,-.03,-.085],['Spine2','rb',C,.34,.22,.025,0,.04,-.125,.12],['Spine2','rb',E,.012,.2,.008,0,.03,-.14,.12],
   // giacca sull'addome (aperta davanti) e cintura con fibbia luminosa
   ['Spine1','rb',C,.1,.2,.03,.095,-.03,.11],['Spine1','rb',C,.1,.2,.03,-.095,-.03,.11],['Spine1','rb',C,.3,.2,.04,0,-.03,-.1],
   ['Hips','rb',D,.32,.055,.225,0,.05,0],['Hips','rb',E,.05,.03,.01,0,.05,.114],['Hips','rb',G,.04,.05,.03,.12,.04,.08],
   // fondina sulla coscia destra con pistola e cinghia
   ['RightUpLeg','c16',D,.165,.028,.155,0,-.2,0],['RightUpLeg','rb',D,.05,.17,.09,-.115,-.22,0],['RightUpLeg','rb',G,.035,.085,.045,-.12,-.1,-.022,.3],['RightUpLeg','sph2',E,.018,.018,.018,-.142,-.2,.03]);
  // spalline con frangia luminosa, gradi sulla spallina sinistra, polsini corazzati con filo luminoso, falde della giacca, ginocchiere, stivali alti
  PG_lr(L,'Shoulder','rb',A,.15,.03,.13,.115,.07,-.015,0,0,-.12);PG_lr(L,'Shoulder','rb',E,.016,.012,.12,.19,.06,-.015,0,0,-.12);
  for(let i=0;i<3;i++)L.push(['LeftShoulder','rb',E,.01,.006,.075,.08+i*.03,.09-i*.0036,-.015,0,0,-.12]);
  PG_lr(L,'ForeArm','rb',A,.1,.075,.08,.18,0,0);PG_lr(L,'ForeArm','rb',E,.2,.008,.01,.12,.04,0);
  PG_lr(L,'UpLeg','rb',C,.19,.46,.03,0,-.2,-.095,.1);L.push(['LeftUpLeg','rb',C,.03,.44,.15,.1,-.2,-.01,0,0,.08]);
  PG_lr(L,'Leg','rb',A,.085,.09,.05,0,-.01,.065);PG_lr(L,'Leg','c16',D,.115,.3,.125,0,-.26,0);PG_lr(L,'Leg','rb',E,.012,.012,.13,.058,-.115,0);},
 // Kross: berretto da ufficiale con fascia d'oro e visiera, visore ambra, spalline d'oro, cappotto nero lungo
 kross(L){const C=PG_mat('kr_coat',0x101014,.6,.2),A=PG_mat('kr_arm',0x2a2a30,.35,.75,1),O=PG_mat('kr_gold',0xc89028,.3,.9),V=PG_mat('kr_vis',0x08080a,.25,.6),E=PG_em(0xffa818,2.4);
  L.push(['Head','c16',C,.25,.07,.27,0,.205,0],['Head','c16',C,.29,.03,.31,0,.245,.02,-.12],['Head','c16',O,.255,.03,.275,0,.18,0],['Head','rb',V,.2,.012,.09,0,.17,.14,.25],
   ['Head','rb',E,.17,.022,.02,0,.12,.122],['Neck','tor',C,.21,.21,.9,0,.03,-.008,Math.PI/2],
   ['Spine2','rb',A,.3,.23,.08,0,.04,.085],['Spine2','rb',O,.03,.18,.012,0,.03,.128],['Spine2','rb',C,.34,.38,.06,0,-.03,-.088],
   ['Spine1','rb',C,.14,.2,.035,.09,-.03,.11],['Spine1','rb',C,.14,.2,.035,-.09,-.03,.11],['Spine1','rb',C,.32,.2,.04,0,-.03,-.1],['Hips','rb',O,.33,.05,.23,0,.05,0]);
  PG_lr(L,'Shoulder','rb',O,.16,.034,.14,.115,.072,-.015,0,0,-.12);PG_lr(L,'Shoulder','rb',E,.018,.014,.13,.195,.062,-.015,0,0,-.12);PG_lr(L,'ForeArm','rb',A,.11,.08,.085,.18,0,0);
  PG_lr(L,'UpLeg','rb',C,.2,.5,.03,0,-.22,-.095,.08);PG_lr(L,'UpLeg','rb',C,.03,.48,.16,.1,-.22,-.01,0,0,.06);PG_lr(L,'Leg','c16',C,.12,.3,.13,0,-.26,0);},
 // Marsh (alleato): elmetto con cuffia e microfono, gilet tattico con tasche, ginocchiere
 marsh(L){const A=PG_mat('ms_arm',0x2c5a5a,.5,.45,1),D=PG_DK(),G=PG_GM(),E=PG_em(0x60f0e0,2.2);
  L.push(['Head','dome',A,.27,.25,.285,0,.13,-.01],['Head','rb',A,.24,.03,.06,0,.14,.12,-.2],['Head','c16',G,.06,.04,.06,.122,.1,0,0,0,Math.PI/2],['Head','rb',G,.012,.02,.09,.12,.06,.06],['Head','sph2',E,.018,.018,.018,.13,.06,.1],
   ['Spine2','rb',A,.31,.23,.085,0,.04,.08],['Spine2','rb',A,.3,.25,.07,0,.03,-.08],['Spine1','rb',D,.07,.1,.05,-.07,.02,.15],['Spine1','rb',D,.07,.1,.05,.07,.02,.15],['Spine2','rb',E,.04,.012,.012,.09,.13,.125],
   ['Hips','rb',D,.31,.05,.215,0,.045,0]);
  PG_lr(L,'Leg','rb',A,.09,.09,.05,0,-.01,.065);PG_lr(L,'Arm','sph2',A,.15,.09,.15,.045,.045,0);}
};
function PG_actor(a){const k=a.k,sty=PG_ASTY[k],f=PG_ACT[k];if(!sty||!f)return;const inner=a.root.children.find(o=>!o.isMesh);if(!inner)return;
 const mats=[],bones={};
 inner.traverse(o=>{if(o.isBone)bones[o.name.replace('mixamorig','')]=o;if(!o.isMesh)return;const m=o.material;
  if(/joint/i.test(o.name+m.name)){m.color.copy(lc(sty.j[0]));m.emissive=lc(sty.j[1]);m.emissiveIntensity=sty.j[2];m.roughness=.4;m.metalness=.6;}
  else{m.color.copy(lc(sty.s[0]));m.roughness=sty.s[1];m.metalness=sty.s[2];}mats.push(m);});
 const L=[];f(L);PG_kit({root:a.root},L,bones);PG_rim({},mats,sty.rim[0],sty.rim[1]);
 // Varr un po' più snella (dopo l'equipaggiamento, così i pezzi seguono la stessa proporzione)
 if(k==='varr')inner.scale.x*=.93;}
const PG_mkActor0=mkActor;
mkActor=function(k,list){const a=PG_mkActor0(k,list);try{PG_actor(a);}catch(err){console.warn('PG attore',k,err);}return a;};
