import pytest
from rpython.rtyper.lltypesystem import lltype
from pypy.interpreter.error import OperationError
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.number import (
    PyIndex_Check, PyNumber_Check, PyNumber_Long,
    PyNumber_Index, PyNumber_Add,
    PyNumber_Multiply, PyNumber_InPlaceMultiply, PyNumber_Absolute,
    PyNumber_Power, PyNumber_InPlacePower)
from pypy.module.cpyext.longobject import PyLong_CheckExact
from pypy.module.cpyext.object import PyObject_Size

class TestIterator(BaseApiTest):
    def test_check(self, space):
        assert PyIndex_Check(space, space.wrap(12))
        assert PyIndex_Check(space, space.wraplong(-12L))
        assert not PyIndex_Check(space, space.wrap(12.1))
        assert not PyIndex_Check(space, space.wrap('12'))

        assert PyNumber_Check(space, space.wrap(12))
        assert PyNumber_Check(space, space.wraplong(-12L))
        assert PyNumber_Check(space, space.wrap(12.1))
        assert not PyNumber_Check(space, space.wrap('12'))
        assert PyNumber_Check(space, space.wrap(1 + 3j))

    def test_number_long(self, space):
        w_l = PyNumber_Long(space, space.wrap(123))
        assert PyLong_CheckExact(space, w_l)
        w_l = PyNumber_Long(space, space.wrap("123"))
        assert PyLong_CheckExact(space, w_l)

    def test_number_long2(self, space):
        w_l = PyNumber_Long(space, space.wraplong(123L))
        assert PyLong_CheckExact(space, w_l)
        w_l = PyNumber_Long(space, space.wrap(2 << 65))
        assert PyLong_CheckExact(space, w_l)
        w_l = PyNumber_Long(space, space.wrap(42.3))
        assert PyLong_CheckExact(space, w_l)
        w_l = PyNumber_Long(space, space.wrap("42"))
        assert PyLong_CheckExact(space, w_l)

    def test_number_index(self, space):
        w_l = PyNumber_Index(space, space.wraplong(123L))
        assert PyLong_CheckExact(space, w_l)
        with pytest.raises(OperationError):
            PyNumber_Index(space, space.wrap(42.3))

    def test_numbermethods(self, space, api):
        assert "ab" == space.unwrap(
            PyNumber_Add(space, space.wrap("a"), space.wrap("b")))
        assert "aaa" == space.unwrap(
            PyNumber_Multiply(space, space.wrap("a"), space.wrap(3)))

        w_l = space.newlist([1, 2, 3])
        w_l2 = PyNumber_Multiply(space, w_l, space.wrap(3))
        assert PyObject_Size(space, w_l2) == 9
        assert PyObject_Size(space, w_l) == 3

        w_l3 = PyNumber_InPlaceMultiply(space, w_l, space.wrap(3))
        assert PyObject_Size(space, w_l) == 9
        assert w_l3 is w_l

        # unary function
        assert 9 == space.unwrap(PyNumber_Absolute(space, space.wrap(-9)))

        # power
        assert 9 == space.unwrap(
            PyNumber_Power(space, space.wrap(3), space.wrap(2), space.w_None))
        assert 4 == space.unwrap(
            PyNumber_Power(space, space.wrap(3), space.wrap(2), space.wrap(5)))
        assert 9 == space.unwrap(
            PyNumber_InPlacePower(space, space.wrap(3), space.wrap(2), space.w_None))


class AppTestCNumber(AppTestCpythonExtensionBase):
    def test_PyNumber_Check(self):
        import sys
        mod = self.import_extension('foo', [
            ("test_PyNumber_Check", "METH_VARARGS",
             '''
                PyObject *obj = PyTuple_GET_ITEM(args, 0);
                int val = PyNumber_Check(obj);
                return PyLong_FromLong(val);
            ''')])
        val = mod.test_PyNumber_Check(10)
        assert val == 1
        #
        class MyIndex:
            def __index__(self):
                return 42
        val = mod.test_PyNumber_Check(MyIndex())
        if sys.version_info >= (3, 8):
            assert val == 1
        else:
            assert val == 0

    def test_number_tobase(self):
        import sys
        mod = self.import_extension('foo', [
            ("pynumber_tobase", "METH_VARARGS",
            """
                PyObject *obj;
                int base;
                if (!PyArg_ParseTuple(args, "Oi:pynumber_tobase",
                                      &obj, &base)) {
                    return NULL;
                }
                return PyNumber_ToBase(obj, base);
            """)])
        assert mod.pynumber_tobase(123, 2) == '0b1111011'
        assert mod.pynumber_tobase(123, 8) == '0o173'
        assert mod.pynumber_tobase(123, 10) == '123'
        assert mod.pynumber_tobase(123, 16) == '0x7b'
        assert mod.pynumber_tobase(-123, 2) == '-0b1111011'
        assert mod.pynumber_tobase(-123, 8) == '-0o173'
        assert mod.pynumber_tobase(-123, 10) == '-123'
        assert mod.pynumber_tobase(-123, 16) == '-0x7b'
        try:
            mod.pynumber_tobase(123.0, 10)
        except TypeError:
            pass
        else:
            assert False, 'expected TypeError'
        try:
            mod.pynumber_tobase('123', 10)
        except TypeError:
            pass
        else:
            assert False, 'expected TypeError'
        if 'PyPy' in sys.version or sys.version_info >= (3,7):
            # bpo 38643
            try:
                mod.pynumber_tobase(123, 0)
            except SystemError:
                pass
            else:
                assert False, 'expected SystemError'

    def test_index_check(self):
        # issue 3383: CPython only checks for the presence of __index__,
        # not that it is valid
        mod = self.import_extension('foo', [
            ("check_index", "METH_O",
            """
                int res = PyIndex_Check(args);
                return PyLong_FromLong(res);
            """)])

        class Raises:
            def __index__(self):
                raise ValueError(42)

        class Missing:
            pass

        m = Raises()
        assert mod.check_index(m)
        m = Missing()
        assert not mod.check_index(m)
    def test_number_to_ssize_t(self):
        import sys
        mod = self.import_extension('foo', [
            ("to_ssize_t", "METH_VARARGS",
            """
                PyObject *obj;
                PyObject *exc = NULL;
                long long value;
                if (!PyArg_ParseTuple(args, "O|O:to_ssize_t",
                                      &obj, &exc)) {
                    return NULL;
                }
                if (exc == NULL) {
                    printf("got no exc\\n");
                } else {
                    printf("got exc\\n");
                }
                value = PyNumber_AsSsize_t(obj, exc);
                if (PyErr_Occurred()) {
                    return NULL;
                }
                return PyLong_FromLongLong(value);
            """)])
        assert mod.to_ssize_t(2 ** 68) == sys.maxsize
        assert mod.to_ssize_t(12) == 12
        raises(TypeError, mod.to_ssize_t, 2 ** 68, TypeError)