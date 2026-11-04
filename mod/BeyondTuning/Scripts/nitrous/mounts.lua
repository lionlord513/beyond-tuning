-- Supplement native saves with exact bottle quantities and native mount
-- records. Recovery only operates on an existing, identified saved vehicle.
return function(T,N)
 local S,J,valid=T.storage,T.json,T.valid
 local M={records={},pending={},cars={},applied={}}
 local actorKey='Actor_2_62DE748F44B7CBBBDC5471B53B1803CE'
 local compKey='ComponentAttached_5_7C2F01C7441B2324C8960C81A55FBB68'
 local trKey='Transform_8_1B293402457C5FD5DE77DDB72871997D'
 local dynamic='WithDynamicCollision_12_2A2A3C1A45A9ED58C33B828184D63966'
 local buried='IsBourred_14_BBC6E510483E36BF7F274CBFA8767DAF'
 local tick='KeepTick_16_B3DDBA4B4F681AD92A644C9C82429BA8'
 local attachable='IsAttachable_19_BD0D858D48CDF86C40F5529D1B2C8B1C'
 local function same(a,b)return valid(a)and valid(b)and a:GetAddress()==b:GetAddress()end
 local function xyz(v)return {X=v.X,Y=v.Y,Z=v.Z}end
 local function file(key)return T.root..'/state/bottle-mounts-'..key..'.json'end
 local function captureBottle(r)
  local a=r.actor;local car=N.parent(a)
  local record={variant=r.def.id,litres=N.fluid.quantity(a.ItemTankComponent)}
  local parent=a:GetAttachParentActor()
  if not valid(parent)or not valid(car)then return record end
  local mounts=parent.AttachActorOn
  if not valid(mounts)then return record end
  mounts.ActorsAttached:ForEach(function(_,entry)
   local row=entry:get()
   if same(row[actorKey],a)and valid(row[compKey])then
    local component=row[compKey];local tr=row[trKey];local q=tr.Rotation
    local parentId=same(parent,car)and 'car'or N.guid(parent)
    if not parentId then return end
    record.mount={car=S.guid(car.GuidGarage),parent=parentId,component=component:GetFName():ToString(),
     transform={Translation=xyz(tr.Translation),Rotation={X=q.X,Y=q.Y,Z=q.Z,W=q.W},Scale3D=xyz(tr.Scale3D)},
     dynamic=row[dynamic],buried=row[buried],tick=row[tick],attachable=row[attachable]}
   end
  end)
  return record
 end
 function M.capture(key)
  local current={}
  for _,r in pairs(N.items)do if valid(r.actor)and r.actor:HasAuthority()then
   local id=N.guid(r.actor);if id then current[id]=captureBottle(r)end
  end end
  local loaded
  for id,r in pairs(M.records)do if not current[id] and r.mount then
   if not loaded then
    loaded={}
    for _,car in ipairs(FindAllOf('AVS_Template_Vehicle_C')or{})do
     if valid(car)and car:GetFullName():find(':PersistentLevel.',1,true)then loaded[S.guid(car.GuidGarage)]=true end
    end
   end
   if M.pending[id] or not loaded[r.mount.car] then current[id]=r end
  end end
  M.records=current
  local text=J.encode({schema=1,items=M.records});if S.read(file(key),4*1024*1024)~=text then S.write(file(key),text)end
 end
 function M.load(key)
  M.reset();if not key then return end
  local data=S.recover(file(key),J.decode,4*1024*1024);if not data then return end
  assert(data.schema==1 and type(data.items)=='table','Invalid bottle records')
  M.records=data.items
  for id,record in pairs(data.items)do
   local d=N.catalog[record.variant]
   assert(id:match('^%x+:%x+:%x+:%x+$')and d and type(record.litres)=='number'and record.litres>=0 and record.litres<=d.litres+.001,'Invalid saved bottle')
   if record.mount then M.pending[id]=record end
  end
  M.wake=true
 end
 function M.quantity(a,id)
  local r=M.records[id];if not r or M.applied[id] then return end
  local tank=a.ItemTankComponent
  if math.abs(N.fluid.quantity(tank)-r.litres)>.0001 then
   tank:EmptyTank();N.fluid.set(tank,r.litres,T.vehicle.player())
   assert(math.abs(N.fluid.quantity(tank)-r.litres)<.001,'Bottle quantity could not be restored')
  end
  M.applied[id]=true
 end
 local function parts(car,m)
  local parent=car
  if m.parent~='car'then
   local children={};car:GetAttachedActors(children,true,true);parent=nil
   for _,v in ipairs(children)do local a=v:get();if valid(a)and a:IsA(StaticFindObject('/Game/BP/Items/Master/ItemBaseMaster.ItemBaseMaster_C'))and N.guid(a)==m.parent then parent=a;break end end
  end
  if not valid(parent)or not valid(parent.AttachActorOn)then return end
  for _,v in ipairs(parent:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.SceneComponent')))do local c=v:get()
   if valid(c)and c:GetFName():ToString()==m.component then return parent,c end
  end
 end
 function M.tick(now)
  if not next(M.pending)then return end
  if M.wake then M.wake=nil;M.untilTime=now+16 end
  if not M.untilTime or now>M.untilTime or now<(M.nextAt or 0)then return end;M.nextAt=now+1
  local p=T.vehicle.player();if not valid(p)or not p:HasAuthority()or not p.IsLoaded or not p.IsInitialized then return end
  local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
  if game:GetGameInstance(p).IsSaving then return end
  local cars,bottles={},{}
  for _,c in ipairs(FindAllOf('AVS_Template_Vehicle_C')or{})do if valid(c)and c:GetFullName():find(':PersistentLevel.',1,true)then cars[S.guid(c.GuidGarage)]=c end end
  for _,a in ipairs(FindAllOf('GasBarrelGaz_2_C')or{})do if valid(a)and a:GetFullName():find(':PersistentLevel.',1,true)then local id=N.guid(a);if id then bottles[id]=a end end end
  for id,r in pairs(M.pending)do
   local car=cars[r.mount.car];local bottle=bottles[id]
   if valid(bottle)and valid(bottle:GetAttachParentActor())then M.pending[id]=nil
   elseif valid(car)then
    local key=car:GetAddress()
    if not M.cars[key]then M.cars[key]=now end
    if now-M.cars[key]>=6 then
     local parent,component=parts(car,r.mount)
     if valid(component)then
      local created=false
      if not valid(bottle)then
       local loc=component:K2_GetComponentLocation()
       bottle=N.spawn(p,r.variant,{X=loc.X,Y=loc.Y,Z=loc.Z+100},id)
       created=true
      end
      -- A player who already took a recovered loose bottle takes precedence.
      local held=false
      for _,pc in ipairs(FindAllOf('PlayerControllerBase_C')or{})do if valid(pc)and valid(pc.PlayerControlled)then local hand={};pc:GetItemInHand(hand);if same(hand.Item,bottle)then held=true end end end
      if not held then
       local m=r.mount
       local ok,e=pcall(function()
        parent.AttachActorOn:AttachActorOn({[actorKey]=bottle,[compKey]=component,[trKey]=m.transform,[dynamic]=m.dynamic,[buried]=m.buried,[tick]=m.tick,[attachable]=m.attachable},false)
        parent.AttachActorOn:OnRep_ActorsAttached()
        assert(same(N.parent(bottle),car),'Native mount restore refused')
       end)
       if not ok then if created and valid(bottle)then bottle:K2_DestroyActor();M.applied[id]=nil end;error(e)end
      end
      M.pending[id]=nil
     end
    end
   end
  end
 end
 function M.reset()M.records={};M.pending={};M.cars={};M.applied={};M.nextAt=0;M.untilTime=nil;M.wake=nil end
 NotifyOnNewObject('/Game/AVS_Template/Template/AVS_Template_Vehicle.AVS_Template_Vehicle_C',function()if next(M.pending)then M.wake=true end end)
 return M
end
