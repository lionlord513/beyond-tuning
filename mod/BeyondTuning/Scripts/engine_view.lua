-- Real scene capture of installed mesh components. No CPU mesh-buffer reads.
return function(T,D,render)
 local valid=T.valid;local game=StaticFindObject('/Script/Engine.Default__GameplayStatics');local mathlib=StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
 D.view={yaw=0,pitch=90,zoom=1}
 function D.orbit(yaw,pitch,zoom)
  local v=D.view;v.yaw=(v.yaw+(yaw or 0))%360;v.pitch=math.max(-75,math.min(90,v.pitch+(pitch or 0)));v.zoom=math.max(.5,math.min(2.5,v.zoom+(zoom or 0)))
  if D.engine then D.engine.dirty=true end
 end
 function D.top()D.view={yaw=0,pitch=90,zoom=1};if D.engine then D.engine.dirty=true end end
 function D.clearEngine()
  local e=D.engine;if e then if valid(e.capture)then e.capture:K2_DestroyActor()end;for _,a in ipairs(e.actors or{})do if valid(a)then a:K2_DestroyActor()end end end
  D.engine=nil
 end
 local function spawn(ctx,class,tr)
  local a=game:BeginDeferredActorSpawnFromClass(ctx,StaticFindObject(class),tr,1,nil,0);assert(valid(a),'Engine preview actor unavailable');game:FinishSpawningActor(a,tr,0);return a
 end
 local function collect(m)
  local actors={m};local attached={};m:GetAttachedActors(attached,true,true)
  for _,v in ipairs(attached)do local a=v:get();if valid(a)then actors[#actors+1]=a end end
  local parts={};local seen={};local root=m:GetTransform()
  for _,a in ipairs(actors)do
   for _,spec in ipairs({{'/Script/Engine.StaticMeshComponent','StaticMesh',false},{'/Script/Engine.SkeletalMeshComponent','SkeletalMesh',true}})do
    for _,v in ipairs(a:K2_GetComponentsByClass(StaticFindObject(spec[1])))do local c=v:get()
     if valid(c)and not seen[c:GetAddress()]and c.bVisible and not c.bHiddenInGame then
      seen[c:GetAddress()]=true;local mesh=c[spec[2]]
      if valid(mesh)then parts[#parts+1]={mesh=mesh,skin=spec[3],relative=mathlib:MakeRelativeTransform(c:K2_GetComponentToWorld(),root)}end
     end
    end
   end
  end
  assert(#parts>0,'Installed engine has no visible mesh');assert(#parts<=96,'Engine preview has too many components');return parts
 end
 local function create(ctx,m)
  local e={key=m:GetFullName(),actors={},dirty=true};D.engine=e
  local low={X=math.huge,Y=math.huge,Z=math.huge};local high={X=-math.huge,Y=-math.huge,Z=-math.huge}
  for _,part in ipairs(collect(m))do
   local r=part.relative;local tr={Translation={X=r.Translation.X,Y=r.Translation.Y,Z=r.Translation.Z-20000},Rotation={X=r.Rotation.X,Y=r.Rotation.Y,Z=r.Rotation.Z,W=r.Rotation.W},Scale3D={X=r.Scale3D.X,Y=r.Scale3D.Y,Z=r.Scale3D.Z}}
   local a=spawn(ctx,part.skin and '/Script/Engine.SkeletalMeshActor'or'/Script/Engine.StaticMeshActor',tr);e.actors[#e.actors+1]=a
   local c=part.skin and a.SkeletalMeshComponent or a.StaticMeshComponent;c:SetMobility(2);c:SetCollisionEnabled(0);c:SetCastShadow(false)
   if part.skin then c:SetSkeletalMesh(part.mesh,true)else c:SetStaticMesh(part.mesh)end
   local origin,extent={},{};a:GetActorBounds(false,origin,extent,false)
   for _,k in ipairs({'X','Y','Z'})do low[k]=math.min(low[k],origin[k]-extent[k]);high[k]=math.max(high[k],origin[k]+extent[k])end
  end
  e.center={X=(low.X+high.X)/2,Y=(low.Y+high.Y)/2,Z=(low.Z+high.Z)/2};e.width=math.max(high.X-low.X,high.Y-low.Y,high.Z-low.Z,10)*1.35;e.distance=e.width*2
  local tr={Translation=e.center,Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
  e.capture=spawn(ctx,'/Script/Engine.SceneCapture2D',tr);local c=e.capture.CaptureComponent2D
  c.bCaptureEveryFrame=false;c.bCaptureOnMovement=false;c.ProjectionType=1;c.PrimitiveRenderMode=2;c.CaptureSource=6
  e.rt=D.target(ctx,384,384);c.TextureTarget=e.rt
  for _,a in ipairs(e.actors)do c:ShowOnlyActorComponents(a,false)end
  return e
 end
 local function capture(e,now)
  local v=D.view;local yaw=(v.yaw-180)*math.pi/180;local pitch=v.pitch*math.pi/180
  local position={X=e.center.X+math.cos(yaw)*math.cos(pitch)*e.distance,Y=e.center.Y+math.sin(yaw)*math.cos(pitch)*e.distance,Z=e.center.Z+math.sin(pitch)*e.distance}
  e.capture:K2_SetActorLocationAndRotation(position,{Pitch=-v.pitch,Yaw=v.yaw,Roll=0},false,{},true)
  local c=e.capture.CaptureComponent2D;c.OrthoWidth=e.width/v.zoom;c:CaptureScene();e.pending=true;e.ready=now+.08;e.nextCapture=now+.14;e.dirty=false
 end
 function D.engineTexture(ctx,m)
  if not valid(m)then D.clearEngine();return nil,'No engine installed'end
  local e=D.engine;if e and e.key~=m:GetFullName()then D.clearEngine();e=nil end
  if not e then local ok,result=pcall(create,ctx,m);if not ok then D.clearEngine();return nil,tostring(result):gsub('^.-:%d+: ','')end;e=result end
  if e.error then return nil,e.error end
  local now=game:GetTimeSeconds(ctx)
  if e.pending and now>=e.ready then
   local ok,err=pcall(function()
    render:ExportRenderTarget(ctx,e.rt,T.root..'/state','engine-normal.png');T.storage.native('hologram')
    e.texture=render:ImportFileAsTexture2D(ctx,T.root..'/state/engine-hologram.png');assert(valid(e.texture),'Transparent engine image unavailable');T.ui.holdEngine(e.texture)
   end)
   e.pending=false;if not ok then e.error='Engine preview unavailable';T.status(err)end
  end
  if e.dirty and not e.pending and now>=(e.nextCapture or 0)then capture(e,now)end
  return e.texture,e.error or'Scanning installed engine...'
 end
end
