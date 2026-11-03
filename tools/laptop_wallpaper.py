"""Generate the mod's original static laptop wallpaper (Pillow)."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).resolve().parents[1]/'mod/BeyondTuning/assets/laptop/wallpaper.png'
im=Image.new('RGB',(960,600),(12,20,28));d=ImageDraw.Draw(im)
for y in range(600):d.line((0,y,960,y),fill=(12+y//90,20+y//70,28+y//40))
for x in range(0,960,40):d.line((x,0,x,600),fill=(26,40,50))
for y in range(0,600,40):d.line((0,y,960,y),fill=(26,40,50))
font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',62)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',24)
d.rounded_rectangle((65,148,895,445),radius=22,fill=(16,27,37),outline=(40,180,220),width=2)
d.text((115,192),'BEYOND TUNING',font=font,fill=(215,242,250))
d.text((118,286),'Your car. Your calibration.',font=small,fill=(108,200,226))
d.line((118,343,840,343),fill=(48,76,94),width=2)
d.text((118,373),'Click the screen to open your desktop',font=small,fill=(155,177,190))
im.save(p,optimize=True)
