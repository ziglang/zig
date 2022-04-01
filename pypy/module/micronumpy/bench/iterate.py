
try:
    import numpypy as numpy
except:
    import numpy

def f():
    sum = 0
    a = numpy.zeros(10000000)
    for i in range(10000000):
        sum += a[i]
    return sum

f()
