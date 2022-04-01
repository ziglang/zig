from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib import rposix
from rpython.jit.backend.x86 import profagent

class OProfileError(Exception):
    def __init__(self, errno, where):
        self.errno = errno
        self.where = where


eci = ExternalCompilationInfo(includes=['stdint.h', 'opagent.h'],
                              library_dirs=['/usr/local/lib/oprofile/'],
                              libraries=['bfd', 'opagent'])
try:
    rffi_platform.verify_eci(eci)
except rffi_platform.CompilationError:
    OPROFILE_AVAILABLE = False
else:
    OPROFILE_AVAILABLE = True
    AGENT = rffi.VOIDP
    uint64_t = rffi.ULONGLONG
    op_open_agent = rffi.llexternal(
        "op_open_agent",
        [],
        AGENT,
        compilation_info=eci,
        save_err=rffi.RFFI_SAVE_ERRNO)
    op_close_agent = rffi.llexternal(
        "op_close_agent",
        [AGENT],
        rffi.INT,
        compilation_info=eci,
        save_err=rffi.RFFI_SAVE_ERRNO)
    # arguments are:
    # agent, symbol_name, address in memory, address in memory again, size
    op_write_native_code = rffi.llexternal(
        "op_write_native_code",
        [AGENT, rffi.CCHARP, uint64_t, rffi.VOIDP, rffi.UINT],
        rffi.INT,
        compilation_info=eci,
        save_err=rffi.RFFI_SAVE_ERRNO)


class OProfileAgent(profagent.ProfileAgent):

    def startup(self):
        if not OPROFILE_AVAILABLE:
            return
        agent = op_open_agent()
        if not agent:
            raise OProfileError(rposix.get_saved_errno(), "startup")
        self.agent = agent

    def shutdown(self):
        if not OPROFILE_AVAILABLE:
            return
        success = op_close_agent(self.agent)
        if success != 0:
            raise OProfileError(rposix.get_saved_errno(), "shutdown")

    def native_code_written(self, name, address, size):
        assert size > 0
        if not OPROFILE_AVAILABLE:
            return
        uaddress = rffi.cast(rffi.ULONG, address)
        success = op_write_native_code(self.agent, name, uaddress, rffi.cast(rffi.VOIDP, 0), size)
        if success != 0:
            raise OProfileError(rposix.get_saved_errno(), "write")
