import sys
import types

from rpython.flowspace.model import Constant
from rpython.annotator import description, model as annmodel
from rpython.rlib.objectmodel import UnboxedValue
from rpython.tool.pairtype import pairtype, pair
from rpython.tool.identity_dict import identity_dict
from rpython.tool.flattenrec import FlattenRecursion
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lltype import (
    Ptr, Struct, GcStruct, malloc, cast_pointer, castable, nullptr,
    RuntimeTypeInfo, getRuntimeTypeInfo, typeOf, Void, FuncType, Bool, Signed,
    functionptr, attachRuntimeTypeInfo)
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rtyper.llannotation import SomePtr
from rpython.rtyper.lltypesystem import rstr
from rpython.rtyper.rmodel import (
    Repr, getgcflavor, inputconst, warning, mangle)


class FieldListAccessor(object):

    def initialize(self, TYPE, fields):
        assert type(fields) is dict
        self.TYPE = TYPE
        self.fields = fields
        for x in fields.itervalues():
            assert isinstance(x, ImmutableRanking)

    def all_immutable_fields(self):
        result = set()
        for key, value in self.fields.iteritems():
            if value in (IR_IMMUTABLE, IR_IMMUTABLE_ARRAY):
                result.add(key)
        return result

    def __repr__(self):
        return '<FieldListAccessor for %s>' % getattr(self, 'TYPE', '?')


class ImmutableRanking(object):
    def __init__(self, name, is_immutable):
        self.name = name
        self.is_immutable = is_immutable

    def __nonzero__(self):
        return self.is_immutable

    def __repr__(self):
        return '<%s>' % self.name

IR_MUTABLE              = ImmutableRanking('mutable', False)
IR_IMMUTABLE            = ImmutableRanking('immutable', True)
IR_IMMUTABLE_ARRAY      = ImmutableRanking('immutable_array', True)
IR_QUASIIMMUTABLE       = ImmutableRanking('quasiimmutable', False)
IR_QUASIIMMUTABLE_ARRAY = ImmutableRanking('quasiimmutable_array', False)

class ImmutableConflictError(Exception):
    """Raised when the _immutable_ or _immutable_fields_ hints are
    not consistent across a class hierarchy."""


def getclassrepr(rtyper, classdef):
    if classdef is None:
        return rtyper.rootclass_repr
    result = classdef.repr
    if result is None:
        result = classdef.repr = ClassRepr(rtyper, classdef)
        rtyper.add_pendingsetup(result)
    return result

def getinstancerepr(rtyper, classdef, default_flavor='gc'):
    if classdef is None:
        flavor = default_flavor
    else:
        flavor = getgcflavor(classdef)
    try:
        result = rtyper.instance_reprs[classdef, flavor]
    except KeyError:
        result = buildinstancerepr(rtyper, classdef, gcflavor=flavor)

        rtyper.instance_reprs[classdef, flavor] = result
        rtyper.add_pendingsetup(result)
    return result


def buildinstancerepr(rtyper, classdef, gcflavor='gc'):
    from rpython.rtyper.rvirtualizable import VirtualizableInstanceRepr

    if classdef is None:
        unboxed = []
        virtualizable = False
    else:
        unboxed = [subdef for subdef in classdef.getallsubdefs() if
            subdef.classdesc.pyobj is not None and
            issubclass(subdef.classdesc.pyobj, UnboxedValue)]
        virtualizable = classdef.classdesc.get_param('_virtualizable_', False)
    config = rtyper.annotator.translator.config
    usetagging = len(unboxed) != 0 and config.translation.taggedpointers

    if virtualizable:
        assert len(unboxed) == 0
        assert gcflavor == 'gc'
        return VirtualizableInstanceRepr(rtyper, classdef)
    elif usetagging:
        # the UnboxedValue class and its parent classes need a
        # special repr for their instances
        if len(unboxed) != 1:
            raise TyperError("%r has several UnboxedValue subclasses" % (
                classdef,))
        assert gcflavor == 'gc'
        from rpython.rtyper.lltypesystem import rtagged
        return rtagged.TaggedInstanceRepr(rtyper, classdef, unboxed[0])
    else:
        return InstanceRepr(rtyper, classdef, gcflavor)


class MissingRTypeAttribute(TyperError):
    pass

# ____________________________________________________________


#
#  There is one "vtable" per user class, with the following structure:
#  A root class "object" has:
#
#      struct object_vtable {
#          // struct object_vtable* parenttypeptr;  not used any more
#          RuntimeTypeInfo * rtti;
#          Signed subclassrange_min;  //this is also the id of the class itself
#          Signed subclassrange_max;
#          RPyString * name;
#          struct object * instantiate();
#      }
#
#  Every other class X, with parent Y, has the structure:
#
#      struct vtable_X {
#          struct vtable_Y super;   // inlined
#          ...                      // extra class attributes
#      }

# The type of the instances is:
#
#     struct object {       // for the root class
#         struct object_vtable* typeptr;
#     }
#
#     struct X {
#         struct Y super;   // inlined
#         ...               // extra instance attributes
#     }
#
# there's also a nongcobject

OBJECT_VTABLE = lltype.ForwardReference()
CLASSTYPE = Ptr(OBJECT_VTABLE)
OBJECT = GcStruct('object', ('typeptr', CLASSTYPE),
                  hints={'immutable': True, 'shouldntbenull': True,
                         'typeptr': True},
                  rtti=True)
OBJECTPTR = Ptr(OBJECT)
OBJECT_VTABLE.become(Struct('object_vtable',
                            #('parenttypeptr', CLASSTYPE),
                            ('subclassrange_min', Signed),
                            ('subclassrange_max', Signed),
                            ('rtti', Ptr(RuntimeTypeInfo)),
                            ('name', Ptr(rstr.STR)),
                            ('instantiate', Ptr(FuncType([], OBJECTPTR))),
                            hints={'immutable': True,
                                   'static_immutable': True}))
# non-gc case
NONGCOBJECT = Struct('nongcobject', ('typeptr', CLASSTYPE))
NONGCOBJECTPTR = Ptr(NONGCOBJECT)

OBJECT_BY_FLAVOR = {'gc': OBJECT, 'raw': NONGCOBJECT}
LLFLAVOR = {'gc': 'gc', 'raw': 'raw', 'stack': 'raw'}

def cast_vtable_to_typeptr(vtable):
    while typeOf(vtable).TO != OBJECT_VTABLE:
        vtable = vtable.super
    return vtable

def alloc_array_name(name):
    return rstr.string_repr.convert_const(name)


class ClassRepr(Repr):
    def __init__(self, rtyper, classdef):
        self.rtyper = rtyper
        self.classdef = classdef
        self.vtable_type = lltype.ForwardReference()
        self.lowleveltype = Ptr(self.vtable_type)

    def __repr__(self):
        if self.classdef is None:
            clsname = 'object'
        else:
            clsname = self.classdef.name
        return '<ClassRepr for %s>' % (clsname,)

    def compact_repr(self):
        if self.classdef is None:
            clsname = 'object'
        else:
            clsname = self.classdef.name
        return 'ClassR %s' % (clsname,)

    def convert_desc(self, desc):
        subclassdef = desc.getuniqueclassdef()
        if self.classdef is not None:
            if self.classdef.commonbase(subclassdef) != self.classdef:
                raise TyperError("not a subclass of %r: %r" % (
                    self.classdef.name, desc))

        r_subclass = getclassrepr(self.rtyper, subclassdef)
        return r_subclass.getruntime(self.lowleveltype)

    def convert_const(self, value):
        if not isinstance(value, (type, types.ClassType)):
            raise TyperError("not a class: %r" % (value,))
        bk = self.rtyper.annotator.bookkeeper
        return self.convert_desc(bk.getdesc(value))

    def prepare_method(self, s_value):
        # special-casing for methods:
        #  if s_value is SomePBC([MethodDescs...])
        #  return a PBC representing the underlying functions
        if (isinstance(s_value, annmodel.SomePBC) and
                s_value.getKind() == description.MethodDesc):
            s_value = self.classdef.lookup_filter(s_value)
            funcdescs = [mdesc.funcdesc for mdesc in s_value.descriptions]
            return annmodel.SomePBC(funcdescs)
        return None   # not a method

    def get_ll_eq_function(self):
        return None

    def _setup_repr(self):
        # NOTE: don't store mutable objects like the dicts below on 'self'
        #       before they are fully built, to avoid strange bugs in case
        #       of recursion where other code would uses these
        #       partially-initialized dicts.
        clsfields = {}
        pbcfields = {}
        allmethods = {}
        # class attributes
        llfields = []
        for name, attrdef in self.classdef.attrs.items():
            if attrdef.readonly:
                s_value = attrdef.s_value
                s_unboundmethod = self.prepare_method(s_value)
                if s_unboundmethod is not None:
                    allmethods[name] = True
                    s_value = s_unboundmethod
                r = self.rtyper.getrepr(s_value)
                mangled_name = 'cls_' + name
                clsfields[name] = mangled_name, r
                llfields.append((mangled_name, r.lowleveltype))
        # attributes showing up in getattrs done on the class as a PBC
        extra_access_sets = self.classdef.extra_access_sets
        for access_set, (attr, counter) in extra_access_sets.items():
            r = self.rtyper.getrepr(access_set.s_value)
            mangled_name = mangle('pbc%d' % counter, attr)
            pbcfields[access_set, attr] = mangled_name, r
            llfields.append((mangled_name, r.lowleveltype))
        llfields.sort()
        llfields.sort(key=attr_reverse_size)
        #
        self.rbase = getclassrepr(self.rtyper, self.classdef.basedef)
        self.rbase.setup()
        kwds = {'hints': {'immutable': True, 'static_immutable': True}}
        vtable_type = Struct('%s_vtable' % self.classdef.name,
                                ('super', self.rbase.vtable_type),
                                *llfields, **kwds)
        self.vtable_type.become(vtable_type)
        allmethods.update(self.rbase.allmethods)
        self.clsfields = clsfields
        self.pbcfields = pbcfields
        self.allmethods = allmethods
        self.vtable = None

    def getvtable(self):
        """Return a ptr to the vtable of this type."""
        if self.vtable is None:
            self.init_vtable()
        return cast_vtable_to_typeptr(self.vtable)

    def getruntime(self, expected_type):
        assert expected_type == CLASSTYPE
        return self.getvtable()

    def init_vtable(self):
        """Create the actual vtable"""
        self.vtable = malloc(self.vtable_type, immortal=True)
        vtable_part = self.vtable
        r_parentcls = self
        while r_parentcls.classdef is not None:
            self.setup_vtable(vtable_part, r_parentcls)
            vtable_part = vtable_part.super
            r_parentcls = r_parentcls.rbase
        self.fill_vtable_root(vtable_part)

    def setup_vtable(self, vtable, r_parentcls):
        """Initialize the vtable portion corresponding to 'r_parentcls'."""
        # setup class attributes: for each attribute name at the level
        # of 'r_parentcls', look up its value in the class
        def assign(mangled_name, value):
            if value is None:
                llvalue = r.special_uninitialized_value()
                if llvalue is None:
                    return
            else:
                if (isinstance(value, Constant) and
                        isinstance(value.value, staticmethod)):
                    value = Constant(value.value.__get__(42))   # staticmethod => bare function
                llvalue = r.convert_desc_or_const(value)
            setattr(vtable, mangled_name, llvalue)

        for fldname in r_parentcls.clsfields:
            mangled_name, r = r_parentcls.clsfields[fldname]
            if r.lowleveltype is Void:
                continue
            value = self.classdef.classdesc.read_attribute(fldname, None)
            assign(mangled_name, value)
        # extra PBC attributes
        for (access_set, attr), (mangled_name, r) in r_parentcls.pbcfields.items():
            if self.classdef.classdesc not in access_set.descs:
                continue   # only for the classes in the same pbc access set
            if r.lowleveltype is Void:
                continue
            attrvalue = self.classdef.classdesc.read_attribute(attr, None)
            assign(mangled_name, attrvalue)

    def fill_vtable_root(self, vtable):
        """Initialize the head of the vtable."""
        # initialize the 'subclassrange_*' and 'name' fields
        if self.classdef is not None:
            #vtable.parenttypeptr = self.rbase.getvtable()
            vtable.subclassrange_min = self.classdef.minid
            vtable.subclassrange_max = self.classdef.maxid
        else:  # for the root class
            vtable.subclassrange_min = 0
            vtable.subclassrange_max = sys.maxint
        rinstance = getinstancerepr(self.rtyper, self.classdef)
        rinstance.setup()
        if rinstance.gcflavor == 'gc':
            vtable.rtti = getRuntimeTypeInfo(rinstance.object_type)
        if self.classdef is None:
            name = 'object'
        else:
            name = self.classdef.shortname
        vtable.name = alloc_array_name(name)
        if hasattr(self.classdef, 'my_instantiate_graph'):
            graph = self.classdef.my_instantiate_graph
            vtable.instantiate = self.rtyper.getcallable(graph)
        #else: the classdef was created recently, so no instantiate()
        #      could reach it

    def fromtypeptr(self, vcls, llops):
        """Return the type pointer cast to self's vtable type."""
        self.setup()
        castable(self.lowleveltype, vcls.concretetype)  # sanity check
        return llops.genop('cast_pointer', [vcls],
                           resulttype=self.lowleveltype)

    fromclasstype = fromtypeptr

    def getclsfield(self, vcls, attr, llops):
        """Read the given attribute of 'vcls'."""
        if attr in self.clsfields:
            mangled_name, r = self.clsfields[attr]
            v_vtable = self.fromtypeptr(vcls, llops)
            cname = inputconst(Void, mangled_name)
            return llops.genop('getfield', [v_vtable, cname], resulttype=r)
        else:
            if self.classdef is None:
                raise MissingRTypeAttribute(attr)
            return self.rbase.getclsfield(vcls, attr, llops)

    def setclsfield(self, vcls, attr, vvalue, llops):
        """Write the given attribute of 'vcls'."""
        if attr in self.clsfields:
            mangled_name, r = self.clsfields[attr]
            v_vtable = self.fromtypeptr(vcls, llops)
            cname = inputconst(Void, mangled_name)
            llops.genop('setfield', [v_vtable, cname, vvalue])
        else:
            if self.classdef is None:
                raise MissingRTypeAttribute(attr)
            self.rbase.setclsfield(vcls, attr, vvalue, llops)

    def getpbcfield(self, vcls, access_set, attr, llops):
        if (access_set, attr) not in self.pbcfields:
            raise TyperError("internal error: missing PBC field")
        mangled_name, r = self.pbcfields[access_set, attr]
        v_vtable = self.fromtypeptr(vcls, llops)
        cname = inputconst(Void, mangled_name)
        return llops.genop('getfield', [v_vtable, cname], resulttype=r)

    def rtype_issubtype(self, hop):
        class_repr = get_type_repr(self.rtyper)
        v_cls1, v_cls2 = hop.inputargs(class_repr, class_repr)
        if isinstance(v_cls2, Constant):
            cls2 = v_cls2.value
            minid = hop.inputconst(Signed, cls2.subclassrange_min)
            maxid = hop.inputconst(Signed, cls2.subclassrange_max)
            return hop.gendirectcall(ll_issubclass_const, v_cls1, minid,
                                     maxid)
        else:
            v_cls1, v_cls2 = hop.inputargs(class_repr, class_repr)
            return hop.gendirectcall(ll_issubclass, v_cls1, v_cls2)

    def ll_str(self, cls):
        return cls.name


class RootClassRepr(ClassRepr):
    """ClassRepr for the root of the class hierarchy"""
    classdef = None

    def __init__(self, rtyper):
        self.rtyper = rtyper
        self.vtable_type = OBJECT_VTABLE
        self.lowleveltype = Ptr(self.vtable_type)

    def _setup_repr(self):
        self.clsfields = {}
        self.pbcfields = {}
        self.allmethods = {}
        self.vtable = None

    def init_vtable(self):
        self.vtable = malloc(self.vtable_type, immortal=True)
        self.fill_vtable_root(self.vtable)

def get_type_repr(rtyper):
    return rtyper.rootclass_repr

# ____________________________________________________________


class __extend__(annmodel.SomeInstance):
    def rtyper_makerepr(self, rtyper):
        return getinstancerepr(rtyper, self.classdef)

    def rtyper_makekey(self):
        return self.__class__, self.classdef

class __extend__(annmodel.SomeException):
    def rtyper_makerepr(self, rtyper):
        return self.as_SomeInstance().rtyper_makerepr(rtyper)

    def rtyper_makekey(self):
        return self.__class__, frozenset(self.classdefs)

class __extend__(annmodel.SomeType):
    def rtyper_makerepr(self, rtyper):
        return get_type_repr(rtyper)

    def rtyper_makekey(self):
        return self.__class__,


class InstanceRepr(Repr):
    def __init__(self, rtyper, classdef, gcflavor='gc'):
        self.rtyper = rtyper
        self.classdef = classdef
        if classdef is None:
            self.object_type = OBJECT_BY_FLAVOR[LLFLAVOR[gcflavor]]
        else:
            ForwardRef = lltype.FORWARDREF_BY_FLAVOR[LLFLAVOR[gcflavor]]
            self.object_type = ForwardRef()
        self.iprebuiltinstances = identity_dict()
        self.lowleveltype = Ptr(self.object_type)
        self.gcflavor = gcflavor

    def has_special_memory_pressure(self, tp):
        if 'special_memory_pressure' in tp._flds:
            return True
        if 'super' in tp._flds:
            return self.has_special_memory_pressure(tp._flds['super'])
        return False

    def _setup_repr(self, llfields=None, hints=None, adtmeths=None):
        # NOTE: don't store mutable objects like the dicts below on 'self'
        #       before they are fully built, to avoid strange bugs in case
        #       of recursion where other code would uses these
        #       partially-initialized dicts.
        if self.classdef is None:
            self.immutable_field_set = set()
        self.rclass = getclassrepr(self.rtyper, self.classdef)
        fields = {}
        allinstancefields = {}
        if self.classdef is None:
            fields['__class__'] = 'typeptr', get_type_repr(self.rtyper)
        else:
            # instance attributes
            attrs = self.classdef.attrs.items()
            attrs.sort()
            myllfields = []
            for name, attrdef in attrs:
                if not attrdef.readonly:
                    r = self.rtyper.getrepr(attrdef.s_value)
                    mangled_name = 'inst_' + name
                    fields[name] = mangled_name, r
                    myllfields.append((mangled_name, r.lowleveltype))

            myllfields.sort(key=attr_reverse_size)
            if llfields is None:
                llfields = myllfields
            else:
                llfields = llfields + myllfields

            self.rbase = getinstancerepr(self.rtyper, self.classdef.basedef,
                                         self.gcflavor)
            self.rbase.setup()

            MkStruct = lltype.STRUCT_BY_FLAVOR[LLFLAVOR[self.gcflavor]]
            if adtmeths is None:
                adtmeths = {}
            if hints is None:
                hints = {}
            hints = self._check_for_immutable_hints(hints)
            if self.classdef.classdesc.get_param('_rpython_never_allocate_'):
                hints['never_allocate'] = True

            kwds = {}
            if self.gcflavor == 'gc':
                kwds['rtti'] = True

            for name, attrdef in attrs:
                if not attrdef.readonly and self.is_quasi_immutable(name):
                    llfields.append(('mutate_' + name, OBJECTPTR))

            bookkeeper = self.rtyper.annotator.bookkeeper
            if self.classdef in bookkeeper.memory_pressure_types:
                # we don't need to add it if it's already there for some of
                # the parent type
                if not self.has_special_memory_pressure(self.rbase.object_type):
                    llfields.append(('special_memory_pressure', lltype.Signed))
                    fields['special_memory_pressure'] = (
                        'special_memory_pressure',
                        self.rtyper.getrepr(lltype_to_annotation(lltype.Signed)))

            object_type = MkStruct(self.classdef.name,
                                   ('super', self.rbase.object_type),
                                   hints=hints,
                                   adtmeths=adtmeths,
                                   *llfields,
                                   **kwds)
            self.object_type.become(object_type)
            allinstancefields.update(self.rbase.allinstancefields)
        allinstancefields.update(fields)
        self.fields = fields
        self.allinstancefields = allinstancefields

    def _check_for_immutable_hints(self, hints):
        hints = hints.copy()
        classdesc = self.classdef.classdesc
        immut = classdesc.get_param('_immutable_', inherit=False)
        if immut is None:
            if classdesc.get_param('_immutable_', inherit=True):
                raise ImmutableConflictError(
                    "class %r inherits from its parent _immutable_=True, "
                    "so it should also declare _immutable_=True" % (
                        self.classdef,))
        elif immut is not True:
            raise TyperError(
                "class %r: _immutable_ = something else than True" % (
                    self.classdef,))
        else:
            hints['immutable'] = True
        self.immutable_field_set = classdesc.immutable_fields
        if (classdesc.immutable_fields or
                'immutable_fields' in self.rbase.object_type._hints):
            accessor = FieldListAccessor()
            hints['immutable_fields'] = accessor
        return hints

    def __repr__(self):
        if self.classdef is None:
            clsname = 'object'
        else:
            clsname = self.classdef.name
        return '<InstanceRepr for %s>' % (clsname,)

    def compact_repr(self):
        if self.classdef is None:
            clsname = 'object'
        else:
            clsname = self.classdef.name
        return 'InstanceR %s' % (clsname,)

    def _setup_repr_final(self):
        self._setup_immutable_field_list()
        self._check_for_immutable_conflicts()
        if self.gcflavor == 'gc':
            if (self.classdef is not None and
                    self.classdef.classdesc.lookup('__del__') is not None):
                s_func = self.classdef.classdesc.s_read_attribute('__del__')
                source_desc = self.classdef.classdesc.lookup('__del__')
                source_classdef = source_desc.getclassdef(None)
                source_repr = getinstancerepr(self.rtyper, source_classdef)
                assert len(s_func.descriptions) == 1
                funcdesc, = s_func.descriptions
                graph = funcdesc.getuniquegraph()
                self.check_graph_of_del_does_not_call_too_much(self.rtyper,
                                                               graph)
                FUNCTYPE = FuncType([Ptr(source_repr.object_type)], Void)
                destrptr = functionptr(FUNCTYPE, graph.name,
                                       graph=graph,
                                       _callable=graph.func)
            else:
                destrptr = None
            self.rtyper.call_all_setups()  # compute ForwardReferences now
            args_s = [SomePtr(Ptr(OBJECT))]
            graph = self.rtyper.annotate_helper(ll_runtime_type_info, args_s)
            s = self.rtyper.annotation(graph.getreturnvar())
            if (not isinstance(s, SomePtr) or
                s.ll_ptrtype != Ptr(RuntimeTypeInfo)):
                raise TyperError("runtime type info function returns %r, "
                                "expected Ptr(RuntimeTypeInfo)" % (s))
            funcptr = self.rtyper.getcallable(graph)
            attachRuntimeTypeInfo(self.object_type, funcptr, destrptr)

            vtable = self.rclass.getvtable()
            self.rtyper.set_type_for_typeptr(vtable, self.lowleveltype.TO)

    def _setup_immutable_field_list(self):
        hints = self.object_type._hints
        if "immutable_fields" in hints:
            accessor = hints["immutable_fields"]
            if not hasattr(accessor, 'fields'):
                immutable_fields = set()
                rbase = self
                while rbase.classdef is not None:
                    immutable_fields.update(rbase.immutable_field_set)
                    rbase = rbase.rbase
                self._parse_field_list(immutable_fields, accessor, hints)

    def _parse_field_list(self, fields, accessor, hints):
        ranking = {}
        for fullname in fields:
            name = fullname
            quasi = False
            if name.endswith('?[*]'):   # a quasi-immutable field pointing to
                name = name[:-4]        # an immutable array
                rank = IR_QUASIIMMUTABLE_ARRAY
                quasi = True
            elif name.endswith('[*]'):    # for virtualizables' lists
                name = name[:-3]
                rank = IR_IMMUTABLE_ARRAY
            elif name.endswith('?'):    # a quasi-immutable field
                name = name[:-1]
                rank = IR_QUASIIMMUTABLE
                quasi = True
            else:                       # a regular immutable/green field
                rank = IR_IMMUTABLE
            try:
                mangled_name, r = self._get_field(name)
            except KeyError:
                continue
            if quasi and hints.get("immutable"):
                raise TyperError(
                    "can't have _immutable_ = True and a quasi-immutable field "
                    "%s in class %s" % (name, self.classdef))
            if rank in (IR_QUASIIMMUTABLE_ARRAY, IR_IMMUTABLE_ARRAY):
                from rpython.rtyper.rlist import AbstractBaseListRepr
                if not isinstance(r, AbstractBaseListRepr):
                    raise TyperError(
                        "_immutable_fields_ = [%r] in %r, but %r is not a list "
                        "(got %r)" % (fullname, self, name, r))
            ranking[mangled_name] = rank
        accessor.initialize(self.object_type, ranking)
        return ranking

    def _check_for_immutable_conflicts(self):
        # check for conflicts, i.e. a field that is defined normally as
        # mutable in some parent class but that is now declared immutable
        is_self_immutable = "immutable" in self.object_type._hints
        base = self
        while base.classdef is not None:
            base = base.rbase
            for fieldname in base.fields:
                if fieldname == 'special_memory_pressure':
                    continue
                try:
                    mangled, r = base._get_field(fieldname)
                except KeyError:
                    continue
                if r.lowleveltype == Void:
                    continue
                base._setup_immutable_field_list()
                if base.object_type._immutable_field(mangled):
                    continue
                # 'fieldname' is a mutable, non-Void field in the parent
                if is_self_immutable:
                    raise ImmutableConflictError(
                        "class %r has _immutable_=True, but parent class %r "
                        "defines (at least) the mutable field %r" %
                        (self, base, fieldname))
                if (fieldname in self.immutable_field_set or
                        (fieldname + '?') in self.immutable_field_set):
                    raise ImmutableConflictError(
                        "field %r is defined mutable in class %r, but "
                        "listed in _immutable_fields_ in subclass %r" %
                        (fieldname, base, self))

    def hook_access_field(self, vinst, cname, llops, flags):
        pass        # for virtualizables; see rvirtualizable.py

    def hook_setfield(self, vinst, fieldname, llops):
        if self.is_quasi_immutable(fieldname):
            c_fieldname = inputconst(Void, 'mutate_' + fieldname)
            llops.genop('jit_force_quasi_immutable', [vinst, c_fieldname])

    def is_quasi_immutable(self, fieldname):
        search1 = fieldname + '?'
        search2 = fieldname + '?[*]'
        rbase = self
        while rbase.classdef is not None:
            if (search1 in rbase.immutable_field_set or
                    search2 in rbase.immutable_field_set):
                return True
            rbase = rbase.rbase
        return False

    def new_instance(self, llops, classcallhop=None, nonmovable=False):
        """Build a new instance, without calling __init__."""
        flavor = self.gcflavor
        flags = {'flavor': flavor}
        if nonmovable:
            flags['nonmovable'] = True
        ctype = inputconst(Void, self.object_type)
        cflags = inputconst(Void, flags)
        vlist = [ctype, cflags]
        vptr = llops.genop('malloc', vlist,
                           resulttype=Ptr(self.object_type))
        ctypeptr = inputconst(CLASSTYPE, self.rclass.getvtable())
        self.setfield(vptr, '__class__', ctypeptr, llops)
        if self.has_special_memory_pressure(self.object_type):
            self.setfield(vptr, 'special_memory_pressure',
                inputconst(lltype.Signed, 0), llops)
        # initialize instance attributes from their defaults from the class
        if self.classdef is not None:
            flds = self.allinstancefields.keys()
            flds.sort()
            for fldname in flds:
                if fldname == '__class__':
                    continue
                mangled_name, r = self.allinstancefields[fldname]
                if r.lowleveltype is Void:
                    continue
                value = self.classdef.classdesc.read_attribute(fldname, None)
                if value is not None:
                    ll_value = r.convert_desc_or_const(value)
                    # don't write NULL GC pointers: we know that the malloc
                    # done above initialized at least the GC Ptr fields to
                    # NULL already, and that's true for all our GCs
                    if (isinstance(r.lowleveltype, Ptr) and
                            r.lowleveltype.TO._gckind == 'gc' and
                            not ll_value):
                        continue
                    cvalue = inputconst(r.lowleveltype, ll_value)
                    self.setfield(vptr, fldname, cvalue, llops,
                                  flags={'access_directly': True})
        return vptr

    def convert_const(self, value):
        if value is None:
            return self.null_instance()
        if isinstance(value, types.MethodType):
            value = value.im_self   # bound method -> instance
        bk = self.rtyper.annotator.bookkeeper
        try:
            classdef = bk.getuniqueclassdef(value.__class__)
        except KeyError:
            raise TyperError("no classdef: %r" % (value.__class__,))
        if classdef != self.classdef:
            # if the class does not match exactly, check that 'value' is an
            # instance of a subclass and delegate to that InstanceRepr
            if classdef.commonbase(self.classdef) != self.classdef:
                raise TyperError("not an instance of %r: %r" % (
                    self.classdef.name, value))
            rinstance = getinstancerepr(self.rtyper, classdef)
            result = rinstance.convert_const(value)
            return self.upcast(result)
        # common case
        return self.convert_const_exact(value)

    def convert_const_exact(self, value):
        try:
            return self.iprebuiltinstances[value]
        except KeyError:
            self.setup()
            result = self.create_instance()
            self.iprebuiltinstances[value] = result
            self.initialize_prebuilt_instance(value, self.classdef, result)
            return result

    def get_reusable_prebuilt_instance(self):
        "Get a dummy prebuilt instance.  Multiple calls reuse the same one."
        try:
            return self._reusable_prebuilt_instance
        except AttributeError:
            self.setup()
            result = self.create_instance()
            self._reusable_prebuilt_instance = result
            self.initialize_prebuilt_data(Ellipsis, self.classdef, result)
            return result

    _initialize_data_flattenrec = FlattenRecursion()

    def initialize_prebuilt_instance(self, value, classdef, result):
        # must fill in the hash cache before the other ones
        # (see test_circular_hash_initialization)
        self._initialize_data_flattenrec(self.initialize_prebuilt_data,
                                         value, classdef, result)

    def get_ll_hash_function(self):
        return ll_inst_hash

    get_ll_fasthash_function = get_ll_hash_function

    def rtype_type(self, hop):
        if hop.s_result.is_constant():
            return hop.inputconst(hop.r_result, hop.s_result.const)
        instance_repr = self.common_repr()
        vinst, = hop.inputargs(instance_repr)
        if hop.args_s[0].can_be_none():
            return hop.gendirectcall(ll_inst_type, vinst)
        else:
            return instance_repr.getfield(vinst, '__class__', hop.llops)

    def rtype_getattr(self, hop):
        if hop.s_result.is_constant():
            return hop.inputconst(hop.r_result, hop.s_result.const)
        attr = hop.args_s[1].const
        vinst, vattr = hop.inputargs(self, Void)
        if attr == '__class__' and hop.r_result.lowleveltype is Void:
            # special case for when the result of '.__class__' is a constant
            [desc] = hop.s_result.descriptions
            return hop.inputconst(Void, desc.pyobj)
        if attr in self.allinstancefields:
            return self.getfield(vinst, attr, hop.llops,
                                 flags=hop.args_s[0].flags)
        elif attr in self.rclass.allmethods:
            # special case for methods: represented as their 'self' only
            # (see MethodsPBCRepr)
            return hop.r_result.get_method_from_instance(self, vinst,
                                                         hop.llops)
        else:
            vcls = self.getfield(vinst, '__class__', hop.llops)
            return self.rclass.getclsfield(vcls, attr, hop.llops)

    def rtype_setattr(self, hop):
        attr = hop.args_s[1].const
        r_value = self.getfieldrepr(attr)
        vinst, vattr, vvalue = hop.inputargs(self, Void, r_value)
        self.setfield(vinst, attr, vvalue, hop.llops,
                      flags=hop.args_s[0].flags)

    def rtype_bool(self, hop):
        vinst, = hop.inputargs(self)
        return hop.genop('ptr_nonzero', [vinst], resulttype=Bool)

    def ll_str(self, i):  # doesn't work for non-gc classes!
        from rpython.rtyper.lltypesystem.ll_str import ll_int2hex
        from rpython.rlib.rarithmetic import r_uint
        if not i:
            return rstr.conststr("NULL")
        instance = cast_pointer(OBJECTPTR, i)
        # Two choices: the first gives a fast answer but it can change
        # (typically only once) during the life of the object.
        #uid = r_uint(cast_ptr_to_int(i))
        uid = r_uint(llop.gc_id(lltype.Signed, i))
        #
        res = rstr.conststr("<")
        res = rstr.ll_strconcat(res, instance.typeptr.name)
        res = rstr.ll_strconcat(res, rstr.conststr(" object at 0x"))
        res = rstr.ll_strconcat(res, ll_int2hex(uid, False))
        res = rstr.ll_strconcat(res, rstr.conststr(">"))
        return res

    def get_ll_eq_function(self):
        return None    # defaults to compare by identity ('==' on pointers)

    def can_ll_be_null(self, s_value):
        return s_value.can_be_none()

    @staticmethod
    def check_graph_of_del_does_not_call_too_much(rtyper, graph):
        # RPython-level __del__() methods should not do "too much".
        # In the PyPy Python interpreter, they usually do simple things
        # like file.__del__() closing the file descriptor; or if they
        # want to do more like call an app-level __del__() method, they
        # enqueue the object instead, and the actual call is done later.
        #
        # Here, as a quick way to check "not doing too much", we check
        # that from no RPython-level __del__() method we can reach a
        # JitDriver.
        #
        # XXX wrong complexity, but good enough because the set of
        # reachable graphs should be small
        callgraph = rtyper.annotator.translator.callgraph.values()
        seen = {graph: None}
        while True:
            oldlength = len(seen)
            for caller, callee in callgraph:
                if caller in seen and callee not in seen:
                    func = getattr(callee, 'func', None)
                    if getattr(func, '_dont_reach_me_in_del_', False):
                        lst = [str(callee)]
                        g = caller
                        while g:
                            lst.append(str(g))
                            g = seen.get(g)
                        lst.append('')
                        raise TyperError("the RPython-level __del__() method "
                                         "in %r calls:%s" %
                                         (graph, '\n\t'.join(lst[::-1])))
                    if getattr(func, '_cannot_really_call_random_things_',
                               False):
                        continue
                    seen[callee] = caller
            if len(seen) == oldlength:
                break

    def common_repr(self):  # -> object or nongcobject reprs
        return getinstancerepr(self.rtyper, None, self.gcflavor)

    def _get_field(self, attr):
        return self.fields[attr]

    def null_instance(self):
        return nullptr(self.object_type)

    def upcast(self, result):
        return cast_pointer(self.lowleveltype, result)

    def create_instance(self):
        return malloc(self.object_type, flavor=self.gcflavor, immortal=True)

    def initialize_prebuilt_data(self, value, classdef, result):
        if self.classdef is not None:
            # recursively build the parent part of the instance
            self.rbase.initialize_prebuilt_data(value, classdef, result.super)
            # then add instance attributes from this level
            for name, (mangled_name, r) in self.fields.items():
                if r.lowleveltype is Void:
                    llattrvalue = None
                else:
                    try:
                        attrvalue = getattr(value, name)
                    except AttributeError:
                        attrvalue = self.classdef.classdesc.read_attribute(
                            name, None)
                        if attrvalue is None:
                            # Ellipsis from get_reusable_prebuilt_instance()
                            #if value is not Ellipsis:
                                #warning("prebuilt instance %r has no "
                                #        "attribute %r" % (value, name))
                            llattrvalue = r.lowleveltype._defl()
                        else:
                            llattrvalue = r.convert_desc_or_const(attrvalue)
                    else:
                        llattrvalue = r.convert_const(attrvalue)
                setattr(result, mangled_name, llattrvalue)
        else:
            # OBJECT part
            rclass = getclassrepr(self.rtyper, classdef)
            result.typeptr = rclass.getvtable()

    def getfieldrepr(self, attr):
        """Return the repr used for the given attribute."""
        if attr in self.fields:
            mangled_name, r = self.fields[attr]
            return r
        else:
            if self.classdef is None:
                raise MissingRTypeAttribute(attr)
            return self.rbase.getfieldrepr(attr)

    def getfield(self, vinst, attr, llops, force_cast=False, flags={}):
        """Read the given attribute (or __class__ for the type) of 'vinst'."""
        if attr in self.fields:
            mangled_name, r = self.fields[attr]
            cname = inputconst(Void, mangled_name)
            if force_cast:
                vinst = llops.genop('cast_pointer', [vinst], resulttype=self)
            self.hook_access_field(vinst, cname, llops, flags)
            return llops.genop('getfield', [vinst, cname], resulttype=r)
        else:
            if self.classdef is None:
                raise MissingRTypeAttribute(attr)
            return self.rbase.getfield(vinst, attr, llops, force_cast=True,
                                       flags=flags)

    def setfield(self, vinst, attr, vvalue, llops, force_cast=False,
                 flags={}):
        """Write the given attribute (or __class__ for the type) of 'vinst'."""
        if attr in self.fields:
            mangled_name, r = self.fields[attr]
            cname = inputconst(Void, mangled_name)
            if force_cast:
                vinst = llops.genop('cast_pointer', [vinst], resulttype=self)
            self.hook_access_field(vinst, cname, llops, flags)
            self.hook_setfield(vinst, attr, llops)
            llops.genop('setfield', [vinst, cname, vvalue])
        else:
            if self.classdef is None:
                raise MissingRTypeAttribute(attr)
            self.rbase.setfield(vinst, attr, vvalue, llops, force_cast=True,
                                flags=flags)

    def rtype_isinstance(self, hop):
        class_repr = get_type_repr(hop.rtyper)
        instance_repr = self.common_repr()

        v_obj, v_cls = hop.inputargs(instance_repr, class_repr)
        if isinstance(v_cls, Constant):
            cls = v_cls.value
            llf, llf_nonnull = make_ll_isinstance(self.rtyper, cls)
            if hop.args_s[0].can_be_None:
                return hop.gendirectcall(llf, v_obj)
            else:
                return hop.gendirectcall(llf_nonnull, v_obj)
        else:
            return hop.gendirectcall(ll_isinstance, v_obj, v_cls)


class __extend__(pairtype(InstanceRepr, InstanceRepr)):
    def convert_from_to((r_ins1, r_ins2), v, llops):
        # which is a subclass of which?
        if r_ins1.classdef is None or r_ins2.classdef is None:
            basedef = None
        else:
            basedef = r_ins1.classdef.commonbase(r_ins2.classdef)
        if basedef == r_ins2.classdef:
            # r_ins1 is an instance of the subclass: converting to parent
            v = llops.genop('cast_pointer', [v],
                            resulttype=r_ins2.lowleveltype)
            return v
        elif basedef == r_ins1.classdef:
            # r_ins2 is an instance of the subclass: potentially unsafe
            # casting, but we do it anyway (e.g. the annotator produces
            # such casts after a successful isinstance() check)
            v = llops.genop('cast_pointer', [v],
                            resulttype=r_ins2.lowleveltype)
            return v
        else:
            return NotImplemented

    def rtype_is_((r_ins1, r_ins2), hop):
        if r_ins1.gcflavor != r_ins2.gcflavor:
            # obscure logic, the is can be true only if both are None
            v_ins1, v_ins2 = hop.inputargs(
                r_ins1.common_repr(), r_ins2.common_repr())
            return hop.gendirectcall(ll_both_none, v_ins1, v_ins2)
        if r_ins1.classdef is None or r_ins2.classdef is None:
            basedef = None
        else:
            basedef = r_ins1.classdef.commonbase(r_ins2.classdef)
        r_ins = getinstancerepr(r_ins1.rtyper, basedef, r_ins1.gcflavor)
        return pairtype(Repr, Repr).rtype_is_(pair(r_ins, r_ins), hop)

    rtype_eq = rtype_is_

    def rtype_ne(rpair, hop):
        v = rpair.rtype_eq(hop)
        return hop.genop("bool_not", [v], resulttype=Bool)

# ____________________________________________________________

def rtype_new_instance(rtyper, classdef, llops, classcallhop=None,
                       nonmovable=False):
    rinstance = getinstancerepr(rtyper, classdef)
    return rinstance.new_instance(llops, classcallhop, nonmovable=nonmovable)

def ll_inst_hash(ins):
    if not ins:
        return 0    # for None
    else:
        return lltype.identityhash(ins)


_missing = object()

def fishllattr(inst, name, default=_missing):
    p = widest = lltype.normalizeptr(inst)
    while True:
        try:
            return getattr(p, 'inst_' + name)
        except AttributeError:
            pass
        try:
            p = p.super
        except AttributeError:
            break
    if default is _missing:
        raise AttributeError("%s has no field %s" %
                             (lltype.typeOf(widest), name))
    return default

def attr_reverse_size((_, T)):
    # This is used to sort the instance or class attributes by decreasing
    # "likely size", as reported by rffi.sizeof(), to minimize padding
    # holes in C.  Fields should first be sorted by name, just to minimize
    # randomness, and then (stably) sorted by 'attr_reverse_size'.
    if T is lltype.Void:
        return None
    from rpython.rtyper.lltypesystem.rffi import sizeof
    try:
        return -sizeof(T)
    except StandardError:
        return None

# ____________________________________________________________
#
#  Low-level implementation of operations on classes and instances

# doesn't work for non-gc stuff!
def ll_cast_to_object(obj):
    return cast_pointer(OBJECTPTR, obj)

# doesn't work for non-gc stuff!
def ll_type(obj):
    return cast_pointer(OBJECTPTR, obj).typeptr

def ll_issubclass(subcls, cls):
    return llop.int_between(Bool,
                            cls.subclassrange_min,
                            subcls.subclassrange_min,
                            cls.subclassrange_max)

def ll_issubclass_const(subcls, minid, maxid):
    return llop.int_between(Bool, minid, subcls.subclassrange_min, maxid)


def ll_isinstance(obj, cls):  # obj should be cast to OBJECT or NONGCOBJECT
    if not obj:
        return False
    obj_cls = obj.typeptr
    return ll_issubclass(obj_cls, cls)

def make_ll_isinstance(rtyper, cls):
    try:
        return rtyper.isinstance_helpers[cls._obj]
    except KeyError:
        minid = cls.subclassrange_min
        maxid = cls.subclassrange_max
        if minid.number_with_subclasses():
            def ll_isinstance_const_nonnull(obj):
                objid = obj.typeptr.subclassrange_min
                return llop.int_between(Bool, minid, objid, maxid)
        else:
            def ll_isinstance_const_nonnull(obj):
                return obj.typeptr == cls
        def ll_isinstance_const(obj):
            if not obj:
                return False
            return ll_isinstance_const_nonnull(obj)
        result = (ll_isinstance_const, ll_isinstance_const_nonnull)
        rtyper.isinstance_helpers[cls._obj] = result
        return result

def ll_runtime_type_info(obj):
    return obj.typeptr.rtti

def ll_inst_type(obj):
    if obj:
        return obj.typeptr
    else:
        # type(None) -> NULL  (for now)
        return nullptr(typeOf(obj).TO.typeptr.TO)

def ll_both_none(ins1, ins2):
    return not ins1 and not ins2

# ____________________________________________________________

def feedllattr(inst, name, llvalue):
    p = widest = lltype.normalizeptr(inst)
    while True:
        try:
            return setattr(p, 'inst_' + name, llvalue)
        except AttributeError:
            pass
        try:
            p = p.super
        except AttributeError:
            break
    raise AttributeError("%s has no field %s" % (lltype.typeOf(widest),
                                                 name))

def declare_type_for_typeptr(vtable, TYPE):
    """Hack for custom low-level-only 'subclasses' of OBJECT:
    call this somewhere annotated, in order to declare that it is
    of the given TYPE and has got the corresponding vtable."""

class Entry(ExtRegistryEntry):
    _about_ = declare_type_for_typeptr

    def compute_result_annotation(self, s_vtable, s_TYPE):
        assert s_vtable.is_constant()
        assert s_TYPE.is_constant()
        return annmodel.s_None

    def specialize_call(self, hop):
        vtable = hop.args_v[0].value
        TYPE = hop.args_v[1].value
        assert lltype.typeOf(vtable) == CLASSTYPE
        assert isinstance(TYPE, GcStruct)
        assert lltype._castdepth(TYPE, OBJECT) > 0
        hop.rtyper.set_type_for_typeptr(vtable, TYPE)
        hop.exception_cannot_occur()
        return hop.inputconst(lltype.Void, None)
