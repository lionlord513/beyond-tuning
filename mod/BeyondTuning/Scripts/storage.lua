return function(root,J,P)
 local S={records={},ready=false,settings={theme='Classic',accent=1,graph=1,simple=false,heat=true,units='km/h'},presets={}}
 function S.read(path,limit)local f=io.open(path,'rb');if not f then return end;local s=f:read((limit or 65536)+1);f:close();assert(#s<=(limit or 65536),'File is too large');return s end
 function S.recover(path,decode,limit)
  local lastError
  for _,suffix in ipairs({'','.bak','.tmp'})do
   local ok,value=pcall(function()local bytes=S.read(path..suffix,limit);if bytes then return decode(bytes)end end)
   if ok and value~=nil then return value elseif not ok then lastError=tostring(value)end
  end
  if lastError then error(lastError)end
 end
 function S.write(path,value)
  local temp=path..'.tmp';local f=assert(io.open(temp,'wb'),'Cannot write '..path);assert(f:write(value));assert(f:close())
  local old=path..'.bak';os.remove(old);local existed=S.read(path,4*1024*1024)~=nil
  if existed then assert(os.rename(path,old),'Cannot back up previous file')end
  local ok,e=os.rename(temp,path);if not ok then if existed then os.rename(old,path)end;error(e)end
 end
 function S.native(name)local f,e=package.loadlib(root..'/assets/native/BeyondTuningNative.dll','bt_'..name);assert(f,e);return f()end
 S.native('init')
 function S.saveSettings()S.write(root..'/state/settings.json',J.encode(S.settings))end
 local settingsOK,d=pcall(S.recover,root..'/state/settings.json',J.decode);if settingsOK and type(d)=='table'then
  if d.theme=='Classic'or d.theme=='Dark'then S.settings.theme=d.theme end
  for _,k in ipairs({'accent','graph'})do if type(d[k])=='number'and d[k]>=1 and d[k]<=5 then S.settings[k]=math.floor(d[k])end end
  S.settings.simple=d.simple==true;if d.units=='mph'then S.settings.units='mph'end
  S.settings.heat=d.heat~=false
 end
 function S.guid(g)return ('%08x%08x%08x%08x'):format(g.A&0xffffffff,g.B&0xffffffff,g.C&0xffffffff,g.D&0xffffffff)end
 function S.saveKey(save)
  local n=save.SaveGameMetadata.SaveName;local world=S.guid(n.Guid);local rev=S.guid(n.GuidUnique)
  if world==string.rep('0',32)then return end
  if rev==string.rep('0',32)then return nil,world end
  return world..'-'..rev..'-'..tostring(n.Iterator),world
 end
 function S.load(save)
  if S.ready then return end;local key,world=S.saveKey(save)
  S.ready=true;S.world=world;S.key=key;S.records={};S.error=nil
  if not world then return end
  local function decode(text)local d=J.decode(text);assert(d.schema==1 and type(d.records)=='table','Invalid tuning journal');for id,r in pairs(d.records)do assert(id:match('^%x+:%x+$')and #id==65,'Invalid car / motor identity');r.tune=P.validate(r.tune);P.baseline(r.base)end;return d.records end
  local ok,v=pcall(function()
   local live=S.recover(root..'/state/active-'..world..'.json',decode,4*1024*1024);if live then return live end
   if key then return S.recover(root..'/state/tunes-'..key..'.json',decode,4*1024*1024)end
  end)
  if ok then S.records=v or{}else S.error=tostring(v)end
 end
 function S.persist()
  assert(S.ready and S.world and not S.error,S.error or'Waiting for world identity')
  S.write(root..'/state/active-'..S.world..'.json',J.encode({schema=1,records=S.records}))
 end
 function S.capture(save)
  if not S.ready or S.error then return end;local key,world=S.saveKey(save);if not key then return end;S.world=world;S.persist()
  local path=root..'/state/tunes-'..key..'.json';local bytes=J.encode({schema=1,records=S.records})
  local old=S.read(path,4*1024*1024)
  if old~=bytes then S.write(path,bytes)end;S.savedKey=key
 end
 function S.reset()S.records={};S.ready=false;S.world=nil;S.error=nil end
 function S.export(tune,name)
  local p={format='BeyondTuning',schema=1,name=name or'My tune',tune=P.validate(tune)}
  S.write(root..'/state/export.json',J.encode(p));S.native('export')
 end
 function S.cleanName(name)
  name=(name or'My tune'):gsub('[^%w _-]',''):sub(1,60);if name==''then name='My tune'end;if name:upper():match('^CON$')or name:upper():match('^PRN$')or name:upper():match('^AUX$')or name:upper():match('^NUL$')or name:upper():match('^COM%d$')or name:upper():match('^LPT%d$')then name='Tune '..name end
  return name
 end
 function S.savePreset(tune,name)
  name=S.cleanName(name)
  local path=root..'/presets/'..name..'.json';S.write(path,J.encode({format='BeyondTuning',schema=1,name=name,tune=P.validate(tune)}));return name
 end
 function S.importPreset(p)
  local base=S.cleanName(p.name);local name=base;local n=1
  while S.read(root..'/presets/'..name..'.json')or S.read(root..'/presets/'..name..'.json.bak')do
   local ok,old=pcall(S.recover,root..'/presets/'..name..'.json',function(bytes)return P.preset(J.decode(bytes))end)
   if ok and old and J.encode(old.tune)==J.encode(p.tune)then return name end
   n=n+1;assert(n<1000,'Too many presets with this name');name=base:sub(1,50)..' '..n
  end
  return S.savePreset(p.tune,name)
 end
 function S.list()
  S.native('list');local list=S.read(root..'/state/presets.txt')or'';local out,seen={},{}
  for name in list:gmatch('[^\r\n]+')do if not seen[name:lower()]and not name:find('[/\\:]')and name:lower():match('%.json$')then
   seen[name:lower()]=true
   local ok,v=pcall(function()return S.recover(root..'/presets/'..name,function(bytes)return P.preset(J.decode(bytes))end)end)
   if ok then out[#out+1]=v end
  end end;table.sort(out,function(a,b)return a.name<b.name end);S.presets=out;return out
 end
 function S.pollImport()
  local path=root..'/state/import.json';local s=S.read(path);if not s then return end
  os.remove(path);return P.preset(J.decode(s))
 end
 return S
end
