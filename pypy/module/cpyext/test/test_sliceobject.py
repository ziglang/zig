import sys
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.api import Py_ssize_t, Py_ssize_tP

class TestSliceObject(BaseApiTest):

    def test_GetIndicesEx(self, space, api):
        w = space.wrap
        def get_indices(w_start, w_stop, w_step, length):
            w_slice = space.newslice(w_start, w_stop, w_step)
            values = lltype.malloc(Py_ssize_tP.TO, 4, flavor='raw')

            res = api.PySlice_GetIndicesEx(w_slice, 100, values,
                rffi.ptradd(values, 1),
                rffi.ptradd(values, 2),
                rffi.ptradd(values, 3))
            assert res == 0
            rv = values[0], values[1], values[2], values[3]
            lltype.free(values, flavor='raw')
            return rv
        assert get_indices(w(10), w(20), w(1), 200) == (10, 20, 1, 10)

    def test_GetIndices(self, space, api):
        w = space.wrap
        def get_indices(w_start, w_stop, w_step, length):
            w_slice = space.newslice(w_start, w_stop, w_step)
            values = lltype.malloc(Py_ssize_tP.TO, 3, flavor='raw')

            res = api.PySlice_GetIndices(w_slice, 100, values,
                rffi.ptradd(values, 1),
                rffi.ptradd(values, 2))
            assert res == 0
            rv = values[0], values[1], values[2]
            lltype.free(values, flavor='raw')
            return rv
        assert get_indices(w(10), w(20), w(1), 200) == (10, 20, 1)

class AppTestSliceMembers(AppTestCpythonExtensionBase):
    def test_members(self):
        module = self.import_extension('foo', [
            ("clone", "METH_O",
             """
                 PySliceObject *slice = (PySliceObject *)args;
                 if (Py_TYPE(slice) != &PySlice_Type) {
                     PyErr_SetNone(PyExc_ValueError);
                     return NULL;
                 }
                 return PySlice_New(slice->start,
                                    slice->stop,
                                    slice->step);
             """),
            ])
        s = slice(10, 20, 30)
        assert module.clone(s) == s

    def test_nulls(self):
        module = self.import_extension('foo', [
            ("nullslice", "METH_NOARGS",
             """
                 return PySlice_New(NULL, NULL, NULL);
             """),
            ])
        assert module.nullslice() == slice(None, None, None)

    def test_ellipsis(self):
        module = self.import_extension('foo', [
            ("get_ellipsis", "METH_NOARGS",
             """
                 PyObject *ret = Py_Ellipsis;
                 Py_INCREF(ret);
                 return ret;
             """),
            ])
        assert module.get_ellipsis() is Ellipsis

    def test_typecheck(self):
        module = self.import_extension('foo', [
            ("check", "METH_O",
             """
                 PySliceObject *slice = (PySliceObject *)args;
                 return PyLong_FromLong(PySlice_Check(slice));
             """),
            ])
        s = slice(10, 20, 30)
        assert module.check(s)

    def test_Unpack(self):
        from sys import maxsize as M
        module = self.import_extension('foo', [
            ("check", "METH_O",
             """
                 Py_ssize_t start, stop, step;
                 if (PySlice_Unpack(args, &start, &stop, &step) != 0)
                     return NULL;
                 return Py_BuildValue("nnn", start, stop, step);
             """),
            ])
        assert module.check(slice(10, 20, 1)) == (10, 20, 1)
        assert module.check(slice(None, 20, 1)) == (0, 20, 1)
        assert module.check(slice(10, None, 3)) == (10, M, 3)
        assert module.check(slice(10, 20, None)) == (10, 20, 1)
        assert module.check(slice(20, 5, 1)) == (20, 5, 1)
        assert module.check(slice(None, None, None)) == (0, M, 1)

        assert module.check(slice(20, 10, -1)) == (20, 10, -1)
        assert module.check(slice(None, 20, -1)) == (M, 20, -1)
        assert module.check(slice(10, None, -1)) == (10, -M-1, -1)

        assert module.check(slice(M*2, M*3, 1)) == (M, M, 1)
        assert module.check(slice(M*2, -123, 1)) == (M, -123, 1)
        assert module.check(slice(-M*2, -M*3, 1)) == (-M-1, -M-1, 1)
        assert module.check(slice(-M*2, 123, -2)) == (-M-1, 123, -2)

        with raises(ValueError):
            module.check(slice(2, 3, 0))
        assert module.check(slice(2, 3, -M-1)) == (2, 3, -M)
        assert module.check(slice(2, 3, -M-10)) == (2, 3, -M)
        assert module.check(slice(2, 3, M+10)) == (2, 3, M)

    def test_AdjustIndices(self):
        module = self.import_extension('foo', [
            ("check", "METH_NOARGS",
             """
                 Py_ssize_t start = -35, stop = 99999, step = 10, result;
                 result = PySlice_AdjustIndices(100, &start, &stop, step);
                 return Py_BuildValue("nnnn", result, start, stop, step);
             """),
            ])
        assert module.check() == (4, 65, 100, 10)
