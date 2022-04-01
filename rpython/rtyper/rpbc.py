import types

from rpython.flowspace.model import FunctionGraph, Link, Block, SpaceOperation
from rpython.annotator import model as annmodel
from rpython.annotator.description import (
    FunctionDesc, MethodDesc, FrozenDesc, MethodOfFrozenDesc)
from rpython.annotator.classdesc import ClassDesc
from rpython.flowspace.model import Constant
from rpython.annotator.argument import simple_args
from rpython.rtyper.debug import ll_assert
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper import rclass, callparse
from rpython.rtyper.rclass import CLASSTYPE, OBJECT_VTABLE, OBJECTPTR
from rpython.rtyper.error import TyperError
from rpython.rtyper.lltypesystem import rffi
from rpython.rtyper.lltypesystem import llmemory
from rpython.rtyper.lltypesystem.lltype import (
    typeOf, Void, ForwardReference, Struct, Bool, Char, Ptr, malloc, nullptr,
    Array, Signed, cast_pointer, getfunctionptr, cast_ptr_to_int)
from rpython.rtyper.rmodel import (Repr, inputconst, CanBeNull, mangle,
    warning, impossible_repr)
from rpython.tool.pairtype import pair, pairtype
from rpython.translator.unsimplify import varoftype


def small_cand(rtyper, s_pbc):
    if 1 < len(s_pbc.descriptions) < rtyper.getconfig().translation.withsmallfuncsets:
        callfamily = s_pbc.any_description().getcallfamily()
        llct = get_concrete_calltable(rtyper, callfamily)
        if (len(llct.uniquerows) == 1 and
                (not s_pbc.subset_of or small_cand(rtyper, s_pbc.subset_of))):
            return True
    return False

class __extend__(annmodel.SomePBC):
    def rtyper_makerepr(self, rtyper):
        kind = self.getKind()
        if issubclass(kind, FunctionDesc):
            if len(self.descriptions) == 1 and not self.can_be_None:
                getRepr = FunctionRepr
            else:
                sample = self.any_description()
                callfamily = sample.querycallfamily()
                if callfamily and callfamily.total_calltable_size > 0:
                    getRepr = FunctionsPBCRepr
                    if small_cand(rtyper, self):
                        getRepr = SmallFunctionSetPBCRepr
                else:
                    getRepr = getFrozenPBCRepr
        elif issubclass(kind, ClassDesc):
            # user classes
            getRepr = ClassesPBCRepr
        elif issubclass(kind, MethodDesc):
            getRepr = MethodsPBCRepr
        elif issubclass(kind, FrozenDesc):
            getRepr = getFrozenPBCRepr
        elif issubclass(kind, MethodOfFrozenDesc):
            getRepr = MethodOfFrozenPBCRepr
        else:
            raise TyperError("unexpected PBC kind %r" % (kind,))

        return getRepr(rtyper, self)

    def rtyper_makekey(self):
        lst = list(self.descriptions)
        lst.sort()
        if self.subset_of:
            t = self.subset_of.rtyper_makekey()
        else:
            t = ()
        return tuple([self.__class__, self.can_be_None] + lst) + t

# ____________________________________________________________

class ConcreteCallTableRow(dict):
    """A row in a concrete call table."""
    @classmethod
    def from_row(cls, rtyper, row):
        concreterow = cls()
        for funcdesc, graph in row.items():
            llfn = rtyper.getcallable(graph)
            concreterow[funcdesc] = llfn
        assert len(concreterow) > 0
        # 'typeOf(llfn)' should be the same for all graphs
        concreterow.fntype = typeOf(llfn)
        return concreterow


class LLCallTable(object):
    """A call table of a call family with low-level functions."""
    def __init__(self, table, uniquerows):
        self.table = table  # (shape,index): row, maybe with duplicates
        self.uniquerows = uniquerows  # list of rows, without duplicates

    def lookup(self, row):
        """A 'matching' row is one that has the same llfn, except
        that it may have more or less 'holes'."""
        for existingindex, existingrow in enumerate(self.uniquerows):
            if row.fntype != existingrow.fntype:
                continue   # not the same pointer type, cannot match
            for funcdesc, llfn in row.items():
                if funcdesc in existingrow:
                    if llfn != existingrow[funcdesc]:
                        break   # mismatch
            else:
                # potential match, unless the two rows have no common funcdesc
                merged = ConcreteCallTableRow(row)
                merged.update(existingrow)
                merged.fntype = row.fntype
                if len(merged) == len(row) + len(existingrow):
                    pass   # no common funcdesc, not a match
                else:
                    return existingindex, merged
        raise LookupError

    def add(self, row):
        """Add a row to the table, potentially merging it with an existing row
        """
        try:
            index, merged = self.lookup(row)
        except LookupError:
            self.uniquerows.append(row)   # new row
        else:
            if merged == self.uniquerows[index]:
                pass    # already exactly in the table
            else:
                del self.uniquerows[index]
                self.add(merged)   # add the potentially larger merged row


def build_concrete_calltable(rtyper, callfamily):
    """Build a complete call table of a call family
    with concrete low-level function objs.
    """
    concretetable = {}
    uniquerows = []
    llct = LLCallTable(concretetable, uniquerows)

    concreterows = {}
    for shape, rows in callfamily.calltables.items():
        for index, row in enumerate(rows):
            concreterow = ConcreteCallTableRow.from_row(rtyper, row)
            concreterows[shape, index] = concreterow
            llct.add(concreterow)

    for (shape, index), row in concreterows.items():
        existingindex, biggerrow = llct.lookup(row)
        row = llct.uniquerows[existingindex]
        assert biggerrow == row
        llct.table[shape, index] = row

    if len(llct.uniquerows) == 1:
        llct.uniquerows[0].attrname = None
    else:
        for finalindex, row in enumerate(llct.uniquerows):
            row.attrname = 'variant%d' % finalindex

    return llct

def get_concrete_calltable(rtyper, callfamily):
    """Get a complete call table of a call family
    with concrete low-level function objs.
    """
    # cache on the callfamily
    try:
        cached = rtyper.concrete_calltables[callfamily]
    except KeyError:
        llct = build_concrete_calltable(rtyper, callfamily)
        cached = llct, callfamily.total_calltable_size
        rtyper.concrete_calltables[callfamily] = cached
    else:
        llct, oldsize = cached
        if oldsize != callfamily.total_calltable_size:
            raise TyperError("call table was unexpectedly extended")
    return llct

class FunctionReprBase(Repr):
    def __init__(self, rtyper, s_pbc):
        self.rtyper = rtyper
        self.s_pbc = s_pbc
        self.callfamily = s_pbc.any_description().getcallfamily()

    def get_s_callable(self):
        return self.s_pbc

    def get_r_implfunc(self):
        return self, 0

    def get_s_signatures(self, shape):
        funcdesc = self.s_pbc.any_description()
        return funcdesc.get_s_signatures(shape)

    def rtype_simple_call(self, hop):
        return self.call(hop)

    def rtype_call_args(self, hop):
        return self.call(hop)

    def call(self, hop):
        bk = self.rtyper.annotator.bookkeeper
        args = hop.spaceop.build_args(hop.args_s[1:])
        s_pbc = hop.args_s[0]   # possibly more precise than self.s_pbc
        descs = list(s_pbc.descriptions)
        shape, index = self.callfamily.find_row(bk, descs, args, hop.spaceop)
        row_of_graphs = self.callfamily.calltables[shape][index]
        anygraph = row_of_graphs.itervalues().next()  # pick any witness
        vfn = hop.inputarg(self, arg=0)
        vlist = [self.convert_to_concrete_llfn(vfn, shape, index,
                                               hop.llops)]
        vlist += callparse.callparse(self.rtyper, anygraph, hop)
        rresult = callparse.getrresult(self.rtyper, anygraph)
        hop.exception_is_here()
        if isinstance(vlist[0], Constant):
            v = hop.genop('direct_call', vlist, resulttype=rresult)
        else:
            vlist.append(hop.inputconst(Void, row_of_graphs.values()))
            v = hop.genop('indirect_call', vlist, resulttype=rresult)
        if hop.r_result is impossible_repr:
            return None      # see test_always_raising_methods
        else:
            return hop.llops.convertvar(v, rresult, hop.r_result)


class FunctionsPBCRepr(CanBeNull, FunctionReprBase):
    """Representation selected for a PBC of functions."""

    def __init__(self, rtyper, s_pbc):
        FunctionReprBase.__init__(self, rtyper, s_pbc)
        llct = get_concrete_calltable(self.rtyper, self.callfamily)
        self.concretetable = llct.table
        self.uniquerows = llct.uniquerows
        if len(llct.uniquerows) == 1:
            row = llct.uniquerows[0]
            self.lowleveltype = row.fntype
        else:
            # several functions, each with several specialized variants.
            # each function becomes a pointer to a Struct containing
            # pointers to its variants.
            self.lowleveltype = self.setup_specfunc()
        self.funccache = {}

    def setup_specfunc(self):
        fields = []
        for row in self.uniquerows:
            fields.append((row.attrname, row.fntype))
        kwds = {'hints': {'immutable': True, 'static_immutable': True}}
        return Ptr(Struct('specfunc', *fields, **kwds))

    def create_specfunc(self):
        return malloc(self.lowleveltype.TO, immortal=True)

    def get_specfunc_row(self, llop, v, c_rowname, resulttype):
        return llop.genop('getfield', [v, c_rowname], resulttype=resulttype)

    def convert_desc(self, funcdesc):
        # get the whole "column" of the call table corresponding to this desc
        try:
            return self.funccache[funcdesc]
        except KeyError:
            pass
        llfns = {}
        found_anything = False
        for row in self.uniquerows:
            if funcdesc in row:
                llfn = row[funcdesc]
                found_anything = True
            else:
                # missing entry -- need a 'null' of the type that matches
                # this row
                llfn = nullptr(row.fntype.TO)
            llfns[row.attrname] = llfn
        if len(self.uniquerows) == 1:
            if found_anything:
                result = llfn   # from the loop above
            else:
                # extremely rare case, shown only sometimes by
                # test_bug_callfamily: don't emit NULL, because that
                # would be interpreted as equal to None...  It should
                # never be called anyway.
                result = rffi.cast(self.lowleveltype, ~len(self.funccache))
        else:
            # build a Struct with all the values collected in 'llfns'
            result = self.create_specfunc()
            for attrname, llfn in llfns.items():
                setattr(result, attrname, llfn)
        self.funccache[funcdesc] = result
        return result

    def convert_const(self, value):
        if isinstance(value, types.MethodType) and value.im_self is None:
            value = value.im_func  # unbound method -> bare function
        elif isinstance(value, staticmethod):
            value = value.__get__(42)  # hackish, get the function wrapped by staticmethod
        if value is None:
            null = nullptr(self.lowleveltype.TO)
            return null
        funcdesc = self.rtyper.annotator.bookkeeper.getdesc(value)
        return self.convert_desc(funcdesc)

    def convert_to_concrete_llfn(self, v, shape, index, llop):
        """Convert the variable 'v' to a variable referring to a concrete
        low-level function.  In case the call table contains multiple rows,
        'index' and 'shape' tells which of its items we are interested in.
        """
        assert v.concretetype == self.lowleveltype
        if len(self.uniquerows) == 1:
            return v
        else:
            # 'v' is a Struct pointer, read the corresponding field
            row = self.concretetable[shape, index]
            cname = inputconst(Void, row.attrname)
            return self.get_specfunc_row(llop, v, cname, row.fntype)


class FunctionRepr(FunctionReprBase):
    """Repr for a constant function"""

    lowleveltype = Void

    def convert_desc(self, funcdesc):
        return None

    def convert_const(self, value):
        return None

    def convert_to_concrete_llfn(self, v, shape, index, llop):
        """Convert the variable 'v' to a variable referring to a concrete
        low-level function.  In case the call table contains multiple rows,
        'index' and 'shape' tells which of its items we are interested in.
        """
        assert v.concretetype == Void
        funcdesc, = self.s_pbc.descriptions
        row_of_one_graph = self.callfamily.calltables[shape][index]
        graph = row_of_one_graph[funcdesc]
        llfn = self.rtyper.getcallable(graph)
        return inputconst(typeOf(llfn), llfn)

    def get_unique_llfn(self):
        # try to build a unique low-level function.  Avoid to use
        # whenever possible!  Doesn't work with specialization, multiple
        # different call sites, etc.
        funcdesc, = self.s_pbc.descriptions
        tables = []        # find the simple call in the calltable
        for shape, table in self.callfamily.calltables.items():
            if not shape[1] and not shape[2]:
                tables.append(table)
        if len(tables) != 1:
            raise TyperError("cannot pass a function with various call shapes")
        table, = tables
        graphs = []
        for row in table:
            if funcdesc in row:
                graphs.append(row[funcdesc])
        if not graphs:
            raise TyperError("cannot pass here a function that is not called")
        graph = graphs[0]
        if graphs != [graph] * len(graphs):
            raise TyperError("cannot pass a specialized function here")
        llfn = self.rtyper.getcallable(graph)
        return inputconst(typeOf(llfn), llfn)

    def get_concrete_llfn(self, s_pbc, args_s, op):
        bk = self.rtyper.annotator.bookkeeper
        funcdesc, = s_pbc.descriptions
        with bk.at_position(None):
            argspec = simple_args(args_s)
            graph = funcdesc.get_graph(argspec, op)
        llfn = self.rtyper.getcallable(graph)
        return inputconst(typeOf(llfn), llfn)



class __extend__(pairtype(FunctionRepr, FunctionRepr)):
    def convert_from_to((r_fpbc1, r_fpbc2), v, llops):
        return v

class __extend__(pairtype(FunctionRepr, FunctionsPBCRepr)):
    def convert_from_to((r_fpbc1, r_fpbc2), v, llops):
        return inputconst(r_fpbc2, r_fpbc1.s_pbc.const)

class __extend__(pairtype(FunctionsPBCRepr, FunctionRepr)):
    def convert_from_to((r_fpbc1, r_fpbc2), v, llops):
        return inputconst(Void, None)

class __extend__(pairtype(FunctionsPBCRepr, FunctionsPBCRepr)):
    def convert_from_to((r_fpbc1, r_fpbc2), v, llops):
        # this check makes sense because both source and dest repr are FunctionsPBCRepr
        if r_fpbc1.lowleveltype == r_fpbc2.lowleveltype:
            return v
        return NotImplemented


class SmallFunctionSetPBCRepr(FunctionReprBase):
    def __init__(self, rtyper, s_pbc):
        FunctionReprBase.__init__(self, rtyper, s_pbc)
        llct = get_concrete_calltable(self.rtyper, self.callfamily)
        assert len(llct.uniquerows) == 1
        self.lowleveltype = Char
        self.pointer_repr = FunctionsPBCRepr(rtyper, s_pbc)
        self._conversion_tables = {}
        self._compression_function = None
        self._dispatch_cache = {}

    def _setup_repr(self):
        if self.s_pbc.subset_of:
            assert self.s_pbc.can_be_None == self.s_pbc.subset_of.can_be_None
            r = self.rtyper.getrepr(self.s_pbc.subset_of)
            if r is not self:
                r.setup()
                self.descriptions = r.descriptions
                self.c_pointer_table = r.c_pointer_table
                return
        self.descriptions = list(self.s_pbc.descriptions)
        if self.s_pbc.can_be_None:
            self.descriptions.insert(0, None)
        POINTER_TABLE = Array(self.pointer_repr.lowleveltype,
                              hints={'nolength': True, 'immutable': True,
                                     'static_immutable': True})
        pointer_table = malloc(POINTER_TABLE, len(self.descriptions),
                               immortal=True)
        for i, desc in enumerate(self.descriptions):
            if desc is not None:
                pointer_table[i] = self.pointer_repr.convert_desc(desc)
            else:
                pointer_table[i] = self.pointer_repr.convert_const(None)
        self.c_pointer_table = inputconst(Ptr(POINTER_TABLE), pointer_table)

    def convert_desc(self, funcdesc):
        return chr(self.descriptions.index(funcdesc))

    def convert_const(self, value):
        if isinstance(value, types.MethodType) and value.im_self is None:
            value = value.im_func   # unbound method -> bare function
        if value is None:
            assert self.descriptions[0] is None
            return chr(0)
        funcdesc = self.rtyper.annotator.bookkeeper.getdesc(value)
        return self.convert_desc(funcdesc)

    def special_uninitialized_value(self):
        return chr(0xFF)

    def dispatcher(self, shape, index, argtypes, resulttype):
        key = shape, index, tuple(argtypes), resulttype
        if key in self._dispatch_cache:
            return self._dispatch_cache[key]
        graph = self.make_dispatcher(shape, index, argtypes, resulttype)
        self.rtyper.annotator.translator.graphs.append(graph)
        ll_ret = getfunctionptr(graph)
        c_ret = self._dispatch_cache[key] = inputconst(typeOf(ll_ret), ll_ret)
        return c_ret

    def make_dispatcher(self, shape, index, argtypes, resulttype):
        inputargs = [varoftype(t) for t in [Char] + argtypes]
        startblock = Block(inputargs)
        startblock.exitswitch = inputargs[0]
        graph = FunctionGraph("dispatcher", startblock, varoftype(resulttype))
        row_of_graphs = self.callfamily.calltables[shape][index]
        links = []
        descs = list(self.s_pbc.descriptions)
        if self.s_pbc.can_be_None:
            descs.insert(0, None)
        for desc in descs:
            if desc is None:
                continue
            args_v = [varoftype(t) for t in argtypes]
            b = Block(args_v)
            llfn = self.rtyper.getcallable(row_of_graphs[desc])
            v_fn = inputconst(typeOf(llfn), llfn)
            v_result = varoftype(resulttype)
            b.operations.append(
                SpaceOperation("direct_call", [v_fn] + args_v, v_result))
            b.closeblock(Link([v_result], graph.returnblock))
            i = self.descriptions.index(desc)
            links.append(Link(inputargs[1:], b, chr(i)))
            links[-1].llexitcase = chr(i)
        startblock.closeblock(*links)
        return graph

    def call(self, hop):
        bk = self.rtyper.annotator.bookkeeper
        args = hop.spaceop.build_args(hop.args_s[1:])
        s_pbc = hop.args_s[0]   # possibly more precise than self.s_pbc
        descs = list(s_pbc.descriptions)
        shape, index = self.callfamily.find_row(bk, descs, args, hop.spaceop)
        row_of_graphs = self.callfamily.calltables[shape][index]
        anygraph = row_of_graphs.itervalues().next()  # pick any witness
        vlist = [hop.inputarg(self, arg=0)]
        vlist += callparse.callparse(self.rtyper, anygraph, hop)
        rresult = callparse.getrresult(self.rtyper, anygraph)
        hop.exception_is_here()
        v_dispatcher = self.dispatcher(shape, index,
                [v.concretetype for v in vlist[1:]], rresult.lowleveltype)
        v_result = hop.genop('direct_call', [v_dispatcher] + vlist,
                             resulttype=rresult)
        return hop.llops.convertvar(v_result, rresult, hop.r_result)

    def rtype_bool(self, hop):
        if not self.s_pbc.can_be_None:
            return inputconst(Bool, True)
        else:
            v1, = hop.inputargs(self)
            return hop.genop('char_ne', [v1, inputconst(Char, '\000')],
                         resulttype=Bool)


class __extend__(pairtype(SmallFunctionSetPBCRepr, FunctionRepr)):
    def convert_from_to((r_set, r_ptr), v, llops):
        return inputconst(Void, None)

class __extend__(pairtype(SmallFunctionSetPBCRepr, FunctionsPBCRepr)):
    def convert_from_to((r_set, r_ptr), v, llops):
        assert v.concretetype is Char
        v_int = llops.genop('cast_char_to_int', [v], resulttype=Signed)
        return llops.genop('getarrayitem', [r_set.c_pointer_table, v_int],
                            resulttype=r_ptr.lowleveltype)


def compression_function(r_set):
    if r_set._compression_function is None:
        table = []
        for i, p in enumerate(r_set.c_pointer_table.value):
            table.append((chr(i), p))
        last_c, last_p = table[-1]
        unroll_table = unrolling_iterable(table[:-1])

        def ll_compress(fnptr):
            for c, p in unroll_table:
                if fnptr == p:
                    return c
            else:
                ll_assert(fnptr == last_p, "unexpected function pointer")
                return last_c
        r_set._compression_function = ll_compress
    return r_set._compression_function


class __extend__(pairtype(FunctionRepr, SmallFunctionSetPBCRepr)):
    def convert_from_to((r_ptr, r_set), v, llops):
        desc, = r_ptr.s_pbc.descriptions
        return inputconst(Char, r_set.convert_desc(desc))

class __extend__(pairtype(FunctionsPBCRepr, SmallFunctionSetPBCRepr)):
    def convert_from_to((r_ptr, r_set), v, llops):
        ll_compress = compression_function(r_set)
        return llops.gendirectcall(ll_compress, v)

class __extend__(pairtype(FunctionReprBase, FunctionReprBase)):
    def rtype_is_((robj1, robj2), hop):
        if hop.s_result.is_constant():
            return inputconst(Bool, hop.s_result.const)
        s_pbc = annmodel.unionof(robj1.s_pbc, robj2.s_pbc)
        r_pbc = hop.rtyper.getrepr(s_pbc)
        v1, v2 = hop.inputargs(r_pbc, r_pbc)
        assert v1.concretetype == v2.concretetype
        if v1.concretetype == Char:
            return hop.genop('char_eq', [v1, v2], resulttype=Bool)
        elif isinstance(v1.concretetype, Ptr):
            return hop.genop('ptr_eq', [v1, v2], resulttype=Bool)
        else:
            raise TyperError("unknown type %r" % (v1.concretetype,))


def conversion_table(r_from, r_to):
    if r_to in r_from._conversion_tables:
        return r_from._conversion_tables[r_to]
    else:
        t = malloc(Array(Char, hints={'nolength': True, 'immutable': True,
                                      'static_immutable': True}),
                   len(r_from.descriptions), immortal=True)
        l = []
        for i, d in enumerate(r_from.descriptions):
            if d in r_to.descriptions:
                j = r_to.descriptions.index(d)
                l.append(j)
                t[i] = chr(j)
            else:
                l.append(None)
        if l == range(len(r_from.descriptions)):
            r = None
        else:
            r = inputconst(typeOf(t), t)
        r_from._conversion_tables[r_to] = r
        return r


class __extend__(pairtype(SmallFunctionSetPBCRepr, SmallFunctionSetPBCRepr)):
    def convert_from_to((r_from, r_to), v, llops):
        c_table = conversion_table(r_from, r_to)
        if c_table:
            assert v.concretetype is Char
            v_int = llops.genop('cast_char_to_int', [v],
                                resulttype=Signed)
            return llops.genop('getarrayitem', [c_table, v_int],
                               resulttype=Char)
        else:
            return v


def getFrozenPBCRepr(rtyper, s_pbc):
    descs = list(s_pbc.descriptions)
    assert len(descs) >= 1
    if len(descs) == 1 and not s_pbc.can_be_None:
        return SingleFrozenPBCRepr(descs[0])
    else:
        access = descs[0].queryattrfamily()
        for desc in descs[1:]:
            access1 = desc.queryattrfamily()
            if access1 is not access:
                try:
                    return rtyper.pbc_reprs['unrelated']
                except KeyError:
                    result = MultipleUnrelatedFrozenPBCRepr(rtyper)
                    rtyper.pbc_reprs['unrelated'] = result
                    return result
        try:
            return rtyper.pbc_reprs[access]
        except KeyError:
            result = MultipleFrozenPBCRepr(rtyper, access)
            rtyper.pbc_reprs[access] = result
            rtyper.add_pendingsetup(result)
            return result


class SingleFrozenPBCRepr(Repr):
    """Representation selected for a single non-callable pre-built constant."""
    lowleveltype = Void

    def __init__(self, frozendesc):
        self.frozendesc = frozendesc

    def rtype_getattr(_, hop):
        if not hop.s_result.is_constant():
            raise TyperError("getattr on a constant PBC returns a non-constant")
        return hop.inputconst(hop.r_result, hop.s_result.const)

    def convert_desc(self, frozendesc):
        assert frozendesc is self.frozendesc
        return object()  # lowleveltype is Void

    def convert_const(self, value):
        return None

    def getstr(self):
        return str(self.frozendesc)
    getstr._annspecialcase_ = 'specialize:memo'

    def ll_str(self, x):
        return self.getstr()

    def get_ll_eq_function(self):
        return None


class MultipleFrozenPBCReprBase(CanBeNull, Repr):
    def convert_const(self, pbc):
        if pbc is None:
            return self.null_instance()
        frozendesc = self.rtyper.annotator.bookkeeper.getdesc(pbc)
        return self.convert_desc(frozendesc)

    def get_ll_eq_function(self):
        return None

class MultipleUnrelatedFrozenPBCRepr(MultipleFrozenPBCReprBase):
    """For a SomePBC of frozen PBCs that have no common access set.
    The only possible operation on such a thing is comparison with 'is'."""
    lowleveltype = llmemory.Address
    EMPTY = Struct('pbc', hints={'immutable': True, 'static_immutable': True})

    def __init__(self, rtyper):
        self.rtyper = rtyper
        self.converted_pbc_cache = {}

    def convert_desc(self, frozendesc):
        try:
            return self.converted_pbc_cache[frozendesc]
        except KeyError:
            r = self.rtyper.getrepr(annmodel.SomePBC([frozendesc]))
            if r.lowleveltype is Void:
                # must create a new empty structure, as a placeholder
                pbc = self.create_instance()
            else:
                pbc = r.convert_desc(frozendesc)
            convpbc = self.convert_pbc(pbc)
            self.converted_pbc_cache[frozendesc] = convpbc
            return convpbc

    def convert_pbc(self, pbcptr):
        return llmemory.fakeaddress(pbcptr)

    def create_instance(self):
        return malloc(self.EMPTY, immortal=True)

    def null_instance(self):
        return llmemory.Address._defl()

    def rtype_getattr(_, hop):
        if not hop.s_result.is_constant():
            raise TyperError("getattr on a constant PBC returns a non-constant")
        return hop.inputconst(hop.r_result, hop.s_result.const)

class __extend__(pairtype(MultipleUnrelatedFrozenPBCRepr,
                          MultipleUnrelatedFrozenPBCRepr),
                 pairtype(MultipleUnrelatedFrozenPBCRepr,
                          SingleFrozenPBCRepr),
                 pairtype(SingleFrozenPBCRepr,
                          MultipleUnrelatedFrozenPBCRepr)):
    def rtype_is_((robj1, robj2), hop):
        if isinstance(robj1, MultipleUnrelatedFrozenPBCRepr):
            r = robj1
        else:
            r = robj2
        vlist = hop.inputargs(r, r)
        return hop.genop('adr_eq', vlist, resulttype=Bool)


class MultipleFrozenPBCRepr(MultipleFrozenPBCReprBase):
    """For a SomePBC of frozen PBCs with a common attribute access set."""

    def __init__(self, rtyper, access_set):
        self.rtyper = rtyper
        self.access_set = access_set
        self.pbc_type = ForwardReference()
        self.lowleveltype = Ptr(self.pbc_type)
        self.pbc_cache = {}

    def _setup_repr(self):
        llfields = self._setup_repr_fields()
        kwds = {'hints': {'immutable': True, 'static_immutable': True}}
        self.pbc_type.become(Struct('pbc', *llfields, **kwds))

    def create_instance(self):
        return malloc(self.pbc_type, immortal=True)

    def null_instance(self):
        return nullptr(self.pbc_type)

    def getfield(self, vpbc, attr, llops):
        mangled_name, r_value = self.fieldmap[attr]
        cmangledname = inputconst(Void, mangled_name)
        return llops.genop('getfield', [vpbc, cmangledname],
                           resulttype=r_value)

    def _setup_repr_fields(self):
        fields = []
        self.fieldmap = {}
        if self.access_set is not None:
            attrlist = self.access_set.attrs.keys()
            attrlist.sort()
            for attr in attrlist:
                s_value = self.access_set.attrs[attr]
                r_value = self.rtyper.getrepr(s_value)
                mangled_name = mangle('pbc', attr)
                fields.append((mangled_name, r_value.lowleveltype))
                self.fieldmap[attr] = mangled_name, r_value
        return fields

    def convert_desc(self, frozendesc):
        if (self.access_set is not None and
                frozendesc not in self.access_set.descs):
            raise TyperError("not found in PBC access set: %r" % (frozendesc,))
        try:
            return self.pbc_cache[frozendesc]
        except KeyError:
            self.setup()
            result = self.create_instance()
            self.pbc_cache[frozendesc] = result
            for attr, (mangled_name, r_value) in self.fieldmap.items():
                if r_value.lowleveltype is Void:
                    continue
                try:
                    thisattrvalue = frozendesc.attrcache[attr]
                except KeyError:
                    if frozendesc.warn_missing_attribute(attr):
                        warning("Desc %r has no attribute %r" % (frozendesc, attr))
                    continue
                llvalue = r_value.convert_const(thisattrvalue)
                setattr(result, mangled_name, llvalue)
            return result

    def rtype_getattr(self, hop):
        if hop.s_result.is_constant():
            return hop.inputconst(hop.r_result, hop.s_result.const)

        attr = hop.args_s[1].const
        vpbc, vattr = hop.inputargs(self, Void)
        v_res = self.getfield(vpbc, attr, hop.llops)
        mangled_name, r_res = self.fieldmap[attr]
        return hop.llops.convertvar(v_res, r_res, hop.r_result)

class __extend__(pairtype(MultipleFrozenPBCRepr,
                          MultipleUnrelatedFrozenPBCRepr)):
    def convert_from_to((robj1, robj2), v, llops):
        return llops.genop('cast_ptr_to_adr', [v], resulttype=llmemory.Address)

class __extend__(pairtype(MultipleFrozenPBCRepr, MultipleFrozenPBCRepr)):
    def convert_from_to((r_pbc1, r_pbc2), v, llops):
        if r_pbc1.access_set == r_pbc2.access_set:
            return v
        return NotImplemented

class __extend__(pairtype(SingleFrozenPBCRepr, MultipleFrozenPBCRepr)):
    def convert_from_to((r_pbc1, r_pbc2), v, llops):
        frozendesc1 = r_pbc1.frozendesc
        access = frozendesc1.queryattrfamily()
        if access is r_pbc2.access_set:
            value = r_pbc2.convert_desc(frozendesc1)
            lltype = r_pbc2.lowleveltype
            return Constant(value, lltype)
        return NotImplemented

class __extend__(pairtype(MultipleFrozenPBCReprBase,
                          SingleFrozenPBCRepr)):
    def convert_from_to((r_pbc1, r_pbc2), v, llops):
        return inputconst(Void, r_pbc2.frozendesc)

class __extend__(pairtype(FunctionRepr, MultipleFrozenPBCRepr)):
    def convert_from_to((r_fn1, r_frozen2), v, llops):
        if r_fn1.s_pbc.is_constant():
            value = r_frozen2.convert_const(r_fn1.s_pbc.const)
            lltype = r_frozen2.lowleveltype
            return Constant(value, lltype)
        return NotImplemented

class __extend__(pairtype(MultipleFrozenPBCRepr, FunctionRepr)):
    def convert_from_to((r_frozen1, r_fn2), v, llops):
        if r_fn2.lowleveltype is Void:
            value = r_fn2.s_pbc.const
            return Constant(value, Void)
        return NotImplemented


class MethodOfFrozenPBCRepr(Repr):
    """Representation selected for a PBC of method object(s) of frozen PBCs.
    It assumes that all methods are the same function bound to different PBCs.
    The low-level representation can then be a pointer to that PBC."""

    def __init__(self, rtyper, s_pbc):
        self.rtyper = rtyper
        funcdescs = set([desc.funcdesc for desc in s_pbc.descriptions])
        assert len(funcdescs) == 1
        self.funcdesc = funcdescs.pop()

        # a hack to force the underlying function to show up in call_families
        # (generally not needed, as normalizecalls() should ensure this,
        # but needed for bound methods that are ll helpers)
        # XXX sort this out
        #call_families = rtyper.annotator.getpbccallfamilies()
        #call_families.find((None, self.function))

        if s_pbc.can_be_none():
            raise TyperError("unsupported: variable of type "
                             "method-of-frozen-PBC or None")

        im_selves = [desc.frozendesc for desc in s_pbc.descriptions]
        self.s_im_self = annmodel.SomePBC(im_selves)
        self.r_im_self = rtyper.getrepr(self.s_im_self)
        self.lowleveltype = self.r_im_self.lowleveltype

    def get_s_callable(self):
        return annmodel.SomePBC([self.funcdesc])

    def get_r_implfunc(self):
        r_func = self.rtyper.getrepr(self.get_s_callable())
        return r_func, 1

    def convert_desc(self, mdesc):
        if mdesc.funcdesc is not self.funcdesc:
            raise TyperError("not a method bound on %r: %r" % (self.funcdesc,
                                                               mdesc))
        return self.r_im_self.convert_desc(mdesc.frozendesc)

    def convert_const(self, method):
        mdesc = self.rtyper.annotator.bookkeeper.getdesc(method)
        return self.convert_desc(mdesc)

    def rtype_simple_call(self, hop):
        return self.redispatch_call(hop, call_args=False)

    def rtype_call_args(self, hop):
        return self.redispatch_call(hop, call_args=True)

    def redispatch_call(self, hop, call_args):
        # XXX obscure, try to refactor...
        s_function = annmodel.SomePBC([self.funcdesc])
        hop2 = hop.copy()
        hop2.args_s[0] = self.s_im_self   # make the 1st arg stand for 'im_self'
        hop2.args_r[0] = self.r_im_self   # (same lowleveltype as 'self')
        if isinstance(hop2.args_v[0], Constant):
            boundmethod = hop2.args_v[0].value
            hop2.args_v[0] = Constant(boundmethod.im_self)
        if call_args:
            hop2.swap_fst_snd_args()
            _, s_shape = hop2.r_s_popfirstarg() # temporarely remove shape
            adjust_shape(hop2, s_shape)
        # a marker that would crash if actually used...
        c = Constant("obscure-don't-use-me")
        hop2.v_s_insertfirstarg(c, s_function)   # insert 'function'
        # now hop2 looks like simple_call(function, self, args...)
        return hop2.dispatch()

class __extend__(pairtype(MethodOfFrozenPBCRepr, MethodOfFrozenPBCRepr)):

    def convert_from_to((r_from, r_to), v, llops):
        return pair(r_from.r_im_self, r_to.r_im_self).convert_from_to(v, llops)

# ____________________________________________________________

class ClassesPBCRepr(Repr):
    """Representation selected for a PBC of class(es)."""

    def __init__(self, rtyper, s_pbc):
        self.rtyper = rtyper
        self.s_pbc = s_pbc
        #if s_pbc.can_be_None:
        #    raise TyperError("unsupported: variable of type "
        #                     "class-pointer or None")
        if s_pbc.is_constant():
            self.lowleveltype = Void
        else:
            self.lowleveltype = self.getlowleveltype()

    def get_access_set(self, attrname):
        """Return the ClassAttrFamily corresponding to accesses to 'attrname'
        and the ClassRepr of the class which stores this attribute in
        its vtable.
        """
        classdescs = list(self.s_pbc.descriptions)
        access = classdescs[0].queryattrfamily(attrname)
        for classdesc in classdescs[1:]:
            access1 = classdesc.queryattrfamily(attrname)
            assert access1 is access       # XXX not implemented
        if access is None:
            raise rclass.MissingRTypeAttribute(attrname)
        commonbase = access.commonbase
        class_repr = rclass.getclassrepr(self.rtyper, commonbase)
        return access, class_repr

    def convert_desc(self, desc):
        if desc not in self.s_pbc.descriptions:
            raise TyperError("%r not in %r" % (desc, self))
        if self.lowleveltype is Void:
            return None
        subclassdef = desc.getuniqueclassdef()
        r_subclass = rclass.getclassrepr(self.rtyper, subclassdef)
        return r_subclass.getruntime(self.lowleveltype)

    def convert_const(self, cls):
        if cls is None:
            if self.lowleveltype is Void:
                return None
            else:
                T = self.lowleveltype
                return nullptr(T.TO)
        bk = self.rtyper.annotator.bookkeeper
        classdesc = bk.getdesc(cls)
        return self.convert_desc(classdesc)

    def rtype_getattr(self, hop):
        if hop.s_result.is_constant():
            return hop.inputconst(hop.r_result, hop.s_result.const)
        else:
            attr = hop.args_s[1].const
            if attr == '__name__':
                from rpython.rtyper.lltypesystem import rstr
                class_repr = self.rtyper.rootclass_repr
                vcls, vattr = hop.inputargs(class_repr, Void)
                cname = inputconst(Void, 'name')
                return hop.genop('getfield', [vcls, cname],
                                 resulttype = Ptr(rstr.STR))
            access_set, class_repr = self.get_access_set(attr)
            vcls, vattr = hop.inputargs(class_repr, Void)
            v_res = class_repr.getpbcfield(vcls, access_set, attr, hop.llops)
            s_res = access_set.s_value
            r_res = self.rtyper.getrepr(s_res)
            return hop.llops.convertvar(v_res, r_res, hop.r_result)

    def replace_class_with_inst_arg(self, hop, v_inst, s_inst, call_args):
        hop2 = hop.copy()
        hop2.r_s_popfirstarg()   # discard the class pointer argument
        if call_args:
            _, s_shape = hop2.r_s_popfirstarg() # temporarely remove shape
            hop2.v_s_insertfirstarg(v_inst, s_inst)  # add 'instance'
            adjust_shape(hop2, s_shape)
        else:
            hop2.v_s_insertfirstarg(v_inst, s_inst)  # add 'instance'
        return hop2

    def rtype_simple_call(self, hop):
        return self.redispatch_call(hop, call_args=False)

    def rtype_call_args(self, hop):
        return self.redispatch_call(hop, call_args=True)

    def redispatch_call(self, hop, call_args):
        s_instance = hop.s_result
        r_instance = hop.r_result

        if len(self.s_pbc.descriptions) == 1:
            # instantiating a single class
            if self.lowleveltype is not Void:
                assert 0, "XXX None-or-1-class instantation not implemented"
            assert isinstance(s_instance, annmodel.SomeInstance)
            classdef = s_instance.classdef
            s_init = classdef.classdesc.s_read_attribute('__init__')
            v_init = Constant("init-func-dummy")   # this value not really used

            if (isinstance(s_init, annmodel.SomeImpossibleValue) and
                classdef.classdesc.is_exception_class() and
                classdef.has_no_attrs()):
                # special case for instanciating simple built-in
                # exceptions: always return the same prebuilt instance,
                # and ignore any arguments passed to the constructor.
                r_instance = rclass.getinstancerepr(hop.rtyper, classdef)
                example = r_instance.get_reusable_prebuilt_instance()
                hop.exception_cannot_occur()
                return hop.inputconst(r_instance.lowleveltype, example)

            v_instance = rclass.rtype_new_instance(hop.rtyper, classdef,
                                                   hop.llops, hop)
            if isinstance(v_instance, tuple):
                v_instance, must_call_init = v_instance
                if not must_call_init:
                    return v_instance
        else:
            # instantiating a class from multiple possible classes
            vtypeptr = hop.inputarg(self, arg=0)
            try:
                access_set, r_class = self.get_access_set('__init__')
            except rclass.MissingRTypeAttribute:
                s_init = annmodel.s_ImpossibleValue
            else:
                s_init = access_set.s_value
                v_init = r_class.getpbcfield(vtypeptr, access_set, '__init__',
                                             hop.llops)
            v_instance = self._instantiate_runtime_class(hop, vtypeptr, r_instance)

        if isinstance(s_init, annmodel.SomeImpossibleValue):
            assert hop.nb_args == 1, ("arguments passed to __init__, "
                                      "but no __init__!")
            hop.exception_cannot_occur()
        else:
            hop2 = self.replace_class_with_inst_arg(
                    hop, v_instance, s_instance, call_args)
            hop2.v_s_insertfirstarg(v_init, s_init)   # add 'initfunc'
            hop2.s_result = annmodel.s_None
            hop2.r_result = self.rtyper.getrepr(hop2.s_result)
            # now hop2 looks like simple_call(initfunc, instance, args...)
            hop2.dispatch()
        return v_instance

    def _instantiate_runtime_class(self, hop, vtypeptr, r_instance):
        graphs = []
        for desc in self.s_pbc.descriptions:
            classdef = desc.getclassdef(None)
            assert hasattr(classdef, 'my_instantiate_graph')
            graphs.append(classdef.my_instantiate_graph)
        c_graphs = hop.inputconst(Void, graphs)
        #
        # "my_instantiate = typeptr.instantiate"
        c_name = hop.inputconst(Void, 'instantiate')
        v_instantiate = hop.genop('getfield', [vtypeptr, c_name],
                                 resulttype=OBJECT_VTABLE.instantiate)
        # "my_instantiate()"
        v_inst = hop.genop('indirect_call', [v_instantiate, c_graphs],
                           resulttype=OBJECTPTR)
        return hop.genop('cast_pointer', [v_inst], resulttype=r_instance)

    def getlowleveltype(self):
        return CLASSTYPE

    def get_ll_hash_function(self):
        return ll_cls_hash

    get_ll_fasthash_function = get_ll_hash_function

    def get_ll_eq_function(self):
        return None

    def ll_str(self, ptr):
        cls = cast_pointer(CLASSTYPE, ptr)
        return cls.name


def ll_cls_hash(cls):
    return cast_ptr_to_int(cls)

class __extend__(pairtype(ClassesPBCRepr, rclass.ClassRepr)):
    def convert_from_to((r_clspbc, r_cls), v, llops):
        # turn a PBC of classes to a standard pointer-to-vtable class repr
        if r_clspbc.lowleveltype == r_cls.lowleveltype:
            return v
        if r_clspbc.lowleveltype is Void:
            return inputconst(r_cls, r_clspbc.s_pbc.const)
        # convert from ptr-to-object-vtable to ptr-to-more-precise-vtable
        return r_cls.fromclasstype(v, llops)

class __extend__(pairtype(ClassesPBCRepr, ClassesPBCRepr)):
    def convert_from_to((r_clspbc1, r_clspbc2), v, llops):
        # this check makes sense because both source and dest repr are ClassesPBCRepr
        if r_clspbc1.lowleveltype == r_clspbc2.lowleveltype:
            return v
        if r_clspbc1.lowleveltype is Void:
            return inputconst(r_clspbc2, r_clspbc1.s_pbc.const)
        if r_clspbc2.lowleveltype is Void:
            return inputconst(Void, r_clspbc2.s_pbc.const)
        return NotImplemented

def adjust_shape(hop2, s_shape):
    new_shape = (s_shape.const[0]+1,) + s_shape.const[1:]
    c_shape = Constant(new_shape)
    s_shape = hop2.rtyper.annotator.bookkeeper.immutablevalue(new_shape)
    hop2.v_s_insertfirstarg(c_shape, s_shape) # reinsert adjusted shape

class MethodsPBCRepr(Repr):
    """Representation selected for a PBC of MethodDescs.
    It assumes that all the methods come from the same name and have
    been read from instances with a common base."""

    def __init__(self, rtyper, s_pbc):
        self.rtyper = rtyper
        self.s_pbc = s_pbc
        mdescs = list(s_pbc.descriptions)
        methodname = mdescs[0].name
        classdef = mdescs[0].selfclassdef
        flags    = mdescs[0].flags
        for mdesc in mdescs[1:]:
            if mdesc.name != methodname:
                raise TyperError("cannot find a unique name under which the "
                                 "methods can be found: %r" % (
                        mdescs,))
            if mdesc.flags != flags:
                raise TyperError("inconsistent 'flags': %r versus %r" % (
                    mdesc.flags, flags))
            classdef = classdef.commonbase(mdesc.selfclassdef)
            if classdef is None:
                raise TyperError("mixing methods coming from instances of "
                                 "classes with no common base: %r" % (mdescs,))

        self.methodname = methodname
        self.classdef = classdef.get_owner(methodname)
        # the low-level representation is just the bound 'self' argument.
        self.s_im_self = annmodel.SomeInstance(self.classdef, flags=flags)
        self.r_im_self = rclass.getinstancerepr(rtyper, self.classdef)
        self.lowleveltype = self.r_im_self.lowleveltype

    def convert_const(self, method):
        if method is None:
            return nullptr(self.lowleveltype.TO)
        if getattr(method, 'im_func', None) is None:
            raise TyperError("not a bound method: %r" % method)
        return self.r_im_self.convert_const(method.im_self)

    def get_r_implfunc(self):
        r_class = self.r_im_self.rclass
        mangled_name, r_func = r_class.clsfields[self.methodname]
        return r_func, 1

    def get_s_callable(self):
        return self.s_pbc

    def get_method_from_instance(self, r_inst, v_inst, llops):
        # The 'self' might have to be cast to a parent class
        # (as shown for example in test_rclass/test_method_both_A_and_B)
        return llops.convertvar(v_inst, r_inst, self.r_im_self)

    def add_instance_arg_to_hop(self, hop, call_args):
        hop2 = hop.copy()
        hop2.args_s[0] = self.s_im_self   # make the 1st arg stand for 'im_self'
        hop2.args_r[0] = self.r_im_self   # (same lowleveltype as 'self')

        if call_args:
            hop2.swap_fst_snd_args()
            _, s_shape = hop2.r_s_popfirstarg()
            adjust_shape(hop2, s_shape)
        return hop2

    def rtype_simple_call(self, hop):
        return self.redispatch_call(hop, call_args=False)

    def rtype_call_args(self, hop):
        return self.redispatch_call(hop, call_args=True)

    def redispatch_call(self, hop, call_args):
        r_class = self.r_im_self.rclass
        mangled_name, r_func = r_class.clsfields[self.methodname]
        assert isinstance(r_func, FunctionReprBase)
        # s_func = r_func.s_pbc -- not precise enough, see
        # test_precise_method_call_1.  Build a more precise one...
        funcdescs = [desc.funcdesc for desc in hop.args_s[0].descriptions]
        s_func = annmodel.SomePBC(funcdescs, subset_of=r_func.s_pbc)
        v_im_self = hop.inputarg(self, arg=0)
        v_cls = self.r_im_self.getfield(v_im_self, '__class__', hop.llops)
        v_func = r_class.getclsfield(v_cls, self.methodname, hop.llops)

        hop2 = self.add_instance_arg_to_hop(hop, call_args)
        hop2.v_s_insertfirstarg(v_func, s_func)   # insert 'function'

        if (type(hop2.args_r[0]) is SmallFunctionSetPBCRepr and
                type(r_func) is FunctionsPBCRepr):
            hop2.args_r[0] = FunctionsPBCRepr(self.rtyper, s_func)
        else:
            hop2.args_v[0] = hop2.llops.convertvar(
                hop2.args_v[0], r_func, hop2.args_r[0])

        # now hop2 looks like simple_call(function, self, args...)
        return hop2.dispatch()

class __extend__(pairtype(MethodsPBCRepr, MethodsPBCRepr)):
    def convert_from_to((r_mpbc1, r_mpbc2), v, llops):
        if r_mpbc1.lowleveltype == r_mpbc2.lowleveltype:
            return v
        return NotImplemented
