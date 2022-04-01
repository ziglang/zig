from rpython.flowspace.model import Constant
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem.lltype import Signed, Void, Ptr
from rpython.rtyper.rlist import dum_nocheck, dum_checkidx
from rpython.rtyper.rmodel import Repr, IteratorRepr
from rpython.rtyper.rint import IntegerRepr
from rpython.tool.pairtype import pairtype


class AbstractRangeRepr(Repr):
    def __init__(self, step):
        self.step = step
        if step != 0:
            self.lowleveltype = self.RANGE
        else:
            self.lowleveltype = self.RANGEST

    def _getstep(self, v_rng, hop):
        return hop.genop(self.getfield_opname,
                [v_rng, hop.inputconst(Void, 'step')], resulttype=Signed)

    def rtype_len(self, hop):
        v_rng, = hop.inputargs(self)
        if self.step == 1:
            return hop.gendirectcall(ll_rangelen1, v_rng)
        elif self.step != 0:
            v_step = hop.inputconst(Signed, self.step)
        else:
            v_step = self._getstep(v_rng, hop)
        return hop.gendirectcall(ll_rangelen, v_rng, v_step)

class __extend__(pairtype(AbstractRangeRepr, IntegerRepr)):

    def rtype_getitem((r_rng, r_int), hop):
        if hop.has_implicit_exception(IndexError):
            spec = dum_checkidx
        else:
            spec = dum_nocheck
        v_func = hop.inputconst(Void, spec)
        v_lst, v_index = hop.inputargs(r_rng, Signed)
        if r_rng.step != 0:
            cstep = hop.inputconst(Signed, r_rng.step)
        else:
            cstep = r_rng._getstep(v_lst, hop)
        if hop.args_s[1].nonneg:
            llfn = ll_rangeitem_nonneg
        else:
            llfn = ll_rangeitem
        hop.exception_is_here()
        return hop.gendirectcall(llfn, v_func, v_lst, v_index, cstep)

# ____________________________________________________________
#
#  Low-level methods.

def _ll_rangelen(start, stop, step):
    if step > 0:
        result = (stop - start + (step - 1)) // step
    else:
        result = (start - stop - (step + 1)) // (-step)
    if result < 0:
        result = 0
    return result

def ll_rangelen(l, step):
    return _ll_rangelen(l.start, l.stop, step)

def ll_rangelen1(l):
    result = l.stop - l.start
    if result < 0:
        result = 0
    return result

def ll_rangeitem_nonneg(func, l, index, step):
    if func is dum_checkidx and index >= _ll_rangelen(l.start, l.stop, step):
        raise IndexError
    return l.start + index * step

def ll_rangeitem(func, l, index, step):
    if func is dum_checkidx:
        length = _ll_rangelen(l.start, l.stop, step)
        if index < 0:
            index += length
        if index < 0 or index >= length:
            raise IndexError
    else:
        if index < 0:
            length = _ll_rangelen(l.start, l.stop, step)
            index += length
    return l.start + index * step

# ____________________________________________________________
#
#  Irregular operations.

def rtype_builtin_range(hop):
    vstep = hop.inputconst(Signed, 1)
    if hop.nb_args == 1:
        vstart = hop.inputconst(Signed, 0)
        vstop, = hop.inputargs(Signed)
    elif hop.nb_args == 2:
        vstart, vstop = hop.inputargs(Signed, Signed)
    else:
        vstart, vstop, vstep = hop.inputargs(Signed, Signed, Signed)
        if isinstance(vstep, Constant) and vstep.value == 0:
            # not really needed, annotator catches it. Just in case...
            raise TyperError("range cannot have a const step of zero")
    if isinstance(hop.r_result, AbstractRangeRepr):
        if hop.r_result.step != 0:
            c_rng = hop.inputconst(Void, hop.r_result.RANGE)
            hop.exception_is_here()
            return hop.gendirectcall(hop.r_result.ll_newrange, c_rng, vstart, vstop)
        else:
            hop.exception_is_here()
            return hop.gendirectcall(hop.r_result.ll_newrangest, vstart, vstop, vstep)
    else:
        # cannot build a RANGE object, needs a real list
        r_list = hop.r_result
        ITEMTYPE = r_list.lowleveltype
        if isinstance(ITEMTYPE, Ptr):
            ITEMTYPE = ITEMTYPE.TO
        cLIST = hop.inputconst(Void, ITEMTYPE)
        hop.exception_is_here()
        return hop.gendirectcall(ll_range2list, cLIST, vstart, vstop, vstep)

rtype_builtin_xrange = rtype_builtin_range

def ll_range2list(LIST, start, stop, step):
    if step == 0:
        raise ValueError
    length = _ll_rangelen(start, stop, step)
    l = LIST.ll_newlist(length)
    if LIST.ITEM is not Void:
        idx = 0
        while idx < length:
            l.ll_setitem_fast(idx, start)
            start += step
            idx += 1
    return l

# ____________________________________________________________
#
#  Iteration.

class AbstractRangeIteratorRepr(IteratorRepr):
    def __init__(self, r_rng):
        self.r_rng = r_rng
        if r_rng.step != 0:
            self.lowleveltype = r_rng.RANGEITER
        else:
            self.lowleveltype = r_rng.RANGESTITER

    def newiter(self, hop):
        v_rng, = hop.inputargs(self.r_rng)
        citerptr = hop.inputconst(Void, self.lowleveltype)
        return hop.gendirectcall(self.ll_rangeiter, citerptr, v_rng)

    def rtype_next(self, hop):
        v_iter, = hop.inputargs(self)
        args = hop.inputconst(Signed, self.r_rng.step),
        if self.r_rng.step > 0:
            llfn = ll_rangenext_up
        elif self.r_rng.step < 0:
            llfn = ll_rangenext_down
        else:
            llfn = ll_rangenext_updown
            args = ()
        hop.has_implicit_exception(StopIteration) # record that we know about it
        hop.exception_is_here()
        return hop.gendirectcall(llfn, v_iter, *args)

def ll_rangenext_up(iter, step):
    next = iter.next
    if next >= iter.stop:
        raise StopIteration
    iter.next = next + step
    return next

def ll_rangenext_down(iter, step):
    next = iter.next
    if next <= iter.stop:
        raise StopIteration
    iter.next = next + step
    return next

def ll_rangenext_updown(iter):
    step = iter.step
    if step > 0:
        return ll_rangenext_up(iter, step)
    else:
        return ll_rangenext_down(iter, step)

# ____________________________________________________________
#
# Support for enumerate().

class EnumerateIteratorRepr(IteratorRepr):
    def __init__(self, r_baseiter, const_startindex):
        self.r_baseiter = r_baseiter
        self.lowleveltype = r_baseiter.lowleveltype
        # only supports for now enumerate() on sequence types whose iterators
        # have a method ll_getnextindex.  It could be added for most
        # iterator types, but it's a bit messy for no clear benefit.
        if not hasattr(r_baseiter, 'll_getnextindex'):
            raise TyperError("not implemented for now: enumerate(x) where x "
                             "is not a regular list (got %r)" % (r_baseiter,))
        self.ll_getnextindex = r_baseiter.ll_getnextindex
        self.const_startindex = const_startindex

    def rtype_next(self, hop):
        v_enumerate, = hop.inputargs(self)
        v_index = hop.gendirectcall(self.ll_getnextindex, v_enumerate)
        if self.const_startindex is not None:
            v_index = hop.llops.genop(
                "int_add",
                [v_index, hop.llops.genconst(self.const_startindex)],
                resulttype=v_index.concretetype)
        hop2 = hop.copy()
        hop2.args_r = [self.r_baseiter]
        r_item_src = self.r_baseiter.external_item_repr
        r_item_dst = hop.r_result.items_r[1]
        v_item = self.r_baseiter.rtype_next(hop2)
        v_item = hop.llops.convertvar(v_item, r_item_src, r_item_dst)
        return hop.r_result.newtuple(hop.llops, hop.r_result,
                                     [v_index, v_item])

def rtype_builtin_enumerate(hop):
    hop.exception_cannot_occur()
    hop2 = hop.copy()
    hop2.args_r = [hop.args_r[0]]
    hop2.args_v = [hop.args_v[0]]
    hop2.args_s = [hop.args_s[0]]
    return hop.r_result.r_baseiter.newiter(hop2)
