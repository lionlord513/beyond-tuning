-- Reliable packets use the owning PlayerController's existing Unreal RPCs.
-- Marked packets are consumed before native console/chat processing. Nothing
-- opens a port, executes a console command, or sends public chat messages.
return function(T)
 local N={peers={},remote={},revision={},serial=0,identities={},cars={}};local valid=T.valid
 local V,S,P,J=T.vehicle,T.storage,T.policy,T.json
 local game=StaticFindObject('/Script/Engine.Default__GameplayStatics');local prefix='BT1 '
 local function now()local p=V.player();return valid(p)and game:GetTimeSeconds(p)or 0 end
 local function encode(p)return prefix..J.encode(p)end
 local function host()local pc=V.pc();return valid(pc)and pc:HasAuthority()end
 local identity={Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
 function N.identity(a,m)
  -- Native save GUIDs may differ on clients. A host-created replicated scene
  -- marker carries the host's persistent car + engine identity to every peer.
  local cached=N.identities[a:GetAddress()]
  if cached and valid(cached.motor)and cached.motor:GetAddress()==m:GetAddress()and valid(cached.marker)then N.cars[cached.id]=a;return cached.id end
  local scene=StaticFindObject('/Script/Engine.SceneComponent')
  local wanted=a:HasAuthority()and(S.guid(a.GuidGarage)..':'..S.guid(m.GuidUnique))or nil
  for _,v in ipairs(m:K2_GetComponentsByClass(scene))do local c=v:get();local id=c.AttachSocketName:ToString():match('^BT_Identity_(%x+:%x+)$')
   if id and #id==65 and(not wanted or id==wanted)then N.identities[a:GetAddress()]={motor=m,marker=c,id=id};N.cars[id]=a;return id end
  end
  if wanted and not wanted:find(string.rep('0',32),1,true)then
   local c=m:AddComponentByClass(scene,true,identity,false);assert(valid(c),'Network identity unavailable')
   c:SetVisibility(false,false);c:SetComponentTickEnabled(false);c:K2_AttachToComponent(m.RootComponent,FName('BT_Identity_'..wanted),0,0,0,false);c:SetIsReplicated(true)
   m:FlushNetDormancy();m:ForceNetUpdate();N.identities[a:GetAddress()]={motor=m,marker=c,id=wanted};N.cars[wanted]=a;return wanted
  end
 end
 local function find(id)
  local cached=N.cars[id];if valid(cached)then local m=V.motor(cached);if valid(m)and V.id(cached,m)==id then return cached end end
  for _,a in ipairs(FindAllOf('AVS_Template_Vehicle_C')or{})do if valid(a)and a:GetFullName():find(':PersistentLevel.',1,true)then local m=V.motor(a);if valid(m)and V.id(a,m)==id then return a end end end
 end
 function N.send(pc,p)if valid(pc)then pc:ClientMessage(encode(p),FName('BeyondTuning'),0)end end
 function N.call(p)local pc=V.pc();assert(valid(pc),'Player unavailable');local text=encode(p);assert(#text<=1000,'Tuning request exceeds network limit');pc:ServerExecRPC(text)end
 function N.record(r,request)
  return {op='record',id=r.id,tune=r.tune,base=r.base,revision=N.revision[r.id]or 0,request=request,world=S.world}
 end
 function N.broadcast(r)
  if not r or not r.id then return end;N.revision[r.id]=(N.revision[r.id]or 0)+1
  for _,peer in pairs(N.peers)do if valid(peer.pc)then N.send(peer.pc,N.record(r))end end
 end
 function N.nitrousForce(a,force,base)
  local m=V.motor(a);if not valid(m)then return end;local id=V.id(a,m)
  for _,peer in pairs(N.peers)do local car=valid(peer.pc)and(valid(peer.pc.Vehicle)and peer.pc.Vehicle or peer.driven);if valid(car)and car:GetAddress()==a:GetAddress()then N.send(peer.pc,{op='nitrousForce',id=id,force=force,base=base})end end
 end
 local function refreshRecord(p)
  assert(type(p.id)=='string'and #p.id==65,'Invalid network identity')
  local tune=P.validate(p.tune);local base=P.baseline(p.base)
  N.revision[p.id]=p.revision or 0
  S.world=p.world;S.ready=true;S.error=nil;S.records[p.id]={tune=tune,base=base}
  local a=find(p.id)
  if valid(a)then
   local r=V.records[a:GetFullName()]
   if not r or r.id~=p.id then r=V.ensure(a)end
   if r then r.base=base;r.tune=tune;V.configure(r);if V.last==a then V.current=r end end
  end
  -- A client keeps a recovery cache; the host remains the save authority.
  if S.world then S.persist()end
  if N.pending and p.request==N.pending.serial then
   T.draft=P.copy(tune);T.dirty=false;N.pending=nil
   S.savePreset(tune,T.presetName or'Last multiplayer tune');T.status('Host applied and permanently saved the tune. All players are synchronized.')
  end
  if T.ui then T.ui.refresh=true end
 end
 function N.receiveServer(pc,p)
  assert(valid(pc)and pc:HasAuthority(),'Invalid host endpoint')
  local address=pc:GetAddress();local peer=N.peers[address]or {pc=pc};N.peers[address]=peer;peer.seen=now()
  if p.op=='hello'then
   N.send(pc,{op='ready',world=S.world,version=T.version})
   for id,saved in pairs(S.records)do local a=find(id);local r=valid(a)and V.ensure(a);if r then N.send(pc,N.record(r))else N.send(pc,{op='record',id=id,tune=saved.tune,base=saved.base,world=S.world,revision=0})end end
   if T.laptop then T.laptop.sync(pc)end
  elseif p.op=='ping'then return
  elseif p.op=='apply'then
   assert(now()>=(peer.applyAt or 0),'Wait a moment before applying again');peer.applyAt=now()+.2
   local a=assert(find(p.id),'Car or engine is no longer available');local tune=P.validate(p.tune)
   local r=V.applyTo(a,tune);N.broadcast(r);N.send(pc,N.record(r,p.request))
  elseif p.op=='watch'then
   local changed=peer.watch~=p.id
   peer.watch=type(p.id)=='string'and p.id or nil;peer.watchUntil=now()+5
   local a=peer.watch and changed and find(peer.watch);if valid(a)then local r=V.ensure(a);N.send(pc,N.record(r))end
  elseif p.op=='telemetry'then
   local a=valid(pc.Vehicle)and pc.Vehicle or peer.driven;local m=valid(a)and V.motor(a)
   if valid(m)and V.id(a,m)==p.id then N.acceptTelemetry(p.id,p.data)end
  elseif p.op=='laptop'then assert(T.laptop,'Laptop unavailable');T.laptop.request(pc,p)
  else error('Unknown tuning message')end
 end
 function N.acceptTelemetry(id,t)
  assert(type(t)=='table','Invalid telemetry')
  local clean={};for _,key in ipairs({'rpm','throttle','gear','speed','heat','fuel','redline'})do local n=t[key];if n~=nil then assert(type(n)=='number'and n==n and math.abs(n)<1e7,'Invalid telemetry value');clean[key]=n end end
  N.remote[id]={data=clean,received=now()}
 end
 function N.receiveClient(p)
  if p.op=='ready'then
   if not host()then for _,r in pairs(V.records)do V.restore(r)end;S.records={}end
   N.connected=true;N.helloAt=now()+30;N.world=p.world;S.world=p.world
  elseif p.op=='record'then refreshRecord(p)
  elseif p.op=='error'then N.pending=nil;T.status('Host: '..tostring(p.message))
  elseif p.op=='telemetry'then N.acceptTelemetry(p.id,p.data)
  elseif p.op=='stream'then N.stream=p.id;N.streamUntil=now()+5
  elseif p.op=='nitrousForce'then
   assert(type(p.force)=='number'and p.force>=0 and p.force<1e9 and type(p.base)=='number'and p.base>=0 and p.base<1e9,'Invalid boost force')
   local a=find(p.id);if valid(a)then T.induction.nitrous.remote={actor=a,force=p.force,base=p.base,untilTime=now()+.4}end
  elseif p.op=='laptops'and T.laptop then T.laptop.receive(p)
  elseif p.op=='notice'then T.status(p.message)
  elseif p.op=='laptopOpened'and T.laptop then T.laptop.waiting={id=p.id,untilTime=now()+8}
  end
 end
 function N.request(tune)
  assert(N.connected,'The host needs Beyond Tuning 1.1 or newer. Waiting for its response.')
  local r=assert(V.current,'Sit in a car with an engine first');assert(r.id,'The car needs a persistent identity')
  N.serial=N.serial+1;N.pending={serial=N.serial,at=now()}
  N.call({op='apply',id=r.id,tune=P.validate(tune),request=N.serial});T.status('Sending tune to host; waiting for the saved confirmation...')
 end
 function N.telemetry(id)
  local entry=id and N.remote[id];if entry and now()-entry.received<2 then return P.copy(entry.data)end
 end
 function N.install()
  if N.hooks then return end;N.hooks={}
  N.hooks[1]={RegisterHook('/Script/Engine.PlayerController:ServerExecRPC',function(ctx,msg)
   local text=msg:get():ToString();if text:sub(1,#prefix)~=prefix then return end;msg:set('')
   local pc=ctx:get();if not valid(pc)or not pc:HasAuthority()or#text>1000 then return end
   T.enqueue(function()local ok,e=pcall(function()N.receiveServer(pc,J.decode(text:sub(#prefix+1)))end);if not ok then N.send(pc,{op='error',message=tostring(e):gsub('^.-:%d+: ',''):sub(1,140)})end end)
  end)}
  N.hooks[2]={RegisterHook('/Script/Engine.PlayerController:ClientMessage',function(ctx,msg,kind,life)
   local text=msg:get():ToString();if text:sub(1,#prefix)~=prefix then return end;msg:set('');life:set(0)
   if #text>32000 then return end
   T.enqueue(function()local ok,e=pcall(function()N.receiveClient(J.decode(text:sub(#prefix+1)))end);if not ok then T.status('Tuning synchronization failed: '..tostring(e))end end)
  end)}
  local stateRPC='/Script/DriveBeyondHorizons.DBHPlayerController:Server_ReceiveNetState'
  if valid(StaticFindObject(stateRPC))then N.hooks[3]={RegisterHook(stateRPC,function()end,function(ctx,state,vehicle)
   local pc=ctx:get();local peer=valid(pc)and N.peers[pc:GetAddress()];local a=vehicle:get()
   if peer and valid(a)then peer.driven=a end
  end)}end
 end
 function N.tick()
  N.install();local pc=V.pc();local p=V.player();if not valid(pc)or not valid(p)or not p.IsLoaded then return end
  local time=now();local open=T.ui and T.ui.opened
  if not host()then
   if time>=(N.helloAt or 0)then N.helloAt=time+(N.connected and 30 or 5);N.call({op=N.connected and'ping'or'hello'})end
   if N.connected and(open or N.watching)and time>=(N.watchAt or 0)then
    N.watchAt=time+2;N.watching=open;N.call({op='watch',id=open and V.current and V.current.id or nil})
   end
   if N.pending and time-N.pending.at>10 then N.pending=nil;T.status('No saved confirmation from host. Reconnect before applying again.')end
   if N.stream and time<(N.streamUntil or 0)and time>=(N.sendAt or 0)then
    N.sendAt=time+.1;local a=pc.Vehicle;local m=valid(a)and V.motor(a)
    if valid(m)and V.id(a,m)==N.stream then N.call({op='telemetry',id=N.stream,data=V.readTelemetry(a)})end
   end
  else
   if time<(N.relayAt or 0)then return end;N.relayAt=time+.1
   local watched={};if open and V.current then watched[V.current.id]=V.current.actor end
   for key,peer in pairs(N.peers)do
    if not valid(peer.pc)or time-peer.seen>45 then if T.laptop and valid(peer.pc)then T.laptop.disconnect(peer.pc)end;N.peers[key]=nil
    else
     local car=valid(peer.pc.Vehicle)and peer.pc.Vehicle or peer.driven;local m=valid(car)and V.motor(car);if valid(m)then N.identity(car,m)end
     if peer.watch and time<(peer.watchUntil or 0)then watched[peer.watch]=find(peer.watch)end
    end
   end
   for id,a in pairs(watched)do if valid(a)then
    local telemetry=N.telemetry(id)or V.readTelemetry(a)
    for _,peer in pairs(N.peers)do
     if peer.watch==id and time<(peer.watchUntil or 0)then N.send(peer.pc,{op='telemetry',id=id,data=telemetry})end
     local driven=valid(peer.pc.Vehicle)and peer.pc.Vehicle or peer.driven
     if valid(driven)and driven:GetAddress()==a:GetAddress()and time>=(peer.streamAt or 0)then peer.streamAt=time+2;N.send(peer.pc,{op='stream',id=id})end
    end
   end end
  end
 end
 function N.reset()N.peers={};N.remote={};N.revision={};N.identities={};N.cars={};N.connected=false;N.helloAt=0;N.watchAt=0;N.stream=nil;N.pending=nil end
 return N
end
