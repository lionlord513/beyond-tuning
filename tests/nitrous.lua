local root=assert(arg[1]);local scratch=assert(arg[2]);local P=dofile(root..'/nitrous/policy.lua')
local function state()return {held=true,driver=true,running=true,ground=true,brake=0,handbrake=false,reverse=false,up=1,litres=5,tier=1,speed=10,throttle=1,steering=0,paused=false}end
local a,u=P.output(state(),.1);assert(math.abs(a-3.6)<1e-9 and math.abs(u-.02)<1e-9)
for _,key in ipairs({'held','driver','running','ground'})do local s=state();s[key]=false;local a,u=P.output(s,.1);assert(a==0 and u==0,key..' failed to stop')end
for _,key in ipairs({'paused','handbrake','reverse'})do local s=state();s[key]=true;local a,u=P.output(s,.1);assert(a==0 and u==0,key..' failed to stop')end
for _,change in ipairs({{brake=.1},{up=.5},{litres=0},{speed=60},{speed=0,throttle=0}})do local s=state();for k,v in pairs(change)do s[k]=v end;local a,u=P.output(s,.1);assert(a==0 and u==0,'Unsafe boost condition consumed fuel')end
local s=state();s.tier=2;local b,v=P.output(s,.1);assert(b>a and b<=5.4 and math.abs(v-.035)<1e-9)
s=state();s.litres=.001;local b,v=P.output(s,.1);assert(v==.001 and b<3.6,'Partial tank produced full boost')
s=state();s.steering=1;local b=P.output(s,.1);assert(b>0 and b<1.1,'Sharp turn did not taper')
for _,dt in ipairs({-.1,0,.001,.05,.1,1,10})do for speed=-10,90,5 do for tier=1,2 do
 local s=state();s.tier=tier;s.speed=speed;local a,u=P.output(s,dt)
 assert(a>=0 and a<=5.4 and u>=0 and u<=.05250001 and u<=s.litres,'Unbounded force or frame-stall consumption')
end end end
-- More capacity changes duration only, never acceleration.
for _,amount in ipairs({2,5,10,40})do local s=state();s.litres=amount;local a=P.output(s,.1);assert(math.abs(a-3.6)<1e-9)end
local catalog=dofile(root..'/nitrous/catalog.lua');assert(#catalog==6)
for i,d in ipairs(catalog)do assert(d.id==i and d.litres==({2,5,10})[(i-1)%3+1]and d.height<=52)end
-- Native revisions are immutable: restoring an older snapshot restores its own variants.
local captureHook
RegisterHook=function(_,fn)captureHook=fn;return 1,2 end
StaticFindObject=function()return{}end
local valid=function(x)return type(x)=='table'and x.valid~=false end
local function read(path)local f=io.open(path,'rb');if not f then return end;local v=f:read('*a');f:close();return v end
local T={root=scratch,valid=valid,storage={saveKey=function(save)return save.SaveGameMetadata.key,save.SaveGameMetadata.world end,read=read}}
local J=dofile(root..'/nitrous/journal.lua')(T,function()end)
for _,ratio in ipairs({25,50,100,200}) do
 local fixture=state();fixture.injection=ratio;local force,used=P.output(fixture,.1)
 assert(math.abs(force-3.6*ratio/100)<.00001 and math.abs(used-.02*ratio/100)<.00001)
end
local guid='11111111:22222222:33333333:44444444'
local save={SaveGameMetadata={key='world-rev1',world='world'},IsA=function()return true end}
J.load(nil);assert(not J.ready);J.load({SaveGameMetadata={world='world'}});J.state.bottle[guid]=6;J.state.site['Garage@1,2,3']=true;J.capture(save)
J.state.bottle[guid]=1;assert(not pcall(J.capture,save),'A save revision was silently overwritten')
J.reset();J.load(save);assert(J.state.bottle[guid]==6 and J.state.site['Garage@1,2,3'])
J.reset();J.load({SaveGameMetadata={key='world-old',world='world'}});assert(not next(J.state.bottle),'Older save inherited future variants')
for _,bad in ipairs({'','BAN1\nbottle '..guid..' 7\n','BAN1\nbottle '..guid..' 1\nbottle '..guid..' 2\n','BAN1\nsite x\nsite x\n','BAN1\nunknown x\n','BAN1\nbottle invalid 2\n'})do assert(not pcall(J.decode,bad),'Malformed snapshot accepted')end
print('PASS: boost safety gates, both tiers, speed/turn taper, frame-stall bounds, non-stacking capacity, immutable native save revisions, corrupt records rejected')
