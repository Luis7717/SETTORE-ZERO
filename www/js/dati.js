// Settore Zero — trama, livelli fissi, armi, rarità, potenziamenti, salvataggio, icone
'use strict';
const $=id=>document.getElementById(id),rnd=n=>Math.random()*n|0;
const cv=$('c'),ui=$('ui'),hud=$('hud'),ov=$('ov'),og=ov.getContext('2d');

let ODPR=1;const PF={m:[],w:[],n:0,sum:0,slow:0,hit:0,max:0,up:0,rn:0,t0:0,L:0};
function pfReset(L){PF.w=[];PF.n=PF.sum=PF.slow=PF.hit=PF.max=PF.up=PF.rn=0;PF.L=L;PF.m.length=0;}

/* ===== campagna ===== */
const NLV=45;
const PREMESSA='Anno 2191. La stazione orbitale Aurora-9 custodisce il Nucleo Zero, un reattore sperimentale. In una sola notte la Legione Cenere del colonnello Kross l\'ha presa; la maggiore Varr, il suo braccio destro, ne guida le squadre. Tu sei Vega, l\'unico agente dell\'Unità Zero rimasto a bordo.';
const CH=[
 {n:'Attracco',th:0,boss:'Ariete',intro:'Sei entrato dall\'hangar merci: nessuno sa che sei a bordo. Per ora.',
  lv:['Ripulisci la banchina di attracco.','Raggiungi il deposito container.','Disattiva le sentinelle del corridoio merci.','Apriti la strada verso l\'ascensore centrale.','Un Colosso sorveglia l\'ascensore: abbattilo.'],
  out:'Ariete è a pezzi. Dall\'ascensore intercetti una voce: Kross vuole la dottoressa Marsh viva.'},
 {n:'Laboratori',th:1,boss:'Bisturi',intro:'La dottoressa Marsh ha progettato il Nucleo Zero. Se Kross la costringe a parlare, il reattore diventa un\'arma.',
  lv:['Entra nell\'ala ricerca.','Recupera i codici dal laboratorio 3.','Segui le tracce della dottoressa.','Supera la zona di quarantena.','Il Colosso Bisturi blocca l\'archivio.'],
  out:'Marsh non è qui: l\'hanno portata in criogenia. Ma ha lasciato un messaggio: «Fermate la Fonderia».'},
 {n:'Fonderia',th:2,boss:'Maglio',intro:'La Fonderia sforna droni da guerra a ciclo continuo. Finché lavora, la Legione non finirà mai i rinforzi.',
  lv:['Scendi ai forni.','Sabota la linea di montaggio.','Taglia l\'alimentazione alle presse.','Sopravvivi al controllo qualità.','Il Colosso Maglio difende il forno madre.'],
  out:'La Fonderia è ferma. I droni rimasti si ritirano verso le serre: qualcosa li sta richiamando.'},
 {n:'Alveare',th:3,boss:'Regina',intro:'Le serre idroponiche sono diventate un nido: i droni vi si riparano e si moltiplicano. Lo chiamano l\'Alveare.',
  lv:['Attraversa la serra est.','Distruggi i nidi di ricarica.','Trova il segnale che comanda lo sciame.','Resisti all\'assalto dello sciame.','La Regina guida lo sciame: spegnila.'],
  out:'Senza la Regina lo sciame cade a terra. La strada per la criogenia è libera.'},
 {n:'Criogenia',th:4,boss:'Brina',intro:'L\'equipaggio di Aurora-9 dorme nelle capsule, ostaggio della Legione. Tra loro c\'è Marsh.',
  lv:['Entra nel settore freddo.','Riattiva le capsule dell\'equipaggio.','Difendi il risveglio.','Raggiungi la capsula di Marsh.','Il Colosso Brina la tiene sotto chiave.'],
  out:'Marsh è libera. «Kross non vuole un\'arma», dice. «Vuole far precipitare la stazione sulla Terra.»'},
 {n:'Nucleo',th:5,boss:'Fornace',intro:'Il Nucleo Zero è già in sovraccarico. Marsh può rallentarlo, ma qualcuno deve portarla fino alla sala di controllo.',
  lv:['Scorta Marsh nell\'anello del reattore.','Chiudi le valvole primarie.','Respingi la squadra d\'assalto.','Raggiungi la sala di controllo.','Il Colosso Fornace presidia il nucleo.'],
  out:'Il sovraccarico è rallentato, non fermato. I comandi veri sono nella Cittadella, e Kross lo sa.'},
 {n:'Cittadella',th:0,boss:'Guardiano',intro:'La Cittadella è il ponte di comando fortificato. Da qui Kross ha staccato la stazione dall\'orbita.',
  lv:['Forza i cancelli della Cittadella.','Spegni le torrette del perimetro.','Sali ai ponti superiori.','Isola la sala comunicazioni.','Il Guardiano non lascia passare nessuno.'],
  out:'Dal ponte vedi la Terra farsi più grande. Mancano i codici di rotta: li ha la maggiore Varr, nell\'Arsenale.'},
 {n:'Arsenale',th:1,boss:'Vendetta',intro:'Varr ti è sfuggita per sette settori. Adesso gioca in casa: l\'Arsenale è suo, e ha lei i codici di rotta.',
  lv:['Infiltrati nell\'Arsenale.','Fai saltare il deposito munizioni.','Insegui Varr tra le rastrelliere.','Tagliale la ritirata.','Varr sale sul suo Colosso, Vendetta.'],
  out:'Hai i codici. Varr, a terra, ride: «Kross è già nel Settore Zero. Arrivi tardi, agente.»'},
 {n:'Settore Zero',th:5,boss:'Titano Zero',intro:'Il Settore Zero è il cuore della stazione, dove tutto è cominciato. Kross ti aspetta lì, con l\'ultimo Colosso.',
  lv:['Scendi nel Settore Zero.','Supera la guardia scelta di Kross.','Inserisci i codici di rotta.','Tieni la posizione mentre la stazione risale.','Kross e il Titano Zero: finiscila.'],
  out:'Il Titano Zero crolla. Aurora-9 risale in orbita, l\'equipaggio è sveglio, il Nucleo è stabile. Dalla Terra arriva una sola riga: «Unità Zero, ottimo lavoro. Rientrate.»'}];
const chI=L=>Math.min(8,(Math.min(NLV,L)-1)/5|0),chOf=L=>CH[chI(L)],lvTxt=L=>chOf(L).lv[(Math.min(NLV,L)-1)%5];

const RUNTXT=['L\'hangar si sta depressurizzando: corri!','Quarantena attivata: si accendono i laser!','La colata invade il condotto: non fermarti!','Lo sciame fa crollare la serra!','Le tubature criogeniche stanno cedendo!','Il reattore scarica nel corridoio!','Le difese della Cittadella si attivano!','Il deposito munizioni sta saltando in aria!','Il Settore Zero sta collassando!'];

/* ===== campagna: livelli fissi =====
 R<tipo><posa><luce><flag> ondate | VOCE:battuta     tipo 0 sala · 1 magazzino · 2 passerella   luce 0 normale · 1 allarme · 2 buio
 flag: v Varr scappa · k Kross scappa · m Marsh ti raggiunge · B boss
 X<l laser · c insegui Varr · q insegui Kross · e fuga dall'esplosione · m fuga con Marsh · x misto> | VOCE:battuta
 nemici: t soldato · d drone · g granatiere · r assaltatore · a automa · s cecchino · b bruto · c scudiero · u torretta · B colosso */
const EL={t:'trooper',d:'drone',g:'gren',r:'runner',a:'automa',s:'sniper',b:'brute',c:'scudo',u:'turret',B:'boss'};
const CHF=['t','tc','ta','d','ts','tg','tc','tg','tcs'];
const SPK={VARR:'#ff6ad5',KROSS:'#ffb020',MARSH:'#5fe0d8',BASE:'#6cc4ff'};
const ACTORS={varr:{c:0xd8d8e4,j:0xff30c0,sc:1},kross:{c:0x16161c,j:0xffa818,sc:1.12},marsh:{c:0x2a9a9a,j:0xd8ffff,sc:.94}};
const LV=[
// 1 · ATTRACCO
['R000 tt/tt|BASE:Vega, sei dentro. Ripulisci la banchina e non farti notare.','R110 tt/ttt','R020 ttt/tt|BASE:Ultima squadra. Poi il deposito è tuo.'],
['R010 tt/ttd|BASE:Droni kamikaze. Abbattili prima che ti arrivino addosso.','R120v ttt/tdd|VARR:Un agente dell\'Unità Zero? Uccidetelo.','Xc|BASE:È la maggiore Varr, il braccio destro di Kross. Non perderla!','R100 ttd/ttt|BASE:Ti è scappata. La ritroveremo.'],
['R020 ttg/ttd','Xl|BASE:Sentinelle laser nel corridoio merci. Salta e abbassati a tempo.','R240 ttr/tgd|BASE:Assaltatori: ti corrono addosso. Fermali o schiva.','R130 tdd/ttg'],
['R110 tts/ttr|BASE:Cecchino in alto. Guarda il raggio rosso.','R220 tsd/tta','R000v ttg/tsr|VARR:Sigillate l\'ascensore. E svegliate Ariete.','Xc|VARR:Ancora tu? Sei lento, agente.'],
['R010 ttg/tsd','R150 trr/ttd','R001B Btt|VARR:Ariete, schiaccialo.','Xe|BASE:Ariete sta per esplodere e si porta via l\'hangar: corri!'],
// 2 · LABORATORI
['R000 ttc/tsd|BASE:Ala ricerca. La dottoressa Marsh lavorava qui.','Xl|BASE:Quarantena attiva: griglie laser.','R102 tta/tdd|BASE:Luci fuori uso. Usa la torcia.','R020 tcs/ttg'],
['R010 ttu/tcd|BASE:Torrette automatiche. Mira alla testa del sensore.','R200 tsa/trr','R122 tdd/tcg','R050 tcs/tad|BASE:Il laboratorio 3 è oltre quella porta.'],
['R020v tcs/ttg|VARR:Portate via la dottoressa. Lui lasciatelo a me.','Xc|BASE:Ha Marsh con sé! Stalle dietro!','R100 tau/tsd','R210 crr/ttd|BASE:L\'hanno caricata su un montacarichi. Segui le tracce.'],
['R000 ttc/tsg/tdd','Xl','R112 tta/tsd/ccg|BASE:Zona di quarantena. Non respirare troppo.','R230 tsu/trr/tag'],
['R010 tcs/tga/tdd','R202 tsd/trr/tta','R001B Bcc|VARR:Bisturi ti aprirà in due. Io ho un appuntamento in criogenia.','Xe|BASE:L\'archivio brucia e i serbatoi saltano: fuori di lì!'],
// 3 · FONDERIA
['R001 tad/taa/tdd|BASE:La Fonderia sforna droni a ciclo continuo. Scendi ai forni.','R210 tsg/tdd/tta','R120 aad/ttg/tsd','R030 tcu/tdd/tar'],
['R020 tda/tdg/tsd','R201 aat/tcd/trr','R110v tsu/tga/ddd|VARR:Fate partire la linea. Sommergetelo di ferraglia.','Xc|VARR:Qui dentro si fonde tutto. Anche tu.','R000 ada/tcg/tsd'],
['R011 tau/tdd/tsg|BASE:Taglia l\'alimentazione alle presse.','R220 tca/trr/tdd','Xe|BASE:Le presse vanno in pezzi: la colata invade il condotto!','R100 aag/tsd/tcu','R061 tdd/tar/tsg'],
['R000 tcs/tad/trg','R212 ddd/tsa/tcu','Xl|BASE:Controllo qualità: laser di taglio. Non sbagliare i tempi.','R121 aar/tsg/tdd','R010 tcb/tdd/tsa'],
['R021 tad/tsg/tcd','R200 aab/tdd/trs','R101 tcu/tga/ddd','R001B Baa|BASE:Maglio difende il forno madre. Mira al nucleo.','Xe|BASE:Il forno madre collassa: via, via, via!'],
// 4 · ALVEARE
['R002 tdd/ddd/tsd|BASE:Le serre sono diventate un nido. Li senti ronzare?','R110 tdg/tdd/dda','R220 tsd/ddd/tcr','Xl','R030 tdd/tda/ddg'],
['R010 ddt/tsg/dda','R102 ddd/tcd/tsr','R200v tdu/ddd/tag|VARR:Lo sciame ha fame, agente. Buon appetito.','Xc|BASE:Varr sta portando via il trasmettitore dello sciame!','R022 ddd/tsd/dcb'],
['R000 tsd/ddg/tca','R122 ddd/dda/tsr|BASE:I nidi di ricarica sono qui. Distruggi tutto.','Xx|BASE:Hai fatto arrabbiare l\'Alveare: scappa!','R210 tdu/ddd/tcg','R072 dds/tad/ddd'],
['R001 ddd/tdd/dda|BASE:Arrivano a ondate. Resisti.','R112 dsd/ddg/tcd','R201 ddd/tar/dds','Xe|BASE:Lo sciame fa crollare la serra!','R020 ddb/tdd/dcs'],
['R012 tdd/dsg/dda','R100 ddc/tdr/dds','R221 ddd/tag/tsd','R001B Bdd|BASE:Eccola: la Regina. Spegnila e lo sciame cade.','Xe|BASE:Senza la Regina la serra implode: corri!'],
// 5 · CRIOGENIA
['R002 tss/tcd/tsg|BASE:Settore freddo. L\'equipaggio dorme nelle capsule.','R110 tcs/tsd/trr','Xl','R220 sst/tca/tdg','R030 tcu/tss/tad'],
['R010 tsc/tgd/tsa|BASE:Riattiva le capsule, una fila alla volta.','R202 sst/tcd/trb','R120 tcu/tsg/ddd','Xx|BASE:Fuga di azoto nel condotto: muoviti!','R040 tcs/tsa/tgr'],
['R000 tsg/tcd/trr|BASE:L\'equipaggio si sta svegliando. Tienili lontani dalle capsule.','R101 tca/tss/ddg','R211 tcu/tsb/tdd','R021 sst/tcg/tar'],
['R012 tss/tcd/tga','R110v tcs/tsd/trb|VARR:La dottoressa resta con noi. Tu resti qui, per sempre.','Xc|BASE:La capsula di Marsh è in fondo. Non mollarla!','R200 tcu/ssg/tad','R020m tcs/tsb/tgd|MARSH:Agente! Sono la dottoressa Marsh. Kross non vuole un\'arma: vuole far cadere la stazione sulla Terra.'],
['R000 tsc/tga/tsd|MARSH:Brina sorveglia l\'uscita. Io resto dietro di te.','R122 sst/tcb/tdd','R001B Bss|MARSH:Il suo nucleo si scopre quando spara!','Xm|MARSH:Le tubature criogeniche cedono! Corri, ti seguo!'],
// 6 · NUCLEO
['R001 tgb/tcs/tad|MARSH:L\'anello del reattore è avanti. Coprimi.','Xm|MARSH:Scarica di plasma in arrivo! Dietro di me!','R110 tsg/tcb/trr','R220 tcu/tga/tsd','R030 tgg/tsb/tcd','R101 tca/tsg/ddd'],
['R010 tgb/tsc/tdd|MARSH:Le valvole primarie sono tre. Ci penso io, tu tienili lontani.','R201 tcu/tga/tsr','Xl|MARSH:Griglia di contenimento. Segui i miei tempi.','R121 bgt/tcs/tad','R000 tsg/tcb/ddd','R051 tcu/tgr/tsa'],
['R021 tcb/tsg/trr','R100v tgu/tca/tsd|VARR:Assaltatori, avanti. Voglio la dottoressa, viva.','Xc|MARSH:Ha preso la mia chiave del reattore! Fermala!','R212 rrb/tsg/tcd','R011 tgg/tca/tsb','R130 tcu/trr/tgd'],
['R000 tsb/tcg/tad','R111 tcu/tgs/trr','R222 sgb/tcd/taa','Xm|MARSH:La sala di controllo è oltre il condotto. Corri!','R021 tgc/tsb/ddd','R001 tca/tgs/trb'],
['R011 tgb/tcs/tad','R201 tcu/tsg/trr','R120 bgc/tsa/tdd','R001B Bgg|MARSH:Fornace presidia il nucleo. Senza di lui posso rallentarlo.','Xm|MARSH:Il reattore scarica nel corridoio! Non voltarti!'],
// 7 · CITTADELLA
['R000 tcu/tsu/tcg|BASE:I cancelli della Cittadella. Torrette ovunque.','R210 ucs/tcb/tsd','Xl|BASE:Le difese della Cittadella si attivano.','R120 tcu/sgc/trr','R031 ucc/tsa/tgd','R101 tsu/tcb/tgs'],
['R010 uuc/tsg/tcd','R200 tcs/ucb/trr','R121 ucg/tsa/tcs','Xx|BASE:Hai spento il perimetro, ma il corridoio è minato!','R022 ssc/tcu/tgb','R040 ucc/tsg/tad'],
['R020 tcs/ucg/tsb','R110k tcu/scg/trr|KROSS:Così sei tu, l\'agente. Ammirevole. Inutile.','Xq|BASE:È Kross in persona! Stagli addosso!','R201 ucc/tsb/tgd','R012 scu/tca/tgs','R130 tcb/usg/tcd'],
['R000 ucs/tcg/tsb','R211 tcu/scc/trr','R102 ssc/tgb/tad|BASE:Sala comunicazioni. Isolala e Kross resta sordo.','Xl','R020 ucg/tcs/tsb','R071 tcu/scg/taa'],
['R010 ucs/tcb/tsg','R221 tcu/scg/trr','R100 ucc/tsb/tgd','R001B Buu|KROSS:Guardiano. Nessuno entra sul mio ponte.','Xe|BASE:Kross ha fatto saltare il ponte per coprirsi la fuga: corri!'],
// 8 · ARSENALE
['R000v tgb/tcg/tsr|VARR:Di nuovo tu. Stavolta sei nel mio Arsenale, e non ne esci.','Xc|BASE:Ha lei i codici di rotta. Non lasciarla andare!','R110 ggt/tcb/tsu','R221 tgs/bcg/trr','R030 tcu/tgb/sgd','R102 tgc/tsb/tga'],
['R010 tgb/tcs/gga|BASE:Deposito munizioni. Piazza le cariche e allontanati.','R200 tcu/tgs/brr','R121 ggc/tsb/tad','R020 tgu/tcb/sgr','R001 bgc/tsg/tcd','Xe|BASE:Il deposito munizioni sta saltando in aria: corri!'],
['R020v tgc/tsb/trr|VARR:Prendimi, se ci riesci.','Xc|VARR:Sette settori che mi insegui. Non sei stanco?','R110v tcu/ggs/tba|VARR:Sei ostinato. Quasi mi dispiace.','Xc|BASE:È a corto di uscite. Stringi!','R201 bgc/tsg/tcr','R030 tgu/tcb/sga'],
['R000 tgb/ucs/trr','R212 ggs/tcb/tad','Xl','R121 tcu/bgs/tgc','R011 sgb/tca/trg','R100v tcb/ugs/bgr|VARR:Basta scappare. Vendetta è pronto, e io anche.'],
['R010 tgb/tcs/ugr','R201 bgc/tsg/tad','R120 tcu/sgb/trr','R001B Bgb|VARR:Ora vediamo quanto vali davvero, agente.','Xe|BASE:Hai i codici! Ma l\'Arsenale brucia: fuori!'],
// 9 · SETTORE ZERO
['R002 tcb/sgu/tar|MARSH:Il Settore Zero è sotto di te. Kross ti aspetta.','R110 ucs/tgb/trr','Xx|MARSH:La stazione perde quota: si stacca tutto!','R221 sgc/tcb/taa','R030 tcu/bgs/tgd','R101 scb/tga/urr'],
['R010 bcs/tgu/tar','R201k scb/tgc/urr|KROSS:La mia guardia scelta. Divertiti, agente.','Xq|MARSH:Non farlo arrivare al Titano!','R122 ggb/tcs/uaa','R020 scu/bgr/tcd','R061 tcb/sga/ugr'],
['R000 scb/tgu/trr|MARSH:Il terminale di rotta è in fondo. Inserisci i codici di Varr.','R212 bgc/usa/tgd','R101 tcu/sgb/aar','Xl','R020 scg/tcb/uar','R011 bgs/tcu/tgr'],
['R001 scb/ugr/taa|MARSH:Codici accettati! La stazione risale. Tieni la posizione!','R111 bgc/tsu/grr','R221 ucs/bga/tgd','R031 sgb/tcu/arr','Xm|MARSH:Regge! Aurora-9 sta risalendo! Vieni via!','R001k scu/bgc/tar|KROSS:Hai rovinato tutto. Scendi nel cuore, e finiamola.'],
['R010 scb/tgu/arr','R201 bgc/usa/tgr','Xq|KROSS:Titano Zero, sveglia. C\'è un ospite.','R001B Bcb|KROSS:Nessuno ferma la Legione Cenere!']];
function lvDef(L){const out=lvDef0(L);if(L>=3){const rm=out.filter(d=>!d.run),pick=n=>[rm[n],rm[n+1],rm[n-1]].find(d=>d&&!d.fl&&!d.boss&&d.kind<6),set=(d,k)=>{if(!d)return;d.kind=k;d.pose=k===6?8:k===7?9:0;d.sty=1;};set(pick(1),[6,8,7][L%3]);if(L>=16)set(pick(3),[8,7,6][L%3]);}return out;}
function lvDef0(L){const F=CHF[chI(L)];let ri=0;return LV[L-1].map(s=>{const i=s.indexOf('|'),a=i<0?s:s.slice(0,i),say=i<0?'':s.slice(i+1);if(a[0]==='X')return{run:1,rk:a[1],say};
 const sp=a.split(' '),h=sp[0],boss=h.includes('B'),sz=clamp(2+(L>=2)+(L/4|0)+(ri>0?1:0),2,5);ri++;
 let kind=+h[1];const fl=h.slice(4),ro=ri-1;if(!kind&&!boss&&!fl&&!(L===1&&ro===0))kind=[0,3,0,5,4,0,3,5][(L*3+ro*5)%8];if(kind===4&&+h[2]>3)kind=3;const sty=boss?(L%10===0?1:0):(chI(L)*2+L+ro*2)%3===0?0:1;return{kind,sty:chI(L)===0&&ro<2&&L<3?0:sty,pose:+h[2],lit:+h[3],fl,boss,say,waves:sp[1].split('/').map((q,wi)=>{const t=[...q];if(!boss)for(let k=0;t.length<sz;k++)t.push(F[(k+wi)%F.length]);return t.map(c=>EL[c]);})};});}
function seeded(s,f){const o=Math.random;let a=s>>>0;Math.random=()=>{a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};try{return f();}finally{Math.random=o;}}

const TRAITS={chain:{n:'Fulmine a catena',d:'ogni colpo salta su altri 3 nemici'},boom:{n:'Colpi esplosivi',d:'ogni colpo esplode all\'impatto: danno ad area anche dietro scudi e ripari'},vamp:{n:'Vampiro',d:'colpire ti cura, uccidere ti cura di più'},slow:{n:'Tempo fermo',d:'ogni uccisione rallenta il tempo'},inf:{n:'Caricatore senza fondo',d:'non si scarica mai'},tri:{n:'Triplo fuoco',d:'spara tre colpi alla volta'},midas:{n:'Tocco di Mida',d:'i nemici uccisi diventano d\'oro: crediti x3'},ice:{n:'Zero assoluto',d:'ogni colpo congela il bersaglio'},hole:{n:'Buco nero',d:'chi muore risucchia i vicini e li fa esplodere'}};
// t = tipo d'arma: le armi a colpi infiniti (inf:1, la Minigun) non pescano 'inf', che per loro sarebbe inutile
function rollTrait(t){const k=Object.keys(TRAITS).filter(x=>!(x==='inf'&&t&&WT[t]&&WT[t].inf));return k[Math.random()*k.length|0];}
/* ---------- dati ---------- */
const RAR=[{n:'Comune',c:'#aab2bd',m:1},{n:'Non comune',c:'#3ddc68',m:1.3},{n:'Rara',c:'#3b9bff',m:1.65},{n:'Epica',c:'#b45cff',m:2.1},{n:'Leggendaria',c:'#ff9a1f',m:2.7},{n:'Mitica',c:'#ff3355',m:3.5}];
const WT={
 pistol:{n:'Pistola',dmg:18,rate:.26,spread:.012,mag:12,rel:1,wt:10,s:'shot',v:{bd:9,bar:[[0,4,62]],c:'#4a4f58',c2:'#2c3036'}},
 revolver:{n:'Revolver',dmg:42,rate:.55,spread:.008,mag:6,rel:1.5,wt:8,s:'heavy',v:{bd:10,bar:[[0,5,70]],c:'#6b5a48',c2:'#3a3a3e'}},
 smg:{n:'Mitraglietta',dmg:8,rate:.08,spread:.05,mag:32,rel:1.4,wt:9,s:'shot',v:{bd:11,bar:[[0,4,74]],c:'#3d4a44',c2:'#22282a'}},
 shotgun:{n:'Fucile a pompa',dmg:11.5,rate:.58,spread:.13,pel:8,mag:6,rel:1.8,range:9,wt:8,s:'heavy',v:{bd:13,bar:[[-5,5,84],[5,5,84]],c:'#5c4630',c2:'#2e2e30'}},
 rifle:{n:"Fucile d'assalto",dmg:15,rate:.13,spread:.025,mag:28,rel:1.6,wt:7,s:'shot',v:{bd:12,bar:[[0,5,90]],c:'#39424e',c2:'#20242a'}},
 sniper:{n:'Cecchino',dmg:110,rate:1.1,spread:0,mag:5,rel:2,pierce:1,wt:5,s:'heavy',v:{bd:11,bar:[[0,4,104]],scope:1,c:'#2f3a2f',c2:'#1c1f1c'}},
 plasma:{n:'Lanciaplasma',dmg:32,rate:.3,mag:4,fm:1,rel:1.8,proj:'plasma',splash:1.2,wt:4,s:'zap',v:{bd:15,bar:[[0,8,80]],glow:'rgba(80,220,255,.9)',c:'#3a4266',c2:'#232845',fc:'rgba(120,230,255,.95)'}},
 minigun:{n:'Minigun',dmg:7,rate:.045,spread:.07,mag:120,rel:3,wt:3,s:'shot',v:{bd:16,bar:[[-7,3.5,92],[0,3.5,96],[7,3.5,92]],c:'#484c52',c2:'#222'}},
 // Minigun: solo mitica (mo), colpi infiniti senza ricarica (inf), danno per colpo come l'AK, cadenza più alta (le canne devono prendere giri: vedi armi-ambienti.js)
 gatling:{n:'Minigun',dmg:7,rate:.036,spread:.09,mag:1,inf:1,mo:1,rel:0,wt:3,s:'shot',v:{bd:16,bar:[[-6,3,94],[0,3,96],[6,3,94]],c:'#3c4046',c2:'#1c1e22'}},
 rocket:{n:'Lanciarazzi',dmg:130,rate:1.2,mag:1,fm:1,mo:1,rel:2.4,proj:'rocket',splash:2.4,wt:3,s:'heavy',v:{bd:17,bar:[[0,11,88]],c:'#4c5a3a',c2:'#2a3320'}},
 laser:{n:'Laser',dmg:5,rate:.035,spread:0,mag:150,rel:2.2,beam:1,wt:3,s:'zap',v:{bd:12,bar:[[0,3,86]],glow:'rgba(255,60,90,.9)',c:'#555a66',c2:'#33363e'}}
};
const PK={hp:{n:'Vitalità',d:'+20 vita massima',max:10,c:120},ar:{n:'Corazza',d:'+15 armatura a inizio livello',max:8,c:100},sp:{n:'Agilità',d:'Entri ed esci dal riparo più in fretta',max:5,c:150},lk:{n:'Fortuna',d:'Rarità migliori da bauli e casse',max:5,c:250},cr:{n:'Recupero',d:'+10% crediti raccolti',max:8,c:140},ct:{n:'Critico',d:'+5% colpi critici (danno x2)',max:6,c:200}};
const CR=[{n:'Cassa Base',p:200,q:.3,min:0,c:'#aab2bd'},{n:'Cassa Avanzata',p:600,q:1.5,min:1,c:'#3b9bff'},{n:'Cassa Elite',p:1800,q:3.5,min:2,c:'#ff9a1f'}];
const SEC=['Bunker','Laboratorio','Fonderia','Alveare','Criogenia','Nucleo'];

let S=load();
function load(){try{const s=JSON.parse(localStorage.getItem('sz_save'));if(s&&s.inv&&s.inv.length&&s.eq&&s.eq.length){s.inv.forEach(w=>{if(w.r===5&&(!w.x||(w.x==='inf'&&WT[w.t]&&WT[w.t].inf)))w.x=rollTrait(w.t);if(WT[w.t]&&WT[w.t].mo&&w.r<5){const ks=Object.keys(WT).filter(k=>!WT[k].mo&&WT[k].s==='heavy');w.t=ks.length?ks[w.id%ks.length]:'rifle';}});s.eq=s.eq.slice(0,2);s.maxL=Math.min(s.maxL||1,NLV);return s;}}catch(e){}
 return{cr:0,inv:[{id:1,t:'pistol',r:0,l:0}],eq:[1],perks:{},maxL:1,nid:2,auto:0,snd:1};}
function save(){try{localStorage.setItem('sz_save',JSON.stringify(S));}catch(e){}}
const pk=k=>S.perks[k]||0;
const wget=id=>S.inv.find(w=>w.id===id);
/* caricatore infinito: nei confronti vale Infinity (non si scarica e non parte mai la ricarica), nei testi diventa '∞' (menu, carta del baule) */
const MAG_INF=Object.freeze({[Symbol.toPrimitive](h){return h==='number'?Infinity:'∞';}});
function wst(w){const t=WT[w.t],m=RAR[w.r].m,l=w.l||0;return{dmg:t.dmg*m,mag:t.inf?MAG_INF:t.mo?t.mag:t.fm?t.mag+Math.floor(l/3):Math.max(t.mag+Math.ceil(l/2),Math.round(t.mag*(1+.1*w.r)*(1+.1*l))),rel:t.inf?0:t.rel*(1-.05*w.r)*(1-(t.mo?.04:.03)*l),spr:(t.spread||0)*Math.max(.3,1-.07*l),dps:t.dmg*m*(t.pel||1)/t.rate};}
function rollRar(q,min){q+=pk('lk')*.25;const b=[60,26,10,3.2,.7,.1];let tot=0;const w=b.map((v,i)=>{const x=i<min?0:v*Math.pow(1+q,i*.55);tot+=x;return x;});let r=Math.random()*tot;for(let i=0;i<6;i++){r-=w[i];if(r<=0)return i;}return min;}
function rollType(ra){const ks=Object.keys(WT).filter(k=>!WT[k].mo||ra===5);let tot=0;ks.forEach(k=>tot+=WT[k].wt);let r=Math.random()*tot;for(const k of ks){r-=WT[k].wt;if(r<=0)return k;}return'pistol';}
function newWeapon(q,min,fr){const r0=fr!=null?fr:rollRar(q,min||0),w={id:S.nid++,t:rollType(r0),r:r0,l:0};if(w.r===5)w.x=rollTrait(w.t);S.inv.push(w);if(S.eq.length<2)S.eq.push(w.id);save();return w;}
const upCost=w=>Math.round(50*(w.l+1)*(1+w.r*.5)*Math.pow(1.15,w.l));
const sellVal=w=>Math.round(30*Math.pow(2.1,w.r)*(1+w.l*.3));
const pkCost=k=>Math.round(PK[k].c*Math.pow(1.6,pk(k)));
const wname=w=>`<span style="color:${RAR[w.r].c}">${WT[w.t].n}${w.x?' ★':''}</span>`;


/* ----- icone delle armi (una sagoma per tipo) ----- */
const WIC={
 pistol:'<path d="M12 7h37l2 2v5H31l-1 3h-4l-3 10H13l3-11h-4z"/><path d="M30 15h7v1c0 3-2 4-5 4h-2" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M15 9h30" stroke="#000" stroke-opacity=".45" stroke-width="1.2"/>',
 revolver:'<path d="M31 7h26v2h1v3H33v4H21l-3 11H8l5-13 1-5h4l1-3h3l1 3z"/><rect x="21.5" y="6.5" width="10" height="9.5" rx="2" fill="#000" fill-opacity=".35"/><path d="M24 7v9M28 7v9" stroke="currentColor" stroke-width="1"/><path d="M26 16h7v1c0 3-2 4-5 4h-2" fill="none" stroke="currentColor" stroke-width="1.4"/>',
 smg:'<path d="M3 9h7V8h34v2h11v3H44v2H33v12h-6V15h-5l-2 10h-6l2-10H9v-4H3z"/><path d="M14 6h3v2h-3zM38 6h3v2h-3z"/><path d="M12 11h28" stroke="#000" stroke-opacity=".45" stroke-width="1.2"/>',
 shotgun:'<path d="M2 13l12-5h47v3h-9v1h-2v3h-4v2H33v-2h-7l-2 2h-4l-3 7h-5l2-8-12 3z"/><path d="M34 13h11" stroke="#000" stroke-opacity=".5" stroke-width="1.4"/><path d="M16 10h43" stroke="#000" stroke-opacity=".35" stroke-width="1"/>',
 rifle:'<path d="M2 10h12V8h8V5h9v3h20v2h6V6h2v4h2v2H51v2H39l2 12h-7l-3-11h-5l-2 9h-6l2-9h-3l-4 3H2z"/><path d="M36 10h14" stroke="#000" stroke-opacity=".45" stroke-width="1.6"/>',
 sniper:'<path d="M2 10h12V9h4V8h3V3h20v5h-3v1h2v1h18V9h4v4h-4v-1H47l3 11h-2l-4-11h-1l-3 11h-2l2-11h-8v5h-5v-5h-3l-2 9h-5l2-9h-4l-5 3H2z"/><path d="M23 5.5h16" stroke="#000" stroke-opacity=".5" stroke-width="1.6"/>',
 plasma:'<path d="M5 10h35V7h18V5h4v4h-3v4h3v4h-4v-2H40v2H29l-2 10h-6l2-10H5z"/><circle cx="20" cy="7" r="5"/><circle cx="20" cy="7" r="2.6" fill="#7fe8ff"/><path d="M44 8v8M48 8v8M52 8v8" stroke="#7fe8ff" stroke-width="1.4"/>',
 // AK (la chiave resta 'minigun' per i salvataggi): calcio e impugnatura in legno, caricatore curvo a banana, astina, tubo del gas, mirino e freno di bocca
 minigun:'<path d="M2 10.5L17 8v6.5L5 18.5H2z"/><path d="M17 7.5h19v7H17z"/><path d="M20 14h5.5l-2.3 9.5h-4.7l1.7-8z"/><path d="M29.5 14h6c.6 4.2 2.6 7.6 5.8 10.2l-4.6 3.3c-3.9-3.4-6.4-8-7.2-13.5z"/><path d="M36 9.5h11.5v5H36z"/><path d="M36 7.6h12v1.6H36zM47 10.3h12.5v1.7H47zM58.5 9.4h4v3.4h-4zM54.5 8.2h1.6v2.2h-1.6zM33.2 6.2h2.6v1.6h-2.6z"/><path d="M25.5 15.5c.2 2.8 1.4 4.2 4 4.2" fill="none" stroke="currentColor" stroke-width="1.3"/><path d="M2 10.5L17 8v6.5L5 18.5H2zM36 9.5h11.5v5H36zM20 14h5.5l-2.3 9.5h-4.7l1.7-8z" fill="#000" fill-opacity=".2"/><path d="M17 8v6.5M36 7.6v7M18 11h17M38 12h8M31 17.5l2.6-.7M32.4 21.3l2.6-1" stroke="#000" stroke-opacity=".45" stroke-width="1"/>',
 // Minigun: sei canne con fascette e anello di bocca, carcassa del rotore, motore, maniglia, impugnatura, cassetta con nastro
 gatling:'<path d="M7 7.5h20l2-1.5v15l-2-1.5H7z"/><rect x="28" y="3.5" width="6" height="20" rx="2"/><path d="M2 10h5v7H2zM11.5 2h14v5.5H23V4.5h-9v3h-2.5z"/><path d="M8 19.5h4.5L11 26.5H6.5zM15 20h11v7.5H15z"/><path d="M34 6.2h25v2.6H34zM34 11.7h25v2.6H34zM34 17.2h25v2.6H34z"/><rect x="57.5" y="4.6" width="5" height="16.8" rx="1.6"/><rect x="44.5" y="5" width="2.8" height="16" rx="1"/><path d="M26 21.5c2.5 0 3.5-.6 4.5-2.4" fill="none" stroke="currentColor" stroke-width="2.6" stroke-dasharray="1.4 .7"/><path d="M34 8.8h10.5M47.3 8.8h10.2M34 14.3h10.5M47.3 14.3h10.2M34 19.8h10.5M47.3 19.8h10.2M8 13.5h19M31 4v19M15 23.5h11" stroke="#000" stroke-opacity=".45" stroke-width="1"/>',
 rocket:'<path d="M2 6l6 2h46l6-2v12l-6-2H8l-6 2z"/><path d="M60 8l4 4-4 4z" fill="#ff6a3a"/><path d="M29 3h8v5h-8zM25 16h6l-1 10h-5zM39 16h4v7h-4z"/><path d="M12 12h38" stroke="#000" stroke-opacity=".4" stroke-width="1.4"/>',
 laser:'<path d="M2 9h6v8H2zM8 9h33v2h19v2H41v2H33v6H22v-6h-3l-2 10h-6l2-10H8z"/><path d="M15 5h3v4h-3zM20 5h3v4h-3zM25 5h3v4h-3zM30 5h3v4h-3z"/><rect x="59" y="8" width="4" height="8" rx="1.5" fill="#ff4466"/><path d="M41 12h18" stroke="#ff4466" stroke-width="1.2"/>'};
function wIcon(t){return '<svg viewBox="0 0 64 28" fill="currentColor" preserveAspectRatio="xMidYMid meet">'+(WIC[t]||WIC.pistol)+'</svg>';}
