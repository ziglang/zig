import py
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rlib.jit_hooks import LOOP_RUN_CONTAINER
from rpython.rlib import rgc
from rpython.jit.backend.x86.assembler import Assembler386
from rpython.jit.backend.x86.regalloc import gpr_reg_mgr_cls, xmm_reg_mgr_cls
from rpython.jit.backend.x86.profagent import ProfileAgent
from rpython.jit.backend.llsupport.llmodel import AbstractLLCPU
from rpython.jit.backend.x86 import regloc
from rpython.jit.backend.x86.vector_ext import X86VectorExt
from rpython.jit.backend.x86.arch import WIN64

import sys


class AbstractX86CPU(AbstractLLCPU):
    debug = True
    supports_floats = True
    supports_singlefloats = True
    supports_load_effective_address = True

    dont_keepalive_stuff = False # for tests
    with_threads = False
    frame_reg = regloc.ebp

    vector_ext = None

    # can an ISA instruction handle a factor to the offset?
    load_supported_factors = (1,2,4,8)

    HAS_CODEMAP = True

    from rpython.jit.backend.x86.arch import JITFRAME_FIXED_SIZE
    all_reg_indexes = gpr_reg_mgr_cls.all_reg_indexes
    gen_regs = gpr_reg_mgr_cls.all_regs
    float_regs = xmm_reg_mgr_cls.all_regs

    def __init__(self, rtyper, stats, opts=None, translate_support_code=False,
                 gcdescr=None):
        AbstractLLCPU.__init__(self, rtyper, stats, opts,
                               translate_support_code, gcdescr)

        profile_agent = ProfileAgent()
        if rtyper is not None:
            config = rtyper.annotator.translator.config
            if config.translation.jit_profiler == "oprofile":
                from rpython.jit.backend.x86 import oprofile
                if not oprofile.OPROFILE_AVAILABLE:
                    raise Exception('oprofile support was explicitly enabled, but oprofile headers seem not to be available')
                profile_agent = oprofile.OProfileAgent()
            self.with_threads = config.translation.thread

        self.profile_agent = profile_agent

    def set_debug(self, flag):
        return self.assembler.set_debug(flag)

    def setup(self):
        self.assembler = Assembler386(self, self.translate_support_code)

    def build_regalloc(self):
        ''' for tests'''
        from rpython.jit.backend.x86.regalloc import RegAlloc
        assert self.assembler is not None
        return RegAlloc(self.assembler, False)

    @rgc.no_release_gil
    def setup_once(self):
        self.profile_agent.startup()
        if self.HAS_CODEMAP:
            self.codemap.setup()
        self.assembler.setup_once()

    @rgc.no_release_gil
    def finish_once(self):
        self.assembler.finish_once()
        self.profile_agent.shutdown()

    def dump_loop_token(self, looptoken):
        """
        NOT_RPYTHON
        """
        from rpython.jit.backend.x86.tool.viewcode import machine_code_dump
        data = []
        label_list = [(offset, name) for name, offset in
                      looptoken._x86_ops_offset.iteritems()]
        label_list.sort()
        addr = looptoken._x86_rawstart
        src = rffi.cast(rffi.CCHARP, addr)
        for p in range(looptoken._x86_fullsize):
            data.append(src[p])
        data = ''.join(data)
        lines = machine_code_dump(data, addr, self.backend_name, label_list)
        print ''.join(lines)

    def compile_bridge(self, faildescr, inputargs, operations,
                       original_loop_token, log=True, logger=None):
        clt = original_loop_token.compiled_loop_token
        clt.compiling_a_bridge()
        return self.assembler.assemble_bridge(faildescr, inputargs, operations,
                                              original_loop_token, log, logger)

    def cast_ptr_to_int(x):
        adr = llmemory.cast_ptr_to_adr(x)
        return CPU386.cast_adr_to_int(adr)
    cast_ptr_to_int._annspecialcase_ = 'specialize:arglltype(0)'
    cast_ptr_to_int = staticmethod(cast_ptr_to_int)

    def redirect_call_assembler(self, oldlooptoken, newlooptoken):
        self.assembler.redirect_call_assembler(oldlooptoken, newlooptoken)

    def invalidate_loop(self, looptoken):
        from rpython.jit.backend.x86 import codebuf

        for addr, tgt in looptoken.compiled_loop_token.invalidate_positions:
            mc = codebuf.MachineCodeBlockWrapper()
            mc.JMP_l(tgt)
            assert mc.get_relative_pos() == 5      # [JMP] [tgt 4 bytes]
            mc.copy_to_raw_memory(addr - 1)
        # positions invalidated
        looptoken.compiled_loop_token.invalidate_positions = []

    def get_all_loop_runs(self):
        asm = self.assembler
        l = lltype.malloc(LOOP_RUN_CONTAINER,
                          len(asm.loop_run_counters))
        for i, ll_s in enumerate(asm.loop_run_counters):
            l[i].type = ll_s.type
            l[i].number = ll_s.number
            l[i].counter = ll_s.i
        return l


class CPU386(AbstractX86CPU):
    backend_name = 'x86'
    NUM_REGS = 8
    CALLEE_SAVE_REGISTERS = [regloc.ebx, regloc.esi, regloc.edi]

    supports_longlong = True

    IS_64_BIT = False

    def __init__(self, *args, **kwargs):
        assert sys.maxint == (2**31 - 1)
        super(CPU386, self).__init__(*args, **kwargs)

class CPU386_NO_SSE2(CPU386):
    supports_floats = False
    supports_longlong = False

class CPU_X86_64(AbstractX86CPU):
    if not WIN64:
        vector_ext = X86VectorExt()
    backend_name = 'x86_64'
    NUM_REGS = 16
    if not WIN64:
        CALLEE_SAVE_REGISTERS = [regloc.ebx, regloc.r12, regloc.r13, regloc.r14,
                                 regloc.r15]
    else:
        CALLEE_SAVE_REGISTERS = [regloc.ebx, regloc.esi, regloc.edi, regloc.r12,
                                 regloc.r14, regloc.r15]
        HAS_CODEMAP = False

    IS_64_BIT = True

CPU = CPU386
