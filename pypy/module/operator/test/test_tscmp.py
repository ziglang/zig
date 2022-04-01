from pypy.module.operator.tscmp import pypy_tscmp

class TestTimingSafeCompare:
    def test_tscmp_neq(self):
        assert not pypy_tscmp('asd', 'qwe', 3, 3)

    def test_tscmp_eq(self):
        assert pypy_tscmp('asd', 'asd', 3, 3)

    def test_tscmp_len(self):
        assert pypy_tscmp('asdp', 'asdq', 3, 3)

    def test_tscmp_nlen(self):
        assert not pypy_tscmp('asd', 'asd', 2, 3)
