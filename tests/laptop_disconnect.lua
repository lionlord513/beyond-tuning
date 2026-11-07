local scripts=assert(root)
StaticFindObject=function()return{}end
local function valid(o)return type(o)=='table'and o.alive~=false end
local T={root=scripts:gsub('/Scripts$',''),valid=valid,storage={},vehicle={},network={},json={}}
local L=dofile(scripts..'/laptop.lua')(T)
local destroyed=0
local function proxy()return {K2_DestroyActor=function()destroyed=destroyed+1 end}end
L.items.shared={users={[1]=true,[2]=true},proxy=proxy()}
L.items.private={users={[1]=true},proxy=proxy()}
local gone={alive=false,GetAddress=function()error('Destroyed controller accessed')end}
L.disconnect(gone,1)
assert(destroyed==1 and not L.items.private.proxy,'Disconnected player retained a private desktop')
assert(L.items.shared.proxy and L.items.shared.users[2]and not L.items.shared.users[1],'Disconnect closed another player desktop')
L.disconnect(gone,1);assert(destroyed==1,'Cleanup must be idempotent')
L.disconnect({GetAddress=function()return 2 end})
assert(destroyed==2 and not L.items.shared.proxy,'Last user did not release the desktop')
return 'Expired controller cleanup, shared desktop retention and last-user teardown'
