import pytest
from pypy.objspace.std.test import test_intobject

@pytest.mark.skipif('config.option.runappdirect')
class AppTestInt(test_intobject.AppTestInt):
    spaceconfig = {"objspace.std.withprebuiltint": True}

    def setup_class(cls):
        space = cls.space
        cls.w_start = space.wrap(space.config.objspace.std.prebuiltintfrom)
        cls.w_stop = space.wrap(space.config.objspace.std.prebuiltintto)

    def test_prebuiltint(self):
        def f(x):
            assert x is (-(x + 3 - 3) * 5 // (-5))
        for i in range(self.start, self.stop):
            f(i)
