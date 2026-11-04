-- Fixed seed, load order and revisits must make the same world loot decision.
local scripts=assert(arg[1])
local level={HasBeenInitialized=true,WorldSoftObjectPtrPath={ToString=function()return '/Game/Maps/Levels/L_Garage' end},Transform={Translation={X=0,Y=0,Z=0}}}
local host={IsInitialized=true,K2_GetActorLocation=function()return {X=0,Y=0,Z=0}end}
local pc={PlayerControlled=host,HasAuthority=function()return true end}
local gs={Seed=42,LSLevelSpawner={LevelsRep={ForEach=function(_,fn)fn(1,{get=function()return level end})end}}}
local game={GetGameInstance=function()return {IsSaving=false}end,GetGameState=function()return gs end}
local trace={LineTraceSingle=function(_,_,_,_,_,_,_,_,hit)hit.ImpactNormal={Z=1};hit.ImpactPoint={Z=0};return true end,BoxTraceSingle=function()return false end}
StaticFindObject=function(path)return path:find('KismetSystemLibrary',1,true)and trace or game end
local T={root=scripts:gsub('/Scripts$',''),valid=function(o)return type(o)=='table'end,vehicle={pc=function()return pc end},storage={},network={},json={}}
local L=dofile(scripts..'/laptop.lua')(T);assert(L.price==1000);L.world='one';L.lootSites={};local total=0
L.spawn=function(buyer,spot,site)assert(buyer==pc and not L.lootSites[site] and spot.Z==16);L.lootSites[site]='saved-laptop-id';total=total+1 end
for x=1,4096 do level.Transform.Translation.X=x;L.loot();L.loot()end
assert(total>30 and total<100,'Unexpected spawn frequency '..total)
local n=total;for x=4096,1,-1 do level.Transform.Translation.X=x;L.loot()end;assert(total==n)
pc.HasAuthority=function()return false end;L.lootSites={};for x=1,4096 do level.Transform.Translation.X=x;L.loot()end;assert(total==n)
print('PASS rare host-only laptop loot, '..total..' of 4096 locations, no duplicate on revisit')
