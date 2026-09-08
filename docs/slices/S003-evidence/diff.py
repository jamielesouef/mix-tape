import sys
from PIL import Image, ImageChops, ImageStat
a=Image.open(sys.argv[1]).convert("RGB"); b=Image.open(sys.argv[2]).convert("RGB")
# regions in full-res px (1206x2622). Accessory container ~ y 2205..2345, x 62..1145. Inner pill ~ x 105..1100, y 2215..2335
R={
 "container-left-margin (outside pill)":(64,2215,103,2335),
 "container-right-margin (outside pill)":(1102,2215,1143,2335),
 "container-top-margin (outside pill)":(105,2207,1100,2213),
 "pill-interior (app glassChrome, text-free)":(760,2225,980,2325),
 "control: status bar":(300,20,900,120),
 "control: content above accessory (should shift)":(100,1900,1100,2100),
}
for k,(x0,y0,x1,y1) in R.items():
    d=ImageChops.difference(a.crop((x0,y0,x1,y1)),b.crop((x0,y0,x1,y1)))
    s=ImageStat.Stat(d); mean=sum(s.mean)/3; mx=max(max(ch) for ch in [d.getextrema()[i] for i in range(3)])
    print(f"{k:50s} mean|Δ|={mean:6.2f}  max|Δ|={mx:3d}")
