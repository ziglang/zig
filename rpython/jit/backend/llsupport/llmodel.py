from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, rstr
from rpython.rtyper import rclass
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rtyper.annlowlevel import llhelper, MixLevelHelperAnnotator
from rpython.rtyper.annlowlevel import hlstr, hlunicode
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rlib.objectmodel import we_are_translated, specialize, compute_hash
from rpython.jit.metainterp import history, compile
from rpython.jit.metainterp.optimize import SpeculativeError
from rpython.jit.metainterp.support import adr2int, ptr2int
from rpython.jit.codewriter import longlong
from rpython.jit.backend.model import AbstractCPU
from rpython.jit.backend.llsupport import symbolic, jitframe
from rpython.jit.backend.llsupport.symbolic import WORD, unroll_basic_sizes
from rpython.jit.backend.llsupport.descr import (
    get_size_descr, get_field_descr, get_array_descr,
    get_call_descr, get_interiorfield_descr,
    FieldDescr, ArrayDescr, CallDescr, InteriorFieldDescr,
    FLAG_POINTER, FLAG_FLOAT)
from rpython.jit.backend.llsupport.memcpy import memset_fn
from rpython.jit.backend.llsupport import asmmemmgr, codemap
from rpython.rlib.unroll import unrolling_iterable


class AbstractLLCPU(AbstractCPU):
    HAS_CODEMAP = False

    done_with_this_frame_descr_int      = None   # overridden by pyjitpl.py
    done_with_this_frame_descr_float    = None
    done_with_this_frame_descr_ref      = None
    done_with_this_frame_descr_void     = None
    exit_frame_with_exception_descr_ref = None

    # can an ISA instruction handle a factor to the offset?
    load_supported_factors = (1,)

    vector_ext = None

    def __init__(self, rtyper, stats, opts, translate_support_code=False,
                 gcdescr=None):
        assert type(opts) is not bool
        self.opts = opts

        from rpython.jit.backend.llsupport.gc import get_ll_description
        AbstractCPU.__init__(self)
        self.rtyper = rtyper
        self.stats = stats
        self.translate_support_code = translate_support_code
        if translate_support_code and rtyper is not None:
            translator = rtyper.annotator.translator
            self.remove_gctypeptr = translator.config.translation.gcremovetypeptr
        else:
            translator = None
        self.gc_ll_descr = get_ll_description(gcdescr, translator, rtyper)
        # support_guard_gc_type indicates if a gc type of an object can be read.
        # In some states (boehm or x86 untranslated) the type is not known just yet,
        # because there are cases where it is not guarded. The precise place where it's not
        # is while inlining short preamble.
        self.supports_guard_gc_type = self.gc_ll_descr.supports_guard_gc_type
        if translator and translator.config.translation.gcremovetypeptr:
            self.vtable_offset = None
        else:
            self.vtable_offset, _ = symbolic.get_field_token(rclass.OBJECT,
                                                             'typeptr',
                                                        translate_support_code)
        self.subclassrange_min_offset, _ = symbolic.get_field_token(
            rclass.OBJECT_VTABLE, 'subclassrange_min', translate_support_code)
        if translate_support_code:
            self._setup_exception_handling_translated()
        else:
            self._setup_exception_handling_untranslated()
        self.asmmemmgr = asmmemmgr.AsmMemoryManager()
        if self.HAS_CODEMAP:
            self.codemap = codemap.CodemapStorage()
        self._setup_frame_realloc(translate_support_code)
        ad = self.gc_ll_descr.getframedescrs(self).arraydescr
        self.signedarraydescr = ad
        # the same as normal JITFRAME, however with an array of pointers
        self.refarraydescr = ArrayDescr(ad.basesize, ad.itemsize, ad.lendescr,
                                        FLAG_POINTER)
        if WORD == 4:
            self.floatarraydescr = ArrayDescr(ad.basesize, ad.itemsize * 2,
                                              ad.lendescr, FLAG_FLOAT)
        else:
            self.floatarraydescr = ArrayDescr(ad.basesize, ad.itemsize,
                                              ad.lendescr, FLAG_FLOAT)
        self.setup()
        self._debug_tls_errno_container = lltype.malloc(
            rffi.CArray(lltype.Signed), 7, flavor='raw', zero=True,
            track_allocation=False)
        self._debug_tls_errno_container[1] = 1234 # dummy thread ident

    def getarraydescr_for_frame(self, type):
        if type == history.FLOAT:
            descr = self.floatarraydescr
        elif type == history.REF:
            descr = self.refarraydescr
        else:
            descr = self.signedarraydescr
        return descr

    def setup(self):
        pass

    def finish_once(self):
        if self.HAS_CODEMAP:
            self.codemap.finish_once()

    def compile_loop(self, inputargs, operations, looptoken, jd_id=0,
                     unique_id=0, log=True, name='', logger=None):
        return self.assembler.assemble_loop(jd_id, unique_id, logger, name,
                                            inputargs, operations,
                                            looptoken, log)

    def stitch_bridge(self, faildescr, target):
        self.assembler.stitch_bridge(faildescr, target)

    def _setup_frame_realloc(self, translate_support_code):
        FUNC_TP = lltype.Ptr(lltype.FuncType([llmemory.GCREF, lltype.Signed],
                                             llmemory.GCREF))
        base_ofs = self.get_baseofs_of_frame_field()

        def realloc_frame(frame, size):
            try:
                if not we_are_translated():
                    assert not self._exception_emulator[0]
                frame = lltype.cast_opaque_ptr(jitframe.JITFRAMEPTR, frame)
                if size > frame.jf_frame_info.jfi_frame_depth:
                    # update the frame_info size, which is for whatever reason
                    # not up to date
                    frame.jf_frame_info.update_frame_depth(base_ofs, size)
                new_frame = jitframe.JITFRAME.allocate(frame.jf_frame_info)
                frame.jf_forward = new_frame
                i = 0
                while i < len(frame.jf_frame):
                    new_frame.jf_frame[i] = frame.jf_frame[i]
                    frame.jf_frame[i] = 0
                    i += 1
                new_frame.jf_savedata = frame.jf_savedata
                new_frame.jf_guard_exc = frame.jf_guard_exc
                # all other fields are empty
                llop.gc_writebarrier(lltype.Void, new_frame)
                return lltype.cast_opaque_ptr(llmemory.GCREF, new_frame)
            except Exception as e:
                print "Unhandled exception", e, "in realloc_frame"
                return lltype.nullptr(llmemory.GCREF.TO)

        def realloc_frame_crash(frame, size):
            print "frame", frame, "size", size
            return lltype.nullptr(llmemory.GCREF.TO)

        if not translate_support_code:
            fptr = llhelper(FUNC_TP, realloc_frame)
        else:
            FUNC = FUNC_TP.TO
            args_s = [lltype_to_annotation(ARG) for ARG in FUNC.ARGS]
            s_result = lltype_to_annotation(FUNC.RESULT)
            mixlevelann = MixLevelHelperAnnotator(self.rtyper)
            graph = mixlevelann.getgraph(realloc_frame, args_s, s_result)
            fptr = mixlevelann.graph2delayed(graph, FUNC)
            mixlevelann.finish()
        self.realloc_frame = ptr2int(fptr)

        if not translate_support_code:
            fptr = llhelper(FUNC_TP, realloc_frame_crash)
        else:
            FUNC = FUNC_TP.TO
            args_s = [lltype_to_annotation(ARG) for ARG in FUNC.ARGS]
            s_result = lltype_to_annotation(FUNC.RESULT)
            mixlevelann = MixLevelHelperAnnotator(self.rtyper)
            graph = mixlevelann.getgraph(realloc_frame_crash, args_s, s_result)
            fptr = mixlevelann.graph2delayed(graph, FUNC)
            mixlevelann.finish()
        self.realloc_frame_crash = ptr2int(fptr)

    def _setup_exception_handling_untranslated(self):
        # for running un-translated only, all exceptions occurring in the
        # llinterpreter are stored in '_exception_emulator', which is then
        # read back by the machine code reading at the address given by
        # pos_exception() and pos_exc_value().
        _exception_emulator = lltype.malloc(rffi.CArray(lltype.Signed), 2,
                                            zero=True, flavor='raw',
                                            immortal=True)
        self._exception_emulator = _exception_emulator

        def _store_exception(lle):
            self._last_exception = lle       # keepalive
            tp_i = rffi.cast(lltype.Signed, lle.args[0])
            v_i = rffi.cast(lltype.Signed, lle.args[1])
            _exception_emulator[0] = tp_i
            _exception_emulator[1] = v_i

        self.debug_ll_interpreter = LLInterpreter(self.rtyper)
        self.debug_ll_interpreter._store_exception = _store_exception

        def pos_exception():
            return rffi.cast(lltype.Signed, _exception_emulator)

        def pos_exc_value():
            return (rffi.cast(lltype.Signed, _exception_emulator) +
                    rffi.sizeof(lltype.Signed))

        self.pos_exception = pos_exception
        self.pos_exc_value = pos_exc_value
        self.insert_stack_check = lambda: (0, 0, 0)

    def _setup_exception_handling_translated(self):

        def pos_exception():
            addr = llop.get_exception_addr(llmemory.Address)
            return adr2int(addr)

        def pos_exc_value():
            addr = llop.get_exc_value_addr(llmemory.Address)
            return adr2int(addr)

        from rpython.rlib import rstack

        STACK_CHECK_SLOWPATH = lltype.Ptr(lltype.FuncType([lltype.Signed],
                                                          lltype.Void))
        def insert_stack_check():
            endaddr = rstack._stack_get_end_adr()
            lengthaddr = rstack._stack_get_length_adr()
            f = llhelper(STACK_CHECK_SLOWPATH, rstack.stack_check_slowpath)
            slowpathaddr = rffi.cast(lltype.Signed, f)
            return endaddr, lengthaddr, slowpathaddr

        self.pos_exception = pos_exception
        self.pos_exc_value = pos_exc_value
        self.insert_stack_check = insert_stack_check

    def grab_exc_value(self, deadframe):
        deadframe = lltype.cast_opaque_ptr(jitframe.JITFRAMEPTR, deadframe)
        return deadframe.jf_guard_exc

    def set_savedata_ref(self, deadframe, data):
        deadframe = lltype.cast_opaque_ptr(jitframe.JITFRAMEPTR, deadframe)
        deadframe.jf_savedata = data

    def get_savedata_ref(self, deadframe):
        deadframe = lltype.cast_opaque_ptr(jitframe.JITFRAMEPTR, deadframe)
        return deadframe.jf_savedata

    def free_loop_and_bridges(self, compiled_loop_token):
        AbstractCPU.free_loop_and_bridges(self, compiled_loop_token)
        # turn off all gcreftracers
        tracers = compiled_loop_token.asmmemmgr_gcreftracers
        if tracers is not None:
            compiled_loop_token.asmmemmgr_gcreftracers = None
            for tracer in tracers:
                self.gc_ll_descr.clear_gcref_tracer(tracer)
        # then free all blocks of code and raw data
        blocks = compiled_loop_token.asmmemmgr_blocks
        if blocks is not None:
            compiled_loop_token.asmmemmgr_blocks = None
            for rawstart, rawstop in blocks:
                self.gc_ll_descr.freeing_block(rawstart, rawstop)
                self.asmmemmgr.free(rawstart, rawstop)
                if self.HAS_CODEMAP:
                    self.codemap.free_asm_block(rawstart, rawstop)

    def force(self, addr_of_force_token):
        frame = rffi.cast(jitframe.JITFRAMEPTR, addr_of_force_token)
        frame = frame.resolve()
        frame.jf_descr = frame.jf_force_descr
        return lltype.cast_opaque_ptr(llmemory.GCREF, frame)

    def make_execute_token(self, *ARGS):
        # The JIT backend must generate functions with the following
        # signature: it takes the jitframe and the threadlocal_addr
        # as arguments, and it returns the (possibly reallocated) jitframe.
        # The backend can optimize OS_THREADLOCALREF_GET calls to return a
        # field of this threadlocal_addr, but only if 'translate_support_code':
        # in untranslated tests, threadlocal_addr is a dummy container
        # for errno tests only.
        FUNCPTR = lltype.Ptr(lltype.FuncType([llmemory.GCREF, llmemory.Address],
                                             llmemory.GCREF))

        lst = [(i, history.getkind(ARG)[0]) for i, ARG in enumerate(ARGS)]
        kinds = unrolling_iterable(lst)

        def execute_token(executable_token, *args):
            clt = executable_token.compiled_loop_token
            assert len(args) == clt._debug_nbargs
            #
            addr = executable_token._ll_function_addr
            func = rffi.cast(FUNCPTR, addr)
            #llop.debug_print(lltype.Void, ">>>> Entering", addr)
            frame_info = clt.frame_info
            frame = self.gc_ll_descr.malloc_jitframe(frame_info)
            ll_frame = lltype.cast_opaque_ptr(llmemory.GCREF, frame)
            locs = executable_token.compiled_loop_token._ll_initial_locs
            prev_interpreter = None   # help flow space
            if not self.translate_support_code:
                prev_interpreter = LLInterpreter.current_interpreter
                LLInterpreter.current_interpreter = self.debug_ll_interpreter
            try:
                for i, kind in kinds:
                    arg = args[i]
                    num = locs[i]
                    if kind == history.INT:
                        self.set_int_value(ll_frame, num, arg)
                    elif kind == history.FLOAT:
                        self.set_float_value(ll_frame, num, arg)
                    else:
                        assert kind == history.REF
                        self.set_ref_value(ll_frame, num, arg)
                if self.translate_support_code:
                    ll_threadlocal_addr = llop.threadlocalref_addr(
                        llmemory.Address)
                else:
                    ll_threadlocal_addr = rffi.cast(llmemory.Address,
                        self._debug_tls_errno_container)
                llop.gc_writebarrier(lltype.Void, ll_frame)
                ll_frame = func(ll_frame, ll_threadlocal_addr)
            finally:
                if not self.translate_support_code:
                    LLInterpreter.current_interpreter = prev_interpreter
            #llop.debug_print(lltype.Void, "<<<< Back")
            return ll_frame
        return execute_token

    def setup_descrs(self):
        return self.gc_ll_descr.setup_descrs()

    # ------------------- helpers and descriptions --------------------

    @staticmethod
    def _cast_int_to_gcref(x):
        # dangerous!  only use if you are sure no collection could occur
        # between reading the integer and casting it to a pointer
        return rffi.cast(llmemory.GCREF, x)

    @staticmethod
    def cast_gcref_to_int(x):
        return rffi.cast(lltype.Signed, x)

    @staticmethod
    def cast_int_to_adr(x):
        return rffi.cast(llmemory.Address, x)

    @staticmethod
    def cast_adr_to_int(x):
        return rffi.cast(lltype.Signed, x)

    @specialize.arg(2)
    def cast_int_to_ptr(self, x, TYPE):
        return rffi.cast(TYPE, x)

    def sizeof(self, S, vtable=lltype.nullptr(rclass.OBJECT_VTABLE)):
        return get_size_descr(self.gc_ll_descr, S, vtable)

    def fielddescrof(self, STRUCT, fieldname):
        return get_field_descr(self.gc_ll_descr, STRUCT, fieldname)

    def unpack_fielddescr(self, fielddescr):
        assert isinstance(fielddescr, FieldDescr)
        return fielddescr.offset
    unpack_fielddescr._always_inline_ = True

    def unpack_fielddescr_size(self, fielddescr):
        assert isinstance(fielddescr, FieldDescr)
        ofs = fielddescr.offset
        size = fielddescr.field_size
        sign = fielddescr.is_field_signed()
        return ofs, size, sign
    unpack_fielddescr_size._always_inline_ = True

    @specialize.memo()
    def arraydescrof(self, A):
        return get_array_descr(self.gc_ll_descr, A)

    def interiorfielddescrof(self, A, fieldname, arrayfieldname=None):
        return get_interiorfield_descr(self.gc_ll_descr, A, fieldname,
                                       arrayfieldname)

    def unpack_arraydescr(self, arraydescr):
        assert isinstance(arraydescr, ArrayDescr)
        return arraydescr.basesize
    unpack_arraydescr._always_inline_ = True

    def unpack_arraydescr_size(self, arraydescr):
        assert isinstance(arraydescr, ArrayDescr)
        ofs = arraydescr.basesize
        size = arraydescr.itemsize
        sign = arraydescr.is_item_signed()
        return ofs, size, sign
    unpack_arraydescr_size._always_inline_ = True

    def calldescrof(self, FUNC, ARGS, RESULT, extrainfo):
        return get_call_descr(self.gc_ll_descr, ARGS, RESULT, extrainfo)

    def calldescrof_dynamic(self, cif_description, extrainfo):
        from rpython.jit.backend.llsupport import ffisupport
        return ffisupport.get_call_descr_dynamic(self, cif_description,
                                                 extrainfo)

    def _calldescr_dynamic_for_tests(self, atypes, rtype,
                                     abiname='FFI_DEFAULT_ABI'):
        from rpython.jit.backend.llsupport import ffisupport
        return ffisupport.calldescr_dynamic_for_tests(self, atypes, rtype,
                                                      abiname)

    def get_latest_descr(self, deadframe):
        deadframe = lltype.cast_opaque_ptr(jitframe.JITFRAMEPTR, deadframe)
        descr = deadframe.jf_descr
        res = history.AbstractDescr.show(self, descr)
        if not we_are_translated():   # tests only: for missing
            if res is None:           # propagate_exception_descr
                raise MissingLatestDescrError
        assert isinstance(res, history.AbstractFailDescr)
        return res

    def _decode_pos(self, deadframe, index):
        descr = self.get_latest_descr(deadframe)
        return rffi.cast(lltype.Signed, descr.rd_locs[index]) * WORD

    @specialize.arg(2)
    def get_value_direct(self, deadframe, tp, index):
        if tp == 'i':
            return self.get_int_value_direct(deadframe, index * WORD)
        elif tp == 'r':
            return self.get_ref_value_direct(deadframe, index * WORD)
        elif tp == 'f':
            return self.get_float_value_direct(deadframe, index * WORD)
        else:
            assert False

    def get_int_value(self, deadframe, index):
        pos = self._decode_pos(deadframe, index)
        return self.get_int_value_direct(deadframe, pos)

    def get_int_value_direct(self, deadframe, pos):
        descr = self.gc_ll_descr.getframedescrs(self).arraydescr
        ofs = self.unpack_arraydescr(descr)
        return self.read_int_at_mem(deadframe, pos + ofs, WORD, 1)

    def get_ref_value(self, deadframe, index):
        pos = self._decode_pos(deadframe, index)
        return self.get_ref_value_direct(deadframe, pos)

    def get_ref_value_direct(self, deadframe, pos):
        descr = self.gc_ll_descr.getframedescrs(self).arraydescr
        ofs = self.unpack_arraydescr(descr)
        return self.read_ref_at_mem(deadframe, pos + ofs)

    def get_float_value(self, deadframe, index):
        pos = self._decode_pos(deadframe, index)
        return self.get_float_value_direct(deadframe, pos)

    def get_float_value_direct(self, deadframe, pos):
        descr = self.gc_ll_descr.getframedescrs(self).arraydescr
        ofs = self.unpack_arraydescr(descr)
        return self.read_float_at_mem(deadframe, pos + ofs)

    # ____________________ RAW PRIMITIVES ________________________

    @specialize.argtype(1)
    def read_int_at_mem(self, gcref, ofs, size, sign):
        for STYPE, UTYPE, itemsize in unroll_basic_sizes:
            if size == itemsize:
                if sign:
                    val = llop.raw_load(STYPE, gcref, ofs)
                    val = rffi.cast(lltype.Signed, val)
                else:
                    val = llop.raw_load(UTYPE, gcref, ofs)
                    val = rffi.cast(lltype.Signed, val)
                return val
        else:
            raise NotImplementedError("size = %d" % size)

    @specialize.argtype(1)
    def write_int_at_mem(self, gcref, ofs, size, newvalue):
        for TYPE, _, itemsize in unroll_basic_sizes:
            if size == itemsize:
                newvalue = rffi.cast(TYPE, newvalue)
                llop.raw_store(lltype.Void, gcref, ofs, newvalue)
                return
        else:
            raise NotImplementedError("size = %d" % size)

    @specialize.argtype(1)
    def read_ref_at_mem(self, gcref, ofs):
        return llop.raw_load(llmemory.GCREF, gcref, ofs)

    # non-@specialized: must only be called with llmemory.GCREF
    def write_ref_at_mem(self, gcref, ofs, newvalue):
        llop.raw_store(lltype.Void, gcref, ofs, newvalue)
        # the write barrier is implied above

    @specialize.argtype(1)
    def read_float_at_mem(self, gcref, ofs):
        return llop.raw_load(longlong.FLOATSTORAGE, gcref, ofs)

    @specialize.argtype(1)
    def write_float_at_mem(self, gcref, ofs, newvalue):
        llop.raw_store(lltype.Void, gcref, ofs, newvalue)
    write_float_at_mem._annenforceargs_ = [None, None, None, longlong.r_float_storage]

    # ____________________________________________________________

    def set_int_value(self, newframe, index, value):
        """ Note that we keep index multiplied by WORD here mostly
        for completeness with get_int_value and friends
        """
        descr = self.gc_ll_descr.getframedescrs(self).arraydescr
        ofs = self.unpack_arraydescr(descr)
        self.write_int_at_mem(newframe, ofs + index, WORD, value)

    def set_ref_value(self, newframe, index, value):
        descr = self.gc_ll_descr.getframedescrs(self).arraydescr
        ofs = self.unpack_arraydescr(descr)
        self.write_ref_at_mem(newframe, ofs + index, value)

    def set_float_value(self, newframe, index, value):
        descr = self.gc_ll_descr.getframedescrs(self).arraydescr
        ofs = self.unpack_arraydescr(descr)
        self.write_float_at_mem(newframe, ofs + index, value)

    @specialize.arg(1)
    def get_ofs_of_frame_field(self, name):
        descrs = self.gc_ll_descr.getframedescrs(self)
        ofs = self.unpack_fielddescr(getattr(descrs, name))
        return ofs

    def get_baseofs_of_frame_field(self):
        descrs = self.gc_ll_descr.getframedescrs(self)
        base_ofs = self.unpack_arraydescr(descrs.arraydescr)
        return base_ofs

    # ____________________________________________________________

    def check_is_object(self, gcptr):
        """Check if the given, non-null gcptr refers to an rclass.OBJECT
        or not at all (an unrelated GcStruct or a GcArray).  Only usable
        in the llgraph backend, or after translation of a real backend."""
        assert self.supports_guard_gc_type
        return self.gc_ll_descr.check_is_object(gcptr)

    def get_actual_typeid(self, gcptr):
        """Fetch the actual typeid of the given gcptr, as an integer.
        Only usable in the llgraph backend, or after translation of a
        real backend."""
        assert self.supports_guard_gc_type
        return self.gc_ll_descr.get_actual_typeid(gcptr)

    def protect_speculative_field(self, gcptr, fielddescr):
        if not gcptr:
            raise SpeculativeError
        if self.supports_guard_gc_type:
            assert isinstance(fielddescr, FieldDescr)
            sizedescr = fielddescr.parent_descr
            if sizedescr.is_object():
                if (not self.check_is_object(gcptr) or
                    not sizedescr.is_valid_class_for(gcptr)):
                    raise SpeculativeError
            else:
                if self.get_actual_typeid(gcptr) != sizedescr.tid:
                    raise SpeculativeError

    def protect_speculative_array(self, gcptr, arraydescr):
        if not gcptr:
            raise SpeculativeError
        if self.supports_guard_gc_type:
            assert isinstance(arraydescr, ArrayDescr)
            if self.get_actual_typeid(gcptr) != arraydescr.tid:
                raise SpeculativeError

    def protect_speculative_string(self, gcptr):
        self.protect_speculative_array(gcptr, self.gc_ll_descr.str_descr)

    def protect_speculative_unicode(self, gcptr):
        self.protect_speculative_array(gcptr, self.gc_ll_descr.unicode_descr)

    # ____________________________________________________________

    def bh_arraylen_gc(self, array, arraydescr):
        assert isinstance(arraydescr, ArrayDescr)
        ofs = arraydescr.lendescr.offset
        return self.read_int_at_mem(array, ofs, WORD, 1)

    @specialize.argtype(1)
    def bh_getarrayitem_gc_i(self, gcref, itemindex, arraydescr):
        ofs, size, sign = self.unpack_arraydescr_size(arraydescr)
        return self.read_int_at_mem(gcref, ofs + itemindex * size, size,
                                    sign)

    def bh_getarrayitem_gc_r(self, gcref, itemindex, arraydescr):
        ofs = self.unpack_arraydescr(arraydescr)
        return self.read_ref_at_mem(gcref, itemindex * WORD + ofs)

    @specialize.argtype(1)
    def bh_getarrayitem_gc_f(self, gcref, itemindex, arraydescr):
        ofs = self.unpack_arraydescr(arraydescr)
        fsize = rffi.sizeof(longlong.FLOATSTORAGE)
        return self.read_float_at_mem(gcref, itemindex * fsize + ofs)

    @specialize.argtype(1)
    def bh_setarrayitem_gc_i(self, gcref, itemindex, newvalue, arraydescr):
        ofs, size, sign = self.unpack_arraydescr_size(arraydescr)
        self.write_int_at_mem(gcref, ofs + itemindex * size, size, newvalue)

    def bh_setarrayitem_gc_r(self, gcref, itemindex, newvalue, arraydescr):
        ofs = self.unpack_arraydescr(arraydescr)
        self.write_ref_at_mem(gcref, itemindex * WORD + ofs, newvalue)

    @specialize.argtype(1)
    def bh_setarrayitem_gc_f(self, gcref, itemindex, newvalue, arraydescr):
        ofs = self.unpack_arraydescr(arraydescr)
        fsize = rffi.sizeof(longlong.FLOATSTORAGE)
        self.write_float_at_mem(gcref, ofs + itemindex * fsize, newvalue)

    bh_setarrayitem_raw_i = bh_setarrayitem_gc_i
    bh_setarrayitem_raw_f = bh_setarrayitem_gc_f

    bh_getarrayitem_raw_i = bh_getarrayitem_gc_i
    bh_getarrayitem_raw_f = bh_getarrayitem_gc_f

    def bh_getinteriorfield_gc_i(self, gcref, itemindex, descr):
        assert isinstance(descr, InteriorFieldDescr)
        ofs, size, _ = self.unpack_arraydescr_size(descr.arraydescr)
        fldofs, fldsize, sign = self.unpack_fielddescr_size(descr.fielddescr)
        ofs += itemindex * size + fldofs
        return self.read_int_at_mem(gcref, ofs, fldsize, sign)

    def bh_getinteriorfield_gc_r(self, gcref, itemindex, descr):
        assert isinstance(descr, InteriorFieldDescr)
        ofs, size, _ = self.unpack_arraydescr_size(descr.arraydescr)
        ofs += descr.fielddescr.offset
        fullofs = itemindex * size + ofs
        return self.read_ref_at_mem(gcref, fullofs)

    def bh_getinteriorfield_gc_f(self, gcref, itemindex, descr):
        assert isinstance(descr, InteriorFieldDescr)
        ofs, size, _ = self.unpack_arraydescr_size(descr.arraydescr)
        ofs += descr.fielddescr.offset
        fullofs = itemindex * size + ofs
        return self.read_float_at_mem(gcref, fullofs)

    def bh_setinteriorfield_gc_i(self, gcref, itemindex, newvalue, descr):
        assert isinstance(descr, InteriorFieldDescr)
        ofs, size, _ = self.unpack_arraydescr_size(descr.arraydescr)
        fldofs, fldsize, _ = self.unpack_fielddescr_size(descr.fielddescr)
        ofs += itemindex * size + fldofs
        self.write_int_at_mem(gcref, ofs, fldsize, newvalue)

    def bh_setinteriorfield_gc_r(self, gcref, itemindex, newvalue, descr):
        assert isinstance(descr, InteriorFieldDescr)
        ofs, size, _ = self.unpack_arraydescr_size(descr.arraydescr)
        ofs += itemindex * size + descr.fielddescr.offset
        self.write_ref_at_mem(gcref, ofs, newvalue)

    def bh_setinteriorfield_gc_f(self, gcref, itemindex, newvalue, descr):
        assert isinstance(descr, InteriorFieldDescr)
        ofs, size, _ = self.unpack_arraydescr_size(descr.arraydescr)
        ofs += itemindex * size + descr.fielddescr.offset
        self.write_float_at_mem(gcref, ofs, newvalue)

    def bh_strlen(self, string):
        s = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), string)
        return len(s.chars)

    def bh_unicodelen(self, string):
        u = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), string)
        return len(u.chars)

    def bh_strhash(self, string):
        s = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), string)
        return compute_hash(hlstr(s))

    def bh_unicodehash(self, string):
        u = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), string)
        return compute_hash(hlunicode(u))

    def bh_strgetitem(self, string, index):
        s = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), string)
        return ord(s.chars[index])

    def bh_unicodegetitem(self, string, index):
        u = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), string)
        return ord(u.chars[index])

    @specialize.argtype(1)
    def bh_getfield_gc_i(self, struct, fielddescr):
        ofs, size, sign = self.unpack_fielddescr_size(fielddescr)
        if isinstance(lltype.typeOf(struct), lltype.Ptr):
            fielddescr.assert_correct_type(struct)
        return self.read_int_at_mem(struct, ofs, size, sign)

    @specialize.argtype(1)
    def bh_getfield_gc_r(self, struct, fielddescr):
        ofs = self.unpack_fielddescr(fielddescr)
        if isinstance(lltype.typeOf(struct), lltype.Ptr):
            fielddescr.assert_correct_type(struct)
        return self.read_ref_at_mem(struct, ofs)

    @specialize.argtype(1)
    def bh_getfield_gc_f(self, struct, fielddescr):
        ofs = self.unpack_fielddescr(fielddescr)
        if isinstance(lltype.typeOf(struct), lltype.Ptr):
            fielddescr.assert_correct_type(struct)
        return self.read_float_at_mem(struct, ofs)

    bh_getfield_raw_i = bh_getfield_gc_i
    bh_getfield_raw_r = bh_getfield_gc_r
    bh_getfield_raw_f = bh_getfield_gc_f

    @specialize.argtype(1)
    def bh_setfield_gc_i(self, struct, newvalue, fielddescr):
        ofs, size, _ = self.unpack_fielddescr_size(fielddescr)
        if isinstance(lltype.typeOf(struct), lltype.Ptr):
            fielddescr.assert_correct_type(struct)
        self.write_int_at_mem(struct, ofs, size, newvalue)

    def bh_setfield_gc_r(self, struct, newvalue, fielddescr):
        ofs = self.unpack_fielddescr(fielddescr)
        if isinstance(lltype.typeOf(struct), lltype.Ptr):
            fielddescr.assert_correct_type(struct)
        self.write_ref_at_mem(struct, ofs, newvalue)

    @specialize.argtype(1)
    def bh_setfield_gc_f(self, struct, newvalue, fielddescr):
        ofs = self.unpack_fielddescr(fielddescr)
        if isinstance(lltype.typeOf(struct), lltype.Ptr):
            fielddescr.assert_correct_type(struct)
        self.write_float_at_mem(struct, ofs, newvalue)

    bh_setfield_raw_i = bh_setfield_gc_i
    bh_setfield_raw_f = bh_setfield_gc_f

    def bh_raw_store_i(self, addr, offset, newvalue, descr):
        ofs, size, _ = self.unpack_arraydescr_size(descr)
        assert ofs == 0     # otherwise, 'descr' is not a raw length-less array
        self.write_int_at_mem(addr, offset, size, newvalue)

    def bh_raw_store_f(self, addr, offset, newvalue, descr):
        self.write_float_at_mem(addr, offset, newvalue)

    def bh_raw_load_i(self, addr, offset, descr):
        ofs, size, sign = self.unpack_arraydescr_size(descr)
        assert ofs == 0     # otherwise, 'descr' is not a raw length-less array
        return self.read_int_at_mem(addr, offset, size, sign)

    def bh_raw_load_f(self, addr, offset, descr):
        return self.read_float_at_mem(addr, offset)

    def bh_gc_load_indexed_i(self, addr, index, scale, base_ofs, bytes):
        offset = base_ofs + scale * index
        return self.read_int_at_mem(addr, offset, abs(bytes), bytes < 0)

    def bh_gc_load_indexed_f(self, addr, index, scale, base_ofs, bytes):
        # only for 'double'!
        assert bytes == rffi.sizeof(lltype.Float)
        offset = base_ofs + scale * index
        return self.read_float_at_mem(addr, offset)

    def bh_gc_store_indexed_i(self, addr, index, val, scale, base_ofs, bytes,
                              descr):
        offset = base_ofs + scale * index
        self.write_int_at_mem(addr, offset, bytes, val)

    def bh_gc_store_indexed_f(self, addr, index, val, scale, base_ofs, bytes,
                              descr):
        offset = base_ofs + scale * index
        self.write_float_at_mem(addr, offset, val)

    def bh_new(self, sizedescr):
        return self.gc_ll_descr.gc_malloc(sizedescr)

    def bh_new_with_vtable(self, sizedescr):
        res = self.gc_ll_descr.gc_malloc(sizedescr)
        if self.vtable_offset is not None:
            self.write_int_at_mem(res, self.vtable_offset, WORD, sizedescr.get_vtable())
        return res

    def bh_classof(self, struct):
        struct = lltype.cast_opaque_ptr(rclass.OBJECTPTR, struct)
        return ptr2int(struct.typeptr)

    def bh_new_array(self, length, arraydescr):
        return self.gc_ll_descr.gc_malloc_array(length, arraydescr)
    bh_new_array_clear = bh_new_array

    def bh_newstr(self, length):
        return self.gc_ll_descr.gc_malloc_str(length)

    def bh_newunicode(self, length):
        return self.gc_ll_descr.gc_malloc_unicode(length)

    def bh_strsetitem(self, string, index, newvalue):
        s = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), string)
        s.chars[index] = chr(newvalue)

    def bh_unicodesetitem(self, string, index, newvalue):
        u = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), string)
        u.chars[index] = unichr(newvalue)

    def bh_copystrcontent(self, src, dst, srcstart, dststart, length):
        src = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), src)
        dst = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), dst)
        rstr.copy_string_contents(src, dst, srcstart, dststart, length)

    def bh_copyunicodecontent(self, src, dst, srcstart, dststart, length):
        src = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), src)
        dst = lltype.cast_opaque_ptr(lltype.Ptr(rstr.UNICODE), dst)
        rstr.copy_unicode_contents(src, dst, srcstart, dststart, length)

    def bh_call_i(self, func, args_i, args_r, args_f, calldescr):
        assert isinstance(calldescr, CallDescr)
        if not we_are_translated():
            calldescr.verify_types(args_i, args_r, args_f, history.INT + 'S')
        return calldescr.call_stub_i(func, args_i, args_r, args_f)

    def bh_call_r(self, func, args_i, args_r, args_f, calldescr):
        assert isinstance(calldescr, CallDescr)
        if not we_are_translated():
            calldescr.verify_types(args_i, args_r, args_f, history.REF)
        return calldescr.call_stub_r(func, args_i, args_r, args_f)

    def bh_call_f(self, func, args_i, args_r, args_f, calldescr):
        assert isinstance(calldescr, CallDescr)
        if not we_are_translated():
            calldescr.verify_types(args_i, args_r, args_f, history.FLOAT + 'L')
        return calldescr.call_stub_f(func, args_i, args_r, args_f)

    def bh_call_v(self, func, args_i, args_r, args_f, calldescr):
        assert isinstance(calldescr, CallDescr)
        if not we_are_translated():
            calldescr.verify_types(args_i, args_r, args_f, history.VOID)
        # the 'i' return value is ignored (and nonsense anyway)
        calldescr.call_stub_i(func, args_i, args_r, args_f)


class MissingLatestDescrError(Exception):
    """For propagate_exception_descr in untranslated tests."""

final_descr_rd_locs = [rffi.cast(rffi.USHORT, 0)]
history.BasicFinalDescr.rd_locs = final_descr_rd_locs
compile._DoneWithThisFrameDescr.rd_locs = final_descr_rd_locs
