import sys
import time

try:
    import numpypy as numpy
except ImportError:
    import numpy

def get_matrix(n):
    import random
    x = numpy.zeros((n,n), dtype=numpy.float64)
    for i in range(n):
        for j in range(n):
            x[i][j] = random.random()
    return x

def main(n, r):
    x = get_matrix(n)
    y = get_matrix(n)
    a = time.time()
    for _ in xrange(r):
        #z = numpy.dot(x, y)  # uses numpy possibly-blas-lib dot
        z = numpy.core.multiarray.dot(x, y)  # uses strictly numpy C dot
    b = time.time()
    print '%d runs, %.2f seconds' % (r, b-a)

n = int(sys.argv[1])
try:
    r = int(sys.argv[2])
except IndexError:
    r = 1
main(n, r)
