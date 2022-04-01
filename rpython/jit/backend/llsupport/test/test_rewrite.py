import py
from rpython.jit.backend.llsupport.descr import get_size_descr,\
     get_field_descr, get_array_descr, ArrayDescr, FieldDescr,\
     SizeDescr, get_interiorfield_descr
from rpython.jit.backend.llsupport.gc import GcLLDescr_boehm,\
     GcLLDescr_framework
from rpython.jit.backend.llsupport import jitframe
from rpython.jit.metainterp.gc import get_description
from rpython.jit.tool.oparser import parse
from rpython.jit.metainterp.optimizeopt.util import equaloplists
from rpython.jit.metainterp.history import JitCellToken, FLOAT
from rpython.jit.metainterp.history import AbstractFailDescr
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper import rclass
from rpython.jit.backend.llsupport.symbolic import (WORD,
        get_array_token)

class Evaluator(object):
    def __init__(self, scope):
        self.scope = scope
    def __getitem__(self, key):
        return eval(key, self.scope)


class FakeLoopToken(object):
    pass

o_vtable = lltype.malloc(rclass.OBJECT_VTABLE, immortal=True)

class RewriteTests(object):
    def check_rewrite(self, frm_operations, to_operations, **namespace):
        def setfield(baseptr, newvalue, descr):
            assert isinstance(baseptr, str)
            assert isinstance(newvalue, (str, int))
            assert not isinstance(descr, (str, int))
            return 'gc_store(%s, %d, %s, %d)' % (baseptr, descr.offset,
                                                 newvalue, descr.field_size)
        def zero_array(baseptr, start, length, descr_name, descr):
            assert isinstance(baseptr, str)
            assert isinstance(start, (str, int))
            assert isinstance(length, (str, int))
            assert isinstance(descr_name, str)
            assert not isinstance(descr, (str,int))
            itemsize = descr.itemsize
            start = start * itemsize
            length_scale = 1
            if isinstance(length, str):
                length_scale = itemsize
            else:
                length = length * itemsize
            return 'zero_array(%s, %s, %s, 1, %d, descr=%s)' % \
                      (baseptr, start, length, length_scale, descr_name)
        def setarrayitem(baseptr, index, newvalue, descr):
            assert isinstance(baseptr, str)
            assert isinstance(index, (str, int))
            assert isinstance(newvalue, (str, int))
            assert not isinstance(descr, (str, int))
            if isinstance(index, int):
                offset = descr.basesize + index * descr.itemsize
                return 'gc_store(%s, %d, %s, %d)' % (baseptr, offset,
                                                     newvalue, descr.itemsize)
            else:
                return 'gc_store_indexed(%s, %s, %s, %d, %d, %s)' % (
                    baseptr, index, newvalue,
                    descr.itemsize, descr.basesize, descr.itemsize)
        #
        WORD = globals()['WORD']
        S = lltype.GcStruct('S', ('x', lltype.Signed),
                                 ('y', lltype.Signed))
        sdescr = get_size_descr(self.gc_ll_descr, S)
        sdescr.tid = 1234
        #
        T = lltype.GcStruct('T', ('y', lltype.Signed),
                                 ('z', lltype.Ptr(S)),
                                 ('t', lltype.Signed))
        tdescr = get_size_descr(self.gc_ll_descr, T)
        tdescr.tid = 5678
        tzdescr = get_field_descr(self.gc_ll_descr, T, 'z')
        myT = lltype.cast_opaque_ptr(llmemory.GCREF,
                                     lltype.malloc(T, zero=True))
        self.myT = myT
        #
        A = lltype.GcArray(lltype.Signed)
        adescr = get_array_descr(self.gc_ll_descr, A)
        adescr.tid = 4321
        alendescr = adescr.lendescr
        #
        B = lltype.GcArray(lltype.Char)
        bdescr = get_array_descr(self.gc_ll_descr, B)
        bdescr.tid = 8765
        blendescr = bdescr.lendescr
        #
        C = lltype.GcArray(lltype.Ptr(S))
        cdescr = get_array_descr(self.gc_ll_descr, C)
        cdescr.tid = 8111
        clendescr = cdescr.lendescr
        #
        S1 = lltype.GcStruct('S1')
        S1I = lltype.GcArray(('x', lltype.Ptr(S1)),
                             ('y', lltype.Ptr(S1)),
                             ('z', lltype.Ptr(S1)))
        itzdescr = get_interiorfield_descr(self.gc_ll_descr, S1I, 'z')
        itydescr = get_interiorfield_descr(self.gc_ll_descr, S1I, 'y')
        itxdescr = get_interiorfield_descr(self.gc_ll_descr, S1I, 'x')
        S2I = lltype.GcArray(('x', lltype.Ptr(S1)),
                             ('y', lltype.Ptr(S1)),
                             ('z', lltype.Ptr(S1)),
                             ('t', lltype.Ptr(S1)))   # size is a power of two
        s2i_item_size_in_bits = (4 if WORD == 4 else 5)
        ity2descr = get_interiorfield_descr(self.gc_ll_descr, S2I, 'y')
        R1 = lltype.GcStruct('R', ('x', lltype.Signed),
                                  ('y', lltype.Float),
                                  ('z', lltype.Ptr(S1)))
        xdescr = get_field_descr(self.gc_ll_descr, R1, 'x')
        ydescr = get_field_descr(self.gc_ll_descr, R1, 'y')
        zdescr = get_field_descr(self.gc_ll_descr, R1, 'z')
        myR1 = lltype.cast_opaque_ptr(llmemory.GCREF,
                                      lltype.malloc(R1, zero=True))
        myR1b = lltype.cast_opaque_ptr(llmemory.GCREF,
                                       lltype.malloc(R1, zero=True))
        self.myR1 = myR1
        self.myR1b = myR1b
        #
        E = lltype.GcStruct('Empty')
        edescr = get_size_descr(self.gc_ll_descr, E)
        edescr.tid = 9000
        #
        vtable_descr = self.gc_ll_descr.fielddescr_vtable
        O = lltype.GcStruct('O', ('parent', rclass.OBJECT),
                                 ('x', lltype.Signed))
        o_descr = self.cpu.sizeof(O, True)
        o_vtable = globals()['o_vtable']
        #
        tiddescr = self.gc_ll_descr.fielddescr_tid
        wbdescr = self.gc_ll_descr.write_barrier_descr
        #
        F = lltype.GcArray(lltype.Float)
        fdescr = get_array_descr(self.gc_ll_descr, F)
        SF = lltype.GcArray(lltype.SingleFloat)
        sfdescr = get_array_descr(self.gc_ll_descr, SF)
        RAW_SF = lltype.Array(lltype.SingleFloat)
        raw_sfdescr = get_array_descr(self.gc_ll_descr, RAW_SF)
        #
        strdescr     = self.gc_ll_descr.str_descr
        str_basesize = self.gc_ll_descr.str_descr.basesize - 1
        unicodedescr = self.gc_ll_descr.unicode_descr
        strlendescr     = strdescr.lendescr
        unicodelendescr = unicodedescr.lendescr
        strhashdescr     = self.gc_ll_descr.str_hash_descr
        unicodehashdescr = self.gc_ll_descr.unicode_hash_descr
        uni_basesize  = unicodedescr.basesize
        uni_itemscale = {2: 1, 4: 2}[unicodedescr.itemsize]
        memcpy_fn = self.gc_ll_descr.memcpy_fn
        memcpy_descr = self.gc_ll_descr.memcpy_descr

        casmdescr = JitCellToken()
        clt = FakeLoopToken()
        clt._ll_initial_locs = [0, 8]
        frame_info = lltype.malloc(jitframe.JITFRAMEINFO, flavor='raw')
        clt.frame_info = frame_info
        frame_info.jfi_frame_depth = 13
        frame_info.jfi_frame_size = 255
        framedescrs = self.gc_ll_descr.getframedescrs(self.cpu)
        framelendescr = framedescrs.arraydescr.lendescr
        jfi_frame_depth = framedescrs.jfi_frame_depth
        jfi_frame_size = framedescrs.jfi_frame_size
        jf_frame_info = framedescrs.jf_frame_info
        jf_savedata = framedescrs.jf_savedata
        jf_force_descr = framedescrs.jf_force_descr
        jf_descr = framedescrs.jf_descr
        jf_guard_exc = framedescrs.jf_guard_exc
        jf_forward = framedescrs.jf_forward
        signedframedescr = self.cpu.signedframedescr
        floatframedescr = self.cpu.floatframedescr
        casmdescr.compiled_loop_token = clt

        #
        guarddescr = AbstractFailDescr()
        #
        namespace.update(locals())
        #
        for funcname in self.gc_ll_descr._generated_functions:
            namespace[funcname] = self.gc_ll_descr.get_malloc_fn(funcname)
            namespace[funcname + '_descr'] = getattr(self.gc_ll_descr,
                                                     '%s_descr' % funcname)
        #
        ops = parse(frm_operations, namespace=namespace)
        expected = parse(to_operations % Evaluator(namespace),
                         namespace=namespace)
        self.gcrefs = []
        operations = self.gc_ll_descr.rewrite_assembler(self.cpu,
                                                        ops.operations,
                                                        self.gcrefs)
        remap = {}
        for a, b in zip(ops.inputargs, expected.inputargs):
            remap[b] = a
        equaloplists(operations, expected.operations, remap=remap)
        lltype.free(frame_info, flavor='raw')

class FakeTracker(object):
    pass

class BaseFakeCPU(object):
    JITFRAME_FIXED_SIZE = 0

    load_constant_offset = True
    load_supported_factors = (1,2,4,8)
    supports_load_effective_address = True

    translate_support_code = None

    def __init__(self):
        self.tracker = FakeTracker()
        self._cache = {}
        self.signedframedescr = ArrayDescr(3, 8, FieldDescr('len', 0, 0, 0), 0)
        self.floatframedescr = ArrayDescr(5, 8, FieldDescr('len', 0, 0, 0), 0)

    def getarraydescr_for_frame(self, tp):
        if tp == FLOAT:
            return self.floatframedescr
        return self.signedframedescr

    def unpack_arraydescr_size(self, d):
        return 0, d.itemsize, 0

    def unpack_fielddescr(self, d):
        return d.offset

    def arraydescrof(self, ARRAY):
        try:
            return self._cache[ARRAY]
        except KeyError:
            r = ArrayDescr(1, 2, FieldDescr('len', 0, 0, 0), 0)
            self._cache[ARRAY] = r
            return r

    def fielddescrof(self, STRUCT, fname):
        key = (STRUCT, fname)
        try:
            return self._cache[key]
        except KeyError:
            r = FieldDescr(fname, 1, 1, 1)
            self._cache[key] = r
            return r

    def cast_adr_to_int(self, adr):
        return llmemory.AddressAsInt(adr)

class TestBoehm(RewriteTests):
    def setup_method(self, meth):
        class FakeCPU(BaseFakeCPU):
            def sizeof(self, STRUCT, is_object):
                assert is_object
                return SizeDescr(102, gc_fielddescrs=[],
                                 vtable=o_vtable)
        self.cpu = FakeCPU()
        self.gc_ll_descr = GcLLDescr_boehm(None, None, None)

    def test_new(self):
        self.check_rewrite("""
            []
            p0 = new(descr=sdescr)
            jump()
        """, """
            [p1]
            p0 = call_r(ConstClass(malloc_fixedsize), %(sdescr.size)d,\
                        descr=malloc_fixedsize_descr)
            check_memory_error(p0)
            jump()
        """)

    def test_no_collapsing(self):
        self.check_rewrite("""
            []
            p0 = new(descr=sdescr)
            p1 = new(descr=sdescr)
            jump()
        """, """
            []
            p0 = call_r(ConstClass(malloc_fixedsize), %(sdescr.size)d,\
                        descr=malloc_fixedsize_descr)
            check_memory_error(p0)
            p1 = call_r(ConstClass(malloc_fixedsize), %(sdescr.size)d,\
                        descr=malloc_fixedsize_descr)
            check_memory_error(p1)
            jump()
        """)

    def test_new_array_fixed(self):
        self.check_rewrite("""
            []
            p0 = new_array(10, descr=adescr)
            jump()
        """, """
            []
            p0 = call_r(ConstClass(malloc_array),           \
                                %(adescr.basesize)d,        \
                                10,                         \
                                %(adescr.itemsize)d,        \
                                %(adescr.lendescr.offset)d, \
                                descr=malloc_array_descr)
            check_memory_error(p0)
            jump()
        """)
##      should ideally be:
##            p0 = call_r(ConstClass(malloc_fixedsize), \
##                                %(adescr.basesize + 10 * adescr.itemsize)d, \
##                                descr=malloc_fixedsize_descr)
##            setfield_gc(p0, 10, descr=alendescr)

    def test_new_array_variable(self):
        self.check_rewrite("""
            [i1]
            p0 = new_array(i1, descr=adescr)
            jump()
        """, """
            [i1]
            p0 = call_r(ConstClass(malloc_array),   \
                                %(adescr.basesize)d,        \
                                i1,                         \
                                %(adescr.itemsize)d,        \
                                %(adescr.lendescr.offset)d, \
                                descr=malloc_array_descr)
            check_memory_error(p0)
            jump()
        """)

    def test_new_with_vtable(self):
        self.check_rewrite("""
            []
            p0 = new_with_vtable(descr=o_descr)
            jump()
        """, """
            [p1]
            p0 = call_r(ConstClass(malloc_fixedsize), 102, \
                                descr=malloc_fixedsize_descr)
            check_memory_error(p0)
            gc_store(p0, 0, ConstClass(o_vtable), %(vtable_descr.field_size)s)
            jump()
        """)

    def test_newstr(self):
        self.check_rewrite("""
            [i1]
            p0 = newstr(i1)
            jump()
        """, """
            [i1]
            p0 = call_r(ConstClass(malloc_array),         \
                                %(strdescr.basesize)d,    \
                                i1,                       \
                                %(strdescr.itemsize)d,    \
                                %(strlendescr.offset)d,   \
                                descr=malloc_array_descr)
            check_memory_error(p0)
            jump()
        """)

    def test_newunicode(self):
        self.check_rewrite("""
            [i1]
            p0 = newunicode(10)
            jump()
        """, """
            [i1]
            p0 = call_r(ConstClass(malloc_array),           \
                                %(unicodedescr.basesize)d,  \
                                10,                         \
                                %(unicodedescr.itemsize)d,  \
                                %(unicodelendescr.offset)d, \
                                descr=malloc_array_descr)
            check_memory_error(p0)
            jump()
        """)
##      should ideally be:
##            p0 = call_r(ConstClass(malloc_fixedsize),           \
##                                %(unicodedescr.basesize +       \
##                                  10 * unicodedescr.itemsize)d, \
##                                descr=malloc_fixedsize_descr)
##            setfield_gc(p0, 10, descr=unicodelendescr)


class TestFramework(RewriteTests):
    def setup_method(self, meth):
        class config_(object):
            class translation(object):
                gc = 'minimark'
                gcrootfinder = 'shadowstack'
                gctransformer = 'framework'
                gcremovetypeptr = False
        gcdescr = get_description(config_)
        self.gc_ll_descr = GcLLDescr_framework(gcdescr, None, None, None,
                                               really_not_translated=True)
        self.gc_ll_descr.write_barrier_descr.has_write_barrier_from_array = (
            lambda cpu: True)
        self.gc_ll_descr.malloc_zero_filled = False
        #
        class FakeCPU(BaseFakeCPU):
            def sizeof(self, STRUCT, is_object):
                descr = SizeDescr(104, gc_fielddescrs=[])
                descr.tid = 9315
                return descr
        self.cpu = FakeCPU()

    def test_rewrite_assembler_new_to_malloc(self):
        self.check_rewrite("""
            [p1]
            p0 = new(descr=sdescr)
            jump()
        """, """
            [p1]
            p0 = call_malloc_nursery(%(sdescr.size)d)
            gc_store(p0, 0, 1234, 8)
            jump()
        """)

    def test_rewrite_assembler_new3_to_malloc(self):
        self.check_rewrite("""
            []
            p0 = new(descr=sdescr)
            p1 = new(descr=tdescr)
            p2 = new(descr=sdescr)
            jump()
        """, """
            []
            p0 = call_malloc_nursery(   \
                               %(sdescr.size + tdescr.size + sdescr.size)d)
            gc_store(p0, 0, 1234, 8)
            p1 = nursery_ptr_increment(p0, %(sdescr.size)d)
            gc_store(p1, 0, 5678, 8)
            p2 = nursery_ptr_increment(p1, %(tdescr.size)d)
            gc_store(p2, 0, 1234, 8)
            %(setfield('p1', 0, tdescr.gc_fielddescrs[0]))s
            jump()
        """)

    def test_rewrite_assembler_new_array_fixed_to_malloc(self):
        self.check_rewrite("""
            []
            p0 = new_array(10, descr=adescr)
            jump()
        """, """
            []
            p0 = call_malloc_nursery(    \
                                %(adescr.basesize + 10 * adescr.itemsize)d)
            gc_store(p0, 0, 4321, %(tiddescr.field_size)s)
            gc_store(p0, 0, 10, %(alendescr.field_size)s)
            jump()
        """)

    def test_rewrite_assembler_new_and_new_array_fixed_to_malloc(self):
        self.check_rewrite("""
            []
            p0 = new(descr=sdescr)
            p1 = new_array(10, descr=adescr)
            jump()
        """, """
            []
            p0 = call_malloc_nursery(                                  \
                                %(sdescr.size +                        \
                                  adescr.basesize + 10 * adescr.itemsize)d)
            gc_store(p0, 0, 1234, %(tiddescr.field_size)s)
            p1 = nursery_ptr_increment(p0, %(sdescr.size)d)
            gc_store(p1, 0, 4321, %(tiddescr.field_size)s)
            gc_store(p1, 0, 10, %(alendescr.field_size)s)
            jump()
        """)

    def test_rewrite_assembler_round_up(self):
        self.check_rewrite("""
            []
            p0 = new_array(6, descr=bdescr)
            jump()
        """, """
            []
            p0 = call_malloc_nursery(%(bdescr.basesize + 8)d)
            gc_store(p0, 0, 8765, %(tiddescr.field_size)s)
            gc_store(p0, 0, 6, %(blendescr.field_size)s)
            jump()
        """)

    def test_rewrite_assembler_round_up_always(self):
        self.check_rewrite("""
            []
            p0 = new_array(5, descr=bdescr)
            p1 = new_array(5, descr=bdescr)
            p2 = new_array(5, descr=bdescr)
            p3 = new_array(5, descr=bdescr)
            jump()
        """, """
            []
            p0 = call_malloc_nursery(%(4 * (bdescr.basesize + 8))d)
            gc_store(p0, 0, 8765, %(tiddescr.field_size)s)
            gc_store(p0, 0, 5, %(blendescr.field_size)s)
            p1 = nursery_ptr_increment(p0, %(bdescr.basesize + 8)d)
            gc_store(p1, 0, 8765, %(tiddescr.field_size)s)
            gc_store(p1, 0, 5, %(blendescr.field_size)s)
            p2 = nursery_ptr_increment(p1, %(bdescr.basesize + 8)d)
            gc_store(p2, 0, 8765, %(tiddescr.field_size)s)
            gc_store(p2, 0, 5, %(blendescr.field_size)s)
            p3 = nursery_ptr_increment(p2, %(bdescr.basesize + 8)d)
            gc_store(p3, 0, 8765, %(tiddescr.field_size)s)
            gc_store(p3, 0, 5, %(blendescr.field_size)s)
            jump()
        """)

    def test_rewrite_assembler_minimal_size(self):
        self.check_rewrite("""
            []
            p0 = new(descr=edescr)
            p1 = new(descr=edescr)
            jump()
        """, """
            []
            p0 = call_malloc_nursery(%(4*WORD)d)
            gc_store(p0, 0,  9000, %(tiddescr.field_size)s)
            p1 = nursery_ptr_increment(p0, %(2*WORD)d)
            gc_store(p1, 0,  9000, %(tiddescr.field_size)s)
            jump()
        """)

    def test_rewrite_assembler_variable_size(self):
        self.check_rewrite("""
            [i0]
            p0 = new_array(i0, descr=bdescr)
            jump(i0)
        """, """
            [i0]
            p0 = call_malloc_nursery_varsize(0, 1, i0, descr=bdescr)
            gc_store(p0, 0, i0, %(bdescr.basesize)s)
            jump(i0)
        """)

    def test_rewrite_new_string(self):
        self.check_rewrite("""
        [i0]
        p0 = newstr(i0)
        jump(i0)
        """, """
        [i0]
        p0 = call_malloc_nursery_varsize(1, 1, i0, descr=strdescr)
        gc_store(p0, %(strlendescr.offset)s, i0, %(strlendescr.field_size)s)
        gc_store(p0, 0, 0, %(strlendescr.field_size)s)
        jump(i0)
        """)

    def test_rewrite_assembler_nonstandard_array(self):
        # a non-standard array is a bit hard to get; e.g. GcArray(Float)
        # is like that on Win32, but not on Linux.  Build one manually...
        NONSTD = lltype.GcArray(lltype.Float)
        nonstd_descr = get_array_descr(self.gc_ll_descr, NONSTD)
        nonstd_descr.tid = 6464
        nonstd_descr.basesize = 64      # <= hacked
        nonstd_descr.itemsize = 8
        nonstd_descr_gcref = 123
        # REVIEW: added descr=nonstd_descr to setarrayitem
        # is it even valid to have a setarrayitem WITHOUT a descr?
        self.check_rewrite("""
            [i0, p1]
            p0 = new_array(i0, descr=nonstd_descr)
            setarrayitem_gc(p0, i0, p1, descr=nonstd_descr)
            jump(i0)
        """, """
            [i0, p1]
            p0 = call_r(ConstClass(malloc_array_nonstandard),         \
                                64, 8,                                \
                                %(nonstd_descr.lendescr.offset)d,     \
                                6464, i0,                             \
                                descr=malloc_array_nonstandard_descr)
            check_memory_error(p0)
            cond_call_gc_wb_array(p0, i0, descr=wbdescr)
            gc_store_indexed(p0, i0, p1, 8, 64, 8)
            jump(i0)
        """, nonstd_descr=nonstd_descr)

    def test_rewrite_assembler_maximal_size_1(self):
        self.gc_ll_descr.max_size_of_young_obj = 100
        self.check_rewrite("""
            []
            p0 = new_array(103, descr=bdescr)
            jump()
        """, """
            []
            p0 = call_r(ConstClass(malloc_array), 1,          \
                                %(bdescr.tid)d, 103,          \
                                descr=malloc_array_descr)
            check_memory_error(p0)
            jump()
        """)

    def test_rewrite_assembler_maximal_size_2(self):
        self.gc_ll_descr.max_size_of_young_obj = 300
        self.check_rewrite("""
            []
            p0 = new_array(101, descr=bdescr)
            p1 = new_array(102, descr=bdescr)  # two new_arrays can be combined
            p2 = new_array(103, descr=bdescr)  # but not all three
            jump()
        """, """
            []
            p0 = call_malloc_nursery(    \
                              %(2 * (bdescr.basesize + 104))d)
            gc_store(p0, 0,  8765, %(tiddescr.field_size)s)
            gc_store(p0, 0,  101, %(blendescr.field_size)s)
            p1 = nursery_ptr_increment(p0, %(bdescr.basesize + 104)d)
            gc_store(p1, 0,  8765, %(tiddescr.field_size)s)
            gc_store(p1, 0,  102, %(blendescr.field_size)s)
            p2 = call_malloc_nursery(    \
                              %(bdescr.basesize + 104)d)
            gc_store(p2, 0,  8765, %(tiddescr.field_size)s)
            gc_store(p2, 0,  103, %(blendescr.field_size)s)
            jump()
        """)

    def test_rewrite_assembler_huge_size(self):
        # "huge" is defined as "larger than 0xffffff bytes, or 16MB"
        self.check_rewrite("""
            []
            p0 = new_array(20000000, descr=bdescr)
            jump()
        """, """
            []
            p0 = call_r(ConstClass(malloc_array), 1,         \
                                %(bdescr.tid)d, 20000000,    \
                                descr=malloc_array_descr)
            check_memory_error(p0)
            jump()
        """)

    def test_new_with_vtable(self):
        self.check_rewrite("""
            []
            p0 = new_with_vtable(descr=o_descr)
            jump()
        """, """
            [p1]
            p0 = call_malloc_nursery(104)      # rounded up
            gc_store(p0, 0,  9315, %(tiddescr.field_size)s)
            gc_store(p0, 0,  0, %(vtable_descr.field_size)s)
            jump()
        """)

    def test_new_with_vtable_too_big(self):
        self.gc_ll_descr.max_size_of_young_obj = 100
        self.check_rewrite("""
            []
            p0 = new_with_vtable(descr=o_descr)
            jump()
        """, """
            [p1]
            p0 = call_r(ConstClass(malloc_big_fixedsize), 104, 9315, \
                                descr=malloc_big_fixedsize_descr)
            check_memory_error(p0)
            gc_store(p0, 0,  0, %(vtable_descr.field_size)s)
            jump()
        """)

    def test_rewrite_assembler_newstr_newunicode(self):
        # note: strdescr.basesize already contains the extra final character,
        # so that's why newstr(14) is rounded up to 'basesize+15' and not
        # 'basesize+16'.
        self.check_rewrite("""
            [i2]
            p0 = newstr(14)
            p1 = newunicode(10)
            p2 = newunicode(i2)
            p3 = newstr(i2)
            jump()
        """, """
            [i2]
            p0 = call_malloc_nursery(                                \
                      %(strdescr.basesize + 15 * strdescr.itemsize + \
                        unicodedescr.basesize + 10 * unicodedescr.itemsize)d)
            gc_store(p0, 0,  %(strdescr.tid)d, %(tiddescr.field_size)s)
            gc_store(p0, %(strlendescr.offset)s, 14, %(strlendescr.field_size)s)
            gc_store(p0, 0,  0, %(strhashdescr.field_size)s)
            p1 = nursery_ptr_increment(p0, %(strdescr.basesize + 15 * strdescr.itemsize)d)
            gc_store(p1, 0,  %(unicodedescr.tid)d, %(tiddescr.field_size)s)
            gc_store(p1, %(unicodelendescr.offset)s, 10, %(unicodelendescr.field_size)s)
            gc_store(p1, 0,  0, %(unicodehashdescr.field_size)s)
            p2 = call_malloc_nursery_varsize(2, %(unicodedescr.itemsize)d, i2,\
                                descr=unicodedescr)
            gc_store(p2, %(unicodelendescr.offset)s, i2, %(unicodelendescr.field_size)s)
            gc_store(p2, 0,  0, %(unicodehashdescr.field_size)s)
            p3 = call_malloc_nursery_varsize(1, 1, i2, \
                                descr=strdescr)
            gc_store(p3, %(strlendescr.offset)s, i2, %(strlendescr.field_size)s)
            gc_store(p3, 0,  0, %(strhashdescr.field_size)s)
            jump()
        """)

    def test_write_barrier_before_setfield_gc(self):
        self.check_rewrite("""
            [p1, p2]
            setfield_gc(p1, p2, descr=tzdescr)
            jump()
        """, """
            [p1, p2]
            cond_call_gc_wb(p1, descr=wbdescr)
            gc_store(p1, %(tzdescr.offset)s, p2, %(tzdescr.field_size)s)
            jump()
        """)

    def test_write_barrier_before_array_without_from_array(self):
        self.gc_ll_descr.write_barrier_descr.has_write_barrier_from_array = (
            lambda cpu: False)
        self.check_rewrite("""
            [p1, i2, p3]
            setarrayitem_gc(p1, i2, p3, descr=cdescr)
            jump()
        """, """
            [p1, i2, p3]
            cond_call_gc_wb(p1, descr=wbdescr)
            %(setarrayitem('p1', 'i2', 'p3', cdescr))s
            jump()
        """)

    def test_write_barrier_before_short_array(self):
        self.gc_ll_descr.max_size_of_young_obj = 2000
        self.check_rewrite("""
            [i2, p3]
            p1 = new_array_clear(129, descr=cdescr)
            call_n(123456)
            setarrayitem_gc(p1, i2, p3, descr=cdescr)
            jump()
        """, """
            [i2, p3]
            p1 = call_malloc_nursery(    \
                                %(cdescr.basesize + 129 * cdescr.itemsize)d)
            gc_store(p1, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p1, 0,  129, %(clendescr.field_size)s)
            %(zero_array('p1', 0, 129, 'cdescr', cdescr))s
            call_n(123456)
            cond_call_gc_wb(p1, descr=wbdescr)
            %(setarrayitem('p1', 'i2', 'p3', cdescr))s
            jump()
        """)

    def test_write_barrier_before_long_array(self):
        # the limit of "being too long" is fixed, arbitrarily, at 130
        self.gc_ll_descr.max_size_of_young_obj = 2000
        self.check_rewrite("""
            [i2, p3]
            p1 = new_array_clear(130, descr=cdescr)
            call_n(123456)
            setarrayitem_gc(p1, i2, p3, descr=cdescr)
            jump()
        """, """
            [i2, p3]
            p1 = call_malloc_nursery(    \
                                %(cdescr.basesize + 130 * cdescr.itemsize)d)
            gc_store(p1, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p1, 0,  130, %(clendescr.field_size)s)
            %(zero_array('p1', 0, 130, 'cdescr', cdescr))s
            call_n(123456)
            cond_call_gc_wb_array(p1, i2, descr=wbdescr)
            %(setarrayitem('p1', 'i2', 'p3', cdescr))s
            jump()
        """)

    def test_write_barrier_before_unknown_array(self):
        self.check_rewrite("""
            [p1, i2, p3]
            setarrayitem_gc(p1, i2, p3, descr=cdescr)
            jump()
        """, """
            [p1, i2, p3]
            cond_call_gc_wb_array(p1, i2, descr=wbdescr)
            %(setarrayitem('p1', 'i2', 'p3', cdescr))s
            jump()
        """)

    def test_label_makes_size_unknown(self):
        self.check_rewrite("""
            [i2, p3]
            p1 = new_array_clear(5, descr=cdescr)
            label(p1, i2, p3)
            setarrayitem_gc(p1, i2, p3, descr=cdescr)
            jump()
        """, """
            [i2, p3]
            p1 = call_malloc_nursery(    \
                                %(cdescr.basesize + 5 * cdescr.itemsize)d)
            gc_store(p1, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p1, 0,  5, %(clendescr.field_size)s)
            %(zero_array('p1', 0, 5, 'cdescr', cdescr))s
            label(p1, i2, p3)
            cond_call_gc_wb_array(p1, i2, descr=wbdescr)
            %(setarrayitem('p1', 'i2', 'p3', cdescr))s
            jump()
        """)

    def test_write_barrier_before_setinteriorfield_gc(self):
        S1 = lltype.GcStruct('S1')
        INTERIOR = lltype.GcArray(('z', lltype.Ptr(S1)))
        interiordescr = get_array_descr(self.gc_ll_descr, INTERIOR)
        interiordescr.tid = 1291
        interiorlendescr = interiordescr.lendescr
        interiorzdescr = get_interiorfield_descr(self.gc_ll_descr,
                                                 INTERIOR, 'z')
        scale = interiorzdescr.arraydescr.itemsize
        offset = interiorzdescr.arraydescr.basesize
        offset += interiorzdescr.fielddescr.offset
        size = interiorzdescr.arraydescr.itemsize
        self.check_rewrite("""
            [p1, p2]
            setinteriorfield_gc(p1, 7, p2, descr=interiorzdescr)
            jump(p1, p2)
        """, """
            [p1, p2]
            cond_call_gc_wb_array(p1, 7, descr=wbdescr)
            gc_store(p1, %(offset + 7 * scale)s, p2, %(size)s)
            jump(p1, p2)
        """, interiorzdescr=interiorzdescr, scale=scale,
             offset=offset, size=size)

    def test_initialization_store(self):
        self.check_rewrite("""
            [p1]
            p0 = new(descr=tdescr)
            setfield_gc(p0, p1, descr=tzdescr)
            jump()
        """, """
            [p1]
            p0 = call_malloc_nursery(%(tdescr.size)d)
            gc_store(p0, 0,  5678, %(tiddescr.field_size)s)
            gc_store(p0, %(tzdescr.offset)s, p1, %(tzdescr.field_size)s)
            jump()
        """)

    def test_initialization_store_2(self):
        self.check_rewrite("""
            []
            p0 = new(descr=tdescr)
            p1 = new(descr=sdescr)
            setfield_gc(p0, p1, descr=tzdescr)
            jump()
        """, """
            []
            p0 = call_malloc_nursery(%(tdescr.size + sdescr.size)d)
            gc_store(p0, 0,  5678, %(tiddescr.field_size)s)
            p1 = nursery_ptr_increment(p0, %(tdescr.size)d)
            gc_store(p1, 0,  1234, %(tiddescr.field_size)s)
            # <<<no cond_call_gc_wb here>>>
            gc_store(p0, %(tzdescr.offset)s, p1, %(tzdescr.field_size)s)
            jump()
        """)

    def test_initialization_store_array(self):
        self.check_rewrite("""
            [p1, i2]
            p0 = new_array_clear(5, descr=cdescr)
            setarrayitem_gc(p0, i2, p1, descr=cdescr)
            jump()
        """, """
            [p1, i2]
            p0 = call_malloc_nursery(    \
                                %(cdescr.basesize + 5 * cdescr.itemsize)d)
            gc_store(p0, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p0, 0,  5, %(clendescr.field_size)s)
            %(zero_array('p0', 0, 5, 'cdescr', cdescr))s
            %(setarrayitem('p0', 'i2', 'p1', cdescr))s
            jump()
        """)

    def test_zero_array_reduced_left(self):
        self.check_rewrite("""
            [p1, p2]
            p0 = new_array_clear(5, descr=cdescr)
            setarrayitem_gc(p0, 1, p1, descr=cdescr)
            setarrayitem_gc(p0, 0, p2, descr=cdescr)
            jump()
        """, """
            [p1, p2]
            p0 = call_malloc_nursery(    \
                                %(cdescr.basesize + 5 * cdescr.itemsize)d)
            gc_store(p0, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p0, 0,  5, %(clendescr.field_size)s)
            %(zero_array('p0', 2, 3, 'cdescr', cdescr))s
            %(setarrayitem('p0', 1, 'p1', cdescr))s
            %(setarrayitem('p0', 0, 'p2', cdescr))s
            jump()
        """)

    def test_zero_array_reduced_right(self):
        self.check_rewrite("""
            [p1, p2]
            p0 = new_array_clear(5, descr=cdescr)
            setarrayitem_gc(p0, 3, p1, descr=cdescr)
            setarrayitem_gc(p0, 4, p2, descr=cdescr)
            jump()
        """, """
            [p1, p2]
            p0 = call_malloc_nursery(    \
                                %(cdescr.basesize + 5 * cdescr.itemsize)d)
            gc_store(p0, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p0, 0,  5, %(clendescr.field_size)s)
            %(zero_array('p0', 0, 3, 'cdescr', cdescr))s
            %(setarrayitem('p0', 3, 'p1', cdescr))s
            %(setarrayitem('p0', 4, 'p2', cdescr))s
            jump()
        """)

    def test_zero_array_not_reduced_at_all(self):
        self.check_rewrite("""
            [p1, p2]
            p0 = new_array_clear(5, descr=cdescr)
            setarrayitem_gc(p0, 3, p1, descr=cdescr)
            setarrayitem_gc(p0, 2, p2, descr=cdescr)
            setarrayitem_gc(p0, 1, p2, descr=cdescr)
            jump()
        """, """
            [p1, p2]
            p0 = call_malloc_nursery(    \
                                %(cdescr.basesize + 5 * cdescr.itemsize)d)
            gc_store(p0, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p0, 0,  5, %(clendescr.field_size)s)
            %(zero_array('p0', 0, 5, 'cdescr', cdescr))s
            %(setarrayitem('p0', 3, 'p1', cdescr))s
            %(setarrayitem('p0', 2, 'p2', cdescr))s
            %(setarrayitem('p0', 1, 'p2', cdescr))s
            jump()
        """)

    def test_zero_array_reduced_completely(self):
        self.check_rewrite("""
            [p1, p2]
            p0 = new_array_clear(5, descr=cdescr)
            setarrayitem_gc(p0, 3, p1, descr=cdescr)
            setarrayitem_gc(p0, 4, p2, descr=cdescr)
            setarrayitem_gc(p0, 0, p1, descr=cdescr)
            setarrayitem_gc(p0, 2, p2, descr=cdescr)
            setarrayitem_gc(p0, 1, p2, descr=cdescr)
            jump()
        """, """
            [p1, p2]
            p0 = call_malloc_nursery(    \
                                %(cdescr.basesize + 5 * cdescr.itemsize)d)
            gc_store(p0, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p0, 0,  5, %(clendescr.field_size)s)
            %(zero_array('p0', 5, 0, 'cdescr', cdescr))s
            %(setarrayitem('p0', 3, 'p1', cdescr))s
            %(setarrayitem('p0', 4, 'p2', cdescr))s
            %(setarrayitem('p0', 0, 'p1', cdescr))s
            %(setarrayitem('p0', 2, 'p2', cdescr))s
            %(setarrayitem('p0', 1, 'p2', cdescr))s
            jump()
        """)

    def test_zero_array_reduced_left_with_call(self):
        self.check_rewrite("""
            [p1, p2]
            p0 = new_array_clear(5, descr=cdescr)
            setarrayitem_gc(p0, 0, p1, descr=cdescr)
            call_n(321321)
            setarrayitem_gc(p0, 1, p2, descr=cdescr)
            jump()
        """, """
            [p1, p2]
            p0 = call_malloc_nursery(    \
                                %(cdescr.basesize + 5 * cdescr.itemsize)d)
            gc_store(p0, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p0, 0,  5, %(clendescr.field_size)s)
            %(zero_array('p0', 1, 4, 'cdescr', cdescr))s
            %(setarrayitem('p0', 0, 'p1', cdescr))s
            call_n(321321)
            cond_call_gc_wb(p0, descr=wbdescr)
            %(setarrayitem('p0', 1, 'p2', cdescr))s
            jump()
        """)

    def test_zero_array_reduced_left_with_label(self):
        self.check_rewrite("""
            [p1, p2]
            p0 = new_array_clear(5, descr=cdescr)
            setarrayitem_gc(p0, 0, p1, descr=cdescr)
            label(p0, p2)
            setarrayitem_gc(p0, 1, p2, descr=cdescr)
            jump()
        """, """
            [p1, p2]
            p0 = call_malloc_nursery(    \
                                %(cdescr.basesize + 5 * cdescr.itemsize)d)
            gc_store(p0, 0,  8111, %(tiddescr.field_size)s)
            gc_store(p0, 0,  5, %(clendescr.field_size)s)
            %(zero_array('p0', 1, 4, 'cdescr', cdescr))s
            %(setarrayitem('p0', 0, 'p1', cdescr))s
            label(p0, p2)
            cond_call_gc_wb_array(p0, 1, descr=wbdescr)
            %(setarrayitem('p0', 1, 'p2', cdescr))s
            jump()
        """)

    def test_zero_array_varsize(self):
        self.check_rewrite("""
            [p1, p2, i3]
            p0 = new_array_clear(i3, descr=bdescr)
            jump()
        """, """
            [p1, p2, i3]
            p0 = call_malloc_nursery_varsize(0, 1, i3, descr=bdescr)
            gc_store(p0, 0,  i3, %(blendescr.field_size)s)
            %(zero_array('p0', 0, 'i3', 'bdescr', bdescr))s
            jump()
        """)

    def test_zero_array_varsize_cannot_reduce(self):
        self.check_rewrite("""
            [p1, p2, i3]
            p0 = new_array_clear(i3, descr=bdescr)
            setarrayitem_gc(p0, 0, p1, descr=bdescr)
            jump()
        """, """
            [p1, p2, i3]
            p0 = call_malloc_nursery_varsize(0, 1, i3, descr=bdescr)
            gc_store(p0, 0,  i3, %(blendescr.field_size)s)
            %(zero_array('p0', 0, 'i3', 'bdescr', bdescr))s
            cond_call_gc_wb_array(p0, 0, descr=wbdescr)
            %(setarrayitem('p0', 0, 'p1', bdescr))s
            jump()
        """)

    def test_initialization_store_potentially_large_array(self):
        # the write barrier cannot be omitted, because we might get
        # an array with cards and the GC assumes that the write
        # barrier is always called, even on young (but large) arrays
        self.check_rewrite("""
            [i0, p1, i2]
            p0 = new_array(i0, descr=bdescr)
            setarrayitem_gc(p0, i2, p1, descr=bdescr)
            jump()
        """, """
            [i0, p1, i2]
            p0 = call_malloc_nursery_varsize(0, 1, i0, descr=bdescr)
            gc_store(p0, 0,  i0, %(blendescr.field_size)s)
            cond_call_gc_wb_array(p0, i2, descr=wbdescr)
            gc_store_indexed(p0, i2, p1, 1, %(bdescr.basesize)s, 1)
            jump()
        """)

    def test_non_initialization_store(self):
        self.check_rewrite("""
            [i0]
            p0 = new(descr=tdescr)
            p1 = newstr(i0)
            setfield_gc(p0, p1, descr=tzdescr)
            jump()
        """, """
            [i0]
            p0 = call_malloc_nursery(%(tdescr.size)d)
            gc_store(p0, 0,  5678, %(tiddescr.field_size)s)
            gc_store(p0, %(tdescr.gc_fielddescrs[0].offset)s, 0, %(tdescr.gc_fielddescrs[0].offset)s)
            p1 = call_malloc_nursery_varsize(1, 1, i0, \
                                descr=strdescr)
            gc_store(p1, %(strlendescr.offset)s, i0, %(strlendescr.field_size)s)
            gc_store(p1, 0,  0, %(strhashdescr.field_size)s)
            cond_call_gc_wb(p0, descr=wbdescr)
            gc_store(p0, %(tzdescr.offset)s, p1, %(tzdescr.field_size)s)
            jump()
        """)

    def test_non_initialization_store_label(self):
        self.check_rewrite("""
            [p1]
            p0 = new(descr=tdescr)
            label(p0, p1)
            setfield_gc(p0, p1, descr=tzdescr)
            jump()
        """, """
            [p1]
            p0 = call_malloc_nursery(%(tdescr.size)d)
            gc_store(p0, 0,  5678, %(tiddescr.field_size)s)
            gc_store(p0, %(tdescr.gc_fielddescrs[0].offset)s, 0, %(tdescr.gc_fielddescrs[0].offset)s)
            label(p0, p1)
            cond_call_gc_wb(p0, descr=wbdescr)
            gc_store(p0, %(tzdescr.offset)s, p1, %(tzdescr.field_size)s)
            jump()
        """)

    def test_multiple_writes(self):
        self.check_rewrite("""
            [p0, p1, p2]
            setfield_gc(p0, p1, descr=tzdescr)
            setfield_gc(p0, p2, descr=tzdescr)
            jump(p1, p2, p0)
        """, """
            [p0, p1, p2]
            cond_call_gc_wb(p0, descr=wbdescr)
            gc_store(p0, %(tzdescr.offset)s, p1, %(tzdescr.field_size)s)
            gc_store(p0, %(tzdescr.offset)s, p2, %(tzdescr.field_size)s)
            jump(p1, p2, p0)
        """)

    def test_rewrite_call_assembler(self):
        self.check_rewrite("""
        [i0, f0]
        i2 = call_assembler_i(i0, f0, descr=casmdescr)
        """, """
        [i0, f0]
        i1 = gc_load_i(ConstClass(frame_info), %(jfi_frame_size.offset)s, %(jfi_frame_size.field_size)s)
        p1 = call_malloc_nursery_varsize_frame(i1)
        gc_store(p1, 0,  0, %(tiddescr.field_size)s)
        i2 = gc_load_i(ConstClass(frame_info), %(jfi_frame_depth.offset)s, %(jfi_frame_depth.field_size)s)
        %(setfield('p1', 'NULL', jf_savedata))s
        %(setfield('p1', 'NULL', jf_force_descr))s
        %(setfield('p1', 'NULL', jf_descr))s
        %(setfield('p1', 'NULL', jf_guard_exc))s
        %(setfield('p1', 'NULL', jf_forward))s
        gc_store(p1, 0, i2, %(framelendescr.field_size)s)
        %(setfield('p1', 'ConstClass(frame_info)', jf_frame_info))s
        gc_store(p1, 3, i0, 8)
        gc_store(p1, 13, f0, 8)
        i3 = call_assembler_i(p1, descr=casmdescr)
        """)

    def test_int_add_ovf(self):
        self.check_rewrite("""
            [i0]
            p0 = new(descr=tdescr)
            i1 = int_add_ovf(i0, 123)
            guard_overflow(descr=guarddescr) []
            jump()
        """, """
            [i0]
            p0 = call_malloc_nursery(%(tdescr.size)d)
            gc_store(p0, 0,  5678, %(tiddescr.field_size)s)
            gc_store(p0, %(tdescr.gc_fielddescrs[0].offset)s, 0, %(tdescr.gc_fielddescrs[0].offset)s)
            i1 = int_add_ovf(i0, 123)
            guard_overflow(descr=guarddescr) []
            jump()
        """)

    def test_int_gt(self):
        self.check_rewrite("""
            [i0]
            p0 = new(descr=tdescr)
            i1 = int_gt(i0, 123)
            guard_false(i1, descr=guarddescr) []
            jump()
        """, """
            [i0]
            p0 = call_malloc_nursery(%(tdescr.size)d)
            gc_store(p0, 0,  5678, %(tiddescr.field_size)s)
            gc_store(p0, %(tdescr.gc_fielddescrs[0].offset)s, 0, %(tdescr.gc_fielddescrs[0].offset)s)
            i1 = int_gt(i0, 123)
            guard_false(i1, descr=guarddescr) []
            jump()
        """)

    def test_zero_ptr_field_before_getfield(self):
        # This case may need to be fixed in the metainterp/optimizeopt
        # already so that it no longer occurs for rewrite.py.  But anyway
        # it's a good idea to make sure rewrite.py is correct on its own.
        self.check_rewrite("""
            []
            p0 = new(descr=tdescr)
            p1 = getfield_gc_r(p0, descr=tzdescr)
            jump(p1)
        """, """
            []
            p0 = call_malloc_nursery(%(tdescr.size)d)
            gc_store(p0, 0,  5678, %(tiddescr.field_size)s)
            gc_store(p0, %(tdescr.gc_fielddescrs[0].offset)s, 0, %(tdescr.gc_fielddescrs[0].offset)s)
            p1 = gc_load_r(p0, %(tzdescr.offset)s, %(tzdescr.field_size)s)
            jump(p1)
        """)

    def test_remove_tested_failarg(self):
        self.check_rewrite("""
            [i5]
            i2 = int_ge(i5, 10)
            guard_true(i2) [i5, i2]
            jump()
        """, """
            [i5]
            i0 = same_as_i(0)
            i2 = int_ge(i5, 10)
            guard_true(i2) [i5, i0]
            jump()
        """)
        self.check_rewrite("""
            [i5]
            i2 = int_ge(i5, 10)
            guard_false(i2) [i5, i2]
            jump()
        """, """
            [i5]
            i0 = same_as_i(1)
            i2 = int_ge(i5, 10)
            guard_false(i2) [i5, i0]
            jump()
        """)

    @py.test.mark.parametrize('support_offset,factors,fromto',[
        # [False, (1,2,4,8), 'setarrayitem_gc(p0,i1,i2,descr=adescr)' '->'
        #    'i3 = int_mul(i1,%(adescr.itemsize)s);'
        #    'i4 = int_add(i3,%(adescr.basesize)s);'
        #    'gc_store(p0,i4,i2,%(adescr.itemsize)s)'],
        [True, (1,2,4,8), 'setarrayitem_gc(p0,i1,i2,descr=adescr)' '->'
           'gc_store_indexed(p0,i1,i2,%(adescr.itemsize)s,'
           '%(adescr.basesize)s,%(adescr.itemsize)s)'],
        #[False, (1,), 'setarrayitem_gc(p0,i1,i2,descr=adescr)' '->'
        #   'i3 = int_mul(i1,%(adescr.itemsize)s);'
        #   'i4 = int_add(i3,%(adescr.basesize)s);'
        #   'gc_store(p0,i4,i2,%(adescr.itemsize)s)'],
        [True, None, 'i3 = raw_load_i(p0,i1,descr=adescr)' '->'
           'gc_load_indexed_i(p0,i1,1,%(adescr.basesize)s,-%(adescr.itemsize)s)'],
        [True, None, 'i3 = raw_load_f(p0,i1,descr=fdescr)' '->'
           'gc_load_indexed_f(p0,i1,1,%(fdescr.basesize)s,%(fdescr.itemsize)s)'],
        [True, None, 'i3 = raw_load_i(p0,i1,descr=sfdescr)' '->'
           'gc_load_indexed_i(p0,i1,1,%(sfdescr.basesize)s,%(sfdescr.itemsize)s)'],
        [True, (1,2,4,8), 'i3 = raw_store(p0,i1,i2,descr=raw_sfdescr)' '->'
           'gc_store_indexed(p0,i1,i2,1,%(raw_sfdescr.basesize)s,%(raw_sfdescr.itemsize)s)'],
        # [False, (1,), 'i3 = raw_store(p0,i1,i2,descr=raw_sfdescr)' '->'
        #    'i5 = int_add(i1,%(raw_sfdescr.basesize)s);'
        #    'gc_store(p0,i5,i2,%(raw_sfdescr.itemsize)s)'],
        [True, (1,2,4,8), 'i3 = getfield_gc_f(p0,descr=ydescr)' '->'
           'i3 = gc_load_f(p0,%(ydescr.offset)s,%(ydescr.field_size)s)'],
        [True, (1,2,4,8), 'setfield_raw(p0,i1,descr=ydescr)' '->'
           'gc_store(p0,%(ydescr.offset)s,i1,%(ydescr.field_size)s)'],
        [True, (1,2,4,8), 'setfield_gc(p0,p0,descr=zdescr)' '->'
           'cond_call_gc_wb(p0, descr=wbdescr);'
           'gc_store(p0,%(zdescr.offset)s,p0,%(zdescr.field_size)s)'],
        [False, (1,), 'i3 = arraylen_gc(p0, descr=adescr)' '->'
                      'i3 = gc_load_i(p0,0,%(adescr.itemsize)s)'],
        #[False, (1,),  'i3 = strlen(p0)' '->'
        #               'i3 = gc_load_i(p0,'
        #               '%(strlendescr.offset)s,%(strlendescr.field_size)s)'],
        [True,  (1,),  'i3 = strlen(p0)' '->'
                       'i3 = gc_load_i(p0,'
                                 '%(strlendescr.offset)s,'
                                 '%(strlendescr.field_size)s)'],
        [True,  (1,),  'i3 = strhash(p0)' '->'
                       'i3 = gc_load_i(p0,'
                                 '%(strhashdescr.offset)s,'
                                 '-%(strhashdescr.field_size)s)'],
        #[False, (1,),  'i3 = unicodelen(p0)' '->'
        #               'i3 = gc_load_i(p0,'
        #                       '%(unicodelendescr.offset)s,'
        #                       '%(unicodelendescr.field_size)s)'],
        [True,  (1,),  'i3 = unicodelen(p0)' '->'
                       'i3 = gc_load_i(p0,'
                               '%(unicodelendescr.offset)s,'
                               '%(unicodelendescr.field_size)s)'],
        [True,  (1,),  'i3 = unicodehash(p0)' '->'
                       'i3 = gc_load_i(p0,'
                                 '%(unicodehashdescr.offset)s,'
                                 '-%(unicodehashdescr.field_size)s)'],
        ## getitem str/unicode
        [True,  (2,4), 'i3 = unicodegetitem(p0,i1)' '->'
                       'i3 = gc_load_indexed_i(p0,i1,'
                                  '%(unicodedescr.itemsize)d,'
                                  '%(unicodedescr.basesize)d,'
                                  '%(unicodedescr.itemsize)d)'],
        #[False, (2,4), 'i3 = unicodegetitem(p0,i1)' '->'
        #               'i4 = int_mul(i1, %(unicodedescr.itemsize)d);'
        #               'i5 = int_add(i4, %(unicodedescr.basesize)d);'
        #               'i3 = gc_load_i(p0,i5,%(unicodedescr.itemsize)d)'],
        [True,  (4,),  'i3 = strgetitem(p0,i1)' '->'
                       'i3 = gc_load_indexed_i(p0,i1,1,'
                       '%(strdescr.basesize-1)d,1)'],
        #[False, (4,),  'i3 = strgetitem(p0,i1)' '->'
        #               'i5 = int_add(i1, %(strdescr.basesize-1)d);'
        #               'i3 = gc_load_i(p0,i5,1)'],
        ## setitem str/unicode
        [True, (4,),  'i3 = strsetitem(p0,i1,0)' '->'
                      'i3 = gc_store_indexed(p0,i1,0,1,'
                               '%(strdescr.basesize-1)d,1)'],
        [True, (2,4), 'i3 = unicodesetitem(p0,i1,0)' '->'
                      'i3 = gc_store_indexed(p0,i1,0,'
                                 '%(unicodedescr.itemsize)d,'
                                 '%(unicodedescr.basesize)d,'
                                 '%(unicodedescr.itemsize)d)'],
        ## interior
        [True, (1,2,4,8), 'i3 = getinteriorfield_gc_i(p0,i1,descr=itzdescr)' '->'
                          'i4 = int_mul(i1,'
                             '%(itzdescr.arraydescr.itemsize)d);'
                          'i3 = gc_load_indexed_i(p0,i4,1,'
                                   '%(itzdescr.arraydescr.basesize'
                                   '   + itzdescr.fielddescr.offset)d,'
                                   '%(itzdescr.fielddescr.field_size)d)'],
        [True, (1,2,4,8), 'i3 = getinteriorfield_gc_r(p0,i1,descr=itxdescr)' '->'
                          'i4 = int_mul(i1,'
                             '%(itxdescr.arraydescr.itemsize)d);'
                          'i3 = gc_load_indexed_r(p0,i4,1,'
                             '%(itxdescr.arraydescr.basesize'
                             '   + itxdescr.fielddescr.offset)d,'
                             '%(itxdescr.fielddescr.field_size)d)'],
        [True, (1,2,4,8), 'i3 = setinteriorfield_gc(p0,i1,i2,descr=itydescr)' '->'
                          'i4 = int_mul(i1,'
                             '%(itydescr.arraydescr.itemsize)d);'
                          'i3 = gc_store_indexed(p0,i4,i2,1,'
                             '%(itydescr.arraydescr.basesize'
                             '   + itydescr.fielddescr.offset)d,'
                             '%(itydescr.fielddescr.field_size)d)'],
        [True, (1,2,4,8), 'i3 = setinteriorfield_gc(p0,i1,i2,descr=ity2descr)' '->'
                          'i4 = int_lshift(i1,'
                             '%(s2i_item_size_in_bits)d);'
                          'i3 = gc_store_indexed(p0,i4,i2,1,'
                             '%(ity2descr.arraydescr.basesize'
                             '   + itydescr.fielddescr.offset)d,'
                             '%(ity2descr.fielddescr.field_size)d)'],
        [True, (2,), 'i3 = gc_load_indexed_i(i1, i2, 2, 40, 1)' '->'
                     'i3 = gc_load_indexed_i(i1, i2, 2, 40, 1)'],
        [True, (2,), 'i3 = gc_load_indexed_i(i1, 6, 8, 40, 4)' '->'
                     'i3 = gc_load_i(i1, 88, 4)'],
        [True, (2,), 'i3 = gc_load_indexed_i(i1, i2, 2, 40, -1)' '->'
                     'i3 = gc_load_indexed_i(i1, i2, 2, 40, -1)'],
        [True, (2,), 'i3 = gc_load_indexed_i(i1, 6, 8, 40, -4)' '->'
                     'i3 = gc_load_i(i1, 88, -4)'],
        [True, (2,), 'i3 = gc_store_indexed(i1, i2, 999, 2, 40, 1)' '->'
                     'i3 = gc_store_indexed(i1, i2, 999, 2, 40, 1)'],
        [True, (2,), 'i3 = gc_store_indexed(i1, 6, 999, 8, 40, 2)' '->'
                     'i3 = gc_store(i1, 88, 999, 2)'],
    ])
    def test_gc_load_store_transform(self, support_offset, factors, fromto):
        self.cpu.load_constant_offset = support_offset
        all_supported_sizes = [factors]

        if not factors:
            all_supported_sizes = [(1,), (1,2,), (4,), (1,2,4,8)]
        try:
            for factors in all_supported_sizes:
                self.cpu.load_supported_factors = factors
                f, t = fromto.split('->')
                t = ('\n' +(' '*20)).join([s for s in t.split(';')])
                self.check_rewrite("""
                    [p0,i1,i2]
                    {f}
                    jump()
                """.format(**locals()), """
                    [p0,i1,i2]
                    {t}
                    jump()
                """.format(**locals()))
        finally:
            del self.cpu.load_supported_factors   # restore class-level value

    def test_load_from_gc_table_1i(self):
        self.check_rewrite("""
            [i1]
            setfield_gc(ConstPtr(myR1), i1, descr=xdescr)
            jump()
        """, """
            [i1]
            p0 = load_from_gc_table(0)
            gc_store(p0, %(xdescr.offset)s, i1, %(xdescr.field_size)s)
            jump()
        """)
        assert self.gcrefs == [self.myR1]

    def test_load_from_gc_table_1p(self):
        self.check_rewrite("""
            [p1]
            setfield_gc(ConstPtr(myT), p1, descr=tzdescr)
            jump()
        """, """
            [i1]
            p0 = load_from_gc_table(0)
            cond_call_gc_wb(p0, descr=wbdescr)
            gc_store(p0, %(tzdescr.offset)s, i1, %(tzdescr.field_size)s)
            jump()
        """)
        assert self.gcrefs == [self.myT]

    def test_load_from_gc_table_2(self):
        self.check_rewrite("""
            [i1, f2]
            setfield_gc(ConstPtr(myR1), i1, descr=xdescr)
            setfield_gc(ConstPtr(myR1), f2, descr=ydescr)
            jump()
        """, """
            [i1, f2]
            p0 = load_from_gc_table(0)
            gc_store(p0, %(xdescr.offset)s, i1, %(xdescr.field_size)s)
            gc_store(p0, %(ydescr.offset)s, f2, %(ydescr.field_size)s)
            jump()
        """)
        assert self.gcrefs == [self.myR1]

    def test_load_from_gc_table_3(self):
        self.check_rewrite("""
            [i1, f2]
            setfield_gc(ConstPtr(myR1), i1, descr=xdescr)
            label(f2)
            setfield_gc(ConstPtr(myR1), f2, descr=ydescr)
            jump()
        """, """
            [i1, f2]
            p0 = load_from_gc_table(0)
            gc_store(p0, %(xdescr.offset)s, i1, %(xdescr.field_size)s)
            label(f2)
            p1 = load_from_gc_table(0)
            gc_store(p1, %(ydescr.offset)s, f2, %(ydescr.field_size)s)
            jump()
        """)
        assert self.gcrefs == [self.myR1]

    def test_load_from_gc_table_4(self):
        self.check_rewrite("""
            [i1, f2]
            setfield_gc(ConstPtr(myR1), i1, descr=xdescr)
            setfield_gc(ConstPtr(myR1b), f2, descr=ydescr)
            jump()
        """, """
            [i1, f2]
            p0 = load_from_gc_table(0)
            gc_store(p0, %(xdescr.offset)s, i1, %(xdescr.field_size)s)
            p1 = load_from_gc_table(1)
            gc_store(p1, %(ydescr.offset)s, f2, %(ydescr.field_size)s)
            jump()
        """)
        assert self.gcrefs == [self.myR1, self.myR1b]

    def test_pinned_simple_getfield(self):
        # originally in test_pinned_object_rewrite; now should give the
        # same result for pinned objects and for normal objects
        self.check_rewrite("""
            []
            i0 = getfield_gc_i(ConstPtr(myR1), descr=xdescr)
        """, """
            []
            p1 = load_from_gc_table(0)
            i0 = gc_load_i(p1, %(xdescr.offset)s, -%(xdescr.field_size)s)
        """)
        assert self.gcrefs == [self.myR1]

    def test_pinned_simple_getfield_twice(self):
        # originally in test_pinned_object_rewrite; now should give the
        # same result for pinned objects and for normal objects
        self.check_rewrite("""
            []
            i0 = getfield_gc_i(ConstPtr(myR1), descr=xdescr)
            i1 = getfield_gc_i(ConstPtr(myR1b), descr=xdescr)
            i2 = getfield_gc_i(ConstPtr(myR1), descr=xdescr)
        """, """
            []
            p1 = load_from_gc_table(0)
            i0 = gc_load_i(p1, %(xdescr.offset)s, -%(xdescr.field_size)s)
            p2 = load_from_gc_table(1)
            i1 = gc_load_i(p2, %(xdescr.offset)s, -%(xdescr.field_size)s)
            i2 = gc_load_i(p1, %(xdescr.offset)s, -%(xdescr.field_size)s)
        """)
        assert self.gcrefs == [self.myR1, self.myR1b]

    def test_guard_in_gcref(self):
        self.check_rewrite("""
            [i1, i2]
            guard_true(i1) []
            guard_true(i2) []
            jump()
        """, """
            [i1, i2]
            guard_true(i1) []
            guard_true(i2) []
            jump()
        """)
        assert len(self.gcrefs) == 2

    def test_rewrite_copystrcontents(self):
        self.check_rewrite("""
        [p0, p1, i0, i1, i_len]
        copystrcontent(p0, p1, i0, i1, i_len)
        """, """
        [p0, p1, i0, i1, i_len]
        i2 = load_effective_address(p0, i0, %(str_basesize)s, 0)
        i3 = load_effective_address(p1, i1, %(str_basesize)s, 0)
        call_n(ConstClass(memcpy_fn), i3, i2, i_len, descr=memcpy_descr)
        """)

    def test_rewrite_copystrcontents_without_load_effective_address(self):
        self.cpu.supports_load_effective_address = False
        self.check_rewrite("""
        [p0, p1, i0, i1, i_len]
        copystrcontent(p0, p1, i0, i1, i_len)
        """, """
        [p0, p1, i0, i1, i_len]
        i2b = int_add(p0, i0)
        i2 = int_add(i2b, %(str_basesize)s)
        i3b = int_add(p1, i1)
        i3 = int_add(i3b, %(str_basesize)s)
        call_n(ConstClass(memcpy_fn), i3, i2, i_len, descr=memcpy_descr)
        """)

    def test_rewrite_copyunicodecontents(self):
        self.check_rewrite("""
        [p0, p1, i0, i1, i_len]
        copyunicodecontent(p0, p1, i0, i1, i_len)
        """, """
        [p0, p1, i0, i1, i_len]
        i2 = load_effective_address(p0, i0, %(uni_basesize)s, %(uni_itemscale)d)
        i3 = load_effective_address(p1, i1, %(uni_basesize)s, %(uni_itemscale)d)
        i4 = int_lshift(i_len, %(uni_itemscale)d)
        call_n(ConstClass(memcpy_fn), i3, i2, i4, descr=memcpy_descr)
        """)

    def test_rewrite_copyunicodecontents_without_load_effective_address(self):
        self.cpu.supports_load_effective_address = False
        self.check_rewrite("""
        [p0, p1, i0, i1, i_len]
        copyunicodecontent(p0, p1, i0, i1, i_len)
        """, """
        [p0, p1, i0, i1, i_len]
        i0s = int_lshift(i0, %(uni_itemscale)d)
        i2b = int_add(p0, i0s)
        i2 = int_add(i2b, %(uni_basesize)s)
        i1s = int_lshift(i1, %(uni_itemscale)d)
        i3b = int_add(p1, i1s)
        i3 = int_add(i3b, %(uni_basesize)s)
        i4 = int_lshift(i_len, %(uni_itemscale)d)
        call_n(ConstClass(memcpy_fn), i3, i2, i4, descr=memcpy_descr)
        """)

    def test_record_int_add_or_sub(self):
        # ---- no rewrite ----
        self.check_rewrite("""
            [p0, i0]
            i2 = getarrayitem_gc_i(p0, i0, descr=cdescr)
        """, """
            [p0, i0]
            i3 = gc_load_indexed_i(p0, i0,   \
                      %(cdescr.itemsize)d,   \
                      %(cdescr.basesize)d,   \
                      %(cdescr.itemsize)d)
        """)
        # ---- add 5 ----
        self.check_rewrite("""
            [p0, i0]
            i1 = int_add(i0, 5)
            i2 = getarrayitem_gc_i(p0, i1, descr=cdescr)
        """, """
            [p0, i0]
            i1 = int_add(i0, 5)
            i3 = gc_load_indexed_i(p0, i0,   \
                      %(cdescr.itemsize)d,   \
                      %(cdescr.basesize + 5 * cdescr.itemsize)d,   \
                      %(cdescr.itemsize)d)
        """)
        # ---- subtract 1 ----
        self.check_rewrite("""
            [p0, i0]
            i1 = int_sub(i0, 1)
            i2 = getarrayitem_gc_i(p0, i1, descr=cdescr)
        """, """
            [p0, i0]
            i1 = int_sub(i0, 1)
            i3 = gc_load_indexed_i(p0, i0,   \
                      %(cdescr.itemsize)d,   \
                      %(cdescr.basesize - cdescr.itemsize)d,   \
                      %(cdescr.itemsize)d)
        """)
        # ---- add reversed and multiple levels ----
        self.check_rewrite("""
            [p0, i0]
            i1 = int_sub(i0, 1)
            i2 = int_add(i1, 10)
            i3 = int_add(100, i2)
            i4 = getarrayitem_gc_i(p0, i3, descr=cdescr)
        """, """
            [p0, i0]
            i1 = int_sub(i0, 1)
            i2 = int_add(i1, 10)
            i3 = int_add(100, i2)
            i4 = gc_load_indexed_i(p0, i0,   \
                      %(cdescr.itemsize)d,   \
                      %(cdescr.basesize + 109 * cdescr.itemsize)d,   \
                      %(cdescr.itemsize)d)
        """)
        # ---- a label stops the optimization ----
        self.check_rewrite("""
            [p0, i0]
            i1 = int_sub(i0, 1)
            label(p0, i0, i1)
            i4 = getarrayitem_gc_i(p0, i1, descr=cdescr)
        """, """
            [p0, i0]
            i1 = int_sub(i0, 1)
            label(p0, i0, i1)
            i4 = gc_load_indexed_i(p0, i1,   \
                      %(cdescr.itemsize)d,   \
                      %(cdescr.basesize)d,   \
                      %(cdescr.itemsize)d)
        """)
        # ---- also test setarrayitem_gc ----
        self.check_rewrite("""
            [p0, i0, i4]
            i1 = int_sub(i0, 1)
            i2 = int_add(i1, 10)
            i3 = int_add(100, i2)
            setarrayitem_gc(p0, i3, i4, descr=cdescr)
        """, """
            [p0, i0, i4]
            i1 = int_sub(i0, 1)
            i2 = int_add(i1, 10)
            i3 = int_add(100, i2)
            gc_store_indexed(p0, i0, i4,   \
                      %(cdescr.itemsize)d,   \
                      %(cdescr.basesize + 109 * cdescr.itemsize)d,   \
                      %(cdescr.itemsize)d)
        """)
        # ---- also check int_add_ovf, int_sub_ovf ----
        self.check_rewrite("""
            [p0, i0, i4]
            i1 = int_sub_ovf(i0, 1)
            guard_no_overflow(descr=guarddescr) []
            i2 = int_add_ovf(i1, 10)
            guard_no_overflow(descr=guarddescr) []
            i3 = int_add_ovf(100, i2)
            guard_no_overflow(descr=guarddescr) []
            setarrayitem_gc(p0, i3, i4, descr=cdescr)
        """, """
            [p0, i0, i4]
            i1 = int_sub_ovf(i0, 1)
            guard_no_overflow(descr=guarddescr) []
            i2 = int_add_ovf(i1, 10)
            guard_no_overflow(descr=guarddescr) []
            i3 = int_add_ovf(100, i2)
            guard_no_overflow(descr=guarddescr) []
            gc_store_indexed(p0, i0, i4,   \
                      %(cdescr.itemsize)d,   \
                      %(cdescr.basesize + 109 * cdescr.itemsize)d,   \
                      %(cdescr.itemsize)d)
        """)

    def test_guard_always_fails(self):
        self.check_rewrite("""
        [i1, i2, i3]
        guard_always_fails(descr=guarddescr) [i1, i2, i3]
        """, """
        [i1, i2, i3]
        i4 = same_as_i(0)
        guard_value(i4, 1, descr=guarddescr) [i1, i2, i3]
        """)


