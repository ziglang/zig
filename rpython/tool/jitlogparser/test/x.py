
import pypyjit
pypyjit.set_param(threshold=3)

def f(a, b):
    return a + b

def g():
    i = 0
    while i < 10:
        a = 'foo'
        i += 1

def h():
    [x for x in range(10)]

g()
h()
