from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.lltypesystem import rdict
from rpython.rlib.objectmodel import we_are_translated
from rpython.memory.support import mangle_hash

# This is a low-level AddressDict, reusing a lot of the logic from rdict.py.
# xxx this is very dependent on the details of rdict.py

alloc_count = 0     # for debugging

def count_alloc(delta):
    "NOT_RPYTHON"
    global alloc_count
    alloc_count += delta


def newdict(length_estimate=0):
    return rdict.ll_newdict_size(DICT, length_estimate)

def dict_allocate():
    if not we_are_translated(): count_alloc(+1)
    return lltype.malloc(DICT, flavor="raw")

def dict_delete(d):
    dict_delete_entries(d.entries)
    lltype.free(d, flavor="raw")
    if not we_are_translated(): count_alloc(-1)

def dict_allocate_entries(n):
    if not we_are_translated(): count_alloc(+1)
    # 'raw zero varsize malloc with length field' is not really implemented.
    # we can initialize the memory to zero manually
    entries = lltype.malloc(ENTRIES, n, flavor="raw")
    i = 0
    while i < n:
        entries[i].key = llmemory.NULL
        i += 1
    return entries

def dict_delete_entries(entries):
    lltype.free(entries, flavor="raw")
    if not we_are_translated(): count_alloc(-1)

def _hash(adr):
    return mangle_hash(llmemory.cast_adr_to_int(adr))

def dict_keyhash(d, key):
    return _hash(key)

def dict_entry_valid(entries, i):
    return entries[i].key != llmemory.NULL

def dict_entry_hash(entries, i):
    return _hash(entries[i].key)

def dict_get(d, key, default=llmemory.NULL):
    return rdict.ll_get(d, key, default)

def dict_add(d, key):
    rdict.ll_dict_setitem(d, key, llmemory.NULL)

def dict_insertclean(d, key, value):
    rdict.ll_dict_insertclean(d, key, value, _hash(key))

def dict_foreach(d, callback, arg):
    entries = d.entries
    i = len(entries) - 1
    while i >= 0:
        if dict_entry_valid(entries, i):
            callback(entries[i].key, entries[i].value, arg)
        i -= 1
dict_foreach._annspecialcase_ = 'specialize:arg(1)'

ENTRY = lltype.Struct('ENTRY', ('key', llmemory.Address),
                               ('value', llmemory.Address))
ENTRIES = lltype.Array(ENTRY,
                       adtmeths = {
                           'allocate': dict_allocate_entries,
                           'delete': dict_delete_entries,
                           'valid': dict_entry_valid,
                           'everused': dict_entry_valid,
                           'hash': dict_entry_hash,
                       })
DICT = lltype.Struct('DICT', ('entries', lltype.Ptr(ENTRIES)),
                             ('num_items', lltype.Signed),
                             ('resize_counter', lltype.Signed),
                     adtmeths = {
                         'allocate': dict_allocate,
                         'delete': dict_delete,
                         'length': rdict.ll_dict_len,
                         'contains': rdict.ll_contains,
                         'setitem': rdict.ll_dict_setitem,
                         'get': dict_get,
                         'add': dict_add,
                         'insertclean': dict_insertclean,
                         'clear': rdict.ll_clear,
                         'foreach': dict_foreach,
                         'keyhash': dict_keyhash,
                         'keyeq': None,
                     })
