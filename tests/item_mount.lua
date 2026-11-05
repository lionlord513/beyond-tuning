local scripts=arg[1]
local function obj(id)return {GetAddress=function()return id end}end
local function wrap(v)return {get=function()return v end}end
local function pos(x,y,z)return {X=x,Y=y,Z=z}end
local function valid(v)return type(v)=='table'and v.alive~=false end
local car,on,a,pc=obj(1),obj(2),obj(3),obj(4)
local target=pos(100000,-15000,29000);local savePose,writes=nil,0
local row={Actor_2_62DE748F44B7CBBBDC5471B53B1803CE=a,ComponentAttached_5_7C2F01C7441B2324C8960C81A55FBB68=on}
local native={ActorsAttached={ForEach=function(_,fn)fn(1,wrap(row))end},
 UpdateRelativeTransform=function(_,who,t)assert(who==a);savePose=t;writes=writes+1 end}
car.K2_GetComponentsByClass=function()return {wrap(native)}end
car.ForceNetUpdate=function()end;car.FlushNetDormancy=car.ForceNetUpdate
on.GetOwner=function()return car end;on.K2_GetComponentToWorld=function()return target end
a.pos=target;a.authority=true;a.parent=car;a.RootComponent={GetAttachParent=function()return on end}
a.HasAuthority=function()return a.authority end;a.GetAttachParentActor=function()return a.parent end
a.GetFullName=function()return 'fixture actor'end
a.K2_GetActorLocation=function()return a.pos end
a.K2_SetActorRelativeTransform=function(_,t)assert(t==savePose);a.pos=t.Translation end
a.ForceNetUpdate=car.ForceNetUpdate;a.FlushNetDormancy=car.FlushNetDormancy
local game={GetComponentBounds=function(_,c,center,extent)
 assert(c==on);for k,v in pairs(target)do center[k]=v;extent[k]=20 end
end}
StaticFindObject=function(path)
 if path:find('KismetSystemLibrary')then return game end
 if path:find('KismetMathLibrary')then return {MakeRelativeTransform=function(_,pose,parent)assert(parent==target);return pose end}end
 return {}
end
pc.PlayerControlled={K2_GetActorLocation=function()return target end}
pc.GetItemInHand=function(_,h)h.Item=a end
local L={actors={},items={}};local bottles={}
local T={valid=valid,enqueue=function(fn)fn()end,induction={nitrous={items=bottles}}}
local mount=dofile(scripts..'/item_mount.lua')(T,L)
local r={actor=a};L.actors[3]=r;L.items.laptop=r
mount.schedule(r);assert(writes==0,'A correct placement must stay exactly as placed')
a.pos=pos(0,0,0);r.mountBuyer=pc
mount.receive(pc,{id='laptop',offset=pos(5,8,9),rotation={X=0,Y=0,Z=0,W=1}})
mount.schedule(r);assert(writes==1 and a.pos.X==target.X+5 and a.pos.Y==target.Y+8 and a.pos.Z==target.Z+9)
L.actors[3]=nil;local bottle={actor=a};bottles[a:GetFullName()]=bottle
a.pos=pos(0,0,0);mount.schedule(bottle)
assert(writes==2 and a.pos.X==target.X and a.pos.Z==target.Z+23,'Recover the same saved bottle on the original component')
a.pos=pos(0,0,0);a.authority=false;mount.schedule(bottle);assert(writes==2)
a.authority=true;a.parent=nil;mount.schedule(bottle);assert(writes==2)
a.parent=car;bottles[a:GetFullName()]=nil;mount.schedule(bottle);assert(writes==2)
return 'Host repair of marked, corrupt native attachment rows; normal mounts, loose items and unmarked actors untouched'
