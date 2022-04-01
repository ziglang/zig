from ctypes import POINTER, c_void_p

def test_pointer_subclasses():
    Void_pp = POINTER(c_void_p)
    class My_void_p(c_void_p):
        pass

    My_void_pp = POINTER(My_void_p)
    o = My_void_pp()

    assert Void_pp.from_param(o) is o


def test_multiple_signature(dll):
    # when .argtypes is not set, calling a function with a certain
    # set of parameters should not prevent another call with
    # another set.
    func = dll._testfunc_p_p

    # This is call has too many arguments
    assert func(None, 1) == 0

    # This one is normal
    assert func(None) == 0
