from __future__ import absolute_import
import types
from rpython.annotator.signature import (
    enforce_signature_args, enforce_signature_return, finish_type)
from rpython.flowspace.model import FunctionGraph
from rpython.annotator.argument import rawshape, ArgErr, simple_args
from rpython.tool.sourcetools import valid_identifier
from rpython.tool.pairtype import extendabletype
from rpython.annotator.model import AnnotatorError, s_ImpossibleValue, unionof

class CallFamily(object):
    """A family of Desc objects that could be called from common call sites.
    The call families are conceptually a partition of all (callable) Desc
    objects, where the equivalence relation is the transitive closure of
    'd1~d2 if d1 and d2 might be called at the same call site'.
    """
    normalized = False
    modified = True

    def __init__(self, desc):
        self.descs = {desc: True}
        self.calltables = {}  # see calltable_lookup_row()
        self.total_calltable_size = 0

    def update(self, other):
        self.modified = True
        self.normalized = self.normalized or other.normalized
        self.descs.update(other.descs)
        for shape, table in other.calltables.items():
            for row in table:
                self.calltable_add_row(shape, row)
    absorb = update  # UnionFind API

    def calltable_lookup_row(self, callshape, row):
        # this code looks up a table of which graph to
        # call at which call site.  Each call site gets a row of graphs,
        # sharable with other call sites.  Each column is a FunctionDesc.
        # There is one such table per "call shape".
        table = self.calltables.get(callshape, [])
        for i, existing_row in enumerate(table):
            if existing_row == row:   # XXX maybe use a dict again here?
                return i
        raise LookupError

    def calltable_add_row(self, callshape, row):
        try:
            self.calltable_lookup_row(callshape, row)
        except LookupError:
            self.modified = True
            table = self.calltables.setdefault(callshape, [])
            table.append(row)
            self.total_calltable_size += 1

    def find_row(self, bookkeeper, descs, args, op):
        shape = rawshape(args)
        with bookkeeper.at_position(None):
            row = build_calltable_row(descs, args, op)
        index = self.calltable_lookup_row(shape, row)
        return shape, index

def build_calltable_row(descs, args, op):
    # see comments in CallFamily
    row = {}
    for desc in descs:
        graph = desc.get_graph(args, op)
        assert isinstance(graph, FunctionGraph)
        row[desc.rowkey()] = graph
    return row


class FrozenAttrFamily(object):
    """A family of FrozenDesc objects that have any common 'getattr' sites.
    The attr families are conceptually a partition of FrozenDesc objects,
    where the equivalence relation is the transitive closure of:
    d1~d2 if d1 and d2 might have some attribute read on them by the same
    getattr operation.
    """
    def __init__(self, desc):
        self.descs = {desc: True}
        self.read_locations = {}     # set of position_keys
        self.attrs = {}              # { attr: s_value }

    def update(self, other):
        self.descs.update(other.descs)
        self.read_locations.update(other.read_locations)
        self.attrs.update(other.attrs)
    absorb = update  # UnionFind API

    def get_s_value(self, attrname):
        try:
            return self.attrs[attrname]
        except KeyError:
            return s_ImpossibleValue

    def set_s_value(self, attrname, s_value):
        self.attrs[attrname] = s_value


class ClassAttrFamily(object):
    """A family of ClassDesc objects that have common 'getattr' sites for a
    given attribute name.  The attr families are conceptually a partition
    of ClassDesc objects, where the equivalence relation is the transitive
    closure of:  d1~d2 if d1 and d2 might have a common attribute 'attrname'
    read on them by the same getattr operation.

    The 'attrname' is not explicitly stored here, but is the key used
    in the dictionary bookkeeper.pbc_maximal_access_sets_map.
    """
    # The difference between ClassAttrFamily and FrozenAttrFamily is that
    # FrozenAttrFamily is the union for all attribute names, but
    # ClassAttrFamily is more precise: it is only about one attribut name.

    def __init__(self, desc):
        self.descs = {desc: True}
        self.read_locations = {}     # set of position_keys
        self.s_value = s_ImpossibleValue    # union of possible values

    def update(self, other):
        self.descs.update(other.descs)
        self.read_locations.update(other.read_locations)
        self.s_value = unionof(self.s_value, other.s_value)
    absorb = update  # UnionFind API

    def get_s_value(self, attrname):
        return self.s_value

    def set_s_value(self, attrname, s_value):
        self.s_value = s_value

# ____________________________________________________________

class Desc(object):
    __metaclass__ = extendabletype

    def __init__(self, bookkeeper, pyobj=None):
        self.bookkeeper = bookkeeper
        # 'pyobj' is non-None if there is an associated underlying Python obj
        self.pyobj = pyobj

    def __repr__(self):
        pyobj = self.pyobj
        if pyobj is None:
            return object.__repr__(self)
        return '<%s for %r>' % (self.__class__.__name__, pyobj)

    def querycallfamily(self):
        """Retrieve the CallFamily object if there is one, otherwise
           return None."""
        call_families = self.bookkeeper.pbc_maximal_call_families
        try:
            return call_families[self]
        except KeyError:
            return None

    def getcallfamily(self):
        """Get the CallFamily object. Possibly creates one."""
        call_families = self.bookkeeper.pbc_maximal_call_families
        _, _, callfamily = call_families.find(self.rowkey())
        return callfamily

    def mergecallfamilies(self, *others):
        """Merge the call families of the given Descs into one."""
        if not others:
            return False
        call_families = self.bookkeeper.pbc_maximal_call_families
        changed, rep, callfamily = call_families.find(self.rowkey())
        for desc in others:
            changed1, rep, callfamily = call_families.union(rep, desc.rowkey())
            changed = changed or changed1
        return changed

    def queryattrfamily(self):
        # no attributes supported by default;
        # overriden in FrozenDesc and ClassDesc
        return None

    def bind_under(self, classdef, name):
        return self

    @staticmethod
    def simplify_desc_set(descs):
        pass


class NoStandardGraph(Exception):
    """The function doesn't have a single standard non-specialized graph."""

NODEFAULT = object()

class FunctionDesc(Desc):
    knowntype = types.FunctionType

    def __init__(self, bookkeeper, pyobj, name, signature, defaults,
                 specializer=None):
        super(FunctionDesc, self).__init__(bookkeeper, pyobj)
        self.name = name
        self.signature = signature
        self.defaults = defaults if defaults is not None else ()
        # 'specializer' is a function with the following signature:
        #      specializer(funcdesc, args_s) => graph
        #                                 or => s_result (overridden/memo cases)
        self.specializer = specializer
        self._cache = {}     # convenience for the specializer

    def buildgraph(self, alt_name=None, builder=None):
        translator = self.bookkeeper.annotator.translator
        if builder:
            graph = builder(translator, self.pyobj)
        else:
            graph = translator.buildflowgraph(self.pyobj)
        if alt_name:
            graph.name = alt_name
        return graph

    def getgraphs(self):
        return self._cache.values()

    def getuniquegraph(self):
        if len(self._cache) != 1:
            raise NoStandardGraph(self)
        [graph] = self._cache.values()
        relax_sig_check = getattr(self.pyobj, "relax_sig_check", False)
        if (graph.signature != self.signature or
                graph.defaults != self.defaults) and not relax_sig_check:
            raise NoStandardGraph(self)
        return graph

    def cachedgraph(self, key, alt_name=None, builder=None):
        try:
            return self._cache[key]
        except KeyError:
            def nameof(thing):
                if isinstance(thing, str):
                    return thing
                elif hasattr(thing, '__name__'):  # mostly types and functions
                    return thing.__name__
                elif hasattr(thing, 'name') and isinstance(thing.name, str):
                    return thing.name            # mostly ClassDescs
                elif isinstance(thing, tuple):
                    return '_'.join(map(nameof, thing))
                else:
                    return str(thing)[:30]

            if key is not None and alt_name is None:
                postfix = valid_identifier(nameof(key))
                alt_name = "%s__%s" % (self.name, postfix)
            graph = self.buildgraph(alt_name, builder)
            self._cache[key] = graph
            return graph

    def parse_arguments(self, args, graph=None):
        defs_s = []
        if graph is None:
            signature = self.signature
            defaults = self.defaults
        else:
            signature = graph.signature
            defaults = graph.defaults
        if defaults:
            for x in defaults:
                if x is NODEFAULT:
                    defs_s.append(None)
                else:
                    defs_s.append(self.bookkeeper.immutablevalue(x))
        try:
            inputcells = args.match_signature(signature, defs_s)
        except ArgErr as e:
            raise AnnotatorError("signature mismatch: %s() %s" %
                            (self.name, e.getmsg()))
        return inputcells

    def specialize(self, inputcells, op=None):
        if (op is None and
                getattr(self.bookkeeper, "position_key", None) is not None):
            _, block, i = self.bookkeeper.position_key
            op = block.operations[i]
        self.normalize_args(inputcells)
        if getattr(self.pyobj, '_annspecialcase_', '').endswith("call_location"):
            return self.specializer(self, inputcells, op)
        else:
            return self.specializer(self, inputcells)

    def pycall(self, whence, args, s_previous_result, op=None):
        inputcells = self.parse_arguments(args)
        graph = self.specialize(inputcells, op)
        assert isinstance(graph, FunctionGraph)
        # if that graph has a different signature, we need to re-parse
        # the arguments.
        # recreate the args object because inputcells may have been changed
        new_args = args.unmatch_signature(self.signature, inputcells)
        inputcells = self.parse_arguments(new_args, graph)
        annotator = self.bookkeeper.annotator
        result = annotator.recursivecall(graph, whence, inputcells)
        signature = getattr(self.pyobj, '_signature_', None)
        if signature:
            sigresult = enforce_signature_return(self, signature[1], result)
            if sigresult is not None:
                annotator.addpendingblock(
                    graph, graph.returnblock, [sigresult])
                result = sigresult
        # Some specializations may break the invariant of returning
        # annotations that are always more general than the previous time.
        # We restore it here:
        result = unionof(result, s_previous_result)
        return result

    def normalize_args(self, inputs_s):
        """
        Canonicalize argument annotations into the exact parameter
        annotations of a specific specialized graph.

        Note: this method has no return value but mutates its argument instead.
        """
        enforceargs = getattr(self.pyobj, '_annenforceargs_', None)
        signature = getattr(self.pyobj, '_signature_', None)
        if enforceargs and signature:
            raise AnnotatorError("%r: signature and enforceargs cannot both be "
                                 "used" % (self,))
        if enforceargs:
            if not callable(enforceargs):
                from rpython.annotator.signature import Sig
                enforceargs = Sig(*enforceargs)
                self.pyobj._annenforceargs_ = enforceargs
            enforceargs(self, inputs_s)  # can modify inputs_s in-place
        if signature:
            enforce_signature_args(self, signature[0], inputs_s)  # mutates inputs_s

    def get_graph(self, args, op):
        inputs_s = self.parse_arguments(args)
        return self.specialize(inputs_s, op)

    def get_call_parameters(self, args_s):
        args = simple_args(args_s)
        inputcells = self.parse_arguments(args)
        graph = self.specialize(inputcells)
        assert isinstance(graph, FunctionGraph)
        # if that graph has a different signature, we need to re-parse
        # the arguments.
        # recreate the args object because inputcells may have been changed
        new_args = args.unmatch_signature(self.signature, inputcells)
        inputcells = self.parse_arguments(new_args, graph)
        signature = getattr(self.pyobj, '_signature_', None)
        if signature:
            s_result = finish_type(signature[1], self.bookkeeper, self.pyobj)
            if s_result is not None:
                self.bookkeeper.annotator.addpendingblock(
                    graph, graph.returnblock, [s_result])
        return graph, inputcells

    def bind_under(self, classdef, name):
        # XXX static methods
        return self.bookkeeper.getmethoddesc(self,
                                             classdef,   # originclassdef,
                                             None,       # selfclassdef
                                             name)

    @staticmethod
    def consider_call_site(descs, args, s_result, op):
        family = descs[0].getcallfamily()
        shape = rawshape(args)
        row = build_calltable_row(descs, args, op)
        family.calltable_add_row(shape, row)
        descs[0].mergecallfamilies(*descs[1:])

    def rowkey(self):
        return self

    def get_s_signatures(self, shape):
        family = self.getcallfamily()
        table = family.calltables.get(shape)
        if table is None:
            return []
        else:
            graph_seen = {}
            s_sigs = []

            binding = self.bookkeeper.annotator.binding

            def enlist(graph):
                if graph in graph_seen:
                    return
                graph_seen[graph] = True
                s_sig = ([binding(v) for v in graph.getargs()],
                         binding(graph.getreturnvar()))
                if s_sig in s_sigs:
                    return
                s_sigs.append(s_sig)

            for row in table:
                for graph in row.itervalues():
                    enlist(graph)

            return s_sigs

class MemoDesc(FunctionDesc):
    def pycall(self, whence, args, s_previous_result, op=None):
        inputcells = self.parse_arguments(args)
        s_result = self.specialize(inputcells, op)
        if isinstance(s_result, FunctionGraph):
            s_result = s_result.getreturnvar().annotation
            if s_result is None:
                s_result = s_ImpossibleValue
        s_result = unionof(s_result, s_previous_result)
        return s_result


class MethodDesc(Desc):
    knowntype = types.MethodType

    def __init__(self, bookkeeper, funcdesc, originclassdef,
                 selfclassdef, name, flags={}):
        super(MethodDesc, self).__init__(bookkeeper)
        self.funcdesc = funcdesc
        self.originclassdef = originclassdef
        self.selfclassdef = selfclassdef
        self.name = name
        self.flags = flags

    def __repr__(self):
        if self.selfclassdef is None:
            return '<unbound MethodDesc %r of %r>' % (self.name,
                                                      self.originclassdef)
        else:
            return '<MethodDesc %r of %r bound to %r %r>' % (self.name,
                                                          self.originclassdef,
                                                          self.selfclassdef,
                                                          self.flags)

    def getuniquegraph(self):
        return self.funcdesc.getuniquegraph()

    def func_args(self, args):
        from rpython.annotator.model import SomeInstance
        if self.selfclassdef is None:
            raise AnnotatorError("calling %r" % (self,))
        s_instance = SomeInstance(self.selfclassdef, flags=self.flags)
        return args.prepend(s_instance)

    def pycall(self, whence, args, s_previous_result, op=None):
        func_args = self.func_args(args)
        return self.funcdesc.pycall(whence, func_args, s_previous_result, op)

    def get_graph(self, args, op):
        func_args = self.func_args(args)
        return self.funcdesc.get_graph(func_args, op)

    def bind_under(self, classdef, name):
        self.bookkeeper.warning("rebinding an already bound %r" % (self,))
        return self.funcdesc.bind_under(classdef, name)

    def bind_self(self, newselfclassdef, flags={}):
        return self.bookkeeper.getmethoddesc(self.funcdesc,
                                             self.originclassdef,
                                             newselfclassdef,
                                             self.name,
                                             flags)

    @staticmethod
    def consider_call_site(descs, args, s_result, op):
        cnt, keys, star = rawshape(args)
        shape = cnt + 1, keys, star  # account for the extra 'self'
        row = build_calltable_row(descs, args, op)
        family = descs[0].getcallfamily()
        family.calltable_add_row(shape, row)
        descs[0].mergecallfamilies(*descs[1:])

    def rowkey(self):
        # we are computing call families and call tables that always contain
        # FunctionDescs, not MethodDescs.  The present method returns the
        # FunctionDesc to use as a key in that family.
        return self.funcdesc

    @staticmethod
    def simplify_desc_set(descs):
        # Some hacking needed to make contains() happy on SomePBC: if the
        # set of MethodDescs contains some "redundant" ones, i.e. ones that
        # are less general than others already in the set, then kill them.
        # This ensures that if 'a' is less general than 'b', then
        # SomePBC({a}) union SomePBC({b}) is again SomePBC({b}).
        #
        # Two cases:
        # 1. if two MethodDescs differ in their selfclassdefs, and if one
        #    of the selfclassdefs is a subclass of the other;
        # 2. if two MethodDescs differ in their flags, take the intersection.

        # --- case 2 ---
        # only keep the intersection of all the flags, that's good enough
        lst = list(descs)
        commonflags = lst[0].flags.copy()
        for key, value in commonflags.items():
            for desc in lst[1:]:
                if key not in desc.flags or desc.flags[key] != value:
                    del commonflags[key]
                    break
        for desc in lst:
            if desc.flags != commonflags:
                newdesc = desc.bookkeeper.getmethoddesc(desc.funcdesc,
                                                        desc.originclassdef,
                                                        desc.selfclassdef,
                                                        desc.name,
                                                        commonflags)
                descs.remove(desc)
                descs.add(newdesc)

        # --- case 1 ---
        groups = {}
        for desc in descs:
            if desc.selfclassdef is not None:
                key = desc.funcdesc, desc.originclassdef, desc.name
                groups.setdefault(key, []).append(desc)
        for group in groups.values():
            if len(group) > 1:
                for desc1 in group:
                    cdef1 = desc1.selfclassdef
                    for desc2 in group:
                        cdef2 = desc2.selfclassdef
                        if cdef1 is not cdef2 and cdef1.issubclass(cdef2):
                            descs.remove(desc1)
                            break


def new_or_old_class(c):
    if hasattr(c, '__class__'):
        return c.__class__
    else:
        return type(c)

class FrozenDesc(Desc):

    def __init__(self, bookkeeper, pyobj, read_attribute=None):
        super(FrozenDesc, self).__init__(bookkeeper, pyobj)
        if read_attribute is None:
            read_attribute = lambda attr: getattr(pyobj, attr)
        self._read_attribute = read_attribute
        self.attrcache = {}
        self.knowntype = new_or_old_class(pyobj)
        assert bool(pyobj), "__nonzero__ unsupported on frozen PBC %r" % (pyobj,)

    def has_attribute(self, attr):
        if attr in self.attrcache:
            return True
        try:
            self._read_attribute(attr)
            return True
        except AttributeError:
            return False

    def warn_missing_attribute(self, attr):
        # only warn for missing attribute names whose name doesn't start
        # with '$', to silence the warnings about '$memofield_xxx'.
        return not self.has_attribute(attr) and not attr.startswith('$')

    def read_attribute(self, attr):
        try:
            return self.attrcache[attr]
        except KeyError:
            result = self.attrcache[attr] = self._read_attribute(attr)
            return result

    def s_read_attribute(self, attr):
        try:
            value = self.read_attribute(attr)
        except AttributeError:
            return s_ImpossibleValue
        else:
            return self.bookkeeper.immutablevalue(value)

    def create_new_attribute(self, name, value):
        try:
            self.read_attribute(name)
        except AttributeError:
            pass
        else:
            raise AssertionError("name clash: %r" % (name,))
        self.attrcache[name] = value

    def getattrfamily(self, attrname=None):
        "Get the FrozenAttrFamily object for attrname. Possibly creates one."
        access_sets = self.bookkeeper.frozenpbc_attr_families
        _, _, attrfamily = access_sets.find(self)
        return attrfamily

    def queryattrfamily(self, attrname=None):
        """Retrieve the FrozenAttrFamily object for attrname if there is one,
           otherwise return None."""
        access_sets = self.bookkeeper.frozenpbc_attr_families
        try:
            return access_sets[self]
        except KeyError:
            return None

    def mergeattrfamilies(self, others, attrname=None):
        """Merge the attr families of the given Descs into one."""
        access_sets = self.bookkeeper.frozenpbc_attr_families
        changed, rep, attrfamily = access_sets.find(self)
        for desc in others:
            changed1, rep, attrfamily = access_sets.union(rep, desc)
            changed = changed or changed1
        return changed


class MethodOfFrozenDesc(Desc):
    knowntype = types.MethodType

    def __init__(self, bookkeeper, funcdesc, frozendesc):
        super(MethodOfFrozenDesc, self).__init__(bookkeeper)
        self.funcdesc = funcdesc
        self.frozendesc = frozendesc

    def __repr__(self):
        return '<MethodOfFrozenDesc %r of %r>' % (self.funcdesc,
                                                  self.frozendesc)

    def func_args(self, args):
        from rpython.annotator.model import SomePBC
        s_self = SomePBC([self.frozendesc])
        return args.prepend(s_self)

    def pycall(self, whence, args, s_previous_result, op=None):
        func_args = self.func_args(args)
        return self.funcdesc.pycall(whence, func_args, s_previous_result, op)

    def get_graph(self, args, op):
        func_args = self.func_args(args)
        return self.funcdesc.get_graph(func_args, op)

    @staticmethod
    def consider_call_site(descs, args, s_result, op):
        cnt, keys, star = rawshape(args)
        shape = cnt + 1, keys, star  # account for the extra 'self'
        row = build_calltable_row(descs, args, op)
        family = descs[0].getcallfamily()
        family.calltable_add_row(shape, row)
        descs[0].mergecallfamilies(*descs[1:])

    def rowkey(self):
        return self.funcdesc
