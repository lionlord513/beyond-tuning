return function(T)
 local L={items={},actors={},data={},helpers={},transient={},dirty=true,price=250};local valid=T.valid
 local S,V,N,J=T.storage,T.vehicle,T.network,T.json
 local visual=dofile(T.root..'/Scripts/laptop_visual.lua')(T);L.visual=visual
 local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
 local scene=StaticFindObject('/Script/Engine.SceneComponent')
 local meshClass=StaticFindObject('/Script/Engine.StaticMeshComponent')
 local colliderClass=StaticFindObject('/Script/ProceduralMeshComponent.ProceduralMeshComponent')
 local identity={Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
 local carrierPath='/Game/BP/Items/Master/AttachableMaster.AttachableMaster_C'
 local helperPath='/Game/BP/Items/Master/ItemSavableMaster.ItemSavableMaster_C'
 local function same(a,b)return valid(a)and valid(b)and a:GetAddress()==b:GetAddress()end
 local function marker(a)
  for _,v in ipairs(a:K2_GetComponentsByClass(scene))do local c=v:get();local id=c.AttachSocketName:ToString():match('^BT_Laptop_(%x+)$');if id and#id==32 then return id,c end end
 end
 local function actorId(a)return S.guid(a.GuidUnique)end
 function L.attached(r)return valid(r.actor)and r.actor:isAttachedFunction()end
 local function takeName(r)return L.attached(r)and'Remove'or'Take'end
 function L.persist()
  assert(S.world,'Waiting for world save identity')
  S.write(T.root..'/state/laptops-'..S.world..'.json',J.encode({schema=1,items=L.data}))
 end
 function L.sync(pc)
  for id,data in pairs(L.data)do N.send(pc,{op='laptops',id=id,closed=data.closed})end
 end
 local function broadcast(id)
  for _,peer in pairs(N.peers)do if valid(peer.pc)then N.send(peer.pc,{op='laptops',id=id,closed=L.data[id].closed})end end
 end
 function L.receive(p)
  assert(type(p.id)=='string'and#p.id==32 and p.id:match('^%x+$'),'Invalid laptop identity')
  L.data[p.id]={closed=p.closed==true};local r=L.items[p.id]
  if r then L.fold(r,p.closed==true)else L.dirty=true;L.discoverUntil=game:GetTimeSeconds(V.player())+12 end
 end
 local function configureCarrier(a,id)
  local c=a.RootMeshComponent
  if not valid(c)then local _,tag=marker(a);local parent=valid(tag)and tag:GetAttachParent();if valid(parent)and parent:IsA(colliderClass)then c=parent end end
  if not valid(c)then
   c=a:AddComponentByClass(colliderClass,true,identity,false);assert(valid(c),'Laptop collision unavailable')
   c:K2_AttachToComponent(a.DefaultSceneRoot,FName('None'),0,0,0,false)
   c:SetIsReplicated(true)
  end
  -- A real 35 x 40 x 3 cm convex body at unit scale. Native mounting and saves
  -- can reset scale without inflating the collision or separating the hinge.
  if not L.colliders then L.colliders={}end
  if not L.colliders[c:GetAddress()]then
   local vertices={};for _,z in ipairs({-1.5,1.5})do for _,y in ipairs({-20,20})do for _,x in ipairs({-17.5,17.5})do vertices[#vertices+1]={X=x,Y=y,Z=z}end end end
   c.bUseComplexAsSimpleCollision=false;c:CreateMeshSection(0,vertices,{0,2,1,1,2,3,4,5,6,5,7,6,0,1,4,1,5,4,2,6,3,3,6,7,0,4,2,2,4,6,1,3,5,3,7,5},{},{},{},{},false)
   c:ClearCollisionConvexMeshes();c:AddCollisionConvexMesh(vertices);L.colliders[c:GetAddress()]=true
  end
  c:SetCollisionProfileName(FName('PhysicsActor'),true)
  a.RootMeshComponent=c;a:SetActorScale3D({X=1,Y=1,Z=1});c:SetWorldScale3D({X=1,Y=1,Z=1});a.BaseRelativeScale={X=1,Y=1,Z=1}
  c:SetVisibility(false,false);c:SetHiddenInGame(true,false);c:SetCastShadow(false)
  c:SetMassOverrideInKg(FName('None'),3,true)
  a.CanBeAttachedToTheCar=true;a.CanBeInBackpack=true;a.OvverideMass=3;a.BaseMass=3
  if valid(a.AttachableComponent)then a.AttachableComponent:SetComponentTickEnabled(false)end
  return c
 end
 local function mark(a,id)
  local old=marker(a);if old==id then return end
  local c=a:AddComponentByClass(scene,true,identity,false)
  c:K2_AttachToComponent(a.RootMeshComponent,FName('BT_Laptop_'..id),0,0,0,false)
  c:SetVisibility(false,false);c:SetComponentTickEnabled(false);c:SetIsReplicated(true);a:ForceNetUpdate()
 end
 local function inert(a)
  a:SetActorTickEnabled(false)
  for _,v in ipairs(a:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.ActorComponent')))do local c=v:get();c:SetComponentTickEnabled(false)end
 end
 local function box(a,parent,scale,position)
  local c=a:AddComponentByClass(meshClass,true,identity,false)
  c:SetStaticMesh((LoadAsset('/Engine/BasicShapes/Cube.Cube')));c:K2_AttachToComponent(parent,FName('None'),0,0,0,false)
  c:SetRelativeScale3D(scale);c:K2_SetRelativeLocation(position,false,{},true)
  c:SetVisibility(false,false);c:SetHiddenInGame(true,false);c:SetCastShadow(false);c:SetSimulatePhysics(false)
  c:SetCollisionResponseToAllChannels(0);c:SetCollisionResponseToChannel(3,2);c:SetCollisionResponseToChannel(0,2);c:SetCollisionEnabled(1);c:SetGenerateOverlapEvents(false)
  return c
 end
 function L.helper(r)
  local a=r.actor;local tr=a:GetTransform();tr.Scale3D={X=1,Y=1,Z=1}
  local h=game:BeginDeferredActorSpawnFromClass(a,LoadAsset(helperPath),tr,1,nil,0);assert(valid(h),'Laptop interaction unavailable')
  game:FinishSpawningActor(h,tr,0);h:SetReplicates(false);inert(h)
  h:K2_AttachToComponent(r.lid,FName('None'),0,0,0,false)
  h:K2_SetActorRelativeLocation({X=0,Y=0,Z=0},false,{},true)
  h:K2_SetActorRelativeRotation({Pitch=0,Yaw=0,Roll=0},false,{},true)
  h:SetActorRelativeScale3D({X=1,Y=1,Z=1})
  r.helper=h;r.helperName=h:GetFullName();L.helpers[h:GetAddress()]=r;L.transient[h:GetAddress()]=r.helperName
  if valid(h.ItemSaver)then h.ItemSaver.SaveOnDistance=false end
  -- Left-click uses only the open screen; the lid forwards pickup to the body.
  -- Right-click on either interaction surface opens/closes the physical lid.
  r.lidHit=box(h,h.RootComponent,{X=.023,Y=.40,Z=.34},{X=8.5,Y=0,Z=15.5})
  r.screenHit=box(h,h.RootComponent,{X=.024,Y=.313,Z=.237},{X=8.1,Y=0,Z=16.4})
  r.lidHit:K2_SetRelativeRotation({Pitch=-29,Yaw=0,Roll=0},false,{},true)
  r.screenHit:K2_SetRelativeRotation({Pitch=-29,Yaw=0,Roll=0},false,{},true)
 end
 function L.fold(r,closed)
  if closed then
   if L.active==r then L.close()end
   if L.waiting and L.waiting.id==r.id then L.waiting=nil end
  end
  visual.fold(r,closed)
  if valid(r.screenHit)then r.screenHit:SetCollisionEnabled(closed and 0 or 1)end
  if valid(r.actor)and r.actor:HasAuthority()then r.actor:ForceNetUpdate()end
 end
 function L.skin(a,id)
  local r=L.items[id];if r and same(r.actor,a)and valid(r.base)then return r end
  if r then if valid(r.actor)then L.actors[r.actor:GetAddress()]=nil end;if valid(r.helper)then L.helpers[r.helper:GetAddress()]=nil;r.helper:K2_DestroyActor()end;visual.destroy(r)end
  local c=configureCarrier(a,id);if a:HasAuthority()then mark(a,id)end;r=visual.create(a);r.id=id;r.colliderAddress=c:GetAddress();L.items[id]=r;L.actors[a:GetAddress()]=r
  L.helper(r);L.fold(r,L.data[id]and L.data[id].closed or false)
  local path=T.root..'/state/laptop-'..id..'.png'
  if S.read(path,4*1024*1024)then local tex=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(a,path);if valid(tex)then r.screenMaterial:SetTextureParameterValue(FName('SlateUI'),tex)end end
  return r
 end
 function L.buy(pc)
  assert(valid(pc)and pc:HasAuthority(),'Laptop purchase must be processed by the host')
  assert(S.world,'Save your world before ordering a laptop')
  local p=pc.PlayerControlled;assert(valid(p),'Player unavailable')
  local paid={};pc:TryPurchase(L.price,false,paid);assert(paid.Success,'The laptop costs $250')
  local a
  local ok,e=pcall(function()
   local at=p:K2_GetActorLocation();local f=p:GetActorForwardVector()
   local tr={Translation={X=at.X+f.X*100,Y=at.Y+f.Y*100,Z=at.Z+35},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
   a=game:BeginDeferredActorSpawnFromClass(p,LoadAsset(carrierPath),tr,1,nil,0);assert(valid(a),'Laptop spawn failed')
   local id=actorId(a);configureCarrier(a,id);game:FinishSpawningActor(a,tr,0)
   a:K2_SetActorLocation(tr.Translation,false,{},true)
   a.RootMeshComponent:K2_SetWorldLocation(tr.Translation,false,{},true)
   a.RootMeshComponent:SetPhysicsLinearVelocity({X=0,Y=0,Z=0},false,FName('None'))
   a:ForceRepStateItem()
   -- BeginPlay assigns the final persistent GUID.
   local final=actorId(a);mark(a,final)
   L.data[final]={closed=false};L.persist();L.skin(a,final);broadcast(final)
   a:FlushNetDormancy();a:ForceNetUpdate()
  end)
  if not ok then if valid(a)then a:K2_DestroyActor()end;pc:AddMoney(L.price);error(e)end
  return 'Laptop delivered beside you. Right-click the lid to open/close; left-click the closed laptop to pick it up.'
 end
 function L.order()
  local pc=V.pc();if pc:HasAuthority()then T.status(L.buy(pc))else assert(N.connected,'Host needs Beyond Tuning');N.call({op='laptop',action='buy'})end
 end
 function L.disconnect(pc)
  local address=pc:GetAddress()
  for _,r in pairs(L.items)do if r.users then r.users[address]=nil;if not next(r.users)and valid(r.proxy)then r.proxy:K2_DestroyActor();r.proxy=nil end end end
 end
 function L.request(pc,p)
  if p.action=='buy'then N.send(pc,{op='notice',message=L.buy(pc)});return end
  local r=assert(L.items[p.id],'Laptop unavailable');assert(valid(r.actor),'Laptop unavailable')
  assert(p.action=='close'or valid(pc.PlayerControlled)and pc.PlayerControlled:GetDistanceTo(r.actor)<600,'Move closer to the laptop')
  if p.action=='fold'then L.data[p.id].closed=not L.data[p.id].closed;L.persist();L.fold(r,L.data[p.id].closed);broadcast(p.id)
  elseif p.action=='pickup'then
   local held={};pc:GetItemInHand(held);assert(not valid(held.Item)or same(held.Item,r.actor),'Put down the item in your hands first')
   if not same(held.Item,r.actor)then
    local a=r.actor;local mesh=a.RootMeshComponent
    -- Native secondary is Remove for attached items; native primary is Take
    -- for loose items. Let the game own attachment lists, hands and physics.
    if L.attached(r)then a:ExecuteSecondaryAction(true,pc,mesh,a,mesh:K2_GetComponentToWorld())
    else a:ExecutePrimaryAction(true,pc,mesh,a)end
   end
  elseif p.action=='open'then assert(not r.closed,'Open the lid first');L.createProxy(r);r.users=r.users or{};r.users[pc:GetAddress()]=true;N.send(pc,{op='laptopOpened',id=r.id})
  elseif p.action=='close'then
   if r.users then r.users[pc:GetAddress()]=nil end
   if not r.users or not next(r.users)then if valid(r.proxy)then r.proxy:K2_DestroyActor()end;r.proxy=nil end
  end
 end
 function L.toggle(r)
  if r.actor:HasAuthority()then L.request(V.pc(),{id=r.id,action='fold'})else N.call({op='laptop',id=r.id,action='fold'})end
 end
 function L.pickup(r)
  if r.actor:HasAuthority()then L.request(V.pc(),{id=r.id,action='pickup'})else N.call({op='laptop',id=r.id,action='pickup'})end
 end
 function L.createProxy(r)
  if valid(r.proxy)then return r.proxy end
  local p=V.player();local tr=r.actor:GetTransform();tr.Scale3D={X=1,Y=1,Z=1}
  local pc=game:BeginDeferredActorSpawnFromClass(p,LoadAsset('/Game/BP/EbaySystem/BP_eBayPC.BP_eBayPC_C'),tr,1,nil,0)
  assert(valid(pc),'Native desktop unavailable');pc.FirstTimeOpen=true;pc.QuestGenerated=true;pc['Light Visibility']=false
  local mediaClass=StaticFindObject('/Script/MediaAssets.MediaPlayer');if valid(mediaClass)then pc.MediaPlayer=StaticConstructObject(mediaClass,pc)end
  game:FinishSpawningActor(pc,tr,0);pc:SetReplicates(true);pc:SetActorHiddenInGame(true);pc:SetActorEnableCollision(false);inert(pc)
  L.transient[pc:GetAddress()]=pc:GetFullName();if valid(pc.ItemSaver)then pc.ItemSaver.SaveOnDistance=false end
  local m=pc:AddComponentByClass(scene,true,identity,false);m:K2_AttachToComponent(pc.RootComponent,FName('BT_PC_'..r.id),0,0,0,false);m:SetIsReplicated(true);m:SetComponentTickEnabled(false)
  pc:K2_AttachToComponent(r.actor.RootMeshComponent,FName('None'),1,1,1,false)
  pc:ForceNetUpdate()
  if valid(pc.MediaPlayer)then pc.MediaPlayer:Close()end
  r.proxy=pc;return pc
 end
 function L.open(r)
  assert(not r.closed,'Open the lid first');assert(not L.active,'Close the current computer first')
  if not V.pc():HasAuthority()then N.call({op='laptop',action='open',id=r.id});L.waiting={id=r.id,untilTime=game:GetTimeSeconds(V.player())+8};return end
  local proxy=L.createProxy(r);r.users=r.users or{};r.users[V.pc():GetAddress()]=true;L.show(r,proxy)
 end
 function L.show(r,proxy)
  assert(not r.closed,'Open the lid first')
  local p=V.player();r.pc=V.pc();r.pawn=p;r.proxy=proxy;r.hadDesktop=false
  r.menu=r.pc['BP Menu Component'];if not valid(r.menu)then r.menu=r.pc.BP_MenuComponent end
  if valid(r.menu)then r.oldPause=r.menu.CanOpenPauseMenu end
  L.active=r
  local ok,e=pcall(function()p.AC_EbaySystem['Open PC'](p.AC_EbaySystem,proxy)end)
  if not ok then L.close();error(e)end;L.openPending=true
 end
 function L.cancelCapture()
  local c=L.capture;L.capture=nil
  if c and valid(c.component)then
   pcall(function()c.component:SetComponentTickEnabled(false)end)
   pcall(function()c.component:SetWidget(nil)end)
   pcall(function()c.component:K2_DestroyComponent(c.r.actor)end)
  end
 end
 function L.freeze(r,widget)
  if not valid(widget)then return end
  L.cancelCapture()
  local width,height=1400,900
  if T.ui.opened and valid(widget.CP_RSPartWindow)then
   local panel=widget.CP_RSPartWindow;panel.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=0,Y=0}});panel.Slot:SetPosition({X=0,Y=0});panel:SetRenderScale({X=1,Y=1})
  end
  local wc=r.actor:AddComponentByClass(StaticFindObject('/Script/UMG.WidgetComponent'),true,identity,false)
  L.capture={r=r,component=wc,frames=0,width=width,height=height}
  wc:SetDrawSize({X=width,Y=height});wc:SetManuallyRedraw(true);wc:SetTickWhenOffscreen(true);wc:SetCollisionEnabled(0)
  wc:SetTickMode(0);wc:SetComponentTickEnabled(true);wc:SetVisibility(true,false);wc:SetHiddenInGame(false,false)
  wc:K2_SetWorldLocation({X=0,Y=0,Z=-50000},false,{},true);widget:RemoveFromParent();wc:SetWidget(widget);wc:RequestRedraw()
 end
 function L.close()
  local r=L.active;if not r then return end
  -- Exit is unconditional. Snapshot/native-desktop failures must never strand
  -- the player in UI-only input or prevent the remaining cleanup steps.
  L.active=nil;L.waiting=nil;L.openPending=false
  r.session={app=T.ui.opened,mode=T.ui.mode,menu=T.ui.menu}
  local widget=T.ui.opened and T.ui.ui or T.ui.hud;local hud=T.ui.hud;local app=T.ui.ui
  local pc=valid(r.pc)and r.pc or V.pc();local p=valid(r.pawn)and r.pawn or V.player()
  local function attempt(fn)local ok,e=pcall(fn);if not ok then print('[Beyond Tuning] Laptop exit: '..tostring(e)..'\n')end;return ok end
  if not attempt(function()if valid(r.actor)then L.freeze(r,widget)end end)then L.cancelCapture()end
  T.ui.opened=false
  local ebay=valid(p)and p.AC_EbaySystem
  if valid(ebay)then
   attempt(function()ebay.InBuyMenu=false;ebay:OnRep_InBuyMenu()end)
   attempt(function()ebay:DestroyHUD()end)
  end
  attempt(function()if valid(app)then app:RemoveFromParent()end end)
  attempt(function()if valid(hud)then hud:RemoveFromParent()end end)
  attempt(T.ui.reset)
  if valid(pc)then
   attempt(function()pc:ResetIgnoreLookInput()end);attempt(function()pc:ResetIgnoreMoveInput()end)
   attempt(function()if valid(p)then p:EnableInput(pc)end end)
   attempt(function()pc.bShowMouseCursor=false;StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):SetInputMode_GameOnly(pc,true)end)
   attempt(function()if valid(r.menu)then r.menu.CanOpenPauseMenu=r.oldPause end end)
   attempt(function()if pc:HasAuthority()then L.request(pc,{id=r.id,action='close'})else N.call({op='laptop',id=r.id,action='close'})end end)
  end
 end
 function L.install()
  if L.hooks then return end;LoadAsset(helperPath);L.hooks={}
  local base='/Game/BP/Items/Master/ItemSavableMaster.ItemSavableMaster_C:'
  L.hooks[1]={RegisterHook(base..'ExecutePrimaryAction',function(ctx,pressed,pc,component)
   local a=ctx:get();local r=valid(a)and L.helpers[a:GetAddress()]
   if r and pressed:get()and same(pc:get(),V.pc())then local screen=same(component:get(),r.screenHit);T.enqueue(function()if screen and not r.closed then L.open(r)else L.pickup(r)end end)end
  end)}
  L.hooks[2]={RegisterHook(base..'CanExecuteActionInVehicle',function(ctx,pc,primary,out)if L.helpers[ctx:get():GetAddress()]then out:set(true)end end)}
  L.hooks[3]={RegisterHook(base..'ForcePrimaryAction',function(ctx,pc,out)if L.helpers[ctx:get():GetAddress()]then out:set(true)end end)}
  L.hooks[4]={RegisterHook(base..'GetPrimaryActionName',function(ctx,out)local r=L.helpers[ctx:get():GetAddress()];if r then out:set(FText(r.closed and takeName(r)or('Screen: use computer / Lid: '..takeName(r))))end end)}
  L.hooks[5]={RegisterHook(base..'GetName',function(ctx,out)if L.helpers[ctx:get():GetAddress()]then out:set(FText('Tuner Laptop'))end end)}
  L.hooks[6]={RegisterHook(base..'SaveObject',function(ctx,out)
   local a=ctx:get();if L.transient[a:GetAddress()]==a:GetFullName()then local values=out:get();values:Empty()end
  end)}
  local function interaction(ctx,pressed,pc,primary)
   local a=ctx:get();local id=valid(a)and marker(a);if not id or not L.items[id]then return end;local caller=pc:get()
   local r=L.items[id];local remove=primary and pressed:get()and r.closed and L.attached(r)
   T.enqueue(function()
    if not valid(a)then return end
    if remove and valid(caller)then
     if a:HasAuthority()then L.request(caller,{id=id,action='pickup'})elseif same(caller,V.pc())then L.pickup(r)end
    end
    local held={};if valid(caller)then caller:GetItemInHand(held)end
    local inHand=same(held.Item,a);if valid(a.AttachableComponent)then a.AttachableComponent:SetComponentTickEnabled(inHand)end
    if valid(a:GetAttachParentActor())and not inHand then a:SetActorTickEnabled(false)end
   end)
  end
  local attach='/Game/BP/Items/Master/AttachableMaster.AttachableMaster_C:'
  L.hooks[7]={RegisterHook(attach..'ExecutePrimaryAction',function(ctx,pressed,pc)interaction(ctx,pressed,pc,true)end)}
  L.hooks[8]={RegisterHook(attach..'ExecuteSecondaryAction',function(ctx,pressed,pc)interaction(ctx,pressed,pc,false)end)}
  L.hooks[9]={RegisterHook('/Game/BP/Components/AttachActorOn.AttachActorOn_C:OnRep_ActorsAttached',function()
   for _,r in pairs(L.items)do if valid(r.actor)and valid(r.actor:GetAttachParentActor())then
    r.actor:SetActorTickEnabled(false);if valid(r.actor.AttachableComponent)then r.actor.AttachableComponent:SetComponentTickEnabled(false)end
   end end
  end)}
  L.hooks[10]={RegisterHook(base..'ExecuteSecondaryAction',function(ctx,pressed,pc)
   local a=ctx:get();local r=valid(a)and L.helpers[a:GetAddress()]
   if r and pressed:get()and same(pc:get(),V.pc())then T.enqueue(function()L.toggle(r)end)end
  end)}
  L.hooks[11]={RegisterHook(base..'GetSecondaryActionName',function(ctx,out)
   local r=L.helpers[ctx:get():GetAddress()];if r then out:set(FText(r.closed and'Open lid'or'Close lid'))end
  end)}
  L.hooks[12]={RegisterHook(attach..'ForcePrimaryAction',function(ctx,pc,out)
   local r=L.actors[ctx:get():GetAddress()];if r and r.closed then out:set(true)end
  end)}
  L.hooks[13]={RegisterHook(attach..'GetPrimaryActionName',function(ctx,out)
   local r=L.actors[ctx:get():GetAddress()];if r and r.closed then out:set(FText(takeName(r)))end
  end)}
  L.hooks[14]={RegisterHook('/Game/BP/Items/Master/ItemBaseMaster.ItemBaseMaster_C:GetName',function(ctx,out)
   local a=ctx:get();if L.actors[a:GetAddress()]or(a:GetFullName():match('^AttachableMaster_C ')and L.data[actorId(a)])then out:set(FText('Tuner Laptop'))end
  end)}
  local restore='/Game/BP/Components/BP_InventoryComponent.BP_InventoryComponent_C:GetItemFromSlot'
  L.hooks[15]={RegisterHook(restore,function(ctx,slot,force,position,remove,defer,item)
   local a=item:get();if defer:get()or not valid(a)then return end
   local id=actorId(a);if L.data[id]then L.skin(a,id)end
  end)}
  -- Stored items are destroyed by native inventory. Retire the separate local
  -- hit targets at EndPlay, without polling world items or leaving a ghost lid.
  L.hooks[16]={RegisterHook('/Game/BP/Items/Master/ItemBaseMaster.ItemBaseMaster_C:ReceiveEndPlay',function(ctx)
   local addr=ctx:get():GetAddress();local r=L.actors[addr];if not r then return end
   L.actors[addr]=nil
   if L.colliders then L.colliders[r.colliderAddress]=nil end
   if L.items[r.id]==r then L.items[r.id]=nil end
   if valid(r.proxy)and r.proxy:HasAuthority()then r.proxy:K2_DestroyActor();r.proxy=nil end
   if valid(r.helper)then local h=r.helper:GetAddress();L.helpers[h]=nil;L.transient[h]=nil;r.helper:K2_DestroyActor()end
   if L.active==r then T.enqueue(function()if L.active==r then L.close()end end)end
  end)}
  NotifyOnNewObject(carrierPath,function()L.dirty=true end)
 end
 function L.tick()
  if not S.ready or not S.world then return end;L.install()
  if L.world~=S.world then
   L.world=S.world;local saved=S.recover(T.root..'/state/laptops-'..S.world..'.json',J.decode,1024*1024)
   local incoming=L.data;L.data=saved and saved.items or{};for id,d in pairs(incoming)do L.data[id]=d end;L.dirty=true
  end
  if L.discoverUntil then
   local time=game:GetTimeSeconds(V.player());local missing=false;for id in pairs(L.data)do if not L.items[id]then missing=true;break end end
   if not missing or time>L.discoverUntil then L.discoverUntil=nil elseif time>=(L.discoverAt or 0)then L.discoverAt=time+.5;L.dirty=true end
  end
  if L.dirty then
   L.dirty=false
   for _,a in ipairs(FindAllOf('AttachableMaster_C')or{})do if valid(a)then local id=marker(a);if not id and a:HasAuthority()then local guid=actorId(a);if L.data[guid]then id=guid end end
    if id and L.data[id]then L.skin(a,id)end
   end end
  end
  if L.openPending and L.active then
   L.openPending=false;T.ui.tick();local session=L.active.session
   if session and session.app then T.ui.open();T.ui.mode=session.mode;T.ui.menu=session.menu;T.ui.refresh=true end
  end
  if L.active and not L.openPending then
   local p=V.player();local e=valid(p)and p.AC_EbaySystem;local hud=valid(e)and e.HUDREF
   if not valid(L.active.actor)or not valid(L.active.proxy)then L.close()elseif valid(hud)and hud:IsInViewport()then L.active.hadDesktop=true elseif L.active.hadDesktop then L.close()end
  end
  if L.waiting then
   local w=L.waiting
   if game:GetTimeSeconds(V.player())>w.untilTime then L.waiting=nil;T.status('Laptop desktop did not arrive from the host')else
    for _,a in ipairs(FindAllOf('BP_eBayPC_C')or{})do if valid(a)then
     for _,v in ipairs(a:K2_GetComponentsByClass(scene))do if v:get().AttachSocketName:ToString()=='BT_PC_'..w.id then local r=L.items[w.id];if r then L.waiting=nil;L.show(r,a)end;break end end
    end end
   end
  end
  if L.capture then
   local ok,e=pcall(function()
   local c=L.capture;c.frames=c.frames+1
   if c.flat and c.frames>=c.copyFrame+1 then
    StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ExportRenderTarget(c.r.actor,c.flat,T.root..'/state','laptop-'..c.r.id..'.png')
    L.cancelCapture();return
   end
   if c.frames>=2 then
    local rt=c.component:GetRenderTarget()
    if not valid(rt)and c.frames<10 then c.component:RequestRedraw();return end
    if valid(rt)then
     c.flat=T.draw.target(c.r.actor,c.width,c.height)
     T.draw.paint(c.r.actor,c.flat,{R=0,G=0,B=0,A=1},function(canvas)
      canvas:K2_DrawTexture(rt,{X=0,Y=0},{X=c.width,Y=c.height},{X=0,Y=0},{X=1,Y=1},{R=1,G=1,B=1,A=1},0,0,{X=0,Y=0})
     end)
     c.r.screenMaterial:SetTextureParameterValue(FName('SlateUI'),c.flat);c.copyFrame=c.frames;return
    end
    L.cancelCapture()
   end
   end)
   if not ok then L.cancelCapture();print('[Beyond Tuning] Screen snapshot skipped: '..tostring(e)..'\n')end
  end
 end
 function L.reset()
  if L.active then pcall(L.close)end
  L.cancelCapture()
  for _,r in pairs(L.items)do if valid(r.helper)then r.helper:K2_DestroyActor()end;visual.destroy(r)end
  L.items={};L.actors={};L.data={};L.helpers={};L.colliders={};L.transient={};L.world=nil;L.active=nil;L.capture=nil;L.dirty=true
 end
 return L
end
