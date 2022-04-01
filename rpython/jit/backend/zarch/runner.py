from rpython.jit.backend.llsupport.llmodel import AbstractLLCPU
from rpython.jit.backend.zarch import registers as r
from rpython.jit.backend.zarch.assembler import AssemblerZARCH
from rpython.jit.backend.zarch.codebuilder import InstrBuilder
from rpython.jit.backend.zarch import vector_ext
from rpython.rlib import rgc
from rpython.rtyper.lltypesystem import lltype, llmemory

class AbstractZARCHCPU(AbstractLLCPU):
    def __init__(self, rtyper, stats, opts=None, translate_support_code=False,
                 gcdescr=None):
        AbstractLLCPU.__init__(self, rtyper, stats, opts,
                               translate_support_code, gcdescr)

class CPU_S390_64(AbstractZARCHCPU):
    dont_keepalive_stuff = True
    supports_floats = True
    from rpython.jit.backend.zarch.registers import JITFRAME_FIXED_SIZE

    vector_ext = vector_ext.ZSIMDVectorExt()

    backend_name = 'zarch'

    IS_64_BIT = True

    frame_reg = r.SP
    all_reg_indexes = [-1] * 32
    for _i, _r in enumerate(r.MANAGED_REGS):
        all_reg_indexes[_r.value] = _i
    gen_regs = r.MANAGED_REGS
    float_regs = r.MANAGED_FP_REGS

    load_supported_factors = (1,)

    def setup(self):
        self.assembler = AssemblerZARCH(self)

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

    def invalidate_loop(self, looptoken):
        """Activate all GUARD_NOT_INVALIDATED in the loop and its attached
        bridges.  Before this call, all GUARD_NOT_INVALIDATED do nothing;
        after this call, they all fail.  Note that afterwards, if one such
        guard fails often enough, it has a bridge attached to it; it is
        possible then to re-call invalidate_loop() on the same looptoken,
        which must invalidate all newer GUARD_NOT_INVALIDATED, but not the
        old one that already has a bridge attached to it."""

        for jmp, tgt in looptoken.compiled_loop_token.invalidate_positions:
            mc = InstrBuilder()
            # needs 4 bytes, ensured by the previous process
            mc.b_offset(tgt)     # a single instruction
            mc.copy_to_raw_memory(jmp)
        # positions invalidated
        looptoken.compiled_loop_token.invalidate_positions = []

    def redirect_call_assembler(self, oldlooptoken, newlooptoken):
        self.assembler.redirect_call_assembler(oldlooptoken, newlooptoken)

    def cast_ptr_to_int(x):
        adr = llmemory.cast_ptr_to_adr(x)
        return CPU_S390_64.cast_adr_to_int(adr)
    cast_ptr_to_int._annspecialcase_ = 'specialize:arglltype(0)'
    cast_ptr_to_int = staticmethod(cast_ptr_to_int)

    def build_regalloc(self):
        ''' NOT_RPYTHON: for tests '''
        from rpython.jit.backend.zarch.regalloc import Regalloc
        assert self.assembler is not None
        return Regalloc(self.assembler)
