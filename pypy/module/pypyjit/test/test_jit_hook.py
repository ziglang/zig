
import py
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.pycode import PyCode
from rpython.jit.metainterp.history import JitCellToken, ConstInt, ConstPtr,\
     BasicFailDescr
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.metainterp.logger import Logger
from rpython.rtyper.annlowlevel import (cast_instance_to_base_ptr,
                                      cast_base_ptr_to_instance)
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.rtyper.rclass import OBJECT
from pypy.module.pypyjit.interp_jit import pypyjitdriver
from pypy.module.pypyjit.hooks import pypy_hooks
from rpython.jit.tool.oparser import parse
from rpython.rlib.jit import JitDebugInfo, AsmInfo, Counters


class MockJitDriverSD(object):
    class warmstate(object):
        @staticmethod
        def get_location_str(boxes):
            ll_code = lltype.cast_opaque_ptr(lltype.Ptr(OBJECT),
                                             boxes[2].getref_base())
            pycode = cast_base_ptr_to_instance(PyCode, ll_code)
            return pycode.co_name

    jitdriver = pypyjitdriver


class MockSD(object):
    class cpu(object):
        pass

    jitdrivers_sd = [MockJitDriverSD]


class AppTestJitHook(object):
    spaceconfig = dict(usemodules=('pypyjit',))

    def setup_class(cls):
        if cls.runappdirect:
            py.test.skip("Can't run this test with -A")
        w_f = cls.space.appexec([], """():
        def function():
            pass
        return function
        """)
        cls.w_f = w_f
        ll_code = cast_instance_to_base_ptr(w_f.code)
        code_gcref = lltype.cast_opaque_ptr(llmemory.GCREF, ll_code)
        logger = Logger(MockSD())

        oplist = parse("""
        [i1, i2, p2]
        i3 = int_add(i1, i2)
        debug_merge_point(0, 0, 0, 0, 0, ConstPtr(ptr0))
        guard_nonnull(p2) []
        guard_true(i3) []
        """, namespace={'ptr0': code_gcref}).operations
        greenkey = [ConstInt(0), ConstInt(0), ConstPtr(code_gcref)]
        offset = {}
        for i, op in enumerate(oplist):
            if i != 1:
                offset[op] = i

        oplist_no_descrs = parse("""
        [i1, i2, p2]
        i3 = int_add(i1, i2)
        debug_merge_point(0, 0, 0, 0, 0, ConstPtr(ptr0))
        guard_nonnull(p2) []
        guard_true(i3) []
        """, namespace={'ptr0': code_gcref}).operations
        for op in oplist_no_descrs:
            if op.is_guard():
                op.setdescr(None)

        class FailDescr(BasicFailDescr):
            def get_jitcounter_hash(self):
                from rpython.rlib.rarithmetic import r_uint
                return r_uint(13)

        oplist[-1].setdescr(FailDescr())
        oplist[-2].setdescr(FailDescr())

        token = JitCellToken()
        token.number = 0
        di_loop = JitDebugInfo(MockJitDriverSD, logger, token, oplist, 'loop',
                   greenkey)
        di_loop_optimize = JitDebugInfo(MockJitDriverSD, logger, JitCellToken(),
                                        oplist, 'loop', greenkey)
        di_loop.asminfo = AsmInfo(offset, 0x42, 12)
        di_bridge = JitDebugInfo(MockJitDriverSD, logger, JitCellToken(),
                                 oplist, 'bridge', fail_descr=FailDescr())
        di_bridge.asminfo = AsmInfo(offset, 0, 0)

        def interp_on_compile():
            di_loop.oplist = cls.oplist
            if pypy_hooks.are_hooks_enabled():
                pypy_hooks.after_compile(di_loop)

        def interp_on_compile_bridge():
            if pypy_hooks.are_hooks_enabled():
                pypy_hooks.after_compile_bridge(di_bridge)

        def interp_on_optimize():
            if pypy_hooks.are_hooks_enabled():
                di_loop_optimize.oplist = cls.oplist
                pypy_hooks.before_compile(di_loop_optimize)

        def interp_on_abort():
            if pypy_hooks.are_hooks_enabled():
                pypy_hooks.on_abort(Counters.ABORT_TOO_LONG, pypyjitdriver,
                                    greenkey, 'blah', Logger(MockSD),
                                    cls.oplist_no_descrs)

        space = cls.space
        cls.w_on_compile = space.wrap(interp2app(interp_on_compile))
        cls.w_on_compile_bridge = space.wrap(interp2app(interp_on_compile_bridge))
        cls.w_on_abort = space.wrap(interp2app(interp_on_abort))
        cls.w_int_add_num = space.wrap(rop.INT_ADD)
        cls.w_dmp_num = space.wrap(rop.DEBUG_MERGE_POINT)
        cls.w_on_optimize = space.wrap(interp2app(interp_on_optimize))
        cls.orig_oplist = oplist
        cls.orig_oplist_no_descrs = oplist_no_descrs
        cls.w_sorted_keys = space.wrap(sorted(Counters.counter_names))

    def setup_method(self, meth):
        self.__class__.oplist = self.orig_oplist[:]
        self.__class__.oplist_no_descrs = self.orig_oplist_no_descrs[:]

    def test_on_compile(self):
        import pypyjit
        all = []

        def hook(info):
            all.append(info)

        self.on_compile()
        pypyjit.set_compile_hook(hook)
        assert not all
        self.on_compile()
        assert len(all) == 1
        info = all[0]
        assert info.jitdriver_name == 'pypyjit'
        assert info.greenkey[0].co_name == 'function'
        assert info.greenkey[1] == 0
        assert info.greenkey[2] == False
        assert info.loop_no == 0
        assert info.type == 'loop'
        assert info.asmaddr == 0x42
        assert info.asmlen == 12
        raises(TypeError, 'info.bridge_no')
        assert len(info.operations) == 4
        int_add = info.operations[0]
        dmp = info.operations[1]
        assert isinstance(dmp, pypyjit.DebugMergePoint)
        assert dmp.pycode is self.f.__code__
        assert dmp.greenkey == (self.f.__code__, 0, False)
        assert dmp.call_depth == 0
        assert dmp.call_id == 0
        assert dmp.offset == -1
        assert int_add.name == 'int_add'
        assert int_add.offset == 0
        self.on_compile_bridge()
        expected = ('<JitLoopInfo pypyjit, 4 operations, starting at '
                    '<(%s, 0, False)>>' % repr(self.f.__code__))
        assert repr(all[0]) == expected
        assert len(all) == 2
        pypyjit.set_compile_hook(None)
        self.on_compile()
        assert len(all) == 2

    def test_on_compile_exception(self):
        import pypyjit, sys
        from io import StringIO

        def hook(*args):
            1/0

        pypyjit.set_compile_hook(hook)
        s = StringIO()
        prev = sys.stderr
        sys.stderr = s
        try:
            self.on_compile()
        finally:
            sys.stderr = prev
        assert 'jit hook' in s.getvalue()
        assert 'ZeroDivisionError' in s.getvalue()

    def test_on_compile_crashes(self):
        import pypyjit
        loops = []
        def hook(loop):
            loops.append(loop)
        pypyjit.set_compile_hook(hook)
        self.on_compile()
        loop = loops[0]
        op = loop.operations[2]
        assert op.name == 'guard_nonnull'

    def test_non_reentrant(self):
        import pypyjit
        l = []

        def hook(*args):
            l.append(None)
            self.on_compile()
            self.on_compile_bridge()

        pypyjit.set_compile_hook(hook)
        self.on_compile()
        assert len(l) == 1 # and did not crash
        self.on_compile_bridge()
        assert len(l) == 2 # and did not crash

    def test_on_compile_types(self):
        import pypyjit
        l = []

        def hook(info):
            l.append(info)

        pypyjit.set_compile_hook(hook)
        self.on_compile()
        op = l[0].operations[1]
        assert isinstance(op, pypyjit.ResOperation)
        assert 'function' in repr(op)

    def test_on_abort(self):
        import pypyjit
        l = []

        def hook(jitdriver_name, greenkey, reason, operations):
            l.append((jitdriver_name, reason, operations))

        pypyjit.set_abort_hook(hook)
        self.on_abort()
        assert len(l) == 1
        name, reason, ops = l[0]
        assert name == 'pypyjit'
        assert reason == 'ABORT_TOO_LONG'
        assert len(ops) == 4
        assert ops[2].hash == 0

    def test_creation(self):
        from pypyjit import ResOperation

        op = ResOperation("int_add", -1, "int_add(1, 2)")
        assert op.name == 'int_add'
        assert repr(op) == "int_add(1, 2)"

    def test_creation_dmp(self):
        from pypyjit import DebugMergePoint

        def f():
            pass

        op = DebugMergePoint("debug_merge_point", 'repr', 'pypyjit', 2, 3, (f.__code__, 0, 0))
        assert op.bytecode_no == 0
        assert op.pycode is f.__code__
        assert repr(op) == 'repr'
        assert op.jitdriver_name == 'pypyjit'
        assert op.name == 'debug_merge_point'
        assert op.call_depth == 2
        assert op.call_id == 3
        op = DebugMergePoint('debug_merge_point', 'repr', 'notmain',
                             5, 4, ('str',))
        raises(AttributeError, 'op.pycode')
        assert op.call_depth == 5

    def test_get_stats_snapshot(self):
        skip("a bit no idea how to test it")
        from pypyjit import get_stats_snapshot

        stats = get_stats_snapshot() # we can't do much here, unfortunately
        assert stats.w_loop_run_times == []
        assert isinstance(stats.w_counters, dict)
        assert sorted(stats.w_counters.keys()) == self.sorted_keys

