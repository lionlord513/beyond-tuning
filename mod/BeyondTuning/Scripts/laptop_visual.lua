-- Imported, textured model: 2,012 triangles, shared materials, no capture tick.
return function(T)
 local V={geometry={}};local valid=T.valid
 local identity={Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
 local function texture(a,name)
  return StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(a,T.root..'/assets/laptop/'..name..'.png')
 end
 function V.material(a)
  if valid(V.bodyMaterial)then return V.bodyMaterial end
  local m=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary'):CreateDynamicMaterialInstance(a,LoadAsset('/MasterWeapon/Materials/Weapons/MAT_ArK47.MAT_ArK47'),FName('BT_LaptopBody'),0)
  for key,file in pairs({Diffuse='laptop',NormalMap='normal',RoughnessMap='roughness',MetalMap='black',AOMap='white'})do m:SetTextureParameterValue(FName(key),texture(a,file))end
  m:SetScalarParameterValue(FName('AODarkness'),1);m:SetScalarParameterValue(FName('DiffuseBrightness'),1.3);m:SetScalarParameterValue(FName('RoughnessBrightness'),1);V.bodyMaterial=m;return m
 end
 function V.screenMaterial(a)
  local m=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary'):CreateDynamicMaterialInstance(a,LoadAsset('/Engine/EngineMaterials/Widget3DPassThrough_Opaque.Widget3DPassThrough_Opaque'),FName('BT_LaptopScreen'),0)
  m:SetTextureParameterValue(FName('SlateUI'),texture(a,'wallpaper'));m:SetVectorParameterValue(FName('TintColorAndOpacity'),{R=1,G=1,B=1,A=1});return m
 end
 function V.create(a)
  assert(valid(a)and valid(a.RootMeshComponent),'Laptop carrier is not ready')
  local r={actor=a,base=a.RootMeshComponent};local cls=StaticFindObject('/Script/ProceduralMeshComponent.ProceduralMeshComponent')
  r.anchor=a:AddComponentByClass(StaticFindObject('/Script/Engine.SceneComponent'),true,identity,false)
  r.anchor:K2_AttachToComponent(a.RootMeshComponent,FName('None'),0,0,0,false);r.anchor:SetAbsolute(false,false,true);r.anchor:SetWorldScale3D({X=1,Y=1,Z=1});r.anchor:SetComponentTickEnabled(false)
  for _,name in ipairs({'lid','screen'})do
   local g=V.geometry[name]or dofile(T.root..'/assets/laptop/'..name..'.lua');V.geometry[name]=g
   local c=a:AddComponentByClass(cls,true,identity,false)
   c:K2_AttachToComponent(r.anchor,FName('None'),0,0,0,false)
   -- Keep the lid at its authored size when the native placement preview scales.
   c:SetAbsolute(false,false,true);c:SetWorldScale3D({X=1,Y=1,Z=1})
   c:CreateMeshSection(0,g.vertices,g.triangles,g.normals,g.uv,{},g.tangents,false)
   c:K2_SetWorldLocation(a.RootMeshComponent:K2_GetComponentLocation(),false,{},true)
   c:SetCollisionEnabled(0);c:SetGenerateOverlapEvents(false);c:SetComponentTickEnabled(false);c:SetCullDistance(8000);c:SetCastShadow(name~='screen')
   if name=='screen'then r.screenMaterial=V.screenMaterial(a);c:SetMaterial(0,r.screenMaterial)else c:SetMaterial(0,V.material(a))end
   r[name]=c
  end
  V.fold(r,false);return r
 end
 function V.fold(r,closed)
  -- Geometry is authored around the hinge. UE pitch closes toward the keyboard.
  for _,name in ipairs({'lid','screen'})do
   local c=r[name];local g=V.geometry[name]
   c:K2_SetRelativeLocation({X=g.pivot.X,Y=g.pivot.Y,Z=g.pivot.Z},false,{},true)
   c:K2_SetRelativeRotation({Pitch=closed and 119 or 0,Yaw=0,Roll=0},false,{},true)
  end
  r.closed=closed;r.screen:SetVisibility(not closed,false)
 end
 function V.destroy(r)
  for _,name in ipairs({'lid','screen','anchor'})do if valid(r[name])then r[name]:K2_DestroyComponent(r.actor)end end
 end
 return V
end
