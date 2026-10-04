import sys, os
from PIL import Image, ImageDraw
d=sys.argv[1]; n=int(sys.argv[2]) if len(sys.argv)>2 else 12
fs=sorted(f for f in os.listdir(d) if f.endswith('.jpeg'))
t0=int(fs[0].split('.')[0])
step=max(1,len(fs)//n); pick=fs[::step][:n]
W,H=220,476; cols=6; rows=(len(pick)+cols-1)//cols
sheet=Image.new('RGB',(W*cols,(H+24)*rows),'white'); dr=ImageDraw.Draw(sheet)
for i,f in enumerate(pick):
    im=Image.open(os.path.join(d,f)).resize((W,H)); x=(i%cols)*W; y=(i//cols)*(H+24)
    sheet.paste(im,(x,y+24)); dr.text((x+4,y+4),f"{(int(f.split('.')[0])-t0)/1e9:.1f}s",fill='black')
sheet.save(sys.argv[3] if len(sys.argv)>3 else d+'_contact.jpg'); print(len(fs),'frames', (int(fs[-1].split('.')[0])-t0)/1e9,'s')
