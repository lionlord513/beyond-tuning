-- The SLIDY module's measured grip/steering values plus the native drift assist.
-- Keep each engine's gearbox, vehicle mass and suspension; never replace arrays.
return function(T)
 local H={};local valid=T.valid
 local carFields={'BaseTireFriction','BaseYFriction','BaseYFrictionDrift','SteeringSpeed'}
 local wheelFields={'IsDrivingWheel','IsSteerableWheel','IsHandbrakeWheel','MaxSteeringAngle','BrakePressure','RollingResistance'}
 local function wheels(a)
  local out={};local cls=StaticFindObject('/VehicleSystemPlugin/VehicleAssets/Components/Vehicle_Wheel.Vehicle_Wheel_C')
  if not valid(cls)then cls=a.Vehicle_Wheel_DriverFront:GetClass()end
  for _,v in ipairs(a:K2_GetComponentsByClass(cls))do local w=v:get();out[w:GetFName():ToString()]=w end;return out
 end
 function H.baseline(a)
  local b={wheels={},assist=valid(a.DriftAssist1)and a.DriftAssist1:IsAssistActive()or false}
  for _,k in ipairs(carFields)do b[k]=a[k]end
  for key,w in pairs(wheels(a))do local t={};for _,k in ipairs(wheelFields)do t[k]=w.WheelConfig[k]end;b.wheels[key]=t end
  return b
 end
 function H.configure(r,mode)
  local a,b=r.actor,r.base.handling;if not b then b=H.baseline(a);r.base.handling=b end
  mode=mode or r.tune.handling or 'stock'
  for _,k in ipairs(carFields)do a[k]=b[k]end
  local all=wheels(a);local minX,maxX=math.huge,-math.huge
  for _,w in pairs(all)do local x=w.RelativeLocation.X;minX=math.min(minX,x);maxX=math.max(maxX,x)end
  for key,w in pairs(all)do
   local old=b.wheels[key];if old then for _,k in ipairs(wheelFields)do w.WheelConfig[k]=old[k]end;w:SetIsDrivingWheel(old.IsDrivingWheel)end
   if mode=='drift'then
    local isFront
    if maxX-minX>1 then isFront=w.RelativeLocation.X>(minX+maxX)/2 else isFront=w.WheelConfig.IsSteerableWheel end
    w:SetIsDrivingWheel(not isFront);w.WheelConfig.IsHandbrakeWheel=not isFront
    if w.WheelConfig.IsSteerableWheel then w.WheelConfig.MaxSteeringAngle=math.max(55,w.WheelConfig.MaxSteeringAngle)end
    w.WheelConfig.RollingResistance=.001
   elseif mode=='race'and old then
    w.WheelConfig.RollingResistance=math.min(.002,old.RollingResistance)
    w.WheelConfig.BrakePressure=old.BrakePressure*1.25
   end
  end
  if mode=='drift'then a.BaseTireFriction=2;a.BaseYFriction=1.42;a.BaseYFrictionDrift=1.32;a.SteeringSpeed=4
  elseif mode=='race'then a.BaseTireFriction=math.max(b.BaseTireFriction,2.25);a.BaseYFriction=math.max(b.BaseYFriction,2.2);a.BaseYFrictionDrift=math.max(b.BaseYFrictionDrift,1.8)end
  if valid(a.DriftAssist1)then a.DriftAssist1:SetAssistActive(mode=='drift'or(mode=='stock'and b.assist))end
 end
 return H
end
