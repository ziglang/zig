from pypy.module.micronumpy.test.test_base import BaseNumpyAppTest
from pypy.module.micronumpy.descriptor import get_dtype_cache, num2dtype
from pypy.module.micronumpy.casting import (
    promote_types, can_cast_type, _promote_types_su)
import pypy.module.micronumpy.constants as NPY


class AppTestNumSupport(BaseNumpyAppTest):
    def test_result_type(self):
        import numpy as np
        exc = raises(ValueError, np.result_type)
        assert str(exc.value) == "at least one array or dtype is required"
        exc = raises(TypeError, np.result_type, a=2)
        assert str(exc.value) == "result_type() takes no keyword arguments"
        assert np.result_type(True) is np.dtype('bool')
        assert np.result_type(1) is np.dtype('int')
        assert np.result_type(1.) is np.dtype('float64')
        assert np.result_type(1+2j) is np.dtype('complex128')
        assert np.result_type(1, 1.) is np.dtype('float64')
        assert np.result_type(np.array([1, 2])) is np.dtype('int')
        assert np.result_type(np.array([1, 2]), 1, 1+2j) is np.dtype('complex128')
        assert np.result_type(np.array([1, 2]), 1, 'float64') is np.dtype('float64')
        assert np.result_type(np.array([1, 2]), 1, None) is np.dtype('float64')

    def test_can_cast(self):
        import numpy as np

        assert np.can_cast(np.int32, np.int64)
        assert np.can_cast(np.float64, complex)
        assert not np.can_cast(np.complex64, float)
        assert np.can_cast(np.bool_, np.bool_)

        assert np.can_cast('i8', 'f8')
        assert not np.can_cast('i8', 'f4')
        assert np.can_cast('i4', 'S11')

        assert np.can_cast('i8', 'i8', 'no')
        assert not np.can_cast('<i8', '>i8', 'no')

        assert np.can_cast('<i8', '>i8', 'equiv')
        assert not np.can_cast('<i4', '>i8', 'equiv')

        assert np.can_cast('<i4', '>i8', 'safe')
        assert not np.can_cast('<i8', '>i4', 'safe')

        assert np.can_cast('<i8', '>i4', 'same_kind')
        assert not np.can_cast('<i8', '>u4', 'same_kind')

        assert np.can_cast('<i8', '>u4', 'unsafe')

        assert np.can_cast('bool', 'S5')
        assert not np.can_cast('bool', 'S4')

        assert np.can_cast('b', 'S4')
        assert not np.can_cast('b', 'S3')

        assert np.can_cast('u1', 'S3')
        assert not np.can_cast('u1', 'S2')
        assert np.can_cast('u2', 'S5')
        assert not np.can_cast('u2', 'S4')
        assert np.can_cast('u4', 'S10')
        assert not np.can_cast('u4', 'S9')
        assert np.can_cast('u8', 'S20')
        assert not np.can_cast('u8', 'S19')

        assert np.can_cast('i1', 'S4')
        assert not np.can_cast('i1', 'S3')
        assert np.can_cast('i2', 'S6')
        assert not np.can_cast('i2', 'S5')
        assert np.can_cast('i4', 'S11')
        assert not np.can_cast('i4', 'S10')
        assert np.can_cast('i8', 'S21')
        assert not np.can_cast('i8', 'S20')

        assert np.can_cast('bool', 'S5')
        assert not np.can_cast('bool', 'S4')

        assert np.can_cast('b', 'U4')
        assert not np.can_cast('b', 'U3')

        assert np.can_cast('u1', 'U3')
        assert not np.can_cast('u1', 'U2')
        assert np.can_cast('u2', 'U5')
        assert not np.can_cast('u2', 'U4')
        assert np.can_cast('u4', 'U10')
        assert not np.can_cast('u4', 'U9')
        assert np.can_cast('u8', 'U20')
        assert not np.can_cast('u8', 'U19')

        assert np.can_cast('i1', 'U4')
        assert not np.can_cast('i1', 'U3')
        assert np.can_cast('i2', 'U6')
        assert not np.can_cast('i2', 'U5')
        assert np.can_cast('i4', 'U11')
        assert not np.can_cast('i4', 'U10')
        assert np.can_cast('i8', 'U21')
        assert not np.can_cast('i8', 'U20')

        raises(TypeError, np.can_cast, 'i4', None)
        raises(TypeError, np.can_cast, None, 'i4')

    def test_can_cast_scalar(self):
        import numpy as np
        assert np.can_cast(True, np.bool_)
        assert np.can_cast(True, np.int8)
        assert not np.can_cast(0, np.bool_)
        assert np.can_cast(127, np.int8)
        assert not np.can_cast(128, np.int8)
        assert np.can_cast(128, np.int16)

        assert np.can_cast(np.float32('inf'), np.float32)
        assert np.can_cast(float('inf'), np.float32)  # XXX: False in CNumPy?!
        assert np.can_cast(3.3e38, np.float32)
        assert not np.can_cast(3.4e38, np.float32)

        assert np.can_cast(1 + 2j, np.complex64)
        assert not np.can_cast(1 + 1e50j, np.complex64)
        assert np.can_cast(1., np.complex64)
        assert not np.can_cast(1e50, np.complex64)

    def test_can_cast_record(self):
        import numpy as np
        rec1 = np.dtype([('x', int), ('y', float)])
        rec2 = np.dtype([('x', float), ('y', float)])
        rec3 = np.dtype([('y', np.float64), ('x', float)])
        assert not np.can_cast(rec1, rec2, 'equiv')
        assert np.can_cast(rec2, rec3, 'equiv')
        assert np.can_cast(rec1, rec2)
        assert np.can_cast(int, rec1)

    def test_min_scalar_type(self):
        import numpy as np
        assert np.min_scalar_type(2**8 - 1) == np.dtype('uint8')
        assert np.min_scalar_type(2**64 - 1) == np.dtype('uint64')
        # XXX: np.asarray(2**64) fails with OverflowError
        # assert np.min_scalar_type(2**64) == np.dtype('O')

    def test_promote_types(self):
        import numpy as np
        assert np.promote_types('f4', 'f8') == np.dtype('float64')
        assert np.promote_types('i8', 'f4') == np.dtype('float64')
        assert np.promote_types('>i8', '<c8') == np.dtype('complex128')
        assert np.promote_types('i4', 'S8') == np.dtype('S11')
        assert np.promote_types('f4', 'S8') == np.dtype('S32')
        assert np.promote_types('f4', 'U8') == np.dtype('U32')
        assert np.promote_types('?', '?') is np.dtype('?')
        assert np.promote_types('?', 'float64') is np.dtype('float64')
        assert np.promote_types('float64', '?') is np.dtype('float64')
        assert np.promote_types('i', 'b') is np.dtype('i')
        assert np.promote_types('i', '?') is np.dtype('i')
        assert np.promote_types('c8', 'f8') is np.dtype('c16')
        assert np.promote_types('c8', 'longdouble') == np.dtype('clongdouble')
        assert np.promote_types('c16', 'longdouble') == np.dtype('clongdouble')

    def test_result_type(self):
        import numpy as np
        assert np.result_type(np.uint8, np.int8) == np.int16
        assert np.result_type(np.uint16(1), np.int8(0)) == np.int32
        assert np.result_type(np.uint16(1), np.int8(0), np.uint8) == np.uint8
        assert np.result_type(-1, np.uint8, 1) == np.int16

def test_can_cast_same_type(space):
    dt_bool = get_dtype_cache(space).w_booldtype
    assert can_cast_type(space, dt_bool, dt_bool, 'no')
    assert can_cast_type(space, dt_bool, dt_bool, 'equiv')
    assert can_cast_type(space, dt_bool, dt_bool, 'safe')
    assert can_cast_type(space, dt_bool, dt_bool, 'same_kind')
    assert can_cast_type(space, dt_bool, dt_bool, 'unsafe')

def test_promote_types_su(space):
    dt_int8 = num2dtype(space, NPY.BYTE)
    dt_uint8 = num2dtype(space, NPY.UBYTE)
    dt_int16 = num2dtype(space, NPY.SHORT)
    dt_uint16 = num2dtype(space, NPY.USHORT)
    # The results must be signed
    assert _promote_types_su(space, dt_int8, dt_int16, False, False) == (dt_int16, False)
    assert _promote_types_su(space, dt_int8, dt_int16, True, False) == (dt_int16, False)
    assert _promote_types_su(space, dt_int8, dt_int16, False, True) == (dt_int16, False)

    # The results may be unsigned
    assert _promote_types_su(space, dt_int8, dt_int16, True, True) == (dt_int16, True)
    assert _promote_types_su(space, dt_uint8, dt_int16, False, True) == (dt_uint16, True)
