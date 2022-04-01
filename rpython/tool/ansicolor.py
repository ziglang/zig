class colors:
    black = '30'
    darkred = '31'
    darkgreen = '32'    
    brown = '33'
    darkblue = '34'
    purple = '35'
    teal = '36'
    lightgray = '37'
    darkgray = '30;01'
    red = '31;01'
    green = '32;01'
    yellow = '33;01'
    blue = '34;01'
    fuchsia = '35;01'
    turquoise = '36;01'
    white = '37;01'

def setcolor(s, color):
    return '\x1b[%sm%s\x1b[00m' % (color, s)

for name in colors.__dict__:
    if name.startswith('_'):
        continue
    exec("""
def %s(s):
    return setcolor(s, colors.%s)
""" % (name, name))
