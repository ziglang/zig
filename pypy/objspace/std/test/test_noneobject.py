class TestW_NoneObject:
    def test_equality(self):
        assert self.space.eq_w(self.space.w_None, self.space.w_None)

    def test_inequality(self):
        neresult = self.space.ne(self.space.w_None, self.space.w_None)
        assert not self.space.is_true(neresult)

    def test_false(self):
        assert not self.space.is_true(self.space.w_None)

