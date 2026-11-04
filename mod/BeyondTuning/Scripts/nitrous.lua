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
  if T.valid(p) then serviceTick(p,now) end
 end
 function N.status(car)
  local r=T.valid(car) and N.cars[car:GetFullName()]
  if not r or #r.items==0 then return 'No bottle fitted',false end
  return ('%.2f / %g L'):format(r.litres,r.capacity),true
 end
 function N.buy(pc,id)
  assert(T.valid(pc) and pc:HasAuthority() and T.valid(pc.PlayerControlled),'Host unavailable')
  local d=assert(type(id)=='number' and N.catalog[id],'Unknown bottle')
  local paid={}
  pc:TryPurchase(d.price,false,paid)
  assert(paid.Success,'Not enough money')
  local ok,actor=pcall(N.spawn,pc.PlayerControlled,id)
  if not ok then pc:AddMoney(d.price);error(actor) end
  return d.name..' delivered'
 end
 function N.order(id)
  local pc=T.vehicle.pc()
  if pc:HasAuthority() then T.status(N.buy(pc,id))
  else T.network.call({op='buyNitrous',variant=id}) end
 end
 return N
end
