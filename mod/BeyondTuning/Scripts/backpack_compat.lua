-- UE4SS mods have separate Lua states. Install a small optional loader in BA;
-- keep all adapter code here, and never ship or replace BA's source files.
return function(root)
 local path=root..'/../BeyondApocalypse/Scripts/main.lua'
 local f=io.open(path,'rb');if not f then return false end
 local original=f:read('*a');f:close()
 if original:find('-- BEGIN BEYOND TUNING BACKPACK BRIDGE',1,true)then return false end
 if not original:find('_G.BeyondApocalypse=M',1,true)then return false end
 local before,ending=original:match('^(.*)(return M%s*)$');if not before then return false end
 local block=[=[-- BEGIN BEYOND TUNING BACKPACK BRIDGE
do
 local ok,err=pcall(function()
  local scripts=debug.getinfo(1,'S').source:sub(2):gsub('\\','/'):match('^(.*)/[^/]+$')
  local mods=scripts..'/../..';local tuning=mods..'/BeyondTuning'
  local enabled=io.open(tuning..'/enabled.txt','r');local active=enabled~=nil;if enabled then enabled:close()end
  local list=io.open(mods..'/mods.txt','r');if list then for line in list:lines()do local v=line:match('^%s*BeyondTuning%s*:%s*(%d)');if v then active=v=='1'end end;list:close()end
  if not active then return end
  local path=tuning..'/Scripts/backpack_bridge.lua';local file=io.open(path,'r');if not file then return end;file:close()
  dofile(path)(_G.BeyondApocalypse,tuning)
 end)
 if not ok then print('[Beyond Tuning] Backpack bridge: '..tostring(err)..'\n')end
end
-- END BEYOND TUNING BACKPACK BRIDGE
]=]
 local updated=before..block..ending;assert(load(updated,'@'..path),'Invalid compatibility loader')
 local backup=root..'/state/ba-bootstrap-backup.txt'
 local existing=io.open(backup,'rb');if existing then existing:close()else local b=assert(io.open(backup,'wb'));assert(b:write(original));assert(b:close())end
 local pending=path..'.bt-pending';local out=assert(io.open(pending,'wb'));assert(out:write(updated));assert(out:close())
 local commit=assert(package.loadlib(root..'/assets/native/BeyondTuningNative.dll','bt_commit_backpack_loader'));commit()
 local check=assert(io.open(path,'rb'));local written=check:read('*a');check:close();assert(written==updated,'Could not commit BA backpack adapter')
 return true
end
