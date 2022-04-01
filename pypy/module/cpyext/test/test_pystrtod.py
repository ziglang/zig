import math

from pypy.module.cpyext import pystrtod
from pypy.module.cpyext.test.test_api import BaseApiTest, raises_w
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from rpython.rtyper.lltypesystem import rffi
from rpython.rtyper.lltypesystem import lltype
from pypy.module.cpyext.pystrtod import PyOS_string_to_double, INTP_real
from pypy.module.cpyext.api import Py_DTSF_SIGN, Py_DTSF_ADD_DOT_0, Py_DTSF_ALT


class TestPyOS_string_to_double(BaseApiTest):

    def test_simple_float(self, space):
        s = rffi.str2constcharp('0.4')
        null = lltype.nullptr(rffi.CCHARPP.TO)
        r = PyOS_string_to_double(space, s, null, None)
        assert r == 0.4
        rffi.free_charp(s)

    def test_empty_string(self, space):
        s = rffi.str2constcharp('')
        null = lltype.nullptr(rffi.CCHARPP.TO)
        with raises_w(space, ValueError):
            PyOS_string_to_double(space, s, null, None)
        rffi.free_charp(s)

    def test_bad_string(self, space):
        s = rffi.str2constcharp(' 0.4')
        null = lltype.nullptr(rffi.CCHARPP.TO)
        with raises_w(space, ValueError):
            PyOS_string_to_double(space, s, null, None)
        rffi.free_charp(s)

    def test_overflow_pos(self, space):
        s = rffi.str2constcharp('1e500')
        null = lltype.nullptr(rffi.CCHARPP.TO)
        r = PyOS_string_to_double(space, s, null, None)
        assert math.isinf(r)
        assert r > 0
        rffi.free_charp(s)

    def test_overflow_neg(self, space):
        s = rffi.str2constcharp('-1e500')
        null = lltype.nullptr(rffi.CCHARPP.TO)
        r = PyOS_string_to_double(space, s, null, None)
        assert math.isinf(r)
        assert r < 0
        rffi.free_charp(s)

    def test_overflow_exc(self, space):
        s = rffi.str2constcharp('1e500')
        null = lltype.nullptr(rffi.CCHARPP.TO)
        with raises_w(space, ValueError):
            PyOS_string_to_double(space, s, null, space.w_ValueError)
        rffi.free_charp(s)

    def test_endptr_number(self, space):
        s = rffi.str2constcharp('0.4')
        endp = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
        r = PyOS_string_to_double(space, s, endp, None)
        assert r == 0.4
        endp_addr = rffi.cast(rffi.LONG, endp[0])
        s_addr = rffi.cast(rffi.LONG, s)
        assert endp_addr == s_addr + 3
        rffi.free_charp(s)
        lltype.free(endp, flavor='raw')

    def test_endptr_tail(self, space):
        s = rffi.str2constcharp('0.4 foo')
        endp = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
        r = PyOS_string_to_double(space, s, endp, None)
        assert r == 0.4
        endp_addr = rffi.cast(rffi.LONG, endp[0])
        s_addr = rffi.cast(rffi.LONG, s)
        assert endp_addr == s_addr + 3
        rffi.free_charp(s)
        lltype.free(endp, flavor='raw')

    def test_endptr_no_conversion(self, space):
        s = rffi.str2constcharp('foo')
        endp = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
        with raises_w(space, ValueError):
            PyOS_string_to_double(space, s, endp, None)
        endp_addr = rffi.cast(rffi.LONG, endp[0])
        s_addr = rffi.cast(rffi.LONG, s)
        assert endp_addr == s_addr
        rffi.free_charp(s)
        lltype.free(endp, flavor='raw')

    def test_endptr_inf(self, space):
        endp = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
        for test in ('inf', '+infinity', 'INF'):
            s = rffi.str2constcharp(test)
            r = PyOS_string_to_double(space, s, endp, None)
            assert r == float('inf')
            endp_addr = rffi.cast(rffi.LONG, endp[0])
            s_addr = rffi.cast(rffi.LONG, s)
            assert endp_addr == s_addr + len(test)
            rffi.free_charp(s)
        s = rffi.str2constcharp('inf aaa')
        r = PyOS_string_to_double(space, s, endp, None)
        assert r == float('inf')
        endp_addr = rffi.cast(rffi.LONG, endp[0])
        s_addr = rffi.cast(rffi.LONG, s)
        # CPython returns 3
        assert endp_addr == s_addr + 3
        rffi.free_charp(s)
        lltype.free(endp, flavor='raw')

class TestPyOS_double_to_string(BaseApiTest):

    def test_flags(self, api):
        from rpython.rlib.rfloat import DTSF_SIGN, DTSF_ADD_DOT_0, DTSF_ALT
        assert Py_DTSF_SIGN == DTSF_SIGN
        assert Py_DTSF_ADD_DOT_0 == DTSF_ADD_DOT_0
        assert Py_DTSF_ALT == DTSF_ALT

    def test_format_code(self, api):
        ptype = lltype.malloc(INTP_real.TO, 1, flavor='raw')
        r = api.PyOS_double_to_string(150.0, 'e', 1, 0, ptype)
        assert '1.5e+02' == rffi.charp2str(r)
        type_value = rffi.cast(lltype.Signed, ptype[0])
        assert pystrtod.Py_DTST_FINITE == type_value
        rffi.free_charp(r)
        lltype.free(ptype, flavor='raw')

    def test_precision(self, api):
        ptype = lltype.malloc(INTP_real.TO, 1, flavor='raw')
        r = api.PyOS_double_to_string(3.14159269397, 'g', 5, 0, ptype)
        assert '3.1416' == rffi.charp2str(r)
        type_value = rffi.cast(lltype.Signed, ptype[0])
        assert pystrtod.Py_DTST_FINITE == type_value
        rffi.free_charp(r)
        lltype.free(ptype, flavor='raw')

    def test_flags_sign(self, api):
        ptype = lltype.malloc(INTP_real.TO, 1, flavor='raw')
        r = api.PyOS_double_to_string(-3.14, 'g', 3, Py_DTSF_SIGN, ptype)
        assert '-3.14' == rffi.charp2str(r)
        type_value = rffi.cast(lltype.Signed, ptype[0])
        assert pystrtod.Py_DTST_FINITE == type_value
        rffi.free_charp(r)
        lltype.free(ptype, flavor='raw')

    def test_flags_add_dot_0(self, api):
        ptype = lltype.malloc(INTP_real.TO, 1, flavor='raw')
        r = api.PyOS_double_to_string(3, 'g', 5, Py_DTSF_ADD_DOT_0, ptype)
        assert '3.0' == rffi.charp2str(r)
        type_value = rffi.cast(lltype.Signed, ptype[0])
        assert pystrtod.Py_DTST_FINITE == type_value
        rffi.free_charp(r)
        lltype.free(ptype, flavor='raw')

    def test_flags_alt(self, api):
        ptype = lltype.malloc(INTP_real.TO, 1, flavor='raw')
        r = api.PyOS_double_to_string(314., 'g', 3, Py_DTSF_ALT, ptype)
        assert '314.' == rffi.charp2str(r)
        type_value = rffi.cast(lltype.Signed, ptype[0])
        assert pystrtod.Py_DTST_FINITE == type_value
        rffi.free_charp(r)
        lltype.free(ptype, flavor='raw')

    def test_ptype_nan(self, api):
        ptype = lltype.malloc(INTP_real.TO, 1, flavor='raw')
        r = api.PyOS_double_to_string(float('nan'), 'g', 3, Py_DTSF_ALT, ptype)
        assert 'nan' == rffi.charp2str(r)
        type_value = rffi.cast(lltype.Signed, ptype[0])
        assert pystrtod.Py_DTST_NAN == type_value
        rffi.free_charp(r)
        lltype.free(ptype, flavor='raw')

    def test_ptype_infinity(self, api):
        ptype = lltype.malloc(INTP_real.TO, 1, flavor='raw')
        r = api.PyOS_double_to_string(1e200 * 1e200, 'g', 0, 0, ptype)
        assert 'inf' == rffi.charp2str(r)
        type_value = rffi.cast(lltype.Signed, ptype[0])
        assert pystrtod.Py_DTST_INFINITE == type_value
        rffi.free_charp(r)
        lltype.free(ptype, flavor='raw')

    def test_ptype_null(self, api):
        ptype = lltype.nullptr(INTP_real.TO)
        r = api.PyOS_double_to_string(3.14, 'g', 3, 0, ptype)
        assert '3.14' == rffi.charp2str(r)
        assert ptype == lltype.nullptr(INTP_real.TO)
        rffi.free_charp(r)

class AppTestStringToDouble(AppTestCpythonExtensionBase):

    def test_endswith_space(self):
        module = self.import_extension('foo', [
           ("test_convert", "METH_O",
            '''
                Py_ssize_t size;
                const char *utf8 = PyUnicode_AsUTF8AndSize(args, &size);
                double result = PyOS_string_to_double(utf8, NULL, NULL);
                if (result == -1.0 && PyErr_Occurred()) {
                    return NULL;
                }
                return PyFloat_FromDouble(result);
                
            '''),
           ])
        
        for s in ('.123 ', 'inf ', 'nan ', '1e500 '):
            try:
                module.test_convert(s)
            except ValueError as e:
                pass
            else:
                assert False, 'did not raise'
