import sys

import py

from rpython.rlib.nonconst import NonConstant
from rpython.rlib.objectmodel import CDefinedIntSymbolic, keepalive_until_here, specialize, not_rpython, we_are_translated
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.tool.sourcetools import rpython_wrapper

DEBUG_ELIDABLE_FUNCTIONS = False


def elidable(func):
    """ Decorate a function as "trace-elidable". Usually this means simply that
    the function is constant-foldable, i.e. is pure and has no side-effects.
    This also has the effect that the inside of the function will never be
    traced.

    In some situations it is ok to use this decorator if the function *has*
    side effects, as long as these side-effects are idempotent. A typical
    example for this would be a cache.

    To be totally precise:

    (1) the result of the call should not change if the arguments are
        the same (same numbers or same pointers)
    (2) it's fine to remove the call completely if we can guess the result
        according to rule 1
    (3) the function call can be moved around by optimizer,
        but only so it'll be called earlier and not later.

    Most importantly it doesn't mean that an elidable function has no observable
    side effect, but those side effects are idempotent (ie caching).
    If a particular call to this function ends up raising an exception, then it
    is handled like a normal function call (this decorator is ignored).

    Note also that this optimisation will only take effect if the arguments
    to the function are proven constant. By this we mean each argument
    is either:

      1) a constant from the RPython source code (e.g. "x = 2")
      2) easily shown to be constant by the tracer
      3) a promoted variable (see @jit.promote)

    Examples of condition 2:

      * i1 = int_eq(i0, 0), guard_true(i1)
      * i1 = getfield_pc_pure(<constant>, "immutable_field")

    In both cases, the tracer will deduce that i1 is constant.

    Failing the above conditions, the function is not traced into (as if the
    function were decorated with @jit.dont_look_inside). Generally speaking,
    it is a bad idea to liberally sprinkle @jit.elidable without a concrete
    need.
    """
    if DEBUG_ELIDABLE_FUNCTIONS:
        cache = {}
        oldfunc = func
        def func(*args):
            result = oldfunc(*args)    # if it raises, no caching
            try:
                oldresult = cache.setdefault(args, result)
            except TypeError:
                pass           # unhashable args
            else:
                assert oldresult == result
            return result
    if getattr(func, '_jit_unroll_safe_', False):
        raise TypeError("it does not make sense for %s to be both elidable and unroll_safe" % func)
    func._elidable_function_ = True
    return func

def purefunction(*args, **kwargs):
    import warnings
    warnings.warn("purefunction is deprecated, use elidable instead", DeprecationWarning)
    return elidable(*args, **kwargs)

def hint(x, **kwds):
    """ Hint for the JIT

    possible arguments are:

    * promote - promote the argument from a variable into a constant
    * promote_string - same, but promote string by *value*
    * promote_unicode - same, but promote unicode string by *value*
    * access_directly - directly access a virtualizable, as a structure
                        and don't treat it as a virtualizable
    * fresh_virtualizable - means that virtualizable was just allocated.
                            Useful in say Frame.__init__ when we do want
                            to store things directly on it. Has to come with
                            access_directly=True
    * force_virtualizable - a performance hint to force the virtualizable early
                            (useful e.g. for python generators that are going
                            to be read later anyway)
    """
    return x

@specialize.argtype(0)
def promote(x):
    """
    Promotes a variable in a trace to a constant.

    When a variable is promoted, a guard is inserted that assumes the value
    of the variable is constant. In other words, the value of the variable
    is checked to be the same as it was at trace collection time.  Once the
    variable is assumed constant, more aggressive constant folding may be
    possible.

    If however, the guard fails frequently, a bridge will be generated
    this time assuming the constancy of the variable under its new value.
    This optimisation should be used carefully, as in extreme cases, where
    the promoted variable is not very constant at all, code explosion can
    occur. In turn this leads to poor performance.

    Overpromotion is characterised by a cascade of bridges branching from
    very similar guard_value opcodes, each guarding the same variable under
    a different value.

    Note that promoting a string with @jit.promote will promote by pointer.
    To promote a string by value, see @jit.promote_string.

    """
    return hint(x, promote=True)

def promote_string(x):
    return hint(x, promote_string=True)

def promote_unicode(x):
    return hint(x, promote_unicode=True)

def dont_look_inside(func):
    """ Make sure the JIT does not trace inside decorated function
    (it becomes a call instead)
    """
    if getattr(func, '_jit_unroll_safe_', False):
        raise TypeError("it does not make sense for %s to be both dont_look_inside and unroll_safe" % func)
    func._jit_look_inside_ = False
    return func

def look_inside(func):
    """ Make sure the JIT traces inside decorated function, even
    if the rest of the module is not visible to the JIT
    """
    import warnings
    warnings.warn("look_inside is deprecated", DeprecationWarning)
    func._jit_look_inside_ = True
    return func

def unroll_safe(func):
    """ JIT can safely unroll loops in this function and this will
    not lead to code explosion
    """
    if getattr(func, '_elidable_function_', False):
        raise TypeError("it does not make sense for %s to be both elidable and unroll_safe" % func)
    if not getattr(func, '_jit_look_inside_', True):
        raise TypeError("it does not make sense for %s to be both unroll_safe and dont_look_inside" % func)
    func._jit_unroll_safe_ = True
    return func

def loop_invariant(func):
    """ Describes a function with no argument that returns an object that
    is always the same in a loop.

    Use it only if you know what you're doing.
    """
    dont_look_inside(func)
    func._jit_loop_invariant_ = True
    return func

def _get_args(func):
    import inspect

    args, varargs, varkw, defaults = inspect.getargspec(func)
    assert varargs is None and varkw is None
    assert not defaults
    return args

def elidable_promote(promote_args='all'):
    """ A decorator that promotes all arguments and then calls the supplied
    function
    """
    def decorator(func):
        elidable(func)
        args = _get_args(func)
        argstring = ", ".join(args)
        code = ["def f(%s):\n" % (argstring, )]
        if promote_args != 'all':
            args = [args[int(i)] for i in promote_args.split(",")]
        for arg in args:
            code.append( #use both hints, and let jtransform pick the right one
                "    %s = hint(%s, promote=True, promote_string=True)\n" %
                (arg, arg))
        code.append("    return _orig_func_unlikely_name(%s)\n" % (argstring, ))
        d = {"_orig_func_unlikely_name": func, "hint": hint}
        exec py.code.Source("\n".join(code)).compile() in d
        result = d["f"]
        result.__name__ = func.__name__ + "_promote"
        return result
    return decorator

def purefunction_promote(*args, **kwargs):
    import warnings
    warnings.warn("purefunction_promote is deprecated, use elidable_promote instead", DeprecationWarning)
    return elidable_promote(*args, **kwargs)

def look_inside_iff(predicate):
    """
    look inside (including unrolling loops) the target function, if and only if
    predicate(*args) returns True
    """
    def inner(func):
        func = unroll_safe(func)
        # When we return the new function, it might be specialized in some
        # way. We "propogate" this specialization by using
        # specialize:call_location on relevant functions.
        for thing in [func, predicate]:
            thing._annspecialcase_ = "specialize:call_location"

        args = _get_args(func)
        predicateargs = _get_args(predicate)
        assert len(args) == len(predicateargs), "%s and predicate %s need the same numbers of arguments" % (func, predicate)
        d = {
            "dont_look_inside": dont_look_inside,
            "predicate": predicate,
            "func": func,
            "we_are_jitted": we_are_jitted,
        }
        exec py.code.Source("""
            @dont_look_inside
            def trampoline(%(arguments)s):
                return func(%(arguments)s)
            if hasattr(func, "oopspec"):
                trampoline.oopspec = func.oopspec
                del func.oopspec
            trampoline.__name__ = func.__name__ + "_trampoline"
            trampoline._annspecialcase_ = "specialize:call_location"

            def f(%(arguments)s):
                if not we_are_jitted() or predicate(%(arguments)s):
                    return func(%(arguments)s)
                else:
                    return trampoline(%(arguments)s)
            f.__name__ = func.__name__ + "_look_inside_iff"
        """ % {"arguments": ", ".join(args)}).compile() in d
        return d["f"]
    return inner

def oopspec(spec):
    """ The JIT compiler won't look inside this decorated function,
        but instead during translation, rewrites it according to the handler in
        rpython/jit/codewriter/jtransform.py.
    """
    def decorator(func):
        func.oopspec = spec
        return func
    return decorator

def not_in_trace(func):
    """A decorator for a function with no return value.  It makes the
    function call disappear from the jit traces. It is still called in
    interpreted mode, and by the jit tracing and blackholing, but not
    by the final assembler."""
    func.oopspec = "jit.not_in_trace()"   # note that 'func' may take arguments
    return func


@oopspec("jit.isconstant(value)")
@specialize.call_location()
def isconstant(value):
    """
    While tracing, returns whether or not the value is currently known to be
    constant. This is not perfect, values can become constant later. Mostly for
    use with @look_inside_iff.

    This is for advanced usage only.
    """
    return NonConstant(False)

@oopspec("jit.isvirtual(value)")
@specialize.call_location()
def isvirtual(value):
    """
    Returns if this value is virtual, while tracing, it's relatively
    conservative and will miss some cases.

    This is for advanced usage only.
    """
    return NonConstant(False)

@specialize.call_location()
def loop_unrolling_heuristic(lst, size, cutoff=2):
    """ In which cases iterating over items of lst can be unrolled
    """
    return size == 0 or isvirtual(lst) or (isconstant(size) and size <= cutoff)

class Entry(ExtRegistryEntry):
    _about_ = hint

    def compute_result_annotation(self, s_x, **kwds_s):
        from rpython.annotator import model as annmodel
        s_x = annmodel.not_const(s_x)
        access_directly = 's_access_directly' in kwds_s
        fresh_virtualizable = 's_fresh_virtualizable' in kwds_s
        if access_directly or fresh_virtualizable:
            assert access_directly, "lone fresh_virtualizable hint"
            if isinstance(s_x, annmodel.SomeInstance):
                from rpython.flowspace.model import Constant
                classdesc = s_x.classdef.classdesc
                virtualizable = classdesc.get_param('_virtualizable_')
                if virtualizable is not None:
                    flags = s_x.flags.copy()
                    flags['access_directly'] = True
                    if fresh_virtualizable:
                        flags['fresh_virtualizable'] = True
                    s_x = annmodel.SomeInstance(s_x.classdef,
                                                s_x.can_be_None,
                                                flags)
        return s_x

    def specialize_call(self, hop, **kwds_i):
        from rpython.rtyper.lltypesystem import lltype
        hints = {}
        for key, index in kwds_i.items():
            s_value = hop.args_s[index]
            if not s_value.is_constant():
                from rpython.rtyper.error import TyperError
                raise TyperError("hint %r is not constant" % (key,))
            assert key.startswith('i_')
            hints[key[2:]] = s_value.const
        v = hop.inputarg(hop.args_r[0], arg=0)
        c_hint = hop.inputconst(lltype.Void, hints)
        hop.exception_cannot_occur()
        return hop.genop('hint', [v, c_hint], resulttype=v.concretetype)


def we_are_jitted():
    """ Considered as true during tracing and blackholing,
    so its consquences are reflected into jitted code """
    return False

_we_are_jitted = CDefinedIntSymbolic('0 /* we are not jitted here */',
                                     default=0)

def _get_virtualizable_token(frame):
    """ An obscure API to get vable token.
    Used by _vmprof
    """
    from rpython.rtyper.lltypesystem import lltype, llmemory

    return lltype.nullptr(llmemory.GCREF.TO)

class GetVirtualizableTokenEntry(ExtRegistryEntry):
    _about_ = _get_virtualizable_token

    def compute_result_annotation(self, s_arg):
        from rpython.rtyper.llannotation import SomePtr
        from rpython.rtyper.lltypesystem import llmemory
        return SomePtr(llmemory.GCREF)

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype, llmemory

        hop.exception_cannot_occur()
        T = hop.args_r[0].lowleveltype.TO
        v = hop.inputarg(hop.args_r[0], arg=0)
        while not hasattr(T, 'vable_token'):
            if not hasattr(T, 'super'):
                # we're not really in a jitted build
                return hop.inputconst(llmemory.GCREF,
                                      lltype.nullptr(llmemory.GCREF.TO))
            T = T.super
        v = hop.genop('cast_pointer', [v], resulttype=lltype.Ptr(T))
        c_vable_token = hop.inputconst(lltype.Void, 'vable_token')
        return hop.genop('getfield', [v, c_vable_token],
                         resulttype=llmemory.GCREF)

class Entry(ExtRegistryEntry):
    _about_ = we_are_jitted

    def compute_result_annotation(self):
        from rpython.annotator import model as annmodel
        return annmodel.SomeInteger(nonneg=True)

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Signed, _we_are_jitted)

@oopspec('jit.current_trace_length()')
def current_trace_length():
    """During JIT tracing, returns the current trace length (as a constant).
    If not tracing, returns -1."""
    if NonConstant(False):
        return 73
    return -1

@oopspec('jit.debug(string, arg1, arg2, arg3, arg4)')
def jit_debug(string, arg1=-sys.maxint-1, arg2=-sys.maxint-1,
                      arg3=-sys.maxint-1, arg4=-sys.maxint-1):
    """When JITted, cause an extra operation JIT_DEBUG to appear in
    the graphs.  Should not be left after debugging."""
    keepalive_until_here(string) # otherwise the whole function call is removed

@oopspec('jit.assert_green(value)')
@specialize.argtype(0)
def assert_green(value):
    """Very strong assert: checks that 'value' is a green
    (a JIT compile-time constant)."""
    keepalive_until_here(value)

class AssertGreenFailed(Exception):
    pass


def jit_callback(name):
    """Use as a decorator for C callback functions, to insert a
    jitdriver.jit_merge_point() at the start.  Only for callbacks
    that typically invoke more app-level Python code.
    """
    def decorate(func):
        from rpython.tool.sourcetools import compile2
        #
        def get_printable_location():
            return name
        jitdriver = JitDriver(get_printable_location=get_printable_location,
                              greens=[], reds='auto', name=name)
        #
        args = ','.join(['a%d' % i for i in range(func.__code__.co_argcount)])
        source = """def callback_with_jitdriver(%(args)s):
                        jitdriver.jit_merge_point()
                        return real_callback(%(args)s)""" % locals()
        miniglobals = {
            'jitdriver': jitdriver,
            'real_callback': func,
            }
        exec compile2(source) in miniglobals
        return miniglobals['callback_with_jitdriver']
    return decorate


# ____________________________________________________________
# VRefs

@oopspec('virtual_ref(x)')
@specialize.argtype(0)
def virtual_ref(x):
    """Creates a 'vref' object that contains a reference to 'x'.  Calls
    to virtual_ref/virtual_ref_finish must be properly nested.  The idea
    is that the object 'x' is supposed to be JITted as a virtual between
    the calls to virtual_ref and virtual_ref_finish, but the 'vref'
    object can escape at any point in time.  If at runtime it is
    dereferenced (by the call syntax 'vref()'), it returns 'x', which is
    then forced."""
    return DirectJitVRef(x)

@oopspec('virtual_ref_finish(x)')
@specialize.argtype(1)
def virtual_ref_finish(vref, x):
    """See docstring in virtual_ref(x)"""
    keepalive_until_here(x)   # otherwise the whole function call is removed
    _virtual_ref_finish(vref, x)

def non_virtual_ref(x):
    """Creates a 'vref' that just returns x when called; nothing more special.
    Used for None or for frames outside JIT scope."""
    return DirectVRef(x)

class InvalidVirtualRef(Exception):
    """
    Raised if we try to call a non-forced virtualref after the call to
    virtual_ref_finish
    """

# ---------- implementation-specific ----------

class DirectVRef(object):
    def __init__(self, x):
        self._x = x
        self._state = 'non-forced'

    def __call__(self):
        if self._state == 'non-forced':
            self._state = 'forced'
        elif self._state == 'invalid':
            raise InvalidVirtualRef
        return self._x

    @property
    def virtual(self):
        """A property that is True if the vref contains a virtual that would
        be forced by the '()' operator."""
        return self._state == 'non-forced'

    def _finish(self):
        if self._state == 'non-forced':
            self._state = 'invalid'

class DirectJitVRef(DirectVRef):
    def __init__(self, x):
        assert x is not None, "virtual_ref(None) is not allowed"
        DirectVRef.__init__(self, x)

def _virtual_ref_finish(vref, x):
    assert vref._x is x, "Invalid call to virtual_ref_finish"
    vref._finish()

class Entry(ExtRegistryEntry):
    _about_ = (non_virtual_ref, DirectJitVRef)

    def compute_result_annotation(self, s_obj):
        from rpython.rlib import _jit_vref
        return _jit_vref.SomeVRef(s_obj)

    def specialize_call(self, hop):
        return hop.r_result.specialize_call(hop)

class Entry(ExtRegistryEntry):
    _type_ = DirectVRef

    def compute_annotation(self):
        from rpython.rlib import _jit_vref
        assert isinstance(self.instance, DirectVRef)
        s_obj = self.bookkeeper.immutablevalue(self.instance())
        return _jit_vref.SomeVRef(s_obj)

class Entry(ExtRegistryEntry):
    _about_ = _virtual_ref_finish

    def compute_result_annotation(self, s_vref, s_obj):
        pass

    def specialize_call(self, hop):
        hop.exception_cannot_occur()

vref_None = non_virtual_ref(None)

# ____________________________________________________________
# User interface for the warmspot JIT policy

class JitHintError(Exception):
    """Inconsistency in the JIT hints."""

ENABLE_ALL_OPTS = (
    'intbounds:rewrite:virtualize:string:pure:earlyforce:heap:unroll')

PARAMETER_DOCS = {
    'threshold': 'number of times a loop has to run for it to become hot',
    'function_threshold': 'number of times a function must run for it to become traced from start',
    'trace_eagerness': 'number of times a guard has to fail before we start compiling a bridge',
    'decay': 'amount to regularly decay counters by (0=none, 1000=max)',
    'trace_limit': 'number of recorded operations before we abort tracing with ABORT_TOO_LONG',
    'inlining': 'inline python functions or not (1/0)',
    'loop_longevity': 'a parameter controlling how long loops will be kept before being freed, an estimate',
    'retrace_limit': 'how many times we can try retracing before giving up',
    'max_retrace_guards': 'number of extra guards a retrace can cause',
    'max_unroll_loops': 'number of extra unrollings a loop can cause',
    'disable_unrolling': 'after how many operations we should not unroll',
    'enable_opts': 'INTERNAL USE ONLY (MAY NOT WORK OR LEAD TO CRASHES): '
                   'optimizations to enable, or all = %s' % ENABLE_ALL_OPTS,
    'max_unroll_recursion': 'how many levels deep to unroll a recursive function',
    'vec': 'turn on the vectorization optimization (vecopt). ' \
           'Supports x86 (SSE 4.1), powerpc (SVX), s390x SIMD',
    'vec_cost': 'threshold for which traces to bail. Unpacking increases the counter,'\
                ' vector operation decrease the cost',
    'vec_all': 'try to vectorize trace loops that occur outside of the numpypy library',
}

PARAMETERS = {'threshold': 1039, # just above 1024, prime
              'function_threshold': 1619, # slightly more than one above, also prime
              'trace_eagerness': 200,
              'decay': 40,
              'trace_limit': 6000,
              'inlining': 1,
              'loop_longevity': 1000,
              'retrace_limit': 0,
              'max_retrace_guards': 15,
              'max_unroll_loops': 0,
              'disable_unrolling': 200,
              'enable_opts': 'all',
              'max_unroll_recursion': 7,
              'vec': 0,
              'vec_all': 0,
              'vec_cost': 0,
              }
unroll_parameters = unrolling_iterable(PARAMETERS.items())

# ____________________________________________________________

class JitDriver(object):
    """Base class to declare fine-grained user control on the JIT.  So
    far, there must be a singleton instance of JitDriver.  This style
    will allow us (later) to support a single RPython program with
    several independent JITting interpreters in it.
    """

    active = True          # if set to False, this JitDriver is ignored
    virtualizables = []
    name = 'jitdriver'
    inline_jit_merge_point = False
    _store_last_enter_jit = None

    @not_rpython
    def __init__(self, greens=None, reds=None, virtualizables=None,
                 get_jitcell_at=None, set_jitcell_at=None,
                 get_printable_location=None, confirm_enter_jit=None,
                 can_never_inline=None, should_unroll_one_iteration=None,
                 name='jitdriver', check_untranslated=True, vectorize=False,
                 get_unique_id=None, is_recursive=False, get_location=None):
        """get_location:
              The return value is designed to provide enough information to express the
              state of an interpreter when invoking jit_merge_point.
              For a bytecode interperter such as PyPy this includes, filename, line number,
              function name, and more information. However, it should also be able to express
              the same state for an interpreter that evaluates an AST.
              return paremter:
                0 -> filename. An absolute path specifying the file the interpreter invoked.
                               If the input source is no file it should start with the
                               prefix: "string://<name>"
                1 -> line number. The line number in filename. This should at least point to
                                  the enclosing name. It can however point to the specific
                                  source line of the instruction executed by the interpreter.
                2 -> enclosing name. E.g. the function name.
                3 -> index. 64 bit number indicating the execution progress. It can either be
                     an offset to byte code, or an index to the node in an AST
                4 -> operation name. a name further describing the current program counter.
                     this can be either a byte code name or the name of an AST node
        """
        if greens is not None:
            self.greens = greens
        self.name = name
        if reds == 'auto':
            self.autoreds = True
            self.reds = []
            self.numreds = None # see warmspot.autodetect_jit_markers_redvars
            assert confirm_enter_jit is None, (
                "reds='auto' is not compatible with confirm_enter_jit")
        else:
            if reds is not None:
                self.reds = reds
            self.autoreds = False
            self.numreds = len(self.reds)
        if not hasattr(self, 'greens') or not hasattr(self, 'reds'):
            raise AttributeError("no 'greens' or 'reds' supplied")
        if virtualizables is not None:
            self.virtualizables = virtualizables
        for v in self.virtualizables:
            assert v in self.reds
        # if reds are automatic, they won't be passed to jit_merge_point, so
        # _check_arguments will receive only the green ones (i.e., the ones
        # which are listed explicitly). So, it is fine to just ignore reds
        self._somelivevars = set([name for name in
                                  self.greens + (self.reds or [])
                                  if '.' not in name])
        self._heuristic_order = {}   # check if 'reds' and 'greens' are ordered
        self._make_extregistryentries()
        assert get_jitcell_at is None, "get_jitcell_at no longer used"
        assert set_jitcell_at is None, "set_jitcell_at no longer used"
        for green in self.greens:
            if "." in green:
                raise ValueError("green fields are buggy! if you need them fixed, please talk to us")
        self.get_printable_location = get_printable_location
        self.get_location = get_location
        self.has_unique_id = (get_unique_id is not None)
        if get_unique_id is None:
            get_unique_id = lambda *args: 0
        self.get_unique_id = get_unique_id
        self.confirm_enter_jit = confirm_enter_jit
        self.can_never_inline = can_never_inline
        self.should_unroll_one_iteration = should_unroll_one_iteration
        self.check_untranslated = check_untranslated
        self.is_recursive = is_recursive
        self.vec = vectorize

    def _freeze_(self):
        return True

    def _check_arguments(self, livevars, is_merge_point):
        assert set(livevars) == self._somelivevars
        # check heuristically that 'reds' and 'greens' are ordered as
        # the JIT will need them to be: first INTs, then REFs, then
        # FLOATs.
        if len(self._heuristic_order) < len(livevars):
            from rpython.rlib.rarithmetic import (r_singlefloat, r_longlong,
                                                  r_ulonglong, r_uint)
            added = False
            for var, value in livevars.items():
                if var not in self._heuristic_order:
                    if (r_ulonglong is not r_uint and
                            isinstance(value, (r_longlong, r_ulonglong))):
                        assert 0, ("should not pass a r_longlong argument for "
                                   "now, because on 32-bit machines it needs "
                                   "to be ordered as a FLOAT but on 64-bit "
                                   "machines as an INT")
                    elif isinstance(value, (int, long, r_singlefloat)):
                        kind = '1:INT'
                    elif isinstance(value, float):
                        kind = '3:FLOAT'
                    elif isinstance(value, (str, unicode)) and len(value) != 1:
                        kind = '2:REF'
                    elif isinstance(value, (list, dict)):
                        kind = '2:REF'
                    elif (hasattr(value, '__class__')
                          and value.__class__.__module__ != '__builtin__'):
                        if hasattr(value, '_freeze_'):
                            continue   # value._freeze_() is better not called
                        elif getattr(value, '_alloc_flavor_', 'gc') == 'gc':
                            kind = '2:REF'
                        else:
                            kind = '1:INT'
                    else:
                        continue
                    self._heuristic_order[var] = kind
                    added = True
            if added:
                for color in ('reds', 'greens'):
                    lst = getattr(self, color)
                    allkinds = [self._heuristic_order.get(name, '?')
                                for name in lst]
                    kinds = [k for k in allkinds if k != '?']
                    assert kinds == sorted(kinds), (
                        "bad order of %s variables in the jitdriver: "
                        "must be INTs, REFs, FLOATs; got %r" %
                        (color, allkinds))

        if is_merge_point:
            if self._store_last_enter_jit:
                if livevars != self._store_last_enter_jit:
                    raise JitHintError(
                        "Bad can_enter_jit() placement: there should *not* "
                        "be any code in between can_enter_jit() -> jit_merge_point()" )
                self._store_last_enter_jit = None
        else:
            self._store_last_enter_jit = livevars

    def jit_merge_point(_self, **livevars):
        # special-cased by ExtRegistryEntry
        if _self.check_untranslated:
            _self._check_arguments(livevars, True)

    def can_enter_jit(_self, **livevars):
        if _self.autoreds:
            raise TypeError("Cannot call can_enter_jit on a driver with reds='auto'")
        # special-cased by ExtRegistryEntry
        if _self.check_untranslated:
            _self._check_arguments(livevars, False)

    def loop_header(self):
        # special-cased by ExtRegistryEntry
        pass

    def inline(self, call_jit_merge_point):
        assert False, "@inline off: see skipped failures in test_warmspot."
        #
        assert self.autoreds, "@inline works only with reds='auto'"
        self.inline_jit_merge_point = True
        def decorate(func):
            template = """
                def {name}({arglist}):
                    {call_jit_merge_point}({arglist})
                    return {original}({arglist})
            """
            templateargs = {'call_jit_merge_point': call_jit_merge_point.__name__}
            globaldict = {call_jit_merge_point.__name__: call_jit_merge_point}
            result = rpython_wrapper(func, template, templateargs, **globaldict)
            result._inline_jit_merge_point_ = call_jit_merge_point
            return result

        return decorate


    def clone(self):
        assert self.inline_jit_merge_point, 'JitDriver.clone works only after @inline'
        newdriver = object.__new__(self.__class__)
        newdriver.__dict__ = self.__dict__.copy()
        return newdriver

    def _make_extregistryentries(self):
        # workaround: we cannot declare ExtRegistryEntries for functions
        # used as methods of a frozen object, but we can attach the
        # bound methods back to 'self' and make ExtRegistryEntries
        # specifically for them.
        self.jit_merge_point = self.jit_merge_point
        self.can_enter_jit = self.can_enter_jit
        self.loop_header = self.loop_header
        class Entry(ExtEnterLeaveMarker):
            _about_ = (self.jit_merge_point, self.can_enter_jit)

        class Entry(ExtLoopHeader):
            _about_ = self.loop_header

def _set_param(driver, name, value):
    # special-cased by ExtRegistryEntry
    # (internal, must receive a constant 'name')
    # if value is None, sets the default value.
    assert name in PARAMETERS

@specialize.arg(0, 1)
def set_param(driver, name, value):
    """Set one of the tunable JIT parameter. Driver can be None, then all
    drivers have this set """
    _set_param(driver, name, value)

@specialize.arg(0, 1)
def set_param_to_default(driver, name):
    """Reset one of the tunable JIT parameters to its default value."""
    _set_param(driver, name, None)

class TraceLimitTooHigh(Exception):
    """ This is raised when the trace limit is too high for the chosen
    opencoder model, recompile your interpreter with 'big' as
    jit_opencoder_model
    """

@specialize.arg(0)
def set_user_param(driver, text):
    """Set the tunable JIT parameters from a user-supplied string
    following the format 'param=value,param=value', or 'off' to
    disable the JIT.  For programmatic setting of parameters, use
    directly JitDriver.set_param().
    """
    if text == 'off':
        set_param(driver, 'threshold', -1)
        set_param(driver, 'function_threshold', -1)
        return
    if text == 'default':
        for name1, _ in unroll_parameters:
            set_param_to_default(driver, name1)
        return
    for s in text.split(','):
        s = s.strip(' ')
        parts = s.split('=')
        if len(parts) != 2:
            raise ValueError
        name = parts[0]
        value = parts[1]
        if name == 'enable_opts':
            set_param(driver, 'enable_opts', value)
        else:
            for name1, _ in unroll_parameters:
                if name1 == name and name1 != 'enable_opts':
                    try:
                        if name1 == 'trace_limit' and int(value) > 2**14:
                            raise TraceLimitTooHigh
                        set_param(driver, name1, int(value))
                    except ValueError:
                        raise
                    break
            else:
                raise ValueError

# ____________________________________________________________
#
# Annotation and rtyping of some of the JitDriver methods


class ExtEnterLeaveMarker(ExtRegistryEntry):
    # Replace a call to myjitdriver.jit_merge_point(**livevars)
    # with an operation jit_marker('jit_merge_point', myjitdriver, livevars...)
    # Also works with can_enter_jit.

    def compute_result_annotation(self, **kwds_s):
        from rpython.annotator import model as annmodel

        if self.instance.__name__ == 'jit_merge_point':
            self.annotate_hooks(**kwds_s)

        driver = self.instance.im_self
        keys = kwds_s.keys()
        keys.sort()
        expected = ['s_' + name for name in driver.greens + driver.reds
                                if '.' not in name]
        expected.sort()
        if keys != expected:
            raise JitHintError("%s expects the following keyword "
                               "arguments: %s" % (self.instance,
                                                  expected))

        try:
            cache = self.bookkeeper._jit_annotation_cache[driver]
        except AttributeError:
            cache = {}
            self.bookkeeper._jit_annotation_cache = {driver: cache}
        except KeyError:
            cache = {}
            self.bookkeeper._jit_annotation_cache[driver] = cache
        for key, s_value in kwds_s.items():
            s_previous = cache.get(key, annmodel.s_ImpossibleValue)
            s_value = annmodel.unionof(s_previous, s_value)  # where="mixing incompatible types in argument %s of jit_merge_point/can_enter_jit" % key[2:]
            cache[key] = s_value

        # add the attribute _dont_reach_me_in_del_ (see rpython.rtyper.rclass)
        try:
            graph = self.bookkeeper.position_key[0]
            graph.func._dont_reach_me_in_del_ = True
        except (TypeError, AttributeError):
            pass

        return annmodel.s_None

    def annotate_hooks(self, **kwds_s):
        driver = self.instance.im_self
        h = self.annotate_hook
        h(driver.get_printable_location, driver.greens, **kwds_s)
        h(driver.get_location, driver.greens, **kwds_s)

    def annotate_hook(self, func, variables, args_s=[], **kwds_s):
        if func is None:
            return
        bk = self.bookkeeper
        s_func = bk.immutablevalue(func)
        uniquekey = 'jitdriver.%s' % func.__name__
        args_s = args_s[:]
        for name in variables:
            if '.' not in name:
                s_arg = kwds_s['s_' + name]
            else:
                objname, fieldname = name.split('.')
                s_instance = kwds_s['s_' + objname]
                classdesc = s_instance.classdef.classdesc
                bk.record_getattr(classdesc, fieldname)
                attrdef = s_instance.classdef.find_attribute(fieldname)
                s_arg = attrdef.s_value
                assert s_arg is not None
            args_s.append(s_arg)
        bk.emulate_pbc_call(uniquekey, s_func, args_s)

    def specialize_call(self, hop, **kwds_i):
        # XXX to be complete, this could also check that the concretetype
        # of the variables are the same for each of the calls.
        from rpython.rtyper.lltypesystem import lltype
        driver = self.instance.im_self
        greens_v = []
        reds_v = []
        for name in driver.greens:
            if '.' not in name:
                i = kwds_i['i_' + name]
                r_green = hop.args_r[i]
                v_green = hop.inputarg(r_green, arg=i)
            else:
                objname, fieldname = name.split('.')   # see test_green_field
                assert objname in driver.reds
                i = kwds_i['i_' + objname]
                s_red = hop.args_s[i]
                r_red = hop.args_r[i]
                while True:
                    try:
                        mangled_name, r_field = r_red._get_field(fieldname)
                        break
                    except KeyError:
                        pass
                    assert r_red.rbase is not None, (
                        "field %r not found in %r" % (name,
                                                      r_red.lowleveltype.TO))
                    r_red = r_red.rbase
                GTYPE = r_red.lowleveltype.TO
                assert GTYPE._immutable_field(mangled_name), (
                    "field %r must be declared as immutable" % name)
                if not hasattr(driver, 'll_greenfields'):
                    driver.ll_greenfields = {}
                driver.ll_greenfields[name] = GTYPE, mangled_name
                #
                v_red = hop.inputarg(r_red, arg=i)
                c_llname = hop.inputconst(lltype.Void, mangled_name)
                v_green = hop.genop('getfield', [v_red, c_llname],
                                    resulttype=r_field)
                s_green = s_red.classdef.about_attribute(fieldname)
                assert s_green is not None
                hop.rtyper.annotator.setbinding(v_green, s_green)
            greens_v.append(v_green)
        for name in driver.reds:
            i = kwds_i['i_' + name]
            r_red = hop.args_r[i]
            v_red = hop.inputarg(r_red, arg=i)
            reds_v.append(v_red)
        hop.exception_cannot_occur()
        vlist = [hop.inputconst(lltype.Void, self.instance.__name__),
                 hop.inputconst(lltype.Void, driver)]
        vlist.extend(greens_v)
        vlist.extend(reds_v)
        return hop.genop('jit_marker', vlist,
                         resulttype=lltype.Void)

class ExtLoopHeader(ExtRegistryEntry):
    # Replace a call to myjitdriver.loop_header()
    # with an operation jit_marker('loop_header', myjitdriver).

    def compute_result_annotation(self, **kwds_s):
        from rpython.annotator import model as annmodel
        return annmodel.s_None

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        driver = self.instance.im_self
        hop.exception_cannot_occur()
        vlist = [hop.inputconst(lltype.Void, 'loop_header'),
                 hop.inputconst(lltype.Void, driver)]
        return hop.genop('jit_marker', vlist,
                         resulttype=lltype.Void)

class ExtSetParam(ExtRegistryEntry):
    _about_ = _set_param

    def compute_result_annotation(self, s_driver, s_name, s_value):
        from rpython.annotator import model as annmodel
        assert s_name.is_constant()
        if s_name.const == 'enable_opts':
            assert annmodel.SomeString(can_be_None=True).contains(s_value)
        else:
            assert (s_value == annmodel.s_None or
                    annmodel.SomeInteger().contains(s_value))
        return annmodel.s_None

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        from rpython.rtyper.lltypesystem.rstr import string_repr
        from rpython.flowspace.model import Constant

        hop.exception_cannot_occur()
        driver = hop.inputarg(lltype.Void, arg=0)
        name = hop.args_s[1].const
        if name == 'enable_opts':
            repr = string_repr
        else:
            repr = lltype.Signed
        if (isinstance(hop.args_v[2], Constant) and
            hop.args_v[2].value is None):
            value = PARAMETERS[name]
            v_value = hop.inputconst(repr, value)
        else:
            v_value = hop.inputarg(repr, arg=2)
        vlist = [hop.inputconst(lltype.Void, "set_param"),
                 driver,
                 hop.inputconst(lltype.Void, name),
                 v_value]
        return hop.genop('jit_marker', vlist,
                         resulttype=lltype.Void)

class AsmInfo(object):
    """ An addition to JitDebugInfo concerning assembler. Attributes:

    ops_offset - dict of offsets of operations or None
    asmaddr - (int) raw address of assembler block
    asmlen - assembler block length
    rawstart - address a guard can jump to
    """
    def __init__(self, ops_offset, asmaddr, asmlen, rawstart=0):
        self.ops_offset = ops_offset
        self.asmaddr = asmaddr
        self.asmlen = asmlen
        self.rawstart = rawstart

class JitDebugInfo(object):
    """ An object representing debug info. Attributes meanings:

    greenkey - a list of green boxes or None for bridge
    logger - an instance of jit.metainterp.logger.LogOperations
    type - either 'loop', 'entry bridge' or 'bridge'
    looptoken - description of a loop
    fail_descr - fail descr or None
    asminfo - extra assembler information
    """

    asminfo = None
    def __init__(self, jitdriver_sd, logger, looptoken, operations, type,
                 greenkey=None, fail_descr=None):
        self.jitdriver_sd = jitdriver_sd
        self.logger = logger
        self.looptoken = looptoken
        self.operations = operations
        self.type = type
        if type == 'bridge':
            assert fail_descr is not None
        else:
            assert greenkey is not None
        self.greenkey = greenkey
        self.fail_descr = fail_descr

    def get_jitdriver(self):
        """ Return where the jitdriver on which the jitting started
        """
        return self.jitdriver_sd.jitdriver

    def get_greenkey_repr(self):
        """ Return the string repr of a greenkey
        """
        return self.jitdriver_sd.warmstate.get_location_str(self.greenkey)

class JitHookInterface(object):
    """ This is the main connector between the JIT and the interpreter.
    Several methods on this class will be invoked at various stages
    of JIT running like JIT loops compiled, aborts etc.
    An instance of this class has to be passed into the JitPolicy constructor
    (and will then be available as policy.jithookiface).
    """
    # WARNING: You should make a single prebuilt instance of a subclass
    # of this class.  You can, before translation, initialize some
    # attributes on this instance, and then read or change these
    # attributes inside the methods of the subclass.  But this prebuilt
    # instance *must not* be seen during the normal annotation/rtyping
    # of the program!  A line like ``pypy_hooks.foo = ...`` must not
    # appear inside your interpreter's RPython code.

    def are_hooks_enabled(self):
        """ A hook that is called to check whether the interpreter's hooks are
        enabled at all. Only if this function returns True, are the other hooks
        called. Otherwise, nothing happens. This is done because constructing
        some of the hooks' arguments is expensive, so we'd rather not do it."""
        return True

    def on_abort(self, reason, jitdriver, greenkey, greenkey_repr, logops, operations):
        """ A hook called each time a loop is aborted with jitdriver and
        greenkey where it started, reason is a string why it got aborted
        """

    def on_trace_too_long(self, jitdriver, greenkey, greenkey_repr):
        """ A hook called each time we abort the trace because it's too
        long with the greenkey being the one responsible for the
        disabled function
        """

    #def before_optimize(self, debug_info):
    #    """ A hook called before optimizer is run, called with instance of
    #    JitDebugInfo. Overwrite for custom behavior
    #    """
    # DISABLED

    def before_compile(self, debug_info):
        """ A hook called after a loop is optimized, before compiling assembler,
        called with JitDebugInfo instance. Overwrite for custom behavior
        """

    def after_compile(self, debug_info):
        """ A hook called after a loop has compiled assembler,
        called with JitDebugInfo instance. Overwrite for custom behavior
        """

    #def before_optimize_bridge(self, debug_info):
    #                           operations, fail_descr_no):
    #    """ A hook called before a bridge is optimized.
    #    Called with JitDebugInfo instance, overwrite for
    #    custom behavior
    #    """
    # DISABLED

    def before_compile_bridge(self, debug_info):
        """ A hook called before a bridge is compiled, but after optimizations
        are performed. Called with instance of debug_info, overwrite for
        custom behavior
        """

    def after_compile_bridge(self, debug_info):
        """ A hook called after a bridge is compiled, called with JitDebugInfo
        instance, overwrite for custom behavior
        """

def record_exact_class(value, cls):
    """
    Assure the JIT that value is an instance of cls. This is a precise
    class check, like a guard_class.

    See also debug.ll_assert_not_none(x), which asserts that x is not None
    and also assures the JIT that it is the case.
    """
    assert type(value) is cls

def ll_record_exact_class(ll_value, ll_cls):
    from rpython.rlib.debug import ll_assert
    from rpython.rtyper.lltypesystem.lloperation import llop
    from rpython.rtyper.lltypesystem import lltype
    from rpython.rtyper.rclass import ll_type
    ll_assert(ll_value != lltype.nullptr(lltype.typeOf(ll_value).TO), "record_exact_class called with None argument")
    ll_assert(ll_type(ll_value) is ll_cls, "record_exact_class called with invalid arguments")
    llop.jit_record_exact_class(lltype.Void, ll_value, ll_cls)


class Entry(ExtRegistryEntry):
    _about_ = record_exact_class

    def compute_result_annotation(self, s_inst, s_cls):
        from rpython.annotator import model as annmodel
        assert not s_inst.can_be_none()
        assert isinstance(s_inst, annmodel.SomeInstance)

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        from rpython.rtyper import rclass

        classrepr = rclass.get_type_repr(hop.rtyper)
        v_inst = hop.inputarg(hop.args_r[0], arg=0)
        v_cls = hop.inputarg(classrepr, arg=1)
        hop.exception_is_here()
        return hop.gendirectcall(ll_record_exact_class, v_inst, v_cls)

def _jit_conditional_call(condition, function, *args):
    pass           # special-cased below

@specialize.call_location()
def conditional_call(condition, function, *args):
    """Does the same as:

         if condition:
             function(*args)

    but is better for the JIT, in case the condition is often false
    but could be true occasionally.  It allows the JIT to always produce
    bridge-free code.  The function is never looked inside.
    """
    if we_are_jitted():
        _jit_conditional_call(condition, function, *args)
    else:
        if condition:
            function(*args)
conditional_call._always_inline_ = 'try'

def _jit_conditional_call_value(value, function, *args):
    return value    # special-cased below

@specialize.call_location()
def conditional_call_elidable(value, function, *args):
    """Does the same as:

        if value == <0 or None or NULL>:
            value = function(*args)
        return value

    For the JIT.  Allows one branch which doesn't create a bridge,
    typically used for caching.  The value and the function's return
    type must match and cannot be a float: they must be either regular
    'int', or something that turns into a pointer.

    Even if the function is not marked @elidable, it is still treated
    mostly like one.  The only difference is that (in heapcache.py)
    we don't assume this function won't change anything observable.
    This is useful for caches, as you can write:

        def _compute_and_cache(...):
            self.cache = ...compute...
            return self.cache

        x = jit.conditional_call_elidable(self.cache, _compute_and_cache, ...)

    """
    if we_are_translated() and we_are_jitted():
        #^^^ the occasional test patches we_are_jitted() to True
        return _jit_conditional_call_value(value, function, *args)
    else:
        if isinstance(value, int):
            if value == 0:
                value = function(*args)
                assert isinstance(value, int)
        else:
            if not isinstance(value, list) and not value:
                value = function(*args)
                assert not isinstance(value, int)
        return value
conditional_call_elidable._always_inline_ = 'try'

class ConditionalCallEntry(ExtRegistryEntry):
    _about_ = _jit_conditional_call, _jit_conditional_call_value

    def compute_result_annotation(self, *args_s):
        s_res = self.bookkeeper.emulate_pbc_call(self.bookkeeper.position_key,
                                                 args_s[1], args_s[2:])
        if self.instance == _jit_conditional_call_value:
            from rpython.annotator import model as annmodel
            # the result is either s_res, i.e. the function result, or
            # it is args_s[0]-but-not-none.  The "not-none" part is
            # only useful for pointer-like types, but it means that
            # args_s[0] could be NULL without the result of the whole
            # conditional_call_elidable() necessarily returning a result
            # that can be NULL.
            return annmodel.unionof(s_res, args_s[0].nonnoneify())

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype

        if self.instance == _jit_conditional_call:
            opname = 'jit_conditional_call'
            COND = lltype.Bool
            resulttype = None
        elif self.instance == _jit_conditional_call_value:
            opname = 'jit_conditional_call_value'
            COND = hop.r_result
            resulttype = hop.r_result.lowleveltype
        else:
            assert False
        args_v = hop.inputargs(COND, lltype.Void, *hop.args_r[2:])
        args_v[1] = hop.args_r[1].get_concrete_llfn(hop.args_s[1],
                                                    hop.args_s[2:], hop.spaceop)
        hop.exception_is_here()
        return hop.genop(opname, args_v, resulttype=resulttype)

def enter_portal_frame(unique_id):
    """call this when starting to interpret a function. calling this is not
    necessary for almost all interpreters. The only exception is stackless
    interpreters where the portal never calls itself.
    """
    from rpython.rtyper.lltypesystem import lltype
    from rpython.rtyper.lltypesystem.lloperation import llop
    llop.jit_enter_portal_frame(lltype.Void, unique_id)

def leave_portal_frame():
    """call this after the end of executing a function. calling this is not
    necessary for almost all interpreters. The only exception is stackless
    interpreters where the portal never calls itself.
    """
    from rpython.rtyper.lltypesystem import lltype
    from rpython.rtyper.lltypesystem.lloperation import llop
    llop.jit_leave_portal_frame(lltype.Void)

class Counters(object):
    counters="""
    TRACING
    BACKEND
    OPS
    HEAPCACHED_OPS
    RECORDED_OPS
    GUARDS
    OPT_OPS
    OPT_GUARDS
    OPT_GUARDS_SHARED
    OPT_FORCINGS
    OPT_VECTORIZE_TRY
    OPT_VECTORIZED
    ABORT_TOO_LONG
    ABORT_BRIDGE
    ABORT_BAD_LOOP
    ABORT_ESCAPE
    ABORT_FORCE_QUASIIMMUT
    ABORT_SEGMENTED_TRACE
    NVIRTUALS
    NVHOLES
    NVREUSED
    TOTAL_COMPILED_LOOPS
    TOTAL_COMPILED_BRIDGES
    TOTAL_FREED_LOOPS
    TOTAL_FREED_BRIDGES
    """

    counter_names = []

    @staticmethod
    def _setup():
        names = Counters.counters.split()
        for i, name in enumerate(names):
            setattr(Counters, name, i)
            Counters.counter_names.append(name)
        Counters.ncounters = len(names)

Counters._setup()
