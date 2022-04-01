"""
This file defines utilities for manipulating objects in an
RPython-compliant way.
"""

from __future__ import absolute_import

import sys
import types
import math
import inspect
from collections import OrderedDict

from rpython.tool.sourcetools import rpython_wrapper, func_with_new_name
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.flowspace.specialcase import register_flow_sc
from rpython.flowspace.model import Constant

# specialize is a decorator factory for attaching _annspecialcase_
# attributes to functions: for example
#
# f._annspecialcase_ = 'specialize:memo' can be expressed with:
# @specialize.memo()
# def f(...
#
# f._annspecialcase_ = 'specialize:arg(0)' can be expressed with:
# @specialize.arg(0)
# def f(...
#


class _Specialize(object):
    def memo(self):
        """ Specialize the function based on argument values.  All arguments
        have to be either constants or PBCs (i.e. instances of classes with a
        _freeze_ method returning True).  The function call is replaced by
        just its result, or in case several PBCs are used, by some fast
        look-up of the result.
        """
        def decorated_func(func):
            func._annspecialcase_ = 'specialize:memo'
            return func
        return decorated_func

    def arg(self, *args):
        """ Specialize the function based on the values of given positions
        of arguments.  They must be compile-time constants in order to work.

        There will be a copy of provided function for each combination
        of given arguments on positions in args (that can lead to
        exponential behavior!).
        """
        def decorated_func(func):
            func._annspecialcase_ = 'specialize:arg' + self._wrap(args)
            return func

        return decorated_func

    def arg_or_var(self, *args):
        """ Same as arg, but additionally allow for a 'variable' annotation,
        that would simply be a situation where designated arg is not
        a constant
        """
        def decorated_func(func):
            func._annspecialcase_ = 'specialize:arg_or_var' + self._wrap(args)
            return func

        return decorated_func

    def argtype(self, *args):
        """ Specialize function based on types of arguments on given positions.

        There will be a copy of provided function for each combination
        of given arguments on positions in args (that can lead to
        exponential behavior!).
        """
        def decorated_func(func):
            func._annspecialcase_ = 'specialize:argtype' + self._wrap(args)
            return func

        return decorated_func

    def ll(self):
        """ This is version of argtypes that cares about low-level types
        (so it'll get additional copies for two different types of pointers
        for example). Same warnings about exponential behavior apply.
        """
        def decorated_func(func):
            func._annspecialcase_ = 'specialize:ll'
            return func

        return decorated_func

    def ll_and_arg(self, *args):
        """ This is like ll(), and additionally like arg(...).
        """
        def decorated_func(func):
            func._annspecialcase_ = 'specialize:ll_and_arg' + self._wrap(args)
            return func

        return decorated_func

    def call_location(self):
        """ Specializes the function for each call site.
        """
        def decorated_func(func):
            func._annspecialcase_ = "specialize:call_location"
            return func

        return decorated_func

    def _wrap(self, args):
        return "("+','.join([repr(arg) for arg in args]) +")"

specialize = _Specialize()

NOT_CONSTANT = object()      # to use in enforceargs()

def enforceargs(*types_, **kwds):
    """ Decorate a function with forcing of RPython-level types on arguments.
    None means no enforcing.

    When not translated, the type of the actual arguments is checked against
    the enforced types every time the function is called. You can disable the
    typechecking by passing ``typecheck=False`` to @enforceargs.
    """
    typecheck = kwds.pop('typecheck', True)
    if types_ and kwds:
        raise TypeError('Cannot mix positional arguments and keywords')

    if not typecheck:
        def decorator(f):
            f._annenforceargs_ = types_
            return f
        return decorator
    #
    def decorator(f):
        def get_annotation(t):
            from rpython.annotator.signature import annotation
            from rpython.annotator.model import SomeObject
            if isinstance(t, SomeObject):
                return t
            return annotation(t)

        def get_type_descr_of_argument(arg):
            # we don't want to check *all* the items in list/dict: we assume
            # they are already homogeneous, so we only check the first
            # item. The case of empty list/dict is handled inside typecheck()
            if isinstance(arg, list):
                return [get_type_descr_of_argument(arg[0])]
            elif isinstance(arg, dict):
                key, value = next(arg.iteritems())
                return {get_type_descr_of_argument(key): get_type_descr_of_argument(value)}
            else:
                return type(arg)

        def typecheck(*args):
            from rpython.annotator.model import SomeList, SomeDict, SomeChar,\
                 SomeInteger
            for i, (s_expected, arg) in enumerate(zip(s_types, args)):
                if s_expected is None:
                    continue
                # special case: if we expect a list or dict and the argument
                # is an empty list/dict, the typecheck always pass
                if isinstance(s_expected, SomeList) and arg == []:
                    continue
                if isinstance(s_expected, SomeDict) and arg == {}:
                    continue
                if isinstance(s_expected, SomeChar) and (
                        isinstance(arg, str) and len(arg) == 1):   # a char
                    continue
                if (isinstance(s_expected, SomeInteger) and
                    isinstance(arg, s_expected.knowntype)):
                    continue
                #
                s_argtype = get_annotation(get_type_descr_of_argument(arg))
                if not s_expected.contains(s_argtype):
                    msg = "%s argument %r must be of type %s" % (
                        f.__name__, srcargs[i], types[i])
                    raise TypeError(msg)
        #
        template = """
            def {name}({arglist}):
                if not we_are_translated():
                    typecheck({arglist})    # rpython.rlib.objectmodel
                return {original}({arglist})
        """
        result = rpython_wrapper(f, template,
                                 typecheck=typecheck,
                                 we_are_translated=we_are_translated)
        #
        srcargs, srcvarargs, srckeywords, defaults = inspect.getargspec(f)
        if kwds:
            types = tuple([kwds.get(arg) for arg in srcargs])
        else:
            types = types_
        assert len(srcargs) == len(types), (
            'not enough types provided: expected %d, got %d' %
            (len(types), len(srcargs)))

        s_types = [None if typ is None else
                   NOT_CONSTANT if typ is NOT_CONSTANT else
                   get_annotation(typ) for typ in types]
        result._annenforceargs_ = types
        return result
    return decorator

def always_inline(func):
    """ mark the function as to-be-inlined by the RPython optimizations (not
    the JIT!), no matter its size."""
    func._always_inline_ = True
    return func

def dont_inline(func):
    """ mark the function as never-to-be-inlined by the RPython optimizations
    (not the JIT!), no matter its size."""
    func._dont_inline_ = True
    return func

def try_inline(func):
    """ tell the RPython inline (not the JIT!), to try to inline this function,
    no matter its size."""
    func._always_inline_ = 'try'
    return func

def not_rpython(func):
    """ mark a function as not rpython. the translation process will raise an
    error if it encounters the function. """
    # test is in annotator/test/test_annrpython.py
    func._not_rpython_ = True
    return func

def llhelper_error_value(error_value):
    """
    This decorator has two effects:

      1. declare that this llhelper can raise RPython exceptions, which should
         be correctly propagated

      2. specify the error_value to return in case of exception.
    """
    # relevant tests:
    #     - test_ll2ctypes.test_llhelper_error_value
    #     - test_exceptiontransform.test_custom_error_value
    def decorate(func):
        func._llhelper_error_value_ = error_value
        return func
    return decorate

# ____________________________________________________________

class Symbolic(object):

    def annotation(self):
        return None

    def lltype(self):
        return None

    def __cmp__(self, other):
        if self is other:
            return 0
        else:
            raise TypeError("Symbolics cannot be compared! (%r, %r)"
                            % (self, other))

    def __hash__(self):
        raise TypeError("Symbolics are not hashable! %r" % (self,))

    def __nonzero__(self):
        raise TypeError("Symbolics are not comparable! %r" % (self,))

class ComputedIntSymbolic(Symbolic):

    def __init__(self, compute_fn):
        self.compute_fn = compute_fn

    def __repr__(self):
        # repr(self.compute_fn) can arrive back here in an
        # infinite recursion
        try:
            name = self.compute_fn.__name__
        except (AttributeError, TypeError):
            name = hex(id(self.compute_fn))
        return '%s(%r)' % (self.__class__.__name__, name)

    def annotation(self):
        from rpython.annotator import model
        return model.SomeInteger()

    def lltype(self):
        from rpython.rtyper.lltypesystem import lltype
        return lltype.Signed

class CDefinedIntSymbolic(Symbolic):

    def __init__(self, expr, default=0):
        self.expr = expr
        self.default = default

    def __repr__(self):
        return '%s(%r)' % (self.__class__.__name__, self.expr)

    def annotation(self):
        from rpython.annotator import model
        return model.SomeInteger()

    def lltype(self):
        from rpython.rtyper.lltypesystem import lltype
        return lltype.Signed

malloc_zero_filled = CDefinedIntSymbolic('MALLOC_ZERO_FILLED', default=0)
_translated_to_c = CDefinedIntSymbolic('1 /*_translated_to_c*/', default=0)

def we_are_translated_to_c():
    return we_are_translated() and _translated_to_c

# ____________________________________________________________

def instantiate(cls, nonmovable=False):
    "Create an empty instance of 'cls'."
    if isinstance(cls, type):
        return cls.__new__(cls)
    else:
        return types.InstanceType(cls)

def we_are_translated():
    return False

@register_flow_sc(we_are_translated)
def sc_we_are_translated(ctx):
    return Constant(True)

def register_replacement_for(replaced_function, sandboxed_name=None):
    def wrap(func):
        from rpython.rtyper.extregistry import ExtRegistryEntry
        # to support calling func directly
        func._sandbox_external_name = sandboxed_name
        class ExtRegistry(ExtRegistryEntry):
            _about_ = replaced_function
            def compute_annotation(self):
                if sandboxed_name:
                    config = self.bookkeeper.annotator.translator.config
                    if config.translation.sandbox:
                        func._sandbox_external_name = sandboxed_name
                        func._dont_inline_ = True
                return self.bookkeeper.immutablevalue(func)
        return func
    return wrap

def keepalive_until_here(*values):
    pass

def is_annotation_constant(thing):
    """ Returns whether the annotator can prove that the argument is constant.
    For advanced usage only."""
    return True

class Entry(ExtRegistryEntry):
    _about_ = is_annotation_constant

    def compute_result_annotation(self, s_arg):
        from rpython.annotator import model
        r = model.SomeBool()
        r.const = s_arg.is_constant()
        return r

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Bool, hop.s_result.const)

def int_to_bytearray(i):
    # XXX this can be made more efficient in the future
    return bytearray(str(i))

def fetch_translated_config():
    """Returns the config that is current when translating.
    Returns None if not translated.
    """
    return None

class Entry(ExtRegistryEntry):
    _about_ = fetch_translated_config

    def compute_result_annotation(self):
        config = self.bookkeeper.annotator.translator.config
        return self.bookkeeper.immutablevalue(config)

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        translator = hop.rtyper.annotator.translator
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Void, translator.config)


def revdb_flag_io_disabled():
    if not revdb_enabled():
        return False
    return _revdb_flag_io_disabled()

def _revdb_flag_io_disabled():
    # moved in its own function for the import statement
    from rpython.rlib import revdb
    return revdb.flag_io_disabled()

@not_rpython
def revdb_enabled():
    return False

class Entry(ExtRegistryEntry):
    _about_ = revdb_enabled

    def compute_result_annotation(self):
        from rpython.annotator import model as annmodel
        config = self.bookkeeper.annotator.translator.config
        if config.translation.reverse_debugger:
            return annmodel.s_True
        else:
            return annmodel.s_False

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Bool, hop.s_result.const)

# ____________________________________________________________

class FREED_OBJECT(object):
    def __getattribute__(self, attr):
        raise RuntimeError("trying to access freed object")
    def __setattr__(self, attr, value):
        raise RuntimeError("trying to access freed object")


def free_non_gc_object(obj):
    assert not getattr(obj.__class__, "_alloc_flavor_", 'gc').startswith('gc'), "trying to free gc object"
    obj.__dict__ = {}
    obj.__class__ = FREED_OBJECT

# ____________________________________________________________

def newlist_hint(sizehint=0):
    """ Create a new list, but pass a hint how big the size should be
    preallocated
    """
    return []

class Entry(ExtRegistryEntry):
    _about_ = newlist_hint

    def compute_result_annotation(self, s_sizehint):
        from rpython.annotator.model import SomeInteger, AnnotatorError

        if not isinstance(s_sizehint, SomeInteger):
            raise AnnotatorError("newlist_hint() argument must be an int")
        s_l = self.bookkeeper.newlist()
        s_l.listdef.listitem.resize()
        return s_l

    def specialize_call(self, orig_hop, i_sizehint=None):
        from rpython.rtyper.rlist import rtype_newlist
        # fish a bit hop
        hop = orig_hop.copy()
        v = hop.args_v[0]
        r, s = hop.r_s_popfirstarg()
        if s.is_constant():
            v = hop.inputconst(r, s.const)
        hop.exception_is_here()
        return rtype_newlist(hop, v_sizehint=v)

def resizelist_hint(l, sizehint):
    """Reallocate the underlying list to the specified sizehint"""
    return

class Entry(ExtRegistryEntry):
    _about_ = resizelist_hint

    def compute_result_annotation(self, s_l, s_sizehint):
        from rpython.annotator import model as annmodel
        if annmodel.s_None.contains(s_l):
            return   # first argument is only None so far, but we
                     # expect a generalization later
        if not isinstance(s_l, annmodel.SomeList):
            raise annmodel.AnnotatorError("First argument must be a list")
        if not isinstance(s_sizehint, annmodel.SomeInteger):
            raise annmodel.AnnotatorError("Second argument must be an integer")
        s_l.listdef.listitem.resize()

    def specialize_call(self, hop):
        r_list = hop.args_r[0]
        v_list, v_sizehint = hop.inputargs(*hop.args_r)
        hop.exception_is_here()
        hop.gendirectcall(r_list.LIST._ll_resize_hint, v_list, v_sizehint)

def list_get_physical_size(l):
    """ try to get the physical size of an overallocated RPython list. will
    return the regular length untranslated. """
    return len(l)

def ll_physical_size(l):
    return len(l.items)

class Entry(ExtRegistryEntry):
    _about_ = list_get_physical_size

    def compute_result_annotation(self, s_l):
        from rpython.annotator import model as annmodel
        if annmodel.s_None.contains(s_l):
            pass # first argument is only None so far, but we
                 # expect a generalization later
        elif not isinstance(s_l, annmodel.SomeList):
            raise annmodel.AnnotatorError("First argument must be a list")
        return annmodel.SomeInteger(nonneg=True)

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem.rlist import FixedSizeListRepr, ListRepr
        v_list, = hop.inputargs(*hop.args_r)
        if isinstance(hop.args_r[0], ListRepr):
            ll_func = ll_physical_size
        else:
            ll_func = v_list.concretetype.TO.ll_length
        hop.exception_cannot_occur()
        return hop.gendirectcall(ll_func, v_list)


# ____________________________________________________________
#
# id-like functions.  The idea is that calling hash() or id() is not
# allowed in RPython.  You have to call one of the following more
# precise functions.

def compute_hash(x):
    """RPython equivalent of hash(x), where 'x' is an immutable
    RPython-level.  For strings or unicodes it computes the hash as
    in Python.  For tuples it calls compute_hash() recursively.
    For instances it uses compute_identity_hash().

    Note that this can return 0 or -1 too.

    NOTE: It returns a different number before and after translation!
    Dictionaries will be rehashed when the translated program starts.
    Be careful about other places that store or depend on a hash value:
    if such a place can exist before translation, you should add for
    example a _cleanup_() method to clear this cache during translation.

    (Nowadays we could completely remove compute_hash() and decide that
    hash(x) is valid RPython instead, at least for the types listed here.)
    """
    if isinstance(x, (str, unicode)):
        return _hash_string(x)
    if isinstance(x, int):
        return x
    if isinstance(x, float):
        return _hash_float(x)
    if isinstance(x, tuple):
        return _hash_tuple(x)
    if x is None:
        return 0
    return compute_identity_hash(x)

def compute_identity_hash(x):
    """RPython equivalent of object.__hash__(x).  This returns the
    so-called 'identity hash', which is the non-overridable default hash
    of Python.  Can be called for any RPython-level object that turns
    into a GC object, but not NULL.  The value will be different before
    and after translation (WARNING: this is a change with older RPythons!)
    """
    assert x is not None
    return object.__hash__(x)

def compute_unique_id(x):
    """RPython equivalent of id(x).  The 'x' must be an RPython-level
    object that turns into a GC object.  This operation can be very
    costly depending on the garbage collector.  To remind you of this
    fact, we don't support id(x) directly.
    """
    # The assumption with RPython is that a regular integer is wide enough
    # to store a pointer.  The following intmask() should not loose any
    # information.
    from rpython.rlib.rarithmetic import intmask
    return intmask(id(x))

def current_object_addr_as_int(x):
    """A cheap version of id(x).

    The current memory location of an object can change over time for moving
    GCs.
    """
    from rpython.rlib.rarithmetic import intmask
    return intmask(id(x))

# ----------

@specialize.ll()
def _hash_string(s):
    """The default algorithm behind compute_hash() for a string or a unicode.
    This is a modified Fowler-Noll-Vo (FNV) hash.  According to Wikipedia,
    FNV needs carefully-computed constants called FNV primes and FNV offset
    basis, which are absent from the present algorithm.  Nevertheless,
    this matches CPython 2.7 without -R, which has proven a good hash in
    practice (even if not crypographical nor randomizable).

    There is a mechanism to use another one in programs after translation.
    See rsiphash.py, which implements the algorithm of CPython >= 3.4.
    """
    from rpython.rlib.rarithmetic import intmask

    length = len(s)
    if length == 0:
        return -1
    x = ord(s[0]) << 7
    i = 0
    while i < length:
        x = intmask((1000003*x) ^ ord(s[i]))
        i += 1
    x ^= length
    return intmask(x)

def ll_hash_string(ll_s):
    return _hash_string(ll_s.chars)

def _hash_float(f):
    """The algorithm behind compute_hash() for a float.
    This implementation is identical to the CPython implementation,
    except the fact that the integer case is not treated specially.
    In RPython, floats cannot be used with ints in dicts, anyway.
    """
    from rpython.rlib.rarithmetic import intmask
    from rpython.rlib.rfloat import isfinite
    if not isfinite(f):
        if math.isinf(f):
            if f < 0.0:
                return -271828
            else:
                return 314159
        else: #isnan(f):
            return 0
    v, expo = math.frexp(f)
    v *= TAKE_NEXT
    hipart = int(v)
    v = (v - float(hipart)) * TAKE_NEXT
    x = hipart + int(v) + (expo << 15)
    return intmask(x)
TAKE_NEXT = float(2**31)

@not_rpython
def _hash_tuple(t):
    """The algorithm behind compute_hash() for a tuple.
    It is modelled after the old algorithm of Python 2.3, which is
    a bit faster than the one introduced by Python 2.4.  We assume
    that nested tuples are very uncommon in RPython, making the bad
    case unlikely.
    """
    from rpython.rlib.rarithmetic import intmask
    x = 0x345678
    for item in t:
        y = compute_hash(item)
        x = intmask((1000003 * x) ^ y)
    return x

# ----------

class Entry(ExtRegistryEntry):
    _about_ = compute_hash

    def compute_result_annotation(self, s_x):
        from rpython.annotator import model as annmodel
        return annmodel.SomeInteger()

    def specialize_call(self, hop):
        r_obj, = hop.args_r
        v_obj, = hop.inputargs(r_obj)
        ll_fn = r_obj.get_ll_hash_function()
        hop.exception_is_here()
        return hop.gendirectcall(ll_fn, v_obj)

class Entry(ExtRegistryEntry):
    _about_ = ll_hash_string
    # this is only used when annotating the code in rstr.py, and so
    # it always occurs after the RPython program signalled its intent
    # to use a different hash.  The code below overwrites the use of
    # ll_hash_string() to make the annotator think a possibly different
    # function was called.

    def compute_annotation(self):
        from rpython.annotator import model as annmodel
        bk = self.bookkeeper
        translator = bk.annotator.translator
        fn = getattr(translator, 'll_hash_string', ll_hash_string)
        return annmodel.SomePBC([bk.getdesc(fn)])

class Entry(ExtRegistryEntry):
    _about_ = compute_identity_hash

    def compute_result_annotation(self, s_x):
        from rpython.annotator import model as annmodel
        return annmodel.SomeInteger()

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        vobj, = hop.inputargs(hop.args_r[0])
        ok = (isinstance(vobj.concretetype, lltype.Ptr) and
                vobj.concretetype.TO._gckind == 'gc')
        if not ok:
            from rpython.rtyper.error import TyperError
            raise TyperError("compute_identity_hash() cannot be applied to"
                             " %r" % (vobj.concretetype,))
        hop.exception_cannot_occur()
        return hop.genop('gc_identityhash', [vobj], resulttype=lltype.Signed)

class Entry(ExtRegistryEntry):
    _about_ = compute_unique_id

    def compute_result_annotation(self, s_x):
        from rpython.annotator import model as annmodel
        return annmodel.SomeInteger()

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        vobj, = hop.inputargs(hop.args_r[0])
        ok = (isinstance(vobj.concretetype, lltype.Ptr) and
                vobj.concretetype.TO._gckind == 'gc')
        if not ok:
            from rpython.rtyper.error import TyperError
            raise TyperError("compute_unique_id() cannot be applied to"
                             " %r" % (vobj.concretetype,))
        hop.exception_cannot_occur()
        return hop.genop('gc_id', [vobj], resulttype=lltype.Signed)

class Entry(ExtRegistryEntry):
    _about_ = current_object_addr_as_int

    def compute_result_annotation(self, s_x):
        from rpython.annotator import model as annmodel
        return annmodel.SomeInteger()

    def specialize_call(self, hop):
        vobj, = hop.inputargs(hop.args_r[0])
        hop.exception_cannot_occur()
        from rpython.rtyper.lltypesystem import lltype
        if isinstance(vobj.concretetype, lltype.Ptr):
            return hop.genop('cast_ptr_to_int', [vobj],
                                resulttype = lltype.Signed)
        from rpython.rtyper.error import TyperError
        raise TyperError("current_object_addr_as_int() cannot be applied to"
                         " %r" % (vobj.concretetype,))

# ____________________________________________________________

def hlinvoke(repr, llcallable, *args):
    raise TypeError("hlinvoke is meant to be rtyped and not called direclty")


class UnboxedValue(object):
    """A mixin class to use for classes that have exactly one field which
    is an integer.  They are represented as a tagged pointer, if the
    translation.taggedpointers config option is used."""
    _mixin_ = True

    def __new__(cls, value):
        assert '__init__' not in cls.__dict__  # won't be called anyway
        assert isinstance(cls.__slots__, str) or len(cls.__slots__) == 1
        return super(UnboxedValue, cls).__new__(cls)

    def __init__(self, value):
        # this funtion is annotated but not included in the translated program
        int_as_pointer = value * 2 + 1   # XXX for now
        if -sys.maxint-1 <= int_as_pointer <= sys.maxint:
            if isinstance(self.__class__.__slots__, str):
                setattr(self, self.__class__.__slots__, value)
            else:
                setattr(self, self.__class__.__slots__[0], value)
        else:
            raise OverflowError("UnboxedValue: argument out of range")

    def __repr__(self):
        return '<unboxed %d>' % (self.get_untagged_value(),)

    def get_untagged_value(self):   # helper, equivalent to reading the custom field
        if isinstance(self.__class__.__slots__, str):
            return getattr(self, self.__class__.__slots__)
        else:
            return getattr(self, self.__class__.__slots__[0])

# ____________________________________________________________

def likely(condition):
    assert isinstance(condition, bool)
    return condition

def unlikely(condition):
    assert isinstance(condition, bool)
    return condition

class Entry(ExtRegistryEntry):
    _about_ = (likely, unlikely)

    def compute_result_annotation(self, s_x):
        from rpython.annotator import model as annmodel
        return annmodel.SomeBool()

    def specialize_call(self, hop):
        from rpython.rtyper.lltypesystem import lltype
        vlist = hop.inputargs(lltype.Bool)
        hop.exception_cannot_occur()
        return hop.genop(self.instance.__name__, vlist,
                         resulttype=lltype.Bool)

# ____________________________________________________________


class r_dict(object):
    """An RPython dict-like object.
    Only provides the interface supported by RPython.
    The functions key_eq() and key_hash() are used by the key comparison
    algorithm."""

    def _newdict(self):
        return {}

    def __init__(self, key_eq, key_hash, force_non_null=False, simple_hash_eq=False):
        """ force_non_null=True means that the key can never be None (even if
        the annotator things it could be)

        simple_hash_eq=True means that the hash function is very fast, meaning it's
        efficient enough that the dict does not have to store the hash per key.
        It also implies that neither the hash nor the eq function will mutate
        the dictionary. """
        self._dict = self._newdict()
        self.key_eq = key_eq
        self.key_hash = key_hash
        self.force_non_null = force_non_null
        self.simple_hash_eq = simple_hash_eq

    def __getitem__(self, key):
        return self._dict[_r_dictkey(self, key)]

    def __setitem__(self, key, value):
        self._dict[_r_dictkey(self, key)] = value

    def __delitem__(self, key):
        del self._dict[_r_dictkey(self, key)]

    def __len__(self):
        return len(self._dict)

    def __iter__(self):
        for dk in self._dict:
            yield dk.key

    def __contains__(self, key):
        return _r_dictkey(self, key) in self._dict

    def get(self, key, default):
        return self._dict.get(_r_dictkey(self, key), default)

    def setdefault(self, key, default):
        return self._dict.setdefault(_r_dictkey(self, key), default)

    def pop(self, key, *default):
        return self._dict.pop(_r_dictkey(self, key), *default)

    def popitem(self):
        dk, value = self._dict.popitem()
        return dk.key, value

    def copy(self):
        result = self.__class__(self.key_eq, self.key_hash)
        result.update(self)
        return result

    def update(self, other):
        for key, value in other.items():
            self[key] = value

    def keys(self):
        return [dk.key for dk in self._dict]

    def values(self):
        return self._dict.values()

    def items(self):
        return [(dk.key, value) for dk, value in self._dict.items()]

    iterkeys = __iter__

    def itervalues(self):
        return self._dict.itervalues()

    def iteritems(self):
        for dk, value in self._dict.items():
            yield dk.key, value

    def clear(self):
        self._dict.clear()

    def __repr__(self):
        "Representation for debugging purposes."
        return 'r_dict(%r)' % (self._dict,)

    def __hash__(self):
        raise TypeError("cannot hash r_dict instances")

class r_ordereddict(r_dict):
    def _newdict(self):
        return OrderedDict()

class _r_dictkey(object):
    __slots__ = ['dic', 'key', 'hash']
    def __init__(self, dic, key):
        self.dic = dic
        self.key = key
        self.hash = dic.key_hash(key)
    def __eq__(self, other):
        if not isinstance(other, _r_dictkey):
            return NotImplemented
        return self.dic.key_eq(self.key, other.key)
    def __ne__(self, other):
        if not isinstance(other, _r_dictkey):
            return NotImplemented
        return not self.dic.key_eq(self.key, other.key)
    def __hash__(self):
        return self.hash

    def __repr__(self):
        return repr(self.key)


@specialize.call_location()
def prepare_dict_update(dict, n_elements):
    """RPython hint that the given dict (or r_dict) will soon be
    enlarged by n_elements."""
    if we_are_translated():
        dict._prepare_dict_update(n_elements)
        # ^^ call an extra method that doesn't exist before translation

@specialize.call_location()
def reversed_dict(d):
    """Equivalent to reversed(ordered_dict), but works also for
    regular dicts."""
    # note that there is also __pypy__.reversed_dict(), which we could
    # try to use here if we're not translated and running on top of pypy,
    # but that seems a bit pointless
    if not we_are_translated():
        d = d.keys()
    return reversed(d)

def _expected_hash(d, key):
    if isinstance(d, r_dict):
        return d.key_hash(key)
    else:
        return compute_hash(key)

def _iterkeys_with_hash_untranslated(d):
    for k in d:
        yield (k, _expected_hash(d, k))

@specialize.call_location()
def iterkeys_with_hash(d):
    """Iterates (key, hash) pairs without recomputing the hash."""
    if not we_are_translated():
        return _iterkeys_with_hash_untranslated(d)
    return d.iterkeys_with_hash()

def _iteritems_with_hash_untranslated(d):
    for k, v in d.iteritems():
        yield (k, v, _expected_hash(d, k))

@specialize.call_location()
def iteritems_with_hash(d):
    """Iterates (key, value, keyhash) triples without recomputing the hash."""
    if not we_are_translated():
        return _iteritems_with_hash_untranslated(d)
    return d.iteritems_with_hash()

@specialize.call_location()
def contains_with_hash(d, key, h):
    """Same as 'key in d'.  The extra argument is the hash.  Use this only
    if you got the hash just now from some other ..._with_hash() function."""
    if not we_are_translated():
        assert _expected_hash(d, key) == h
        return key in d
    return d.contains_with_hash(key, h)

@specialize.call_location()
def setitem_with_hash(d, key, h, value):
    """Same as 'd[key] = value'.  The extra argument is the hash.  Use this only
    if you got the hash just now from some other ..._with_hash() function."""
    if not we_are_translated():
        assert _expected_hash(d, key) == h
        d[key] = value
        return
    d.setitem_with_hash(key, h, value)

@specialize.call_location()
def getitem_with_hash(d, key, h):
    """Same as 'd[key]'.  The extra argument is the hash.  Use this only
    if you got the hash just now from some other ..._with_hash() function."""
    if not we_are_translated():
        assert _expected_hash(d, key) == h
        return d[key]
    return d.getitem_with_hash(key, h)

@specialize.call_location()
def delitem_with_hash(d, key, h):
    """Same as 'del d[key]'.  The extra argument is the hash.  Use this only
    if you got the hash just now from some other ..._with_hash() function."""
    if not we_are_translated():
        assert _expected_hash(d, key) == h
        del d[key]
        return
    d.delitem_with_hash(key, h)

@specialize.call_location()
def delitem_if_value_is(d, key, value):
    """Same as 'if d.get(key) is value: del d[key]'.  It is safe even in
    case 'd' is an r_dict and the lookup involves callbacks that might
    release the GIL."""
    if not we_are_translated():
        try:
            if d[key] is value:
                del d[key]
        except KeyError:
            pass
        return
    d.delitem_if_value_is(key, value)

def _untranslated_move_to_end(d, key, last):
    "NOT_RPYTHON"
    value = d.pop(key)
    if last:
        d[key] = value
    else:
        items = d.items()
        d.clear()
        d[key] = value
        # r_dict.update does not support list of tuples, do it manually
        for key, value in items:
            d[key] = value

@specialize.call_location()
def move_to_end(d, key, last=True):
    if not we_are_translated():
        _untranslated_move_to_end(d, key, last)
        return
    d.move_to_end(key, last)

# ____________________________________________________________

def import_from_mixin(M, special_methods=['__init__', '__del__']):
    """Copy all methods and class attributes from the class M into
    the current scope.  Should be called when defining a class body.
    Function and staticmethod objects are duplicated, which means
    that annotation will not consider them as identical to another
    copy in another unrelated class.

    By default, "special" methods and class attributes, with a name
    like "__xxx__", are not copied unless they are "__init__" or
    "__del__".  The list can be changed with the optional second
    argument.
    """
    flatten = {}
    caller = sys._getframe(1)
    caller_name = caller.f_globals.get('__name__')
    immutable_fields = []
    for base in inspect.getmro(M):
        if base is object:
            continue
        for key, value in base.__dict__.items():
            if key == '_immutable_fields_':
                immutable_fields.extend(value)
                continue
            if key.startswith('__') and key.endswith('__'):
                if key not in special_methods:
                    continue
            if key in flatten:
                continue
            if isinstance(value, types.FunctionType):
                value = func_with_new_name(value, value.__name__)
            elif isinstance(value, staticmethod):
                func = value.__get__(42)
                func = func_with_new_name(func, func.__name__)
                if caller_name:
                    # staticmethods lack a unique im_class so further
                    # distinguish them from themselves
                    func.__module__ = caller_name
                value = staticmethod(func)
            elif isinstance(value, classmethod):
                raise AssertionError("classmethods not supported "
                                     "in 'import_from_mixin'")
            flatten[key] = value
    #
    target = caller.f_locals
    for key, value in flatten.items():
        if key in target:
            raise Exception("import_from_mixin: would overwrite the value "
                            "already defined locally for %r" % (key,))
        if key == '_mixin_':
            raise Exception("import_from_mixin(M): class M should not "
                            "have '_mixin_ = True'")
        target[key] = value
    if immutable_fields:
        target['_immutable_fields_'] = target.get('_immutable_fields_', []) + immutable_fields

def never_allocate(cls):
    """
    Class decorator to ensure that a class is NEVER instantiated at runtime.

    Useful e.g for context manager which are expected to be constant-folded
    away.
    """
    cls._rpython_never_allocate_ = True
    return cls
