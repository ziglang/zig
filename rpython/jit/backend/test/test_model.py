from rpython.jit.backend.model import CompiledLoopToken

class FakeCPU(object):
    class tracker:
        total_compiled_loops = 0
        total_freed_loops = 0
        total_freed_bridges = 0

    def free_loop_and_bridges(self, *args):
        pass

class FrameInfo(object):
    def __init__(self, depth):
        self.jfi_frame_depth = depth

    def update_frame_depth(self, baseofs, newdepth):
        self.jfi_frame_depth = newdepth

def test_redirect_loop_token():
    cpu = FakeCPU()
    c = CompiledLoopToken(cpu, 0)
    c2 = CompiledLoopToken(cpu, 0)
    c.frame_info = FrameInfo(1)
    c2.frame_info = FrameInfo(2)
    c2.update_frame_info(c, 0)
    assert c.frame_info.jfi_frame_depth == 2
    c3 = CompiledLoopToken(cpu, 0)
    c3.frame_info = FrameInfo(3)
    c3.update_frame_info(c2, 0)
    assert c.frame_info.jfi_frame_depth == 3
    assert c2.frame_info.jfi_frame_depth == 3
    
