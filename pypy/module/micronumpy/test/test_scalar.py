# -*- encoding:utf-8 -*-
from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest

class AppTestScalar(BaseNumpyAppTest):
    spaceconfig = dict(usemodules=["micronumpy", "binascii", "struct"])

    def test_integer_types(self):
        import numpy as np
        _32BIT = np.dtype('int').itemsize == 4
        if _32BIT:
            assert np.int32 is np.dtype('l').type
            assert np.uint32 is np.dtype('L').type
            assert np.intp is np.dtype('i').type
            assert np.uintp is np.dtype('I').type
            assert np.int64 is np.dtype('q').type
            assert np.uint64 is np.dtype('Q').type
        else:
            assert np.int32 is np.dtype('i').type
            assert np.uint32 is np.dtype('I').type
            assert np.intp is np.dtype('l').type
            assert np.uintp is np.dtype('L').type
            assert np.int64 is np.dtype('l').type
            assert np.uint64 is np.dtype('L').type
        assert np.int16 is np.short is np.dtype('h').type
        assert np.int_ is np.dtype('l').type
        assert np.uint is np.dtype('L').type
        assert np.dtype('intp') == np.dtype('int')
        assert np.dtype('uintp') == np.dtype('uint')
        assert np.dtype('i') is not np.dtype('l') is not np.dtype('q')
        assert np.dtype('I') is not np.dtype('L') is not np.dtype('Q')

    def test_hierarchy(self):
        import numpy
        assert issubclass(numpy.float64, numpy.floating)
        assert issubclass(numpy.longfloat, numpy.floating)
        assert not issubclass(numpy.float64, numpy.longfloat)
        assert not issubclass(numpy.longfloat, numpy.float64)

    def test_mro(self):
        import numpy
        assert numpy.int16.__mro__ == (numpy.int16, numpy.signedinteger,
                                       numpy.integer, numpy.number,
                                       numpy.generic, object)
        assert numpy.bool_.__mro__ == (numpy.bool_, numpy.generic, object)

    def test_init(self):
        import numpy as np
        import math
        import sys
        assert np.intp() == np.intp(0)
        assert np.intp('123') == np.intp(123)
        raises(TypeError, np.intp, None)
        assert np.float64() == np.float64(0)
        assert math.isnan(np.float64(None))
        assert np.bool_() == np.bool_(False)
        assert np.bool_('abc') == np.bool_(True)
        assert np.bool_(None) == np.bool_(False)
        assert np.complex_() == np.complex_(0)
        #raises(TypeError, np.complex_, '1+2j')
        assert math.isnan(np.complex_(None))
        for c in ['i', 'I', 'l', 'L', 'q', 'Q']:
            assert np.dtype(c).type().dtype.char == c
        for c in ['l', 'q']:
            assert np.dtype(c).type(sys.maxint) == sys.maxint
        for c in ['L', 'Q']:
            assert np.dtype(c).type(sys.maxint + 42) == sys.maxint + 42
        assert np.float32(np.array([True, False])).dtype == np.float32
        assert type(np.float32(np.array([True]))) is np.ndarray
        assert type(np.float32(1.0)) is np.float32
        a = np.array([True, False])
        assert np.bool_(a) is a

    def test_builtin(self):
        import numpy as np
        assert int(np.str_('12')) == 12
        exc = raises(ValueError, "int(np.str_('abc'))")
        assert str(exc.value).startswith('invalid literal for int()')
        assert int(np.uint64((2<<63) - 1)) == (2<<63) - 1
        exc = raises(ValueError, "int(np.float64(np.nan))")
        assert str(exc.value) == "cannot convert float NaN to integer"
        exc = raises(OverflowError, "int(np.float64(np.inf))")
        assert str(exc.value) == "cannot convert float infinity to integer"
        assert int(np.float64(1e100)) == int(1e100)
        assert long(np.float64(1e100)) == int(1e100)
        assert int(np.complex128(1e100+2j)) == int(1e100)
        exc = raises(OverflowError, "int(np.complex64(1e100+2j))")
        assert str(exc.value) == "cannot convert float infinity to integer"
        assert int(np.str_('100000000000000000000')) == 100000000000000000000
        assert long(np.str_('100000000000000000000')) == 100000000000000000000

        assert float(np.float64(1e100)) == 1e100
        assert float(np.complex128(1e100+2j)) == 1e100
        assert float(np.str_('1e100')) == 1e100
        assert float(np.str_('inf')) == np.inf
        assert str(float(np.float64(np.nan))) == 'nan'

        assert oct(np.int32(11)) == '0o13'
        assert oct(np.float32(11.6)) == '0o13'
        assert oct(np.complex64(11-12j)) == '0o13'
        assert hex(np.int32(11)) == '0xb'
        assert hex(np.float32(11.6)) == '0xb'
        assert hex(np.complex64(11-12j)) == '0xb'
        assert bin(np.int32(11)) == '0b1011'
        exc = raises(TypeError, "bin(np.float32(11.6))")
        assert "index" in exc.value.message
        exc = raises(TypeError, "len(np.int32(11))")
        assert "has no len" in exc.value.message
        assert len(np.string_('123')) == 3

    def test_pickle(self):
        from numpy import dtype, zeros
        import sys
        try:
            from numpy.core.multiarray import scalar
        except ImportError:
            # running on dummy module
            from numpy import scalar
        from pickle import loads, dumps
        i = dtype('int32').type(1337)
        f = dtype('float64').type(13.37)
        c = dtype('complex128').type(13 + 37.j)

        swap = lambda s: (''.join(reversed(s))) if sys.byteorder == 'big' else s
        assert i.__reduce__() == (scalar, (dtype('int32'), swap('9\x05\x00\x00')))
        assert f.__reduce__() == (scalar, (dtype('float64'), swap('=\n\xd7\xa3p\xbd*@')))
        assert c.__reduce__() == (scalar, (dtype('complex128'), swap('\x00\x00\x00\x00\x00\x00*@') + \
                                                                swap('\x00\x00\x00\x00\x00\x80B@')))

        assert loads(dumps(i)) == i
        assert loads(dumps(f)) == f
        assert loads(dumps(c)) == c

        a = zeros(3)
        assert loads(dumps(a.sum())) == a.sum()

    def test_round(self):
        import numpy as np
        i = np.dtype('int32').type(1337)
        f = np.dtype('float64').type(13.37)
        c = np.dtype('complex128').type(13 + 37.j)
        b = np.dtype('bool').type(1)
        assert i.round(decimals=-2) == 1300
        assert i.round(decimals=1) == 1337
        assert c.round() == c
        assert f.round() == 13.
        assert f.round(decimals=-1) == 10.
        assert f.round(decimals=1) == 13.4
        raises(TypeError, b.round, decimals=5)
        assert f.round(decimals=1, out=None) == 13.4
        assert b.round() == 1.0

    def test_astype(self):
        import numpy as np
        a = np.bool_(True).astype(np.float32)
        assert type(a) is np.float32
        assert a == 1.0
        a = np.bool_(True).astype('int32')
        assert type(a) is np.int32
        assert a == 1
        a = np.str_('123').astype('int32')
        assert type(a) is np.int32
        assert a == 123

    def test_copy(self):
        import numpy as np
        a = np.int32(2)
        b = a.copy()
        assert type(b) is type(a)
        assert b == a
        assert b is not a

    def test_methods(self):
        import numpy as np
        for a in [np.int32(2), np.float64(2.0), np.complex64(42)]:
            for op in ['min', 'max', 'sum', 'prod']:
                assert getattr(a, op)() == a
            for op in ['argmin', 'argmax']:
                b = getattr(a, op)()
                assert type(b) is np.int_
                assert b == 0

    def test_buffer(self):
        import numpy as np
        a = np.int32(123)
        b = memoryview(a)
        assert type(b) is memoryview
        a = np.string_('abc')
        b = memoryview(a)
        assert str(b) == a

    def test_byteswap(self):
        import numpy as np
        assert np.int64(123).byteswap() == 8863084066665136128
        a = np.complex64(1+2j).byteswap()
        assert repr(a.real).startswith('4.60060')
        assert repr(a.imag).startswith('8.96831')

    def test_squeeze(self):
        import numpy as np
        assert np.True_.squeeze() is np.True_
        a = np.float32(1.0)
        assert a.squeeze() is a
        raises(TypeError, a.squeeze, 2)

    def test_bitshift(self):
        import numpy as np
        assert np.int32(123) >> 1 == 61
        assert type(np.int32(123) >> 1) is np.int_
        assert np.int64(123) << 1 == 246
        assert type(np.int64(123) << 1) is np.int64
        exc = raises(TypeError, "np.uint64(123) >> 1")
        assert 'not supported for the input types' in exc.value.message

    def test_attributes(self):
        import numpy as np
        value = np.dtype('int64').type(12345)
        assert value.dtype == np.dtype('int64')
        assert value.size == 1
        assert value.itemsize == 8
        assert value.nbytes == 8
        assert value.shape == ()
        assert value.strides == ()
        assert value.ndim == 0
        assert value.T is value

    def test_indexing(self):
        import numpy as np
        v = np.int32(2)
        b = v[()]
        assert isinstance(b, np.int32)
        assert b.shape == ()
        assert b == v
        b = v[...]
        assert isinstance(b, np.ndarray)
        assert b.shape == ()
        assert b == v
        raises(IndexError, "v['blah']")

    def test_realimag(self):
        import numpy as np
        a = np.int64(2)
        assert a.real == 2
        assert a.imag == 0
        a = np.float64(2.5)
        assert a.real == 2.5
        assert a.imag == 0.0
        a = np.complex64(2.5-1.5j)
        assert a.real == 2.5
        assert a.imag == -1.5

    def test_view(self):
        import numpy as np
        import sys
        s = np.dtype('int64').type(12)
        exc = raises(ValueError, s.view, 'int8')
        assert str(exc.value) == "new type not compatible with array."
        t = s.view('double')
        assert type(t) is np.double
        assert t < 7e-323
        t = s.view('complex64')
        assert type(t) is np.complex64
        if sys.byteorder == 'big':
            assert 0 < t.imag < 1
            assert t.real == 0
        else:
            assert 0 < t.real < 1
            assert t.imag == 0
        exc = raises(TypeError, s.view, 'string')
        assert str(exc.value) == "data-type must not be 0-sized"
        t = s.view('S8')
        assert type(t) is np.string_
        if sys.byteorder == 'big':
            assert t == '\x00' * 7 + '\x0c'
        else:
            assert t == '\x0c'
        s = np.dtype('string').type('abc1')
        assert s.view('S4') == 'abc1'
        if '__pypy__' in sys.builtin_module_names:
            raises(NotImplementedError, s.view, [('a', 'i2'), ('b', 'i2')])
        else:
            b = s.view([('a', 'i2'), ('b', 'i2')])
            assert b.shape == ()
            assert b[0] == 25185
            assert b[1] == 12643
        if '__pypy__' in sys.builtin_module_names:
            raises(TypeError, "np.dtype([('a', 'int64'), ('b', 'int64')]).type('a' * 16)")
        else:
            s = np.dtype([('a', 'int64'), ('b', 'int64')]).type('a' * 16)
            assert s.view('S16') == 'a' * 16

    def test_as_integer_ratio(self):
        import numpy as np
        raises(AttributeError, 'np.float32(1.5).as_integer_ratio()')
        assert np.float64(1.5).as_integer_ratio() == (3, 2)

    def test_tostring(self):
        import numpy as np
        assert np.int64(123).tostring() == np.array(123, dtype='i8').tostring()
        assert np.int64(123).tostring('C') == np.array(123, dtype='i8').tostring()
        assert np.float64(1.5).tostring() == np.array(1.5, dtype=float).tostring()
        exc = raises(TypeError, 'np.int64(123).tostring("Z")')
        assert exc.value[0] == 'order not understood'

    def test_reshape(self):
        import numpy as np
        assert np.int64(123).reshape((1,)) == 123
        assert np.int64(123).reshape(1).shape == (1,)
        assert np.int64(123).reshape((1,)).shape == (1,)
        exc = raises(ValueError, "np.int64(123).reshape((2,))")
        assert exc.value[0] == 'total size of new array must be unchanged'
        assert type(np.int64(123).reshape(())) == np.int64

    def test_complex_scalar_complex_cast(self):
        import numpy as np
        for tp in [np.csingle, np.cdouble, np.clongdouble]:
            x = tp(1+2j)
            assert hasattr(x, '__complex__') == (tp != np.cdouble)
            assert complex(x) == 1+2j

    def test_complex_str_format(self):
        import numpy as np
        for t in [np.complex64, np.complex128]:
            assert str(t(complex(1, float('nan')))) == '(1+nan*j)'
            assert str(t(complex(1, float('-nan')))) == '(1+nan*j)'
            assert str(t(complex(1, float('inf')))) == '(1+inf*j)'
            assert str(t(complex(1, float('-inf')))) == '(1-inf*j)'
            for x in [0, 1, -1]:
                assert str(t(complex(x))) == str(complex(x))
                assert str(t(x*1j)) == str(complex(x*1j))
                assert str(t(x + x*1j)) == str(complex(x + x*1j))

    def test_complex_zero_division(self):
        import numpy as np
        for t in [np.complex64, np.complex128]:
            a = t(0.0)
            b = t(1.0)
            assert np.isinf(b/a)
            b = t(complex(np.inf, np.inf))
            assert np.isinf(b/a)
            b = t(complex(np.inf, np.nan))
            assert np.isinf(b/a)
            b = t(complex(np.nan, np.inf))
            assert np.isinf(b/a)
            b = t(complex(np.nan, np.nan))
            assert np.isnan(b/a)
            b = t(0.)
            assert np.isnan(b/a)

    def test_scalar_iter(self):
        from numpy import int8, int16, int32, int64, float32, float64
        from numpy import complex64, complex128
        for t in (int8, int16, int32, int64, float32, float64,
                  complex64, complex128):
            raises(TypeError, iter, t(17))

    def test_item_tolist(self):
        from numpy import int8, int16, int32, int64, float32, float64
        from numpy import complex64, complex128, dtype

        def _do_test(np_type, py_type, orig_val, exp_val):
            val = np_type(orig_val)
            assert val == orig_val
            assert val.item() == exp_val
            assert val.tolist() == exp_val
            assert type(val.item()) is py_type
            assert type(val.tolist()) is py_type
            val.item(0)
            val.item(())
            val.item((0,))
            raises(ValueError, val.item, 0, 1)
            raises(ValueError, val.item, 0, '')
            raises(TypeError, val.item, '')
            raises(IndexError, val.item, 2)

        for t in int8, int16, int32:
            _do_test(t, int, 17, 17)

        py_type = int if dtype('int').itemsize == 8 else long
        _do_test(int64, py_type, 17, 17)

        for t in float32, float64:
            _do_test(t, float, 17, 17)

        for t in complex64, complex128:
            _do_test(t, complex, 17j, 17j)

    def test_transpose(self):
        from numpy import int8, int16, int32, int64, float32, float64
        from numpy import complex64, complex128

        def _do_test(np_type, orig_val, exp_val):
            val = np_type(orig_val)
            assert val == orig_val
            assert val.transpose() == exp_val
            assert type(val.transpose()) is np_type
            val.transpose(())
            raises(ValueError, val.transpose, 0, 1)
            raises(TypeError, val.transpose, 0, '')
            raises(ValueError, val.transpose, 0)

        for t in int8, int16, int32, int64:
            _do_test(t, 17, 17)

        for t in float32, float64:
            _do_test(t, 17, 17)

        for t in complex64, complex128:
            _do_test(t, 17j, 17j)

    def test_swapaxes(self):
        from numpy import int8, int16, int32, int64, float32, float64
        from numpy import complex64, complex128

        def _do_test(np_type, orig_val, exp_val):
            val = np_type(orig_val)
            assert val == orig_val
            raises(ValueError, val.swapaxes, 10, 20)
            raises(ValueError, val.swapaxes, 0, 1)
            raises(TypeError, val.swapaxes, 0, ())

        for t in int8, int16, int32, int64:
            _do_test(t, 17, 17)

        for t in float32, float64:
            _do_test(t, 17, 17)

        for t in complex64, complex128:
            _do_test(t, 17j, 17j)

    def test_nonzero(self):
        from numpy import int8, int16, int32, int64, float32, float64
        from numpy import complex64, complex128

        for t in (int8, int16, int32, int64, float32, float64,
                  complex64, complex128):
            res, = t(17).nonzero()
            assert len(res) == 1
            assert res[0] == 0
            res, = t(0).nonzero()
            assert len(res) == 0

    def test_fill(self):
        import sys
        from numpy import int8, int16, int32, int64, float32, float64
        from numpy import complex64, complex128

        for t in (int8, int16, int32, int64, float32, float64,
                  complex64, complex128):
            t(17).fill(2)
            exc = (TypeError if t in (complex64, complex128)
                   and '__pypy__' not in sys.builtin_module_names
                   else ValueError)
            raises(exc, t(17).fill, '')

    def test_conj(self):
        from numpy import int8, int16, int32, int64, float32, float64
        from numpy import complex64, complex128

        def _do_test(np_type, orig_val, exp_val):
            val = np_type(orig_val)
            assert val == orig_val
            assert val.conj() == exp_val
            assert val.conjugate() == exp_val

        for t in (int8, int16, int32, int64, float32, float64,
                  complex64, complex128):
            _do_test(t, 17, 17)

        for t in complex64, complex128:
            _do_test(t, 17j, -17j)

    def test_string_boxes(self):
        from numpy import str_
        assert isinstance(str_(3), str_)
        assert str_(3) == '3'
        assert str(str_(3)) == '3'
        assert repr(str_(3)) == "'3'"

    def test_unicode_boxes(self):
        from numpy import unicode_
        u = unicode_(3)
        assert isinstance(u, unicode)
        assert u == u'3'

    def test_unicode_repr(self):
        from numpy import unicode_
        u = unicode_(3)
        assert str(u) == '3'
        assert repr(u) == "u'3'"
        u = unicode_(u'Aÿ')
        # raises(UnicodeEncodeError, "str(u)")  # XXX
        assert repr(u) == repr(u'Aÿ')

    def test_binop_with_sequence(self):
        import numpy as np
        c = np.float64(1.) + [1.]
        assert isinstance(c, np.ndarray)
        assert (c == [2.]).all()
