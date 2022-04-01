from rpython.rtyper.lltypesystem import lltype, llmemory, llarena, llgroup, rffi
from rpython.rtyper import rclass
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.debug import ll_assert
from rpython.rlib.rarithmetic import intmask
from rpython.tool.identity_dict import identity_dict


class GCData(object):
    """The GC information tables, and the query functions that the GC
    calls to decode their content.  The encoding of this information
    is done by encode_type_shape().  These two places should be in sync,
    obviously, but in principle no other code should depend on the
    details of the encoding in TYPE_INFO.
    """
    _alloc_flavor_ = 'raw'

    OFFSETS_TO_GC_PTR = lltype.Array(lltype.Signed)

    # A CUSTOM_FUNC is either a destructor, or a custom tracer.
    # A destructor is called when the object is about to be freed.
    # A custom tracer (CT) enumerates the addresses that contain GCREFs.
    # Both are called with the address of the object as only argument.
    # They're embedded in a struct that has raw_memory_offset as another
    # argument, which is only valid if T_HAS_MEMORY_PRESSURE is set
    CUSTOM_FUNC = lltype.FuncType([llmemory.Address], lltype.Void)
    CUSTOM_FUNC_PTR = lltype.Ptr(CUSTOM_FUNC)
    CUSTOM_DATA_STRUCT = lltype.Struct('custom_data',
        ('customfunc', CUSTOM_FUNC_PTR),
        ('memory_pressure_offset', lltype.Signed), # offset to where the amount
                                           # of owned memory pressure is stored
        )
    CUSTOM_DATA_STRUCT_PTR = lltype.Ptr(CUSTOM_DATA_STRUCT)

    # structure describing the layout of a typeid
    TYPE_INFO = lltype.Struct("type_info",
        ("infobits",       lltype.Signed),    # combination of the T_xxx consts
        ("customdata",     CUSTOM_DATA_STRUCT_PTR),
        ("fixedsize",      lltype.Signed),
        ("ofstoptrs",      lltype.Ptr(OFFSETS_TO_GC_PTR)),
        hints={'immutable': True},
        )
    VARSIZE_TYPE_INFO = lltype.Struct("varsize_type_info",
        ("header",         TYPE_INFO),
        ("varitemsize",    lltype.Signed),
        ("ofstovar",       lltype.Signed),
        ("ofstolength",    lltype.Signed),
        ("varofstoptrs",   lltype.Ptr(OFFSETS_TO_GC_PTR)),
        hints={'immutable': True},
        )
    TYPE_INFO_PTR = lltype.Ptr(TYPE_INFO)
    VARSIZE_TYPE_INFO_PTR = lltype.Ptr(VARSIZE_TYPE_INFO)

    def __init__(self, type_info_group):
        assert isinstance(type_info_group, llgroup.group)
        self.type_info_group = type_info_group
        self.type_info_group_ptr = type_info_group._as_ptr()

    def get(self, typeid):
        res = llop.get_group_member(GCData.TYPE_INFO_PTR,
                                    self.type_info_group_ptr,
                                    typeid)
        _check_valid_type_info(res)
        return res

    def get_varsize(self, typeid):
        res = llop.get_group_member(GCData.VARSIZE_TYPE_INFO_PTR,
                                    self.type_info_group_ptr,
                                    typeid)
        _check_valid_type_info_varsize(res)
        return res

    def q_is_varsize(self, typeid):
        infobits = self.get(typeid).infobits
        return (infobits & T_IS_VARSIZE) != 0

    def q_has_gcptr_in_varsize(self, typeid):
        infobits = self.get(typeid).infobits
        return (infobits & T_HAS_GCPTR_IN_VARSIZE) != 0

    def q_has_gcptr(self, typeid):
        infobits = self.get(typeid).infobits
        return (infobits & T_HAS_GCPTR) != 0

    def q_is_gcarrayofgcptr(self, typeid):
        infobits = self.get(typeid).infobits
        return (infobits & T_IS_GCARRAY_OF_GCPTR) != 0

    def q_cannot_pin(self, typeid):
        typeinfo = self.get(typeid)
        ANY = (T_HAS_GCPTR | T_IS_WEAKREF)
        return (typeinfo.infobits & ANY) != 0 or bool(typeinfo.customdata)

    def q_finalizer_handlers(self):
        adr = self.finalizer_handlers   # set from framework.py or gcwrapper.py
        return llmemory.cast_adr_to_ptr(adr, lltype.Ptr(FIN_HANDLER_ARRAY))

    def q_destructor_or_custom_trace(self, typeid):
        if not self.get(typeid).customdata:
            return lltype.nullptr(GCData.CUSTOM_FUNC_PTR.TO)
        return self.get(typeid).customdata.customfunc

    def q_is_old_style_finalizer(self, typeid):
        typeinfo = self.get(typeid)
        return (typeinfo.infobits & T_HAS_OLDSTYLE_FINALIZER) != 0

    def q_offsets_to_gc_pointers(self, typeid):
        return self.get(typeid).ofstoptrs

    def q_fixed_size(self, typeid):
        return self.get(typeid).fixedsize

    def q_varsize_item_sizes(self, typeid):
        return self.get_varsize(typeid).varitemsize

    def q_varsize_offset_to_variable_part(self, typeid):
        return self.get_varsize(typeid).ofstovar

    def q_varsize_offset_to_length(self, typeid):
        return self.get_varsize(typeid).ofstolength

    def q_varsize_offsets_to_gcpointers_in_var_part(self, typeid):
        return self.get_varsize(typeid).varofstoptrs

    def q_weakpointer_offset(self, typeid):
        infobits = self.get(typeid).infobits
        if infobits & T_IS_WEAKREF:
            return weakptr_offset
        return -1

    def q_member_index(self, typeid):
        infobits = self.get(typeid).infobits
        return infobits & T_MEMBER_INDEX

    def q_is_rpython_class(self, typeid):
        infobits = self.get(typeid).infobits
        return infobits & T_IS_RPYTHON_INSTANCE != 0

    def q_has_custom_trace(self, typeid):
        infobits = self.get(typeid).infobits
        return infobits & T_HAS_CUSTOM_TRACE != 0

    def q_fast_path_tracing(self, typeid):
        # return True if none of the flags T_HAS_GCPTR_IN_VARSIZE,
        # T_IS_GCARRAY_OF_GCPTR or T_HAS_CUSTOM_TRACE is set
        T_ANY_SLOW_FLAG = (T_HAS_GCPTR_IN_VARSIZE |
                           T_IS_GCARRAY_OF_GCPTR |
                           T_HAS_CUSTOM_TRACE)
        infobits = self.get(typeid).infobits
        return infobits & T_ANY_SLOW_FLAG == 0

    def q_has_memory_pressure(self, typeid):
        infobits = self.get(typeid).infobits
        return infobits & T_HAS_MEMORY_PRESSURE != 0

    def q_get_memory_pressure_ofs(self, typeid):
        infobits = self.get(typeid).infobits
        assert infobits & T_HAS_MEMORY_PRESSURE != 0
        return self.get(typeid).customdata.memory_pressure_offset

    def set_query_functions(self, gc):
        gc.set_query_functions(
            self.q_is_varsize,
            self.q_has_gcptr_in_varsize,
            self.q_is_gcarrayofgcptr,
            self.q_finalizer_handlers,
            self.q_destructor_or_custom_trace,
            self.q_is_old_style_finalizer,
            self.q_offsets_to_gc_pointers,
            self.q_fixed_size,
            self.q_varsize_item_sizes,
            self.q_varsize_offset_to_variable_part,
            self.q_varsize_offset_to_length,
            self.q_varsize_offsets_to_gcpointers_in_var_part,
            self.q_weakpointer_offset,
            self.q_member_index,
            self.q_is_rpython_class,
            self.q_has_custom_trace,
            self.q_fast_path_tracing,
            self.q_has_gcptr,
            self.q_cannot_pin,
            self.q_has_memory_pressure,
            self.q_get_memory_pressure_ofs)

    def _has_got_custom_trace(self, typeid):
        type_info = self.get(typeid)
        type_info.infobits |= (T_HAS_CUSTOM_TRACE | T_HAS_GCPTR)


# the lowest 16bits are used to store group member index
T_MEMBER_INDEX              =   0xffff
T_IS_VARSIZE                = 0x010000
T_HAS_GCPTR_IN_VARSIZE      = 0x020000
T_IS_GCARRAY_OF_GCPTR       = 0x040000
T_IS_WEAKREF                = 0x080000
T_IS_RPYTHON_INSTANCE       = 0x100000 # the type is a subclass of OBJECT
T_HAS_CUSTOM_TRACE          = 0x200000
T_HAS_OLDSTYLE_FINALIZER    = 0x400000
T_HAS_GCPTR                 = 0x1000000
T_HAS_MEMORY_PRESSURE       = 0x2000000 # first field is memory pressure field
T_KEY_MASK                  = intmask(0xFC000000) # bug detection only
T_KEY_VALUE                 = intmask(0x58000000) # bug detection only

def _check_valid_type_info(p):
    ll_assert(p.infobits & T_KEY_MASK == T_KEY_VALUE, "invalid type_id")

def _check_valid_type_info_varsize(p):
    ll_assert(p.header.infobits & (T_KEY_MASK | T_IS_VARSIZE) ==
                                  (T_KEY_VALUE | T_IS_VARSIZE),
              "invalid varsize type_id")

def check_typeid(typeid):
    # xxx does not perform a full check of validity, just checks for nonzero
    ll_assert(llop.is_group_member_nonzero(lltype.Bool, typeid),
              "invalid type_id")

def has_special_memory_pressure(TYPE):
    if TYPE._is_varsize():
        return False
    T = TYPE
    while True:
        if 'special_memory_pressure' in T._flds:
            return True
        if 'super' not in T._flds:
            return False
        T = T._flds['super']

def get_memory_pressure_ofs(TYPE):
    T = TYPE
    while True:
        if 'special_memory_pressure' in T._flds:
            return llmemory.offsetof(T, 'special_memory_pressure')
        if 'super' not in T._flds:
            assert False, "get_ and has_memory_pressure disagree"
        T = T._flds['super']    

def encode_type_shape(builder, info, TYPE, index):
    """Encode the shape of the TYPE into the TYPE_INFO structure 'info'."""
    offsets = offsets_to_gc_pointers(TYPE)
    infobits = index
    info.ofstoptrs = builder.offsets2table(offsets, TYPE)
    if len(offsets) > 0:
        infobits |= T_HAS_GCPTR
    #
    fptrs = builder.special_funcptr_for_type(TYPE)
    if fptrs or has_special_memory_pressure(TYPE):
        customdata = lltype.malloc(GCData.CUSTOM_DATA_STRUCT, flavor='raw',
                                   immortal=True)
        info.customdata = customdata
        if "destructor" in fptrs:
            customdata.customfunc = fptrs["destructor"]
        if "old_style_finalizer" in fptrs:
            customdata.customfunc = fptrs["old_style_finalizer"]
            infobits |= T_HAS_OLDSTYLE_FINALIZER
        if has_special_memory_pressure(TYPE):
            infobits |= T_HAS_MEMORY_PRESSURE
            info.customdata.memory_pressure_offset = get_memory_pressure_ofs(TYPE)
    #
    if not TYPE._is_varsize():
        info.fixedsize = llarena.round_up_for_allocation(
            llmemory.sizeof(TYPE), builder.GCClass.object_minimal_size)
        # note about round_up_for_allocation(): in the 'info' table
        # we put a rounded-up size only for fixed-size objects.  For
        # varsize ones, the GC must anyway compute the size at run-time
        # and round up that result.
    else:
        infobits |= T_IS_VARSIZE
        varinfo = lltype.cast_pointer(GCData.VARSIZE_TYPE_INFO_PTR, info)
        info.fixedsize = llmemory.sizeof(TYPE, 0)
        if isinstance(TYPE, lltype.Struct):
            ARRAY = TYPE._flds[TYPE._arrayfld]
            ofs1 = llmemory.offsetof(TYPE, TYPE._arrayfld)
            varinfo.ofstolength = ofs1 + llmemory.ArrayLengthOffset(ARRAY)
            varinfo.ofstovar = ofs1 + llmemory.itemoffsetof(ARRAY, 0)
        else:
            assert isinstance(TYPE, lltype.GcArray)
            ARRAY = TYPE
            if (isinstance(ARRAY.OF, lltype.Ptr)
                and ARRAY.OF.TO._gckind == 'gc'):
                infobits |= T_IS_GCARRAY_OF_GCPTR
            varinfo.ofstolength = llmemory.ArrayLengthOffset(ARRAY)
            varinfo.ofstovar = llmemory.itemoffsetof(TYPE, 0)
        assert isinstance(ARRAY, lltype.Array)
        if ARRAY.OF != lltype.Void:
            offsets = offsets_to_gc_pointers(ARRAY.OF)
        else:
            offsets = ()
        if len(offsets) > 0:
            infobits |= T_HAS_GCPTR_IN_VARSIZE | T_HAS_GCPTR
        varinfo.varofstoptrs = builder.offsets2table(offsets, ARRAY.OF)
        varinfo.varitemsize = llmemory.sizeof(ARRAY.OF)
    if builder.is_weakref_type(TYPE):
        infobits |= T_IS_WEAKREF
    if is_subclass_of_object(TYPE):
        infobits |= T_IS_RPYTHON_INSTANCE
    info.infobits = infobits | T_KEY_VALUE

# ____________________________________________________________


class TypeLayoutBuilder(object):
    can_add_new_types = True
    can_encode_type_shape = True    # set to False initially by the JIT

    size_of_fixed_type_info = llmemory.sizeof(GCData.TYPE_INFO)

    def __init__(self, GCClass, lltype2vtable=None):
        self.GCClass = GCClass
        self.lltype2vtable = lltype2vtable
        self.make_type_info_group()
        self.id_of_type = {}      # {LLTYPE: type_id}
        self.iseen_roots = identity_dict()
        # the following are lists of addresses of gc pointers living inside the
        # prebuilt structures.  It should list all the locations that could
        # possibly point to a GC heap object.
        # this lists contains pointers in GcStructs and GcArrays
        self.addresses_of_static_ptrs = []
        # this lists contains pointers in raw Structs and Arrays
        self.addresses_of_static_ptrs_in_nongc = []
        # for debugging, the following list collects all the prebuilt
        # GcStructs and GcArrays
        self.all_prebuilt_gc = []
        self._special_funcptrs = {}
        self.offsettable_cache = {}

    def make_type_info_group(self):
        self.type_info_group = llgroup.group("typeinfo")
        # don't use typeid 0, may help debugging
        DUMMY = lltype.Struct("dummy", ('x', lltype.Signed))
        dummy = lltype.malloc(DUMMY, immortal=True, zero=True)
        self.type_info_group.add_member(dummy)

    def get_type_id(self, TYPE):
        try:
            return self.id_of_type[TYPE]
        except KeyError:
            assert self.can_add_new_types
            assert isinstance(TYPE, (lltype.GcStruct, lltype.GcArray))
            # Record the new type_id description as a TYPE_INFO structure.
            # build the TYPE_INFO structure
            if not TYPE._is_varsize():
                fullinfo = lltype.malloc(GCData.TYPE_INFO,
                                         immortal=True, zero=True)
                info = fullinfo
            else:
                fullinfo = lltype.malloc(GCData.VARSIZE_TYPE_INFO,
                                         immortal=True, zero=True)
                info = fullinfo.header
            type_id = self.type_info_group.add_member(fullinfo)
            if self.can_encode_type_shape:
                encode_type_shape(self, info, TYPE, type_id.index)
            else:
                self._pending_type_shapes.append((info, TYPE, type_id.index))
            # store it
            self.id_of_type[TYPE] = type_id
            self.add_vtable_after_typeinfo(TYPE)
            return type_id

    def add_vtable_after_typeinfo(self, TYPE):
        # if gcremovetypeptr is False, then lltype2vtable is None and it
        # means that we don't have to store the vtables in type_info_group.
        if self.lltype2vtable is None:
            return
        # does the type have a vtable?
        vtable = self.lltype2vtable.get(TYPE, None)
        if vtable is not None:
            # yes.  check that in this case, we are not varsize
            assert not TYPE._is_varsize()
            vtable = lltype.normalizeptr(vtable)
            self.type_info_group.add_member(vtable)
        else:
            # no vtable from lltype2vtable -- double-check to be sure
            # that it's not a subclass of OBJECT.
            assert not is_subclass_of_object(TYPE)

    def get_info(self, type_id):
        res = llop.get_group_member(GCData.TYPE_INFO_PTR,
                                    self.type_info_group._as_ptr(),
                                    type_id)
        _check_valid_type_info(res)
        return res

    def get_info_varsize(self, type_id):
        res = llop.get_group_member(GCData.VARSIZE_TYPE_INFO_PTR,
                                    self.type_info_group._as_ptr(),
                                    type_id)
        _check_valid_type_info_varsize(res)
        return res

    def is_weakref_type(self, TYPE):
        return TYPE == WEAKREF

    def encode_type_shapes_now(self):
        if not self.can_encode_type_shape:
            self.can_encode_type_shape = True
            for info, TYPE, index in self._pending_type_shapes:
                encode_type_shape(self, info, TYPE, index)
            del self._pending_type_shapes

    def delay_encoding(self):
        # used by the JIT
        self._pending_type_shapes = []
        self.can_encode_type_shape = False

    def offsets2table(self, offsets, TYPE):
        if len(offsets) == 0:
            TYPE = lltype.Void    # we can share all zero-length arrays
        try:
            return self.offsettable_cache[TYPE]
        except KeyError:
            cachedarray = lltype.malloc(GCData.OFFSETS_TO_GC_PTR,
                                        len(offsets), immortal=True)
            for i, value in enumerate(offsets):
                cachedarray[i] = value
            self.offsettable_cache[TYPE] = cachedarray
            return cachedarray

    def close_table(self):
        # make sure we no longer add members to the type_info_group.
        self.can_add_new_types = False
        self.offsettable_cache = None
        return self.type_info_group

    def special_funcptr_for_type(self, TYPE):
        if TYPE in self._special_funcptrs:
            return self._special_funcptrs[TYPE]
        fptr1, is_lightweight = self.make_destructor_funcptr_for_type(TYPE)
        fptr2 = self.make_custom_trace_funcptr_for_type(TYPE)
        result = {}
        if fptr1:
            if is_lightweight:
                result["destructor"] = fptr1
            else:
                result["old_style_finalizer"] = fptr1
        if fptr2:
            result["custom_trace"] = fptr2
        self._special_funcptrs[TYPE] = result
        return result

    def make_destructor_funcptr_for_type(self, TYPE):
        # must be overridden for proper destructor support
        return None, False

    def make_custom_trace_funcptr_for_type(self, TYPE):
        # must be overridden for proper custom tracer support
        return None

    def initialize_gc_query_function(self, gc):
        gcdata = GCData(self.type_info_group)
        gcdata.set_query_functions(gc)
        return gcdata

    def consider_constant(self, TYPE, value, gc):
        if value is not lltype.top_container(value):
            return
        if value in self.iseen_roots:
            return
        self.iseen_roots[value] = True

        if isinstance(TYPE, lltype.GcOpaqueType):
            self.consider_constant(lltype.typeOf(value.container),
                                   value.container, gc)
            return

        if isinstance(TYPE, (lltype.GcStruct, lltype.GcArray)):
            typeid = self.get_type_id(TYPE)
            hdr = gc.gcheaderbuilder.new_header(value)
            adr = llmemory.cast_ptr_to_adr(hdr)
            if gc.gcflag_dummy and self.is_dummy_struct(value):
                gc.init_gc_object_immortal(adr, typeid, flags=gc.gcflag_dummy)
            else:
                gc.init_gc_object_immortal(adr, typeid)
            self.all_prebuilt_gc.append(value)

        # The following collects the addresses of all the fields that have
        # a GC Pointer type, inside the current prebuilt object.  All such
        # fields are potential roots: unless the structure is immutable,
        # they could be changed later to point to GC heap objects.
        adr = llmemory.cast_ptr_to_adr(value._as_ptr())
        if TYPE._gckind == "gc":
            if gc.prebuilt_gc_objects_are_static_roots or gc.DEBUG:
                appendto = self.addresses_of_static_ptrs
            else:
                return
        else:
            appendto = self.addresses_of_static_ptrs_in_nongc
        for a in gc_pointers_inside(value, adr, mutable_only=True):
            appendto.append(a)

    def is_dummy_struct(self, obj):
        return False    # overridden in TransformerLayoutBuilder


# ____________________________________________________________
#
# Helpers to discover GC pointers inside structures

def offsets_to_gc_pointers(TYPE):
    offsets = []
    if isinstance(TYPE, lltype.Struct):
        for name in TYPE._names:
            FIELD = getattr(TYPE, name)
            if isinstance(FIELD, lltype.Array):
                continue    # skip inlined array
            baseofs = llmemory.offsetof(TYPE, name)
            suboffsets = offsets_to_gc_pointers(FIELD)
            for s in suboffsets:
                try:
                    knownzero = s == 0
                except TypeError:
                    knownzero = False
                if knownzero:
                    offsets.append(baseofs)
                else:
                    offsets.append(baseofs + s)
        # sanity check
        #ex = lltype.Ptr(TYPE)._example()
        #adr = llmemory.cast_ptr_to_adr(ex)
        #for off in offsets:
        #    (adr + off)
    elif isinstance(TYPE, lltype.Ptr) and TYPE.TO._gckind == 'gc':
        offsets.append(0)
    return offsets

def gc_pointers_inside(v, adr, mutable_only=False):
    t = lltype.typeOf(v)
    if isinstance(t, lltype.Struct):
        skip = ()
        if mutable_only:
            if t._hints.get('immutable'):
                return
            if 'immutable_fields' in t._hints:
                skip = t._hints['immutable_fields'].all_immutable_fields()
        for n, t2 in t._flds.iteritems():
            if isinstance(t2, lltype.Ptr) and t2.TO._gckind == 'gc':
                if n not in skip:
                    yield adr + llmemory.offsetof(t, n)
            elif isinstance(t2, (lltype.Array, lltype.Struct)):
                for a in gc_pointers_inside(getattr(v, n),
                                            adr + llmemory.offsetof(t, n),
                                            mutable_only):
                    yield a
    elif isinstance(t, lltype.Array):
        if mutable_only and t._hints.get('immutable'):
            return
        if isinstance(t.OF, lltype.Ptr) and t.OF.TO._gckind == 'gc':
            for i in range(len(v.items)):
                yield adr + llmemory.itemoffsetof(t, i)
        elif isinstance(t.OF, lltype.Struct):
            for i in range(len(v.items)):
                for a in gc_pointers_inside(v.items[i],
                                            adr + llmemory.itemoffsetof(t, i),
                                            mutable_only):
                    yield a

def zero_gc_pointers(p):
    TYPE = lltype.typeOf(p).TO
    zero_gc_pointers_inside(p, TYPE)

def zero_gc_pointers_inside(p, TYPE):
    if isinstance(TYPE, lltype.Struct):
        for name, FIELD in TYPE._flds.items():
            if isinstance(FIELD, lltype.Ptr) and FIELD.TO._gckind == 'gc':
                setattr(p, name, lltype.nullptr(FIELD.TO))
            elif isinstance(FIELD, lltype.ContainerType):
                zero_gc_pointers_inside(getattr(p, name), FIELD)
    elif isinstance(TYPE, lltype.Array):
        ITEM = TYPE.OF
        if isinstance(ITEM, lltype.Ptr) and ITEM.TO._gckind == 'gc':
            null = lltype.nullptr(ITEM.TO)
            for i in range(p._obj.getlength()):
                p[i] = null
        elif isinstance(ITEM, lltype.ContainerType):
            for i in range(p._obj.getlength()):
                zero_gc_pointers_inside(p[i], ITEM)

def is_subclass_of_object(TYPE):
    while isinstance(TYPE, lltype.GcStruct):
        if TYPE is rclass.OBJECT:
            return True
        _, TYPE = TYPE._first_struct()
    return False

########## weakrefs ##########
# framework: weakref objects are small structures containing only an address

WEAKREF = lltype.GcStruct("weakref", ("weakptr", llmemory.Address))
WEAKREFPTR = lltype.Ptr(WEAKREF)
sizeof_weakref= llmemory.sizeof(WEAKREF)
empty_weakref = lltype.malloc(WEAKREF, immortal=True)
empty_weakref.weakptr = llmemory.NULL
weakptr_offset = llmemory.offsetof(WEAKREF, "weakptr")

def ll_weakref_deref(wref):
    wref = llmemory.cast_weakrefptr_to_ptr(WEAKREFPTR, wref)
    return wref.weakptr

def convert_weakref_to(targetptr):
    # Prebuilt weakrefs don't really need to be weak at all,
    # but we need to emulate the structure expected by ll_weakref_deref().
    if not targetptr:
        return empty_weakref
    else:
        link = lltype.malloc(WEAKREF, immortal=True)
        link.weakptr = llmemory.cast_ptr_to_adr(targetptr)
        return link

########## finalizers ##########

FIN_TRIGGER_FUNC = lltype.FuncType([], lltype.Void)
FIN_HANDLER_ARRAY = lltype.Array(('deque', llmemory.Address),
                                 ('trigger', lltype.Ptr(FIN_TRIGGER_FUNC)))
