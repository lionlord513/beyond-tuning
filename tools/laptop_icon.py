"""Draw the transparent Tuner Laptop inventory glyph at double resolution."""
from pathlib import Path
from PIL import Image, ImageDraw

im=Image.new('RGBA',(256,256));d=ImageDraw.Draw(im)
d.rounded_rectangle((48,39,220,159),radius=8,fill='#343d45',outline='#ccd5d6',width=3)
d.rectangle((57,49,211,149),fill='#0e202a',outline='#617a85',width=2)
for x in range(65,211,16): d.line((x,54,x,144),fill='#263c46')
for y in range(61,146,16): d.line((62,y,206,y),fill='#263c46')
d.line([(64,124),(84,119),(101,105),(118,108),(136,81),(153,75),(165,60),(182,69),(203,66)],fill='#48d2d8',width=4)
d.line([(64,134),(89,130),(111,120),(128,123),(147,101),(167,98),(187,87),(203,93)],fill='#ffaf53',width=3)
d.polygon([(48,159),(219,159),(238,205),(18,205)],fill='#737e85',outline='#d1d9dc')
d.polygon([(18,205),(238,205),(235,215),(24,215)],fill='#343e46',outline='#aebac1')
for j in range(4):
 for i in range(14):
  x=54-j*2+i*(10.8+j*.28);y=164+j*5
  d.rectangle((x,y,x+7.5,y+3),fill='#26343d')
d.polygon([(105,187),(143,187),(147,200),(99,200)],fill='#8d999e',outline='#495760')
im.resize((128,128),Image.Resampling.LANCZOS).save(Path(__file__).resolve().parents[1]/'mod/BeyondTuning/assets/laptop/icon.png',optimize=True)
