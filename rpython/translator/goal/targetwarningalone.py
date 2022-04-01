
class Base(object):
    pass

class A(Base):
    a = 1
    b = 2
    c = 3

class B(Base):
    a = 2
    b = 2

class C(Base):
    b = 8
    c = 6

def f(n):
    if n > 3:
        x = A
    elif n > 1:
        x = B
    else:
        x = C
    if n > 0:
        return x.a
    return 9

# __________  Entry point  __________

def entry_point(argv):
    print f(int(argv[1]))
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None

if __name__ == '__main__':
    import sys
    entry_point(sys.argv)
