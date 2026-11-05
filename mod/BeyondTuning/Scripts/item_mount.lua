-- Repair only identified laptops and nitrous bottles already mounted by DBH. The native
-- attachment row is the source both replication and the save system read.
return function(T,L)
 local valid=T.valid
 local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 local system=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
 local attachClass
 local function same(a,b)return valid(a)and valid(b)and a:GetAddress()==b:GetAddress()end
 local function record(a)
  if not valid(a)then return end
  local r=L.actors[a:GetAddress()]
  if r then return r end
  local n=T.induction and T.induction.nitrous
  return n and n.items and n.items[a:GetFullName()]
 end
 local function finite(n)return type(n)=='number'and n==n and math.abs(n)<1e12 end
 local function copyPose(t)
  local p,q=t.Translation,t.Rotation
  return {Translation={X=p.X,Y=p.Y,Z=p.Z},Rotation={X=q.X,Y=q.Y,Z=q.Z,W=q.W},Scale3D={X=1,Y=1,Z=1}}
 end
 local function bounds(component)
  local center,extent={},{ }
  system:GetComponentBounds(component,center,extent,{})
  if not finite(center.X)or not finite(extent.X)then return end
  return center,extent
 end
 local function near(p,center,extent)
  return math.abs(p.X-center.X)<=extent.X+100 and math.abs(p.Y-center.Y)<=extent.Y+100 and math.abs(p.Z-center.Z)<=extent.Z+100
 end
 local field='Actor_2_62DE748F44B7CBBBDC5471B53B1803CE'
 local componentField='ComponentAttached_5_7C2F01C7441B2324C8960C81A55FBB68'
 local function repair(r)
  if not valid(r.actor)or record(r.actor)~=r or not r.actor:HasAuthority()then return end
  local a=r.actor;local parent=a:GetAttachParentActor();if not valid(parent)then return end
  local on=a.RootComponent:GetAttachParent()
  if not valid(on)or not same(on:GetOwner(),parent)then return end
  local center,extent=bounds(on);if not center or near(a:K2_GetActorLocation(),center,extent)then return end
  if not valid(attachClass)then attachClass=StaticFindObject('/Game/BP/Components/AttachActorOn.AttachActorOn_C')end
  if not valid(attachClass)then return end
  local native
  for _,v in ipairs(parent:K2_GetComponentsByClass(attachClass))do
   local c=v:get();c.ActorsAttached:ForEach(function(_,entry)
    local row=entry:get();if same(row[field],a)and same(row[componentField],on)then native=c end
   end)
   if native then break end
  end
  if not native then return end
  local pose;local desired=r.mountPose
  if desired and os.clock()-desired.at<2 and valid(desired.pc)and same(desired.pc,r.mountBuyer)then
   if desired.offset and valid(desired.pc.PlayerControlled)then
    local b=desired.pc.PlayerControlled:K2_GetActorLocation();local o=desired.offset
    local q={X=b.X+o.X,Y=b.Y+o.Y,Z=b.Z+o.Z}
    if near(q,center,extent)then pose={Translation=q,Rotation=desired.rotation,Scale3D={X=1,Y=1,Z=1}}end
   end
   if not pose and desired.native and near(desired.native.Translation,center,extent)then pose=desired.native end
  end
  -- A corrupt saved attachment has no live cursor pose. Put it on the
  -- original component where it can be removed, preserving the same actor.
  pose=pose or {Translation={X=center.X,Y=center.Y,Z=center.Z+extent.Z+3},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
  local rel=mathlib:MakeRelativeTransform(pose,on:K2_GetComponentToWorld())
  native:UpdateRelativeTransform(a,rel,true);a:K2_SetActorRelativeTransform(rel,false,{},true)
  a:FlushNetDormancy();a:ForceNetUpdate();parent:FlushNetDormancy();parent:ForceNetUpdate()
 end
 local function schedule(r)
  if r.mountCheck then return end;r.mountCheck=true
  T.enqueue(function()r.mountCheck=nil;repair(r)end)
 end
 local function sample(r,pc)
  local s=r.mountPose
  if not s or not same(s.pc,pc)or os.clock()-s.at>2 then s={pc=pc};r.mountPose=s end
  s.at=os.clock();return s
 end
 local function receive(pc,p)
  local hand={};pc:GetItemInHand(hand)
  local r=p.id and L.items[p.id]or (p.bottle and record(hand.Item))
  if not r or not valid(r.actor)or not valid(pc.PlayerControlled)then return end
  local o,q=p.offset,p.rotation;if type(o)~='table'or type(q)~='table'then return end
  if not(finite(o.X)and finite(o.Y)and finite(o.Z)and o.X^2+o.Y^2+o.Z^2<=600^2)then return end
  if not(finite(q.X)and finite(q.Y)and finite(q.Z)and finite(q.W)and math.abs(q.X^2+q.Y^2+q.Z^2+q.W^2-1)<.02)then return end
  if not same(hand.Item,r.actor)and not (same(pc,r.mountBuyer)and r.mountPose and os.clock()-r.mountPose.at<2)then return end
  local s=sample(r,pc);s.offset=o;s.rotation=q
 end
 local base='/Game/BP/PlayerController/PlayerControllerBase.PlayerControllerBase_C:'
 local function install()
  RegisterHook(base..'SetDesiredAttachedTransform',function(ctx,tr,target)
   local pc,a=ctx:get(),target:get()
   if not valid(a)or not valid(pc)or pc:HasAuthority()or not pc:IsLocalPlayerController()then return end
   local r=record(a)
   if not r or not valid(pc.PlayerControlled)or os.clock()<(r.poseAt or 0)then return end
   local pose=copyPose(tr:get());local q=pose.Translation;local b=pc.PlayerControlled:K2_GetActorLocation()
   local offset={X=q.X-b.X,Y=q.Y-b.Y,Z=q.Z-b.Z}
   if offset.X^2+offset.Y^2+offset.Z^2>600^2 then return end
   r.poseAt=os.clock()+.15;T.enqueue(function()if T.network.connected and record(a)==r then
    T.network.call({op='laptopPose',id=r.id,bottle=r.id==nil,offset=offset,rotation=pose.Rotation})
   end end)
  end)
  RegisterHook(base..'ServerSetDesiredAttachedTransform',function(ctx,tr,target)
   local pc,a=ctx:get(),target:get()
   if not valid(pc)or not pc:HasAuthority()or not valid(a)then return end
   local r=record(a);if not r or not valid(pc.PlayerControlled)then return end
   local hand={};pc:GetItemInHand(hand);if not same(hand.Item,a)then return end
   r.mountBuyer=pc;sample(r,pc).native=copyPose(tr:get())
  end)
 end
 return {schedule=schedule,receive=receive,install=install}
end
