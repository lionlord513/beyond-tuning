-- An unused, discovered laptop must make no calls into Unreal or the filesystem.
-- Run from repository root: lua tests/laptop_idle.lua
local scriptRoot=root or 'mod/BeyondTuning/Scripts'
local calls=0
StaticFindObject=function()calls=calls+1;return{}end
local T={root=scriptRoot:gsub('/Scripts$',''),valid=function(o)return o~=nil end,
 storage={ready=true,world='fixture'},vehicle={},network={},json={}}
local L=dofile(scriptRoot..'/laptop.lua')(T)
L.hooks={};L.world='fixture';L.dirty=false
L.items.fixture={actor={}};L.data.fixture={closed=true}
calls=0
for i=1,10000 do L.tick()end
assert(calls==0,'Idle laptop called the engine')
assert(L.capture==nil and L.active==nil,'Idle laptop started a live display')
print('PASS 10,000 idle laptop updates: no engine calls, capture, polling or file work')
