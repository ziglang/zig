from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper import rclass

def is_immutable_struct(S):
    return isinstance(S, lltype.GcStruct) and S._hints.get('immutable', False)

def has_gcstruct_a_vtable(GCSTRUCT):
    if not isinstance(GCSTRUCT, lltype.GcStruct):
        return False
    if GCSTRUCT is rclass.OBJECT:
        return False
    while not GCSTRUCT._hints.get('typeptr'):
        _, GCSTRUCT = GCSTRUCT._first_struct()
        if GCSTRUCT is None:
            return False
    return True

def get_vtable_for_gcstruct(gccache, GCSTRUCT):
    # xxx hack: from a GcStruct representing an instance's
    # lowleveltype, return the corresponding vtable pointer.
    # Returns None if the GcStruct does not belong to an instance.
    if not isinstance(GCSTRUCT, lltype.GcStruct):
        return lltype.nullptr(rclass.OBJECT_VTABLE)
    if not has_gcstruct_a_vtable(GCSTRUCT):
        return lltype.nullptr(rclass.OBJECT_VTABLE)
    setup_cache_gcstruct2vtable(gccache)
    try:
        return gccache._cache_gcstruct2vtable[GCSTRUCT]
    except KeyError:
        return testing_gcstruct2vtable[GCSTRUCT]

def setup_cache_gcstruct2vtable(gccache):
    if not hasattr(gccache, '_cache_gcstruct2vtable'):
        cache = {}
        if gccache.rtyper:
            for rinstance in gccache.rtyper.instance_reprs.values():
                cache[rinstance.lowleveltype.TO] = rinstance.rclass.getvtable()
        gccache._cache_gcstruct2vtable = cache

def set_testing_vtable_for_gcstruct(GCSTRUCT, vtable, name):
    # only for tests that need to register the vtable of their malloc'ed
    # structures in case they are GcStruct inheriting from OBJECT.
    vtable.name = rclass.alloc_array_name(name)
    testing_gcstruct2vtable[GCSTRUCT] = vtable

testing_gcstruct2vtable = {}

# ____________________________________________________________


def all_fielddescrs(gccache, STRUCT, only_gc=False, res=None,
                    get_field_descr=None):
    from rpython.jit.backend.llsupport import descr

    if get_field_descr is None:
        get_field_descr = descr.get_field_descr
    if res is None:
        res = []
    # order is not relevant, except for tests
    for name in STRUCT._names:
        FIELD = getattr(STRUCT, name)
        if FIELD is lltype.Void:
            continue
        if name.startswith('c__pad'):
            continue
        if name == 'typeptr':
            continue # dealt otherwise
        elif isinstance(FIELD, lltype.Struct):
            all_fielddescrs(gccache, FIELD, only_gc, res, get_field_descr)
        elif (not only_gc) or (isinstance(FIELD, lltype.Ptr) and FIELD._needsgc()):
            res.append(get_field_descr(gccache, STRUCT, name))
    return res

def all_interiorfielddescrs(gccache, ARRAY, get_field_descr=None):
    from rpython.jit.backend.llsupport import descr
    from rpython.jit.codewriter.effectinfo import UnsupportedFieldExc

    if get_field_descr is None:
        get_field_descr = descr.get_field_descr
    # order is not relevant, except for tests
    STRUCT = ARRAY.OF
    res = []
    for name in STRUCT._names:
        FIELD = getattr(STRUCT, name)
        if FIELD is lltype.Void:
            continue
        if name == 'typeptr':
            continue # dealt otherwise
        elif isinstance(FIELD, lltype.Struct):
            raise UnsupportedFieldExc("unexpected array(struct(struct))")
        res.append(get_field_descr(gccache, ARRAY, name))
    return res

def gc_fielddescrs(gccache, STRUCT):
    return all_fielddescrs(gccache, STRUCT, True)

def get_fielddescr_index_in(STRUCT, fieldname, cur_index=0):
    for name in STRUCT._names:
        FIELD = getattr(STRUCT, name)
        if FIELD is lltype.Void:
            continue
        if name == 'typeptr':
            continue # dealt otherwise
        elif isinstance(FIELD, lltype.Struct):
            r = get_fielddescr_index_in(FIELD, fieldname, cur_index)
            if r >= 0:
                return r
            cur_index += -r - 1
            continue
        elif name == fieldname:
            return cur_index
        cur_index += 1
    return -cur_index - 1 # not found
