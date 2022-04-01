#!/usr/bin/python
from array import array

def f(img, intimg):
    l=0
    i=640    
    while i<640*480:
        l+=img[i]
        intimg[i]=intimg[i-640]+l
        i+=1
    return l



img=array('d','\x00'*640*480*8)
intimg=array('d','\x00'*640*480*8)

for l in range(500): f(img, intimg)
