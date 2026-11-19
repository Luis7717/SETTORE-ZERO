import sys
from PIL import Image
fs=sys.argv[2:]
ims=[Image.open(f).convert('RGB').resize((390,844)) for f in fs]
out=Image.new('RGB',(390*len(ims),844)); x=0
for i in ims: out.paste(i,(x,0)); x+=390
out.save(sys.argv[1])
