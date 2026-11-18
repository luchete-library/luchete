"""Second, hand-authored pixel pass: half-grid material clusters and silhouettes.

Coordinates are in the established logical grid. Half a unit is one native
pixel. These strokes add geometry, folds and lighting; no blur or random noise.
"""


def grain(a,x,y,w,light='#c3976d',dark='#aa7c58'):
    a.l([(x,y),(x+w*.3,y),(x+w*.4,y-.5),(x+w*.7,y-.5),(x+w,y)],dark,.5)
    a.l([(x+1,y+.5),(x+w*.3,y+.5)],light,.5)


def ring(a,x,y):
    a.r(x-1.5,y-1,3,.5,'gold0')
    a.l([(x-1.5,y),(x-1.5,y+1),(x-1,y+1.5),(x+1,y+1.5),(x+1.5,y+1),(x+1.5,y)],'gold0',.5)
    a.l([(x-1,y),(x-1,y+1),(x+1,y+1),(x+1,y)],'goldhi',.5)
    a.r(x-.5,y-1,1,1,'goldhi')


def spine(a,x,y,w,h,tone):
    a.r(x+.5,y+.5,w-1,h-1,tone)
    a.r(x+.5,y+1,.5,h-2,'#c2a88b')
    a.r(x+w-1,y+1,.5,h-1,'#443537')
    for yy in [y+1.5,y+h-2.5]:
        a.r(x+1.5,yy,max(.5,w-3),.5,'gold')
        a.r(x+1.5,yy+.5,max(.5,w-3),.5,'gold0')
    if w>=5:
        a.r(x+2,y+h*.4,w-3,3,'#d3c49e')
        a.r(x+2.5,y+h*.4+.5,w-4,.5,'#8c7e65')
        a.r(x+2.5,y+h*.4+1.5,max(.5,w-4.5),.5,'#8c7e65')
        a.r(x+2,y+h-4.5,w-3,.5,'#b9a274')
    else:
        a.r(x+2,y+4,.5,1,'gold')
        a.r(x+1.5,y+6,1,.5,'gold0')


def floor(a,variant):
    # Narrow seams let furniture carry the contrast, rather than a dark grid.
    tones=['#a27b5c','#a88060','#ac8463','#9f795c']
    tone=tones[variant]
    a.r(0,0,64,16,'#785b46')
    a.r(.5,.5,63,15,tone)
    a.r(.5,.5,63,.5,'#be9470')
    a.r(.5,15,63,.5,'#89664d')
    a.r(63,1,.5,14,'#906c50')
    # Flowing grain follows the same knot, not independent scattered scratches.
    kx=22+variant*7
    for offset in [-3,-1.5,1.5,3]:
        a.l([(3,8+offset),(kx-8,8+offset),(kx-4,8+offset*1.6),(kx+4,8+offset*1.6),(kx+9,8+offset),(60,8+offset+.5)],'#987152',.5)
    a.l([(kx-4,8),(kx-2,7),(kx+2,7),(kx+4,8),(kx+2,9),(kx-2,9),(kx-4,8)],'#87644b',.5)
    a.l([(kx-1,8),(kx+1,8)],'#b38b65',.5)
    a.l([(7,3),(17+variant,3),(19+variant,3.5),(30,3.5)],'#b18a65',.5)
    a.l([(36,12.5),(48,12.5),(51,12),(60,12)],'#b38a65',.5)
    for x in [2,61]:
        for y in [2,13]:
            a.r(x,y,.5,.5,'#705543');a.r(x,y+.5,.5,.5,'#bc9873')


def bookshelf(a,name):
    stage=int(name[-1]);story='_story_' in name;w=a.w
    for row in range(2):
        yy=6+row*19
        a.poly([(6,yy),(w-6,yy),(w-8,yy+3),(9,yy+3),(9,yy+16),(6,yy+16)],'#392e30')
        a.r(9,yy+16,w-16,.5,'#b28a5d')
        if not (story and row==1):
            cursor=9;idx=0
            while cursor<w-14:
                bw=[5,6,4,7,5,4][idx%6]
                bh=[13,15,12,14,11][(idx+row)%5]
                if (idx*3+row*2)%7<=stage:
                    tone=['green1','rose0','blue1','wood2','purple1','green2'][(idx+row)%6]
                    spine(a,cursor,yy+16-bh,bw,bh,tone)
                cursor+=bw+2;idx+=1
        a.r(5,yy+17.5,w-10,.5,'#e0bc87')
        a.r(5,yy+19,w-10,.5,'#624433')
        for x in range(15,w-18,31):grain(a,x,yy+18.5,16,'#ceac79','#ac835b')
    # Fluted posts, mitred trim and carved corner brackets.
    for x in [1,w-5]:
        a.r(x+1,8,.5,33,'#d1a271')
        a.r(x+2,8,.5,33,'#684637')
        for yy in [4,42]:
            a.r(x-.5,yy+.5,5,.5,'#edc995')
            a.r(x+.5,yy+1.5,3,.5,'#856039')
    for x,sign in [(6,1),(w-7,-1)]:
        a.l([(x,5),(x+sign*5,5),(x+sign*5,6),(x+sign*3,6),(x+sign*3,8),(x+sign,9)],'#b4895b',.5)
    for x in range(9,w-10,8):
        a.r(x,2,3,.5,'#d7b181');a.r(x+1,3,2,.5,'#75503b')
    a.r(1,46.5,w-2,.5,'#e3ba82')


def upholstery(a,rose=False):
    shade='#684753' if rose else '#3e5d50'
    middle='#a17484' if rose else '#74957c'
    light='#bd919e' if rose else '#9fb493'
    a.poly([(15,9),(32,9),(33,10),(33,22),(32,23),(15,23)],middle)
    a.l([(15.5,10),(31.5,10),(32,10.5),(32,21.5)],light,.5)
    a.l([(15,10),(15,22),(16,22.5),(32,22.5)],shade,.5)
    for x in [19,29]:
        for y in [13,20]:
            for dx,dy in [(-2,-2),(2,-2),(-2,2),(2,2)]:
                a.l([(x+dx,y+dy),(x,y)],shade,.5)
            a.r(x-.5,y-.5,1,1,shade);a.r(x-.5,y-.5,.5,.5,light)
            a.r(x+.5,y+1,.5,.5,light)
    # Curved, piped front edge of the cushion and a consistent contact shadow.
    a.poly([(12,27),(13,26),(34,26),(36,27),(36,30),(34,31),(14,31),(12,30)],middle)
    a.l([(13,27),(34,27),(35,27.5)],light,.5)
    a.l([(13,30),(15,31),(34,31),(35.5,30)],shade,.5)
    for x in range(15,34,3):a.r(x,28.5,.5,.5,light)
    for x in [11,35]:
        a.r(x+1,7,.5,17,'wood4');a.r(x+2,7,.5,17,'wood0')
    a.l([(12,6),(15,5.5),(33,5.5),(36,6)],'gold',.5)
    for x in [13,32]:
        a.r(x+.5,34,1,5,'wood3');a.r(x,38,3,.5,'wood4')
        a.r(x,40,3,.5,'wood0')


def table_details(a,desk=False):
    w=a.w
    # Shaped apron, recessed drawers and ring pulls replace flat blocks.
    a.r(6,25,w-12,1,'#4a3531')
    for x in range(9,w-18,21):
        a.r(x+.5,26.5,18,6,'#634532')
        a.r(x+1.5,27.5,16,4,'#a67a53')
        a.l([(x+1,27),(x+17.5,27)],'#d1a16b',.5)
        a.l([(x+2,31.5),(x+18,31.5)],'#543a2e',.5)
        grain(a,x+2,28.5,5,'#b98e60','#8f6445')
        ring(a,x+10,29)
    for x in [9,w-15]:
        a.r(x+.5,35,1,6,'#b58a5e')
        a.r(x+4,35,.5,7,'#513a31')
        a.r(x,39,6,.5,'#bd966b');a.r(x,40,6,.5,'#73503b')
        a.r(x-1,43,7,.5,'#bd966b')
    a.r(3,23,w-6,.5,'#edc993')
    a.r(3,25,w-6,.5,'#765139')
    for x in [5,w-10]:
        a.l([(x,15),(x,20),(x+4,20)],'#efcd96',.5)
        a.l([(x+1,15),(x+1,19),(x+4,19)],'#a77e4d',.5)
    # Tiny stitches on the green desk blotter, confined to its existing outline.
    for x in range(15,w-19,3):a.r(x,22,.5,.5,'#bdba88')
    a.r(13,14,w-31,.5,'#9bab84')
    a.r(13,21.5,w-31,.5,'#446354')
    # Page thickness and bowed lines in the open ledger.
    bx,bw=18,22 if desk else 27
    for dy in [0,.5,1]:
        a.l([(bx+1,20+dy),(bx+bw/2,22+dy),(bx+bw-2,20+dy)],'#bfa982' if dy==.5 else '#eddbad',.5)
    for y in [13,15.5,18]:
        a.l([(bx+3,y),(bx+7,y-.5),(bx+bw/2-2,y)],'#b69e79',.5)
        a.l([(bx+bw/2+3,y),(bx+bw-6,y+.5),(bx+bw-3,y+.5)],'#af9976',.5)
    a.l([(bx+bw/2,11),(bx+bw/2,21)],'#ab936e',.5)
    a.l([(bx+2,11),(bx+bw/2-1,10.5)],'#fff7d9',.5)
    if not desk:
        # Bound ruler, rolled vellum and individually notched feather barbs.
        a.r(84,20,10,1,'#b48c58')
        for x in range(85,94,2):a.r(x,20,.5,.5,'#684d3c')
        a.r(87,14,7,4,'#b5a07d');a.r(87,13.5,7,3,'#f0dfb6')
        a.r(87,14,1,2,'#aa9370');a.r(87.5,14.5,.5,1,'#fff2cf')
        a.r(88.5,14,5,.5,'#fff2cf')
        a.r(74.5,16,1,4,'#b3a4c5');a.r(78,17,1,3,'#655577')
        a.r(76,13.5,3,.5,'goldhi');a.r(76,14.5,3,.5,'gold0')
        a.l([(77.5,15),(85,1)],'#997f62',.5)
        for y in range(3,10,2):
            x=85-(y-1)*.5
            a.l([(x-1.5,y-1),(x,y),(x+1.5,y-.5)],'#fff3d5',.5)
        a.r(56,14,10,.5,'#fff0cf')
        a.l([(64,13),(64,15),(66,15)],'#c3ab82',.5)
        a.r(50,19.5,2,.5,'#d29285');a.r(51,20,.5,.5,'#6e4145')
    else:
        a.r(w-16,10,1,5,'#d1aa73');a.r(w-13,10,.5,5,'#654535')
        a.r(w-17,7.5,5,.5,'#b0c1a1')
        a.r(w-18,18,8,.5,'#e8b279')


def tea_table(a):
    # Bevel and underside remain below the character's hands.
    a.r(8,31,32,.5,'#efd2a1');a.r(7,33,34,.5,'#5b3e31')
    for x in [10,36]:
        a.r(x+.5,35,1,5,'#c59d6a');a.r(x,40,3,.5,'#73513b')
    for x in range(16,32,2):a.r(x,29,.5,.5,'#c7af8b')
    a.r(15.5,26.5,15,.5,'#fff3d9')
    a.poly([(31.5,22),(33,20.5),(36,20.5),(38,22),(38,25),(36.5,27),(33,27),(31.5,25)],'#648c82')
    a.poly([(32.5,22),(34,21),(36,21.5),(37,23),(37,25),(35,26),(33,25)],'#b8cbb0')
    a.l([(33,22),(33,24.5),(34,25)],'#e2e4bd',.5)
    a.l([(37.5,22),(39,21.5),(39.5,22),(39.5,24),(38,24.5)],'#b8cbb0',.5)
    a.poly([(32,23),(30,21),(29.5,21.5),(31.5,25)],'#8dab98')
    a.r(33,20,4,.5,'#dbe2ba');a.r(34,19.5,2,.5,'#688e81')
    a.l([(11,27.5),(12,28),(15,28),(16,27.5)],'#b29873',.5)
    a.r(12,25.5,3,1.5,'#fff0cf');a.r(13,25.5,2,.5,'#9d805d')
    a.l([(15,26),(16,26),(16,27),(15,27)],'#f1deb5',.5)


def textiles(a,name):
    w,h=a.w,a.h
    tone={'rug_main':'#3a5750','rug_read':'#516f61','rug_tea':'#7c5263','rug_exercise':'#635675','rug_stream':'#405c70'}[name]
    # Herringbone binding and individually knotted fringes.
    for x in range(6,w-6,3):
        a.l([(x,5),(x+1,5.5),(x+2,5)],'#beab7b',.5)
        a.l([(x,h-6),(x+1,h-6.5),(x+2,h-6)],'#9c8d66',.5)
    for y in range(11,h-11,5):
        for x in [5,w-6]:
            a.l([(x,y),(x+1,y+1),(x,y+2)],'#c3ad78',.5)
    for x in range(4,w-3,4):
        a.r(x,1,.5,2,'#e0c697');a.r(x+.5,h-2,.5,2,'#9e845f')
    for x in [12,w-13]:
        for y in [14,h-15]:
            for dx,dy in [(-5,0),(5,0),(0,-5),(0,5)]:
                a.l([(x,y),(x+dx*.6,y+dy*.6),(x+dx,y+dy)],'#a89b70',.5)
                a.r(x+dx-.5,y+dy-.5,1,1,'#d1b97f')
    # Tone-on-tone woven diamonds are kept below the characters' contrast.
    for y in range(21,h-18,12):
        for x in range(21,w-18,14):
            a.l([(x-1,y),(x,y-.5),(x+1,y),(x,y+.5),(x-1,y)],tone,.5)
    cx,cy=w//2,h//2
    r=min(w,h)//5
    a.l([(cx,cy-r-1),(cx+r+1,cy),(cx,cy+r+1),(cx-r-1,cy),(cx,cy-r-1)],tone,.5)


def glass_window(a,name):
    # Reflections stay inside panes; an opaque mullion still reads in front.
    for x,y,w in [(10,9,10),(26,9,10),(10,27,8),(26,27,10)]:
        a.poly([(x,y),(x+3,y),(x+w,y+8),(x+w-2,y+8)],'#a3bcb5')
        a.l([(x,y+1),(x+w-1,y+8)],'#b9cec1',.5)
    a.r(22,7,.5,32,'#ecc995');a.r(24,7,.5,32,'#634b3c')
    a.r(7,23,34,.5,'#e9c58d');a.r(7,25,34,.5,'#634b3c')
    a.r(21,29,1.5,1,'gold');a.r(21,30,1.5,.5,'gold0')
    a.r(2,41,44,.5,'#f0cb94');a.r(4,44,40,.5,'#6a4936')
    if name=='window_boarded':
        # Keep all added glass work behind the two original planks.
        for y in [12,28]:
            a.poly([(2,y+3),(43,y),(44,y+5),(3,y+8)],'wood0')
            a.poly([(3,y+3),(43,y+1),(43,y+4),(3,y+6)],'wood2')
            a.l([(5,y+4),(22,y+3),(40,y+2)],'#b2875e',.5)
            a.r(5,y+4,1,1,'wood0');a.r(40,y+2,1,1,'wood0')
    else:
        for x in [1,40]:
            a.poly([(x,3),(x+7,3),(x+5,20),(x+3,25),(x+1,32)],'#47675b')
            a.l([(x+1,4),(x+2,14),(x+1.5,23),(x+1,30)],'#a4b697',.5)
            a.l([(x+3,4),(x+4,12),(x+3,20)],'#789b80',.5)
            a.l([(x+5,4),(x+5,11),(x+4,20)],'#304c45',.5)
            a.r(x+1,22,4,1,'gold');a.r(x+2,22.5,2,.5,'goldhi')
            a.l([(x+3,23),(x+4,27),(x+3,29)],'gold0',.5)


def foliage(a,name):
    a.poly([(8,30),(10,30),(11,35),(19,35),(20,30),(22,30),(20,37),(9,37)],'#a47554')
    a.r(9,30,1,5,'#d4ae78');a.r(11,35,7,.5,'#d4ae78')
    a.r(7,27.5,15,.5,'#eed1a0');a.r(7,29,16,.5,'#6e4e3e')
    a.r(10,32,10,.5,'#ba9164')
    leaves=[(6,19),(15,15),(4,10),(14,5),(10,2)]
    for x,y in leaves[:5 if name=='plant_lush' else 3]:
        a.l([(x+1,y+2),(x+4,y+2),(x+8,y+4)],'#bdd0a1',.5)
        a.l([(x+2,y+3),(x+8,y+5),(14,y+8)],'#3f6650',.5)
        for k in [3,5,7]:
            a.l([(x+k,y+4),(x+k-1,y+2.5)],'#829f7a',.5)
        a.r(x+2,y+2.5,.5,.5,'#d2dcab')


def small_lamp(a,lit):
    a.r(7,3,.5,6,'#f1d19a');a.r(8.5,3,.5,6,'#614a3c')
    for x,sign in [(3,1),(12,-1)]:
        a.l([(x,12),(x+sign,21)],'#eac68a' if lit else '#b6a781',.5)
    a.r(4,13,1,8,'#dcb67b' if lit else '#9d967e')
    a.r(9.5,13,1,8,'#d4aa69' if lit else '#8d8874')
    a.r(6.5,15,1,5,'#fff4cf' if lit else '#bdb394')
    a.r(2,23.5,11,.5,'#f0d497');a.r(4,24.5,7,.5,'#6b503c')


def portal_details(a):
    for x in [5,36]:
        a.r(x+.5,11,.5,26,'#f2cf90');a.r(x+1.5,11,.5,26,'#916c42')
        for y in [12,34]:
            a.l([(x-1,y),(x+2,y),(x+2,y+2),(x,y+2)],'#b7935d',.5)
    for x in [14,26]:
        a.l([(x,13),(x+3,16),(x,19),(x-2,16),(x,13)],'#93b6a3',.5)
        a.l([(x,28),(x+3,31),(x,34),(x-2,31),(x,28)],'#557d72',.5)
    a.r(21,8,.5,33,'#f2d9aa');a.r(22.5,8,.5,33,'#8b7a56')
    for x in [18,26]:
        a.r(x,30,.5,2,'#f1d797');a.r(x+.5,30,.5,2,'#846c44')
    a.l([(4,45),(39,45)],'#eed1a0',.5)
    a.l([(6,47),(37,47)],'#76543b',.5)


def ui_detail(a,name):
    # UI remains on its original 1:1 grid so these pixels stay sharp on screen.
    a.r(8,2,16,1,'#e3bc86');a.r(8,3,16,1,'#b78c5b')
    for x,y,w in [(10,2,4),(19,2,3),(13,29,5),(21,29,2)]:a.r(x,y,w,1,'#ac7d50')
    a.r(2,10,1,7,'#c49b6d');a.r(29,12,1,5,'#8b6546')
    if name!='ui_slot':
        for x in [3,25]:
            for y in [3,25]:
                a.r(x,y,4,4,'#785b3c');a.r(x,y,3,3,'#dcc18a')
                a.r(x,y,3,1,'#ffe5b0');a.r(x+1,y+1,1,1,'#6a513a')
                a.r(x+1,y+2,2,1,'#b59765')
    else:
        for x in [4,26]:
            for y in [4,26]:a.r(x,y,2,1,'#e8c38d')


def icon_detail(a,kind):
    if kind=='bag':
        a.r(4.5,7,1,9,'#d2a166');a.r(15.5,8,.5,8,'#74503a')
        a.l([(6,2),(6,4),(7,4)],'#d6b07b',.5)
        for x in [6,8,12,14]:a.r(x,12,.5,.5,'#e6c89b')
        a.r(9.5,10.5,2,.5,'#ffdf9b');a.r(10,11,1,1,'#805d3c')
    elif kind in ['requests','paper']:
        a.r(4.5,3,.5,12,'#fff8dc')
        a.l([(12,2),(12,4),(14,4)],'#ceb78c',.5)
        a.r(11,15,1,.5,'#d39491')
    elif kind=='ink':
        a.l([(5,10),(5,14),(6,15)],'#ddd4e0',.5)
        a.r(7,2.5,6,.5,'#f3d59c');a.r(13.5,9,.5,7,'#9684a2')
        a.r(10,12,3,.5,'#b5a080')
    elif kind in ['journal','table']:
        a.r(3,5,.5,10,'#c4b58d');a.r(15.5,6,.5,9,'#324d47')
        if kind=='table':
            for y in [7,10,13]:a.r(5,y,3,.5,'#b5a080');a.r(12,y,3,.5,'#b5a080')
        else:a.r(7,5,7,.5,'#e8cf99');a.r(7,15,7,.5,'#c8ad76')
    elif kind=='loans':
        a.r(7,2.5,7,.5,'#b9cba7');a.r(8.5,7,1,4,'#cda16e')
        a.r(5,14,10,.5,'#e6be85')
    elif kind=='sleep':
        a.r(7,4,.5,5,'#b6c79f');a.r(12,7,1,1,'#54765c')
        a.r(6,12,8,.5,'#c0d1a2');a.r(4,11,1,.5,'#f0cb8e')
    elif kind=='bookmark':
        a.r(7,3,.5,12,'#c28a91');a.r(12.5,4,.5,11,'#6e4d5d')
        a.r(9,7,.5,.5,'#fff0bd')
    elif kind=='portal':
        a.r(3.5,3,.5,14,'#f6dca6');a.r(15.5,3,.5,14,'#916f46')
        a.r(6.5,5,.5,7,'#9fc6b1')


def book_detail(a,name):
    if name=='book_closed_detail':
        for x,sign in [(5,1),(12,-1)]:
            for y,dy in [(4,1),(17,-1)]:
                a.l([(x,y+dy*2),(x,y),(x+sign*2,y)],'#e3c18a',.5)
                a.r(x+sign*.5,y+dy*.5,.5,.5,'#fff0bd')
        a.l([(7,10),(9,8),(11,10),(9,12),(7,10)],'#af8b56',.5)
        a.r(4,22.5,11,.5,'#fff0c9');a.r(4,23.5,10,.5,'#b6a27d')
        a.r(11.5,21,1,.5,'#d79991')
    elif name=='book_open_detail':
        for y in [6.5,9.5,12.5]:
            a.l([(4,y),(7,y-.5),(10,y)],'#c2aa7e',.5)
            a.l([(16,y),(20,y+.5),(23,y+.5)],'#b6a07a',.5)
        a.r(12,3,.5,12,'#dbca9e')
        a.r(2,15.5,10,.5,'#c5b18a');a.r(14,16,10,.5,'#c5b18a')


def refine(a,name):
    if name.startswith('floor_plank_'):floor(a,int(name[-1]))
    elif name.startswith('shelf_'):bookshelf(a,name)
    elif name.startswith('rug_'):textiles(a,name)
    elif name in ['work_table','lending_desk']:table_details(a,name=='lending_desk')
    elif name in ['chair_back','tea_back']:upholstery(a,name=='tea_back')
    elif name=='chair_front':
        for x in [9,35]:
            a.r(x+.5,26,1,9,'#c59a67');a.r(x+2.5,26,.5,9,'#523b30')
            a.r(x-1,21.5,5,.5,'#edcc99');a.r(x,24,4,.5,'#745139')
    elif name=='tea_front':tea_table(a)
    elif name.startswith('window_'):glass_window(a,name)
    elif name.startswith('plant_'):foliage(a,name)
    elif name.startswith('lamp_'):small_lamp(a,name=='lamp_on')
    elif name=='garden_door':portal_details(a)
    elif name=='notice_board':
        for x,y in [(5,5),(18,7),(11,13)]:
            a.r(x+.5,y+.5,7,.5,'#fff3d5');a.r(x+2,y+7,4,.5,'#c4ad82')
            a.r(x+4,y,.5,.5,'#f0b1a1')
        a.r(2,2,29,.5,'#e4bc87');a.r(2,23,29,.5,'#6a4b37')
    elif name.startswith('ui_'):ui_detail(a,name)
    elif name.startswith('icon_'):icon_detail(a,name.removeprefix('icon_'))
    elif name.startswith('book_'):book_detail(a,name)
