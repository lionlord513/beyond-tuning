-- Native UMG computer app using Beyond Apocalypse Hangar's window and
-- ColorElement input-surface methodology. All callbacks stay on the game thread.
return function(T)
 local U={hits={},pending={},generation=0,mode='Curve',selected={5,4},menu=nil};local valid=T.valid
 local lib=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary');local P,S,V,D=T.policy,T.storage,T.vehicle,T.draw
 local function new(k,outer)return StaticConstructObject(StaticFindObject('/Script/UMG.'..k),outer)end
 local function color(r,g,b,a)return {R=r,G=g,B=b,A=a or 1}end
 local function place(parent,o,x,y,w,h)local s=parent:AddChildToCanvas(o);s:SetPosition({X=x,Y=y});s:SetSize({X=w,Y=h});return s end
 local function fill(s)s:SetHorizontalAlignment(0);s:SetVerticalAlignment(0);return s end
 local function colors()
  local dark=S.settings.theme=='Dark'
  U.bg=dark and color(.07,.085,.11)or color(.86,.87,.88);U.paper=dark and color(.1,.12,.15)or color(.96,.96,.96)
  U.ink=dark and color(.9,.93,.96)or color(.09,.12,.16);U.muted=dark and color(.55,.63,.7)or color(.35,.4,.46)
  U.rule=dark and color(.22,.27,.32)or color(.68,.71,.74);U.accent=D.color(S.settings.accent)
 end
 local function rect(parent,x,y,w,h,col)
  local im=new('Image',U.ui and U.ui.WidgetTree or parent);im:SetColorAndOpacity(col);im:SetVisibility(3);place(parent,im,x,y,w,h);return im
 end
 local function label(parent,s,x,y,w,h,size,col)
  local o=new('TextBlock',U.ui and U.ui.WidgetTree or parent);o:SetText(FText(tostring(s)));local f=o.Font;f.Size=size or 16;o:SetFont(f);o:SetColorAndOpacity({SpecifiedColor=col or U.ink,ColorUseRule=0});o:SetVisibility(3);o:SetClipping(1);place(parent,o,x,y,w,h);return o
 end
 local function surface(parent,fn)
  local s=lib:Create(U.pc,LoadAsset('/Game/BP/Garage/PaintStation/UI/ColorElement.ColorElement_C'),U.pc)
  fill(parent:AddChildToOverlay(s));s:SetRenderOpacity(.001);s:SetVisibility(0);s.SelfBaseReference=s;s.Border_47:SetVisibility(0);s.Border_160:SetVisibility(0)
  s:SetCursor(9);s.Border_47:SetCursor(9);s.Border_160:SetCursor(9);U.hits[s:GetAddress()]=fn;return s
 end
 local function button(parent,s,x,y,w,h,fn,active,size)
  local overlay=new('Overlay',U.ui.WidgetTree);place(parent,overlay,x,y,w,h)
  local cv=new('CanvasPanel',U.ui.WidgetTree);fill(overlay:AddChildToOverlay(cv))
  rect(cv,0,0,w,h,active and U.accent or U.paper);rect(cv,0,h-1,w,1,U.rule)
  label(cv,s,10,(h-(size or 16)*1.4)/2,w-18,h,size or 16,active and color(1,1,1)or U.ink)
  local input=surface(overlay,fn);return input
 end
 local function edit(parent,s,x,y,w,h)
  local o=new('EditableTextBox',U.ui.WidgetTree);o.WidgetStyle.TextStyle.Font.Size=17;o:SetText(FText(s));place(parent,o,x,y,w,h);return o
 end
 local function refresh()U.refresh=true end
 local function dirty()T.dirty=true;refresh()end
 function U.fit()
  if not valid(U.ui)then return end
  local layout=StaticFindObject('/Script/UMG.Default__WidgetLayoutLibrary');local size=layout:GetViewportSize(U.pc);local dpi=layout:GetViewportScale(U.pc)
  local scale=math.min(1,(size.X/dpi-28)/1400,(size.Y/dpi-28)/900)
  if U.scale~=scale then U.scale=scale;local c=U.ui.CP_RSPartWindow;c.Slot:SetAnchors({Minimum={X=.5,Y=.5},Maximum={X=.5,Y=.5}});c.Slot:SetPosition({X=-700,Y=-450});c.Slot:SetSize({X=1400,Y=900});c:SetRenderTransformPivot({X=.5,Y=.5});c:SetRenderScale({X=scale,Y=scale})end
 end
 function U.close()
  U.dragging=false;D.clearEngine()
  if valid(U.ui)then U.ui:RemoveFromParent()end;U.ui=nil;U.opened=false;U.menu=nil;U.hits={};U.pending={};U.generation=U.generation+1
  if valid(U.hud)and valid(U.pc)and U.hud:IsInViewport()then U.hud:SetVisibility(0);lib:SetInputMode_UIOnlyEx(U.pc,U.hud,0,false)end
 end
 local function preset(p)T.draft=P.copy(p.tune);T.presetName=p.name;U.menu=nil;dirty();T.status(p.name..' loaded as a draft. '..(p.description or'Press Apply to write it to this car.'))end
 local function sheet(title)
  local p=U.panel;rect(p,14,82,1372,754,U.paper);rect(p,14,82,1372,4,U.accent);label(p,title,38,105,1000,40,25)
  button(p,'Back to tuning',1180,101,178,38,function()U.menu=nil;refresh()end);return p
 end
 local function help()
  local p=sheet('HELP / Get from stock to your own tune')
  local lines={
   {'01  Connect to your car','Sit in your car, then open Car Tuning on a computer or mounted laptop. It remembers the last car you sat in.','The vehicle and installed engine are shown at the top. Swapping the engine reconnects the app.'},
   {'02  Start with an engine example','File > Presets offers Drift and Race for your installed engine. Load one, adjust it, then press Apply.','Drift adds rear drive and SLIDY-style assistance. Race adds grip, launch torque and taller top gears.'},
   {'03  Apply and test','Apply works from the driver seat, even while moving. Changes and a reusable preset are saved immediately.','Compare on the same road. Race uses maximum output: watch heat, fuel and traction. Save to keep the car itself.'},
   {'04  Fine-tune the table','Click a cell, then use -5 / +5. Rows are pedal position; columns are RPM across your engine redline.','100 is stock. 110 adds 10% torque in that region. Values blend smoothly between neighboring cells.'},
   {'05  Import, export and share','File > Import opens a drop window. Drag one preset JSON onto it, or click Browse. Review, then Apply.','File > Export opens Save As. File > Save preset stores a reusable copy; Preset folder opens it in Explorer.'},
   {'06  Use your portable computer','File > Laptop buys the laptop for $250. Right-click its lid to open/close; left-click the open screen to use it.','Left-click the closed laptop to pick it up. Use normal attachment controls to mount its bottom in a car.'},
  }
  for i,row in ipairs(lines)do local y=166+(i-1)*98;label(p,row[1],42,y,1300,28,19,U.accent);label(p,row[2],42,y+31,1300,24,16);label(p,row[3],42,y+55,1300,24,16,U.muted)end
  label(p,'Multiplayer: everyone needs this mod. Host saves tunes; the driver supplies live telemetry. Esc freezes the laptop screen.',42,778,1300,26,15,U.muted)
 end
 local function settings()
  local p=sheet('SETTINGS / Make the workspace yours')
  label(p,'Interface theme',42,173,320,32,20)
  for i,name in ipairs({'Classic','Dark'})do button(p,name,400+(i-1)*210,170,190,42,function()S.settings.theme=name;S.saveSettings();refresh()end,S.settings.theme==name)end
  label(p,'Interface accent',42,254,320,32,20)
  label(p,'Graph / hologram color',42,335,320,32,20)
  local titles={'Blue','Green','Amber','Violet','Cyan'}
  for i,name in ipairs(titles)do
   button(p,name,400+(i-1)*180,250,163,42,function()S.settings.accent=i;S.saveSettings();refresh()end,S.settings.accent==i)
   button(p,name,400+(i-1)*180,331,163,42,function()S.settings.graph=i;S.saveSettings();refresh()end,S.settings.graph==i)
  end
  label(p,'Simple view',42,422,320,32,20)
  button(p,S.settings.simple and 'ON - fewer controls'or'OFF - full tuning table',400,416,420,44,function()S.settings.simple=not S.settings.simple;S.saveSettings();refresh()end,S.settings.simple)
  label(p,'Simple view keeps the five main controls, presets, graphs and Apply. It hides the cell editor.',42,478,1260,26,17,U.muted)
  label(p,'Speed units',42,548,320,32,20)
  for i,name in ipairs({'km/h','mph'})do button(p,name,400+(i-1)*210,542,190,42,function()S.settings.units=name;S.saveSettings();refresh()end,S.settings.units==name)end
  button(p,'Engine heat overlay: '..(S.settings.heat and'ON'or'OFF'),42,625,480,44,function()S.settings.heat=not S.settings.heat;S.saveSettings();refresh()end,S.settings.heat)
  label(p,'Color shows the engine temperature, not a per-cylinder thermal simulation.',550,636,790,28,16,U.muted)
  label(p,'Beyond Tuning '..T.version..'  /  native computer integration  /  DBH build 26106988',42,718,1250,32,17,U.muted)
 end
 local function files()
  local p=sheet('FILE / Presets and transfer')
  label(p,'Preset name',42,175,260,28,18);U.nameInput=edit(p,T.presetName or'My tune',280,166,620,44)
  button(p,'Save preset',930,166,190,44,function()T.presetName=S.savePreset(T.draft,U.nameInput:GetText():ToString());T.status('Saved preset '..T.presetName);S.list();refresh()end,true)
  button(p,'Export...',1140,166,200,44,function()S.export(T.draft,U.nameInput:GetText():ToString());T.status('Choose where to export your preset JSON.')end)
  button(p,'Import / drop JSON...',42,235,310,46,function()S.native('import');T.status('Drop a preset on the import window, or use Browse.')end,true)
  button(p,'Open preset folder',374,235,270,46,function()S.native('folder')end)
  button(p,'Refresh presets',666,235,230,46,function()S.list();refresh()end)
  button(p,'Presets >',930,235,190,46,function()U.fileTab='Presets';U.presetPage=1;refresh()end,U.fileTab~='All')
  button(p,'All / saved',1140,235,200,46,function()U.fileTab='All';U.presetPage=1;refresh()end,U.fileTab=='All')
  local all=S.list();local list={};local motor=V.motor(V.last);local engine=valid(motor)and motor:GetClass():GetFName():ToString()
  for _,row in ipairs(all)do if U.fileTab=='All'or not row.engine or row.engine==engine then list[#list+1]=row end end
  table.sort(list,function(a,b)if(a.engine~=nil)~=(b.engine~=nil)then return a.engine~=nil end;return a.name<b.name end)
  label(p,U.fileTab=='All'and 'FILE > PRESETS / All engines and your saved tunes'or('FILE > PRESETS / '..(engine and V.name(motor)or'Sit in a car to see its engine examples')),42,319,1270,32,18,U.accent)
  U.presetPage=math.min(U.presetPage or 1,math.max(1,math.ceil(#list/12)))
  for i=(U.presetPage-1)*12+1,math.min(#list,U.presetPage*12)do local n=i-(U.presetPage-1)*12-1;local row=list[i]
   button(p,row.name,42+n%3*438,373+math.floor(n/3)*72,415,54,function()preset(row)end,false,18)
  end
  button(p,'< Previous',42,696,180,40,function()U.presetPage=math.max(1,U.presetPage-1);refresh()end)
  button(p,'Next >',240,696,180,40,function()U.presetPage=math.min(math.max(1,math.ceil(#list/12)),U.presetPage+1);refresh()end)
  label(p,'Page '..U.presetPage..'  /  '..#list..' presets',448,705,460,30,17,U.muted)
  button(p,'Laptop / Buy for $250',1010,696,330,44,function()T.laptop.order()end,true,16)
  label(p,'Drift: rear drive + native assist. Race: max output + longer top gears. Load, edit, Apply, then Save preset.',42,778,1290,28,16,U.muted)
 end
 local function boost()
  local p=sheet('BOOST / Nitrous injection and individual turbos');local I=T.induction;local a=V.last
  local status,available=I.nitrous.status(a)
  label(p,'NITROUS',42,165,280,30,20,U.accent);label(p,status,330,168,1000,29,17,U.muted)
  if available then
   local value=T.draft.nitrous or 100
   label(p,'Injection amount',42,218,290,32,19)
   button(p,'-',346,213,52,42,function()T.draft.nitrous=math.max(25,(T.draft.nitrous or 100)-25);dirty()end)
   label(p,('%g%%'):format(value),424,220,130,32,21,U.accent)
   button(p,'+',564,213,52,42,function()T.draft.nitrous=math.min(200,(T.draft.nitrous or 100)+25);dirty()end)
   label(p,('About %.2fx stock duration / %.2fx injection force'):format(100/value,value/100),657,220,650,32,17)
  end
  label(p,'Less injection uses less nitrous and gives a gentler push. More injection burns the bottle faster.',42,278,1290,27,17,U.muted)
  label(p,'Hold Shift while driving to use BA nitrous. Its engine, traction and braking safety rules still apply.',42,310,1290,27,16,U.muted)
  label(p,'INSTALLED TURBOS',42,365,800,32,20,U.accent)
  local list=I.turbos(V.lastMotor);U.turboPage=math.min(U.turboPage or 1,math.max(1,math.ceil(#list/4)))
  if #list==0 then label(p,'Unavailable - fit a turbo to the installed engine first.',42,426,1260,32,19,U.muted)end
  for i=(U.turboPage-1)*4+1,math.min(#list,U.turboPage*4)do local x=list[i];local y=417+(i-(U.turboPage-1)*4-1)*65;local value=T.draft.turbos[x.key]or T.draft.turboDefault or 100
   label(p,('Turbo %d / %s'):format(i,x.name),42,y,560,30,18)
   label(p,x.key,42,y+29,650,24,13,U.muted)
   button(p,'-',730,y,52,40,function()T.draft.turbos[x.key]=math.max(25,value-25);dirty()end)
   label(p,('%g%% boost'):format(value),804,y+6,190,30,19,U.accent)
   button(p,'+',1002,y,52,40,function()T.draft.turbos[x.key]=math.min(200,value+25);dirty()end)
   button(p,'Stock',1090,y,180,40,function()T.draft.turbos[x.key]=nil;dirty()end)
  end
  if #list>4 then button(p,'<',42,695,55,34,function()U.turboPage=math.max(1,U.turboPage-1);refresh()end);button(p,'>',110,695,55,34,function()U.turboPage=math.min(math.ceil(#list/4),U.turboPage+1);refresh()end)end
  label(p,'Each setting scales that turbo\'s native boost contribution. 100% is stock; missing slots are ignored.',42,742,1290,28,16,U.muted)
  label(p,T.dirty and 'DRAFT / Press Apply to save changes to this car.'or'Changes are saved with the car and engine.',42,792,870,28,17,U.muted)
  button(p,'Apply to car',1148,780,205,45,function()V.apply(T.draft);refresh()end,true,18)
 end
 local function diagnostics()
  local p=sheet('VEHICLE / Connected hardware');local a=V.last;local m=V.lastMotor
  local rows={{'Target',valid(a)and V.carName(a)or'Sit in a car to connect'},{'Chassis class',valid(a)and a:GetClass():GetFName():ToString()or'--'},
   {'Installed engine',V.name(m)},{'Engine class',valid(m)and m:GetClass():GetFName():ToString()or'--'},
   {'Tune identity',V.current and V.current.id or'Not assigned yet'},
   {'Transmission',V.current and (#V.current.base.gears-1)..' forward gears + reverse'or'--'},
   {'Engine redline',V.current and math.floor(V.current.base.redline)..' RPM'or'--'},
   {'Authority',valid(a)and(a:HasAuthority()and'Host / tuning enabled'or(T.network and T.network.connected and'Client / host synchronization active'or'Client / waiting for host mod'))or'--'}}
  if valid(a)then for _,d in ipairs({{'Battery','CarBatteryV2'},{'Radiator','CarRadiatorV2'},{'Fuel tank','CarTankGasV2'}})do local slot=a[d[2]];rows[#rows+1]={d[1],valid(slot)and V.name(slot.AttachedCarEquipableActor)or'Not installed'}end end
  for i,row in ipairs(rows)do label(p,row[1],42,169+(i-1)*48,280,31,17,U.muted);label(p,row[2],330,169+(i-1)*48,1000,31,18)end
  label(p,'Hardware names come from the installed actors. Exact class identifiers are included above.',42,762,1280,32,17,U.muted)
 end
 local function tuning()
  local p=U.panel;local a=V.last;local motor=V.lastMotor
  label(p,valid(a)and V.carName(a)or'No car connected',24,94,650,32,23,U.accent)
  label(p,'ENGINE  '..V.name(motor),650,98,720,28,18)
  label(p,valid(a)and a:GetClass():GetFName():ToString()or'Sit in a car, leave it, then return to this computer.',24,129,620,25,14,U.muted)
  label(p,valid(motor)and motor:GetClass():GetFName():ToString()or'Install an engine to enable tuning.',650,129,720,25,14,U.muted)
  U.gaugeRT=D.target(U.pc,1372,188);local im=rect(p,14,162,1372,188,color(1,1,1));im:SetBrushResourceObject(U.gaugeRT)
  U.gaugeValues={};local names={'RPM','Speed / '..S.settings.units,'Pedal / %','Engine / C','Gear','Torque / %','Fuel / L'}
  for i,name in ipairs(names)do local x=14+(i-1)*196;label(p,name,x+25,164,168,25,14,U.ink);rect(p,x+14,337,168,34,U.rule);U.gaugeValues[i]=label(p,'--',x+38,336,150,34,23,U.ink)end
  rect(p,14,385,648,394,U.paper);rect(p,674,385,712,394,U.paper)
  if not U.tableMode or S.settings.simple then
  label(p,'CALIBRATION',28,396,410,27,17,U.accent)
  button(p,S.settings.simple and 'Full view'or'Simple view',500,391,148,32,function()S.settings.simple=not S.settings.simple;S.saveSettings();refresh()end,S.settings.simple,14)
  for i,d in ipairs(P.controls)do local y=435+(i-1)*45
   label(p,d.name,28,y,235,30,17)
   button(p,'-',276,y-3,38,34,function()T.draft[d.key]=math.max(d.min,T.draft[d.key]-d.step);dirty()end)
   label(p,('%g%s'):format(T.draft[d.key],d.unit),331,y,112,30,19,U.accent)
   button(p,'+',441,y-3,38,34,function()T.draft[d.key]=math.min(d.max,T.draft[d.key]+d.step);dirty()end)
   button(p,'?',598,y-3,38,34,function()T.status(d.hint)end,false,16)
   local f=(T.draft[d.key]-d.min)/(d.max-d.min);rect(p,492,y+11,89,4,U.rule);rect(p,492,y+11,math.max(1,89*f),4,U.accent)
  end
  button(p,'Stock',28,685,185,42,function()preset({name='Stock',tune=P.stock()})end)
  button(p,'Presets...',228,685,185,42,function()U.menu='File';refresh()end)
  button(p,'Restore stock',428,685,207,42,function()T.draft=P.stock();V.apply(T.draft);refresh()end)
  button(p,'Handling: '..(T.draft.handling or'stock'),28,737,290,31,function()local nextMode={stock='drift',drift='race',race='stock'};T.draft.handling=nextMode[T.draft.handling or'stock'];dirty()end,false,14)
  button(p,'Gears: '..(T.draft.gearshape or'standard'),330,737,305,31,function()local nextMode={standard='drift',drift='race',race='standard'};T.draft.gearshape=nextMode[T.draft.gearshape or'standard'];dirty()end,false,14)
  end
  for i,d in ipairs({{'Curve','Tuning curve'},{'Live','Live log'},{'Engine','Engine view'}})do button(p,d[2],686+(i-1)*224,391,212,32,function()U.mode=d[1];refresh()end,U.mode==d[1],14)end
  U.graphRT=D.target(U.pc,712,440);local graph=rect(p,680,431,700,337,color(1,1,1));graph:SetBrushResourceObject(U.graphRT)
  if U.mode=='Engine'then
   U.engineImage=rect(p,895,454,270,270,color(1,1,1));U.engineImage:SetRenderOpacity(0)
   local drag=new('Overlay',U.ui.WidgetTree);place(p,drag,690,456,680,270)
   surface(drag,function()U.dragging=true;U.lastPointer=nil end)
   local controls={{'Left',function()D.orbit(-20)end},{'Right',function()D.orbit(20)end},{'Tilt up',function()D.orbit(0,15)end},{'Tilt down',function()D.orbit(0,-15)end},{'Zoom +',function()D.orbit(0,0,.2)end},{'Zoom -',function()D.orbit(0,0,-.2)end},{'Top',D.top}}
   for i,item in ipairs(controls)do button(p,item[1],689+(i-1)*98,737,92,28,item[2],false,12)end
  end
  -- The advanced table replaces the left calibration panel after a dedicated
  -- switch, retaining the same window scale and full-size graph.
  if U.tableMode and not S.settings.simple then
   rect(p,14,385,648,394,U.paper);label(p,'TORQUE CORRECTION / %',28,395,430,28,17,U.accent)
   button(p,'Main controls',488,390,160,32,function()U.tableMode=false;refresh()end,true,14)
   local red=V.current and V.current.base.redline or 7000
   label(p,'Pedal',26,443,64,24,13,U.muted)
   for c=1,8 do label(p,tostring(math.floor(red*(c-1)/7)),99+(c-1)*68,443,64,25,12,U.muted)end
   for r=1,5 do local y=479+(r-1)*42;label(p,(r*20)..'%',27,y+8,60,28,15,U.muted)
    for c=1,8 do local selected=U.selected[1]==r and U.selected[2]==c;button(p,tostring(T.draft.map[r][c]),91+(c-1)*68,y,64,37,function()U.selected={r,c};refresh()end,selected,15)end
   end
   local function adjust(delta)local r,c=table.unpack(U.selected);T.draft.map[r][c]=math.max(60,math.min(140,T.draft.map[r][c]+delta));dirty()end
   button(p,'-5',28,704,90,37,function()adjust(-5)end)
   button(p,'+5',130,704,90,37,function()adjust(5)end,true)
   button(p,'Cell 100%',232,704,145,37,function()local r,c=table.unpack(U.selected);T.draft.map[r][c]=100;dirty()end)
   button(p,'Reset table',390,704,240,37,function()T.draft.map=P.stock().map;dirty()end)
   label(p,'Select a cell. 100 = stock; changes blend between RPM and pedal rows.',28,750,615,24,13,U.muted)
  end
  if not S.settings.simple then button(p,U.tableMode and 'Main controls'or'Torque table',24,790,185,40,function()U.tableMode=not U.tableMode;refresh()end,U.tableMode,15)end
  button(p,V.paused and 'Resume log'or'Pause log',226,790,170,40,function()V.paused=not V.paused;refresh()end,V.paused,15)
  button(p,'Clear log',410,790,140,40,function()V.history={};refresh()end,false,15)
  label(p,T.dirty and 'DRAFT CHANGES' or'CALIBRATION READY',582,800,360,27,16,T.dirty and color(.9,.4,.05)or U.muted)
  button(p,'Revert draft',999,788,170,44,function()T.draft=P.copy(V.current and V.current.tune or P.stock());T.dirty=false;refresh()end)
  button(p,'Apply to car',1184,788,190,44,function()V.apply(T.draft);refresh()end,true,18)
 end
 function U.render()
  if not valid(U.ui)then return end;colors();U.panel=U.ui.CP_RSPartWindow;local p=U.panel
  D.clearEngine();U.engineImage=nil;U.hits={};U.generation=U.generation+1;p:ClearChildren();U.gaugeRT=nil;U.graphRT=nil;U.gaugeValues=nil
  rect(p,0,0,1400,900,U.bg);rect(p,0,0,1400,35,U.paper);label(p,'BEYOND TUNING  /  Car Tuning',15,5,1150,29,17,U.ink)
  button(p,'X',1351,0,49,35,U.close,false,17)
  if T.laptop and T.laptop.active then button(p,'Return to laptop',1110,0,230,35,T.laptop.close,false,15)end
  local x=14
  for _,name in ipairs({'File','View','Boost','Vehicle','Settings','Help'})do local tab=name
   button(p,name,x,42,tab=='Settings'and 112 or 92,32,function()
    if tab=='View'then U.menu=nil;U.tableMode=not U.tableMode;if S.settings.simple then S.settings.simple=false;S.saveSettings()end else U.menu=U.menu==tab and nil or tab end;refresh()
   end,U.menu==name,16);x=x+(tab=='Settings'and 118 or 98)
  end
  label(p,'CONNECTED TO LAST VEHICLE',980,48,390,25,13,U.muted)
  if U.menu=='Boost'then boost()elseif U.menu=='Help'then help()elseif U.menu=='Settings'then settings()elseif U.menu=='File'then files()elseif U.menu=='Vehicle'then diagnostics()else tuning()end
  rect(p,0,850,1400,50,U.paper);U.statusText=label(p,T.message,18,863,1364,28,15,U.muted)
  U.refresh=false;U.refreshStatus=false;U.scale=nil;U.fit();U.update()
 end
 function U.holdEngine(texture)
  if valid(U.engineImage)then U.engineImage:SetBrushFromTexture(texture,false);U.engineImage:SetColorAndOpacity(D.color(S.settings.graph));U.engineImage:SetRenderOpacity(1)end
 end
 function U.update()
  if not valid(U.ui)then return end
  if U.refreshStatus and valid(U.statusText)then U.statusText:SetText(FText(T.message));U.refreshStatus=false end
  if U.dragging then
   S.native('pointer');local value=S.read(T.root..'/state/pointer.txt')or'';local x,y,down=value:match('^(-?%d+) (-?%d+) (%d)$');x,y=tonumber(x),tonumber(y)
   if not x or down~='1'then U.dragging=false;U.lastPointer=nil
   elseif U.lastPointer then local dx=math.max(-100,math.min(100,x-U.lastPointer[1]));local dy=math.max(-100,math.min(100,y-U.lastPointer[2]));if dx~=0 or dy~=0 then D.orbit(-dx*.35,dy*.35)end;U.lastPointer={x,y}
   else U.lastPointer={x,y}end
  end
  local t=V.telemetry
  if valid(U.engineImage)then
   local shade=D.color(S.settings.graph)
   if S.settings.heat and t.heat then local f=math.max(0,math.min(1,(t.heat-55)/65));shade={R=.1+.9*f,G=.85-.7*f,B=1-.95*f,A=1}end
   U.engineImage:SetColorAndOpacity(shade)
  end
  if valid(U.gaugeRT)then
   D.gauges(U.pc,U.gaugeRT,t)
   local speed=(t.speed or 0)*(S.settings.units=='mph'and .621371 or 1)
   local values={t.rpm and ('%.0f'):format(t.rpm)or'--',t.speed and ('%.1f'):format(speed)or'--',t.throttle and ('%.0f'):format(t.throttle*100)or'--',t.heat and ('%.1f'):format(t.heat)or'--',t.gear and(t.gear<0 and 'R'or t.gear==0 and 'N'or tostring(t.gear))or'--',t.factor and ('%.0f'):format(t.factor*100)or'--',t.fuel and ('%.1f'):format(t.fuel)or'--'}
   for i,w in ipairs(U.gaugeValues)do w:SetText(FText(values[i]))end
  end
  if valid(U.graphRT)then D.graph(U.pc,U.graphRT,U.mode)end
 end
 function U.open()
  if valid(U.ui)then U.close();return end
  assert(valid(U.hud)and U.hud:IsInViewport(),'Open an in-game computer first')
  local c=lib:Create(U.pc,U.hud:GetClass(),U.pc);U.ui=c;U.opened=true;c:AddToViewport(12);c:SetVisibility(0)
  c.MainMenuSwitcher:SetActiveWidget(c.CP_RSPartWindow:GetParent());c:BndEvt__HUDBuyMenu_BT_CarPart_K2Node_ComponentBoundEvent_1_OnButtonClickedEvent__DelegateSignature()
  c.CP_HomePanel:SetVisibility(1);c.CP_MainMenu:SetVisibility(1);c.CP_RSPartWindow:SetVisibility(4);U.hud:SetVisibility(1)
  U.menu=nil;U.render();lib:SetInputMode_UIOnlyEx(U.pc,c,0,false)
 end
 function U.build(hud,pc)
  U.pc=pc;colors();local desktop=hud.BT_CarPart:GetParent():GetParent();local box=new('SizeBox',hud.WidgetTree);box:SetWidthOverride(200);box:SetHeightOverride(200);desktop:AddChildToHorizontalBox(box);U.app=box
  local overlay=new('Overlay',hud.WidgetTree);box:AddChild(overlay);local cv=new('CanvasPanel',hud.WidgetTree);fill(overlay:AddChildToOverlay(cv))
  local texture=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(hud,T.root..'/assets/icon.png');U.iconTexture=texture
  local im=rect(cv,30,6,140,140,color(1,1,1));im:SetBrushFromTexture(texture,false);label(cv,'CAR TUNING',28,154,172,35,18,color(1,1,1));U.icon=surface(overlay,U.open)
  if not U.hook then U.hook={RegisterHook('/Game/BP/Garage/PaintStation/UI/ColorElement.ColorElement_C:OnMouseButtonDown',function(ctx,_,mouse)
   local target=ctx:get();if not valid(target)then return end;local id=target:GetAddress();local fn=U.hits[id]
   if valid(U.icon)and id==U.icon:GetAddress()then fn=U.open end;if not fn then return end
   if StaticFindObject('/Script/Engine.Default__KismetInputLibrary'):PointerEvent_GetEffectingButton(mouse:get()).KeyName:ToString()=='LeftMouseButton'then
    if not U.pending[id]then U.pending[id]=true;local gen=U.generation;T.enqueue(function()if gen==U.generation then local ok,e=pcall(fn);if not ok then T.status(e)end end;U.pending[id]=nil end)end
   end;return lib:Handled()
  end)}end
  U.hud=hud
 end
 function U.tick()
  local pc=V.pc();local p=valid(pc)and pc.PlayerControlled;if not valid(p)or not valid(p.AC_EbaySystem)then return end
  local hud=p.AC_EbaySystem.HUDREF
  if valid(hud)and hud:IsInViewport()and valid(hud.BT_CarPart)then
   if not valid(U.hud)or hud:GetAddress()~=U.hud:GetAddress()or not valid(U.app)then U.reset();U.build(hud,pc)end
   if U.opened then if U.refresh then U.render()end;U.fit();U.update()end
  elseif U.opened then U.reset()end
 end
 function U.reset()
  U.dragging=false;D.clearEngine()
  if valid(U.ui)then U.ui:RemoveFromParent()end;if valid(U.app)then U.app:RemoveFromParent()end
  U.ui=nil;U.app=nil;U.icon=nil;U.hud=nil;U.pc=nil;U.opened=false;U.hits={};U.pending={};U.generation=U.generation+1;U.gaugeRT=nil;U.graphRT=nil
 end
 return U
end
