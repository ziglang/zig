from rpython.rlib import rgc, jit, types
from rpython.rtyper.debug import ll_assert
from rpython.rlib.signature import signature
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem import rstr
from rpython.rtyper.lltypesystem.lltype import (GcForwardReference, Ptr, GcArray,
     GcStruct, Void, Signed, malloc, typeOf, nullptr, typeMethod, Char)
from rpython.rtyper.rlist import (AbstractBaseListRepr, AbstractListRepr,
    AbstractFixedSizeListRepr, AbstractListIteratorRepr, ll_setitem_nonneg,
    ADTIList, ADTIFixedList, dum_nocheck)
from rpython.rtyper.rmodel import Repr, inputconst, externalvsinternal
from rpython.tool.pairtype import pairtype, pair


# ____________________________________________________________
#
#  Concrete implementation of RPython lists:
#
#    struct list {
#        int length;
#        items_array *items;
#    }
#
#    'items' points to a C-like array in memory preceded by a 'length' header,
#    where each item contains a primitive value or pointer to the actual list
#    item.
#
#    or for fixed-size lists an array is directly used:
#
#    item_t list_items[]
#

def LIST_OF(ITEMTYPE, cache={}):
    """
    Return the low-level type for a resizable list of ITEMTYPE
    """
    try:
        return cache[ITEMTYPE]
    except KeyError:
        pass
    
    from rpython.rtyper.lltypesystem.rstr import CharRepr
    assert ITEMTYPE is Char, 'only Char is supported for now'
    # XXX: maybe we should think of a better way to build the type?
    list_of_char_repr = ListRepr(None, CharRepr())
    list_of_char_repr._setup_repr()
    LIST = list_of_char_repr.LIST
    cache[ITEMTYPE] = LIST
    return LIST


class BaseListRepr(AbstractBaseListRepr):
    rstr_ll = rstr.LLHelpers

    def __init__(self, rtyper, item_repr, listitem=None):
        self.rtyper = rtyper
        self.LIST = GcForwardReference()
        self.lowleveltype = Ptr(self.LIST)
        if not isinstance(item_repr, Repr):  # not computed yet, done by setup()
            assert callable(item_repr)
            self._item_repr_computer = item_repr
        else:
            self.external_item_repr, self.item_repr = externalvsinternal(rtyper, item_repr)
        self.listitem = listitem
        self.list_cache = {}
        # setup() needs to be called to finish this initialization

    def null_const(self):
        return nullptr(self.LIST)

    def get_eqfunc(self):
        return inputconst(Void, self.item_repr.get_ll_eq_function())

    def make_iterator_repr(self, *variant):
        if not variant:
            return ListIteratorRepr(self)
        elif variant == ("reversed",):
            return ReversedListIteratorRepr(self)
        else:
            raise TyperError("unsupported %r iterator over a list" % (variant,))

    def get_itemarray_lowleveltype(self):
        ITEM = self.item_repr.lowleveltype
        ITEMARRAY = GcArray(ITEM,
                            adtmeths = ADTIFixedList({
                                 "ll_newlist": ll_fixed_newlist,
                                 "ll_newemptylist": ll_fixed_newemptylist,
                                 "ll_length": ll_fixed_length,
                                 "ll_items": ll_fixed_items,
                                 "ITEM": ITEM,
                                 "ll_getitem_fast": ll_fixed_getitem_fast,
                                 "ll_setitem_fast": ll_fixed_setitem_fast,
                            }))
        return ITEMARRAY


class __extend__(pairtype(BaseListRepr, BaseListRepr)):
    def rtype_is_((r_lst1, r_lst2), hop):
        if r_lst1.lowleveltype != r_lst2.lowleveltype:
            # obscure logic, the is can be true only if both are None
            v_lst1, v_lst2 = hop.inputargs(r_lst1, r_lst2)
            return hop.gendirectcall(ll_both_none, v_lst1, v_lst2)

        return pairtype(Repr, Repr).rtype_is_(pair(r_lst1, r_lst2), hop)


class ListRepr(AbstractListRepr, BaseListRepr):

    def _setup_repr(self):
        if 'item_repr' not in self.__dict__:
            self.external_item_repr, self.item_repr = externalvsinternal(self.rtyper, self._item_repr_computer())
        if isinstance(self.LIST, GcForwardReference):
            ITEM = self.item_repr.lowleveltype
            ITEMARRAY = self.get_itemarray_lowleveltype()
            # XXX we might think of turning length stuff into Unsigned
            self.LIST.become(GcStruct("list", ("length", Signed),
                                              ("items", Ptr(ITEMARRAY)),
                                      adtmeths = ADTIList({
                                          "ll_newlist": ll_newlist,
                                          "ll_newlist_hint": ll_newlist_hint,
                                          "ll_newemptylist": ll_newemptylist,
                                          "ll_length": ll_length,
                                          "ll_items": ll_items,
                                          "ITEM": ITEM,
                                          "ll_getitem_fast": ll_getitem_fast,
                                          "ll_setitem_fast": ll_setitem_fast,
                                          "_ll_resize_ge": _ll_list_resize_ge,
                                          "_ll_resize_le": _ll_list_resize_le,
                                          "_ll_resize": _ll_list_resize,
                                          "_ll_resize_hint": _ll_list_resize_hint,
                                      }),
                                      hints = {'list': True})
                             )

    def compact_repr(self):
        return 'ListR %s' % (self.item_repr.compact_repr(),)

    def prepare_const(self, n):
        result = malloc(self.LIST, immortal=True)
        result.length = n
        result.items = malloc(self.LIST.items.TO, n)
        return result

    def rtype_method_append(self, hop):
        if getattr(self.listitem, 'hint_maxlength', False):
            v_lst, v_value = hop.inputargs(self, self.item_repr)
            hop.exception_cannot_occur()
            hop.gendirectcall(ll_append_noresize, v_lst, v_value)
        else:
            AbstractListRepr.rtype_method_append(self, hop)

    def rtype_hint(self, hop):
        optimized = getattr(self.listitem, 'hint_maxlength', False)
        hints = hop.args_s[-1].const
        if 'maxlength' in hints:
            if optimized:
                v_list = hop.inputarg(self, arg=0)
                v_maxlength = self._get_v_maxlength(hop)
                hop.llops.gendirectcall(ll_set_maxlength, v_list, v_maxlength)
                return v_list
        if 'fence' in hints:
            v_list = hop.inputarg(self, arg=0)
            if isinstance(hop.r_result, FixedSizeListRepr):
                if optimized and 'exactlength' in hints:
                    llfn = ll_list2fixed_exact
                else:
                    llfn = ll_list2fixed
                v_list = hop.llops.gendirectcall(llfn, v_list)
            return v_list
        return AbstractListRepr.rtype_hint(self, hop)


class FixedSizeListRepr(AbstractFixedSizeListRepr, BaseListRepr):

    def _setup_repr(self):
        if 'item_repr' not in self.__dict__:
            self.external_item_repr, self.item_repr = externalvsinternal(self.rtyper, self._item_repr_computer())
        if isinstance(self.LIST, GcForwardReference):
            ITEMARRAY = self.get_itemarray_lowleveltype()
            self.LIST.become(ITEMARRAY)

    def compact_repr(self):
        return 'FixedSizeListR %s' % (self.item_repr.compact_repr(),)

    def prepare_const(self, n):
        result = malloc(self.LIST, n, immortal=True)
        return result


# ____________________________________________________________
#
#  Low-level methods.  These can be run for testing, but are meant to
#  be direct_call'ed from rtyped flow graphs, which means that they will
#  get flowed and annotated, mostly with SomePtr.

# adapted C code

@jit.look_inside_iff(lambda l, newsize, overallocate: jit.isconstant(len(l.items)) and jit.isconstant(newsize))
@signature(types.any(), types.int(), types.bool(), returns=types.none())
def _ll_list_resize_hint_really(l, newsize, overallocate):
    """
    Ensure l.items has room for at least newsize elements.  Note that
    l.items may change, and even if newsize is less than l.length on
    entry.
    """
    # This over-allocates proportional to the list size, making room
    # for additional growth.  The over-allocation is mild, but is
    # enough to give linear-time amortized behavior over a long
    # sequence of appends() in the presence of a poorly-performing
    # system malloc().
    # The growth pattern is:  0, 4, 8, 16, 25, 35, 46, 58, 72, 88, ...
    if newsize <= 0:
        ll_assert(newsize == 0, "negative list length")
        l.length = 0
        l.items = _ll_new_empty_item_array(typeOf(l).TO)
        return
    elif overallocate:
        if newsize < 9:
            some = 3
        else:
            some = 6
        some += newsize >> 3
        new_allocated = newsize + some
    else:
        new_allocated = newsize
    # new_allocated is a bit more than newsize, enough to ensure an amortized
    # linear complexity for e.g. repeated usage of l.append().  In case
    # it overflows sys.maxint, it is guaranteed negative, and the following
    # malloc() will fail.
    items = l.items
    newitems = malloc(typeOf(l).TO.items.TO, new_allocated)
    before_len = l.length
    if before_len:   # avoids copying GC flags from the prebuilt_empty_array
        if before_len < newsize:
            p = before_len
        else:
            p = newsize
        rgc.ll_arraycopy(items, newitems, 0, 0, p)
    l.items = newitems

@jit.look_inside_iff(lambda l, newsize: jit.isconstant(len(l.items)) and jit.isconstant(newsize))
def _ll_list_resize_hint(l, newsize):
    """Ensure l.items has room for at least newsize elements without
    setting l.length to newsize.

    Used before (and after) a batch operation that will likely grow the
    list to the newsize (and after the operation incase the initial
    guess lied).
    """
    assert newsize >= 0, "negative list length"
    allocated = len(l.items)
    if newsize > allocated:
        overallocate = True
    elif newsize < (allocated >> 1) - 5:
        overallocate = False
    else:
        return
    _ll_list_resize_hint_really(l, newsize, overallocate)

@signature(types.any(), types.int(), types.bool(), returns=types.none())
def _ll_list_resize_really(l, newsize, overallocate):
    """
    Ensure l.items has room for at least newsize elements, and set
    l.length to newsize.  Note that l.items may change, and even if
    newsize is less than l.length on entry.
    """
    _ll_list_resize_hint_really(l, newsize, overallocate)
    l.length = newsize

# this common case was factored out of _ll_list_resize
# to see if inlining it gives some speed-up.

@jit.dont_look_inside
def _ll_list_resize(l, newsize):
    """Called only in special cases.  Forces the allocated and actual size
    of the list to be 'newsize'."""
    _ll_list_resize_really(l, newsize, False)


def _ll_list_resize_ge(l, newsize):
    """This is called with 'newsize' larger than the current length of the
    list.  If the list storage doesn't have enough space, then really perform
    a realloc().  In the common case where we already overallocated enough,
    then this is a very fast operation.
    """
    cond = len(l.items) < newsize
    if jit.isconstant(len(l.items)) and jit.isconstant(newsize):
        if cond:
            _ll_list_resize_hint_really(l, newsize, True)
    else:
        jit.conditional_call(cond,
                             _ll_list_resize_hint_really, l, newsize, True)
    l.length = newsize

def _ll_list_resize_le(l, newsize):
    """This is called with 'newsize' smaller than the current length of the
    list.  If 'newsize' falls lower than half the allocated size, proceed
    with the realloc() to shrink the list.
    """
    cond = newsize < (len(l.items) >> 1) - 5
    # note: overallocate=False should be safe here
    if jit.isconstant(len(l.items)) and jit.isconstant(newsize):
        if cond:
            _ll_list_resize_hint_really(l, newsize, False)
    else:
        jit.conditional_call(cond, _ll_list_resize_hint_really, l, newsize,
                             False)
    l.length = newsize

def ll_append_noresize(l, newitem):
    length = l.length
    l.length = length + 1
    l.ll_setitem_fast(length, newitem)


def ll_both_none(lst1, lst2):
    return not lst1 and not lst2


# ____________________________________________________________
#
#  Accessor methods

def ll_newlist(LIST, length):
    ll_assert(length >= 0, "negative list length")
    l = malloc(LIST)
    l.length = length
    l.items = malloc(LIST.items.TO, length)
    return l
ll_newlist = typeMethod(ll_newlist)
ll_newlist.oopspec = 'newlist(length)'

def ll_newlist_hint(LIST, lengthhint):
    ll_assert(lengthhint >= 0, "negative list length")
    l = malloc(LIST)
    l.length = 0
    l.items = malloc(LIST.items.TO, lengthhint)
    return l
ll_newlist_hint = typeMethod(ll_newlist_hint)
ll_newlist_hint.oopspec = 'newlist_hint(lengthhint)'

# should empty lists start with no allocated memory, or with a preallocated
# minimal number of entries?  XXX compare memory usage versus speed, and
# check how many always-empty lists there are in a typical pypy-c run...
INITIAL_EMPTY_LIST_ALLOCATION = 0

def _ll_prebuilt_empty_array(LISTITEM):
    return malloc(LISTITEM, 0)
_ll_prebuilt_empty_array._annspecialcase_ = 'specialize:memo'

def _ll_new_empty_item_array(LIST):
    if INITIAL_EMPTY_LIST_ALLOCATION > 0:
        return malloc(LIST.items.TO, INITIAL_EMPTY_LIST_ALLOCATION)
    else:
        return _ll_prebuilt_empty_array(LIST.items.TO)

def ll_newemptylist(LIST):
    l = malloc(LIST)
    l.length = 0
    l.items = _ll_new_empty_item_array(LIST)
    return l
ll_newemptylist = typeMethod(ll_newemptylist)
ll_newemptylist.oopspec = 'newlist(0)'

def ll_length(l):
    return l.length
ll_length.oopspec = 'list.len(l)'

def ll_items(l):
    return l.items

def ll_getitem_fast(l, index):
    ll_assert(index < l.length, "getitem out of bounds")
    return l.ll_items()[index]
ll_getitem_fast.oopspec = 'list.getitem(l, index)'

def ll_setitem_fast(l, index, item):
    ll_assert(index < l.length, "setitem out of bounds")
    l.ll_items()[index] = item
ll_setitem_fast.oopspec = 'list.setitem(l, index, item)'

# fixed size versions

@typeMethod
def ll_fixed_newlist(LIST, length):
    ll_assert(length >= 0, "negative fixed list length")
    l = malloc(LIST, length)
    return l
ll_fixed_newlist.oopspec = 'newlist(length)'

@typeMethod
def ll_fixed_newemptylist(LIST):
    return ll_fixed_newlist(LIST, 0)

def ll_fixed_length(l):
    return len(l)
ll_fixed_length.oopspec = 'list.len(l)'

def ll_fixed_items(l):
    return l

def ll_fixed_getitem_fast(l, index):
    ll_assert(index < len(l), "fixed getitem out of bounds")
    return l[index]
ll_fixed_getitem_fast.oopspec = 'list.getitem(l, index)'

def ll_fixed_setitem_fast(l, index, item):
    ll_assert(index < len(l), "fixed setitem out of bounds")
    l[index] = item
ll_fixed_setitem_fast.oopspec = 'list.setitem(l, index, item)'

def newlist(llops, r_list, items_v, v_sizehint=None):
    LIST = r_list.LIST
    if len(items_v) == 0:
        if v_sizehint is None:
            v_result = llops.gendirectcall(LIST.ll_newemptylist)
        else:
            v_result = llops.gendirectcall(LIST.ll_newlist_hint, v_sizehint)
    else:
        assert v_sizehint is None
        cno = inputconst(Signed, len(items_v))
        v_result = llops.gendirectcall(LIST.ll_newlist, cno)
    v_func = inputconst(Void, dum_nocheck)
    for i, v_item in enumerate(items_v):
        ci = inputconst(Signed, i)
        llops.gendirectcall(ll_setitem_nonneg, v_func, v_result, ci, v_item)
    return v_result

# special operations for list comprehension optimization
def ll_set_maxlength(l, n):
    LIST = typeOf(l).TO
    l.items = malloc(LIST.items.TO, n)

def ll_list2fixed(l):
    n = l.length
    olditems = l.items
    if n == len(olditems):
        return olditems
    else:
        LIST = typeOf(l).TO
        newitems = malloc(LIST.items.TO, n)
        rgc.ll_arraycopy(olditems, newitems, 0, 0, n)
        return newitems

def ll_list2fixed_exact(l):
    ll_assert(l.length == len(l.items), "ll_list2fixed_exact: bad length")
    return l.items

# ____________________________________________________________
#
#  Iteration.

class ListIteratorRepr(AbstractListIteratorRepr):

    def __init__(self, r_list):
        self.r_list = r_list
        self.external_item_repr = r_list.external_item_repr
        self.lowleveltype = Ptr(GcStruct('listiter',
                                         ('list', r_list.lowleveltype),
                                         ('index', Signed)))
        self.ll_listiter = ll_listiter
        if (isinstance(r_list, FixedSizeListRepr)
                and not r_list.listitem.mutated):
            self.ll_listnext = ll_listnext_foldable
        else:
            self.ll_listnext = ll_listnext
        self.ll_getnextindex = ll_getnextindex


def ll_listiter(ITERPTR, lst):
    iter = malloc(ITERPTR.TO)
    iter.list = lst
    iter.index = 0
    return iter

def ll_listnext(iter):
    l = iter.list
    index = iter.index
    if index >= l.ll_length():
        raise StopIteration
    iter.index = index + 1      # cannot overflow because index < l.length
    return l.ll_getitem_fast(index)

def ll_listnext_foldable(iter):
    from rpython.rtyper.rlist import ll_getitem_foldable_nonneg
    l = iter.list
    index = iter.index
    if index >= l.ll_length():
        raise StopIteration
    iter.index = index + 1      # cannot overflow because index < l.length
    return ll_getitem_foldable_nonneg(l, index)

def ll_getnextindex(iter):
    return iter.index


class ReversedListIteratorRepr(AbstractListIteratorRepr):
    def __init__(self, r_list):
        self.r_list = r_list
        self.lowleveltype = Ptr(GcStruct('revlistiter',
            ('list', r_list.lowleveltype),
            ('index', Signed),
        ))
        self.ll_listnext = ll_revlistnext
        self.ll_listiter = ll_revlistiter


def ll_revlistiter(ITERPTR, lst):
    iter = malloc(ITERPTR.TO)
    iter.list = lst
    iter.index = lst.ll_length() - 1
    return iter


def ll_revlistnext(iter):
    l = iter.list
    index = iter.index
    if index < 0:
        raise StopIteration
    iter.index -= 1
    return l.ll_getitem_fast(index)
