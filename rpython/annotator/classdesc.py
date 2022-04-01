"""
Type inference for user-defined classes.
"""
from __future__ import absolute_import
import types

from rpython.flowspace.model import Constant
from rpython.tool.flattenrec import FlattenRecursion
from rpython.tool.sourcetools import func_with_new_name
from rpython.tool.uid import Hashable
from rpython.annotator.model import (
    SomePBC, s_ImpossibleValue, unionof, s_None, AnnotatorError, SomeInteger,
    SomeString, SomeImpossibleValue, SomeList, HarmlesslyBlocked)
from rpython.annotator.description import (
    Desc, FunctionDesc, MethodDesc, NODEFAULT)


# The main purpose of a ClassDef is to collect information about class/instance
# attributes as they are really used.  An Attribute object is stored in the
# most general ClassDef where an attribute of that name is read/written:
#    classdef.attrs = {'attrname': Attribute()}
#
# The following invariants hold:
#
# (A) if an attribute is read/written on an instance of class A, then the
#     classdef of A or a parent class of A has an Attribute object corresponding
#     to that name.
#
# (I) if B is a subclass of A, then they don't both have an Attribute for the
#     same name.  (All information from B's Attribute must be merged into A's.)
#
# Additionally, each ClassDef records an 'attr_sources': it maps attribute names
# to a list of 'source' objects that want to provide a constant value for this
# attribute at the level of this class.  The attr_sources provide information
# higher in the class hierarchy than concrete Attribute()s.  It is for the case
# where (so far or definitely) the user program only reads/writes the attribute
# at the level of a subclass, but a value for this attribute could possibly
# exist in the parent class or in an instance of a parent class.
#
# The point of not automatically forcing the Attribute instance up to the
# parent class which has a class attribute of the same name is apparent with
# multiple subclasses:
#
#                                    A
#                                 attr=s1
#                                  /   \
#                                 /     \
#                                B       C
#                             attr=s2  attr=s3
#
# XXX this does not seem to be correct, but I don't know how to phrase
#     it correctly. See test_specific_attributes in test_annrpython
#
# In this case, as long as 'attr' is only read/written from B or C, the
# Attribute on B says that it can be 's1 or s2', and the Attribute on C says
# it can be 's1 or s3'.  Merging them into a single Attribute on A would give
# the more imprecise 's1 or s2 or s3'.
#
# The following invariant holds:
#
# (II) if a class A has an Attribute, the 'attr_sources' for the same name is
#      empty.  It is also empty on all subclasses of A.  (The information goes
#      into the Attribute directly in this case.)
#
# The following invariant holds:
#
#  (III) for a class A, each attrsource that comes from the class (as opposed to
#        from a prebuilt instance) must be merged into all Attributes of the
#        same name in all subclasses of A, if any.  (Parent class attributes can
#        be visible in reads from instances of subclasses.)

class Attribute(object):
    # readonly-ness
    # SomeThing-ness
    # NB.  an attribute is readonly if it is a constant class attribute.
    #      Both writing to the instance attribute and discovering prebuilt
    #      instances that have the attribute set will turn off readonly-ness.

    def __init__(self, name):
        assert name != '__class__'
        self.name = name
        self.s_value = s_ImpossibleValue
        self.readonly = True
        self.attr_allowed = True
        self.read_locations = set()

    def add_constant_source(self, classdef, source):
        s_value = source.s_get_value(classdef, self.name)
        if source.instance_level:
            # a prebuilt instance source forces readonly=False, see above
            self.modified(classdef)
        s_new_value = unionof(self.s_value, s_value)
        self.s_value = s_new_value

    def merge(self, other, classdef):
        assert self.name == other.name
        s_new_value = unionof(self.s_value, other.s_value)
        self.s_value = s_new_value
        if not other.readonly:
            self.modified(classdef)
        self.read_locations.update(other.read_locations)

    def validate(self, homedef):
        s_newvalue = self.s_value
        # check for after-the-fact method additions
        if isinstance(s_newvalue, SomePBC):
            attr = self.name
            if s_newvalue.getKind() == MethodDesc:
                # is method
                if homedef.classdesc.read_attribute(attr, None) is None:
                    homedef.check_missing_attribute_update(attr)

        # check for attributes forbidden by slots or _attrs_
        if homedef.classdesc.all_enforced_attrs is not None:
            if self.name not in homedef.classdesc.all_enforced_attrs:
                self.attr_allowed = False
                if not self.readonly:
                    raise NoSuchAttrError(
                        "the attribute %r goes here to %r, but it is "
                        "forbidden here" % (self.name, homedef))

    def modified(self, classdef='?'):
        self.readonly = False
        if not self.attr_allowed:
            from rpython.annotator.bookkeeper import getbookkeeper
            bk = getbookkeeper()
            classdesc = classdef.classdesc
            locations = bk.getattr_locations(classdesc, self.name)
            raise NoSuchAttrError(
                "Attribute %r on %r should be read-only.\n" % (self.name,
                                                               classdef) +
                "This error can be caused by another 'getattr' that promoted\n"
                "the attribute here; the list of read locations is:\n" +
                '\n'.join([str(loc[0]) for loc in locations]))

class ClassDef(object):
    "Wraps a user class."

    def __init__(self, bookkeeper, classdesc):
        self.bookkeeper = bookkeeper
        self.attrs = {}          # {name: Attribute}
        self.classdesc = classdesc
        self.name = self.classdesc.name
        self.shortname = self.name.split('.')[-1]
        self.subdefs = []
        self.attr_sources = {}   # {name: list-of-sources}
        self.read_locations_of__class__ = {}
        self.repr = None
        self.extra_access_sets = {}
        self.instances_seen = set()

        if classdesc.basedesc:
            self.basedef = classdesc.basedesc.getuniqueclassdef()
            self.basedef.subdefs.append(self)
            self.basedef.see_new_subclass(self)
        else:
            self.basedef = None

        self.parentdefs = dict.fromkeys(self.getmro())

    def setup(self, sources):
        # collect the (supposed constant) class attributes
        for name, source in sources.items():
            self.add_source_for_attribute(name, source)
        if self.bookkeeper:
            self.bookkeeper.event('classdef_setup', self)

    def s_getattr(self, attrname, flags):
        attrdef = self.find_attribute(attrname)
        s_result = attrdef.s_value
        # hack: if s_result is a set of methods, discard the ones
        #       that can't possibly apply to an instance of self.
        # XXX do it more nicely
        if isinstance(s_result, SomePBC):
            s_result = self.lookup_filter(s_result, attrname, flags)
        elif isinstance(s_result, SomeImpossibleValue):
            self.check_missing_attribute_update(attrname)
            # blocking is harmless if the attribute is explicitly listed
            # in the class or a parent class.
            for basedef in self.getmro():
                if basedef.classdesc.all_enforced_attrs is not None:
                    if attrname in basedef.classdesc.all_enforced_attrs:
                        raise HarmlesslyBlocked("get enforced attr")
        elif isinstance(s_result, SomeList):
            s_result = self.classdesc.maybe_return_immutable_list(
                attrname, s_result)
        return s_result

    def add_source_for_attribute(self, attr, source):
        """Adds information about a constant source for an attribute.
        """
        for cdef in self.getmro():
            if attr in cdef.attrs:
                # the Attribute() exists already for this class (or a parent)
                attrdef = cdef.attrs[attr]
                s_prev_value = attrdef.s_value
                attrdef.add_constant_source(self, source)
                # we should reflow from all the reader's position,
                # but as an optimization we try to see if the attribute
                # has really been generalized
                if attrdef.s_value != s_prev_value:
                    self.bookkeeper.update_attr(cdef, attrdef)
                return
        else:
            # remember the source in self.attr_sources
            sources = self.attr_sources.setdefault(attr, [])
            sources.append(source)
            # register the source in any Attribute found in subclasses,
            # to restore invariant (III)
            # NB. add_constant_source() may discover new subdefs but the
            #     right thing will happen to them because self.attr_sources
            #     was already updated
            if not source.instance_level:
                for subdef in self.getallsubdefs():
                    if attr in subdef.attrs:
                        attrdef = subdef.attrs[attr]
                        s_prev_value = attrdef.s_value
                        attrdef.add_constant_source(self, source)
                        if attrdef.s_value != s_prev_value:
                            self.bookkeeper.update_attr(subdef, attrdef)

    def get_owner(self, attrname):
        """Return the classdef owning the attribute `attrname`."""
        for cdef in self.getmro():
            if attrname in cdef.attrs:
                return cdef
        else:
            return None


    def locate_attribute(self, attr):
        cdef = self.get_owner(attr)
        if cdef:
            return cdef
        else:
            self._generalize_attr(attr, s_value=None)
            return self

    def find_attribute(self, attr):
        return self.locate_attribute(attr).attrs[attr]

    def __repr__(self):
        return "<ClassDef '%s'>" % (self.name,)

    def has_no_attrs(self):
        for clsdef in self.getmro():
            if clsdef.attrs:
                return False
        return True

    def commonbase(self, other):
        while other is not None and not self.issubclass(other):
            other = other.basedef
        return other

    def getmro(self):
        while self is not None:
            yield self
            self = self.basedef

    def issubclass(self, other):
        return self.classdesc.issubclass(other.classdesc)

    def getallsubdefs(self):
        pending = [self]
        seen = {}
        for clsdef in pending:
            yield clsdef
            for sub in clsdef.subdefs:
                if sub not in seen:
                    pending.append(sub)
                    seen[sub] = True

    def _generalize_attr(self, attr, s_value):
        # create the Attribute and do the generalization asked for
        newattr = Attribute(attr)
        if s_value:
            newattr.s_value = s_value

        # remove the attribute from subclasses -- including us!
        # invariant (I)
        constant_sources = []    # [(classdef-of-origin, source)]
        for subdef in self.getallsubdefs():
            if attr in subdef.attrs:
                subattr = subdef.attrs[attr]
                newattr.merge(subattr, classdef=self)
                del subdef.attrs[attr]
            if attr in subdef.attr_sources:
                # accumulate attr_sources for this attribute from all subclasses
                lst = subdef.attr_sources[attr]
                for source in lst:
                    constant_sources.append((subdef, source))
                del lst[:]    # invariant (II)

        # accumulate attr_sources for this attribute from all parents, too
        # invariant (III)
        for superdef in self.getmro():
            if attr in superdef.attr_sources:
                for source in superdef.attr_sources[attr]:
                    if not source.instance_level:
                        constant_sources.append((superdef, source))

        # store this new Attribute, generalizing the previous ones from
        # subclasses -- invariant (A)
        self.attrs[attr] = newattr

        # add the values of the pending constant attributes
        # completes invariants (II) and (III)
        for origin_classdef, source in constant_sources:
            newattr.add_constant_source(origin_classdef, source)

        # reflow from all read positions
        self.bookkeeper.update_attr(self, newattr)

    def generalize_attr(self, attr, s_value=None):
        # if the attribute exists in a superclass, generalize there,
        # as imposed by invariant (I)
        clsdef = self.get_owner(attr)
        if clsdef:
            clsdef._generalize_attr(attr, s_value)
        else:
            self._generalize_attr(attr, s_value)

    def about_attribute(self, name):
        """This is the interface for the code generators to ask about
           the annotation given to a attribute."""
        for cdef in self.getmro():
            if name in cdef.attrs:
                s_result = cdef.attrs[name].s_value
                if s_result != s_ImpossibleValue:
                    return s_result
                else:
                    return None
        return None

    def lookup_filter(self, pbc, name=None, flags={}):
        """Selects the methods in the pbc that could possibly be seen by
        a lookup performed on an instance of 'self', removing the ones
        that cannot appear.
        """
        d = []
        uplookup = None
        updesc = None
        for desc in pbc.descriptions:
            # pick methods but ignore already-bound methods, which can come
            # from an instance attribute
            if (isinstance(desc, MethodDesc) and desc.selfclassdef is None):
                methclassdef = desc.originclassdef
                if methclassdef is not self and methclassdef.issubclass(self):
                    pass  # subclasses methods are always candidates
                elif self.issubclass(methclassdef):
                    # upward consider only the best match
                    if uplookup is None or methclassdef.issubclass(uplookup):
                        uplookup = methclassdef
                        updesc = desc
                    continue
                    # for clsdef1 >= clsdef2, we guarantee that
                    # clsdef1.lookup_filter(pbc) includes
                    # clsdef2.lookup_filter(pbc) (see formal proof...)
                else:
                    continue  # not matching
                # bind the method by giving it a selfclassdef.  Use the
                # more precise subclass that it's coming from.
                desc = desc.bind_self(methclassdef, flags)
            d.append(desc)
        if uplookup is not None:
            d.append(updesc.bind_self(self, flags))

        if d:
            return SomePBC(d, can_be_None=pbc.can_be_None)
        elif pbc.can_be_None:
            return s_None
        else:
            return s_ImpossibleValue

    def check_missing_attribute_update(self, name):
        # haaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaack
        # sometimes, new methods can show up on classes, added
        # e.g. by W_TypeObject._freeze_() -- the multimethod
        # implementations.  Check that here...
        found = False
        parents = list(self.getmro())
        parents.reverse()
        for base in parents:
            if base.check_attr_here(name):
                found = True
        return found

    def check_attr_here(self, name):
        source = self.classdesc.find_source_for(name)
        if source is not None:
            # oups! new attribute showed up
            self.add_source_for_attribute(name, source)
            # maybe it also showed up in some subclass?
            for subdef in self.getallsubdefs():
                if subdef is not self:
                    subdef.check_attr_here(name)
            return True
        else:
            return False

    _see_instance_flattenrec = FlattenRecursion()

    def see_instance(self, x):
        assert isinstance(x, self.classdesc.pyobj)
        key = Hashable(x)
        if key in self.instances_seen:
            return
        self.instances_seen.add(key)
        self.bookkeeper.event('mutable', x)
        source = InstanceSource(self.bookkeeper, x)
        def delayed():
            for attr in source.all_instance_attributes():
                self.add_source_for_attribute(attr, source)
                # ^^^ can trigger reflowing
        self._see_instance_flattenrec(delayed)

    def see_new_subclass(self, classdef):
        for position in self.read_locations_of__class__:
            self.bookkeeper.annotator.reflowfromposition(position)
        if self.basedef is not None:
            self.basedef.see_new_subclass(classdef)

    def read_attr__class__(self):
        position = self.bookkeeper.position_key
        self.read_locations_of__class__[position] = True
        return SomePBC([subdef.classdesc for subdef in self.getallsubdefs()])

    def _freeze_(self):
        raise Exception("ClassDefs are used as knowntype for instances but "
                        "cannot be used as immutablevalue arguments directly")

# ____________________________________________________________

class InstanceSource(object):
    instance_level = True

    def __init__(self, bookkeeper, obj):
        self.bookkeeper = bookkeeper
        self.obj = obj

    def s_get_value(self, classdef, name):
        try:
            v = getattr(self.obj, name)
        except AttributeError:
            all_enforced_attrs = classdef.classdesc.all_enforced_attrs
            if all_enforced_attrs and name in all_enforced_attrs:
                return s_ImpossibleValue
            raise
        s_value = self.bookkeeper.immutablevalue(v)
        return s_value

    def all_instance_attributes(self):
        result = getattr(self.obj, '__dict__', {}).keys()
        tp = self.obj.__class__
        if isinstance(tp, type):
            for basetype in tp.__mro__:
                slots = basetype.__dict__.get('__slots__')
                if slots:
                    if isinstance(slots, str):
                        result.append(slots)
                    else:
                        result.extend(slots)
        return result

class NoSuchAttrError(AnnotatorError):
    """Raised when an attribute is found on a class where __slots__
     or _attrs_ forbits it."""


def is_mixin(cls):
    return cls.__dict__.get('_mixin_', False)

def is_primitive_type(cls):
    from rpython.rlib.rarithmetic import base_int
    return cls.__module__ == '__builtin__' or issubclass(cls, base_int)


class BuiltinTypeDesc(object):
    """Represents a primitive or builtin type object"""
    def __init__(self, cls):
        self.pyobj = cls

    def issubclass(self, other):
        return issubclass(self.pyobj, other.pyobj)


class ClassDesc(Desc):
    knowntype = type
    instance_level = False
    all_enforced_attrs = None   # or a set
    _detect_invalid_attrs = None

    def __init__(self, bookkeeper, cls,
                 name=None, basedesc=None, classdict=None):
        super(ClassDesc, self).__init__(bookkeeper, cls)
        if '__NOT_RPYTHON__' in cls.__dict__:
            raise AnnotatorError('Bad class')

        if name is None:
            name = cls.__module__ + '.' + cls.__name__
        self.name = name
        self.basedesc = basedesc
        if classdict is None:
            classdict = {}    # populated below
        self.classdict = classdict     # {attr: Constant-or-Desc}
        if cls.__dict__.get('_annspecialcase_', ''):
            raise AnnotatorError(
                "Class specialization has been removed. The "
                "'_annspecialcase_' class tag is now unsupported.")
        self.classdef = None

        if is_mixin(cls):
            raise AnnotatorError("cannot use directly the class %r because "
                                 "it is a _mixin_" % (cls,))

        assert cls.__module__ != '__builtin__'
        baselist = list(cls.__bases__)

        # special case: skip BaseException, and pretend
        # that all exceptions ultimately inherit from Exception instead
        # of BaseException (XXX hack)
        if cls is Exception:
            baselist = []
        elif baselist == [BaseException]:
            baselist = [Exception]

        immutable_fields = cls.__dict__.get('_immutable_fields_', [])
        # To prevent confusion, we forbid strings. Any other bona fide sequence
        # of strings is OK.
        if isinstance(immutable_fields, basestring):
            raise AnnotatorError(
                "In class %s, '_immutable_fields_' must be a sequence of "
                "attribute names, not a string." % cls)
        self.immutable_fields = set(immutable_fields)

        mixins_before = []
        mixins_after = []
        base = object
        for b1 in baselist:
            if b1 is object:
                continue
            if is_mixin(b1):
                if base is object:
                    mixins_before.append(b1)
                else:
                    mixins_after.append(b1)
            else:
                assert base is object, ("multiple inheritance only supported "
                                        "with _mixin_: %r" % (cls,))
                base = b1
        if mixins_before and mixins_after:
            raise AnnotatorError("unsupported: class %r has mixin bases both"
                                 " before and after the regular base" % (self,))
        self.add_mixins(mixins_after, check_not_in=base)
        self.add_mixins(mixins_before)
        self.add_sources_for_class(cls)

        if base is not object:
            self.basedesc = bookkeeper.getdesc(base)

        if '__slots__' in cls.__dict__ or '_attrs_' in cls.__dict__:
            attrs = {}
            for decl in ('__slots__', '_attrs_'):
                decl = cls.__dict__.get(decl, [])
                if isinstance(decl, str):
                    decl = (decl,)
                decl = dict.fromkeys(decl)
                attrs.update(decl)
            if self.basedesc is not None:
                if self.basedesc.all_enforced_attrs is None:
                    raise AnnotatorError("%r has slots or _attrs_, "
                                         "but not its base class" % (cls,))
                attrs.update(self.basedesc.all_enforced_attrs)
            self.all_enforced_attrs = attrs

        if (self.is_builtin_exception_class() and
                self.all_enforced_attrs is None):
            if cls not in FORCE_ATTRIBUTES_INTO_CLASSES:
                self.all_enforced_attrs = []    # no attribute allowed

        if (getattr(cls, '_must_be_light_finalizer_', False) and
            hasattr(cls, '__del__') and
            not getattr(cls.__del__, '_must_be_light_finalizer_', False)):
            raise AnnotatorError(
                "Class %r is in a class hierarchy with "
                "_must_be_light_finalizer_ = True: it cannot have a "
                "finalizer without @rgc.must_be_light_finalizer" % (cls,))

    def add_source_attribute(self, name, value, mixin=False):
        if isinstance(value, property):
            # special case for property object
            if value.fget is not None:
                newname = name + '__getter__'
                func = func_with_new_name(value.fget, newname)
                self.add_source_attribute(newname, func, mixin)
            if value.fset is not None:
                newname = name + '__setter__'
                func = func_with_new_name(value.fset, newname)
                self.add_source_attribute(newname, func, mixin)
            self.classdict[name] = Constant(value)
            return

        if isinstance(value, types.FunctionType):
            # for debugging
            if not hasattr(value, 'class_'):
                value.class_ = self.pyobj
            if mixin:
                # make a new copy of the FunctionDesc for this class,
                # but don't specialize further for all subclasses
                funcdesc = self.bookkeeper.newfuncdesc(value)
                self.classdict[name] = funcdesc
                return
            # NB. if value is, say, AssertionError.__init__, then we
            # should not use getdesc() on it.  Never.  The problem is
            # that the py lib has its own AssertionError.__init__ which
            # is of type FunctionType.  But bookkeeper.immutablevalue()
            # will do the right thing in s_get_value().
        if isinstance(value, staticmethod) and mixin:
            # make a new copy of staticmethod
            func = value.__get__(42)
            value = staticmethod(func_with_new_name(func, func.__name__))

        if type(value) in MemberDescriptorTypes:
            # skip __slots__, showing up in the class as 'member' objects
            return
        if name == '__init__' and self.is_builtin_exception_class():
            # pretend that built-in exceptions have no __init__,
            # unless explicitly specified in builtin.py
            from rpython.annotator.builtin import BUILTIN_ANALYZERS
            value = getattr(value, 'im_func', value)
            if value not in BUILTIN_ANALYZERS:
                return
        self.classdict[name] = Constant(value)

    def add_mixins(self, mixins, check_not_in=object):
        if not mixins:
            return
        A = type('tmp', tuple(mixins) + (object,), {})
        mro = A.__mro__
        assert mro[0] is A and mro[-1] is object
        mro = mro[1:-1]
        #
        skip = set()
        def add(cls):
            if cls is not object:
                for base in cls.__bases__:
                    add(base)
                for name in cls.__dict__:
                    skip.add(name)
        add(check_not_in)
        #
        for base in reversed(mro):
            assert is_mixin(base), (
                "Mixin class %r has non mixin base class %r" % (mixins, base))
            for name, value in base.__dict__.items():
                if name in skip:
                    continue
                self.add_source_attribute(name, value, mixin=True)
            if '_immutable_fields_' in base.__dict__:
                self.immutable_fields.update(
                    set(base.__dict__['_immutable_fields_']))


    def add_sources_for_class(self, cls):
        for name, value in cls.__dict__.items():
            self.add_source_attribute(name, value)

    def getclassdef(self, key):
        return self.getuniqueclassdef()

    def _init_classdef(self):
        classdef = ClassDef(self.bookkeeper, self)
        self.bookkeeper.classdefs.append(classdef)
        self.classdef = classdef

        # forced attributes
        cls = self.pyobj
        if cls in FORCE_ATTRIBUTES_INTO_CLASSES:
            for name, s_value in FORCE_ATTRIBUTES_INTO_CLASSES[cls].items():
                classdef.generalize_attr(name, s_value)
                classdef.find_attribute(name).modified(classdef)

        # register all class attributes as coming from this ClassDesc
        # (as opposed to prebuilt instances)
        classsources = {}
        for attr in self.classdict:
            classsources[attr] = self    # comes from this ClassDesc
        classdef.setup(classsources)
        # look for a __del__ method and annotate it if it's there
        if '__del__' in self.classdict:
            from rpython.annotator.model import s_None, SomeInstance
            s_func = self.s_read_attribute('__del__')
            args_s = [SomeInstance(classdef)]
            s = self.bookkeeper.emulate_pbc_call(classdef, s_func, args_s)
            assert s_None.contains(s)
        return classdef

    def getuniqueclassdef(self):
        if self.classdef is None:
            self._init_classdef()
        return self.classdef

    def pycall(self, whence, args, s_previous_result, op=None):
        from rpython.annotator.model import SomeInstance, SomeImpossibleValue
        classdef = self.getuniqueclassdef()
        s_instance = SomeInstance(classdef)
        # look up __init__ directly on the class, bypassing the normal
        # lookup mechanisms ClassDef (to avoid influencing Attribute placement)
        s_init = self.s_read_attribute('__init__')
        if isinstance(s_init, SomeImpossibleValue):
            # no __init__: check that there are no constructor args
            if not self.is_exception_class():
                try:
                    args.fixedunpack(0)
                except ValueError:
                    raise AnnotatorError("default __init__ takes no argument"
                                         " (class %s)" % (self.name,))
            elif self.pyobj is Exception:
                # check explicitly against "raise Exception, x" where x
                # is a low-level exception pointer
                try:
                    [s_arg] = args.fixedunpack(1)
                except ValueError:
                    pass
                else:
                    from rpython.rtyper.llannotation import SomePtr
                    assert not isinstance(s_arg, SomePtr)
        else:
            # call the constructor
            args = args.prepend(s_instance)
            s_init.call(args)
        return s_instance

    def is_exception_class(self):
        return issubclass(self.pyobj, BaseException)

    def is_builtin_exception_class(self):
        if self.is_exception_class():
            if self.pyobj.__module__ == 'exceptions':
                return True
            if issubclass(self.pyobj, AssertionError):
                return True
        return False

    def issubclass(self, other):
        return issubclass(self.pyobj, other.pyobj)

    def lookup(self, name):
        cdesc = self
        while name not in cdesc.classdict:
            cdesc = cdesc.basedesc
            if cdesc is None:
                return None
        else:
            return cdesc

    def get_param(self, name, default=None, inherit=True):
        cls = self.pyobj
        if inherit:
            return getattr(cls, name, default)
        else:
            return cls.__dict__.get(name, default)

    def read_attribute(self, name, default=NODEFAULT):
        cdesc = self.lookup(name)
        if cdesc is None:
            if default is NODEFAULT:
                raise AttributeError
            else:
                return default
        else:
            return cdesc.classdict[name]

    def s_read_attribute(self, name):
        # look up an attribute in the class
        cdesc = self.lookup(name)
        if cdesc is None:
            return s_ImpossibleValue
        else:
            # delegate to s_get_value to turn it into an annotation
            return cdesc.s_get_value(None, name)

    def s_get_value(self, classdef, name):
        obj = self.classdict[name]
        if isinstance(obj, Constant):
            value = obj.value
            if isinstance(value, staticmethod):   # special case
                value = value.__get__(42)
                classdef = None   # don't bind
            elif isinstance(value, classmethod):
                raise AnnotatorError("classmethods are not supported")
            s_value = self.bookkeeper.immutablevalue(value)
            if classdef is not None:
                s_value = s_value.bind_callables_under(classdef, name)
        elif isinstance(obj, Desc):
            if classdef is not None:
                obj = obj.bind_under(classdef, name)
            s_value = SomePBC([obj])
        else:
            raise TypeError("classdict should not contain %r" % (obj,))
        return s_value

    def create_new_attribute(self, name, value):
        assert name not in self.classdict, "name clash: %r" % (name,)
        self.classdict[name] = Constant(value)

    def find_source_for(self, name):
        if name in self.classdict:
            return self
        # check whether there is a new attribute
        cls = self.pyobj
        if name in cls.__dict__:
            self.add_source_attribute(name, cls.__dict__[name])
            if name in self.classdict:
                return self
        return None

    def maybe_return_immutable_list(self, attr, s_result):
        # hack: 'x.lst' where lst is listed in _immutable_fields_ as
        # either 'lst[*]' or 'lst?[*]'
        # should really return an immutable list as a result.  Implemented
        # by changing the result's annotation (but not, of course, doing an
        # actual copy in the rtyper). Tested in rpython.rtyper.test.test_rlist,
        # test_immutable_list_out_of_instance.
        if self._detect_invalid_attrs and attr in self._detect_invalid_attrs:
            raise AnnotatorError("field %r was migrated to %r from a subclass in "
                                 "which it was declared as _immutable_fields_" %
                            (attr, self.pyobj))
        search1 = '%s[*]' % (attr,)
        search2 = '%s?[*]' % (attr,)
        cdesc = self
        while cdesc is not None:
            immutable_fields = cdesc.immutable_fields
            if immutable_fields:
                if (search1 in immutable_fields or search2 in immutable_fields):
                    s_result.listdef.never_resize()
                    s_copy = s_result.listdef.offspring(self.bookkeeper)
                    s_copy.listdef.mark_as_immutable()
                    #
                    cdesc = cdesc.basedesc
                    while cdesc is not None:
                        if cdesc._detect_invalid_attrs is None:
                            cdesc._detect_invalid_attrs = set()
                        cdesc._detect_invalid_attrs.add(attr)
                        cdesc = cdesc.basedesc
                    #
                    return s_copy
            cdesc = cdesc.basedesc
        return s_result     # common case

    @staticmethod
    def consider_call_site(descs, args, s_result, op):
        descs[0].getcallfamily()
        descs[0].mergecallfamilies(*descs[1:])
        from rpython.annotator.model import SomeInstance, SomePBC, s_None
        if len(descs) == 1:
            # call to a single class, look at the result annotation
            # in case it was specialized
            if not isinstance(s_result, SomeInstance):
                raise AnnotatorError("calling a class didn't return an instance??")
            classdefs = [s_result.classdef]
        else:
            # call to multiple classes: specialization not supported
            classdefs = [desc.getuniqueclassdef() for desc in descs]
            # If some of the classes have an __init__ and others not, then
            # we complain, even though in theory it could work if all the
            # __init__s take no argument.  But it's messy to implement, so
            # let's just say it is not RPython and you have to add an empty
            # __init__ to your base class.
            has_init = False
            for desc in descs:
                s_init = desc.s_read_attribute('__init__')
                has_init |= isinstance(s_init, SomePBC)
            basedesc = ClassDesc.getcommonbase(descs)
            s_init = basedesc.s_read_attribute('__init__')
            parent_has_init = isinstance(s_init, SomePBC)
            if has_init and not parent_has_init:
                raise AnnotatorError(
                    "some subclasses among %r declare __init__(),"
                    " but not the common parent class" % (descs,))
        # make a PBC of MethodDescs, one for the __init__ of each class
        initdescs = []
        for desc, classdef in zip(descs, classdefs):
            s_init = desc.s_read_attribute('__init__')
            if isinstance(s_init, SomePBC):
                assert len(s_init.descriptions) == 1, (
                    "unexpected dynamic __init__?")
                initfuncdesc, = s_init.descriptions
                if isinstance(initfuncdesc, FunctionDesc):
                    from rpython.annotator.bookkeeper import getbookkeeper
                    initmethdesc = getbookkeeper().getmethoddesc(
                        initfuncdesc, classdef, classdef, '__init__')
                    initdescs.append(initmethdesc)
        # register a call to exactly these __init__ methods
        if initdescs:
            initdescs[0].mergecallfamilies(*initdescs[1:])
            MethodDesc.consider_call_site(initdescs, args, s_None, op)

    def getallbases(self):
        desc = self
        while desc is not None:
            yield desc
            desc = desc.basedesc

    @staticmethod
    def getcommonbase(descs):
        commondesc = descs[0]
        for desc in descs[1:]:
            allbases = set(commondesc.getallbases())
            while desc not in allbases:
                assert desc is not None, "no common base for %r" % (descs,)
                desc = desc.basedesc
            commondesc = desc
        return commondesc

    def rowkey(self):
        return self

    def getattrfamily(self, attrname):
        "Get the ClassAttrFamily object for attrname. Possibly creates one."
        access_sets = self.bookkeeper.get_classpbc_attr_families(attrname)
        _, _, attrfamily = access_sets.find(self)
        return attrfamily

    def queryattrfamily(self, attrname):
        """Retrieve the ClassAttrFamily object for attrname if there is one,
           otherwise return None."""
        access_sets = self.bookkeeper.get_classpbc_attr_families(attrname)
        try:
            return access_sets[self]
        except KeyError:
            return None

    def mergeattrfamilies(self, others, attrname):
        """Merge the attr families of the given Descs into one."""
        access_sets = self.bookkeeper.get_classpbc_attr_families(attrname)
        changed, rep, attrfamily = access_sets.find(self)
        for desc in others:
            changed1, rep, attrfamily = access_sets.union(rep, desc)
            changed = changed or changed1
        return changed

# ____________________________________________________________

class Sample(object):
    __slots__ = 'x'
MemberDescriptorTypes = [type(Sample.x)]
del Sample
try:
    MemberDescriptorTypes.append(type(OSError.errno))
except AttributeError:    # on CPython <= 2.4
    pass

# ____________________________________________________________

FORCE_ATTRIBUTES_INTO_CLASSES = {
    EnvironmentError: {'errno': SomeInteger(),
                       'strerror': SomeString(can_be_None=True),
                       'filename': SomeString(can_be_None=True)},
}

try:
    WindowsError
except NameError:
    pass
else:
    FORCE_ATTRIBUTES_INTO_CLASSES[WindowsError] = {'winerror': SomeInteger()}
