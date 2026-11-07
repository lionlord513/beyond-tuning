-- A native inventory transfer may destroy the laptop between capture frames.
local scripts=assert(root)
local unsafe,painted,exports,destroyed=0,0,0,0
local renderer={ExportRenderTarget=function()exports=exports+1 end}
StaticFindObject=function(path)if path:find('KismetRendering')then return renderer end;return{}end
FName=function(s)return s end
local function valid(o)return type(o)=='table'and o.alive~=false end
local T={root=scripts:gsub('/Scripts$',''),valid=valid,
 storage={ready=true,world='fixture'},vehicle={},network={},json={},draw={}}
T.draw.target=function(actor)if not valid(actor)then unsafe=unsafe+1 end;return{}end
T.draw.paint=function(actor,rt,bg,draw)if not valid(actor)then unsafe=unsafe+1 end;painted=painted+1;draw({K2_DrawTexture=function()end})end
local L=dofile(scripts..'/laptop.lua')(T)
L.hooks={};L.world='fixture';L.dirty=false
local function setup()
 local r={id='fixture',actor={},screenMaterial={}}
 r.screenMaterial.SetTextureParameterValue=function(self)if not valid(self)then unsafe=unsafe+1 end end
 local component={GetRenderTarget=function(self)if not valid(self)then unsafe=unsafe+1 end;return{}end,
  SetComponentTickEnabled=function()end,SetWidget=function()end,K2_DestroyComponent=function()destroyed=destroyed+1 end}
 L.items.fixture=r;L.capture={r=r,component=component,frames=1,width=1400,height=900}
 return r,component
end
for _,kind in ipairs({'actor','component','material','replaced'})do
 local r,c=setup()
 if kind=='actor'then r.actor.alive=false elseif kind=='component'then c.alive=false
 elseif kind=='material'then r.screenMaterial.alive=false else L.items.fixture={}end
 L.tick()
 assert(unsafe==0 and painted==0 and exports==0,'Capture touched stale '..kind)
 assert(not L.capture,'Stale capture retained '..kind)
end
setup();L.tick();assert(L.capture and painted==1,'Live laptop snapshot was lost')
L.tick();assert(not L.capture and exports==1,'Live capture did not export and release')
return 'Expired actor, material, component and replaced-record captures stop before native access; live snapshot still exports'
