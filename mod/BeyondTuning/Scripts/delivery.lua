-- Both shop items use the same host-owned handoff to native world physics.
return function(T)
 local D={}
 function D.note(message)
  D.message=message
  T.status(message)
 end
 local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
 local trace=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
 local clear={R=0,G=0,B=0,A=0}
 function D.spot(pc)
  assert(T.valid(pc) and pc:HasAuthority(),'Host unavailable')
  local player=pc.PlayerControlled
  assert(T.valid(player) and player.IsLoaded,'Player unavailable')
  assert(not game:GetGameInstance(pc).IsSaving,'Wait for the save to finish')
  local at=player:K2_GetActorLocation()
  local front=player:GetActorForwardVector()
  local right=player:GetActorRightVector()
  local distance=100
  local vehicle=pc.Vehicle
  if T.valid(vehicle) then
   local center,extent={},{}
   vehicle:GetActorBounds(true,center,extent,false)
   at=center;front=vehicle:GetActorRightVector();right=vehicle:GetActorForwardVector()
   distance=math.abs(front.X)*extent.X+math.abs(front.Y)*extent.Y+45
  end
  for _,offset in ipairs({{distance,0},{-distance,0},{0,distance},{0,-distance},{distance,65},{distance,-65}}) do
   local x=at.X+offset[1]*front.X+offset[2]*right.X
   local y=at.Y+offset[1]*front.Y+offset[2]*right.Y
   local floor={}
   if trace:LineTraceSingle(player,{X=x,Y=y,Z=at.Z+35},{X=x,Y=y,Z=at.Z-350},0,false,{player},0,floor,true,clear,clear,0) and floor.ImpactNormal.Z>.55 then
    local pos={X=x,Y=y,Z=floor.ImpactPoint.Z+22}
    local endPos={X=x,Y=y,Z=pos.Z+1}
    if not trace:BoxTraceSingle(player,pos,endPos,{X=30,Y=23,Z=13},{Pitch=0,Yaw=0,Roll=0},0,false,{player},0,{},true,clear,clear,0) then return pos end
   end
  end
  error('No clear delivery space beside you')
 end
 function D.place(actor,body,at)
  assert(T.valid(actor) and T.valid(body),'Delivery item unavailable')
  actor:K2_SetActorLocation(at,false,{},true)
  body:K2_SetWorldLocation(at,false,{},true)
  body:SetPhysicsLinearVelocity({X=0,Y=0,Z=0},false,FName('None'))
  body:SetPhysicsAngularVelocityInDegrees({X=0,Y=0,Z=0},false,FName('None'))
  actor:ForceRepStateItem();actor:FlushNetDormancy();actor:ForceNetUpdate()
  local pos=body:K2_GetComponentLocation()
  assert((at.X-pos.X)^2+(at.Y-pos.Y)^2+(at.Z-pos.Z)^2<100,'Delivery placement failed')
 end
 function D.purchase(pc,price,deliver)
  local at=D.spot(pc)
  local paid={};pc:TryPurchase(price,false,paid)
  assert(paid.Success,'Not enough money')
  local ok,receipt=pcall(deliver,at)
  if not ok then pc:AddMoney(price);error(receipt) end
  return receipt
 end
 return D
end
