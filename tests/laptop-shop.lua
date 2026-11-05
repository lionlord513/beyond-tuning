local source=assert(arg[1]);local J=dofile(assert(arg[2]));local build=dofile(source)
local now,serial=10,0;local queue={};local world=string.rep('a',32)
local game={GetRealTimeSeconds=function()return now end}
local guid={NewGuid=function()serial=serial+1;return {A=0,B=0,C=0,D=serial}end}
StaticFindObject=function(path)if path:find('GameplayStatics')then return game elseif path:find('KismetGuid')then return guid end end
local function valid(o)return type(o)=='table'end
local function storage()
 local files={};return {world=world,files=files,guid=function(g)return ('%08x%08x%08x%08x'):format(g.A,g.B,g.C,g.D)end,
 recover=function(path,decode)return files[path]and decode(files[path])end,write=function(path,text)files[path]=text end}
end
local hs=storage();local hn={peers={}};local hl={data={},price=1000};local hostBalance=0;local spawned=0;local fail=false
local ht={root='host',storage=hs,network=hn,json=J,valid=valid,vehicle={player=function()return{}end},delivery={spot=function()if fail then error('No delivery space')end;return{}end}}
hl.spawn=function(pc,at,site,id)assert(not hl.data[id]);hl.data[id]={owner=pc.id};spawned=spawned+1;return 'delivered'end
local hp=build(ht,hl)
local function endpoint(id,money)
 local e={id=id,balance=money,debits=0,refunds=0,saves=0,storage=storage()}
 e.pc={PlayerControlled={IsLoaded=true},IsLocalPlayerController=function()return true end,HasAuthority=function()return false end,
  GetCurrentMoney=function(_,out)out.NewParam=e.balance end,
  TryPurchase=function(_,price,force,out)assert(force);out.Success=e.balance>=price;if out.Success then e.balance=e.balance-price;e.debits=e.debits+1 end end,
  AddMoney=function(_,n)e.balance=e.balance+n;e.refunds=e.refunds+1 end,
  BP_GarageComp={IsInit=true,SAVE=function()e.saves=e.saves+1 end}}
 e.remote={id=id,PlayerControlled={IsLoaded=true},HasAuthority=function()return true end,GetAddress=function()return id end,
  TryPurchase=function()error('Remote controller touched host wallet')end}
 hn.peers[id]={pc=e.remote}
 local n={connected=true,laptopShop=2,call=function(p)queue[#queue+1]={remote=e.remote,p=p}end}
 e.l={data={},price=1000};e.t={root='client'..id,storage=e.storage,network=n,json=J,valid=valid,
  vehicle={pc=function()return e.pc end,player=function()return{}end},ui={orderStatus=function(s)e.message=s end}}
 e.p=build(e.t,e.l);return e
end
local clients={};hn.send=function(pc,p)queue[#queue+1]={client=clients[pc.id],p=p}end
local function step()
 assert(#queue>0);local item=table.remove(queue,1)
 if item.remote then hp.server(item.remote,item.p)else item.client.p.client(item.p)end
 return item
end
local function pump()local count=0;while #queue>0 do step();count=count+1;assert(count<100)end end
local a,b=endpoint(1,2000),endpoint(2,3500);clients[1]=a;clients[2]=b
a.p.order();b.p.order();pump()
assert(a.balance==1000 and b.balance==2500 and hostBalance==0 and spawned==2)
assert(a.debits==1 and b.debits==1 and not a.l.orderPending and not b.l.orderPending)
local paid={op='laptopOrder',action='paid',id=a.p.pending.id,identity=a.p.pending.identity,world=world}
hp.server(a.remote,paid);hp.server(a.remote,paid);pump();assert(spawned==2 and a.debits==1)
assert(not pcall(hp.server,b.remote,paid),'Another player replayed a purchase')
now=20;local poor=endpoint(3,500);clients[3]=poor;poor.p.order();pump();assert(poor.balance==500 and poor.debits==0 and spawned==2 and not poor.l.orderPending)
local c=endpoint(4,3000);clients[4]=c;c.p.order();step();step();assert(c.balance==2000);fail=true;step();fail=false;local refund=queue[1].p;pump()
c.p.client(refund);assert(c.balance==3000 and c.refunds==1 and c.saves==1 and spawned==2)
local d=endpoint(5,4000);clients[5]=d;d.p.order();step();step();step();assert(spawned==3);queue={}
d.p=build(d.t,d.l);now=30;d.p.tick();pump();assert(d.balance==3000 and d.debits==1 and spawned==3 and d.p.pending.state=='delivered')
-- Recovery of a debit that completed just before its payment-journal update.
local e=endpoint(6,5000);clients[6]=e;e.p.order();step();step();local pending=e.p.pending
pending.state='charging';e.storage.files['client6/state/laptop-payment.json']=J.encode(pending);queue={}
e.p=build(e.t,e.l);now=40;e.p.tick();pump();assert(e.balance==4000 and e.debits==1 and spawned==4)
-- A forged quote cannot charge an unrelated or already-completed order.
a.p.client({id=string.rep('f',32),world=world,state='quote',price=1000});assert(a.debits==1)
return 'PASS laptop shop: two independent wallets, empty host wallet, insufficient funds, duplicate payment, cross-player replay rejection, delivery failure/refund exactly once, lost reply/restart, interrupted debit recovery'
