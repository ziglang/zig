class AppTestSieve:
    spaceconfig = dict(usemodules=('_demo',))

    def test_sieve(self):
        import _demo
        lst = _demo.sieve(100)
        assert lst == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41,
                       43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97]
