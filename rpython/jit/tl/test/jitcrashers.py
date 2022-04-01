def jit_simple_loop():
    print "simple loop"

    i = 0
    while i < 200:
        i = i + 3
    print i
    #assert i == 102

def jit_simple_inplace_add():
    print "simple loop with inplace_add"

    i = 0
    while i < 200:
        i += 3
    print i

def jit_range():
    print "range object, but outside the loop"

    s = 0
    for i in range(200):
        s = s + i
    print s

def jit_exceptions():
    try:
        i = 200
        while i > 0:
            if i == 10:
                raise IndexError
            i -= 1
    except IndexError:
        pass
    else:
        raise AssertionError

def jit_simple_bridge():
    s = 0
    for i in range(200):
        if i % 2:
            s += 1
        else:
            s += 2
    print s

def jit_tuple_indexing():
    t = (1, 2, 3)
    i = 0
    while i < 200:
        t = t[1], t[2], t[0]
        i += 1
    print t

def jit_nested_loop():
    print     "Arbitrary test function."
    n = 100
    i = 0
    x = 1
    while i<n:
        j = 0   #ZERO
        while j<=i:
            j = j + 1
            x = x + (i&j)
        i = i + 1
    print x
    return x

def jit_another_loop():
    n = "hello"
    i = 0
    while i < 150:
        i = i + 1
    print n

def jit_loop_with_call():
    i = 0
    k = 0
    while i < 20000:
        k += call(i)
        i += 1

def call(i):
    k = 0
    for j in range(i, i + 2):
        if j > i + 2:
            raise Exception("Explode")
        k += 1
    return k

def jit_importing_posixpath():
    import os
    import posixpath

def jit_importing_site():
    import site

def jit_unicode_formatting():
    d = []
    for i in range(1000):
        d[i] = u'\\xyz%d' % i

