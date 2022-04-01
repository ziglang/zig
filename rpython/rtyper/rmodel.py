from rpython.annotator import model as annmodel, unaryop, binaryop, description
from rpython.flowspace.model import Constant
from rpython.rtyper.error import TyperError, MissingRTypeOperation
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lltype import Void, Bool, LowLevelType, Ptr
from rpython.tool.pairtype import pairtype, extendabletype, pair


# initialization states for Repr instances

class setupstate(object):
    NOTINITIALIZED = 0
    INPROGRESS = 1
    BROKEN = 2
    FINISHED = 3
    DELAYED = 4

class Repr(object):
    """ An instance of Repr is associated with each instance of SomeXxx.
    It defines the chosen representation for the SomeXxx.  The Repr subclasses
    generally follows the SomeXxx subclass hierarchy, but there are numerous
    exceptions.  For example, the annotator uses SomeIter for any iterator, but
    we need different representations according to the type of container we are
    iterating over.
    """
    __metaclass__ = extendabletype
    _initialized = setupstate.NOTINITIALIZED
    __NOT_RPYTHON__ = True

    def __repr__(self):
        return '<%s %s>' % (self.__class__.__name__, self.lowleveltype)

    def compact_repr(self):
        return '%s %s' % (self.__class__.__name__.replace('Repr','R'), self.lowleveltype._short_name())

    def setup(self):
        """ call _setup_repr() and keep track of the initializiation
            status to e.g. detect recursive _setup_repr invocations.
            the '_initialized' attr has four states:
        """
        if self._initialized == setupstate.FINISHED:
            return
        elif self._initialized == setupstate.BROKEN:
            raise BrokenReprTyperError(
                "cannot setup already failed Repr: %r" %(self,))
        elif self._initialized == setupstate.INPROGRESS:
            raise AssertionError(
                "recursive invocation of Repr setup(): %r" %(self,))
        elif self._initialized == setupstate.DELAYED:
            raise AssertionError(
                "Repr setup() is delayed and cannot be called yet: %r" %(self,))
        assert self._initialized == setupstate.NOTINITIALIZED
        self._initialized = setupstate.INPROGRESS
        try:
            self._setup_repr()
        except TyperError:
            self._initialized = setupstate.BROKEN
            raise
        else:
            self._initialized = setupstate.FINISHED

    def _setup_repr(self):
        "For recursive data structure, which must be initialized in two steps."

    def setup_final(self):
        """Same as setup(), called a bit later, for effects that are only
        needed after the typer finished (as opposed to needed for other parts
        of the typer itself)."""
        if self._initialized == setupstate.BROKEN:
            raise BrokenReprTyperError("cannot perform setup_final_touch "
                             "on failed Repr: %r" %(self,))
        assert self._initialized == setupstate.FINISHED, (
                "setup_final() on repr with state %s: %r" %
                (self._initialized, self))
        self._setup_repr_final()

    def _setup_repr_final(self):
        pass

    def is_setup_delayed(self):
        return self._initialized == setupstate.DELAYED

    def set_setup_delayed(self, flag):
        assert self._initialized in (setupstate.NOTINITIALIZED,
                                     setupstate.DELAYED)
        if flag:
            self._initialized = setupstate.DELAYED
        else:
            self._initialized = setupstate.NOTINITIALIZED

    def set_setup_maybe_delayed(self):
        if self._initialized == setupstate.NOTINITIALIZED:
            self._initialized = setupstate.DELAYED
        return self._initialized == setupstate.DELAYED

    def __getattr__(self, name):
        # Assume that when an attribute is missing, it's because setup() needs
        # to be called
        if not (name[:2] == '__' == name[-2:]):
            if self._initialized == setupstate.NOTINITIALIZED:
                self.setup()
                try:
                    return self.__dict__[name]
                except KeyError:
                    pass
        raise AttributeError("%s instance has no attribute %s" % (
            self.__class__.__name__, name))

    def _freeze_(self):
        return True

    def convert_desc_or_const(self, desc_or_const):
        if isinstance(desc_or_const, description.Desc):
            return self.convert_desc(desc_or_const)
        elif isinstance(desc_or_const, Constant):
            return self.convert_const(desc_or_const.value)
        else:
            raise TyperError("convert_desc_or_const expects a Desc"
                             "or Constant: %r" % desc_or_const)

    def convert_const(self, value):
        "Convert the given constant value to the low-level repr of 'self'."
        if not self.lowleveltype._contains_value(value):
            raise TyperError("convert_const(self = %r, value = %r)" % (
                self, value))
        return value

    def special_uninitialized_value(self):
        return None

    def get_ll_eq_function(self):
        """Return an eq(x,y) function to use to compare two low-level
        values of this Repr.
        This can return None to mean that simply using '==' is fine.
        """
        raise TyperError('no equality function for %r' % self)

    def get_ll_hash_function(self):
        """Return a hash(x) function for low-level values of this Repr.
        """
        raise TyperError('no hashing function for %r' % self)

    def get_ll_fasthash_function(self):
        """Return a 'fast' hash(x) function for low-level values of this
        Repr.  The function can assume that 'x' is already stored as a
        key in a dict.  get_ll_fasthash_function() should return None if
        the hash should rather be cached in the dict entry.
        """
        return None

    def can_ll_be_null(self, s_value):
        """Check if the low-level repr can take the value 0/NULL.
        The annotation s_value is provided as a hint because it may
        contain more information than the Repr.
        """
        return True   # conservative

    def get_ll_dummyval_obj(self, rtyper, s_value):
        """A dummy value is a special low-level value, not otherwise
        used.  It should not be the NULL value even if it is special.
        This returns either None, or a hashable object that has a
        (possibly lazy) attribute 'll_dummy_value'.
        The annotation s_value is provided as a hint because it may
        contain more information than the Repr.
        """
        T = self.lowleveltype
        if (isinstance(T, lltype.Ptr) and
            isinstance(T.TO, (lltype.Struct,
                              lltype.Array,
                              lltype.ForwardReference))):
            return DummyValueBuilder(rtyper, T.TO)
        else:
            return None

    def rtype_bltn_list(self, hop):
        raise TyperError('no list() support for %r' % self)

    def rtype_unichr(self, hop):
        raise TyperError('no unichr() support for %r' % self)

    # default implementation of some operations

    def rtype_getattr(self, hop):
        s_attr = hop.args_s[1]
        if s_attr.is_constant() and isinstance(s_attr.const, str):
            attr = s_attr.const
            s_obj = hop.args_s[0]
            if s_obj.find_method(attr) is None:
                raise TyperError("no method %s on %r" % (attr, s_obj))
            else:
                # implement methods (of a known name) as just their 'self'
                return hop.inputarg(self, arg=0)
        else:
            raise TyperError("getattr() with a non-constant attribute name")

    def rtype_str(self, hop):
        [v_self] = hop.inputargs(self)
        return hop.gendirectcall(self.ll_str, v_self)

    def rtype_bool(self, hop):
        try:
            vlen = self.rtype_len(hop)
        except MissingRTypeOperation:
            if not hop.s_result.is_constant():
                raise TyperError("rtype_bool(%r) not implemented" % (self,))
            return hop.inputconst(Bool, hop.s_result.const)
        else:
            return hop.genop('int_is_true', [vlen], resulttype=Bool)

    def rtype_isinstance(self, hop):
        hop.exception_cannot_occur()
        if hop.s_result.is_constant():
            return hop.inputconst(lltype.Bool, hop.s_result.const)

        if hop.args_s[1].is_constant() and hop.args_s[1].const in (str, list, unicode):
            if hop.args_s[0].knowntype not in (str, list, unicode):
                raise TyperError("isinstance(x, str/list/unicode) expects x to be known"
                                " statically to be a str/list/unicode or None")
            rstrlist = hop.args_r[0]
            vstrlist = hop.inputarg(rstrlist, arg=0)
            cnone = hop.inputconst(rstrlist, None)
            return hop.genop('ptr_ne', [vstrlist, cnone], resulttype=lltype.Bool)
        raise TyperError

    def rtype_hash(self, hop):
        ll_hash = self.get_ll_hash_function()
        v, = hop.inputargs(self)
        return hop.gendirectcall(ll_hash, v)

    def rtype_iter(self, hop):
        r_iter = self.make_iterator_repr()
        return r_iter.newiter(hop)

    def make_iterator_repr(self, *variant):
        raise TyperError("%s is not iterable" % (self,))

    def rtype_hint(self, hop):
        return hop.inputarg(hop.r_result, arg=0)

    # hlinvoke helpers

    def get_r_implfunc(self):
        raise TyperError("%s has no corresponding implementation function representation" % (self,))

    def get_s_callable(self):
        raise TyperError("%s is not callable or cannot reconstruct a pbc annotation for itself" % (self,))

def ll_hash_void(v):
    return 0


class CanBeNull(object):
    """A mix-in base class for subclasses of Repr that represent None as
    'null' and true values as non-'null'.
    """
    def rtype_bool(self, hop):
        if hop.s_result.is_constant():
            return hop.inputconst(Bool, hop.s_result.const)
        else:
            vlist = hop.inputargs(self)
            return hop.genop('ptr_nonzero', vlist, resulttype=Bool)


class IteratorRepr(Repr):
    """Base class of Reprs of any kind of iterator."""

    def rtype_iter(self, hop):    #   iter(iter(x))  <==>  iter(x)
        v_iter, = hop.inputargs(self)
        return v_iter

    def rtype_method_next(self, hop):
        return self.rtype_next(hop)


class __extend__(annmodel.SomeIterator):
    # NOTE: SomeIterator is for iterators over any container, not just list
    def rtyper_makerepr(self, rtyper):
        r_container = rtyper.getrepr(self.s_container)
        if self.variant and self.variant[0] == "enumerate":
            from rpython.rtyper.rrange import EnumerateIteratorRepr
            r_baseiter = r_container.make_iterator_repr()
            return EnumerateIteratorRepr(r_baseiter, self.variant[1])
        return r_container.make_iterator_repr(*self.variant)

    def rtyper_makekey(self):
        return self.__class__, self.s_container.rtyper_makekey(), self.variant


class __extend__(annmodel.SomeImpossibleValue):
    def rtyper_makerepr(self, rtyper):
        return impossible_repr

    def rtyper_makekey(self):
        return self.__class__,

# ____ generic binary operations _____________________________


class __extend__(pairtype(Repr, Repr)):

    def rtype_is_((robj1, robj2), hop):
        if hop.s_result.is_constant():
            return inputconst(Bool, hop.s_result.const)
        roriginal1 = robj1
        roriginal2 = robj2
        if robj1.lowleveltype is Void:
            robj1 = robj2
        elif robj2.lowleveltype is Void:
            robj2 = robj1
        if (not isinstance(robj1.lowleveltype, Ptr) or
                not isinstance(robj2.lowleveltype, Ptr)):
            raise TyperError('is of instances of the non-pointers: %r, %r' % (
                roriginal1, roriginal2))
        if robj1.lowleveltype != robj2.lowleveltype:
            raise TyperError('is of instances of different pointer types: %r, %r' % (
                roriginal1, roriginal2))

        v_list = hop.inputargs(robj1, robj2)
        return hop.genop('ptr_eq', v_list, resulttype=Bool)


    # default implementation for checked getitems

    def rtype_getitem_idx((r_c1, r_o1), hop):
        return pair(r_c1, r_o1).rtype_getitem(hop)


# ____________________________________________________________


def make_missing_op(rcls, opname):
    attr = 'rtype_' + opname
    if not hasattr(rcls, attr):
        def missing_rtype_operation(self, hop):
            raise MissingRTypeOperation("unimplemented operation: "
                                        "'%s' on %r" % (opname, self))
        setattr(rcls, attr, missing_rtype_operation)

for opname in unaryop.UNARY_OPERATIONS:
    make_missing_op(Repr, opname)

for opname in binaryop.BINARY_OPERATIONS:
    make_missing_op(pairtype(Repr, Repr), opname)

# not in BINARY_OPERATIONS
make_missing_op(pairtype(Repr, Repr), 'contains')

class __extend__(pairtype(Repr, Repr)):
    def convert_from_to((r_from, r_to), v, llops):
        return NotImplemented

# ____________________________________________________________

class VoidRepr(Repr):
    lowleveltype = Void
    def get_ll_eq_function(self): return None
    def get_ll_hash_function(self): return ll_hash_void
    get_ll_fasthash_function = get_ll_hash_function
    def ll_str(self, nothing): raise AssertionError("unreachable code")
impossible_repr = VoidRepr()

class __extend__(pairtype(Repr, VoidRepr)):
    def convert_from_to((r_from, r_to), v, llops):
        return inputconst(lltype.Void, None)

class SimplePointerRepr(Repr):
    "Convenience Repr for simple ll pointer types with no operation on them."

    def __init__(self, lowleveltype):
        self.lowleveltype = lowleveltype

    def convert_const(self, value):
        if value is not None:
            raise TyperError("%r only supports None as prebuilt constant, "
                             "got %r" % (self, value))
        return lltype.nullptr(self.lowleveltype.TO)

# ____________________________________________________________

def inputconst(reqtype, value):
    """Return a Constant with the given value, of the requested type,
    which can be a Repr instance or a low-level type.
    """
    if isinstance(reqtype, Repr):
        value = reqtype.convert_const(value)
        lltype = reqtype.lowleveltype
    elif isinstance(reqtype, LowLevelType):
        lltype = reqtype
    else:
        raise TypeError(repr(reqtype))
    if not lltype._contains_value(value):
        raise TyperError("inputconst(): expected a %r, got %r" %
                         (lltype, value))
    c = Constant(value)
    c.concretetype = lltype
    return c

class BrokenReprTyperError(TyperError):
    """ raised when trying to setup a Repr whose setup
        has failed already.
    """

def mangle(prefix, name):
    """Make a unique identifier from the prefix and the name.  The name
    is allowed to start with $."""
    if name.startswith('$'):
        return '%sinternal_%s' % (prefix, name[1:])
    else:
        return '%s_%s' % (prefix, name)

# __________ utilities __________

def getgcflavor(classdef):
    classdesc = classdef.classdesc
    alloc_flavor = classdesc.get_param('_alloc_flavor_', default='gc')
    return alloc_flavor

def externalvsinternal(rtyper, item_repr): # -> external_item_repr, (internal_)item_repr
    from rpython.rtyper import rclass
    if (isinstance(item_repr, rclass.InstanceRepr) and
        getattr(item_repr, 'gcflavor', 'gc') == 'gc'):
        return item_repr, rclass.getinstancerepr(rtyper, None)
    else:
        return item_repr, item_repr


class DummyValueBuilder(object):

    def __init__(self, rtyper, TYPE):
        self.rtyper = rtyper
        self.TYPE = TYPE

    def _freeze_(self):
        return True

    def __hash__(self):
        return hash(self.TYPE)

    def __eq__(self, other):
        return (isinstance(other, DummyValueBuilder) and
                self.rtyper is other.rtyper and
                self.TYPE == other.TYPE)

    def __ne__(self, other):
        return not (self == other)

    @property
    def ll_dummy_value(self):
        TYPE = self.TYPE
        try:
            return self.rtyper.cache_dummy_values[TYPE]
        except KeyError:
            # generate a dummy ptr to an immortal placeholder struct/array
            if TYPE._is_varsize():
                p = lltype.malloc(TYPE, 1, immortal=True)
            else:
                p = lltype.malloc(TYPE, immortal=True)
            self.rtyper.cache_dummy_values[TYPE] = p
            return p


# logging/warning

from rpython.tool.ansi_print import AnsiLogger

log = AnsiLogger("rtyper")

def warning(msg):
    log.WARNING(msg)
