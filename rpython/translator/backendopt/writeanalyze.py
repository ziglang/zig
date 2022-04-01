from rpython.flowspace.model import Variable, Constant
from rpython.translator.backendopt import graphanalyze
from rpython.rtyper.lltypesystem import lltype, llmemory

top_set = object()
empty_set = frozenset()

# CUTOFF is disabled, as it gave a strangely not-working-any-more effect
# if the size of the result grows past that bound.  The main user was
# optimizeopt/heap.py (force_from_effectinfo), which has been rewritten
# to be happy with any size now.
#CUTOFF = 3000

class WriteAnalyzer(graphanalyze.GraphAnalyzer):
    #cutoff = CUTOFF

    def bottom_result(self):
        return empty_set

    def top_result(self):
        return top_set

    def is_top_result(self, result):
        return result is top_set

    def result_builder(self):
        return set()

    def add_to_result(self, result, other):
        if other is top_set:
            return top_set
        result.update(other)
        #if len(result) > self.cutoff:
        #    return top_set
        return result

    def finalize_builder(self, result):
        if result is top_set:
            return result
        return frozenset(result)

    def join_two_results(self, result1, result2):
        if result1 is top_set or result2 is top_set:
            return top_set
        return result1.union(result2)

    def _getinteriorname(self, op):
        if (isinstance(op.args[1], Constant) and
            isinstance(op.args[1].value, str)):
            return op.args[1].value
        return op.args[2].value

    def analyze_simple_operation(self, op, graphinfo):
        if op.opname == "setfield":
            if graphinfo is None or not graphinfo.is_fresh_malloc(op.args[0]):
                return frozenset([
                    ("struct", op.args[0].concretetype, op.args[1].value)])
        elif op.opname == "setarrayitem":
            if graphinfo is None or not graphinfo.is_fresh_malloc(op.args[0]):
                return self._array_result(op.args[0].concretetype)
        elif op.opname == "setinteriorfield":
            if graphinfo is None or not graphinfo.is_fresh_malloc(op.args[0]):
                name = self._getinteriorname(op)
                return self._interiorfield_result(op.args[0].concretetype, name)
        elif op.opname == "gc_store_indexed":
            if graphinfo is None or not graphinfo.is_fresh_malloc(op.args[0]):
                return self._gc_store_indexed_result(op)
        elif op.opname == 'gc_add_memory_pressure':
            # special_memory_pressure would be overwritten by zero, because
            # the JIT cannot see the field write, which is why we assume
            # it can write anything
            return top_set
        return empty_set

    def _array_result(self, TYPE):
        return frozenset([("array", TYPE)])

    def _interiorfield_result(self, TYPE, fieldname):
        return frozenset([("interiorfield", TYPE, fieldname)])

    def _gc_store_indexed_result(self, op):
        base_ofs = op.args[4].value
        effect = self._get_effect_for_offset(base_ofs)
        return frozenset([effect])

    def _get_effect_for_offset(self, ofs, prefix=''):
        # gc_{load,store}_indexed are generic operation which operate on
        # various data types: depending on the symbolic offset, they can be
        # equivalent as reading/writing an array, and interiorfield, etc. The
        # following logic tries to catch all the known usages. If you see an
        # 'implement me', please update the logic accordingly
        if isinstance(ofs, llmemory.CompositeOffset):
            # get the effect for the first component and modify it if
            # necessary
            sub_offsets = ofs.offsets
            effect = self._get_effect_for_offset(sub_offsets[0], prefix)
            for sub_ofs in sub_offsets[1:]:
                if isinstance(sub_ofs, llmemory.ArrayItemsOffset):
                    # reading from the middle of an array is the same as
                    # reading from the beginning, so we don't need to change
                    # the effect
                    pass
                else:
                    assert False, 'implement me'
            return effect
        elif isinstance(ofs, llmemory.FieldOffset):
            T = ofs.TYPE
            return (prefix + 'interiorfield', lltype.Ptr(T), ofs.fldname)
        elif isinstance(ofs, llmemory.ArrayItemsOffset):
            return (prefix + 'array', lltype.Ptr(ofs.TYPE))
        else:
            assert False, 'implement me'

    def compute_graph_info(self, graph):
        return FreshMallocs(graph)


class FreshMallocs(object):
    def __init__(self, graph):
        self.nonfresh = set(graph.getargs())
        pendingblocks = list(graph.iterblocks())
        self.allvariables = set()
        for block in pendingblocks:
            self.allvariables.update(block.inputargs)
        pendingblocks.reverse()
        while pendingblocks:
            block = pendingblocks.pop()
            for op in block.operations:
                self.allvariables.add(op.result)
                if (op.opname == 'malloc' or op.opname == 'malloc_varsize'
                    or op.opname == 'new'):
                    continue
                elif op.opname in ('cast_pointer', 'same_as'):
                    if self.is_fresh_malloc(op.args[0]):
                        continue
                self.nonfresh.add(op.result)
            for link in block.exits:
                self.nonfresh.update(link.getextravars())
                self.allvariables.update(link.getextravars())
                prevlen = len(self.nonfresh)
                for v1, v2 in zip(link.args, link.target.inputargs):
                    if not self.is_fresh_malloc(v1):
                        self.nonfresh.add(v2)
                if len(self.nonfresh) > prevlen:
                    pendingblocks.append(link.target)

    def is_fresh_malloc(self, v):
        if not isinstance(v, Variable):
            return False
        assert v in self.allvariables
        return v not in self.nonfresh


class ReadWriteAnalyzer(WriteAnalyzer):

    def analyze_simple_operation(self, op, graphinfo):
        if op.opname == "getfield":
            return frozenset([
                ("readstruct", op.args[0].concretetype, op.args[1].value)])
        elif op.opname == "getarrayitem":
            return frozenset([
                ("readarray", op.args[0].concretetype)])
        elif op.opname == "getinteriorfield":
            name = self._getinteriorname(op)
            return frozenset([("readinteriorfield", op.args[0].concretetype,
                            name)])
        elif op.opname == "gc_load_indexed":
            return self._gc_load_indexed_result(op)
        return WriteAnalyzer.analyze_simple_operation(self, op, graphinfo)

    def _gc_load_indexed_result(self, op):
        base_offset = op.args[3].value
        effect = self._get_effect_for_offset(base_offset, prefix='read')
        return frozenset([effect])

