# test about the binop operation rule, see issue 412

class Base(object):
    def __init__(self, name):
        self.name = name

def lookup_where(obj, name):
    mro = type(obj).__mro__
    for t in mro:
        if name in t.__dict__:
            return t.__dict__[name], t
    return None, None

def refop(x, y, opname, ropname):
    # this has been validated by running the tests on top of cpython
    # so for the space of possibilities that the tests touch it is known
    # to behave like cpython as long as the latter doesn't change its own
    # algorithm
    t1 = type(x)
    t2 = type(y)
    op, where1 = lookup_where(x, opname)
    rop, where2 = lookup_where(y, ropname)
    if op is None and rop is not None:
        return rop(y, x)
    if rop and where1 is not where2:
        if (issubclass(t2, t1) and not issubclass(where1, where2)
            and not issubclass(t1, where2)
            ):
            return rop(y, x)
    if op is None:
        return "TypeError"
    return op(x,y)

def do_test(X, Y, name, impl):
    x = X('x')
    y = Y('y')
    opname = '__%s__' % name
    ropname = '__r%s__' % name

    count = [0]
    fail = []

    def check(z1, z2):
        ref = refop(z1, z2, opname, ropname)
        try:
            v = impl(z1, z2)
        except TypeError:
            v = "TypeError"
        if v != ref:
            fail.append(count[0])

    def override_in_hier(n=6):
        if n == 0:
            count[0] += 1
            check(x, y)
            check(y, x)
            return

        f = lambda self, other: (n, self.name, other.name)
        if n%2 == 0:
            name = opname
        else:
            name = ropname

        for C in Y.__mro__:
            if name in C.__dict__:
                continue
            if C is not object:
                setattr(C, name, f)
            override_in_hier(n-1)
            if C is not object:
                delattr(C, name)

    override_in_hier()
    #print count[0]
    return fail

def test_binop_combinations_mul():
    class X(Base):
        pass
    class Y(X):
        pass

    fail = do_test(X, Y, 'mul', lambda x,y: x*y)
    #print len(fail)
    assert not fail



def test_binop_combinations_sub():
    class X(Base):
        pass
    class Y(X):
        pass

    fail = do_test(X, Y, 'sub', lambda x,y: x-y)
    #print len(fail)
    assert not fail


def test_binop_combinations_pow():
    class X(Base):
        pass
    class Y(X):
        pass

    fail = do_test(X, Y, 'pow', lambda x,y: x**y)
    #print len(fail)
    assert not fail

def test_binop_combinations_more_exhaustive():
    class X(Base):
        pass

    class B1(object):
        pass

    class B2(object):
        pass

    class X1(B1, X, B2):
        pass

    class C1(object):
        pass

    class C2(object):
        pass

    class Y(C1, X1, C2):
        pass

    fail = do_test(X, Y, 'sub', lambda x,y: x-y)
    #print len(fail)
    assert not fail
