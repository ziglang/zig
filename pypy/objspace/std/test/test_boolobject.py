class TestW_BoolObject:
    def setup_method(self,method):
        self.true = self.space.w_True
        self.false = self.space.w_False
        self.wrap = self.space.wrap

    def test_init(self):
        assert (self.false.intval, type(self.false.intval)) == (0, int)
        assert (self.true.intval, type(self.true.intval)) == (1, int)

    def test_repr(self):
        assert self.space.eq_w(self.space.repr(self.true), self.wrap("True"))
        assert self.space.eq_w(self.space.repr(self.false), self.wrap("False"))

    def test_true(self):
        assert self.space.is_true(self.true)

    def test_false(self):
        assert not self.space.is_true(self.false)

    def test_int_w(self):
        assert self.space.int_w(self.true) is 1
        assert self.space.int_w(self.false) is 0

    def test_uint_w(self):
        assert self.space.uint_w(self.true) == 1
        assert self.space.uint_w(self.false) == 0

    def test_rbigint_w(self):
        assert self.space.bigint_w(self.true)._digits == [1]
