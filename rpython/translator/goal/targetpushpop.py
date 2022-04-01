"""
A simple standalone target.

The target below specifies None as the argument types list.
This is a case treated specially in driver.py . If the list
of input types is empty, it is meant to be a list of strings,
actually implementing argv of the executable.
"""

# __________  Entry point  __________

class A(object):
    pass

class B(object):
    pass

def f(x):
    if x == 0:
        return f(x - 1)
    b = B()
    b.x = x
    return b

global_a = A()

def entry_point(argv):
    a1 = A()
    a2 = A()
    a3 = A()
    a4 = A()
    global_a.next = a1
    a1.x = 1
    a2.x = 2
    a3.x = 3
    a4.x = 4
    a1.next = a2
    a2.next = a3
    a3.next = a4
    a4.next = None
    # push stuff
    global_a.b = f(len(argv))
    global_a.b.x = len(argv)
    # pop stuff
    return a1.x + a2.x + a3.x + a4.x + global_a.b.x

# _____ Define and setup target ___

def target(*args):
    return entry_point, None
