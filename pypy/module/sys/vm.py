"""
Implementation of interpreter-level 'sys' routines.
"""

from rpython.rlib import jit
from rpython.rlib.rutf8 import MAXUNICODE
from rpython.rlib import debug
from rpython.rlib import objectmodel

from pypy.interpreter import gateway
from pypy.interpreter.error import oefmt, OperationError
from pypy.interpreter.gateway import unwrap_spec, WrappedDefault


# ____________________________________________________________

app_hookargs = gateway.applevel("""
from _structseq import structseqtype, structseqfield
class UnraisableHookArgs(metaclass=structseqtype):
    exc_type = structseqfield(0, "Exception type")
    exc_value = structseqfield(1, "Exception value")
    exc_traceback = structseqfield(2, "Exception traceback")
    err_msg = structseqfield(3, "Error message")
    object = structseqfield(4, "Object causing the exception")
    extra_line = structseqfield(6, "Extra error lines that is PyPy specific")
""")

@unwrap_spec(depth=int)
def _getframe(space, depth=0):
    """Return a frame object from the call stack.  If optional integer depth is
given, return the frame object that many calls below the top of the stack.
If that is deeper than the call stack, ValueError is raised.  The default
for depth is zero, returning the frame at the top of the call stack.

This function should be used for internal and specialized
purposes only."""
    if depth < 0:
        raise oefmt(space.w_ValueError, "frame index must not be negative")
    return getframe(space, depth)


@jit.look_inside_iff(lambda space, depth: jit.isconstant(depth))
def getframe(space, depth):
    ec = space.getexecutioncontext()
    f = ec.gettopframe_nohidden()
    while True:
        if f is None:
            raise oefmt(space.w_ValueError, "call stack is not deep enough")
        if depth == 0:
            f.mark_as_escaped()
            return f
        depth -= 1
        f = ec.getnextframe_nohidden(f)


def _stack_check_noinline():
    from rpython.rlib.rstack import stack_check
    stack_check()
_stack_check_noinline._dont_inline_ = True

@jit.dont_look_inside
@unwrap_spec(new_limit="c_int")
def setrecursionlimit(space, new_limit):
    """setrecursionlimit() sets the maximum number of nested calls that
can occur before a RecursionError is raised.  On PyPy the limit
is approximative and checked at a lower level.  The default 1000
reserves 768KB of stack space, which should suffice (on Linux,
depending on the compiler settings) for ~1400 calls.  Setting the
value to N reserves N/1000 times 768KB of stack space.

Note that there are other factors that also limit the stack size.
The operating system typically sets a maximum which can be changed
manually (e.g. with "ulimit" on Linux) for the main thread.  For other
threads you can configure the limit by calling "threading.stack_size()".
"""
    from rpython.rlib.rstack import _stack_set_length_fraction
    from rpython.rlib.rstackovf import StackOverflow
    from rpython.rlib.rgc import increase_root_stack_depth
    if new_limit <= 0:
        raise oefmt(space.w_ValueError, "recursion limit must be positive")
    # Some programs use very large values to mean "don't check, I want to
    # use as much as possible and then segfault".  Add a silent upper bound
    # of 10**6 here, because huge values cause huge shadowstacks to be
    # allocated (or MemoryErrors).
    if new_limit > 1000000:
        new_limit = 1000000
    try:
        _stack_set_length_fraction(new_limit * 0.001)
        _stack_check_noinline()
    except StackOverflow:
        old_limit = space.sys.recursionlimit
        _stack_set_length_fraction(old_limit * 0.001)
        raise oefmt(space.w_RecursionError,
                "cannot set the recursion limit to %s at the recursion depth: the limit is too low")
    space.sys.recursionlimit = new_limit
    increase_root_stack_depth(int(new_limit * 0.001 * 163840))

def getrecursionlimit(space):
    """Return the last value set by setrecursionlimit().
    """
    return space.newint(space.sys.recursionlimit)

@unwrap_spec(interval=int)
def setcheckinterval(space, interval):
    """Tell the Python interpreter to check for asynchronous events every
    n instructions.  This also affects how often thread switches occur."""
    space.actionflag.setcheckinterval(interval)

def getcheckinterval(space):
    """Return the current check interval; see setcheckinterval()."""
    # xxx to make tests and possibly some obscure apps happy, if the
    # checkinterval is set to the minimum possible value (which is 1) we
    # return 0.  The idea is that according to the CPython docs, <= 0
    # means "check every virtual instruction, maximizing responsiveness
    # as well as overhead".
    result = space.actionflag.getcheckinterval()
    if result <= 1:
        result = 0
    return space.newint(result)

@unwrap_spec(interval=float)
def setswitchinterval(space, interval):
    """For CPython compatibility, this maps to
    sys.setcheckinterval(interval * 2000000)
    """
    # The scaling factor is chosen so that with the default
    # checkinterval value of 10000, it corresponds to 0.005, which is
    # the default value of the switchinterval in CPython 3.5
    if interval <= 0.0:
        raise oefmt(space.w_ValueError,
                    "switch interval must be strictly positive")
    space.actionflag.setcheckinterval(int(interval * 2000000.0))

def getswitchinterval(space):
    """For CPython compatibility, this maps to
    sys.getcheckinterval() / 2000000
    """
    return space.newfloat(space.actionflag.getcheckinterval() / 2000000.0)

def exc_info(space):
    """Return the (type, value, traceback) of the most recent exception
caught by an except clause in the current stack frame or in an older stack
frame."""
    return exc_info_with_tb(space)    # indirection for the tests

def exc_info_with_tb(space):
    operror = space.getexecutioncontext().sys_exc_info()
    if operror is None:
        return space.newtuple([space.w_None, space.w_None, space.w_None])
    else:
        return space.newtuple([operror.w_type, operror.get_w_value(space),
                               operror.get_w_traceback(space)])

def exc_info_without_tb(space, operror):
    return space.newtuple([operror.w_type, operror.get_w_value(space),
                           space.w_None])

def exc_info_direct(space, frame):
    from pypy.tool import stdlib_opcode
    # In order to make the JIT happy, we try to return (exc, val, None)
    # instead of (exc, val, tb).  We can do that only if we recognize
    # the following pattern in the bytecode:
    #       CALL_FUNCTION/CALL_METHOD         <-- invoking me
    #       LOAD_CONST 0, 1, -2 or -3
    #       BINARY_SUBSCR
    # or:
    #       CALL_FUNCTION/CALL_METHOD
    #       LOAD_CONST any integer or None
    #       LOAD_CONST <=2
    #       BUILD_SLICE 2
    #       BINARY_SUBSCR
    need_all_three_args = True
    co = frame.getcode().co_code
    p = frame.last_instr
    if (ord(co[p]) == stdlib_opcode.CALL_FUNCTION or
        ord(co[p]) == stdlib_opcode.CALL_METHOD):
        if ord(co[p + 2]) == stdlib_opcode.LOAD_CONST:
            lo = ord(co[p + 3])
            w_constant = frame.getconstant_w(lo)
            if ord(co[p + 4]) == stdlib_opcode.BINARY_SUBSCR:
                if space.isinstance_w(w_constant, space.w_int):
                    constant = space.int_w(w_constant)
                    if -3 <= constant <= 1 and constant != -1:
                        need_all_three_args = False
            elif (ord(co[p + 4]) == stdlib_opcode.LOAD_CONST and
                  ord(co[p + 6]) == stdlib_opcode.BUILD_SLICE and
                  ord(co[p + 8]) == stdlib_opcode.BINARY_SUBSCR):
                if (space.is_w(w_constant, space.w_None) or
                    space.isinstance_w(w_constant, space.w_int)):
                    lo = ord(co[p + 5])
                    w_constant = frame.getconstant_w(lo)
                    if space.isinstance_w(w_constant, space.w_int):
                        if space.int_w(w_constant) <= 2:
                            need_all_three_args = False
    #
    operror = space.getexecutioncontext().sys_exc_info()
    if need_all_three_args or operror is None or frame.hide():
        return exc_info_with_tb(space)
    else:
        return exc_info_without_tb(space, operror)

def settrace(space, w_func):
    """Set the global debug tracing function.  It will be called on each
function call.  See the debugger chapter in the library manual."""
    space.getexecutioncontext().settrace(w_func)

def gettrace(space):
    """Return the global debug tracing function set with sys.settrace.
See the debugger chapter in the library manual."""
    return space.getexecutioncontext().gettrace()

def setprofile(space, w_func):
    """Set the profiling function.  It will be called on each function call
and return.  See the profiler chapter in the library manual."""
    space.getexecutioncontext().setprofile(w_func)

def getprofile(space):
    """Return the profiling function set with sys.setprofile.
See the profiler chapter in the library manual."""
    w_func = space.getexecutioncontext().getprofile()
    if w_func is not None:
        return w_func
    else:
        return space.w_None

def call_tracing(space, w_func, w_args):
    """Call func(*args), while tracing is enabled.  The tracing state is
saved, and restored afterwards.  This is intended to be called from
a debugger from a checkpoint, to recursively debug some other code."""
    return space.getexecutioncontext().call_tracing(w_func, w_args)


app = gateway.applevel('''
"NOT_RPYTHON"
from _structseq import structseqtype, structseqfield

class windows_version_info(metaclass=structseqtype):

    name = "sys.getwindowsversion"

    major = structseqfield(0, "Major version number")
    minor = structseqfield(1, "Minor version number")
    build = structseqfield(2, "Build number")
    platform = structseqfield(3, "Operating system platform")
    service_pack = structseqfield(4, "Latest Service Pack installed on the system")

    # Because the indices aren't consecutive, they aren't included when
    # unpacking and other such operations.
    service_pack_major = structseqfield(10, "Service Pack major version number")
    service_pack_minor = structseqfield(11, "Service Pack minor version number")
    suite_mask = structseqfield(12, "Bit mask identifying available product suites")
    product_type = structseqfield(13, "System product type")
    platform_version = structseqfield(14, "Diagnostic version number")


class asyncgen_hooks(metaclass=structseqtype):
    name = "asyncgen_hooks"

    firstiter = structseqfield(0)
    finalizer = structseqfield(1)

''')


def getwindowsversion(space):
    from rpython.rlib import rwin32
    info = rwin32.GetVersionEx()
    w_windows_version_info = app.wget(space, "windows_version_info")
    raw_version = space.newtuple([
        space.newint(info[0]),
        space.newint(info[1]),
        space.newint(info[2]),
        space.newint(info[3]),
        space.newtext(info[4]),
        space.newint(info[5]),
        space.newint(info[6]),
        space.newint(info[7]),
        space.newint(info[8]),
        # leave _platform_version empty, platform.py will use the main
        # version numbers above.
        space.w_None,
    ])
    return space.call_function(w_windows_version_info, raw_version)

@jit.dont_look_inside
def get_dllhandle(space):
    if not space.config.objspace.usemodules.cpyext:
        return space.newint(0)

    return _get_dllhandle(space)

def _get_dllhandle(space):
    # Retrieve cpyext api handle
    from pypy.module.cpyext.api import State
    handle = space.fromcache(State).get_pythonapi_handle()

    # It used to be a CDLL
    # from pypy.module._rawffi.interp_rawffi import W_CDLL
    # from rpython.rlib.clibffi import RawCDLL
    # cdll = RawCDLL(handle)
    # return W_CDLL(space, "python api", cdll)
    # Provide a cpython-compatible int
    from rpython.rtyper.lltypesystem import lltype, rffi
    return space.newint(rffi.cast(lltype.Signed, handle))

getsizeof_missing = """getsizeof(...)
    getsizeof(object, default) -> int

    Return the size of object in bytes.

sys.getsizeof(object, default) will always return default on PyPy, and
raise a TypeError if default is not provided.

First note that the CPython documentation says that this function may
raise a TypeError, so if you are seeing it, it means that the program
you are using is not correctly handling this case.

On PyPy, though, it always raises TypeError.  Before looking for
alternatives, please take a moment to read the following explanation as
to why it is the case.  What you are looking for may not be possible.

A memory profiler using this function is most likely to give results
inconsistent with reality on PyPy.  It would be possible to have
sys.getsizeof() return a number (with enough work), but that may or
may not represent how much memory the object uses.  It doesn't even
make really sense to ask how much *one* object uses, in isolation
with the rest of the system.  For example, instances have maps,
which are often shared across many instances; in this case the maps
would probably be ignored by an implementation of sys.getsizeof(),
but their overhead is important in some cases if they are many
instances with unique maps.  Conversely, equal strings may share
their internal string data even if they are different objects---or
empty containers may share parts of their internals as long as they
are empty.  Even stranger, some lists create objects as you read
them; if you try to estimate the size in memory of range(10**6) as
the sum of all items' size, that operation will by itself create one
million integer objects that never existed in the first place.
"""

def getsizeof(space, w_object, w_default=None):
    if w_default is None:
        raise oefmt(space.w_TypeError, getsizeof_missing)
    return w_default

getsizeof.__doc__ = getsizeof_missing

def intern(space, w_str):
    """``Intern'' the given string.  This enters the string in the (global)
table of interned strings whose purpose is to speed up dictionary lookups.
Return the string itself or the previously interned string object with the
same value."""
    if space.is_w(space.type(w_str), space.w_unicode):
        return space.new_interned_w_str(w_str)
    raise oefmt(space.w_TypeError, "intern() argument must be string.")

def get_asyncgen_hooks(space):
    """get_asyncgen_hooks()

Return a namedtuple of installed asynchronous generators hooks (firstiter, finalizer)."""
    ec = space.getexecutioncontext()
    w_firstiter = ec.w_asyncgen_firstiter_fn
    if w_firstiter is None:
        w_firstiter = space.w_None
    w_finalizer = ec.w_asyncgen_finalizer_fn
    if w_finalizer is None:
        w_finalizer = space.w_None
    w_asyncgen_hooks = app.wget(space, "asyncgen_hooks")
    return space.call_function(
        w_asyncgen_hooks,
        space.newtuple([w_firstiter, w_finalizer]))

# Note: the docstring is wrong on CPython
def set_asyncgen_hooks(space, w_firstiter=None, w_finalizer=None):
    """set_asyncgen_hooks(firstiter=None, finalizer=None)

Set a finalizer for async generators objects."""
    ec = space.getexecutioncontext()
    if space.is_w(w_finalizer, space.w_None):
        ec.w_asyncgen_finalizer_fn = None
    elif w_finalizer is not None:
        if space.callable_w(w_finalizer):
            ec.w_asyncgen_finalizer_fn = w_finalizer
        else:
            raise oefmt(space.w_TypeError,
                "callable finalizer expected, got %T", w_finalizer)
    if space.is_w(w_firstiter, space.w_None):
        ec.w_asyncgen_firstiter_fn = None
    elif w_firstiter is not None:
        if space.callable_w(w_firstiter):
            ec.w_asyncgen_firstiter_fn = w_firstiter
        else:
            raise oefmt(space.w_TypeError,
                "callable firstiter expected, got %T", w_firstiter)


def is_finalizing(space):
    return space.newbool(space.sys.finalizing)

def get_coroutine_origin_tracking_depth(space):
    """get_coroutine_origin_tracking_depth()
        Check status of origin tracking for coroutine objects in this thread.
    """
    ec = space.getexecutioncontext()
    return space.newint(ec.coroutine_origin_tracking_depth)

@unwrap_spec(depth=int)
def set_coroutine_origin_tracking_depth(space, depth):
    """set_coroutine_origin_tracking_depth(depth)
        Enable or disable origin tracking for coroutine objects in this thread.

        Coroutine objects will track 'depth' frames of traceback information
        about where they came from, available in their cr_origin attribute.

        Set a depth of 0 to disable.
    """
    if depth < 0:
        raise oefmt(space.w_ValueError,
                "depth must be >= 0")
    ec = space.getexecutioncontext()
    ec.coroutine_origin_tracking_depth = depth


class AuditHolder(object):
    _immutable_fields_ = ['hooks_w?[:]']

    def __init__(self, space):
        self.hooks_w = None
        self.space = space

    @objectmodel.dont_inline
    @jit.unroll_safe
    def trigger_audit_events(self, space, event, args_w):
        w_event = space.newtext(event)
        w_args = space.newtuple(args_w)
        hooks_w = self.hooks_w
        assert hooks_w is not None
        ec = space.getexecutioncontext()
        # don't trace audithooks by default
        ec.is_tracing += 1
        try:
            for w_hook in hooks_w:
                w_cantrace = space.findattr(w_hook, space.newtext("__cantrace__"))
                if w_cantrace is None:
                    cantrace = False
                else:
                    cantrace = space.is_true(w_cantrace)
                if cantrace:
                    ec.is_tracing -= 1
                try:
                    space.call_function(w_hook, w_event, w_args)
                finally:
                    if cantrace:
                        ec.is_tracing += 1
        finally:
            ec.is_tracing -= 1


@unwrap_spec(event="text")
def audit(space, event, args_w):
    """
    audit(event, *args)
    
    Passes the event to any audit hooks that are attached.
    """
    holder = space.fromcache(AuditHolder)
    if holder.hooks_w is None:
        return
    holder.trigger_audit_events(space, event, args_w)


def addaudithook(space, w_hook):
    """
    addaudithook(hook)

    Adds a new audit hook callback.
    """
    holder = space.fromcache(AuditHolder)
    try:
        audit(space, "sys.addaudithook", [])
    except OperationError, e:
        if not e.match(space, space.w_RuntimeError):
            raise
        # RuntimeError is ignored and we don't add the new hook
        return
    if holder.hooks_w is None:
        holder.hooks_w = [w_hook]
        debug.make_sure_not_resized(holder.hooks_w)
    else:
        holder.hooks_w = holder.hooks_w + [w_hook]



def unraisablehook(space, w_hookargs):
    w_type = space.getattr(w_hookargs, space.newtext("exc_type"))
    w_value = space.getattr(w_hookargs, space.newtext("exc_value"))
    w_tb = space.getattr(w_hookargs, space.newtext("exc_traceback"))
    err_msg = space.text_w(space.getattr(w_hookargs, space.newtext("err_msg")))
    w_object = space.getattr(w_hookargs, space.newtext("object"))
    extra_line = space.text_w(space.getattr(w_hookargs, space.newtext("extra_line")))
    OperationError.write_unraisable_default(space, w_type, w_value, w_tb, err_msg, w_object, extra_line)



