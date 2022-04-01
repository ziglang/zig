import py, os, sys
from pypy.module._cppyy import interp_cppyy, executor
from .support import setup_make, soext

currpath = py.path.local(__file__).dirpath()
test_dct = str(currpath.join("example01Dict"))+soext

def setup_module(mod):
    setup_make("example01")


class TestCPPYYImplementation:
    def test01_class_query(self, space):
        # NOTE: this test needs to run before test_pythonify.py
        import ctypes
        dct = ctypes.CDLL(test_dct)
        w_cppyyclass = interp_cppyy.scope_byname(space, "example01")
        w_cppyyclass2 = interp_cppyy.scope_byname(space, "example01")
        assert space.is_w(w_cppyyclass, w_cppyyclass2)
        adddouble = w_cppyyclass.overloads["staticAddToDouble"]
        func, = adddouble.functions
        assert func.executor is None
        func._setup(None)     # creates executor
        assert isinstance(func.executor, executor._executors['double'])
        assert func.arg_defs == [("double", "")]


class AppTestCPPYY:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        cls.w_lib, cls.w_instantiate, cls.w_example01, cls.w_payload = \
                   cls.space.unpackiterable(cls.space.appexec([], """():
            import _cppyy, ctypes
            _cppyy._post_import_startup()
            lib = ctypes.CDLL(%r, ctypes.RTLD_GLOBAL)
            def cpp_instantiate(tt, *args):
                inst = _cppyy._bind_object(0, tt, True)
                ol = tt.get_overload("__init__").__get__(inst)
                ol(*args)
                return inst
            return lib, cpp_instantiate, _cppyy._scope_byname('example01'),\
                          _cppyy._scope_byname('payload')""" % (test_dct, )))

    def test01_static_int(self):
        """Test passing of an int, returning of an int, and overloading on a
            differening number of arguments."""

        import sys, math
        t = self.example01

        pylong = int
        if sys.hexversion < 0x3000000:
            pylong = long

        res = t.get_overload("staticAddOneToInt")(1)
        assert res == 2
        res = t.get_overload("staticAddOneToInt")(pylong(1))
        assert res == 2
        res = t.get_overload("staticAddOneToInt")(1, 2)
        assert res == 4
        res = t.get_overload("staticAddOneToInt")(-1)
        assert res == 0
        maxint32 = int(2 ** 31 - 1)
        res = t.get_overload("staticAddOneToInt")(maxint32-1)
        assert res == maxint32
        res = t.get_overload("staticAddOneToInt")(maxint32)
        assert res == -maxint32-1

        raises(TypeError, 't.get_overload("staticAddOneToInt")(1, [])')
        raises(TypeError, 't.get_overload("staticAddOneToInt")(1.)')
        raises(TypeError, 't.get_overload("staticAddOneToInt")(maxint32+1)')

    def test02_static_double(self):
        """Test passing of a double and returning of a double on a static function."""

        t = self.example01

        res = t.get_overload("staticAddToDouble")(0.09)
        assert res == 0.09 + 0.01

    def test03_static_constcharp(self):
        """Test passing of a C string and returning of a C string on a static
            function."""

        t = self.example01

        res = t.get_overload("staticAtoi")("1")
        assert res == 1
        res = t.get_overload("staticStrcpy")("aap")    # TODO: this leaks
        assert res == "aap"
        res = t.get_overload("staticStrcpy")(u"aap")   # TODO: this leaks
        assert res == "aap"

        raises(TypeError, 't.get_overload("staticStrcpy")(1.)')  # TODO: this leaks

    def test04_method_int(self):
        """Test passing of a int, returning of a int, and memory cleanup, on
            a method."""
        import _cppyy

        t = self.example01

        assert t.get_overload("getCount")() == 0

        e1 = self.instantiate(t, 7)
        assert t.get_overload("getCount")() == 1
        res = t.get_overload("addDataToInt")(e1, 4)
        assert res == 11
        res = t.get_overload("addDataToInt")(e1, -4)
        assert res == 3
        e1.__destruct__()
        assert t.get_overload("getCount")() == 0
        raises(ReferenceError, 't.get_overload("addDataToInt")(e1, 4)')

        e1 = self.instantiate(t, 7)
        e2 = self.instantiate(t, 8)
        assert t.get_overload("getCount")() == 2
        e1.__destruct__()
        assert t.get_overload("getCount")() == 1
        e2.__destruct__()
        assert t.get_overload("getCount")() == 0

        e2.__destruct__()
        assert t.get_overload("getCount")() == 0

        raises(TypeError, t.get_overload("addDataToInt"), 41, 4)

    def test05_memory(self):
        """Test memory destruction and integrity."""

        import gc
        import _cppyy

        t = self.example01

        assert t.get_overload("getCount")() == 0

        e1 = self.instantiate(t, 7)
        assert t.get_overload("getCount")() == 1
        res = t.get_overload("addDataToInt")(e1, 4)
        assert res == 11
        res = t.get_overload("addDataToInt")(e1, -4)
        assert res == 3
        e1 = None
        gc.collect()
        assert t.get_overload("getCount")() == 0

        e1 = self.instantiate(t, 7)
        e2 = self.instantiate(t, 8)
        assert t.get_overload("getCount")() == 2
        e1 = None
        gc.collect()
        assert t.get_overload("getCount")() == 1
        e2.__destruct__()
        assert t.get_overload("getCount")() == 0
        e2 = None
        gc.collect()
        assert t.get_overload("getCount")() == 0

    def test05a_memory2(self):
        """Test ownership control."""

        import gc, _cppyy

        t = self.example01

        assert t.get_overload("getCount")() == 0

        e1 = self.instantiate(t, 7)
        assert t.get_overload("getCount")() == 1
        assert e1.__python_owns__ == True
        e1.__python_owns__ = False
        e1 = None
        gc.collect()
        assert t.get_overload("getCount")() == 1

        # forced fix-up of object count for later tests
        t.get_overload("setCount")(0)


    def test06_method_double(self):
        """Test passing of a double and returning of double on a method."""

        import _cppyy

        t = self.example01

        e = self.instantiate(t, 13)
        res = t.get_overload("addDataToDouble")(e, 16)
        assert round(res-29, 8) == 0.
        e.__destruct__()

        e = self.instantiate(t, -13)
        res = t.get_overload("addDataToDouble")(e, 16)
        assert round(res-3, 8) == 0.
        e.__destruct__()
        assert t.get_overload("getCount")() == 0

    def test07_method_constcharp(self):
        """Test passing of a C string and returning of a C string on a
            method."""
        import _cppyy

        t = self.example01

        e = self.instantiate(t, 42)
        res = t.get_overload("addDataToAtoi")(e, "13")
        assert res == 55
        res = t.get_overload("addToStringValue")(e, "12")       # TODO: this leaks
        assert res == "54"
        res = t.get_overload("addToStringValue")(e, "-12")      # TODO: this leaks
        assert res == "30"
        e.__destruct__()
        assert t.get_overload("getCount")() == 0

    def test08_pass_object_by_pointer(self):
        """Test passing of an instance as an argument."""
        import _cppyy

        t1 = self.example01
        t2 = self.payload

        pl = self.instantiate(t2, 3.14)
        assert round(t2.get_overload("getData")(pl)-3.14, 8) == 0
        t1.get_overload("staticSetPayload")(pl, 41.)
        assert t2.get_overload("getData")(pl) == 41.

        e = self.instantiate(t1, 50)
        t1.get_overload("setPayload")(e, pl);
        assert round(t2.get_overload("getData")(pl)-50., 8) == 0

        e.__destruct__()
        pl.__destruct__() 
        assert t1.get_overload("getCount")() == 0

    def test09_return_object_by_pointer(self):
        """Test returning of an instance as an argument."""
        import _cppyy

        t1 = self.example01
        t2 = self.payload

        pl1 = self.instantiate(t2, 3.14)
        assert round(t2.get_overload("getData")(pl1)-3.14, 8) == 0
        pl2 = t1.get_overload("staticCyclePayload")(pl1, 38.)
        assert t2.get_overload("getData")(pl2) == 38.

        e = self.instantiate(t1, 50)
        pl2 = t1.get_overload("cyclePayload")(e, pl1);
        assert round(t2.get_overload("getData")(pl2)-50., 8) == 0

        e.__destruct__()
        pl1.__destruct__() 
        assert t1.get_overload("getCount")() == 0
