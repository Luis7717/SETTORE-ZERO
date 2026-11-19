// Settore Zero — costruzione dei livelli, attori di scena, porte
'use strict';
/* ===== level build ===== */
const Z0=3,Z1=-25.16,PP={x:0,z:0,dx:0,dz:-1};
const POSES=[{x:0,z:0,th:0,i:0,o:1},{x:-2.5,z:-.5,th:-.18,i:0,o:1},{x:2.5,z:-.5,th:.18,i:0,o:1},{x:0,z:-8.5,th:0,i:0,o:1},{x:0,z:-22.2,th:Math.PI,i:0,o:1},{x:0,z:-22.2,th:Math.PI,i:1,o:0},{x:-2.5,z:-21.7,th:Math.PI+.18,i:1,o:0},{x:2.5,z:-21.7,th:Math.PI-.18,i:1,o:0}];
const angd=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
function pathLen(P){let t=0;for(let i=1;i<P.length;i++)t+=Math.hypot(P[i][0]-P[i-1][0],P[i][1]-P[i-1][1]);return t;}
/* percorsi con angoli arrotondati: ogni punto ricorda la distanza percorsa sul percorso originale,
   così pericoli, rampe e durate restano uguali; cambia solo la traiettoria nelle curve */
const CURVE_R=1.2,SPC=new WeakMap();
function smoothPath(P){const sig=P.length+':'+P[0]+':'+P[P.length-1];let c=SPC.get(P);if(c&&c.sig===sig)return c;
 const n=P.length,D=[0];for(let i=1;i<n;i++)D.push(D[i-1]+Math.hypot(P[i][0]-P[i-1][0],P[i][1]-P[i-1][1]));const Q=[[P[0][0],P[0][1],0]];
 for(let i=1;i<n-1;i++){const A=P[i-1],V=P[i],B=P[i+1],l1=D[i]-D[i-1],l2=D[i+1]-D[i];if(l1<1e-3||l2<1e-3){Q.push([V[0],V[1],D[i]]);continue;}
  const ux=(V[0]-A[0])/l1,uz=(V[1]-A[1])/l1,wx=(B[0]-V[0])/l2,wz=(B[1]-V[1])/l2,th=Math.acos(clamp(ux*wx+uz*wz,-1,1));
  if(th<.03){Q.push([V[0],V[1],D[i]]);continue;}const t=Math.min(CURVE_R*Math.tan(Math.min(th,2.6)/2),.45*l1,.45*l2),ax=V[0]-ux*t,az=V[1]-uz*t,bx=V[0]+wx*t,bz=V[1]+wz*t,N=Math.max(4,Math.ceil(th*9));
  for(let j=0;j<=N;j++){const s=j/N,a=(1-s)*(1-s),b=2*(1-s)*s,c2=s*s;Q.push([a*ax+b*V[0]+c2*bx,a*az+b*V[1]+c2*bz,D[i]-t+2*t*s]);}}
 Q.push([P[n-1][0],P[n-1][1],D[n-1]]);c={sig,Q,tot:D[n-1]};SPC.set(P,c);return c;}
function pathPos(P,k,o){const c=smoothPath(P),Q=c.Q,tot=c.tot,d=clamp(k,0,1)*tot;let j=1;while(j<Q.length-1&&Q[j][2]<d)j++;const a=Q[j-1],b=Q[j],l=b[2]-a[2],t=l>1e-6?clamp((d-a[2])/l,0,1):1;
 o.x=a[0]+(b[0]-a[0])*t;o.z=a[1]+(b[1]-a[1])*t;let dx=b[0]-a[0],dz=b[1]-a[1];if(Math.hypot(dx,dz)<1e-3&&j<Q.length-1){dx=Q[j+1][0]-b[0];dz=Q[j+1][1]-b[1];}if(Math.hypot(dx,dz)>1e-3){o.dx=dx;o.dz=dz;}return tot;}
/* direzione dello sguardo: verso un punto un po' più avanti sul percorso, così le curve si anticipano dolcemente */
const YAW_MAX=4.2,LOOK_AHEAD=1.6,_PL={x:0,z:0,dx:0,dz:-1};
function pathYaw(P,u,tot,cur){pathPos(P,Math.min(1,u+LOOK_AHEAD/Math.max(tot,.01)),_PL);const dx=_PL.x-cur.x,dz=_PL.z-cur.z;return Math.hypot(dx,dz)>.25?Math.atan2(-dx,-dz):Math.atan2(-cur.dx,-cur.dz);}
function mkProp(st,type,mesh,o){const p=Object.assign({type,mesh,dead:false,si:st.i},o);mesh.traverse(m=>{m.userData.prop=p;});G.props.push(p);return p;}
function mkChest(st,x,z,ry,gold,room){const g=new THREE.Group(),bm=gold?M.gold:M.wood,tm=gold?M.purple:M.steel;
 P('box',bm,.8,.42,.5,0,.21,0,g);const lid=new THREE.Group();lid.position.set(0,.42,-.25);g.add(lid);P('box',bm,.8,.16,.5,0,.08,.25,lid);
 for(const sx of[-.28,.28]){P('box',tm,.07,.44,.52,sx,.21,0,g);P('box',tm,.07,.18,.52,sx,.08,.25,lid);}P('box',gold?M.purple:M.gold,.12,.14,.04,0,.4,.26,g);
 let cp;if(room){g.position.set(x,0,z);g.rotation.y=ry;st.rg.add(g);const q=st.r2c(x,z);cp=new V3(q[0],.3,q[1]);}else{st.put(g,x,0,z,ry);cp=new V3(x,.3,z);}
 return mkProp(st,'chest',g,{lid,gold,cp});}
function blk(st,x,z,m){for(const o of st.cob)if(!(o.p&&o.p.dead)&&Math.abs(x-o.x)<o.hx+m&&Math.abs(z-o.z)<o.hz+m)return true;const r=st.c2r(x,z);return st.hit(r[0],r[1],m)||r[0]<st.x0-.05+m||r[0]>st.x1+.05-m;}
const NDIR=[[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]];
function navPath(st,x0,z0,x1,z1,m){PF.m.push('nav');const C=.4,W=Math.ceil((st.x1-st.x0+1)/C),H=74,ox=st.x0-.5,oz=Z1-.6,g=new Uint8Array(W*H),N=W*H;
 for(let j=0;j<H;j++)for(let i=0;i<W;i++){const zr=oz+(j+.5)*C,q=st.r2c(ox+(i+.5)*C,zr);g[j*W+i]=zr<Z1+.35||zr>Z0-.35||blk(st,q[0],q[1],m)?1:0;}
 const ci=(x,z)=>{const r=st.c2r(x,z);return clamp(Math.floor((r[1]-oz)/C),0,H-1)*W+clamp(Math.floor((r[0]-ox)/C),0,W-1);},
  near=c=>{if(!g[c])return c;const cx=c%W,cy=c/W|0;let b=-1,bd=1e9;for(let j=Math.max(0,cy-7);j<Math.min(H,cy+8);j++)for(let i=Math.max(0,cx-7);i<Math.min(W,cx+8);i++)if(!g[j*W+i]){const d=(i-cx)*(i-cx)+(j-cy)*(j-cy);if(d<bd){bd=d;b=j*W+i;}}return b<0?c:b;},
  cc=c=>st.r2c(ox+(c%W+.5)*C,oz+((c/W|0)+.5)*C);
 const S=near(ci(x0,z0)),T=near(ci(x1,z1)),prev=new Int32Array(N).fill(-1),q=[S];prev[S]=S;
 for(let h=0;h<q.length&&prev[T]<0;h++){const c=q[h],cx=c%W,cy=c/W|0;for(const d of NDIR){const nx=cx+d[0],ny=cy+d[1];if(nx<0||ny<0||nx>=W||ny>=H)continue;const n=ny*W+nx;if(prev[n]>=0||g[n])continue;if(d[0]&&d[1]&&(g[cy*W+nx]||g[ny*W+cx]))continue;prev[n]=c;q.push(n);}}
 if(prev[T]<0)return[[x1,z1]];const pts=[];for(let c=T;c!==S;c=prev[c])pts.push(cc(c));pts.push(cc(S));pts.reverse();pts.push([x1,z1]);
 const clr=(a,b)=>{const d=Math.hypot(b[0]-a[0],b[1]-a[1]),n=Math.ceil(d/.2);for(let i=1;i<n;i++){const t=i/n;if(blk(st,a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,m-.04))return false;}return true;};
 const out=[];let cur=[x0,z0],i=0;while(i<pts.length){let j=pts.length-1;while(j>i&&!clr(cur,pts[j]))j--;out.push(pts[j]);cur=pts[j];i=j+1;}return out;}
function goTo(e,tx,tz,s,m){const p=e.root.position;if(!e.path||e.ptx!==tx||e.ptz!==tz){for(const mm of[m,.3,.16]){e.path=navPath(G.stages[G.si],p.x,p.z,tx,tz,mm);if(e.path.length>1||Math.hypot(tx-p.x,tz-p.z)<1)break;}e.pi=0;e.ptx=tx;e.ptz=tz;}
 const w=e.path[e.pi],dx=w[0]-p.x,dz=w[1]-p.z,d=Math.hypot(dx,dz);if(d<=s){p.x=w[0];p.z=w[1];if(e.pi<e.path.length-1)e.pi++;}else{p.x+=dx/d*s;p.z+=dz/d*s;e.ma=Math.atan2(dx,dz);}}
function turn(e,dt){if(e.ma===undefined)return;e.ry=e.ry===undefined?e.ma:e.ry+angd(e.ma,e.ry)*Math.min(1,dt*12);e.root.rotation.y=e.ry;}
function openSlot(st,e,k,y){const C=[[-1.6,-6],[1.7,-6.6],[-2.1,-8.6],[2,-8],[0,-7.4],[-1,-10],[1.1,-10.6],[0,-5.2]];for(let i=0;i<C.length;i++){const c=C[(i+k)%C.length];if(!blk(st,c[0],c[1],.42)&&st.los(c[0],y||1.35,c[1])&&!G.en.some(o=>o!==e&&!o.dead&&o.slot&&Math.hypot(o.slot.x-c[0],o.slot.z-c[1])<1.1))return{x:c[0],z:c[1],cover:null,used:e};}return{x:0,z:-5.2,cover:null,used:e};}
/* ===== attori di scena ===== */
function mkActor(k,list){const C=ACTORS[k],src=MODELS.xbot,g=new THREE.Group(),inner=THREE.SkeletonUtils.clone(src.scene);g.add(inner);blob(g,.5);g.scale.setScalar(C.sc);
 inner.traverse(m=>{if(m.isMesh){m.material=m.material.clone();m.userData.ownMat=1;m.castShadow=false;m.frustumCulled=false;m.raycast=()=>{};if(/joint/i.test(m.name+m.material.name)){m.material.color.copy(lc(0x101012));m.material.emissive=lc(C.j);m.material.emissiveIntensity=1.3;}else{m.material.color.copy(lc(C.c));m.material.metalness=.5;m.material.roughness=.38;}}});
 const mx=new THREE.AnimationMixer(inner),act={};for(const n of['idle','run'])(act[n]=mx.clipAction(src.animations.find(q=>q.name.toLowerCase()===n))).play();act.run.setEffectiveWeight(0);
 const a={k,root:g,mx,act,w:0,path:null,pi:0,spd:6.4,ry:0,wait:0};enG.add(g);(list||G.acts).push(a);return a;}
function updActors(dt){for(const a of G.acts){const p=a.root.position;let run=0;
  if(a.fol){const m=G.mv,st=G.stages[G.si];if(m&&m.kind==='run'){const tot=m.tot||pathLen(m.P),sd=clamp(m.t,0,1)*tot+a.fol,lk=st.haz.some(h=>h.kind==='lock'&&h.s<3);if(sd>=tot-.4){if(a.root.visible){a.root.visible=false;if(lk)st.door.o=0;}}else{pathPos(m.P,sd/tot,PA);const l=Math.hypot(PA.dx,PA.dz)||1,o=a.fx!==undefined?a.fx:Math.sin(G.t*1.4)*.8;p.set(PA.x-PA.dz/l*o,runY(st,sd),PA.z+PA.dx/l*o);a.ry=Math.atan2(PA.dx,PA.dz);run=1;if(a.fx===undefined){a.fol+=dt*.45*(m.ts===undefined?1:m.ts);if(tot-sd<4.5)st.door.o=1;}}}}
  else if(a.path){const w=a.path[a.pi],dx=w[0]-p.x,dz=w[1]-p.z,d=Math.hypot(dx,dz),s=a.spd*dt;if(d<=s){p.x=w[0];p.z=w[1];if(++a.pi>=a.path.length){a.path=null;if(a.end){a.root.visible=false;const d=G.stages[G.si].door;if(d&&G.phase!=='out')d.o=0;}}}else{p.x+=dx/d*s;p.z+=dz/d*s;a.ry=Math.atan2(dx,dz);run=1;if(a.end){const f=a.path[a.path.length-1],dd=G.stages[G.si].door;if(dd&&Math.hypot(f[0]-p.x,f[1]-p.z)<4)dd.o=1;}}}
  else if(a.look)a.ry=Math.atan2(G.px-p.x,G.pz-p.z);
  a.root.rotation.y+=angd(a.ry,a.root.rotation.y)*Math.min(1,dt*10);a.w+=(run-a.w)*Math.min(1,dt*8);a.act.run.setEffectiveWeight(a.w);a.act.idle.setEffectiveWeight(1-a.w);a.mx.update(dt);}}
let subT=0;function sub(line,ms){const i=line.indexOf(':'),w=line.slice(0,i),el=$('sub');el.innerHTML='<b style="color:'+(SPK[w]||'#fff')+'">'+w+'</b><span>'+line.slice(i+1)+'</span>';el.classList.add('on');clearTimeout(subT);subT=setTimeout(()=>el.classList.remove('on'),ms||3600);}
function cineOn(t,ft,f){G.phase='cine';G.cine={t,ft,f};hud.classList.add('cine');}
function cineOff(){G.cine=null;hud.classList.remove('cine');$('card').style.display='none';}
function startFight(st){G.mv=null;G.px=G.pz=0;$('fade').style.opacity=0;const a=st.actor;
 if(st.boss){cineOn(3.1);spawnWave(st);st.wd=1.3;const c=$('card');c.innerHTML='<small>'+BOSS[chI(G.L)].t+'</small><b>'+chOf(G.L).boss.toUpperCase()+'</b>';c.style.display='block';if(st.say)sub(st.say,3600);}
 else if(a){const e=st.exitP||st.outP[st.outP.length-1];cineOn(2.6,1.3,()=>{a.path=navPath(st,a.root.position.x,a.root.position.z,e[0],e[1],.4);a.pi=0;a.end=1;});if(st.say)sub(st.say,3800);}
 else G.phase='fight';}
function escPre(m){const n=Math.floor((1.5-m.lb)/.2);m.nb=m.nb||0;while(m.nb<n&&m.nb<7){const p=new V3(m.nb?rr(-2.2,2.2):0,rr(1.2,2.6),m.nb?G.pz+Math.max(3.4,8-m.nb*.75):.5),r=rr(3,4.2);glow(p,r*1.7,0xff6a18,.6,3.5);glow(p,r,0xffe6a8,.4,4.5);bits(p,7,m.nb%2?M.spark:M.scrap,7,.1,1);if(m.nb%2===0)snd('boom');xl.position.copy(p);xl.intensity=5;G.shake=1;m.nb++;}if(m.lb<=0)hud.classList.remove('cine');}
function escFx(dt){G.fxT=(G.fxT||0)-dt;G.shake=Math.max(G.shake,.2);if(G.fxT<=0){G.fxT=rr(.3,.55);const z=G.pz-rr(7,13),sx=rnd(2)?1:-1;TV.set(sx*rr(2.2,4.2),rr(3.6,4.8),z);bits(TV,5,rnd(2)?M.scrap:M.spark,2.5,.09,1.1);if(rnd(3)===0){TV.set(sx*4.2,rr(1,3),z);glow(TV,rr(2,3.4),0xff8030,.35,4);glow(TV,1.6,0xfff0c0,.18,5);snd('boom');}}}
function stFrame(st){st.cob=[];const hall=MODELS.hall,rg=st.rg=new THREE.Group(),P0=st.pose,c=Math.cos(P0.th),s=Math.sin(P0.th),len=Z0-Z1+1,mz=(Z0+Z1)/2;st.obs=[];
 st.c2r=(x,z)=>[x*c+z*s+P0.x,-x*s+z*c+P0.z];st.r2c=(xr,zr)=>{const dx=xr-P0.x,dz=zr-P0.z;return[dx*c-dz*s,dx*s+dz*c];};
 st.put=(o,x,y,z,ry)=>{const r=st.c2r(x,z);o.position.set(r[0],y,r[1]);o.rotation.y=(ry||0)+P0.th;rg.add(o);return o;};
 st.hit=(xr,zr,m)=>st.obs.some(o=>Math.abs(xr-o.x)<o.hx+m&&Math.abs(zr-o.z)<o.hz+m);
 st.x0=st.kind===7?-13.3:st.kind===8?-9.6:-4.7;st.x1=st.kind===6?13.3:st.kind===8?9.6:4.7;st.wide=st.kind>=6;st.carve=st.kind===6?[[3.2,-11.5,13.6,3.3]]:st.kind===7?[[-13.6,-11.5,-3.2,3.3]]:st.kind===8?[[4.7,-8.5,9.9,3.3],[-9.9,-8.5,-4.7,3.3]]:[];st.dx=st.kind===6?11:st.kind===7?-11:0;
 st.ok=(x,z,m)=>{const r=st.c2r(x,z),mm=4.7-(m||4.2);return r[0]>=st.x0+mm&&r[0]<=st.x1-mm&&r[1]>Z1+.9&&r[1]<Z0-.9&&!st.hit(r[0],r[1],.95);};
 st.los=(x,y,z)=>{const n=Math.ceil(Math.hypot(x,z)/.25);for(let i=1;i<n;i++){const t=i/n,r=st.c2r(x*t,z*t),yy=1.62+(y-1.62)*t;for(const o of st.obs)if(yy<o.h&&Math.abs(r[0]-o.x)<o.hx+.12&&Math.abs(r[1]-o.z)<o.hz+.12)return false;if(yy<1.2)for(const o of st.cob)if(o.p&&!o.p.dead&&Math.abs(x*t-o.x)<o.hx+.1&&Math.abs(z*t-o.z)<o.hz+.1)return false;}return true;};
 st.depth=c>0?(P0.z-Z1)/c:(Z0-P0.z)/-c;
 if(st.wide)wideShell(st,rg);else if(hall){const iv=M.inv;rg.add(box(10.4,.3,len,iv,0,-.15,mz),box(10.4,.3,len,iv,0,5.65,mz),box(.4,5.5,len,iv,-4.9,2.75,mz),box(.4,5.5,len,iv,4.9,2.75,mz),box(10.4,5.5,.4,iv,0,2.75,Z0+.2),box(10.4,5.5,.4,iv,0,2.75,Z1-.2));if(st.sty&&G)roomShell(rg,chI(G.L));else{const h=noRay(hall.scene.clone(true));h.scale.set(1.3,.85,1);h.position.set(-20.115*1.3,2.96*.85,3-3.08);rg.add(h);}}
 else{rg.add(box(10.8,.3,len,M.floor,0,-.15,mz,3),box(10.8,.3,len,M.ceil,0,5.15,mz,3),box(.4,5,len,M.wall,-5.2,2.5,mz,3),box(.4,5,len,M.wall,5.2,2.5,mz,3),box(10.8,5,.4,M.wall,0,2.5,Z0+.2,3),box(10.8,5,.4,M.wall,0,2.5,Z1-.2,3));for(let z=0;z>Z1;z-=6)for(const sx of[-1,1]){const q=P('box',M.strip,1.8,.05,.28,sx*2.3,4.95,z,rg);q.castShadow=false;}}
 return rg;}
const DEC={};function dmat(k,col,o){return DEC[k]||(DEC[k]=new THREE.MeshStandardMaterial(Object.assign({color:lc(0x0a0c10),emissive:lc(col),emissiveIntensity:1.4,roughness:.5},o)));}
function decor(rg,ci,sx,zr){const g=new THREE.Group();g.position.set(sx*4.55,0,zr);rg.add(g);const A=(geo,m,a,b,c,px,py,pz)=>{const q=P(geo,m,a,b,c,px,py,pz,g);q.castShadow=false;q.raycast=()=>{};return q;};
 switch(ci){
  case 1:A('cyl',M.steel,.95,.25,.95,0,.12,0);A('cyl',dmat('gl',0x30ffa0,{transparent:true,opacity:.32,emissiveIntensity:.45,depthWrite:false}),.8,1.7,.8,0,1.1,0);A('sph',dmat('sp',0x60ffb0),.34,.7,.34,0,1.05,0);A('cyl',M.steel,.95,.2,.95,0,2.05,0);break;
  case 2:A('cyl',M.dark,1.05,1.1,1.05,0,.55,0);A('cyl',dmat('lava',0xff6a10,{emissiveIntensity:2.2}),.9,.06,.9,0,1.11,0);A('box',M.steel,.16,.16,1.3,sx*.2,2.6,0);break;
  case 3:A('sph',dmat('pod',0x70ff30),.75,.9,.75,sx*.1,.45,-.15);A('sph',DEC.pod,.5,.6,.5,sx*.2,1.5,.25);A('sph',DEC.pod,.35,.4,.35,sx*.25,2.3,-.2);break;
  case 4:A('box',M.steel,.7,2.2,1.05,sx*.1,1.1,0);A('box',dmat('cryo',0x50c8ff),.06,1.25,.6,-sx*.27,1.3,0);break;
  case 5:case 8:A('cyl',dmat(ci===5?'core':'zero',ci===5?0x40e0ff:0xc050ff,{emissiveIntensity:2}),.3,5,.3,sx*.15,2.5,0);for(const y of[.3,1.9,3.5])A('cyl',M.steel,.5,.18,.5,sx*.15,y,0);break;
  case 6:A('box',dmat('ban',0xb01818,{emissiveIntensity:.35}),.05,2.7,1,sx*.12,2.5,0);A('box',dmat('emb',0xffc040),.06,.5,.5,sx*.09,2.9,0);break;
  case 7:A('box',M.dark,.12,2.1,1.25,sx*.1,1.05,0);for(const y of[.6,1.1,1.6])A('box',M.steel,.07,.11,1,-sx*.02,y,0);break;
  default:g.add(box(.6,2,1.2,M.locker,sx*.15,1,0));}}
const HZL={laserU:'LASER — SALTA',laserD:'LASER — GIÙ',barrel:'BARILE — SCHIVA',brute:'MAZZATA — GIÙ',automa:'PUGNO — SCHIVA',rocket:'RAZZO — SCHIVA',drone:'DRONE — GIÙ',gap:'VORAGINE — SALTA',beam:'TRAVE — SALTA',pipe:'TUBO — GIÙ',shut:'SARACINESCA — SCIVOLA',lock:'SPARA AL PANNELLO'},
 HZD={laserU:'U',laserD:'D',brute:'D',drone:'D',gap:'U',beam:'U',pipe:'D',shut:'D',lock:'T'},
 HZP={l:['laserU','laserD','gap','shut','drone'],c:['barrel','rocket','brute','automa'],x:['laserU','barrel','brute','automa','rocket','drone','gap','shut'],e:['beam','pipe','barrel','gap']};HZP.q=HZP.c;HZP.m=HZP.e;
function mkDummy(type){const T=ET[type],e={t:type,T,root:new THREE.Group(),state:'hide',st:0,dead:false,fl:0,an:0,cr:0,aimK:0,tele:0,teleT:1,sx:0,shotN:0,frz:0,dt:0,atk:0};e.root.rotation.order='YXZ';BUILD[T.m](e,T);e.root.traverse(m=>{m.raycast=()=>{};});return e;}
function hzLas(st,h,rg,ys,ph){for(const y of ys){const b=P('box',M.doorL,8.8,.06,.06,0,y,0,rg);b.castShadow=false;st.put(b,0,y,h.z);}for(const sx of[-1,1]){const p=box(.3,ph,.3,M.dark,0,0,0);st.put(p,sx*4.45,ph/2,h.z);}h.src=new V3(h.x,ys[0],h.z);}
function hzSet(h,o,x,y,z){const r=h.st.c2r(x,z);o.position.set(r[0],y,r[1]);}
const HZ={
 laserU:{snd:'zap',b(st,h,rg){hzLas(st,h,rg,[.38],.7);}},
 laserD:{snd:'zap',b(st,h,rg){hzLas(st,h,rg,[1.5,1.78],2.1);}},
 beam:{b(st,h,rg){const b=box(9.2,.42,.5,M.steel,0,0,0,1);b.castShadow=true;st.put(b,0,.21,h.z);b.rotation.z=.015;for(const sx of[-3,2.2]){const c=box(rr(.5,.9),.3,rr(.5,.8),M.mcrate,0,0,0);st.put(c,sx,.56,h.z+rr(-.1,.1),rr(0,1));}h.src=new V3(h.x,.4,h.z);}},
 pipe:{b(st,h,rg){const b=box(9.2,.34,.5,M.steel,0,0,0,1);b.castShadow=true;st.put(b,0,1.68,h.z);b.rotation.z=-.045;for(const sx of[-2.4,.5,2.8]){const c=P('box',M.dark,.05,rr(.4,.9),.05,0,0,0,rg);st.put(c,sx,1.25,h.z);}h.src=new V3(h.x,1.7,h.z);}},
 gap:{b(st,h,rg){const g=box(9.4,.05,1.7,M.hole0,0,0,0);g.castShadow=false;st.put(g,0,.03,h.z);for(const dz of[-.88,.88]){const e=P('box',dmat('lava',0xff6a10,{emissiveIntensity:2.2}),9.4,.05,.09,0,0,0,rg);e.castShadow=false;st.put(e,0,.05,h.z+dz);}for(const sx of[-4.3,4.3]){const p=box(.5,.5,1.9,M.hazard,0,0,0);st.put(p,sx,.25,h.z);}h.src=new V3(h.x,.15,h.z);},t(h,k,dt){if(Math.random()<dt*9){TV.set(rr(-4,4),.1,h.z+rr(-.7,.7));bits(TV,2,M.spark,3,.03,.4);}}},
 shut:{b(st,h,rg){const g=h.pan=new THREE.Group();g.add(box(9.4,3.2,.22,M.door,0,0,0,2),box(9.4,.2,.26,M.hazard,0,-1.6,0,2));st.put(g,0,4.75,h.z);for(const sx of[-1,1]){const p=box(.35,5.4,.5,M.dark,0,0,0);st.put(p,sx*4.5,2.7,h.z);}h.src=new V3(h.x,2.6,h.z);},on(){snd('metal');},t(h,k){h.pan.position.y=4.75-1.75*Math.min(1,k);h.src.y=h.pan.position.y-1.5;},end(h){h.pan.position.y=2.2;}},
 barrel:{b(st,h,rg){const bx=h.bx=h.x+h.side*2;if(MODELS.bar)for(const o of[[0,0],[h.side*.62,-.7]]){const v=noRay(MODELS.bar.scene.clone(true));v.scale.setScalar(.0132);st.put(v,bx+o[0],0,h.z+o[1]);}const l=P('sph',M.doorL,.22,.22,.22,0,0,0,rg);l.castShadow=false;st.put(l,bx,1.25,h.z);h.lamp=l;h.src=new V3(bx,1,h.z);},t(h){h.lamp.visible=Math.sin(G.t*24)>0;},pass(h){explode(new V3(h.bx,1,h.z),3,0);h.lamp.visible=false;}},
 brute:{b(st,h,rg){const d=h.dm=mkDummy('brute'),x=h.x+h.side*1.35;st.put(d.root,x,0,h.z-.3,0);const c=h.club=new THREE.Group();P('box',M.dark,2.2,.11,.11,-h.side*1.1,0,0,c);P('box',M.steel,.4,.34,.34,-h.side*2.1,0,0,c);P('box',M.dark,.5,.1,.1,-h.side*2.1,.2,0,c).rotation.z=.8;st.put(c,x,1.52,h.z-.3,-h.side*1.75);h.src=new V3(x,1.75,h.z-.3);},
  t(h,k,dt){const w=clamp((k-.72)/.28,0,1);h.club.rotation.y=-h.side*1.75+h.side*w*w*3;poseH(h.dm,0,k<.75?1:0,dt);},idle(h,dt){poseH(h.dm,0,0,dt);}},
 automa:{b(st,h,rg){const d=h.dm=mkDummy('automa'),x=h.x+h.side*1.3;st.put(d.root,x,0,h.z-.25,Math.atan2(-h.side,.45));h.src=new V3(x,1.5,h.z-.25);},on(h){const d=h.dm;if(d.act){const p=d.act.Punch;p.reset();p.timeScale=p.getClip().duration/Math.max(.5,G.qte.T+.25);p.setEffectiveWeight(4);p.play();}},t(h,k,dt){if(h.dm.mx)h.dm.mx.update(dt);},idle(h,dt){if(h.dm.mx)h.dm.mx.update(dt);}},
 rocket:{b(st,h,rg){const d=h.dm=mkDummy('turret'),tz=h.tz=Math.max(h.z-8.5,-26);st.put(d.root,h.x,0,tz,0);h.src=new V3(h.x,1.1,tz);},on(h){const m=h.rk=new THREE.Group(),c=P('cyl',M.steel,.16,.6,.16,0,0,0,m);c.rotation.x=Math.PI/2;P('sph',M.doorL,.17,.17,.17,0,0,.32,m);fxG.add(m);snd('rocket');TV.set(h.x,1.1,h.tz+.8);glow(TV,1.2,0xffb060,.15,3);},
  t(h,k){const q=Math.min(1,k),m=h.rk;m.position.set(h.x,1.1+.35*q,mix(h.tz+.8,h.z+1.5,q));h.src.copy(m.position);if(Math.random()<.6)glow(m.position,.45,0xffa040,.28,2);},pass(h){explode(h.rk.position.clone(),2.6,0);fxG.remove(h.rk);}},
 drone:{b(st,h,rg){const d=h.dm=mkDummy('drone');h.dz=Math.max(h.z-7,-26.2);st.put(d.root,h.x,2.9,h.dz,0);h.src=new V3(h.x,2.9,h.dz);},on(){snd('tele');},idle(h,dt){for(const r of h.dm.rot)r.rotation.y+=dt*40;h.dm.root.position.y=2.9+Math.sin(G.t*3)*.15;},
  t(h,k,dt){const d=h.dm;for(const r of d.rot)r.rotation.y+=dt*40;const q=Math.min(1.25,k);h.src.set(h.x,mix(2.9,1.64,Math.min(1,q*1.3)),mix(h.dz,h.z+1.3,q));hzSet(h,d.root,h.src.x,h.src.y,h.src.z);d.root.rotation.x=.5;},end(h){explode(h.src.clone(),2,0);h.dm.root.visible=false;}},
 lock:{b(st,h,rg){h.z=-21.3;h.x=0;const p=h.pn=P('box',M.doorL,.6,.6,.1,0,0,0,rg);p.castShadow=false;st.put(p,0,1.7,-26.62);h.tp=new V3(0,1.7,-26.6);}}};
function buildRun(st,L){const rg=stFrame(st),rk=st.rk,esc=rk==='e'||rk==='m',zs=esc?[-17.5,-24]:[-8.5,-15.6,-22.6],pool=HZP[rk].slice();st.haz=[];let sg=rnd(2)?1:-1;st.door=mkDoor(rg,Z1,1);
 for(let k=0;k<zs.length;k++){let i=rnd(pool.length);if(k===zs.length-1&&pool[i]==='rocket')i=(i+1)%pool.length;let kind=pool.splice(i,1)[0];if((rk==='c'||rk==='q')&&k===zs.length-1)kind='lock';
  const side=rnd(2)?1:-1,h={st,z:zs[k],x:sg*rr(1.1,1.9),kind,side,dir:HZD[kind]||(side>0?'L':'R'),T:clamp(1.45-L*.008,1,1.45),s:0,ok:0,lab:HZL[kind]};sg=-sg;st.haz.push(h);HZ[kind].b(st,h,rg);
  if(kind!=='lock'){const ox=-Math.sign(h.x)*rr(2.5,3.1),oz=h.z+rr(3.2,4.2),c=box(1.5,1.5,1.5,M.mcrate,0,0,0,1);c.castShadow=true;st.put(c,ox,.75,oz,rr(-.3,.3));const c2=box(.9,.8,.9,M.mcrate,0,0,0,1);st.put(c2,ox+rr(-.2,.2),1.9,oz,rr(0,1));}}
 const P_=[[0,esc?-1.5:0]];for(const h of st.haz)if(h.kind==='lock')P_.push([0,h.z+2]);else{P_.push([h.x,h.z+3]);P_.push([h.x,h.z-1.3]);}P_.push([0,-(Z0-Z1-2.4)]);st.inP=st.outP=P_;}
function runHaz(m,sp,dt){const rs=G.stages[G.si],esc=rs.rk==='e'||rs.rk==='m';if(esc&&!(m.lb>0))escFx(dt);
 for(let hi=0;hi<rs.haz.length;hi++){const h=rs.haz[hi],Z=HZ[h.kind],pv=hi?rs.haz[hi-1]:null;
  if(!h.s){if(Z.idle)Z.idle(h,dt);if(!(m.lb>0)&&(!pv||pv.s>=2)){if(h.kind==='lock'){if(G.pz<h.z+.2&&qteStart('T',3,()=>{h.ok=1;},true,h.lab)){h.s=1;m.hold=1;G.qte.pos=h.tp;sub((rs.rk==='q'?'KROSS':'VARR')+':Porta sigillata. Addio, agente.',2600);}}
    else if(G.pz<h.z+sp*h.T+2.1&&qteStart(h.dir,Math.max(.6,(G.pz-h.z-1.95)/sp),()=>{h.ok=1;},true,h.lab)){h.s=1;h.z0=G.pz;G.qte.src=h.src;G.qte.h=h;if(Z.on)Z.on(h);}}}
  if(h.kind==='lock'){if(h.s===1){h.pn.visible=Math.sin(G.t*14)>-.3;if(!G.qte){h.s=3;m.hold=0;rs.door.o=1;h.pn.visible=false;if(h.ok)explode(h.tp.clone(),1.5,0);else{hurt(14*G.ds,true);G.shake=.6;snd('zap');}}}continue;}
  if(h.s>=1&&h.s<3&&Z.t)Z.t(h,clamp(1-(G.pz-h.z-1.9)/Math.max(.1,h.z0-h.z-1.9),0,1.6),dt);
  if(h.s===1&&G.pz<h.z+1.9){h.s=2;if(G.qte&&G.qte.h===h)qteEnd(false);if(h.ok)startDodge(h.dir);if(Z.pass)Z.pass(h);}
  if(h.s===2&&G.pz<h.z){h.s=3;if(!h.ok){hurt(16*G.ds,true);G.shake=.7;snd(Z.snd||'crash');}if(Z.end)Z.end(h);if(state!=='play')return;}}
 if(G.pz<-20.5&&!rs.haz.some(h=>h.kind==='lock'&&h.s<3))rs.door.o=1;}
/* porte scorrevoli */
/* porte d'acciaio a denti incrociati: due ante che scorrono dentro il muro (tagliate da piani di clipping) */
let DOORT=null;
function doorTpl(){if(DOORT)return DOORT;const W=1.45,H=3.3,T=.2,N=6,ph=H/N,sl=.07,gp=.02,ed=[],ms=new THREE.MeshStandardMaterial({color:lc(0x848e98),roughness:.4,metalness:.82}),md=new THREE.MeshStandardMaterial({color:lc(0x20242a),roughness:.6,metalness:.5});
 for(let k=0;k<N;k++){const x=k%2?-T:T;ed.push([x,k*ph+(k?sl:0)],[x,(k+1)*ph-(k<N-1?sl:0)]);}
 DOORT=[-1,1].map(sx=>{const sh=new THREE.Shape();sh.moveTo(sx*W,0);sh.lineTo(ed[0][0]+sx*gp,0);for(const p of ed)sh.lineTo(p[0]+sx*gp,p[1]);sh.lineTo(sx*W,H);sh.closePath();
  const geo=new THREE.ExtrudeGeometry(sh,{depth:.1,bevelEnabled:true,bevelThickness:.014,bevelSize:.014,bevelSegments:1});geo.translate(0,0,-.05);const g=new THREE.Group();g.add(new THREE.Mesh(geo,ms));
  for(const fz of[-1,1]){for(const y of[.6,2.7])P('box',md,.9,.12,.04,sx*.88,y,fz*.07,g);P('box',M.hazard,.9,.24,.03,sx*.88,1.65,fz*.068,g);P('box',md,.07,H-.24,.04,sx*1.37,H/2,fz*.07,g);P('box',md,.05,H-.5,.03,sx*.36,H/2,fz*.068,g);
   for(let k=0;k<N;k++){const tx=k%2?-T:T,mine=sx<0?tx>0:tx<0;if(!mine)continue;const c=P('cyl',md,.11,.05,.11,tx+sx*.16,(k+.5)*ph,fz*.07,g);c.rotation.x=Math.PI/2;const c2=P('cyl',ms,.05,.07,.05,tx+sx*.16,(k+.5)*ph,fz*.075,g);c2.rotation.x=Math.PI/2;}}
  bake(g);return g;});return DOORT;}
function mkDoor(rg,wz,s){const T=doorTpl(),d={l:[],k:0,o:0,g:0,rg,pl:[new THREE.Plane(new V3(0,1,0),1e6),new THREE.Plane(new V3(0,1,0),1e6)]},z=wz+s*.2,mm=new Map();const bk=P('box',M.hole0,2.9,3.3,.04,0,1.65,wz+s*.1,rg);bk.castShadow=false;d.wz=wz;d.s=s;d.bk=bk;
 T.forEach((t,i)=>{const g=new THREE.Group();for(const c of t.children){let m=mm.get(c.material);if(!m){m=c.material.clone();m.clippingPlanes=d.pl;mm.set(c.material,m);}const me=new THREE.Mesh(c.geometry,m);me.castShadow=false;g.add(me);}g.position.set(0,0,z);g.userData.sx=i?1:-1;rg.add(g);d.l.push(g);});
 d.lamp=P('box',M.doorL,.7,.12,.05,0,3.56,z+s*.05,rg);d.lamp.castShadow=false;return d;}
const DPL=new V3(),DPN=new V3(),DPM=new THREE.Matrix3();
function updDoor(dt){const st=G.stages[G.si];if(st&&st.door0&&st.door0.cl){animDoor(st.door0,dt);if(st.door0.k===0){st.door0.cl=0;dropBehind();}}const d=st&&st.door;if(!d)return;if(d.o&&!d.pv){d.pv=1;showNext();}if(d.o&&!d.so){d.so=1;snd('metal');}const g=d.o||d.g;if(g!==d.gg){d.gg=g;d.lamp.material=g?dmat('dgo',0x30ff70,{emissiveIntensity:2.2}):M.doorL;}animDoor(d,dt);}
function animDoor(d,dt){const k0=d.k;d.k=clamp(d.k+(d.o?1:-1)*dt*1.7,0,1);if(d.k===k0&&d.cp)return;
 if(!d.cp||d.k!==k0){d.cp=1;d.rg.updateWorldMatrix(true,false);const mw=d.rg.matrixWorld;DPM.getNormalMatrix(mw);for(let i=0;i<2;i++){const sx=i?-1:1;DPN.set(sx,0,0).applyMatrix3(DPM).normalize();DPL.set(-sx*1.452,0,0).applyMatrix4(mw);d.pl[i].setFromNormalAndCoplanarPoint(DPN,DPL);}}
 const e=d.k<.12?0:(d.k-.12)/.88,q=e*e*(3-2*e),off=(d.k<.12?d.k/.12*.035:.035)+q*1.68;for(const m of d.l)m.position.x=m.userData.sx*off;}
function buildRoom(st,L,boss,secs){const rg=stFrame(st),P0=st.pose,c=Math.cos(P0.th);
 const dzz=P0.o?Z1+.18:Z0-.18,dm=boss?M.doorL:M.door;for(const a of[[-1.5,1.65,.12,3.4],[1.5,1.65,.12,3.4],[0,3.36,3.12,.12]]){const m=P('box',dm,a[2],a[3],.1,a[0]+st.dx,a[1],dzz,rg);m.castShadow=false;if(boss)G.doorP.push(m);}{const dgp=new THREE.Group();dgp.position.x=st.dx;rg.add(dgp);st.door=mkDoor(dgp,P0.o?Z1:Z0,P0.o?1:-1);}
 const b=box(2.4,1.2,.45,M.hazard,0,0,0,1.2);b.castShadow=true;st.put(b,0,.6,-.75);st.cob.push({x:0,z:-.75,hx:1.2,hz:.25});
 const taken=new Set(),LZ=[-2,-6,-10,-14,-18,-22],fz=c>0?1:-1;
 if(st.kind===1){let n=0;for(let t=0;t<24&&n<4;t++){const sx=Math.random()<.5?-1:1,zr=rr(-22.3,.3),hz=rr(1.3,2.1),xr=sx*3.7,q0=st.r2c(xr,zr);if(Math.hypot(xr-P0.x,zr-P0.z)<3.8||st.hit(xr,zr,.7)||q0[1]>-3.5)continue;
   const cb=box(2,2.5,hz*2,[M.mcrate,M.mcrateB,M.mcrateR][rnd(3)],xr,1.25,zr);cb.castShadow=true;rg.add(cb);st.obs.push({x:xr,z:zr,hx:1,hz,h:2.5});n++;for(const lz of LZ)if(Math.abs(lz-zr)<hz+.9)taken.add(sx+'_'+lz);
   const d=-q0[1];if(d>6.5&&d<19&&Math.abs(q0[0])<d*.34+.3&&Math.random()<.8){const cz=zr+fz*(hz-.2),cv=box(1.7,1.1,.25,M.hazard,xr,3.05,cz,1.1);cv.castShadow=true;rg.add(cv);const cq=st.r2c(xr,cz),pr=mkProp(st,'crate',cv,{hp:null,cp:new V3(cq[0],3.05,cq[1])}),sq=st.r2c(xr,cz-fz*.75);st.slots.push({x:sq[0],z:sq[1],y:2.5,cover:pr,used:null,el:1});st.obs.push({x:xr,z:cz,hx:.85,hz:.13,h:3.5});}}}
 else if(st.kind===2){const D=Math.min(14,st.depth-4.5),zr=st.c2r(0,-D)[1],y=2.9;const dkk=box(9.4,.7,1.6,M.steel,0,y-.35,zr);dkk.castShadow=true;rg.add(dkk);
  for(const sx of[-1,1]){const pl=box(.3,y-.7,.3,M.steel,sx*3.3,(y-.7)/2,zr);pl.castShadow=true;rg.add(pl);st.obs.push({x:sx*3.3,z:zr,hx:.15,hz:.15,h:2.2});}
  const rl=box(9.4,1.1,.08,M.hazard,0,y+.55,zr+fz*.72,1.1);rl.castShadow=true;rg.add(rl);const rq=st.r2c(0,zr+fz*.72),pr=mkProp(st,'crate',rl,{hp:null,cp:new V3(rq[0],y+.55,rq[1])});
  for(const xr of[-2.7,-.9,.9,2.7])if(Math.random()<.75){const q=st.r2c(xr,zr-fz*.05);if(Math.abs(q[0])<-q[1]*.34+.3)st.slots.push({x:q[0],z:q[1],y,cover:pr,used:null,el:1});}}
 else if(st.kind===3){const m=corrM(chI(L));for(const zr of[-4.5,-9.5,-14.5,-19.5])for(const sx of[-1,1]){const xr=sx*2.35,q=st.r2c(xr,zr);if(Math.hypot(xr-P0.x,zr-P0.z)<4.2||q[1]>-4.2)continue;colonna(st,rg,m,xr,zr);}}
 else if(st.kind===4){const zr=st.c2r(0,-Math.min(11.5,st.depth-6))[1];macchina(st,rg,corrM(chI(L)),zr);}
 else if(st.kind===5){const m=corrM(chI(L));for(const sx of[-1,1]){const q0=st.r2c(sx*3.45,0),za=st.c2r(sx*3.45,-7.5)[1],zb=st.c2r(sx*3.45,-Math.min(18,st.depth-3))[1],zc=(za+zb)/2,hz=Math.abs(zb-za)/2;if(hz<2)continue;
   const dk=box(2.5,1.4,hz*2,m.r,sx*3.45,.7,zc,2);dk.castShadow=true;rg.add(dk);rg.add(box(2.6,.12,hz*2+.1,M.hazard,sx*3.45,1.42,zc,2));st.obs.push({x:sx*3.45,z:zc,hx:1.25,hz,h:1.4});for(const lz of LZ)if(Math.abs(lz-zc)<hz+.9)taken.add(sx+'_'+lz);
   for(const k of[-.6,0,.6])if(Math.random()<.8){const cz=zc+k*hz,cv=box(1.7,1.1,.25,M.hazard,sx*3.3,1.95,cz,1.1);cv.castShadow=true;rg.add(cv);const cq=st.r2c(sx*3.3,cz),pr=mkProp(st,'crate',cv,{hp:null,cp:new V3(cq[0],1.95,cq[1])}),sq=st.r2c(sx*3.3,cz-fz*.75);st.slots.push({x:sq[0],z:sq[1],y:1.4,cover:pr,used:null,el:1});st.obs.push({x:sx*3.3,z:cz,hx:.85,hz:.13,h:2.4});}}}
 else if(st.kind>=6)wideDress(st,rg,L,fz,taken,LZ);
 st.slots=st.slots.filter(q=>st.los(q.x,q.y+1.4,q.z));
 const used=[],dk=Math.min(1,(st.depth-2.4)/15.5);
 st.rndSlot=(d,cov)=>{for(let t=0;t<14;t++){const x=(Math.random()<.5?-1:1)*rr(1.3,Math.max(1.5,Math.min(st.wide?7.5:3.6,d*.28))),z=-d;if(!st.ok(x,z,3.85)||!st.ok(x,z+.95,3.85)||!st.los(x,1.35,z)||blk(st,x,z,.45)||used.some(u=>Math.abs(u[0]-x)<1.7&&Math.abs(u[1]-d)<2.2))continue;used.push([x,d]);
   const sl={x,z,cover:null,used:null};if(cov){const wood=Math.random()<.6,cr=box(1.5,1.15,.8,wood?M.wood:M.mcrate,0,0,0);cr.castShadow=true;st.put(cr,x,.575,z+.95);sl.cover=mkProp(st,'crate',cr,{hp:wood?70*G.hs:null,wood,cp:new V3(x,.575,z+.95)});st.cob.push({x,z:z+.95,hx:.75,hz:.4,p:sl.cover});}st.slots.push(sl);return sl;}return null;};
 [rr(5,6.5),rr(7.5,9.5),rr(10.5,12.5),rr(13.5,15.5)].forEach(d=>st.rndSlot(d*dk,true));for(let k=0;k<3;k++)st.rndSlot(rr(5.5,15.5)*dk,false);if(st.wide){[17,19.5,22,24].forEach(d=>st.rndSlot(d,true));for(let k=0;k<3;k++)st.rndSlot(rr(16,24),false);}
 const cs=st.slots.filter(q=>q.cover);for(let k=0,nb=1+rnd(2);k<nb&&cs.length;k++){const sl=cs[rnd(cs.length)],bx=sl.x+Math.sign(sl.x)*1.3,bz=sl.z+.5;if(!st.ok(bx,bz,4.3)||st.slots.some(q=>!q.el&&q!==sl&&Math.hypot(q.x-bx,q.z-bz)<1.1))continue;
  const m=new THREE.Mesh(new THREE.CylinderGeometry(.32,.32,.95,14),MODELS.bar?M.inv:M.barrel);m.userData.own=1;m.castShadow=true;if(MODELS.bar){const v=noRay(MODELS.bar.scene.clone(true));v.scale.setScalar(.0132);v.position.y=-.475;v.rotation.y=rr(0,6);v.traverse(o=>{if(o.isMesh)o.castShadow=true;});m.add(v);}st.put(m,bx,.475,bz);st.cob.push({x:bx,z:bz,hx:.34,hz:.34,p:mkProp(st,'barrel',m,{hp:18,cp:new V3(bx,.475,bz)})});}
 for(let k=0;k<secs;k++){const cand=[];for(const zr of LZ)for(const sx of[-1,1]){if(taken.has(sx+'_'+zr))continue;const q=st.r2c(sx*4.4,zr);if(q[1]<-9&&q[1]>-21&&Math.abs(q[0])<-q[1]*.3+.3)cand.push([sx,zr,q]);}
  if(!cand.length)break;const cd=cand[rnd(cand.length)],sx=cd[0],zr=cd[1],q=cd[2];taken.add(sx+'_'+zr);const ch=mkChest(st,sx*4.67,zr,-sx*Math.PI/2,true,true);ch.locked=true;const lk=box(.62,2,1.2,M.lockerC,sx*4.68,1,zr);rg.add(lk);mkProp(st,'secret',lk,{hp:30,chest:ch,sp:rr(1,3),cp:new V3(q[0],1,q[1])});G.snum++;}
 for(const zr of LZ)for(const sx of[-1,1])if(!taken.has(sx+'_'+zr)&&Math.random()<.62)decor(rg,chI(L),sx,zr);
 if(Math.random()<.75||st.i===0)for(let t=0;t<6;t++){const sx=Math.random()<.5?-1:1,d=rr(8,14)*dk,x=sx*Math.min(rr(2.4,3.4),d*.27);if(st.ok(x,-d,4.1)&&!blk(st,x,-d,.6)&&!st.slots.some(q=>!q.el&&Math.hypot(q.x-x,q.z+d)<1.25)){mkChest(st,x,-d,-sx*rr(.3,.9),false);st.cob.push({x,z:-d,hx:.5,hz:.4});break;}}
 const din=P0.i?[0,Z1+1.2]:[0,Z0-1.2],dout=P0.o?[st.dx,Z1+1.2]:[st.dx,Z0-1.2],a=st.r2c(din[0],din[1]),e=st.r2c(dout[0],dout[1]);
 st.inP=[a,[0,0]];st.outP=st.dx?[[0,0],[0,-1.7]].concat(navPath(st,0,-1.7,e[0],e[1],.45)):e[1]<-6?[[0,0],[0,Math.max(e[1]+4,-17)],e]:[[0,0],e];
 if(!st.dx&&!pathFree(st,st.outP,.32,2)){const n=navPath(st,0,-1.7,e[0],e[1],.45);if(n&&n.length>1){const o=[[0,0],[0,-1.7]].concat(n),l=o[o.length-1];if(Math.hypot(l[0]-e[0],l[1]-e[1])>.3)o.push(e);if(pathFree(st,o,.2,2))st.outP=o;}}
 if(!pathFree(st,st.inP,.32,0,.9)){const n=navPath(st,a[0],a[1],0,.3,.45);if(n&&n.length>1){const o=n.slice(),f=o[0];if(Math.hypot(f[0]-a[0],f[1]-a[1])>.3)o.unshift(a);o.push([0,0]);if(pathFree(st,o,.2,0,.9))st.inP=o;}}}
function segFree(st,a,b,m,s0,s1){const l=Math.hypot(b[0]-a[0],b[1]-a[1]),n=Math.max(1,Math.ceil(l/.2));for(let i=0;i<=n;i++){const t=i/n;if(t*l<s0||(1-t)*l<s1)continue;if(blk(st,a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,m))return false;}return true;}
function pathFree(st,P,m,skip,end){for(let i=1;i<P.length;i++)if(!segFree(st,P[i-1],P[i],m,i===1?skip||0:0,i===P.length-1?end||0:0))return false;return true;}
function safeX(st,x,z){for(const c of[x,0,1.2,-1.2,2.6,-2.6,3.6,-3.6])if(!blk(st,c,z,.6))return c;return x;}
const BLOBM=new THREE.MeshBasicMaterial({color:0,transparent:true,opacity:.4,depthWrite:false});
function blob(r,s){const b=new THREE.Mesh(GEO.cyl,BLOBM);b.scale.set(s*2,.01,s*2);b.position.y=.03;b.raycast=()=>{};b.renderOrder=1;r.add(b);}
function warm(){try{$('fade').style.opacity=1;const tmp=new THREE.Group(),ts=new Set(['drone']),ds=[];scene.add(tmp);let boss=0,i=0;for(const d of lvDef(G.L))if(!d.run)d.waves.forEach(w=>w.forEach(t=>{if(t==='boss')boss=1;else ts.add(t);}));
  for(const t of ts){const d=mkDummy(t);d.root.position.set((i%5-2)*1.3,0,-6-(i/5|0)*1.5);i++;tmp.add(d.root);ds.push(d.root);}if(boss){const e={root:new THREE.Group()};BUILD.mech(e,null,chI(G.L));e.root.position.set(0,0,-14);tmp.add(e.root);ds.push(e.root);}
  const p=new V3(0,1.5,-5);glow(p,.5,0xffffff,.05,1);glow(p,.5,0x111111,.05,1,false);bits(p,1,M.spark,1,.05,.05);bits(p,1,M.scrap,1,.05,.05);tracer(new V3(0,1.4,-1),p);
  const wb=new THREE.BoxGeometry(.2,.2,.2),seen=new Set();let wi=0;for(const st of G.stages)if(st.clip)for(const[m,c]of st.clip.mats){if(seen.has(m))continue;seen.add(m);const q=new THREE.Mesh(wb,c);q.position.set((wi%8-4)*.3,1.2+(wi/8|0)*.3,-3);wi++;tmp.add(q);}
  cam.position.set(0,1.6,0);cam.rotation.set(0,0,0);cam.updateMatrixWorld();scene.updateMatrixWorld();renderer.shadowMap.needsUpdate=true;renderer.render(scene,cam);for(const r of ds)freeE(r);scene.remove(tmp);wb.dispose();}catch(e){}}
function freeE(r){r.traverse(o=>{if(o.isMesh&&o.userData.own&&o.geometry)o.geometry.dispose();if(o.isSkinnedMesh&&o.skeleton&&o.skeleton.boneTexture)o.skeleton.dispose();});}
function enterRoom(i){PF.m.push('room');const old=G.stages[G.si];if(old&&old.rg.parent)world.remove(old.rg);for(const e of G.en){enG.remove(e.root);freeE(e.root);if(e.las)fxG.remove(e.las);}G.en=[];G.aimers=0;for(const h of holes)fxG.remove(h);holes.length=0;
 G.si=i;const st=G.stages[i],o=st.r2c(0,0);st.rg.rotation.y=-st.pose.th;st.rg.position.set(o[0],0,o[1]);world.add(st.rg);if(G.pw&&G.pw.parent)G.pw.parent.remove(G.pw);st.rg.updateMatrixWorld(true);clipMode(st,'none');dropBehind();{const d0=st.door0;if(d0&&d0.hid){d0.hid=0;for(const m of d0.l)m.visible=true;d0.k=1;d0.o=0;d0.cp=0;d0.cl=1;snd('metal');if(old&&st.link)keepBehind(old,st.link);}}
 G.lit=st.run?(st.rk==='e'||st.rk==='m'?1:0):st.lit||0;G.py=0;G.lookP=0;G.lookT=null;renderer.toneMappingExposure=G.lit===2?.6:1.12;hemi.intensity=G.lit===2?.035:G.lit===1?.26:.38;if(HM.Vent_light){const dm=G.lit===2;HM.Vent_light.emissiveIntensity=dm?.05:1;HM.Wall_blue.emissiveIntensity=dm?.3:1;for(const k in HM)HM[k].envMapIntensity=dm?.1:1;}syncClip();G.qte=null;G.dg=null;G.wnd=null;G.sl=1;qsHide();for(const a of G.acts)enG.remove(a.root);G.acts=[];cineOff();st.actor=null;
 if(st.run){const esc=st.rk==='e'||st.rk==='m';G.mv={P:st.inP,t:0,el:0,kind:'run',lb:esc?1.5:0,dur:pathLen(st.inP)/((esc?5.5:5)+Math.min(1.5,G.L*.035))};G.phase='run';if(esc)hud.classList.add('cine');
  sub(st.say||'BASE:'+RUNTXT[chI(G.L)],3800);toast('Trascina il cursore fino in fondo',2600);
  if(MODELS.xbot){if(st.rk==='c'||st.rk==='q'){const a=mkActor(st.rk==='c'?'varr':'kross');a.fol=7;a.root.position.set(0,0,-7);a.root.rotation.y=Math.PI;}else if(st.rk==='m'){const a=mkActor('marsh');a.fol=3.4;a.fx=1.4;a.root.position.set(1.4,0,-4.4);a.root.rotation.y=Math.PI;}}}
 else{const f=st.fl||'';if(MODELS.xbot&&(f.includes('v')||f.includes('k'))){const a=mkActor(f.includes('v')?'varr':'kross'),z=-Math.min(6.5,st.depth*.45);let x=0;for(const c of[0,1.3,-1.3,2.4,-2.4])if(!blk(st,c,z,.5)){x=c;break;}a.root.position.set(x,0,z);a.ry=a.root.rotation.y=Math.atan2(-x,-z);a.look=1;st.actor=a;}else if(st.say&&!st.boss&&!f.includes('m'))sub(st.say,4400);
  G.mv={P:st.inP,t:0,kind:'in',dur:Math.max(.7,pathLen(st.inP)/(5.2*(1+.05*pk('sp'))))};G.phase='in';if(G.lit===2)toast('Luci fuori uso: illumina con la torcia',2400);}
 const d0=st.inP[0],d1=st.inP[1];G.px=d0[0];G.pz=d0[1];PP.dx=d1[0]-d0[0];PP.dz=d1[1]-d0[1];G.yaw=G.mv.lb?Math.PI:pathYaw(G.mv.P,0,pathLen(G.mv.P),{x:d0[0],z:d0[1],dx:PP.dx,dz:PP.dz});st.wd=.4;dots();}
function buildLevel(L){
 if(G&&G.stages)for(const q of G.stages)if(q.rg)clearGroup(q.rg);
 clearGroup(world);clearGroup(enG);clearGroup(prG);clearGroup(fxG);parts.length=0;holes.length=0;setTheme(chOf(L).th);
 const boss=L%5===0,nR=3+(L>=11)+(L>=26);
 G={L,nS:0,si:0,phase:'in',stages:[],props:[],en:[],eproj:[],pproj:[],dn:[],bh:[],lean:1,rel:0,cdw:0,idle:0,kick:0,mflash:0,hitM:0,hitHead:false,hurtFx:0,shake:0,earn:0,kills:0,total:0,sfound:0,snum:0,aimers:0,slow:0,boomN:0,tr:null,qte:null,dg:null,inv:0,lit:0,
  maxAim:1+(L>=4)+(L>=12)+(L>=24),tsc:Math.max(.5,.94-.011*L),hs:1+.07*(L-1),ds:(1+.04*(L-1))*1.08,hp:100+20*pk('hp'),mhp:100+20*pk('hp'),ar:15*pk('ar'),lsp:6.5*(1+.08*pk('sp')),
  cz:0,cy:0,px:0,pz:0,yaw:0,mv:null,wi:0,ammo:{},t:0,boss:null,beam:0,stepT:0,hudT:0,doorP:[],acts:[],cine:null};
 S.eq.forEach(id=>{const w=wget(id);if(w)G.ammo[id]=wst(w).mag;});
 const D=lvDef(L),rooms=D.filter(d=>!d.run).length,nSec=1+(L>=3)+(L>=8);
 seeded(L*7919+101,()=>{const secSt=[];for(let i=0;i<nSec;i++)secSt.push(rnd(rooms));let ri=0;
  for(const d of D){const i=G.stages.length;if(d.run){const rs={i,run:true,rk:d.rk,say:d.say,pose:{x:0,z:Z0-1.2,th:0,i:0,o:1},slots:[],waves:[],wi:0,wd:0,zc:0};G.stages.push(rs);buildRun(rs,L);continue;}
   const st={i,pose:POSES[d.pose],slots:[],waves:d.waves,wi:0,wd:.9,zc:0,kind:d.kind,sty:d.sty,lit:d.lit,fl:d.fl,say:d.say,boss:d.boss};G.stages.push(st);buildRoom(st,L,d.boss,secSt.filter(q=>q===ri).length);ri++;st.waves.forEach(a=>G.total+=a.length);}});
 G.nS=G.stages.length;linkStages();
 buildWeapon();enterRoom(0);}
/* ===== porte aperte sulla stanza successiva =====
   Ogni stanza ha le sue coordinate. Per ogni coppia di stanze si calcola come ruotare e spostare la successiva
   in modo che il suo ingresso combaci con la porta d'uscita della precedente; il percorso d'uscita prosegue
   oltre la porta fino al punto di partenza della stanza nuova, così il passaggio avviene senza stacchi. */
const LINK_GAP=0;
function stFrameMat(st,m){const o=st.r2c(0,0);return m.compose(new V3(o[0],0,o[1]),new THREE.Quaternion().setFromAxisAngle(new V3(0,1,0),-st.pose.th),new V3(1,1,1));}
function relMat(o,root,m){m.identity();const ch=[];for(let x=o;x&&x!==root;x=x.parent)ch.push(x);for(let i=ch.length-1;i>=0;i--){ch[i].updateMatrix();m.multiply(ch[i].matrix);}return m;}
function linkStages(){for(let i=0;i+1<G.nS;i++){const a=G.stages[i],b=G.stages[i+1],d=a.door;if(!d||d.wz===undefined||!a.rg||!b.rg)continue;
 const Ma=stFrameMat(a,new THREE.Matrix4()).multiply(relMat(d.rg,a.rg,new THREE.Matrix4())),Dc=new V3(0,0,d.wz).applyMatrix4(Ma),nc=new V3(0,0,-d.s).transformDirection(Ma);nc.y=0;nc.normalize();
 const Mb=stFrameMat(b,new THREE.Matrix4());let En,inw;
 if(b.run){const d0=b.door0;if(!d0||d0.wz===undefined)continue;const M0=Mb.clone().multiply(relMat(d0.rg,b.rg,new THREE.Matrix4()));En=new V3(0,0,d0.wz).applyMatrix4(M0);inw=new V3(0,0,d0.s).transformDirection(M0);}
 else{const o=b.pose.o!==0;En=new V3(0,0,o?Z0:Z1).applyMatrix4(Mb);inw=new V3(0,0,o?-1:1).transformDirection(Mb);}
 inw.y=0;inw.normalize();const beta=Math.atan2(nc.x,nc.z)-Math.atan2(inw.x,inw.z),c=Math.cos(beta),s=Math.sin(beta),rot=v=>new V3(v.x*c+v.z*s,v.y,-v.x*s+v.z*c);
 const p=Dc.clone().addScaledVector(nc,LINK_GAP).sub(rot(En));p.y=Dc.y-En.y;b.link={beta,p};
 const P=a.run?a.inP:a.outP;if(!P||!b.inP)continue;a.exitP=P[P.length-1].slice();a.tot0=pathLen(P);const S=b.inP[0],TS=rot(new V3(S[0],0,S[1])).add(p);P.push([Dc.x+nc.x*.3,Dc.z+nc.z*.3],[TS.x,TS.z]);}
 for(let i=0;i+1<G.nS;i++){const a=G.stages[i],b=G.stages[i+1];if(b.link)clipLink(a,b);}}
/* taglio delle sale collegate (materiali copiati per stanza, 4 piani in modalità "intersezione"):
   - sala attuale a porta aperta: si nasconde solo ciò che sta nel tunnel dell'apertura, oltre la porta
     (es. la porta chiusa del modello della sala), così si vede la stanza successiva;
   - stanza successiva vista da dietro la porta: si nasconde ciò che sporge dietro il suo ingresso. */
const TUN_D=.12,TUN_W=1.46,TUN_H=3.32,CLIP_RUN=-.2,CLIP_ROOM=.15,CLIP_MARGIN=.05;
function clipKit(st){if(st.clip)return st.clip;const P=()=>new THREE.Plane(new V3(0,1,0),1e6);return st.clip={p:[P(),P(),P(),P()],li:null,tun:null,mats:new Map()};}
function clipLink(a,b){const d=a.door,ka=clipKit(a),kb=clipKit(b),Ra=relMat(d.rg,a.rg,new THREE.Matrix4()),pl=(n,p)=>new THREE.Plane().setFromNormalAndCoplanarPoint(n,p).applyMatrix4(Ra);
 ka.tun=[pl(new V3(0,0,d.s),new V3(0,0,d.wz+d.s*TUN_D)),pl(new V3(-1,0,0),new V3(-TUN_W,0,0)),pl(new V3(1,0,0),new V3(TUN_W,0,0)),pl(new V3(0,1,0),new V3(0,TUN_H,0))];
 let En,inw;if(b.run){const d0=b.door0,R0=relMat(d0.rg,b.rg,new THREE.Matrix4());En=new V3(0,0,d0.wz).applyMatrix4(R0);inw=new V3(0,0,d0.s).transformDirection(R0);}else{const o=b.pose.o!==0;En=new V3(0,0,o?Z0:Z1);inw=new V3(0,0,o?-1:1);}
 inw.y=0;inw.normalize();kb.li=new THREE.Plane().setFromNormalAndCoplanarPoint(inw,En.addScaledVector(inw,b.run?CLIP_RUN:CLIP_ROOM));clipMeshes(a);clipMeshes(b);}
function boxMinDist(pl,b){const n=pl.normal;return pl.constant+(n.x>0?n.x*b.min.x:n.x*b.max.x)+(n.y>0?n.y*b.min.y:n.y*b.max.y)+(n.z>0?n.z*b.min.z:n.z*b.max.z);}
function clipMeshes(st){const k=st.clip,R=new THREE.Matrix4(),bx=new THREE.Box3(),own=new Set(k.mats.values());st.rg.traverse(o=>{if(!o.isMesh||!o.geometry)return;const ms=Array.isArray(o.material)?o.material:[o.material];if(ms.some(m=>!m||m.clippingPlanes&&!own.has(m)))return;
  if(!o.geometry.boundingBox)o.geometry.computeBoundingBox();bx.copy(o.geometry.boundingBox).applyMatrix4(relMat(o,st.rg,R));
  if(!((k.li&&boxMinDist(k.li,bx)<-CLIP_MARGIN)||(k.tun&&boxMinDist(k.tun[0],bx)<-CLIP_MARGIN)))return;
  const sw=m=>{if(own.has(m))return m;let c=k.mats.get(m);if(!c){c=m.clone();c.clippingPlanes=k.p;c.clipIntersection=true;k.mats.set(m,c);own.add(c);}return c;};o.material=Array.isArray(o.material)?o.material.map(sw):sw(o.material);});}
/* mode: 'in' = stanza vista da dietro la porta, 'out' = sala con la porta aperta, altrimenti nessun taglio */
function clipMode(st,mode){const k=st.clip;if(!k)return;st.rg.updateMatrixWorld(true);const mw=st.rg.matrixWorld;
 for(let i=0;i<4;i++){const p=k.p[i];if(mode==='out'&&k.tun)p.copy(k.tun[i]).applyMatrix4(mw);else if(mode==='in'&&k.li){if(i===0)p.copy(k.li).applyMatrix4(mw);else p.set(new V3(0,1,0),-1e6);}else p.set(new V3(0,1,0),1e6);}}
function syncClip(){for(const st of G.stages||[])if(st.clip)for(const[m,c]of st.clip.mats){if(m.emissiveIntensity!==undefined)c.emissiveIntensity=m.emissiveIntensity;if(m.envMapIntensity!==undefined)c.envMapIntensity=m.envMapIntensity;}}
/* la sala precedente, riportata nelle coordinate della nuova stanza (trasformazione inversa del collegamento) */
function keepBehind(a,lk){const w=G.pb||(G.pb=new THREE.Group()),c=Math.cos(lk.beta),s=Math.sin(lk.beta),p=lk.p;w.rotation.set(0,-lk.beta,0);w.position.set(-(p.x*c-p.z*s),-p.y,-(p.x*s+p.z*c));w.add(a.rg);world.add(w);w.updateMatrixWorld(true);clipMode(a,'out');if(a.door){a.door.cp=0;animDoor(a.door,0);}}
function dropBehind(){const w=G.pb;if(!w)return;for(const ch of w.children.slice())w.remove(ch);if(w.parent)w.parent.remove(w);}
function showNext(){const b=G.stages[G.si+1],a=G.stages[G.si];if(!b||!b.link||!b.rg)return;const w=G.pw||(G.pw=new THREE.Group());w.rotation.set(0,b.link.beta,0);w.position.copy(b.link.p);
 const o=b.r2c(0,0);b.rg.rotation.y=-b.pose.th;b.rg.position.set(o[0],0,o[1]);w.add(b.rg);world.add(w);w.updateMatrixWorld(true);clipMode(a,'out');clipMode(b,'in');if(a.door&&a.door.bk)a.door.bk.visible=false;
 const d0=b.door0;if(d0){d0.hid=1;for(const m of d0.l)m.visible=false;if(d0.bk)d0.bk.visible=false;}renderer.shadowMap.needsUpdate=true;}
