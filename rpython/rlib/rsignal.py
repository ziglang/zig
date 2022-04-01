import signal as cpy_signal
import sys
import py
from rpython.translator import cdir
from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.rarithmetic import is_valid_int

def setup():
    for key, value in cpy_signal.__dict__.items():
        if (key.startswith('SIG') or key.startswith('CTRL_')) and \
                is_valid_int(value) and \
                key != 'SIG_DFL' and key != 'SIG_IGN':
            globals()[key] = value
            yield key

NSIG    = cpy_signal.NSIG
SIG_DFL = cpy_signal.SIG_DFL
SIG_IGN = cpy_signal.SIG_IGN
signal_names = list(setup())
signal_values = {}
for key in signal_names:
    signal_values[globals()[key]] = None
if sys.platform == 'win32' and not hasattr(cpy_signal,'CTRL_C_EVENT'):
    # XXX Hack to revive values that went missing,
    #     Remove this once we are sure the host cpy module has them.
    signal_values[0] = None
    signal_values[1] = None
    signal_names.append('CTRL_C_EVENT')
    signal_names.append('CTRL_BREAK_EVENT')
    CTRL_C_EVENT = 0
    CTRL_BREAK_EVENT = 1
includes = ['stdlib.h', 'src/signals.h', 'signal.h']
if sys.platform != 'win32':
    includes.append('sys/time.h')

cdir = py.path.local(cdir)

eci = ExternalCompilationInfo(
    includes = includes,
    separate_module_files = [cdir / 'src' / 'signals.c'],
    include_dirs = [str(cdir)],
    pre_include_bits = ["#define PYPY_SIGINT_INTERRUPT_EVENT 1\n"],
)

class CConfig:
    _compilation_info_ = eci

if sys.platform != 'win32':
    for name in """
        ITIMER_REAL ITIMER_VIRTUAL ITIMER_PROF
        SIG_BLOCK SIG_UNBLOCK SIG_SETMASK""".split():
        setattr(CConfig, name, rffi_platform.DefinedConstantInteger(name))

    CConfig.timeval = rffi_platform.Struct(
        'struct timeval',
        [('tv_sec', rffi.LONG),
         ('tv_usec', rffi.LONG)])

    CConfig.itimerval = rffi_platform.Struct(
        'struct itimerval',
        [('it_value', CConfig.timeval),
         ('it_interval', CConfig.timeval)])

for k, v in rffi_platform.configure(CConfig).items():
    globals()[k] = v

def external(name, args, result, **kwds):
    return rffi.llexternal(name, args, result, compilation_info=eci,
                           sandboxsafe=True, **kwds)

pypysig_ignore = external('pypysig_ignore', [rffi.INT], lltype.Void)
pypysig_default = external('pypysig_default', [rffi.INT], lltype.Void)
pypysig_setflag = external('pypysig_setflag', [rffi.INT], lltype.Void)
pypysig_reinstall = external('pypysig_reinstall', [rffi.INT], lltype.Void)
PYPYSIG_WITH_NUL_BYTE = 0x01   # flags for the 2nd argument to set_wakeup_fd()
PYPYSIG_USE_SEND = 0x02
PYPYSIG_NO_WARN_FULL  = 0x04
pypysig_set_wakeup_fd = external('pypysig_set_wakeup_fd',
                                 [rffi.INT, rffi.INT], rffi.INT)
pypysig_poll = external('pypysig_poll', [], rffi.INT, releasegil=False)
# don't bother releasing the GIL around a call to pypysig_poll: it's
# pointless and a performance issue
pypysig_pushback = external('pypysig_pushback', [rffi.INT], lltype.Void,
                            releasegil=False)

# don't use rffi.LONGP because the JIT doesn't support raw arrays so far
struct_name = 'pypysig_long_struct'
LONG_STRUCT = lltype.Struct(struct_name, ('c_value', lltype.Signed),
                            hints={'c_name' : struct_name, 'external' : 'C'})
del struct_name

pypysig_getaddr_occurred = external('pypysig_getaddr_occurred', [],
                                    lltype.Ptr(LONG_STRUCT), _nowrapper=True,
                                    elidable_function=True)
pypysig_check_and_reset = external('pypysig_check_and_reset', [],
                                   lltype.Bool, _nowrapper=True)
c_alarm = external('alarm', [rffi.INT], rffi.INT)
c_pause = external('pause', [], rffi.INT, releasegil=True)
c_siginterrupt = external('siginterrupt', [rffi.INT, rffi.INT], rffi.INT,
                          save_err=rffi.RFFI_SAVE_ERRNO)
c_raise = external('raise', [rffi.INT], rffi.INT)

if sys.platform != 'win32':
    itimervalP = rffi.CArrayPtr(itimerval)
    c_setitimer = external('setitimer',
                           [rffi.INT, itimervalP, itimervalP], rffi.INT,
                           save_err=rffi.RFFI_SAVE_ERRNO)
    c_getitimer = external('getitimer', [rffi.INT, itimervalP], rffi.INT)

c_pthread_kill = external('pthread_kill', [lltype.Signed, rffi.INT], rffi.INT,
                          save_err=rffi.RFFI_SAVE_ERRNO)

if sys.platform != 'win32':
    c_strsignal = external('strsignal', [rffi.INT], rffi.CCHARP)
    def strsignal(signum):
        res = c_strsignal(signum)
        if not res:
            return None
        return rffi.charp2str(res)
else:
    def strsignal(signum):
        # CPython does this too!
        if signum == SIGINT:
            return "Interrupt";
        elif signum == SIGILL:
            return "Illegal instruction";
        elif signum == SIGABRT:
            return "Aborted";
        elif signum == SIGFPE:
            return "Floating point exception";
        elif signum == SIGSEGV:
            return "Segmentation fault";
        elif signum == SIGTERM:
            return "Terminated";
        return None


if sys.platform != 'win32':
    c_sigset_t = rffi.COpaquePtr('sigset_t', compilation_info=eci)
    c_sigemptyset = external('sigemptyset', [c_sigset_t], rffi.INT)
    c_sigfillset = external('sigfillset', [c_sigset_t], rffi.INT)
    c_sigaddset = external('sigaddset', [c_sigset_t, rffi.INT], rffi.INT)
    c_sigismember = external('sigismember', [c_sigset_t, rffi.INT], rffi.INT)
    c_sigwait = external('sigwait', [c_sigset_t, rffi.INTP], rffi.INT,
                         releasegil=True,
                         save_err=rffi.RFFI_SAVE_ERRNO)
    c_sigpending = external('sigpending', [c_sigset_t], rffi.INT,
                            save_err=rffi.RFFI_SAVE_ERRNO)
    c_pthread_sigmask = external('pthread_sigmask',
                                 [rffi.INT, c_sigset_t, c_sigset_t], rffi.INT,
                                 save_err=rffi.RFFI_SAVE_ERRNO)
