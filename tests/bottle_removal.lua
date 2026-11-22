local scripts=arg[1];local hooks,queue={},{}
local function obj(id)return {GetAddress=function()return id end}end
local function valid(o)return type(o)=='table'and o.alive~=false end
local a,pc,world,mesh=obj(1),obj(2),obj(3),obj(4)
local parent,held,reset,taken=nil,nil,0,0
pc.PlayerControlled={};pc.GetItemInHand=function(_,o)o.Item=held end;pc.GetWorld=function()return world end
a.GetWorld=pc.GetWorld;a.HasAuthority=function()return true end;a.GetFullName=function()return 'GasBarrelGaz_2_C test'end
a.GetAttachParentActor=function()return parent end;a.isAttachedFunction=function()return parent~=nil end
a.RootMeshComponent=mesh;a.AttachableComponent={isAttached=true,ResetState=function(self)self.isAttached=false;reset=reset+1 end}
a.ResetState=function()end;a.ExecutePrimaryAction=function()taken=taken+1 end
StaticFindObject=function()return{}end;RegisterHook=function(path,fn)hooks[path]=fn end
local r={actor=a};local T={valid=valid,enqueue=function(fn)queue[#queue+1]=fn end,induction={nitrous={items={[a:GetFullName()]=r}}}}
local A=dofile(scripts..'/item_mount.lua')(T,{actors={},items={}});A.install()
local wrap=function(v)return {get=function()return v end}end
local function remove()
 hooks['/Game/BP/Items/Master/ContainerMasterItem.ContainerMasterItem_C:ExecuteSecondaryAction'](wrap(a),wrap(true),wrap(pc))
 for _,fn in ipairs(queue)do fn()end;queue={}
end
parent=obj(10);remove();assert(reset==0,'An attached bottle cannot be force-detached')
parent=nil;held=obj(11);remove();assert(reset==0,'Do not replace another held item')
held=nil;remove();assert(reset==1 and taken==1,'Finish the native detached transition and allow pickup')
remove();assert(reset==1 and taken==1,'Removal is idempotent')
local cleared,detached=0,0
parent=obj(10);parent.AttachActorOn={RemoveAttachActorOn=function(_,item)assert(item==a);cleared=cleared+1 end}
parent.FlushNetDormancy=function()end;parent.ForceNetUpdate=function()end
a.FlushNetDormancy=function()end;a.ForceNetUpdate=function()end
a.K2_DetachFromActor=function()parent=nil;detached=detached+1 end
held=a;a.isAttached=true;remove();assert(cleared==0,'Mounting an item still in hands is not a removal')
a.isAttached=false;remove();assert(cleared==1 and detached==1 and held==a,'Finish only the accepted native pickup and clear its save row')
held=nil
a.AttachableComponent.isAttached=true;T.induction.nitrous.items={};remove();assert(reset==2,'Unmarked barrels are untouched')
return 'Mounted, detached, occupied hands, duplicate callback and ordinary barrel cases'
