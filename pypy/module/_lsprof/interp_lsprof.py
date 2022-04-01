import py

from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.function import BuiltinFunction, Method, Function
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import (TypeDef, GetSetProperty,
                                      interp_attrproperty)
from rpython.rlib import jit
from rpython.rlib.objectmodel import we_are_translated, always_inline
from rpython.rlib.rtimer import read_timestamp, _is_64_bit
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator import cdir
from rpython.rlib.rarithmetic import r_longlong

import time, sys

# cpu affinity settings

srcdir = py.path.local(cdir).join('src')
eci = ExternalCompilationInfo(
    include_dirs          = [cdir],
    separate_module_files = [srcdir.join('profiling.c')])

c_setup_profiling = rffi.llexternal('pypy_setup_profiling',
                                  [], lltype.Void,
                                  compilation_info = eci)
c_teardown_profiling = rffi.llexternal('pypy_teardown_profiling',
                                       [], lltype.Void,
                                       compilation_info = eci)

if _is_64_bit:
    timer_size_int = int
else:
    timer_size_int = r_longlong

class W_StatsEntry(W_Root):
    def __init__(self, space, frame, callcount, reccallcount, tt, it,
                 w_sublist):
        self.frame = frame
        self.callcount = callcount
        self.reccallcount = reccallcount
        self.it = it
        self.tt = tt
        self.w_calls = w_sublist

    def get_calls(self, space):
        return self.w_calls

    def repr(self, space):
        frame_repr = space.text_w(space.repr(self.frame))
        if not self.w_calls:
            calls_repr = "None"
        else:
            calls_repr = space.text_w(space.repr(self.w_calls))
        return space.newtext('("%s", %d, %d, %f, %f, %s)' % (
            frame_repr, self.callcount, self.reccallcount,
            self.tt, self.it, calls_repr))

    def get_code(self, space):
        return returns_code(space, self.frame)

W_StatsEntry.typedef = TypeDef(
    '_lsprof.StatsEntry',
    code = GetSetProperty(W_StatsEntry.get_code),
    callcount = interp_attrproperty('callcount', W_StatsEntry,
        wrapfn="newint"),
    reccallcount = interp_attrproperty('reccallcount', W_StatsEntry,
        wrapfn="newint"),
    inlinetime = interp_attrproperty('it', W_StatsEntry,
        wrapfn="newfloat"),
    totaltime = interp_attrproperty('tt', W_StatsEntry,
        wrapfn="newfloat"),
    calls = GetSetProperty(W_StatsEntry.get_calls),
    __repr__ = interp2app(W_StatsEntry.repr),
)

class W_StatsSubEntry(W_Root):
    def __init__(self, space, frame, callcount, reccallcount, tt, it):
        self.frame = frame
        self.callcount = callcount
        self.reccallcount = reccallcount
        self.it = it
        self.tt = tt

    def repr(self, space):
        frame_repr = space.text_w(space.repr(self.frame))
        return space.newtext('("%s", %d, %d, %f, %f)' % (
            frame_repr, self.callcount, self.reccallcount, self.tt, self.it))

    def get_code(self, space):
        return returns_code(space, self.frame)

W_StatsSubEntry.typedef = TypeDef(
    '_lsprof.SubStatsEntry',
    code = GetSetProperty(W_StatsSubEntry.get_code),
    callcount = interp_attrproperty('callcount', W_StatsSubEntry,
        wrapfn="newint"),
    reccallcount = interp_attrproperty('reccallcount', W_StatsSubEntry,
        wrapfn="newint"),
    inlinetime = interp_attrproperty('it', W_StatsSubEntry,
        wrapfn="newfloat"),
    totaltime = interp_attrproperty('tt', W_StatsSubEntry,
        wrapfn="newfloat"),
    __repr__ = interp2app(W_StatsSubEntry.repr),
)

def stats(space, values, factor):
    l_w = []
    for v in values:
        if v.callcount != 0:
            l_w.append(v.stats(space, None, factor))
    return space.newlist(l_w)

class ProfilerSubEntry(object):
    def __init__(self, frame):
        self.frame = frame
        self.ll_tt = r_longlong(0)
        self.ll_it = r_longlong(0)
        self.callcount = 0
        self.recursivecallcount = 0
        self.recursionLevel = 0

    def stats(self, space, parent, factor):
        w_sse = W_StatsSubEntry(space, self.frame,
                                self.callcount, self.recursivecallcount,
                                factor * float(self.ll_tt),
                                factor * float(self.ll_it))
        return w_sse

    def _stop(self, tt, it):
        if not we_are_translated():
            assert type(tt) is timer_size_int
            assert type(it) is timer_size_int
        self.recursionLevel -= 1
        if self.recursionLevel == 0:
            self.ll_tt += tt
        else:
            self.recursivecallcount += 1
        self.ll_it += it
        self.callcount += 1

class ProfilerEntry(ProfilerSubEntry):
    def __init__(self, frame):
        ProfilerSubEntry.__init__(self, frame)
        self.calls = {}

    def stats(self, space, dummy, factor):
        if self.calls:
            w_sublist = space.newlist([sub_entry.stats(space, self, factor)
                                       for sub_entry in self.calls.values()])
        else:
            w_sublist = space.w_None
        w_se = W_StatsEntry(space, self.frame, self.callcount,
                            self.recursivecallcount,
                            factor * float(self.ll_tt),
                            factor * float(self.ll_it), w_sublist)
        return w_se

    @jit.elidable
    def _get_or_make_subentry(self, entry, make=True):
        try:
            return self.calls[entry]
        except KeyError:
            if make:
                subentry = ProfilerSubEntry(entry.frame)
                self.calls[entry] = subentry
                return subentry
            raise

class ProfilerContext(object):
    def __init__(self, profobj, entry):
        self.entry = entry
        self.ll_subt = timer_size_int(0)
        self.previous = profobj.current_context
        entry.recursionLevel += 1
        if profobj.subcalls and self.previous:
            caller = jit.promote(self.previous.entry)
            subentry = caller._get_or_make_subentry(entry)
            subentry.recursionLevel += 1
        self.ll_t0 = profobj.ll_timer()

    def _stop(self, profobj, entry):
        tt = profobj.ll_timer() - self.ll_t0
        it = tt - self.ll_subt
        if self.previous:
            self.previous.ll_subt += tt
        entry._stop(tt, it)
        if profobj.subcalls and self.previous:
            caller = jit.promote(self.previous.entry)
            try:
                subentry = caller._get_or_make_subentry(entry, False)
            except KeyError:
                pass
            else:
                subentry._stop(tt, it)


def create_spec_for_method(space, w_function, w_type):
    class_name = None
    if isinstance(w_function, Function):
        name = w_function.name
        # try to get the real class that defines the method,
        # which is a superclass of the class of the instance
        from pypy.objspace.std.typeobject import W_TypeObject   # xxx
        if isinstance(w_type, W_TypeObject):
            w_realclass, _ = space.lookup_in_type_where(w_type, name)
            if isinstance(w_realclass, W_TypeObject):
                class_name = w_realclass.name
    else:
        name = '?'
    if class_name is None:
        class_name = w_type.getname(space)    # if the rest doesn't work
    return b"<method '%s' of '%s' objects>" % (name, class_name)


def create_spec_for_function(space, w_func):
    assert isinstance(w_func, Function)
    pre = b'built-in function ' if isinstance(w_func, BuiltinFunction) else b''
    if w_func.w_module is not None:
        module = space.utf8_w(w_func.w_module)
        if module != b'builtins':
            return b'<%s%s.%s>' % (pre, module, w_func.getname(space))
    return b'<%s%s>' % (pre, w_func.getname(space))


def create_spec_for_object(space, w_type):
    class_name = w_type.getname(space)
    return b"<'%s' object>" % (class_name,)


class W_DelayedBuiltinStr(W_Root):
    # This class should not be seen at app-level, but is useful to
    # contain a (w_func, w_type) pair returned by prepare_spec().
    # Turning this pair into a string cannot be done eagerly in
    # an @elidable function because of space.text_w(), but it can
    # be done lazily when we really want it.

    _immutable_fields_ = ['w_func', 'w_type']

    def __init__(self, w_func, w_type):
        self.w_func = w_func
        self.w_type = w_type
        self.w_string = None

    def wrap_string(self, space):
        if self.w_string is None:
            if self.w_type is None:
                s = create_spec_for_function(space, self.w_func)
            elif self.w_func is None:
                s = create_spec_for_object(space, self.w_type)
            else:
                s = create_spec_for_method(space, self.w_func, self.w_type)
            self.w_string = space.newtext(s)
        return self.w_string

W_DelayedBuiltinStr.typedef = TypeDef(
    'DelayedBuiltinStr',
    __str__ = interp2app(W_DelayedBuiltinStr.wrap_string),
)

def returns_code(space, w_frame):
    if isinstance(w_frame, W_DelayedBuiltinStr):
        return w_frame.wrap_string(space)
    return w_frame    # actually a PyCode object

@always_inline
def prepare_spec(space, w_arg):
    if isinstance(w_arg, Method):
        return (w_arg.w_function, space.type(w_arg.w_instance))
    elif isinstance(w_arg, Function):
        return (w_arg, None)
    else:
        return (None, space.type(w_arg))

def lsprof_call(space, w_self, frame, event, w_arg):
    assert isinstance(w_self, W_Profiler)
    if event == 'call':
        code = frame.getcode()
        w_self._enter_call(code)
    elif event == 'return':
        code = frame.getcode()
        w_self._enter_return(code)
    elif event == 'c_call':
        if w_self.builtins:
            w_self._enter_builtin_call(w_arg)
    elif event == 'c_return' or event == 'c_exception':
        if w_self.builtins:
            w_self._enter_builtin_return(w_arg)
    else:
        # ignore or raise an exception???
        pass


class W_Profiler(W_Root):
    def __init__(self, space, w_callable, time_unit, subcalls, builtins):
        self.subcalls = subcalls
        self.builtins = builtins
        self.current_context = None
        self.w_callable = w_callable
        self.time_unit = time_unit
        self.data = {}
        self.builtin_data = {}
        self.space = space
        self.is_enabled = False
        self.total_timestamp = r_longlong(0)
        self.total_real_time = 0.0

    def ll_timer(self):
        if self.w_callable:
            space = self.space
            try:
                if _is_64_bit:
                    return space.int_w(space.call_function(self.w_callable))
                else:
                    return space.r_longlong_w(space.call_function(self.w_callable))
            except OperationError as e:
                e.write_unraisable(space, "timer function ",
                                   self.w_callable)
                return timer_size_int(0)
        return read_timestamp()

    def enable(self, space, w_subcalls=None,
               w_builtins=None):
        if self.is_enabled:
            return      # ignored
        if w_subcalls is not None:
            self.subcalls = space.bool_w(w_subcalls)
        if w_builtins is not None:
            self.builtins = space.bool_w(w_builtins)
        # We want total_real_time and total_timestamp to end up containing
        # (endtime - starttime).  Now we are at the start, so we first
        # have to subtract the current time.
        self.is_enabled = True
        self.total_real_time -= time.time()
        self.total_timestamp -= read_timestamp()
        # set profiler hook
        c_setup_profiling()
        space.getexecutioncontext().setllprofile(lsprof_call, self)

    @jit.elidable
    def _get_or_make_entry(self, f_code, make=True):
        try:
            return self.data[f_code]
        except KeyError:
            if make:
                entry = ProfilerEntry(f_code)
                self.data[f_code] = entry
                return entry
            raise

    @jit.elidable_promote()
    def _get_or_make_builtin_entry(self, w_func, w_type, make):
        key = (w_func, w_type)
        try:
            return self.builtin_data[key]
        except KeyError:
            if make:
                entry = ProfilerEntry(W_DelayedBuiltinStr(w_func, w_type))
                self.builtin_data[key] = entry
                return entry
            raise

    def _enter_call(self, f_code):
        # we have a superb gc, no point in freelist :)
        self = jit.promote(self)
        entry = self._get_or_make_entry(f_code)
        self.current_context = ProfilerContext(self, entry)

    def _enter_return(self, f_code):
        context = self.current_context
        if context is None:
            return
        self = jit.promote(self)
        try:
            entry = self._get_or_make_entry(f_code, False)
        except KeyError:
            pass
        else:
            context._stop(self, entry)
        self.current_context = context.previous

    def _enter_builtin_call(self, w_arg):
        w_func, w_type = prepare_spec(self.space, w_arg)
        entry = self._get_or_make_builtin_entry(w_func, w_type, True)
        self.current_context = ProfilerContext(self, entry)

    def _enter_builtin_return(self, w_arg):
        context = self.current_context
        if context is None:
            return
        w_func, w_type = prepare_spec(self.space, w_arg)
        try:
            entry = self._get_or_make_builtin_entry(w_func, w_type, False)
        except KeyError:
            pass
        else:
            context._stop(self, entry)
        self.current_context = context.previous

    def _flush_unmatched(self):
        context = self.current_context
        while context:
            entry = context.entry
            if entry:
                context._stop(self, entry)
            context = context.previous
        self.current_context = None

    def disable(self, space):
        if not self.is_enabled:
            return      # ignored
        # We want total_real_time and total_timestamp to end up containing
        # (endtime - starttime), or the sum of such intervals if
        # enable() and disable() are called several times.
        self.is_enabled = False
        self.total_timestamp += read_timestamp()
        self.total_real_time += time.time()
        # unset profiler hook
        space.getexecutioncontext().setllprofile(None, None)
        c_teardown_profiling()
        self._flush_unmatched()

    def getstats(self, space):
        if self.w_callable is None:
            if self.is_enabled:
                raise oefmt(space.w_RuntimeError,
                            "Profiler instance must be disabled before "
                            "getting the stats")
            if self.total_timestamp:
                factor = self.total_real_time / float(self.total_timestamp)
            else:
                factor = 1.0     # probably not used
        elif self.time_unit > 0.0:
            factor = self.time_unit
        else:
            factor = 1.0 / sys.maxint
        return stats(space, self.data.values() + self.builtin_data.values(),
                     factor)

@unwrap_spec(time_unit=float, subcalls=int, builtins=int)
def descr_new_profile(space, w_type, w_callable=None, time_unit=0.0,
                      subcalls=1, builtins=1):
    p = space.allocate_instance(W_Profiler, w_type)
    p.__init__(space, w_callable, time_unit, bool(subcalls), bool(builtins))
    return p

W_Profiler.typedef = TypeDef(
    '_lsprof.Profiler',
    __new__ = interp2app(descr_new_profile),
    enable = interp2app(W_Profiler.enable),
    disable = interp2app(W_Profiler.disable),
    getstats = interp2app(W_Profiler.getstats),
)
