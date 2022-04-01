from rpython.flowspace.model import Constant
from rpython.rtyper.lltypesystem import lltype, llmemory, rdict
from rpython.rtyper.lltypesystem.llmemory import weakref_create, weakref_deref
from rpython.rtyper import rclass
from rpython.rtyper.error import TyperError
from rpython.rtyper.rclass import getinstancerepr
from rpython.rtyper.rmodel import Repr
from rpython.rlib.rweakref import RWeakValueDictionary
from rpython.rlib import jit


class WeakValueDictRepr(Repr):
    def __init__(self, rtyper, r_key):
        self.rtyper = rtyper
        self.r_key = r_key

        fasthashfn = r_key.get_ll_fasthash_function()
        self.ll_keyhash = r_key.get_ll_hash_function()
        ll_keyeq = lltype.staticAdtMethod(r_key.get_ll_eq_function())

        def ll_valid(entries, i):
            value = entries[i].value
            return bool(value) and bool(weakref_deref(rclass.OBJECTPTR, value))

        def ll_everused(entries, i):
            return bool(entries[i].value)

        def ll_hash(entries, i):
            return fasthashfn(entries[i].key)

        entrymeths = {
            'allocate': lltype.typeMethod(rdict._ll_malloc_entries),
            'delete': rdict._ll_free_entries,
            'valid': ll_valid,
            'everused': ll_everused,
            'hash': ll_hash,
            }
        WEAKDICTENTRY = lltype.Struct("weakdictentry",
                                      ("key", r_key.lowleveltype),
                                      ("value", llmemory.WeakRefPtr))
        WEAKDICTENTRYARRAY = lltype.GcArray(WEAKDICTENTRY,
                                            adtmeths=entrymeths,
                                            hints={'weakarray': 'value'})
        # NB. the 'hints' is not used so far ^^^

        dictmeths = {
            'll_get': self.ll_get,
            'll_set': self.ll_set,
            'keyeq': ll_keyeq,
            'paranoia': False,
            }

        self.WEAKDICT = lltype.GcStruct(
            "weakvaldict",
            ("num_items", lltype.Signed),
            ("resize_counter", lltype.Signed),
            ("entries", lltype.Ptr(WEAKDICTENTRYARRAY)),
            adtmeths=dictmeths)

        self.lowleveltype = lltype.Ptr(self.WEAKDICT)
        self.dict_cache = {}

    def convert_const(self, weakdict):
        if weakdict is None:
            return lltype.nullptr(self.WEAKDICT)
        if not isinstance(weakdict, RWeakValueDictionary):
            raise TyperError("expected an RWeakValueDictionary: %r" % (
                weakdict,))
        try:
            key = Constant(weakdict)
            return self.dict_cache[key]
        except KeyError:
            self.setup()
            l_dict = self.ll_new_weakdict()
            self.dict_cache[key] = l_dict
            bk = self.rtyper.annotator.bookkeeper
            classdef = bk.getuniqueclassdef(weakdict._valueclass)
            r_value = getinstancerepr(self.rtyper, classdef)
            any_value = False
            for dictkey, dictvalue in weakdict._dict.items():
                llkey = self.r_key.convert_const(dictkey)
                llvalue = r_value.convert_const(dictvalue)
                if llvalue:
                    llvalue = lltype.cast_pointer(rclass.OBJECTPTR, llvalue)
                    self.ll_set_nonnull(l_dict, llkey, llvalue)
                    any_value = True
            if any_value:
                l_dict.resize_counter = -1
            return l_dict

    def rtype_method_get(self, hop):
        v_d, v_key = hop.inputargs(self, self.r_key)
        hop.exception_cannot_occur()
        v_result = hop.gendirectcall(self.ll_get, v_d, v_key)
        v_result = hop.genop("cast_pointer", [v_result],
                             resulttype=hop.r_result.lowleveltype)
        return v_result

    def rtype_method_set(self, hop):
        r_object = getinstancerepr(self.rtyper, None)
        v_d, v_key, v_value = hop.inputargs(self, self.r_key, r_object)
        hop.exception_cannot_occur()
        if hop.args_s[2].is_constant() and hop.args_s[2].const is None:
            hop.gendirectcall(self.ll_set_null, v_d, v_key)
        else:
            hop.gendirectcall(self.ll_set, v_d, v_key, v_value)


    # ____________________________________________________________

    @jit.dont_look_inside
    def ll_new_weakdict(self):
        d = lltype.malloc(self.WEAKDICT)
        d.entries = self.WEAKDICT.entries.TO.allocate(rdict.DICT_INITSIZE)
        d.num_items = 0
        d.resize_counter = rdict.DICT_INITSIZE * 2
        return d

    @jit.dont_look_inside
    def ll_get(self, d, llkey):
        if d.resize_counter < 0:
            self.ll_weakdict_rehash_after_translation(d)
        hash = self.ll_keyhash(llkey)
        i = rdict.ll_dict_lookup(d, llkey, hash) & rdict.MASK
        #llop.debug_print(lltype.Void, i, 'get')
        valueref = d.entries[i].value
        if valueref:
            return weakref_deref(rclass.OBJECTPTR, valueref)
        else:
            return lltype.nullptr(rclass.OBJECTPTR.TO)

    @jit.dont_look_inside
    def ll_set(self, d, llkey, llvalue):
        if llvalue:
            self.ll_set_nonnull(d, llkey, llvalue)
        else:
            self.ll_set_null(d, llkey)

    @jit.dont_look_inside
    def ll_set_nonnull(self, d, llkey, llvalue):
        if d.resize_counter < 0:
            self.ll_weakdict_rehash_after_translation(d)
        hash = self.ll_keyhash(llkey)
        valueref = weakref_create(llvalue)    # GC effects here, before the rest
        i = rdict.ll_dict_lookup(d, llkey, hash) & rdict.MASK
        everused = d.entries.everused(i)
        d.entries[i].key = llkey
        d.entries[i].value = valueref
        #llop.debug_print(lltype.Void, i, 'stored')
        if not everused:
            d.resize_counter -= 3
            if d.resize_counter <= 0:
                #llop.debug_print(lltype.Void, 'RESIZE')
                self.ll_weakdict_resize(d)

    @jit.dont_look_inside
    def ll_set_null(self, d, llkey):
        if d.resize_counter < 0:
            self.ll_weakdict_rehash_after_translation(d)
        hash = self.ll_keyhash(llkey)
        i = rdict.ll_dict_lookup(d, llkey, hash) & rdict.MASK
        if d.entries.everused(i):
            # If the entry was ever used, clean up its key and value.
            # We don't store a NULL value, but a dead weakref, because
            # the entry must still be marked as everused().
            d.entries[i].value = llmemory.dead_wref
            if isinstance(self.r_key.lowleveltype, lltype.Ptr):
                d.entries[i].key = self.r_key.convert_const(None)
            else:
                d.entries[i].key = self.r_key.convert_const(0)
            #llop.debug_print(lltype.Void, i, 'zero')

    def ll_weakdict_resize(self, d):
        # first set num_items to its correct, up-to-date value
        entries = d.entries
        num_items = 0
        for i in range(len(entries)):
            if entries.valid(i):
                num_items += 1
        d.num_items = num_items
        rdict.ll_dict_resize(d)

    def ll_weakdict_rehash_after_translation(self, d):
        # recompute all hashes.  See comment in rordereddict.py,
        # ll_dict_rehash_after_translation().
        entries = d.entries
        for i in range(len(entries)):
            self.ll_keyhash(entries[i].key)
        self.ll_weakdict_resize(d)
        assert d.resize_counter >= 0

def specialize_make_weakdict(hop):
    hop.exception_cannot_occur()
    v_d = hop.gendirectcall(hop.r_result.ll_new_weakdict)
    return v_d

