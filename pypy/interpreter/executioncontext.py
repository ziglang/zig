import sys
from pypy.interpreter.error import OperationError, get_cleared_operation_error
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.objectmodel import specialize, not_rpython
from rpython.rlib import jit, rgc, objectmodel

TICK_COUNTER_STEP = 100

def app_profile_call(space, w_callable, frame, event, w_arg):
    space.call_function(w_callable,
                        frame,
                        space.newtext(event), w_arg)

class ExecutionContext(object):
    """An ExecutionContext holds the state of an execution thread
    in the Python interpreter."""

    # XXX JIT: when tracing (but not when blackholing!), the following
    # XXX fields should be known to a constant None or False:
    # XXX   self.w_tracefunc, self.profilefunc
    # XXX   frame.is_being_profiled

    # XXX [fijal] but they're not. is_being_profiled is guarded a bit all
    #     over the place as well as w_tracefunc

    _immutable_fields_ = [
        'profilefunc?', 'w_tracefunc?',
        'w_asyncgen_firstiter_fn?', 'w_asyncgen_finalizer_fn?']

    def __init__(self, space):
        self.space = space
        self.topframeref = jit.vref_None
        # this is exposed to app-level as 'sys.exc_info()'.  At any point in
        # time it is the exception caught by the topmost 'except ... as e:'
        # app-level block.
        self.sys_exc_operror = None
        self.w_tracefunc = None
        self.is_tracing = 0
        self.compiler = space.createcompiler()
        self.profilefunc = None
        self.w_profilefuncarg = None
        self.thread_disappeared = False   # might be set to True after os.fork()
        self.w_asyncgen_firstiter_fn = None
        self.w_asyncgen_finalizer_fn = None
        self.contextvar_context = None
        self.coroutine_origin_tracking_depth = 0

    @staticmethod
    def _mark_thread_disappeared(space):
        # Called in the child process after os.fork() by interp_posix.py.
        # Marks all ExecutionContexts except the current one
        # with 'thread_disappeared = True'.
        me = space.getexecutioncontext()
        for ec in space.threadlocals.getallvalues().values():
            if ec is not me:
                ec.thread_disappeared = True

    def gettopframe(self):
        return self.topframeref()

    @jit.unroll_safe
    def gettopframe_nohidden(self):
        frame = self.topframeref()
        while frame and frame.hide():
            frame = frame.f_backref()
        return frame

    @staticmethod
    @jit.unroll_safe  # should usually loop 0 times, very rarely more than once
    def getnextframe_nohidden(frame):
        frame = frame.f_backref()
        while frame and frame.hide():
            frame = frame.f_backref()
        return frame

    def enter(self, frame):
        if self.space.reverse_debugging:
            self._revdb_enter(frame)
        frame.f_backref = self.topframeref
        self.topframeref = jit.virtual_ref(frame)

    def leave(self, frame, w_exitvalue, got_exception):
        try:
            if self.profilefunc:
                self._trace(frame, 'leaveframe', w_exitvalue)
        finally:
            frame_vref = self.topframeref
            self.topframeref = frame.f_backref
            if frame.escaped or got_exception:
                # if this frame escaped to applevel, we must ensure that also
                # f_back does
                f_back = frame.f_backref()
                if f_back:
                    f_back.mark_as_escaped()
                # force the frame (from the JIT point of view), so that it can
                # be accessed also later
                frame_vref()
            jit.virtual_ref_finish(frame_vref, frame)
            if self.space.reverse_debugging:
                self._revdb_leave(got_exception)

    # ________________________________________________________________

    def c_call_trace(self, frame, w_func, args=None):
        "Profile the call of a builtin function"
        self._c_call_return_trace(frame, w_func, args, 'c_call')

    def c_return_trace(self, frame, w_func, args=None):
        "Profile the return from a builtin function"
        self._c_call_return_trace(frame, w_func, args, 'c_return')

    def _c_call_return_trace(self, frame, w_func, args, event):
        if self.profilefunc is None:
            frame.getorcreatedebug().is_being_profiled = False
        else:
            # undo the effect of the CALL_METHOD bytecode, which would be
            # that even on a built-in method call like '[].append()',
            # w_func is actually the unbound function 'append'.
            from pypy.interpreter.function import FunctionWithFixedCode
            if isinstance(w_func, FunctionWithFixedCode) and args is not None:
                w_firstarg = args.firstarg()
                if w_firstarg is not None:
                    from pypy.interpreter.function import descr_function_get
                    w_func = descr_function_get(self.space, w_func, w_firstarg,
                                                self.space.type(w_firstarg))
            #
            self._trace(frame, event, w_func)

    def c_exception_trace(self, frame, w_exc):
        "Profile function called upon OperationError."
        if self.profilefunc is None:
            frame.getorcreatedebug().is_being_profiled = False
        else:
            self._trace(frame, 'c_exception', w_exc)

    def call_trace(self, frame):
        "Trace the call of a function"
        if self.gettrace() is not None or self.profilefunc is not None:
            self._trace(frame, 'call', self.space.w_None)
            if self.profilefunc:
                frame.getorcreatedebug().is_being_profiled = True

    def return_trace(self, frame, w_retval):
        "Trace the return from a function"
        if self.gettrace() is not None:
            self._trace(frame, 'return', w_retval)

    @objectmodel.always_inline
    def bytecode_trace(self, frame, decr_by=TICK_COUNTER_STEP):
        "Trace function called before each bytecode."
        # this is split into a fast path and a slower path that is
        # not invoked every time bytecode_trace() is.
        self.bytecode_only_trace(frame)
        actionflag = self.space.actionflag
        if actionflag.decrement_ticker(decr_by) < 0:
            actionflag.action_dispatcher(self, frame)     # slow path

    def _run_finalizers_now(self):
        # Tests only: run the actions now, to ensure that the
        # finalizable objects are really finalized.  Used notably by
        # pypy.tool.pytest.apptest.
        self.space.actionflag.action_dispatcher(self, None)

    @objectmodel.always_inline
    def bytecode_only_trace(self, frame):
        """
        Like bytecode_trace() but doesn't invoke any other events besides the
        trace function.
        """
        if self.space.reverse_debugging:
            self._revdb_potential_stop_point(frame)
        if (frame.get_w_f_trace() is None or self.is_tracing or
            self.gettrace() is None):
            return
        self.run_trace_func(frame)

    @jit.unroll_safe
    def run_trace_func(self, frame):
        code = frame.pycode
        d = frame.getorcreatedebug()
        line = d.f_lineno
        if not (d.instr_lb <= frame.last_instr < d.instr_ub):
            size = len(code.co_lnotab) / 2
            addr = 0
            line = code.co_firstlineno
            p = 0
            lineno = code.co_lnotab
            while size > 0:
                c = ord(lineno[p])
                if (addr + c) > frame.last_instr:
                    break
                addr += c
                if c:
                    d.instr_lb = addr
                line_offset = ord(lineno[p + 1])
                if line_offset >= 0x80:
                    line_offset -= 0x100
                line += line_offset
                p += 2
                size -= 1

            if size > 0:
                while True:
                    size -= 1
                    if size < 0:
                        break
                    addr += ord(lineno[p])
                    if ord(lineno[p + 1]):
                        break
                    p += 2
                d.instr_ub = addr
            else:
                d.instr_ub = sys.maxint

        # when we are at a start of a line, or executing a backwards jump,
        # produce a line event
        if d.instr_lb == frame.last_instr or frame.last_instr < d.instr_prev_plus_one:
            d.f_lineno = line
            if d.f_trace_lines:
                self._trace(frame, 'line', self.space.w_None)
        if d.f_trace_opcodes:
            self._trace(frame, 'opcode', self.space.w_None)

        d.instr_prev_plus_one = frame.last_instr + 1

    @objectmodel.try_inline
    def bytecode_trace_after_exception(self, frame):
        "Like bytecode_trace(), but without increasing the ticker."
        actionflag = self.space.actionflag
        self.bytecode_only_trace(frame)
        if actionflag.get_ticker() < 0:
            actionflag.action_dispatcher(self, frame)     # slow path
    # NB. this function is not inlined right now.  backendopt.inline would
    # need some improvements to handle this case, but it's not really an
    # issue

    def exception_trace(self, frame, operationerr):
        "Trace function called upon OperationError."
        if self.gettrace() is not None:
            self._trace(frame, 'exception', None, operationerr)
        #operationerr.print_detailed_traceback(self.space)

    @jit.unroll_safe
    def sys_exc_info(self):
        """Implements sys.exc_info().
        Return an OperationError instance or None.
        Returns the "top-most" exception in the stack.

        # NOTE: the result is not the wrapped sys.exc_info() !!!

        """
        return self.sys_exc_operror

    def set_sys_exc_info(self, operror):
        self.sys_exc_operror = operror

    def set_sys_exc_info3(self, w_type, w_value, w_traceback):
        from pypy.interpreter import pytraceback

        space = self.space
        if space.is_none(w_value):
            operror = None
        else:
            tb = None
            if not space.is_none(w_traceback):
                try:
                    tb = pytraceback.check_traceback(space, w_traceback, '?')
                except OperationError:    # catch and ignore bogus objects
                    pass
            operror = OperationError(w_type, w_value, tb)
        self.set_sys_exc_info(operror)

    @jit.dont_look_inside
    def settrace(self, w_func):
        """Set the global trace function."""
        # self.space.audit("sys.settrace", [])
        if self.space.is_w(w_func, self.space.w_None):
            self.w_tracefunc = None
        else:
            self.force_all_frames()
            self.w_tracefunc = w_func
            # Increase the JIT's trace_limit when we have a tracefunc, it
            # generates a ton of extra ops.
            jit.set_param(None, 'trace_limit', 10000)

    def gettrace(self):
        return jit.promote(self.w_tracefunc)

    def setprofile(self, w_func):
        """Set the global trace function."""
        # self.space.audit("sys.setprofile", [])
        if self.space.is_w(w_func, self.space.w_None):
            self.profilefunc = None
            self.w_profilefuncarg = None
        else:
            self.setllprofile(app_profile_call, w_func)

    def getprofile(self):
        return self.w_profilefuncarg

    def setllprofile(self, func, w_arg):
        if func is not None:
            if w_arg is None:
                raise ValueError("Cannot call setllprofile with real None")
            self.force_all_frames(is_being_profiled=True)
        self.profilefunc = func
        self.w_profilefuncarg = w_arg

    def force_all_frames(self, is_being_profiled=False):
        # "Force" all frames in the sense of the jit, and optionally
        # set the flag 'is_being_profiled' on them.  A forced frame is
        # one out of which the jit will exit: if it is running so far,
        # in a piece of assembler currently running a CALL_MAY_FORCE,
        # then being forced means that it will fail the following
        # GUARD_NOT_FORCED operation, and so fall back to interpreted
        # execution.  (We get this effect simply by reading the f_back
        # field of all frames, during the loop below.)
        frame = self.gettopframe_nohidden()
        while frame:
            if is_being_profiled:
                frame.getorcreatedebug().is_being_profiled = True
            frame = self.getnextframe_nohidden(frame)

    def call_tracing(self, w_func, w_args):
        is_tracing = self.is_tracing
        self.is_tracing = 0
        try:
            return self.space.call(w_func, w_args)
        finally:
            self.is_tracing = is_tracing

    def _trace(self, frame, event, w_arg, operr=None):
        if self.is_tracing or frame.hide():
            return

        space = self.space

        # Tracing cases
        if event == 'call':
            w_callback = self.gettrace()
        else:
            w_callback = frame.get_w_f_trace()

        if w_callback is not None and event != "leaveframe":
            if operr is not None:
                operr.normalize_exception(space)
                w_value = operr.get_w_value(space)
                w_arg = space.newtuple([operr.w_type, w_value,
                                        operr.get_w_traceback(space)])

            d = frame.getorcreatedebug()
            if d.w_locals is not None:
                # only update the w_locals dict if it exists
                # if it does not exist yet and the tracer accesses it via
                # frame.f_locals, it is filled by PyFrame.getdictscope
                frame.fast2locals()
            prev_line_tracing = d.is_in_line_tracing
            self.is_tracing += 1
            try:
                if event == 'line':
                    d.is_in_line_tracing = True
                try:
                    w_result = space.call_function(w_callback, frame, space.newtext(event), w_arg)
                    if space.is_w(w_result, space.w_None):
                        # bug-to-bug compatibility with CPython
                        # http://bugs.python.org/issue11992
                        pass   #d.w_f_trace = None
                    else:
                        d.w_f_trace = w_result
                except:
                    self.settrace(space.w_None)
                    d.w_f_trace = None
                    raise
            finally:
                self.is_tracing -= 1
                d.is_in_line_tracing = prev_line_tracing
                if d.w_locals is not None:
                    frame.locals2fast()

        # Profile cases
        if self.profilefunc is not None:
            if not (event == 'leaveframe' or
                    event == 'call' or
                    event == 'c_call' or
                    event == 'c_return' or
                    event == 'c_exception'):
                return

            if event == 'leaveframe':
                event = 'return'

            assert self.is_tracing == 0
            self.is_tracing += 1
            try:
                try:
                    self.profilefunc(space, self.w_profilefuncarg,
                                     frame, event, w_arg)
                except:
                    self.profilefunc = None
                    self.w_profilefuncarg = None
                    raise

            finally:
                self.is_tracing -= 1

    def checksignals(self):
        """Similar to PyErr_CheckSignals().  If called in the main thread,
        and if signals are pending for the process, deliver them now
        (i.e. call the signal handlers)."""
        if self.space.check_signal_action is not None:
            self.space.check_signal_action.perform(self, None)

    def _revdb_enter(self, frame):
        # moved in its own function for the import statement
        from pypy.interpreter.reverse_debugging import enter_call
        enter_call(self.topframeref(), frame)

    def _revdb_leave(self, got_exception):
        # moved in its own function for the import statement
        from pypy.interpreter.reverse_debugging import leave_call
        leave_call(self.topframeref(), got_exception)

    def _revdb_potential_stop_point(self, frame):
        # moved in its own function for the import statement
        from pypy.interpreter.reverse_debugging import potential_stop_point
        potential_stop_point(frame)

    def _freeze_(self):
        raise Exception("ExecutionContext instances should not be seen during"
                        " translation.  Now is a good time to inspect the"
                        " traceback and see where this one comes from :-)")


class AbstractActionFlag(object):
    """This holds in an integer the 'ticker'.  If threads are enabled,
    it is decremented at each bytecode; when it reaches zero, we release
    the GIL.  And whether we have threads or not, it is forced to zero
    whenever we fire any of the asynchronous actions.
    """

    _immutable_fields_ = ["checkinterval_scaled?"]

    def __init__(self):
        self._periodic_actions = []
        self._nonperiodic_actions = []
        self.has_bytecode_counter = False
        self._fired_actions_reset()
        # the default value is not 100, unlike CPython 2.7, but a much
        # larger value, because we use a technique that not only allows
        # but actually *forces* another thread to run whenever the counter
        # reaches zero.
        self.checkinterval_scaled = 10000 * TICK_COUNTER_STEP
        self._rebuild_action_dispatcher()

    def fire(self, action):
        """Request for the action to be run before the next opcode."""
        if not action._fired:
            action._fired = True
            self._fired_actions_append(action)
            # set the ticker to -1 in order to force action_dispatcher()
            # to run at the next possible bytecode
            self.reset_ticker(-1)

    def _fired_actions_reset(self):
        # linked list of actions. We cannot use a normal RPython list because
        # we want AsyncAction.fire() to be marked as @rgc.collect: this way,
        # we can call it from e.g. GcHooks or cpyext's dealloc_trigger.
        self._fired_actions_first = None
        self._fired_actions_last = None

    @rgc.no_collect
    def _fired_actions_append(self, action):
        assert action._next is None
        if self._fired_actions_first is None:
            self._fired_actions_first = action
            self._fired_actions_last = action
        else:
            self._fired_actions_last._next = action
            self._fired_actions_last = action

    @not_rpython
    def register_periodic_action(self, action, use_bytecode_counter):
        """
        Register the PeriodicAsyncAction action to be called whenever the
        tick counter becomes smaller than 0.  If 'use_bytecode_counter' is
        True, make sure that we decrease the tick counter at every bytecode.
        This is needed for threads.  Note that 'use_bytecode_counter' can be
        False for signal handling, because whenever the process receives a
        signal, the tick counter is set to -1 by C code in signals.h.
        """
        assert isinstance(action, PeriodicAsyncAction)
        # hack to put the release-the-GIL one at the end of the list,
        # and the report-the-signals one at the start of the list.
        if use_bytecode_counter:
            self._periodic_actions.append(action)
            self.has_bytecode_counter = True
        else:
            self._periodic_actions.insert(0, action)
        self._rebuild_action_dispatcher()

    def getcheckinterval(self):
        return self.checkinterval_scaled // TICK_COUNTER_STEP

    def setcheckinterval(self, interval):
        MAX = sys.maxint // TICK_COUNTER_STEP
        if interval < 1:
            interval = 1
        elif interval > MAX:
            interval = MAX
        self.checkinterval_scaled = interval * TICK_COUNTER_STEP
        self.reset_ticker(-1)

    def _rebuild_action_dispatcher(self):
        periodic_actions = unrolling_iterable(self._periodic_actions)

        @jit.unroll_safe
        @objectmodel.dont_inline
        def action_dispatcher(ec, frame):
            # periodic actions (first reset the bytecode counter)
            self.reset_ticker(self.checkinterval_scaled)
            for action in periodic_actions:
                action.perform(ec, frame)

            # nonperiodic actions
            action = self._fired_actions_first
            if action:
                self._fired_actions_reset()
                # NB. in case there are several actions, we reset each
                # 'action._fired' to false only when we're about to call
                # 'action.perform()'.  This means that if
                # 'action.fire()' happens to be called any time before
                # the corresponding perform(), the fire() has no
                # effect---which is the effect we want, because
                # perform() will be called anyway.  All such pending
                # actions with _fired == True are still inside the old
                # chained list.  As soon as we reset _fired to False,
                # we also reset _next to None and we are ready for
                # another fire().
                while action is not None:
                    next_action = action._next
                    action._next = None
                    action._fired = False
                    action.perform(ec, frame)
                    action = next_action

        self.action_dispatcher = action_dispatcher


class ActionFlag(AbstractActionFlag):
    """The normal class for space.actionflag.  The signal module provides
    a different one."""
    _ticker = 0

    def get_ticker(self):
        return self._ticker

    def reset_ticker(self, value):
        self._ticker = value

    def decrement_ticker(self, by):
        value = self._ticker
        if self.has_bytecode_counter:    # this 'if' is constant-folded
            if jit.isconstant(by) and by == 0:
                pass     # normally constant-folded too
            else:
                value -= by
                self._ticker = value
        return value


class AsyncAction(object):
    """Abstract base class for actions that must be performed
    asynchronously with regular bytecode execution, but that still need
    to occur between two opcodes, not at a completely random time.
    """
    _fired = False
    _next = None

    def __init__(self, space):
        self.space = space

    @rgc.no_collect
    def fire(self):
        """Request for the action to be run before the next opcode.
        The action must have been registered at space initalization time."""
        self.space.actionflag.fire(self)

    def perform(self, executioncontext, frame):
        """To be overridden."""


class PeriodicAsyncAction(AsyncAction):
    """Abstract base class for actions that occur automatically
    every sys.checkinterval bytecodes.
    """


class UserDelAction(AsyncAction):
    """An action that invokes all pending app-level __del__() method.
    This is done as an action instead of immediately when the
    WRootFinalizerQueue is triggered, because the latter can occur more
    or less anywhere in the middle of code that might not be happy with
    random app-level code mutating data structures under its feet.
    """

    def __init__(self, space):
        AsyncAction.__init__(self, space)
        self.finalizers_lock_count = 0        # see pypy/module/gc
        self.enabled_at_app_level = True      # see pypy/module/gc
        self.pending_with_disabled_del = None

    def perform(self, executioncontext, frame):
        self._run_finalizers()

    @jit.dont_look_inside
    def _run_finalizers(self):
        # called by perform() when we have to "perform" this action,
        # and also directly at the end of gc.collect).
        while True:
            w_obj = self.space.finalizer_queue.next_dead()
            if w_obj is None:
                break
            self._call_finalizer(w_obj)

    def gc_disabled(self, w_obj):
        # If we're running in 'gc.disable()' mode, record w_obj in the
        # "call me later" list and return True.  In normal mode, return
        # False.  Use this function from some _finalize_() methods:
        # if a _finalize_() method would call some user-defined
        # app-level function, like a weakref callback, then first do
        # 'if gc.disabled(self): return'.  Another attempt at
        # calling _finalize_() will be made after 'gc.enable()'.
        # (The exact rule for when to use gc_disabled() or not is a bit
        # vague, but most importantly this includes all user-level
        # __del__().)
        pdd = self.pending_with_disabled_del
        if pdd is None:
            return False
        else:
            pdd.append(w_obj)
            return True

    def _call_finalizer(self, w_obj):
        # Before calling the finalizers, clear the weakrefs, if any.
        w_obj.clear_all_weakrefs()

        # Look up and call the app-level __del__, if any.
        space = self.space
        if w_obj.typedef is None:
            w_del = None       # obscure case: for WeakrefLifeline
        else:
            w_del = space.lookup(w_obj, '__del__')
        if w_del is not None:
            if self.gc_disabled(w_obj):
                return
            try:
                w_impl = space.get(w_del, w_obj)
            except Exception as e:
                report_error(space, e, "method __del__ of ", w_obj)
            else:
                try:
                    space.call_function(w_impl)
                except Exception as e:
                    report_error(space, e, '', w_del)

        # Call the RPython-level _finalize_() method.
        try:
            w_obj._finalize_()
        except Exception as e:
            report_error(space, e, "finalizer of ", w_obj)


def report_error(space, e, where, w_obj):
    if isinstance(e, OperationError):
        e.write_unraisable(space, where, w_obj)
        e.clear(space)   # break up reference cycles
    else:
        addrstring = w_obj.getaddrstring(space)
        msg = ("RPython exception %s in %s<%s at 0x%s> ignored\n" % (
                   str(e), where, space.type(w_obj).name, addrstring))
        space.call_method(space.sys.get('stderr'), 'write',
                          space.newtext(msg))


def make_finalizer_queue(W_Root, space):
    """Make a FinalizerQueue subclass which responds to GC finalizer
    events by 'firing' the UserDelAction class above.  It does not
    directly fetches the objects to finalize at all; they stay in the
    GC-managed queue, and will only be fetched by UserDelAction
    (between bytecodes)."""

    class WRootFinalizerQueue(rgc.FinalizerQueue):
        Class = W_Root

        def finalizer_trigger(self):
            space.user_del_action.fire()

    space.user_del_action = UserDelAction(space)
    space.finalizer_queue = WRootFinalizerQueue()
