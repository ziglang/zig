from rpython.rlib.jit_libffi import types, CIF_DESCRIPTION, FFI_TYPE_PP
from rpython.rlib.clibffi import FFI_DEFAULT_ABI
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.jit.codewriter.longlong import is_64_bit
from rpython.jit.backend.llsupport.descr import *
from rpython.jit.backend.llsupport.ffisupport import *
from rpython.rlib.rarithmetic import is_emulated_long


class FakeCPU:
    def __init__(self, supports_floats=False, supports_longlong=False,
                 supports_singlefloats=False):
        self.supports_floats = supports_floats
        self.supports_longlong = supports_longlong
        self.supports_singlefloats = supports_singlefloats
    def calldescrof_dynamic(self, cif_descr, effectinfo):
        return get_call_descr_dynamic(self, cif_descr, effectinfo)

def test_call_descr_dynamic():
    args = [types.sint, types.pointer]
    descr = calldescr_dynamic_for_tests(FakeCPU(), args, types.sint)
    assert isinstance(descr, CallDescr)
    assert descr.result_type == 'i'
    assert descr.result_flag == FLAG_SIGNED
    assert descr.arg_classes == 'ii'
    assert descr.get_ffi_flags() == FFI_DEFAULT_ABI

    args = [types.sint, types.double, types.pointer]
    descr = calldescr_dynamic_for_tests(FakeCPU(), args, types.void)
    assert descr is None    # missing floats
    descr = calldescr_dynamic_for_tests(FakeCPU(supports_floats=True),
                                        args, types.void)
    assert descr.result_type == 'v'
    assert descr.result_flag == FLAG_VOID
    assert descr.arg_classes == 'ifi'
    assert descr.get_ffi_flags() == FFI_DEFAULT_ABI

    descr = calldescr_dynamic_for_tests(FakeCPU(), [], types.sint8)
    assert descr.get_result_size() == 1
    assert descr.result_flag == FLAG_SIGNED
    assert descr.is_result_signed() == True

    descr = calldescr_dynamic_for_tests(FakeCPU(), [], types.uint8)
    assert isinstance(descr, CallDescr)
    assert descr.get_result_size() == 1
    assert descr.result_flag == FLAG_UNSIGNED
    assert descr.is_result_signed() == False

    if not is_64_bit or is_emulated_long:
        descr = calldescr_dynamic_for_tests(FakeCPU(), [], types.slonglong)
        assert descr is None   # missing longlongs
        descr = calldescr_dynamic_for_tests(FakeCPU(supports_longlong=True),
                                            [], types.slonglong)
        assert isinstance(descr, CallDescr)
        assert descr.result_flag == FLAG_FLOAT
        assert descr.result_type == 'L'
        assert descr.get_ffi_flags() == FFI_DEFAULT_ABI
    else:
        assert types.slonglong is types.slong

    descr = calldescr_dynamic_for_tests(FakeCPU(), [], types.float)
    assert descr is None   # missing singlefloats
    descr = calldescr_dynamic_for_tests(FakeCPU(supports_singlefloats=True),
                                        [], types.float)
    assert descr.result_flag == FLAG_UNSIGNED
    assert descr.result_type == 'S'
    assert descr.get_ffi_flags() == FFI_DEFAULT_ABI
