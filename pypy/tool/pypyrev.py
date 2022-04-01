
import pypy
import py

def pypyrev(cache=[]): 
    """ return subversion revision number for current pypy package. 
    """
    try:
        return cache[0]
    except IndexError: 
        pypydir = py.path.svnwc(pypy.__file__).dirpath()
        rev = pypydir.info().rev 
        cache.append(rev) 
        return rev 

