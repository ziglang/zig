#!/usr/bin/python
from array import array

def f(img):
    l=0
    i=0;
    while i<640*480:
        l+=img[i]
        i+=1
    return l

img=array('d', (0,)) * (640*480)
    
for l in range(500): f(img)

#           C          pypy-simple pypy        cpython
# sumtst:   0m0.630s   0m0.659s    0m0.851s    0m33.447s
# intimg:   0m0.646s   0m1.078s    0m1.446s    1m0.279s
