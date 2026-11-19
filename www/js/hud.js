// Settore Zero — interfaccia in partita, inizio e fine livello
'use strict';
/* ===== hud ===== */
function dots(){$('lv').textContent='LIV '+G.L+' · '+chOf(G.L).n.toUpperCase()+(G.L%5===0?' · BOSS':'');}
const HU={};function hset(k,v,f){if(HU[k]!==v){HU[k]=v;f(v);}}
function hudUp(){const w=cw(),rl=G.rel>0,o=S.eq.length>1?wget(S.eq[(G.wi+1)%S.eq.length]):null;
 hset('hp',Math.max(0,Math.round(G.hp/G.mhp*100)),v=>{const t='scaleX('+v/100+')';$('hp').style.transform=t;$('hpg').style.transform=t;$('hpb').className='hb hp'+(v<=25?' low':v<=50?' mid':'');});
 hset('ar',Math.round(Math.min(100,G.ar/150*100)),v=>{$('ar').style.transform='scaleX('+v/100+')';$('arb').style.opacity=v?1:.3;});
 hset('red',Math.round((G.hurtFx*1.4+(G.hp<G.mhp*.25?.25:0))*20),v=>{$('red').style.opacity=v/20;});
 hset('wk',w.id+'|'+(w.l||0)+'|'+w.r,()=>{$('wn').innerHTML=wname(w)+(w.l?' +'+w.l:'');const i=$('wic');i.innerHTML=wIcon(w.t);i.style.color=RAR[w.r].c;});
 hset('am',rl?'R':G.ammo[w.id]+' / '+wst(w).mag,v=>{const a=$('am');a.textContent=rl?'RICARICA':v;a.className=rl?'rl':'';});
 hset('ok',o?o.id+'|'+o.r:'',v=>{const b=$('swap');b.style.display=o?'block':'none';if(o){$('swi').innerHTML=wIcon(o.t);b.style.setProperty('--sc',RAR[o.r].c);}});
 if(o)hset('oa',G.ammo[o.id]+'/'+wst(o).mag,v=>{$('swn').textContent=v;});
 const ex=G.lean>.4;hset('cov',G.mv?0:ex?1:2,v=>{const c=$('cov');c.textContent=v===0?'IN MOVIMENTO':v===1?'ESPOSTO':'AL RIPARO';c.style.color=v===1?'#ffb040':'#5fe08f';c.style.borderColor=v===1?'#ffb04088':'#5fe08f88';});}
function drawOv(){const g=og;g.setTransform(ODPR,0,0,ODPR,0,0);g.clearRect(0,0,innerWidth,innerHeight);g.lineCap='round';g.textAlign='center';
 if(G.warn>0){g.font='900 24px -apple-system,system-ui,sans-serif';g.fillStyle=Math.sin(G.t*18)>0?'#ff4040':'#ffd65a';g.strokeStyle='#000';g.lineWidth=4;g.strokeText(G.warnTxt,innerWidth/2,innerHeight*.3);g.fillText(G.warnTxt,innerWidth/2,innerHeight*.3);}
 if(G.qte){const q=G.qte;if(q.dir==='T'){const p=proj2(TV.copy(q.pos));if(p){const r=26+46*q.t/q.T;g.lineWidth=4;g.strokeStyle='#ffd65a';g.beginPath();g.arc(p[0],p[1],r,0,7);g.stroke();g.lineWidth=2;g.beginPath();g.arc(p[0],p[1],22,0,7);g.moveTo(p[0]-34,p[1]);g.lineTo(p[0]-12,p[1]);g.moveTo(p[0]+12,p[1]);g.lineTo(p[0]+34,p[1]);g.moveTo(p[0],p[1]-34);g.lineTo(p[0],p[1]-12);g.moveTo(p[0],p[1]+12);g.lineTo(p[0],p[1]+34);g.stroke();}}
  else if(q.src){const p=proj2(TV.copy(q.src));if(p){const k=.5+.5*Math.sin(G.t*20),x=clamp(p[0],30,innerWidth-30),y=clamp(p[1]-34,90,innerHeight-200);g.fillStyle='rgba(255,'+(60+120*k|0)+',40,.95)';g.strokeStyle='#000';g.lineWidth=3;g.beginPath();g.moveTo(x,y-20);g.lineTo(x+20,y+15);g.lineTo(x-20,y+15);g.closePath();g.stroke();g.fill();g.fillStyle='#000';g.font='900 22px -apple-system,system-ui,sans-serif';g.fillText('!',x,y+11);if(q.nm){g.font='900 15px -apple-system,system-ui,sans-serif';g.lineWidth=4;g.strokeStyle='#000';g.strokeText(q.nm,x,y+36);g.fillStyle='#ffd65a';g.fillText(q.nm,x,y+36);}}
   if(q.nm){const W=innerWidth,H=innerHeight,gr=g.createRadialGradient(W/2,H/2,H*.3,W/2,H/2,H*.75);gr.addColorStop(0,'rgba(0,0,0,0)');gr.addColorStop(1,'rgba(60,0,0,.5)');g.fillStyle=gr;g.fillRect(0,0,W,H);
    const cx=W/2,cy=H*.27,dv={L:[-1,0],R:[1,0],U:[0,-1],D:[0,1]}[q.dir],ph=(G.t*2.2)%1;g.lineCap='round';g.lineJoin='round';for(let i=0;i<3;i++){const o=(i+ph)*26-26,a=1-Math.abs(i+ph-1.5)/1.6,px=cx+dv[0]*o,py=cy+dv[1]*o;g.strokeStyle='rgba(255,214,90,'+Math.max(0,a)+')';g.lineWidth=9;g.beginPath();g.moveTo(px-dv[1]*24-dv[0]*14,py-dv[0]*24-dv[1]*14);g.lineTo(px+dv[0]*10,py+dv[1]*10);g.lineTo(px+dv[1]*24-dv[0]*14,py+dv[0]*24-dv[1]*14);g.stroke();}
    g.font='900 30px -apple-system,system-ui,sans-serif';g.lineWidth=5;g.strokeStyle='#000';const tx={L:'SCHIVA A SINISTRA',R:'SCHIVA A DESTRA',U:'SALTA!',D:'ABBASSATI!'}[q.dir];g.strokeText(tx,cx,cy+78);g.fillStyle='#fff';g.fillText(tx,cx,cy+78);g.font='800 15px -apple-system,system-ui,sans-serif';g.strokeText(q.nm+' IN ARRIVO',cx,cy-52);g.fillStyle='#ff6a5a';g.fillText(q.nm+' IN ARRIVO',cx,cy-52);}}}
 else if(G.qres&&G.qres.t>0){G.qres.t-=.016;g.font='bold 26px -apple-system,system-ui,sans-serif';g.fillStyle=G.qres.good?'#5fe08f':'#ff5a5a';g.fillText(G.qres.good?'OK!':'MANCATO',innerWidth/2,innerHeight*.5);}
 if(G.mv)return;
 const ring=(s,r,col,k,fill)=>{g.lineWidth=3;g.strokeStyle=col+'55';g.beginPath();g.arc(s[0],s[1],r,0,7);g.stroke();g.strokeStyle=col;g.beginPath();g.arc(s[0],s[1],r,-1.57,-1.57+6.283*k);g.stroke();if(fill){g.fillStyle=col+'66';g.beginPath();g.arc(s[0],s[1],r,0,7);g.fill();}};
 for(const e of G.en){if(e.dead)continue;const s=proj2(ePos(e,TV,true));if(!s)continue;const r=clamp(260/Math.max(2,-e.root.position.z),13,34);
  if(e.state==='aim'||e.state==='wind'||e.state==='tele')ring(s,r,'#ff3030',1-e.tele/e.teleT);else if(e.state==='watch')ring(s,r,e.rc>=0?'#ff3030':'#ffa020',e.rc>=0?1-e.rc/e.rcT:1,e.rc>=0);else if(e.state==='fire')ring(s,r,'#ff3030',1,Math.sin(G.t*40)>0);else if(e.T.m==='drone')ring(s,r*.8,'#ffa020',1);}
 for(const p of G.eproj){const s=proj2(p.m.position);if(s)ring(s,16+Math.sin(G.t*18)*3,'#ffa020',1,true);}
 g.font='bold 14px -apple-system,system-ui,sans-serif';g.textAlign='center';
 for(let i=G.dn.length-1;i>=0;i--){const d=G.dn[i];d.life-=.016;if(d.life<=0){G.dn.splice(i,1);continue;}const s=proj2(d.p);if(!s)continue;g.globalAlpha=Math.min(1,d.life*2.5);g.fillStyle='#000';g.fillText(d.txt,s[0]+1,s[1]-(1-d.life)*40+1);g.fillStyle=d.c;g.fillText(d.txt,s[0],s[1]-(1-d.life)*40);}
 g.globalAlpha=1;
 if(G.lean>.5&&(aim.down||G.cdw>-.4)){const x=aim.cx,y=aim.cy;g.lineWidth=2;g.strokeStyle=G.hitM>0?(G.hitHead?'#ffd65a':'#ff4040'):'rgba(255,255,255,.85)';g.beginPath();g.arc(x,y,G.hitM>0?15:20,0,7);g.stroke();g.fillStyle=g.strokeStyle;g.fillRect(x-1.5,y-1.5,3,3);
  if(!(G.ammo[cw().id]>0)){g.fillStyle='#ffb040';g.fillText('Rilascia per ricaricare',x,y-34);}}
 if(G.boss){const w=innerWidth*.7,x=(innerWidth-w)/2,y=innerHeight*.2;g.fillStyle='rgba(0,0,0,.6)';g.fillRect(x-2,y-2,w+4,10);g.fillStyle='#ff3ac8';g.fillRect(x,y,w*Math.max(0,G.boss.hp/G.boss.mhp),6);g.fillStyle='#fff';g.fillText(chOf(G.L).boss.toUpperCase(),innerWidth/2,y-8);}
 if(G.slow>0){g.fillStyle='rgba(80,170,255,'+(.12*Math.min(1,G.slow))+')';g.fillRect(0,0,innerWidth,innerHeight);}}

/* ===== flow ===== */
function startLevel(L){ainit();resize();MENU=null;WG.visible=true;$('sub').classList.remove('on');pfReset(L);for(const k in HU)delete HU[k];buildLevel(L);warm();state='play';ui.style.display='none';hud.style.display='block';$('toast').innerHTML='';$('adv').style.display='none';$('fade').style.opacity=0;aim.down=false;aim.hold=0;cov.down=false;$('covz').classList.remove('on');ndc.set(0,0);dots();last=performance.now();MU.track=null;musicStart('level');
 toast('<b>'+lvTxt(L)+'</b>'+(L===1?'<br>Tieni premuto: esci dal riparo e spari · rilascia: ti ripari e ricarichi':L%5===0?'<br><span style="color:#ff3ac8">Mira al nucleo luminoso</span>':''),L===1?5500:3200);}
function pause(){if(state!=='play')return;state='pause';if(AC)MUS.gain.setTargetAtTime(0,AC.currentTime,.05);ui.className='ov';ui.style.display='flex';
 ui.innerHTML=`<div class="pan"><h2>PAUSA</h2><button class="b p big" data-a="resume">RIPRENDI</button><button class="b big" data-a="diag">Diagnostica prestazioni</button><button class="b big" data-a="tsnd">Audio: ${S.snd?'ON':'OFF'}</button><button class="b big" data-a="tmus">Musica: ${S.mus===0?'OFF':'ON'}</button><button class="b big" data-a="tgfx">Grafica: ${S.gfx===0?'LEGGERA':'ALTA'}</button>
 <button class="b d big" data-a="quit">TORNA ALLA BASE</button><p class="tip">Uscendo conservi i crediti e le armi trovate finora.</p></div>`;}
function endLevel(won){state='end';qsHide();G.qte=null;cineOff();$('sub').classList.remove('on');const L=G.L,fin=won&&L>=NLV,bossW=won&&L%5===0;let b=0,rows='';musicStop();snd(won?'win':'lose');$('fade').style.opacity=0;
 if(won){b=40+10*L;rows+=`<p>Livello completato: +${b} ◈</p>`;if(G.hp>=G.mhp*.75){b+=20*L;rows+=`<p>Quasi illeso: +${20*L} ◈</p>`;}if(G.snum&&G.sfound>=G.snum){b+=30*L;rows+=`<p>Tutti i segreti trovati: +${30*L} ◈</p>`;}S.maxL=Math.min(NLV,Math.max(S.maxL,L+1));if(fin)S.done=1;}
 const tot=won?G.earn+b:Math.floor(G.earn/2);S.cr+=tot;save();hud.style.display='none';ui.className='ov';ui.style.display='flex';
 ui.innerHTML=`<div class="pan"><h2 style="color:${won?'#5fe08f':'#ff5a5a'}">${fin?'MISSIONE COMPIUTA':won?'LIVELLO '+L+' SUPERATO':'SEI CADUTO'}</h2>${bossW?`<p style="text-align:left;line-height:1.5;color:#e8ecf2;font-size:14px;margin-bottom:10px">${chOf(L).out}</p>`:''}<p>Nemici: ${G.kills}/${G.total} · Segreti: ${G.sfound}/${G.snum}</p><p>Crediti raccolti: ${G.earn} ◈${won?'':' (ne conservi la metà)'}</p>${rows}
 <p style="font-size:20px;color:#ffd65a;font-weight:800;margin:10px 0">+${tot} ◈</p>${fin?'':won?`<button class="b g big" data-a="next">LIVELLO ${L+1} ▶</button>`:`<button class="b g big" data-a="retry">RIPROVA</button>`}<button class="b p big" data-a="hub">BASE · ARSENALE</button><button class="b" data-a="diag" style="margin-top:8px;opacity:.75">Diagnostica prestazioni</button></div>`;}
