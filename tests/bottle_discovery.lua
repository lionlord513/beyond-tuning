local scripts=arg[1];local real=dofile;local calls,fail=0,true
local valid=function(v)return type(v)=='table'and v.alive~=false end
local a={GuidUnique={A=1,B=2,C=3,D=4},GetFullName=function()return 'GasBarrelGaz_2_C fixture'end,GetAddress=function()return 1 end,HasAuthority=function()return false end,K2_GetComponentsByClass=function()return{}end,ItemTankComponent={}}
local guid='00000001:00000002:00000003:00000004'
local visual={apply=function(r)calls=calls+1;if fail then error('Asset not ready')end;r.visual={}end,maintain=function()end}
local journal={state={bottle={}},reset=function()end}
local mounts={records={[guid]={variant=5,litres=1.25}},reset=function()end}
dofile=function(path)
 if path:match('/nitrous/visuals.lua$')then return function()return visual end end
 if path:match('/nitrous/journal.lua$')then return function()return journal end end
 if path:match('/nitrous/mounts.lua$')then return function()return mounts end end
 if path:match('/nitrous/fluid.lua$')then return function()return {install=function()return true end}end end
 if path:match('/nitrous/effects.lua$')or path:match('/nitrous/network.lua$')or path:match('/nitrous/presentation.lua$')then return function()return{}end end
 return real(path)
end
StaticFindObject=function()return{}end;NotifyOnNewObject=function()end;RegisterHook=function()end
FindAllOf=function()return{a}end;ModRef={SetSharedVariable=function()end}
local N=real(scripts..'/nitrous/controller.lua')({root=scripts:gsub('/Scripts$',''),valid=valid},{},function()end)
assert(N.info(a).id==5,'The saved mount record identifies the bottle even without its marker')
N.discover(0);assert(calls==1 and not next(N.items)and #N.incoming==1,'Failed presentation must remain retryable')
fail=false;N.discover(1);assert(calls==2 and N.items[a:GetFullName()].def.id==5 and #N.incoming==0)
for t=2,100 do N.discover(t)end;assert(calls==2,'A healthy bottle must not be rebuilt while idle')
return 'Saved variant recovery, late asset retry, no half-adopted actor and idle visual reuse'
