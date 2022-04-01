import pytest
import os
from pypy.interpreter.error import OperationError
from pypy.module.cpyext.pyobject import make_ref, decref
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.module.micronumpy.ndarray import W_NDimArray
from pypy.module.micronumpy.descriptor import get_dtype_cache
import pypy.module.micronumpy.constants as NPY
from pypy.module.cpyext.ndarrayobject import (
    _PyArray_FromAny, _PyArray_FromObject)

pytest.skip("Micronumpy not yet supported on py3k.")

def scalar(space):
    dtype = get_dtype_cache(space).w_float64dtype
    return W_NDimArray.new_scalar(space, dtype, space.wrap(10.))

def array(space, shape, order=NPY.CORDER):
    dtype = get_dtype_cache(space).w_float64dtype
    return W_NDimArray.from_shape(space, shape, dtype, order=order)

def iarray(space, shape, order=NPY.CORDER):
    dtype = get_dtype_cache(space).w_int64dtype
    return W_NDimArray.from_shape(space, shape, dtype, order=order)


NULL = lltype.nullptr(rffi.VOIDP.TO)

class TestNDArrayObject(BaseApiTest):
    spaceconfig = AppTestCpythonExtensionBase.spaceconfig.copy()
    spaceconfig['usemodules'].append('micronumpy')

    def test_Check(self, space, api):
        a = array(space, [10, 5, 3])
        x = space.wrap(10.)
        assert api._PyArray_Check(a)
        assert api._PyArray_CheckExact(a)
        assert not api._PyArray_Check(x)
        assert not api._PyArray_CheckExact(x)

    def test_FLAGS(self, space, api):
        s = array(space, [10])
        c = array(space, [10, 5, 3], order=NPY.CORDER)
        f = array(space, [10, 5, 3], order=NPY.FORTRANORDER)
        assert api._PyArray_FLAGS(s) & 0x0001
        assert api._PyArray_FLAGS(s) & 0x0002
        assert api._PyArray_FLAGS(c) & 0x0001
        assert api._PyArray_FLAGS(f) & 0x0002
        assert not api._PyArray_FLAGS(c) & 0x0002
        assert not api._PyArray_FLAGS(f) & 0x0001

    def test_NDIM(self, space, api):
        a = array(space, [10, 5, 3])
        assert api._PyArray_NDIM(a) == 3

    def test_DIM(self, space, api):
        a = array(space, [10, 5, 3])
        assert api._PyArray_DIM(a, 1) == 5

    def test_STRIDE(self, space, api):
        a = array(space, [10, 5, 3], )
        assert api._PyArray_STRIDE(a, 1) == a.implementation.get_strides()[1]

    def test_SIZE(self, space, api):
        a = array(space, [10, 5, 3])
        assert api._PyArray_SIZE(a) == 150

    def test_ITEMSIZE(self, space, api):
        a = array(space, [10, 5, 3])
        assert api._PyArray_ITEMSIZE(a) == 8

    def test_NBYTES(self, space, api):
        a = array(space, [10, 5, 3])
        assert api._PyArray_NBYTES(a) == 1200

    def test_TYPE(self, space, api):
        a = array(space, [10, 5, 3])
        assert api._PyArray_TYPE(a) == 12

    def test_DATA(self, space, api):
        a = array(space, [10, 5, 3])
        addr = api._PyArray_DATA(a)
        addr2 = rffi.cast(rffi.VOIDP, a.implementation.storage)
        assert addr == addr2

    def test_FromAny_scalar(self, space, api):
        a0 = scalar(space)
        assert a0.get_scalar_value().value == 10.

        a = api._PyArray_FromAny(a0, None, 0, 0, 0, NULL)
        assert api._PyArray_NDIM(a) == 0

        ptr = rffi.cast(rffi.DOUBLEP, api._PyArray_DATA(a))
        assert ptr[0] == 10.

    def test_FromAny(self, space):
        a = array(space, [10, 5, 3])
        assert _PyArray_FromAny(space, a, None, 0, 0, 0, NULL) is a
        assert _PyArray_FromAny(space, a, None, 1, 4, 0, NULL) is a
        with pytest.raises(OperationError) as excinfo:
            _PyArray_FromAny(space, a, None, 4, 5, 0, NULL)

    def test_FromObject(self, space):
        a = array(space, [10, 5, 3])
        assert _PyArray_FromObject(space, a, a.get_dtype().num, 0, 0) is a
        with pytest.raises(OperationError) as excinfo:
            _PyArray_FromObject(space, a, 11, 4, 5)
        assert excinfo.value.errorstr(space).find('desired') >= 0

    def test_list_from_fixedptr(self, space, api):
        A = lltype.GcArray(lltype.Float)
        ptr = lltype.malloc(A, 3)
        assert isinstance(ptr, lltype._ptr)
        ptr[0] = 10.
        ptr[1] = 5.
        ptr[2] = 3.
        l = list(ptr)
        assert l == [10., 5., 3.]

    def test_list_from_openptr(self, space, api):
        nd = 3
        a = array(space, [nd])
        ptr = rffi.cast(rffi.DOUBLEP, api._PyArray_DATA(a))
        ptr[0] = 10.
        ptr[1] = 5.
        ptr[2] = 3.
        l = []
        for i in range(nd):
            l.append(ptr[i])
        assert l == [10., 5., 3.]

    def test_SimpleNew_scalar(self, space, api):
        ptr_s = lltype.nullptr(rffi.LONGP.TO)
        a = api._PyArray_SimpleNew(0, ptr_s, 12)

        dtype = get_dtype_cache(space).w_float64dtype

        a.set_scalar_value(dtype.itemtype.box(10.))
        assert a.get_scalar_value().value == 10.

    def test_SimpleNewFromData_scalar(self, space, api):
        a = array(space, [1])
        num = api._PyArray_TYPE(a)
        ptr_a = api._PyArray_DATA(a)

        x = rffi.cast(rffi.DOUBLEP, ptr_a)
        x[0] = float(10.)

        ptr_s = lltype.nullptr(rffi.LONGP.TO)

        res = api._PyArray_SimpleNewFromData(0, ptr_s, num, ptr_a)
        assert res.is_scalar()
        assert res.get_scalar_value().value == 10.

    def test_SimpleNew(self, space, api):
        shape = [10, 5, 3]
        nd = len(shape)

        s = iarray(space, [nd])
        ptr_s = rffi.cast(rffi.LONGP, api._PyArray_DATA(s))
        ptr_s[0] = 10
        ptr_s[1] = 5
        ptr_s[2] = 3

        a = api._PyArray_SimpleNew(nd, ptr_s, 12)

        #assert list(api._PyArray_DIMS(a))[:3] == shape

        ptr_a = api._PyArray_DATA(a)

        x = rffi.cast(rffi.DOUBLEP, ptr_a)
        for i in range(150):
            x[i] = float(i)

        for i in range(150):
            assert x[i] == float(i)

    def test_SimpleNewFromData(self, space, api):
        shape = [10, 5, 3]
        nd = len(shape)

        s = iarray(space, [nd])
        ptr_s = rffi.cast(rffi.LONGP, api._PyArray_DATA(s))
        ptr_s[0] = 10
        ptr_s[1] = 5
        ptr_s[2] = 3

        a = array(space, shape)
        num = api._PyArray_TYPE(a)
        ptr_a = api._PyArray_DATA(a)

        x = rffi.cast(rffi.DOUBLEP, ptr_a)
        for i in range(150):
            x[i] = float(i)

        res = api._PyArray_SimpleNewFromData(nd, ptr_s, num, ptr_a)
        assert api._PyArray_TYPE(res) == num
        assert api._PyArray_DATA(res) == ptr_a
        for i in range(nd):
            assert api._PyArray_DIM(res, i) == shape[i]
        ptr_r = rffi.cast(rffi.DOUBLEP, api._PyArray_DATA(res))
        for i in range(150):
            assert ptr_r[i] == float(i)
        res = api._PyArray_SimpleNewFromDataOwning(nd, ptr_s, num, ptr_a)
        x = rffi.cast(rffi.DOUBLEP, ptr_a)
        ptr_r = rffi.cast(rffi.DOUBLEP, api._PyArray_DATA(res))
        x[20] = -100.
        assert ptr_r[20] == -100.

    def test_SimpleNewFromData_complex(self, space, api):
        a = array(space, [2])
        ptr_a = api._PyArray_DATA(a)

        x = rffi.cast(rffi.DOUBLEP, ptr_a)
        x[0] = 3.
        x[1] = 4.

        ptr_s = lltype.nullptr(rffi.LONGP.TO)

        res = api._PyArray_SimpleNewFromData(0, ptr_s, 15, ptr_a)
        assert res.get_scalar_value().real == 3.
        assert res.get_scalar_value().imag == 4.

    def _test_Ufunc_FromFuncAndDataAndSignature(self, space, api):
        pytest.skip('preliminary non-translated test')
        '''
        PyUFuncGenericFunction funcs[] = {&double_times2, &int_times2};
        char types[] = { NPY_DOUBLE,NPY_DOUBLE, NPY_INT, NPY_INT };
        void *array_data[] = {NULL, NULL};
        ufunc = api.PyUFunc_FromFuncAndDataAndSignature(space, funcs, data,
                        types, ntypes, nin, nout, identity, doc, check_return,
                        signature)
        '''

    def test_ndarray_ref(self, space, api):
        w_obj = space.appexec([], """():
            import _numpypy
            return _numpypy.multiarray.dtype('int64').type(2)""")
        ref = make_ref(space, w_obj)
        decref(space, ref)

class AppTestNDArray(AppTestCpythonExtensionBase):

    def setup_class(cls):
        AppTestCpythonExtensionBase.setup_class.im_func(cls)
        if cls.runappdirect:
            try:
                import numpy
            except ImportError:
                skip('numpy not importable')
            cls.w_numpy_include = [numpy.get_include()]
        else:
            numpy_incl = os.path.abspath(os.path.dirname(__file__) +
                                         '/../include/_numpypy')
            assert os.path.exists(numpy_incl)
            cls.w_numpy_include = cls.space.wrap([numpy_incl])

    def test_ndarray_object_c(self):
        mod = self.import_extension('foo', [
                ("test_simplenew", "METH_NOARGS",
                '''
                npy_intp dims[2] ={2, 3};
                PyObject * obj = PyArray_SimpleNew(2, dims, 11);
                return obj;
                '''
                ),
                ("test_fill", "METH_NOARGS",
                '''
                npy_intp dims[2] ={2, 3};
                PyObject * obj = PyArray_SimpleNew(2, dims, 1);
                PyArray_FILLWBYTE((PyArrayObject*)obj, 42);
                return obj;
                '''
                ),
                ("test_copy", "METH_NOARGS",
                '''
                npy_intp dims1[2] ={2, 3};
                npy_intp dims2[2] ={3, 2};
                int ok;
                PyObject * obj1 = PyArray_ZEROS(2, dims1, 11, 0);
                PyObject * obj2 = PyArray_ZEROS(2, dims2, 11, 0);
                PyArray_FILLWBYTE((PyArrayObject*)obj2, 42);
                ok = PyArray_CopyInto((PyArrayObject*)obj2, (PyArrayObject*)obj1);
                Py_DECREF(obj2);
                if (ok < 0)
                {
                    /* Should have failed */
                    Py_DECREF(obj1);
                    return NULL;
                }
                return obj1;
                '''
                ),
                ("test_FromAny", "METH_NOARGS",
                '''
                npy_intp dims[2] ={2, 3};
                PyObject * obj2, * obj1 = PyArray_SimpleNew(2, dims, 1);
                PyArray_FILLWBYTE((PyArrayObject*)obj1, 42);
                obj2 = PyArray_FromAny(obj1, NULL, 0, 0, 0, NULL);
                Py_DECREF(obj1);
                return obj2;
                '''
                ),
                 ("test_FromObject", "METH_NOARGS",
                '''
                npy_intp dims[2] ={2, 3};
                PyObject  * obj2, * obj1 = PyArray_SimpleNew(2, dims, 1);
                PyArray_FILLWBYTE((PyArrayObject*)obj1, 42);
                obj2 = PyArray_FromObject(obj1, 12, 0, 0);
                Py_DECREF(obj1);
                return obj2;
                '''
                ),
                ("test_DescrFromType", "METH_O",
                """
                    long typenum = PyInt_AsLong(args);
                    return PyArray_DescrFromType(typenum);
                """
                ),
                ], include_dirs=self.numpy_include,
                   prologue='''
                #define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION
                #include <numpy/arrayobject.h>
                #ifdef PYPY_VERSION
                    #define PyArray_FromObject _PyArray_FromObject
                    #define PyArray_FromAny _PyArray_FromAny
                #endif
                ''',
                    more_init = '''
                #ifndef PYPY_VERSION
                    import_array();
                #endif
                ''')
        arr = mod.test_simplenew()
        assert arr.shape == (2, 3)
        assert arr.dtype.num == 11 #float32 dtype
        arr = mod.test_fill()
        assert arr.shape == (2, 3)
        assert arr.dtype.num == 1 #int8 dtype
        assert (arr == 42).all()
        raises(ValueError, mod.test_copy)
        #Make sure these work without errors
        arr = mod.test_FromAny()
        arr = mod.test_FromObject()
        dt = mod.test_DescrFromType(11)
        assert dt.num == 11

    def test_pass_ndarray_object_to_c(self):
        if self.runappdirect:
            from numpy import ndarray
        else:
            from _numpypy.multiarray import ndarray
        mod = self.import_extension('foo', [
                ("check_array", "METH_VARARGS",
                '''
                    PyObject* obj;
                    if (!PyArg_ParseTuple(args, "O!", &PyArray_Type, &obj))
                        return NULL;
                    Py_INCREF(obj);
                    return obj;
                '''),
                ], include_dirs=self.numpy_include,
                   prologue='''
                #define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION
                #include <numpy/arrayobject.h>
                ''',
                    more_init = '''
                #ifndef PYPY_VERSION
                    import_array();
                #endif
                ''')
        array = ndarray((3, 4), dtype='d')
        assert mod.check_array(array) is array
        raises(TypeError, "mod.check_array(42)")

    def test_ufunc(self):
        if self.runappdirect:
            from numpy import arange
            pytest.xfail('segfaults on cpython: PyUFunc_API == NULL?')
        else:
            from _numpypy.multiarray import arange
        mod = self.import_extension('foo', [
                ("create_ufunc_basic",  "METH_NOARGS",
                """
                PyUFuncGenericFunction funcs[] = {&double_times2, &int_times2};
                char types[] = { NPY_DOUBLE,NPY_DOUBLE, NPY_INT, NPY_INT };
                void *array_data[] = {NULL, NULL};
                PyObject * retval;
                retval = PyUFunc_FromFuncAndData(funcs,
                                    array_data, types, 2, 1, 1, PyUFunc_None,
                                    "times2", "times2_docstring", 0);
                return retval;
                """
                ),
                ("create_ufunc_signature", "METH_NOARGS",
                """
                PyUFuncGenericFunction funcs[] = {&double_times2, &int_times2};
                char types[] = { NPY_DOUBLE,NPY_DOUBLE, NPY_INT, NPY_INT };
                void *array_data[] = {NULL, NULL};
                PyObject * retval;
                retval = PyUFunc_FromFuncAndDataAndSignature(funcs,
                                    array_data, types, 2, 1, 1, PyUFunc_None,
                                    "times2", "times2_docstring", 0, "()->()");
                return retval;
                """),
                ("create_float_ufunc_3x3", "METH_NOARGS",
                """
                PyUFuncGenericFunction funcs[] = {&float_func_with_sig_3x3};
                char types[] = { NPY_FLOAT,NPY_FLOAT};
                void *array_data[] = {NULL, NULL};
                return PyUFunc_FromFuncAndDataAndSignature(funcs,
                                    array_data, types, 1, 1, 1, PyUFunc_None,
                                    "float_3x3",
                                    "a ufunc that tests a more complicated signature",
                                    0, "(m,m)->(m,m)");
                """),
                ], include_dirs=self.numpy_include,
                   prologue='''
                #define NPY_NO_DEPRECATED_API NPY_1_7_API_VERSION
                #include <numpy/arrayobject.h>
                #ifndef PYPY_VERSION
                #include <numpy/ufuncobject.h> /*generated by numpy setup.py*/
                #endif
                typedef void (*PyUFuncGenericFunction)
                            (char **args,
                             npy_intp *dimensions,
                             npy_intp *strides,
                             void *innerloopdata);
                #define PyUFunc_None -1
                void double_times2(char **args, npy_intp *dimensions,
                              npy_intp* steps, void* data)
                {
                    npy_intp i;
                    npy_intp n;
                    char *in, *out;
                    npy_intp in_step, out_step;
                    double tmp;
                    n = dimensions[0];
                    in = args[0]; out=args[1];
                    in_step = steps[0]; out_step = steps[1];

                    for (i = 0; i < n; i++) {
                        /*BEGIN main ufunc computation*/
                        tmp = *(double *)in;
                        tmp *=2.0;
                        *((double *)out) = tmp;
                        /*END main ufunc computation*/

                        in += in_step;
                        out += out_step;
                    };
                };
                void int_times2(char **args, npy_intp *dimensions,
                              npy_intp* steps, void* data)
                {
                    npy_intp i;
                    npy_intp n = dimensions[0];
                    char *in = args[0], *out=args[1];
                    npy_intp in_step = steps[0], out_step = steps[1];
                    int tmp;
                    for (i = 0; i < n; i++) {
                        /*BEGIN main ufunc computation*/
                        tmp = *(int *)in;
                        tmp *=2.0;
                        *((int *)out) = tmp;
                        /*END main ufunc computation*/

                        in += in_step;
                        out += out_step;
                    };
                };
                void float_func_with_sig_3x3(char ** args, npy_intp * dimensions,
                              npy_intp* steps, void* data)
                {
                    int target_dims[] = {1, 3};
                    int target_steps[] = {0, 0, 12, 4, 12, 4};
                    int res = 0;
                    int i;
                    for (i=0; i<sizeof(target_dims)/sizeof(int); i++)
                        if (dimensions[i] != target_dims[i])
                            res += 1;
                    for (i=0; i<sizeof(target_steps)/sizeof(int); i++)
                        if (steps[i] != target_steps[i])
                            res += +10;
                    *((float *)args[1]) = res;
                };

                ''',  more_init = '''
                #ifndef PYPY_VERSION
                    import_array();
                #endif
                ''')
        sq = arange(18, dtype="float32").reshape(2,3,3)
        float_ufunc = mod.create_float_ufunc_3x3()
        out = float_ufunc(sq)
        assert out[0, 0, 0] == 0

        times2 = mod.create_ufunc_basic()
        arr = arange(12, dtype='i').reshape(3, 4)
        out = times2(arr, extobj=[0, 0, None])
        assert (out == arr * 2).all()

        times2prime = mod.create_ufunc_signature()
        out = times2prime(arr, sig='d->d', extobj=[0, 0, None])
        assert (out == arr * 2).all()
