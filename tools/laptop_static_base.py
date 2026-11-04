"""Build a visible glTF static mesh for the game's native physics handle."""
import base64, json, re, struct
from pathlib import Path

dest=Path(__file__).resolve().parents[1]/'mod/BeyondTuning/assets/laptop'
source=(dest/'base.lua').read_text()
def rows(key,fields):
    data=re.search(r'^'+key+r'=\{(.*)\},$',source,re.M)[1]
    return [tuple(float(x) for x in re.findall(r'=(?:\s*)([-+.\deE]+)',row)) for row in re.findall(r'\{([^{}]+)\}',data)]
pos=[(x/100,z/100,y/100) for x,y,z in rows('vertices',3)]
normal=[(x,z,y) for x,y,z in rows('normals',3)]
uv=rows('uv',2)
indices=list(map(int,re.search(r'triangles=\{([\d,]+)\}',source)[1].split(',')))
blob=bytearray();views=[];access=[]
def add(values,fmt,kind,num):
    while len(blob)%4:blob.append(0)
    offset=len(blob)
    for v in values:blob.extend(struct.pack('<'+fmt,*v))
    i=len(views);views.append(dict(buffer=0,byteOffset=offset,byteLength=len(blob)-offset))
    access.append(dict(bufferView=i,componentType=num,count=len(values),type=kind))
    return i
add(pos,'3f','VEC3',5126);access[0].update(min=list(map(min,zip(*pos))),max=list(map(max,zip(*pos))))
add(normal,'3f','VEC3',5126);add(uv,'2f','VEC2',5126);add([(i,)for i in indices],'H','SCALAR',5123)
doc=dict(asset=dict(version='2.0'),buffers=[dict(byteLength=len(blob),uri='data:application/octet-stream;base64,'+base64.b64encode(blob).decode())],bufferViews=views,accessors=access,meshes=[dict(primitives=[dict(attributes=dict(POSITION=0,NORMAL=1,TEXCOORD_0=2),indices=3)])],nodes=[dict(mesh=0)],scenes=[dict(nodes=[0])],scene=0)
(dest/'base.gltf').write_text(json.dumps(doc,separators=(',',':')))
print('Native laptop base dimensions (cm)',[(round(min(v),1),round(max(v),1)) for v in zip(*[(x*100,y*100,z*100) for x,z,y in pos])])
