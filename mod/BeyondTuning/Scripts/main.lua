local root=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/Scripts/[^/]+$')
local T={version='1.1.1',root=assert(root),queue={},message='Sit in a car, then open Car Tuning on a computer.',active=true}
function T.valid(o)return o and o:IsValid()end
function T.status(s)local text=tostring(s);print('[Beyond Tuning] '..text..'\n');T.message=text:gsub('^.-:%d+: ',''):match('[^\r\n]+'):sub(1,165);if T.ui then T.ui.refreshStatus=true end end
function T.enqueue(fn)T.queue[#T.queue+1]=fn end
T.json=dofile(root..'/Scripts/json.lua');T.policy=dofile(root..'/Scripts/policy.lua')
T.storage=dofile(root..'/Scripts/storage.lua')(root,T.json,T.policy)
T.handling=dofile(root..'/Scripts/handling.lua')(T)
T.draft=T.policy.stock();T.vehicle=dofile(root..'/Scripts/vehicle.lua')(T)
T.induction=dofile(root..'/Scripts/induction.lua')(T)
T.draw=dofile(root..'/Scripts/draw.lua')(T)
T.ui=dofile(root..'/Scripts/ui.lua')(T)
T.network=dofile(root..'/Scripts/network.lua')(T)
T.laptop=dofile(root..'/Scripts/laptop.lua')(T)
local errors={};local tick=0
T.timer=LoopInGameThreadWithDelay(50,function()
 if not T.active then return end
 local ok,e=xpcall(function()
  if T.resetRequested then T.resetRequested=false;T.queue={};T.ui.reset();T.induction.reset();T.network.reset();if T.laptop then T.laptop.reset()end;T.vehicle.reset();T.draft=T.policy.stock();T.dirty=false end
  T.vehicle.install()
  local q=T.queue;T.queue={};for _,fn in ipairs(q)do local worked,why=pcall(fn);if not worked then T.status(why)end end
  T.induction.tick();tick=tick+1
  if tick%2==0 then T.vehicle.tick();T.network.tick();if T.laptop then T.laptop.tick()end;T.ui.tick()end
  if tick%10==0 then local worked,p=pcall(T.storage.pollImport);if not worked then T.status('Import refused: '..tostring(p))elseif p then local name=T.storage.importPreset(p);T.draft=p.tune;T.presetName=name;T.dirty=true;T.ui.refresh=true;T.status('Imported and saved '..name..'. Review the draft, then press Apply.')end end
 end,debug.traceback)
 if not ok and not errors[tostring(e)]then errors[tostring(e)]=true;T.status(e)end
end)
RegisterLoadMapPreHook(function()T.resetRequested=true end)
RegisterKeyBind(Key.ESCAPE,function()if T.laptop.active then T.enqueue(T.laptop.close)elseif T.ui.opened then T.enqueue(T.ui.close)end end)
_G.BeyondTuning=T
T.status('Beyond Tuning '..T.version..' loaded. Car Tuning is available on in-game computers.')
return T
