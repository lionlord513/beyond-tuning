-- Native garage currency belongs to the owning client. Calling TryPurchase on
-- a remote controller on the host still addresses the host's local garage.
-- Follow the native shop split: owner pays, host validates/creates the item.
return function(T,L)
 local P={};local S,N,J,V=T.storage,T.network,T.json,T.vehicle;local valid=T.valid
 local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
 local clientPath=T.root..'/state/laptop-payment.json'
 local function hex(v)return type(v)=='string'and #v==32 and v:match('^[%da-f]+$')end
 local function uuid()return S.guid(StaticFindObject('/Script/Engine.Default__KismetGuidLibrary'):NewGuid())end
 local function read(path)return S.recover(path,J.decode)end
 local function write(path,r)S.write(path,J.encode(r))end
 local function save()write(clientPath,P.pending)end
 local function funds(pc)local r={};pc:GetCurrentMoney(r);assert(type(r.NewParam)=='number','Wallet unavailable');return r.NewParam end
 local function terminal(r)return r.state=='delivered'or r.state=='refunded'or r.state=='cancelled'end
 local function clock()return game:GetRealTimeSeconds(V.player())end
 local function persistWallet(pc)
  local garage=pc.BP_GarageComp;assert(valid(garage)and garage.IsInit,'Wallet unavailable');garage:SAVE()
 end
 local function owner(pc,identity)
  local steam=StaticFindObject('/Script/SteamCorePro.Default__SteamUtilities')
  if valid(steam)and valid(pc.PlayerState)then
   local id=steam:BreakSteamID(steam:GetSteamIdFromPlayerState(pc.PlayerState));id=type(id)=='string'and id or id:ToString()
   if id:match('^%d+$')and #id>=15 and not id:match('^0+$')then return id end
  end
  return 'offline-'..identity
 end
 local function send(action)
  local r=P.pending;N.call({op='laptopOrder',action=action,id=r.id,identity=r.identity,world=r.world});P.retryAt=clock()+3
 end
 local function finish(message)
  L.orderPending=nil;T.ui.orderStatus(message)
 end
 function P.order()
  assert(N.connected and N.laptopShop==2,'Update Beyond Tuning to 1.2.5 or newer on the host and client')
  if not P.loaded then P.pending=read(clientPath);P.loaded=true end
  assert(not P.pending or terminal(P.pending),'Previous laptop order is still pending')
  assert(hex(S.world),'Waiting for world identity')
  local identityPath=T.root..'/state/laptop-buyer.json';local identity=read(identityPath)
  if not identity or not hex(identity.token)then identity={token=uuid()};write(identityPath,identity)end
  P.pending={schema=1,id=uuid(),identity=identity.token,world=S.world,state='quote'};save()
  L.orderPending=true;send('quote');T.ui.orderStatus('Ordering laptop…')
 end
 function P.server(pc,p)
  assert(pc:HasAuthority()and valid(pc.PlayerControlled)and pc.PlayerControlled.IsLoaded,'Player unavailable')
  assert(hex(p.id)and hex(p.identity)and hex(p.world)and p.world==S.world,'Invalid laptop order')
  assert(p.action=='quote'or p.action=='paid'or p.action=='cancel','Invalid order action')
  local peer=N.peers[pc:GetAddress()];assert(peer,'Reconnect to the host')
  assert(not peer.laptopIdentity or peer.laptopIdentity==p.identity,'Laptop buyer identity changed')
  peer.laptopIdentity=p.identity
  local path=T.root..'/state/laptop-order-'..p.world..'-'..p.id..'.json'
  local r=read(path);local who=owner(pc,p.identity)
  if not r then
   assert(p.action=='quote','Laptop order was not authorized')
   assert(not L.data[p.id],'Laptop order identity already exists')
   assert(clock()>=(peer.laptopOrderAt or 0),'Please wait before ordering again');peer.laptopOrderAt=clock()+2
   T.delivery.spot(pc)
   r={schema=1,id=p.id,owner=who,identity=p.identity,world=S.world,price=L.price,state='quote'};write(path,r)
  end
  assert(r.owner==who and r.identity==p.identity,'Laptop order belongs to another player')
  local function reply()
   N.send(pc,{op='laptopPayment',id=r.id,world=r.world,state=r.state,price=r.price,message=r.message})
  end
  if p.action=='cancel'and r.state=='quote'then r.state='cancelled';r.message='Laptop order cancelled';write(path,r)
  elseif p.action=='paid'and(r.state=='quote'or r.state=='delivering')then
   -- L.data is written by spawn before a success reply. A lost reply or an
   -- interrupted transaction must never create a second physical laptop.
   if L.data[r.id]then r.state='delivered';r.message='Tuner Laptop delivered beside you'
   else
    r.state='delivering';write(path,r)
    local ok,result=pcall(function()return L.spawn(pc,T.delivery.spot(pc),nil,r.id)end)
    if ok then r.state='delivered';r.message=result
    else r.state='refund';r.message=tostring(result):gsub('^.-:%d+: ',''):sub(1,140)end
   end
   write(path,r)
  end
  reply()
 end
 local function settle()
  local r=P.pending;local pc=V.pc();assert(valid(pc)and pc:IsLocalPlayerController(),'Local wallet required')
  if r.state=='charging'then
   local balance=funds(pc)
   if balance==r.before-r.price then r.state='paid';save()
   elseif balance==r.before then
    local paid={};pc:TryPurchase(r.price,true,paid)
    if paid.Success then r.state='paid';save()
    else r.state='cancelled';save();send('cancel');finish('Not enough money');return end
   else
    -- A crash plus unrelated wallet changes is ambiguous. Keep the journal,
    -- do not guess a second debit or give away an unverified purchase.
    finish('Laptop payment needs review. The saved order has been kept.');return
   end
  end
  if r.state=='refunding'then
   local balance=funds(pc)
   if balance==r.refundBefore then pc:AddMoney(r.price);persistWallet(pc)
   elseif balance~=r.refundBefore+r.price then finish('Laptop refund needs review. The saved order has been kept.');return end
   r.state='refunded';save();finish('Laptop order failed. Your $'..r.price..' was refunded.');return
  end
  if r.state=='paid'then send('paid')end
 end
 function P.client(p)
  local r=P.pending;if not r or p.id~=r.id or p.world~=r.world or terminal(r)then return end
  if p.state=='quote'and r.state=='quote'then
   assert(p.price==L.price,'Laptop price changed. Order cancelled before payment')
   r.price=p.price;r.before=funds(V.pc());r.state='charging';save();settle()
  elseif p.state=='quote'and r.state=='paid'then send('paid')
  elseif p.state=='delivered'and r.state=='paid'then r.state='delivered';save();finish(p.message or'Tuner Laptop delivered beside you')
  elseif(p.state=='refund'or p.state=='cancelled')and r.state=='paid'then
   r.refundBefore=funds(V.pc());r.state='refunding';save();settle()
  elseif p.state=='cancelled'and r.state=='quote'then r.state='cancelled';save();finish(p.message or'Laptop order cancelled')end
 end
 function P.tick()
  if not N.connected or N.laptopShop~=2 or not S.world then return end
  local pc=V.pc();if not valid(pc)or pc:HasAuthority()then return end
  if not P.loaded then P.pending=read(clientPath);P.loaded=true end
  local r=P.pending;if not r or terminal(r)or r.world~=S.world or clock()<(P.retryAt or 0)then return end
  L.orderPending=true;P.retryAt=clock()+3
  if r.state=='quote'then send('quote')else settle()end
 end
 return P
end
