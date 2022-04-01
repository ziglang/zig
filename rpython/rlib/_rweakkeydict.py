from rpython.flowspace.model import Constant
from rpython.rtyper.lltypesystem import lltype, llmemory, rdict
from rpython.rtyper.lltypesystem.llmemory import weakref_create, weakref_deref
from rpython.rtyper import rclass
from rpython.rtyper.rclass import getinstancerepr
from rpython.rtyper.rmodel import Repr
from rpython.rlib.rweakref import RWeakKeyDictionary
from rpython.rlib import jit
from rpython.rlib.objectmodel import compute_identity_hash


# Warning: this implementation of RWeakKeyDictionary is not exactly
# leaking, but can keep around some values for a long time, even after
# the corresponding keys were freed.  They will be eventually freed if
# you continue to manipulate the dictionary.  Avoid to use this if the
# values are objects that might keep alive tons of memory.


class WeakKeyDictRepr(Repr):
    def __init__(self, rtyper):
        self.rtyper = rtyper
        self.lowleveltype = lltype.Ptr(WEAKDICT)
        self.dict_cache = {}

    def convert_const(self, weakdict):
        if not isinstance(weakdict, RWeakKeyDictionary):
            raise TyperError("expected an RWeakKeyDictionary: %r" % (
                weakdict,))
        try:
            key = Constant(weakdict)
            return self.dict_cache[key]
        except KeyError:
            self.setup()
            if weakdict.length() != 0:
                raise TyperError("got a non-empty prebuilt RWeakKeyDictionary")
            l_dict = ll_new_weakdict()
            self.dict_cache[key] = l_dict
            return l_dict

    def rtype_method_get(self, hop):
        r_object = getinstancerepr(self.rtyper, None)
        v_d, v_key = hop.inputargs(self, r_object)
        hop.exception_cannot_occur()
        v_result = hop.gendirectcall(ll_get, v_d, v_key)
        v_result = hop.genop("cast_pointer", [v_result],
                             resulttype=hop.r_result.lowleveltype)
        return v_result

    def rtype_method_set(self, hop):
        r_object = getinstancerepr(self.rtyper, None)
        v_d, v_key, v_value = hop.inputargs(self, r_object, r_object)
        hop.exception_cannot_occur()
        if hop.args_s[2].is_constant() and hop.args_s[2].const is None:
            hop.gendirectcall(ll_set_null, v_d, v_key)
        else:
            hop.gendirectcall(ll_set, v_d, v_key, v_value)

    def rtype_method_length(self, hop):
        v_d, = hop.inputargs(self)
        hop.exception_cannot_occur()
        return hop.gendirectcall(ll_length, v_d)


def specialize_make_weakdict(hop):
    hop.exception_cannot_occur()
    v_d = hop.gendirectcall(ll_new_weakdict)
    return v_d

# ____________________________________________________________


NULLVALUE = lltype.nullptr(rclass.OBJECTPTR.TO)
WEAKDICTENTRY = lltype.Struct("weakdictentry",
                              ("key", llmemory.WeakRefPtr),
                              ("value", rclass.OBJECTPTR),
                              ("f_hash", lltype.Signed))

def ll_debugrepr(x):
    if x:
        h = compute_identity_hash(x)
    else:
        h = 0
    return '<%x>' % (h,)

def ll_valid(entries, i):
    key = entries[i].key
    if not key:
        return False
    elif weakref_deref(rclass.OBJECTPTR, key):
        return True
    else:
        # The entry might be a dead weakref still holding a strong
        # reference to the value; for this case, we clear the old
        # value from the entry, if any.
        entries[i].value = NULLVALUE
        return False

def ll_everused(entries, i):
    return bool(entries[i].key)

entrymeths = {
    'allocate': lltype.typeMethod(rdict._ll_malloc_entries),
    'delete': rdict._ll_free_entries,
    'valid': ll_valid,
    'everused': ll_everused,
    'hash': rdict.ll_hash_from_cache,
    'no_direct_compare': True,
    }
WEAKDICTENTRYARRAY = lltype.GcArray(WEAKDICTENTRY,
                                    adtmeths=entrymeths,
                                    hints={'weakarray': 'key'})
# NB. the 'hints' is not used so far ^^^

@jit.dont_look_inside
def ll_new_weakdict():
    d = lltype.malloc(WEAKDICT)
    d.entries = WEAKDICT.entries.TO.allocate(rdict.DICT_INITSIZE)
    d.num_items = 0
    d.resize_counter = rdict.DICT_INITSIZE * 2
    return d

@jit.dont_look_inside
def ll_get(d, llkey):
    hash = compute_identity_hash(llkey)
    i = rdict.ll_dict_lookup(d, llkey, hash) & rdict.MASK
    #llop.debug_print(lltype.Void, i, 'get', hex(hash),
    #                 ll_debugrepr(d.entries[i].key),
    #                 ll_debugrepr(d.entries[i].value))
    # NB. ll_valid() above was just called at least on entry i, so if
    # it is an invalid entry with a dead weakref, the value was reset
    # to NULLVALUE.
    return d.entries[i].value

@jit.dont_look_inside
def ll_set(d, llkey, llvalue):
    if llvalue:
        ll_set_nonnull(d, llkey, llvalue)
    else:
        ll_set_null(d, llkey)

@jit.dont_look_inside
def ll_set_nonnull(d, llkey, llvalue):
    hash = compute_identity_hash(llkey)
    keyref = weakref_create(llkey)    # GC effects here, before the rest
    i = rdict.ll_dict_lookup(d, llkey, hash) & rdict.MASK
    everused = d.entries.everused(i)
    d.entries[i].key = keyref
    d.entries[i].value = llvalue
    d.entries[i].f_hash = hash
    #llop.debug_print(lltype.Void, i, 'stored', hex(hash),
    #                 ll_debugrepr(llkey),
    #                 ll_debugrepr(llvalue))
    if not everused:
        d.resize_counter -= 3
        if d.resize_counter <= 0:
            #llop.debug_print(lltype.Void, 'RESIZE')
            ll_weakdict_resize(d)

@jit.dont_look_inside
def ll_set_null(d, llkey):
    hash = compute_identity_hash(llkey)
    i = rdict.ll_dict_lookup(d, llkey, hash) & rdict.MASK
    if d.entries.everused(i):
        # If the entry was ever used, clean up its key and value.
        # We don't store a NULL value, but a dead weakref, because
        # the entry must still be marked as everused().
        d.entries[i].key = llmemory.dead_wref
        d.entries[i].value = NULLVALUE
        #llop.debug_print(lltype.Void, i, 'zero')

def ll_update_num_items(d):
    entries = d.entries
    num_items = 0
    for i in range(len(entries)):
        if entries.valid(i):
            num_items += 1
    d.num_items = num_items

def ll_weakdict_resize(d):
    # first set num_items to its correct, up-to-date value
    ll_update_num_items(d)
    rdict.ll_dict_resize(d)

def ll_keyeq(d, weakkey1, realkey2):
    # only called by ll_dict_lookup() with the first arg coming from an
    # entry.key, and the 2nd arg being the argument to ll_dict_lookup().
    if not weakkey1:
        assert bool(realkey2)
        return False
    return weakref_deref(rclass.OBJECTPTR, weakkey1) == realkey2

@jit.dont_look_inside
def ll_length(d):
    # xxx slow, but it's only for debugging
    ll_update_num_items(d)
    #llop.debug_print(lltype.Void, 'length:', d.num_items)
    return d.num_items

dictmeths = {
    'll_get': ll_get,
    'll_set': ll_set,
    'keyeq': ll_keyeq,
    'paranoia': False,
    }

WEAKDICT = lltype.GcStruct("weakkeydict",
                           ("num_items", lltype.Signed),
                           ("resize_counter", lltype.Signed),
                           ("entries", lltype.Ptr(WEAKDICTENTRYARRAY)),
                           adtmeths=dictmeths)
