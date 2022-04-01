from rpython.annotator import model as annmodel, description
from rpython.flowspace.argument import Signature
from rpython.flowspace.model import (Variable, Constant, Block, Link,
    checkgraph, FunctionGraph, SpaceOperation)
from rpython.rlib.objectmodel import ComputedIntSymbolic
from rpython.rtyper.error import TyperError
from rpython.rtyper.rmodel import getgcflavor
from rpython.tool.sourcetools import valid_identifier
from rpython.annotator.classdesc import ClassDesc


def normalize_call_familes(annotator):
    for callfamily in annotator.bookkeeper.pbc_maximal_call_families.infos():
        if not callfamily.modified:
            assert callfamily.normalized
            continue
        normalize_calltable(annotator, callfamily)
        callfamily.normalized = True
        callfamily.modified = False

def normalize_calltable(annotator, callfamily):
    """Try to normalize all rows of a table."""
    nshapes = len(callfamily.calltables)
    for shape, table in callfamily.calltables.items():
        for row in table:
            did_something = normalize_calltable_row_signature(annotator, shape,
                                                              row)
            if did_something:
                assert not callfamily.normalized, "change in call family normalisation"
                if nshapes != 1:
                    raise_call_table_too_complex_error(callfamily, annotator)
    while True:
        progress = False
        for shape, table in callfamily.calltables.items():
            for row in table:
                progress |= normalize_calltable_row_annotation(annotator,
                                                               row.values())
        if not progress:
            return   # done
        assert not callfamily.normalized, "change in call family normalisation"

def raise_call_table_too_complex_error(callfamily, annotator):
    msg = []
    items = callfamily.calltables.items()
    for i, (shape1, table1) in enumerate(items):
        for shape2, table2 in items[i + 1:]:
            if shape1 == shape2:
                continue
            row1 = table1[0]
            row2 = table2[0]
            problematic_function_graphs = set(row1.values()).union(set(row2.values()))
            pfg = [str(graph) for graph in problematic_function_graphs]
            pfg.sort()
            msg.append("the following functions:")
            msg.append("    %s" % ("\n    ".join(pfg), ))
            msg.append("are called with inconsistent numbers of arguments")
            msg.append("(and/or the argument names are different, which is"
                       " not supported in this case)")
            if shape1[0] != shape2[0]:
                msg.append("sometimes with %s arguments, sometimes with %s" % (shape1[0], shape2[0]))
            else:
                pass # XXX better message in this case
            callers = []
            msg.append("the callers of these functions are:")
            for tag, (caller, callee) in annotator.translator.callgraph.iteritems():
                if callee not in problematic_function_graphs:
                    continue
                if str(caller) in callers:
                    continue
                callers.append(str(caller))
            callers.sort()
            for caller in callers:
                msg.append("    %s" % (caller, ))
    raise TyperError("\n".join(msg))

def normalize_calltable_row_signature(annotator, shape, row):
    graphs = row.values()
    assert graphs, "no graph??"
    sig0 = graphs[0].signature
    defaults0 = graphs[0].defaults
    for graph in graphs[1:]:
        if graph.signature != sig0:
            break
        if graph.defaults != defaults0:
            break
    else:
        return False   # nothing to do, all signatures already match

    shape_cnt, shape_keys, shape_star = shape
    assert not shape_star, "should have been removed at this stage"

    # for the first 'shape_cnt' arguments we need to generalize to
    # a common type
    call_nbargs = shape_cnt + len(shape_keys)

    did_something = False

    for graph in graphs:
        argnames, varargname, kwargname = graph.signature
        assert not varargname, "XXX not implemented"
        assert not kwargname, "XXX not implemented" # ?
        inputargs_s = [annotator.binding(v) for v in graph.getargs()]
        argorder = range(shape_cnt)
        for key in shape_keys:
            i = list(argnames).index(key)
            assert i not in argorder
            argorder.append(i)
        need_reordering = (argorder != range(call_nbargs))
        if need_reordering or len(graph.getargs()) != call_nbargs:
            oldblock = graph.startblock
            inlist = []
            defaults = graph.defaults or ()
            num_nondefaults = len(inputargs_s) - len(defaults)
            defaults = [description.NODEFAULT] * num_nondefaults + list(defaults)
            newdefaults = []
            for j in argorder:
                v = Variable(graph.getargs()[j])
                annotator.setbinding(v, inputargs_s[j])
                inlist.append(v)
                newdefaults.append(defaults[j])
            newblock = Block(inlist)
            # prepare the output args of newblock:
            # 1. collect the positional arguments
            outlist = inlist[:shape_cnt]
            # 2. add defaults and keywords
            for j in range(shape_cnt, len(inputargs_s)):
                try:
                    i = argorder.index(j)
                    v = inlist[i]
                except ValueError:
                    default = defaults[j]
                    if default is description.NODEFAULT:
                        raise TyperError(
                            "call pattern has %d positional arguments, "
                            "but %r takes at least %d arguments" % (
                                shape_cnt, graph.name, num_nondefaults))
                    v = Constant(default)
                outlist.append(v)
            newblock.closeblock(Link(outlist, oldblock))
            graph.startblock = newblock
            for i in range(len(newdefaults)-1,-1,-1):
                if newdefaults[i] is description.NODEFAULT:
                    newdefaults = newdefaults[i:]
                    break
            graph.defaults = tuple(newdefaults)
            graph.signature = Signature([argnames[j] for j in argorder],
                                        None, None)
            # finished
            checkgraph(graph)
            annotator.annotated[newblock] = annotator.annotated[oldblock]
            did_something = True
    return did_something

def normalize_calltable_row_annotation(annotator, graphs):
    if len(graphs) <= 1:
        return False   # nothing to do
    graph_bindings = {}
    for graph in graphs:
        graph_bindings[graph] = [annotator.binding(v)
                                 for v in graph.getargs()]
    iterbindings = graph_bindings.itervalues()
    nbargs = len(iterbindings.next())
    for binding in iterbindings:
        assert len(binding) == nbargs

    generalizedargs = []
    for i in range(nbargs):
        args_s = []
        for graph, bindings in graph_bindings.items():
            args_s.append(bindings[i])
        s_value = annmodel.unionof(*args_s)
        generalizedargs.append(s_value)
    result_s = [annotator.binding(graph.getreturnvar())
                for graph in graph_bindings]
    generalizedresult = annmodel.unionof(*result_s)

    conversion = False
    for graph in graphs:
        bindings = graph_bindings[graph]
        need_conversion = (generalizedargs != bindings)
        if need_conversion:
            conversion = True
            oldblock = graph.startblock
            inlist = []
            for j, s_value in enumerate(generalizedargs):
                v = Variable(graph.getargs()[j])
                annotator.setbinding(v, s_value)
                inlist.append(v)
            newblock = Block(inlist)
            # prepare the output args of newblock and link
            outlist = inlist[:]
            newblock.closeblock(Link(outlist, oldblock))
            graph.startblock = newblock
            # finished
            checkgraph(graph)
            annotator.annotated[newblock] = annotator.annotated[oldblock]
        # convert the return value too
        if annotator.binding(graph.getreturnvar()) != generalizedresult:
            conversion = True
            annotator.setbinding(graph.getreturnvar(), generalizedresult)

    return conversion

# ____________________________________________________________

def merge_classpbc_getattr_into_classdef(annotator):
    # code like 'some_class.attr' will record an attribute access in the
    # PBC access set of the family of classes of 'some_class'.  If the classes
    # have corresponding ClassDefs, they are not updated by the annotator.
    # We have to do it now.
    all_families = annotator.bookkeeper.classpbc_attr_families
    for attrname, access_sets in all_families.items():
        for access_set in access_sets.infos():
            descs = access_set.descs
            if len(descs) <= 1:
                continue
            if not isinstance(descs.iterkeys().next(), ClassDesc):
                continue
            classdefs = [desc.getuniqueclassdef() for desc in descs]
            commonbase = classdefs[0]
            for cdef in classdefs[1:]:
                commonbase = commonbase.commonbase(cdef)
                if commonbase is None:
                    raise TyperError("reading attribute %r: no common base "
                                     "class for %r" % (attrname, descs.keys()))
            extra_access_sets = commonbase.extra_access_sets
            if commonbase.repr is not None:
                assert access_set in extra_access_sets # minimal sanity check
                continue
            access_set.commonbase = commonbase
            if access_set not in extra_access_sets:
                counter = len(extra_access_sets)
                extra_access_sets[access_set] = attrname, counter

# ____________________________________________________________

def create_class_constructors(annotator):
    bk = annotator.bookkeeper
    call_families = bk.pbc_maximal_call_families

    for family in call_families.infos():
        if len(family.descs) <= 1:
            continue
        descs = family.descs.keys()
        if not isinstance(descs[0], ClassDesc):
            continue
        # Note that if classes are in the same callfamily, their __init__
        # attribute must be in the same attrfamily as well.
        change = descs[0].mergeattrfamilies(descs[1:], '__init__')
        if hasattr(descs[0].getuniqueclassdef(), 'my_instantiate_graph'):
            assert not change, "after the fact change to a family of classes" # minimal sanity check
            continue
        # Put __init__ into the attr family, for ClassesPBCRepr.call()
        attrfamily = descs[0].getattrfamily('__init__')
        inits_s = [desc.s_read_attribute('__init__') for desc in descs]
        s_value = annmodel.unionof(attrfamily.s_value, *inits_s)
        attrfamily.s_value = s_value
        # ClassesPBCRepr.call() will also need instantiate() support
        for desc in descs:
            bk.needs_generic_instantiate[desc.getuniqueclassdef()] = True

# ____________________________________________________________

def create_instantiate_functions(annotator):
    # build the 'instantiate() -> instance of C' functions for the vtables

    needs_generic_instantiate = annotator.bookkeeper.needs_generic_instantiate

    for classdef in needs_generic_instantiate:
        assert getgcflavor(classdef) == 'gc'   # only gc-case
        create_instantiate_function(annotator, classdef)

def create_instantiate_function(annotator, classdef):
    # build the graph of a function that looks like
    #
    # def my_instantiate():
    #     return instantiate(cls)
    #
    if hasattr(classdef, 'my_instantiate_graph'):
        return
    v = Variable()
    block = Block([])
    block.operations.append(SpaceOperation('instantiate1', [], v))
    name = valid_identifier('instantiate_' + classdef.name)
    graph = FunctionGraph(name, block)
    block.closeblock(Link([v], graph.returnblock))
    annotator.setbinding(v, annmodel.SomeInstance(classdef))
    annotator.annotated[block] = graph
    # force the result to be converted to a generic OBJECTPTR
    generalizedresult = annmodel.SomeInstance(classdef=None)
    annotator.setbinding(graph.getreturnvar(), generalizedresult)
    classdef.my_instantiate_graph = graph
    annotator.translator.graphs.append(graph)

# ____________________________________________________________

class TooLateForNewSubclass(Exception):
    pass

class TotalOrderSymbolic(ComputedIntSymbolic):

    def __init__(self, orderwitness, peers):
        self.orderwitness = orderwitness
        self.peers = peers
        self.value = None
        self._with_subclasses = None    # unknown
        peers.append(self)

    def __cmp__(self, other):
        if not isinstance(other, TotalOrderSymbolic):
            return cmp(self.compute_fn(), other)
        else:
            return cmp(self.orderwitness, other.orderwitness)

    # support for implementing int_between: (a<=b<c) with (b-a<c-a)
    # see rpython.jit.metainterp.pyjitpl.opimpl_int_between
    def __sub__(self, other):
        return self.compute_fn() - other

    def __rsub__(self, other):
        return other - self.compute_fn()

    def check_any_subclass_in_peer_list(self, i):
        # check if the next peer, in order, is or not the end
        # marker for this start marker
        assert self.peers[i] is self
        return self.peers[i + 1].orderwitness != self.orderwitness + [MAX]

    def number_with_subclasses(self):
        # Return True or False depending on whether this is the
        # subclassrange_min corresponding to a class which has subclasses
        # or not.  If this is called and returns False, then adding later
        # new subclasses will crash in compute_fn().
        if self._with_subclasses is None:     # unknown so far
            self.peers.sort()
            i = self.peers.index(self)
            self._with_subclasses = self.check_any_subclass_in_peer_list(i)
        return self._with_subclasses

    def compute_fn(self):
        if self.value is None:
            self.peers.sort()
            for i, peer in enumerate(self.peers):
                assert peer.value is None or peer.value == i
                peer.value = i
                #
                if peer._with_subclasses is False:
                    if peer.check_any_subclass_in_peer_list(i):
                        raise TooLateForNewSubclass
                #
            assert self.value is not None
        return self.value

    def dump(self, annotator):   # for debugging
        self.peers.sort()
        mapping = {}
        for classdef in annotator.bookkeeper.classdefs:
            if hasattr(classdef, '_unique_cdef_id'):
                mapping[classdef._unique_cdef_id] = classdef
        for peer in self.peers:
            if peer is self:
                print '==>',
            else:
                print '   ',
            print 'value %4s --' % (peer.value,), peer.orderwitness,
            if peer.orderwitness[-1] in mapping:
                print mapping[peer.orderwitness[-1]]
            else:
                print

def assign_inheritance_ids(annotator):
    # we sort the classes by lexicographic order of reversed(mro),
    # which gives a nice depth-first order.  The classes are turned
    # into numbers in order to (1) help determinism, (2) ensure that
    # new hierarchies of classes with no common base classes can be
    # added later and get higher numbers.
    bk = annotator.bookkeeper
    try:
        lst = bk._inheritance_id_symbolics
    except AttributeError:
        lst = bk._inheritance_id_symbolics = []
    for classdef in annotator.bookkeeper.classdefs:
        if not hasattr(classdef, 'minid'):
            witness = [get_unique_cdef_id(cdef) for cdef in classdef.getmro()]
            witness.reverse()
            classdef.minid = TotalOrderSymbolic(witness, lst)
            classdef.maxid = TotalOrderSymbolic(witness + [MAX], lst)

MAX = 1E100
_cdef_id_counter = 0
def get_unique_cdef_id(cdef):
    global _cdef_id_counter
    try:
        return cdef._unique_cdef_id
    except AttributeError:
        cdef._unique_cdef_id = _cdef_id_counter
        _cdef_id_counter += 1
        return cdef._unique_cdef_id

# ____________________________________________________________

def perform_normalizations(annotator):
    create_class_constructors(annotator)
    annotator.frozen += 1
    try:
        normalize_call_familes(annotator)
        merge_classpbc_getattr_into_classdef(annotator)
        assign_inheritance_ids(annotator)
    finally:
        annotator.frozen -= 1
    create_instantiate_functions(annotator)
