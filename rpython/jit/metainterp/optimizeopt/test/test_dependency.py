import py
import pytest

from rpython.jit.metainterp.compile import invent_fail_descr_for_op
from rpython.jit.metainterp.history import TargetToken, JitCellToken, TreeLoop
from rpython.jit.metainterp.optimizeopt.dependency import (DependencyGraph, Dependency,
        IndexVar, MemoryRef, Node)
from rpython.jit.metainterp.optimizeopt.vector import VectorLoop
from rpython.jit.metainterp.optimizeopt.test.test_util import (
    BaseTest, convert_old_style_to_targets, FakeJitDriverStaticData)
from rpython.jit.metainterp.resoperation import rop, ResOperation
from rpython.jit.backend.llgraph.runner import ArrayDescr
from rpython.jit.tool.oparser import OpParser
from rpython.rtyper.lltypesystem import rffi
from rpython.rtyper.lltypesystem import lltype
from rpython.conftest import option

class FakeDependencyGraph(DependencyGraph):
    """ A dependency graph that is able to emit every instruction
    one by one. """
    def __init__(self, loop):
        self.loop = loop
        if isinstance(loop, list):
            self.nodes = loop
        else:
            operations = loop.operations
            self.nodes = [Node(op,i) for i,op in \
                            enumerate(operations)]
        self.schedulable_nodes = list(reversed(self.nodes))
        self.guards = []


class DependencyBaseTest(BaseTest):

    def setup_method(self, method):
        self.test_name = method.__name__
        if not self.cpu.vector_ext.is_enabled():
            py.test.skip("cpu %s needs to implement the vector backend" % self.cpu)

    def build_dependency(self, ops):
        loop = self.parse_loop(ops)
        graph = DependencyGraph(loop)
        self.show_dot_graph(graph, self.test_name)
        for node in graph.nodes:
            assert node.independent(node)
        graph.parsestr = ops
        return graph

    def match_op(self, expected, actual, remap):
        if expected.getopnum() != actual.getopnum():
            return False
        expargs = expected.getarglist()
        actargs = [remap.get(arg, None) for arg in actual.getarglist()]
        if not all([e == a or a is None for e,a in zip(expargs,actargs)]):
            return False
        if expected.getfailargs():
            expargs = expected.getfailargs()
            actargs = [remap.get(arg, None) for arg in actual.getfailargs()]
            if not all([e == a or a is None for e,a in zip(expargs,actargs)]):
                return False
        return True

    def ensure_operations(self, opstrlist, trace):
        oparse = OpParser('', self.cpu, self.namespace, None,
                          None, True, None)
        oplist = []
        for op_str in opstrlist:
            op = oparse.parse_next_op(op_str)
            if not op.returns_void():
                var = op_str.split('=')[0].strip()
                if '[' in var:
                    var = var[:var.find('[')]
                elem = op_str[:len(var)]
                oparse._cache['lltype', elem] = op
            oplist.append(op)
        oplist_i = 0
        remap = {}
        last_match = 0
        for i, op in enumerate(trace.operations):
            if oplist_i >= len(oplist):
                break
            curtomatch = oplist[oplist_i]
            if self.match_op(curtomatch, op, remap):
                if not op.returns_void():
                    remap[curtomatch] = op
                oplist_i += 1
                last_match = i

        msg =  "could not find all ops in the trace sequence\n\n"
        if oplist_i != len(oplist):
            l = [str(o) for o in oplist[oplist_i:]]
            msg += "sequence\n  " + '\n  '.join(l)
            msg += "\n\ndoes not match\n  "
            l = [str(o) for o in trace.operations[last_match+1:]]
            msg += '\n  '.join(l)
        assert oplist_i == len(oplist), msg

    def parse_loop(self, ops, add_label=True):
        loop = self.parse(ops)
        loop.operations = filter(lambda op: op.getopnum() != rop.DEBUG_MERGE_POINT, loop.operations)
        token = JitCellToken()
        if add_label:
            label = ResOperation(rop.LABEL, loop.inputargs, descr=TargetToken(token))
        else:
            label = loop.operations[0]
            label.setdescr(TargetToken(token))
        jump = loop.operations[-1]
        loop = VectorLoop(label, loop.operations[0:-1], jump)
        loop.jump.setdescr(token)
        class Optimizer(object):
            metainterp_sd = self.metainterp_sd
            jitdriver_sd = FakeJitDriverStaticData()
        opt = Optimizer()
        opt.jitdriver_sd.vec = True
        for op in loop.operations:
            if op.is_guard() and not op.getdescr():
                descr = invent_fail_descr_for_op(op.getopnum(), opt)
                op.setdescr(descr)
        return loop

    def parse_trace(self, source, inc_label_jump=True, pargs=2, iargs=10,
              fargs=6, additional_args=None, replace_args=None):
        args = []
        for prefix, rang in [('p',range(pargs)),
                             ('i',range(iargs)),
                             ('f',range(fargs))]:
            for i in rang:
                args.append(prefix + str(i))

        assert additional_args is None or isinstance(additional_args,list)
        for arg in additional_args or []:
            args.append(arg)
        for k,v in (replace_args or {}).items():
            for i,_ in enumerate(args):
                if k == args[i]:
                    args[i] = v
                    break
        indent = "        "
        joinedargs = ','.join(args)
        fmt = (indent, joinedargs, source, indent, joinedargs)
        src = "%s[%s]\n%s\n%sjump(%s)" % fmt
        loop = self.parse_loop(src)
        # needed to assign the right number to the input
        # arguments
        [str(arg) for arg in loop.inputargs]
        loop.graph = FakeDependencyGraph(loop)
        loop.setup_vectorization()
        return loop


    def assert_edges(self, graph, edge_list, exceptions):
        """ Check if all dependencies are met. for complex cases
        adding None instead of a list of integers skips the test.
        This checks both if a dependency forward and backward exists.
        """
        assert len(edge_list) == len(graph.nodes) + 2
        edge_list = edge_list[1:-1]
        for idx,edges in enumerate(edge_list):
            if edges is None:
                continue
            node_a = graph.getnode(idx)
            dependencies = node_a.provides()[:]
            for idx_b in edges:
                if idx_b == 0 or idx_b >= len(graph.nodes) + 2 -1:
                    continue
                idx_b -= 1
                node_b = graph.getnode(idx_b)
                dependency = node_a.getedge_to(node_b)
                if dependency is None and idx_b not in exceptions.setdefault(idx,[]):
                    self.show_dot_graph(graph, self.test_name + '_except')
                    assert dependency is not None or node_b.getopnum() == rop.JUMP, \
                       " it is expected that instruction at index" + \
                       " %s depends on instr on index %s but it does not.\n%s" \
                            % (node_a.getindex(), node_b.getindex(), graph)
                elif dependency is not None:
                    dependencies.remove(dependency)
            assert dependencies == [], \
                    "dependencies unexpected %s.\n%s" \
                    % (dependencies,graph)

    def assert_dependencies(self, graph, full_check=True):
        import re
        deps = {}
        exceptions = {}
        for i,line in enumerate(graph.parsestr.splitlines()):
            dep_pattern = re.compile("#\s*(\d+):")
            dep_match = dep_pattern.search(line)
            if dep_match:
                label = int(dep_match.group(1))
                deps_list = []
                deps[label] = []
                for to in [d for d in line[dep_match.end():].split(',') if len(d) > 0]:
                    exception = to.endswith("?")
                    if exception:
                        to = to[:-1]
                        exceptions.setdefault(label,[]).append(int(to))
                    deps[label].append(int(to))

        if full_check:
            edges = [ None ] * len(deps)
            for k,l in deps.items():
                edges[k] = l
            self.assert_edges(graph, edges, exceptions)
        return graph

    def assert_independent(self, graph, a, b):
        a -= 1
        b -= 1
        a = graph.getnode(a)
        b = graph.getnode(b)
        assert a.independent(b), "{a} and {b} are dependent!".format(a=a,b=b)

    def assert_dependent(self, graph, a, b):
        a -= 1
        b -= 1
        a = graph.getnode(a)
        b = graph.getnode(b)
        assert not a.independent(b), "{a} and {b} are independent!".format(a=a,b=b)

    def show_dot_graph(self, graph, name):
        if option and option.viewdeps:
            from rpython.translator.tool.graphpage import GraphPage
            page = GraphPage()
            page.source = graph.as_dot()
            page.links = []
            page.display()

    def debug_print_operations(self, loop):
        print('--- loop instr numbered ---')
        for i,op in enumerate(loop.operations):
            print "[",i,"]",op,
            if op.is_guard():
                print op.getfailargs()
            else:
                print ""

    def assert_memory_ref_adjacent(self, m1, m2):
        assert m1.is_adjacent_to(m2)
        assert m2.is_adjacent_to(m1)

    def assert_memory_ref_not_adjacent(self, m1, m2):
        assert not m1.is_adjacent_to(m2)
        assert not m2.is_adjacent_to(m1)

class TestDependencyGraph(DependencyBaseTest):

    def test_index_var_basic(self):
        b = FakeBox()
        i = IndexVar(b,1,1,0)
        j = IndexVar(b,1,1,0)
        assert i.is_identity()
        assert i.same_variable(j)
        assert i.constant_diff(j) == 0

    def test_index_var_diff(self):
        b = FakeBox()
        i = IndexVar(b,4,2,0)
        j = IndexVar(b,1,1,1)
        assert not i.is_identity()
        assert not j.is_identity()
        assert not i.same_mulfactor(j)
        assert i.constant_diff(j) == -1

    def test_memoryref_basic(self):
        i = FakeBox()
        a = FakeBox()
        m1 = memoryref(a, i, (1,1,0))
        m2 = memoryref(a, i, (1,1,0))
        assert m1.alias(m2)

    @py.test.mark.parametrize('coeff1,coeff2,state',
            #                    +------------------ adjacent
            #                    |+----------------- adjacent_after
            #                    ||+---------------- adjacent_befure
            #                    |||+--------------- alias
            #                    ||||
            [((1,1,0), (1,1,0), 'ffft'),
             ((4,2,0), (8,4,0), 'ffft'),
             ((4,2,0), (8,2,0), 'ffft'),
             ((4,2,1), (8,4,0), 'tftf'),
            ])
    def test_memoryref_adjacent_alias(self, coeff1, coeff2, state):
        i = FakeBox()
        a = FakeBox()
        m1 = memoryref(a, i, coeff1)
        m2 = memoryref(a, i, coeff2)
        adja = state[0] == 't'
        adja_after = state[1] == 't'
        adja_before = state[2] == 't'
        alias = state[3] == 't'
        assert m1.is_adjacent_to(m2) == adja
        assert m2.is_adjacent_to(m1) == adja
        assert m1.is_adjacent_after(m2) == adja_after
        assert m2.is_adjacent_after(m1) == adja_before
        assert m1.alias(m2) == alias

    def test_dependency_empty(self):
        graph = self.build_dependency("""
        [] # 0: 1
        jump() # 1:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_dependency_of_constant_not_used(self):
        graph = self.build_dependency("""
        [] # 0: 2
        i1 = int_add(1,1) # 1: 2
        jump() # 2:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_dependency_simple(self):
        graph = self.build_dependency("""
        [] # 0: 4
        i1 = int_add(1,1) # 1: 2
        i2 = int_add(i1,1) # 2: 3
        guard_value(i2,3) [] # 3: 4
        jump() # 4:
        """)
        graph = self.assert_dependencies(graph, full_check=True)
        self.assert_dependent(graph, 1,2)
        self.assert_dependent(graph, 2,3)
        self.assert_dependent(graph, 1,3)

    def test_def_use_jump_use_def(self):
        graph = self.build_dependency("""
        [i3] # 0: 1
        i1 = int_add(i3,1) # 1: 2, 3
        guard_value(i1,0) [] # 2: 3
        jump(i1) # 3:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_dependency_guard(self):
        graph = self.build_dependency("""
        [i3] # 0: 2,3
        i1 = int_add(1,1) # 1: 2
        guard_value(i1,0) [i3] # 2: 3
        jump(i3) # 3:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_dependency_guard_2(self):
        graph = self.build_dependency("""
        [i1] # 0: 1,2?,3
        i2 = int_le(i1, 10) # 1: 2
        guard_true(i2) [i1] # 2:
        i3 = int_add(i1,1) # 3: 4
        jump(i3) # 4:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_no_edge_duplication(self):
        graph = self.build_dependency("""
        [i1] # 0: 1,2?,3
        i2 = int_lt(i1,10) # 1: 2
        guard_false(i2) [i1] # 2:
        i3 = int_add(i1,i1) # 3: 4
        jump(i3) # 4:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_no_edge_duplication_in_guard_failargs(self):
        graph = self.build_dependency("""
        [i1] # 0: 1,2?,3?
        i2 = int_lt(i1,10) # 1: 2
        guard_false(i2) [i1,i1,i2,i1,i2,i1] # 2: 3
        jump(i1) # 3:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_dependencies_1(self):
        graph = self.build_dependency("""
        [i0, i1, i2] # 0: 1,3,6,7,11?
        i4 = int_gt(i1, 0) # 1: 2
        guard_true(i4) [] # 2: 5, 11?
        i6 = int_sub(i1, 1) # 3: 4
        i8 = int_gt(i6, 0) # 4: 5
        guard_false(i8) [] # 5: 10
        i10 = int_add(i2, 1) # 6: 8
        i12 = int_sub(i0, 1) # 7: 9, 11
        i14 = int_add(i10, 1) # 8: 11
        i16 = int_gt(i12, 0) # 9: 10
        guard_true(i16) [] # 10: 11
        jump(i12, i1, i14) # 11:
        """)
        self.assert_dependencies(graph, full_check=True)
        self.assert_independent(graph, 6, 2)
        self.assert_independent(graph, 6, 1)

    def test_prevent_double_arg(self):
        graph = self.build_dependency("""
        [i0, i1, i2] # 0: 1,3
        i4 = int_gt(i1, i0) # 1: 2
        guard_true(i4) [] # 2: 3
        jump(i0, i1, i2) # 3:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_ovf_dep(self):
        graph = self.build_dependency("""
        [i0, i1, i2] # 0: 2,3
        i4 = int_sub_ovf(1, 0) # 1: 2
        guard_overflow() [i2] # 2: 3
        jump(i0, i1, i2) # 3:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_exception_dep(self):
        graph = self.build_dependency("""
        [p0, i1, i2] # 0: 1,3?
        i4 = call_i(p0, 1, descr=nonwritedescr) # 1: 2,3
        guard_no_exception() [] # 2: 3
        jump(p0, i1, i2) # 3:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_call_dependency_on_ptr_but_not_index_value(self):
        graph = self.build_dependency("""
        [p0, p1, i2] # 0: 1,2?,3?,4?,5?
        i3 = int_add(i2,1) # 1: 2
        i4 = call_i(p0, i3, descr=nonwritedescr) # 2: 3,4,5?
        guard_no_exception() [i2] # 3:
        p2 = getarrayitem_gc_r(p1, i3, descr=arraydescr) # 4: 5
        jump(p2, p1, i3) # 5:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_call_dependency(self):
        graph = self.build_dependency("""
        [p0, p1, i2, i5] # 0: 1,2?,3?,4?,5?
        i3 = int_add(i2,1) # 1: 2
        i4 = call_i(i5, i3, descr=nonwritedescr) # 2: 3,4,5?
        guard_no_exception() [i2] # 3: 5?
        p2 = getarrayitem_gc_r(p1,i3,descr=chararraydescr) # 4: 5
        jump(p2, p1, i3, i5) # 5:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_call_not_forced_exception(self):
        graph = self.build_dependency("""
        [p0, p1, i2, i5] # 0: 1,2,4?,5,6
        i4 = call_i(i5, i2, descr=nonwritedescr) # 1: 2,4,6
        guard_not_forced() [i2] # 2: 3
        guard_no_exception() [] # 3: 6
        i3 = int_add(i2,1) # 4: 5
        p2 = getarrayitem_gc_r(p1,i3,descr=chararraydescr) # 5: 6
        jump(p2, p1, i2, i5) # 6:
        """)
        self.assert_dependencies(graph, full_check=True)
        assert graph.nodes[1].priority == 100
        assert graph.nodes[2].priority == 100

    def test_setarrayitem_dependency(self):
        graph = self.build_dependency("""
        [p0, i1] # 0: 1,2?,3?,4?
        setarrayitem_raw(p0, i1, 1, descr=floatarraydescr) # 1: 2,3
        i2 = getarrayitem_raw_i(p0, i1, descr=floatarraydescr) # 2: 4
        setarrayitem_raw(p0, i1, 2, descr=floatarraydescr) # 3: 4
        jump(p0, i2) # 4:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_setarrayitem_alias_dependency(self):
        # #1 depends on #2, i1 and i2 might alias, reordering would destroy
        # coorectness
        graph = self.build_dependency("""
        [p0, i1, i2] # 0: 1,2?,3?
        setarrayitem_raw(p0, i1, 1, descr=floatarraydescr) # 1: 2
        setarrayitem_raw(p0, i2, 2, descr=floatarraydescr) # 2: 3
        jump(p0, i1, i2) # 3:
        """)
        self.assert_dependencies(graph, full_check=True)
        self.assert_dependent(graph, 1,2)

    def test_setarrayitem_dont_depend_with_memref_info(self):
        graph = self.build_dependency("""
        [p0, i1] # 0: 1,2,3?,4?
        setarrayitem_raw(p0, i1, 1, descr=chararraydescr) # 1: 4
        i2 = int_add(i1,1) # 2: 3
        setarrayitem_raw(p0, i2, 2, descr=chararraydescr) # 3: 4
        jump(p0, i1) # 4:
        """)
        self.assert_dependencies(graph, full_check=True)
        self.assert_independent(graph, 1,2)
        self.assert_independent(graph, 1,3) # they modify 2 different cells

    def test_dependency_complex_trace(self):
        graph = self.build_dependency("""
        [i0, i1, i2, i3, i4, i5, i6, i7] # 0:
        i9 = int_mul(i0, 8) # 1: 2
        i10 = raw_load_i(i3, i9, descr=arraydescr) # 2: 5, 10
        i11 = int_mul(i0, 8) # 3: 4
        i12 = raw_load_i(i4, i11, descr=arraydescr) # 4: 5,10
        i13 = int_add(i10, i12) # 5: 7,10
        i14 = int_mul(i0, 8) # 6: 7
        raw_store(i3, i14, i13, descr=arraydescr) # 7: 10,12,20
        i16 = int_add(i0, 1) # 8: 9,10,11,13,16,18
        i17 = int_lt(i16, i7) # 9: 10
        guard_true(i17) [i7, i13, i5, i4, i3, i12, i10, i16] # 10: 17, 20
        i18 = int_mul(i16, 9) # 11: 12
        i19 = raw_load_i(i3, i18, descr=arraydescr) # 12: 15, 20
        i20 = int_mul(i16, 8) # 13: 14
        i21 = raw_load_i(i4, i20, descr=arraydescr) # 14: 15, 20
        i22 = int_add(i19, i21) # 15: 17, 20
        i23 = int_mul(i16, 8) # 16: 17
        raw_store(i5, i23, i22, descr=arraydescr) # 17: 20
        i24 = int_add(i16, 1) # 18: 19, 20
        i25 = int_lt(i24, i7) # 19: 20
        guard_true(i25) [i7, i22, i5, i4, i3, i21, i19, i24] # 20:
        jump(i24, i19, i21, i3, i4, i5, i22, i7) # 21:
        """)
        self.assert_dependencies(graph, full_check=True)
        self.assert_dependent(graph, 2,12)
        self.assert_dependent(graph, 7,12)
        self.assert_dependent(graph, 4,12)

    def test_getfield(self):
        graph = self.build_dependency("""
        [p0, p1] # 0: 1,2,5
        p2 = getfield_gc_r(p0, descr=valuedescr) # 1: 3,5
        p3 = getfield_gc_r(p0, descr=valuedescr) # 2: 4
        guard_nonnull(p2) [p2] # 3: 4,5
        guard_nonnull(p3) [p3] # 4: 5
        jump(p0,p2) # 5:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_cyclic(self):
        graph = self.build_dependency("""
        [p0, p1, p5, p6, p7, p9, p11, p12] # 0: 1,6
        p13 = getfield_gc_r(p9, descr=valuedescr) # 1: 2,5
        guard_nonnull(p13) [] # 2: 4,5
        i14 = getfield_gc_i(p9, descr=valuedescr) # 3: 5
        p15 = getfield_gc_r(p13, descr=valuedescr) # 4: 5
        guard_class(p15, 14073732) [p1, p0, p9, i14, p15, p13, p5, p6, p7] # 5: 6
        jump(p0,p1,p5,p6,p7,p9,p11,p12) # 6:
        """)
        self.assert_dependencies(graph, full_check=True)

    def test_dep_on_vector_op(self):
        graph = self.build_dependency("""
        [p0, i1] # 0: 1,2,3
        i19 = int_mul(i1, 8) # 1: 2
        v20[2xi64] = vec_load_i(p0, i19, 1, 0, descr=arraydescr) # 2:
        jump(p0, i1) # 3:
        """)
        self.assert_dependencies(graph, full_check=True)


    def test_iterate(self):
        n1,n2,n3,n4,n5 = [FakeNode(i+1) for i in range(5)]
        # n1 -> n2 -> n4 -> n5
        #  +---> n3 --^
        n1.edge_to(n2); n2.edge_to(n4); n4.edge_to(n5)
        n1.edge_to(n3); n3.edge_to(n4);

        paths = list(n5.iterate_paths(n1, backwards=True))
        assert all([path.check_acyclic() for path in paths])
        assert len(paths) == 2
        assert paths[0].as_str() == "n5 -> n4 -> n2 -> n1"
        assert paths[1].as_str() == "n5 -> n4 -> n3 -> n1"
        paths = list(n1.iterate_paths(n5))
        assert all([path.check_acyclic() for path in paths])
        assert len(paths) == 2
        assert paths[0].as_str() == "n1 -> n2 -> n4 -> n5"
        assert paths[1].as_str() == "n1 -> n3 -> n4 -> n5"


    def test_iterate_one_many_one(self):
        r = range(19)
        n0 = FakeNode(0)
        nodes = [FakeNode(i+1) for i in r]
        nend = FakeNode(len(r)+1)

        assert len(list(n0.iterate_paths(nodes[0], backwards=True))) == 0

        for i in r:
            n0.edge_to(nodes[i])
            nodes[i].edge_to(nend)

        paths = list(nend.iterate_paths(n0, backwards=True))
        assert all([path.check_acyclic() for path in paths])
        assert len(paths) == len(r)
        for i in r:
            assert paths[i].as_str() == "n%d -> %s -> n0" % (len(r)+1, nodes[i])
        # forward
        paths = list(n0.iterate_paths(nend))
        assert all([path.check_acyclic() for path in paths])
        assert len(paths) == len(r)
        for i in r:
            assert paths[i].as_str() == "n0 -> %s -> n%d" % (nodes[i], len(r)+1)

    def test_iterate_blacklist_diamond(self):
        blacklist = {}
        n1,n2,n3,n4 = [FakeNode(i+1) for i in range(4)]
        # n1 -> n2 -> n4
        #  +---> n3 --^
        n1.edge_to(n2); n2.edge_to(n4);
        n1.edge_to(n3); n3.edge_to(n4);

        paths = list(n1.iterate_paths(n4, blacklist=True))
        assert len(paths) == 2
        assert paths[0].as_str() == "n1 -> n2 -> n4"
        assert paths[1].as_str() == "n1 -> n3 -> n4"

    def test_iterate_blacklist_double_diamond(self):
        blacklist = {}
        n1,n2,n3,n4,n5,n6,n7,n8 = [FakeNode(i+1) for i in range(8)]
        # n1 -> n2 -> n4 -> n5 -> n6 --> n8
        #  +---> n3 --^      +---> n7 --^
        n1.edge_to(n2); n2.edge_to(n4);
        n1.edge_to(n3); n3.edge_to(n4);
        n4.edge_to(n5)
        n5.edge_to(n6); n6.edge_to(n8);
        n5.edge_to(n7); n7.edge_to(n8);

        paths = list(n1.iterate_paths(n8, blacklist=True))
        assert len(paths) == 3
        assert paths[0].as_str() == "n1 -> n2 -> n4 -> n5 -> n6 -> n8"
        assert paths[1].as_str() == "n1 -> n2 -> n4 -> n5 -> n7 -> n8"
        assert paths[2].as_str() == "n1 -> n3 -> n4"

    def test_iterate_blacklist_split_path(self):
        blacklist = {}
        n1,n2,n3,n4,n5,n6,n7,n8 = [FakeNode(i+1) for i in range(8)]
        n1.edge_to(n2);
        n3.edge_to(n2);
        n2.edge_to(n4);
        n3.edge_to(n4);

        paths = list(n4.iterate_paths(n3, backwards=True, blacklist=True))
        assert len(paths) == 2
        assert paths[0].as_str() == "n4 -> n2 -> n3"
        assert paths[1].as_str() == "n4 -> n3"

        n5.edge_to(n1)
        n5.edge_to(n3)

        paths = list(n4.iterate_paths(n5, backwards=True, blacklist=True))
        assert len(paths) == 3
        assert paths[0].as_str() == "n4 -> n2 -> n1 -> n5"
        assert paths[1].as_str() == "n4 -> n2 -> n3 -> n5"
        assert paths[2].as_str() == "n4 -> n3"

    def test_sccs(self):
        n1,n2 = FakeNode(1), FakeNode(2)
        n1.edge_to(n2); n2.edge_to(n1)

        graph = FakeDependencyGraph([n1,n2])
        cycle = graph.cycles()
        assert cycle == [n1, n2]

        n3 = FakeNode(0)
        graph.nodes = [n3]
        cycle = graph.cycles()
        assert cycle is None

    def test_cycles_2(self):
        n1,n2,n3,n4 = FakeNode(1), FakeNode(2), FakeNode(3), FakeNode(4)
        n1.edge_to(n3); n3.edge_to(n4); n4.edge_to(n1)

        graph = FakeDependencyGraph([n1,n2])
        graph.nodes = [n1,n2,n3]
        cycle = graph.cycles()
        assert cycle is not None
        assert cycle == [n1,n3,n4]

class FakeMemoryRefResOp(object):
    def __init__(self, array, descr):
        self.array = array
        self.descr = descr
    def getarg(self, index):
        return self.array
    def getdescr(self):
        return self.descr

FLOAT = ArrayDescr(lltype.GcArray(lltype.Float), None)

def memoryref(array, var, mod=(1,1,0), descr=None, raw=False):
    if descr is None:
        descr = FLOAT
    mul, div, off = mod
    op = FakeMemoryRefResOp(array, descr)
    return MemoryRef(op,
                     IndexVar(var, mul, div, off),
                     raw)

class FakeBox(object):
    pass

class FakeNode(Node):
    def __init__(self, i):
        Node.__init__(self, None, i)
        pass

    def __repr__(self):
        return "n%d" % self.opidx
