root=root or 'mod/BeyondTuning/Scripts'
local P=dofile(root..'/policy.lua');local J=dofile(root..'/json.lua');local checks=0
local function check(x,s)assert(x,s);checks=checks+1 end
local function refuse(fn,s)check(not pcall(fn),s)end
local t=P.stock();check(P.factor(t,3000,6000,.5)==1,'Stock neutral');t.power=120;check(math.abs(P.factor(t,3000,6000,1)-1.2)<1e-9,'Torque changes')
t.map[5][4]=120;t.map[5][5]=140;check(math.abs(P.map(t,.5,1)-1.3)<1e-9,'Map interpolation');check(P.factor(t,6100,6000,1)==0,'Actual torque cut')
local base={{StartSpeed=10,EndSpeed=100,UpShift=90,DownShift=20,HighRPM=6000,LowRPM=1000,MaxTorque=10,MinTorque=5}}
t.gearing=125;local gears=P.gears(base,t);check(gears[1].EndSpeed==80 and gears[1].MaxTorque==12.5,'Final-drive tradeoff');check(base[1].EndSpeed==100,'Baseline immutable')
local p={format='BeyondTuning',schema=1,name='Test',tune=t};local round=P.preset(J.decode(J.encode(p)));check(round.tune.power==120,'JSON round trip')
for _,bad in ipairs({'{"a":1,"a":2}','[1,]','{"x":NaN}','{"x":1e309}','{"x":01}','{} trailing','{"x":"\\uD800"}'})do refuse(function()J.decode(bad)end,'Malformed JSON refused '..bad)end
local unicode=J.decode('"\\uD83D\\uDE80"');check(unicode=='🚀','Unicode surrogate')
refuse(function()P.preset({format='Other',schema=1,name='x',tune=t})end,'Wrong format')
refuse(function()local bad=P.copy(t);bad.power=10000;P.validate(bad)end,'Power bounded')
refuse(function()local bad=P.copy(t);bad.map[1][1]=0/0;P.validate(bad)end,'NaN refused')
refuse(function()local bad=P.copy(t);bad.code='os.execute';P.validate(bad)end,'Unknown controls refused')
refuse(function()J.decode(string.rep('[',26)..'0'..string.rep(']',26))end,'Depth bounded')
check(P.isStock(P.stock()),'Stock bypasses tuning hook')
check(not P.isStock(t),'Modified tune remains active')
local baseline={gears={base[1],base[1]},redline=6000,shift=.3,idle=6000,consumption=.1,heat=1}
check(P.baseline(baseline)==baseline,'Saved baseline validated')
refuse(function()local b=P.copy(baseline);b.gears[1].HighRPM=0/0;P.baseline(b)end,'Corrupted saved gearbox refused')
local legacy=P.stock();legacy.nitrous=nil;legacy.turbos=nil;local upgraded=P.validate(legacy);check(upgraded.nitrous==100 and next(upgraded.turbos)==nil,'Legacy presets upgrade to stock hardware')
local hardware=P.stock();hardware.nitrous=50;hardware.turbos={CarTurboV2=50,CarTurboV2_2=175};local converted=P.preset(J.decode(J.encode({format='BeyondTuning',schema=1,name='Hardware',tune=hardware})))
check(converted.tune.nitrous==50 and converted.tune.turbos.CarTurboV2_2==175,'Hardware preset round trip')
check(not P.isStock(hardware),'Hardware-only tunes persist')
refuse(function()local t=P.stock();t.nitrous=0;P.validate(t)end,'No zero injection exploit')
refuse(function()local t=P.stock();t.turbos={CarTurboV2=201};P.validate(t)end,'Turbo bounded')
refuse(function()local t=P.stock();t.turbos={['../bad']=125};P.validate(t)end,'Invalid slot refused')
check(P.isStock(P.validate(legacy)),'Legacy stock restores all hardware')
print('PASS '..checks..' policy, interpolation, baseline and JSON checks')
