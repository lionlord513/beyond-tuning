"""Reproducible example library for every engine in DBH build 26106988."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
# Engine families have different low-RPM needs. Each pair shares a native
# engine identity; normalized RPM maps remain valid across gearbox swaps.
engines=[
 ('Musgoat','MusgoatMotor_C','v8'),('Bonphiac','BP_Pontiac_Motor_C','v8'),
 ('C18','BP_C15_Motor_C','utility'),('Bolf','BP_Golf_Motor_C','compact'),
 ('GTR','BP_GTR_Motor_C','sport'),('IFA','BP_IFA_Motor_C','utility'),
 ('Dada','LadaMotor_C','compact'),('Poyopa','PoyopaMotor_C','utility'),
 ('TriClops','BP_Tucker_Motor_C','v8'),('UAZ','BP_UAZ_Motor_C','utility'),
 ('Aircraft','BP_Plane_Motor_C','aircraft'),('Tomahawk','MuscleCarMotor_C','v8'),
 ('Loft','BP_GermanCompact_Motor_C','compact'),('Kage','BP_JapaneseSporty_Motor_C','sport'),
 ('Escada','EscadaMotor_C','sport'),('Speedle','SpeedleMotor_C','compact'),
 ('P-51','BP_FrenchUtility_Engine_C','utility'),('Peak','PeakMotor_C','utility'),
 ('Froggy','BingoMotor_C','compact'),('KaijuG54','BP_KaijuR34_Motor_C','sport'),
 ('RotorGT7','RotorGT7Motor_C','rotary')]
drift={
 'v8':(115,110,[75,85,100,118,125,122,112,100]),
 'utility':(135,120,[95,110,130,140,135,125,105,90]),
 'compact':(130,120,[85,100,120,135,140,135,120,105]),
 'sport':(120,110,[75,85,105,120,135,140,130,115]),
 'rotary':(130,115,[85,95,110,125,140,140,135,125]),
 'aircraft':(110,105,[70,80,95,110,120,125,120,110])}
folder=root/'mod/BeyondTuning/presets';index=[]
for name,engine,family in engines:
 for mode in ('Drift','Race'):
  power,gearing,curve=drift[family]
  if mode=='Race':power=135;gearing={'utility':100,'compact':100,'v8':95,'sport':95,'rotary':100,'aircraft':90}[family];curve=[140]*8
  table=[]
  for r in range(5):
   table.append([min(140,max(60,round(100+(c-100)*((r+1)/5)))) for c in curve])
  tune=dict(power=power,gearing=gearing,limiter=115 if mode=='Race' else 105,shift=60 if mode=='Race' else 80,response=130 if mode=='Race' else 110,nitrous=200 if mode=='Race' else 50,turbos={},turboDefault=200 if mode=='Race' else 105,handling=mode.lower(),gearshape=mode.lower(),map=table)
  description=('SLIDY-style native drift assistance, rear drive, broad steering and a progressive torque map. Short gears sustain wheelspin; 50% nitrous favors duration.' if mode=='Drift' else 'Maximum engine output and fitted turbo contribution, fast shifts, stronger launch gears and taller top gears. Extra grip and lower rolling loss. 200% nitrous favors force.')
  if family=='aircraft':description+=' Handling applies to a wheeled car fitted with this engine, not aircraft flight controls.'
  p=dict(format='BeyondTuning',schema=1,name=f'{name} - {mode}',engine=engine,category=mode,description=description,tune=tune)
  file=f'Example - {name} - {mode}.json';(folder/file).write_text(json.dumps(p,indent=2)+'\n',encoding='utf-8');index.append(file)
(root/'tools/example-presets.json').write_text(json.dumps(index,indent=2)+'\n',encoding='utf-8')
print(f'Built {len(index)} presets for {len(engines)} engines')
