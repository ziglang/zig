"""
This file defines the 'subset' SomeValue classes.

An instance of a SomeValue class stands for a Python object that has some
known properties, for example that is known to be a list of non-negative
integers.  Each instance can be considered as an object that is only
'partially defined'.  Another point of view is that each instance is a
generic element in some specific subset of the set of all objects.

"""

# Old terminology still in use here and there:
#    SomeValue means one of the SomeXxx classes in this file.
#    Cell is an instance of one of these classes.
#
# Think about cells as potato-shaped circles in a diagram:
#    ______________________________________________________
#   / SomeObject()                                         \
#  /   ___________________________          ______________  \
#  |  / SomeInteger(nonneg=False) \____    / SomeString() \  \
#  | /     __________________________  \   |              |  |
#  | |    / SomeInteger(nonneg=True) \ |   |      "hello" |  |
#  | |    |   0    42       _________/ |   \______________/  |
#  | \ -3 \________________/           /                     |
#  \  \                     -5   _____/                      /
#   \  \________________________/              3.1416       /
#    \_____________________________________________________/
#

from __future__ import absolute_import

import inspect
import math
import weakref
from types import BuiltinFunctionType, MethodType
from collections import OrderedDict, defaultdict

import rpython
from rpython.tool import descriptor
from rpython.tool.pairtype import pair, extendabletype, doubledispatch
from rpython.rlib.rarithmetic import r_uint, base_int, r_singlefloat, r_longfloat


class State(object):
    # A global attribute :-(  Patch it with 'True' to enable checking of
    # the no_nul attribute...
    check_str_without_nul = False
    allow_int_to_float = True
TLS = State()

class SomeObject(object):
    """The set of all objects.  Each instance stands
    for an arbitrary object about which nothing is known."""
    __metaclass__ = extendabletype
    immutable = False
    knowntype = object

    def __init__(self):
        assert type(self) is not SomeObject

    def __eq__(self, other):
        return (self.__class__ is other.__class__ and
                self.__dict__  == other.__dict__)

    def __ne__(self, other):
        return not (self == other)

    def __repr__(self):
        try:
            reprdict = TLS.reprdict
        except AttributeError:
            reprdict = TLS.reprdict = {}
        if self in reprdict:
            kwds = '...'
        else:
            reprdict[self] = True
            try:
                items = self.__dict__.items()
                items.sort()
                args = []
                for k, v in items:
                    m = getattr(self, 'fmt_' + k, repr)
                    r = m(v)
                    if r is not None:
                        args.append('%s=%s' % (k, r))
                kwds = ', '.join(args)
            finally:
                del reprdict[self]
        return '%s(%s)' % (self.__class__.__name__, kwds)

    def fmt_knowntype(self, t):
        return t.__name__

    def contains(self, other):
        if self == other:
            return True
        try:
            return union(self, other) == self
        except UnionError:
            return False

    def is_constant(self):
        d = self.__dict__
        return 'const' in d or 'const_box' in d

    def is_immutable_constant(self):
        return self.immutable and 'const' in self.__dict__

    # delegate accesses to 'const' to accesses to 'const_box.value',
    # where const_box is a Constant.  This is not a property, in order
    # to allow 'self.const = xyz' to work as well.
    class ConstAccessDelegator(object):
        def __get__(self, obj, cls=None):
            return obj.const_box.value
    const = ConstAccessDelegator()
    del ConstAccessDelegator

    def can_be_none(self):
        return True

    def noneify(self):
        raise UnionError(self, s_None)

    def nonnoneify(self):
        return self

@doubledispatch
def intersection(s_obj1, s_obj2):
    """Return the intersection of two annotations, or an over-approximation thereof"""
    raise NotImplementedError

@doubledispatch
def difference(s_obj1, s_obj2):
    """Return the set difference of two annotations, or an over-approximation thereof"""
    raise NotImplementedError


class SomeType(SomeObject):
    "Stands for a type.  We might not be sure which one it is."
    knowntype = type
    immutable = True

    def can_be_none(self):
        return False

class SomeTypeOf(SomeType):
    """The type of a variable"""
    def __init__(self, args_v):
        self.is_type_of = args_v

def typeof(args_v):
    if args_v:
        result = SomeTypeOf(args_v)
        if len(args_v) == 1:
            s_arg = args_v[0].annotation
            if isinstance(s_arg, SomeException) and len(s_arg.classdefs) == 1:
                cdef, = s_arg.classdefs
                result.const = cdef.classdesc.pyobj
        return result
    else:
        return SomeType()


class SomeFloat(SomeObject):
    "Stands for a float or an integer."
    knowntype = float   # if we don't know if it's a float or an int,
                        # pretend it's a float.
    immutable = True

    def __eq__(self, other):
        if (type(self) is SomeFloat and type(other) is SomeFloat and
            self.is_constant() and other.is_constant()):
            # NaN unpleasantness.
            if math.isnan(self.const) and math.isnan(other.const):
                return True
            # 0.0 vs -0.0 unpleasantness.
            if not self.const and not other.const:
                return math.copysign(1., self.const) == math.copysign(1., other.const)
            #
        return super(SomeFloat, self).__eq__(other)

    def can_be_none(self):
        return False


class SomeSingleFloat(SomeObject):
    "Stands for an r_singlefloat."
    # No operation supported, not even union with a regular float
    knowntype = r_singlefloat
    immutable = True

    def can_be_none(self):
        return False


class SomeLongFloat(SomeObject):
    "Stands for an r_longfloat."
    # No operation supported, not even union with a regular float
    knowntype = r_longfloat
    immutable = True

    def can_be_none(self):
        return False


class SomeInteger(SomeFloat):
    "Stands for an object which is known to be an integer."
    knowntype = int

    # size is in multiples of C's sizeof(long)!
    def __init__(self, nonneg=False, unsigned=None, knowntype=None):
        assert (knowntype is None or knowntype is int or
                issubclass(knowntype, base_int))
        if knowntype is None:
            if unsigned:
                knowntype = r_uint
            else:
                knowntype = int
        elif unsigned is not None:
            raise TypeError('Conflicting specification for SomeInteger')
        self.knowntype = knowntype
        unsigned = self.knowntype(-1) > 0
        self.nonneg = unsigned or nonneg
        self.unsigned = unsigned  # rpython.rlib.rarithmetic.r_uint


class SomeBool(SomeInteger):
    "Stands for true or false."
    knowntype = bool
    nonneg = True
    unsigned = False

    def __init__(self):
        pass

    def set_knowntypedata(self, knowntypedata):
        assert not hasattr(self, 'knowntypedata')
        for key, value in knowntypedata.items():
            if not value:
                del knowntypedata[key]
        if knowntypedata:
            self.knowntypedata = knowntypedata


class SomeStringOrUnicode(SomeObject):
    """Base class for shared implementation of SomeString,
    SomeUnicodeString and SomeByteArray.

    Cannot be an annotation."""

    immutable = True
    can_be_None = False
    no_nul = False  # No NUL character in the string.

    def __init__(self, can_be_None=False, no_nul=False):
        assert type(self) is not SomeStringOrUnicode
        if can_be_None:
            self.can_be_None = True
        if no_nul:
            assert self.immutable   #'no_nul' cannot be used with SomeByteArray
            self.no_nul = True

    def can_be_none(self):
        return self.can_be_None

    def __eq__(self, other):
        if self.__class__ is not other.__class__:
            return False
        d1 = self.__dict__
        d2 = other.__dict__
        if not TLS.check_str_without_nul:
            d1 = d1.copy()
            d1['no_nul'] = 0
            d2 = d2.copy()
            d2['no_nul'] = 0
        return d1 == d2

    def nonnoneify(self):
        return self.__class__(can_be_None=False, no_nul=self.no_nul)

    def nonnulify(self):
        if self.can_be_None:
            return self.__class__(can_be_None=True, no_nul=True)
        else:
            return self.__class__(no_nul=True)


class SomeString(SomeStringOrUnicode):
    "Stands for an object which is known to be a string."
    knowntype = str

    def noneify(self):
        return SomeString(can_be_None=True, no_nul=self.no_nul)


class SomeUnicodeString(SomeStringOrUnicode):
    "Stands for an object which is known to be an unicode string"
    knowntype = unicode

    def noneify(self):
        return SomeUnicodeString(can_be_None=True, no_nul=self.no_nul)


class SomeByteArray(SomeStringOrUnicode):
    immutable = False
    knowntype = bytearray


class SomeChar(SomeString):
    "Stands for an object known to be a string of length 1."
    can_be_None = False

    def __init__(self, no_nul=False):    # no 'can_be_None' argument here
        if no_nul:
            self.no_nul = True


class SomeUnicodeCodePoint(SomeUnicodeString):
    "Stands for an object known to be a unicode codepoint."
    can_be_None = False

    def __init__(self, no_nul=False):    # no 'can_be_None' argument here
        if no_nul:
            self.no_nul = True

SomeString.basestringclass = SomeString
SomeString.basecharclass = SomeChar
SomeUnicodeString.basestringclass = SomeUnicodeString
SomeUnicodeString.basecharclass = SomeUnicodeCodePoint


class SomeList(SomeObject):
    "Stands for a homogenous list of any length."
    knowntype = list

    def __init__(self, listdef):
        self.listdef = listdef

    def __eq__(self, other):
        if self.__class__ is not other.__class__:
            return False
        if not self.listdef.same_as(other.listdef):
            return False
        selfdic = self.__dict__.copy()
        otherdic = other.__dict__.copy()
        del selfdic['listdef']
        del otherdic['listdef']
        return selfdic == otherdic

    def can_be_none(self):
        return True

    def noneify(self):
        return SomeList(self.listdef)


class SomeTuple(SomeObject):
    "Stands for a tuple of known length."
    knowntype = tuple
    immutable = True

    def __init__(self, items):
        self.items = tuple(items)   # tuple of s_xxx elements
        for i in items:
            if not i.is_constant():
                break
        else:
            self.const = tuple([i.const for i in items])

    def can_be_none(self):
        return False


class SomeDict(SomeObject):
    "Stands for a dict."
    knowntype = dict

    def __init__(self, dictdef):
        self.dictdef = dictdef

    def __eq__(self, other):
        if self.__class__ is not other.__class__:
            return False
        if not self.dictdef.same_as(other.dictdef):
            return False
        selfdic = self.__dict__.copy()
        otherdic = other.__dict__.copy()
        del selfdic['dictdef']
        del otherdic['dictdef']
        return selfdic == otherdic

    def can_be_none(self):
        return True

    def fmt_const(self, const):
        if len(const) < 20:
            return repr(const)
        else:
            return '{...%s...}' % (len(const),)

    def noneify(self):
        return type(self)(self.dictdef)

class SomeOrderedDict(SomeDict):
    knowntype = OrderedDict

    def method_copy(dct):
        return SomeOrderedDict(dct.dictdef)

    def method_update(dct1, dct2):
        if s_None.contains(dct2):
            return SomeImpossibleValue()
        assert isinstance(dct2, SomeOrderedDict), "OrderedDict.update(dict) not allowed"
        dct1.dictdef.union(dct2.dictdef)

SomeDict = SomeOrderedDict      # all dicts are ordered!


class SomeIterator(SomeObject):
    "Stands for an iterator returning objects from a given container."
    knowntype = type(iter([]))  # arbitrarily chose seqiter as the type

    def __init__(self, s_container, *variant):
        self.variant = variant
        self.s_container = s_container

    def can_be_none(self):
        return False


class SomeInstance(SomeObject):
    "Stands for an instance of a (user-defined) class."

    def __init__(self, classdef, can_be_None=False, flags={}):
        self.classdef = classdef
        self.knowntype = classdef.classdesc if classdef else None
        self.can_be_None = can_be_None
        self.flags = flags

    def fmt_knowntype(self, kt):
        return None

    def fmt_classdef(self, cdef):
        if cdef is None:
            return 'object'
        else:
            return cdef.name

    def fmt_flags(self, flags):
        if flags:
            return repr(flags)
        else:
            return None

    def can_be_none(self):
        return self.can_be_None

    def nonnoneify(self):
        return SomeInstance(self.classdef, can_be_None=False)

    def noneify(self):
        return SomeInstance(self.classdef, can_be_None=True)

@intersection.register(SomeInstance, SomeInstance)
def intersection_Instance(s_inst1, s_inst2):
    can_be_None = s_inst1.can_be_None and s_inst2.can_be_None
    if s_inst1.classdef.issubclass(s_inst2.classdef):
        return SomeInstance(s_inst1.classdef, can_be_None=can_be_None)
    elif s_inst2.classdef.issubclass(s_inst1.classdef):
        return SomeInstance(s_inst2.classdef, can_be_None=can_be_None)
    else:
        return s_ImpossibleValue

@difference.register(SomeInstance, SomeInstance)
def difference_Instance_Instance(s_inst1, s_inst2):
    if s_inst1.classdef.issubclass(s_inst2.classdef):
        return s_ImpossibleValue
    else:
        return s_inst1


class SomeException(SomeObject):
    """The set of exceptions obeying type(exc) in self.classes"""
    def __init__(self, classdefs):
        self.classdefs = classdefs

    def can_be_none(self):
        return False

    def as_SomeInstance(self):
        return unionof(*[SomeInstance(cdef) for cdef in self.classdefs])

@intersection.register(SomeException, SomeInstance)
def intersection_Exception_Instance(s_exc, s_inst):
    classdefs = {c for c in s_exc.classdefs if c.issubclass(s_inst.classdef)}
    if classdefs:
        return SomeException(classdefs)
    else:
        return s_ImpossibleValue

@intersection.register(SomeInstance, SomeException)
def intersection_Exception_Instance(s_inst, s_exc):
    return intersection(s_exc, s_inst)

@difference.register(SomeException, SomeInstance)
def difference_Exception_Instance(s_exc, s_inst):
    classdefs = {c for c in s_exc.classdefs
        if not c.issubclass(s_inst.classdef)}
    if classdefs:
        return SomeException(classdefs)
    else:
        return s_ImpossibleValue

class SomePBC(SomeObject):
    """Stands for a global user instance, built prior to the analysis,
    or a set of such instances."""
    immutable = True

    def __init__(self, descriptions, can_be_None=False, subset_of=None):
        assert descriptions
        # descriptions is a set of Desc instances
        descriptions = set(descriptions)
        self.descriptions = descriptions
        self.can_be_None = can_be_None
        self.subset_of = subset_of
        self.simplify()
        knowntype = reduce(commonbase, [x.knowntype for x in descriptions])
        if knowntype == type(Exception):
            knowntype = type
        if knowntype != object:
            self.knowntype = knowntype
        if len(descriptions) == 1 and not can_be_None:
            # hack for the convenience of direct callers to SomePBC():
            # only if there is a single object in descriptions
            desc, = descriptions
            if desc.pyobj is not None:
                self.const = desc.pyobj
        elif len(descriptions) > 1:
            from rpython.annotator.classdesc import ClassDesc
            from rpython.annotator.description import MethodOfFrozenDesc
            kind = self.getKind()
            if kind is ClassDesc:
                # a PBC of several classes: enforce them all to be
                # built, without support for specialization.  See
                # rpython/test/test_rpbc.test_pbc_of_classes_not_all_used
                for desc in descriptions:
                    desc.getuniqueclassdef()
            elif kind is MethodOfFrozenDesc:
                funcdescs = set(desc.funcdesc for desc in descriptions)
                if len(funcdescs) > 1:
                    raise AnnotatorError(
                        "You can't mix a set of methods on a frozen PBC in "
                        "RPython that are different underlying functions")

    def any_description(self):
        return iter(self.descriptions).next()

    def getKind(self):
        "Return the common Desc class of all descriptions in this PBC."
        kinds = set()
        for x in self.descriptions:
            assert type(x).__name__.endswith('Desc')  # avoid import nightmares
            kinds.add(x.__class__)
        if len(kinds) > 1:
            raise AnnotatorError("mixing several kinds of PBCs: %r" % kinds)
        return kinds.pop()

    def simplify(self):
        # We check that the set only contains a single kind of Desc instance
        kind = self.getKind()
        # then we remove unnecessary entries in self.descriptions:
        # some MethodDescs can be 'shadowed' by others
        if len(self.descriptions) > 1:
            kind.simplify_desc_set(self.descriptions)

    def consider_call_site(self, args, s_result, call_op):
        descs = list(self.descriptions)
        self.getKind().consider_call_site(descs, args, s_result, call_op)

    def can_be_none(self):
        return self.can_be_None

    def nonnoneify(self):
        return SomePBC(self.descriptions, can_be_None=False,
                subset_of=self.subset_of)

    def noneify(self):
        return SomePBC(self.descriptions, can_be_None=True,
                subset_of=self.subset_of)

    def fmt_descriptions(self, pbis):
        if hasattr(self, 'const'):
            return None
        else:
            return '{...%s...}' % (len(pbis),)

    def fmt_knowntype(self, kt):
        if self.is_constant():
            return None
        else:
            return kt.__name__

class SomeNone(SomeObject):
    knowntype = type(None)
    const = None

    def __init__(self):
        pass

    def is_constant(self):
        return True

    def is_immutable_constant(self):
        return True

    def nonnoneify(self):
        return s_ImpossibleValue


class SomeConstantType(SomePBC):
    can_be_None = False
    subset_of = None
    def __init__(self, x, bk):
        self.descriptions = set([bk.getdesc(x)])
        self.knowntype = type(x)
        self.const = x


class SomeBuiltin(SomeObject):
    "Stands for a built-in function or method with special-cased analysis."
    knowntype = BuiltinFunctionType  # == BuiltinMethodType
    immutable = True

    def __init__(self, analyser, s_self=None, methodname=None):
        if isinstance(analyser, MethodType):
            analyser = descriptor.InstanceMethod(
                analyser.im_func,
                analyser.im_self,
                analyser.im_class)
        self.analyser = analyser
        self.s_self = s_self
        self.methodname = methodname

    def can_be_none(self):
        return False


class SomeBuiltinMethod(SomeBuiltin):
    """ Stands for a built-in method which has got special meaning
    """
    def __init__(self, analyser, s_self, methodname):
        if isinstance(analyser, MethodType):
            analyser = descriptor.InstanceMethod(
                analyser.im_func,
                analyser.im_self,
                analyser.im_class)
        self.analyser = analyser
        self.s_self = s_self
        self.methodname = methodname


class SomeImpossibleValue(SomeObject):
    """The empty set.  Instances are placeholders for objects that
    will never show up at run-time, e.g. elements of an empty list."""
    immutable = True
    annotationcolor = (160, 160, 160)

    def can_be_none(self):
        return False


class SomeProperty(SomeObject):
    # used for union error only
    immutable = True
    knowntype = type(property)

    def __init__(self, prop):
        self.fget = prop.fget
        self.fset = prop.fset

    def can_be_none(self):
        return False


s_None = SomeNone()
s_Bool = SomeBool()
s_True = SomeBool()
s_True.const = True
s_False = SomeBool()
s_False.const = False
s_Int = SomeInteger()
s_ImpossibleValue = SomeImpossibleValue()
s_Str0 = SomeString(no_nul=True)
s_Unicode0 = SomeUnicodeString(no_nul=True)


# ____________________________________________________________
# weakrefs

class SomeWeakRef(SomeObject):
    knowntype = weakref.ReferenceType
    immutable = True

    def __init__(self, classdef):
        # 'classdef' is None for known-to-be-dead weakrefs.
        self.classdef = classdef

    def noneify(self):
        return SomeWeakRef(self.classdef)

# ____________________________________________________________


class AnnotatorError(Exception):
    def __init__(self, msg=None):
        self.msg = msg
        self.source = None

    def __str__(self):
        s = "\n\n%s" % self.msg
        if self.source is not None:
            s += "\n\n"
            s += self.source

        return s

class UnionError(AnnotatorError):
    """Signals an suspicious attempt at taking the union of
    deeply incompatible SomeXxx instances."""

    def __init__(self, s_obj1, s_obj2, msg=None):
        """
        This exception expresses the fact that s_obj1 and s_obj2 cannot be unified.
        The msg paramter is appended to a generic message. This can be used to
        give the user a little more information.
        """
        s = ""
        if msg is not None:
            s += "%s\n\n" % msg
        s += "Offending annotations:\n"
        s += "  %s\n  %s" % (s_obj1, s_obj2)
        self.s_obj1 = s_obj1
        self.s_obj2 = s_obj2
        self.msg = s
        self.source = None

    def __repr__(self):
        return str(self)

def union(s1, s2):
    """The join operation in the lattice of annotations.

    It is the most precise SomeObject instance that contains both arguments.

    union() is (supposed to be) idempotent, commutative, associative and has
    no side-effects.
    """
    try:
        TLS.no_side_effects_in_union += 1
    except AttributeError:
        TLS.no_side_effects_in_union = 1
    try:
        if s1 == s2:
            # Most pair(...).union() methods deal incorrectly with that case
            # when constants are involved.
            return s1
        return pair(s1, s2).union()
    finally:
        TLS.no_side_effects_in_union -= 1

def unionof(*somevalues):
    "The most precise SomeValue instance that contains all the values."
    try:
        s1, s2 = somevalues
    except ValueError:
        s1 = s_ImpossibleValue
        for s2 in somevalues:
            if s1 != s2:
                s1 = pair(s1, s2).union()
    else:
        # See comment in union() above
        if s1 != s2:
            s1 = pair(s1, s2).union()
    return s1


# make knowntypedata dictionary

def add_knowntypedata(ktd, truth, vars, s_obj):
    for v in vars:
        ktd[truth][v] = s_obj


def merge_knowntypedata(ktd1, ktd2):
    r = defaultdict(dict)
    for truth, constraints in ktd1.items():
        for v in constraints:
            if truth in ktd2 and v in ktd2[truth]:
                r[truth][v] = unionof(ktd1[truth][v], ktd2[truth][v])
    return r


def not_const(s_obj):
    if s_obj.is_constant() and not isinstance(s_obj, (SomePBC, SomeNone)):
        new_s_obj = SomeObject.__new__(s_obj.__class__)
        dic = new_s_obj.__dict__ = s_obj.__dict__.copy()
        if 'const' in dic:
            del new_s_obj.const
        else:
            del new_s_obj.const_box
        s_obj = new_s_obj
    return s_obj


# ____________________________________________________________
# internal

def commonbase(cls1, cls2):   # XXX single inheritance only  XXX hum
    l1 = inspect.getmro(cls1)
    l2 = inspect.getmro(cls2)
    if l1[-1] != object:
        l1 = l1 + (object,)
    if l2[-1] != object:
        l2 = l2 + (object,)
    for x in l1:
        if x in l2:
            return x
    assert 0, "couldn't get to commonbase of %r and %r" % (cls1, cls2)


class HarmlesslyBlocked(Exception):
    """Raised by the unaryop/binaryop to signal a harmless kind of
    BlockedInference: the current block is blocked, but not in a way
    that gives 'Blocked block' errors at the end of annotation."""


def read_can_only_throw(opimpl, *args):
    can_only_throw = getattr(opimpl, "can_only_throw", None)
    if can_only_throw is None or isinstance(can_only_throw, list):
        return can_only_throw
    return can_only_throw(*args)

#
# safety check that no-one is trying to make annotation and translation
# faster by providing the -O option to Python.
import os
if "WINGDB_PYTHON" not in os.environ:
    # ...but avoiding this boring check in the IDE
    try:
        assert False
    except AssertionError:
        pass   # fine
    else:
        raise RuntimeError("The annotator relies on 'assert' statements from the\n"
                     "\tannotated program: you cannot run it with 'python -O'.")
