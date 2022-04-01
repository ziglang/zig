def test_overriding_base_binop_explict():
    class MulBase(object):
        def __init__(self, value):
            self.value = value
        def __mul__(self, other):
            return self.value * other.value
        def __rmul__(self, other):
            return other.value * self.value
    class DoublerBase(MulBase):
        def __mul__(self, other):
            return 2 * (self.value * other.value)
    class AnotherDoubler(DoublerBase):
        pass
    res = DoublerBase(2) * AnotherDoubler(3)
    assert res == 12

