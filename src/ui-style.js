// Stili dei menu (HTML sopra la scena 3D). Inseriti una sola volta in <head> da UI.
// Tutte le regole sono sotto #ui, dopo quelle del template: prevalgono a parità di peso.
// Colori squadra: --k1 / --k2 (impostati da UI.show quando c'è una carriera).
export const UI_CSS = `
#ui{--bg0:#050912;--bg1:#0b1426;--panel:#111c31;--panel2:#18263f;--line:#ffffff14;--line2:#ffffff26;--txt:#eef3fb;--dim:#93a4c3;--gold:#ffd93d;--gold2:#c9a410;--good:#4aeb9f;--bad:#ff7079;--k1:#1746a2;--k2:#ffffff;--r:18px;
  background:radial-gradient(120% 60% at 50% -5%,#0b1426 0%,#0a1224 48%,var(--bg0) 100%);background:radial-gradient(120% 60% at 50% -5%,color-mix(in srgb,var(--k1) 38%,#0b1426) 0%,#0a1224 48%,var(--bg0) 100%);color:var(--txt);font-variant-numeric:tabular-nums}
#ui.clear{background:radial-gradient(120% 60% at 50% -5%,#0b1426 0%,#0a1224 50%,var(--bg0) 100%);background:radial-gradient(120% 60% at 50% -5%,color-mix(in srgb,var(--k1) 32%,#0b1426) 0%,#0a1224 50%,var(--bg0) 100%)}
#ui .scr{padding:0 16px calc(env(safe-area-inset-bottom) + 32px);max-width:520px}
#ui .scr::before{content:"";display:block;height:calc(env(safe-area-inset-top) + 14px)}
#ui .scr.in>*{animation:uiUp .38s cubic-bezier(.2,.8,.25,1) both}
#ui .scr.in>*:nth-child(2){animation-delay:.04s}#ui .scr.in>*:nth-child(3){animation-delay:.08s}#ui .scr.in>*:nth-child(4){animation-delay:.12s}#ui .scr.in>*:nth-child(5){animation-delay:.16s}#ui .scr.in>*:nth-child(n+6){animation-delay:.2s}
@keyframes uiUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}
@keyframes uiPulse{0%,100%{box-shadow:0 5px 0 var(--gold2),0 10px 28px #ffd93d40}50%{box-shadow:0 5px 0 var(--gold2),0 10px 38px #ffd93d80}}
@media (prefers-reduced-motion:reduce){#ui .scr.in>*,#ui .btn.big.play{animation:none!important}}
#ui h1{font-size:26px;font-weight:850;letter-spacing:-.01em}
#ui h2{font-size:21px;font-weight:800;letter-spacing:-.005em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#ui h3{display:flex;align-items:center;gap:10px;font-size:12px;letter-spacing:.12em;color:var(--dim);margin:24px 2px 10px}
#ui h3::after{content:"";flex:1;height:1px;background:var(--line)}
#ui h3 em{font-style:normal;color:#6b7da0;letter-spacing:.04em;text-transform:none;font-weight:700}
#ui .dim{color:var(--dim)}
#ui .note{color:#a3b4d2;font-size:13.5px;line-height:1.45;margin:10px 2px}

/* pulsanti */
#ui .btn{min-height:52px;border-radius:16px;background:var(--panel2);border:1px solid var(--line2);font-size:16px;font-weight:750;letter-spacing:.01em;display:flex;align-items:center;justify-content:center;gap:10px;transition:transform .12s,filter .12s,background .2s}
#ui .btn.big{min-height:60px;font-size:18px;letter-spacing:.03em;text-transform:uppercase;background:linear-gradient(#ffe45e,var(--gold));color:#15130a;border:0;box-shadow:0 5px 0 var(--gold2),0 10px 26px #ffd93d30}
#ui .btn.big:active{transform:translateY(4px);box-shadow:0 1px 0 var(--gold2),0 4px 14px #ffd93d30;filter:none}
#ui .btn.big.play{animation:uiPulse 2.4s ease-in-out infinite}
#ui .btn.big svg{width:22px;height:22px;flex:none}
#ui .btn.ghost{background:#ffffff08;border:1px solid var(--line2);color:#cbd7ee}
#ui .btn.sm{min-height:46px;font-size:15px;border-radius:14px}
#ui .btn.warn{background:#ff4d58;color:#fff;border-color:#ff4d58}
#ui .btn:active,#ui .tile:active,#ui .chip:active,#ui .prow:active,#ui .kit:active{transform:scale(.975);filter:brightness(1.15)}
#ui .btn.opp{justify-content:space-between;padding:0 18px;text-align:left}
#ui .btn.opp small{font-size:13px;color:var(--dim);font-weight:650}
#ui .btn.opp .lv{display:flex;gap:4px}#ui .btn.opp .lv i{width:9px;height:9px;border-radius:50%;background:#ffffff26}#ui .btn.opp .lv i.on{background:var(--gold)}

/* carte */
#ui .card{background:linear-gradient(180deg,#14213a,#101a2f);border:1px solid var(--line);border-radius:var(--r);padding:16px;margin:12px 0;box-shadow:0 8px 24px #0006}
#ui .card label{font-size:12px;letter-spacing:.1em;color:var(--dim);margin:4px 0 10px;display:flex;align-items:center;justify-content:space-between}
#ui .card label b{color:var(--txt);letter-spacing:.02em;text-transform:none;font-size:13px}
#ui input{height:54px;border-radius:14px;background:#08101f;border:1.5px solid var(--line2);font-size:18px;font-weight:650;transition:border-color .2s,box-shadow .2s}
#ui input:focus{outline:0;border-color:var(--gold);box-shadow:0 0 0 4px #ffd93d22}

/* titolo */
#ui .hero{position:relative;padding:15vh 0 5vh;text-align:center}
#ui .hero.small{padding:3vh 0 1vh}
#ui .hero .pitch{position:absolute;left:50%;top:-4vh;width:130%;max-width:640px;transform:translateX(-50%);opacity:.5;pointer-events:none}
#ui .hero>*:not(.pitch){position:relative}
#ui .ballmark{width:64px;height:64px;margin:0 auto 14px;display:block;filter:drop-shadow(0 6px 14px #0008)}
#ui .hero.small .pitch{opacity:.25}#ui .hero.small .ballmark{width:46px;height:46px;margin-bottom:8px}
#ui .logo{font-size:52px;font-weight:900;letter-spacing:-.025em;line-height:.95;font-style:italic;text-shadow:0 4px 0 #0006,0 10px 30px #0008}
#ui .hero.small .logo{font-size:40px}
#ui .logo span{color:var(--gold);margin:0 5px}
#ui .sub{color:#c3d0e8;font-size:16px;margin-top:16px;letter-spacing:.01em}
#ui .claim{display:flex;justify-content:center;gap:8px;margin-top:22px;flex-wrap:wrap}
#ui .claim i{font-style:normal;font-size:12px;font-weight:750;letter-spacing:.06em;color:#bcd0f0;border:1px solid var(--line2);background:#ffffff0c;border-radius:999px;padding:6px 12px}
#ui .kits{grid-template-columns:repeat(5,1fr);gap:8px}
#ui .kit{position:relative;aspect-ratio:1;min-height:44px;border-radius:14px;border:2px solid transparent;background:#0a1424;display:flex;align-items:center;justify-content:center;transition:transform .15s,border-color .15s,background .15s;padding:0}
#ui .kit svg{width:78%;height:78%;filter:drop-shadow(0 2px 3px #0008)}
#ui .kit.on{border-color:var(--gold);background:#1b2a47;transform:scale(1.05);box-shadow:0 0 0 3px #ffd93d22}
#ui .newhead{display:flex;align-items:center;gap:14px;margin-bottom:8px}
#ui .newhead .crest{width:52px;height:62px}

/* barra squadra + stemma */
#ui .crest{display:block;width:46px;height:54px;border:0;border-radius:0;background:none;flex:none;filter:drop-shadow(0 4px 8px #0008)}
#ui .crest.lg{width:60px;height:72px}
#ui .clubbar{display:flex;align-items:center;gap:12px;margin:0 0 14px}
#ui .clubbar h1{font-size:23px;line-height:1.1}
#ui .clubbar .dim{margin-top:3px;font-size:13px}
#ui .money{background:linear-gradient(#123324,#0d2418);color:var(--good);border:1px solid #46eb9f40;border-radius:999px;padding:0 13px;min-height:34px;display:inline-flex;align-items:center;font-weight:800;font-size:14px;letter-spacing:.01em;white-space:nowrap}
#ui .pill{display:inline-flex;align-items:center;min-height:26px;padding:0 10px;border-radius:999px;font-size:11.5px;font-weight:800;letter-spacing:.07em;text-transform:uppercase;background:#ffffff12;color:#c9d6ee}
#ui .pill.gold{background:#ffd93d20;color:var(--gold)}

/* hub: prossima partita */
#ui .card.next{position:relative;overflow:hidden;padding:16px 16px 18px;background:linear-gradient(160deg,#14213a 0%,#101a2f 62%);background:linear-gradient(160deg,color-mix(in srgb,var(--k1) 34%,#14213a) 0%,#101a2f 62%);border-color:#ffffff1f}
#ui .card.next::after{content:"";position:absolute;right:-40px;top:-40px;width:160px;height:160px;border-radius:50%;background:radial-gradient(#ffffff14,transparent 70%);pointer-events:none}
#ui .nx-top{display:flex;align-items:center;justify-content:space-between;gap:8px}
#ui .nx-top .lbl{font-size:12px;letter-spacing:.12em;text-transform:uppercase;font-weight:800;color:#b7c7e3}
#ui .vs{display:flex;align-items:flex-start;gap:6px;margin:16px 0 18px}
#ui .vs>div{flex:1;min-width:0;display:flex;flex-direction:column;align-items:center;text-align:center;gap:6px}
#ui .vs>div:last-child{text-align:center}
#ui .vs b{font-size:14.5px;line-height:1.2;white-space:normal;max-width:100%;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
#ui .vs span{font-size:12px;color:var(--dim);font-weight:650}
#ui .vs span em{font-style:normal;color:var(--txt);font-weight:850;font-size:13px}
#ui .vs i{flex:none;align-self:center;font-style:normal;font-weight:900;font-size:13px;letter-spacing:.12em;color:#fff;background:#ffffff14;border:1px solid var(--line2);border-radius:999px;width:42px;height:42px;display:flex;align-items:center;justify-content:center;margin-top:-18px}
#ui .prog{height:5px;border-radius:3px;background:#ffffff14;margin:0 0 14px;overflow:hidden}#ui .prog i{display:block;height:100%;background:linear-gradient(90deg,var(--gold),#ffb347);border-radius:3px}
#ui .last{display:flex;align-items:center;gap:10px;margin:12px 2px 0;font-size:13px;color:#a9bad6}
#ui .last .wl{flex:none;width:26px;height:26px;border-radius:8px;display:inline-flex;align-items:center;justify-content:center;font-weight:900;font-size:12px;color:#06120c}
#ui .wl.w{background:var(--good)}#ui .wl.d{background:#f1c75a}#ui .wl.l{background:var(--bad)}
#ui .grid{gap:10px;margin-top:16px}
#ui .tile{position:relative;background:linear-gradient(180deg,#15233c,#111c31);border:1px solid var(--line);border-radius:var(--r);padding:14px 12px 14px 14px;min-height:88px;display:flex;flex-direction:column;justify-content:flex-end;overflow:hidden;transition:transform .12s,filter .12s}
#ui .tile .ic{position:absolute;right:10px;top:10px;width:34px;height:34px;border-radius:11px;display:flex;align-items:center;justify-content:center;background:#1c2b49;background:color-mix(in srgb,var(--k1) 38%,#1c2b49);border:1px solid #ffffff1c}
#ui .tile .ic svg{width:20px;height:20px;stroke:#fff;fill:none;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}
#ui .tile b{font-size:16px;margin:12px 0 3px;letter-spacing:-.005em}
#ui .tile span{font-size:12.5px;color:var(--dim);line-height:1.25}

/* barra alta */
#ui .top{position:sticky;top:0;z-index:5;display:flex;align-items:center;gap:12px;margin:calc(-1*(env(safe-area-inset-top) + 14px)) -16px 8px;padding:calc(env(safe-area-inset-top) + 10px) 16px 10px;background:#0a1224e8;-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px);border-bottom:1px solid var(--line)}
#ui .top::after{content:"";position:absolute;left:0;right:0;bottom:-1px;height:2px;background:linear-gradient(90deg,var(--k1),var(--k2) 60%,transparent)}
#ui .back{width:46px;height:46px;border-radius:14px;border:1px solid var(--line2);background:var(--panel2);color:#fff;font-size:28px;line-height:1;padding:0 0 4px;flex:none;display:flex;align-items:center;justify-content:center}
#ui .back:active{transform:scale(.94)}
#ui .flash{background:linear-gradient(#ffe45e,var(--gold));color:#15130a;border-radius:14px;padding:12px 14px;font-weight:800;margin:10px 0;animation:uiUp .25s both}

/* chip */
#ui .chips{display:flex;flex-wrap:wrap;gap:8px;margin:10px 0}
#ui .chip{min-height:44px;padding:0 16px;border-radius:999px;background:var(--panel);border:1px solid var(--line2);color:#d6e1f4;font-size:14.5px;font-weight:750;letter-spacing:.01em;transition:background .15s,color .15s,transform .12s}
#ui .chip.on{background:var(--gold);color:#15130a;border-color:var(--gold);box-shadow:0 4px 14px #ffd93d30}

/* righe giocatore */
#ui .prow{gap:10px;background:linear-gradient(180deg,#15233c,#111c31);border:1px solid var(--line);border-radius:14px;padding:6px 10px 6px 8px;margin:7px 0;min-height:56px;transition:transform .12s,background .2s,border-color .2s}
#ui .prow.sel{border-color:var(--gold);background:linear-gradient(180deg,#223458,#18263f);box-shadow:0 0 0 3px #ffd93d1c}
#ui .pos{width:42px;height:34px;display:inline-flex;align-items:center;justify-content:center;border-radius:10px;padding:0;font-size:11.5px;letter-spacing:.04em;color:#fff;text-shadow:0 1px 1px #0005}
#ui .pP{background:linear-gradient(#d68a14,#a8680a)}#ui .pD{background:linear-gradient(#2d86d2,#1d5d98)}#ui .pC{background:linear-gradient(#25a362,#17703f)}#ui .pA{background:linear-gradient(#d4414a,#9a2a31)}
#ui .pn{font-size:15.5px;font-weight:700}
#ui .pn em{color:#ffbf70}
#ui .age{font-size:12.5px;color:var(--dim);font-weight:650}
#ui .ovr{width:42px;height:34px;display:inline-flex;align-items:center;justify-content:center;border-radius:10px;font-size:17px;font-weight:900;background:#ffffff0d;text-align:center}
#ui .ovr.o1{background:#b7c2d61c;color:#c4cddd}#ui .ovr.o2{background:#8fd3ff1f;color:#8fd3ff}#ui .ovr.o3{background:#4aeb9f20;color:var(--good)}#ui .ovr.o4{background:linear-gradient(#ffe45e,#ffc01f);color:#1a1405}
#ui .ovr.bad{background:#ff70792a;color:var(--bad)}
#ui .price{width:auto;min-width:62px;font-size:13.5px;font-weight:850;color:var(--good);text-align:right}#ui .price.no{color:#ff9aa0}
#ui .cal{flex:none;width:38px;height:34px;display:inline-flex;align-items:center;justify-content:center;font-weight:850;color:var(--dim);font-size:14px}

/* scheda giocatore */
#ui .pcard{background:linear-gradient(180deg,#16253f,#0f192c);border:1px solid #ffd93d66;border-radius:16px;padding:14px;margin:4px 0 12px;animation:uiUp .25s both;box-shadow:0 10px 28px #0007}
#ui .pc1 b{font-size:18px;letter-spacing:-.005em}#ui .pc1 span{font-size:12.5px;line-height:1.4;margin-top:4px}
#ui .stats{grid-template-columns:repeat(4,1fr);gap:8px 8px;margin-top:12px;text-align:left}
#ui .stats>div{background:#ffffff08;border-radius:10px;padding:8px 10px 9px;position:relative}
#ui .stats i{display:flex;justify-content:space-between;align-items:baseline;font-size:10.5px;letter-spacing:.1em;font-weight:800}
#ui .stats b{font-size:18px;position:absolute;right:10px;top:5px}
#ui .stats u{display:block;height:5px;border-radius:3px;background:#ffffff14;margin-top:11px;overflow:hidden;text-decoration:none}
#ui .stats u::after{content:"";display:block;height:100%;width:var(--w);border-radius:3px;background:currentColor}
#ui .stats .o1{color:#b7c2d6}#ui .stats .o2{color:#8fd3ff}#ui .stats .o3{color:var(--good)}#ui .stats .o4{color:var(--gold)}
#ui .stats>div.o1 i,#ui .stats>div.o2 i,#ui .stats>div.o3 i,#ui .stats>div.o4 i{color:var(--dim)}
#ui .stats>div b{color:var(--txt)}

/* classifica */
#ui .tbl{border-collapse:separate;border-spacing:0 5px;font-size:13.5px}
#ui .tbl th{font-size:10.5px;letter-spacing:.1em;color:var(--dim);padding:4px 3px;font-weight:800}
#ui .tbl td{border:0;padding:0 4px;height:46px;background:#111c31;font-weight:600}
#ui .tbl td:first-child{border-radius:12px 0 0 12px;width:34px;color:var(--dim);font-weight:800}
#ui .tbl td:last-child{border-radius:0 12px 12px 0;color:var(--txt);width:40px}
#ui .tbl td.l{max-width:none;width:100%;font-size:14px}
#ui .tbl td.l span{display:flex;align-items:center;gap:8px;min-width:0}
#ui .tbl td.l span>b{flex:none;width:14px;height:14px;border-radius:5px;border:1px solid #ffffff55}
#ui .tbl td.l span>em{font-style:normal;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:132px}
#ui .tbl tr.me td{background:#302d12;color:var(--gold);font-weight:850}
#ui .tbl tr.me td:first-child{color:var(--gold)}
#ui .tbl tr.up td:first-child{box-shadow:inset 4px 0 0 var(--good)}#ui .tbl tr.dn td:first-child{box-shadow:inset 4px 0 0 var(--bad)}
#ui .legend{display:flex;gap:14px;flex-wrap:wrap;font-size:12.5px;color:var(--dim);margin:8px 2px}#ui .legend i{display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:6px;vertical-align:-1px}

/* come si gioca / stagione */
#ui .how{padding-top:5vh}
#ui .how .ill{width:112px;height:112px;border-radius:30px;background:linear-gradient(160deg,#1b2b49,#101a2f);background:linear-gradient(160deg,color-mix(in srgb,var(--k1) 40%,#1b2b49),#101a2f);border:1px solid var(--line2);display:flex;align-items:center;justify-content:center;margin:2vh 0 18px;box-shadow:0 12px 30px #0007}
#ui .how .ill svg{width:72px;height:72px;stroke:#fff;fill:none;stroke-width:2.4;stroke-linecap:round;stroke-linejoin:round}
#ui .how h1{font-size:32px;margin:6px 0 12px;letter-spacing:-.015em}
#ui .how p{font-size:17.5px;line-height:1.55;color:#d7e1f3}
#ui .how b{color:var(--gold)}
#ui .dots{display:flex;gap:7px;align-items:center}#ui .dots i{height:6px;width:6px;border-radius:3px;background:#ffffff2e;transition:width .25s}#ui .dots i.on{width:26px;background:var(--gold)}
#ui .dots+.dim{margin-left:auto}
#ui .stepbar{display:flex;align-items:center;justify-content:space-between}
#ui .how .btn{margin-top:14px}
#ui .how .trophy{width:96px;height:96px;margin:0 auto 6px;display:block;filter:drop-shadow(0 8px 20px #ffd93d40)}
#ui .how.season{text-align:center;padding-top:9vh}
#ui .how.season p{font-size:16.5px}

/* risultato */
#ui .res{text-align:center;padding-top:2vh}
#ui .res .dim{font-size:12px;letter-spacing:.1em;text-transform:uppercase;font-weight:750}
#ui .scoreboard{position:relative;margin:12px 0 4px;border-radius:22px;padding:18px 12px 16px;background:linear-gradient(160deg,#16253f,#0f192c 70%);background:linear-gradient(160deg,color-mix(in srgb,var(--k1) 38%,#16253f),#0f192c 70%);border:1px solid var(--line2);box-shadow:0 12px 32px #0007}
#ui .score{gap:6px;margin:8px 0 10px}
#ui .score b{font-size:56px;letter-spacing:.02em;text-shadow:0 4px 0 #0006;min-width:0;flex:none}
#ui .score span{flex:1;font-size:20px;font-weight:850;letter-spacing:.05em}
#ui .verdict{display:inline-flex;align-items:center;min-height:28px;padding:0 14px;border-radius:999px;font-size:12px;font-weight:900;letter-spacing:.12em}
#ui .verdict.w{background:#4aeb9f26;color:var(--good)}#ui .verdict.d{background:#f1c75a26;color:#f1c75a}#ui .verdict.l{background:#ff707926;color:var(--bad)}
#ui .scorers{font-size:13px;color:#c9d6ee;margin:12px 0 0;display:grid;gap:5px}
#ui .st{display:grid;grid-template-columns:56px 1fr 56px;align-items:center;gap:10px;border-top:0;padding:9px 2px;font-size:14px}
#ui .st span{text-align:center;color:#b3c3de;font-weight:650;font-size:13px}
#ui .st b{font-size:16px;text-align:left}#ui .st b:last-child{text-align:right}
#ui .st .bar{grid-column:1/-1;display:flex;height:5px;border-radius:3px;overflow:hidden;gap:3px;margin-top:-4px}
#ui .st .bar i{display:block;background:#ffffff1f;height:100%}#ui .st .bar i:first-child{background:var(--gold)}#ui .st .bar i:last-child{background:#6f86b0}#ui .st .bar i{flex:var(--f) 1 0}
#ui .res .st{display:grid}
#ui .res .st b{width:auto}
#ui .card .st{display:flex;border-top:1px solid var(--line)}#ui .card .st:first-child{border-top:0}
#ui .card .st b{font-size:16px}
#ui .card .st span{text-align:left}
#ui .good{color:var(--good)}#ui .bad{color:var(--bad)}

/* stemmi piccoli */
#ui .crest.xs{width:22px;height:26px;filter:drop-shadow(0 2px 3px #0007)}
#ui .crest.sm{width:30px;height:36px;display:inline-block;vertical-align:middle;margin:0 6px 0 0}
#ui .pn.cr{display:flex;align-items:center;gap:8px}
#ui .pbtns{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:12px}
#ui .pbtns .btn{min-height:48px}
#ui .pbtns .btn .crest.xs{margin-right:2px}

/* editor: stemma, campione, aspetto, divisa */
#ui .edtop .pill{margin-left:auto}
#ui .edstage{position:sticky;top:calc(env(safe-area-inset-top) + 56px);z-index:4;height:min(38vh,320px);margin:0 -16px;background:radial-gradient(70% 80% at 50% 38%,#1d2c4b 0%,#0c1528 72%);background:radial-gradient(70% 80% at 50% 38%,color-mix(in srgb,var(--k1) 45%,#1d2c4b) 0%,#0c1528 72%);border-bottom:1px solid var(--line);overflow:hidden}
#ui .edstage canvas{display:block;width:100%;height:100%;border:0;touch-action:none}
#ui .edstage.cst{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;height:min(34vh,290px)}
#ui .edstage .crest.big{width:auto;height:72%;filter:drop-shadow(0 10px 22px #000a)}
#ui .edstage.cst b{font-size:18px;font-weight:850;letter-spacing:.02em}
#ui .edwait{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:var(--dim);font-weight:700;pointer-events:none}
#ui .edname{position:absolute;left:12px;bottom:10px;background:#0a1224c0;border:1px solid var(--line2);border-radius:999px;padding:5px 12px;font-size:13px;font-weight:800;letter-spacing:.03em;pointer-events:none}
#ui .edtabs{position:sticky;top:calc(env(safe-area-inset-top) + 56px + min(38vh,320px));z-index:3;display:grid;grid-auto-flow:column;grid-auto-columns:1fr;gap:6px;margin:0 -16px;padding:8px 16px;background:#0a1224;border-bottom:1px solid var(--line)}
#ui .edtab{min-height:46px;border-radius:12px;background:var(--panel);border:1px solid var(--line2);color:#cbd7ee;font-size:14px;font-weight:800;padding:0 4px}
#ui .edtab.on{background:var(--gold);color:#15130a;border-color:var(--gold)}
#ui #edpanel h3{margin:18px 2px 8px}
#ui .edchips{display:flex;flex-wrap:wrap;gap:8px}
#ui .edchips .chip{flex:1 0 auto;min-width:30%}
#ui .edsw{display:flex;flex-wrap:wrap;gap:10px}
#ui .sw{width:46px;height:46px;border-radius:50%;background:var(--c);border:3px solid #ffffff22;box-shadow:inset 0 -6px 10px #0003;padding:0;transition:transform .12s}
#ui .sw.on{border-color:var(--gold);transform:scale(1.08);box-shadow:0 0 0 3px #ffd93d33,inset 0 -6px 10px #0003}
#ui .edgrid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}
#ui .edgrid.g5{grid-template-columns:repeat(4,1fr)}
#ui .edopt{display:flex;flex-direction:column;align-items:center;gap:4px;min-height:92px;padding:8px 4px 6px;border-radius:14px;background:var(--panel);border:2px solid var(--line2)}
#ui .edopt .crest{width:42px;height:50px}
#ui .edopt span{font-size:11px;font-weight:750;color:#c4d1e8;line-height:1.15;text-align:center}
#ui .edopt.on{border-color:var(--gold);background:#1b2a47;box-shadow:0 0 0 3px #ffd93d22}
#ui .ednum{display:grid;grid-template-columns:64px 1fr 64px;gap:10px;align-items:center;margin-bottom:10px}
#ui .ednum b{text-align:center;font-size:40px;font-weight:900}
#ui .ednum .btn{font-size:28px}
#ui .edbar{position:sticky;bottom:calc(-1*(env(safe-area-inset-bottom) + 28px));z-index:5;display:grid;grid-template-columns:1fr 1.8fr;gap:10px;margin:18px -16px calc(-1*(env(safe-area-inset-bottom) + 28px));padding:12px 16px calc(env(safe-area-inset-bottom) + 14px);background:linear-gradient(#0a122400,#0a1224f2 30%)}
#ui .edbar .btn{min-height:56px}
#ui .edbar .btn.big{font-size:16px}
`;
