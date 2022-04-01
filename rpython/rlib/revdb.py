import sys
from rpython.rlib.objectmodel import we_are_translated, fetch_translated_config
from rpython.rlib.objectmodel import specialize
from rpython.rlib.rarithmetic import r_longlong
from rpython.rtyper.lltypesystem import lltype, llmemory, rstr
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.annlowlevel import llhelper, hlstr
from rpython.rtyper.annlowlevel import cast_gcref_to_instance
from rpython.rtyper.lltypesystem import lltype, rffi


CMD_PRINT       = 1
CMD_BACKTRACE   = 2
CMD_LOCALS      = 3
CMD_BREAKPOINTS = 4
CMD_STACKID     = 5
CMD_ATTACHID    = 6
CMD_COMPILEWATCH= 7
CMD_CHECKWATCH  = 8
CMD_WATCHVALUES = 9
ANSWER_LINECACHE= 19
ANSWER_TEXT     = 20
ANSWER_STACKID  = 21
ANSWER_NEXTNID  = 22
ANSWER_WATCH    = 23
ANSWER_CHBKPT   = 24


def stop_point(place=0):
    """Indicates a point in the execution of the RPython program where
    the reverse-debugger can stop.  When reverse-debugging, we see
    the "time" as the index of the stop-point that happened.
    """
    if we_are_translated():
        if fetch_translated_config().translation.reverse_debugger:
            llop.revdb_stop_point(lltype.Void, place)

def register_debug_command(command, lambda_func):
    """Register the extra RPython-implemented debug command."""

def send_answer(cmd, arg1=0, arg2=0, arg3=0, extra=""):
    """For RPython debug commands: writes an answer block to stdout"""
    llop.revdb_send_answer(lltype.Void, cmd, arg1, arg2, arg3, extra)

def send_output(text):
    send_answer(ANSWER_TEXT, extra=text)

def send_print(text):
    send_answer(ANSWER_TEXT, 1, extra=text)   # adds a newline

def send_nextnid(unique_id):
    send_answer(ANSWER_NEXTNID, unique_id)

def send_watch(text, ok_flag):
    send_answer(ANSWER_WATCH, ok_flag, extra=text)

def send_linecache(filename, linenum, strip=True):
    send_answer(ANSWER_LINECACHE, linenum, int(strip), extra=filename)

def send_change_breakpoint(breakpointnum, newtext=''):
    send_answer(ANSWER_CHBKPT, breakpointnum, extra=newtext)

def current_time():
    """For RPython debug commands: returns the current time."""
    return llop.revdb_get_value(lltype.SignedLongLong, 'c')

def current_break_time():
    """Returns the time configured for the next break.  When going forward,
    this is the target time at which we'll stop going forward."""
    return llop.revdb_get_value(lltype.SignedLongLong, 'b')

def total_time():
    """For RPython debug commands: returns the total time (measured
    as the total number of stop-points)."""
    return llop.revdb_get_value(lltype.SignedLongLong, 't')

def currently_created_objects():
    """For RPython debug commands: returns the current value of
    the object creation counter.  All objects created so far have
    a lower unique id; all objects created afterwards will have a
    unique id greater or equal."""
    return llop.revdb_get_value(lltype.SignedLongLong, 'u')

def current_place():
    """For RPython debug commands: the value of the 'place' argument
    passed to stop_point().
    """
    return llop.revdb_get_value(lltype.Signed, 'p')

def flag_io_disabled():
    """Returns True if we're in the debugger typing commands."""
    if we_are_translated():
        if fetch_translated_config().translation.reverse_debugger:
            flag = llop.revdb_get_value(lltype.Signed, 'i')
            return flag != ord('R')  # FID_REGULAR_MODE
    return False

## @specialize.arg(1)
## def go_forward(time_delta, callback):
##     """For RPython debug commands: tells that after this function finishes,
##     the debugger should run the 'forward <time_delta>' command and then
##     invoke the 'callback' with no argument.
##     """
##     _change_time('f', time_delta, callback)

def breakpoint(num):
    llop.revdb_breakpoint(lltype.Void, num)

def set_thread_breakpoint(tnum):
    llop.revdb_set_thread_breakpoint(lltype.Void, tnum)

@specialize.argtype(0)
def get_unique_id(x):
    """Returns the creation number of the object 'x'.  For objects created
    by the program, it is globally unique, monotonic, and reproducible
    among multiple processes.  For objects created by a debug command,
    this returns a (random) negative number.  Right now, this returns 0
    for all prebuilt objects.
    """
    return llop.revdb_get_unique_id(lltype.SignedLongLong, x)

def track_object(unique_id, callback):
    """Track the creation of the object given by its unique_id, which must
    be in the future (i.e. >= currently_created_objects()).  Call this
    before go_forward().  If go_forward() goes over the creation of this
    object, then 'callback(gcref)' is called.  Careful in callback(),
    gcref is not fully initialized and should not be immediately read from,
    only stored for later.  The purpose of callback() is to possibly
    call track_object() again to track the next object, and/or to call
    breakpoint().  Note: object tracking remains activated until one of:
    (1) we reach the creation time in go_forward(); (2) we call
    track_object() to track a different object; (3) we call jump_in_time().
    """
    ll_callback = llhelper(_CALLBACK_GCREF_FNPTR, callback)
    llop.revdb_track_object(lltype.Void, unique_id, ll_callback)

def watch_save_state(force=False):
    return llop.revdb_watch_save_state(lltype.Bool, force)

def watch_restore_state(any_watch_point):
    llop.revdb_watch_restore_state(lltype.Void, any_watch_point)


def split_breakpoints_arg(breakpoints):
    # RPython generator to help in splitting the string arg in CMD_BREAKPOINTS
    n = 0
    i = 0
    while i < len(breakpoints):
        kind = breakpoints[i]
        i += 1
        if kind != '\x00':
            length = (ord(breakpoints[i]) |
                      (ord(breakpoints[i + 1]) << 8) |
                      (ord(breakpoints[i + 2]) << 16))
            assert length >= 0
            i += 3
            yield n, kind, breakpoints[i : i + length]
            i += length
        n += 1
    assert i == len(breakpoints)


# ____________________________________________________________


## @specialize.arg(2)
## def _change_time(mode, time, callback):
##     ll_callback = llhelper(_CALLBACK_NOARG_FNPTR, callback)
##     llop.revdb_change_time(lltype.Void, mode, time, ll_callback)
## _CALLBACK_NOARG_FNPTR = lltype.Ptr(lltype.FuncType([], lltype.Void))
_CALLBACK_GCREF_FNPTR = lltype.Ptr(lltype.FuncType([llmemory.GCREF],
                                                   lltype.Void))
_CMDPTR = rffi.CStructPtr('rpy_revdb_command_s',
                          ('cmd', rffi.INT),
                          ('arg1', lltype.SignedLongLong),
                          ('arg2', lltype.SignedLongLong),
                          ('arg3', lltype.SignedLongLong),
                          hints={'ignore_revdb': True})


class RegisterDebugCommand(ExtRegistryEntry):
    _about_ = register_debug_command

    def compute_result_annotation(self, s_command_num, s_lambda_func):
        command_num = s_command_num.const
        lambda_func = s_lambda_func.const
        assert isinstance(command_num, (int, str))
        t = self.bookkeeper.annotator.translator
        if t.config.translation.reverse_debugger:
            func = lambda_func()
            try:
                cmds = t.revdb_commands
            except AttributeError:
                cmds = t.revdb_commands = {}
            old_func = cmds.setdefault(command_num, func)
            assert old_func is func
            s_func = self.bookkeeper.immutablevalue(func)
            arg_getter = getattr(self, 'arguments_' + str(command_num),
                                 self.default_arguments)
            self.bookkeeper.emulate_pbc_call(self.bookkeeper.position_key,
                                             s_func, arg_getter())

    def default_arguments(self):
        from rpython.annotator import model as annmodel
        from rpython.rtyper import llannotation
        return [llannotation.SomePtr(ll_ptrtype=_CMDPTR),
                annmodel.SomeString()]

    def arguments_ALLOCATING(self):
        from rpython.annotator import model as annmodel
        from rpython.rtyper import llannotation
        return [annmodel.SomeInteger(knowntype=r_longlong),
                llannotation.lltype_to_annotation(llmemory.GCREF)]

    def arguments_WATCHING(self):
        raise Exception("XXX remove me")

    def specialize_call(self, hop):
        hop.exception_cannot_occur()


# ____________________________________________________________

# Emulation for strtod() and dtoa() when running debugger commands
# (we can't easily just call C code there).  The emulation can return
# a crude result.  Hack hack hack.

_INVALID_STRTOD = -3.46739514239368e+113

def emulate_strtod(input):
    d = llop.revdb_strtod(lltype.Float, input)
    if d == _INVALID_STRTOD:
        raise ValueError
    return d

def emulate_dtoa(value):
    s = llop.revdb_dtoa(lltype.Ptr(rstr.STR), value)
    s = hlstr(s)
    assert s is not None
    return s

def emulate_modf(x):
    return (llop.revdb_modf(lltype.Float, x, 0),
            llop.revdb_modf(lltype.Float, x, 1))

def emulate_frexp(x):
    return (llop.revdb_frexp(lltype.Float, x, 0),
            int(llop.revdb_frexp(lltype.Float, x, 1)))
