-- Optional hardware integration; never loads or modifies Beyond Apocalypse code.
return function(T)
 local I={proxies={},turboRecords={}};local valid=T.valid;local game=StaticFindObject('/Script/Engine.Default__GameplayStatics')
 local turboClass=StaticFindObject('/Game/BP/CarsV2/System/Actors/Master/CarItemTurbo.CarItemTurbo_C')
 local function same(a,b)return valid(a)and valid(b)and a:GetAddress()==b:GetAddress()end
 function I.turbos(m)
  local out={};local visited={}
  if not valid(turboClass)then turboClass=StaticFindObject('/Game/BP/CarsV2/System/Actors/Master/CarItemTurbo.CarItemTurbo_C')end
  if not valid(turboClass)then return out end
  local function scan(actor,prefix,depth)
   if not valid(actor)or depth>8 or visited[actor:GetAddress()]then return end;visited[actor:GetAddress()]=true
   -- Enumerate native attachment components, including turbo-on-turbo layouts.
   for _,v in ipairs(actor:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.ActorComponent')))do local slot=v:get()
    local cls=slot:GetClass();if cls:GetFName():ToString()=='CarTurboV2_C'then
     local key=prefix..slot:GetFName():ToString();local child=slot.AttachedCarEquipableActor
     if valid(child)and child:IsA(turboClass)then out[#out+1]={key=key,actor=child,slot=slot,name=T.vehicle.name(child)};scan(child,key..'/',depth+1)end
    end
   end
  end
  scan(m,'',0);table.sort(out,function(a,b)return a.key<b.key end);return out
 end
 function I.restore(r)
  for _,x in ipairs(r.turboHardware or{})do local rec=I.turboRecords[x.actor:GetAddress()]
   if rec then if valid(rec.actor)and same(rec.actor.TorqueMultiplierCurve,rec.proxy)and valid(rec.base)then rec.actor.TorqueMultiplierCurve=rec.base end;I.proxies[rec.address]=nil;I.turboRecords[x.actor:GetAddress()]=nil end
  end;r.turboHardware=nil
 end
 function I.configure(r)
  local hardware=I.turbos(r.motor);local keep={}
  for _,x in ipairs(hardware)do
   local address=x.actor:GetAddress();keep[address]=true;local gain=(r.tune.turbos[x.key]or 100)/100;local rec=I.turboRecords[address]
   if rec and (not same(rec.actor,x.actor)or not same(x.actor.TorqueMultiplierCurve,rec.proxy))then I.proxies[rec.address]=nil;rec=nil;I.turboRecords[address]=nil end
   if gain~=1 and not rec then
    local base=x.actor.TorqueMultiplierCurve;assert(valid(base),'Turbo curve unavailable')
    local proxy=StaticConstructObject(StaticFindObject('/Script/Engine.CurveFloat'),x.actor,FName('None'));assert(valid(proxy),'Turbo calibration unavailable')
    rec={actor=x.actor,base=base,proxy=proxy,address=proxy:GetAddress(),gain=gain};I.turboRecords[address]=rec;I.proxies[rec.address]=rec;x.actor.TorqueMultiplierCurve=proxy
   elseif rec and gain==1 then
    if valid(rec.base)then x.actor.TorqueMultiplierCurve=rec.base end;I.proxies[rec.address]=nil;I.turboRecords[address]=nil;rec=nil
   end
   if rec then rec.gain=gain end
  end
  for _,x in ipairs(r.turboHardware or{})do if not keep[x.actor:GetAddress()]then local rec=I.turboRecords[x.actor:GetAddress()];if rec then if valid(rec.actor)and same(rec.actor.TorqueMultiplierCurve,rec.proxy)and valid(rec.base)then rec.actor.TorqueMultiplierCurve=rec.base end;I.proxies[rec.address]=nil;I.turboRecords[x.actor:GetAddress()]=nil end end end
  local signature={};for _,x in ipairs(hardware)do signature[#signature+1]=x.key..':'..x.actor:GetAddress()end;signature=table.concat(signature,'|')
  if r.hardwareSignature and r.hardwareSignature~=signature and T.vehicle.current==r then if T.draw then T.draw.clearEngine()end;if T.ui then T.ui.refresh=true end end
  r.hardwareSignature=signature;r.turboHardware=hardware
 end
 function I.install()
  if I.hook then return end
  I.hook={RegisterHook('/Script/Engine.CurveFloat:GetFloatValue',function()end,function(ctx,original,time)
   local c=ctx:get();local rec=valid(c)and I.proxies[c:GetAddress()]
   if rec and valid(rec.actor)and valid(rec.base)and same(rec.actor.TorqueMultiplierCurve,rec.proxy)then return rec.base:GetFloatValue(time:get())*rec.gain end
  end)}
 end
 function I.tick()
  I.install();local p=T.vehicle.player();if not valid(p)then return end;local now=game:GetTimeSeconds(p)
  if now>=(I.nextScan or 0)then I.nextScan=now+.5
   for _,r in pairs(T.vehicle.records)do if valid(r.actor)and valid(r.motor)and r.actor:HasAuthority()and same(T.vehicle.motor(r.actor),r.motor)then I.configure(r)end end
  end
  if I.nitrous then I.nitrous.tick(now)end
 end
 function I.reset()
  for _,r in pairs(T.vehicle.records)do I.restore(r)end;I.proxies={};I.turboRecords={};I.nextScan=0;if I.nitrous then I.nitrous.reset()end
 end
 I.nitrous=dofile(T.root..'/Scripts/nitrous.lua')(T)
 return I
end
