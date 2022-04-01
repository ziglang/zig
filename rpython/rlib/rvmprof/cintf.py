import platform as host_platform
import py
import sys
import shutil
from rpython.tool.udir import udir
from rpython.tool.version import rpythonroot
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rtyper.tool import rffi_platform as platform
from rpython.rlib import rthread, jit
from rpython.rlib.objectmodel import we_are_translated
from rpython.config.translationoption import get_translation_config
from rpython.jit.backend import detect_cpu

class VMProfPlatformUnsupported(Exception):
    pass

# vmprof works only on x86 for now
IS_SUPPORTED = False
if sys.platform in ('darwin', 'linux', 'linux2') or sys.platform.startswith('freebsd'):
    try:
        proc = detect_cpu.autodetect()
        IS_SUPPORTED = proc.startswith('x86') or proc == 'aarch64'
    except detect_cpu.ProcessorAutodetectError:
        print("PROCESSOR NOT DETECTED, SKIPPING VMPROF")

ROOT = py.path.local(rpythonroot).join('rpython', 'rlib', 'rvmprof')
SRC = ROOT.join('src')
SHARED = SRC.join('shared')
BACKTRACE = SHARED.join('libbacktrace')

def make_eci():
    if make_eci.called:
        raise ValueError("make_eci() should be called at most once")
    #
    compile_extra = ['-DRPYTHON_VMPROF']
    separate_module_files = [
        SHARED.join('symboltable.c'),
        SHARED.join('vmprof_unix.c')
    ]
    if sys.platform.startswith('linux'):
        separate_module_files += [
           BACKTRACE.join('atomic.c'),
           BACKTRACE.join('backtrace.c'),
           BACKTRACE.join('state.c'),
           BACKTRACE.join('elf.c'),
           BACKTRACE.join('dwarf.c'),
           BACKTRACE.join('fileline.c'),
           BACKTRACE.join('mmap.c'),
           BACKTRACE.join('mmapio.c'),
           BACKTRACE.join('posix.c'),
           BACKTRACE.join('sort.c'),
        ]
        _libs = ['dl']
        compile_extra += ['-DVMPROF_UNIX']
        compile_extra += ['-DVMPROF_LINUX']
    elif sys.platform == 'win32':
        compile_extra += ['-DVMPROF_WINDOWS']
        separate_module_files = [SHARED.join('vmprof_win.c')]
        _libs = []
    else:
        # Guessing a BSD-like Unix platform
        compile_extra += ['-DVMPROF_UNIX']
        if sys.platform.startswith('darwin'):
            compile_extra += ['-DVMPROF_APPLE']
        if sys.platform.startswith('freebsd'):
            _libs = ['unwind']
        else:
            _libs = []

    eci_kwds = dict(
        include_dirs = [SRC, SHARED, BACKTRACE],
        includes = ['rvmprof.h','vmprof_stack.h'],
        libraries = _libs,
        separate_module_files = [
            SRC.join('rvmprof.c'),
            SHARED.join('compat.c'),
            SHARED.join('machine.c'),
            SHARED.join('vmp_stack.c'),
            SHARED.join('vmprof_memory.c'),
            SHARED.join('vmprof_common.c'),
            # symbol table already in separate_module_files
        ] + separate_module_files,
        post_include_bits=[],
        compile_extra=compile_extra
        )
    if sys.platform != 'win32':
        eci_kwds['separate_module_files'].append(
            SHARED.join('vmprof_mt.c'),
        )
    make_eci.called = True
    return ExternalCompilationInfo(**eci_kwds), eci_kwds
make_eci.called = False

def configure_libbacktrace_linux():
    bits = 32 if sys.maxsize == 2**31-1 else 64
    # FIXME well, the config generated on x86 seems to work on s390x and ppc
    # vmprof is currently not supported there! we just need to pass compilation
    specific_config = 'config-x86_%d.h' % bits
    config = BACKTRACE.join('config.h')
    shutil.copy(str(BACKTRACE.join(specific_config)), str(config))

def setup():
    if not IS_SUPPORTED:
        raise VMProfPlatformUnsupported
    
    if sys.platform.startswith('linux'):
        configure_libbacktrace_linux()

    eci, eci_kwds = make_eci()
    eci_kwds['compile_extra'].append('-DRPYTHON_LL2CTYPES')
    platform.verify_eci(ExternalCompilationInfo(
                        **eci_kwds))

    vmprof_init = rffi.llexternal("vmprof_init",
                                  [rffi.INT, rffi.DOUBLE, rffi.INT, rffi.INT,
                                   rffi.CCHARP, rffi.INT, rffi.INT],
                                  rffi.CCHARP, compilation_info=eci)
    vmprof_enable = rffi.llexternal("vmprof_enable", [rffi.INT, rffi.INT, rffi.INT],
                                    rffi.INT,
                                    compilation_info=eci,
                                    save_err=rffi.RFFI_SAVE_ERRNO)
    vmprof_disable = rffi.llexternal("vmprof_disable", [], rffi.INT,
                                     compilation_info=eci,
                                     save_err=rffi.RFFI_SAVE_ERRNO)
    vmprof_register_virtual_function = rffi.llexternal(
                                           "vmprof_register_virtual_function",
                                           [rffi.CCHARP, rffi.LONG, rffi.INT],
                                           rffi.INT, compilation_info=eci)
    vmprof_ignore_signals = rffi.llexternal("vmprof_ignore_signals",
                                            [rffi.INT], lltype.Void,
                                            compilation_info=eci,
                                            _nowrapper=True)
    vmprof_get_traceback = rffi.llexternal("vmprof_get_traceback",
                                  [PVMPROFSTACK, llmemory.Address,
                                   rffi.SIGNEDP, lltype.Signed],
                                  lltype.Signed, compilation_info=eci,
                                  _nowrapper=True)

    vmprof_get_profile_path = rffi.llexternal("vmprof_get_profile_path", [rffi.CCHARP, lltype.Signed],
                                              lltype.Signed, compilation_info=eci,
                                              _nowrapper=True)

    vmprof_stop_sampling = rffi.llexternal("vmprof_stop_sampling", [],
                                           rffi.INT, compilation_info=eci,
                                           _nowrapper=True)
    vmprof_start_sampling = rffi.llexternal("vmprof_start_sampling", [],
                                            lltype.Void, compilation_info=eci,
                                            _nowrapper=True)

    return CInterface(locals())


class CInterface(object):
    def __init__(self, namespace):
        for k, v in namespace.iteritems():
            setattr(self, k, v)

    def _freeze_(self):
        return True


# --- copy a few declarations from src/vmprof_stack.h ---

VMPROF_CODE_TAG = 1

VMPROFSTACK = lltype.ForwardReference()
PVMPROFSTACK = lltype.Ptr(VMPROFSTACK)
VMPROFSTACK.become(rffi.CStruct("vmprof_stack_s",
                                ('next', PVMPROFSTACK),
                                ('value', lltype.Signed),
                                ('kind', lltype.Signed)))
# ----------


vmprof_tl_stack = rthread.ThreadLocalField(PVMPROFSTACK, "vmprof_tl_stack")
do_use_eci = rffi.llexternal_use_eci(
    ExternalCompilationInfo(includes=['vmprof_stack.h'],
                            include_dirs = [SRC]))

def enter_code(unique_id):
    do_use_eci()
    s = lltype.malloc(VMPROFSTACK, flavor='raw')
    s.c_next = vmprof_tl_stack.get_or_make_raw()
    s.c_value = unique_id
    s.c_kind = VMPROF_CODE_TAG
    vmprof_tl_stack.setraw(s)
    return s

def leave_code(s):
    if not we_are_translated():
        assert vmprof_tl_stack.getraw() == s
    vmprof_tl_stack.setraw(s.c_next)
    lltype.free(s, flavor='raw')

#
# JIT notes:
#
# - When running JIT-generated assembler code, we have different custom
#   code to build the VMPROFSTACK, so the functions above are not used.
#   (It uses kind == VMPROF_JITTED_TAG and the VMPROFSTACK is allocated
#   in the C stack.)
#
# - The jitcode for decorated_jitted_function() in rvmprof.py is
#   special-cased by jtransform.py to produce this:
#
#        rvmprof_code(0, unique_id)
#        res = inline_call FUNC         <- for func(*args)
#        rvmprof_code(1, unique_id)
#        return res
#
#   There is no 'catch_exception', but the second 'rvmprof_code' is
#   meant to be executed even in case there was an exception.  This is
#   done by a special case in pyjitpl.py and blackhole.py.  The point
#   is that the above simple pattern can be detected by the blackhole
#   interp, when it first rebuilds all the intermediate RPython
#   frames; at that point it needs to call jit_rvmprof_code(0) on all
#   intermediate RPython frames, so it does pattern matching to
#   recognize when it must call that and with which 'unique_id' value.
#
# - The jitcode opcode 'rvmprof_code' doesn't produce any resop.  When
#   meta-interpreting, it causes pyjitpl to call jit_rvmprof_code().
#   As mentioned above, there is logic to call jit_rvmprof_code(1)
#   even if we exit with an exception, even though there is no
#   'catch_exception'.  There is similar logic inside the blackhole
#   interpreter.


def jit_rvmprof_code(leaving, unique_id):
    if leaving == 0:
        enter_code(unique_id)    # ignore the return value
    else:
        s = vmprof_tl_stack.getraw()
        if s.c_value == unique_id and s.c_kind == VMPROF_CODE_TAG:
            leave_code(s)
        else:
            # this is a HACK! in some strange situations related to stack
            # overflows we end up in a situation where the stack is not
            # properly popped somewhere, so we end up with an extra entry.
            # instead of crashing with an assertion error (which was done
            # previously) try to fix the situation by popping of the stack
            # twice. if that also gives the wrong unique_id we still crash with
            # an assert.

            # the test that found this problem is test_recursive_pickle in
            # python3 test_functools.py
            assert (s.c_next and s.c_next.c_value == unique_id and
                        s.c_next.c_kind == VMPROF_CODE_TAG)
            s = vmprof_tl_stack.getraw()
            leave_code(s)
            s = vmprof_tl_stack.getraw()
            leave_code(s)

#
# traceback support

def get_rvmprof_stack():
    return vmprof_tl_stack.get_or_make_raw()
