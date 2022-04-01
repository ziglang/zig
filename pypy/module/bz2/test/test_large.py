import py


class AppTestBZ2File:
    spaceconfig = dict(usemodules=('bz2',))

    def setup_class(cls):
        if not cls.runappdirect:
            py.test.skip("skipping this very slow test; try 'pypy-c -A'")
        largetest_bz2 = py.path.local(__file__).dirpath().join("largetest.bz2")
        cls.w_compressed_data = cls.space.newbytes(largetest_bz2.read('rb'))

    def test_decompress(self):
        from bz2 import decompress
        result = decompress(self.compressed_data)
        assert len(result) == 901179
