return function(T)
 local function legacyOwner()
  local mods=T.root..'/..'
  local main=T.storage.read(mods..'/BeyondApocalypse/Scripts/main.lua',256*1024)
  if not main or not main:find('M.nitrous=dofile',1,true) then return false end
  local list=T.storage.read(mods..'/mods.txt') or ''
  local enabled=('\n'..list):match('\n%s*BeyondApocalypse%s*:%s*(%d)')
  if enabled then return enabled=='1' end
  return T.storage.read(mods..'/BeyondApocalypse/enabled.txt')~=nil
 end
 -- Users may update the two mods in either order. Only one controller may
 -- consume the native fluid or apply force to the driving client.
 if legacyOwner() then return dofile(T.root..'/Scripts/nitrous/legacy_adapter.lua')(T) end
 T.storage.native('import_nitrous_saves')
 local H={GetPlayerController=T.vehicle.pc,GetPlayer=T.vehicle.player}
 function H.IsPauseMenu(pc)
  local menu=pc['BP Menu Component']
  if not T.valid(menu) then menu=pc.BP_MenuComponent end
  return T.valid(menu) and menu:GetIsPauseMenu()
 end
 local function log(message) print('[Beyond Tuning] '..message..'\n') end
 local N=dofile(T.root..'/Scripts/nitrous/controller.lua')(T,H,log)
 local serviceTick=N.tick
 function N.tick(now)
  local p=T.vehicle.player()
  if T.valid(p) then serviceTick(p,now);if not p:HasAuthority()or #N.orders.queue>0 then N.orders.tick(T.vehicle.pc())end end
 end
 function N.status(car)
  local r=T.valid(car) and N.cars[car:GetFullName()]
  if not r or #r.items==0 then return 'No bottle fitted',false end
  return ('%.2f / %g L'):format(r.litres,r.capacity),true
 end
 function N.buy(pc,id,complete)
  assert(T.valid(pc) and pc:HasAuthority() and T.valid(pc.PlayerControlled),'Host unavailable')
  local d=assert(type(id)=='number' and N.catalog[id],'Unknown bottle')
  local function deliver(at)
   local actor=N.spawn(pc.PlayerControlled,id,at)
   local ok,err=pcall(function()
    T.delivery.place(actor,actor.TankMesh,at)
    local r=N.items[actor:GetFullName()]
    assert(r and T.valid(r.visual) and r.visual:IsVisible() and N.fluid.quantity(actor.ItemTankComponent)>.001,'Bottle unavailable')
   end)
   if not ok then N.discard(actor);error(err) end
   return d.name..' delivered beside you'
  end
  if complete then complete(true,deliver(T.delivery.spot(pc)));return end
  assert(pc:IsLocalPlayerController(),'Both players need the updated bottle shop to use the buyer wallet')
  return T.delivery.purchase(pc,d.price,deliver)
 end
 N.orders=dofile(T.root..'/Scripts/owner_shop.lua')({
  protocol='BTBottle1',valid=T.valid,game=StaticFindObject('/Script/Engine.Default__GameplayStatics'),pc=T.vehicle.pc,
  path=function(name)return T.root..'/state/'..name end,note=T.delivery.note,
  price=function(item)local d=N.catalog[tonumber(item)];return d and d.price end,
  deliver=function(pc,item,complete)return N.buy(pc,tonumber(item),complete)end
 })
 local reset=N.reset
 function N.reset()N.orders.reset();reset()end
 function N.order(id)
  local pc=T.vehicle.pc()
  if pc:HasAuthority() then
   local ok,result=pcall(N.buy,pc,id)
   T.delivery.note(ok and result or tostring(result):gsub('^.-:%d+: ',''))
  else
   assert(T.network.connected,'Host unavailable')
   N.orders.order(tostring(id))
  end
 end
 return N
end
