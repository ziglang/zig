
class AppTestJitNotInTrace(object):
    spaceconfig = dict(usemodules=('pypyjit',))

    def test_not_from_assembler(self):
        import pypyjit
        @pypyjit.not_from_assembler
        def f(x, y):
            return 42
        r = f(3, 4)
        assert r is f

    def test_not_from_assembler_exception(self):
        import pypyjit
        @pypyjit.not_from_assembler
        def f(x, y):
            raise ValueError(y, x)
        e = raises(ValueError, f, 3, 4)
        assert e.value.args == (4, 3)
