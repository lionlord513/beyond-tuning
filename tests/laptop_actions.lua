-- Blueprint action hooks run after the native handler. Placing a held laptop
-- must not be mistaken for clicking a laptop that was already mounted.
local scripts=assert(root)
local callbacks,queue={},{}
StaticFindObject=function()return {} end
LoadAsset=function()end
NotifyOnNewObject=function()end
RegisterHook=function(path,fn) callbacks[path]=fn;return 1,1 end
FText=function(s)return s end
local function param(v)return {get=function()return v end} end
local function object(id)return {GetAddress=function()return id end} end
local actor,pc,helper,mesh=object(1),object(2),object(3),object(4)
local mounted,held,removed=true,nil,0
actor.isAttachedFunction=function()return mounted end
actor.HasAuthority=function()return true end
actor.SetActorTickEnabled=function()end
mesh.GetOwner=function()return actor end
helper.SetActorEnableCollision=function()end
pc.GetItemInHand=function(_,out)out.Item=held end
local T={valid=function(x)return type(x)=='table'end,root=scripts:match('^(.*)/Scripts$'),vehicle={pc=function()return pc end},storage={},network={},json={},enqueue=function(fn)queue[#queue+1]=fn end}
local L=dofile(scripts..'/laptop.lua')(T)
L.install()
local r={id='carried',actor=actor,helper=helper,closed=true,holder=pc}
L.items[r.id]=r;L.actors[1]=r;L.helpers[3]=r
L.request=function()removed=removed+1 end
local physical='/Game/BP/Items/Master/AttachableMaster.AttachableMaster_C:'
local function click()
 callbacks[physical..'ExecutePrimaryAction'](param(actor),param(true),param(pc),param(mesh))
 for _,fn in ipairs(queue)do fn()end;queue={}
end
click()
assert(removed==0,'Completing placement removed the new mount')
click()
assert(removed==1,'Clicking an already mounted laptop did not remove it')
r.closed=false
local name
callbacks[physical..'GetPrimaryActionName'](param(actor),{set=function(_,v)name=v end})
assert(name=='Use laptop')
print('PASS native placement, subsequent removal and open prompt')
