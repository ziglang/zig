

class AppTestIntOp:
    spaceconfig = dict(usemodules=['__pypy__'])

    def w_intmask(self, n):
        import sys
        n &= (sys.maxsize*2+1)
        if n > sys.maxsize:
            n -= 2*(sys.maxsize+1)
        return int(n)

    def test_intmask(self):
        import sys
        assert self.intmask(sys.maxsize) == sys.maxsize
        assert self.intmask(sys.maxsize+1) == -sys.maxsize-1
        assert self.intmask(-sys.maxsize-2) == sys.maxsize
        N = 2 ** 128
        assert self.intmask(N+sys.maxsize) == sys.maxsize
        assert self.intmask(N+sys.maxsize+1) == -sys.maxsize-1
        assert self.intmask(N-sys.maxsize-2) == sys.maxsize

    def test_int_add(self):
        import sys
        from __pypy__ import intop
        assert intop.int_add(40, 2) == 42
        assert intop.int_add(sys.maxsize, 1) == -sys.maxsize-1
        assert intop.int_add(-2, -sys.maxsize) == sys.maxsize

    def test_int_sub(self):
        import sys
        from __pypy__ import intop
        assert intop.int_sub(40, -2) == 42
        assert intop.int_sub(sys.maxsize, -1) == -sys.maxsize-1
        assert intop.int_sub(-2, sys.maxsize) == sys.maxsize

    def test_int_mul(self):
        import sys
        from __pypy__ import intop
        assert intop.int_mul(40, -2) == -80
        assert intop.int_mul(-sys.maxsize, -sys.maxsize) == (
            self.intmask(sys.maxsize ** 2))

    def test_int_floordiv(self):
        import sys
        from __pypy__ import intop
        assert intop.int_floordiv(41, 3) == 13
        assert intop.int_floordiv(41, -3) == -13
        assert intop.int_floordiv(-41, 3) == -13
        assert intop.int_floordiv(-41, -3) == 13
        assert intop.int_floordiv(-sys.maxsize, -1) == sys.maxsize
        assert intop.int_floordiv(sys.maxsize, -1) == -sys.maxsize

    def test_int_mod(self):
        import sys
        from __pypy__ import intop
        assert intop.int_mod(41, 3) == 2
        assert intop.int_mod(41, -3) == 2
        assert intop.int_mod(-41, 3) == -2
        assert intop.int_mod(-41, -3) == -2
        assert intop.int_mod(-sys.maxsize, -1) == 0
        assert intop.int_mod(sys.maxsize, -1) == 0

    def test_int_lshift(self):
        import sys
        from __pypy__ import intop
        if sys.maxsize == 2**31-1:
            bits = 32
        else:
            bits = 64
        assert intop.int_lshift(42, 3) == 42 << 3
        assert intop.int_lshift(0, 3333) == 0
        assert intop.int_lshift(1, bits-2) == 1 << (bits-2)
        assert intop.int_lshift(1, bits-1) == -sys.maxsize-1 == (-1) << (bits-1)
        assert intop.int_lshift(-1, bits-2) == (-1) << (bits-2)
        assert intop.int_lshift(-1, bits-1) == -sys.maxsize-1
        assert intop.int_lshift(sys.maxsize // 3, 2) == (
            self.intmask((sys.maxsize // 3) << 2))
        assert intop.int_lshift(-sys.maxsize // 3, 2) == (
            self.intmask((-sys.maxsize // 3) << 2))

    def test_int_rshift(self):
        from __pypy__ import intop
        assert intop.int_rshift(42, 3) == 42 >> 3
        assert intop.int_rshift(-42, 3) == (-42) >> 3
        assert intop.int_rshift(0, 3333) == 0
        assert intop.int_rshift(-1, 0) == -1
        assert intop.int_rshift(-1, 1) == -1

    def test_uint_rshift(self):
        import sys
        from __pypy__ import intop
        if sys.maxsize == 2**31-1:
            bits = 32
        else:
            bits = 64
        N = 1 << bits
        assert intop.uint_rshift(42, 3) == 42 >> 3
        assert intop.uint_rshift(-42, 3) == (N-42) >> 3
        assert intop.uint_rshift(0, 3333) == 0
        assert intop.uint_rshift(-1, 0) == -1
        assert intop.uint_rshift(-1, 1) == sys.maxsize
        assert intop.uint_rshift(-1, bits-2) == 3
        assert intop.uint_rshift(-1, bits-1) == 1

    def test_mulmod(self):
        from __pypy__ import intop
        assert intop.int_mulmod(9373891, 9832739, 2**31-1) == 1025488209
