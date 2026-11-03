return function(T)
 local D={};local valid=T.valid;local lib=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
 D.palette={{R=.03,G=.42,B=.85,A=1},{R=.05,G=.75,B=.42,A=1},{R=.95,G=.43,B=.08,A=1},{R=.67,G=.28,B=.95,A=1},{R=.06,G=.75,B=.82,A=1}}
 local white={R=.9,G=.93,B=.96,A=1};local dark={R=.003,G=.005,B=.008,A=1};local grid={R=.025,G=.04,B=.06,A=1}
 function D.color(i)return D.palette[i or 1]or D.palette[1]end
 function D.target(ctx,w,h)return lib:CreateRenderTarget2D(ctx,w,h,2,{R=0,G=0,B=0,A=1},false,false)end
 local function line(c,x,y,x2,y2,col,width)c:K2_DrawLine({X=x,Y=y},{X=x2,Y=y2},width or 1,col)end
 local function text(c,s,x,y,col,scale)
  if not valid(D.font)then D.font=LoadAsset('/Engine/EngineFonts/Roboto.Roboto')end
  if valid(D.font)then c:K2_DrawText(D.font,tostring(s),{X=x,Y=y},{X=scale or .8,Y=scale or .8},col or white,0,{R=0,G=0,B=0,A=0},{X=0,Y=0},false,false,false,{R=0,G=0,B=0,A=0})end
 end
 -- Context has native-only fields which cannot round-trip through a Lua table.
 -- Finish inside the native post-hook, while the original context is alive.
 D.paintHook={RegisterHook('/Script/Engine.KismetRenderingLibrary:BeginDrawCanvasToRenderTarget',function()end,function(_,world,target,canvas,_,context)
  local rt=target:get();local job=D.job
  if not job or not valid(rt)or rt:GetAddress()~=job.address then return end
  D.job=nil;local ok,e=pcall(job.fn,canvas:get())
  lib:EndDrawCanvasToRenderTarget(world:get(),context:get());job.done=true;if not ok then job.error=e end
 end)}
 function D.paint(ctx,rt,bg,fn)
  lib:ClearRenderTarget2D(ctx,rt,bg);local job={address=rt:GetAddress(),fn=fn};D.job=job
  lib:BeginDrawCanvasToRenderTarget(ctx,rt,{},{},{})
  D.job=nil;assert(job.done,'Canvas draw callback unavailable');if job.error then error(job.error)end
 end
 function D.gauges(ctx,rt,t)
  local darkTheme=T.storage.settings.theme=='Dark';local ink=darkTheme and white or {R=.13,G=.16,B=.2,A=1}
  local bg=darkTheme and {R=.09,G=.11,B=.14,A=1}or {R=.89,G=.9,B=.91,A=1}
  local values={t.rpm or 0,t.speed or 0,(t.throttle or 0)*100,t.heat or 0,t.gear or 0,(t.factor or 1)*100,t.fuel or 0}
  local maxima={t.redline or 8000,200,100,160,8,200,100};if T.storage.settings.units=='mph'then values[2]=values[2]*.621371;maxima[2]=125 end;local accent=D.color(T.storage.settings.accent)
  D.paint(ctx,rt,bg,function(c)
   for g=1,7 do local cx=98+(g-1)*196;local cy=100;local radius=71
    for i=0,89 do local a=i*math.pi*2/90;local b=(i+1)*math.pi*2/90;line(c,cx+math.cos(a)*radius,cy+math.sin(a)*radius,cx+math.cos(b)*radius,cy+math.sin(b)*radius,accent,2)end
    for i=0,40 do local a=(135+i*270/40)*math.pi/180;local long=i%5==0;line(c,cx+math.cos(a)*(long and 58 or 63),cy+math.sin(a)*(long and 58 or 63),cx+math.cos(a)*68,cy+math.sin(a)*68,i>=34 and {R=.9,G=.18,B=.1,A=1}or ink,long and 2 or 1)
     if long then local v=maxima[g]*i/40;text(c,g==1 and ('%.0f'):format(v/1000)or ('%.0f'):format(v),cx+math.cos(a)*45-7,cy+math.sin(a)*45-7,ink,.6)end
    end
    local a=(135+math.min(1,math.max(0,values[g]/maxima[g]))*270)*math.pi/180
    line(c,cx-math.cos(a)*12,cy-math.sin(a)*12,cx+math.cos(a)*54,cy+math.sin(a)*54,{R=.93,G=.25,B=.08,A=1},3)
    line(c,cx-3,cy,cx+3,cy,ink,6)
   end
  end)
 end
 dofile(T.root..'/Scripts/engine_view.lua')(T,D,lib)
 function D.graph(ctx,rt,mode)
  local smallText=text;local function text(c,s,x,y,col,scale)smallText(c,s,x,y,col,(scale or .8)*1.5)end
  local V=T.vehicle;local t=V.telemetry;local accent=D.color(T.storage.settings.graph)
  local engine,engineStatus;if mode=='Engine'then engine,engineStatus=D.engineTexture(ctx,V.lastMotor)end
  D.paint(ctx,rt,dark,function(c)
   for i=0,10 do local x=48+i*62;line(c,x,30,x,374,grid);local y=30+i*34.4;line(c,48,y,668,y,grid)end
   if mode=='Engine'then
    local data,why=engine,engineStatus
    if not data then text(c,why,68,160,white,.9);return end
    -- UMG owns the texture reference; a Lua userdata alone is not a GC root.
    text(c,'Drag to orbit / installed engine and attached parts',50,8,white,.8)
   elseif mode=='Live'then
    local history=V.history;local channels={{'rpm',t.redline or 8000,accent},{'speed',200,{R=.95,G=.8,B=.1,A=1}},{'throttle',1,{R=.2,G=.95,B=.4,A=1}}}
    for _,d in ipairs(channels)do for i=2,#history do local x1=48+(i-2)*620/149;local x2=48+(i-1)*620/149;local y1=374-math.min(1,(history[i-1][d[1]]or 0)/d[2])*344;local y2=374-math.min(1,(history[i][d[1]]or 0)/d[2])*344;line(c,x1,y1,x2,y2,d[3],1.5)end end
    text(c,'RPM 0-'..math.floor(t.redline or 8000),50,397,accent,.7);text(c,'Speed 0-200 km/h',258,397,channels[2][3],.7);text(c,'Pedal 0-100%',500,397,channels[3][3],.7)
    text(c,'Last 15 seconds',50,8,white,.65)
   else
    local red=t.redline or 7000;local prior
    for i=0,100 do local rpm=red*1.15*i/100;local f=T.policy.factor(T.draft,rpm,red,1);local x=48+620*i/100;local y=374-math.min(2,f)/2*344
     if prior then line(c,prior[1],prior[2],x,y,accent,2)end;prior={x,y}
    end
    for x=48,658,16 do line(c,x,202,x+8,202,{R=.5,G=.55,B=.6,A=1})end
    text(c,'Draft / full throttle',50,8,accent,.7);text(c,'Stock 100% reference',385,8,white,.7)
    for i=0,4 do text(c,('%.0f'):format(red*1.15*i/4),40+620*i/4,380,white,.65);text(c,(200-i*50)..'%',4,24+i*86,white,.6)end
    text(c,'Engine RPM',300,410,white,.75)
   end
  end)
 end
 return D
end
