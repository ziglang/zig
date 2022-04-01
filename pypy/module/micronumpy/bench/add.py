
try:
    import numpypy as numpy
except:
    import numpy

def f():
    a = numpy.zeros(10000000)
    a = a + a + a + a + a
    # To ensure that the computation isn't totally optimized away.
    a[0] = 3.0

f()
