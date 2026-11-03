"""Convert the supplied CC BY laptop GLB to UE procedural mesh data.

Usage: python tools/import_laptop.py path/to/laptop.glb
No game assets or proprietary editor tools are required. Requires numpy, Pillow.
"""
from pathlib import Path
import json,struct,sys
import numpy as np
from PIL import Image

source=Path(sys.argv[1]);raw=source.read_bytes()
magic,version,length=struct.unpack_from('<III',raw)
assert magic==0x46546c67 and version==2 and length==len(raw)
chunks={};offset=12
while offset<len(raw):
 size,kind=struct.unpack_from('<II',raw,offset);offset+=8;chunks[kind]=raw[offset:offset+size];offset+=size
doc=json.loads(chunks[0x4e4f534a]);blob=chunks[0x004e4942]
dest=Path(__file__).resolve().parents[1]/'mod/BeyondTuning/assets/laptop';dest.mkdir(parents=True,exist_ok=True)

def accessor(index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
 dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']]
 width={'VEC2':2,'VEC3':3,'SCALAR':1}[a['type']]
 return np.ndarray((a['count'],width),dtype=dtype,buffer=blob,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',np.dtype(dtype).itemsize*width),np.dtype(dtype).itemsize)).copy()

def transform(node):
 x,y,z,w=node.get('rotation',[0,0,0,1])
 r=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
 return r@np.diag(node.get('scale',[1,1,1])),np.array(node.get('translation',[0,0,0]))

ue=np.array([[0,0,-1],[1,0,0],[0,1,0]])
parts={};zmin=1e9
for node in doc['nodes']:
 if 'mesh' not in node:continue
 mat,trans=transform(node)
 for prim in doc['meshes'][node['mesh']]['primitives']:
  original=accessor(prim['attributes']['POSITION'])
  positions=((original@mat.T)+trans)@ue.T*20
  normals=accessor(prim['attributes']['NORMAL'])@np.linalg.inv(mat)@ue.T
  normals/=np.linalg.norm(normals,axis=1)[:,None]
  uv=accessor(prim['attributes']['TEXCOORD_0'])
  name='base' if node['name'].lower()=='keyboard' else ('screen' if prim['material']==1 else 'lid')
  if name=='screen':
   uv=np.column_stack(((original[:,0]+.774889886)/(1.565731525),1-(original[:,1]-.342883855)/1.186498851))
  zmin=min(zmin,positions[:,2].min())
  # The handedness conversion already gives Unreal clockwise front faces.
  parts[name]=(positions,normals,uv,accessor(prim['indices']).flatten(),trans@ue.T*20)

def vectors(values,keys):
 return '{'+','.join('{'+','.join(k+'='+format(float(v),'.7g') for k,v in zip(keys,row))+'}' for row in values)+'}'

for name,(pos,norm,uv,tri,pivot) in parts.items():
 pos[:,2]-=zmin;pivot[2]-=zmin
 if name!='base':pos-=pivot
 else:pivot[:]=0
 text='-- Imported from ZwiebelGames, CC BY 4.0; see ATTRIBUTION.txt.\nreturn {\n'
 text+='pivot='+vectors([pivot],['X','Y','Z'])[1:-1]+',\n'
 for key,val,fields in [('vertices',pos,['X','Y','Z']),('normals',norm,['X','Y','Z']),('uv',uv,['X','Y'])]:text+=key+'='+vectors(val,fields)+',\n'
 tangents=np.zeros_like(pos);flip=np.zeros(len(pos),dtype=bool)
 for ids in tri.reshape(-1,3):
  a,b,c=ids;e=pos[b]-pos[a];f=pos[c]-pos[a];du=uv[b]-uv[a];dv=uv[c]-uv[a];det=du[0]*dv[1]-du[1]*dv[0]
  if abs(det)<1e-10:continue
  t=(e*dv[1]-f*du[1])/det;bit=(f*du[0]-e*dv[0])/det
  for i in ids:
   tangent=t-norm[i]*np.dot(norm[i],t);length=np.linalg.norm(tangent)
   if length>1e-10:
    tangents[i]=tangent/length;flip[i]=np.dot(np.cross(norm[i],tangents[i]),bit)<0
 text+='tangents={'+','.join('{TangentX='+vectors([t],['X','Y','Z'])[1:-1]+',bFlipTangentY='+str(bool(b)).lower()+'}' for t,b in zip(tangents,flip))+'},\n'
 text+='triangles={'+','.join(str(int(v)) for v in tri)+'}\n}\n'
 (dest/(name+'.lua')).write_text(text,encoding='utf-8')
 print(name,len(pos),'vertices',len(tri)//3,'triangles','pivot',pivot.tolist())
image=doc['images'][0];view=doc['bufferViews'][image['bufferView']]
(dest/'laptop.png').write_bytes(blob[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
for name,color in [('normal',(128,128,255,255)),('roughness',(235,235,235,255)),('black',(0,0,0,255)),('white',(255,255,255,255))]:Image.new('RGBA',(4,4),color).save(dest/(name+'.png'))
(dest/'ATTRIBUTION.txt').write_text('''Old low-poly laptop (PSX retro prop)
Creator: ZwiebelGames — https://sketchfab.com/ZwiebelGames
Source: https://sketchfab.com/3d-models/old-low-poly-laptop-psx-retro-prop-a2d9f3d0080b412983e19825aace11b5
License: Creative Commons Attribution 4.0 International
https://creativecommons.org/licenses/by/4.0/

Modifications for Beyond Tuning: converted coordinate system and units; separated
base, hinged lid and screen; remapped screen UVs for the in-game display.
The original model and its texture remain licensed under CC BY 4.0.
The creator does not endorse this mod. Flat utility textures are by Beyond Tuning.
''',encoding='utf-8')
