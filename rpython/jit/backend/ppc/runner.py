from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rlib import rgc
from rpython.rlib.jit_hooks import LOOP_RUN_CONTAINER
from rpython.jit.backend.llsupport.llmodel import AbstractLLCPU
from rpython.jit.backend.ppc.vector_ext import AltiVectorExt
from rpython.jit.backend.ppc.ppc_assembler import AssemblerPPC
from rpython.jit.backend.ppc.arch import WORD
from rpython.jit.backend.ppc.codebuilder import PPCBuilder
from rpython.jit.backend.ppc import register as r

class PPC_CPU(AbstractLLCPU):

    vector_ext = AltiVectorExt()

    supports_floats = True
    # missing: supports_singlefloats

    IS_64_BIT = True
    backend_name = 'ppc64'

    # can an ISA instruction handle a factor to the offset?
    load_supported_factors = (1,)

    from rpython.jit.backend.ppc.register import JITFRAME_FIXED_SIZE
    frame_reg = r.SP
    all_reg_indexes = [-1] * 32
    for _i, _r in enumerate(r.MANAGED_REGS):
        all_reg_indexes[_r.value] = _i
    gen_regs = r.MANAGED_REGS
    float_regs = [None] + r.MANAGED_FP_REGS
    #             ^^^^ we leave a never-used hole for f0 in the jitframe
    #             for rebuild_faillocs_from_descr(), as a counter-workaround
    #             for the reverse hack in ALL_REG_INDEXES

    def __init__(self, rtyper, stats, opts=None, translate_support_code=False,
                 gcdescr=None):
        AbstractLLCPU.__init__(self, rtyper, stats, opts,
                               translate_support_code, gcdescr)

    def setup(self):
        self.assembler = AssemblerPPC(self)

    @rgc.no_release_gil
    def setup_once(self):
        self.assembler.setup_once()

    @rgc.no_release_gil
    def finish_once(self):
        self.assembler.finish_once()

    def compile_bridge(self, faildescr, inputargs, operations,
                       original_loop_token, log=True, logger=None):
        clt = original_loop_token.compiled_loop_token
        clt.compiling_a_bridge()
        return self.assembler.assemble_bridge(faildescr, inputargs, operations,
                                              original_loop_token, log, logger)

    def cast_ptr_to_int(x):
        adr = llmemory.cast_ptr_to_adr(x)
        return PPC_CPU.cast_adr_to_int(adr)
    cast_ptr_to_int._annspecialcase_ = 'specialize:arglltype(0)'
    cast_ptr_to_int = staticmethod(cast_ptr_to_int)


    def redirect_call_assembler(self, oldlooptoken, newlooptoken):
        self.assembler.redirect_call_assembler(oldlooptoken, newlooptoken)

    def invalidate_loop(self, looptoken):
        """Activate all GUARD_NOT_INVALIDATED in the loop and its attached
        bridges.  Before this call, all GUARD_NOT_INVALIDATED do nothing;
        after this call, they all fail.  Note that afterwards, if one such
        guard fails often enough, it has a bridge attached to it; it is
        possible then to re-call invalidate_loop() on the same looptoken,
        which must invalidate all newer GUARD_NOT_INVALIDATED, but not the
        old one that already has a bridge attached to it."""

        for jmp, tgt in looptoken.compiled_loop_token.invalidate_positions:
            mc = PPCBuilder()
            mc.b_offset(tgt)     # a single instruction
            mc.copy_to_raw_memory(jmp)
        # positions invalidated
        looptoken.compiled_loop_token.invalidate_positions = []

    def get_all_loop_runs(self):
        # not implemented
        return lltype.malloc(LOOP_RUN_CONTAINER, 0)

    def build_regalloc(self):
        ''' for tests'''
        from rpython.jit.backend.ppc.regalloc import Regalloc
        assert self.assembler is not None
        return Regalloc(self.assembler)
