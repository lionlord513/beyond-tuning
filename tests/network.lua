local root=arg[1]
local hooks,tasks={},{}
local function valid(v)return type(v)=='table'and v.alive~=false end
local function pc(localPlayer,authority)
 return {alive=true,IsLocalPlayerController=function()return localPlayer end,HasAuthority=function()return authority end}
end
local function ctx(v)return {get=function()return v end}end
local function text(s)return {get=function()return {ToString=function()return s end}end,set=function()error('Engine-owned RPC string was changed')end}end
StaticFindObject=function()return nil end
RegisterHook=function(path,fn)hooks[path]=fn;return 1,2 end
local T={valid=valid,vehicle={},storage={},policy={},json=dofile(root..'/json.lua'),enqueue=function(fn)tasks[#tasks+1]=fn end,status=function(e)error(e)end}
local N=dofile(root..'/network.lua')(T);N.install()
local server,client=hooks['/Script/Engine.PlayerController:ServerExecRPC'],hooks['/Script/Engine.PlayerController:ClientMessage']
local localHost,remoteOwner=pc(true,true),pc(false,true)
local received,sent=0,0
N.receiveServer=function(who,p)assert(who==remoteOwner and p.op=='ping');received=received+1 end
N.receiveClient=function(p)assert(p.op=='notice');sent=sent+1 end
N.send=function()error('Unexpected error reply')end
local function drain()local q=tasks;tasks={};for _,f in ipairs(q)do f()end end
for i=1,1000 do server(ctx(remoteOwner),text('BT1 {"op":"ping"}'));drain()end
assert(received==1000)
client(ctx(remoteOwner),text('BT1 {"op":"notice"}'));drain();assert(sent==0,'Host consumed another player reply')
client(ctx(localHost),text('BT1 {"op":"notice"}'));drain();assert(sent==1)
local gone=pc(false,true);server(ctx(gone),text('BT1 {"op":"ping"}'));gone.alive=false;drain();assert(received==1000)
server(ctx(remoteOwner),text('MTM1_other'));client(ctx(localHost),text('BAINV2R|other'));drain()
assert(received==1000 and sent==1,'Another mod packet was intercepted')
local testPc=pc(true,false);local saves,presets=0,0
local function unchanged(v)return v end
T.vehicle={pc=function()return testPc end,player=function()return nil end,records={}}
T.storage={records={},persist=function()saves=saves+1 end,savePreset=function(t)assert(t==2);presets=presets+1 end}
T.policy={validate=unchanged,baseline=unchanged,copy=unchanged};T.status=function()end
FindAllOf=function()return {}end
local U=dofile(root..'/network.lua')(T)
local w=string.rep('a',32);local car=w..':'..w;local w2=string.rep('b',32)
local function ready(id)U.receiveClient({op='ready',world=id})end
local function record(world,num,request)
 U.receiveClient({op='record',world=world,id=car,revision=num,tune=num,base=1,request=request})
end
ready(w);record(w,3);U.pending={id=car,serial=1};record(w,2,1)
assert(T.storage.records[car].tune==3 and saves==1 and presets==1 and not U.pending and T.draft==3,'A late acknowledgement rolled back a newer tune')
ready(w);assert(T.storage.records[car].tune==3,'Repeat hello deleted a current tune')
ready(w2);record(w,9);assert(not T.storage.records[car]and saves==1,'A prior world overwrote the save after travel')
record(w2,0);assert(T.storage.records[car].tune==0 and saves==2,'New world must accept its initial revision')
print('RPC regression: read-only strings, correct recipient, disconnected controller and other-mod isolation passed')
