from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.metainterp.test import support
from rpython.rtyper.lltypesystem import lltype, rffi

def run_asm(asm, return_float=False):
    BOOTSTRAP_TP = lltype.FuncType([], lltype.Signed)
    addr = asm.mc.materialize(asm.cpu, [], None)
    assert addr % 8 == 0
    func = rffi.cast(lltype.Ptr(BOOTSTRAP_TP), addr)
    asm.mc._dump_trace(addr, 'test.asm')
    if return_float:
        pass
    return func()

class JitZARCHMixin(support.LLJitMixin):
    type_system = 'lltype'
    CPUClass = getcpuclass()
    # we have to disable unroll
    enable_opts = "intbounds:rewrite:virtualize:string:earlyforce:pure:heap"
    basic = False

    def check_jumps(self, maxcount):
        pass
