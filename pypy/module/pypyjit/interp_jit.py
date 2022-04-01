"""This is not the JIT :-)

This is transformed to become a JIT by code elsewhere: rpython/jit/*
"""

from rpython.rlib.rarithmetic import r_uint, intmask
from rpython.rlib.jit import JitDriver, hint, we_are_jitted, dont_look_inside
from rpython.rlib import jit, jit_hooks
from rpython.rlib.rjitlog import rjitlog as jl
from rpython.rlib.jit import current_trace_length, unroll_parameters,\
     JitHookInterface
from rpython.rtyper.annlowlevel import cast_instance_to_gcref
import pypy.interpreter.pyopcode   # for side-effects
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.pycode import CO_GENERATOR, CO_COROUTINE, PyCode
from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.pyframe import PyFrame
from pypy.interpreter.pyopcode import Yield, Return
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.gateway import interp2app
from opcode import opmap


PyFrame._virtualizable_ = ['last_instr', 'pycode',
                           'valuestackdepth',
                           'locals_cells_stack_w[*]',
                           'debugdata',
                           'lastblock',
                           'w_globals',
                           ]

JUMP_ABSOLUTE = opmap['JUMP_ABSOLUTE']

def get_printable_location(next_instr, is_being_profiled, bytecode):
    from pypy.tool.stdlib_opcode import opcode_method_names
    from pypy.interpreter.pytraceback import offset2lineno
    bytecode_name = opcode_method_names[ord(bytecode.co_code[next_instr])]
    lineno = offset2lineno(bytecode, intmask(next_instr))
    return '%s;%s:%d-%d~#%d %s' % (
        bytecode.co_name, bytecode.co_filename, bytecode.co_firstlineno,
        lineno, next_instr, bytecode_name)

def get_unique_id(next_instr, is_being_profiled, bytecode):
    from rpython.rlib import rvmprof
    return rvmprof.get_unique_id(bytecode)

@jl.returns(jl.MP_FILENAME, jl.MP_LINENO,
            jl.MP_SCOPE, jl.MP_INDEX, jl.MP_OPCODE)
def get_location(next_instr, is_being_profiled, bytecode):
    from pypy.tool.stdlib_opcode import opcode_method_names
    from pypy.interpreter.pytraceback import offset2lineno
    bcindex = ord(bytecode.co_code[next_instr])
    opname = ""
    if 0 <= bcindex < len(opcode_method_names):
        opname = opcode_method_names[bcindex]
    name = bytecode.co_name
    if not name:
        name = ""
    line = offset2lineno(bytecode, intmask(next_instr))
    return (bytecode.co_filename, line,
            name, intmask(next_instr), opname)

def should_unroll_one_iteration(next_instr, is_being_profiled, bytecode):
    return (bytecode.co_flags & (CO_COROUTINE | CO_GENERATOR)) != 0

class PyPyJitDriver(JitDriver):
    reds = ['frame', 'ec']
    greens = ['next_instr', 'is_being_profiled', 'pycode']
    virtualizables = ['frame']

pypyjitdriver = PyPyJitDriver(get_printable_location = get_printable_location,
                              get_location = get_location,
                              get_unique_id = get_unique_id,
                              should_unroll_one_iteration =
                              should_unroll_one_iteration,
                              name='pypyjit',
                              is_recursive=True)

class __extend__(PyFrame):

    def dispatch(self, pycode, next_instr, ec):
        self = hint(self, access_directly=True)
        next_instr = r_uint(next_instr)
        is_being_profiled = self.get_is_being_profiled()
        try:
            while True:
                pypyjitdriver.jit_merge_point(ec=ec,
                    frame=self, next_instr=next_instr, pycode=pycode,
                    is_being_profiled=is_being_profiled)
                co_code = pycode.co_code
                self.valuestackdepth = hint(self.valuestackdepth, promote=True)
                next_instr = self.handle_bytecode(co_code, next_instr, ec)
                is_being_profiled = self.get_is_being_profiled()
        except Yield:
            w_result = self.popvalue()
            jit.hint(self, force_virtualizable=True)
            return w_result
        except Return:
            return self.popvalue()

    def jump_absolute(self, jumpto, ec):
        if we_are_jitted():
            #
            # assume that only threads are using the bytecode counter
            decr_by = 0
            if self.space.actionflag.has_bytecode_counter:   # constant-folded
                if self.space.threadlocals.gil_ready:   # quasi-immutable field
                    decr_by = _get_adapted_tick_counter()
            #
            self.last_instr = intmask(jumpto)
            ec.bytecode_trace(self, decr_by)
            jumpto = r_uint(self.last_instr)
        #
        pypyjitdriver.can_enter_jit(frame=self, ec=ec, next_instr=jumpto,
                                 pycode=self.getcode(),
                                 is_being_profiled=self.get_is_being_profiled())
        return jumpto

def _get_adapted_tick_counter():
    # Normally, the tick counter is decremented by 100 for every
    # Python opcode.  Here, to better support JIT compilation of
    # small loops, we decrement it by a possibly smaller constant.
    # We get the maximum 100 when the (unoptimized) trace length
    # is at least 3200 (a bit randomly).
    trace_length = r_uint(current_trace_length())
    decr_by = trace_length // 32
    if decr_by < 1:
        decr_by = 1
    elif decr_by > 100:    # also if current_trace_length() returned -1
        decr_by = 100
    return intmask(decr_by)


# ____________________________________________________________
#
# Public interface

def set_param(space, __args__):
    '''Configure the tunable JIT parameters.
        * set_param(name=value, ...)            # as keyword arguments
        * set_param("name=value,name=value")    # as a user-supplied string
        * set_param("off")                      # disable the jit
        * set_param("default")                  # restore all defaults
    '''
    # XXXXXXXXX
    args_w, kwds_w = __args__.unpack()
    if len(args_w) > 1:
        raise oefmt(space.w_TypeError,
                    "set_param() takes at most 1 non-keyword argument, %d "
                    "given", len(args_w))
    if len(args_w) == 1:
        text = space.text_w(args_w[0])
        try:
            jit.set_user_param(None, text)
        except ValueError:
            raise oefmt(space.w_ValueError, "error in JIT parameters string")
    for key, w_value in kwds_w.items():
        if key == 'enable_opts':
            jit.set_param(None, 'enable_opts', space.text_w(w_value))
        else:
            intval = space.int_w(w_value)
            for name, _ in unroll_parameters:
                if name == key and name != 'enable_opts':
                    jit.set_param(None, name, intval)
                    break
            else:
                raise oefmt(space.w_TypeError, "no JIT parameter '%s'", key)

@dont_look_inside
def residual_call(space, w_callable, __args__):
    '''For testing.  Invokes callable(...), but without letting
    the JIT follow the call.'''
    return space.call_args(w_callable, __args__)


class W_NotFromAssembler(W_Root):
    def __init__(self, space, w_callable):
        self.space = space
        self.w_callable = w_callable
    def descr_call(self, __args__):
        _call_not_in_trace(self.space, self.w_callable, __args__)
        return self

@jit.not_in_trace
def _call_not_in_trace(space, w_callable, __args__):
    # this _call_not_in_trace() must return None
    space.call_args(w_callable, __args__)

def not_from_assembler_new(space, w_subtype, w_callable):
    return W_NotFromAssembler(space, w_callable)

W_NotFromAssembler.typedef = TypeDef("not_from_assembler",
    __doc__ = """\
A decorator that returns a callable that invokes the original
callable, but not from the JIT-produced assembler.  It is called
from the interpreted mode, and from the JIT creation (pyjitpl) or
exiting (blackhole) steps, but just not from the final assembler.

Note that the return value of the callable is ignored, because
there is no reasonable way to guess what it should be in case the
function is not called.  Instead, calling the callable returns
the callable itself, for convenience (see below).

This is meant to be used notably in sys.settrace() for coverage-
like tools.  For that purpose, if g = not_from_assembler(f), then
'g(*args)' may call 'f(*args)' or not.  As g() always returns g
itself, you can directly set sys.settrace(g).
""",
    __new__ = interp2app(not_from_assembler_new),
    __call__ = interp2app(W_NotFromAssembler.descr_call),
)
W_NotFromAssembler.typedef.acceptable_as_base_class = False

@unwrap_spec(next_instr=int, is_being_profiled=int, w_pycode=PyCode)
@dont_look_inside
def get_jitcell_at_key(space, next_instr, is_being_profiled, w_pycode):
    ll_pycode = cast_instance_to_gcref(w_pycode)
    return space.newbool(bool(jit_hooks.get_jitcell_at_key(
       'pypyjit', r_uint(next_instr), int(bool(is_being_profiled)), ll_pycode)))

@unwrap_spec(next_instr=int, is_being_profiled=int, w_pycode=PyCode)
@dont_look_inside
def dont_trace_here(space, next_instr, is_being_profiled, w_pycode):
    ll_pycode = cast_instance_to_gcref(w_pycode)
    jit_hooks.dont_trace_here(
        'pypyjit', r_uint(next_instr), int(bool(is_being_profiled)), ll_pycode)
    return space.w_None

@unwrap_spec(next_instr=int, is_being_profiled=int, w_pycode=PyCode)
@dont_look_inside
def trace_next_iteration(space, next_instr, is_being_profiled, w_pycode):
    ll_pycode = cast_instance_to_gcref(w_pycode)
    jit_hooks.trace_next_iteration(
        'pypyjit', r_uint(next_instr), int(bool(is_being_profiled)), ll_pycode)
    return space.w_None

@unwrap_spec(hash=r_uint)
@dont_look_inside
def trace_next_iteration_hash(space, hash):
    jit_hooks.trace_next_iteration_hash('pypyjit', hash)
    return space.w_None

@dont_look_inside
def releaseall(space):
    """ Mark all current machine code objects as ready to release.  They will
    be released at the next GC (unless they are currently in use in the stack
    of one of the threads).  Doing pypyjit.releaseall(); gc.collect() is a
    heavy hammer that forces the JIT roughly to the state of a newly started
    PyPy.
    """
    jit_hooks.stats_memmgr_release_all(None)

# class Cache(object):
#     in_recursion = False

#     def __init__(self, space):
#         self.w_compile_bridge = space.w_None
#         self.w_compile_loop = space.w_None

# def set_compile_bridge(space, w_hook):
#     cache = space.fromcache(Cache)
#     assert w_hook is not None
#     cache.w_compile_bridge = w_hook

# def set_compile_loop(space, w_hook):
#     from rpython.rlib.nonconst import NonConstant

#     cache = space.fromcache(Cache)
#     assert w_hook is not None
#     cache.w_compile_loop = w_hook
#     cache.in_recursion = NonConstant(False)

# class PyPyJitHookInterface(JitHookInterface):
#     def after_compile(self, debug_info):
#         space = self.space
#         cache = space.fromcache(Cache)
#         if cache.in_recursion:
#             return
#         l_w = []
#         if not space.is_true(cache.w_compile_loop):
#             return
#         for i, op in enumerate(debug_info.operations):
#             if op.is_guard():
#                 w_t = space.newtuple([space.newint(i), space.newint(op.getopnum()), space.newint(op.getdescr().get_jitcounter_hash())])
#                 l_w.append(w_t)
#         try:
#             cache.in_recursion = True
#             try:
#                 space.call_function(cache.w_compile_loop, space.newlist(l_w))
#             except OperationError, e:
#                 e.write_unraisable(space, "jit hook ", cache.w_compile_bridge)
#         finally:
#             cache.in_recursion = False

#     def after_compile_bridge(self, debug_info):
#         space = self.space
#         cache = space.fromcache(Cache)
#         if cache.in_recursion:
#             return
#         if not space.is_true(cache.w_compile_bridge):
#             return
#         w_hash = space.newint(debug_info.fail_descr.get_jitcounter_hash())
#         try:
#             cache.in_recursion = True
#             try:
#                 space.call_function(cache.w_compile_bridge, w_hash)
#             except OperationError, e:
#                 e.write_unraisable(space, "jit hook ", cache.w_compile_bridge)
#         finally:
#             cache.in_recursion = False

#     def before_compile(self, debug_info):
#         pass

#     def before_compile_bridge(self, debug_info):
#         pass

# pypy_hooks = PyPyJitHookInterface()

