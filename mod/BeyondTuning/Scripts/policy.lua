-- Pure tuning math; all controls correspond to an AVS value or torque output.
local P={schema=1,columns=8,rows=5}
P.controls={
 {key='power',name='Engine output',min=70,max=135,step=5,unit='%',hint='More power uses more fuel and produces more heat.'},
 {key='gearing',name='Final drive',min=75,max=125,step=5,unit='%',hint='Above 100: stronger acceleration, shorter gears. Below 100: taller gears.'},
 {key='limiter',name='Rev ceiling',min=80,max=115,step=5,unit='%',hint='Sets the rev limit as a percentage of the engine redline.'},
 {key='shift',name='Shift duration',min=60,max=150,step=10,unit='%',hint='Below 100 changes gear faster. Above 100 changes gear more slowly.'},
 {key='response',name='Pedal response',min=70,max=130,step=5,unit='%',hint='Above 100 gives more torque at part throttle; full throttle is unchanged.'},
}
function P.stock()
 local t={power=100,gearing=100,limiter=100,shift=100,response=100,nitrous=100,turbos={},turboDefault=100,handling='stock',gearshape='standard',map={}}
 for r=1,P.rows do t.map[r]={};for c=1,P.columns do t.map[r][c]=100 end end
 return t
end
function P.copy(t)local n={};for k,v in pairs(t)do n[k]=type(v)=='table'and P.copy(v)or v end;return n end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function P.validate(t)
 assert(type(t)=='table','Preset tune must be an object')
 local out=P.stock();local allowed={map=true,nitrous=true,turbos=true,turboDefault=true,handling=true,gearshape=true}
 out.turboDefault=t.turboDefault or 100;assert(finite(out.turboDefault)and out.turboDefault>=25 and out.turboDefault<=200,'Default turbo boost must be 25 to 200 percent')
 out.handling=t.handling or 'stock';assert(out.handling=='stock'or out.handling=='drift'or out.handling=='race','Unknown handling mode')
 out.gearshape=t.gearshape or 'standard';assert(out.gearshape=='standard'or out.gearshape=='race'or out.gearshape=='drift','Unknown gearbox profile')
 for _,d in ipairs(P.controls)do allowed[d.key]=true;local v=t[d.key];assert(finite(v)and v>=d.min and v<=d.max,d.name..' must be '..d.min..' to '..d.max);out[d.key]=v end
 local n=t.nitrous or 100;assert(finite(n)and n>=25 and n<=200,'Nitrous injection must be 25 to 200 percent');out.nitrous=n
 assert(t.turbos==nil or type(t.turbos)=='table','Turbo settings must be an object')
 local count=0;for slot,boost in pairs(t.turbos or{})do
  count=count+1;assert(count<=32 and type(slot)=='string'and #slot<=180 and slot:match('^[%w_/]+$'),'Invalid turbo slot')
  assert(finite(boost)and boost>=25 and boost<=200,'Turbo boost must be 25 to 200 percent');out.turbos[slot]=boost
 end
 for k in pairs(t)do assert(allowed[k],'Unknown tuning control: '..tostring(k))end
 assert(type(t.map)=='table'and #t.map==P.rows,'Torque map needs five throttle rows')
 for r=1,P.rows do assert(type(t.map[r])=='table'and #t.map[r]==P.columns,'Torque map needs eight RPM columns');for c=1,P.columns do local v=t.map[r][c];assert(finite(v)and v>=60 and v<=140,'Map cells must be 60 to 140 percent');out.map[r][c]=v end end
 return out
end
function P.preset(p)
 assert(type(p)=='table'and p.format=='BeyondTuning'and p.schema==P.schema,'Use a Beyond Tuning version 1 JSON preset')
 assert(type(p.name)=='string'and #p.name<=80,'Preset name must be at most 80 characters')
 local out={format='BeyondTuning',schema=1,name=p.name:gsub('%c',' '),tune=P.validate(p.tune)}
 for _,k in ipairs({'engine','category','description'})do if p[k]~=nil then assert(type(p[k])=='string'and #p[k]<=320,'Invalid preset '..k);out[k]=p[k]:gsub('%c',' ')end end
 return out
end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
function P.map(t,rpmFraction,throttle)
 local x=clamp(rpmFraction,0,1)*(P.columns-1);local y=clamp(throttle*P.rows-1,0,P.rows-1)
 local c=math.min(P.columns-1,math.floor(x)+1);local r=math.min(P.rows-1,math.floor(y)+1)
 local fx=x-(c-1);local fy=y-(r-1)
 local a=t.map[r][c]*(1-fx)+t.map[r][c+1]*fx
 local b=t.map[r+1][c]*(1-fx)+t.map[r+1][c+1]*fx
 return (a*(1-fy)+b*fy)/100
end
function P.factor(t,rpm,redline,throttle)
 if rpm>redline*t.limiter/100 then return 0 end
 local pedal=1
 if throttle>.01 then pedal=math.min(1,throttle^(100/t.response))/throttle end
 return t.power/100*P.map(t,rpm/math.max(redline,1),throttle)*pedal
end
function P.gears(base,t)
 local out=P.copy(base)
 for i,g in ipairs(out)do
  local ratio=t.gearing/100
  -- AVS slot 1 is reverse. Shape only forward gears; preserve gear count.
  if i>1 and t.gearshape=='race'then local phase=(i-2)/math.max(1,#out-2);ratio=ratio*(1.12-.30*phase)
  elseif i>1 and t.gearshape=='drift'then ratio=ratio*1.12 end
  for _,k in ipairs({'StartSpeed','EndSpeed','UpShift','DownShift'})do g[k]=g[k]/ratio end
  g.MaxTorque=g.MaxTorque*ratio;g.MinTorque=g.MinTorque*ratio
 end;return out
end
function P.isStock(t)
 if(t.turboDefault or 100)~=100 then return false end
 if (t.handling or 'stock')~='stock'or(t.gearshape or 'standard')~='standard'then return false end
 if (t.nitrous or 100)~=100 then return false end
 for _,value in pairs(t.turbos or{})do if value~=100 then return false end end
 for _,c in ipairs(P.controls)do if t[c.key]~=100 then return false end end
 for r=1,5 do for c=1,8 do if t.map[r][c]~=100 then return false end end end;return true
end
function P.baseline(b)
 assert(type(b)=='table'and type(b.gears)=='table'and #b.gears>=2 and #b.gears<=20,'Invalid baseline gearbox')
 local function number(v)assert(type(v)=='number'and v==v and math.abs(v)<1e9,'Invalid baseline number')end
 for _,k in ipairs({'redline','shift','idle','consumption','heat'})do number(b[k]);assert(b[k]>=0,'Negative baseline')end
 assert(b.redline>0,'Invalid baseline redline')
 if b.handling then
  for _,k in ipairs({'BaseTireFriction','BaseYFriction','BaseYFrictionDrift','SteeringSpeed'})do number(b.handling[k])end
  assert(type(b.handling.assist)=='boolean'and type(b.handling.wheels)=='table','Invalid handling baseline')
  for key,w in pairs(b.handling.wheels)do assert(type(key)=='string'and #key<180,'Invalid wheel identity');for _,k in ipairs({'MaxSteeringAngle','BrakePressure','RollingResistance'})do number(w[k])end;for _,k in ipairs({'IsDrivingWheel','IsSteerableWheel','IsHandbrakeWheel'})do assert(type(w[k])=='boolean','Invalid wheel setting')end end
 end
 for _,g in ipairs(b.gears)do for _,k in ipairs({'StartSpeed','EndSpeed','UpShift','DownShift','HighRPM','LowRPM','MaxTorque','MinTorque'})do number(g[k])end end
 return b
end
return P
