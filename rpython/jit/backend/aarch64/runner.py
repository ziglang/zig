
from rpython.rtyper.lltypesystem import llmemory, lltype
from rpython.jit.backend.aarch64.assembler import AssemblerARM64
from rpython.jit.backend.aarch64 import registers as r
from rpython.jit.backend.aarch64.regalloc import VFPRegisterManager
from rpython.jit.backend.llsupport.llmodel import AbstractLLCPU
from rpython.jit.backend.aarch64.codebuilder import InstrBuilder

class CPU_ARM64(AbstractLLCPU):
    """ARM 64"""
    backend_name = "aarch64"
    frame_reg = r.fp
    all_reg_indexes = range(14) + [-1, -1, -1, -1, -1, 14, 15]
    gen_regs = r.all_regs
    float_regs = VFPRegisterManager.all_regs
    supports_floats = True
    HAS_CODEMAP = True

    from rpython.jit.backend.aarch64.arch import JITFRAME_FIXED_SIZE

    IS_64_BIT = True

    def __init__(self, rtyper, stats, opts=None, translate_support_code=False,
                 gcdescr=None):
        AbstractLLCPU.__init__(self, rtyper, stats, opts,
                               translate_support_code, gcdescr)

    def setup(self):
        self.assembler = AssemblerARM64(self, self.translate_support_code)

    def setup_once(self):
        self.assembler.setup_once()
        if self.HAS_CODEMAP:
            self.codemap.setup()

    def compile_bridge(self, faildescr, inputargs, operations,
                       original_loop_token, log=True, logger=None):
        clt = original_loop_token.compiled_loop_token
        clt.compiling_a_bridge()
        return self.assembler.assemble_bridge(logger, faildescr, inputargs,
                                              operations,
                                              original_loop_token, log=log)

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
            mc = InstrBuilder()
            mc.B_ofs(tgt)
            mc.copy_to_raw_memory(jmp)
        # positions invalidated
        looptoken.compiled_loop_token.invalidate_positions = []

    def cast_ptr_to_int(x):
        adr = llmemory.cast_ptr_to_adr(x)
        return CPU_ARM64.cast_adr_to_int(adr)
    cast_ptr_to_int._annspecialcase_ = 'specialize:arglltype(0)'
    cast_ptr_to_int = staticmethod(cast_ptr_to_int)

    def build_regalloc(self):
        ''' for tests'''
        from rpython.jit.backend.aarch64.regalloc import Regalloc
        assert self.assembler is not None
        return Regalloc(self.assembler)


for _i, _r in enumerate(r.all_regs):
    assert CPU_ARM64.all_reg_indexes[_r.value] == _i
from rpython.jit.backend.aarch64 import arch
assert arch.NUM_MANAGED_REGS == len(r.all_regs)
