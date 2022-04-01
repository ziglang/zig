class AppTestTest:
    def test_app_method(self):
        assert 42 == 41

def test_interp_func(space):
    assert space.is_true(space.w_None)

def test_interp_reinterpret(space):
    a = 1
    assert a == 2

class TestInterpTest:
    def test_interp_method(self):
        assert self.space.is_true(self.space.w_False)
