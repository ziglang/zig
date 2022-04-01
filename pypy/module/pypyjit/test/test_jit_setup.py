class AppTestPyPyJIT:
    spaceconfig = dict(usemodules=('pypyjit',))

    def test_setup(self):
        # this just checks that the module is setting up things correctly, and
        # the resulting code makes sense on top of CPython.
        import pypyjit
        try:
            pypyjit.set_param(threshold=5, inlining=1)
            pypyjit.set_param("trace_eagerness=3,inlining=0")

            def f(x, y):
                return x*y+1

            assert f(6, 7) == 43

            def gen(x):
                i = 0
                while i < x:
                    yield i*i
                    i += 1

            assert list(gen(3)) == [0, 1, 4]
        finally:
            pypyjit.set_param('default')

    def test_no_jit(self):
        import pypyjit
        was_called = []
        def should_not_be_called(*args, **kwds):
            was_called.append((args, kwds))
        try:
            pypyjit.set_param('off')
            pypyjit.set_compile_hook(should_not_be_called)
            def f():
                pass
            for i in range(2500):
                f()
            assert not was_called
        finally:
            pypyjit.set_compile_hook(None)
            pypyjit.set_param('default')

    def test_doc(self):
        import pypyjit
        d = pypyjit.PARAMETER_DOCS
        assert type(d) is dict
        assert 'threshold' in d

    def test_interface_residual_call(self):
        import pypyjit
        def f(*args, **kwds):
            return (args, kwds)
        res = pypyjit.residual_call(f, 4, x=6)
        assert res == ((4,), {'x': 6})
