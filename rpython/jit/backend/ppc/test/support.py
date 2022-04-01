from rpython.jit.backend.detect_cpu import getcpuclass
from rpython.jit.metainterp.test import support

class JitPPCMixin(support.LLJitMixin):
    type_system = 'lltype'
    CPUClass = getcpuclass()
    # we have to disable unroll
    enable_opts = "intbounds:rewrite:virtualize:string:earlyforce:pure:heap"
    basic = False

    def check_jumps(self, maxcount):
        pass
