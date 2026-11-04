"""Build a clean Nexus/BMM archive. Never include runtime state or test files."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
mod=root/'mod/BeyondTuning'
meta=json.loads((mod/'bmm.json').read_text())
version=meta['Version'];out=root/'build';out.mkdir(exist_ok=True)
name=f'BeyondTuning-{version}-Nexus.zip';archive=out/name
allowed={'bmm.json','enabled.txt','state/KEEP.txt','assets/icon.png','assets/native/BeyondTuningNative.dll','presets/Stock.json','presets/Street.json','presets/Economy.json'}
allowed.update('presets/'+name for name in json.loads((root/'tools/example-presets.json').read_text()))
allowed.update('assets/laptop/'+name for name in ['base.lua','lid.lua','screen.lua','laptop.png','normal.png','roughness.png','black.png','white.png','wallpaper.png','icon.png','ATTRIBUTION.txt'])
allowed.update('assets/nitrous/'+name for name in ['ATTRIBUTION.txt','bottle.lua','collider.gltf','blue-textures.gltf','purple-textures.gltf','blue.png','purple.png'])
allowed.update({'assets/native/BeyondImports.dll','assets/native/BeyondMotorcycle.dll','assets/laptop/base.gltf','assets/laptop/pickup.gltf'})
allowed.update('assets/nitrous/'+name for name in ['plastic-normal.png','roughness.png','rifle-metal.png','clean-ao.png'])
prefix='DriveBeyondHorizons/Binaries/Win64/ue4ss/Mods/BeyondTuning/'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for file in sorted(mod.rglob('*')):
  if file.is_file():
   rel=file.relative_to(mod).as_posix()
   if rel in allowed or (rel.startswith('Scripts/') and file.suffix=='.lua'):z.write(file,prefix+rel)
 for file in sorted((root/'docs/screenshots').glob('*.png')):z.write(file,file.relative_to(root).as_posix())
 for name2 in ['README.md','CHANGELOG.md','LICENSE.txt','TESTING.md']:
  if (root/name2).exists():z.write(root/name2,name2)
sha=hashlib.sha256(archive.read_bytes()).hexdigest()
(out/'SHA256SUMS.txt').write_text(f'{sha}  {name}\n',encoding='utf-8')
manifest={'schema':1,'version':version,'channel':'stable','asset':name,'url':f'https://github.com/lionlord513/beyond-tuning/releases/download/v{version}/{name}','sha256':sha,'size':archive.stat().st_size,'notes':[meta['Changelog']]}
(out/'bmm-mod.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(f'{archive}\nSHA256 {sha}')
