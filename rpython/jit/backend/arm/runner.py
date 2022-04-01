from rpython.jit.backend.arm.arch import JITFRAME_FIXED_SIZE
from rpython.jit.backend.arm.assembler import AssemblerARM
from rpython.jit.backend.arm.regalloc import VFPRegisterManager
from rpython.jit.backend.arm.registers import fp, all_regs
from rpython.jit.backend.llsupport import jitframe
from rpython.jit.backend.llsupport.llmodel import AbstractLLCPU
from rpython.rlib.jit_hooks import LOOP_RUN_CONTAINER
from rpython.rtyper.lltypesystem import lltype, llmemory
from rpython.jit.backend.arm.detect import detect_hardfloat
from rpython.jit.backend.arm.detect import detect_arch_version, detect_neon

jitframe.STATICSIZE = JITFRAME_FIXED_SIZE

class CPUInfo(object):
    hf_abi = False
    arch_version = 6
    neon = False

class AbstractARMCPU(AbstractLLCPU):

    IS_64_BIT = False

    supports_floats = True
    supports_longlong = True
    supports_singlefloats = True
    supports_load_effective_address = True

    from rpython.jit.backend.arm.arch import JITFRAME_FIXED_SIZE
    all_reg_indexes = range(len(all_regs))
    gen_regs = all_regs
    float_regs = VFPRegisterManager.all_regs
    frame_reg = fp

    # can an ISA instruction handle a factor to the offset?
    # XXX should be: tuple(1 << i for i in range(31))
    load_supported_factors = (1,)

    def __init__(self, rtyper, stats, opts=None, translate_support_code=False,
                 gcdescr=None):
        AbstractLLCPU.__init__(self, rtyper, stats, opts,
                               translate_support_code, gcdescr)
        self.cpuinfo = CPUInfo()

    def set_debug(self, flag):
        return self.assembler.set_debug(flag)

    def setup(self):
        self.assembler = AssemblerARM(self, self.translate_support_code)

    def setup_once(self):
        self.cpuinfo.arch_version = detect_arch_version()
        self.cpuinfo.hf_abi = detect_hardfloat()
        self.cpuinfo.neon = detect_neon()
        #self.codemap.setup()
        self.assembler.setup_once()

    def finish_once(self):
        self.assembler.finish_once()

    def compile_bridge(self, faildescr, inputargs, operations,
                       original_loop_token, log=True, logger=None):
        clt = original_loop_token.compiled_loop_token
        clt.compiling_a_bridge()
        return self.assembler.assemble_bridge(logger, faildescr, inputargs,
                                              operations,
                                              original_loop_token, log=log)

    def cast_ptr_to_int(x):
        adr = llmemory.cast_ptr_to_adr(x)
        return CPU_ARM.cast_adr_to_int(adr)
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
        from rpython.jit.backend.arm.codebuilder import InstrBuilder

        for jmp, tgt in looptoken.compiled_loop_token.invalidate_positions:
            mc = InstrBuilder(self.cpuinfo.arch_version)
            mc.B_offs(tgt)
            mc.copy_to_raw_memory(jmp)
        # positions invalidated
        looptoken.compiled_loop_token.invalidate_positions = []

    # should be combined with other ll backends
    def get_all_loop_runs(self):
        l = lltype.malloc(LOOP_RUN_CONTAINER,
                          len(self.assembler.loop_run_counters))
        for i, ll_s in enumerate(self.assembler.loop_run_counters):
            l[i].type = ll_s.type
            l[i].number = ll_s.number
            l[i].counter = ll_s.i
        return l

    def build_regalloc(self):
        ''' for tests'''
        from rpython.jit.backend.arm.regalloc import Regalloc
        assert self.assembler is not None
        return Regalloc(self.assembler)


class CPU_ARM(AbstractARMCPU):
    """ARM"""
    backend_name = "arm"
