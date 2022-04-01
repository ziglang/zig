import sys
from rpython.rtyper.lltypesystem import lltype, llmemory, rstr
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.annlowlevel import llhelper
from rpython.jit.backend.llsupport import jitframe, gc, descr
from rpython.jit.backend.llsupport import symbolic
from rpython.jit.metainterp.gc import get_description
from rpython.jit.metainterp.history import ConstPtr
from rpython.jit.metainterp.resoperation import get_deep_immutable_oplist, rop,\
     ResOperation, InputArgRef
from rpython.rlib.rarithmetic import is_valid_int, r_uint

def test_boehm():
    gc_ll_descr = gc.GcLLDescr_boehm(None, None, None)
    #
    record = []
    prev_malloc_fn_ptr = gc_ll_descr.malloc_fn_ptr
    def my_malloc_fn_ptr(size):
        p = prev_malloc_fn_ptr(size)
        record.append((size, p))
        return p
    gc_ll_descr.malloc_fn_ptr = my_malloc_fn_ptr
    #
    # ---------- gc_malloc ----------
    S = lltype.GcStruct('S', ('x', lltype.Signed))
    sizedescr = descr.get_size_descr(gc_ll_descr, S)
    p = gc_ll_descr.gc_malloc(sizedescr)
    assert record == [(sizedescr.size, p)]
    del record[:]
    # ---------- gc_malloc_array ----------
    A = lltype.GcArray(lltype.Signed)
    arraydescr = descr.get_array_descr(gc_ll_descr, A)
    p = gc_ll_descr.gc_malloc_array(10, arraydescr)
    assert record == [(arraydescr.basesize +
                       10 * arraydescr.itemsize, p)]
    del record[:]
    # ---------- gc_malloc_str ----------
    p = gc_ll_descr.gc_malloc_str(10)
    basesize, itemsize, ofs_length = symbolic.get_array_token(rstr.STR, False)
    assert record == [(basesize + 10 * itemsize, p)]
    del record[:]
    # ---------- gc_malloc_unicode ----------
    p = gc_ll_descr.gc_malloc_unicode(10)
    basesize, itemsize, ofs_length = symbolic.get_array_token(rstr.UNICODE,
                                                              False)
    assert record == [(basesize + 10 * itemsize, p)]
    del record[:]

# ____________________________________________________________


class FakeLLOp(object):
    def __init__(self):
        self.record = []

    def _malloc(self, type_id, size):
        tid = llop.combine_ushort(lltype.Signed, type_id, 0)
        x = llmemory.raw_malloc(self.gcheaderbuilder.size_gc_header + size)
        x += self.gcheaderbuilder.size_gc_header
        return x, tid

    def do_malloc_fixedsize(self, RESTYPE, type_id, size,
                                  has_finalizer, has_light_finalizer,
                                  contains_weakptr):
        assert not contains_weakptr
        assert not has_finalizer
        assert not has_light_finalizer
        p, tid = self._malloc(type_id, size)
        p = llmemory.cast_adr_to_ptr(p, RESTYPE)
        self.record.append(("fixedsize", repr(size), tid, p))
        return p

    do_malloc_fixedsize_clear = do_malloc_fixedsize

    def do_malloc_varsize(self, RESTYPE, type_id, length, size,
                                itemsize, offset_to_length):
        p, tid = self._malloc(type_id, size + itemsize * length)
        (p + offset_to_length).signed[0] = length
        p = llmemory.cast_adr_to_ptr(p, RESTYPE)
        self.record.append(("varsize", tid, length,
                            repr(size), repr(itemsize),
                            repr(offset_to_length), p))
        return p

    do_malloc_varsize_clear = do_malloc_varsize

    def _write_barrier_failing_case(self, adr_struct):
        self.record.append(('barrier', adr_struct))

    def get_write_barrier_failing_case(self, FPTRTYPE):
        return llhelper(FPTRTYPE, self._write_barrier_failing_case)

    _have_wb_from_array = False

    def _write_barrier_from_array_failing_case(self, adr_struct, v_index):
        self.record.append(('barrier_from_array', adr_struct, v_index))

    def get_write_barrier_from_array_failing_case(self, FPTRTYPE):
        if self._have_wb_from_array:
            return llhelper(FPTRTYPE,
                            self._write_barrier_from_array_failing_case)
        else:
            return lltype.nullptr(FPTRTYPE.TO)


class TestFramework(object):
    gc = 'minimark'

    def setup_method(self, meth):
        class config_(object):
            class translation(object):
                gc = self.gc
                gcrootfinder = 'shadowstack'
                gctransformer = 'framework'
                gcremovetypeptr = False
        class FakeTranslator(object):
            config = config_
        class FakeCPU(object):
            def cast_adr_to_int(self, adr):
                if not adr:
                    return 0
                try:
                    ptr = llmemory.cast_adr_to_ptr(adr, gc_ll_descr.WB_FUNCPTR)
                    assert ptr._obj._callable == \
                           llop1._write_barrier_failing_case
                    return 42
                except lltype.InvalidCast:
                    ptr = llmemory.cast_adr_to_ptr(
                        adr, gc_ll_descr.WB_ARRAY_FUNCPTR)
                    assert ptr._obj._callable == \
                           llop1._write_barrier_from_array_failing_case
                    return 43

        gcdescr = get_description(config_)
        llop1 = FakeLLOp()
        gc_ll_descr = gc.GcLLDescr_framework(gcdescr, FakeTranslator(), None,
                                             llop1)
        gc_ll_descr.initialize()
        llop1.gcheaderbuilder = gc_ll_descr.gcheaderbuilder
        self.llop1 = llop1
        self.gc_ll_descr = gc_ll_descr
        self.fake_cpu = FakeCPU()

    def test_gc_malloc(self):
        S = lltype.GcStruct('S', ('x', lltype.Signed))
        sizedescr = descr.get_size_descr(self.gc_ll_descr, S)
        p = self.gc_ll_descr.gc_malloc(sizedescr)
        assert lltype.typeOf(p) == llmemory.GCREF
        assert self.llop1.record == [("fixedsize", repr(sizedescr.size),
                                      sizedescr.tid, p)]

    def test_gc_malloc_array(self):
        A = lltype.GcArray(lltype.Signed)
        arraydescr = descr.get_array_descr(self.gc_ll_descr, A)
        p = self.gc_ll_descr.gc_malloc_array(10, arraydescr)
        assert self.llop1.record == [("varsize", arraydescr.tid, 10,
                                      repr(arraydescr.basesize),
                                      repr(arraydescr.itemsize),
                                      repr(arraydescr.lendescr.offset),
                                      p)]

    def test_gc_malloc_str(self):
        p = self.gc_ll_descr.gc_malloc_str(10)
        type_id = self.gc_ll_descr.layoutbuilder.get_type_id(rstr.STR)
        tid = llop.combine_ushort(lltype.Signed, type_id, 0)
        basesize, itemsize, ofs_length = symbolic.get_array_token(rstr.STR,
                                                                  True)
        assert self.llop1.record == [("varsize", tid, 10,
                                      repr(basesize), repr(itemsize),
                                      repr(ofs_length), p)]

    def test_gc_malloc_unicode(self):
        p = self.gc_ll_descr.gc_malloc_unicode(10)
        type_id = self.gc_ll_descr.layoutbuilder.get_type_id(rstr.UNICODE)
        tid = llop.combine_ushort(lltype.Signed, type_id, 0)
        basesize, itemsize, ofs_length = symbolic.get_array_token(rstr.UNICODE,
                                                                  True)
        assert self.llop1.record == [("varsize", tid, 10,
                                      repr(basesize), repr(itemsize),
                                      repr(ofs_length), p)]

    def test_gen_write_barrier(self):
        gc_ll_descr = self.gc_ll_descr
        llop1 = self.llop1
        #
        rewriter = gc.GcRewriterAssembler(gc_ll_descr, None)
        newops = rewriter._newops
        v_base = InputArgRef()
        rewriter.gen_write_barrier(v_base)
        assert llop1.record == []
        assert len(newops) == 1
        assert newops[0].getopnum() == rop.COND_CALL_GC_WB
        assert newops[0].getarg(0) == v_base
        wbdescr = newops[0].getdescr()
        assert is_valid_int(wbdescr.jit_wb_if_flag)
        assert is_valid_int(wbdescr.jit_wb_if_flag_byteofs)
        assert is_valid_int(wbdescr.jit_wb_if_flag_singlebyte)


class TestFrameworkMiniMark(TestFramework):
    gc = 'minimark'

def test_custom_tracer():
    def indexof(no):
        return (frame_adr + jitframe.getofs('jf_frame') +
                jitframe.BASEITEMOFS + jitframe.SIGN_SIZE * no)
    
    frame_info = lltype.malloc(jitframe.JITFRAMEINFO, zero=True, flavor='raw')
    frame = lltype.malloc(jitframe.JITFRAME, 200, zero=True)
    frame.jf_frame_info = frame_info
    frame.jf_gcmap = lltype.malloc(jitframe.GCMAP, 4, flavor='raw')
    if sys.maxint == 2**31 - 1:
        max = r_uint(2 ** 31)
    else:
        max = r_uint(2 ** 63)
    frame.jf_gcmap[0] = r_uint(1 | 2 | 8 | 32 | 128) | max
    frame.jf_gcmap[1] = r_uint(0)
    frame.jf_gcmap[2] = r_uint(2 | 16 | 32 | 128)
    frame.jf_gcmap[3] = r_uint(0)
    frame_adr = llmemory.cast_ptr_to_adr(frame)
    #
    all_addrs = []
    class FakeGC:
        def _trace_callback(self, callback, arg, addr):
            assert callback == "hello"
            assert arg == "world"
            all_addrs.append(addr)
    jitframe.jitframe_trace(FakeGC(), frame_adr, "hello", "world")
    #
    counter = 0
    for name in jitframe.JITFRAME._names:
        TP = getattr(jitframe.JITFRAME, name)
        if isinstance(TP, lltype.Ptr) and TP.TO._gckind == 'gc': 
            assert all_addrs[counter] == frame_adr + jitframe.getofs(name)
            counter += 1
    assert counter == 5
    # gcpattern
    assert all_addrs[5] == indexof(0)
    assert all_addrs[6] == indexof(1)
    assert all_addrs[7] == indexof(3)
    assert all_addrs[8] == indexof(5)
    assert all_addrs[9] == indexof(7)
    if sys.maxint == 2**31 - 1:
        assert all_addrs[10] == indexof(31)
        assert all_addrs[11] == indexof(65)
        assert all_addrs[12] == indexof(68)
        assert all_addrs[13] == indexof(69)
        assert all_addrs[14] == indexof(71)
    else:
        assert all_addrs[10] == indexof(63)
        assert all_addrs[11] == indexof(129)
        assert all_addrs[12] == indexof(132)
        assert all_addrs[13] == indexof(133)
        assert all_addrs[14] == indexof(135)

    assert len(all_addrs) == 15
    lltype.free(frame_info, flavor='raw')
    lltype.free(frame.jf_gcmap, flavor='raw')

def test_custom_tracer_2():    
    frame_info = lltype.malloc(jitframe.JITFRAMEINFO, zero=True, flavor='raw')
    frame = lltype.malloc(jitframe.JITFRAME, 200, zero=True)
    frame.jf_frame_info = frame_info
    frame.jf_gcmap = lltype.malloc(jitframe.GCMAP, 3, flavor='raw')
    frame.jf_gcmap[0] = r_uint(18446744073441116160)
    frame.jf_gcmap[1] = r_uint(18446740775107559407)
    frame.jf_gcmap[2] = r_uint(3)
    frame_adr = llmemory.cast_ptr_to_adr(frame)
    class FakeGC:
        def _trace_callback(self, callback, arg, addr):
            assert callback == "hello"
            assert arg == "world"
    jitframe.jitframe_trace(FakeGC(), frame_adr, "hello", "world")
    # assert did not hang

    lltype.free(frame_info, flavor='raw')
    lltype.free(frame.jf_gcmap, flavor='raw')
