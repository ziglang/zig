import sys

try:
    import ctypes
    import ctypes.util

    if not hasattr(ctypes, 'c_longdouble'):
        ctypes.c_longdouble = ctypes.c_double
except ImportError:
    ctypes = None

if sys.version_info >= (2, 6):
    load_library_kwargs = {'use_errno': True}
else:
    load_library_kwargs = {}

import os, platform as host_platform
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.extfunc import ExtRegistryEntry
from rpython.rlib.objectmodel import Symbolic, ComputedIntSymbolic
from rpython.tool.uid import fixid
from rpython.rlib.rarithmetic import r_singlefloat, r_longfloat, base_int, intmask
from rpython.rlib.rarithmetic import is_emulated_long, maxint
from rpython.annotator import model as annmodel
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rtyper.llannotation import SomePtr
from rpython.rtyper.llinterp import LLInterpreter, LLException
from rpython.rtyper.rclass import OBJECT, OBJECT_VTABLE
from rpython.rtyper import raddress
from rpython.translator.platform import platform
from array import array
try:
    from thread import _local as tlsobject
except ImportError:
    class tlsobject(object):
        pass
try:
    from threading import RLock
except ImportError:
    class RLock(object):
        def __enter__(self):
            pass
        def __exit__(self, *args):
            pass
rlock = RLock()

_POSIX = os.name == "posix"
_MS_WINDOWS = os.name == "nt"
_FREEBSD = sys.platform.startswith('freebsd')
_64BIT = "64bit" in host_platform.architecture()[0]


# ____________________________________________________________

far_regions = None

def allocate_ctypes(ctype):
    if far_regions:
        import random
        pieces = far_regions._ll2ctypes_pieces
        num = random.randrange(len(pieces)+1)
        if num == len(pieces):
            return ctype()
        i1, stop = pieces[num]
        i2 = i1 + ((ctypes.sizeof(ctype) or 1) + 7) & ~7
        if i2 > stop:
            raise MemoryError("out of memory in far_regions")
        pieces[num] = i2, stop
        p = lltype2ctypes(far_regions.getptr(i1))
        return ctypes.cast(p, ctypes.POINTER(ctype)).contents
    else:
        return ctype()

def do_allocation_in_far_regions():
    """On 32 bits: this reserves 1.25GB of address space, or 2.5GB on POSIX,
       which helps test this module for address values that are signed or
       unsigned.

       On 64-bits: reserves 10 times 2GB of address space.  This should help
       to find 32-vs-64-bit issues in the JIT.  It is likely that objects
       are further apart than 32 bits can represent; it is also possible
       to hit the corner case of being precisely e.g. 2GB - 8 bytes apart.

       Avoid this function if your OS reserves actual RAM from mmap() eagerly.
    """
    global far_regions
    if not far_regions:
        from rpython.rlib import rmmap
        if _64BIT:
            PIECE_STRIDE = 0x80000000
        else:
            if _POSIX:
                PIECE_STRIDE = 0x10000000
            else:
                PIECE_STRIDE = 0x08000000
        if _POSIX:
            PIECE_SIZE = 0x04000000
        else:
            PIECE_SIZE = PIECE_STRIDE
        PIECES = 10
        flags = (0,)
        if _POSIX:
            flags = (rmmap.MAP_PRIVATE|rmmap.MAP_ANONYMOUS|rmmap.MAP_NORESERVE,
                     rmmap.PROT_READ|rmmap.PROT_WRITE)
        elif _MS_WINDOWS:
            flags = (rmmap.MEM_RESERVE,)
            # XXX seems not to work
        else:
            assert False  # should always generate flags

        # Map and unmap something just to exercise unmap so that we (lazily)
        # build the ctypes callable.  Otherwise, when we reach unmap below
        # we may already have a giant map and be unable to fork, as for the
        # /sbin/ldconfig call inside ctypes.util.find_library().
        rmmap.mmap(-1, 4096, *flags).close()

        m = rmmap.mmap(-1, PIECES * PIECE_STRIDE, *flags)
        m.close = lambda : None    # leak instead of giving a spurious
                                   # error at CPython's shutdown
        m._ll2ctypes_pieces = []
        for i in range(PIECES):
            start = i * PIECE_STRIDE
            m._ll2ctypes_pieces.append((start, start + PIECE_SIZE))
            if _POSIX:
                m.unmap_range(start + PIECE_SIZE, PIECE_STRIDE - PIECE_SIZE)
        far_regions = m

# ____________________________________________________________

_ctypes_cache = {}
_eci_cache = {}

def _setup_ctypes_cache():
    from rpython.rtyper.lltypesystem import rffi

    if is_emulated_long:
        signed_as_ctype = ctypes.c_longlong
        unsigned_as_ctypes = ctypes.c_ulonglong
    else:
        signed_as_ctype = ctypes.c_long
        unsigned_as_ctypes = ctypes.c_ulong

    _ctypes_cache.update({
        lltype.Signed:   signed_as_ctype,
        lltype.Unsigned: unsigned_as_ctypes,
        lltype.Char:     ctypes.c_ubyte,
        rffi.DOUBLE:     ctypes.c_double,
        rffi.FLOAT:      ctypes.c_float,
        rffi.LONGDOUBLE: ctypes.c_longdouble,
        rffi.SIGNEDCHAR: ctypes.c_byte,
        rffi.UCHAR:      ctypes.c_ubyte,
        rffi.SHORT:      ctypes.c_short,
        rffi.USHORT:     ctypes.c_ushort,
        rffi.INT:        ctypes.c_int,
        rffi.INT_real:   ctypes.c_int,
        rffi.UINT:       ctypes.c_uint,
        rffi.LONG:       ctypes.c_long,
        rffi.ULONG:      ctypes.c_ulong,
        rffi.LONGLONG:   ctypes.c_longlong,
        rffi.ULONGLONG:  ctypes.c_ulonglong,
        rffi.SIZE_T:     ctypes.c_size_t,
        lltype.Bool:     getattr(ctypes, "c_bool", ctypes.c_byte),
        llmemory.Address:  ctypes.c_void_p,
        llmemory.GCREF:    ctypes.c_void_p,
        llmemory.WeakRef:  ctypes.c_void_p, # XXX
        })

    if '__int128_t' in rffi.TYPES:
        class c_int128(ctypes.Array):   # based on 2 ulongs
            _type_ = ctypes.c_uint64
            _length_ = 2
            @property
            def value(self):
                res = self[0] | (self[1] << 64)
                if res >= (1 << 127):
                    res -= 1 << 128
                return res
        class c_uint128(ctypes.Array):   # based on 2 ulongs
            _type_ = ctypes.c_uint64
            _length_ = 2
            @property
            def value(self):
                res = self[0] | (self[1] << 64)
                return res

        _ctypes_cache[rffi.__INT128_T] = c_int128
        _ctypes_cache[rffi.__UINT128_T] = c_uint128

    # for unicode strings, do not use ctypes.c_wchar because ctypes
    # automatically converts arrays into unicode strings.
    # Pick the unsigned int that has the same size.
    if ctypes.sizeof(ctypes.c_wchar) == ctypes.sizeof(ctypes.c_uint16):
        _ctypes_cache[lltype.UniChar] = ctypes.c_uint16
    else:
        _ctypes_cache[lltype.UniChar] = ctypes.c_uint32

def build_ctypes_struct(S, delayed_builders, max_n=None):
    def builder():
        # called a bit later to fill in _fields_
        # (to handle recursive structure pointers)
        fields = []
        for fieldname in S._names:
            FIELDTYPE = S._flds[fieldname]
            if max_n is not None and fieldname == S._arrayfld:
                cls = get_ctypes_array_of_size(FIELDTYPE, max_n)
            else:
                if isinstance(FIELDTYPE, lltype.Ptr):
                    cls = get_ctypes_type(FIELDTYPE, delayed_builders)
                else:
                    cls = get_ctypes_type(FIELDTYPE, delayed_builders,
                                          cannot_delay=True)
            fields.append((fieldname, cls))
        CStruct._fields_ = fields

    if S._hints.get('union', False):
        base = ctypes.Union
    else:
        base = ctypes.Structure

    class CStruct(base):
        # no _fields_: filled later by builder()

        def _malloc(cls, n=None):
            if S._arrayfld is None:
                if n is not None:
                    raise TypeError("%r is not variable-sized" % (S,))
                storage = allocate_ctypes(cls)
                return storage
            else:
                if n is None:
                    raise TypeError("%r is variable-sized" % (S,))
                biggercls = build_ctypes_struct(S, None, n)
                bigstruct = allocate_ctypes(biggercls)
                array = getattr(bigstruct, S._arrayfld)
                if hasattr(array, 'length'):
                    array.length = n
                return bigstruct
        _malloc = classmethod(_malloc)

    CStruct.__name__ = 'ctypes_%s' % (S,)
    if max_n is not None:
        CStruct._normalized_ctype = get_ctypes_type(S)
        builder()    # no need to be lazy here
    else:
        delayed_builders.append((S, builder))
    return CStruct

def build_ctypes_array(A, delayed_builders, max_n=0):
    assert max_n >= 0
    ITEM = A.OF
    ctypes_item = get_ctypes_type(ITEM, delayed_builders)
    ctypes_item_ptr = ctypes.POINTER(ctypes_item)

    class CArray(ctypes.Structure):
        if is_emulated_long:
            lentype = ctypes.c_longlong
        else:
            lentype = ctypes.c_long

        if not A._hints.get('nolength'):
            _fields_ = [('length', lentype),
                        ('items',
                           (max_n + A._hints.get('extra_item_after_alloc', 0))
                           * ctypes_item)]
        else:
            _fields_ = [('items',  max_n * ctypes_item)]

        @classmethod
        def _malloc(cls, n=None):
            if not isinstance(n, int):
                raise TypeError("array length must be an int")
            biggercls = get_ctypes_array_of_size(A, n)
            bigarray = allocate_ctypes(biggercls)
            if hasattr(bigarray, 'length'):
                bigarray.length = n
            return bigarray

        def _indexable(self, index):
            p = ctypes.cast(self.items, ctypes_item_ptr)
            return p

        def _getitem(self, index, boundscheck=True):
            if boundscheck:
                items = self.items
            else:
                items = self._indexable(index)
            cobj = items[index]
            if isinstance(ITEM, lltype.ContainerType):
                return ctypes2lltype(lltype.Ptr(ITEM), ctypes.pointer(cobj))
            else:
                return ctypes2lltype(ITEM, cobj)

        def _setitem(self, index, value, boundscheck=True):
            if boundscheck:
                items = self.items
            else:
                items = self._indexable(index)
            cobj = lltype2ctypes(value)
            items[index] = cobj

    CArray.__name__ = 'ctypes_%s*%d' % (A, max_n)
    if max_n > 0:
        CArray._normalized_ctype = get_ctypes_type(A)
    return CArray

def get_ctypes_array_of_size(FIELDTYPE, max_n):
    if max_n > 0:
        # no need to cache the results in this case, because the exact
        # type is never seen - the array instances are cast to the
        # array's _normalized_ctype, which is always the same.
        return build_ctypes_array(FIELDTYPE, None, max_n)
    else:
        return get_ctypes_type(FIELDTYPE)

def get_ctypes_type(T, delayed_builders=None, cannot_delay=False):
    # Check delayed builders
    if cannot_delay and delayed_builders:
        for T2, builder in delayed_builders:
            if T2 is T:
                builder()
                delayed_builders.remove((T2, builder))
                return _ctypes_cache[T]

    try:
        return _ctypes_cache[T]
    except KeyError:
        toplevel = cannot_delay or delayed_builders is None
        if toplevel:
            delayed_builders = []
        cls = build_new_ctypes_type(T, delayed_builders)
        if T not in _ctypes_cache:
            _ctypes_cache[T] = cls
        else:
            # check for buggy recursive structure logic
            assert _ctypes_cache[T] is cls
        if toplevel:
            complete_builders(delayed_builders)
        return cls

def build_new_ctypes_type(T, delayed_builders):
    if isinstance(T, lltype.Typedef):
        T = T.OF

    if isinstance(T, lltype.Ptr):
        if isinstance(T.TO, lltype.FuncType):
            functype = ctypes.CFUNCTYPE
            if sys.platform == 'win32' and not _64BIT:
                from rpython.rlib.clibffi import FFI_STDCALL, FFI_DEFAULT_ABI
                if getattr(T.TO, 'ABI', FFI_DEFAULT_ABI) == FFI_STDCALL:
                    # for win32 system call
                    functype = ctypes.WINFUNCTYPE
            argtypes = [get_ctypes_type(ARG) for ARG in T.TO.ARGS
                        if ARG is not lltype.Void]
            if T.TO.RESULT is lltype.Void:
                restype = None
            else:
                restype = get_ctypes_type(T.TO.RESULT)
            try:
                kwds = {'use_errno': True}
                return functype(restype, *argtypes, **kwds)
            except TypeError:
                # unexpected 'use_errno' argument, old ctypes version
                return functype(restype, *argtypes)
        elif isinstance(T.TO, lltype.OpaqueType):
            return ctypes.c_void_p
        else:
            return ctypes.POINTER(get_ctypes_type(T.TO, delayed_builders))
    elif T is lltype.Void:
        return ctypes.c_long # opaque pointer
    elif isinstance(T, lltype.Struct):
        return build_ctypes_struct(T, delayed_builders)
    elif isinstance(T, lltype.Array):
        return build_ctypes_array(T, delayed_builders)
    elif isinstance(T, lltype.OpaqueType):
        if T is lltype.RuntimeTypeInfo:
            return ctypes.c_char * 2
        if T._hints.get('external', None) != 'C':
            raise TypeError("%s is not external" % T)
        return ctypes.c_char * T._hints['getsize']()
    else:
        _setup_ctypes_cache()
        if T in _ctypes_cache:
            return _ctypes_cache[T]
        raise NotImplementedError(T)

def complete_builders(delayed_builders):
    while delayed_builders:
        T, builder = delayed_builders[0]
        builder()
        delayed_builders.pop(0)

def convert_struct(container, cstruct=None, delayed_converters=None):
    STRUCT = container._TYPE
    if cstruct is None:
        # if 'container' is an inlined substructure, convert the whole
        # bigger structure at once
        parent, parentindex = lltype.parentlink(container)
        if parent is not None:
            if isinstance(parent, lltype._struct):
                convert_struct(parent)
            elif isinstance(parent, lltype._array):
                convert_array(parent)
            else:
                raise AssertionError(type(parent))
            return
        # regular case: allocate a new ctypes Structure of the proper type
        cls = get_ctypes_type(STRUCT)
        if STRUCT._arrayfld is not None:
            n = getattr(container, STRUCT._arrayfld).getlength()
        else:
            n = None
        cstruct = cls._malloc(n)

    if isinstance(container, lltype._fixedsizearray):
        cls_mixin = _fixedsizedarray_mixin
    else:
        cls_mixin = _struct_mixin
    add_storage(container, cls_mixin, ctypes.pointer(cstruct))

    if delayed_converters is None:
        delayed_converters_was_None = True
        delayed_converters = []
    else:
        delayed_converters_was_None = False
    for field_name in STRUCT._names:
        FIELDTYPE = getattr(STRUCT, field_name)
        field_value = getattr(container, field_name)
        if not isinstance(FIELDTYPE, lltype.ContainerType):
            # regular field
            if FIELDTYPE != lltype.Void:
                def convert(field_name=field_name, field_value=field_value):
                    setattr(cstruct, field_name, lltype2ctypes(field_value))
                if isinstance(FIELDTYPE, lltype.Ptr):
                    delayed_converters.append(convert)
                else:
                    convert()
        else:
            # inlined substructure/subarray
            if isinstance(FIELDTYPE, lltype.Struct):
                csubstruct = getattr(cstruct, field_name)
                convert_struct(field_value, csubstruct,
                               delayed_converters=delayed_converters)
            elif field_name == STRUCT._arrayfld:    # inlined var-sized part
                csubarray = getattr(cstruct, field_name)
                convert_array(field_value, csubarray)
            else:
                raise NotImplementedError('inlined field', FIELDTYPE)
    if delayed_converters_was_None:
        for converter in delayed_converters:
            converter()

    remove_regular_struct_content(container)

def remove_regular_struct_content(container):
    STRUCT = container._TYPE
    if isinstance(STRUCT, lltype.FixedSizeArray):
        del container._items
        return
    for field_name in STRUCT._names:
        FIELDTYPE = getattr(STRUCT, field_name)
        if not isinstance(FIELDTYPE, lltype.ContainerType):
            delattr(container, field_name)

def convert_array(container, carray=None):
    ARRAY = container._TYPE
    if carray is None:
        # if 'container' is an inlined substructure, convert the whole
        # bigger structure at once
        parent, parentindex = lltype.parentlink(container)
        if parent is not None:
            if not isinstance(parent, _parentable_mixin):
                convert_struct(parent)
            return
        # regular case: allocate a new ctypes array of the proper type
        cls = get_ctypes_type(ARRAY)
        carray = cls._malloc(container.getlength())
    add_storage(container, _array_mixin, ctypes.pointer(carray))
    if not isinstance(ARRAY.OF, lltype.ContainerType):
        # fish that we have enough space
        ctypes_array = ctypes.cast(carray.items,
                                   ctypes.POINTER(carray.items._type_))
        for i in range(container.getlength()):
            item_value = container.items[i]    # fish fish
            ctypes_array[i] = lltype2ctypes(item_value)
        remove_regular_array_content(container)
    else:
        assert isinstance(ARRAY.OF, lltype.Struct)
        for i in range(container.getlength()):
            item_ptr = container.items[i]    # fish fish
            convert_struct(item_ptr, carray.items[i])

def remove_regular_array_content(container):
    for i in range(container.getlength()):
        container.items[i] = None

def struct_use_ctypes_storage(container, ctypes_storage):
    STRUCT = container._TYPE
    assert isinstance(STRUCT, lltype.Struct)
    if isinstance(container, lltype._fixedsizearray):
        cls_mixin = _fixedsizedarray_mixin
    else:
        cls_mixin = _struct_mixin
    add_storage(container, cls_mixin, ctypes_storage)
    remove_regular_struct_content(container)
    for field_name in STRUCT._names:
        FIELDTYPE = getattr(STRUCT, field_name)
        if isinstance(FIELDTYPE, lltype.ContainerType):
            if isinstance(FIELDTYPE, lltype.Struct):
                struct_container = getattr(container, field_name)
                struct_storage = ctypes.pointer(
                    getattr(ctypes_storage.contents, field_name))
                struct_use_ctypes_storage(struct_container, struct_storage)
                struct_container._setparentstructure(container, field_name)
            elif isinstance(FIELDTYPE, lltype.Array):
                if FIELDTYPE._hints.get('nolength', False):
                    arraycontainer = _array_of_unknown_length(FIELDTYPE)
                else:
                    arraycontainer = _array_of_known_length(FIELDTYPE)
                arraycontainer._storage = ctypes.pointer(
                    getattr(ctypes_storage.contents, field_name))
                arraycontainer._setparentstructure(container, field_name)
                object.__setattr__(container, field_name, arraycontainer)
            else:
                raise NotImplementedError(FIELDTYPE)

# ____________________________________________________________
# Ctypes-aware subclasses of the _parentable classes

ALLOCATED = {}     # mapping {address: _container}
DEBUG_ALLOCATED = False

def get_common_subclass(cls1, cls2, cache={}):
    """Return a unique subclass with (cls1, cls2) as bases."""
    try:
        return cache[cls1, cls2]
    except KeyError:
        subcls = type('_ctypes_%s' % (cls1.__name__,),
                      (cls1, cls2),
                      {'__slots__': ()})
        cache[cls1, cls2] = subcls
        return subcls

def add_storage(instance, mixin_cls, ctypes_storage):
    """Put ctypes_storage on the instance, changing its __class__ so that it
    sees the methods of the given mixin class."""
    # _storage is a ctypes pointer to a structure
    # except for Opaque objects which use a c_void_p.
    assert not isinstance(instance, _parentable_mixin)  # not yet
    subcls = get_common_subclass(mixin_cls, instance.__class__)
    instance.__class__ = subcls
    instance._storage = ctypes_storage
    assert ctypes_storage   # null pointer?

class NotCtypesAllocatedStructure(ValueError):
    pass

class _parentable_mixin(object):
    """Mixin added to _parentable containers when they become ctypes-based.
    (This is done by changing the __class__ of the instance to reference
    a subclass of both its original class and of this mixin class.)
    """
    __slots__ = ()

    def _ctypes_storage_was_allocated(self):
        addr = ctypes.cast(self._storage, ctypes.c_void_p).value
        if addr in ALLOCATED:
            raise Exception("internal ll2ctypes error - "
                            "double conversion from lltype to ctypes?")
        # XXX don't store here immortal structures
        if DEBUG_ALLOCATED:
            print >> sys.stderr, "LL2CTYPES:", hex(addr)
        ALLOCATED[addr] = self

    def _addressof_storage(self):
        "Returns the storage address as an int"
        if self._storage is None or self._storage is True:
            raise NotCtypesAllocatedStructure("Not a ctypes allocated structure")
        return intmask(ctypes.cast(self._storage, ctypes.c_void_p).value)

    def _free(self):
        self._check()   # no double-frees
        # allow the ctypes object to go away now
        addr = ctypes.cast(self._storage, ctypes.c_void_p).value
        if DEBUG_ALLOCATED:
            print >> sys.stderr, "LL2C FREE:", hex(addr)
        try:
            del ALLOCATED[addr]
        except KeyError:
            raise Exception("invalid free() - data already freed or "
                            "not allocated from RPython at all")
        self._storage = None

    def _getid(self):
        return self._addressof_storage()

    def __eq__(self, other):
        if isinstance(other, _llgcopaque):
            addressof_other = other.intval
        else:
            if not isinstance(other, lltype._parentable):
                return False
            if self._storage is None or other._storage is None:
                raise RuntimeError("pointer comparison with a freed structure")
            if other._storage is True:
                return False    # the other container is not ctypes-based
            addressof_other = other._addressof_storage()
        # both containers are ctypes-based, compare the addresses
        return self._addressof_storage() == addressof_other

    def __ne__(self, other):
        return not (self == other)

    def __hash__(self):
        if self._storage is not None:
            return self._addressof_storage()
        else:
            return object.__hash__(self)

    def __repr__(self):
        if '__str__' in self._TYPE._adtmeths:
            r = self._TYPE._adtmeths['__str__'](self)
        else:
            r = 'C object %s' % (self._TYPE,)
        if self._storage is None:
            return '<freed %s>' % (r,)
        else:
            return '<%s at 0x%x>' % (r, fixid(self._addressof_storage()))

    def __str__(self):
        return repr(self)

    def _setparentstructure(self, parent, parentindex):
        super(_parentable_mixin, self)._setparentstructure(parent, parentindex)
        self._keepparent = parent   # always keep a strong ref

class _struct_mixin(_parentable_mixin):
    """Mixin added to _struct containers when they become ctypes-based."""
    __slots__ = ()

    def __getattr__(self, field_name):
        T = getattr(self._TYPE, field_name)
        cobj = getattr(self._storage.contents, field_name)
        return ctypes2lltype(T, cobj)

    def __setattr__(self, field_name, value):
        if field_name.startswith('_'):
            object.__setattr__(self, field_name, value)  # '_xxx' attributes
        else:
            cobj = lltype2ctypes(value)
            setattr(self._storage.contents, field_name, cobj)

class _fixedsizedarray_mixin(_parentable_mixin):
    """Mixin added to _fixedsizearray containers when they become ctypes-based."""
    __slots__ = ()

    def __getattr__(self, field_name):
        if hasattr(self, '_items'):
            obj = lltype._fixedsizearray.__getattr__.im_func(self, field_name)
            return obj
        else:
            cobj = getattr(self._storage.contents, field_name)
            T = getattr(self._TYPE, field_name)
            return ctypes2lltype(T, cobj)

    def __setattr__(self, field_name, value):
        if field_name.startswith('_'):
            object.__setattr__(self, field_name, value)  # '_xxx' attributes
        else:
            cobj = lltype2ctypes(value)
            if hasattr(self, '_items'):
                lltype._fixedsizearray.__setattr__.im_func(self, field_name, cobj)
            else:
                setattr(self._storage.contents, field_name, cobj)


    def getitem(self, index, uninitialized_ok=False):
        if hasattr(self, '_items'):
            obj = lltype._fixedsizearray.getitem.im_func(self, 
                                     index, uninitialized_ok=uninitialized_ok)
            return obj
        else:
            return getattr(self, 'item%d' % index)

    def setitem(self, index, value):
        cobj = lltype2ctypes(value)
        if hasattr(self, '_items'):
            lltype._fixedsizearray.setitem.im_func(self, index, value)
        else:
            setattr(self, 'item%d' % index, cobj)

class _array_mixin(_parentable_mixin):
    """Mixin added to _array containers when they become ctypes-based."""
    __slots__ = ()

    def getitem(self, index, uninitialized_ok=False):
        return self._storage.contents._getitem(index)

    def setitem(self, index, value):
        self._storage.contents._setitem(index, value)

class _array_of_unknown_length(_parentable_mixin, lltype._parentable):
    _kind = "array"
    __slots__ = ()

    def getbounds(self):
        # we have no clue, so we allow whatever index
        return 0, maxint

    def shrinklength(self, newlength):
        raise NotImplementedError

    def getitem(self, index, uninitialized_ok=False):
        res = self._storage.contents._getitem(index, boundscheck=False)
        if isinstance(self._TYPE.OF, lltype.ContainerType):
            res._obj._setparentstructure(self, index)
        return res

    def setitem(self, index, value):
        self._storage.contents._setitem(index, value, boundscheck=False)

    def getitems(self):
        if self._TYPE.OF != lltype.Char:
            raise Exception("cannot get all items of an unknown-length "
                            "array of %r" % self._TYPE.OF)
        _items = []
        i = 0
        while 1:
            nextitem = self.getitem(i)
            if nextitem == '\x00':
                _items.append('\x00')
                return _items
            _items.append(nextitem)
            i += 1

    items = property(getitems)

class _array_of_known_length(_array_of_unknown_length):
    __slots__ = ()

    def getlength(self):
        return self._storage.contents.length

    def getbounds(self):
        return 0, self.getlength()

# ____________________________________________________________

def _find_parent(llobj):
    parent, parentindex = lltype.parentlink(llobj)
    if parent is None:
        return llobj, 0
    next_p, next_i = _find_parent(parent)
    if isinstance(parentindex, int):
        c_tp = get_ctypes_type(lltype.typeOf(parent))
        sizeof = ctypes.sizeof(get_ctypes_type(lltype.typeOf(parent).OF))
        ofs = c_tp.items.offset + parentindex * sizeof
        return next_p, next_i + ofs
    else:
        c_tp = get_ctypes_type(lltype.typeOf(parent))
        ofs = getattr(c_tp, parentindex).offset
        return next_p, next_i + ofs

# ____________________________________________________________

# XXX THIS IS A HACK XXX
# ctypes does not keep callback arguments alive. So we do. Forever
# we need to think deeper how to approach this problem
# additionally, this adds mess to __del__ "semantics"
_all_callbacks = {}
_all_callbacks_results = []
_int2obj = {}
_callback_exc_info = None
_opaque_objs = [None]
_opaque_objs_seen = {}

def get_rtyper():
    llinterp = LLInterpreter.current_interpreter
    if llinterp is not None:
        return llinterp.typer
    else:
        return None

def lltype2ctypes(llobj, normalize=True):
    """Convert the lltype object 'llobj' to its ctypes equivalent.
    'normalize' should only be False in tests, where we want to
    inspect the resulting ctypes object manually.
    """
    with rlock:
        if isinstance(llobj, lltype._uninitialized):
            return uninitialized2ctypes(llobj.TYPE)
        if isinstance(llobj, llmemory.AddressAsInt):
            cobj = ctypes.cast(lltype2ctypes(llobj.adr), ctypes.c_void_p)
            res = intmask(cobj.value)
            _int2obj[res] = llobj.adr.ptr._obj
            return res
        if isinstance(llobj, llmemory.fakeaddress):
            llobj = llobj.ptr or 0

        T = lltype.typeOf(llobj)

        if isinstance(T, lltype.Ptr):
            if not llobj:   # NULL pointer
                if T == llmemory.GCREF:
                    return ctypes.c_void_p(0)
                return get_ctypes_type(T)()

            if T == llmemory.GCREF:
                if isinstance(llobj._obj, _llgcopaque):
                    return ctypes.c_void_p(llobj._obj.intval)
                if isinstance(llobj._obj, int):    # tagged pointer
                    return ctypes.c_void_p(llobj._obj)
                container = llobj._obj.container
                T = lltype.Ptr(lltype.typeOf(container))
                # otherwise it came from integer and we want a c_void_p with
                # the same value
                if getattr(container, 'llopaque', None):
                    try:
                        no = _opaque_objs_seen[container]
                    except KeyError:
                        no = len(_opaque_objs)
                        _opaque_objs.append(container)
                        _opaque_objs_seen[container] = no
                    return no * 2 + 1
            else:
                container = llobj._obj
            if isinstance(T.TO, lltype.FuncType):
                if hasattr(llobj._obj0, '_real_integer_addr'):
                    ctypes_func_type = get_ctypes_type(T)
                    return ctypes.cast(llobj._obj0._real_integer_addr(),
                                       ctypes_func_type)
                # XXX a temporary workaround for comparison of lltype.FuncType
                key = llobj._obj.__dict__.copy()
                key['_TYPE'] = repr(key['_TYPE'])
                items = key.items()
                items.sort()
                key = tuple(items)
                if key in _all_callbacks:
                    return _all_callbacks[key]
                v1voidlist = [(i, getattr(container, '_void' + str(i), None))
                                 for i in range(len(T.TO.ARGS))
                                     if T.TO.ARGS[i] is lltype.Void]
                def callback_internal(*cargs):
                    cargs = list(cargs)
                    for v1 in v1voidlist:
                        cargs.insert(v1[0], v1[1])
                    assert len(cargs) == len(T.TO.ARGS)
                    llargs = []
                    for ARG, carg in zip(T.TO.ARGS, cargs):
                        if ARG is lltype.Void:
                            llargs.append(carg)
                        else:
                            llargs.append(ctypes2lltype(ARG, carg))
                    if hasattr(container, 'graph'):
                        if LLInterpreter.current_interpreter is None:
                            raise AssertionError
                        llinterp = LLInterpreter.current_interpreter
                        try:
                            llres = llinterp.eval_graph(container.graph, llargs)
                        except LLException as lle:
                            llinterp._store_exception(lle)
                            return 0
                        #except:
                        #    import pdb
                        #    pdb.set_trace()
                    else:
                        try:
                            llres = container._callable(*llargs)
                        except LLException as lle:
                            llinterp = LLInterpreter.current_interpreter
                            llinterp._store_exception(lle)
                            return 0
                    return ctypes_return_value(llres)

                def ctypes_return_value(llres):
                    assert lltype.typeOf(llres) == T.TO.RESULT
                    if T.TO.RESULT is lltype.Void:
                        return None
                    res = lltype2ctypes(llres)
                    if isinstance(T.TO.RESULT, lltype.Ptr):
                        _all_callbacks_results.append(res)
                        res = ctypes.cast(res, ctypes.c_void_p).value
                        if res is None:
                            return 0
                    if T.TO.RESULT == lltype.SingleFloat:
                        res = res.value     # baaaah, cannot return a c_float()
                    return res

                def callback(*cargs):
                    try:
                        return callback_internal(*cargs)
                    except:
                        import sys
                        #if option.usepdb:
                        #    import pdb; pdb.post_mortem(sys.exc_traceback)
                        global _callback_exc_info
                        _callback_exc_info = sys.exc_info()
                        _callable = getattr(container, '_callable', None)
                        if hasattr(_callable, '_llhelper_error_value_'):
                            # see rlib.objectmodel.llhelper_error_value
                            llres = _callable._llhelper_error_value_
                            assert lltype.typeOf(llres) == T.TO.RESULT
                            return ctypes_return_value(llres)
                        else:
                            raise

                if isinstance(T.TO.RESULT, lltype.Ptr):
                    TMod = lltype.Ptr(lltype.FuncType(T.TO.ARGS,
                                                      lltype.Signed))
                    ctypes_func_type = get_ctypes_type(TMod)
                    res = ctypes_func_type(callback)
                    ctypes_func_type = get_ctypes_type(T)
                    res = ctypes.cast(res, ctypes_func_type)
                else:
                    ctypes_func_type = get_ctypes_type(T)
                    res = ctypes_func_type(callback)
                _all_callbacks[key] = res
                key2 = intmask(ctypes.cast(res, ctypes.c_void_p).value)
                _int2obj[key2] = container
                return res

            index = 0
            if isinstance(container, lltype._subarray):
                topmost, index = _find_parent(container)
                container = topmost
                T = lltype.Ptr(lltype.typeOf(container))

            if container._storage is None:
                raise RuntimeError("attempting to pass a freed structure to C")
            if container._storage is True:
                # container has regular lltype storage, convert it to ctypes
                if isinstance(T.TO, lltype.Struct):
                    convert_struct(container)
                elif isinstance(T.TO, lltype.Array):
                    convert_array(container)
                elif isinstance(T.TO, lltype.OpaqueType):
                    if T.TO != lltype.RuntimeTypeInfo:
                        cbuf = ctypes.create_string_buffer(T.TO._hints['getsize']())
                    else:
                        cbuf = ctypes.create_string_buffer("\x00")
                    cbuf = ctypes.cast(cbuf, ctypes.c_void_p)
                    add_storage(container, _parentable_mixin, cbuf)
                else:
                    raise NotImplementedError(T)
                container._ctypes_storage_was_allocated()

            if isinstance(T.TO, lltype.OpaqueType):
                return container._storage.value

            storage = container._storage
            p = storage
            if index:
                p = ctypes.cast(p, ctypes.c_void_p)
                p = ctypes.c_void_p(p.value + index)
                c_tp = get_ctypes_type(T.TO)
                storage.contents._normalized_ctype = c_tp
            if normalize and hasattr(storage.contents, '_normalized_ctype'):
                normalized_ctype = storage.contents._normalized_ctype
                p = ctypes.cast(p, ctypes.POINTER(normalized_ctype))
            if lltype.typeOf(llobj) == llmemory.GCREF:
                p = ctypes.cast(p, ctypes.c_void_p)
            return p

        if isinstance(llobj, Symbolic):
            if isinstance(llobj, llmemory.ItemOffset):
                llobj = ctypes.sizeof(get_ctypes_type(llobj.TYPE)) * llobj.repeat
            elif isinstance(llobj, ComputedIntSymbolic):
                llobj = llobj.compute_fn()
            elif isinstance(llobj, llmemory.CompositeOffset):
                llobj = sum([lltype2ctypes(c) for c in llobj.offsets])
            elif isinstance(llobj, llmemory.FieldOffset):
                CSTRUCT = get_ctypes_type(llobj.TYPE)
                llobj = getattr(CSTRUCT, llobj.fldname).offset
            elif isinstance(llobj, llmemory.ArrayItemsOffset):
                CARRAY = get_ctypes_type(llobj.TYPE)
                llobj = CARRAY.items.offset
            else:
                raise NotImplementedError(llobj)  # don't know about symbolic value

        if T is lltype.Char or T is lltype.UniChar:
            return ord(llobj)

        if T is lltype.SingleFloat:
            return ctypes.c_float(float(llobj))

        return llobj

def ctypes2lltype(T, cobj, force_real_ctypes_function=False):
    """Convert the ctypes object 'cobj' to its lltype equivalent.
    'T' is the expected lltype type.
    """
    with rlock:
        if T is lltype.Void:
            return None
        if isinstance(T, lltype.Typedef):
            T = T.OF
        if isinstance(T, lltype.Ptr):
            ptrval = ctypes.cast(cobj, ctypes.c_void_p).value
            if not cobj or not ptrval:   # NULL pointer
                # CFunctionType.__nonzero__ is broken before Python 2.6
                return lltype.nullptr(T.TO)
            if isinstance(T.TO, lltype.Struct):
                if T.TO._gckind == 'gc' and ptrval & 1: # a tagged pointer
                    gcref = _opaque_objs[ptrval // 2].hide()
                    return lltype.cast_opaque_ptr(T, gcref)
                REAL_TYPE = T.TO
                if T.TO._arrayfld is not None:
                    carray = getattr(cobj.contents, T.TO._arrayfld)
                    length = getattr(carray, 'length', 9999)   # XXX
                    container = lltype._struct(T.TO, length)
                else:
                    # special treatment of 'OBJECT' subclasses
                    if get_rtyper() and lltype._castdepth(REAL_TYPE, OBJECT) >= 0:
                        # figure out the real type of the object
                        containerheader = lltype._struct(OBJECT)
                        cobjheader = ctypes.cast(cobj,
                                           get_ctypes_type(lltype.Ptr(OBJECT)))
                        struct_use_ctypes_storage(containerheader,
                                                  cobjheader)
                        REAL_TYPE = get_rtyper().get_type_for_typeptr(
                            containerheader.typeptr)
                        REAL_T = lltype.Ptr(REAL_TYPE)
                        cobj = ctypes.cast(cobj, get_ctypes_type(REAL_T))
                    container = lltype._struct(REAL_TYPE)
                # obscuuuuuuuuure: 'cobj' is a ctypes pointer, which is
                # mutable; and so if we save away the 'cobj' object
                # itself, it might suddenly later be unexpectedly
                # modified!  Make a copy.
                cobj = ctypes.cast(cobj, type(cobj))
                struct_use_ctypes_storage(container, cobj)
                if REAL_TYPE != T.TO:
                    p = container._as_ptr()
                    container = lltype.cast_pointer(T, p)._as_obj()
                # special treatment of 'OBJECT_VTABLE' subclasses
                if get_rtyper() and lltype._castdepth(REAL_TYPE,
                                                      OBJECT_VTABLE) >= 0:
                    # figure out the real object that this vtable points to,
                    # and just return that
                    p = get_rtyper().get_real_typeptr_for_typeptr(
                        container._as_ptr())
                    container = lltype.cast_pointer(T, p)._as_obj()
            elif isinstance(T.TO, lltype.Array):
                if T.TO._hints.get('nolength', False):
                    container = _array_of_unknown_length(T.TO)
                    container._storage = type(cobj)(cobj.contents)
                else:
                    container = _array_of_known_length(T.TO)
                    container._storage = type(cobj)(cobj.contents)
            elif isinstance(T.TO, lltype.FuncType):
                # cobj is a CFunctionType object.  We naively think
                # that it should be a function pointer.  No no no.  If
                # it was read out of an array, say, then it is a *pointer*
                # to a function pointer.  In other words, the read doesn't
                # read anything, it just takes the address of the function
                # pointer inside the array.  If later the array is modified
                # or goes out of scope, then we crash.  CTypes is fun.
                # It works if we cast it now to an int and back.
                cobjkey = intmask(ctypes.cast(cobj, ctypes.c_void_p).value)
                if cobjkey in _int2obj and not force_real_ctypes_function:
                    container = _int2obj[cobjkey]
                else:
                    name = getattr(cobj, '__name__', '?')
                    cobj = ctypes.cast(cobjkey, type(cobj))
                    _callable = get_ctypes_trampoline(T.TO, cobj)
                    return lltype.functionptr(T.TO, name,
                                              _callable=_callable,
                                          _real_integer_addr=lambda: cobjkey)
            elif isinstance(T.TO, lltype.OpaqueType):
                if T == llmemory.GCREF:
                    container = _llgcopaque(cobj)
                else:
                    container = lltype._opaque(T.TO)
                    cbuf = ctypes.cast(cobj, ctypes.c_void_p)
                    add_storage(container, _parentable_mixin, cbuf)
            else:
                raise NotImplementedError(T)
            llobj = lltype._ptr(T, container, solid=True)
        elif T is llmemory.Address:
            if cobj is None:
                llobj = llmemory.NULL
            else:
                llobj = _lladdress(cobj)
        elif T is lltype.Char:
            llobj = chr(cobj)
        elif T is lltype.UniChar:
            try:
                llobj = unichr(cobj)
            except (ValueError, OverflowError):
                for tc in 'HIL':
                    if array(tc).itemsize == array('u').itemsize:
                        import struct
                        cobj &= 256 ** struct.calcsize(tc) - 1
                        llobj = array('u', array(tc, (cobj,)).tostring())[0]
                        break
                else:
                    raise
        elif T is lltype.Signed:
            llobj = cobj
        elif T is lltype.Bool:
            assert cobj == True or cobj == False    # 0 and 1 work too
            llobj = bool(cobj)
        elif T is lltype.SingleFloat:
            if isinstance(cobj, ctypes.c_float):
                cobj = cobj.value
            llobj = r_singlefloat(cobj)
        elif T is lltype.LongFloat:
            if isinstance(cobj, ctypes.c_longdouble):
                cobj = cobj.value
            llobj = r_longfloat(cobj)
        elif T is lltype.Void:
            llobj = cobj
        else:
            from rpython.rtyper.lltypesystem import rffi
            try:
                inttype = rffi.platform.numbertype_to_rclass[T]
            except KeyError:
                llobj = cobj
            else:
                llobj = inttype(cobj)

        assert lltype.typeOf(llobj) == T
        return llobj

def uninitialized2ctypes(T):
    "For debugging, create a ctypes object filled with 0xDD."
    ctype = get_ctypes_type(T)
    cobj = ctype()
    size = ctypes.sizeof(cobj)
    p = ctypes.cast(ctypes.pointer(cobj),
                    ctypes.POINTER(ctypes.c_ubyte * size))
    for i in range(size):
        p.contents[i] = 0xDD
    if isinstance(T, lltype.Primitive):
        return cobj.value
    else:
        return cobj

# __________ the standard C library __________

if ctypes:
    def get_libc_name():
        if sys.platform == 'win32':
            # Parses sys.version and deduces the version of the compiler
            import distutils.msvccompiler
            version = distutils.msvccompiler.get_build_version()
            if version is None:
                # This logic works with official builds of Python.
                if sys.version_info < (2, 4):
                    clibname = 'msvcrt'
                else:
                    clibname = 'msvcr71'
            else:
                if version <= 6:
                    clibname = 'msvcrt'
                elif version >= 13:
                    clibname = 'ucrtbase'
                else:
                    clibname = 'msvcr%d' % (version * 10)

            # If python was built with in debug mode
            import imp
            if imp.get_suffixes()[0][0] == '_d.pyd':
                clibname += 'd'

            return clibname+'.dll'
        else:
            return ctypes.util.find_library('c')

    libc_name = get_libc_name()     # Make sure the name is determined during import, not at runtime
    if _FREEBSD:
        RTLD_DEFAULT = -2  # see <dlfcn.h>
        rtld_default_lib = ctypes.CDLL("ld-elf.so.1", handle=RTLD_DEFAULT, **load_library_kwargs)
    # XXX is this always correct???
    standard_c_lib = ctypes.CDLL(libc_name, **load_library_kwargs)
else:
    libc_name = 'no ctypes'

# ____________________________________________

# xxx from ctypes.util, this code is a useful fallback on darwin too
if sys.platform == 'darwin':
    # Andreas Degert's find function using gcc
    import re, tempfile, errno

    def _findLib_gcc_fallback(name):
        expr = r'[^\(\)\s]*lib%s\.[^\(\)\s]*' % re.escape(name)
        fdout, ccout = tempfile.mkstemp()
        os.close(fdout)
        cmd = 'if type gcc >/dev/null 2>&1; then : ${CC:=gcc}; else : ${CC:=cc}; fi;' \
              '$CC -Wl,-t -o ' + ccout + ' 2>&1 -l' + name
        try:
            f = os.popen(cmd)
            trace = f.read()
            f.close()
        finally:
            try:
                os.unlink(ccout)
            except OSError as e:
                if e.errno != errno.ENOENT:
                    raise
        res = re.search(expr, trace)
        if not res:
            return None
        return res.group(0)
else:
    _findLib_gcc_fallback = lambda name: None

def get_ctypes_callable(funcptr, calling_conv):
    if not ctypes:
        raise ImportError("ctypes is needed to use ll2ctypes")

    def get_on_lib(lib, elem):
        """ Wrapper to always use lib[func] instead of lib.func
        """
        try:
            return lib[elem]
        except AttributeError:
            pass

    old_eci = funcptr._obj.compilation_info
    funcname = funcptr._obj._name
    if hasattr(old_eci, '_with_ctypes'):
        old_eci = old_eci._with_ctypes

    try:
        eci = _eci_cache[old_eci]
    except KeyError:
        eci = old_eci.compile_shared_lib(ignore_a_files=True,
                                         defines=['RPYTHON_LL2CTYPES'])
        _eci_cache[old_eci] = eci

    libraries = eci.testonly_libraries + eci.libraries + eci.frameworks

    FUNCTYPE = lltype.typeOf(funcptr).TO
    cfunc = None
    if libraries:
        not_found = []
        for libname in libraries:
            libpath = None
            ext = platform.so_ext
            prefixes = platform.so_prefixes
            for dir in eci.library_dirs:
                if libpath:
                    break
                for prefix in prefixes:
                    tryfile = os.path.join(dir, prefix + libname + '.' + ext)
                    if os.path.isfile(tryfile):
                        libpath = tryfile
                        break
            if not libpath:
                libpath = ctypes.util.find_library(libname)
                if not libpath:
                    libpath = _findLib_gcc_fallback(libname)
                if not libpath and os.path.isabs(libname):
                    libpath = libname
            if libpath:
                dllclass = getattr(ctypes, calling_conv + 'dll')
                # on ie slackware there was need for RTLD_GLOBAL here.
                # this breaks a lot of things, since passing RTLD_GLOBAL
                # creates symbol conflicts on C level.
                clib = dllclass._dlltype(libpath, **load_library_kwargs)
                cfunc = get_on_lib(clib, funcname)
                if cfunc is not None:
                    break
            else:
                not_found.append(libname)

    if cfunc is None:
        if _FREEBSD and funcname in ('dlopen', 'fdlopen', 'dlsym', 'dlfunc', 'dlerror', 'dlclose'):
            cfunc = rtld_default_lib[funcname]
        else:
            cfunc = get_on_lib(standard_c_lib, funcname)
        # XXX magic: on Windows try to load the function from 'kernel32' too
        if cfunc is None and hasattr(ctypes, 'windll'):
            cfunc = get_on_lib(ctypes.windll.kernel32, funcname)
        if cfunc is None and hasattr(ctypes, 'windll'):
            cfunc = get_on_lib(ctypes.cdll.msvcrt, funcname)

    if cfunc is None:
        # function name not found in any of the libraries
        if not libraries:
            place = 'the standard C library (missing libraries=...?)'
        elif len(not_found) == len(libraries):
            if len(not_found) == 1:
                raise NotImplementedError(
                    'cannot find the library %r' % (not_found[0],))
            else:
                raise NotImplementedError(
                    'cannot find any of the libraries %r' % (not_found,))
        elif len(libraries) == 1:
            place = 'library %r' % (libraries[0],)
        else:
            place = 'any of the libraries %r' % (libraries,)
            if not_found:
                place += ' (did not find %r)' % (not_found,)
        raise NotImplementedError("function %r not found in %s" % (
            funcname, place))

    # get_ctypes_type() can raise NotImplementedError too
    from rpython.rtyper.lltypesystem import rffi
    cfunc.argtypes = [get_ctypes_type(T) if T is not rffi.VOIDP
                                         else ctypes.c_void_p
                      for T in FUNCTYPE.ARGS
                      if not T is lltype.Void]
    if FUNCTYPE.RESULT is lltype.Void:
        cfunc.restype = None
    else:
        cfunc.restype = get_ctypes_type(FUNCTYPE.RESULT)
    return cfunc

class LL2CtypesCallable(object):
    # a special '_callable' object that invokes ctypes

    def __init__(self, FUNCTYPE, calling_conv):
        self.FUNCTYPE = FUNCTYPE
        self.calling_conv = calling_conv
        self.trampoline = None
        #self.funcptr = ...  set later

    def __call__(self, *argvalues):
        with rlock:
            if self.trampoline is None:
                # lazily build the corresponding ctypes function object
                cfunc = get_ctypes_callable(self.funcptr, self.calling_conv)
                self.trampoline = get_ctypes_trampoline(self.FUNCTYPE, cfunc)
        # perform the call
        return self.trampoline(*argvalues)

    def get_real_address(self):
        cfunc = get_ctypes_callable(self.funcptr, self.calling_conv)
        return ctypes.cast(cfunc, ctypes.c_void_p).value

def get_ctypes_trampoline(FUNCTYPE, cfunc):
    RESULT = FUNCTYPE.RESULT
    container_arguments = []
    for i in range(len(FUNCTYPE.ARGS)):
        if isinstance(FUNCTYPE.ARGS[i], lltype.ContainerType):
            container_arguments.append(i)
    void_arguments = []
    for i in range(len(FUNCTYPE.ARGS)):
        if FUNCTYPE.ARGS[i] is lltype.Void:
            void_arguments.append(i)
    def callme(cargs):   # an extra indirection: workaround for rlib.rstacklet
        return cfunc(*cargs)
    def invoke_via_ctypes(*argvalues):
        global _callback_exc_info
        cargs = []
        for i in range(len(argvalues)):
            if i not in void_arguments:
                cvalue = lltype2ctypes(argvalues[i])
                if i in container_arguments:
                    cvalue = cvalue.contents
                cargs.append(cvalue)
        _callback_exc_info = None
        _restore_c_errno()
        cres = callme(cargs)
        _save_c_errno()
        if _callback_exc_info:
            etype, evalue, etb = _callback_exc_info
            # cres is the actual C result returned by the function. Stick it
            # into the exception so that we can check it inside tests (see
            # e.g. test_llhelper_error_value)
            evalue._ll2ctypes_c_result = cres
            _callback_exc_info = None
            raise etype, evalue, etb
        return ctypes2lltype(RESULT, cres)
    return invoke_via_ctypes


def force_cast(RESTYPE, value):
    with rlock:
        if not isinstance(RESTYPE, lltype.LowLevelType):
            raise TypeError("rffi.cast() first arg should be a TYPE")
        if isinstance(value, llmemory.AddressAsInt):
            value = value.adr
        if isinstance(value, llmemory.fakeaddress):
            value = value.ptr or 0
        if isinstance(value, r_singlefloat):
            value = float(value)
        TYPE1 = lltype.typeOf(value)
        cvalue = lltype2ctypes(value)
        cresulttype = get_ctypes_type(RESTYPE)
        if RESTYPE == TYPE1:
            return value
        elif isinstance(TYPE1, lltype.Ptr):
            if isinstance(RESTYPE, lltype.Ptr):
                # shortcut: ptr->ptr cast
                cptr = ctypes.cast(cvalue, cresulttype)
                return ctypes2lltype(RESTYPE, cptr)
            # first cast the input pointer to an integer
            cvalue = ctypes.cast(cvalue, ctypes.c_void_p).value
            if cvalue is None:
                cvalue = 0
        elif isinstance(cvalue, (str, unicode)):
            cvalue = ord(cvalue)     # character -> integer
        elif hasattr(RESTYPE, "_type") and issubclass(RESTYPE._type, base_int):
            cvalue = int(cvalue)
        elif isinstance(cvalue, r_longfloat):
            cvalue = cvalue.value

        if not isinstance(cvalue, (int, long, float)):
            raise NotImplementedError("casting %r to %r" % (TYPE1, RESTYPE))

        if isinstance(RESTYPE, lltype.Ptr):
            # upgrade to a more recent ctypes (e.g. 1.0.2) if you get
            # an OverflowError on the following line.
            cvalue = ctypes.cast(ctypes.c_void_p(cvalue), cresulttype)
        elif RESTYPE == lltype.Bool:
            cvalue = bool(cvalue)
        else:
            try:
                cvalue = cresulttype(cvalue).value   # mask high bits off if needed
            except TypeError:
                cvalue = int(cvalue)   # float -> int
                cvalue = cresulttype(cvalue).value   # try again
        return ctypes2lltype(RESTYPE, cvalue)

class ForceCastEntry(ExtRegistryEntry):
    _about_ = force_cast

    def compute_result_annotation(self, s_RESTYPE, s_value):
        assert s_RESTYPE.is_constant()
        RESTYPE = s_RESTYPE.const
        return lltype_to_annotation(RESTYPE)

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        s_RESTYPE = hop.args_s[0]
        assert s_RESTYPE.is_constant()
        RESTYPE = s_RESTYPE.const
        v_arg = hop.inputarg(hop.args_r[1], arg=1)
        return hop.genop('force_cast', [v_arg], resulttype = RESTYPE)

def typecheck_ptradd(T):
    # --- ptradd() is only for pointers to non-GC, no-length arrays.
    assert isinstance(T, lltype.Ptr)
    assert isinstance(T.TO, lltype.Array)
    assert T.TO._hints.get('nolength')

def force_ptradd(ptr, n):
    """'ptr' must be a pointer to an array.  Equivalent of 'ptr + n' in
    C, i.e. gives a pointer to the n'th item of the array.  The type of
    the result is again a pointer to an array, the same as the type of
    'ptr'.
    """
    T = lltype.typeOf(ptr)
    typecheck_ptradd(T)
    ctypes_item_type = get_ctypes_type(T.TO.OF)
    ctypes_arrayptr_type = get_ctypes_type(T)
    cptr = lltype2ctypes(ptr)
    baseaddr = ctypes.addressof(cptr.contents.items)
    addr = baseaddr + n * ctypes.sizeof(ctypes_item_type)
    cptr = ctypes.cast(ctypes.c_void_p(addr), ctypes_arrayptr_type)
    return ctypes2lltype(T, cptr)

class ForcePtrAddEntry(ExtRegistryEntry):
    _about_ = force_ptradd

    def compute_result_annotation(self, s_ptr, s_n):
        assert isinstance(s_n, annmodel.SomeInteger)
        assert isinstance(s_ptr, SomePtr)
        typecheck_ptradd(s_ptr.ll_ptrtype)
        return lltype_to_annotation(s_ptr.ll_ptrtype)

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        v_ptr, v_n = hop.inputargs(hop.args_r[0], lltype.Signed)
        return hop.genop('direct_ptradd', [v_ptr, v_n],
                         resulttype = v_ptr.concretetype)

class _lladdress(long):
    _TYPE = llmemory.Address

    def __new__(cls, void_p):
        if isinstance(void_p, (int, long)):
            void_p = ctypes.c_void_p(void_p)
        self = long.__new__(cls, intmask(void_p.value))
        self.void_p = void_p
        self.intval = intmask(void_p.value)
        return self

    def _cast_to_ptr(self, TP):
        return force_cast(TP, self.intval)

    def __repr__(self):
        return '<_lladdress %s>' % (self.void_p,)

    def __eq__(self, other):
        if not isinstance(other, (int, long)):
            other = cast_adr_to_int(other)
        return intmask(other) == self.intval

    def __ne__(self, other):
        return not self == other

class _llgcopaque(lltype._container):
    _TYPE = llmemory.GCREF.TO
    _name = "_llgcopaque"
    _read_directly_intval = True     # for _ptr._cast_to_int()

    def __init__(self, void_p):
        if isinstance(void_p, (int, long)):
            self.intval = intmask(void_p)
        else:
            self.intval = intmask(void_p.value)

    def __eq__(self, other):
        if not other:
            return self.intval == 0
        if isinstance(other, _llgcopaque):
            return self.intval == other.intval
        storage = object()
        if hasattr(other, 'container'):
            storage = other.container._storage
        else:
            storage = other._storage

        if storage in (None, True):
            return False
        return force_cast(lltype.Signed, other._as_ptr()) == self.intval

    def __hash__(self):
        return self.intval

    def __ne__(self, other):
        return not self == other

    def _cast_to_ptr(self, PTRTYPE):
        if self.intval & 1:
            return _opaque_objs[self.intval // 2]
        return force_cast(PTRTYPE, self.intval)


def cast_adr_to_int(addr):
    if isinstance(addr, llmemory.fakeaddress):
        # use ll2ctypes to obtain a real ctypes-based representation of
        # the memory, and cast that address as an integer
        if addr.ptr is None:
            res = 0
        else:
            res = force_cast(lltype.Signed, addr.ptr)
    else:
        res = addr._cast_to_int()
    if res > maxint:
        res = res - 2*(maxint + 1)
        assert int(res) == res
        return int(res)
    return res

class CastAdrToIntEntry(ExtRegistryEntry):
    _about_ = cast_adr_to_int

    def compute_result_annotation(self, s_addr):
        return annmodel.SomeInteger()

    def specialize_call(self, hop):
        assert isinstance(hop.args_r[0], raddress.AddressRepr)
        adr, = hop.inputargs(hop.args_r[0])
        hop.exception_cannot_occur()
        return hop.genop('cast_adr_to_int', [adr],
                         resulttype = lltype.Signed)

# ____________________________________________________________
# errno

# this saves in a thread-local way the "current" value that errno
# should have in C.  We have to save it away from one external C function
# call to the next.  Otherwise a non-zero value left behind will confuse
# CPython itself a bit later, and/or CPython will stamp on it before we
# try to inspect it via rposix.get_errno().
TLS = tlsobject()

# helpers to save/restore the C-level errno -- platform-specific because
# ctypes doesn't just do the right thing and expose it directly :-(

# on 2.6 ctypes does it right, use it

if sys.version_info >= (2, 6):
    def _save_c_errno():
        TLS.errno = ctypes.get_errno()

    def _restore_c_errno():
        pass

else:
    def _where_is_errno():
        raise NotImplementedError("don't know how to get the C-level errno!")

    def _save_c_errno():
        errno_p = _where_is_errno()
        TLS.errno = errno_p.contents.value
        errno_p.contents.value = 0

    def _restore_c_errno():
        if hasattr(TLS, 'errno'):
            _where_is_errno().contents.value = TLS.errno

    if ctypes:
        if _MS_WINDOWS:
            standard_c_lib._errno.restype = ctypes.POINTER(ctypes.c_int)
            def _where_is_errno():
                return standard_c_lib._errno()

        elif sys.platform.startswith('linux'):
            standard_c_lib.__errno_location.restype = ctypes.POINTER(ctypes.c_int)
            def _where_is_errno():
                return standard_c_lib.__errno_location()

        elif sys.platform == 'darwin' or _FREEBSD:
            standard_c_lib.__error.restype = ctypes.POINTER(ctypes.c_int)
            def _where_is_errno():
                return standard_c_lib.__error()
