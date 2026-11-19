// Settore Zero — tocco, mira, slider di schivata
'use strict';
/* ===== input ===== */
const QS={el:$('qs'),tr:$('qst'),kn:$('qsk'),gl:$('qsg'),lb:$('qsl'),bar:$('qsbi'),id:null,sx:0,sy:0,p:0,len:160,dir:'L'};
function qsKnob(){const d=QS.dir,L=QS.len,p=QS.p;let x=0,y=0;if(d==='R')x=L*p;else if(d==='L')x=L*(1-p);else if(d==='D')y=L*p;else y=L*(1-p);QS.kn.style.transform='translate('+x+'px,'+y+'px)';}
function qsShow(dir,lab){const hz=dir==='L'||dir==='R',len=hz?236:196;QS.len=len-68;QS.dir=dir;QS.p=0;QS.id=null;QS.tr.style.width=(hz?len:68)+'px';QS.tr.style.height=(hz?68:len)+'px';QS.kn.textContent={L:'◀',R:'▶',U:'▲',D:'▼'}[dir];QS.lb.textContent=lab||{L:'SCHIVA',R:'SCHIVA',U:'SALTA',D:'ABBASSATI'}[dir];QS.tr.style.display=dir==='T'?'none':'block';
 QS.gl.style.left=(dir==='R'?QS.len:0)+'px';QS.gl.style.top=(dir==='D'?QS.len:0)+'px';QS.el.style.display='block';qsKnob();if(G.mv&&dir!=='T')qsGrab();}
function qsHide(){QS.el.style.display='none';QS.id=null;}
function qsGrab(){if(!aim.down)return;QS.id=aim.id;QS.sx=aim.rx;QS.sy=aim.ry;aim.down=false;aim.id=null;aim.hold=0;}
function qsMove(e){const d=QS.dir,dl=d==='R'?e.clientX-QS.sx:d==='L'?QS.sx-e.clientX:d==='D'?e.clientY-QS.sy:QS.sy-e.clientY;QS.p=clamp(dl/QS.len,0,1);qsKnob();if(QS.p>=.8)qteEnd(true);}
function qteStart(dir,T,ok,defer,lab){if(G.qte||state!=='play')return false;G.qte={dir,t:T,T,ok,defer};scopeOff(false);/* niente cannocchiale durante le QTE (mirini.js) */qsShow(dir,lab);if(dir!=='T')qsGrab();snd('tele');return true;}
function startDodge(dir){G.dg={dir,t:0,d:.62};G.inv=.75;snd('throw');}
function qteEnd(good){const q=G.qte;if(!q)return;G.qte=null;qsHide();G.qres={good,t:.6};if(good){snd('pick');if(!q.defer)startDodge(q.dir);if(q.ok)q.ok();}else snd('lose0');}
function swipe(x,y){if(!G||!G.qte)return;if(!G.sw){G.sw={x,y};return;}const dx=x-G.sw.x,dy=y-G.sw.y;if(Math.hypot(dx,dy)<34)return;const dir=Math.abs(dx)>Math.abs(dy)?(dx<0?'L':'R'):(dy<0?'U':'D');G.sw={x,y};qteEnd(dir===G.qte.dir);}
function aimSet(e){aim.rx=e.clientX;aim.ry=e.clientY;aim.cx=e.clientX;aim.cy=Math.max(6,e.clientY-(e.pointerType==='touch'||e.pointerType==='pen'?58:0));ndc.set(aim.cx/innerWidth*2-1,-(aim.cy/innerHeight)*2+1);}
hud.addEventListener('pointerdown',e=>{if(state!=='play')return;const id=e.target.id;if(id==='pause'){pause();return;}if(id==='swap'){swapW();return;}if(id==='adv'){advance();return;}
 e.preventDefault();if(G.qte&&G.qte.dir==='T'){const q=proj2(TV.copy(G.qte.pos));if(q&&(Math.hypot(e.clientX-q[0],e.clientY-q[1])<80||Math.hypot(e.clientX-q[0],e.clientY-58-q[1])<80)){snd('w_'+cw().t);G.kick=1;glow(G.qte.pos,1.4,0xfff0c0,.2,3);bits(G.qte.pos,8,M.spark,4,.04,.4);qteEnd(true);}return;}if(G.qte){QS.id=e.pointerId;QS.sx=e.clientX;QS.sy=e.clientY;return;}if(id==='covz'){cov.down=true;cov.id=e.pointerId;e.target.classList.add('on');return;}aim.down=true;aim.id=e.pointerId;aimSet(e);aim.hold=.5;});
addEventListener('pointermove',e=>{if(e.pointerId===QS.id&&G&&G.qte){qsMove(e);return;}if(aim.down&&e.pointerId===aim.id)aimSet(e);});
function pup(e){if(e.pointerId===QS.id){QS.id=null;QS.p=0;if(G&&G.qte)qsKnob();}if(e.pointerId===aim.id){aim.down=false;aim.id=null;}if(e.pointerId===cov.id){cov.down=false;cov.id=null;$('covz').classList.remove('on');}}
addEventListener('pointerup',pup);addEventListener('pointercancel',pup);
addEventListener('keydown',e=>{keys[e.code]=1;if(state==='play'){if(e.code==='KeyQ')swapW();if(e.code==='Escape')pause();if(e.code==='Enter'&&G.phase==='clear')advance();if(G.qte){const m={ArrowLeft:'L',ArrowRight:'R',ArrowUp:'U',ArrowDown:'D'}[e.code];if(m)qteEnd(m===G.qte.dir);}}});addEventListener('keyup',e=>{keys[e.code]=0;});
document.addEventListener('touchmove',e=>{if(state==='play')e.preventDefault();},{passive:false});
document.addEventListener('contextmenu',e=>e.preventDefault());
