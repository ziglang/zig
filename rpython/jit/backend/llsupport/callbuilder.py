from rpython.rlib.clibffi import FFI_DEFAULT_ABI
from rpython.rlib import rgil
from rpython.rtyper.lltypesystem import lltype, rffi


class AbstractCallBuilder(object):

    # this is the calling convention (can be FFI_STDCALL on Windows)
    callconv = FFI_DEFAULT_ABI

    # is it for the main CALL of a call_release_gil?
    is_call_release_gil = False

    # this can be set to guide more complex calls: gives the detailed
    # type of the arguments
    argtypes = ""
    ressign = False


    def __init__(self, assembler, fnloc, arglocs, resloc, restype, ressize):
        self.fnloc = fnloc
        self.arglocs = arglocs
        self.asm = assembler
        self.mc = assembler.mc
        self.resloc = resloc
        self.restype = restype
        self.ressize = ressize

    def emit_no_collect(self):
        """Emit a call that cannot collect."""
        self.prepare_arguments()
        self.emit_raw_call()
        self.restore_stack_pointer()
        self.load_result()

    def emit(self):
        """Emit a regular call; not for CALL_RELEASE_GIL."""
        self.prepare_arguments()
        self.push_gcmap()
        self.emit_raw_call()
        self.restore_stack_pointer()
        self.pop_gcmap()
        self.load_result()

    def emit_call_release_gil(self, save_err):
        """Emit a CALL_RELEASE_GIL, including calls to releasegil_addr
        and reacqgil_addr.  'save_err' is a combination of rffi.RFFI_*ERR*."""
        fastgil = rffi.cast(lltype.Signed, rgil.gil_fetch_fastgil())
        self.select_call_release_gil_mode()
        self.prepare_arguments()
        self.push_gcmap_for_call_release_gil()
        self.call_releasegil_addr_and_move_real_arguments(fastgil)
        self.write_real_errno(save_err)
        self.emit_raw_call()
        self.restore_stack_pointer()
        self.read_real_errno(save_err)
        self.move_real_result_and_call_reacqgil_addr(fastgil)
        self.pop_gcmap()
        self.load_result()

    def call_releasegil_addr_and_move_real_arguments(self, fastgil):
        raise NotImplementedError

    def move_real_result_and_call_reacqgil_addr(self, fastgil):
        raise NotImplementedError

    def write_real_errno(self, save_err):
        raise NotImplementedError

    def read_real_errno(self, save_err):
        raise NotImplementedError

    def select_call_release_gil_mode(self):
        """Overridden in CallBuilder64"""
        self.is_call_release_gil = True

    def prepare_arguments(self):
        raise NotImplementedError

    def push_gcmap(self):
        raise NotImplementedError

    def push_gcmap_for_call_release_gil(self):
        assert self.is_call_release_gil
        # we put the gcmap now into the frame before releasing the GIL,
        # and pop it after reacquiring the GIL.  The assumption
        # is that this gcmap describes correctly the situation at any
        # point in-between: all values containing GC pointers should
        # be safely saved out of registers by now, and will not be
        # manipulated by any of the following CALLs.
        gcmap = self.asm._regalloc.get_gcmap(noregs=True)
        self.asm.push_gcmap(self.mc, gcmap, store=True)

    def pop_gcmap(self):
        raise NotImplementedError

    def emit_raw_call(self):
        raise NotImplementedError

    def restore_stack_pointer(self):
        raise NotImplementedError

    def load_result(self):
        raise NotImplementedError
