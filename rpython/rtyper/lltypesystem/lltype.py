import weakref
from types import MethodType, NoneType

from rpython.annotator.bookkeeper import analyzer_for, immutablevalue
from rpython.annotator.model import (
        AnnotatorError, SomeBool, SomeInteger, SomeObject)
from rpython.rlib.objectmodel import Symbolic
from rpython.rlib.rarithmetic import (
    base_int, intmask, is_emulated_long, is_valid_int, longlonglongmask,
    longlongmask, maxint, normalizedinttype, r_int, r_longfloat, r_longlong,
    r_longlonglong, r_singlefloat, r_uint, r_ulonglong, r_ulonglonglong)
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.tool import leakfinder
from rpython.tool.identity_dict import identity_dict

class State(object):
    pass

TLS = State()

class WeakValueDictionary(weakref.WeakValueDictionary):
    """A subclass of weakref.WeakValueDictionary
    which resets the 'nested_hash_level' when keys are being deleted.
    """
    def __init__(self, *args, **kwargs):
        weakref.WeakValueDictionary.__init__(self, *args, **kwargs)
        remove_base = self._remove
        def remove(*args):
            if safe_equal is None:
                # The interpreter is shutting down, and the comparison
                # function is already gone.
                return
            if TLS is None: # Happens when the interpreter is shutting down
                return remove_base(*args)
            nested_hash_level = TLS.nested_hash_level
            try:
                # The 'remove' function is called when an object dies.  This
                # can happen anywhere when they are reference cycles,
                # especially when we are already computing another __hash__
                # value.  It's not really a recursion in this case, so we
                # reset the counter; otherwise the hash value may be be
                # incorrect and the key won't be deleted.
                TLS.nested_hash_level = 0
                remove_base(*args)
            finally:
                TLS.nested_hash_level = nested_hash_level
        self._remove = remove

class _uninitialized(object):
    def __init__(self, TYPE):
        #self._TYPE = TYPE
        self.TYPE = TYPE
    def __repr__(self):
        return '<Uninitialized %r>'%(self.TYPE,)


def saferecursive(func, defl, TLS=TLS):
    def safe(*args):
        try:
            seeing = TLS.seeing
        except AttributeError:
            seeing = TLS.seeing = {}
        seeingkey = tuple([func] + [id(arg) for arg in args])
        if seeingkey in seeing:
            return defl
        seeing[seeingkey] = True
        try:
            return func(*args)
        finally:
            del seeing[seeingkey]
    return safe

#safe_equal = saferecursive(operator.eq, True)
def safe_equal(x, y, TLS=TLS):
    # a specialized version for performance
    try:
        seeing = TLS.seeing_eq
    except AttributeError:
        seeing = TLS.seeing_eq = {}
    seeingkey = (id(x), id(y))
    if seeingkey in seeing:
        return True
    seeing[seeingkey] = True
    try:
        return x == y
    finally:
        del seeing[seeingkey]


class frozendict(dict):

    def __hash__(self):
        items = self.items()
        items.sort()
        return hash(tuple(items))


class LowLevelType(object):
    # the following line prevents '__cached_hash' to be in the __dict__ of
    # the instance, which is needed for __eq__() and __hash__() to work.
    __slots__ = ['__dict__', '__cached_hash']

    def __eq__(self, other):
        if isinstance(other, Typedef):
            return other.__eq__(self)
        return self.__class__ is other.__class__ and (
            self is other or safe_equal(self.__dict__, other.__dict__))

    def __ne__(self, other):
        return not (self == other)

    _is_compatible = __eq__

    def __setattr__(self, attr, nvalue):
        try:
            LowLevelType.__cached_hash.__get__(self)
        except AttributeError:
            pass
        else:
            try:
                reprself = repr(self)
            except:
                try:
                    reprself = str(self)
                except:
                    reprself = object.__repr__(self)
            raise AssertionError("%s: changing the field %r but we already "
                                 "computed the hash" % (reprself, attr))
        object.__setattr__(self, attr, nvalue)

    def _enforce(self, value):
        if typeOf(value) != self:
            raise TypeError
        return value

    def __hash__(self, TLS=TLS):
        # cannot use saferecursive() -- see test_lltype.test_hash().
        # NB. the __cached_hash should neither be used nor updated
        # if we enter with hash_level > 0, because the computed
        # __hash__ can be different in this situation.
        hash_level = 0
        try:
            hash_level = TLS.nested_hash_level
            if hash_level == 0:
                return self.__cached_hash
        except AttributeError:
            pass
        if hash_level >= 3:
            return 0
        items = self.__dict__.items()
        items.sort()
        TLS.nested_hash_level = hash_level + 1
        try:
            result = hash((self.__class__,) + tuple(items))
        finally:
            TLS.nested_hash_level = hash_level
        if hash_level == 0:
            self.__cached_hash = result
        return result

    # due to this dynamic hash value, we should forbid
    # pickling, until we have an algorithm for that.
    # but we just provide a tag for external help.
    __hash_is_not_constant__ = True

    def __repr__(self):
        return '<%s>' % (self,)

    def __str__(self):
        return self.__class__.__name__

    def _short_name(self):
        return str(self)

    def _defl(self, parent=None, parentindex=None):
        raise NotImplementedError

    def _allocate(self, initialization, parent=None, parentindex=None):
        assert initialization in ('raw', 'malloc', 'example')
        raise NotImplementedError

    def _freeze_(self):
        return True

    def _note_inlined_into(self, parent, first, last):
        """Called when this type is being used inline in a container."""

    def _is_atomic(self):
        return False

    def _is_varsize(self):
        return False

    def _contains_value(self, value):
        if self is Void:
            return True
        return isCompatibleType(typeOf(value), self)

NFOUND = object()

class ContainerType(LowLevelType):
    _adtmeths = {}

    def _note_inlined_into(self, parent, first, last):
        raise TypeError("%r cannot be inlined in %r" % (
            self.__class__.__name__, parent.__class__.__name__))

    def _install_extras(self, adtmeths={}, hints={}):
        self._adtmeths = frozendict(adtmeths)
        self._hints = frozendict(hints)

    def __getattr__(self, name):
        adtmeth = self._adtmeths.get(name, NFOUND)
        if adtmeth is not NFOUND:
            if getattr(adtmeth, '_type_method', False):
                return adtmeth.__get__(self)
            else:
                return adtmeth
        self._nofield(name)

    def _nofield(self, name):
        raise AttributeError("no field %r" % name)

    def _container_example(self):
        raise NotImplementedError


class Typedef(LowLevelType):
    """A typedef is just another name for an existing type"""
    def __init__(self, OF, c_name):
        """
        @param OF: the equivalent rffi type
        @param c_name: the name we want in C code
        """
        assert isinstance(OF, LowLevelType)
        # Look through typedefs, so other places don't have to
        if isinstance(OF, Typedef):
            OF = OF.OF # haha
        self.OF = OF
        self.c_name = c_name

    def __repr__(self):
        return '<Typedef "%s" of %r>' % (self.c_name, self.OF)

    def __eq__(self, other):
        return other == self.OF

    def __getattr__(self, name):
        return self.OF.get(name)

    def _defl(self, parent=None, parentindex=None):
        return self.OF._defl()

    def _allocate(self, initialization, parent=None, parentindex=None):
        return self.OF._allocate(initialization, parent, parentindex)


class Struct(ContainerType):
    _gckind = 'raw'

    def __init__(self, name, *fields, **kwds):
        self._name = self.__name__ = name
        flds = {}
        names = []
        self._arrayfld = None
        for name, typ in fields:
            if name.startswith('_'):
                raise NameError("%s: field name %r should not start with "
                                  "an underscore" % (self._name, name,))
            names.append(name)
            if name in flds:
                raise TypeError("%s: repeated field name" % self._name)
            flds[name] = typ
            if isinstance(typ, ContainerType) and typ._gckind != 'raw':
                if name == fields[0][0] and typ._gckind == self._gckind:
                    pass  # can inline a XxContainer as 1st field of XxStruct
                else:
                    raise TypeError("%s: cannot inline %s container %r" % (
                        self._name, typ._gckind, typ))

        # look if we have an inlined variable-sized array as the last field
        if fields:
            first = True
            for name, typ in fields[:-1]:
                typ._note_inlined_into(self, first=first, last=False)
                first = False
            name, typ = fields[-1]
            typ._note_inlined_into(self, first=first, last=True)
            if typ._is_varsize():
                self._arrayfld = name
        self._flds = frozendict(flds)
        self._names = tuple(names)

        self._install_extras(**kwds)

    def _first_struct(self):
        if self._names:
            first = self._names[0]
            FIRSTTYPE = self._flds[first]
            if (isinstance(FIRSTTYPE, Struct) and
                self._gckind == FIRSTTYPE._gckind):
                return first, FIRSTTYPE
        return None, None

    def _note_inlined_into(self, parent, first, last):
        if self._arrayfld is not None:
            raise TypeError("cannot inline a var-sized struct "
                            "inside another container")
        if self._gckind == 'gc':
            if not first or not isinstance(parent, GcStruct):
                raise TypeError("a GcStruct can only be inlined as the first "
                                "field of another GcStruct")

    def _is_atomic(self):
        for typ in self._flds.values():
            if not typ._is_atomic():
                return False
        return True

    def _is_varsize(self):
        return self._arrayfld is not None

    def __getattr__(self, name):
        try:
            return self._flds[name]
        except KeyError:
            return ContainerType.__getattr__(self, name)

    def _nofield(self, name):
        raise AttributeError('struct %s has no field %r' % (self._name,
                                                             name))

    def _names_without_voids(self):
        return [name for name in self._names if self._flds[name] is not Void]

    def _str_fields_without_voids(self):
        return ', '.join(['%s: %s' % (name, self._flds[name])
                          for name in self._names_without_voids(False)])
    _str_fields_without_voids = saferecursive(_str_fields_without_voids, '...')

    def _str_without_voids(self):
        return "%s %s { %s }" % (self.__class__.__name__,
                                 self._name, self._str_fields_without_voids())

    def _str_fields(self):
        return ', '.join(['%s: %s' % (name, self._flds[name])
                          for name in self._names])
    _str_fields = saferecursive(_str_fields, '...')

    def __str__(self):
        # -- long version --
        #return "%s %s { %s }" % (self.__class__.__name__,
        #                         self._name, self._str_fields())
        # -- short version --
        return "%s %s { %s }" % (self.__class__.__name__, self._name,
                                 ', '.join(self._names))

    def _short_name(self):
        return "%s %s" % (self.__class__.__name__, self._name)

    def _allocate(self, initialization, parent=None, parentindex=None):
        return _struct(self, initialization=initialization,
                       parent=parent, parentindex=parentindex)

    def _container_example(self):
        if self._arrayfld is None:
            n = None
        else:
            n = 1
        return _struct(self, n, initialization='example')

    def _immutable_field(self, field):
        if self._hints.get('immutable'):
            return True
        if 'immutable_fields' in self._hints:
            try:
                return self._hints['immutable_fields'].fields[field]
            except KeyError:
                pass
        return False

class RttiStruct(Struct):
    _runtime_type_info = None

    def _install_extras(self, rtti=False, **kwds):
        if rtti:
            self._runtime_type_info = opaqueptr(RuntimeTypeInfo,
                                                name=self._name,
                                                about=self)._obj
        Struct._install_extras(self, **kwds)

    def _attach_runtime_type_info_funcptr(self, funcptr, destrptr):
        if self._runtime_type_info is None:
            raise TypeError("attachRuntimeTypeInfo: %r must have been built "
                            "with the rtti=True argument" % (self,))
        if funcptr is not None:
            T = typeOf(funcptr)
            if (not isinstance(T, Ptr) or
                not isinstance(T.TO, FuncType) or
                len(T.TO.ARGS) != 1 or
                T.TO.RESULT != Ptr(RuntimeTypeInfo) or
                castable(T.TO.ARGS[0], Ptr(self)) < 0):
                raise TypeError("expected a runtime type info function "
                                "implementation, got: %s" % funcptr)
            self._runtime_type_info.query_funcptr = funcptr
        if destrptr is not None:
            T = typeOf(destrptr)
            if (not isinstance(T, Ptr) or
                not isinstance(T.TO, FuncType) or
                len(T.TO.ARGS) != 1 or
                T.TO.RESULT != Void or
                castable(T.TO.ARGS[0], Ptr(self)) < 0):
                raise TypeError("expected a destructor function "
                                "implementation, got: %s" % destrptr)
            self._runtime_type_info.destructor_funcptr = destrptr

class GcStruct(RttiStruct):
    _gckind = 'gc'

STRUCT_BY_FLAVOR = {'raw': Struct,
                    'gc':  GcStruct}

class Array(ContainerType):
    _gckind = 'raw'
    __name__ = 'array'
    _anonym_struct = False

    def __init__(self, *fields, **kwds):
        if len(fields) == 1 and isinstance(fields[0], LowLevelType):
            self.OF = fields[0]
        else:
            self.OF = Struct("<arrayitem>", *fields)
            self._anonym_struct = True
        if isinstance(self.OF, ContainerType) and self.OF._gckind != 'raw':
            raise TypeError("cannot have a %s container as array item type"
                            % (self.OF._gckind,))
        self.OF._note_inlined_into(self, first=False, last=False)

        self._install_extras(**kwds)

    def _note_inlined_into(self, parent, first, last):
        if not last or not isinstance(parent, Struct):
            raise TypeError("cannot inline an array in another container"
                            " unless as the last field of a structure")
        if self._gckind == 'gc':
            raise TypeError("cannot inline a GC array inside a structure")
        if parent._gckind == 'gc' and self._hints.get('nolength', False):
            raise TypeError("cannot inline a no-length array inside a GcStruct")

    def _is_atomic(self):
        return self.OF._is_atomic()

    def _is_varsize(self):
        return True

    def _str_fields(self):
        if isinstance(self.OF, Struct):
            of = self.OF
            if self._anonym_struct:
                return "{ %s }" % of._str_fields()
            else:
                return "%s { %s }" % (of._name, of._str_fields())
        elif self._hints.get('render_as_void'):
            return 'void'
        else:
            return str(self.OF)
    _str_fields = saferecursive(_str_fields, '...')

    def __str__(self):
        hints = (' ' + str(self._hints)) if self._hints else ''
        return "%s of %s%s " % (self.__class__.__name__,
                                self._str_fields(),
                                hints)

    def _short_name(self):
        hints = (' ' + str(self._hints)) if self._hints else ''
        return "%s %s%s" % (self.__class__.__name__,
                            self.OF._short_name(),
                            hints)
    _short_name = saferecursive(_short_name, '...')

    def _container_example(self):
        return _array(self, 1, initialization='example')

    def _immutable_field(self, index=None):
        return self._hints.get('immutable', False)

class GcArray(Array):
    _gckind = 'gc'

class FixedSizeArray(Struct):
    # behaves more or less like a Struct with fields item0, item1, ...
    # but also supports __getitem__(), __setitem__(), __len__().

    _cache = WeakValueDictionary() # cache the length-1 FixedSizeArrays
    def __new__(cls, OF, length, **kwds):
        if length == 1 and not kwds:
            try:
                obj = FixedSizeArray._cache[OF]
            except KeyError:
                obj = FixedSizeArray._cache[OF] = Struct.__new__(cls)
            except TypeError:
                obj = Struct.__new__(cls)
        else:
            obj = Struct.__new__(cls)
        return obj

    def __init__(self, OF, length, **kwds):
        if '_name' in self.__dict__:
            assert self.OF == OF
            assert self.length == length
            return
        fields = [('item%d' % i, OF) for i in range(length)]
        super(FixedSizeArray, self).__init__('array%d' % length, *fields,
                                             **kwds)
        self.OF = OF
        self.length = length
        if isinstance(self.OF, ContainerType) and self.OF._gckind != 'raw':
            raise TypeError("cannot have a %s container as array item type"
                            % (self.OF._gckind,))
        self.OF._note_inlined_into(self, first=False, last=False)

    def _str_fields(self):
        return str(self.OF)
    _str_fields = saferecursive(_str_fields, '...')

    def __str__(self):
        return "%s of %d %s " % (self.__class__.__name__,
                                 self.length,
                                 self._str_fields(),)

    def _short_name(self):
        return "%s %d %s" % (self.__class__.__name__,
                             self.length,
                             self.OF._short_name(),)
    _short_name = saferecursive(_short_name, '...')

    def _first_struct(self):
        # don't consider item0 as an inlined first substructure
        return None, None


class FuncType(ContainerType):
    _gckind = 'raw'
    __name__ = 'func'
    def __init__(self, args, result, abi='FFI_DEFAULT_ABI'):
        for arg in args:
            assert isinstance(arg, LowLevelType)
            # There are external C functions eating raw structures, not
            # pointers, don't check args not being container types
        self.ARGS = tuple(args)
        assert isinstance(result, LowLevelType)
        if isinstance(result, ContainerType):
            raise TypeError("function result can only be primitive or pointer")
        self.RESULT = result
        self.ABI = abi

    def __str__(self):
        args = ', '.join(map(str, self.ARGS))
        return "Func ( %s ) -> %s" % (args, self.RESULT)
    __str__ = saferecursive(__str__, '...')

    def _short_name(self):
        args = ', '.join([ARG._short_name() for ARG in self.ARGS])
        return "Func(%s)->%s" % (args, self.RESULT._short_name())
    _short_name = saferecursive(_short_name, '...')

    def _container_example(self):
        def ex(*args):
            return self.RESULT._defl()
        return _func(self, _callable=ex)

    def _trueargs(self):
        return [arg for arg in self.ARGS if arg is not Void]


class OpaqueType(ContainerType):
    _gckind = 'raw'

    def __init__(self, tag, hints={}):
        """If hints['render_structure'] is set, the type is internal and
        not considered to come from somewhere else (it should be
        rendered as a structure)
        """
        self.tag = tag
        self.__name__ = tag
        self._hints = frozendict(hints)

    def __str__(self):
        return "%s (opaque)" % self.tag

    def _note_inlined_into(self, parent, first, last):
        # OpaqueType can be inlined, but not GcOpaqueType
        if self._gckind == 'gc':
            raise TypeError("%r cannot be inlined in %r" % (
                self.__class__.__name__, parent.__class__.__name__))

    def _container_example(self):
        return _opaque(self)

    def _defl(self, parent=None, parentindex=None):
        return _opaque(self, parent=parent, parentindex=parentindex)

    def _allocate(self, initialization, parent=None, parentindex=None):
        return self._defl(parent=parent, parentindex=parentindex)

RuntimeTypeInfo = OpaqueType("RuntimeTypeInfo")

class GcOpaqueType(OpaqueType):
    _gckind = 'gc'

    def __str__(self):
        return "%s (gcopaque)" % self.tag

class ForwardReference(ContainerType):
    _gckind = 'raw'
    def become(self, realcontainertype):
        if not isinstance(realcontainertype, ContainerType):
            raise TypeError("ForwardReference can only be to a container, "
                            "not %r" % (realcontainertype,))
        if realcontainertype._gckind != self._gckind:
            raise TypeError("become() gives conflicting gckind, use the "
                            "correct XxForwardReference")
        self.__class__ = realcontainertype.__class__
        self.__dict__ = realcontainertype.__dict__

    def __hash__(self):
        raise TypeError("%r object is not hashable" % self.__class__.__name__)

class GcForwardReference(ForwardReference):
    _gckind = 'gc'


class FuncForwardReference(ForwardReference):
    _gckind = 'prebuilt'

FORWARDREF_BY_FLAVOR = {'raw': ForwardReference,
                        'gc':  GcForwardReference,
                        'prebuilt': FuncForwardReference}


class Primitive(LowLevelType):
    def __init__(self, name, default):
        self._name = self.__name__ = name
        self._default = default

    def __str__(self):
        return self._name

    def _defl(self, parent=None, parentindex=None):
        return self._default

    def _allocate(self, initialization, parent=None, parentindex=None):
        if self is not Void and initialization != 'example':
            return _uninitialized(self)
        else:
            return self._default

    def _is_atomic(self):
        return True

    def _example(self, parent=None, parentindex=None):
        return self._default

class Number(Primitive):

    def __init__(self, name, type, cast=None):
        Primitive.__init__(self, name, type())
        self._type = type
        if cast is None:
            self._cast = type
        else:
            self._cast = cast

    def normalized(self):
        return build_number(None, normalizedinttype(self._type))


_numbertypes = {int: Number("Signed", int, intmask)}
_numbertypes[r_int] = _numbertypes[int]
_numbertypes[r_longlonglong] = Number("SignedLongLongLong", r_longlonglong,
                                      longlonglongmask)

if r_longlong is not r_int:
    _numbertypes[r_longlong] = Number("SignedLongLong", r_longlong,
                                      longlongmask)

def build_number(name, type):
    try:
        return _numbertypes[type]
    except KeyError:
        pass
    if name is None:
        raise ValueError('No matching lowlevel type for %r'%type)
    number = _numbertypes[type] = Number(name, type)
    return number

if is_emulated_long:
    SignedFmt = 'q'
else:
    SignedFmt = 'l'

Signed   = build_number("Signed", int)
Unsigned = build_number("Unsigned", r_uint)
SignedLongLong = build_number("SignedLongLong", r_longlong)
SignedLongLongLong = build_number("SignedLongLongLong", r_longlonglong)
UnsignedLongLong = build_number("UnsignedLongLong", r_ulonglong)
UnsignedLongLongLong = build_number("UnsignedLongLongLong", r_ulonglonglong)

Float       = Primitive("Float",       0.0)                  # C type 'double'
SingleFloat = Primitive("SingleFloat", r_singlefloat(0.0))   # 'float'
LongFloat   = Primitive("LongFloat",   r_longfloat(0.0))     # 'long double'
r_singlefloat._TYPE = SingleFloat

Char     = Primitive("Char", '\x00')
Bool     = Primitive("Bool", False)
Void     = Primitive("Void", None)
UniChar  = Primitive("UniChar", u'\x00')


class Ptr(LowLevelType):
    __name__ = property(lambda self: '%sPtr' % self.TO.__name__)

    _cache = WeakValueDictionary()  # cache the Ptrs
    def __new__(cls, TO, use_cache=True):
        if not isinstance(TO, ContainerType):
            raise TypeError("can only point to a Container type, "
                              "not to %s" % (TO,))
        if not use_cache:
            obj = LowLevelType.__new__(cls)
        else:
            try:
                return Ptr._cache[TO]
            except KeyError:
                obj = Ptr._cache[TO] = LowLevelType.__new__(cls)
            except TypeError:
                obj = LowLevelType.__new__(cls)
        obj.TO = TO
        return obj

    def _needsgc(self):
        # XXX deprecated interface
        return self.TO._gckind not in ('raw', 'prebuilt')

    def __str__(self):
        return '* %s' % (self.TO, )

    def _short_name(self):
        return 'Ptr %s' % (self.TO._short_name(), )

    def _is_atomic(self):
        return self.TO._gckind == 'raw'

    def _defl(self, parent=None, parentindex=None):
        return _ptr(self, None)

    def _allocate(self, initialization, parent=None, parentindex=None):
        if initialization == 'example':
            return _ptr(self, None)
        elif initialization == 'malloc' and self._needsgc():
            return _ptr(self, None)
        else:
            return _uninitialized(self)

    def _example(self):
        o = self.TO._container_example()
        return _ptr(self, o, solid=True)

    def _interior_ptr_type_with_index(self, TO):
        assert self.TO._gckind == 'gc'
        if isinstance(TO, Struct):
            R = GcStruct("Interior", ('ptr', self), ('index', Signed),
                         hints={'interior_ptr_type':True},
                         adtmeths=TO._adtmeths)
        else:
            R = GcStruct("Interior", ('ptr', self), ('index', Signed),
                         hints={'interior_ptr_type':True})
        return R

@analyzer_for(Ptr)
def constPtr(T):
    assert T.is_constant()
    return immutablevalue(Ptr(T.const))


class InteriorPtr(LowLevelType):
    def __init__(self, PARENTTYPE, TO, offsets):
        self.PARENTTYPE = PARENTTYPE
        self.TO = TO
        self.offsets = tuple(offsets)
    def __str__(self):
        return '%s (%s).%s'%(self.__class__.__name__,
                             self.PARENTTYPE._short_name(),
                             '.'.join(map(str, self.offsets)))
    def _example(self):
        ob = Ptr(self.PARENTTYPE)._example()
        for o in self.offsets:
            if isinstance(o, str):
                ob = getattr(ob, o)
            else:
                ob = ob[0]
        return ob

# ____________________________________________________________


def typeOf(val):
    try:
        return val._TYPE
    except AttributeError:
        tp = type(val)
        if tp is _uninitialized:
            raise UninitializedMemoryAccess("typeOf uninitialized value")
        if tp is NoneType:
            return Void   # maybe
        if tp is int:
            return Signed
        if tp is long:
            if -maxint-1 <= val <= maxint:
                return Signed
            elif longlongmask(val) == val:
                raise OverflowError("integer %r is out of bounds for Signed "
                                    "(it would fit SignedLongLong, but we "
                                    "won't implicitly return SignedLongLong "
                                    "for typeOf(%r) where type(%r) is long)"
                                    % (val, val, val))
            else:
                raise OverflowError("integer %r is out of bounds" % (val,))
        if tp is bool:
            return Bool
        if issubclass(tp, base_int):
            return build_number(None, tp)
        if tp is float:
            return Float
        if tp is r_longfloat:
            return LongFloat
        if tp is str:
            assert len(val) == 1
            return Char
        if tp is unicode:
            assert len(val) == 1
            return UniChar
        if issubclass(tp, Symbolic):
            return val.lltype()
        # if you get a TypeError: typeOf('_interior_ptr' object)
        # here, it is very likely that you are accessing an interior pointer
        # in an illegal way!
        raise TypeError("typeOf(%r object)" % (tp.__name__,))

@analyzer_for(typeOf)
def ann_typeOf(s_val):
    from rpython.rtyper.llannotation import annotation_to_lltype
    lltype = annotation_to_lltype(s_val, info="in typeOf(): ")
    return immutablevalue(lltype)


_to_primitive = {
    Char: chr,
    UniChar: unichr,
    Float: float,
    Bool: bool,
}

def cast_primitive(TGT, value):
    ORIG = typeOf(value)
    if not isinstance(TGT, Primitive) or not isinstance(ORIG, Primitive):
        raise TypeError("can only primitive to primitive")
    if ORIG == TGT:
        return value
    if ORIG == Char or ORIG == UniChar:
        value = ord(value)
    elif ORIG == Float:
        if TGT == SingleFloat:
            return r_singlefloat(value)
        elif TGT == LongFloat:
            return r_longfloat(value)
        value = long(value)
    cast = _to_primitive.get(TGT)
    if cast is not None:
        return cast(value)
    if isinstance(TGT, Number):
        return TGT._cast(value)
    if ORIG == SingleFloat and TGT == Float:
        return float(value)
    if ORIG == LongFloat and TGT == Float:
        return float(value)
    raise TypeError("unsupported cast")

@analyzer_for(cast_primitive)
def ann_cast_primitive(T, s_v):
    from rpython.rtyper.llannotation import (
        annotation_to_lltype, ll_to_annotation)
    assert T.is_constant()
    return ll_to_annotation(cast_primitive(T.const,
                                           annotation_to_lltype(s_v)._defl()))


def _cast_whatever(TGT, value):
    from rpython.rtyper.lltypesystem import llmemory, rffi
    ORIG = typeOf(value)
    if ORIG == TGT:
        return value
    if (isinstance(TGT, Primitive) and
        isinstance(ORIG, Primitive)):
        return cast_primitive(TGT, value)
    elif isinstance(TGT, Ptr):
        if isinstance(ORIG, Ptr):
            if (isinstance(TGT.TO, OpaqueType) or
                isinstance(ORIG.TO, OpaqueType)):
                return cast_opaque_ptr(TGT, value)
            else:
                return cast_pointer(TGT, value)
        elif ORIG == llmemory.Address:
            return llmemory.cast_adr_to_ptr(value, TGT)
        elif TGT == rffi.VOIDP and ORIG == Unsigned:
            return rffi.cast(TGT, value)
        elif ORIG == Signed:
            return cast_int_to_ptr(TGT, value)
    elif TGT == llmemory.Address and isinstance(ORIG, Ptr):
        return llmemory.cast_ptr_to_adr(value)
    elif TGT == Signed and isinstance(ORIG, Ptr) and ORIG.TO._gckind == 'raw':
        return llmemory.cast_adr_to_int(llmemory.cast_ptr_to_adr(value),
                                        'symbolic')
    raise TypeError("don't know how to cast from %r to %r" % (ORIG, TGT))


def erasedType(T):
    while isinstance(T, Ptr) and isinstance(T.TO, Struct):
        first, FIRSTTYPE = T.TO._first_struct()
        if first is None:
            break
        T = Ptr(FIRSTTYPE)
    return T

class InvalidCast(TypeError):
    pass

def _castdepth(OUTSIDE, INSIDE):
    if OUTSIDE == INSIDE:
        return 0
    dwn = 0
    while isinstance(OUTSIDE, Struct):
        first, FIRSTTYPE = OUTSIDE._first_struct()
        if first is None:
            break
        dwn += 1
        if FIRSTTYPE == INSIDE:
            return dwn
        OUTSIDE = getattr(OUTSIDE, first)
    return -1

def castable(PTRTYPE, CURTYPE):
    if CURTYPE.TO._gckind != PTRTYPE.TO._gckind:
        raise TypeError("cast_pointer() cannot change the gc status: %s to %s"
                        % (CURTYPE, PTRTYPE))
    if CURTYPE == PTRTYPE:
        return 0
    if (not isinstance(CURTYPE.TO, Struct) or
        not isinstance(PTRTYPE.TO, Struct)):
        raise InvalidCast(CURTYPE, PTRTYPE)
    CURSTRUC = CURTYPE.TO
    PTRSTRUC = PTRTYPE.TO
    d = _castdepth(CURSTRUC, PTRSTRUC)
    if d >= 0:
        return d
    u = _castdepth(PTRSTRUC, CURSTRUC)
    if u == -1:
        raise InvalidCast(CURTYPE, PTRTYPE)
    return -u


def cast_pointer(PTRTYPE, ptr):
    CURTYPE = typeOf(ptr)
    if not isinstance(CURTYPE, Ptr) or not isinstance(PTRTYPE, Ptr):
        raise TypeError("can only cast pointers to other pointers")
    return ptr._cast_to(PTRTYPE)

@analyzer_for(cast_pointer)
def ann_cast_pointer(PtrT, s_p):
    assert isinstance(s_p, SomePtr), "casting of non-pointer: %r" % s_p
    assert PtrT.is_constant()
    cast_p = cast_pointer(PtrT.const, s_p.ll_ptrtype._defl())
    return SomePtr(ll_ptrtype=typeOf(cast_p))


def cast_opaque_ptr(PTRTYPE, ptr):
    CURTYPE = typeOf(ptr)
    if not isinstance(CURTYPE, Ptr) or not isinstance(PTRTYPE, Ptr):
        raise TypeError("can only cast pointers to other pointers")
    if CURTYPE == PTRTYPE:
        return ptr
    if CURTYPE.TO._gckind != PTRTYPE.TO._gckind:
        raise TypeError("cast_opaque_ptr() cannot change the gc status: "
                        "%s to %s" % (CURTYPE, PTRTYPE))
    if (isinstance(CURTYPE.TO, OpaqueType)
        and not isinstance(PTRTYPE.TO, OpaqueType)):
        if hasattr(ptr._obj, '_cast_to_ptr'):
            return ptr._obj._cast_to_ptr(PTRTYPE)
        if not ptr:
            return nullptr(PTRTYPE.TO)
        try:
            container = ptr._obj.container
        except AttributeError:
            raise InvalidCast("%r does not come from a container" % (ptr,))
        solid = getattr(ptr._obj, 'solid', False)
        p = _ptr(Ptr(typeOf(container)), container, solid)
        return cast_pointer(PTRTYPE, p)
    elif (not isinstance(CURTYPE.TO, OpaqueType)
          and isinstance(PTRTYPE.TO, OpaqueType)):
        if hasattr(ptr, '_cast_to_opaque'):
            return ptr._cast_to_opaque(PTRTYPE)
        if not ptr:
            return nullptr(PTRTYPE.TO)
        return opaqueptr(PTRTYPE.TO, 'hidden', container = ptr._obj,
                                               ORIGTYPE = CURTYPE,
                                               solid     = ptr._solid)
    elif (isinstance(CURTYPE.TO, OpaqueType)
          and isinstance(PTRTYPE.TO, OpaqueType)):
        if not ptr:
            return nullptr(PTRTYPE.TO)
        try:
            container = ptr._obj.container
        except AttributeError:
            raise InvalidCast("%r does not come from a container" % (ptr,))
        return opaqueptr(PTRTYPE.TO, 'hidden',
                         container = container,
                         solid     = ptr._obj.solid)
    else:
        raise TypeError("invalid cast_opaque_ptr(): %r -> %r" %
                        (CURTYPE, PTRTYPE))

@analyzer_for(cast_opaque_ptr)
def ann_cast_opaque_ptr(PtrT, s_p):
    assert isinstance(s_p, SomePtr), "casting of non-pointer: %r" % s_p
    assert PtrT.is_constant()
    cast_p = cast_opaque_ptr(PtrT.const, s_p.ll_ptrtype._defl())
    return SomePtr(ll_ptrtype=typeOf(cast_p))


def length_of_simple_gcarray_from_opaque(opaque_ptr):
    CURTYPE = typeOf(opaque_ptr)
    if not isinstance(CURTYPE, Ptr):
        raise TypeError("can only cast pointers to other pointers")
    if not isinstance(CURTYPE.TO, GcOpaqueType):
        raise TypeError("expected a GcOpaqueType")
    try:
        c = opaque_ptr._obj.container
    except AttributeError:
        # if 'opaque_ptr' is already some _llgcopaque, hack its length
        # by casting it to a random GcArray type and hoping
        from rpython.rtyper.lltypesystem import rffi
        p = rffi.cast(Ptr(GcArray(Signed)), opaque_ptr)
        return len(p)
    else:
        return c.getlength()

@analyzer_for(length_of_simple_gcarray_from_opaque)
def ann_length_of_simple_gcarray_from_opaque(s_p):
    assert isinstance(s_p, SomePtr), "casting of non-pointer: %r" % s_p
    assert isinstance(s_p.ll_ptrtype.TO, GcOpaqueType)
    return SomeInteger(nonneg=True)


def direct_fieldptr(structptr, fieldname):
    """Get a pointer to a field in the struct.  The resulting
    pointer is actually of type Ptr(FixedSizeArray(FIELD, 1)).
    It can be used in a regular getarrayitem(0) or setarrayitem(0)
    to read or write to the field.
    """
    CURTYPE = typeOf(structptr).TO
    if not isinstance(CURTYPE, Struct):
        raise TypeError("direct_fieldptr: not a struct")
    if fieldname not in CURTYPE._flds:
        raise TypeError("%s has no field %r" % (CURTYPE, fieldname))
    if not structptr:
        raise RuntimeError("direct_fieldptr: NULL argument")
    return _subarray._makeptr(structptr._obj, fieldname, structptr._solid)

@analyzer_for(direct_fieldptr)
def ann_direct_fieldptr(s_p, s_fieldname):
    assert isinstance(s_p, SomePtr), "direct_* of non-pointer: %r" % s_p
    assert s_fieldname.is_constant()
    cast_p = direct_fieldptr(s_p.ll_ptrtype._example(),
                                    s_fieldname.const)
    return SomePtr(ll_ptrtype=typeOf(cast_p))


def direct_arrayitems(arrayptr):
    """Get a pointer to the first item of the array.  The resulting
    pointer is actually of type Ptr(FixedSizeArray(ITEM, 1)) but can
    be used in a regular getarrayitem(n) or direct_ptradd(n) to access
    further elements.
    """
    CURTYPE = typeOf(arrayptr).TO
    if not isinstance(CURTYPE, (Array, FixedSizeArray)):
        raise TypeError("direct_arrayitems: not an array")
    if not arrayptr:
        raise RuntimeError("direct_arrayitems: NULL argument")
    return _subarray._makeptr(arrayptr._obj, 0, arrayptr._solid)

@analyzer_for(direct_arrayitems)
def ann_direct_arrayitems(s_p):
    assert isinstance(s_p, SomePtr), "direct_* of non-pointer: %r" % s_p
    cast_p = direct_arrayitems(s_p.ll_ptrtype._example())
    return SomePtr(ll_ptrtype=typeOf(cast_p))


def direct_ptradd(ptr, n):
    """Shift a pointer forward or backward by n items.  The pointer must
    have been built by direct_arrayitems(), or it must be directly a
    pointer to a raw array with no length (handled by emulation with ctypes).
    """
    if not ptr:
        raise RuntimeError("direct_ptradd: NULL argument")
    if not isinstance(ptr._obj, _subarray):
        # special case: delegate barebone C-like array cases to rffi.ptradd()
        from rpython.rtyper.lltypesystem import rffi
        return rffi.ptradd(ptr, n)
    parent, base = parentlink(ptr._obj)
    return _subarray._makeptr(parent, base + n, ptr._solid)

@analyzer_for(direct_ptradd)
def ann_direct_ptradd(s_p, s_n):
    assert isinstance(s_p, SomePtr), "direct_* of non-pointer: %r" % s_p
    # don't bother with an example here: the resulting pointer is the same
    return s_p


def parentlink(container):
    parent = container._parentstructure()
    if parent is not None:
        return parent, container._parent_index
    else:
        return None, None

def top_container(container):
    top_parent = container
    while True:
        parent = top_parent._parentstructure()
        if parent is None:
            break
        top_parent = parent
    return top_parent

def normalizeptr(p, check=True):
    # If p is a pointer, returns the same pointer casted to the largest
    # containing structure (for the cast where p points to the header part).
    # Also un-hides pointers to opaque.  Null pointers become None.
    assert not isinstance(p, _container)  # pointer or primitive
    T = typeOf(p)
    if not isinstance(T, Ptr):
        return p      # primitive
    obj = p._getobj(check)
    if not obj:
        return None   # null pointer
    if type(p._obj0) is int:
        return p      # a pointer obtained by cast_int_to_ptr
    if getattr(p._obj0, '_carry_around_for_tests', False):
        return p      # a pointer obtained by cast_instance_to_base_ptr
    container = obj._normalizedcontainer()
    if type(container) is int:
        # this must be an opaque ptr originating from an integer
        assert isinstance(obj, _opaque)
        return cast_int_to_ptr(obj.ORIGTYPE, container)
    if container is not obj:
        p = _ptr(Ptr(typeOf(container)), container, p._solid)
    return p

class DelayedPointer(Exception):
    pass

class UninitializedMemoryAccess(Exception):
    pass

class _abstract_ptr(object):
    __slots__ = ('_T',)

    # assumes one can access _TYPE, _expose and _obj

    def _set_T(self, T):
        _ptr._T.__set__(self, T)

    def _togckind(self):
        return self._T._gckind

    def _needsgc(self):
        # XXX deprecated interface
        return self._TYPE._needsgc() # xxx other rules?

    def __eq__(self, other):
        if type(self) is not type(other):
            raise TypeError("comparing pointer with %r object" % (
                type(other).__name__,))
        if self._TYPE != other._TYPE:
            raise TypeError("comparing %r and %r" % (self._TYPE, other._TYPE))
        try:
            return self._obj == other._obj
        except DelayedPointer:
            # if one of the two pointers is delayed, they cannot
            # possibly be equal unless they are the same _ptr instance
            return self is other

    def __ne__(self, other):
        return not (self == other)

    def _same_obj(self, other):
        return self._obj == other._obj

    def __hash__(self):
        raise TypeError("pointer objects are not hashable")

    def __nonzero__(self):
        try:
            return self._obj is not None
        except DelayedPointer:
            return True    # assume it's not a delayed null

    # _setobj, _getobj and _obj0 are really _internal_ implementations
    # details of _ptr, use _obj if necessary instead !
    def _setobj(self, pointing_to, solid=False):
        if pointing_to is None:
            obj0 = None
        elif (solid or self._T._gckind != 'raw' or
              isinstance(self._T, FuncType)):
            obj0 = pointing_to
        else:
            self._set_weak(True)
            obj0 = weakref.ref(pointing_to)
        self._set_solid(solid)
        self._set_obj0(obj0)

    def _getobj(self, check=True):
        obj = self._obj0
        if obj is not None:
            if self._weak:
                obj = obj()
                if obj is None:
                    raise RuntimeError("accessing already garbage collected %r"
                                   % (self._T,))
            if isinstance(obj, _container):
                if check:
                    obj._check()
            elif isinstance(obj, str) and obj.startswith("delayed!"):
                raise DelayedPointer
        return obj
    _obj = property(_getobj)

    def _was_freed(self):
        return (type(self._obj0) not in (type(None), int) and
                self._getobj(check=False)._was_freed())

    def _lookup_adtmeth(self, member_name):
        if isinstance(self._T, ContainerType):
            try:
                adtmember = self._T._adtmeths[member_name]
            except KeyError:
                pass
            else:
                try:
                    getter = adtmember.__get__
                except AttributeError:
                    return adtmember
                else:
                    return getter(self)
        raise AttributeError

    def __getattr__(self, field_name): # ! can only return basic or ptr !
        if isinstance(self._T, Struct):
            if field_name in self._T._flds:
                o = self._obj._getattr(field_name)
                return self._expose(field_name, o)
        try:
            return self._lookup_adtmeth(field_name)
        except AttributeError:
            raise AttributeError("%r instance has no field %r" % (self._T,
                                                                  field_name))

    def __setattr__(self, field_name, val):
        if isinstance(self._T, Struct):
            if field_name in self._T._flds:
                T1 = self._T._flds[field_name]
                T2 = typeOf(val)
                if T1 == T2:
                    setattr(self._obj, field_name, val)
                else:
                    raise TypeError(
                        "%r instance field %r:\nexpects %r\n    got %r" %
                        (self._T, field_name, T1, T2))
                return
        raise AttributeError("%r instance has no field %r" %
                             (self._T, field_name))

    def __getitem__(self, i): # ! can only return basic or ptr !
        if isinstance(self._T, (Array, FixedSizeArray)):
            start, stop = self._obj.getbounds()
            if not (start <= i < stop):
                if isinstance(i, slice):
                    raise TypeError("array slicing not supported")
                raise IndexError("array index out of bounds")
            o = self._obj.getitem(i)
            return self._expose(i, o)
        raise TypeError("%r instance is not an array" % (self._T,))

    def __setitem__(self, i, val):
        if isinstance(self._T, (Array, FixedSizeArray)):
            T1 = self._T.OF
            if isinstance(T1, ContainerType):
                raise TypeError("cannot directly assign to container array "
                                "items")
            T2 = typeOf(val)
            if T2 != T1:
                from rpython.rtyper.lltypesystem import rffi
                if T1 is rffi.VOIDP and isinstance(T2, Ptr):
                    # Any pointer is convertible to void*
                    val = rffi.cast(rffi.VOIDP, val)
                else:
                    raise TypeError("%r items:\n"
                                    "expect %r\n"
                                    "   got %r" % (self._T, T1, T2))
            start, stop = self._obj.getbounds()
            if not (start <= i < stop):
                if isinstance(i, slice):
                    raise TypeError("array slicing not supported")
                raise IndexError("array index out of bounds")
            self._obj.setitem(i, val)
            return
        raise TypeError("%r instance is not an array" % (self._T,))

    def __len__(self):
        if isinstance(self._T, (Array, FixedSizeArray)):
            if self._T._hints.get('nolength', False):
                raise TypeError("%r instance has no length attribute" %
                                    (self._T,))
            return self._obj.getlength()
        raise TypeError("%r instance is not an array" % (self._T,))

    def _fixedlength(self):
        length = len(self)      # always do this, for the checking
        if isinstance(self._T, FixedSizeArray):
            return length
        else:
            return None

    def __repr__(self):
        return '<%s>' % (self,)

    def __str__(self):
        try:
            return '* %s' % (self._obj, )
        except RuntimeError:
            return '* DEAD %s' % self._T
        except DelayedPointer:
            return '* %s' % (self._obj0,)

    def __call__(self, *args):
        from rpython.rtyper.lltypesystem import rffi
        if isinstance(self._T, FuncType):
            if len(args) != len(self._T.ARGS):
                raise TypeError("calling %r with wrong argument number: %r" %
                                (self._T, args))
            for i, a, ARG in zip(range(len(self._T.ARGS)), args, self._T.ARGS):
                if typeOf(a) != ARG:
                    # ARG could be Void
                    if ARG == Void:
                        try:
                            value = getattr(self._obj, '_void' + str(i))
                        except AttributeError:
                            pass
                        else:
                            assert a == value
                    # None is acceptable for any pointer
                    elif isinstance(ARG, Ptr) and a is None:
                        pass
                    # Any pointer is convertible to void*
                    elif ARG is rffi.VOIDP and isinstance(typeOf(a), Ptr):
                        pass
                    # special case: ARG can be a container type, in which
                    # case a should be a pointer to it.  This must also be
                    # special-cased in the backends.
                    elif (isinstance(ARG, ContainerType) and
                          typeOf(a) == Ptr(ARG)):
                        pass
                    else:
                        args_repr = [typeOf(arg) for arg in args]
                        raise TypeError("calling %r with wrong argument "
                                          "types: %r" % (self._T, args_repr))
            callb = self._obj._callable
            if callb is None:
                raise RuntimeError("calling undefined function")
            return callb(*args)
        raise TypeError("%r instance is not a function" % (self._T,))

    def _identityhash(self):
        p = normalizeptr(self)
        assert self._T._gckind == 'gc'
        assert self      # not for NULL
        return hash(p._obj)

class _ptr(_abstract_ptr):
    __slots__ = ('_TYPE',
                 '_weak', '_solid',
                 '_obj0', '__weakref__')

    def _set_TYPE(self, TYPE):
        _ptr._TYPE.__set__(self, TYPE)

    def _set_weak(self, weak):
        _ptr._weak.__set__(self, weak)

    def _set_solid(self, solid):
        _ptr._solid.__set__(self, solid)

    def _set_obj0(self, obj):
        _ptr._obj0.__set__(self, obj)

    def __init__(self, TYPE, pointing_to, solid=False):
        self._set_TYPE(TYPE)
        self._set_T(TYPE.TO)
        self._set_weak(False)
        self._setobj(pointing_to, solid)

    def _become(self, other):
        assert self._TYPE == other._TYPE
        assert not self._weak
        self._setobj(other._obj, other._solid)

    def _cast_to(self, PTRTYPE):
        CURTYPE = self._TYPE
        down_or_up = castable(PTRTYPE, CURTYPE)
        if down_or_up == 0:
            return self
        if not self: # null pointer cast
            return PTRTYPE._defl()
        if isinstance(self._obj, int):
            return _ptr(PTRTYPE, self._obj, solid=True)
        if down_or_up > 0:
            p = self
            while down_or_up:
                p = getattr(p, typeOf(p).TO._names[0])
                down_or_up -= 1
            return _ptr(PTRTYPE, p._obj, solid=self._solid)
        u = -down_or_up
        struc = self._obj
        while u:
            parent = struc._parentstructure()
            if parent is None:
                raise RuntimeError("widening to trash: %r" % self)
            PARENTTYPE = struc._parent_type
            if getattr(parent, PARENTTYPE._names[0]) != struc:
                 # xxx different exception perhaps?
                raise InvalidCast(CURTYPE, PTRTYPE)
            struc = parent
            u -= 1
        if PARENTTYPE != PTRTYPE.TO:
            raise RuntimeError("widening %r inside %r instead of %r" %
                               (CURTYPE, PARENTTYPE, PTRTYPE.TO))
        return _ptr(PTRTYPE, struc, solid=self._solid)

    def _cast_to_int(self, check=True):
        obj = self._getobj(check)
        if not obj:
            return 0       # NULL pointer
        if isinstance(obj, int):
            return obj     # special case for cast_int_to_ptr() results
        obj = normalizeptr(self, check)._getobj(check)
        if isinstance(obj, int):
            # special case for cast_int_to_ptr() results put into
            # opaques
            return obj
        if getattr(obj, '_read_directly_intval', False):
            return obj.intval   # special case for _llgcopaque
        result = intmask(obj._getid())
        # assume that id() returns an addressish value which is
        # not zero and aligned to at least a multiple of 4
        # (at least for GC pointers; we can't really assume anything
        # for raw addresses)
        if self._T._gckind == 'gc':
            assert result != 0 and (result & 3) == 0
        return result

    def _cast_to_adr(self):
        from rpython.rtyper.lltypesystem import llmemory
        if isinstance(self._T, FuncType):
            return llmemory.fakeaddress(self)
        elif self._was_freed():
            # hack to support llarena.test_replace_object_with_stub()
            from rpython.rtyper.lltypesystem import llarena
            return llarena._oldobj_to_address(self._getobj(check=False))
        elif isinstance(self._obj, _subarray):
            return llmemory.fakeaddress(self)
##            # return an address built as an offset in the whole array
##            parent, parentindex = parentlink(self._obj)
##            T = typeOf(parent)
##            addr = llmemory.fakeaddress(normalizeptr(_ptr(Ptr(T), parent)))
##            addr += llmemory.itemoffsetof(T, parentindex)
##            return addr
        else:
            # normal case
            return llmemory.fakeaddress(normalizeptr(self))

    def _as_ptr(self):
        return self
    def _as_obj(self, check=True):
        return self._getobj(check=check)

    def _expose(self, offset, val):
        """XXX A nice docstring here"""
        T = typeOf(val)
        if isinstance(T, ContainerType):
            if (self._T._gckind == 'gc' and T._gckind == 'raw' and
                not isinstance(T, OpaqueType)):
                val = _interior_ptr(T, self._obj, [offset])
            else:
                val = _ptr(Ptr(T), val, solid=self._solid)
        return val

assert not '__dict__' in dir(_ptr)

class _ptrEntry(ExtRegistryEntry):
    _type_ = _ptr

    def compute_annotation(self):
        from rpython.rtyper.llannotation import SomePtr
        return SomePtr(typeOf(self.instance))

class SomePtr(SomeObject):
    knowntype = _ptr
    immutable = True

    def __init__(self, ll_ptrtype):
        assert isinstance(ll_ptrtype, Ptr)
        self.ll_ptrtype = ll_ptrtype

    def can_be_none(self):
        return False

    def getattr(self, s_attr):
        from rpython.rtyper.llannotation import SomeLLADTMeth, ll_to_annotation
        if not s_attr.is_constant():
            raise AnnotatorError("getattr on ptr %r with non-constant "
                                 "field-name" % self.ll_ptrtype)
        example = self.ll_ptrtype._example()
        try:
            v = example._lookup_adtmeth(s_attr.const)
        except AttributeError:
            v = getattr(example, s_attr.const)
            return ll_to_annotation(v)
        else:
            if isinstance(v, MethodType):
                ll_ptrtype = typeOf(v.im_self)
                assert isinstance(ll_ptrtype, (Ptr, InteriorPtr))
                return SomeLLADTMeth(ll_ptrtype, v.im_func)
            return immutablevalue(v)
    getattr.can_only_throw = []

    def len(self):
        length = self.ll_ptrtype._example()._fixedlength()
        if length is None:
            return SomeObject.len(self)
        else:
            return immutablevalue(length)

    def setattr(self, s_attr, s_value): # just doing checking
        from rpython.rtyper.llannotation import annotation_to_lltype
        if not s_attr.is_constant():
            raise AnnotatorError("setattr on ptr %r with non-constant "
                                 "field-name" % self.ll_ptrtype)
        example = self.ll_ptrtype._example()
        if getattr(example, s_attr.const) is not None:  # ignore Void s_value
            v_lltype = annotation_to_lltype(s_value)
            setattr(example, s_attr.const, v_lltype._defl())

    def call(self, args):
        from rpython.rtyper.llannotation import (
            annotation_to_lltype, ll_to_annotation)
        args_s, kwds_s = args.unpack()
        if kwds_s:
            raise Exception("keyword arguments to call to a low-level fn ptr")
        info = 'argument to ll function pointer call'
        llargs = [annotation_to_lltype(s_arg, info)._defl()
                  for s_arg in args_s]
        v = self.ll_ptrtype._example()(*llargs)
        return ll_to_annotation(v)

    def bool(self):
        result = SomeBool()
        if self.is_constant():
            result.const = bool(self.const)
        return result


class _interior_ptr(_abstract_ptr):
    __slots__ = ('_parent', '_offsets')
    def _set_parent(self, _parent):
        _interior_ptr._parent.__set__(self, _parent)
    def _set_offsets(self, _offsets):
        _interior_ptr._offsets.__set__(self, _offsets)

    def __init__(self, _T, _parent, _offsets):
        self._set_T(_T)
        #self._set_parent(weakref.ref(_parent))
        self._set_parent(_parent)
        self._set_offsets(_offsets)

    def __nonzero__(self):
        raise RuntimeError("do not test an interior pointer for nullity")

    def _get_obj(self):
        ob = self._parent
        if ob is None:
            raise RuntimeError
        if isinstance(ob, _container):
            ob._check()
        for o in self._offsets:
            if isinstance(o, str):
                ob = ob._getattr(o)
            else:
                ob = ob.getitem(o)
        return ob
    _obj = property(_get_obj)

    def _get_TYPE(self):
        ob = self._parent
        if ob is None:
            raise RuntimeError
        return InteriorPtr(typeOf(ob), self._T, self._offsets)
##     _TYPE = property(_get_TYPE)

    def _expose(self, offset, val):
        """XXX A nice docstring here"""
        T = typeOf(val)
        if isinstance(T, ContainerType):
            assert T._gckind == 'raw'
            val = _interior_ptr(T, self._parent, self._offsets + [offset])
        return val


assert not '__dict__' in dir(_interior_ptr)

class _container(object):
    __slots__ = ()
    def _parentstructure(self, check=True):
        return None
    def _check(self):
        pass
    def _as_ptr(self):
        return _ptr(Ptr(self._TYPE), self, True)
    def _as_obj(self, check=True):
        return self
    def _normalizedcontainer(self, check=True):
        return self
    def _getid(self):
        return id(self)
    def _was_freed(self):
        return False

class _parentable(_container):
    _kind = "?"

    __slots__ = ('_TYPE',
                 '_parent_type', '_parent_index', '_keepparent',
                 '_wrparent',
                 '__weakref__',
                 '_storage')

    def __init__(self, TYPE):
        self._wrparent = None
        self._TYPE = TYPE
        self._storage = True    # means "use default storage", as opposed to:
                                #    None            - container was freed
                                #    <ctypes object> - using ctypes
                                #                      (see ll2ctypes.py)

    def _free(self):
        self._check()   # no double-frees
        self._storage = None

    def _protect(self):
        result = self._storage
        self._free()   # no double-frees or double-protects
        return result

    def _unprotect(self, saved_storage):
        assert self._storage is None
        self._storage = saved_storage

    def _was_freed(self):
        if self._storage is None:
            return True
        if self._wrparent is None:
            return False
        parent = self._wrparent()
        if parent is None:
            raise RuntimeError("accessing sub%s %r,\n"
                               "but already garbage collected parent %r"
                               % (self._kind, self, self._parent_type))
        return parent._was_freed()

    def _setparentstructure(self, parent, parentindex):
        self._wrparent = weakref.ref(parent)
        self._parent_type = typeOf(parent)
        self._parent_index = parentindex
        if (isinstance(self._parent_type, Struct)
            and self._parent_type._names
            and parentindex in (self._parent_type._names[0], 0)
            and self._TYPE._gckind == typeOf(parent)._gckind):
            # keep strong reference to parent, we share the same allocation
            self._keepparent = parent

    def _parentstructure(self, check=True):
        if self._wrparent is not None:
            parent = self._wrparent()
            if parent is None:
                raise RuntimeError("accessing sub%s %r,\n"
                                   "but already garbage collected parent %r"
                                   % (self._kind, self, self._parent_type))
            if check:
                parent._check()
            return parent
        return None

    def _check(self):
        if self._storage is None:
            raise RuntimeError("accessing freed %r" % self._TYPE)
        self._parentstructure()

    def _normalizedcontainer(self, check=True):
        # if we are the first inlined substructure of a structure,
        # return the whole (larger) structure instead
        container = self
        while True:
            parent = container._parentstructure(check=check)
            if parent is None:
                break
            index = container._parent_index
            T = typeOf(parent)
            if (not isinstance(T, Struct) or T._first_struct()[0] != index
                or isinstance(T, FixedSizeArray)):
                break
            container = parent
        return container

def _struct_variety(flds, cache={}):
    flds = list(flds)
    flds.sort()
    tag = tuple(flds)
    try:
        return cache[tag]
    except KeyError:
        class _struct1(_struct):
            __slots__ = tag + ('__arena_location__',)
        cache[tag] = _struct1
        return _struct1

#for pickling support:
def _get_empty_instance_of_struct_variety(flds):
    cls = _struct_variety(flds)
    return object.__new__(cls)

class _struct(_parentable):
    _kind = "structure"

    __slots__ = ('_compilation_info',)

    def __new__(self, TYPE, n=None, initialization=None, parent=None,
                parentindex=None):
        if isinstance(TYPE, FixedSizeArray):
            my_variety = _fixedsizearray
        else:
            my_variety = _struct_variety(TYPE._names)
        return object.__new__(my_variety)

    def __init__(self, TYPE, n=None, initialization=None, parent=None,
                 parentindex=None):
        _parentable.__init__(self, TYPE)
        if n is not None and TYPE._arrayfld is None:
            raise TypeError("%r is not variable-sized" % (TYPE,))
        if n is None and TYPE._arrayfld is not None:
            raise TypeError("%r is variable-sized" % (TYPE,))
        for fld, typ in TYPE._flds.items():
            if fld == TYPE._arrayfld:
                value = _array(typ, n, initialization=initialization,
                               parent=self, parentindex=fld)
            else:
                value = typ._allocate(initialization=initialization,
                                      parent=self, parentindex=fld)
            setattr(self, fld, value)
        if parent is not None:
            self._setparentstructure(parent, parentindex)

    def __repr__(self):
        return '<%s>' % (self,)

    def _str_fields(self):
        fields = []
        names = self._TYPE._names
        if len(names) > 10:
            names = names[:5] + names[-1:]
            skipped_after = 5
        else:
            skipped_after = None
        for name in names:
            T = self._TYPE._flds[name]
            if isinstance(T, Primitive):
                reprvalue = repr(getattr(self, name, '<uninitialized>'))
            else:
                reprvalue = '...'
            fields.append('%s=%s' % (name, reprvalue))
        if skipped_after:
            fields.insert(skipped_after, '(...)')
        return ', '.join(fields)

    def __str__(self):
        return 'struct %s { %s }' % (self._TYPE._name, self._str_fields())

    def _getattr(self, field_name, uninitialized_ok=False):
        r = getattr(self, field_name)
        if isinstance(r, _uninitialized) and not uninitialized_ok:
            raise UninitializedMemoryAccess("%r.%s"%(self, field_name))
        return r


class _fixedsizearray(_struct):
    def __init__(self, TYPE, n=None, initialization=None, parent=None,
                 parentindex=None):
        _parentable.__init__(self, TYPE)
        if n is not None:
            raise TypeError("%r is not variable-sized" % (TYPE,))
        typ = TYPE.OF
        storage = []
        for i, fld in enumerate(TYPE._names):
            value = typ._allocate(initialization=initialization,
                                  parent=self, parentindex=fld)
            storage.append(value)
        self._items = storage
        if parent is not None:
            self._setparentstructure(parent, parentindex)

    def getlength(self):
        return self._TYPE.length

    def getbounds(self):
        return 0, self.getlength()

    def getitem(self, index, uninitialized_ok=False):
        assert 0 <= index < self.getlength()
        return self._items[index]

    def setitem(self, index, value):
        assert 0 <= index < self.getlength()
        self._items[index] = value

    def __getattr__(self, name):
        # obscure
        if name.startswith("item"):
            return self.getitem(int(name[len('item'):]))
        return _struct.__getattr__(self, name)

    def __setattr__(self, name, value):
        if name.startswith("item"):
            self.setitem(int(name[len('item'):]), value)
            return
        _struct.__setattr__(self, name, value)

class _array(_parentable):
    _kind = "array"

    __slots__ = ('items', '__arena_location__',)

    def __init__(self, TYPE, n, initialization=None, parent=None,
                 parentindex=None):
        if not is_valid_int(n):
            raise TypeError("array length must be an int")
        if n < 0:
            raise ValueError("negative array length")
        _parentable.__init__(self, TYPE)
        myrange = self._check_range(n)
        self.items = [TYPE.OF._allocate(initialization=initialization,
                                        parent=self, parentindex=j)
                      for j in myrange]
        if parent is not None:
            self._setparentstructure(parent, parentindex)

    def __repr__(self):
        return '<%s>' % (self,)

    def _check_range(self, n):
        # checks that it's ok to make an array of size 'n', and returns
        # range(n).  Explicitly overridden by some tests.
        try:
            return range(n)
        except OverflowError:
            raise MemoryError("definitely too many items")

    def _str_item(self, item):
        if isinstance(item, _uninitialized):
            return '#'
        if isinstance(self._TYPE.OF, Struct):
            of = self._TYPE.OF
            if self._TYPE._anonym_struct:
                return "{%s}" % item._str_fields()
            else:
                return "%s {%s}" % (of._name, item._str_fields())
        else:
            return repr(item)

    def __str__(self):
        items = self.items
        if len(items) > 20:
            items = items[:12] + items[-5:]
            skipped_at = 12
        else:
            skipped_at = None
        items = [self._str_item(item) for item in items]
        if skipped_at:
            items.insert(skipped_at, '(...)')
        return 'array [ %s ]' % (', '.join(items),)

    def getlength(self):
        return len(self.items)

    def shrinklength(self, newlength):
        del self.items[newlength:]

    def getbounds(self):
        stop = len(self.items)
        return 0, stop

    def getitem(self, index, uninitialized_ok=False):
        try:
            v = self.items[index]
        except IndexError:
            if (index == len(self.items) and uninitialized_ok == 2 and
                self._TYPE._hints.get('extra_item_after_alloc')):
                # special case: reading the extra final char returns
                # an uninitialized, if 'uninitialized_ok==2'
                return _uninitialized(self._TYPE.OF)
            raise
        if isinstance(v, _uninitialized) and not uninitialized_ok:
            raise UninitializedMemoryAccess("%r[%s]"%(self, index))
        return v

    def setitem(self, index, value):
        assert typeOf(value) == self._TYPE.OF
        try:
            self.items[index] = value
        except IndexError:
            if (index == len(self.items) and value == '\x00' and
                self._TYPE._hints.get('extra_item_after_alloc')):
                # special case: writing NULL to the extra final char
                return
            raise

assert not '__dict__' in dir(_array)
assert not '__dict__' in dir(_struct)


class _subarray(_parentable):     # only for direct_fieldptr()
                                  # and direct_arrayitems()
    _kind = "subarray"
    _cache = {}  # TYPE -> weak{ parentarray -> {subarrays} }

    def __init__(self, TYPE, parent, baseoffset_or_fieldname):
        _parentable.__init__(self, TYPE)
        self._setparentstructure(parent, baseoffset_or_fieldname)
        # Keep the parent array alive, we share the same allocation.
        # Don't do it if we are inside a GC object, though -- it's someone
        # else's job to keep the GC object alive
        if (typeOf(top_container(parent))._gckind == 'raw' or
            hasattr(top_container(parent)._storage, 'contents')):  # ll2ctypes
            self._keepparent = parent

    def __str__(self):
        parent = self._wrparent()
        if parent is None:
            return '_subarray at %s in already freed' % (self._parent_index,)
        return '_subarray at %r in %s' % (self._parent_index,
                                          parent._TYPE)

    def __repr__(self):
        parent = self._wrparent()
        if parent is None:
            return '<_subarray at %s in already freed>' % (self._parent_index,)
        return '<_subarray at %r in %r>' % (self._parent_index,
                                            self._parentstructure(check=False))

    def getlength(self):
        assert isinstance(self._TYPE, FixedSizeArray)
        return self._TYPE.length

    def getbounds(self):
        baseoffset = self._parent_index
        if isinstance(baseoffset, str):
            return 0, 1     # structfield case
        start, stop = self._parentstructure().getbounds()
        return start - baseoffset, stop - baseoffset

    def getitem(self, index, uninitialized_ok=False):
        baseoffset = self._parent_index
        if isinstance(baseoffset, str):
            assert index == 0
            fieldname = baseoffset    # structfield case
            return getattr(self._parentstructure(), fieldname)
        else:
            return self._parentstructure().getitem(baseoffset + index,
                                             uninitialized_ok=uninitialized_ok)

    def setitem(self, index, value):
        baseoffset = self._parent_index
        if isinstance(baseoffset, str):
            assert index == 0
            fieldname = baseoffset    # structfield case
            setattr(self._parentstructure(), fieldname, value)
        else:
            self._parentstructure().setitem(baseoffset + index, value)

    def _makeptr(parent, baseoffset_or_fieldname, solid=False):
        try:
            d = _subarray._cache[parent._TYPE]
        except KeyError:
            d = _subarray._cache[parent._TYPE] = weakref.WeakKeyDictionary()
        try:
            cache = d.setdefault(parent, {})
        except RuntimeError:    # pointer comparison with a freed structure
            _subarray._cleanup_cache()
            # try again
            return _subarray._makeptr(parent, baseoffset_or_fieldname, solid)
        try:
            subarray = cache[baseoffset_or_fieldname]
        except KeyError:
            PARENTTYPE = typeOf(parent)
            if isinstance(baseoffset_or_fieldname, str):
                # for direct_fieldptr
                ITEMTYPE = getattr(PARENTTYPE, baseoffset_or_fieldname)
            else:
                # for direct_arrayitems
                ITEMTYPE = PARENTTYPE.OF
            ARRAYTYPE = FixedSizeArray(ITEMTYPE, 1)
            subarray = _subarray(ARRAYTYPE, parent, baseoffset_or_fieldname)
            cache[baseoffset_or_fieldname] = subarray
        return _ptr(Ptr(subarray._TYPE), subarray, solid)
    _makeptr = staticmethod(_makeptr)

    def _getid(self):
        raise NotImplementedError('_subarray._getid()')

    def _cleanup_cache():
        for T, d in _subarray._cache.items():
            newcache = weakref.WeakKeyDictionary()
            for key, value in d.items():
                try:
                    if not key._was_freed():
                        newcache[key] = value
                except RuntimeError:
                    # ignore "accessing subxxx, but already gc-ed parent"
                    pass
            if newcache:
                _subarray._cache[T] = newcache
            else:
                del _subarray._cache[T]
    _cleanup_cache = staticmethod(_cleanup_cache)


class _arraylenref(_parentable):
    """Pseudo-reference to the length field of an array.
    Only used internally by llmemory to implement ArrayLengthOffset.
    """
    _kind = "arraylenptr"
    _cache = weakref.WeakKeyDictionary()  # array -> _arraylenref

    def __init__(self, array):
        TYPE = FixedSizeArray(Signed, 1)
        _parentable.__init__(self, TYPE)
        self.array = array

    def getlength(self):
        return 1

    def getbounds(self):
        return 0, 1

    def getitem(self, index, uninitialized_ok=False):
        assert index == 0
        return self.array.getlength()

    def setitem(self, index, value):
        assert index == 0
        if value != self.array.getlength():
            if value > self.array.getlength():
                raise Exception("can't grow an array in-place")
            self.array.shrinklength(value)

    def _makeptr(array, solid=False):
        try:
            lenref = _arraylenref._cache[array]
        except KeyError:
            lenref = _arraylenref(array)
            _arraylenref._cache[array] = lenref
        return _ptr(Ptr(lenref._TYPE), lenref, solid)
    _makeptr = staticmethod(_makeptr)

    def _getid(self):
        raise NotImplementedError('_arraylenref._getid()')


class _func(_container):
    def __init__(self, TYPE, **attrs):
        attrs.setdefault('_TYPE', TYPE)
        attrs.setdefault('_name', '?')
        attrs.setdefault('_callable', None)
        self.__dict__.update(attrs)
        if '_callable' in attrs and hasattr(attrs['_callable'],
                                            '_compilation_info'):
            self.__dict__['compilation_info'] = \
                attrs['_callable']._compilation_info

    def __repr__(self):
        return '<%s>' % (self,)

    def __str__(self):
        return "fn %s" % self._name

    def __eq__(self, other):
        return (self.__class__ is other.__class__ and
                self.__dict__ == other.__dict__)

    def __ne__(self, other):
        return not (self == other)

    def __hash__(self):
        return hash(frozendict(self.__dict__))

    def _getid(self):
        if hasattr(self, 'graph'):
            return id(self.graph)
        elif self._callable:
            return id(self._callable)
        else:
            return id(self)

    def __setattr__(self, attr, value):
        raise AttributeError("cannot change the attributes of %r" % (self,))

class _opaque(_parentable):
    def __init__(self, TYPE, parent=None, parentindex=None, **attrs):
        _parentable.__init__(self, TYPE)
        self._name = "?"
        self.__dict__.update(attrs)
        if parent is not None:
            self._setparentstructure(parent, parentindex)

    def __repr__(self):
        return '<%s>' % (self,)

    def __str__(self):
        return "%s %s" % (self._TYPE.__name__, self._name)

    def __eq__(self, other):
        if self.__class__ is not other.__class__:
            return NotImplemented
        if hasattr(self, 'container') and hasattr(other, 'container'):
            obj1 = self._normalizedcontainer()
            obj2 = other._normalizedcontainer()
            return obj1 == obj2
        else:
            return self is other

    def __ne__(self, other):
        if self.__class__ is not other.__class__:
            return NotImplemented
        return not (self == other)

    def __hash__(self):
        if hasattr(self, 'container'):
            obj = self.container._normalizedcontainer()
            return hash(obj)
        else:
            return _parentable.__hash__(self)

    def _normalizedcontainer(self):
        # if we are an opaque containing a normal Struct/GcStruct,
        # unwrap it
        if hasattr(self, 'container'):
            # an integer, cast to a ptr, cast to an opaque
            if type(self.container) is int:
                return self.container
            if getattr(self.container, '_carry_around_for_tests', False):
                return self.container
            return self.container._normalizedcontainer()
        else:
            return _parentable._normalizedcontainer(self)


def malloc(T, n=None, flavor='gc', immortal=False, zero=False,
           track_allocation=True, add_memory_pressure=False,
           nonmovable=False):
    assert flavor in ('gc', 'raw')
    if zero or immortal:
        initialization = 'example'
    elif flavor == 'raw':
        initialization = 'raw'
    else:
        initialization = 'malloc'
    if isinstance(T, Struct):
        o = _struct(T, n, initialization=initialization)
    elif isinstance(T, Array):
        o = _array(T, n, initialization=initialization)
    elif isinstance(T, OpaqueType):
        assert n is None
        o = _opaque(T, initialization=initialization)
    else:
        raise TypeError("malloc: unmallocable type")
    if flavor == 'gc' and T._gckind != 'gc' and not immortal:
        raise TypeError("gc flavor malloc of a non-GC non-immortal structure")
    if flavor == "raw" and not immortal and track_allocation:
        leakfinder.remember_malloc(o, framedepth=2)
    solid = immortal or flavor == 'raw'
    return _ptr(Ptr(T), o, solid)

@analyzer_for(malloc)
def ann_malloc(s_T, s_n=None, s_flavor=None, s_immortal=None, s_zero=None,
               s_track_allocation=None, s_add_memory_pressure=None,
               s_nonmovable=None):
    assert (s_n is None or s_n.knowntype == int
            or issubclass(s_n.knowntype, base_int))
    assert s_T.is_constant()
    if s_n is not None:
        n = 1
    else:
        n = None
    if s_zero:
        assert s_zero.is_constant()
    if s_flavor is None:
        p = malloc(s_T.const, n)
        r = SomePtr(typeOf(p))
    else:
        assert s_flavor.is_constant()
        assert s_track_allocation is None or s_track_allocation.is_constant()
        assert (s_add_memory_pressure is None or
                s_add_memory_pressure.is_constant())
        assert s_nonmovable is None or s_nonmovable.is_constant()
        # not sure how to call malloc() for the example 'p' in the
        # presence of s_extraargs
        r = SomePtr(Ptr(s_T.const))
    return r


def free(p, flavor, track_allocation=True):
    if flavor.startswith('gc'):
        raise TypeError("gc flavor free")
    T = typeOf(p)
    if not isinstance(T, Ptr) or p._togckind() != 'raw':
        raise TypeError("free(): only for pointers to non-gc containers")
    if track_allocation:
        leakfinder.remember_free(p._obj0)
    p._obj0._free()

@analyzer_for(free)
def ann_free(s_p, s_flavor, s_track_allocation=None):
    assert s_flavor.is_constant()
    assert s_track_allocation is None or s_track_allocation.is_constant()
    # same problem as in malloc(): some flavors are not easy to
    # malloc-by-example
    #T = s_p.ll_ptrtype.TO
    #p = malloc(T, flavor=s_flavor.const)
    #free(p, flavor=s_flavor.const)


def render_immortal(p, track_allocation=True):
    T = typeOf(p)
    if not isinstance(T, Ptr) or p._togckind() != 'raw':
        raise TypeError("free(): only for pointers to non-gc containers")
    if track_allocation:
        leakfinder.remember_free(p._obj0)

@analyzer_for(render_immortal)
def ann_render_immortal(s_p, s_track_allocation=None):
    assert s_track_allocation is None or s_track_allocation.is_constant()

def _make_scoped_allocator(T, zero):
    class ScopedAlloc:
        def __init__(self, n=None):
            if n is None:
                self.buf = malloc(T, flavor='raw', zero=zero)
            else:
                self.buf = malloc(T, n, flavor='raw', zero=zero)

        def __enter__(self):
            return self.buf

        def __exit__(self, *args):
            free(self.buf, flavor='raw')

    ScopedAlloc.__name__ = 'ScopedAlloc_%s' % (T,)
    return ScopedAlloc
_make_scoped_allocator._annspecialcase_ = 'specialize:memo'

def scoped_alloc(T, n=None, zero=False):
    """Returns a context manager which handles allocation and
    deallocation of temporary memory. Use it in a with statement::

        with scoped_alloc(Array(Signed), 1) as array:
            ...use array...
        ...it's freed now.
    """
    return _make_scoped_allocator(T, zero)(n=n)
scoped_alloc._annspecialcase_ = 'specialize:arg(0, 2)'

def functionptr(TYPE, name, **attrs):
    if not isinstance(TYPE, FuncType):
        raise TypeError("functionptr() for FuncTypes only")
    try:
        hash(tuple(attrs.items()))
    except TypeError:
        raise TypeError("'%r' must be hashable"%attrs)
    o = _func(TYPE, _name=name, **attrs)
    return _ptr(Ptr(TYPE), o)

def _getconcretetype(v):
    return v.concretetype

def getfunctionptr(graph, getconcretetype=_getconcretetype):
    """Return callable given a Python function."""
    llinputs = [getconcretetype(v) for v in graph.getargs()]
    lloutput = getconcretetype(graph.getreturnvar())

    FT = FuncType(llinputs, lloutput)
    name = graph.name
    if hasattr(graph, 'func') and callable(graph.func):
        # the Python function object can have _llfnobjattrs_, specifying
        # attributes that are forced upon the functionptr().  The idea
        # for not passing these extra attributes as arguments to
        # getcallable() itself is that multiple calls to getcallable()
        # for the same graph should return equal functionptr() objects.
        if hasattr(graph.func, '_llfnobjattrs_'):
            fnobjattrs = graph.func._llfnobjattrs_.copy()
            # can specify a '_name', but use graph.name by default
            name = fnobjattrs.pop('_name', name)
        else:
            fnobjattrs = {}
        # _callable is normally graph.func, but can be overridden:
        # see fakeimpl in extfunc.py
        _callable = fnobjattrs.pop('_callable', graph.func)
        return functionptr(FT, name, graph=graph, _callable=_callable,
                           **fnobjattrs)
    else:
        return functionptr(FT, name, graph=graph)

def nullptr(T):
    return Ptr(T)._defl()

@analyzer_for(nullptr)
def ann_nullptr(T):
    assert T.is_constant()
    p = nullptr(T.const)
    return immutablevalue(p)


def opaqueptr(TYPE, name, **attrs):
    if not isinstance(TYPE, OpaqueType):
        raise TypeError("opaqueptr() for OpaqueTypes only")
    o = _opaque(TYPE, _name=name, **attrs)
    return _ptr(Ptr(TYPE), o, solid=True)


def cast_ptr_to_int(ptr):
    return ptr._cast_to_int()

@analyzer_for(cast_ptr_to_int)
def ann_cast_ptr_to_int(s_ptr): # xxx
    return SomeInteger()


def cast_int_to_ptr(PTRTYPE, oddint):
    if oddint == 0:
        return nullptr(PTRTYPE.TO)
    if not (oddint & 1):
        raise ValueError("only odd integers can be cast back to ptr")
    return _ptr(PTRTYPE, oddint, solid=True)

@analyzer_for(cast_int_to_ptr)
def ann_cast_int_to_ptr(PtrT, s_int):
    assert PtrT.is_constant()
    return SomePtr(ll_ptrtype=PtrT.const)


def attachRuntimeTypeInfo(GCSTRUCT, funcptr=None, destrptr=None):
    if not isinstance(GCSTRUCT, RttiStruct):
        raise TypeError("expected a RttiStruct: %s" % GCSTRUCT)
    GCSTRUCT._attach_runtime_type_info_funcptr(funcptr, destrptr)
    return _ptr(Ptr(RuntimeTypeInfo), GCSTRUCT._runtime_type_info)

def getRuntimeTypeInfo(GCSTRUCT):
    if not isinstance(GCSTRUCT, RttiStruct):
        raise TypeError("expected a RttiStruct: %s" % GCSTRUCT)
    if GCSTRUCT._runtime_type_info is None:
        raise ValueError("no attached runtime type info for GcStruct %s" %
                           GCSTRUCT._name)
    return _ptr(Ptr(RuntimeTypeInfo), GCSTRUCT._runtime_type_info)

@analyzer_for(getRuntimeTypeInfo)
def ann_getRuntimeTypeInfo(T):
    assert T.is_constant()
    return immutablevalue(getRuntimeTypeInfo(T.const))


def runtime_type_info(p):
    T = typeOf(p)
    if not isinstance(T, Ptr) or not isinstance(T.TO, RttiStruct):
        raise TypeError("runtime_type_info on non-RttiStruct pointer: %s" % p)
    struct = p._obj
    top_parent = top_container(struct)
    result = getRuntimeTypeInfo(top_parent._TYPE)
    static_info = getRuntimeTypeInfo(T.TO)
    query_funcptr = getattr(static_info._obj, 'query_funcptr', None)
    if query_funcptr is not None:
        T = typeOf(query_funcptr).TO.ARGS[0]
        result2 = query_funcptr(cast_pointer(T, p))
        if result != result2:
            raise RuntimeError("runtime type-info function for %s:\n"
                                 "        returned: %s,\n"
                                 "should have been: %s" % (p, result2, result))
    return result

@analyzer_for(runtime_type_info)
def ann_runtime_type_info(s_p):
    assert isinstance(s_p, SomePtr), \
        "runtime_type_info of non-pointer: %r" % s_p
    return SomePtr(typeOf(runtime_type_info(s_p.ll_ptrtype._example())))


def identityhash(p):
    """Returns the lltype-level hash of the given GcStruct.
    Not for NULL. See rlib.objectmodel.compute_identity_hash() for more
    information about the RPython-level meaning of this.
    """
    assert p
    return p._identityhash()

@analyzer_for(identityhash)
def ann_identityhash(s_obj):
    assert isinstance(s_obj, SomePtr)
    return SomeInteger()


def isCompatibleType(TYPE1, TYPE2):
    return TYPE1._is_compatible(TYPE2)

def enforce(TYPE, value):
    return TYPE._enforce(value)

# mark type ADT methods

def typeMethod(func):
    func._type_method = True
    return func

class staticAdtMethod(object):
    # Like staticmethod(), but for ADT methods.  The difference is only
    # that this version compares and hashes correctly, unlike CPython's.
    def __init__(self, obj):
        self.obj = obj

    def __get__(self, inst, typ=None):
        return self.obj

    def __hash__(self):
        return hash(self.obj)

    def __eq__(self, other):
        if not isinstance(other, staticAdtMethod):
            return NotImplemented
        else:
            return self.obj == other.obj

    def __ne__(self, other):
        if not isinstance(other, staticAdtMethod):
            return NotImplemented
        else:
            return self.obj != other.obj


def dissect_ll_instance(v, t=None, memo=None):
    if memo is None:
        memo = identity_dict()
    if v in memo:
        return
    memo[v] = True
    if t is None:
        t = typeOf(v)
    yield t, v
    if isinstance(t, Ptr):
        if v._obj:
            for i in dissect_ll_instance(v._obj, t.TO, memo):
                yield i
    elif isinstance(t, Struct):
        parent = v._parentstructure()
        if parent:
            for i in dissect_ll_instance(parent, typeOf(parent), memo):
                yield i
        for n in t._flds:
            f = getattr(t, n)
            for i in dissect_ll_instance(getattr(v, n), t._flds[n], memo):
                yield i
    elif isinstance(t, Array):
        for item in v.items:
            for i in dissect_ll_instance(item, t.OF, memo):
                yield i


