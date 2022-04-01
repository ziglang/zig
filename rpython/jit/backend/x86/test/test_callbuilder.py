from rpython.jit.backend.x86 import callbuilder
from rpython.jit.backend.x86.regloc import esi, edi, ebx, ecx, ImmedLoc


class FakeAssembler:
    class mc:
        _frame_size = 42
    class _regalloc:
        class rm:
            free_regs = [ebx]

    def __init__(self):
        self._log = []

    def _is_asmgcc(self):
        return False

    def regalloc_mov(self, src, dst):
        self._log.append(('mov', src, dst))


def test_base_case(call_release_gil_mode=False):
    asm = FakeAssembler()
    old_follow_jump = callbuilder.follow_jump
    try:
        callbuilder.follow_jump = lambda addr: addr
        cb = callbuilder.CallBuilder64(asm, ImmedLoc(12345), [ebx, ebx])
    finally:
        callbuilder.follow_jump = old_follow_jump
    if call_release_gil_mode:
        cb.select_call_release_gil_mode()
    cb.prepare_arguments()
    assert asm._log == [('mov', ebx, callbuilder.CallBuilder64.ARG0),
                        ('mov', ebx, callbuilder.CallBuilder64.ARG1)]

def test_call_release_gil():
    test_base_case(call_release_gil_mode=True)
