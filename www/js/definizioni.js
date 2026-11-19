// Settore Zero — tipi di nemici e di armi
'use strict';
/* ===== enemy + weapon definitions ===== */
const ET={
 trooper:{n:'Soldato',hp:45,spd:3.6,cr:11,m:'human',col:0x55664a,tint:0xffffff,sc:1,tele:.95,burst:3,bint:.14,dmg:7,acc:.58,cool:2.3,vis:0x30d0ff},
 sniper:{n:'Cecchino',hp:36,spd:3.2,cr:16,m:'human',col:0x2c3038,mdl:'xbot',tint:0x1c1f26,sc:1.02,tele:1.7,burst:1,bint:.1,dmg:26,acc:.9,cool:4,far:1,laser:1,vis:0xff2020},
  runner:{n:'Assaltatore',hp:34,spd:4.3,cr:12,m:'human',mdl:'xbot',col:0x8a2a22,tint:0xb8342a,sc:1,dmg:12,melee:1,fast:1,vis:0xff5030},
 automa:{n:'Automa',hp:150,spd:1.7,cr:22,m:'robot',armor:.6,dmg:16,melee:1,sc:.5},
 scudo:{n:'Scudiero',hp:60,spd:3.2,cr:18,m:'human',mdl:'xbot',col:0x24384e,tint:0x2e5c9a,sc:1.04,tele:1.1,burst:4,bint:.13,dmg:7,acc:.6,cool:2.2,vis:0x60a0ff,shield:1},
 gren:{n:'Granatiere',hp:65,spd:2.9,cr:16,m:'human',col:0xa86424,tint:0xffa058,sc:1.08,tele:.9,burst:1,bint:.1,dmg:24,cool:4.4,gren:1,vis:0xffa020},
 drone:{n:'Drone',hp:22,spd:4.6,cr:8,m:'drone',dmg:10},
 brute:{n:'Bruto',hp:260,spd:1.3,cr:30,m:'human',col:0x742c2c,tint:0xd05a4c,sc:1.45,armor:.5,dmg:14,melee:1,vis:0xffe030},
 turret:{n:'Torretta',hp:150,spd:0,cr:20,m:'turret',armor:.7,tele:1.15,burst:8,bint:.08,dmg:4,acc:.6,cool:3.2},
 boss:{n:'Colosso',hp:1500,spd:1.2,cr:300,m:'mech',armor:.6,dmg:5,acc:.6,tele:1.3,burst:14,bint:.09,cool:2}
};
const WV={pistol:{b:[.05,.12,.2],br:.016,bl:.13,n:1,c:0x40444c},revolver:{b:[.055,.13,.2],br:.02,bl:.2,n:1,c:0x62564c,drum:1},smg:{b:[.06,.14,.34],br:.016,bl:.16,n:1,c:0x38463e,mag:1},
 shotgun:{b:[.07,.12,.5],br:.021,bl:.42,n:2,c:0x62492e},rifle:{b:[.065,.15,.5],br:.018,bl:.3,n:1,c:0x3a424e,mag:1},sniper:{b:[.06,.14,.6],br:.017,bl:.55,n:1,c:0x303c30,scope:1},
 plasma:{b:[.1,.17,.45],br:.045,bl:.28,n:1,c:0x3a426e,glow:0x50dcff},minigun:{b:[.12,.19,.4],br:.02,bl:.5,n:3,c:0x4a4e56},gatling:{b:[.12,.19,.4],br:.016,bl:.5,n:3,c:0x3c4046},rocket:{b:[.11,.15,.5],br:.07,bl:.6,n:1,c:0x4e5e3e},laser:{b:[.07,.14,.45],br:.012,bl:.4,n:1,c:0x565a64,glow:0xff3c5a}};
WT.shotgun.range=12;WT.revolver.n='Luger';WT.minigun.n='Mitragliatore AK';
const WM={pistol:{k:'g_makarov',tz:-.045,by:.05,mz:-.13,hide:['Magazine'],wz:-.44,wx:.1,wy:-.17},revolver:{k:'g_luger',rot:1,tz:-.06,by:.055,mz:-.17,hide:['Clip'],dx:-.025,wz:-.44,wx:.1,wy:-.17},smg:{k:'g_suomi',tz:.07,by:.03,mz:-.45},shotgun:{k:'g_shotgun',tz:.39,by:.03,mz:-.41},rifle:{k:'g_m4',tz:.025,by:.03,mz:-.54},sniper:{k:'g_sniper',tz:.235,by:.03,mz:-.52},minigun:{k:'g_ak',tz:.24,by:.015,mz:-.32},plasma:{k:'g_flare',tz:0,by:.03,mz:-.15,wz:-.44,wx:.1,wy:-.17}};
let G=null,state='hub',BEAM=null;const SEG=23,WG=new THREE.Group();WG.rotation.order='YXZ';cam.add(WG);
const aim={down:false,id:null,cx:0,cy:0,hold:0},cov={down:false,id:null},keys={},ndc=new THREE.Vector2(0,0);
const RC=new THREE.Raycaster(),TV=new V3(),TV2=new V3(),PV=new V3();
