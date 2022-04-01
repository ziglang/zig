from rpython.jit.backend.llsupport import jitframe
from rpython.jit.backend.llsupport.memcpy import memcpy_fn, memset_fn
from rpython.jit.backend.llsupport.symbolic import WORD
from rpython.jit.backend.llsupport.codemap import CodemapBuilder
from rpython.jit.metainterp.history import (INT, REF, FLOAT, JitCellToken,
    ConstInt, AbstractFailDescr, VECTOR)
from rpython.jit.metainterp.resoperation import ResOperation, rop
from rpython.rlib import rgc
from rpython.rlib.debug import (debug_start, debug_stop, have_debug_prints_for,
                                debug_print)
from rpython.rlib.rarithmetic import r_uint
from rpython.rlib.objectmodel import specialize, compute_unique_id
from rpython.rtyper.annlowlevel import cast_instance_to_gcref, llhelper
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib.rjitlog import rjitlog as jl

DEBUG_COUNTER = lltype.Struct('DEBUG_COUNTER',
    # 'b'ridge, 'l'abel or # 'e'ntry point
    ('i', lltype.Signed),      # first field, at offset 0
    ('type', lltype.Char),
    ('number', lltype.Signed)
)

class GuardToken(object):
    def __init__(self, cpu, gcmap, faildescr, failargs, fail_locs,
                 guard_opnum, frame_depth, faildescrindex):
        assert isinstance(faildescr, AbstractFailDescr)
        self.cpu = cpu
        self.faildescr = faildescr
        self.faildescrindex = faildescrindex
        self.failargs = failargs
        self.fail_locs = fail_locs
        self.gcmap = self.compute_gcmap(gcmap, failargs,
                                        fail_locs, frame_depth)
        self.guard_opnum = guard_opnum

    def guard_not_invalidated(self):
        return self.guard_opnum == rop.GUARD_NOT_INVALIDATED

    def must_save_exception(self):
        guard_opnum = self.guard_opnum
        return (guard_opnum == rop.GUARD_EXCEPTION or
                guard_opnum == rop.GUARD_NO_EXCEPTION or
                guard_opnum == rop.GUARD_NOT_FORCED)

    def compute_gcmap(self, gcmap, failargs, fail_locs, frame_depth):
        # note that regalloc has a very similar compute, but
        # one that does iteration over all bindings, so slightly different,
        # eh
        input_i = 0
        for i in range(len(failargs)):
            arg = failargs[i]
            if arg is None:
                continue
            loc = fail_locs[input_i]
            input_i += 1
            if arg.type == REF:
                loc = fail_locs[i]
                if loc.is_core_reg():
                    val = self.cpu.all_reg_indexes[loc.value]
                else:
                    val = loc.get_position() + self.cpu.JITFRAME_FIXED_SIZE
                gcmap[val // WORD // 8] |= r_uint(1) << (val % (WORD * 8))
        return gcmap


class BaseAssembler(object):
    """ Base class for Assembler generator in real backends
    """

    def __init__(self, cpu, translate_support_code=False):
        self.cpu = cpu
        self.memcpy_addr = 0
        self.memset_addr = 0
        self.rtyper = cpu.rtyper
        # do not rely on this attribute if you test for jitlog
        self._debug = False
        self.loop_run_counters = []

        # XXX register allocation statistics to be removed later
        self.num_moves_calls = 0
        self.num_moves_jump = 0
        self.num_spills = 0
        self.num_spills_to_existing = 0
        self.num_reloads = 0

        self.preamble_num_moves_calls = 0
        self.preamble_num_moves_jump = 0
        self.preamble_num_spills = 0
        self.preamble_num_spills_to_existing = 0
        self.preamble_num_reloads = 0


    def stitch_bridge(self, faildescr, target):
        raise NotImplementedError

    def setup_once(self):
        # the address of the function called by 'new'
        gc_ll_descr = self.cpu.gc_ll_descr
        gc_ll_descr.initialize()
        if hasattr(gc_ll_descr, 'minimal_size_in_nursery'):
            self.gc_minimal_size_in_nursery = gc_ll_descr.minimal_size_in_nursery
        else:
            self.gc_minimal_size_in_nursery = 0
        if hasattr(gc_ll_descr, 'gcheaderbuilder'):
            self.gc_size_of_header = gc_ll_descr.gcheaderbuilder.size_gc_header
        else:
            self.gc_size_of_header = WORD # for tests
        self.memcpy_addr = rffi.cast(lltype.Signed, memcpy_fn)
        self.memset_addr = rffi.cast(lltype.Signed, memset_fn)
        self._build_failure_recovery(False, withfloats=False)
        self._build_failure_recovery(True, withfloats=False)
        self._build_wb_slowpath(False)
        self._build_wb_slowpath(True)
        self._build_wb_slowpath(False, for_frame=True)
        # only one of those
        self.build_frame_realloc_slowpath()
        if self.cpu.supports_floats:
            self._build_failure_recovery(False, withfloats=True)
            self._build_failure_recovery(True, withfloats=True)
            self._build_wb_slowpath(False, withfloats=True)
            self._build_wb_slowpath(True, withfloats=True)
        self._build_propagate_exception_path()
        if gc_ll_descr.get_malloc_slowpath_addr is not None:
            # generate few slowpaths for various cases
            self.malloc_slowpath = self._build_malloc_slowpath(kind='fixed')
            self.malloc_slowpath_varsize = self._build_malloc_slowpath(
                kind='var')
        if hasattr(gc_ll_descr, 'malloc_str'):
            self.malloc_slowpath_str = self._build_malloc_slowpath(kind='str')
        else:
            self.malloc_slowpath_str = None
        if hasattr(gc_ll_descr, 'malloc_unicode'):
            self.malloc_slowpath_unicode = self._build_malloc_slowpath(
                kind='unicode')
        else:
            self.malloc_slowpath_unicode = None
        lst = [0, 0, 0, 0]
        lst[0] = self._build_cond_call_slowpath(False, False)
        lst[1] = self._build_cond_call_slowpath(False, True)
        if self.cpu.supports_floats:
            lst[2] = self._build_cond_call_slowpath(True, False)
            lst[3] = self._build_cond_call_slowpath(True, True)
        self.cond_call_slowpath = lst

        self._build_stack_check_slowpath()
        self._build_release_gil(gc_ll_descr.gcrootmap)
        # do not rely on the attribute _debug for jitlog
        if not self._debug:
            # if self._debug is already set it means that someone called
            # set_debug by hand before initializing the assembler. Leave it
            # as it is
            should_debug = have_debug_prints_for('jit-backend-counts')
            self.set_debug(should_debug)
        # when finishing, we only have one value at [0], the rest dies
        self.gcmap_for_finish = lltype.malloc(jitframe.GCMAP, 1,
                                              flavor='raw',
                                              track_allocation=False)
        self.gcmap_for_finish[0] = r_uint(1)

    def setup(self, looptoken):
        if self.cpu.HAS_CODEMAP:
            self.codemap_builder = CodemapBuilder()
        self._finish_gcmap = lltype.nullptr(jitframe.GCMAP)

    def setup_gcrefs_list(self, allgcrefs):
        self._allgcrefs = allgcrefs
        self._allgcrefs_faildescr_next = 0

    def teardown_gcrefs_list(self):
        self._allgcrefs = None

    def get_gcref_from_faildescr(self, descr):
        """This assumes that it is called in order for all faildescrs."""
        search = cast_instance_to_gcref(descr)
        while not _safe_eq(
                self._allgcrefs[self._allgcrefs_faildescr_next], search):
            self._allgcrefs_faildescr_next += 1
            assert self._allgcrefs_faildescr_next < len(self._allgcrefs)
        return self._allgcrefs_faildescr_next

    def get_asmmemmgr_blocks(self, looptoken):
        clt = looptoken.compiled_loop_token
        if clt.asmmemmgr_blocks is None:
            clt.asmmemmgr_blocks = []
        return clt.asmmemmgr_blocks

    def get_asmmemmgr_gcreftracers(self, looptoken):
        clt = looptoken.compiled_loop_token
        if clt.asmmemmgr_gcreftracers is None:
            clt.asmmemmgr_gcreftracers = []
        return clt.asmmemmgr_gcreftracers

    def set_debug(self, v):
        r = self._debug
        self._debug = v
        return r

    def rebuild_faillocs_from_descr(self, descr, inputargs):
        locs = []
        GPR_REGS = len(self.cpu.gen_regs)
        XMM_REGS = len(self.cpu.float_regs)
        input_i = 0
        if self.cpu.IS_64_BIT:
            coeff = 1
        else:
            coeff = 2
        for pos in descr.rd_locs:
            pos = rffi.cast(lltype.Signed, pos)
            if pos == 0xFFFF:
                continue
            elif pos < GPR_REGS:
                locs.append(self.cpu.gen_regs[pos])
            elif pos < GPR_REGS + XMM_REGS * coeff:
                pos = (pos - GPR_REGS) // coeff
                locs.append(self.cpu.float_regs[pos])
            else:
                i = pos - self.cpu.JITFRAME_FIXED_SIZE
                assert i >= 0
                tp = inputargs[input_i].type
                locs.append(self.new_stack_loc(i, tp))
            input_i += 1
        return locs

    _previous_rd_locs = []

    def store_info_on_descr(self, startspos, guardtok):
        withfloats = False
        for box in guardtok.failargs:
            if box is not None and \
               (box.type == FLOAT or box.type == VECTOR):
                withfloats = True
                break
        exc = guardtok.must_save_exception()
        target = self.failure_recovery_code[exc + 2 * withfloats]
        faildescrindex = guardtok.faildescrindex
        base_ofs = self.cpu.get_baseofs_of_frame_field()
        #
        # in practice, about 2/3rd of 'positions' lists that we build are
        # exactly the same as the previous one, so share the lists to
        # conserve memory
        if len(self._previous_rd_locs) == len(guardtok.fail_locs):
            positions = self._previous_rd_locs     # tentatively
            shared = True
        else:
            positions = [rffi.cast(rffi.USHORT, 0)] * len(guardtok.fail_locs)
            shared = False
        #
        for i, loc in enumerate(guardtok.fail_locs):
            if loc is None:
                position = 0xFFFF
            elif loc.is_stack():
                assert (loc.value & (WORD - 1)) == 0, \
                    "store_info_on_descr: misaligned"
                position = (loc.value - base_ofs) // WORD
                assert 0 < position < 0xFFFF, "store_info_on_descr: overflow!"
            else:
                assert loc is not self.cpu.frame_reg # for now
                if self.cpu.IS_64_BIT:
                    coeff = 1
                else:
                    coeff = 2
                if loc.is_float():
                    position = len(self.cpu.gen_regs) + loc.value * coeff
                else:
                    position = self.cpu.all_reg_indexes[loc.value]

            if shared:
                if (rffi.cast(lltype.Signed, self._previous_rd_locs[i]) ==
                    rffi.cast(lltype.Signed, position)):
                    continue   # still equal
                positions = positions[:]
                shared = False
            positions[i] = rffi.cast(rffi.USHORT, position)
        self._previous_rd_locs = positions
        # write down the positions of locs
        guardtok.faildescr.rd_locs = positions
        return faildescrindex, target

    def enter_portal_frame(self, op):
        if self.cpu.HAS_CODEMAP:
            pos = self.mc.get_relative_pos(break_basic_block=False)
            self.codemap_builder.enter_portal_frame(op.getarg(0).getint(),
                                                    op.getarg(1).getint(),
                                                    pos)

    def leave_portal_frame(self, op):
        if self.cpu.HAS_CODEMAP:
            pos = self.mc.get_relative_pos(break_basic_block=False)
            self.codemap_builder.leave_portal_frame(op.getarg(0).getint(),
                                                    pos)

    def call_assembler(self, op, argloc, vloc, result_loc, tmploc):
        """
            * argloc: location of the frame argument that we're passing to
                      the called assembler (this is the first return value
                      of locs_for_call_assembler())

            * vloc:   location of the virtualizable (not in a register;
                      this is the optional second return value of
                      locs_for_call_assembler(), or imm(0) if none returned)

            * result_loc: location of op.result (which is not be
                          confused with the next one)

            * tmploc: location where the actual call to the other piece
                      of assembler will return its jitframe result
                      (which is always a REF), before the helper may be
                      called
        """
        descr = op.getdescr()
        assert isinstance(descr, JitCellToken)
        #
        # Write a call to the target assembler
        # we need to allocate the frame, keep in sync with runner's
        # execute_token
        jd = descr.outermost_jitdriver_sd
        self._call_assembler_emit_call(self.imm(descr._ll_function_addr),
                                        argloc, tmploc)

        if op.type == 'v':
            assert result_loc is None
            value = self.cpu.done_with_this_frame_descr_void
        else:
            kind = op.type
            if kind == INT:
                assert result_loc is tmploc
                value = self.cpu.done_with_this_frame_descr_int
            elif kind == REF:
                assert result_loc is tmploc
                value = self.cpu.done_with_this_frame_descr_ref
            elif kind == FLOAT:
                value = self.cpu.done_with_this_frame_descr_float
            else:
                raise AssertionError(kind)

        gcref = cast_instance_to_gcref(value)
        if gcref:
            rgc._make_sure_does_not_move(gcref)    # but should be prebuilt
        value = rffi.cast(lltype.Signed, gcref)
        je_location = self._call_assembler_check_descr(value, tmploc)
        #
        # Path A: use assembler_helper_adr
        assert jd is not None
        asm_helper_adr = self.cpu.cast_adr_to_int(jd.assembler_helper_adr)

        self._call_assembler_emit_helper_call(self.imm(asm_helper_adr),
                                                [tmploc, vloc], result_loc)

        jmp_location = self._call_assembler_patch_je(result_loc, je_location)

        # Path B: fast path.  Must load the return value

        #
        self._call_assembler_load_result(op, result_loc)
        #
        # Here we join Path A and Path B again
        self._call_assembler_patch_jmp(jmp_location)

    def get_loop_run_counters(self, index):
        return self.loop_run_counters[index]

    @specialize.argtype(1)
    def _inject_debugging_code(self, looptoken, operations, tp, number):
        if self._debug or jl.jitlog_enabled():
            newoperations = []
            self._append_debugging_code(newoperations, tp, number, None)
            for op in operations:
                newoperations.append(op)
                if op.getopnum() == rop.LABEL:
                    self._append_debugging_code(newoperations, 'l', number,
                                                op.getdescr())
            operations = newoperations
        return operations

    def _append_debugging_code(self, operations, tp, number, token):
        counter = self._register_counter(tp, number, token)
        c_adr = ConstInt(rffi.cast(lltype.Signed, counter))
        operations.append(
            ResOperation(rop.INCREMENT_DEBUG_COUNTER, [c_adr]))

    def _register_counter(self, tp, number, token):
        # XXX the numbers here are ALMOST unique, but not quite, use a counter
        #     or something
        struct = lltype.malloc(DEBUG_COUNTER, flavor='raw',
                               track_allocation=False)
        struct.i = 0
        struct.type = tp
        if tp == 'b' or tp == 'e':
            struct.number = number
        else:
            assert token
            struct.number = compute_unique_id(token)
        # YYY very minor leak -- we need the counters to stay alive
        # forever, just because we want to report them at the end
        # of the process
        self.loop_run_counters.append(struct)
        return struct

    def finish_once(self):
        if self._debug:
            # TODO remove the old logging system when jitlog is complete
            debug_start('jit-backend-counts')
            length = len(self.loop_run_counters)
            for i in range(length):
                struct = self.loop_run_counters[i]
                if struct.type == 'l':
                    prefix = 'TargetToken(%d)' % struct.number
                else:
                    num = struct.number
                    if num == -1:
                        num = '-1'
                    else:
                        num = str(r_uint(num))
                    if struct.type == 'b':
                        prefix = 'bridge %s' % num
                    else:
                        prefix = 'entry %s' % num
                debug_print(prefix + ':' + str(struct.i))
            debug_stop('jit-backend-counts')

        self.flush_trace_counters()

    def flush_trace_counters(self):
        # this is always called, the jitlog knows if it is enabled
        length = len(self.loop_run_counters)
        for i in range(length):
            struct = self.loop_run_counters[i]
            # only log if it has been executed
            if struct.i > 0:
                jl._log_jit_counter(struct)
            # reset the counter, flush in a later point in time will
            # add up the counters!
            struct.i = 0
        # here would be the point to free some counters
        # see YYY comment above! but first we should run this every once in a while
        # not just when jitlog_disable is called

    @staticmethod
    @rgc.no_collect
    def _reacquire_gil_shadowstack():
        # This used to be more complex for asmgcc.  In shadowstack mode,
        # 'rpy_fastgil' contains only zero or non-zero, and this is only
        # called when the old value stored in 'rpy_fastgil' was non-zero
        # (i.e. still locked, must wait with the regular mutex)
        from rpython.rlib import rgil
        rgil.acquire()

    _REACQGIL0_FUNC = lltype.Ptr(lltype.FuncType([], lltype.Void))
    _REACQGIL2_FUNC = lltype.Ptr(lltype.FuncType([rffi.CCHARP, lltype.Signed],
                                                 lltype.Void))

    def _build_release_gil(self, gcrootmap):
        if gcrootmap is None or gcrootmap.is_shadow_stack:
            reacqgil_func = llhelper(self._REACQGIL0_FUNC,
                                     self._reacquire_gil_shadowstack)
            self.reacqgil_addr = self.cpu.cast_ptr_to_int(reacqgil_func)
        else:
            raise AssertionError("!is_shadow_stack")

    def _is_asmgcc(self):
        return False        # legacy


def debug_bridge(descr_number, rawstart, codeendpos):
    debug_start("jit-backend-addr")
    debug_print("bridge out of Guard 0x%x has address 0x%x to 0x%x" %
                (r_uint(descr_number), r_uint(rawstart),
                    r_uint(rawstart + codeendpos)))
    debug_stop("jit-backend-addr")

def _safe_eq(x, y):
    try:
        return x == y
    except AttributeError:    # minor mess
        return False
