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
print('RPC regression: read-only strings, correct recipient, disconnected controller and other-mod isolation passed')
