# this file contains the definitions and most extremely faked
# implementations of things relating to the description of the layout
# of objects in memeory.

# sizeof, offsetof

import weakref
from rpython.annotator.bookkeeper import analyzer_for
from rpython.annotator.model import SomeInteger, SomeObject, SomeString, s_Bool
from rpython.annotator.model import SomeBool
from rpython.rlib.objectmodel import Symbolic, specialize
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lltype import SomePtr
from rpython.tool.uid import uid
from rpython.rlib.rarithmetic import is_valid_int
from rpython.rtyper.extregistry import ExtRegistryEntry


class AddressOffset(Symbolic):

    def annotation(self):
        from rpython.annotator import model
        return model.SomeInteger()

    def lltype(self):
        return lltype.Signed

    def __add__(self, other):
        if not isinstance(other, AddressOffset):
            return NotImplemented
        return CompositeOffset(self, other)

    # special-casing: only for '>= 0' and '< 0' and only when the
    # symbolic offset is known to be non-negative
    def __ge__(self, other):
        if self is other:
            return True
        elif (is_valid_int(other) and other == 0 and
            self.known_nonneg()):
            return True
        else:
            raise TypeError("Symbolics cannot be compared! (%r, %r)"
                            % (self, other))

    def __lt__(self, other):
        return not self.__ge__(other)

    def known_nonneg(self):
        return False

    def _raw_malloc(self, rest, zero):
        raise NotImplementedError("_raw_malloc(%r, %r)" % (self, rest))

    def raw_memcopy(self, srcadr, dstadr):
        raise NotImplementedError("raw_memcopy(%r)" % (self,))


class ItemOffset(AddressOffset):

    def __init__(self, TYPE, repeat=1):
        self.TYPE = TYPE
        self.repeat = repeat

    def __repr__(self):
        return "<ItemOffset %r %r>" % (self.TYPE, self.repeat)

    def __mul__(self, other):
        if not is_valid_int(other):
            return NotImplemented
        return ItemOffset(self.TYPE, self.repeat * other)

    __rmul__ = __mul__

    def __neg__(self):
        return ItemOffset(self.TYPE, -self.repeat)

    def known_nonneg(self):
        return self.repeat >= 0

    def ref(self, firstitemptr):
        A = lltype.typeOf(firstitemptr).TO
        if A == self.TYPE:
            # for array of containers
            parent, index = lltype.parentlink(firstitemptr._obj)
            assert parent, "%r is not within a container" % (firstitemptr,)
            assert isinstance(lltype.typeOf(parent),
                              (lltype.Array, lltype.FixedSizeArray)), (
                "%r is not within an array" % (firstitemptr,))
            if isinstance(index, str):
                assert index.startswith('item')    # itemN => N
                index = int(index[4:])
            index += self.repeat
            if index == parent.getlength():
                # for references exactly to the end of the array
                try:
                    endmarker = _end_markers[parent]
                except KeyError:
                    endmarker = _endmarker_struct(A, parent=parent,
                                                  parentindex=index)
                    _end_markers[parent] = endmarker
                return endmarker._as_ptr()
            else:
                return parent.getitem(index)._as_ptr()
        elif ((isinstance(A, lltype.FixedSizeArray)
               or (isinstance(A, lltype.Array) and A._hints.get('nolength',
                                                                False)))
              and array_item_type_match(A.OF, self.TYPE)):
            # for array of primitives or pointers
            return lltype.direct_ptradd(firstitemptr, self.repeat)
        else:
            raise TypeError('got %r, expected %r' % (A, self.TYPE))

    def _raw_malloc(self, rest, zero):
        assert not rest
        if (isinstance(self.TYPE, lltype.ContainerType)
            and self.TYPE._gckind == 'gc'):
            assert self.repeat == 1
            p = lltype.malloc(self.TYPE, flavor='raw', zero=zero,
                              track_allocation=False)
            return cast_ptr_to_adr(p)
        else:
            T = lltype.FixedSizeArray(self.TYPE, self.repeat)
            p = lltype.malloc(T, flavor='raw', zero=zero,
                              track_allocation=False)
            array_adr = cast_ptr_to_adr(p)
            return array_adr + ArrayItemsOffset(T)

    def raw_memcopy(self, srcadr, dstadr):
        repeat = self.repeat
        if repeat == 0:
            return
        if isinstance(self.TYPE, lltype.ContainerType):
            PTR = lltype.Ptr(self.TYPE)
        elif self.TYPE == GCREF:
            self._raw_memcopy_gcrefs(srcadr, dstadr)
            return
        else:
            PTR = lltype.Ptr(lltype.FixedSizeArray(self.TYPE, 1))
        steps = []
        while True:
            src = cast_adr_to_ptr(srcadr, PTR)
            dst = cast_adr_to_ptr(dstadr, PTR)
            _reccopy_lazy(src, dst, steps)
            repeat -= 1
            if repeat <= 0:
                break
            srcadr += ItemOffset(self.TYPE)
            dstadr += ItemOffset(self.TYPE)
        for step in steps:
            step()

    def _raw_memcopy_gcrefs(self, srcadr, dstadr):
        # special case to handle arrays of any GC pointers
        repeat = self.repeat
        data_list = []
        while True:
            data_list.append(srcadr.address[0])
            repeat -= 1
            if repeat <= 0:
                break
            srcadr += ItemOffset(self.TYPE)
        for i, data in enumerate(data_list):
            if i > 0:
                dstadr += ItemOffset(self.TYPE)
            dstadr.address[0] = data

_end_markers = weakref.WeakKeyDictionary()  # <array of STRUCT> -> _endmarker
class _endmarker_struct(lltype._struct):
    __slots__ = ()
    def __new__(self, *args, **kwds):
        return object.__new__(self)
    def __init__(self, *args, **kwds):
        lltype._struct.__init__(self, *args, **kwds)
        self._storage = False
    def __getattr__(self, name):
        raise AttributeError("cannot access fields in the endmarker "
                             "structure at the end of the array")
    def __setattr__(self, name, value):
        if name.startswith('_'):
            object.__setattr__(self, name, value)  # '_xxx' attributes
        elif self._storage is False:
            raise AttributeError("cannot access fields in the endmarker "
                                 "structure at the end of the array")


class FieldOffset(AddressOffset):

    def __init__(self, TYPE, fldname):
        self.TYPE = TYPE
        self.fldname = fldname

    def __repr__(self):
        return "<FieldOffset %r %r>" % (self.TYPE, self.fldname)

    def known_nonneg(self):
        return True

    def ref(self, struct):
        if lltype.typeOf(struct).TO != self.TYPE:
            struct = lltype.cast_pointer(lltype.Ptr(self.TYPE), struct)
        FIELD = getattr(self.TYPE, self.fldname)
        if isinstance(FIELD, lltype.ContainerType):
            substruct = struct._obj._getattr(self.fldname)
            return substruct._as_ptr()
        else:
            return lltype.direct_fieldptr(struct, self.fldname)

    def _raw_malloc(self, rest, parenttype=None, zero=False):
        if self.fldname != self.TYPE._arrayfld:
            # for the error msg
            return AddressOffset._raw_malloc(self, rest, zero=zero)
        assert rest
        return rest[0]._raw_malloc(rest[1:], parenttype=parenttype or self.TYPE,
                                            zero=zero)

    def raw_memcopy(self, srcadr, dstadr):
        if self.fldname != self.TYPE._arrayfld:
            return AddressOffset.raw_memcopy(srcadr, dstadr) #for the error msg
        PTR = lltype.Ptr(self.TYPE)
        src = cast_adr_to_ptr(srcadr, PTR)
        dst = cast_adr_to_ptr(dstadr, PTR)
        _reccopy(src, dst)


class CompositeOffset(AddressOffset):

    def __new__(cls, *offsets):
        lst = []
        for item in offsets:
            if isinstance(item, CompositeOffset):
                lst.extend(item.offsets)
            else:
                lst.append(item)
        for i in range(len(lst)-2, -1, -1):
            if (isinstance(lst[i], ItemOffset) and
                isinstance(lst[i+1], ItemOffset) and
                lst[i].TYPE == lst[i+1].TYPE):
                lst[i:i+2] = [ItemOffset(lst[i].TYPE,
                                         lst[i].repeat + lst[i+1].repeat)]
        if len(lst) == 1:
            return lst[0]
        else:
            self = object.__new__(cls)
            self.offsets = lst
            return self

    def __repr__(self):
        return '< %s >' % (' + '.join([repr(item) for item in self.offsets]),)

    def __neg__(self):
        ofs = [-item for item in self.offsets]
        ofs.reverse()
        return CompositeOffset(*ofs)

    def known_nonneg(self):
        for item in self.offsets:
            if not item.known_nonneg():
                return False
        return True

    def ref(self, ptr):
        for item in self.offsets:
            ptr = item.ref(ptr)
        return ptr

    def _raw_malloc(self, rest, zero):
        return self.offsets[0]._raw_malloc(self.offsets[1:] + rest, zero=zero)

    def raw_memcopy(self, srcadr, dstadr):
        for o in self.offsets[:-1]:
            o.raw_memcopy(srcadr, dstadr)
            srcadr += o
            dstadr += o
        o = self.offsets[-1]
        o.raw_memcopy(srcadr, dstadr)


class ArrayItemsOffset(AddressOffset):

    def __init__(self, TYPE):
        self.TYPE = TYPE

    def __repr__(self):
        return '< ArrayItemsOffset %r >' % (self.TYPE,)

    def known_nonneg(self):
        return True

    def ref(self, arrayptr):
        assert array_type_match(lltype.typeOf(arrayptr).TO, self.TYPE)
        if isinstance(self.TYPE.OF, lltype.ContainerType):
            # XXX this doesn't support empty arrays
            # XXX it's also missing 'solid' support, probably
            o = arrayptr._obj.getitem(0)
            return o._as_ptr()
        else:
            return lltype.direct_arrayitems(arrayptr)

    def _raw_malloc(self, rest, parenttype=None, zero=False):
        if rest:
            assert len(rest) == 1
            assert isinstance(rest[0], ItemOffset)
            assert self.TYPE.OF == rest[0].TYPE
            count = rest[0].repeat
        else:
            count = 0
        p = lltype.malloc(parenttype or self.TYPE, count,
                          immortal = self.TYPE._gckind == 'raw',
                          zero = zero,
                          track_allocation = False)
        return cast_ptr_to_adr(p)

    def raw_memcopy(self, srcadr, dstadr):
        # copy the length field, if we can
        srclen = srcadr.ptr._obj.getlength()
        dstlen = dstadr.ptr._obj.getlength()
        if dstlen != srclen:
            assert dstlen > srclen, "can't increase the length"
            # a decrease in length occurs in the GC tests when copying a STR:
            # the copy is initially allocated with really one extra char,
            # the 'extra_item_after_alloc', and must be fixed.
            dstadr.ptr._obj.shrinklength(srclen)


class ArrayLengthOffset(AddressOffset):

    def __init__(self, TYPE):
        self.TYPE = TYPE

    def __repr__(self):
        return '< ArrayLengthOffset %r >' % (self.TYPE,)

    def known_nonneg(self):
        return True

    def ref(self, arrayptr):
        assert array_type_match(lltype.typeOf(arrayptr).TO, self.TYPE)
        return lltype._arraylenref._makeptr(arrayptr._obj, arrayptr._solid)


class GCHeaderOffset(AddressOffset):
    def __init__(self, gcheaderbuilder):
        self.gcheaderbuilder = gcheaderbuilder

    def __repr__(self):
        return '< GCHeaderOffset >'

    def __neg__(self):
        return GCHeaderAntiOffset(self.gcheaderbuilder)

    def known_nonneg(self):
        return True

    def ref(self, headerptr):
        gcptr = self.gcheaderbuilder.object_from_header(headerptr)
        return gcptr

    def _raw_malloc(self, rest, zero):
        assert rest
        if isinstance(rest[0], GCHeaderAntiOffset):
            return rest[1]._raw_malloc(rest[2:], zero=zero)    # just for fun
        gcobjadr = rest[0]._raw_malloc(rest[1:], zero=zero)
        headerptr = self.gcheaderbuilder.new_header(gcobjadr.ptr)
        return cast_ptr_to_adr(headerptr)

    def raw_memcopy(self, srcadr, dstadr):
        _reccopy(srcadr.ptr, dstadr.ptr)

class GCHeaderAntiOffset(AddressOffset):
    def __init__(self, gcheaderbuilder):
        self.gcheaderbuilder = gcheaderbuilder

    def __repr__(self):
        return '< GCHeaderAntiOffset >'

    def __neg__(self):
        return GCHeaderOffset(self.gcheaderbuilder)

    def ref(self, gcptr):
        headerptr = self.gcheaderbuilder.header_of_object(gcptr)
        return headerptr

    def _raw_malloc(self, rest, zero):
        assert len(rest) >= 2
        assert isinstance(rest[0], GCHeaderOffset)
        return rest[1]._raw_malloc(rest[2:], zero=zero)

# ____________________________________________________________

@specialize.memo()
def _sizeof_none(TYPE):
    assert not TYPE._is_varsize()
    return ItemOffset(TYPE)

@specialize.memo()
def _internal_array_field(TYPE):
    return TYPE._arrayfld, TYPE._flds[TYPE._arrayfld]

def _sizeof_int(TYPE, n):
    if isinstance(TYPE, lltype.Struct):
        fldname, ARRAY = _internal_array_field(TYPE)
        return offsetof(TYPE, fldname) + sizeof(ARRAY, n)
    else:
        raise Exception("don't know how to take the size of a %r"%TYPE)

@specialize.memo()
def extra_item_after_alloc(ARRAY):
    assert isinstance(ARRAY, lltype.Array)
    return ARRAY._hints.get('extra_item_after_alloc', 0)

@specialize.arg(0)
def sizeof(TYPE, n=None):
    """Return the symbolic size of TYPE.
    For a Struct with no varsized part, it must be called with n=None.
    For an Array or a Struct with a varsized part, it is the number of items.
    There is a special case to return 1 more than requested if the array
    has the hint 'extra_item_after_alloc' set to 1.
    """
    if n is None:
        return _sizeof_none(TYPE)
    elif isinstance(TYPE, lltype.Array):
        n += extra_item_after_alloc(TYPE)
        return itemoffsetof(TYPE) + _sizeof_none(TYPE.OF) * n
    else:
        return _sizeof_int(TYPE, n)

@specialize.memo()
def offsetof(TYPE, fldname):
    assert fldname in TYPE._flds
    return FieldOffset(TYPE, fldname)

@analyzer_for(offsetof)
def ann_offsetof(TYPE, fldname):
    return SomeInteger()


@specialize.memo()
def itemoffsetof(TYPE, n=0):
    result = ArrayItemsOffset(TYPE)
    if n != 0:
        result += ItemOffset(TYPE.OF) * n
    return result

@specialize.memo()
def arraylengthoffset(TYPE):
    return ArrayLengthOffset(TYPE)

# -------------------------------------------------------------

class fakeaddress(object):
    __slots__ = ['ptr']
    # NOTE: the 'ptr' in the addresses must be normalized.
    # Use cast_ptr_to_adr() instead of directly fakeaddress() if unsure.
    def __init__(self, ptr):
        if ptr is not None and ptr._obj0 is None:
            ptr = None   # null ptr => None
        self.ptr = ptr

    def __repr__(self):
        if self.ptr is None:
            s = 'NULL'
        else:
            #try:
            #    s = hex(self.ptr._cast_to_int())
            #except:
            s = str(self.ptr)
        return '<fakeaddr %s>' % (s,)

    def __add__(self, other):
        if isinstance(other, AddressOffset):
            if self.ptr is None:
                raise NullAddressError("offset from NULL address")
            return fakeaddress(other.ref(self.ptr))
        if other == 0:
            return self
        return NotImplemented

    def __sub__(self, other):
        if isinstance(other, AddressOffset):
            return self + (-other)
        if isinstance(other, fakeaddress):
            if self == other:
                return 0
            else:
                raise TypeError("cannot subtract fakeaddresses in general")
        if other == 0:
            return self
        return NotImplemented

    def __nonzero__(self):
        return self.ptr is not None

    #def __hash__(self):
    #    raise TypeError("don't put addresses in a prebuilt dictionary")

    def __eq__(self, other):
        if isinstance(other, fakeaddress):
            try:
                obj1 = self._fixup().ptr
                obj2 = other._fixup().ptr
                if obj1 is not None: obj1 = obj1._obj
                if obj2 is not None: obj2 = obj2._obj
                return obj1 == obj2
            except lltype.DelayedPointer:
                return self.ptr is other.ptr
        else:
            return NotImplemented

    def __ne__(self, other):
        if isinstance(other, fakeaddress):
            return not (self == other)
        else:
            return NotImplemented

    def __lt__(self, other):
        # for the convenience of debugging the GCs, NULL compares as the
        # smallest address even when compared with a non-fakearenaaddress
        if not isinstance(other, fakeaddress):
            raise TypeError("cannot compare fakeaddress and %r" % (
                other.__class__.__name__,))
        if not other:
            return False     # self < NULL              => False
        if not self:
            return True      # NULL < non-null-other    => True
        raise TypeError("cannot compare non-NULL fakeaddresses with '<'")
    def __le__(self, other):
        return self == other or self < other
    def __gt__(self, other):
        return not (self == other or self < other)
    def __ge__(self, other):
        return not (self < other)

    def ref(self):
        if not self:
            raise NullAddressError
        return self.ptr

    def _cast_to_ptr(self, EXPECTED_TYPE):
        addr = self._fixup()
        if addr:
            return cast_any_ptr(EXPECTED_TYPE, addr.ptr)
        else:
            return lltype.nullptr(EXPECTED_TYPE.TO)

    def _cast_to_int(self, symbolic=False):
        if self:
            if isinstance(self.ptr._obj0, int):    # tagged integer
                return self.ptr._obj0
            if symbolic:
                return AddressAsInt(self)
            else:
                # This is a bit annoying. We want this method to still work
                # when the pointed-to object is dead
                return self.ptr._cast_to_int(False)
        else:
            return 0

    def _fixup(self):
        if self.ptr is not None and self.ptr._was_freed():
            # hack to support llarena.test_replace_object_with_stub()
            from rpython.rtyper.lltypesystem import llarena
            return llarena.getfakearenaaddress(self)
        else:
            return self

class fakeaddressEntry(ExtRegistryEntry):
    _type_ = fakeaddress

    def compute_annotation(self):
        from rpython.rtyper.llannotation import SomeAddress
        return SomeAddress()

class SomeAddress(SomeObject):
    immutable = True

    def can_be_none(self):
        return False

    def is_null_address(self):
        return self.is_immutable_constant() and not self.const

    def getattr(self, s_attr):
        assert s_attr.is_constant()
        assert isinstance(s_attr, SomeString)
        assert s_attr.const in supported_access_types
        return SomeTypedAddressAccess(supported_access_types[s_attr.const])
    getattr.can_only_throw = []

    def bool(self):
        return s_Bool

class SomeTypedAddressAccess(SomeObject):
    """This class is used to annotate the intermediate value that
    appears in expressions of the form:
    addr.signed[offset] and addr.signed[offset] = value
    """

    def __init__(self, type):
        self.type = type

    def can_be_none(self):
        return False

# ____________________________________________________________

class AddressAsInt(Symbolic):
    # a symbolic, rendered as an address cast to an integer.
    def __init__(self, adr):
        self.adr = adr
    def annotation(self):
        from rpython.annotator import model
        return model.SomeInteger()
    def lltype(self):
        return lltype.Signed
    def __eq__(self, other):
        return self.adr == cast_int_to_adr(other)
    def __ne__(self, other):
        return self.adr != cast_int_to_adr(other)
    def __nonzero__(self):
        return bool(self.adr)
    def __add__(self, ofs):
        if (isinstance(ofs, int) and
                getattr(self.adr.ptr._TYPE.TO, 'OF', None) == lltype.Char):
            return AddressAsInt(self.adr + ItemOffset(lltype.Char, ofs))
        if isinstance(ofs, FieldOffset) and ofs.TYPE is self.adr.ptr._TYPE.TO:
            fieldadr = getattr(self.adr.ptr, ofs.fldname)
            return AddressAsInt(cast_ptr_to_adr(fieldadr))
        if (isinstance(ofs, ItemOffset) and
            isinstance(self.adr.ptr._TYPE.TO, lltype.Array) and
            self.adr.ptr._TYPE.TO._hints.get('nolength') is True and
            ofs.TYPE is self.adr.ptr._TYPE.TO.OF):
            itemadr = self.adr.ptr[ofs.repeat]
            return AddressAsInt(cast_ptr_to_adr(itemadr))
        return NotImplemented
    def __repr__(self):
        try:
            return '<AddressAsInt %s>' % (self.adr.ptr,)
        except AttributeError:
            return '<AddressAsInt at 0x%x>' % (uid(self),)

# ____________________________________________________________

class NullAddressError(Exception):
    pass

class DanglingPointerError(Exception):
    pass

NULL = fakeaddress(None)
Address = lltype.Primitive("Address", NULL)

# GCREF is similar to Address but it is GC-aware
GCREF = lltype.Ptr(lltype.GcOpaqueType('GCREF'))

# A placeholder for any type that is a GcArray of pointers.
# This can be used in the symbolic offsets above to access such arrays
# in a generic way.
GCARRAY_OF_PTR = lltype.GcArray(GCREF, hints={'placeholder': True})
gcarrayofptr_lengthoffset = ArrayLengthOffset(GCARRAY_OF_PTR)
gcarrayofptr_itemsoffset = ArrayItemsOffset(GCARRAY_OF_PTR)
gcarrayofptr_singleitemoffset = ItemOffset(GCARRAY_OF_PTR.OF)
def array_type_match(A1, A2):
    return A1 == A2 or (A2 == GCARRAY_OF_PTR and
                        isinstance(A1, lltype.GcArray) and
                        isinstance(A1.OF, lltype.Ptr) and
                        not A1._hints.get('nolength'))
def array_item_type_match(T1, T2):
    return T1 == T2 or (T2 == GCREF and isinstance(T1, lltype.Ptr))


class _fakeaccessor(object):
    def __init__(self, addr):
        self.addr = addr
    def __getitem__(self, index):
        ptr = self.addr.ref()
        if index != 0:
            ptr = lltype.direct_ptradd(ptr, index)
        return self.read_from_ptr(ptr)

    def __setitem__(self, index, value):
        assert lltype.typeOf(value) == self.TYPE
        ptr = self.addr.ref()
        if index != 0:
            ptr = lltype.direct_ptradd(ptr, index)
        self.write_into_ptr(ptr, value)

    def read_from_ptr(self, ptr):
        value = ptr[0]
        assert lltype.typeOf(value) == self.TYPE
        return value

    def write_into_ptr(self, ptr, value):
        ptr[0] = value


class _signed_fakeaccessor(_fakeaccessor):
    TYPE = lltype.Signed

class _unsigned_fakeaccessor(_fakeaccessor):
    TYPE = lltype.Unsigned

class _float_fakeaccessor(_fakeaccessor):
    TYPE = lltype.Float

class _char_fakeaccessor(_fakeaccessor):
    TYPE = lltype.Char

class _address_fakeaccessor(_fakeaccessor):
    TYPE = Address

    def read_from_ptr(self, ptr):
        value = ptr[0]
        if isinstance(value, lltype._ptr):
            return value._cast_to_adr()
        elif lltype.typeOf(value) == Address:
            return value
        else:
            raise TypeError(value)

    def write_into_ptr(self, ptr, value):
        TARGETTYPE = lltype.typeOf(ptr).TO.OF
        if TARGETTYPE == Address:
            pass
        elif isinstance(TARGETTYPE, lltype.Ptr):
            value = cast_adr_to_ptr(value, TARGETTYPE)
        else:
            raise TypeError(TARGETTYPE)
        ptr[0] = value

supported_access_types = {"signed":    lltype.Signed,
                          "unsigned":  lltype.Unsigned,
                          "char":      lltype.Char,
                          "address":   Address,
                          "float":     lltype.Float,
                          }

fakeaddress.signed = property(_signed_fakeaccessor)
fakeaddress.unsigned = property(_unsigned_fakeaccessor)
fakeaddress.float = property(_float_fakeaccessor)
fakeaddress.char = property(_char_fakeaccessor)
fakeaddress.address = property(_address_fakeaccessor)
fakeaddress._TYPE = Address

# the obtained address will not keep the object alive. e.g. if the object is
# only reachable through an address, it might get collected
def cast_ptr_to_adr(obj):
    assert isinstance(lltype.typeOf(obj), lltype.Ptr)
    return obj._cast_to_adr()

@analyzer_for(cast_ptr_to_adr)
def ann_cast_ptr_to_adr(s):
    from rpython.rtyper.llannotation import SomeInteriorPtr
    assert not isinstance(s, SomeInteriorPtr)
    return SomeAddress()


def cast_adr_to_ptr(adr, EXPECTED_TYPE):
    return adr._cast_to_ptr(EXPECTED_TYPE)

@analyzer_for(cast_adr_to_ptr)
def ann_cast_adr_to_ptr(s, s_type):
    assert s_type.is_constant()
    return SomePtr(s_type.const)


def cast_adr_to_int(adr, mode="emulated"):
    # The following modes are supported before translation (after
    # translation, it's all just a cast):
    # * mode="emulated": goes via lltype.cast_ptr_to_int(), which returns some
    #     number based on id().  The difference is that it works even if the
    #     address is that of a dead object.
    # * mode="symbolic": returns an AddressAsInt instance, which can only be
    #     cast back to an address later.
    # * mode="forced": uses rffi.cast() to return a real number.
    assert mode in ("emulated", "symbolic", "forced")
    res = adr._cast_to_int(symbolic = (mode != "emulated"))
    if mode == "forced":
        from rpython.rtyper.lltypesystem.rffi import cast
        res = cast(lltype.Signed, res)
    return res

@analyzer_for(cast_adr_to_int)
def ann_cast_adr_to_int(s, s_mode=None):
    return SomeInteger()  # xxx


_NONGCREF = lltype.Ptr(lltype.OpaqueType('NONGCREF'))
def cast_int_to_adr(int):
    if isinstance(int, AddressAsInt):
        return int.adr
    try:
        ptr = lltype.cast_int_to_ptr(_NONGCREF, int)
    except ValueError:
        from rpython.rtyper.lltypesystem import ll2ctypes
        ptr = ll2ctypes._int2obj[int]._as_ptr()
    return cast_ptr_to_adr(ptr)

@analyzer_for(cast_int_to_adr)
def ann_cast_int_to_adr(s):
    return SomeAddress()

# ____________________________________________________________
# Weakrefs.
#
# An object of type WeakRef is a small GC-managed object that contains
# a weak reference to another GC-managed object, as in regular Python.
#

class _WeakRefType(lltype.ContainerType):
    _gckind = 'gc'

    def __str__(self):
        return "WeakRef"

WeakRef = _WeakRefType()
WeakRefPtr = lltype.Ptr(WeakRef)

def weakref_create(ptarget):
    # ptarget should not be a nullptr
    PTRTYPE = lltype.typeOf(ptarget)
    assert isinstance(PTRTYPE, lltype.Ptr)
    assert PTRTYPE.TO._gckind == 'gc'
    assert ptarget
    return _wref(ptarget)._as_ptr()

@analyzer_for(weakref_create)
def ann_weakref_create(s_obj):
    if (not isinstance(s_obj, SomePtr) or
            s_obj.ll_ptrtype.TO._gckind != 'gc'):
        raise Exception("bad type for argument to weakref_create(): %r" % (
            s_obj,))
    return SomePtr(WeakRefPtr)


def weakref_deref(PTRTYPE, pwref):
    # pwref should not be a nullptr
    assert isinstance(PTRTYPE, lltype.Ptr)
    assert PTRTYPE.TO._gckind == 'gc'
    assert lltype.typeOf(pwref) == WeakRefPtr
    p = pwref._obj._dereference()
    if p is None:
        return lltype.nullptr(PTRTYPE.TO)
    else:
        return cast_any_ptr(PTRTYPE, p)

@analyzer_for(weakref_deref)
def ann_weakref_deref(s_ptrtype, s_wref):
    if not (s_ptrtype.is_constant() and
            isinstance(s_ptrtype.const, lltype.Ptr) and
            s_ptrtype.const.TO._gckind == 'gc'):
        raise Exception("weakref_deref() arg 1 must be a constant "
                        "ptr type, got %s" % (s_ptrtype,))
    if not (isinstance(s_wref, SomePtr) and
            s_wref.ll_ptrtype == WeakRefPtr):
        raise Exception("weakref_deref() arg 2 must be a WeakRefPtr, "
                        "got %s" % (s_wref,))
    return SomePtr(s_ptrtype.const)


class _wref(lltype._container):
    _gckind = 'gc'
    _TYPE = WeakRef

    def __init__(self, ptarget):
        if ptarget is None:
            self._obref = lambda: None
        else:
            obj = lltype.normalizeptr(ptarget)._obj
            self._obref = weakref.ref(obj)

    def _dereference(self):
        obj = self._obref()
        # in combination with a GC like the SemiSpace, the 'obj' can be
        # still alive in the CPython sense but freed by the arena logic.
        if obj is None or obj._was_freed():
            return None
        else:
            return obj._as_ptr()

    def __repr__(self):
        return '<%s>' % (self,)

    def __str__(self):
        return 'wref -> %s' % (self._obref(),)

# a prebuilt pointer to a dead low-level weakref
dead_wref = _wref(None)._as_ptr()

# The rest is to support the GC transformers: they can use it to build
# an explicit weakref object with some structure and then "hide" the
# result by casting it to a WeakRefPtr, and "reveal" it again.  In other
# words, weakref_create and weakref_deref are operations that exist only
# before the GC transformation, whereas the two cast operations below
# exist only after.  They are implemented here only to allow GC
# transformers to be tested on top of the llinterpreter.
def cast_ptr_to_weakrefptr(ptr):
    if ptr:
        return _gctransformed_wref(ptr)._as_ptr()
    else:
        return lltype.nullptr(WeakRef)

@analyzer_for(cast_ptr_to_weakrefptr)
def llcast_ptr_to_weakrefptr(s_ptr):
    assert isinstance(s_ptr, SomePtr)
    return SomePtr(WeakRefPtr)


def cast_weakrefptr_to_ptr(PTRTYPE, pwref):
    assert lltype.typeOf(pwref) == WeakRefPtr
    if pwref:
        assert isinstance(pwref._obj, _gctransformed_wref)
        if PTRTYPE is not None:
            assert PTRTYPE == lltype.typeOf(pwref._obj._ptr)
        return pwref._obj._ptr
    else:
        return lltype.nullptr(PTRTYPE.TO)

@analyzer_for(cast_weakrefptr_to_ptr)
def llcast_weakrefptr_to_ptr(s_ptrtype, s_wref):
    if not (s_ptrtype.is_constant() and
            isinstance(s_ptrtype.const, lltype.Ptr)):
        raise Exception("cast_weakrefptr_to_ptr() arg 1 must be a constant "
                        "ptr type, got %s" % (s_ptrtype,))
    if not (isinstance(s_wref, SomePtr) and s_wref.ll_ptrtype == WeakRefPtr):
        raise Exception("cast_weakrefptr_to_ptr() arg 2 must be a WeakRefPtr, "
                        "got %s" % (s_wref,))
    return SomePtr(s_ptrtype.const)


class _gctransformed_wref(lltype._container):
    _gckind = 'gc'
    _TYPE = WeakRef
    def __init__(self, ptr):
        self._ptr = ptr
    def __repr__(self):
        return '<%s>' % (self,)
    def __str__(self):
        return 'gctransformed_wref(%s)' % (self._ptr,)
    def _normalizedcontainer(self, check=True):
        return self._ptr._getobj(check=check)._normalizedcontainer(check=check)
    def _was_freed(self):
        return self._ptr._was_freed()

# ____________________________________________________________

def raw_malloc(size, zero=False):
    if not isinstance(size, AddressOffset):
        raise NotImplementedError(size)
    return size._raw_malloc([], zero=zero)

@analyzer_for(raw_malloc)
def ann_raw_malloc(s_size, s_zero=None):
    assert isinstance(s_size, SomeInteger)  # XXX add noneg...?
    assert s_zero is None or isinstance(s_zero, SomeBool)
    return SomeAddress()


def raw_free(adr):
    # try to free the whole object if 'adr' is the address of the header
    from rpython.memory.gcheader import GCHeaderBuilder
    try:
        objectptr = GCHeaderBuilder.object_from_header(adr.ptr)
    except KeyError:
        pass
    else:
        raw_free(cast_ptr_to_adr(objectptr))
    assert isinstance(adr.ref()._obj, lltype._parentable)
    adr.ptr._as_obj()._free()

@analyzer_for(raw_free)
def ann_raw_free(s_addr):
    assert isinstance(s_addr, SomeAddress)

def raw_malloc_usage(size):
    if isinstance(size, AddressOffset):
        # ouah
        from rpython.memory.lltypelayout import convert_offset_to_int
        size = convert_offset_to_int(size)
    return size

@analyzer_for(raw_malloc_usage)
def ann_raw_malloc_usage(s_size):
    assert isinstance(s_size, SomeInteger)  # XXX add noneg...?
    return SomeInteger(nonneg=True)


def raw_memclear(adr, size):
    if not isinstance(size, AddressOffset):
        raise NotImplementedError(size)
    assert lltype.typeOf(adr) == Address
    zeroadr = size._raw_malloc([], zero=True)
    size.raw_memcopy(zeroadr, adr)

@analyzer_for(raw_memclear)
def ann_raw_memclear(s_addr, s_int):
    assert isinstance(s_addr, SomeAddress)
    assert isinstance(s_int, SomeInteger)


def raw_memcopy(source, dest, size):
    assert lltype.typeOf(source) == Address
    assert lltype.typeOf(dest) == Address
    size.raw_memcopy(source, dest)

@analyzer_for(raw_memcopy)
def ann_raw_memcopy(s_addr1, s_addr2, s_int):
    assert isinstance(s_addr1, SomeAddress)
    assert isinstance(s_addr2, SomeAddress)
    assert isinstance(s_int, SomeInteger)  # XXX add noneg...?


def raw_memmove(source, dest, size):
    # for now let's assume that raw_memmove is the same as raw_memcopy,
    # when run on top of fake addresses, but we _free the source object
    raw_memcopy(source, dest, size)
    source.ptr._as_obj()._free()

def raw_memmove_no_free(source, dest, size):
    # same as raw_memmove(), but we can't _free the source object when
    # running on top of fake addresses.  This is meant to be used when
    # source and dest are subarrays of the same array.
    raw_memcopy(source, dest, size)

class RawMemmoveEntry(ExtRegistryEntry):
    _about_ = (raw_memmove, raw_memmove_no_free)

    def compute_result_annotation(self, s_from, s_to, s_size):
        assert isinstance(s_from, SomeAddress)
        assert isinstance(s_to, SomeAddress)
        assert isinstance(s_size, SomeInteger)

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        v_list = hop.inputargs(Address, Address, lltype.Signed)
        return hop.genop('raw_memmove', v_list)

def cast_any_ptr(EXPECTED_TYPE, ptr):
    # this is a generalization of the various cast_xxx_ptr() functions.
    PTRTYPE = lltype.typeOf(ptr)
    if PTRTYPE == EXPECTED_TYPE:
        return ptr
    elif EXPECTED_TYPE == WeakRefPtr:
        return cast_ptr_to_weakrefptr(ptr)
    elif PTRTYPE == WeakRefPtr:
        ptr = cast_weakrefptr_to_ptr(None, ptr)
        return cast_any_ptr(EXPECTED_TYPE, ptr)
    elif (isinstance(EXPECTED_TYPE.TO, lltype.OpaqueType) or
            isinstance(PTRTYPE.TO, lltype.OpaqueType)):
        return lltype.cast_opaque_ptr(EXPECTED_TYPE, ptr)
    else:
        # regular case
        return lltype.cast_pointer(EXPECTED_TYPE, ptr)


def _reccopy_lazy(source, dest, steps):
    # copy recursively a structure or array onto another.
    # This does all the reading and then fills 'steps' with a list of callables.
    # Only when these callables are invoked does all the writing take place.
    T = lltype.typeOf(source).TO
    assert T == lltype.typeOf(dest).TO
    if isinstance(T, (lltype.Array, lltype.FixedSizeArray)):
        sourcelgt = source._obj.getlength()
        destlgt = dest._obj.getlength()
        lgt = min(sourcelgt, destlgt)
        ITEMTYPE = T.OF
        for i in range(lgt):
            if isinstance(ITEMTYPE, lltype.ContainerType):
                subsrc = source._obj.getitem(i)._as_ptr()
                subdst = dest._obj.getitem(i)._as_ptr()
                _reccopy_lazy(subsrc, subdst, steps)
            else:
                # this is a hack XXX de-hack this
                llvalue = source._obj.getitem(i, uninitialized_ok=2)
                if not isinstance(llvalue, lltype._uninitialized):
                    steps.append(lambda i=i, llvalue=llvalue:
                                 dest._obj.setitem(i, llvalue))
    elif isinstance(T, lltype.Struct):
        for name in T._names:
            FIELDTYPE = getattr(T, name)
            if isinstance(FIELDTYPE, lltype.ContainerType):
                subsrc = source._obj._getattr(name)._as_ptr()
                subdst = dest._obj._getattr(name)._as_ptr()
                _reccopy_lazy(subsrc, subdst, steps)
            else:
                # this is a hack XXX de-hack this
                llvalue = source._obj._getattr(name, uninitialized_ok=True)
                steps.append(lambda name=name, llvalue=llvalue:
                             setattr(dest._obj, name, llvalue))
    else:
        raise TypeError(T)

def _reccopy(source, dest):
    # copy recursively a structure or array onto another.
    steps = []
    _reccopy_lazy(source, dest, steps)
    for step in steps:
        step()
