-- BA retains activation, safety gates and bottle ownership. This optional adapter
-- adjusts measured consumption and the resulting native force, never the enum.
return function(T)
 local N={tanks={},cars={},available=false};local valid=T.valid
 local game=StaticFindObject('/Script/Engine.Default__GameplayStatics');local scene=StaticFindObject('/Script/Engine.SceneComponent')
 local vehicleClass=StaticFindObject('/Script/VehicleSystemPlugin.VehicleSystemBase')
 local fluidType='FluidType_2_3FEF52254C42CACD89BCB090838F9BEB';local fluidValue='Value_5_22AE2EBC4B5FE6FECBBC58B9FD6C03CC'
 local function quantity(t)return t.FluidMap:Contains(6)and math.max(0,t.FluidMap:Find(6):get())or 0 end
 function N.detect()
  local enum=StaticFindObject('/Game/BP/Items/Enums/FluidTypeEnum.FluidTypeEnum');local yes=false
  if valid(enum)then enum:ForEachName(function(name,id)if id==6 and name:ToString()=='FluidTypeEnum::Nitrous'then yes=true end end)end
  if N.available~=yes and T.ui then T.ui.refresh=true end;N.available=yes;return yes
 end
 local function parent(a)
  local p=a:GetAttachParentActor();for _=1,8 do if not valid(p)then return end;if p:IsA(vehicleClass)then return p end;p=p:GetAttachParentActor()end
 end
 function N.scan()
  if not N.detect()then N.tanks={};N.cars={};return end
  local keep={};local cars={}
  for _,a in ipairs(FindAllOf('GasBarrelGaz_2_C')or{})do if valid(a)then
   local id;for _,v in ipairs(a:K2_GetComponentsByClass(scene))do local c=v:get();id=tonumber(c.AttachSocketName:ToString():match('^BA_Nitrous_([1-6])$'));if id then break end end
   local car=id and parent(a);local tank=a.ItemTankComponent
   if valid(car)and valid(tank)then
    local key=tank:GetAddress();keep[key]=true;local x=N.tanks[key]
    if not x or x.actor:GetAddress()~=a:GetAddress()then x={actor=a,tank=tank,q=quantity(tank)};N.tanks[key]=x end
    x.car=car;x.tier=id<=3 and 1 or 2;x.capacity=({2,5,10})[(id-1)%3+1]
    local ckey=car:GetFullName();local c=cars[ckey]or N.cars[ckey]or{actor=car,serial=0};cars[ckey]=c
    if not c.scanItems then c.items={};c.scanItems=true end;c.items[#c.items+1]=x
   end
  end end
  for key in pairs(N.tanks)do if not keep[key]then N.tanks[key]=nil end end
  for _,c in pairs(cars)do c.scanItems=nil end;N.cars=cars
  local a=T.vehicle.last;local c=valid(a)and cars[a:GetFullName()];local signature={}
  if c then for _,x in ipairs(c.items)do signature[#signature+1]=tostring(x.actor:GetAddress())end end;table.sort(signature);signature=table.concat(signature,',')
  if signature~=N.signature then N.signature=signature;if T.ui and T.ui.menu=='Boost'then T.ui.refresh=true end end
 end
 function N.status(a)
  if not N.available then return 'Unavailable - Beyond Apocalypse not installed',false end
  local c=valid(a)and N.cars[a:GetFullName()];if not c or #c.items==0 then return 'Unavailable - fit a Beyond Apocalypse nitrous bottle',false end
  local q,capacity=0,0;for _,x in ipairs(c.items)do if valid(x.tank)then q=q+quantity(x.tank);capacity=capacity+x.capacity end end
  return ('%d bottle(s) / %.2f of %g L'):format(#c.items,q,capacity),true
 end
 local function set(t,q,p)
  N.writing=true;local ok,e=pcall(function()t:UpdateFluidMap({[fluidType]=6,[fluidValue]=math.max(0,q)},true,false,t,true,false,p,true)end);N.writing=false;if not ok then error(e)end
 end
 function N.install()
  if N.hook or not N.available then return end
  N.hook={RegisterHook('/Game/BP/Items/Components/TankComponent/ItemTankComponent.ItemTankComponent_C:UpdateFluidMap',function(ctx,value,update,add,target,force,sound,player,bypass)
   if N.writing then return end;local t=ctx:get();local x=valid(t)and N.tanks[t:GetAddress()];if not x then return end
   local q=quantity(t);local before=x.q;x.q=q
   local d=value:get();if d[fluidType]~=6 or not update:get()or add:get()or not force:get()or not bypass:get()then return end
   local a=x.car;local record=valid(a)and T.vehicle.records[a:GetFullName()];if not record or not a:HasAuthority()then return end
   local ratio=(record.tune.nitrous or 100)/100;local used=(before or q)-q
   local motor=T.vehicle.motor(a)
   if used<=0 or used>.055 or not valid(a.Driver)or not valid(motor)or not motor.IsStart or not a.EngineRunning then return end
   local actual=math.min(before,used*ratio)
   if ratio~=1 then set(t,before-actual,player:get());x.q=before-actual end
   local c=N.cars[a:GetFullName()];if c then c.serial=c.serial+1;c.scale=actual/used;c.burnAt=game:GetTimeSeconds(a)end
  end)}
 end
 function N.force(c,now)
  local a=c.actor;if not valid(a)or not a:HasAuthority()or not c.burnAt or now-c.burnAt>.3 or a.BoostInput<=0 or not a.EnableBoost then return end
  if c.serial~=c.appliedSerial then
   c.appliedSerial=c.serial;c.baseForce=a.BoostForce;c.writtenForce=c.baseForce*(c.scale or 1);a.BoostForce=c.writtenForce
  elseif c.scale~=1 and c.baseForce and math.abs(a.BoostForce-c.baseForce)<.001 then
   -- Native boost input events can reapply BA's unchanged force between burns.
   a.BoostForce=c.writtenForce
  end
  if T.network and now>=(c.syncAt or 0)then c.syncAt=now+.1;T.network.nitrousForce(a,c.writtenForce,c.baseForce)end
 end
 function N.tick(now)
  if now>=(N.nextScan or 0)then N.nextScan=now+(N.available and 1 or 5);N.scan();N.install()end
  for _,c in pairs(N.cars)do N.force(c,now)end
  local r=N.remote;if r then
   if not valid(r.actor)then N.remote=nil
   elseif now<r.untilTime and r.actor.BoostInput>0 then r.actor.BoostForce=r.force
   else if math.abs(r.actor.BoostForce-r.force)<.001 then r.actor.BoostForce=r.base end;N.remote=nil end
  end
 end
 function N.reset()N.tanks={};N.cars={};N.remote=nil;N.nextScan=0;N.writing=false end
 return N
end
