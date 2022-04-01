from rpython.annotator import model as annmodel
from rpython.flowspace.model import Constant
from rpython.rlib import rgc, jit, types
from rpython.rtyper.debug import ll_assert
from rpython.rlib.objectmodel import malloc_zero_filled, enforceargs, specialize
from rpython.rlib.signature import signature
from rpython.rlib.rarithmetic import ovfcheck, widen, r_uint, intmask
from rpython.rlib.rarithmetic import int_force_ge_zero
from rpython.rtyper.annlowlevel import ADTInterface
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem.lltype import typeOf, Ptr, Void, Signed, Bool
from rpython.rtyper.lltypesystem.lltype import nullptr, Char, UniChar, Number
from rpython.rtyper.rmodel import Repr, IteratorRepr
from rpython.rtyper.rint import IntegerRepr
from rpython.rtyper.rstr import AbstractStringRepr, AbstractCharRepr
from rpython.tool.pairtype import pairtype, pair


ADTIFixedList = ADTInterface(None, {
    'll_newlist':      (['SELF', Signed        ], 'self'),
    'll_length':       (['self'                ], Signed),
    'll_getitem_fast': (['self', Signed        ], 'item'),
    'll_setitem_fast': (['self', Signed, 'item'], Void),
})
ADTIList = ADTInterface(ADTIFixedList, {
    # grow the length if needed, overallocating a bit
    '_ll_resize_ge':   (['self', Signed        ], Void),
    # shrink the length; if reallocating, don't keep any overallocation
    '_ll_resize_le':   (['self', Signed        ], Void),
    # resize to exactly the given size; no overallocation
    '_ll_resize':      (['self', Signed        ], Void),
    # give a hint about the size; does overallocation if growing
    '_ll_resize_hint': (['self', Signed        ], Void),
})


def dum_checkidx(): pass
def dum_nocheck(): pass


class __extend__(annmodel.SomeList):
    def rtyper_makerepr(self, rtyper):
        listitem = self.listdef.listitem
        s_value = listitem.s_value
        if (listitem.range_step is not None and not listitem.mutated and
                not isinstance(s_value, annmodel.SomeImpossibleValue)):
            from rpython.rtyper.lltypesystem.rrange import RangeRepr
            return RangeRepr(listitem.range_step)
        else:
            # cannot do the rtyper.getrepr() call immediately, for the case
            # of recursive structures -- i.e. if the listdef contains itself
            from rpython.rtyper.lltypesystem.rlist import ListRepr, FixedSizeListRepr
            item_repr = lambda: rtyper.getrepr(listitem.s_value)
            if self.listdef.listitem.resized:
                return ListRepr(rtyper, item_repr, listitem)
            else:
                return FixedSizeListRepr(rtyper, item_repr, listitem)

    def rtyper_makekey(self):
        self.listdef.listitem.dont_change_any_more = True
        return self.__class__, self.listdef.listitem


class AbstractBaseListRepr(Repr):
    eq_func_cache = None

    def recast(self, llops, v):
        return llops.convertvar(v, self.item_repr, self.external_item_repr)

    def convert_const(self, listobj):
        # get object from bound list method
        if listobj is None:
            return self.null_const()
        if not isinstance(listobj, list):
            raise TyperError("expected a list: %r" % (listobj,))
        try:
            key = Constant(listobj)
            return self.list_cache[key]
        except KeyError:
            self.setup()
            n = len(listobj)
            result = self.prepare_const(n)
            self.list_cache[key] = result
            r_item = self.item_repr
            if r_item.lowleveltype is not Void:
                for i in range(n):
                    x = listobj[i]
                    result.ll_setitem_fast(i, r_item.convert_const(x))
            return result

    def null_const(self):
        raise NotImplementedError

    def prepare_const(self, nitems):
        raise NotImplementedError

    def ll_str(self, l):
        constant = self.rstr_ll.ll_constant
        start    = self.rstr_ll.ll_build_start
        push     = self.rstr_ll.ll_build_push
        finish   = self.rstr_ll.ll_build_finish

        length = l.ll_length()
        if length == 0:
            return constant("[]")

        buf = start(2 * length + 1)
        push(buf, constant("["), 0)
        item_repr = self.item_repr
        i = 0
        while i < length:
            if i > 0:
                push(buf, constant(", "), 2 * i)
            item = l.ll_getitem_fast(i)
            push(buf, item_repr.ll_str(item), 2 * i + 1)
            i += 1
        push(buf, constant("]"), 2 * length)
        return finish(buf)

    def rtype_bltn_list(self, hop):
        v_lst = hop.inputarg(self, 0)
        cRESLIST = hop.inputconst(Void, hop.r_result.LIST)
        hop.exception_is_here()
        return hop.gendirectcall(ll_copy, cRESLIST, v_lst)

    def rtype_len(self, hop):
        v_lst, = hop.inputargs(self)
        if hop.args_s[0].listdef.listitem.resized:
            ll_func = ll_len
        else:
            ll_func = ll_len_foldable
        return hop.gendirectcall(ll_func, v_lst)

    def rtype_bool(self, hop):
        v_lst, = hop.inputargs(self)
        if hop.args_s[0].listdef.listitem.resized:
            ll_func = ll_list_is_true
        else:
            ll_func = ll_list_is_true_foldable
        return hop.gendirectcall(ll_func, v_lst)

    def rtype_method_reverse(self, hop):
        v_lst, = hop.inputargs(self)
        hop.exception_cannot_occur()
        hop.gendirectcall(ll_reverse,v_lst)

    def rtype_method_remove(self, hop):
        v_lst, v_value = hop.inputargs(self, self.item_repr)
        hop.has_implicit_exception(ValueError)   # record that we know about it
        hop.exception_is_here()
        return hop.gendirectcall(ll_listremove, v_lst, v_value,
                                 self.get_eqfunc())

    def rtype_method_index(self, hop):
        v_lst, v_value = hop.inputargs(self, self.item_repr)
        hop.has_implicit_exception(ValueError)   # record that we know about it
        hop.exception_is_here()
        return hop.gendirectcall(ll_listindex, v_lst, v_value, self.get_eqfunc())

    def get_ll_eq_function(self):
        result = self.eq_func_cache
        if result is not None:
            return result
        def list_eq(l1, l2):
            return ll_listeq(l1, l2, item_eq_func)
        self.eq_func_cache = list_eq
        # ^^^ do this first, before item_repr.get_ll_eq_function()
        item_eq_func = self.item_repr.get_ll_eq_function()
        return list_eq

    def _get_v_maxlength(self, hop):
        from rpython.rtyper.rint import signed_repr
        v_iterable = hop.args_v[1]
        s_iterable = hop.args_s[1]
        r_iterable = hop.args_r[1]
        hop2 = hop.copy()
        while hop2.nb_args > 0:
            hop2.r_s_popfirstarg()
        hop2.v_s_insertfirstarg(v_iterable, s_iterable)
        hop2.r_result = signed_repr
        v_maxlength = r_iterable.rtype_len(hop2)
        return v_maxlength


class AbstractListRepr(AbstractBaseListRepr):

    def rtype_method_append(self, hop):
        v_lst, v_value = hop.inputargs(self, self.item_repr)
        hop.exception_cannot_occur()
        hop.gendirectcall(ll_append, v_lst, v_value)

    def rtype_method_insert(self, hop):
        v_lst, v_index, v_value = hop.inputargs(self, Signed, self.item_repr)
        arg1 = hop.args_s[1]
        args = v_lst, v_index, v_value
        if arg1.is_constant() and arg1.const == 0:
            llfn = ll_prepend
            args = v_lst, v_value
        elif arg1.nonneg:
            llfn = ll_insert_nonneg
        else:
            raise TyperError("insert() index must be proven non-negative")
        hop.exception_cannot_occur()
        hop.gendirectcall(llfn, *args)

    def rtype_method_extend(self, hop):
        v_lst1, v_lst2 = hop.inputargs(*hop.args_r)
        hop.exception_cannot_occur()
        hop.gendirectcall(ll_extend, v_lst1, v_lst2)

    def rtype_method_pop(self, hop):
        if hop.has_implicit_exception(IndexError):
            spec = dum_checkidx
        else:
            spec = dum_nocheck
        v_func = hop.inputconst(Void, spec)
        if hop.nb_args == 2:
            args = hop.inputargs(self, Signed)
            assert hasattr(args[1], 'concretetype')
            arg1 = hop.args_s[1]
            if arg1.is_constant() and arg1.const == 0:
                llfn = ll_pop_zero
                args = args[:1]
            elif hop.args_s[1].nonneg:
                llfn = ll_pop_nonneg
            else:
                llfn = ll_pop
        else:
            args = hop.inputargs(self)
            llfn = ll_pop_default
        hop.exception_is_here()
        v_res = hop.gendirectcall(llfn, v_func, *args)
        return self.recast(hop.llops, v_res)


class AbstractFixedSizeListRepr(AbstractBaseListRepr):
    pass


class __extend__(pairtype(AbstractBaseListRepr, Repr)):

    def rtype_contains((r_lst, _), hop):
        v_lst, v_any = hop.inputargs(r_lst, r_lst.item_repr)
        hop.exception_cannot_occur()
        return hop.gendirectcall(ll_listcontains, v_lst, v_any, r_lst.get_eqfunc())

class __extend__(pairtype(AbstractBaseListRepr, IntegerRepr)):

    def rtype_getitem((r_lst, r_int), hop, checkidx=False):
        v_lst, v_index = hop.inputargs(r_lst, Signed)
        if checkidx:
            hop.exception_is_here()
            spec = dum_checkidx
        else:
            spec = dum_nocheck
            hop.exception_cannot_occur()
        if hop.args_s[0].listdef.listitem.mutated:
            basegetitem = ll_getitem_fast
        else:
            basegetitem = ll_getitem_foldable_nonneg

        if hop.args_s[1].nonneg:
            llfn = ll_getitem_nonneg
        else:
            llfn = ll_getitem
        c_func_marker = hop.inputconst(Void, spec)
        c_basegetitem = hop.inputconst(Void, basegetitem)
        v_res = hop.gendirectcall(llfn, c_func_marker, c_basegetitem, v_lst, v_index)
        return r_lst.recast(hop.llops, v_res)

    def rtype_getitem_idx((r_lst, r_int), hop):
        return pair(r_lst, r_int).rtype_getitem(hop, checkidx=True)

    def rtype_setitem((r_lst, r_int), hop):
        if hop.has_implicit_exception(IndexError):
            spec = dum_checkidx
        else:
            spec = dum_nocheck
        v_func = hop.inputconst(Void, spec)
        v_lst, v_index, v_item = hop.inputargs(r_lst, Signed, r_lst.item_repr)
        if hop.args_s[1].nonneg:
            llfn = ll_setitem_nonneg
        else:
            llfn = ll_setitem
        hop.exception_is_here()
        return hop.gendirectcall(llfn, v_func, v_lst, v_index, v_item)

    def rtype_mul((r_lst, r_int), hop):
        cRESLIST = hop.inputconst(Void, hop.r_result.LIST)
        v_lst, v_factor = hop.inputargs(r_lst, Signed)
        return hop.gendirectcall(ll_mul, cRESLIST, v_lst, v_factor)

class __extend__(pairtype(IntegerRepr, AbstractBaseListRepr)):
    def rtype_mul((r_int, r_lst), hop):
        cRESLIST = hop.inputconst(Void, hop.r_result.LIST)
        v_factor, v_lst = hop.inputargs(Signed, r_lst)
        return hop.gendirectcall(ll_mul, cRESLIST, v_lst, v_factor)

class __extend__(pairtype(AbstractListRepr, IntegerRepr)):

    def rtype_delitem((r_lst, r_int), hop):
        if hop.has_implicit_exception(IndexError):
            spec = dum_checkidx
        else:
            spec = dum_nocheck
        v_func = hop.inputconst(Void, spec)
        v_lst, v_index = hop.inputargs(r_lst, Signed)
        if hop.args_s[1].nonneg:
            llfn = ll_delitem_nonneg
        else:
            llfn = ll_delitem
        hop.exception_is_here()
        return hop.gendirectcall(llfn, v_func, v_lst, v_index)

    def rtype_inplace_mul((r_lst, r_int), hop):
        v_lst, v_factor = hop.inputargs(r_lst, Signed)
        return hop.gendirectcall(ll_inplace_mul, v_lst, v_factor)


class __extend__(pairtype(AbstractBaseListRepr, AbstractBaseListRepr)):
    def convert_from_to((r_lst1, r_lst2), v, llops):
        if r_lst1.listitem is None or r_lst2.listitem is None:
            return NotImplemented
        if r_lst1.listitem is not r_lst2.listitem:
            return NotImplemented
        return v

    def rtype_eq((r_lst1, r_lst2), hop):
        assert r_lst1.item_repr == r_lst2.item_repr
        v_lst1, v_lst2 = hop.inputargs(r_lst1, r_lst2)
        return hop.gendirectcall(ll_listeq, v_lst1, v_lst2, r_lst1.get_eqfunc())

    def rtype_ne((r_lst1, r_lst2), hop):
        assert r_lst1.item_repr == r_lst2.item_repr
        v_lst1, v_lst2 = hop.inputargs(r_lst1, r_lst2)
        flag = hop.gendirectcall(ll_listeq, v_lst1, v_lst2, r_lst1.get_eqfunc())
        return hop.genop('bool_not', [flag], resulttype=Bool)


def rtype_newlist(hop, v_sizehint=None):
    from rpython.rtyper.lltypesystem.rlist import newlist
    nb_args = hop.nb_args
    r_list = hop.r_result
    r_listitem = r_list.item_repr
    items_v = [hop.inputarg(r_listitem, arg=i) for i in range(nb_args)]
    return newlist(hop.llops, r_list, items_v, v_sizehint=v_sizehint)

def rtype_alloc_and_set(hop):
    r_list = hop.r_result
    v_count, v_item = hop.inputargs(Signed, r_list.item_repr)
    cLIST = hop.inputconst(Void, r_list.LIST)
    return hop.gendirectcall(ll_alloc_and_set, cLIST, v_count, v_item)


class __extend__(pairtype(AbstractBaseListRepr, AbstractBaseListRepr)):

    def rtype_add((r_lst1, r_lst2), hop):
        v_lst1, v_lst2 = hop.inputargs(r_lst1, r_lst2)
        cRESLIST = hop.inputconst(Void, hop.r_result.LIST)
        return hop.gendirectcall(ll_concat, cRESLIST, v_lst1, v_lst2)

class __extend__(pairtype(AbstractListRepr, AbstractBaseListRepr)):

    def rtype_inplace_add((r_lst1, r_lst2), hop):
        v_lst1, v_lst2 = hop.inputargs(r_lst1, r_lst2)
        hop.gendirectcall(ll_extend, v_lst1, v_lst2)
        return v_lst1

class __extend__(pairtype(AbstractListRepr, AbstractStringRepr)):

    def rtype_inplace_add((r_lst1, r_str2), hop):
        if r_lst1.item_repr.lowleveltype not in (Char, UniChar):
            raise TyperError('"lst += string" only supported with a list '
                             'of chars or unichars')
        string_repr = r_str2.repr
        v_lst1, v_str2 = hop.inputargs(r_lst1, string_repr)
        c_strlen  = hop.inputconst(Void, string_repr.ll.ll_strlen)
        c_stritem = hop.inputconst(Void, string_repr.ll.ll_stritem_nonneg)
        hop.gendirectcall(ll_extend_with_str, v_lst1, v_str2,
                          c_strlen, c_stritem)
        return v_lst1

    def rtype_extend_with_str_slice((r_lst1, r_str2), hop):
        from rpython.rtyper.lltypesystem.rstr import string_repr
        if r_lst1.item_repr.lowleveltype not in (Char, UniChar):
            raise TyperError('"lst += string" only supported with a list '
                             'of chars or unichars')
        v_lst1 = hop.inputarg(r_lst1, arg=0)
        v_str2 = hop.inputarg(string_repr, arg=3)
        kind, vlist = hop.decompose_slice_args()
        c_strlen  = hop.inputconst(Void, string_repr.ll.ll_strlen)
        c_stritem = hop.inputconst(Void, string_repr.ll.ll_stritem_nonneg)
        ll_fn = globals()['ll_extend_with_str_slice_%s' % kind]
        hop.gendirectcall(ll_fn, v_lst1, v_str2, c_strlen, c_stritem, *vlist)
        return v_lst1

class __extend__(pairtype(AbstractListRepr, AbstractCharRepr)):

    def rtype_extend_with_char_count((r_lst1, r_chr2), hop):
        from rpython.rtyper.lltypesystem.rstr import char_repr
        if r_lst1.item_repr.lowleveltype not in (Char, UniChar):
            raise TyperError('"lst += string" only supported with a list '
                             'of chars or unichars')
        v_lst1, v_chr, v_count = hop.inputargs(r_lst1, char_repr, Signed)
        hop.gendirectcall(ll_extend_with_char_count, v_lst1, v_chr, v_count)
        return v_lst1


class __extend__(AbstractBaseListRepr):

    def rtype_getslice(r_lst, hop):
        cRESLIST = hop.inputconst(Void, hop.r_result.LIST)
        v_lst = hop.inputarg(r_lst, arg=0)
        kind, vlist = hop.decompose_slice_args()
        ll_listslice = globals()['ll_listslice_%s' % kind]
        return hop.gendirectcall(ll_listslice, cRESLIST, v_lst, *vlist)

    def rtype_setslice(r_lst, hop):
        v_lst = hop.inputarg(r_lst, arg=0)
        kind, vlist = hop.decompose_slice_args()
        if kind != 'startstop':
            raise TyperError('list.setitem does not support %r slices' % (
                kind,))
        v_start, v_stop = vlist
        v_lst2 = hop.inputarg(hop.args_r[3], arg=3)
        hop.gendirectcall(ll_listsetslice, v_lst, v_start, v_stop, v_lst2)

    def rtype_delslice(r_lst, hop):
        v_lst = hop.inputarg(r_lst, arg=0)
        kind, vlist = hop.decompose_slice_args()
        ll_listdelslice = globals()['ll_listdelslice_%s' % kind]
        return hop.gendirectcall(ll_listdelslice, v_lst, *vlist)


# ____________________________________________________________
#
#  Iteration.

class AbstractListIteratorRepr(IteratorRepr):

    def newiter(self, hop):
        v_lst, = hop.inputargs(self.r_list)
        citerptr = hop.inputconst(Void, self.lowleveltype)
        return hop.gendirectcall(self.ll_listiter, citerptr, v_lst)

    def rtype_next(self, hop):
        v_iter, = hop.inputargs(self)
        hop.has_implicit_exception(StopIteration) # record that we know about it
        hop.exception_is_here()
        v_res = hop.gendirectcall(self.ll_listnext, v_iter)
        return self.r_list.recast(hop.llops, v_res)


# ____________________________________________________________
#
#  Low-level methods.  These can be run for testing, but are meant to
#  be direct_call'ed from rtyped flow graphs, which means that they will
#  get flowed and annotated, mostly with SomePtr.
#
#  === a note about overflows ===
#
#  The maximal length of RPython lists is bounded by the assumption that
#  we can never allocate arrays more than sys.maxint bytes in size.
#  Our arrays have a length and some GC headers, so a list of characters
#  could come near sys.maxint in length (but not reach it).  A list of
#  pointers could only come near sys.maxint/sizeof(void*) elements.  There
#  is the list of Voids that could reach exactly sys.maxint elements,
#  but for now let's ignore this case -- the reasoning is that even if
#  the length of a Void list overflows, nothing bad memory-wise can be
#  done with it.  So in the sequel we don't bother checking for overflow
#  when we compute "ll_length() + 1".


def _ll_zero_or_null(item):
    # Check if 'item' is zero/null, or not.
    T = typeOf(item)
    if T is Char or T is UniChar:
        check = ord(item)
    elif isinstance(T, Number):
        check = widen(item)
    else:
        check = item
    return not check

@specialize.memo()
def _null_of_type(T):
    return T._defl()

def ll_alloc_and_set(LIST, count, item):
    count = int_force_ge_zero(count)
    if jit.we_are_jitted():
        return _ll_alloc_and_set_jit(LIST, count, item)
    else:
        return _ll_alloc_and_set_nojit(LIST, count, item)

def _ll_alloc_and_set_nojit(LIST, count, item):
    l = LIST.ll_newlist(count)
    if malloc_zero_filled and _ll_zero_or_null(item):
        return l
    i = 0
    while i < count:
        l.ll_setitem_fast(i, item)
        i += 1
    return l

def _ll_alloc_and_set_jit(LIST, count, item):
    if _ll_zero_or_null(item):
        # 'item' is zero/null.  Do the list allocation with the
        # function _ll_alloc_and_clear(), which the JIT knows about.
        return _ll_alloc_and_clear(LIST, count)
    else:
        # 'item' is not zero/null.  Do the list allocation with the
        # function _ll_alloc_and_set_nonnull().  That function has
        # a JIT marker to unroll it, but only if the 'count' is
        # a not-too-large constant.
        return _ll_alloc_and_set_nonnull(LIST, count, item)

@jit.oopspec("newlist_clear(count)")
def _ll_alloc_and_clear(LIST, count):
    l = LIST.ll_newlist(count)
    if malloc_zero_filled:
        return l
    zeroitem = _null_of_type(LIST.ITEM)
    i = 0
    while i < count:
        l.ll_setitem_fast(i, zeroitem)
        i += 1
    return l

@jit.look_inside_iff(lambda LIST, count, item: jit.isconstant(count) and count < 137)
def _ll_alloc_and_set_nonnull(LIST, count, item):
    l = LIST.ll_newlist(count)
    i = 0
    while i < count:
        l.ll_setitem_fast(i, item)
        i += 1
    return l


# return a nullptr() if lst is a list of pointers it, else None.
def ll_null_item(lst):
    LIST = typeOf(lst)
    if isinstance(LIST, Ptr):
        ITEM = LIST.TO.ITEM
        if isinstance(ITEM, Ptr):
            return nullptr(ITEM.TO)
    return None

def listItemType(lst):
    LIST = typeOf(lst)
    return LIST.TO.ITEM


@signature(types.any(), types.any(), types.int(), types.int(), types.int(), returns=types.none())
def ll_arraycopy(source, dest, source_start, dest_start, length):
    SRCTYPE = typeOf(source)
    # lltype
    rgc.ll_arraycopy(source.ll_items(), dest.ll_items(),
                     source_start, dest_start, length)

@signature(types.any(), types.int(), types.int(), types.int(), returns=types.none())
def ll_arraymove(lst, source_start, dest_start, length):
    # copy the slice [source_start:source_stop] to the slice [dest_start:..]
    rgc.ll_arraymove(lst.ll_items(), source_start, dest_start, length)


def ll_copy(RESLIST, l):
    length = l.ll_length()
    new_lst = RESLIST.ll_newlist(length)
    ll_arraycopy(l, new_lst, 0, 0, length)
    return new_lst
# no oopspec -- the function is inlined by the JIT

def ll_len(l):
    return l.ll_length()

def ll_list_is_true(l):
    # check if a list is True, allowing for None
    return bool(l) and l.ll_length() != 0
# no oopspec -- the function is inlined by the JIT

def ll_len_foldable(l):
    return l.ll_length()
ll_len_foldable.oopspec = 'list.len_foldable(l)'

def ll_list_is_true_foldable(l):
    return bool(l) and ll_len_foldable(l) != 0
# no oopspec -- the function is inlined by the JIT

def ll_append(l, newitem):
    length = l.ll_length()
    l._ll_resize_ge(length+1)           # see "a note about overflows" above
    l.ll_setitem_fast(length, newitem)

# this one is for the special case of insert(0, x)
def ll_prepend(l, newitem):
    length = l.ll_length()
    l._ll_resize_ge(length+1)           # see "a note about overflows" above
    ll_arraymove(l, 0, 1, length)
    l.ll_setitem_fast(0, newitem)

def ll_concat(RESLIST, l1, l2):
    len1 = l1.ll_length()
    len2 = l2.ll_length()
    try:
        newlength = ovfcheck(len1 + len2)
    except OverflowError:
        raise MemoryError
    l = RESLIST.ll_newlist(newlength)
    ll_arraycopy(l1, l, 0, 0, len1)
    ll_arraycopy(l2, l, 0, len1, len2)
    return l
# no oopspec -- the function is inlined by the JIT

def ll_insert_nonneg(l, index, newitem):
    length = l.ll_length()
    ll_assert(0 <= index, "negative list insertion index")
    ll_assert(index <= length, "list insertion index out of bound")
    l._ll_resize_ge(length+1)           # see "a note about overflows" above
    ll_arraymove(l, index, index + 1, length - index)
    l.ll_setitem_fast(index, newitem)

def ll_pop_nonneg(func, l, index):
    ll_assert(index >= 0, "unexpectedly negative list pop index")
    if func is dum_checkidx:
        if index >= l.ll_length():
            raise IndexError
    else:
        ll_assert(index < l.ll_length(), "list pop index out of bound")
    res = l.ll_getitem_fast(index)
    ll_delitem_nonneg(dum_nocheck, l, index)
    return res
ll_pop_nonneg.oopspec = 'list.pop(l, index)'

def ll_pop_default(func, l):
    length = l.ll_length()
    if func is dum_checkidx and (length == 0):
        raise IndexError
    ll_assert(length > 0, "pop from empty list")
    index = length - 1
    newlength = index
    res = l.ll_getitem_fast(index)
    null = ll_null_item(l)
    if null is not None:
        l.ll_setitem_fast(index, null)
    l._ll_resize_le(newlength)
    return res

def ll_pop_zero(func, l):
    length = l.ll_length()
    if func is dum_checkidx and (length == 0):
        raise IndexError
    ll_assert(length > 0, "pop(0) from empty list")
    res = l.ll_getitem_fast(0)
    newlength = length - 1
    ll_arraymove(l, 1, 0, newlength)
    null = ll_null_item(l)
    if null is not None:
        l.ll_setitem_fast(newlength, null)
    l._ll_resize_le(newlength)
    return res
ll_pop_zero.oopspec = 'list.pop(l, 0)'

def ll_pop(func, l, index):
    length = l.ll_length()
    if index < 0:
        index += length
    if func is dum_checkidx:
        if index < 0 or index >= length:
            raise IndexError
    else:
        ll_assert(index >= 0, "negative list pop index out of bound")
        ll_assert(index < length, "list pop index out of bound")
    res = l.ll_getitem_fast(index)
    ll_delitem_nonneg(dum_nocheck, l, index)
    return res

@jit.look_inside_iff(lambda l: jit.isvirtual(l))
def ll_reverse(l):
    length = l.ll_length()
    i = 0
    length_1_i = length-1-i
    while i < length_1_i:
        tmp = l.ll_getitem_fast(i)
        l.ll_setitem_fast(i, l.ll_getitem_fast(length_1_i))
        l.ll_setitem_fast(length_1_i, tmp)
        i += 1
        length_1_i -= 1

def ll_getitem_nonneg(func, basegetitem, l, index):
    ll_assert(index >= 0, "unexpectedly negative list getitem index")
    if func is dum_checkidx:
        if index >= l.ll_length():
            raise IndexError
    return basegetitem(l, index)
ll_getitem_nonneg._always_inline_ = True
# no oopspec -- the function is inlined by the JIT

def ll_getitem(func, basegetitem, l, index):
    if func is dum_checkidx:
        length = l.ll_length()    # common case: 0 <= index < length
        if r_uint(index) >= r_uint(length):
            # Failed, so either (-length <= index < 0), or we have to raise
            # IndexError.  First add 'length' to get the final index, then
            # check that we now have (0 <= index < length).
            index = r_uint(index) + r_uint(length)
            if index >= r_uint(length):
                raise IndexError
            index = intmask(index)
    else:
        # We don't want checking, but still want to support index < 0.
        # Only call ll_length() if needed.
        if index < 0:
            index += l.ll_length()
            ll_assert(index >= 0, "negative list getitem index out of bound")
    return basegetitem(l, index)
# no oopspec -- the function is inlined by the JIT

def ll_getitem_fast(l, index):
    return l.ll_getitem_fast(index)
ll_getitem_fast._always_inline_ = True

def ll_getitem_foldable_nonneg(l, index):
    ll_assert(index >= 0, "unexpectedly negative list getitem index")
    return l.ll_getitem_fast(index)
ll_getitem_foldable_nonneg.oopspec = 'list.getitem_foldable(l, index)'

def ll_setitem_nonneg(func, l, index, newitem):
    ll_assert(index >= 0, "unexpectedly negative list setitem index")
    if func is dum_checkidx:
        if index >= l.ll_length():
            raise IndexError
    l.ll_setitem_fast(index, newitem)
ll_setitem_nonneg._always_inline_ = True
# no oopspec -- the function is inlined by the JIT

def ll_setitem(func, l, index, newitem):
    if func is dum_checkidx:
        length = l.ll_length()
        if r_uint(index) >= r_uint(length):   # see comments in ll_getitem().
            index = r_uint(index) + r_uint(length)
            if index >= r_uint(length):
                raise IndexError
            index = intmask(index)
    else:
        if index < 0:
            index += l.ll_length()
            ll_assert(index >= 0, "negative list setitem index out of bound")
    l.ll_setitem_fast(index, newitem)
# no oopspec -- the function is inlined by the JIT

@enforceargs(None, None, int)
def ll_delitem_nonneg(func, l, index):
    ll_assert(index >= 0, "unexpectedly negative list delitem index")
    length = l.ll_length()
    if func is dum_checkidx:
        if index >= length:
            raise IndexError
    else:
        ll_assert(index < length, "list delitem index out of bound")
    newlength = length - 1
    ll_arraymove(l, index + 1, index, newlength - index)
    null = ll_null_item(l)
    if null is not None:
        l.ll_setitem_fast(newlength, null)
    l._ll_resize_le(newlength)
# no oopspec -- the function is inlined by the JIT

def ll_delitem(func, l, index):
    if func is dum_checkidx:
        length = l.ll_length()
        if r_uint(index) >= r_uint(length):   # see comments in ll_getitem().
            index = r_uint(index) + r_uint(length)
            if index >= r_uint(length):
                raise IndexError
            index = intmask(index)
    else:
        if index < 0:
            index += l.ll_length()
            ll_assert(index >= 0, "negative list delitem index out of bound")
    ll_delitem_nonneg(dum_nocheck, l, index)
# no oopspec -- the function is inlined by the JIT

def ll_extend(l1, l2):
    len1 = l1.ll_length()
    len2 = l2.ll_length()
    try:
        newlength = ovfcheck(len1 + len2)
    except OverflowError:
        raise MemoryError
    l1._ll_resize_ge(newlength)
    ll_arraycopy(l2, l1, 0, len1, len2)

def ll_extend_with_str(lst, s, getstrlen, getstritem):
    return ll_extend_with_str_slice_startonly(lst, s, getstrlen, getstritem, 0)

def ll_extend_with_str_slice_startonly(lst, s, getstrlen, getstritem, start):
    len1 = lst.ll_length()
    len2 = getstrlen(s)
    count2 = len2 - start
    ll_assert(start >= 0, "unexpectedly negative str slice start")
    assert count2 >= 0, "str slice start larger than str length"
    try:
        newlength = ovfcheck(len1 + count2)
    except OverflowError:
        raise MemoryError
    lst._ll_resize_ge(newlength)
    i = start
    j = len1
    while i < len2:
        c = getstritem(s, i)
        if listItemType(lst) is UniChar:
            c = unichr(ord(c))
        lst.ll_setitem_fast(j, c)
        i += 1
        j += 1
# not inlined by the JIT -- contains a loop

def ll_extend_with_str_slice_startstop(lst, s, getstrlen, getstritem,
                                       start, stop):
    len1 = lst.ll_length()
    len2 = getstrlen(s)
    ll_assert(start >= 0, "unexpectedly negative str slice start")
    ll_assert(start <= len2, "str slice start larger than str length")
    if stop > len2:
        stop = len2
    count2 = stop - start
    assert count2 >= 0, "str slice stop smaller than start"
    try:
        newlength = ovfcheck(len1 + count2)
    except OverflowError:
        raise MemoryError
    lst._ll_resize_ge(newlength)
    i = start
    j = len1
    while i < stop:
        c = getstritem(s, i)
        if listItemType(lst) is UniChar:
            c = unichr(ord(c))
        lst.ll_setitem_fast(j, c)
        i += 1
        j += 1
# not inlined by the JIT -- contains a loop

def ll_extend_with_str_slice_minusone(lst, s, getstrlen, getstritem):
    len1 = lst.ll_length()
    len2m1 = getstrlen(s) - 1
    assert len2m1 >= 0, "empty string is sliced with [:-1]"
    try:
        newlength = ovfcheck(len1 + len2m1)
    except OverflowError:
        raise MemoryError
    lst._ll_resize_ge(newlength)
    i = 0
    j = len1
    while i < len2m1:
        c = getstritem(s, i)
        if listItemType(lst) is UniChar:
            c = unichr(ord(c))
        lst.ll_setitem_fast(j, c)
        i += 1
        j += 1
# not inlined by the JIT -- contains a loop

def ll_extend_with_char_count(lst, char, count):
    if count <= 0:
        return
    len1 = lst.ll_length()
    try:
        newlength = ovfcheck(len1 + count)
    except OverflowError:
        raise MemoryError
    lst._ll_resize_ge(newlength)
    j = len1
    if listItemType(lst) is UniChar:
        char = unichr(ord(char))
    while j < newlength:
        lst.ll_setitem_fast(j, char)
        j += 1


@signature(types.any(), types.any(), types.int(), returns=types.any())
def ll_listslice_startonly(RESLIST, l1, start):
    len1 = l1.ll_length()
    ll_assert(start >= 0, "unexpectedly negative list slice start")
    ll_assert(start <= len1, "list slice start larger than list length")
    newlength = len1 - start
    l = RESLIST.ll_newlist(newlength)
    ll_arraycopy(l1, l, start, 0, newlength)
    return l


def ll_listslice_startstop(RESLIST, l1, start, stop):
    length = l1.ll_length()
    ll_assert(start >= 0, "unexpectedly negative list slice start")
    ll_assert(start <= length, "list slice start larger than list length")
    ll_assert(stop >= start, "list slice stop smaller than start")
    if stop > length:
        stop = length
    newlength = stop - start
    l = RESLIST.ll_newlist(newlength)
    ll_arraycopy(l1, l, start, 0, newlength)
    return l
# no oopspec -- the function is inlined by the JIT

def ll_listslice_minusone(RESLIST, l1):
    newlength = l1.ll_length() - 1
    ll_assert(newlength >= 0, "empty list is sliced with [:-1]")
    l = RESLIST.ll_newlist(newlength)
    ll_arraycopy(l1, l, 0, 0, newlength)
    return l
# no oopspec -- the function is inlined by the JIT

@jit.look_inside_iff(lambda l, start: jit.isconstant(start) and jit.isvirtual(l))
@jit.oopspec('list.delslice_startonly(l, start)')
def ll_listdelslice_startonly(l, start):
    ll_assert(start >= 0, "del l[start:] with unexpectedly negative start")
    ll_assert(start <= l.ll_length(), "del l[start:] with start > len(l)")
    newlength = start
    null = ll_null_item(l)
    if null is not None:
        j = l.ll_length() - 1
        while j >= newlength:
            l.ll_setitem_fast(j, null)
            j -= 1
    l._ll_resize_le(newlength)

def ll_listdelslice_startstop(l, start, stop):
    length = l.ll_length()
    ll_assert(start >= 0, "del l[start:x] with unexpectedly negative start")
    ll_assert(start <= length, "del l[start:x] with start > len(l)")
    ll_assert(stop >= start, "del l[x:y] with x > y")
    if stop > length:
        stop = length
    ll_arraymove(l, stop, start, length - stop)
    newlength = length - (stop-start)
    null = ll_null_item(l)
    if null is not None:
        j = length - 1
        while j >= newlength:
            l.ll_setitem_fast(j, null)
            j -= 1
    l._ll_resize_le(newlength)
ll_listdelslice_startstop.oopspec = 'list.delslice_startstop(l, start, stop)'

def ll_listsetslice(l1, start, stop, l2):
    len1 = l1.ll_length()
    len2 = l2.ll_length()
    ll_assert(start >= 0, "l[start:x] = l with unexpectedly negative start")
    ll_assert(start <= len1, "l[start:x] = l with start > len(l)")
    ll_assert(stop <= len1, "stop cannot be past the end of l1")
    if len2 == stop - start:
        ll_arraycopy(l2, l1, 0, start, len2)
    elif len2 < stop - start:
        ll_arraycopy(l2, l1, 0, start, len2)
        ll_arraycopy(l1, l1, stop, start + len2, len1 - stop)
        l1._ll_resize_le(len1 + len2 - (stop - start))
    else: # len2 > stop - start:
        try:
            newlength = ovfcheck(len1 + len2)
        except OverflowError:
            raise MemoryError
        l1._ll_resize_ge(newlength)
        ll_arraycopy(l1, l1, stop, start + len2, len1 - stop)
        ll_arraycopy(l2, l1, 0, start, len2)


# ____________________________________________________________
#
#  Comparison.

def listeq_unroll_case(l1, l2, eqfn):
    if jit.isvirtual(l1) and l1.ll_length() < 10:
        return True
    if jit.isvirtual(l2) and l2.ll_length() < 10:
        return True
    return False

@jit.look_inside_iff(listeq_unroll_case)
def ll_listeq(l1, l2, eqfn):
    if not l1 and not l2:
        return True
    if not l1 or not l2:
        return False
    len1 = l1.ll_length()
    len2 = l2.ll_length()
    if len1 != len2:
        return False
    j = 0
    while j < len1:
        if eqfn is None:
            if l1.ll_getitem_fast(j) != l2.ll_getitem_fast(j):
                return False
        else:
            if not eqfn(l1.ll_getitem_fast(j), l2.ll_getitem_fast(j)):
                return False
        j += 1
    return True
# not inlined by the JIT -- contains a loop

def ll_listcontains(lst, obj, eqfn):
    lng = lst.ll_length()
    j = 0
    while j < lng:
        if eqfn is None:
            if lst.ll_getitem_fast(j) == obj:
                return True
        else:
            if eqfn(lst.ll_getitem_fast(j), obj):
                return True
        j += 1
    return False
# not inlined by the JIT -- contains a loop

def ll_listindex(lst, obj, eqfn):
    lng = lst.ll_length()
    j = 0
    while j < lng:
        if eqfn is None:
            if lst.ll_getitem_fast(j) == obj:
                return j
        else:
            if eqfn(lst.ll_getitem_fast(j), obj):
                return j
        j += 1
    raise ValueError # can't say 'list.index(x): x not in list'
# not inlined by the JIT -- contains a loop

def ll_listremove(lst, obj, eqfn):
    index = ll_listindex(lst, obj, eqfn) # raises ValueError if obj not in lst
    ll_delitem_nonneg(dum_nocheck, lst, index)

def ll_inplace_mul(l, factor):
    if factor == 1:
        return l
    length = l.ll_length()
    if factor < 0:
        factor = 0
    try:
        resultlen = ovfcheck(length * factor)
    except OverflowError:
        raise MemoryError
    res = l
    res._ll_resize(resultlen)
    j = length
    while j < resultlen:
        ll_arraycopy(l, res, 0, j, length)
        j += length
    return res
ll_inplace_mul.oopspec = 'list.inplace_mul(l, factor)'

@jit.look_inside_iff(lambda _, l, factor: jit.isvirtual(l) and
                     jit.isconstant(factor) and factor < 10)
def ll_mul(RESLIST, l, factor):
    length = l.ll_length()
    if factor < 0:
        factor = 0
    try:
        resultlen = ovfcheck(length * factor)
    except OverflowError:
        raise MemoryError
    res = RESLIST.ll_newlist(resultlen)
    j = 0
    while j < resultlen:
        ll_arraycopy(l, res, 0, j, length)
        j += length
    return res
# not inlined by the JIT -- contains a loop
