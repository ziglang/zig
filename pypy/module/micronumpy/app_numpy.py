from __future__ import absolute_import

import math

import _numpypy
from _numpypy.multiarray import set_docstring

def arange(start, stop=None, step=1, dtype=None):
    '''arange([start], stop[, step], dtype=None)
    Generate values in the half-interval [start, stop).
    '''
    if stop is None:
        stop = start
        start = 0
    if dtype is None:
        # find minimal acceptable dtype but not less than int
        dtype = _numpypy.multiarray.result_type(start, stop, step, int)
    length = math.ceil((float(stop) - start) / step)
    length = int(length)
    arr = _numpypy.multiarray.empty(length, dtype=dtype)
    i = start
    for j in range(arr.size):
        arr[j] = i
        i += step
    return arr


def add_docstring(obj, docstring):
    old_doc = getattr(obj, '__doc__', None)
    if old_doc is not None:
        raise RuntimeError("%s already has a docstring" % obj)
    try:
        set_docstring(obj, docstring)
    except:
        raise TypeError("Cannot set a docstring for %s" % obj)
