
import ctypes
from rpython.rtyper.tool.mkrffi import *
from rpython.translator import cdir
import py

class random_structure(ctypes.Structure):
    _fields_ = [('one', ctypes.c_int),
                ('two', ctypes.POINTER(ctypes.c_int))]

def test_rffisource():
    res = RffiSource({1:2, 3:4}, "ab") + RffiSource(None, "c")
    assert res.structs == {1:2, 3:4}
    assert str(res.source) == "ab\nc"
    res += RffiSource({5:6})
    assert 5 in res.structs.keys()

def test_proc_tp_simple():
    rffi_source = RffiSource()
    assert rffi_source.proc_tp(ctypes.c_int) == 'rffi.INT'
    assert rffi_source.proc_tp(ctypes.c_void_p) == 'rffi.VOIDP'
    assert rffi_source.compiled()

def test_proc_tp_complicated():
    rffi_source = RffiSource()    
    assert rffi_source.proc_tp(ctypes.POINTER(ctypes.c_uint)) == \
           "lltype.Ptr(lltype.Array(rffi.UINT, hints={'nolength': True}))"
    src = rffi_source.proc_tp(random_structure)
    _src = py.code.Source("""
    random_structure = lltype.Struct('random_structure', ('one', rffi.INT), ('two', lltype.Ptr(lltype.Array(rffi.INT, hints={'nolength': True}))),  hints={'external':'C'})
    """)
    src = rffi_source.source
    assert src.strip() == _src.strip(), str(src) + "\n" + str(_src)
    assert rffi_source.compiled()

def test_proc_tp_array():
    rffi_source = RffiSource()
    src = rffi_source.proc_tp(ctypes.c_uint * 12)
    _src = "lltype.Ptr(lltype.Array(rffi.UINT, hints={'nolength': True}))"
    assert src == _src

def test_proc_cyclic_structure():
    rffi_source = RffiSource()
    x_ptr = ctypes.POINTER('x')
    class x(ctypes.Structure):
        _fields_ = [('x', x_ptr)]
    x_ptr._type_ = x
    rffi_source.proc_tp(x)
    _src = py.code.Source("""
    forward_ref0 = lltype.ForwardReference()
    x = lltype.Struct('x', ('x', lltype.Ptr(forward_ref0)),  hints={'external':'C'})

    forward_ref0.become(x)
    """)
    assert rffi_source.source.strip() == _src.strip()

class TestMkrffi(object):
    def setup_class(cls):
        import ctypes
        from rpython.tool.udir import udir
        from rpython.translator.platform import platform
        from rpython.translator.tool.cbuild import ExternalCompilationInfo

        c_source = """
        #include "src/precommondefs.h"

        RPY_EXPORTED
        void *int_to_void_p(int arg) {}

        RPY_EXPORTED
        struct random_structure* int_int_to_struct_p(int one, int two) {}
        """

        c_file = udir.join('rffilib.c')
        c_file.write(c_source)
        eci = ExternalCompilationInfo(include_dirs=[cdir])
        libname = platform.compile([c_file], eci,
                                   standalone=False)
        cls.lib = ctypes.CDLL(str(libname))
    
    def test_single_func(self):
        func = self.lib.int_to_void_p
        func.argtypes = [ctypes.c_int]
        func.restype = ctypes.c_voidp

        src = RffiSource()
        src.proc_func(func)
        _src = py.code.Source("""
        int_to_void_p = rffi.llexternal('int_to_void_p', [rffi.INT], rffi.VOIDP)
        """)

        assert src.source == _src, str(src) + "\n" + str(_src)
        assert src.compiled()

    def test_struct_return(self):
        func = self.lib.int_int_to_struct_p
        func.argtypes = [ctypes.c_int, ctypes.c_int]
        func.restype = ctypes.POINTER(random_structure)
        rffi_source = RffiSource()
        rffi_source.proc_func(func)
        assert random_structure in rffi_source.structs
        _src = py.code.Source("""
        random_structure = lltype.Struct('random_structure', ('one', rffi.INT), ('two', lltype.Ptr(lltype.Array(rffi.INT, hints={'nolength': True}))),  hints={'external':'C'})

        int_int_to_struct_p = rffi.llexternal('int_int_to_struct_p', [rffi.INT, rffi.INT], lltype.Ptr(random_structure))
        """)
        src = rffi_source.source
        assert src.strip() == _src.strip(), str(src) + "\n" + str(_src)
        assert rffi_source.compiled()
        
