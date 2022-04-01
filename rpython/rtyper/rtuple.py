import operator

from rpython.annotator import model as annmodel
from rpython.flowspace.model import Constant
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem.lltype import (
    Void, Signed, Bool, Ptr, GcStruct, malloc, typeOf, nullptr)
from rpython.rtyper.lltypesystem.rstr import LLHelpers
from rpython.rtyper.rstr import AbstractStringRepr
from rpython.rtyper.rmodel import (Repr, inputconst, IteratorRepr,
    externalvsinternal)
from rpython.rtyper.rint import IntegerRepr
from rpython.tool.pairtype import pairtype


class __extend__(annmodel.SomeTuple):
    def rtyper_makerepr(self, rtyper):
        return TupleRepr(rtyper, [rtyper.getrepr(s_item) for s_item in self.items])

    def rtyper_makekey(self):
        keys = [s_item.rtyper_makekey() for s_item in self.items]
        return tuple([self.__class__] + keys)


_gen_eq_function_cache = {}
_gen_hash_function_cache = {}
_gen_str_function_cache = {}

def gen_eq_function(items_r):
    eq_funcs = [r_item.get_ll_eq_function() or operator.eq for r_item in items_r]
    key = tuple(eq_funcs)
    try:
        return _gen_eq_function_cache[key]
    except KeyError:
        autounrolling_funclist = unrolling_iterable(enumerate(eq_funcs))

        def ll_eq(t1, t2):
            equal_so_far = True
            for i, eqfn in autounrolling_funclist:
                if not equal_so_far:
                    return False
                attrname = 'item%d' % i
                item1 = getattr(t1, attrname)
                item2 = getattr(t2, attrname)
                equal_so_far = eqfn(item1, item2)
            return equal_so_far

        _gen_eq_function_cache[key] = ll_eq
        return ll_eq

def gen_hash_function(items_r):
    # based on CPython
    hash_funcs = [r_item.get_ll_hash_function() for r_item in items_r]
    key = tuple(hash_funcs)
    try:
        return _gen_hash_function_cache[key]
    except KeyError:
        autounrolling_funclist = unrolling_iterable(enumerate(hash_funcs))

        def ll_hash(t):
            """Must be kept in sync with rlib.objectmodel._hash_tuple()."""
            x = 0x345678
            for i, hash_func in autounrolling_funclist:
                attrname = 'item%d' % i
                item = getattr(t, attrname)
                y = hash_func(item)
                x = intmask((1000003 * x) ^ y)
            return x

        _gen_hash_function_cache[key] = ll_hash
        return ll_hash

def gen_str_function(tuplerepr):
    items_r = tuplerepr.items_r
    key = tuple([r_item.ll_str for r_item in items_r])
    try:
        return _gen_str_function_cache[key]
    except KeyError:
        autounrolling_funclist = unrolling_iterable(enumerate(key))

        constant = LLHelpers.ll_constant
        start = LLHelpers.ll_build_start
        push = LLHelpers.ll_build_push
        finish = LLHelpers.ll_build_finish
        length = len(items_r)

        def ll_str(t):
            if length == 0:
                return constant("()")
            buf = start(2 * length + 1)
            push(buf, constant("("), 0)
            for i, str_func in autounrolling_funclist:
                attrname = 'item%d' % i
                item = getattr(t, attrname)
                if i > 0:
                    push(buf, constant(", "), 2 * i)
                push(buf, str_func(item), 2 * i + 1)
            if length == 1:
                push(buf, constant(",)"), 2 * length)
            else:
                push(buf, constant(")"), 2 * length)
            return finish(buf)

        _gen_str_function_cache[key] = ll_str
        return ll_str


# ____________________________________________________________
#
#  Concrete implementation of RPython tuples:
#
#    struct tuple {
#        type0 item0;
#        type1 item1;
#        type2 item2;
#        ...
#    }

def TUPLE_TYPE(field_lltypes):
    if len(field_lltypes) == 0:
        return Void      # empty tuple
    else:
        fields = [('item%d' % i, TYPE) for i, TYPE in enumerate(field_lltypes)]
        kwds = {'hints': {'immutable': True,
                          'noidentity': True}}
        return Ptr(GcStruct('tuple%d' % len(field_lltypes), *fields, **kwds))


class TupleRepr(Repr):

    def __init__(self, rtyper, items_r):
        self.items_r = []
        self.external_items_r = []
        for item_r in items_r:
            external_repr, internal_repr = externalvsinternal(rtyper, item_r)
            self.items_r.append(internal_repr)
            self.external_items_r.append(external_repr)
        items_r = self.items_r
        self.fieldnames = ['item%d' % i for i in range(len(items_r))]
        self.lltypes = [r.lowleveltype for r in items_r]
        self.tuple_cache = {}
        self.lowleveltype = TUPLE_TYPE(self.lltypes)

    def getitem(self, llops, v_tuple, index):
        """Generate the operations to get the index'th item of v_tuple,
        in the external repr external_items_r[index]."""
        v = self.getitem_internal(llops, v_tuple, index)
        r_item = self.items_r[index]
        r_external_item = self.external_items_r[index]
        return llops.convertvar(v, r_item, r_external_item)

    @classmethod
    def newtuple(cls, llops, r_tuple, items_v):
        # items_v should have the lowleveltype of the internal reprs
        assert len(r_tuple.items_r) == len(items_v)
        for r_item, v_item in zip(r_tuple.items_r, items_v):
            assert r_item.lowleveltype == v_item.concretetype
        #
        if len(r_tuple.items_r) == 0:
            return inputconst(Void, ())    # a Void empty tuple
        c1 = inputconst(Void, r_tuple.lowleveltype.TO)
        cflags = inputconst(Void, {'flavor': 'gc'})
        v_result = llops.genop('malloc', [c1, cflags],
                                         resulttype = r_tuple.lowleveltype)
        for i in range(len(r_tuple.items_r)):
            cname = inputconst(Void, r_tuple.fieldnames[i])
            llops.genop('setfield', [v_result, cname, items_v[i]])
        return v_result

    @classmethod
    def newtuple_cached(cls, hop, items_v):
        r_tuple = hop.r_result
        if hop.s_result.is_constant():
            return inputconst(r_tuple, hop.s_result.const)
        else:
            return cls.newtuple(hop.llops, r_tuple, items_v)

    @classmethod
    def _rtype_newtuple(cls, hop):
        r_tuple = hop.r_result
        vlist = hop.inputargs(*r_tuple.items_r)
        return cls.newtuple_cached(hop, vlist)

    def convert_const(self, value):
        assert isinstance(value, tuple) and len(value) == len(self.items_r)
        key = tuple([Constant(item) for item in value])
        try:
            return self.tuple_cache[key]
        except KeyError:
            p = self.instantiate()
            self.tuple_cache[key] = p
            for obj, r, name in zip(value, self.items_r, self.fieldnames):
                if r.lowleveltype is not Void:
                    setattr(p, name, r.convert_const(obj))
            return p

    def compact_repr(self):
        return "TupleR %s" % ' '.join([llt._short_name() for llt in self.lltypes])

    def rtype_len(self, hop):
        return hop.inputconst(Signed, len(self.items_r))

    def get_ll_eq_function(self):
        return gen_eq_function(self.items_r)

    def get_ll_hash_function(self):
        return gen_hash_function(self.items_r)

    # no get_ll_fasthash_function: the hash is a bit slow, better cache
    # it inside dict entries

    ll_str = property(gen_str_function)

    def make_iterator_repr(self, variant=None):
        if variant is not None:
            raise TyperError("unsupported %r iterator over a tuple" %
                             (variant,))
        if len(self.items_r) == 1:
            # subclasses are supposed to set the IteratorRepr attribute
            return self.IteratorRepr(self)
        raise TyperError("can only iterate over tuples of length 1 for now")

    def instantiate(self):
        if len(self.items_r) == 0:
            return dum_empty_tuple     # PBC placeholder for an empty tuple
        else:
            return malloc(self.lowleveltype.TO)

    def rtype_bltn_list(self, hop):
        from rpython.rtyper.lltypesystem import rlist
        nitems = len(self.items_r)
        vtup = hop.inputarg(self, 0)
        LIST = hop.r_result.lowleveltype.TO
        cno = inputconst(Signed, nitems)
        hop.exception_is_here()
        vlist = hop.gendirectcall(LIST.ll_newlist, cno)
        v_func = hop.inputconst(Void, rlist.dum_nocheck)
        for index in range(nitems):
            name = self.fieldnames[index]
            ritem = self.items_r[index]
            cname = hop.inputconst(Void, name)
            vitem = hop.genop('getfield', [vtup, cname], resulttype = ritem)
            vitem = hop.llops.convertvar(vitem, ritem, hop.r_result.item_repr)
            cindex = inputconst(Signed, index)
            hop.gendirectcall(rlist.ll_setitem_nonneg, v_func, vlist, cindex, vitem)
        return vlist

    def getitem_internal(self, llops, v_tuple, index):
        """Return the index'th item, in internal repr."""
        name = self.fieldnames[index]
        llresult = self.lltypes[index]
        cname = inputconst(Void, name)
        return  llops.genop('getfield', [v_tuple, cname], resulttype = llresult)


def rtype_newtuple(hop):
    return TupleRepr._rtype_newtuple(hop)

newtuple = TupleRepr.newtuple

def dum_empty_tuple(): pass


class __extend__(pairtype(TupleRepr, IntegerRepr)):

    def rtype_getitem((r_tup, r_int), hop):
        v_tuple, v_index = hop.inputargs(r_tup, Signed)
        if not isinstance(v_index, Constant):
            raise TyperError("non-constant tuple index")
        if hop.has_implicit_exception(IndexError):
            hop.exception_cannot_occur()
        index = v_index.value
        return r_tup.getitem(hop.llops, v_tuple, index)

class __extend__(TupleRepr):

    def rtype_getslice(r_tup, hop):
        s_start = hop.args_s[1]
        s_stop = hop.args_s[2]
        assert s_start.is_immutable_constant(),"tuple slicing: needs constants"
        assert s_stop.is_immutable_constant(), "tuple slicing: needs constants"
        start = s_start.const
        stop = s_stop.const
        indices = range(len(r_tup.items_r))[start:stop]
        assert len(indices) == len(hop.r_result.items_r)

        v_tup = hop.inputarg(r_tup, arg=0)
        items_v = [r_tup.getitem_internal(hop.llops, v_tup, i)
                   for i in indices]
        return hop.r_result.newtuple(hop.llops, hop.r_result, items_v)

class __extend__(pairtype(TupleRepr, Repr)):
    def rtype_contains((r_tup, r_item), hop):
        s_tup = hop.args_s[0]
        if not s_tup.is_constant():
            raise TyperError("contains() on non-const tuple")
        t = s_tup.const
        s_item = hop.args_s[1]
        r_item = hop.args_r[1]
        v_arg = hop.inputarg(r_item, arg=1)
        ll_eq = r_item.get_ll_eq_function() or _ll_equal
        v_result = None
        for x in t:
            s_const_item = hop.rtyper.annotator.bookkeeper.immutablevalue(x)
            if not s_item.contains(s_const_item):
                continue   # corner case, see test_constant_tuple_contains_bug
            c_tuple_item = hop.inputconst(r_item, x)
            v_equal = hop.gendirectcall(ll_eq, v_arg, c_tuple_item)
            if v_result is None:
                v_result = v_equal
            else:
                v_result = hop.genop("int_or", [v_result, v_equal],
                                     resulttype = Bool)
        hop.exception_cannot_occur()
        return v_result or hop.inputconst(Bool, False)

class __extend__(pairtype(TupleRepr, TupleRepr)):

    def rtype_add((r_tup1, r_tup2), hop):
        v_tuple1, v_tuple2 = hop.inputargs(r_tup1, r_tup2)
        vlist = []
        for i in range(len(r_tup1.items_r)):
            vlist.append(r_tup1.getitem_internal(hop.llops, v_tuple1, i))
        for i in range(len(r_tup2.items_r)):
            vlist.append(r_tup2.getitem_internal(hop.llops, v_tuple2, i))
        return r_tup1.newtuple_cached(hop, vlist)
    rtype_inplace_add = rtype_add

    def rtype_eq((r_tup1, r_tup2), hop):
        s_tup = annmodel.unionof(*hop.args_s)
        r_tup = hop.rtyper.getrepr(s_tup)
        v_tuple1, v_tuple2 = hop.inputargs(r_tup, r_tup)
        ll_eq = r_tup.get_ll_eq_function()
        return hop.gendirectcall(ll_eq, v_tuple1, v_tuple2)

    def rtype_ne(tup1tup2, hop):
        v_res = tup1tup2.rtype_eq(hop)
        return hop.genop('bool_not', [v_res], resulttype=Bool)

    def convert_from_to((r_from, r_to), v, llops):
        if len(r_from.items_r) == len(r_to.items_r):
            if r_from.lowleveltype == r_to.lowleveltype:
                return v
            n = len(r_from.items_r)
            items_v = []
            for i in range(n):
                item_v = r_from.getitem_internal(llops, v, i)
                item_v = llops.convertvar(item_v,
                                              r_from.items_r[i],
                                              r_to.items_r[i])
                items_v.append(item_v)
            return r_from.newtuple(llops, r_to, items_v)
        return NotImplemented

    def rtype_is_((robj1, robj2), hop):
        raise TyperError("cannot compare tuples with 'is'")

class __extend__(pairtype(AbstractStringRepr, TupleRepr)):
    def rtype_mod((r_str, r_tuple), hop):
        r_tuple = hop.args_r[1]
        v_tuple = hop.args_v[1]

        sourcevars = []
        for i, r_arg in enumerate(r_tuple.external_items_r):
            v_item = r_tuple.getitem(hop.llops, v_tuple, i)
            sourcevars.append((v_item, r_arg))

        return r_str.ll.do_stringformat(hop, sourcevars)

# ____________________________________________________________
#
#  Iteration.

class AbstractTupleIteratorRepr(IteratorRepr):

    def newiter(self, hop):
        v_tuple, = hop.inputargs(self.r_tuple)
        citerptr = hop.inputconst(Void, self.lowleveltype)
        return hop.gendirectcall(self.ll_tupleiter, citerptr, v_tuple)

    def rtype_next(self, hop):
        v_iter, = hop.inputargs(self)
        hop.has_implicit_exception(StopIteration) # record that we know about it
        hop.exception_is_here()
        v = hop.gendirectcall(self.ll_tuplenext, v_iter)
        return hop.llops.convertvar(v, self.r_tuple.items_r[0], self.r_tuple.external_items_r[0])

class Length1TupleIteratorRepr(AbstractTupleIteratorRepr):

    def __init__(self, r_tuple):
        self.r_tuple = r_tuple
        self.lowleveltype = Ptr(GcStruct('tuple1iter',
                                         ('tuple', r_tuple.lowleveltype)))
        self.ll_tupleiter = ll_tupleiter
        self.ll_tuplenext = ll_tuplenext

TupleRepr.IteratorRepr = Length1TupleIteratorRepr

def ll_tupleiter(ITERPTR, tuple):
    iter = malloc(ITERPTR.TO)
    iter.tuple = tuple
    return iter

def ll_tuplenext(iter):
    # for iterating over length 1 tuples only!
    t = iter.tuple
    if t:
        iter.tuple = nullptr(typeOf(t).TO)
        return t.item0
    else:
        raise StopIteration

def _ll_equal(x, y):
    return x == y
