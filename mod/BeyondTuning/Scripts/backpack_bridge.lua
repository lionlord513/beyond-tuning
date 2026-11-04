-- Runs in Beyond Apocalypse's Lua state. Optional, event-driven integration.
return function(M,root)
 local N=M.backpack and M.backpack.native
 if not N or N.tunerLaptopBridge then return end
 N.tunerLaptopBridge=true
 local function valid(o)return o and o:IsValid()end
 local function laptop(a)
  if not valid(a)or not (a:GetFullName():match('^AttachableMaster_C ') or a:GetFullName():match('^BP_Gift_Noeud_C '))then return false end
  local out={};a:GetName(out)
  if out.Name and out.Name:ToString()=='Tuner Laptop'then return true end
  for _,v in ipairs(a:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.SceneComponent')))do if v:get().AttachSocketName:ToString():match('^BT_Laptop_%x+$')then return true end end
  return false
 end
 -- RMB belongs to the lid. Quick-store would otherwise consume the same click
 -- and serialize/destroy the physical item instead of letting it open or close.
 local looked=N.looked
 N.looked=function(pc,id)
  local item=looked(pc,id);if not valid(item)then return end
  if laptop(item)then return end
  if item:GetFullName():match('^ItemSavableMaster_C ')then
   local parent=item:GetAttachParentActor();if valid(parent) and laptop(parent)then return end
  end
  return item
 end
 local itemName,title,icon=M.itemName,N.title,N.icon
 M.itemName=function(a)
  if laptop(a) then return 'Tuner Laptop' end
  if valid(a) and a:GetFullName():match('^GasBarrelGaz_2_C ') then
   local out={};a:GetName(out)
   local name=out.Name and out.Name:ToString()
   if name and name:match('^Nitrous Stage ') then return name end
  end
  return itemName(a)
 end
 -- Older stored laptops have the carrier's old label. Resolve each snapshot
 -- only when displayed, through the game's normal loader, without editing bytes.
 local resolved={}
 N.title=function(d,b,k)
  local label=title(d,b,k)
  if label=='Tuner Laptop'then return label end
  if not valid(b)and label=='Attachable Master'and M.backpack.ui and valid(M.backpack.ui.bag)and M.backpack.ui.bag:HasAuthority()and valid(d.Class)then
   local token=N.token(d);if not resolved[token]then for slot,entry in pairs(N.nativeData(M.backpack.ui.bag))do if N.token(entry)==token then b=M.backpack.ui.bag;k=slot;break end end end
  end
  if valid(b)and b:HasAuthority()and valid(d.Class)and (d.Class:GetFullName():match('%.AttachableMaster_C$') or d.Class:GetFullName():match('%.BP_Gift_Noeud_C$'))then
   local token=N.token(d)
   if not resolved[token]then
    resolved[token]=true;local a
    local ok=pcall(function()
     local out={};b.BP_InventoryComponent:GetItemFromSlot(k,true,b:K2_GetActorLocation(),false,true,out);a=out.Item
     if valid(a)then a.FromInventory=false;a.LastInventoryComponent=nil;a.LastSlot=-1;if laptop(a)then N.remember(d,a)end end
    end)
    if valid(a)then a:K2_DestroyActor()end
    if not ok then resolved[token]=nil end
    label=title(d,b,k)
   end
  end
  return label
 end
 N.icon=function(d,pc)
  if N.title(d)=='Tuner Laptop'then
   if not valid(N.tunerLaptopIcon)then N.tunerLaptopIcon=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary'):ImportFileAsTexture2D(pc,root..'/assets/laptop/icon.png')end
   return N.tunerLaptopIcon
  end
  return icon(d,pc)
 end
end
