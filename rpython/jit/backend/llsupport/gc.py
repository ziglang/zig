import os
from rpython.rlib import rgc
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, rstr
from rpython.rtyper import rclass
from rpython.rtyper.lltypesystem import llgroup
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.annlowlevel import llhelper, cast_instance_to_gcref
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.jit.codewriter import heaptracker
from rpython.jit.metainterp.history import ConstPtr, AbstractDescr, ConstInt
from rpython.jit.metainterp.resoperation import rop, ResOperation
from rpython.jit.metainterp.support import ptr2int
from rpython.jit.backend.llsupport import symbolic, jitframe
from rpython.jit.backend.llsupport.symbolic import WORD
from rpython.jit.backend.llsupport.memcpy import memcpy_fn
from rpython.jit.backend.llsupport.descr import SizeDescr, ArrayDescr, FieldDescr
from rpython.jit.backend.llsupport.descr import GcCache, get_field_descr
from rpython.jit.backend.llsupport.descr import get_array_descr
from rpython.jit.backend.llsupport.descr import get_call_descr
from rpython.jit.backend.llsupport.descr import unpack_arraydescr
from rpython.jit.backend.llsupport.rewrite import GcRewriterAssembler
from rpython.jit.codewriter.effectinfo import EffectInfo

# ____________________________________________________________

class GcLLDescription(GcCache):

    def __init__(self, gcdescr, translator=None, rtyper=None):
        GcCache.__init__(self, translator is not None, rtyper)
        self.gcdescr = gcdescr
        if translator and translator.config.translation.gcremovetypeptr:
            self.fielddescr_vtable = None
        else:
            self.fielddescr_vtable = get_field_descr(self, rclass.OBJECT,
                                                     'typeptr')
        self._generated_functions = []
        self.memcpy_fn = memcpy_fn
        self.memcpy_descr = get_call_descr(self,
            [lltype.Signed, lltype.Signed, lltype.Signed], lltype.Void,
            EffectInfo([], [], [], [], [], [], EffectInfo.EF_CANNOT_RAISE,
                can_collect=False))

    def _setup_str(self):
        self.str_descr     = get_array_descr(self, rstr.STR)
        self.unicode_descr = get_array_descr(self, rstr.UNICODE)
        self.str_hash_descr     = get_field_descr(self, rstr.STR,     'hash')
        self.unicode_hash_descr = get_field_descr(self, rstr.UNICODE, 'hash')

    def generate_function(self, funcname, func, ARGS, RESULT=llmemory.GCREF):
        """Generates a variant of malloc with the given name and the given
        arguments.  It should return NULL if out of memory.  If it raises
        anything, it must be an optional MemoryError.
        """
        FUNCPTR = lltype.Ptr(lltype.FuncType(ARGS, RESULT))
        # Note: the call may invoke the GC, which may run finalizers.
        # Finalizers are constrained in what they can do, but we can't
        # really express that in a useful way here.
        descr = get_call_descr(self, ARGS, RESULT, EffectInfo.MOST_GENERAL)
        setattr(self, funcname, func)
        setattr(self, funcname + '_FUNCPTR', FUNCPTR)
        setattr(self, funcname + '_descr', descr)
        self._generated_functions.append(funcname)

    @specialize.arg(1)
    def get_malloc_fn(self, funcname):
        func = getattr(self, funcname)
        FUNC = getattr(self, funcname + '_FUNCPTR')
        return llhelper(FUNC, func)

    @specialize.arg(1)
    def get_malloc_fn_addr(self, funcname):
        ll_func = self.get_malloc_fn(funcname)
        return ptr2int(ll_func)

    def _freeze_(self):
        return True
    def initialize(self):
        pass
    def can_use_nursery_malloc(self, size):
        return False
    def has_write_barrier_class(self):
        return None
    def get_nursery_free_addr(self):
        raise NotImplementedError
    def get_nursery_top_addr(self):
        raise NotImplementedError

    def freeing_block(self, rawstart, rawstop):
        pass

    def gc_malloc(self, sizedescr):
        """Blackhole: do a 'bh_new'.  Also used for 'bh_new_with_vtable',
        with the vtable pointer set manually afterwards."""
        assert isinstance(sizedescr, SizeDescr)
        return self._bh_malloc(sizedescr)

    def gc_malloc_array(self, num_elem, arraydescr):
        assert isinstance(arraydescr, ArrayDescr)
        return self._bh_malloc_array(num_elem, arraydescr)

    def gc_malloc_str(self, num_elem):
        return self._bh_malloc_array(num_elem, self.str_descr)

    def gc_malloc_unicode(self, num_elem):
        return self._bh_malloc_array(num_elem, self.unicode_descr)

    def rewrite_assembler(self, cpu, operations, gcrefs_output_list):
        rewriter = GcRewriterAssembler(self, cpu)
        newops = rewriter.rewrite(operations, gcrefs_output_list)
        return newops

    @specialize.memo()
    def getframedescrs(self, cpu):
        descrs = JitFrameDescrs()
        descrs.arraydescr = cpu.arraydescrof(jitframe.JITFRAME)
        for name in ['jf_descr', 'jf_guard_exc', 'jf_force_descr',
                     'jf_frame_info', 'jf_gcmap',
                     'jf_savedata', 'jf_forward']:
            setattr(descrs, name, cpu.fielddescrof(jitframe.JITFRAME, name))
        descrs.jfi_frame_size = cpu.fielddescrof(jitframe.JITFRAMEINFO,
                                                  'jfi_frame_size')
        descrs.jfi_frame_depth = cpu.fielddescrof(jitframe.JITFRAMEINFO,
                                                  'jfi_frame_depth')
        return descrs

    def getarraydescr_for_frame(self, type):
        """ This functions retuns an arraydescr of type for the JITFRAME"""
        raise NotImplementedError

    def malloc_jitframe(self, frame_info):
        """ Allocate a new frame, overwritten by tests
        """
        return jitframe.JITFRAME.allocate(frame_info)

    def make_gcref_tracer(self, array_base_addr, gcrefs):
        # for tests, or for Boehm.  Overridden for framework GCs
        from rpython.jit.backend.llsupport import gcreftracer
        return gcreftracer.make_boehm_tracer(array_base_addr, gcrefs)

    def clear_gcref_tracer(self, tracer):
        pass    # nothing needed unless overridden

class JitFrameDescrs:
    def _freeze_(self):
        return True

# ____________________________________________________________

class GcLLDescr_boehm(GcLLDescription):
    kind                  = 'boehm'
    malloc_zero_filled    = True
    moving_gc             = False
    round_up              = False
    write_barrier_descr   = None
    fielddescr_tid        = None
    gcrootmap             = None
    str_type_id           = 0
    unicode_type_id       = 0
    get_malloc_slowpath_addr = None
    supports_guard_gc_type   = False

    def is_shadow_stack(self):
        return False

    @classmethod
    def configure_boehm_once(cls):
        """ Configure boehm only once, since we don't cache failures
        """
        if hasattr(cls, 'malloc_fn_ptr'):
            return cls.malloc_fn_ptr
        from rpython.rtyper.tool import rffi_platform
        compilation_info = rffi_platform.configure_boehm()

        # on some platform GC_init is required before any other
        # GC_* functions, call it here for the benefit of tests
        # XXX move this to tests
        init_fn_ptr = rffi.llexternal("GC_init",
                                      [], lltype.Void,
                                      compilation_info=compilation_info,
                                      sandboxsafe=True,
                                      _nowrapper=True)
        init_fn_ptr()

        # Versions 6.x of libgc needs to use GC_local_malloc().
        # Versions 7.x of libgc removed this function; GC_malloc() has
        # the same behavior if libgc was compiled with
        # THREAD_LOCAL_ALLOC.
        class CConfig:
            _compilation_info_ = compilation_info
            HAS_LOCAL_MALLOC = rffi_platform.Has("GC_local_malloc")
        config = rffi_platform.configure(CConfig)
        if config['HAS_LOCAL_MALLOC']:
            GC_MALLOC = "GC_local_malloc"
        else:
            GC_MALLOC = "GC_malloc"
        malloc_fn_ptr = rffi.llexternal(GC_MALLOC,
                                        [lltype.Signed], # size_t, but good enough
                                        llmemory.GCREF,
                                        compilation_info=compilation_info,
                                        sandboxsafe=True,
                                        _nowrapper=True)
        cls.malloc_fn_ptr = malloc_fn_ptr
        return malloc_fn_ptr

    def __init__(self, gcdescr, translator, rtyper):
        GcLLDescription.__init__(self, gcdescr, translator, rtyper)
        # grab a pointer to the Boehm 'malloc' function
        self.malloc_fn_ptr = self.configure_boehm_once()
        self._setup_str()
        self._make_functions()
        self.memory = 0

    def _make_functions(self):

        def malloc_fixedsize(size):
            return self.malloc_fn_ptr(size)
        self.generate_function('malloc_fixedsize', malloc_fixedsize,
                               [lltype.Signed])

        def malloc_array(basesize, num_elem, itemsize, ofs_length):
            try:
                totalsize = ovfcheck(basesize + ovfcheck(itemsize * num_elem))
            except OverflowError:
                return lltype.nullptr(llmemory.GCREF.TO)
            res = self.malloc_fn_ptr(totalsize)
            if res:
                arrayptr = rffi.cast(rffi.CArrayPtr(lltype.Signed), res)
                arrayptr[ofs_length/WORD] = num_elem
            return res
        self.generate_function('malloc_array', malloc_array,
                               [lltype.Signed] * 4)

    def _bh_malloc(self, sizedescr):
        return self.malloc_fixedsize(sizedescr.size)

    def _bh_malloc_array(self, num_elem, arraydescr):
        return self.malloc_array(arraydescr.basesize, num_elem,
                                 arraydescr.itemsize,
                                 arraydescr.lendescr.offset)

# ____________________________________________________________
# All code below is for the hybrid or minimark GC

class GcRootMap_shadowstack(object):
    is_shadow_stack = True

    def __init__(self, gcdescr):
        pass

    def register_asm_addr(self, start, mark):
        pass

    def get_root_stack_top_addr(self):
        rst_addr = llop.gc_adr_of_root_stack_top(llmemory.Address)
        return rffi.cast(lltype.Signed, rst_addr)

class WriteBarrierDescr(AbstractDescr):
    def __init__(self, gc_ll_descr):
        self.llop1 = gc_ll_descr.llop1
        self.WB_FUNCPTR = gc_ll_descr.WB_FUNCPTR
        self.fielddescr_tid = gc_ll_descr.fielddescr_tid
        #
        GCClass = gc_ll_descr.GCClass
        if GCClass is None:     # for tests
            return
        self.jit_wb_if_flag = GCClass.JIT_WB_IF_FLAG
        self.jit_wb_if_flag_byteofs, self.jit_wb_if_flag_singlebyte = (
            self.extract_flag_byte(self.jit_wb_if_flag))
        #
        if hasattr(GCClass, 'JIT_WB_CARDS_SET'):
            self.jit_wb_cards_set = GCClass.JIT_WB_CARDS_SET
            self.jit_wb_card_page_shift = GCClass.JIT_WB_CARD_PAGE_SHIFT
            self.jit_wb_cards_set_byteofs, self.jit_wb_cards_set_singlebyte = (
                self.extract_flag_byte(self.jit_wb_cards_set))
            #
            # the x86 backend uses the following "accidental" facts to
            # avoid one instruction:
            assert self.jit_wb_cards_set_byteofs == self.jit_wb_if_flag_byteofs
            assert self.jit_wb_cards_set_singlebyte == -0x80
        else:
            self.jit_wb_cards_set = 0

    def extract_flag_byte(self, flag_word):
        # if convenient for the backend, we compute the info about
        # the flag as (byte-offset, single-byte-flag).
        import struct
        value = struct.pack(lltype.SignedFmt, flag_word)
        assert value.count('\x00') == len(value) - 1    # only one byte is != 0
        i = 0
        while value[i] == '\x00': i += 1
        return (i, struct.unpack('b', value[i])[0])

    def get_write_barrier_fn(self, cpu):
        llop1 = self.llop1
        funcptr = llop1.get_write_barrier_failing_case(self.WB_FUNCPTR)
        funcaddr = llmemory.cast_ptr_to_adr(funcptr)
        return cpu.cast_adr_to_int(funcaddr)

    def get_write_barrier_from_array_fn(self, cpu):
        # returns a function with arguments [array, index, newvalue]
        llop1 = self.llop1
        funcptr = llop1.get_write_barrier_from_array_failing_case(
            self.WB_FUNCPTR)
        funcaddr = llmemory.cast_ptr_to_adr(funcptr)
        return cpu.cast_adr_to_int(funcaddr)    # this may return 0

    def has_write_barrier_from_array(self, cpu):
        return self.get_write_barrier_from_array_fn(cpu) != 0


class GcLLDescr_framework(GcLLDescription):
    DEBUG = False    # forced to True by x86/test/test_zrpy_gc.py
    kind = 'framework'
    round_up = True
    layoutbuilder = None
    supports_guard_gc_type = True

    def is_shadow_stack(self):
        return self.gcrootmap.is_shadow_stack

    def __init__(self, gcdescr, translator, rtyper, llop1=llop,
                 really_not_translated=False):
        GcLLDescription.__init__(self, gcdescr, translator, rtyper)
        self.translator = translator
        self.llop1 = llop1
        if really_not_translated:
            assert not self.translate_support_code  # but half does not work
            self._initialize_for_tests()
        else:
            assert self.translate_support_code,"required with the framework GC"
            self._check_valid_gc()
            self._make_layoutbuilder()
            self._make_gcrootmap()
            self._setup_gcclass()
            self._setup_tid()
            self._setup_guard_is_object()
        self._setup_write_barrier()
        self._setup_str()
        self._make_functions(really_not_translated)

    def _make_gcrootmap(self):
        # to find roots in the assembler, make a GcRootMap
        name = self.gcdescr.config.translation.gcrootfinder
        try:
            cls = globals()['GcRootMap_' + name]
        except KeyError:
            raise NotImplementedError("--gcrootfinder=%s not implemented"
                                      " with the JIT" % (name,))
        gcrootmap = cls(self.gcdescr)
        self.gcrootmap = gcrootmap

    def _initialize_for_tests(self):
        self.layoutbuilder = None
        self.fielddescr_tid = FieldDescr("test_tid",0,8,0)
        self.max_size_of_young_obj = 1000
        self.GCClass = None

    def _check_valid_gc(self):
        # we need the hybrid or minimark GC for rgc._make_sure_does_not_move()
        # to work.  'hybrid' could work but isn't tested with the JIT.
        if self.gcdescr.config.translation.gc not in ('minimark',
                                                      'incminimark'):
            raise NotImplementedError("--gc=%s not implemented with the JIT" %
                                      (self.gcdescr.config.translation.gc,))

    def _make_layoutbuilder(self):
        # make a TransformerLayoutBuilder and save it on the translator
        # where it can be fished and reused by the FrameworkGCTransformer
        from rpython.memory.gctransform import framework
        translator = self.translator
        self.layoutbuilder = framework.TransformerLayoutBuilder(translator)
        self.layoutbuilder.delay_encoding()
        if not hasattr(translator, '_jit2gc'):
            translator._jit2gc = {}
        translator._jit2gc['layoutbuilder'] = self.layoutbuilder

    def _setup_gcclass(self):
        from rpython.memory.gcheader import GCHeaderBuilder
        self.GCClass = self.layoutbuilder.GCClass
        self.moving_gc = self.GCClass.moving_gc
        self.malloc_zero_filled = self.GCClass.malloc_zero_filled
        self.HDRPTR = lltype.Ptr(self.GCClass.HDR)
        self.gcheaderbuilder = GCHeaderBuilder(self.HDRPTR.TO)
        self.max_size_of_young_obj = self.GCClass.JIT_max_size_of_young_obj()
        self.minimal_size_in_nursery=self.GCClass.JIT_minimal_size_in_nursery()

        # for the fast path of mallocs, the following must be true, at least
        assert self.GCClass.inline_simple_malloc
        assert self.GCClass.inline_simple_malloc_varsize

    def _setup_tid(self):
        self.fielddescr_tid = get_field_descr(self, self.GCClass.HDR, 'tid')
        frame_tid = self.layoutbuilder.get_type_id(jitframe.JITFRAME)
        self.translator._jit2gc['frame_tid'] = frame_tid

    def _setup_write_barrier(self):
        self.WB_FUNCPTR = lltype.Ptr(lltype.FuncType(
            [llmemory.Address], lltype.Void))
        self.write_barrier_descr = WriteBarrierDescr(self)

    def _make_functions(self, really_not_translated):
        from rpython.memory.gctypelayout import check_typeid
        llop1 = self.llop1
        (self.standard_array_basesize, _, self.standard_array_length_ofs) = \
             symbolic.get_array_token(lltype.GcArray(lltype.Signed),
                                      not really_not_translated)

        def malloc_nursery_slowpath(size):
            """Allocate 'size' null bytes out of the nursery.
            Note that the fast path is typically inlined by the backend."""
            assert size >= self.minimal_size_in_nursery
            if self.DEBUG:
                self._random_usage_of_xmm_registers()
            type_id = rffi.cast(llgroup.HALFWORD, 0)    # missing here
            return llop1.do_malloc_fixedsize(llmemory.GCREF,
                                             type_id, size,
                                             False, False, False)

        self.generate_function('malloc_nursery', malloc_nursery_slowpath,
                               [lltype.Signed])

        def malloc_array(itemsize, tid, num_elem):
            """Allocate an array with a variable-size num_elem.
            Only works for standard arrays."""
            assert num_elem >= 0, 'num_elem should be >= 0'
            type_id = llop.extract_ushort(llgroup.HALFWORD, tid)
            check_typeid(type_id)
            return llop1.do_malloc_varsize_clear(
                llmemory.GCREF,
                type_id, num_elem, self.standard_array_basesize, itemsize,
                self.standard_array_length_ofs)
        self.generate_function('malloc_array', malloc_array,
                               [lltype.Signed] * 3)

        def malloc_array_nonstandard(basesize, itemsize, lengthofs, tid,
                                     num_elem):
            """For the rare case of non-standard arrays, i.e. arrays where
            self.standard_array_{basesize,length_ofs} is wrong.  It can
            occur e.g. with arrays of floats on Win32."""
            type_id = llop.extract_ushort(llgroup.HALFWORD, tid)
            check_typeid(type_id)
            return llop1.do_malloc_varsize_clear(
                llmemory.GCREF,
                type_id, num_elem, basesize, itemsize, lengthofs)
        self.generate_function('malloc_array_nonstandard',
                               malloc_array_nonstandard,
                               [lltype.Signed] * 5)

        str_type_id    = self.str_descr.tid
        str_basesize   = self.str_descr.basesize
        str_itemsize   = self.str_descr.itemsize
        str_ofs_length = self.str_descr.lendescr.offset
        unicode_type_id    = self.unicode_descr.tid
        unicode_basesize   = self.unicode_descr.basesize
        unicode_itemsize   = self.unicode_descr.itemsize
        unicode_ofs_length = self.unicode_descr.lendescr.offset

        def malloc_str(length):
            type_id = llop.extract_ushort(llgroup.HALFWORD, str_type_id)
            return llop1.do_malloc_varsize(
                llmemory.GCREF,
                type_id, length, str_basesize, str_itemsize,
                str_ofs_length)
        self.generate_function('malloc_str', malloc_str,
                               [lltype.Signed])

        def malloc_unicode(length):
            type_id = llop.extract_ushort(llgroup.HALFWORD, unicode_type_id)
            return llop1.do_malloc_varsize(
                llmemory.GCREF,
                type_id, length, unicode_basesize, unicode_itemsize,
                unicode_ofs_length)
        self.generate_function('malloc_unicode', malloc_unicode,
                               [lltype.Signed])

        # Never called as far as I can tell, but there for completeness:
        # allocate a fixed-size object, but not in the nursery, because
        # it is too big.
        def malloc_big_fixedsize(size, tid):
            if self.DEBUG:
                self._random_usage_of_xmm_registers()
            type_id = llop.extract_ushort(llgroup.HALFWORD, tid)
            check_typeid(type_id)
            return llop1.do_malloc_fixedsize_clear(llmemory.GCREF,
                                                   type_id, size,
                                                   False, False, False)
        self.generate_function('malloc_big_fixedsize', malloc_big_fixedsize,
                               [lltype.Signed] * 2)

    def _bh_malloc(self, sizedescr):
        from rpython.memory.gctypelayout import check_typeid
        llop1 = self.llop1
        type_id = llop.extract_ushort(llgroup.HALFWORD, sizedescr.tid)
        check_typeid(type_id)
        return llop1.do_malloc_fixedsize_clear(llmemory.GCREF,
                                               type_id, sizedescr.size,
                                               False, False, False)

    def _bh_malloc_array(self, num_elem, arraydescr):
        from rpython.memory.gctypelayout import check_typeid
        llop1 = self.llop1
        type_id = llop.extract_ushort(llgroup.HALFWORD, arraydescr.tid)
        check_typeid(type_id)
        return llop1.do_malloc_varsize_clear(llmemory.GCREF,
                                             type_id, num_elem,
                                             arraydescr.basesize,
                                             arraydescr.itemsize,
                                             arraydescr.lendescr.offset)


    class ForTestOnly:
        pass
    for_test_only = ForTestOnly()
    for_test_only.x = 1.23

    def _random_usage_of_xmm_registers(self):
        x0 = self.for_test_only.x
        x1 = x0 * 0.1
        x2 = x0 * 0.2
        x3 = x0 * 0.3
        self.for_test_only.x = x0 + x1 + x2 + x3

    def get_nursery_free_addr(self):
        nurs_addr = llop.gc_adr_of_nursery_free(llmemory.Address)
        return rffi.cast(lltype.Signed, nurs_addr)

    def get_nursery_top_addr(self):
        nurs_top_addr = llop.gc_adr_of_nursery_top(llmemory.Address)
        return rffi.cast(lltype.Signed, nurs_top_addr)

    def initialize(self):
        pass
        #self.gcrootmap.initialize()

    def init_size_descr(self, S, descr):
        if not isinstance(S, lltype.GcStruct):
            return
        if self.layoutbuilder is not None:
            type_id = self.layoutbuilder.get_type_id(S)
            descr.tid = llop.combine_ushort(lltype.Signed, type_id, 0)

    def init_array_descr(self, A, descr):
        if not isinstance(A, (lltype.GcArray, lltype.GcStruct)):
            return
        if self.layoutbuilder is not None:
            type_id = self.layoutbuilder.get_type_id(A)
            descr.tid = llop.combine_ushort(lltype.Signed, type_id, 0)

    def can_use_nursery_malloc(self, size):
        return size < self.max_size_of_young_obj

    def has_write_barrier_class(self):
        return WriteBarrierDescr

    def get_malloc_slowpath_addr(self):
        return self.get_malloc_fn_addr('malloc_nursery')

    def get_malloc_slowpath_array_addr(self):
        return self.get_malloc_fn_addr('malloc_array')

    def get_typeid_from_classptr_if_gcremovetypeptr(self, classptr):
        """Returns the typeid corresponding from a vtable pointer 'classptr'.
        This function only works if cpu.vtable_offset is None, i.e. in
        a translation with --gcremovetypeptr.
         """
        from rpython.memory.gctypelayout import GCData
        assert self.gcdescr.config.translation.gcremovetypeptr

        # hard-coded assumption: to go from an object to its class
        # we would use the following algorithm:
        #   - read the typeid from mem(locs[0]), i.e. at offset 0;
        #     this is a complete word (N=4 bytes on 32-bit, N=8 on
        #     64-bits)
        #   - keep the lower half of what is read there (i.e.
        #     truncate to an unsigned 'N / 2' bytes value)
        #   - multiply by 4 (on 32-bits only) and use it as an
        #     offset in type_info_group
        #   - add 16/32 bytes, to go past the TYPE_INFO structure
        # here, we have to go back from 'classptr' back to the typeid,
        # so we do (part of) these computations in reverse.

        sizeof_ti = rffi.sizeof(GCData.TYPE_INFO)
        type_info_group = llop.gc_get_type_info_group(llmemory.Address)
        type_info_group = rffi.cast(lltype.Signed, type_info_group)
        expected_typeid = classptr - sizeof_ti - type_info_group
        if WORD == 4:
            expected_typeid >>= 2
        return expected_typeid

    def get_translated_info_for_typeinfo(self):
        from rpython.memory.gctypelayout import GCData
        type_info_group = llop.gc_get_type_info_group(llmemory.Address)
        type_info_group = rffi.cast(lltype.Signed, type_info_group)
        if WORD == 4:
            shift_by = 2
        elif WORD == 8:
            shift_by = 0
        sizeof_ti = rffi.sizeof(GCData.TYPE_INFO)
        return (type_info_group, shift_by, sizeof_ti)

    def _setup_guard_is_object(self):
        from rpython.memory.gctypelayout import GCData, T_IS_RPYTHON_INSTANCE
        import struct
        infobits_offset, _ = symbolic.get_field_token(GCData.TYPE_INFO,
                                                      'infobits', True)
        # compute the offset to the actual *byte*, and the byte mask
        mask = struct.pack("l", T_IS_RPYTHON_INSTANCE)
        assert mask.count('\x00') == len(mask) - 1
        infobits_offset_plus = 0
        while mask.startswith('\x00'):
            infobits_offset_plus += 1
            mask = mask[1:]
        self._infobits_offset = infobits_offset
        self._infobits_offset_plus = infobits_offset_plus
        self._T_IS_RPYTHON_INSTANCE_BYTE = ord(mask[0])

    def get_translated_info_for_guard_is_object(self):
        infobits_offset = rffi.cast(lltype.Signed, self._infobits_offset)
        infobits_offset += self._infobits_offset_plus
        return (infobits_offset, self._T_IS_RPYTHON_INSTANCE_BYTE)

    def get_actual_typeid(self, gcptr):
        # Read the whole GC header word.  Return the typeid from the
        # lower half-word.
        hdr = rffi.cast(self.HDRPTR, gcptr)
        type_id = llop.extract_ushort(llgroup.HALFWORD, hdr.tid)
        return llop.combine_ushort(lltype.Signed, type_id, 0)

    def check_is_object(self, gcptr):
        # read the typeid, fetch one byte of the field 'infobits' from
        # the big typeinfo table, and check the flag 'T_IS_RPYTHON_INSTANCE'.
        typeid = self.get_actual_typeid(gcptr)
        #
        base_type_info, shift_by, sizeof_ti = (
            self.get_translated_info_for_typeinfo())
        infobits_offset, IS_OBJECT_FLAG = (
            self.get_translated_info_for_guard_is_object())
        p = base_type_info + (typeid << shift_by) + infobits_offset
        p = rffi.cast(rffi.CCHARP, p)
        return (ord(p[0]) & IS_OBJECT_FLAG) != 0

    def make_gcref_tracer(self, array_base_addr, gcrefs):
        from rpython.jit.backend.llsupport import gcreftracer
        return gcreftracer.make_framework_tracer(array_base_addr, gcrefs)

    def clear_gcref_tracer(self, tracer):
        tracer.array_length = 0

# ____________________________________________________________

def get_ll_description(gcdescr, translator=None, rtyper=None):
    # translator is None if translate_support_code is False.
    if gcdescr is not None:
        name = gcdescr.config.translation.gctransformer
    else:
        name = "boehm"
    try:
        cls = globals()['GcLLDescr_' + name]
    except KeyError:
        raise NotImplementedError("GC transformer %r not supported by "
                                  "the JIT backend" % (name,))
    return cls(gcdescr, translator, rtyper)
