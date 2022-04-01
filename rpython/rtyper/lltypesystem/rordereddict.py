import sys
from rpython.tool.pairtype import pairtype
from rpython.flowspace.model import Constant
from rpython.rtyper.rdict import AbstractDictRepr, AbstractDictIteratorRepr
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rlib import objectmodel, jit, rgc, types
from rpython.rlib.signature import signature
from rpython.rlib.objectmodel import specialize, likely, not_rpython
from rpython.rtyper.debug import ll_assert
from rpython.rlib.rarithmetic import r_uint, intmask
from rpython.rtyper import rmodel
from rpython.rtyper.error import TyperError
from rpython.rtyper.annlowlevel import llhelper


# ____________________________________________________________
#
#  generic implementation of RPython dictionary, with parametric DICTKEY and
#  DICTVALUE types. The basic implementation is a sparse array of indexes
#  plus a dense array of structs that contain keys and values. struct looks
#  like that:
#
#
#    struct dictentry {
#        DICTKEY key;
#        DICTVALUE value;
#        long f_hash;        # (optional) key hash, if hard to recompute
#        bool f_valid;      # (optional) the entry is filled
#    }
#
#    struct dicttable {
#        int num_live_items;
#        int num_ever_used_items;
#        int resize_counter;
#        {byte, short, int, long} *indexes;
#        dictentry *entries;
#        lookup_function_no; # one of the four possible functions for different
#                       # size dicts; the rest of the word is a counter for how
#                       # many 'entries' at the start are known to be deleted
#        (Function DICTKEY, DICTKEY -> bool) *fnkeyeq;
#        (Function DICTKEY -> int) *fnkeyhash;
#    }
#
#

@jit.look_inside_iff(lambda d, key, hash, flag: jit.isvirtual(d))
@jit.oopspec('ordereddict.lookup(d, key, hash, flag)')
def ll_call_lookup_function(d, key, hash, flag):
    while True:
        fun = d.lookup_function_no & FUNC_MASK
        # This likely() here forces gcc to compile the check for fun==FUNC_BYTE
        # first.  Otherwise, this is a regular switch and gcc (at least 4.7)
        # compiles this as a series of checks, with the FUNC_BYTE case last.
        # It sounds minor, but it is worth 6-7% on a PyPy microbenchmark.
        if likely(fun == FUNC_BYTE):
            return ll_dict_lookup(d, key, hash, flag, TYPE_BYTE)
        elif fun == FUNC_SHORT:
            return ll_dict_lookup(d, key, hash, flag, TYPE_SHORT)
        elif IS_64BIT and fun == FUNC_INT:
            return ll_dict_lookup(d, key, hash, flag, TYPE_INT)
        elif fun == FUNC_LONG:
            return ll_dict_lookup(d, key, hash, flag, TYPE_LONG)
        else:
            ll_dict_create_initial_index(d)
            # then, retry

def get_ll_dict(DICTKEY, DICTVALUE, get_custom_eq_hash=None, DICT=None,
                ll_fasthash_function=None, ll_hash_function=None,
                ll_eq_function=None, method_cache={}, simple_hash_eq=False,
                dummykeyobj=None, dummyvalueobj=None, rtyper=None):
    # get the actual DICT type. if DICT is None, it's created, otherwise
    # forward reference is becoming DICT
    if DICT is None:
        DICT = lltype.GcForwardReference()
    # compute the shape of the DICTENTRY structure
    entryfields = []
    entrymeths = {
        'allocate': lltype.typeMethod(_ll_malloc_entries),
        'delete': _ll_free_entries,
        'must_clear_key':   (isinstance(DICTKEY, lltype.Ptr)
                             and DICTKEY._needsgc()),
        'must_clear_value': (isinstance(DICTVALUE, lltype.Ptr)
                             and DICTVALUE._needsgc()),
        }
    if getattr(ll_eq_function, 'no_direct_compare', False):
        entrymeths['no_direct_compare'] = True

    # * the key
    entryfields.append(("key", DICTKEY))

    # * the state of the entry - trying to encode it as dummy objects
    if dummykeyobj:
        # all the state can be encoded in the key
        entrymeths['dummy_obj'] = dummykeyobj
        entrymeths['valid'] = ll_valid_from_key
        entrymeths['mark_deleted'] = ll_mark_deleted_in_key
        # the key is overwritten by 'dummy' when the entry is deleted
        entrymeths['must_clear_key'] = False

    elif dummyvalueobj:
        # all the state can be encoded in the value
        entrymeths['dummy_obj'] = dummyvalueobj
        entrymeths['valid'] = ll_valid_from_value
        entrymeths['mark_deleted'] = ll_mark_deleted_in_value
        # value is overwritten by 'dummy' when entry is deleted
        entrymeths['must_clear_value'] = False

    else:
        # we need a flag to know if the entry was ever used
        entryfields.append(("f_valid", lltype.Bool))
        entrymeths['valid'] = ll_valid_from_flag
        entrymeths['mark_deleted'] = ll_mark_deleted_in_flag

    # * the value
    entryfields.append(("value", DICTVALUE))

    if simple_hash_eq:
        assert get_custom_eq_hash is not None
        entrymeths['entry_hash'] = ll_hash_custom_fast
    elif ll_fasthash_function is None:
        entryfields.append(("f_hash", lltype.Signed))
        entrymeths['entry_hash'] = ll_hash_from_cache
    else:
        entrymeths['entry_hash'] = ll_hash_recomputed
        entrymeths['fasthashfn'] = ll_fasthash_function

    # Build the lltype data structures
    DICTENTRY = lltype.Struct("odictentry", *entryfields)
    DICTENTRYARRAY = lltype.GcArray(DICTENTRY,
                                    adtmeths=entrymeths)
    fields =          [ ("num_live_items", lltype.Signed),
                        ("num_ever_used_items", lltype.Signed),
                        ("resize_counter", lltype.Signed),
                        ("indexes", llmemory.GCREF),
                        ("lookup_function_no", lltype.Signed),
                        ("entries", lltype.Ptr(DICTENTRYARRAY)) ]
    if get_custom_eq_hash is not None:
        r_rdict_eqfn, r_rdict_hashfn = get_custom_eq_hash()
        fields.extend([ ("fnkeyeq", r_rdict_eqfn.lowleveltype),
                        ("fnkeyhash", r_rdict_hashfn.lowleveltype) ])
        adtmeths = {
            'keyhash':        ll_keyhash_custom,
            'keyeq':          ll_keyeq_custom,
            'r_rdict_eqfn':   r_rdict_eqfn,
            'r_rdict_hashfn': r_rdict_hashfn,
            'paranoia':       not simple_hash_eq,
            }
    else:
        # figure out which functions must be used to hash and compare
        ll_keyhash = ll_hash_function
        ll_keyeq = ll_eq_function
        ll_keyhash = lltype.staticAdtMethod(ll_keyhash)
        if ll_keyeq is not None:
            ll_keyeq = lltype.staticAdtMethod(ll_keyeq)
        adtmeths = {
            'keyhash':  ll_keyhash,
            'keyeq':    ll_keyeq,
            'paranoia': False,
            }
    adtmeths['KEY']   = DICTKEY
    adtmeths['VALUE'] = DICTVALUE
    adtmeths['lookup_function'] = lltype.staticAdtMethod(ll_call_lookup_function)
    adtmeths['allocate'] = lltype.typeMethod(_ll_malloc_dict)

    DICT.become(lltype.GcStruct("dicttable", adtmeths=adtmeths,
                                *fields))
    return DICT


class OrderedDictRepr(AbstractDictRepr):

    def __init__(self, rtyper, key_repr, value_repr, dictkey, dictvalue,
                 custom_eq_hash=None, force_non_null=False, simple_hash_eq=False):
        #assert not force_non_null
        self.rtyper = rtyper
        self.finalized = False
        self.DICT = lltype.GcForwardReference()
        self.lowleveltype = lltype.Ptr(self.DICT)
        self.custom_eq_hash = custom_eq_hash is not None
        self.simple_hash_eq = simple_hash_eq
        if not isinstance(key_repr, rmodel.Repr):  # not computed yet, done by setup()
            assert callable(key_repr)
            self._key_repr_computer = key_repr
        else:
            self.external_key_repr, self.key_repr = self.pickkeyrepr(key_repr)
        if not isinstance(value_repr, rmodel.Repr):  # not computed yet, done by setup()
            assert callable(value_repr)
            self._value_repr_computer = value_repr
        else:
            self.external_value_repr, self.value_repr = self.pickrepr(value_repr)
        self.dictkey = dictkey
        self.dictvalue = dictvalue
        self.dict_cache = {}
        self._custom_eq_hash_repr = custom_eq_hash
        # setup() needs to be called to finish this initialization

    def _externalvsinternal(self, rtyper, item_repr):
        return rmodel.externalvsinternal(self.rtyper, item_repr)

    def _setup_repr(self):
        if 'key_repr' not in self.__dict__:
            key_repr = self._key_repr_computer()
            self.external_key_repr, self.key_repr = self.pickkeyrepr(key_repr)
        if 'value_repr' not in self.__dict__:
            self.external_value_repr, self.value_repr = self.pickrepr(self._value_repr_computer())
        if isinstance(self.DICT, lltype.GcForwardReference):
            DICTKEY = self.key_repr.lowleveltype
            DICTVALUE = self.value_repr.lowleveltype
            # * we need an explicit flag if the key and the value is not
            #   able to store dummy values
            s_key   = self.dictkey.s_value
            s_value = self.dictvalue.s_value
            kwd = {}
            if self.custom_eq_hash:
                self.r_rdict_eqfn, self.r_rdict_hashfn = (
                    self._custom_eq_hash_repr())
                kwd['get_custom_eq_hash'] = self._custom_eq_hash_repr
                kwd['simple_hash_eq'] = self.simple_hash_eq
            else:
                kwd['ll_hash_function'] = self.key_repr.get_ll_hash_function()
                kwd['ll_eq_function'] = self.key_repr.get_ll_eq_function()
                kwd['ll_fasthash_function'] = self.key_repr.get_ll_fasthash_function()
            kwd['dummykeyobj'] = self.key_repr.get_ll_dummyval_obj(self.rtyper,
                                                                   s_key)
            kwd['dummyvalueobj'] = self.value_repr.get_ll_dummyval_obj(
                self.rtyper, s_value)
            get_ll_dict(DICTKEY, DICTVALUE, DICT=self.DICT,
                        rtyper=self.rtyper, **kwd)


    def convert_const(self, dictobj):
        from rpython.rtyper.lltypesystem import llmemory
        # get object from bound dict methods
        #dictobj = getattr(dictobj, '__self__', dictobj)
        if dictobj is None:
            return lltype.nullptr(self.DICT)
        if not isinstance(dictobj, (dict, objectmodel.r_dict)):
            raise TypeError("expected a dict: %r" % (dictobj,))
        try:
            key = Constant(dictobj)
            return self.dict_cache[key]
        except KeyError:
            self.setup()
            self.setup_final()
            l_dict = ll_newdict_size(self.DICT, len(dictobj))
            ll_no_initial_index(l_dict)
            self.dict_cache[key] = l_dict
            r_key = self.key_repr
            if r_key.lowleveltype == llmemory.Address:
                raise TypeError("No prebuilt dicts of address keys")
            r_value = self.value_repr
            if isinstance(dictobj, objectmodel.r_dict):

                if self.r_rdict_eqfn.lowleveltype != lltype.Void:
                    l_fn = self.r_rdict_eqfn.convert_const(dictobj.key_eq)
                    l_dict.fnkeyeq = l_fn
                if self.r_rdict_hashfn.lowleveltype != lltype.Void:
                    l_fn = self.r_rdict_hashfn.convert_const(dictobj.key_hash)
                    l_dict.fnkeyhash = l_fn

                for dictkeycontainer, dictvalue in dictobj._dict.items():
                    llkey = r_key.convert_const(dictkeycontainer.key)
                    llvalue = r_value.convert_const(dictvalue)
                    _ll_dict_insert_no_index(l_dict, llkey, llvalue)
                return l_dict

            else:
                for dictkey, dictvalue in dictobj.items():
                    llkey = r_key.convert_const(dictkey)
                    llvalue = r_value.convert_const(dictvalue)
                    _ll_dict_insert_no_index(l_dict, llkey, llvalue)
                return l_dict

    def rtype_len(self, hop):
        v_dict, = hop.inputargs(self)
        return hop.gendirectcall(ll_dict_len, v_dict)

    def rtype_bool(self, hop):
        v_dict, = hop.inputargs(self)
        return hop.gendirectcall(ll_dict_bool, v_dict)

    def make_iterator_repr(self, *variant):
        return DictIteratorRepr(self, *variant)

    def rtype_method_get(self, hop):
        if hop.nb_args == 3:
            v_dict, v_key, v_default = hop.inputargs(self, self.key_repr,
                                                     self.value_repr)
        else:
            v_dict, v_key = hop.inputargs(self, self.key_repr)
            v_default = hop.inputconst(self.value_repr, None)
        hop.exception_cannot_occur()
        v_res = hop.gendirectcall(ll_dict_get, v_dict, v_key, v_default)
        return self.recast_value(hop.llops, v_res)

    def rtype_method_setdefault(self, hop):
        v_dict, v_key, v_default = hop.inputargs(self, self.key_repr,
                                                 self.value_repr)
        hop.exception_cannot_occur()
        v_res = hop.gendirectcall(ll_dict_setdefault, v_dict, v_key, v_default)
        return self.recast_value(hop.llops, v_res)

    def rtype_method_copy(self, hop):
        v_dict, = hop.inputargs(self)
        hop.exception_cannot_occur()
        return hop.gendirectcall(ll_dict_copy, v_dict)

    def rtype_method_update(self, hop):
        v_dic1, v_dic2 = hop.inputargs(self, self)
        hop.exception_cannot_occur()
        return hop.gendirectcall(ll_dict_update, v_dic1, v_dic2)

    def rtype_method__prepare_dict_update(self, hop):
        v_dict, v_num = hop.inputargs(self, lltype.Signed)
        hop.exception_cannot_occur()
        hop.gendirectcall(ll_prepare_dict_update, v_dict, v_num)

    def _rtype_method_kvi(self, hop, ll_func):
        v_dic, = hop.inputargs(self)
        r_list = hop.r_result
        cLIST = hop.inputconst(lltype.Void, r_list.lowleveltype.TO)
        hop.exception_cannot_occur()
        return hop.gendirectcall(ll_func, cLIST, v_dic)

    def rtype_method_keys(self, hop):
        return self._rtype_method_kvi(hop, ll_dict_keys)

    def rtype_method_values(self, hop):
        return self._rtype_method_kvi(hop, ll_dict_values)

    def rtype_method_items(self, hop):
        return self._rtype_method_kvi(hop, ll_dict_items)

    def rtype_bltn_list(self, hop):
        return self._rtype_method_kvi(hop, ll_dict_keys)

    def rtype_method_iterkeys(self, hop):
        hop.exception_cannot_occur()
        return DictIteratorRepr(self, "keys").newiter(hop)

    def rtype_method_itervalues(self, hop):
        hop.exception_cannot_occur()
        return DictIteratorRepr(self, "values").newiter(hop)

    def rtype_method_iteritems(self, hop):
        hop.exception_cannot_occur()
        return DictIteratorRepr(self, "items").newiter(hop)

    def rtype_method_iterkeys_with_hash(self, hop):
        v_dic, = hop.inputargs(self)
        hop.exception_is_here()
        hop.gendirectcall(ll_ensure_indexes, v_dic)
        return DictIteratorRepr(self, "keys_with_hash").newiter(hop)

    def rtype_method_iteritems_with_hash(self, hop):
        v_dic, = hop.inputargs(self)
        hop.exception_is_here()
        hop.gendirectcall(ll_ensure_indexes, v_dic)
        return DictIteratorRepr(self, "items_with_hash").newiter(hop)

    def rtype_method_clear(self, hop):
        v_dict, = hop.inputargs(self)
        hop.exception_cannot_occur()
        return hop.gendirectcall(ll_dict_clear, v_dict)

    def rtype_method_popitem(self, hop):
        v_dict, = hop.inputargs(self)
        r_tuple = hop.r_result
        cTUPLE = hop.inputconst(lltype.Void, r_tuple.lowleveltype)
        hop.exception_is_here()
        return hop.gendirectcall(ll_dict_popitem, cTUPLE, v_dict)

    def rtype_method_pop(self, hop):
        if hop.nb_args == 2:
            v_args = hop.inputargs(self, self.key_repr)
            target = ll_dict_pop
        elif hop.nb_args == 3:
            v_args = hop.inputargs(self, self.key_repr, self.value_repr)
            target = ll_dict_pop_default
        hop.exception_is_here()
        v_res = hop.gendirectcall(target, *v_args)
        return self.recast_value(hop.llops, v_res)

    def rtype_method_contains_with_hash(self, hop):
        v_dict, v_key, v_hash = hop.inputargs(self, self.key_repr,
                                              lltype.Signed)
        hop.exception_is_here()
        return hop.gendirectcall(ll_dict_contains_with_hash,
                                 v_dict, v_key, v_hash)

    def rtype_method_setitem_with_hash(self, hop):
        v_dict, v_key, v_hash, v_value = hop.inputargs(
            self, self.key_repr, lltype.Signed, self.value_repr)
        if self.custom_eq_hash:
            hop.exception_is_here()
        else:
            hop.exception_cannot_occur()
        hop.gendirectcall(ll_dict_setitem_with_hash,
                          v_dict, v_key, v_hash, v_value)

    def rtype_method_getitem_with_hash(self, hop):
        v_dict, v_key, v_hash = hop.inputargs(
            self, self.key_repr, lltype.Signed)
        if not self.custom_eq_hash:
            hop.has_implicit_exception(KeyError)  # record that we know about it
        hop.exception_is_here()
        v_res = hop.gendirectcall(ll_dict_getitem_with_hash,
                                  v_dict, v_key, v_hash)
        return self.recast_value(hop.llops, v_res)

    def rtype_method_delitem_with_hash(self, hop):
        v_dict, v_key, v_hash = hop.inputargs(
            self, self.key_repr, lltype.Signed)
        if not self.custom_eq_hash:
            hop.has_implicit_exception(KeyError)  # record that we know about it
        hop.exception_is_here()
        hop.gendirectcall(ll_dict_delitem_with_hash, v_dict, v_key, v_hash)

    def rtype_method_delitem_if_value_is(self, hop):
        v_dict, v_key, v_value = hop.inputargs(
            self, self.key_repr, self.value_repr)
        hop.exception_cannot_occur()
        hop.gendirectcall(ll_dict_delitem_if_value_is, v_dict, v_key, v_value)

    def rtype_method_move_to_end(self, hop):
        v_dict, v_key, v_last = hop.inputargs(
            self, self.key_repr, lltype.Bool)
        if not self.custom_eq_hash:
            hop.has_implicit_exception(KeyError)  # record that we know about it
        hop.exception_is_here()
        hop.gendirectcall(ll_dict_move_to_end, v_dict, v_key, v_last)


class __extend__(pairtype(OrderedDictRepr, rmodel.Repr)):

    def rtype_getitem((r_dict, r_key), hop):
        v_dict, v_key = hop.inputargs(r_dict, r_dict.key_repr)
        if not r_dict.custom_eq_hash:
            hop.has_implicit_exception(KeyError)   # record that we know about it
        hop.exception_is_here()
        v_res = hop.gendirectcall(ll_dict_getitem, v_dict, v_key)
        return r_dict.recast_value(hop.llops, v_res)

    def rtype_delitem((r_dict, r_key), hop):
        v_dict, v_key = hop.inputargs(r_dict, r_dict.key_repr)
        if not r_dict.custom_eq_hash:
            hop.has_implicit_exception(KeyError)   # record that we know about it
        hop.exception_is_here()
        hop.gendirectcall(ll_dict_delitem, v_dict, v_key)

    def rtype_setitem((r_dict, r_key), hop):
        v_dict, v_key, v_value = hop.inputargs(r_dict, r_dict.key_repr, r_dict.value_repr)
        if r_dict.custom_eq_hash:
            hop.exception_is_here()
        else:
            hop.exception_cannot_occur()
        hop.gendirectcall(ll_dict_setitem, v_dict, v_key, v_value)

    def rtype_contains((r_dict, r_key), hop):
        v_dict, v_key = hop.inputargs(r_dict, r_dict.key_repr)
        hop.exception_is_here()
        return hop.gendirectcall(ll_dict_contains, v_dict, v_key)

class __extend__(pairtype(OrderedDictRepr, OrderedDictRepr)):
    def convert_from_to((r_dict1, r_dict2), v, llops):
        # check that we don't convert from Dicts with
        # different key/value types
        if r_dict1.dictkey is None or r_dict2.dictkey is None:
            return NotImplemented
        if r_dict1.dictkey is not r_dict2.dictkey:
            return NotImplemented
        if r_dict1.dictvalue is None or r_dict2.dictvalue is None:
            return NotImplemented
        if r_dict1.dictvalue is not r_dict2.dictvalue:
            return NotImplemented
        return v

# ____________________________________________________________
#
#  Low-level methods.  These can be run for testing, but are meant to
#  be direct_call'ed from rtyped flow graphs, which means that they will
#  get flowed and annotated, mostly with SomePtr.

DICTINDEX_LONG = lltype.Ptr(lltype.GcArray(lltype.Unsigned))
DICTINDEX_INT = lltype.Ptr(lltype.GcArray(rffi.UINT))
DICTINDEX_SHORT = lltype.Ptr(lltype.GcArray(rffi.USHORT))
DICTINDEX_BYTE = lltype.Ptr(lltype.GcArray(rffi.UCHAR))

IS_64BIT = sys.maxint != 2 ** 31 - 1

if IS_64BIT:
    FUNC_SHIFT = 3
    FUNC_MASK  = 0x07  # three bits
    FUNC_BYTE, FUNC_SHORT, FUNC_INT, FUNC_LONG, FUNC_MUST_REINDEX = range(5)
else:
    FUNC_SHIFT = 2
    FUNC_MASK  = 0x03  # two bits
    FUNC_BYTE, FUNC_SHORT, FUNC_LONG, FUNC_MUST_REINDEX = range(4)
TYPE_BYTE  = rffi.UCHAR
TYPE_SHORT = rffi.USHORT
TYPE_INT   = rffi.UINT
TYPE_LONG  = lltype.Unsigned

def ll_no_initial_index(d):
    # Used when making new empty dicts, and when translating prebuilt dicts.
    # Remove the index completely.  A dictionary must always have an
    # index unless it is freshly created or freshly translated.  Most
    # dict operations start with ll_call_lookup_function(), which will
    # recompute the hashes and create the index.
    ll_assert(d.num_live_items == d.num_ever_used_items, 
         "ll_no_initial_index(): dict already in use")
    d.lookup_function_no = FUNC_MUST_REINDEX
    d.indexes = lltype.nullptr(llmemory.GCREF.TO)

def ll_malloc_indexes_and_choose_lookup(d, n):
    # keep in sync with ll_clear_indexes() below
    if n <= 256:
        d.indexes = lltype.cast_opaque_ptr(llmemory.GCREF,
                                           lltype.malloc(DICTINDEX_BYTE.TO, n,
                                                         zero=True))
        d.lookup_function_no = FUNC_BYTE
    elif n <= 65536:
        d.indexes = lltype.cast_opaque_ptr(llmemory.GCREF,
                                           lltype.malloc(DICTINDEX_SHORT.TO, n,
                                                         zero=True))
        d.lookup_function_no = FUNC_SHORT
    elif IS_64BIT and n <= 2 ** 32:
        d.indexes = lltype.cast_opaque_ptr(llmemory.GCREF,
                                           lltype.malloc(DICTINDEX_INT.TO, n,
                                                         zero=True))
        d.lookup_function_no = FUNC_INT
    else:
        d.indexes = lltype.cast_opaque_ptr(llmemory.GCREF,
                                           lltype.malloc(DICTINDEX_LONG.TO, n,
                                                         zero=True))
        d.lookup_function_no = FUNC_LONG

def ll_clear_indexes(d, n):
    fun = d.lookup_function_no & FUNC_MASK
    d.lookup_function_no = fun
    if fun == FUNC_BYTE:
        rgc.ll_arrayclear(lltype.cast_opaque_ptr(DICTINDEX_BYTE, d.indexes))
    elif fun == FUNC_SHORT:
        rgc.ll_arrayclear(lltype.cast_opaque_ptr(DICTINDEX_SHORT, d.indexes))
    elif IS_64BIT and fun == FUNC_INT:
        rgc.ll_arrayclear(lltype.cast_opaque_ptr(DICTINDEX_INT, d.indexes))
    elif fun == FUNC_LONG:
        rgc.ll_arrayclear(lltype.cast_opaque_ptr(DICTINDEX_LONG, d.indexes))
    else:
        assert False

@jit.dont_look_inside
def ll_call_insert_clean_function(d, hash, i):
    assert i >= 0
    fun = d.lookup_function_no & FUNC_MASK
    if fun == FUNC_BYTE:
        ll_dict_store_clean(d, hash, i, TYPE_BYTE)
    elif fun == FUNC_SHORT:
        ll_dict_store_clean(d, hash, i, TYPE_SHORT)
    elif IS_64BIT and fun == FUNC_INT:
        ll_dict_store_clean(d, hash, i, TYPE_INT)
    elif fun == FUNC_LONG:
        ll_dict_store_clean(d, hash, i, TYPE_LONG)
    else:
        # can't be still FUNC_MUST_REINDEX here
        ll_assert(False, "ll_call_insert_clean_function(): invalid lookup_fun")
        assert False

def ll_call_delete_by_entry_index(d, hash, i, replace_with):
    # only called from _ll_dict_del, whose @jit.look_inside_iff
    # condition should control when we get inside here with the jit
    fun = d.lookup_function_no & FUNC_MASK
    if fun == FUNC_BYTE:
        ll_dict_delete_by_entry_index(d, hash, i, replace_with, TYPE_BYTE)
    elif fun == FUNC_SHORT:
        ll_dict_delete_by_entry_index(d, hash, i, replace_with, TYPE_SHORT)
    elif IS_64BIT and fun == FUNC_INT:
        ll_dict_delete_by_entry_index(d, hash, i, replace_with, TYPE_INT)
    elif fun == FUNC_LONG:
        ll_dict_delete_by_entry_index(d, hash, i, replace_with, TYPE_LONG)
    else:
        # can't be still FUNC_MUST_REINDEX here
        ll_assert(False, "ll_call_delete_by_entry_index(): invalid lookup_fun")
        assert False

def ll_valid_from_flag(entries, i):
    return entries[i].f_valid

def ll_valid_from_key(entries, i):
    ENTRIES = lltype.typeOf(entries).TO
    dummy = ENTRIES.dummy_obj.ll_dummy_value
    return entries[i].key != dummy

def ll_valid_from_value(entries, i):
    ENTRIES = lltype.typeOf(entries).TO
    dummy = ENTRIES.dummy_obj.ll_dummy_value
    return entries[i].value != dummy

def ll_mark_deleted_in_flag(entries, i):
    entries[i].f_valid = False

def ll_mark_deleted_in_key(entries, i):
    ENTRIES = lltype.typeOf(entries).TO
    dummy = ENTRIES.dummy_obj.ll_dummy_value
    entries[i].key = dummy

def ll_mark_deleted_in_value(entries, i):
    ENTRIES = lltype.typeOf(entries).TO
    dummy = ENTRIES.dummy_obj.ll_dummy_value
    entries[i].value = dummy

@signature(types.any(), types.any(), types.int(), returns=types.any())
def ll_hash_from_cache(entries, d, i):
    return entries[i].f_hash

@signature(types.any(), types.any(), types.int(), returns=types.any())
def ll_hash_recomputed(entries, d, i):
    ENTRIES = lltype.typeOf(entries).TO
    return ENTRIES.fasthashfn(entries[i].key)

@signature(types.any(), types.any(), types.int(), returns=types.any())
def ll_hash_custom_fast(entries, d, i):
    DICT = lltype.typeOf(d).TO
    key = entries[i].key
    return objectmodel.hlinvoke(DICT.r_rdict_hashfn, d.fnkeyhash, key)

def ll_keyhash_custom(d, key):
    DICT = lltype.typeOf(d).TO
    return objectmodel.hlinvoke(DICT.r_rdict_hashfn, d.fnkeyhash, key)

def ll_keyeq_custom(d, key1, key2):
    DICT = lltype.typeOf(d).TO
    return objectmodel.hlinvoke(DICT.r_rdict_eqfn, d.fnkeyeq, key1, key2)

def ll_dict_len(d):
    return d.num_live_items

def ll_dict_bool(d):
    # check if a dict is True, allowing for None
    return bool(d) and d.num_live_items != 0

def ll_dict_getitem(d, key):
    return ll_dict_getitem_with_hash(d, key, d.keyhash(key))

def ll_dict_getitem_with_hash(d, key, hash):
    index = d.lookup_function(d, key, hash, FLAG_LOOKUP)
    if index >= 0:
        return d.entries[index].value
    else:
        raise KeyError

def ll_dict_setitem(d, key, value):
    ll_dict_setitem_with_hash(d, key, d.keyhash(key), value)

def ll_dict_setitem_with_hash(d, key, hash, value):
    index = d.lookup_function(d, key, hash, FLAG_STORE)
    _ll_dict_setitem_lookup_done(d, key, value, hash, index)

# It may be safe to look inside always, it has a few branches though, and their
# frequencies needs to be investigated.
@jit.look_inside_iff(lambda d, key, value, hash, i: jit.isvirtual(d) and jit.isconstant(key))
def _ll_dict_setitem_lookup_done(d, key, value, hash, i):
    ENTRY = lltype.typeOf(d.entries).TO.OF
    if i >= 0:
        entry = d.entries[i]
        entry.value = value
    else:
        reindexed = False
        if len(d.entries) == d.num_ever_used_items:
            try:
                reindexed = ll_dict_grow(d)
            except:
                _ll_dict_rescue(d)
                raise
        rc = d.resize_counter - 3
        if rc <= 0:
            try:
                ll_dict_resize(d)
                reindexed = True
            except:
                _ll_dict_rescue(d)
                raise
            rc = d.resize_counter - 3
            ll_assert(rc > 0, "ll_dict_resize failed?")
        if reindexed:
            ll_call_insert_clean_function(d, hash, d.num_ever_used_items)
        #
        d.resize_counter = rc
        entry = d.entries[d.num_ever_used_items]
        entry.key = key
        entry.value = value
        if hasattr(ENTRY, 'f_hash'):
            entry.f_hash = hash
        if hasattr(ENTRY, 'f_valid'):
            entry.f_valid = True
        d.num_ever_used_items += 1
        d.num_live_items += 1

@jit.dont_look_inside
def _ll_dict_rescue(d):
    # MemoryError situation!  The 'indexes' contains an invalid entry
    # at this point.  But we can call ll_dict_reindex() with the
    # following arguments, ensuring no further malloc occurs.
    ll_dict_reindex(d, _ll_len_of_d_indexes(d))
_ll_dict_rescue._dont_inline_ = True

@not_rpython
def _ll_dict_insert_no_index(d, key, value):
    # never translated
    ENTRY = lltype.typeOf(d.entries).TO.OF
    entry = d.entries[d.num_ever_used_items]
    entry.key = key
    entry.value = value
    # note that f_hash is left uninitialized in prebuilt dicts
    if hasattr(ENTRY, 'f_valid'):
        entry.f_valid = True
    d.num_ever_used_items += 1
    d.num_live_items += 1
    rc = d.resize_counter - 3
    d.resize_counter = rc

def _ll_len_of_d_indexes(d):
    # xxx Haaaack: returns len(d.indexes).  Works independently of
    # the exact type pointed to by d, using a forced cast...
    # Must only be called by @jit.dont_look_inside functions.
    return lltype.length_of_simple_gcarray_from_opaque(d.indexes)

def _overallocate_entries_len(baselen):
    # This over-allocates proportional to the list size, making room
    # for additional growth.  This over-allocates slightly more eagerly
    # than with regular lists.  The idea is that there are many more
    # lists than dicts around in PyPy, and dicts of 5 to 8 items are
    # not that rare (so a single jump from 0 to 8 is a good idea).
    # The growth pattern is:  0, 8, 17, 27, 38, 50, 64, 80, 98, ...
    newsize = baselen + (baselen >> 3)
    return newsize + 8

@jit.look_inside_iff(lambda d: jit.isvirtual(d))
def ll_dict_grow(d):
    # note: this @jit.look_inside_iff is here to inline the three lines
    # at the end of this function.  It's important because dicts start
    # with a length-zero 'd.entries' which must be grown as soon as we
    # insert an element.
    if d.num_live_items < d.num_ever_used_items // 2:
        # At least 50% of the allocated entries are dead, so perform a
        # compaction. If ll_dict_remove_deleted_items detects that over
        # 75% of allocated entries are dead, then it will also shrink the
        # memory allocated at the same time as doing a compaction.
        ll_dict_remove_deleted_items(d)
        return True

    new_allocated = _overallocate_entries_len(len(d.entries))

    # Detect a relatively rare case where the indexes numeric type is too
    # small to store all the entry indexes: there would be 'new_allocated'
    # entries, which may in corner cases be larger than 253 even though we
    # have single bytes in 'd.indexes' (and the same for the larger
    # boundaries).  The 'd.indexes' hashtable is never more than 2/3rd
    # full, so we know that 'd.num_live_items' should be at most 2/3 * 256
    # (or 65536 or etc.) so after the ll_dict_remove_deleted_items() below
    # at least 1/3rd items in 'd.entries' are free.
    fun = d.lookup_function_no & FUNC_MASK
    toobig = False
    if fun == FUNC_BYTE:
        assert d.num_live_items < ((1 << 8) - MIN_INDEXES_MINUS_ENTRIES)
        toobig = new_allocated > ((1 << 8) - MIN_INDEXES_MINUS_ENTRIES)
    elif fun == FUNC_SHORT:
        assert d.num_live_items < ((1 << 16) - MIN_INDEXES_MINUS_ENTRIES)
        toobig = new_allocated > ((1 << 16) - MIN_INDEXES_MINUS_ENTRIES)
    elif IS_64BIT and fun == FUNC_INT:
        assert d.num_live_items < ((1 << 32) - MIN_INDEXES_MINUS_ENTRIES)
        toobig = new_allocated > ((1 << 32) - MIN_INDEXES_MINUS_ENTRIES)
    #
    if toobig:
        ll_dict_remove_deleted_items(d)
        assert d.num_live_items == d.num_ever_used_items
        return True

    newitems = lltype.malloc(lltype.typeOf(d).TO.entries.TO, new_allocated)
    rgc.ll_arraycopy(d.entries, newitems, 0, 0, len(d.entries))
    d.entries = newitems
    return False

@jit.dont_look_inside
def ll_dict_remove_deleted_items(d):
    if d.num_live_items < len(d.entries) // 4:
        # At least 75% of the allocated entries are dead, so shrink the memory
        # allocated as well as doing a compaction.
        new_allocated = _overallocate_entries_len(d.num_live_items)
        newitems = lltype.malloc(lltype.typeOf(d).TO.entries.TO, new_allocated)
    else:
        newitems = d.entries
        # The loop below does a lot of writes into 'newitems'.  It's a better
        # idea to do a single gc_writebarrier rather than activating the
        # card-by-card logic (worth 11% in microbenchmarks).
        from rpython.rtyper.lltypesystem.lloperation import llop
        llop.gc_writebarrier(lltype.Void, newitems)
    #
    ENTRIES = lltype.typeOf(d).TO.entries.TO
    ENTRY = ENTRIES.OF
    isrc = 0
    idst = 0
    isrclimit = d.num_ever_used_items
    while isrc < isrclimit:
        if d.entries.valid(isrc):
            src = d.entries[isrc]
            dst = newitems[idst]
            dst.key = src.key
            dst.value = src.value
            if hasattr(ENTRY, 'f_hash'):
                dst.f_hash = src.f_hash
            if hasattr(ENTRY, 'f_valid'):
                assert src.f_valid
                dst.f_valid = True
            idst += 1
        isrc += 1
    assert d.num_live_items == idst
    d.num_ever_used_items = idst
    if ((ENTRIES.must_clear_key or ENTRIES.must_clear_value) and
            d.entries == newitems):
        # must clear the extra entries: they may contain valid pointers
        # which would create a temporary memory leak
        while idst < isrclimit:
            entry = newitems[idst]
            if ENTRIES.must_clear_key:
                entry.key = lltype.nullptr(ENTRY.key.TO)
            if ENTRIES.must_clear_value:
                entry.value = lltype.nullptr(ENTRY.value.TO)
            idst += 1
    else:
        d.entries = newitems

    ll_dict_reindex(d, _ll_len_of_d_indexes(d))


def ll_dict_delitem(d, key):
    ll_dict_delitem_with_hash(d, key, d.keyhash(key))

def ll_dict_delitem_with_hash(d, key, hash):
    index = d.lookup_function(d, key, hash, FLAG_LOOKUP)
    if index < 0:
        raise KeyError
    _ll_dict_del(d, hash, index)

def ll_dict_delitem_if_value_is(d, key, value):
    hash = d.keyhash(key)
    index = d.lookup_function(d, key, hash, FLAG_LOOKUP)
    if index < 0:
        return
    if d.entries[index].value != value:
        return
    _ll_dict_del(d, hash, index)

def _ll_dict_del_entry(d, index):
    d.entries.mark_deleted(index)
    d.num_live_items -= 1
    # clear the key and the value if they are GC pointers
    ENTRIES = lltype.typeOf(d.entries).TO
    ENTRY = ENTRIES.OF
    entry = d.entries[index]
    if ENTRIES.must_clear_key:
        entry.key = lltype.nullptr(ENTRY.key.TO)
    if ENTRIES.must_clear_value:
        entry.value = lltype.nullptr(ENTRY.value.TO)

@jit.look_inside_iff(lambda d, h, i: jit.isvirtual(d) and jit.isconstant(i))
def _ll_dict_del(d, hash, index):
    ll_call_delete_by_entry_index(d, hash, index, DELETED)
    _ll_dict_del_entry(d, index)

    if d.num_live_items == 0:
        # Dict is now empty.  Reset these fields.
        d.num_ever_used_items = 0
        d.lookup_function_no &= FUNC_MASK

    elif index == d.num_ever_used_items - 1:
        # The last element of the ordereddict has been deleted. Instead of
        # simply marking the item as dead, we can safely reuse it. Since it's
        # also possible that there are more dead items immediately behind the
        # last one, we reclaim all the dead items at the end of the ordereditem
        # at the same point.
        i = index
        while True:
            i -= 1
            assert i >= 0
            if d.entries.valid(i):    # must be at least one
                break
        d.num_ever_used_items = i + 1

    # If the dictionary is at least 87.5% dead items, then consider shrinking
    # it.
    if d.num_live_items + DICT_INITSIZE <= len(d.entries) / 8:
        ll_dict_resize(d)

def ll_dict_resize(d):
    # make a 'new_size' estimate and shrink it if there are many
    # deleted entry markers.  See CPython for why it is a good idea to
    # quadruple the dictionary size as long as it's not too big.
    # (Quadrupling comes from '(d.num_live_items + d.num_live_items + 1) * 2'
    # as long as num_live_items is not too large.)
    num_extra = min(d.num_live_items + 1, 30000)
    _ll_dict_resize_to(d, num_extra)
ll_dict_resize.oopspec = 'odict.resize(d)'

def _ll_dict_resize_to(d, num_extra):
    new_estimate = (d.num_live_items + num_extra) * 2
    new_size = DICT_INITSIZE
    while new_size <= new_estimate:
        new_size *= 2

    if new_size < _ll_len_of_d_indexes(d):
        ll_dict_remove_deleted_items(d)
    else:
        ll_dict_reindex(d, new_size)

def ll_ensure_indexes(d):
    num = d.lookup_function_no
    if num == FUNC_MUST_REINDEX:
        ll_dict_create_initial_index(d)
    else:
        ll_assert((num & FUNC_MASK) != FUNC_MUST_REINDEX,
                  "bad combination in lookup_function_no")

def ll_dict_create_initial_index(d):
    """Create the initial index for a dictionary.  The common case is
    that 'd' is empty.  The uncommon case is that it is a prebuilt
    dictionary frozen by translation, in which case we must rehash all
    entries.  The common case must be seen by the JIT.
    """
    if d.num_live_items == 0:
        ll_malloc_indexes_and_choose_lookup(d, DICT_INITSIZE)
        d.resize_counter = DICT_INITSIZE * 2
    else:
        ll_dict_rehash_after_translation(d)

@jit.dont_look_inside
def ll_dict_rehash_after_translation(d):
    assert d.num_live_items == d.num_ever_used_items
    assert not d.indexes
    #
    # recompute all hashes.  Needed if they are stored in d.entries,
    # but do it anyway: otherwise, e.g. a string-keyed dictionary
    # won't have a fasthash on its strings if their hash is still
    # uncomputed.
    ENTRY = lltype.typeOf(d.entries).TO.OF
    for i in range(d.num_ever_used_items):
        assert d.entries.valid(i)
        d_entry = d.entries[i]
        h = d.keyhash(d_entry.key)
        if hasattr(ENTRY, 'f_hash'):
            d_entry.f_hash = h
        #else: purely for the side-effect it can have on d_entry.key
    #
    # Use the smallest acceptable size for ll_dict_reindex
    new_size = DICT_INITSIZE
    while new_size * 2 - d.num_live_items * 3 <= 0:
        new_size *= 2
    ll_dict_reindex(d, new_size)

def ll_dict_reindex(d, new_size):
    if bool(d.indexes) and _ll_len_of_d_indexes(d) == new_size:
        ll_clear_indexes(d, new_size)   # hack: we can reuse the same array
    else:
        ll_malloc_indexes_and_choose_lookup(d, new_size)
    d.resize_counter = new_size * 2 - d.num_live_items * 3
    ll_assert(d.resize_counter > 0, "reindex: resize_counter <= 0")
    ll_assert((d.lookup_function_no >> FUNC_SHIFT) == 0,
              "reindex: lookup_fun >> SHIFT")
    #
    entries = d.entries
    i = 0
    ibound = d.num_ever_used_items
    #
    # Write four loops, moving the check for the value of 'fun' out of
    # the loops.  A small speed-up over ll_call_insert_clean_function().
    fun = d.lookup_function_no     # == lookup_function_no & FUNC_MASK
    if fun == FUNC_BYTE:
        while i < ibound:
            if entries.valid(i):
                ll_dict_store_clean(d, entries.entry_hash(d, i), i, TYPE_BYTE)
            i += 1
    elif fun == FUNC_SHORT:
        while i < ibound:
            if entries.valid(i):
                ll_dict_store_clean(d, entries.entry_hash(d, i), i, TYPE_SHORT)
            i += 1
    elif IS_64BIT and fun == FUNC_INT:
        while i < ibound:
            if entries.valid(i):
                ll_dict_store_clean(d, entries.entry_hash(d, i), i, TYPE_INT)
            i += 1
    elif fun == FUNC_LONG:
        while i < ibound:
            if entries.valid(i):
                ll_dict_store_clean(d, entries.entry_hash(d, i), i, TYPE_LONG)
            i += 1
    else:
        assert False


# ------- a port of CPython's dictobject.c's lookdict implementation -------
PERTURB_SHIFT = 5

FREE = 0
DELETED = 1
VALID_OFFSET = 2
MIN_INDEXES_MINUS_ENTRIES = VALID_OFFSET + 1

FLAG_LOOKUP = 0
FLAG_STORE = 1

@specialize.memo()
def _ll_ptr_to_array_of(T):
    return lltype.Ptr(lltype.GcArray(T))

@jit.look_inside_iff(lambda d, key, hash, store_flag, T:
                     jit.isvirtual(d) and jit.isconstant(key))
@jit.oopspec('ordereddict.lookup(d, key, hash, store_flag, T)')
def ll_dict_lookup(d, key, hash, store_flag, T):
    INDEXES = _ll_ptr_to_array_of(T)
    entries = d.entries
    indexes = lltype.cast_opaque_ptr(INDEXES, d.indexes)
    mask = len(indexes) - 1
    i = r_uint(hash & mask)
    # do the first try before any looping
    ENTRIES = lltype.typeOf(entries).TO
    direct_compare = not hasattr(ENTRIES, 'no_direct_compare')
    index = rffi.cast(lltype.Signed, indexes[intmask(i)])
    if index >= VALID_OFFSET:
        checkingkey = entries[index - VALID_OFFSET].key
        if direct_compare and checkingkey == key:
            return index - VALID_OFFSET   # found the entry
        if d.keyeq is not None and entries.entry_hash(d, index - VALID_OFFSET) == hash:
            # correct hash, maybe the key is e.g. a different pointer to
            # an equal object
            found = d.keyeq(checkingkey, key)
            #llop.debug_print(lltype.Void, "comparing keys", ll_debugrepr(checkingkey), ll_debugrepr(key), found)
            if d.paranoia:
                if (entries != d.entries or lltype.cast_opaque_ptr(llmemory.GCREF, indexes) != d.indexes or
                    not entries.valid(index - VALID_OFFSET) or
                    entries[index - VALID_OFFSET].key != checkingkey):
                    # the compare did major nasty stuff to the dict: start over
                    return ll_dict_lookup(d, key, hash, store_flag, T)
            if found:
                return index - VALID_OFFSET
        deletedslot = -1
    elif index == DELETED:
        deletedslot = intmask(i)
    else:
        # pristine entry -- lookup failed
        if store_flag == FLAG_STORE:
            indexes[i] = rffi.cast(T, d.num_ever_used_items + VALID_OFFSET)
        return -1

    # In the loop, a deleted entry (everused and not valid) is by far
    # (factor of 100s) the least likely outcome, so test for that last.
    perturb = r_uint(hash)
    while 1:
        # compute the next index using unsigned arithmetic
        i = (i << 2) + i + perturb + 1
        i = i & mask
        index = rffi.cast(lltype.Signed, indexes[intmask(i)])
        if index == FREE:
            if store_flag == FLAG_STORE:
                if deletedslot == -1:
                    deletedslot = intmask(i)
                indexes[deletedslot] = rffi.cast(T, d.num_ever_used_items +
                                                 VALID_OFFSET)
            return -1
        elif index >= VALID_OFFSET:
            checkingkey = entries[index - VALID_OFFSET].key
            if direct_compare and checkingkey == key:
                return index - VALID_OFFSET   # found the entry
            if d.keyeq is not None and entries.entry_hash(d, index - VALID_OFFSET) == hash:
                # correct hash, maybe the key is e.g. a different pointer to
                # an equal object
                found = d.keyeq(checkingkey, key)
                if d.paranoia:
                    if (entries != d.entries or lltype.cast_opaque_ptr(llmemory.GCREF, indexes) != d.indexes or
                        not entries.valid(index - VALID_OFFSET) or
                        entries[index - VALID_OFFSET].key != checkingkey):
                        # the compare did major nasty stuff to the dict: start over
                        return ll_dict_lookup(d, key, hash, store_flag, T)
                if found:
                    return index - VALID_OFFSET
        elif deletedslot == -1:
            deletedslot = intmask(i)
        perturb >>= PERTURB_SHIFT

def ll_dict_store_clean(d, hash, index, T):
    # a simplified version of ll_dict_lookup() which assumes that the
    # key is new, and the dictionary doesn't contain deleted entries.
    # It only finds the next free slot for the given hash.
    INDEXES = _ll_ptr_to_array_of(T)
    indexes = lltype.cast_opaque_ptr(INDEXES, d.indexes)
    mask = len(indexes) - 1
    i = r_uint(hash & mask)
    perturb = r_uint(hash)
    while rffi.cast(lltype.Signed, indexes[i]) != FREE:
        i = (i << 2) + i + perturb + 1
        i = i & mask
        perturb >>= PERTURB_SHIFT
    indexes[i] = rffi.cast(T, index + VALID_OFFSET)

# the following function is only called from _ll_dict_del, whose
# @jit.look_inside_iff condition should control when we get inside
# here with the jit
@jit.unroll_safe
def ll_dict_delete_by_entry_index(d, hash, locate_index, replace_with, T):
    # Another simplified version of ll_dict_lookup() which locates a
    # hashtable entry with the given 'index' stored in it, and deletes it.
    # This *should* be safe against evil user-level __eq__/__hash__
    # functions because the 'hash' argument here should be the one stored
    # into the directory, which is correct.
    INDEXES = _ll_ptr_to_array_of(T)
    indexes = lltype.cast_opaque_ptr(INDEXES, d.indexes)
    mask = len(indexes) - 1
    i = r_uint(hash & mask)
    perturb = r_uint(hash)
    locate_value = locate_index + VALID_OFFSET
    while rffi.cast(lltype.Signed, indexes[i]) != locate_value:
        assert rffi.cast(lltype.Signed, indexes[i]) != FREE
        i = (i << 2) + i + perturb + 1
        i = i & mask
        perturb >>= PERTURB_SHIFT
    indexes[i] = rffi.cast(T, replace_with)

# ____________________________________________________________
#
#  Irregular operations.

# Start the hashtable size at 16 rather than 8, as with rdict.py, because
# it is only an array of bytes
DICT_INITSIZE = 16


@specialize.memo()
def _ll_empty_array(DICT):
    """Memo function: cache a single prebuilt allocated empty array."""
    return DICT.entries.TO.allocate(0)

def ll_newdict(DICT):
    d = DICT.allocate()
    d.entries = _ll_empty_array(DICT)
    # Don't allocate an 'indexes' for empty dict.  It seems a typical
    # program contains tons of empty dicts, so this might be a memory win.
    d.num_live_items = 0
    d.num_ever_used_items = 0
    ll_no_initial_index(d)
    return d
OrderedDictRepr.ll_newdict = staticmethod(ll_newdict)

def ll_newdict_size(DICT, orig_length_estimate):
    length_estimate = (orig_length_estimate // 2) * 3
    n = DICT_INITSIZE
    while n < length_estimate:
        n *= 2
    d = DICT.allocate()
    d.entries = DICT.entries.TO.allocate(orig_length_estimate)
    ll_malloc_indexes_and_choose_lookup(d, n)
    d.num_live_items = 0
    d.num_ever_used_items = 0
    d.resize_counter = n * 2
    return d

# rpython.memory.lldict uses a dict based on Struct and Array
# instead of GcStruct and GcArray, which is done by using different
# 'allocate' and 'delete' adtmethod implementations than the ones below
def _ll_malloc_dict(DICT):
    return lltype.malloc(DICT)
def _ll_malloc_entries(ENTRIES, n):
    return lltype.malloc(ENTRIES, n, zero=True)
def _ll_free_entries(entries):
    pass


# ____________________________________________________________
#
#  Iteration.

def get_ll_dictiter(DICTPTR):
    return lltype.Ptr(lltype.GcStruct('dictiter',
                                      ('dict', DICTPTR),
                                      ('index', lltype.Signed)))

class DictIteratorRepr(AbstractDictIteratorRepr):

    def __init__(self, r_dict, variant="keys"):
        self.r_dict = r_dict
        self.variant = variant
        self.lowleveltype = get_ll_dictiter(r_dict.lowleveltype)
        if variant == 'reversed':
            self.ll_dictiter = ll_dictiter_reversed
            self._ll_dictnext = _ll_dictnext_reversed
        else:
            self.ll_dictiter = ll_dictiter
            self._ll_dictnext = _ll_dictnext


def ll_dictiter(ITERPTR, d):
    iter = lltype.malloc(ITERPTR.TO)
    iter.dict = d
    # initialize the index with usually 0, but occasionally a larger value
    iter.index = d.lookup_function_no >> FUNC_SHIFT
    return iter

@jit.look_inside_iff(lambda iter: jit.isvirtual(iter)
                     and (iter.dict is None or
                          jit.isvirtual(iter.dict)))
@jit.oopspec("odictiter.next(iter)")
def _ll_dictnext(iter):
    dict = iter.dict
    if dict:
        entries = dict.entries
        index = iter.index
        assert index >= 0
        entries_len = dict.num_ever_used_items
        while index < entries_len:
            nextindex = index + 1
            if entries.valid(index):
                iter.index = nextindex
                return index
            else:
                # In case of repeated iteration over the start of
                # a dict where the items get removed, like
                # collections.OrderedDict.popitem(last=False),
                # the hack below will increase the value stored in
                # the high bits of lookup_function_no and so the
                # next iteration will start at a higher value.
                # We should carefully reset these high bits to zero
                # as soon as we do something like ll_dict_reindex().
                if index == (dict.lookup_function_no >> FUNC_SHIFT):
                    dict.lookup_function_no += (1 << FUNC_SHIFT)
                # note that we can't have modified a FUNC_MUST_REINDEX
                # dict here because such dicts have no invalid entries
                ll_assert((dict.lookup_function_no & FUNC_MASK) !=
                      FUNC_MUST_REINDEX, "bad combination in _ll_dictnext")
            index = nextindex
        # clear the reference to the dict and prevent restarts
        iter.dict = lltype.nullptr(lltype.typeOf(iter).TO.dict.TO)
    raise StopIteration

def ll_dictiter_reversed(ITERPTR, d):
    iter = lltype.malloc(ITERPTR.TO)
    iter.dict = d
    iter.index = d.num_ever_used_items
    return iter

def _ll_dictnext_reversed(iter):
    dict = iter.dict
    if dict:
        entries = dict.entries
        index = iter.index - 1
        while index >= 0:
            if entries.valid(index):
                iter.index = index
                return index
            index = index - 1
        # clear the reference to the dict and prevent restarts
        iter.dict = lltype.nullptr(lltype.typeOf(iter).TO.dict.TO)
    raise StopIteration

# _____________________________________________________________
# methods

def ll_dict_get(dict, key, default):
    index = dict.lookup_function(dict, key, dict.keyhash(key), FLAG_LOOKUP)
    if index < 0:
        return default
    else:
        return dict.entries[index].value

def ll_dict_setdefault(dict, key, default):
    hash = dict.keyhash(key)
    index = dict.lookup_function(dict, key, hash, FLAG_STORE)
    if index < 0:
        _ll_dict_setitem_lookup_done(dict, key, default, hash, -1)
        return default
    else:
        return dict.entries[index].value

def ll_dict_copy(dict):
    ll_ensure_indexes(dict)

    DICT = lltype.typeOf(dict).TO
    newdict = DICT.allocate()
    newdict.entries = DICT.entries.TO.allocate(len(dict.entries))

    newdict.num_live_items = dict.num_live_items
    newdict.num_ever_used_items = dict.num_ever_used_items
    if hasattr(DICT, 'fnkeyeq'):
        newdict.fnkeyeq = dict.fnkeyeq
    if hasattr(DICT, 'fnkeyhash'):
        newdict.fnkeyhash = dict.fnkeyhash

    rgc.ll_arraycopy(dict.entries, newdict.entries, 0, 0,
                     newdict.num_ever_used_items)

    ll_dict_reindex(newdict, _ll_len_of_d_indexes(dict))
    return newdict
ll_dict_copy.oopspec = 'odict.copy(dict)'

def ll_dict_clear(d):
    if d.num_ever_used_items == 0:
        return
    DICT = lltype.typeOf(d).TO
    old_entries = d.entries
    d.entries = _ll_empty_array(DICT)
    # note: we can't remove the index here, because it is possible that
    # crazy Python code calls d.clear() from the method __eq__() called
    # from ll_dict_lookup(d).  Instead, stick to the rule that once a
    # dictionary has got an index, it will always have one.
    ll_malloc_indexes_and_choose_lookup(d, DICT_INITSIZE)
    d.num_live_items = 0
    d.num_ever_used_items = 0
    d.resize_counter = DICT_INITSIZE * 2
    # old_entries.delete() XXX
ll_dict_clear.oopspec = 'odict.clear(d)'

def ll_dict_update(dic1, dic2):
    if dic1 == dic2:
        return
    ll_ensure_indexes(dic2)    # needed for entries.entry_hash() below
    ll_prepare_dict_update(dic1, dic2.num_live_items)
    i = 0
    while i < dic2.num_ever_used_items:
        entries = dic2.entries
        if entries.valid(i):
            entry = entries[i]
            hash = entries.entry_hash(dic2, i)
            key = entry.key
            value = entry.value
            index = dic1.lookup_function(dic1, key, hash, FLAG_STORE)
            _ll_dict_setitem_lookup_done(dic1, key, value, hash, index)
        i += 1
ll_dict_update.oopspec = 'odict.update(dic1, dic2)'

def ll_prepare_dict_update(d, num_extra):
    # Prescale 'd' for 'num_extra' items, assuming that most items don't
    # collide.  If this assumption is false, 'd' becomes too large by at
    # most 'num_extra'.  The logic is based on:
    #      (d.resize_counter - 1) // 3 = room left in d
    #  so, if num_extra == 1, we need d.resize_counter > 3
    #      if num_extra == 2, we need d.resize_counter > 6  etc.
    # Note however a further hack: if num_extra <= d.num_live_items,
    # we avoid calling _ll_dict_resize_to here.  This is to handle
    # the case where dict.update() actually has a lot of collisions.
    # If num_extra is much greater than d.num_live_items the conditional_call
    # will trigger anyway, which is really the goal.
    ll_ensure_indexes(d)
    x = num_extra - d.num_live_items
    jit.conditional_call(d.resize_counter <= x * 3,
                         _ll_dict_resize_to, d, num_extra)

# this is an implementation of keys(), values() and items()
# in a single function.
# note that by specialization on func, three different
# and very efficient functions are created.

def recast(P, v):
    if isinstance(P, lltype.Ptr):
        return lltype.cast_pointer(P, v)
    else:
        return v

def _make_ll_keys_values_items(kind):
    def ll_kvi(LIST, dic):
        res = LIST.ll_newlist(dic.num_live_items)
        entries = dic.entries
        dlen = dic.num_ever_used_items
        items = res.ll_items()
        i = 0
        p = 0
        while i < dlen:
            if entries.valid(i):
                ELEM = lltype.typeOf(items).TO.OF
                if ELEM is not lltype.Void:
                    entry = entries[i]
                    if kind == 'items':
                        r = lltype.malloc(ELEM.TO)
                        r.item0 = recast(ELEM.TO.item0, entry.key)
                        r.item1 = recast(ELEM.TO.item1, entry.value)
                        items[p] = r
                    elif kind == 'keys':
                        items[p] = recast(ELEM, entry.key)
                    elif kind == 'values':
                        items[p] = recast(ELEM, entry.value)
                p += 1
            i += 1
        assert p == res.ll_length()
        return res
    ll_kvi.oopspec = 'odict.%s(dic)' % kind
    return ll_kvi

ll_dict_keys   = _make_ll_keys_values_items('keys')
ll_dict_values = _make_ll_keys_values_items('values')
ll_dict_items  = _make_ll_keys_values_items('items')

def ll_dict_contains(d, key):
    return ll_dict_contains_with_hash(d, key, d.keyhash(key))

def ll_dict_contains_with_hash(d, key, hash):
    i = d.lookup_function(d, key, hash, FLAG_LOOKUP)
    return i >= 0

def _ll_getnextitem(dic):
    if dic.num_live_items == 0:
        raise KeyError

    ll_ensure_indexes(dic)
    entries = dic.entries

    # find the last entry.  It's unclear if the loop below is still
    # needed nowadays, because 'num_ever_used_items - 1' should always
    # point to the last active item (we decrease it as needed in
    # _ll_dict_del).  Better safe than sorry.
    while True:
        i = dic.num_ever_used_items - 1
        if entries.valid(i):
            break
        dic.num_ever_used_items -= 1

    return i

def ll_dict_popitem(ELEM, dic):
    i = _ll_getnextitem(dic)
    entry = dic.entries[i]
    r = lltype.malloc(ELEM.TO)
    r.item0 = recast(ELEM.TO.item0, entry.key)
    r.item1 = recast(ELEM.TO.item1, entry.value)
    _ll_dict_del(dic, dic.entries.entry_hash(dic, i), i)
    return r

def ll_dict_pop(dic, key):
    hash = dic.keyhash(key)
    index = dic.lookup_function(dic, key, hash, FLAG_LOOKUP)
    if index < 0:
        raise KeyError
    value = dic.entries[index].value
    _ll_dict_del(dic, hash, index)
    return value

def ll_dict_pop_default(dic, key, dfl):
    hash = dic.keyhash(key)
    index = dic.lookup_function(dic, key, hash, FLAG_LOOKUP)
    if index < 0:
        return dfl
    value = dic.entries[index].value
    _ll_dict_del(dic, hash, index)
    return value

def ll_dict_move_to_end(d, key, last):
    if last:
        ll_dict_move_to_last(d, key)
    else:
        ll_dict_move_to_first(d, key)

def ll_dict_move_to_last(d, key):
    hash = d.keyhash(key)
    old_index = d.lookup_function(d, key, hash, FLAG_LOOKUP)
    if old_index < 0:
        raise KeyError

    if old_index == d.num_ever_used_items - 1:
        return

    # remove the entry at the old position
    old_entry = d.entries[old_index]
    key = old_entry.key
    value = old_entry.value
    _ll_dict_del_entry(d, old_index)

    # note a corner case: it is possible that 'replace_with' is just too
    # large to fit in the type T used so far for the index.  But in that
    # case, the list 'd.entries' is full, and the following call to
    # _ll_dict_setitem_lookup_done() will necessarily reindex the dict.
    # So in that case, this value of 'replace_with' should be ignored.
    ll_call_delete_by_entry_index(d, hash, old_index,
            replace_with = VALID_OFFSET + d.num_ever_used_items)
    _ll_dict_setitem_lookup_done(d, key, value, hash, -1)

def ll_dict_move_to_first(d, key):
    # In this function, we might do a bit more than the strict minimum
    # of walks over parts of the array, trying to keep the code at least
    # semi-reasonable, while the goal is still amortized constant-time
    # over many calls.

    # Call ll_dict_remove_deleted_items() first if there are too many
    # deleted items.  Not a perfect solution, because lookup_function()
    # might do random things with the dict and create many new deleted
    # items.  Still, should be fine, because nothing crucially depends
    # on this: the goal is to avoid the dictionary's list growing
    # forever.
    if d.num_live_items < len(d.entries) // 2 - 16:
        ll_dict_remove_deleted_items(d)

    hash = d.keyhash(key)
    old_index = d.lookup_function(d, key, hash, FLAG_LOOKUP)
    if old_index <= 0:
        if old_index < 0:
            raise KeyError
        else:
            return

    # the goal of the following is to set 'idst' to the number of
    # deleted entries at the beginning, ensuring 'idst > 0'
    must_reindex = False
    if d.entries.valid(0):
        # the first entry is valid, so we need to make room before.
        new_allocated = _overallocate_entries_len(d.num_ever_used_items)
        idst = ((new_allocated - d.num_ever_used_items) * 3) // 4
        ll_assert(idst > 0, "overallocate did not do enough")
        newitems = lltype.malloc(lltype.typeOf(d).TO.entries.TO, new_allocated)
        rgc.ll_arraycopy(d.entries, newitems, 0, idst, d.num_ever_used_items)
        d.entries = newitems
        i = 0
        while i < idst:
            d.entries.mark_deleted(i)
            i += 1
        d.num_ever_used_items += idst
        old_index += idst
        must_reindex = True
        idst -= 1
    else:
        idst = d.lookup_function_no >> FUNC_SHIFT
        # All entries in range(0, idst) are deleted.  Check if more are
        while not d.entries.valid(idst):
            idst += 1
        if idst == old_index:
            d.lookup_function_no = ((d.lookup_function_no & FUNC_MASK) |
                                    (old_index << FUNC_SHIFT))
            return
        idst -= 1
        d.lookup_function_no = ((d.lookup_function_no & FUNC_MASK) |
                                (idst << FUNC_SHIFT))

    # remove the entry at the old position
    ll_assert(d.entries.valid(old_index),
              "ll_dict_move_to_first: lost old_index")
    ENTRY = lltype.typeOf(d.entries).TO.OF
    old_entry = d.entries[old_index]
    key = old_entry.key
    value = old_entry.value
    if hasattr(ENTRY, 'f_hash'):
        ll_assert(old_entry.f_hash == hash,
                  "ll_dict_move_to_first: bad hash")
    _ll_dict_del_entry(d, old_index)

    # put the entry at its new position
    ll_assert(not d.entries.valid(idst),
              "ll_dict_move_to_first: overwriting idst")
    new_entry = d.entries[idst]
    new_entry.key = key
    new_entry.value = value
    if hasattr(ENTRY, 'f_hash'):
        new_entry.f_hash = hash
    if hasattr(ENTRY, 'f_valid'):
        new_entry.f_valid = True
    d.num_live_items += 1

    # fix the index
    if must_reindex:
        ll_dict_reindex(d, _ll_len_of_d_indexes(d))
    else:
        ll_call_delete_by_entry_index(d, hash, old_index,
                replace_with = VALID_OFFSET + idst)
