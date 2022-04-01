

class AppTestDescrTypecheck:

    def test_getsetprop_get(self):
        def f():
            pass
        getter =  type(f).__dict__['__code__'].__get__
        getter = getattr(getter, 'im_func', getter) # neutralizes pypy/cpython diff
        raises(TypeError, getter, 1, None)

    def test_func_code_get(self):
        def f():
            pass
        raises(TypeError, type(f).__code__.__get__,1)
