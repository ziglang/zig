from rpython.annotator import model as annmodel
from rpython.rtyper import rmodel
from rpython.rtyper.lltypesystem import lltype


class __extend__(annmodel.SomeDict):
    def get_dict_repr(self):
        from rpython.rtyper.lltypesystem.rdict import DictRepr

        return DictRepr

    def rtyper_makerepr(self, rtyper):
        dictkey = self.dictdef.dictkey
        dictvalue = self.dictdef.dictvalue
        s_key = dictkey.s_value
        s_value = dictvalue.s_value
        force_non_null = self.dictdef.force_non_null
        simple_hash_eq = self.dictdef.simple_hash_eq
        if dictkey.custom_eq_hash:
            custom_eq_hash = lambda: (rtyper.getrepr(dictkey.s_rdict_eqfn),
                                      rtyper.getrepr(dictkey.s_rdict_hashfn))
        else:
            custom_eq_hash = None
        return self.get_dict_repr()(rtyper, lambda: rtyper.getrepr(s_key),
                        lambda: rtyper.getrepr(s_value), dictkey, dictvalue,
                        custom_eq_hash, force_non_null, simple_hash_eq)

    def rtyper_makekey(self):
        self.dictdef.dictkey  .dont_change_any_more = True
        self.dictdef.dictvalue.dont_change_any_more = True
        return (self.__class__, self.dictdef.dictkey, self.dictdef.dictvalue)

class __extend__(annmodel.SomeOrderedDict):
    def get_dict_repr(self):
        from rpython.rtyper.lltypesystem.rordereddict import OrderedDictRepr

        return OrderedDictRepr

class AbstractDictRepr(rmodel.Repr):

    def pickrepr(self, item_repr):
        if self.custom_eq_hash:
            return item_repr, item_repr
        else:
            return self._externalvsinternal(self.rtyper, item_repr)

    pickkeyrepr = pickrepr

    def compact_repr(self):
        return 'DictR %s %s' % (self.key_repr.compact_repr(),
                                self.value_repr.compact_repr())

    def recast_value(self, llops, v):
        return llops.convertvar(v, self.value_repr, self.external_value_repr)

    def recast_key(self, llops, v):
        return llops.convertvar(v, self.key_repr, self.external_key_repr)


def rtype_newdict(hop):
    hop.inputargs()    # no arguments expected
    r_dict = hop.r_result
    cDICT = hop.inputconst(lltype.Void, r_dict.DICT)
    v_result = hop.gendirectcall(r_dict.ll_newdict, cDICT)
    return v_result


class AbstractDictIteratorRepr(rmodel.IteratorRepr):

    def newiter(self, hop):
        v_dict, = hop.inputargs(self.r_dict)
        citerptr = hop.inputconst(lltype.Void, self.lowleveltype)
        return hop.gendirectcall(self.ll_dictiter, citerptr, v_dict)

    def rtype_next(self, hop):
        v_iter, = hop.inputargs(self)
        # record that we know about these two possible exceptions
        hop.has_implicit_exception(StopIteration)
        hop.has_implicit_exception(RuntimeError)
        hop.exception_is_here()
        v_index = hop.gendirectcall(self._ll_dictnext, v_iter)
        #
        # read 'iter.dict.entries'
        DICT = self.lowleveltype.TO.dict
        c_dict = hop.inputconst(lltype.Void, 'dict')
        v_dict = hop.genop('getfield', [v_iter, c_dict], resulttype=DICT)
        ENTRIES = DICT.TO.entries
        c_entries = hop.inputconst(lltype.Void, 'entries')
        v_entries = hop.genop('getfield', [v_dict, c_entries],
                              resulttype=ENTRIES)
        # call the correct variant_*() method
        method = getattr(self, 'variant_' + self.variant)
        return method(hop, ENTRIES, v_entries, v_dict, v_index)

    def get_tuple_result(self, hop, items_v):
        # this allocates the tuple for the result, directly in the function
        # where it will be used (likely).  This will let it be removed.
        if hop.r_result.lowleveltype is lltype.Void:
            return hop.inputconst(lltype.Void, None)
        c1 = hop.inputconst(lltype.Void, hop.r_result.lowleveltype.TO)
        cflags = hop.inputconst(lltype.Void, {'flavor': 'gc'})
        v_result = hop.genop('malloc', [c1, cflags],
                             resulttype = hop.r_result.lowleveltype)
        for i, v_item in enumerate(items_v):
            ITEM = getattr(v_result.concretetype.TO, 'item%d' % i)
            if ITEM != v_item.concretetype:
                assert isinstance(ITEM, lltype.Ptr)
                v_item = hop.genop('cast_pointer', [v_item], resulttype=ITEM)
            c_item = hop.inputconst(lltype.Void, 'item%d' % i)
            hop.genop('setfield', [v_result, c_item, v_item])
        return v_result

    def variant_keys(self, hop, ENTRIES, v_entries, v_dict, v_index):
        KEY = ENTRIES.TO.OF.key
        c_key = hop.inputconst(lltype.Void, 'key')
        v_key = hop.genop('getinteriorfield', [v_entries, v_index, c_key],
                          resulttype=KEY)
        return self.r_dict.recast_key(hop.llops, v_key)

    variant_reversed = variant_keys

    def variant_values(self, hop, ENTRIES, v_entries, v_dict, v_index):
        VALUE = ENTRIES.TO.OF.value
        c_value = hop.inputconst(lltype.Void, 'value')
        v_value = hop.genop('getinteriorfield', [v_entries,v_index,c_value],
                            resulttype=VALUE)
        return self.r_dict.recast_value(hop.llops, v_value)

    def variant_items(self, hop, ENTRIES, v_entries, v_dict, v_index):
        v_key = self.variant_keys(hop, ENTRIES, v_entries, v_dict, v_index)
        v_value = self.variant_values(hop, ENTRIES, v_entries, v_dict, v_index)
        return self.get_tuple_result(hop, (v_key, v_value))

    def variant_hashes(self, hop, ENTRIES, v_entries, v_dict, v_index):
        # there is not really a variant 'hashes', but this method is
        # convenient for the following variants
        return hop.gendirectcall(ENTRIES.TO.entry_hash, v_entries, v_dict, v_index)

    def variant_keys_with_hash(self, hop, ENTRIES, v_entries, v_dict, v_index):
        v_key = self.variant_keys(hop, ENTRIES, v_entries, v_dict, v_index)
        v_hash = self.variant_hashes(hop, ENTRIES, v_entries, v_dict, v_index)
        return self.get_tuple_result(hop, (v_key, v_hash))

    def variant_items_with_hash(self, hop, ENTRIES, v_entries, v_dict, v_index):
        v_key = self.variant_keys(hop, ENTRIES, v_entries, v_dict, v_index)
        v_value = self.variant_values(hop, ENTRIES, v_entries, v_dict, v_index)
        v_hash = self.variant_hashes(hop, ENTRIES, v_entries, v_dict, v_index)
        return self.get_tuple_result(hop, (v_key, v_value, v_hash))
