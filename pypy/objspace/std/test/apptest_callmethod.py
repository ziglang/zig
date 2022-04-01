# The exec hacking is needed to have the code snippets compiled
# by our own compiler, not CPython's

def test_call_method():
    exec("""if 1:
        class C(object):
            def m(*args, **kwds):
                return args, kwds
            sm = staticmethod(m)
            cm = classmethod(m)

        c = C()
        assert c.m() == ((c,), {})
        assert c.sm() == ((), {})
        assert c.cm() == ((C,), {})
        assert c.m(5) == ((c, 5), {})
        assert c.sm(6) == ((6,), {})
        assert c.cm(7) == ((C, 7), {})
        assert c.m(5, x=3) == ((c, 5), {'x': 3})
        assert c.m(*range(5)) == ((c, 0, 1, 2, 3, 4), {})
        assert c.m(**{'u': 4}) == ((c,), {'u': 4})
    """)

def test_call_attribute():
    exec("""if 1:
        class C(object):
            def m(*args, **kwds):
                return args, kwds
        def myfunc(*args):
            return args

        c = C()
        c.m = c.m2 = myfunc
        assert c.m() == ()
        assert c.m(5, 2) == (5, 2)
        assert c.m2(4) == (4,)
        assert c.m2("h", "e", "l", "l", "o") == tuple("hello")
    """)

def test_call_module():
    exec("""if 1:
        import sys
        try:
            sys.exit(5)
        except SystemExit as e:
            assert e.args == (5,)
        else:
            raise Exception("did not raise?")
    """)

def test_custom_getattr():
    exec("""if 1:
        class C(object):
            def __getattr__(self, name):
                if name == 'bla':
                    return myfunc
                raise AttributeError
        def myfunc(*args):
            return args

        c = C()
        assert c.bla(1, 2, 3) == (1, 2, 3)
    """, {})

def test_custom_getattribute():
    exec("""if 1:
        class C(object):
            def __getattribute__(self, name):
                if name == 'bla':
                    return myfunc
                raise AttributeError
            def bla(self):
                Boom
        def myfunc(*args):
            return args

        c = C()
        assert c.bla(1, 2, 3) == (1, 2, 3)
    """, {})

def test_builtin():
    exec("""if 1:
        class C(object):
            foobar = len
        c = C()
        assert c.foobar("hello") == 5
    """)

def test_attributeerror():
    exec("""if 1:
        assert 5 .__add__(6) == 11
        try:
            6 .foobar(7)
        except AttributeError:
            pass
        else:
            raise Exception("did not raise?")
    """)

def test_kwargs():
    exec("""if 1:
        class C(object):
            def f(self, a):
                return a + 2
        
        assert C().f(a=3) == 5
    """)
