from rpython.jit.metainterp import compile
from rpython.jit.metainterp.history import Const
from rpython.jit.metainterp.optimizeopt.dependency import (
    DependencyGraph, IndexVar)
from rpython.jit.metainterp.optimizeopt.guard import (GuardStrengthenOpt,
        Guard)
from rpython.jit.metainterp.optimizeopt.test.test_schedule import SchedulerBaseTest
from rpython.jit.metainterp.optimizeopt.test.test_vecopt import FakeLoopInfo
from rpython.jit.metainterp.resoperation import (rop,
        ResOperation, InputArgInt)

class FakeMemoryRef(object):
    def __init__(self, array, iv):
        self.index_var = iv
        self.array = array

    def is_adjacent_to(self, other):
        if self.array is not other.array:
            return False
        iv = self.index_var
        ov = other.index_var
        val = (int(str(ov.var)[1:]) - int(str(iv.var)[1:]))
        # i0 and i1 are adjacent
        # i1 and i0 ...
        # but not i0, i2
        # ...
        return abs(val) == 1

class FakeOp(object):
    def __init__(self, cmpop):
        self.boolinverse = ResOperation(cmpop, [box(0), box(0)], None).boolinverse
        self.cmpop = cmpop

    def getopnum(self):
        return self.cmpop

    def getarg(self, index):
        if index == 0:
            return 'lhs'
        elif index == 1:
            return 'rhs'
        else:
            assert 0

class FakeResOp(object):
    def __init__(self, opnum):
        self.opnum = opnum

    def getopnum(self):
        return self.opnum

def box(value):
    return InputArgInt(value)

def const(value):
    return Const._new(value)

def iv(value, coeff=(1,1,0)):
    var = IndexVar(value)
    var.coefficient_mul = coeff[0]
    var.coefficient_div = coeff[1]
    var.constant = coeff[2]
    return var

def guard(opnum):
    def guard_impl(cmpop, lhs, rhs):
        guard = Guard(0, FakeResOp(opnum), FakeOp(cmpop), {'lhs': lhs, 'rhs': rhs})
        return guard
    return guard_impl
guard_true = guard(rop.GUARD_TRUE)
guard_false = guard(rop.GUARD_FALSE)
del guard

class TestGuard(SchedulerBaseTest):
    def optguards(self, loop, user_code=False):
        info = FakeLoopInfo(loop)
        info.snapshot(loop)
        for op in loop.operations:
            if op.is_guard():
                op.setdescr(compile.CompileLoopVersionDescr())
        dep = DependencyGraph(loop)
        opt = GuardStrengthenOpt(dep.index_vars)
        opt.propagate_all_forward(info, loop, user_code)
        return opt

    def assert_guard_count(self, loop, count):
        guard = 0
        for op in loop.operations + loop.prefix:
            if op.is_guard():
                guard += 1
        if guard != count:
            self.debug_print_operations(loop)
        assert guard == count

    def assert_contains_sequence(self, loop, instr):
        class Glob(object):
            next = None
            prev = None
            def __repr__(self):
                return '*'
        from rpython.jit.tool.oparser import OpParser, default_fail_descr
        parser = OpParser(instr, self.cpu, self.namespace, None, default_fail_descr, True, None)
        parser.vars = { arg.repr_short(arg._repr_memo) : arg for arg in loop.inputargs}
        operations = []
        last_glob = None
        prev_op = None
        for line in instr.splitlines():
            line = line.strip()
            if line.startswith("#") or \
               line == "":
                continue
            if line.startswith("..."):
                last_glob = Glob()
                last_glob.prev = prev_op
                operations.append(last_glob)
                continue
            op = parser.parse_next_op(line)
            if last_glob is not None:
                last_glob.next = op
                last_glob = None
            operations.append(op)
        def check(op, candidate, rename):
            m = 0
            if isinstance(candidate, Glob):
                if candidate.next is None:
                    return 0 # consumes the rest
                if op.getopnum() != candidate.next.getopnum():
                    return 0
                m = 1
                candidate = candidate.next
            if op.getopnum() == candidate.getopnum():
                for i,arg in enumerate(op.getarglist()):
                    oarg = candidate.getarg(i)
                    if arg in rename:
                        assert rename[arg].same_box(oarg)
                    else:
                        rename[arg] = oarg

                if not op.returns_void():
                    rename[op] = candidate
                m += 1
                return m
            return 0
        j = 0
        rename = {}
        ops = loop.finaloplist()
        for i, op in enumerate(ops):
            candidate = operations[j]
            j += check(op, candidate, rename)
        if isinstance(operations[-1], Glob):
            assert j == len(operations)-1, self.debug_print_operations(loop)
        else:
            assert j == len(operations), self.debug_print_operations(loop)

    def test_basic(self):
        loop1 = self.parse_trace("""
        i10 = int_lt(i1, 42)
        guard_true(i10) []
        i101 = int_add(i1, 1)
        i102 = int_lt(i101, 42)
        guard_true(i102) []
        """)
        opt = self.optguards(loop1)
        self.assert_guard_count(loop1, 1)
        self.assert_contains_sequence(loop1, """
        ...
        i101 = int_add(i1, 1)
        i12 = int_lt(i101, 42)
        guard_true(i12) []
        ...
        """)

    def test_basic_sub(self):
        loop1 = self.parse_trace("""
        i10 = int_gt(i1, 42)
        guard_true(i10) []
        i101 = int_sub(i1, 1)
        i12 = int_gt(i101, 42)
        guard_true(i12) []
        """)
        opt = self.optguards(loop1)
        self.assert_guard_count(loop1, 1)
        self.assert_contains_sequence(loop1, """
        ...
        i101 = int_sub(i1, 1)
        i12 = int_gt(i101, 42)
        guard_true(i12) []
        ...
        """)

    def test_basic_mul(self):
        loop1 = self.parse_trace("""
        i10 = int_mul(i1, 4)
        i20 = int_lt(i10, 42)
        guard_true(i20) []
        i12 = int_add(i10, 1)
        i13 = int_lt(i12, 42)
        guard_true(i13) []
        """)
        opt = self.optguards(loop1)
        self.assert_guard_count(loop1, 1)
        self.assert_contains_sequence(loop1, """
        ...
        i101 = int_mul(i1, 4)
        i12 = int_add(i101, 1)
        i13 = int_lt(i12, 42)
        guard_true(i13) []
        ...
        """)

    def test_compare(self):
        key = box(1)
        incomparable = (False, 0)
        # const const
        assert iv(const(42)).compare(iv(const(42))) == (True, 0)
        assert iv(const(-400)).compare(iv(const(-200))) == (True, -200)
        assert iv(const(0)).compare(iv(const(-1))) == (True, 1)
        # var const
        assert iv(key, coeff=(1,1,0)).compare(iv(const(42))) == incomparable
        assert iv(key, coeff=(5,70,500)).compare(iv(const(500))) == incomparable
        # var var
        assert iv(key, coeff=(1,1,0)).compare(iv(key,coeff=(1,1,0))) == (True, 0)
        assert iv(key, coeff=(1,7,0)).compare(iv(key,coeff=(1,7,0))) == (True, 0)
        assert iv(key, coeff=(4,7,0)).compare(iv(key,coeff=(3,7,0))) == incomparable
        assert iv(key, coeff=(14,7,0)).compare(iv(key,coeff=(2,1,0))) == (True, 0)
        assert iv(key, coeff=(14,7,33)).compare(iv(key,coeff=(2,1,0))) == (True, 33)
        assert iv(key, coeff=(15,5,33)).compare(iv(key,coeff=(3,1,33))) == (True, 0)


    def test_imply_basic(self):
        key = box(1)
        # if x < 42 <=> x < 42
        g1 = guard_true(rop.INT_LT, iv(key, coeff=(1,1,0)), iv(const(42)))
        g2 = guard_true(rop.INT_LT, iv(key, coeff=(1,1,0)), iv(const(42)))
        assert g1.implies(g2)
        assert g2.implies(g1)
        # if x+1 < 42 => x < 42
        g1 = guard_true(rop.INT_LT, iv(key, coeff=(1,1,1)), iv(const(42)))
        g2 = guard_true(rop.INT_LT, iv(key, coeff=(1,1,0)), iv(const(42)))
        assert g1.implies(g2)
        assert not g2.implies(g1)
        # if x+2 < 42 => x < 39
        # counter: 39+2 < 42 => 39 < 39
        g1 = guard_true(rop.INT_LT, iv(key, coeff=(1,1,2)), iv(const(42)))
        g2 = guard_true(rop.INT_LT, iv(key, coeff=(1,1,0)), iv(const(39)))
        assert not g1.implies(g2)
        assert not g2.implies(g1)
        # if x+2 <= 42 => x <= 43
        g1 = guard_true(rop.INT_LE, iv(key, coeff=(1,1,2)), iv(const(42)))
        g2 = guard_true(rop.INT_LE, iv(key, coeff=(1,1,0)), iv(const(43)))
        assert g1.implies(g2)
        assert not g2.implies(g1)
        # if x*13/3+1 <= 0 => x*13/3 <= -1
        # is true, but the implies method is not smart enough
        g1 = guard_true(rop.INT_LE, iv(key, coeff=(13,3,1)), iv(const(0)))
        g2 = guard_true(rop.INT_LE, iv(key, coeff=(13,3,0)), iv(const(-1)))
        assert not g1.implies(g2)
        assert not g2.implies(g1)
        # > or >=
        # if x > -55 => x*2 > -44
        # counter: -44 > -55 (True) => -88 > -44 (False)
        g1 = guard_true(rop.INT_GT, iv(key, coeff=(1,1,0)), iv(const(-55)))
        g2 = guard_true(rop.INT_GT, iv(key, coeff=(2,1,0)), iv(const(-44)))
        assert not g1.implies(g2)
        assert not g2.implies(g1)
        # if x*2/2 > -44 => x*2/2 > -55
        g1 = guard_true(rop.INT_GE, iv(key, coeff=(2,2,0)), iv(const(-44)))
        g2 = guard_true(rop.INT_GE, iv(key, coeff=(2,2,0)), iv(const(-55)))
        assert g1.implies(g2)
        assert not g2.implies(g1)

    def test_imply_coeff(self):
        key = box(1)
        key2 = box(2)
        # if x > y * 9/3 => x > y
        # counter: x = -2, y = -1, -2 > -3 => -2 > -1, True => False
        g1 = guard_true(rop.INT_GT, iv(key, coeff=(1,1,0)), iv(box(1),coeff=(9,3,0)))
        g2 = guard_true(rop.INT_GT, iv(key, coeff=(1,1,0)), iv(box(1),coeff=(1,1,0)))
        assert not g1.implies(g2)
        assert not g2.implies(g1)
        # if x > y * 15/5 <=> x > y * 3
        g1 = guard_true(rop.INT_GT, iv(key, coeff=(1,1,0)), iv(key2,coeff=(15,5,0)))
        g2 = guard_true(rop.INT_GT, iv(key, coeff=(1,1,0)), iv(key2,coeff=(3,1,0)))
        assert g1.implies(g2)
        assert g2.implies(g1)
        # x >= y => x*3-5 >= y
        # counter: 1 >= 0 => 1*3-5 >= 0 == -2 >= 0, True => False
        g1 = guard_true(rop.INT_GE, iv(key, coeff=(1,1,0)), iv(key2))
        g2 = guard_true(rop.INT_GE, iv(key, coeff=(3,1,-5)), iv(key2))
        assert not g1.implies(g2)
        assert not g2.implies(g1)
        # guard false inverst >= to <
        # x < y => x*3-5 < y
        # counter: 3 < 4 => 3*3-5 < 4 == 4 < 4, True => False
        g1 = guard_false(rop.INT_GE, iv(key, coeff=(1,1,0)), iv(key2))
        g2 = guard_false(rop.INT_GE, iv(key, coeff=(3,1,-5)), iv(key2))
        assert not g1.implies(g2)
        assert not g2.implies(g1)
        # x <= y => x*3-5 > y
        # counter: 3 < 4 => 3*3-5 < 4 == 4 < 4, True => False
        g1 = guard_false(rop.INT_GT, iv(key, coeff=(1,1,0)), iv(key2))
        g2 = guard_true(rop.INT_GT, iv(key, coeff=(3,1,-5)), iv(key2))
        assert not g1.implies(g2)
        assert not g2.implies(g1)

    def test_collapse(self):
        loop1 = self.parse_trace("""
        i10 = int_gt(i1, 42)
        guard_true(i10) []
        i11 = int_add(i1, 1)
        i12 = int_gt(i11, i2)
        guard_true(i12) []
        """)
        opt = self.optguards(loop1, True)
        self.assert_guard_count(loop1, 2)
        self.assert_contains_sequence(loop1, """
        ...
        i100 = int_ge(42, i2)
        guard_true(i100) []
        ...
        i40 = int_gt(i1, 42)
        guard_true(i40) []
        ...
        """)
