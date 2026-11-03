-- DBH build 26106988 / native AVS adapter and optional hardware calibration.
return function(T)
 local V={records={},history={},last=nil,telemetry={},hooks={}};local valid=T.valid;local P,S=T.policy,T.storage
 local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
 local fields={'StartSpeed','EndSpeed','UpShift','DownShift','HighRPM','LowRPM','MaxTorque','MinTorque'}
 local function writeGears(a,gears)
  assert(#a.Gears==#gears,'Gearbox changed; reconnect first')
  for i,row in ipairs(gears)do local slot=a.Gears[i];for _,k in ipairs(fields)do slot[k]=row[k]end end
 end
 local names={'Dada','Musgoat','Poyopa','Trailer','Kart','TriClops','Bonphiac','IFA','C18','UAZ','GTR','Golf','Toilet','Tractor','German Compact','French Utility','Muscle Car','Japanese Sport','Peak','Speedle','Escada','Escada Ladder','Kaiju G54','Bingo','SuperCube','Remorque 2000','Barrel Car','Hoist Car','Rotor GT7'}
 local function same(a,b)if not valid(a)or not valid(b)then return not valid(a)and not valid(b)end;return a:GetAddress()==b:GetAddress()end
 function V.pc()
  if valid(V.controller)and V.controller:IsLocalPlayerController()then return V.controller end
  for _,c in ipairs(FindAllOf('PlayerController')or{})do if valid(c)and c:IsLocalPlayerController()then V.controller=c;return c end end
 end
 function V.player()local pc=V.pc();return valid(pc)and pc.PlayerControlled end
 function V.motor(a)local slot=valid(a)and a.CarMotorV2;return valid(slot)and slot.AttachedCarEquipableActor end
 function V.id(a,m)
  local c,e=S.guid(a.GuidGarage),S.guid(m.GuidUnique)
  if c==string.rep('0',32)or e==string.rep('0',32)then return end;return c..':'..e
 end
 function V.name(a)
  if not valid(a)then return 'Not installed'end
  local p=V.player();local class=a:GetClass():GetFName();local result
  if valid(p)and valid(p.AC_EbaySystem)then pcall(function()V.nameCache=V.nameCache or{};local key=class:ToString();result=V.nameCache[key];if not result then p.AC_EbaySystem.PrimaryData.Structure:ForEach(function(_,v)local d=v:get();if valid(d.ItemClass)and d.ItemClass:GetFName():ToString()==key then result=d.HUDName:ToString()end end);V.nameCache[key]=result end end)end
  if result and result~=''then return result end
  local text=class:ToString():gsub('_C$',''):gsub('^BP_',''):gsub('(%l)(%u)','%1 %2'):gsub('_',' ')
  return text
 end
 function V.carName(a)
  local n=names[tonumber(a.VehicleType)or 0];return n or V.name(a)
 end
 function V.baseline(a,m)
  local gears={};a.Gears:ForEach(function(i,v)local g=v:get();local row={};for _,k in ipairs(fields)do row[k]=g[k]end;gears[#gears+1]=row end)
  assert(#gears>=2 and #gears<=20,'Vehicle has no supported gearbox')
  local red=0;for _,g in ipairs(gears)do red=math.max(red,g.HighRPM)end;assert(red>0,'Engine redline unavailable')
  return {gears=gears,redline=red,shift=a.GearSwitchTime,idle=a.IdleMaxRPM,consumption=m.Consumption,heat=m.HeatFactor}
 end
 function V.ensure(a)
  if not valid(a)or not valid(a.CarMotorV2)then return end;local m=V.motor(a);if not valid(m)then local old=V.records[a:GetFullName()];if old then if T.induction then T.induction.restore(old)end;old.configured=false;if valid(old.motor)then old.motor.Consumption=old.base.consumption;old.motor.HeatFactor=old.base.heat end end;return end
  local key=a:GetFullName();local old=V.records[key]
  if old and same(old.actor,a)and same(old.motor,m)then if not old.configured and not P.isStock(old.tune)and a:HasAuthority()then V.configure(old)end;return old end
  if old then
   if T.induction then T.induction.restore(old)end
   -- Engine installation writes a fresh gearbox. Never restore old gears over it.
   if valid(old.motor)then old.motor.Consumption=old.base.consumption;old.motor.HeatFactor=old.base.heat end
   if math.abs(a.GearSwitchTime-old.base.shift*old.tune.shift/100)<.0001 then a.GearSwitchTime=old.base.shift end
   if math.abs(a.IdleMaxRPM-old.base.idle*old.tune.limiter/100)<.0001 then a.IdleMaxRPM=old.base.idle end
   old.configured=false
  end
  local id=V.id(a,m);local saved=id and S.records[id];local base=saved and saved.base or V.baseline(a,m)
  -- Reject a journal for a different gearbox layout rather than reusing it.
  if not base or type(base.gears)~='table'or #base.gears~=#a.Gears then base=V.baseline(a,m);saved=nil end
  local r={actor=a,motor=m,key=key,id=id,base=base,tune=saved and P.validate(saved.tune)or P.stock()}
  V.records[key]=r
  if saved and a:HasAuthority()then V.configure(r)end
  return r
 end
 function V.configure(r)
  assert(valid(r.actor)and valid(r.motor),'Target no longer exists');local a,m=r.actor,r.motor
  assert(same(V.motor(a),m),'Installed engine changed; reconnect first')
  if P.isStock(r.tune)then V.restore(r);return end
  local g=P.gears(r.base.gears,r.tune);writeGears(a,g)
  a.GearSwitchTime=r.base.shift*r.tune.shift/100
  a.IdleMaxRPM=r.base.idle*r.tune.limiter/100
  m.Consumption=r.base.consumption*(r.tune.power/100)^1.25;m.HeatFactor=r.base.heat*(r.tune.power/100)^1.15
  if T.induction then T.induction.configure(r)end
  r.configured=true;a:ForceNetUpdate()
 end
 function V.restore(r)
  if not r or not valid(r.actor)then return end
  if T.induction then T.induction.restore(r)end
  writeGears(r.actor,r.base.gears);r.actor.GearSwitchTime=r.base.shift;r.actor.IdleMaxRPM=r.base.idle
  if valid(r.motor)then r.motor.Consumption=r.base.consumption;r.motor.HeatFactor=r.base.heat end
  r.configured=false
 end
 function V.target(a)
  if not valid(a)or not valid(a.CarMotorV2)then return end
  local changed=not same(V.last,a);V.last=a
  local m=V.motor(a);local engineChanged=not same(V.lastMotor,m);V.lastMotor=m
  if changed or engineChanged then
   V.current=V.ensure(a);V.history={};V.telemetry={};T.draft=P.copy(V.current and V.current.tune or P.stock());T.dirty=false;T.targetGeneration=(T.targetGeneration or 0)+1
   if T.ui then T.ui.refresh=true end
  end
 end
 function V.apply(tune)
  local a=V.last;assert(valid(a),'Sit in a car first');assert(a:HasAuthority(),'Only the host can apply a tune')
  local velocity=a.VehicleMesh:GetPhysicsLinearVelocity(FName('None'));local speed=math.sqrt(velocity.X^2+velocity.Y^2+velocity.Z^2)*.036
  assert(speed<2,'Stop the car before applying a tune')
  local r=assert(V.ensure(a),'Install an engine first');assert(r.id,'Save the car once so it has a persistent identity')
  assert(S.ready and not S.error,S.error or'Waiting for save identity')
  local new=P.validate(tune);local before=P.copy(r.tune);local prior=S.records[r.id]
  S.records[r.id]=not P.isStock(new)and {tune=P.copy(new),base=P.copy(r.base)}or nil
  local persisted,why=pcall(S.persist);if not persisted then S.records[r.id]=prior;error(why)end
  r.tune=new;local ok,e=pcall(V.configure,r)
  if not ok then r.tune=before;S.records[r.id]=prior;pcall(S.persist);pcall(V.configure,r);error(e)end
  V.current=r;T.dirty=false
  if not P.isStock(new)then local saved,err=pcall(S.savePreset,new,'Last applied - '..V.carName(a)..' - '..r.id:sub(1,8)..'-'..r.id:sub(34,41));if not saved then T.status('Tune persisted; reusable preset copy failed: '..tostring(err));return end end
  T.status('Tune applied and saved to disk for '..V.carName(a)..'. Presets and car tunes survive game restarts.')
 end
 function V.sample()
  local a=V.last;if not valid(a)then V.current=nil;V.telemetry={};return end
  V.target(a);local r=V.current;local m=V.motor(a);local t={rpm=a.RPM or 0,throttle=a.Throttle or 0,gear=a.CurrentGear or 0}
  local vel=a.VehicleMesh:GetPhysicsLinearVelocity(FName('None'));t.speed=math.sqrt(vel.X^2+vel.Y^2+vel.Z^2)*.036
  t.heat=valid(m)and m.Heat or nil;t.factor=r and r.configured and P.factor(r.tune,t.rpm,r.base.redline,t.throttle)or 1;t.redline=r and r.base.redline or 7000
  local tank=valid(a.CarTankGasV2)and a.CarTankGasV2.AttachedCarEquipableActor
  if valid(tank)and valid(tank.ItemTankComponent)then pcall(function()local total=0;tank.ItemTankComponent.FluidMap:ForEach(function(_,v)total=total+math.max(0,tonumber(v:get())or 0)end);t.fuel=total end)end
  V.telemetry=t
  if not V.paused then t.time=game:GetTimeSeconds(a);V.history[#V.history+1]=t;if #V.history>150 then table.remove(V.history,1)end end
 end
 function V.tick()
  local pc=V.pc();local p=valid(pc)and pc.PlayerControlled;if not valid(p)or not p.IsLoaded then return end
  local gi=game:GetGameInstance(p);if valid(gi.MainSaveGame)then S.load(gi.MainSaveGame)elseif not S.ready then S.ready=true;S.records={}end
  if valid(pc.Vehicle)then V.target(pc.Vehicle)end
  V.sample()
  local now=game:GetTimeSeconds(p)
  if now>=(V.scanAt or 0)and S.ready then
   V.scanAt=now+2
   for _,a in ipairs(FindAllOf('AVS_Template_Vehicle_C')or{})do if valid(a)and a:HasAuthority()and valid(V.motor(a))then
    local id=V.id(a,V.motor(a));if id and S.records[id]then V.ensure(a)end
   end end
   for key,r in pairs(V.records)do if not valid(r.actor)or r.actor:GetFullName()~=key then V.records[key]=nil end end
  end
 end
 function V.install()
  if V.installed then return end
  local path='/VehicleSystemPlugin/AVS_Vehicle.AVS_Vehicle_C:GetTorque';if not valid(StaticFindObject(path))then return end
  V.hooks[#V.hooks+1]={RegisterHook(path,function(ctx,torque)
   local a=ctx:get();if not valid(a)then return end;local r=V.records[a:GetFullName()]
   if not r or not r.configured or not same(r.actor,a)or not same(V.motor(a),r.motor)then return end
   local factor=P.factor(r.tune,a.RPM,r.base.redline,a.Throttle);torque:set(torque:get()*factor)
  end)}
  V.hooks[#V.hooks+1]={RegisterHook('/Script/DriveBeyondHorizons.DBHHelper:SaveGameToSlotAsyncReal',function(_,save)
   local s=save:get();if valid(s)and s:IsA(StaticFindObject('/Script/DriveBeyondHorizons.DBHSaveGame'))then local ok,e=pcall(S.capture,s);if not ok then T.status('Tuning save failed: '..tostring(e))end end
  end)}
  V.installed=true
 end
 function V.reset()
  V.records={};V.last=nil;V.lastMotor=nil;V.current=nil;V.controller=nil;V.history={};V.telemetry={};V.scanAt=0;S.reset()
 end
 return V
end
