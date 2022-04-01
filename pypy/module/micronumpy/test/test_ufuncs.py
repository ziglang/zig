from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest
from pypy.module.micronumpy.ufuncs import W_UfuncGeneric, unary_ufunc
from pypy.module.micronumpy.support import _parse_signature
from pypy.module.micronumpy.descriptor import get_dtype_cache
from pypy.module.micronumpy.base import W_NDimArray
from pypy.module.micronumpy.concrete import VoidBoxStorage
from pypy.interpreter.error import OperationError


class TestGenericUfuncOperation(object):
    def test_signature_parser(self, space):
        class Ufunc(object):
            def __init__(self, nin, nout):
                self.nin = nin
                self.nout = nout
                self.nargs = nin + nout
                self.core_enabled = True
                self.core_num_dim_ix = 0
                self.core_num_dims = [0] * self.nargs
                self.core_offsets = [0] * self.nargs
                self.core_dim_ixs = []

        u = Ufunc(2, 1)
        _parse_signature(space, u, '(m,n), (n,r)->(m,r)')
        assert u.core_dim_ixs == [0, 1, 1, 2, 0, 2]
        assert u.core_num_dims == [2, 2, 2]
        assert u.core_offsets == [0, 2, 4]

    def test_type_resolver(self, space):
        c128_dtype = get_dtype_cache(space).w_complex128dtype
        c64_dtype = get_dtype_cache(space).w_complex64dtype
        f64_dtype = get_dtype_cache(space).w_float64dtype
        f32_dtype = get_dtype_cache(space).w_float32dtype
        u32_dtype = get_dtype_cache(space).w_uint32dtype
        b_dtype = get_dtype_cache(space).w_booldtype

        ufunc = W_UfuncGeneric(space, [None, None, None], 'eigenvals', None, 1, 1,
                     [f32_dtype, c64_dtype,
                      f64_dtype, c128_dtype,
                      c128_dtype, c128_dtype],
                     '')
        f32_array = W_NDimArray(VoidBoxStorage(0, f32_dtype))
        index, dtypes = ufunc.type_resolver(space, [f32_array], [None],
                                            'd->D', ufunc.dtypes)
        #needs to cast input type, create output type
        assert index == 1
        assert dtypes == [f64_dtype, c128_dtype]
        index, dtypes = ufunc.type_resolver(space, [f32_array], [None],
                                             '', ufunc.dtypes)
        assert index == 0
        assert dtypes == [f32_dtype, c64_dtype]
        raises(OperationError, ufunc.type_resolver, space, [f32_array], [None],
                                'u->u', ufunc.dtypes)
        exc = raises(OperationError, ufunc.type_resolver, space, [f32_array], [None],
                                'i->i', ufunc.dtypes)

    def test_allowed_types(self, space):
        dt_bool = get_dtype_cache(space).w_booldtype
        dt_float16 = get_dtype_cache(space).w_float16dtype
        dt_int32 = get_dtype_cache(space).w_int32dtype
        ufunc = unary_ufunc(space, None, 'x', int_only=True)
        assert ufunc._calc_dtype(space, dt_bool, out=None) == (dt_bool, dt_bool)
        assert ufunc.dtypes  # XXX: shouldn't contain too much stuff

        ufunc = unary_ufunc(space, None, 'x', promote_to_float=True)
        assert ufunc._calc_dtype(space, dt_bool, out=None) == (dt_float16, dt_float16)
        assert ufunc._calc_dtype(space, dt_bool, casting='same_kind') == (dt_float16, dt_float16)
        raises(OperationError, ufunc._calc_dtype, space, dt_bool, casting='no')

        ufunc = unary_ufunc(space, None, 'x')
        assert ufunc._calc_dtype(space, dt_int32, out=None) == (dt_int32, dt_int32)

class AppTestUfuncs(BaseNumpyAppTest):
    def test_constants(self):
        import numpy as np
        assert np.FLOATING_POINT_SUPPORT == 1

    def test_ufunc_instance(self):
        from numpy import add, ufunc

        assert isinstance(add, ufunc)
        assert repr(add) == "<ufunc 'add'>"
        assert repr(ufunc) == "<type 'numpy.ufunc'>"
        assert add.__name__ == 'add'
        raises(TypeError, ufunc)

    def test_frompyfunc_innerloop(self):
        from numpy import ufunc, frompyfunc, arange, dtype
        import sys
        def adder(a, b):
            return a+b
        def sumdiff(a, b):
                return a+b, a-b
        try:
            adder_ufunc0 = frompyfunc(adder, 2, 1)
            adder_ufunc1 = frompyfunc(adder, 2, 1)
            int_func22 = frompyfunc(int, 2, 2)
            int_func12 = frompyfunc(int, 1, 2)
            sumdiff = frompyfunc(sumdiff, 2, 2)
            retype = dtype(object)
        except NotImplementedError as e:
            # dtype of returned value is object, which is not supported yet
            assert 'object' in str(e)
            # Use pypy specific extension for out_dtype
            adder_ufunc0 = frompyfunc(adder, 2, 1, dtypes=['match'])
            sumdiff = frompyfunc(sumdiff, 2, 2, dtypes=['match'],
                                    signature='(i),(i)->(i),(i)')
            adder_ufunc1 = frompyfunc([adder, adder], 2, 1,
                            dtypes=[int, int, int, float, float, float])
            int_func22 = frompyfunc([int, int], 2, 2, signature='(i),(i)->(i),(i)',
                                    dtypes=['match'])
            int_func12 = frompyfunc([int], 1, 2, dtypes=['match'])
            retype = dtype(int)
        a = arange(10)
        assert isinstance(adder_ufunc1, ufunc)
        res = adder_ufunc0(a, a)
        assert res.dtype == retype
        assert all(res == a + a)
        res = adder_ufunc1(a, a)
        assert res.dtype == retype
        assert all(res == a + a)
        raises(TypeError, frompyfunc, 1, 2, 3)
        raises (ValueError, int_func22, a)
        res = int_func12(a)
        assert len(res) == 2
        assert isinstance(res, tuple)
        if '__pypy__' in sys.builtin_module_names:
            assert (res[0] == a).all()
        else:
            assert all([r is None for r in res[0]]) # ??? no warning or error, just a fail?
        res = sumdiff(2 * a, a)
        assert (res[0] == 3 * a).all()
        assert (res[1] == a).all()

    def test_frompyfunc_outerloop(self):
        import sys
        from numpy import frompyfunc, dtype, arange
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy only frompyfunc extension')
        def int_times2(in_array, out_array):
            assert in_array.dtype == int
            in_flat = in_array.flat
            out_flat = out_array.flat
            for i in range(in_array.size):
                out_flat[i] = in_flat[i] * 2
        def double_times2(in_array, out_array):
            assert in_array.dtype == float
            in_flat = in_array.flat
            out_flat = out_array.flat
            for i in range(in_array.size):
                out_flat[i] = in_flat[i] * 2
        ufunc = frompyfunc([int_times2, double_times2], 1, 1,
                            signature='()->()',
                            dtypes=[dtype(int), dtype(int),
                                    dtype(float), dtype(float)
                                    ],
                            stack_inputs=True,
                    )
        ai = arange(10, dtype=int)
        ai2 = ufunc(ai)
        assert all(ai2 == ai * 2)
        af = arange(10, dtype=float)
        af2 = ufunc(af)
        assert all(af2 == af * 2)
        ac = arange(10, dtype=complex)
        raises(TypeError, ufunc, ac)

    def test_frompyfunc_2d_sig(self):
        import sys
        from numpy import frompyfunc, dtype, arange
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy only frompyfunc extension')
        def times_2(in_array, out_array):
            assert len(in_array.shape) == 2
            assert in_array.shape == out_array.shape
            out_array[:] = in_array * 2

        ufunc = frompyfunc([times_2], 1, 1,
                            signature='(m,n)->(n,m)',
                            dtypes=[dtype(int), dtype(int)],
                            stack_inputs=True,
                          )
        ai = arange(18, dtype=int).reshape(2,3,3)
        ai3 = ufunc(ai[0,:,:])
        ai2 = ufunc(ai)
        assert (ai2 == ai * 2).all()

        ufunc = frompyfunc([times_2], 1, 1,
                            signature='(m,m)->(m,m)',
                            dtypes=[dtype(int), dtype(int)],
                            stack_inputs=True,
                          )
        ai = arange(12*3*3, dtype='int32').reshape(12,3,3)
        exc = raises(ValueError, ufunc, ai[:,:,0])
        assert "perand 0 has a mismatch in its core dimension 1" in exc.value.message
        ai3 = ufunc(ai[0,:,:])
        ai2 = ufunc(ai)
        assert (ai2 == ai * 2).all()
        # view
        aiV = ai[::-2, :, :]
        assert aiV.strides == (-72, 12, 4)
        ai2 = ufunc(aiV)
        assert (ai2 == aiV * 2).all()

        ai = arange(0).reshape(0, 1, 1)
        ao = ufunc(ai)
        assert ao.shape == (0, 1, 1)

    def test_frompyfunc_not_contiguous(self):
        import sys
        from numpy import frompyfunc, dtype, arange, dot
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy only frompyfunc extension')
        def _dot(in0, in1, out):
            print in0, '\nin1',in1,'\nin1.shape', in1.shape, 'in1.strides', in1.strides
            out[...] = dot(in0, in1)

        ufunc_dot = frompyfunc(_dot, 2, 1,
                            signature='(m,m),(m,n)->(m,n)',
                            dtypes=[dtype(float), dtype(float), dtype(float)],
                            stack_inputs=True,
                          )
        a1 = arange(4, dtype=float).reshape(2,2)
        # create a non-c-contiguous argument
        a2 = arange(2, dtype=float).reshape(2,1)
        a3 = arange(2, dtype=float).reshape(1,2).T
        b1 = ufunc_dot(a1, a2, sig='dd->d')
        b2 = dot(a1, a2)
        assert (b1==b2).all()
        print 'xxxxxxxxxxxx'
        b1 = ufunc_dot(a1, a3, sig='dd->d')
        b2 = dot(a1, a3)
        assert (b1==b2).all()
 
    def test_frompyfunc_needs_nditer(self):
        import sys
        from numpy import frompyfunc, dtype, arange
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy only frompyfunc extension')
        def summer(in0):
            return in0.sum()

        ufunc = frompyfunc([summer], 1, 1,
                            signature='(m,m)->()',
                            dtypes=[dtype(int), dtype(int)],
                            stack_inputs=False,
                          )
        ai = arange(12, dtype=int).reshape(3, 2, 2)
        ao = ufunc(ai)
        assert ao.size == 3

    def test_frompyfunc_sig_broadcast(self):
        import sys
        from numpy import frompyfunc, dtype, arange
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy only frompyfunc extension')
        def sum_along_0(in_array, out_array):
            out_array[...] = in_array.sum(axis=0)

        def add_two(in0, in1, out):
            out[...] = in0 + in1

        ufunc_add = frompyfunc(add_two, 2, 1,
                            signature='(m,n),(m,n)->(m,n)',
                            dtypes=[dtype(int), dtype(int), dtype(int)],
                            stack_inputs=True,
                          )
        ufunc_sum = frompyfunc([sum_along_0], 1, 1,
                            signature='(m,n)->(n)',
                            dtypes=[dtype(int), dtype(int)],
                            stack_inputs=True,
                          )
        ai = arange(18, dtype=int).reshape(3,2,3)
        aout1 = ufunc_add(ai, ai[0,:,:])
        assert aout1.shape == (3, 2, 3)
        aout2 = ufunc_add(ai, ai[0,:,:])
        aout3 = ufunc_sum(ai)
        assert aout3.shape == (3, 3)
        aout4 = ufunc_add(ai, ai[0,:,:][None, :,:])
        assert (aout1 == aout4).all()
        
    def test_frompyfunc_fortran(self):
        import sys
        import numpy as np
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy only frompyfunc extension')
        def tofrom_fortran(in0, out0):
            out0[:] = in0.T

        def lapack_like_times2(in0, out0):
            a = np.empty(in0.T.shape, in0.dtype)
            tofrom_fortran(in0, a)
            a *= 2
            tofrom_fortran(a, out0)

        times2 = np.frompyfunc([lapack_like_times2], 1, 1,
                            signature='(m,n)->(m,n)',
                            dtypes=[np.dtype(float), np.dtype(float)],
                            stack_inputs=True,
                          )
        in0 = np.arange(3300, dtype=float).reshape(100, 33)
        out0 = times2(in0)
        assert out0.shape == in0.shape
        assert (out0 == in0 * 2).all()

    def test_frompyfunc_casting(self):
        import sys
        import numpy as np
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy only frompyfunc extension')

        def times2_int(in0, out0):
            assert in0.dtype == int
            assert out0.dtype == int
            # hack to assigning to a 0-dim array
            out0.real = in0 * 2

        def times2_complex(in0, out0):
            assert in0.dtype == complex
            assert out0.dtype == complex
            out0.real = in0.real * 2
            out0.imag = in0.imag

        def times2_complex0(in0):
            assert in0.dtype == complex
            return in0 * 2

        def times2_int0(in0):
            assert in0.dtype == int
            return in0 * 2

        times2stacked = np.frompyfunc([times2_int, times2_complex], 1, 1,
                            dtypes=[np.dtype(int), np.dtype(int),
                                np.dtype(complex), np.dtype(complex)],
                            stack_inputs=True, signature='()->()',
                          )
        times2 = np.frompyfunc([times2_int0, times2_complex0], 1, 1,
                            dtypes=[np.dtype(int), np.dtype(int),
                                np.dtype(complex), np.dtype(complex)],
                            stack_inputs=False,
                          )
        for d in [np.dtype(float), np.dtype('uint8'), np.dtype('complex64')]:
            in0 = np.arange(4, dtype=d)
            out0 = times2stacked(in0)
            assert out0.shape == in0.shape
            assert out0.dtype in (int, complex) 
            assert (out0 == in0 * 2).all()

            out0 = times2(in0)
            assert out0.shape == in0.shape
            assert out0.dtype in (int, complex) 
            assert (out0 == in0 * 2).all()

            in0 = np.arange(4, dtype=int)
            out0 = times2(in0, sig='D->D')
            assert out0.dtype == complex

    def test_frompyfunc_scalar(self):
        import sys
        import numpy as np
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy only frompyfunc extension')

        def summer(in0):
            out = np.empty(1, in0.dtype)
            out[0] = in0.sum()
            return out

        pysummer = np.frompyfunc([summer, summer], 1, 1,
                            dtypes=[np.dtype(int), np.dtype(int),
                                np.dtype(complex), np.dtype(complex)],
                            stack_inputs=False, signature='(m,m)->()',
                          )
        for d in [np.dtype(float), np.dtype('uint8'), np.dtype('complex64')]:
            in0 = np.arange(4, dtype=d).reshape(1, 2, 2)
            out0 = pysummer(in0)
            assert out0 == in0.sum()
            assert out0.dtype in (int, complex)

    def test_ufunc_kwargs(self):
        from numpy import ufunc, frompyfunc, arange, dtype
        def adder(a, b):
            return a+b
        adder_ufunc = frompyfunc(adder, 2, 1, dtypes=['match'])
        args = [arange(10), arange(10)]
        res = adder_ufunc(*args, dtype=int)
        assert all(res == args[0] + args[1])
        # extobj support needed for linalg ufuncs
        res = adder_ufunc(*args, extobj=[8192, 0, None])
        assert all(res == args[0] + args[1])
        raises(TypeError, adder_ufunc, *args, blah=True)
        raises(TypeError, adder_ufunc, *args, extobj=True)
        raises(RuntimeError, adder_ufunc, *args, sig='dd->d', dtype=int)

    def test_unary_ufunc_kwargs(self):
        from numpy import array, sin, float16
        bool_array = array([True])
        raises(TypeError, sin, bool_array, casting='no')
        assert sin(bool_array, casting='same_kind').dtype == float16
        raises(TypeError, sin, bool_array, out=bool_array, casting='same_kind')
        assert sin(bool_array).dtype == float16

    def test_ufunc_attrs(self):
        from numpy import add, multiply, sin

        assert add.identity == 0
        assert multiply.identity == 1
        assert sin.identity is None

        assert add.nin == 2
        assert add.nout == 1
        assert add.nargs == 3
        assert add.signature == None
        assert multiply.nin == 2
        assert multiply.nout == 1
        assert multiply.nargs == 3
        assert multiply.signature == None
        assert sin.nin == 1
        assert sin.nout == 1
        assert sin.nargs == 2
        assert sin.signature == None

    def test_wrong_arguments(self):
        from numpy import add, sin

        raises(ValueError, add, 1)
        raises(TypeError, add, 1, 2, 3)
        raises(TypeError, sin, 1, 2)
        raises(ValueError, sin)

    def test_single_item(self):
        from numpy import negative, sign, minimum

        assert negative(5.0) == -5.0
        assert sign(-0.0) == 0.0
        assert minimum(2.0, 3.0) == 2.0

    def test_sequence(self):
        from numpy import array, ndarray, negative, minimum
        a = array(range(3))
        b = [2.0, 1.0, 0.0]
        c = 1.0
        b_neg = negative(b)
        assert isinstance(b_neg, ndarray)
        for i in range(3):
            assert b_neg[i] == -b[i]
        min_a_b = minimum(a, b)
        assert isinstance(min_a_b, ndarray)
        for i in range(3):
            assert min_a_b[i] == min(a[i], b[i])
        min_b_a = minimum(b, a)
        assert isinstance(min_b_a, ndarray)
        for i in range(3):
            assert min_b_a[i] == min(a[i], b[i])
        min_a_c = minimum(a, c)
        assert isinstance(min_a_c, ndarray)
        for i in range(3):
            assert min_a_c[i] == min(a[i], c)
        min_c_a = minimum(c, a)
        assert isinstance(min_c_a, ndarray)
        for i in range(3):
            assert min_c_a[i] == min(a[i], c)
        min_b_c = minimum(b, c)
        assert isinstance(min_b_c, ndarray)
        for i in range(3):
            assert min_b_c[i] == min(b[i], c)
        min_c_b = minimum(c, b)
        assert isinstance(min_c_b, ndarray)
        for i in range(3):
            assert min_c_b[i] == min(b[i], c)

    def test_all_available(self):
        # tests that by calling all available ufuncs on scalars, none will
        # raise uncaught interp-level exceptions, (and crash the test)
        # and those that are uncallable can be accounted for.
        # test on the base-class dtypes: int, bool, float, complex, object
        # We need this test since they have no common base class.
        import numpy as np
        not_implemented = set(['ldexp', 'frexp', 'cbrt', 'spacing',
            'hypot', 'modf', 'remainder', 'nextafter'])
        def find_uncallable_ufuncs(dtype):
            uncallable = set()
            array = np.array(1, dtype)
            for s in dir(np):
                u = getattr(np, s)
                if isinstance(u, np.ufunc):
                    try:
                        u(* [array] * u.nin)
                    except AttributeError:
                        pass
                    except NotImplementedError:
                        #print s
                        uncallable.add(s)
                    except TypeError:
                        assert s not in uncallable
                        uncallable.add(s)
            return uncallable
        assert find_uncallable_ufuncs('int') == set()
        assert find_uncallable_ufuncs('bool') == set(['sign'])
        uncallable = find_uncallable_ufuncs('float')
        uncallable = uncallable.difference(not_implemented)
        assert uncallable == set(
                ['bitwise_and', 'bitwise_not', 'bitwise_or', 'bitwise_xor',
                 'left_shift', 'right_shift', 'invert'])
        uncallable = find_uncallable_ufuncs('complex')
        uncallable = uncallable.difference(not_implemented)
        assert uncallable == set(
                ['bitwise_and', 'bitwise_not', 'bitwise_or', 'bitwise_xor',
                 'arctan2', 'deg2rad', 'degrees', 'rad2deg', 'radians',
                 'fabs', 'fmod', 'invert', 'mod',
                 'logaddexp', 'logaddexp2', 'left_shift', 'right_shift',
                 'copysign', 'signbit', 'ceil', 'floor', 'trunc'])
        uncallable = find_uncallable_ufuncs('object')
        uncallable = uncallable.difference(not_implemented)
        assert uncallable == set(
                ['isnan', 'logaddexp2', 'copysign', 'isfinite', 'signbit',
                 'isinf', 'logaddexp'])

    def test_int_only(self):
        from numpy import bitwise_and, array
        a = array(1.0)
        raises(TypeError, bitwise_and, a, a)

    def test_negative(self):
        from numpy import array, negative

        a = array([-5.0, 0.0, 1.0])
        b = negative(a)
        for i in range(3):
            assert b[i] == -a[i]

        a = array([-5.0, 1.0])
        b = negative(a)
        a[0] = 5.0
        assert b[0] == 5.0
        a = array(range(30))
        assert negative(a + a)[3] == -6

        a = array([[1, 2], [3, 4]])
        b = negative(a + a)
        assert (b == [[-2, -4], [-6, -8]]).all()

        class Obj(object):
            def __neg__(self):
                return 'neg'
        x = Obj()
        assert type(negative(x)) is str

    def test_abs(self):
        from numpy import array, absolute

        a = array([-5.0, -0.0, 1.0])
        b = absolute(a)
        for i in range(3):
            assert b[i] == abs(a[i])

    def test_add(self):
        from numpy import array, add

        a = array([-5.0, -0.0, 1.0])
        b = array([ 3.0, -2.0,-3.0])
        c = add(a, b)
        for i in range(3):
            assert c[i] == a[i] + b[i]
        class Obj(object):
            def __add__(self, other):
                return 'add'
        x = Obj()
        assert type(add(x, 0)) is str

    def test_divide(self):
        from numpy import array, divide

        a = array([-5.0, -0.0, 1.0])
        b = array([ 3.0, -2.0,-3.0])
        c = divide(a, b)
        for i in range(3):
            assert c[i] == a[i] / b[i]

        assert (divide(array([-10]), array([2])) == array([-5])).all()

    def test_true_divide(self):
        import math
        from numpy import array, true_divide

        a = array([0, 1, 2, 3, 4, 1, -1])
        b = array([4, 4, 4, 4, 4, 0,  0])
        c = true_divide(a, b)
        assert (c == [0.0, 0.25, 0.5, 0.75, 1.0, float('inf'), float('-inf')]).all()

        assert math.isnan(true_divide(0, 0))

    def test_fabs(self):
        from numpy import array, fabs
        from math import fabs as math_fabs, isnan

        a = array([-5.0, -0.0, 1.0])
        b = fabs(a)
        for i in range(3):
            assert b[i] == math_fabs(a[i])
        assert fabs(float('inf')) == float('inf')
        assert fabs(float('-inf')) == float('inf')
        assert isnan(fabs(float('nan')))

    def test_fmax(self):
        from numpy import fmax, array
        import math

        nnan, nan, inf, ninf = float('-nan'), float('nan'), float('inf'), float('-inf')

        a = [ninf, -5, 0, 5, inf]
        assert (fmax(a, [ninf]*5) == a).all()
        assert (fmax(a, [inf]*5) == [inf]*5).all()
        assert (fmax(a, [1]*5) == [1, 1, 1, 5, inf]).all()
        assert fmax(nan, 0) == 0
        assert fmax(0, nan) == 0
        assert math.isnan(fmax(nan, nan))
        # The numpy docs specify that the FIRST NaN should be used if both are NaN
        # Since comparisons with nnan and nan all return false,
        # use copysign on both sides to sidestep bug in nan representaion
        # on Microsoft win32
        assert math.copysign(1., fmax(nnan, nan)) == math.copysign(1., nnan)

    def test_fmin(self):
        from numpy import fmin
        import math

        nnan, nan, inf, ninf = float('-nan'), float('nan'), float('inf'), float('-inf')

        a = [ninf, -5, 0, 5, inf]
        assert (fmin(a, [ninf]*5) == [ninf]*5).all()
        assert (fmin(a, [inf]*5) == a).all()
        assert (fmin(a, [1]*5) == [ninf, -5, 0, 1, 1]).all()
        assert fmin(nan, 0) == 0
        assert fmin(0, nan) == 0
        assert math.isnan(fmin(nan, nan))
        # The numpy docs specify that the FIRST NaN should be used if both are NaN
        # use copysign on both sides to sidestep bug in nan representaion
        # on Microsoft win32
        assert math.copysign(1., fmin(nnan, nan)) == math.copysign(1., nnan)

    def test_fmod(self):
        from numpy import fmod
        import math

        assert fmod(-1e-100, 1e100) == -1e-100
        assert fmod(3, float('inf')) == 3
        assert (fmod([-3, -2, -1, 1, 2, 3], 2) == [-1,  0, -1,  1,  0,  1]).all()
        for v in [float('inf'), float('-inf'), float('nan'), float('-nan')]:
            assert math.isnan(fmod(v, 2))

    def test_mod(self):
        from numpy import mod
        assert mod(5, 3) == 2
        assert mod(5, -3) == -1
        assert mod(-5, 3) == 1
        assert mod(-5, -3) == -2
        assert mod(2.5, 1) == 0.5
        assert mod(-1.5, 2) == 0.5

    def test_minimum(self):
        from numpy import array, minimum, nan, isnan

        a = array([-5.0, -0.0, 1.0])
        b = array([ 3.0, -2.0,-3.0])
        c = minimum(a, b)
        for i in range(3):
            assert c[i] == min(a[i], b[i])

        arg1 = array([0, nan, nan])
        arg2 = array([nan, 0, nan])
        assert isnan(minimum(arg1, arg2)).all()

    def test_maximum(self):
        from numpy import array, maximum, nan, isnan

        a = array([-5.0, -0.0, 1.0])
        b = array([ 3.0, -2.0,-3.0])
        c = maximum(a, b)
        for i in range(3):
            assert c[i] == max(a[i], b[i])

        arg1 = array([0, nan, nan])
        arg2 = array([nan, 0, nan])
        assert isnan(maximum(arg1, arg2)).all()

        x = maximum(2, 3)
        assert x == 3
        assert isinstance(x, (int, long))

    def test_complex_nan_extrema(self):
        import math
        import numpy as np
        cnan = complex(0, np.nan)

        b = np.minimum(1, cnan)
        assert b.real == 0
        assert math.isnan(b.imag)

        b = np.maximum(1, cnan)
        assert b.real == 0
        assert math.isnan(b.imag)

        b = np.fmin(1, cnan)
        assert b.real == 1
        assert b.imag == 0

        b = np.fmax(1, cnan)
        assert b.real == 1
        assert b.imag == 0

    def test_multiply(self):
        from numpy import array, multiply, arange

        a = array([-5.0, -0.0, 1.0])
        b = array([ 3.0, -2.0,-3.0])
        c = multiply(a, b)
        for i in range(3):
            assert c[i] == a[i] * b[i]

        a = arange(15).reshape(5, 3)
        assert(multiply.reduce(a) == array([0, 3640, 12320])).all()

    def test_rint(self):
        from numpy import array, dtype, rint, isnan
        import sys

        nnan, nan, inf, ninf = float('-nan'), float('nan'), float('inf'), float('-inf')

        reference = array([ninf, -2., -1., -0., 0., 0., 0., 1., 2., inf])
        a = array([ninf, -1.5, -1., -0.5, -0., 0., 0.5, 1., 1.5, inf])
        b = rint(a)
        for i in range(len(a)):
            assert b[i] == reference[i]
        assert isnan(rint(nan))
        assert isnan(rint(nnan))

        assert rint(complex(inf, 1.5)) == complex(inf, 2.)
        assert rint(complex(0.5, inf)) == complex(0., inf)

        assert rint(sys.maxint) > 0.0

    def test_sign(self):
        from numpy import array, sign, dtype

        reference = [-1.0, 0.0, 0.0, 1.0]
        a = array([-5.0, -0.0, 0.0, 6.0])
        b = sign(a)
        for i in range(4):
            assert b[i] == reference[i]

        a = sign(array(range(-5, 5)))
        ref = [-1, -1, -1, -1, -1, 0, 1, 1, 1, 1]
        for i in range(10):
            assert a[i] == ref[i]

        a = sign(array([10+10j, -10+10j, 0+10j, 0-10j, 0+0j, 0-0j], dtype=complex))
        ref = [1, -1, 1, -1, 0, 0]
        assert (a == ref).all()

    def test_signbit(self):
        from numpy import signbit, add, copysign, nan
        assert signbit(add.identity) == False
        assert (signbit([0, 0.0, 1, 1.0, float('inf')]) ==
                [False, False, False, False, False]).all()
        assert (signbit([-0, -0.0, -1, -1.0, float('-inf')]) ==
                [False,  True,  True,  True,  True]).all()
        assert (signbit([copysign(nan, 1), copysign(nan, -1)]) ==
                [False, True]).all()

    def test_reciprocal(self):
        from numpy import array, reciprocal
        inf = float('inf')
        nan = float('nan')
        reference = [-0.2, inf, -inf, 2.0, nan]
        a = array([-5.0, 0.0, -0.0, 0.5, nan])
        b = reciprocal(a)
        for i in range(4):
            assert b[i] == reference[i]

        for dtype in 'bBhHiIlLqQ':
            a = array([-2, -1, 0, 1, 2], dtype)
            reference = [0, -1, 0, 1, 0]
            dtype = a.dtype.name
            if dtype[0] == 'u':
                reference[1] = 0
            elif dtype == 'int32':
                    reference[2] = -2147483648
            elif dtype == 'int64':
                    reference[2] = -9223372036854775808
            b = reciprocal(a)
            assert (b == reference).all()

    def test_subtract(self):
        from numpy import array, subtract

        a = array([-5.0, -0.0, 1.0])
        b = array([ 3.0, -2.0,-3.0])
        c = subtract(a, b)
        for i in range(3):
            assert c[i] == a[i] - b[i]

    def test_floorceiltrunc(self):
        from numpy import array, floor, ceil, trunc
        import math
        ninf, inf = float("-inf"), float("inf")
        a = array([ninf, -1.4, -1.5, -1.0, 0.0, 1.0, 1.4, 0.5, inf])
        assert ([ninf, -2.0, -2.0, -1.0, 0.0, 1.0, 1.0, 0.0, inf] == floor(a)).all()
        assert ([ninf, -1.0, -1.0, -1.0, 0.0, 1.0, 2.0, 1.0, inf] == ceil(a)).all()
        assert ([ninf, -1.0, -1.0, -1.0, 0.0, 1.0, 1.0, 0.0, inf] == trunc(a)).all()
        assert all([math.isnan(f(float("nan"))) for f in floor, ceil, trunc])
        assert all([math.copysign(1, f(abs(float("nan")))) == 1 for f in floor, ceil, trunc])
        assert all([math.copysign(1, f(-abs(float("nan")))) == -1 for f in floor, ceil, trunc])

    def test_round(self):
        from numpy import array, dtype
        ninf, inf = float("-inf"), float("inf")
        a = array([ninf, -1.4, -1.5, -1.0, 0.0, 1.0, 1.4, 0.5, inf])
        assert ([ninf, -1.0, -2.0, -1.0, 0.0, 1.0, 1.0, 0.0, inf] == a.round()).all()
        i = array([-1000, -100, -1, 0, 1, 111, 1111, 11111], dtype=int)
        assert (i == i.round()).all()
        assert (i.round(decimals=4) == i).all()
        assert (i.round(decimals=-4) == [0, 0, 0, 0, 0, 0, 0, 10000]).all()
        b = array([True, False], dtype=bool)
        bround = b.round()
        assert (bround == [1., 0.]).all()
        assert bround.dtype is dtype('float16')
        c = array([10.5+11.5j, -15.2-100.3456j, 0.2343+11.123456j])
        assert (c.round(0) == [10.+12.j, -15-100j, 0+11j]).all()

    def test_copysign(self):
        from numpy import array, copysign

        reference = [5.0, -0.0, 0.0, -6.0]
        a = array([-5.0, 0.0, 0.0, 6.0])
        b = array([5.0, -0.0, 3.0, -6.0])
        c = copysign(a, b)
        for i in range(4):
            assert c[i] == reference[i]

        b = array([True, True, True, True], dtype=bool)
        c = copysign(a, b)
        for i in range(4):
            assert c[i] == abs(a[i])

    def test_exp(self):
        import math
        from numpy import array, exp

        a = array([-5.0, -0.0, 0.0, 12345678.0, float("inf"),
                   -float('inf'), -12343424.0])
        b = exp(a)
        for i in range(len(a)):
            try:
                res = math.exp(a[i])
            except OverflowError:
                res = float('inf')
            assert b[i] == res

    def test_exp2(self):
        import math
        from numpy import array, exp2
        inf = float('inf')
        ninf = -float('inf')
        nan = float('nan')

        a = array([-5.0, -0.0, 0.0, 2, 12345678.0, inf, ninf, -12343424.0])
        b = exp2(a)
        for i in range(len(a)):
            try:
                res = 2 ** a[i]
            except OverflowError:
                res = float('inf')
            assert b[i] == res

        assert exp2(3) == 8
        assert math.isnan(exp2(nan))

    def test_expm1(self):
        import math, cmath
        from numpy import array, expm1
        inf = float('inf')
        ninf = -float('inf')
        nan = float('nan')

        a = array([-5.0, -0.0, 0.0, 12345678.0, float("inf"),
                   -float('inf'), -12343424.0])
        b = expm1(a)
        for i in range(4):
            try:
                res = math.exp(a[i]) - 1
            except OverflowError:
                res = float('inf')
            assert b[i] == res

        assert expm1(1e-50) == 1e-50

    def test_sin(self):
        import math
        from numpy import array, sin

        a = array([0, 1, 2, 3, math.pi, math.pi*1.5, math.pi*2])
        b = sin(a)
        for i in range(len(a)):
            assert b[i] == math.sin(a[i])

        a = sin(array([True, False], dtype=bool))
        assert abs(a[0] - sin(1)) < 1e-3  # a[0] will be very imprecise
        assert a[1] == 0.0

    def test_cos(self):
        import math
        from numpy import array, cos

        a = array([0, 1, 2, 3, math.pi, math.pi*1.5, math.pi*2])
        b = cos(a)
        for i in range(len(a)):
            assert b[i] == math.cos(a[i])

    def test_tan(self):
        import math
        from numpy import array, tan

        a = array([0, 1, 2, 3, math.pi, math.pi*1.5, math.pi*2])
        b = tan(a)
        for i in range(len(a)):
            assert b[i] == math.tan(a[i])

    def test_arcsin(self):
        import math
        from numpy import array, arcsin

        a = array([-1, -0.5, -0.33, 0, 0.33, 0.5, 1])
        b = arcsin(a)
        for i in range(len(a)):
            assert b[i] == math.asin(a[i])

        a = array([-10, -1.5, -1.01, 1.01, 1.5, 10, float('nan'), float('inf'), float('-inf')])
        b = arcsin(a)
        for f in b:
            assert math.isnan(f)

    def test_arccos(self):
        import math
        from numpy import array, arccos

        a = array([-1, -0.5, -0.33, 0, 0.33, 0.5, 1])
        b = arccos(a)
        for i in range(len(a)):
            assert b[i] == math.acos(a[i])

        a = array([-10, -1.5, -1.01, 1.01, 1.5, 10, float('nan'), float('inf'), float('-inf')])
        b = arccos(a)
        for f in b:
            assert math.isnan(f)

    def test_arctan(self):
        import math
        from numpy import array, arctan

        a = array([-3, -2, -1, 0, 1, 2, 3, float('inf'), float('-inf')])
        b = arctan(a)
        for i in range(len(a)):
            assert b[i] == math.atan(a[i])

        a = array([float('nan')])
        b = arctan(a)
        assert math.isnan(b[0])

    def test_arctan2(self):
        import math
        from numpy import array, arctan2

        # From the numpy documentation
        assert (
            arctan2(
                [0.,  0.,           1.,          -1., float('inf'),  float('inf')],
                [0., -0., float('inf'), float('inf'), float('inf'), float('-inf')]) ==
            [0.,  math.pi,  0., -0.,  math.pi/4, 3*math.pi/4]).all()

        a = array([float('nan')])
        b = arctan2(a, 0)
        assert math.isnan(b[0])

    def test_sinh(self):
        import math
        from numpy import array, sinh

        a = array([-1, 0, 1, float('inf'), float('-inf')])
        b = sinh(a)
        for i in range(len(a)):
            assert b[i] == math.sinh(a[i])

    def test_cosh(self):
        import math
        from numpy import array, cosh

        a = array([-1, 0, 1, float('inf'), float('-inf')])
        b = cosh(a)
        for i in range(len(a)):
            assert b[i] == math.cosh(a[i])

    def test_tanh(self):
        import math
        from numpy import array, tanh

        a = array([-1, 0, 1, float('inf'), float('-inf')])
        b = tanh(a)
        for i in range(len(a)):
            assert b[i] == math.tanh(a[i])

    def test_arcsinh(self):
        import math
        from numpy import arcsinh

        for v in [float('inf'), float('-inf'), 1.0, math.e]:
            assert math.asinh(v) == arcsinh(v)
        assert math.isnan(arcsinh(float("nan")))

    def test_arccosh(self):
        import math
        from numpy import arccosh

        for v in [1.0, 1.1, 2]:
            assert math.acosh(v) == arccosh(v)
        for v in [-1.0, 0, .99]:
            assert math.isnan(arccosh(v))

    def test_arctanh(self):
        import math
        from numpy import arctanh

        for v in [.99, .5, 0, -.5, -.99]:
            assert math.atanh(v) == arctanh(v)
        for v in [2.0, -2.0]:
            assert math.isnan(arctanh(v))
        for v in [1.0, -1.0]:
            assert arctanh(v) == math.copysign(float("inf"), v)

    def test_sqrt(self):
        import math
        from numpy import sqrt

        nan, inf = float("nan"), float("inf")
        data = [1, 2, 3, inf]
        results = [math.sqrt(1), math.sqrt(2), math.sqrt(3), inf]
        assert (sqrt(data) == results).all()
        assert math.isnan(sqrt(-1))
        assert math.isnan(sqrt(nan))

    def test_square(self):
        import math
        from numpy import square

        nan, inf, ninf = float("nan"), float("inf"), float("-inf")

        assert math.isnan(square(nan))
        assert math.isinf(square(inf))
        assert math.isinf(square(ninf))
        assert square(ninf) > 0
        assert [square(x) for x in range(-5, 5)] == [x*x for x in range(-5, 5)]
        assert math.isinf(square(1e300))

    def test_radians(self):
        import math
        from numpy import radians, array
        a = array([
            -181, -180, -179,
            181, 180, 179,
            359, 360, 361,
            400, -1, 0, 1,
            float('inf'), float('-inf')])
        b = radians(a)
        for i in range(len(a)):
            assert b[i] == math.radians(a[i])

    def test_deg2rad(self):
        import math
        from numpy import deg2rad, array
        a = array([
            -181, -180, -179,
            181, 180, 179,
            359, 360, 361,
            400, -1, 0, 1,
            float('inf'), float('-inf')])
        b = deg2rad(a)
        for i in range(len(a)):
            assert b[i] == math.radians(a[i])

    def test_degrees(self):
        import math
        from numpy import degrees, array
        a = array([
            -181, -180, -179,
            181, 180, 179,
            359, 360, 361,
            400, -1, 0, 1,
            float('inf'), float('-inf')])
        b = degrees(a)
        for i in range(len(a)):
            assert b[i] == math.degrees(a[i])

    def test_rad2deg(self):
        import math
        from numpy import rad2deg, array
        a = array([
            -181, -180, -179,
            181, 180, 179,
            359, 360, 361,
            400, -1, 0, 1,
            float('inf'), float('-inf')])
        b = rad2deg(a)
        for i in range(len(a)):
            assert b[i] == math.degrees(a[i])

    def test_reduce_errors(self):
        from numpy import sin, add, maximum, zeros

        raises(ValueError, sin.reduce, [1, 2, 3])
        assert add.reduce(1) == 1

        assert list(maximum.reduce(zeros((2, 0)), axis=0)) == []
        exc = raises(ValueError, maximum.reduce, zeros((2, 0)), axis=None)
        assert exc.value[0] == ('zero-size array to reduction operation '
                                'maximum which has no identity')
        exc = raises(ValueError, maximum.reduce, zeros((2, 0)), axis=1)
        assert exc.value[0] == ('zero-size array to reduction operation '
                                'maximum which has no identity')

        a = zeros((2, 2)) + 1
        assert (add.reduce(a, axis=1) == [2, 2]).all()
        assert (add.reduce(a, axis=(1,)) == [2, 2]).all()
        exc = raises(ValueError, add.reduce, a, axis=2)
        assert exc.value[0] == "'axis' entry is out of bounds"

    def test_reduce_1d(self):
        import numpy as np
        from numpy import array, add, maximum, less, float16, complex64

        assert less.reduce([5, 4, 3, 2, 1])
        assert add.reduce([1, 2, 3]) == 6
        assert maximum.reduce([1]) == 1
        assert maximum.reduce([1, 2, 3]) == 3
        raises(ValueError, maximum.reduce, [])

        assert add.reduce(array([True, False] * 200)) == 200
        assert add.reduce(array([True, False] * 200, dtype='int8')) == 200
        assert add.reduce(array([True, False] * 200), dtype='int8') == -56
        assert type(add.reduce(array([True, False] * 200, dtype='float16'))) is float16
        assert type(add.reduce(array([True, False] * 200, dtype='complex64'))) is complex64

        for dtype in ['bool', 'int']:
            assert np.equal.reduce([1, 2], dtype=dtype) == True
            assert np.equal.reduce([1, 2, 0], dtype=dtype) == False

    def test_reduce_axes(self):
        import numpy as np
        a = np.arange(24).reshape(2, 3, 4)
        b = np.add.reduce(a, axis=(0, 1))
        assert b.shape == (4,)
        assert (b == [60, 66, 72, 78]).all()

    def test_reduce_fmax(self):
        import numpy as np
        assert np.fmax.reduce(np.arange(11).astype('b')) == 10

    def test_reduceND(self):
        from numpy import add, arange
        a = arange(12).reshape(3, 4)
        assert (add.reduce(a, 0) == [12, 15, 18, 21]).all()
        assert (add.reduce(a, 1) == [6.0, 22.0, 38.0]).all()
        raises(ValueError, add.reduce, a, 2)

    def test_reduce_keepdims(self):
        from numpy import add, arange
        a = arange(12).reshape(3, 4)
        b = add.reduce(a, 0, keepdims=True)
        assert b.shape == (1, 4)
        assert (add.reduce(a, 0, keepdims=True) == [12, 15, 18, 21]).all()
        assert (add.reduce(a, 0, None, None, True) == [12, 15, 18, 21]).all()

    def test_bitwise(self):
        from numpy import bitwise_and, bitwise_or, bitwise_xor, arange, array
        a = arange(6).reshape(2, 3)
        assert (a & 1 == [[0, 1, 0], [1, 0, 1]]).all()
        assert (a & 1 == bitwise_and(a, 1)).all()
        assert (a | 1 == [[1, 1, 3], [3, 5, 5]]).all()
        assert (a | 1 == bitwise_or(a, 1)).all()
        assert (a ^ 3 == bitwise_xor(a, 3)).all()
        raises(TypeError, 'array([1.0]) & 1')

    def test_unary_bitops(self):
        from numpy import bitwise_not, invert, array
        a = array([1, 2, 3, 4])
        assert (~a == [-2, -3, -4, -5]).all()
        assert (bitwise_not(a) == ~a).all()
        assert (invert(a) == ~a).all()
        assert invert(True) == False
        assert invert(False) == True

    def test_shift(self):
        from numpy import left_shift, right_shift, dtype

        assert (left_shift([5, 1], [2, 13]) == [20, 2**13]).all()
        assert (right_shift(10, range(5)) == [10, 5, 2, 1, 0]).all()
        bool_ = dtype('bool').type
        assert left_shift(bool(1), 3) == left_shift(1, 3)
        assert right_shift(bool(1), 3) == right_shift(1, 3)

    def test_comparisons(self):
        import operator
        from numpy import (equal, not_equal, less, less_equal, greater,
                            greater_equal, arange)

        for ufunc, func in [
            (equal, operator.eq),
            (not_equal, operator.ne),
            (less, operator.lt),
            (less_equal, operator.le),
            (greater, operator.gt),
            (greater_equal, operator.ge),
        ]:
            for a, b in [
                (3, 3),
                (3, 4),
                (4, 3),
                (3.0, 3.0),
                (3.0, 3.5),
                (3.5, 3.0),
                (3.0, 3),
                (3, 3.0),
                (3.5, 3),
                (3, 3.5),
            ]:
                assert ufunc(a, b) == func(a, b)
        c = arange(10)
        val = c == 'abcdefg'
        assert val == False

    def test_count_nonzero(self):
        from numpy import count_nonzero
        assert count_nonzero(0) == 0
        assert count_nonzero(1) == 1
        assert count_nonzero([]) == 0
        assert count_nonzero([1, 2, 0]) == 2
        assert count_nonzero([[1, 2, 0], [1, 0, 2]]) == 4

    def test_true_divide_2(self):
        from numpy import arange, array, true_divide
        assert (true_divide(arange(3), array([2, 2, 2])) == array([0, 0.5, 1])).all()

    def test_isnan_isinf(self):
        from numpy import isnan, isinf, array, dtype
        assert isnan(float('nan'))
        assert not isnan(3)
        assert not isinf(3)
        assert isnan(dtype('float64').type(float('nan')))
        assert not isnan(3)
        assert isinf(float('inf'))
        assert not isnan(3.5)
        assert not isinf(3.5)
        assert not isnan(float('inf'))
        assert not isinf(float('nan'))
        assert (isnan(array([0.2, float('inf'), float('nan')])) == [False, False, True]).all()
        assert (isinf(array([0.2, float('inf'), float('nan')])) == [False, True, False]).all()
        assert isinf(array([0.2])).dtype.kind == 'b'

    def test_logical_ops(self):
        from numpy import logical_and, logical_or, logical_xor, logical_not

        assert (logical_and([True, False , True, True], [1, 1, 3, 0])
                == [True, False, True, False]).all()
        assert (logical_or([True, False, True, False], [1, 2, 0, 0])
                == [True, True, True, False]).all()
        assert (logical_xor([True, False, True, False], [1, 2, 0, 0])
                == [False, True, True, False]).all()
        assert (logical_not([True, False]) == [False, True]).all()
        assert logical_and.reduce([1.,1.]) == True

    def test_logn(self):
        import math
        from numpy import log, log2, log10

        for log_func, base in [(log, math.e), (log2, 2), (log10, 10)]:
            for v in [float('-nan'), float('-inf'), -1, float('nan')]:
                assert math.isnan(log_func(v))
            for v in [-0.0, 0.0]:
                assert log_func(v) == float("-inf")
            assert log_func(float('inf')) == float('inf')
            assert (log_func([1, base]) == [0, 1]).all()

    def test_log1p(self):
        import math
        from numpy import log1p

        for v in [float('-nan'), float('-inf'), -2, float('nan')]:
            assert math.isnan(log1p(v))
        for v in [-1]:
            assert log1p(v) == float("-inf")
        assert log1p(float('inf')) == float('inf')
        assert (log1p([0, 1e-50, math.e - 1]) == [0, 1e-50, 1]).all()

    def test_power_float(self):
        import math
        from numpy import power, array
        a = array([1., 2., 3.])
        b = power(a, 3)
        for i in range(len(a)):
            assert b[i] == a[i] ** 3

        a = array([1., 2., 3.])
        b = array([1., 2., 3.])
        c = power(a, b)
        for i in range(len(a)):
            assert c[i] == a[i] ** b[i]

        assert power(2, float('inf')) == float('inf')
        assert power(float('inf'), float('inf')) == float('inf')
        assert power(12345.0, 12345.0) == float('inf')
        assert power(-12345.0, 12345.0) == float('-inf')
        assert power(-12345.0, 12346.0) == float('inf')
        assert math.isnan(power(-1, 1.1))
        assert math.isnan(power(-1, -1.1))
        assert power(-2.0, -1) == -0.5
        assert power(-2.0, -2) == 0.25
        assert power(12345.0, -12345.0) == 0
        assert power(float('-inf'), 2) == float('inf')
        assert power(float('-inf'), 2.5) == float('inf')
        assert power(float('-inf'), 3) == float('-inf')

    def test_power_int(self):
        import math
        from numpy import power, array
        a = array([1, 2, 3])
        b = power(a, 3)
        for i in range(len(a)):
            assert b[i] == a[i] ** 3

        a = array([1, 2, 3])
        b = array([1, 2, 3])
        c = power(a, b)
        for i in range(len(a)):
            assert c[i] == a[i] ** b[i]

        # assert power(12345, 12345) == -9223372036854775808
        # assert power(-12345, 12345) == -9223372036854775808
        # assert power(-12345, 12346) == -9223372036854775808
        assert power(2, 0) == 1
        assert power(2, -1) == 0
        assert power(2, -2) == 0
        assert power(-2, -1) == 0
        assert power(-2, -2) == 0
        assert power(12345, -12345) == 0

    def test_floordiv(self):
        from numpy import floor_divide, array
        import math
        a = array([1., 2., 3., 4., 5., 6., 6.01])
        b = floor_divide(a, 2.5)
        for i in range(len(a)):
            assert b[i] == a[i] // 2.5

        a = array([10+10j, -15-100j, 0+10j], dtype=complex)
        b = floor_divide(a, 2.5)
        for i in range(len(a)):
            assert b[i] == a[i] // 2.5
        b = floor_divide(a, 2.5+3j)
        #numpy returns (a.real*b.real + a.imag*b.imag) / abs(b)**2
        expect = [3., -23., 1.]
        for i in range(len(a)):
            assert b[i] == expect[i]
        b = floor_divide(a[0], 0.)
        assert math.isnan(b.real)
        assert b.imag == 0.

    def test_logaddexp(self):
        import math
        import sys
        float_max, float_min = sys.float_info.max, sys.float_info.min
        from numpy import logaddexp

        # From the numpy documentation
        prob1 = math.log(1e-50)
        prob2 = math.log(2.5e-50)
        prob12 = logaddexp(prob1, prob2)
        assert math.fabs(-113.87649168120691 - prob12) < 0.000000000001

        assert logaddexp(0, 0) == math.log(2)
        assert logaddexp(float('-inf'), 0) == 0
        assert logaddexp(float_max, float_max) == float_max
        assert logaddexp(float_min, float_min) == math.log(2)

        assert math.isnan(logaddexp(float('nan'), 1))
        assert math.isnan(logaddexp(1, float('nan')))
        assert math.isnan(logaddexp(float('nan'), float('inf')))
        assert math.isnan(logaddexp(float('inf'), float('nan')))
        assert logaddexp(float('-inf'), float('-inf')) == float('-inf')
        assert logaddexp(float('-inf'), float('inf')) == float('inf')
        assert logaddexp(float('inf'), float('-inf')) == float('inf')
        assert logaddexp(float('inf'), float('inf')) == float('inf')

    def test_logaddexp2(self):
        import math
        import sys
        float_max, float_min = sys.float_info.max, sys.float_info.min
        from numpy import logaddexp2
        log2 = math.log(2)

        # From the numpy documentation
        prob1 = math.log(1e-50) / log2
        prob2 = math.log(2.5e-50) / log2
        prob12 = logaddexp2(prob1, prob2)
        assert math.fabs(-164.28904982231052 - prob12) < 0.000000000001

        assert logaddexp2(0, 0) == 1
        assert logaddexp2(float('-inf'), 0) == 0
        assert logaddexp2(float_max, float_max) == float_max
        assert logaddexp2(float_min, float_min) == 1.0

        assert math.isnan(logaddexp2(float('nan'), 1))
        assert math.isnan(logaddexp2(1, float('nan')))
        assert math.isnan(logaddexp2(float('nan'), float('inf')))
        assert math.isnan(logaddexp2(float('inf'), float('nan')))
        assert logaddexp2(float('-inf'), float('-inf')) == float('-inf')
        assert logaddexp2(float('-inf'), float('inf')) == float('inf')
        assert logaddexp2(float('inf'), float('-inf')) == float('inf')
        assert logaddexp2(float('inf'), float('inf')) == float('inf')

    def test_accumulate(self):
        from numpy import add, subtract, multiply, divide, arange, dtype
        assert (add.accumulate([2, 3, 5]) == [2, 5, 10]).all()
        assert (multiply.accumulate([2, 3, 5]) == [2, 6, 30]).all()
        a = arange(4).reshape(2,2)
        b = add.accumulate(a, axis=0)
        assert (b == [[0, 1], [2, 4]]).all()
        b = add.accumulate(a, 1)
        assert (b == [[0, 1], [2, 5]]).all()
        b = add.accumulate(a) #default axis is 0
        assert (b == [[0, 1], [2, 4]]).all()
        # dtype
        a = arange(0, 3, 0.5).reshape(2, 3)
        b = add.accumulate(a, dtype=int, axis=1)
        assert (b == [[0, 0, 1], [1, 3, 5]]).all()
        assert b.dtype == int
        assert add.accumulate([True]*200)[-1] == 200
        assert add.accumulate([True]*200).dtype == dtype('int')
        assert subtract.accumulate([True]*200).dtype == dtype('bool')
        assert divide.accumulate([True]*200).dtype == dtype('int8')

    def test_accumulate_shapes(self):
        import numpy as np
        a = np.arange(6).reshape(2, 1, 3)
        assert np.add.accumulate(a).shape == (2, 1, 3)
        raises(ValueError, "np.add.accumulate(a, out=np.zeros((3, 1, 3)))")
        raises(ValueError, "np.add.accumulate(a, out=np.zeros((2, 3)))")
        raises(ValueError, "np.add.accumulate(a, out=np.zeros((2, 3, 1)))")
        b = np.zeros((2, 1, 3))
        np.add.accumulate(a, out=b, axis=2)
        assert b[0, 0, 2] == 3

    def test_accumulate_shapes_2(self):
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            skip('PyPy-specific behavior in np.ufunc.accumulate')
        import numpy as np
        a = np.arange(6).reshape(2, 1, 3)
        raises(ValueError, "np.add.accumulate(a, out=np.zeros((2, 1, 3, 2)))")


    def test_noncommutative_reduce_accumulate(self):
        import numpy as np
        tosubtract = np.arange(5)
        todivide = np.array([2.0, 0.5, 0.25])
        assert np.subtract.reduce(tosubtract) == -10
        assert np.divide.reduce(todivide) == 16.0
        assert (np.subtract.accumulate(tosubtract) ==
                np.array([0, -1, -3, -6, -10])).all()
        assert (np.divide.accumulate(todivide) ==
                np.array([2., 4., 16.])).all()

    def test_outer(self):
        import numpy as np
        c = np.multiply.outer([1, 2, 3], [4, 5, 6])
        assert c.shape == (3, 3)
        assert (c ==[[ 4,  5,  6],
                     [ 8, 10, 12],
                     [12, 15, 18]]).all()
        A = np.array([[1, 2, 3], [4, 5, 6]])
        B = np.array([[1, 2, 3, 4]])
        c = np.multiply.outer(A, B)
        assert c.shape == (2, 3, 1, 4)
        assert (c == [[[[ 1,  2,  3,  4]],
                       [[ 2,  4,  6,  8]],
                       [[ 3,  6,  9, 12]]],
                      [[[ 4,  8, 12, 16]],
                       [[ 5, 10, 15, 20]],
                       [[ 6, 12, 18, 24]]]]).all()
        exc = raises(ValueError, np.absolute.outer, [-1, -2])
        assert exc.value[0] == 'outer product only supported for binary functions'

    def test_promotion(self):
        import numpy as np
        assert np.add(np.float16(0), np.int16(0)).dtype == np.float32
        assert np.add(np.float16(0), np.int32(0)).dtype == np.float64
        assert np.add(np.float16(0), np.int64(0)).dtype == np.float64
        assert np.add(np.float16(0), np.float32(0)).dtype == np.float32
        assert np.add(np.float16(0), np.float64(0)).dtype == np.float64
        assert np.add(np.float16(0), np.longdouble(0)).dtype == np.longdouble
        assert np.add(np.float16(0), np.complex64(0)).dtype == np.complex64
        assert np.add(np.float16(0), np.complex128(0)).dtype == np.complex128
        assert np.add(np.zeros(5, dtype=np.int8), 257).dtype == np.int16
        assert np.subtract(np.zeros(5, dtype=np.int8), 257).dtype == np.int16
        assert np.divide(np.zeros(5, dtype=np.int8), 257).dtype == np.int16

    def test_add_doc(self):
        import sys
        if '__pypy__' not in sys.builtin_module_names:
            skip('cpython sets docstrings differently')
        try:
            from numpy import set_docstring
        except ImportError:
            from _numpypy.multiarray import set_docstring
        import numpy as np
        assert np.add.__doc__ is None
        add_doc = np.add.__doc__
        ufunc_doc = np.ufunc.__doc__
        try:
            np.add.__doc__ = 'np.add'
            assert np.add.__doc__ == 'np.add'
            # Test for interferences between ufunc objects and their class
            set_docstring(np.ufunc, 'np.ufunc')
            assert np.ufunc.__doc__ == 'np.ufunc'
            assert np.add.__doc__ == 'np.add'
        finally:
            set_docstring(np.ufunc, ufunc_doc)
            np.add.__doc__ = add_doc
