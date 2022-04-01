import py
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, rstr
from rpython.jit.metainterp.history import ResOperation, TargetToken,\
     JitCellToken
from rpython.jit.metainterp.history import (ConstInt, ConstPtr, Const,
                                            BasicFailDescr, BasicFinalDescr)
from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.backend.x86.arch import WORD, WIN64
from rpython.jit.backend.x86.rx86 import fits_in_32bits
from rpython.jit.backend.llsupport import symbolic
from rpython.jit.metainterp.resoperation import rop, InputArgInt, InputArgRef
from rpython.jit.metainterp.executor import execute
from rpython.jit.backend.test.runner_test import LLtypeBackendTest
from rpython.jit.tool.oparser import parse
import ctypes

CPU = getcpuclass()

class FakeStats(object):
    pass

U = LLtypeBackendTest.U
S = LLtypeBackendTest.S

# ____________________________________________________________

class TestX86(LLtypeBackendTest):

    # for the individual tests see
    # ====> ../../test/runner_test.py

    if WORD == 4:
        add_loop_instructions = ('mov; '
                                 'lea; '    # a nop, for the label
                                 'add; test; je; jmp;')   # plus some padding
        bridge_loop_instructions = 'cmp; jl; jmp;'
    else:
        add_loop_instructions = ('mov; '
                                 'nop; '    # for the label
                                 'add; test; je; jmp;')   # plus some padding
        bridge_loop_instructions = (
            'cmp; jl; mov(abs)?; jmp;')

    def get_cpu(self):
        cpu = CPU(rtyper=None, stats=FakeStats())
        cpu.setup_once()
        return cpu

    def test_execute_ptr_operation(self):
        cpu = self.cpu
        u_box, _, _ = self.alloc_instance(U)
        u = u_box.getref(lltype.Ptr(U))
        ofs = cpu.fielddescrof(S, 'value')
        assert self.execute_operation(rop.SETFIELD_GC,
                                      [u_box, InputArgInt(3)],
                                     'void', ofs) == None
        assert u.parent.parent.value == 3
        u.parent.parent.value += 100
        assert (self.execute_operation(rop.GETFIELD_GC_I, [u_box], 'int', ofs)
                 == 103)

    def test_unicode(self):
        ofs = symbolic.get_field_token(rstr.UNICODE, 'chars', False)[0]
        u = rstr.mallocunicode(13)
        for i in range(13):
            u.chars[i] = unichr(ord(u'a') + i)
        b = InputArgRef(lltype.cast_opaque_ptr(llmemory.GCREF, u))
        r = self.execute_operation(rop.UNICODEGETITEM, [b, ConstInt(2)], 'int')
        assert r == ord(u'a') + 2
        self.execute_operation(rop.UNICODESETITEM, [b, ConstInt(2),
                                                    ConstInt(ord(u'z'))],
                               'void')
        assert u.chars[2] == u'z'
        assert u.chars[3] == u'd'

    @staticmethod
    def _resbuf(res, item_tp=ctypes.c_long if not WIN64 else ctypes.c_longlong):
        return ctypes.cast(res._obj.intval, ctypes.POINTER(item_tp))

    def test_allocations(self):
        py.test.skip("rewrite or kill")
        from rpython.rtyper.lltypesystem import rstr

        allocs = [None]
        all = []
        orig_new = self.cpu.gc_ll_descr.funcptr_for_new
        def f(size):
            allocs.insert(0, size)
            return orig_new(size)

        self.cpu.assembler.setup_once()
        self.cpu.gc_ll_descr.funcptr_for_new = f
        ofs = symbolic.get_field_token(rstr.STR, 'chars', False)[0]

        res = self.execute_operation(rop.NEWSTR, [ConstInt(7)], 'ref')
        assert allocs[0] == 7 + ofs + WORD
        resbuf = self._resbuf(res)
        assert resbuf[ofs/WORD] == 7

        # ------------------------------------------------------------

        res = self.execute_operation(rop.NEWSTR, [InputArgInt(7)], 'ref')
        assert allocs[0] == 7 + ofs + WORD
        resbuf = self._resbuf(res)
        assert resbuf[ofs/WORD] == 7

        # ------------------------------------------------------------

        TP = lltype.GcArray(lltype.Signed)
        ofs = symbolic.get_field_token(TP, 'length', False)[0]
        descr = self.cpu.arraydescrof(TP)

        res = self.execute_operation(rop.NEW_ARRAY, [ConstInt(10)],
                                         'ref', descr)
        assert allocs[0] == 10*WORD + ofs + WORD
        resbuf = self._resbuf(res)
        assert resbuf[ofs/WORD] == 10

        # ------------------------------------------------------------

        res = self.execute_operation(rop.NEW_ARRAY, [InputArgInt(10)],
                                         'ref', descr)
        assert allocs[0] == 10*WORD + ofs + WORD
        resbuf = self._resbuf(res)
        assert resbuf[ofs/WORD] == 10

    def test_stringitems(self):
        from rpython.rtyper.lltypesystem.rstr import STR
        ofs = symbolic.get_field_token(STR, 'chars', False)[0]
        ofs_items = symbolic.get_field_token(STR.chars, 'items', False)[0]

        res = self.execute_operation(rop.NEWSTR, [ConstInt(10)], 'ref')
        self.execute_operation(rop.STRSETITEM, [InputArgRef(res), ConstInt(2), ConstInt(ord('d'))], 'void')
        resbuf = self._resbuf(res, ctypes.c_char)
        assert resbuf[ofs + ofs_items + 2] == 'd'
        self.execute_operation(rop.STRSETITEM, [InputArgRef(res), InputArgInt(2), ConstInt(ord('z'))], 'void')
        assert resbuf[ofs + ofs_items + 2] == 'z'
        r = self.execute_operation(rop.STRGETITEM, [InputArgRef(res), InputArgInt(2)], 'int')
        assert r == ord('z')

    def test_arrayitems(self):
        TP = lltype.GcArray(lltype.Signed)
        ofs = symbolic.get_field_token(TP, 'length', False)[0]
        itemsofs = symbolic.get_field_token(TP, 'items', False)[0]
        descr = self.cpu.arraydescrof(TP)
        res = self.execute_operation(rop.NEW_ARRAY, [ConstInt(10)],
                                     'ref', descr)
        resbuf = self._resbuf(res)
        assert resbuf[ofs/WORD] == 10
        self.execute_operation(rop.SETARRAYITEM_GC, [InputArgRef(res),
                                                     ConstInt(2), InputArgInt(38)],
                               'void', descr)
        assert resbuf[itemsofs/WORD + 2] == 38

        self.execute_operation(rop.SETARRAYITEM_GC, [InputArgRef(res),
                                                     InputArgInt(3), InputArgInt(42)],
                               'void', descr)
        assert resbuf[itemsofs/WORD + 3] == 42

        r = self.execute_operation(rop.GETARRAYITEM_GC_I, [InputArgRef(res), ConstInt(2)],
                                   'int', descr)
        assert r == 38
        r = self.execute_operation(rop.GETARRAYITEM_GC_I, [ConstPtr(res),
                                                         InputArgInt(2)],
                                   'int', descr)
        assert r == 38
        r = self.execute_operation(rop.GETARRAYITEM_GC_I, [ConstPtr(res),
                                                         ConstInt(2)],
                                   'int', descr)
        assert r == 38
        r = self.execute_operation(rop.GETARRAYITEM_GC_I, [InputArgRef(res),
                                                         InputArgInt(2)],
                                   'int', descr)
        assert r == 38

        r = self.execute_operation(rop.GETARRAYITEM_GC_I, [InputArgRef(res), InputArgInt(3)],
                                   'int', descr)
        assert r == 42

    def test_arrayitems_not_int(self):
        TP = lltype.GcArray(lltype.Char)
        ofs = symbolic.get_field_token(TP, 'length', False)[0]
        itemsofs = symbolic.get_field_token(TP, 'items', False)[0]
        descr = self.cpu.arraydescrof(TP)
        res = self.execute_operation(rop.NEW_ARRAY, [ConstInt(10)],
                                     'ref', descr)
        resbuf = self._resbuf(res, ctypes.c_char)
        res = InputArgRef(res)
        assert resbuf[ofs] == chr(10)
        for i in range(10):
            self.execute_operation(rop.SETARRAYITEM_GC, [res,
                                                   ConstInt(i), InputArgInt(i)],
                                   'void', descr)
        for i in range(10):
            assert resbuf[itemsofs + i] == chr(i)
        for i in range(10):
            r = self.execute_operation(rop.GETARRAYITEM_GC_I, [res,
                                                             ConstInt(i)],
                                         'int', descr)
            assert r == i

    def test_getfield_setfield(self):
        TP = lltype.GcStruct('x', ('s', lltype.Signed),
                             ('i', rffi.INT),
                             ('f', lltype.Float),
                             ('u', rffi.USHORT),
                             ('c1', lltype.Char),
                             ('c2', lltype.Char),
                             ('c3', lltype.Char))
        res = InputArgRef(self.execute_operation(rop.NEW, [],
                                     'ref', self.cpu.sizeof(TP)))
        ofs_s = self.cpu.fielddescrof(TP, 's')
        ofs_i = self.cpu.fielddescrof(TP, 'i')
        #ofs_f = self.cpu.fielddescrof(TP, 'f')
        ofs_u = self.cpu.fielddescrof(TP, 'u')
        ofsc1 = self.cpu.fielddescrof(TP, 'c1')
        ofsc2 = self.cpu.fielddescrof(TP, 'c2')
        ofsc3 = self.cpu.fielddescrof(TP, 'c3')
        self.execute_operation(rop.SETFIELD_GC, [res, ConstInt(3)], 'void',
                               ofs_s)
        # XXX ConstFloat
        #self.execute_operation(rop.SETFIELD_GC, [res, ofs_f, 1e100], 'void')
        # XXX we don't support shorts (at all)
        #self.execute_operation(rop.SETFIELD_GC, [res, ofs_u, ConstInt(5)], 'void')
        s = self.execute_operation(rop.GETFIELD_GC_I, [res], 'int', ofs_s)
        assert s == 3
        self.execute_operation(rop.SETFIELD_GC, [res, InputArgInt(3)], 'void',
                               ofs_s)
        s = self.execute_operation(rop.GETFIELD_GC_I, [res], 'int', ofs_s)
        assert s == 3

        self.execute_operation(rop.SETFIELD_GC, [res, InputArgInt(1234)], 'void', ofs_i)
        i = self.execute_operation(rop.GETFIELD_GC_I, [res], 'int', ofs_i)
        assert i == 1234

        #u = self.execute_operation(rop.GETFIELD_GC, [res, ofs_u], 'int')
        #assert u.value == 5
        self.execute_operation(rop.SETFIELD_GC, [res, ConstInt(1)], 'void',
                               ofsc1)
        self.execute_operation(rop.SETFIELD_GC, [res, ConstInt(3)], 'void',
                               ofsc3)
        self.execute_operation(rop.SETFIELD_GC, [res, ConstInt(2)], 'void',
                               ofsc2)
        c = self.execute_operation(rop.GETFIELD_GC_I, [res], 'int', ofsc1)
        assert c == 1
        c = self.execute_operation(rop.GETFIELD_GC_I, [res], 'int', ofsc2)
        assert c == 2
        c = self.execute_operation(rop.GETFIELD_GC_I, [res], 'int', ofsc3)
        assert c == 3

    def test_bug_setfield_64bit(self):
        if WORD == 4:
            py.test.skip("only for 64 bits")
        TP = lltype.GcStruct('S', ('i', lltype.Signed))
        ofsi = self.cpu.fielddescrof(TP, 'i')
        for i in range(500):
            p = lltype.malloc(TP)
            addr = rffi.cast(lltype.Signed, p)
            if fits_in_32bits(addr):
                break    # fitting in 32 bits, good
        else:
            py.test.skip("cannot get a 32-bit pointer")
        res = ConstPtr(rffi.cast(llmemory.GCREF, addr))
        self.execute_operation(rop.SETFIELD_RAW, [res, ConstInt(3**33)],
                               'void', ofsi)
        assert p.i == 3**33

    def test_getfield_64bit_offset(self):
        if WORD == 4:
            py.test.skip("only for 64 bits")
        TP = lltype.Struct('S', ('i', lltype.Signed))
        p = lltype.malloc(TP, flavor='raw')
        p.i = 0x123456789ABC
        offset = 3**33
        val = rffi.cast(lltype.Signed, rffi.cast(lltype.Signed, p) - offset)
        res = self.execute_operation(rop.GC_LOAD_I,
                                     [InputArgInt(val),
                                      ConstInt(offset),
                                      ConstInt(WORD)],
                                     'int')
        assert res == 0x123456789ABC
        lltype.free(p, flavor='raw')

    def test_and_mask_common_patterns(self):
        cases = [8, 16, 24]
        if WORD == 8:
            cases.append(32)
            bigvalue = 0xAAAAAAAAAAAA
        else:
            bigvalue = 0xAAAAAAA
        for i in cases:
            box = InputArgInt(bigvalue)
            res = self.execute_operation(rop.INT_AND,
                                         [box, ConstInt(2 ** i - 1)],
                                         'int')
            assert res == bigvalue & (2 ** i - 1)

    def test_nullity_with_guard(self):
        allops = [rop.INT_IS_TRUE]
        guards = [rop.GUARD_TRUE, rop.GUARD_FALSE]
        p = lltype.cast_opaque_ptr(llmemory.GCREF,
                                   lltype.malloc(lltype.GcStruct('x')))
        nullptr = lltype.nullptr(llmemory.GCREF.TO)
        f = InputArgInt()
        for op in allops:
            for guard in guards:
                if op == rop.INT_IS_TRUE:
                    bp = InputArgInt(1)
                    n = InputArgInt(0)
                else:
                    bp = InputArgRef(p)
                    n = InputArgRef(nullptr)
                for b in (bp, n):
                    i1 = ResOperation(rop.SAME_AS_I, [ConstInt(1)])
                    f = ResOperation(op, [b])
                    ops = [
                        i1,
                        f,
                        ResOperation(guard, [f],
                                     descr=BasicFailDescr()),
                        ResOperation(rop.FINISH, [ConstInt(0)],
                                     descr=BasicFinalDescr()),
                        ]
                    ops[-2].setfailargs([i1])
                    looptoken = JitCellToken()
                    self.cpu.compile_loop([b], ops, looptoken)
                    deadframe = self.cpu.execute_token(looptoken, b.getint())
                    result = self.cpu.get_int_value(deadframe, 0)
                    if guard == rop.GUARD_FALSE:
                        assert result == execute(self.cpu, None,
                                                 op, None, b)
                    else:
                        assert result != execute(self.cpu, None,
                                                 op, None, b)


    def test_stuff_followed_by_guard(self):
        boxes = [(InputArgInt(1), InputArgInt(0)),
                 (InputArgInt(0), InputArgInt(1)),
                 (InputArgInt(1), InputArgInt(1)),
                 (InputArgInt(-1), InputArgInt(1)),
                 (InputArgInt(1), InputArgInt(-1)),
                 (ConstInt(1), InputArgInt(0)),
                 (ConstInt(0), InputArgInt(1)),
                 (ConstInt(1), InputArgInt(1)),
                 (ConstInt(-1), InputArgInt(1)),
                 (ConstInt(1), InputArgInt(-1)),
                 (InputArgInt(1), ConstInt(0)),
                 (InputArgInt(0), ConstInt(1)),
                 (InputArgInt(1), ConstInt(1)),
                 (InputArgInt(-1), ConstInt(1)),
                 (InputArgInt(1), ConstInt(-1))]
        guards = [rop.GUARD_FALSE, rop.GUARD_TRUE]
        all = [rop.INT_EQ, rop.INT_NE, rop.INT_LE, rop.INT_LT, rop.INT_GT,
               rop.INT_GE, rop.UINT_GT, rop.UINT_LT, rop.UINT_LE, rop.UINT_GE]
        for a, b in boxes:
            for guard in guards:
                for op in all:
                    i1 = ResOperation(rop.SAME_AS_I, [ConstInt(1)])
                    res = ResOperation(op, [a, b])
                    ops = [
                        i1, res,
                        ResOperation(guard, [res],
                                     descr=BasicFailDescr()),
                        ResOperation(rop.FINISH, [ConstInt(0)],
                                     descr=BasicFinalDescr()),
                        ]
                    ops[-2].setfailargs([i1])
                    inputargs = [i for i in (a, b) if not isinstance(i, Const)]
                    looptoken = JitCellToken()
                    self.cpu.compile_loop(inputargs, ops, looptoken)
                    inputvalues = [box.getint() for box in inputargs]
                    deadframe = self.cpu.execute_token(looptoken, *inputvalues)
                    result = self.cpu.get_int_value(deadframe, 0)
                    expected = execute(self.cpu, None, op, None, a, b)
                    if guard == rop.GUARD_FALSE:
                        assert result == expected
                    else:
                        assert result != expected

    def test_compile_bridge_check_profile_info(self):
        py.test.skip("does not work, reinvestigate")
        class FakeProfileAgent(object):
            def __init__(self):
                self.functions = []
            def native_code_written(self, name, address, size):
                self.functions.append((name, address, size))
        self.cpu.profile_agent = agent = FakeProfileAgent()

        i0 = InputArgInt()
        i1 = InputArgInt()
        i2 = InputArgInt()
        targettoken = TargetToken()
        faildescr1 = BasicFailDescr(1)
        faildescr2 = BasicFailDescr(2)
        looptoken = JitCellToken()
        looptoken.number = 17
        class FakeString(object):
            def __init__(self, val):
                self.val = val

            def _get_str(self):
                return self.val

        operations = [
            ResOperation(rop.LABEL, [i0], None, descr=targettoken),
            ResOperation(rop.DEBUG_MERGE_POINT, [FakeString("hello"), 0, 0], None),
            ResOperation(rop.INT_ADD, [i0, ConstInt(1)], i1),
            ResOperation(rop.INT_LE, [i1, ConstInt(9)], i2),
            ResOperation(rop.GUARD_TRUE, [i2], None, descr=faildescr1),
            ResOperation(rop.JUMP, [i1], None, descr=targettoken),
            ]
        inputargs = [i0]
        operations[-2].setfailargs([i1])
        self.cpu.compile_loop(inputargs, operations, looptoken)
        name, loopaddress, loopsize = agent.functions[0]
        assert name == "Loop # 17: hello (loop counter 0)"
        assert loopaddress <= looptoken._ll_loop_code
        assert loopsize >= 40 # randomish number

        i1b = InputArgInt()
        i3 = InputArgInt()
        bridge = [
            ResOperation(rop.INT_LE, [i1b, ConstInt(19)], i3),
            ResOperation(rop.GUARD_TRUE, [i3], None, descr=faildescr2),
            ResOperation(rop.DEBUG_MERGE_POINT, [FakeString("bye"), 0, 0], None),
            ResOperation(rop.JUMP, [i1b], None, descr=targettoken),
        ]
        bridge[1].setfailargs([i1b])

        self.cpu.compile_bridge(faildescr1, [i1b], bridge, looptoken)
        name, address, size = agent.functions[1]
        assert name == "Bridge # 0: bye (loop counter 1)"
        # Would be exactly ==, but there are some guard failure recovery
        # stubs in-between
        assert address >= loopaddress + loopsize
        assert size >= 10 # randomish number

        deadframe = self.cpu.execute_token(looptoken, 2)
        fail = self.cpu.get_latest_descr(deadframe)
        assert fail.identifier == 2
        res = self.cpu.get_int_value(deadframe, 0)
        assert res == 20

    def test_ops_offset(self):
        from rpython.rlib import debug
        looptoken = JitCellToken()
        targettoken = TargetToken()
        loop = parse("""
        [i0]
        label(i0, descr=targettoken)
        i1 = int_add(i0, 1)
        i2 = int_le(i1, 9)
        jump(i1, descr=targettoken)
        """, namespace=locals())
        debug._log = dlog = debug.DebugLog()
        info = self.cpu.compile_loop(loop.inputargs, loop.operations, looptoken)
        ops_offset = info.ops_offset
        debug._log = None
        #
        assert ops_offset is looptoken._x86_ops_offset
        # 2*increment_debug_counter + ops + None
        assert len(ops_offset) == 2 + len(loop.operations) + 1
        assert (ops_offset[loop.operations[0]] <=
                ops_offset[loop.operations[1]] <=
                ops_offset[loop.operations[2]] <=
                ops_offset[None])

    def test_calling_convention(self, monkeypatch):
        if WORD != 4:
            py.test.skip("32-bit only test")
        from rpython.jit.backend.x86.regloc import eax, edx
        from rpython.jit.backend.x86 import codebuf, callbuilder
        from rpython.jit.codewriter.effectinfo import EffectInfo
        from rpython.rlib.libffi import types, clibffi
        had_stdcall = hasattr(clibffi, 'FFI_STDCALL')
        if not had_stdcall:    # not running on Windows, but we can still test
            monkeypatch.setattr(clibffi, 'FFI_STDCALL', 12345, raising=False)
            monkeypatch.setattr(callbuilder, 'stdcall_or_cdecl', True)
        else:
            assert callbuilder.stdcall_or_cdecl
        #
        for real_ffi, reported_ffi in [
               (clibffi.FFI_DEFAULT_ABI, clibffi.FFI_DEFAULT_ABI),
               (clibffi.FFI_STDCALL, clibffi.FFI_DEFAULT_ABI),
               (clibffi.FFI_STDCALL, clibffi.FFI_STDCALL)]:
            cpu = self.cpu
            mc = codebuf.MachineCodeBlockWrapper()
            mc.MOV_rs(eax.value, 4)      # argument 1
            mc.MOV_rs(edx.value, 40)     # argument 10
            mc.SUB_rr(eax.value, edx.value)     # return arg1 - arg10
            if real_ffi == clibffi.FFI_DEFAULT_ABI:
                mc.RET()
            else:
                mc.RET16_i(40)
            rawstart = mc.materialize(cpu, [])
            #
            calldescr = cpu._calldescr_dynamic_for_tests([types.slong] * 10,
                                                         types.slong)
            calldescr.get_call_conv = lambda: reported_ffi      # <==== hack
            # ^^^ we patch get_call_conv() so that the test also makes sense
            #     on Linux, because clibffi.get_call_conv() would always
            #     return FFI_DEFAULT_ABI on non-Windows platforms.
            funcbox = ConstInt(rawstart)
            i1 = InputArgInt()
            i2 = InputArgInt()
            c = ConstInt(-1)
            faildescr = BasicFailDescr(1)
            cz = ConstInt(0)
            # we must call it repeatedly: if the stack pointer gets increased
            # by 40 bytes by the STDCALL call, and if we don't expect it,
            # then we are going to get our stack emptied unexpectedly by
            # several repeated calls
            ops = [
            ResOperation(rop.CALL_RELEASE_GIL_I,
                         [cz, funcbox, i1, c, c, c, c, c, c, c, c, i2],
                         descr=calldescr),
            ResOperation(rop.GUARD_NOT_FORCED, [], descr=faildescr),

            ResOperation(rop.CALL_RELEASE_GIL_I,
                         [cz, funcbox, i1, c, c, c, c, c, c, c, c, i2],
                         descr=calldescr),
            ResOperation(rop.GUARD_NOT_FORCED, [], descr=faildescr),

            ResOperation(rop.CALL_RELEASE_GIL_I,
                         [cz, funcbox, i1, c, c, c, c, c, c, c, c, i2],
                         descr=calldescr),
            ResOperation(rop.GUARD_NOT_FORCED, [], descr=faildescr),

            ResOperation(rop.CALL_RELEASE_GIL_I,
                         [cz, funcbox, i1, c, c, c, c, c, c, c, c, i2],
                         descr=calldescr),
            ResOperation(rop.GUARD_NOT_FORCED, [], descr=faildescr),
            ]
            i3 = ops[0]
            i4 = ops[2]
            i5 = ops[4]
            i6 = ops[6]

            ops += [
            ResOperation(rop.GUARD_FALSE, [i3],
                         descr=BasicFailDescr(0)),
            ResOperation(rop.FINISH, [],
                         descr=BasicFinalDescr(1))
            ]
            ops[-2].setfailargs([i3, i4, i5, i6])
            ops[1].setfailargs([])
            ops[3].setfailargs([])
            ops[5].setfailargs([])
            ops[7].setfailargs([])
            looptoken = JitCellToken()
            self.cpu.compile_loop([i1, i2], ops, looptoken)

            deadframe = self.cpu.execute_token(looptoken, 123450, 123408)
            fail = self.cpu.get_latest_descr(deadframe)
            assert fail.identifier == 0
            assert self.cpu.get_int_value(deadframe, 0) == 42
            assert self.cpu.get_int_value(deadframe, 1) == 42
            assert self.cpu.get_int_value(deadframe, 2) == 42
            assert self.cpu.get_int_value(deadframe, 3) == 42


class TestDebuggingAssembler(object):
    def setup_method(self, meth):
        self.cpu = CPU(rtyper=None, stats=FakeStats())
        self.cpu.setup_once()

    def test_debugger_on(self):
        from rpython.tool.logparser import parse_log_file, extract_category
        from rpython.rlib import debug

        targettoken, preambletoken = TargetToken(), TargetToken()
        loop = """
        [i0]
        label(i0, descr=preambletoken)
        debug_merge_point('xyz', 0, 0)
        i1 = int_add(i0, 1)
        i2 = int_ge(i1, 10)
        guard_false(i2) []
        label(i1, descr=targettoken)
        debug_merge_point('xyz', 0, 0)
        i11 = int_add(i1, 1)
        i12 = int_ge(i11, 10)
        guard_false(i12) []
        jump(i11, descr=targettoken)
        """
        ops = parse(loop, namespace={'targettoken': targettoken,
                                     'preambletoken': preambletoken})
        debug._log = dlog = debug.DebugLog()
        try:
            self.cpu.assembler.set_debug(True)
            looptoken = JitCellToken()
            self.cpu.compile_loop(ops.inputargs, ops.operations, looptoken)
            self.cpu.execute_token(looptoken, 0)
            # check debugging info
            struct = self.cpu.assembler.get_loop_run_counters(0)
            assert struct.i == 1
            struct = self.cpu.assembler.get_loop_run_counters(1)
            assert struct.i == 1
            struct = self.cpu.assembler.get_loop_run_counters(2)
            assert struct.i == 9
            self.cpu.finish_once()
        finally:
            debug._log = None
        l0 = ('debug_print', 'entry -1:1')
        l1 = ('debug_print', preambletoken.repr_of_descr() + ':1')
        l2 = ('debug_print', targettoken.repr_of_descr() + ':9')
        assert ('jit-backend-counts', [l0, l1, l2]) in dlog
