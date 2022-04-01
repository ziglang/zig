from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.objectmodel import specialize
from rpython.rlib.debug import debug_start, debug_print, debug_stop
from rpython.rlib.debug import have_debug_prints
from rpython.jit.backend.llsupport.asmmemmgr import BlockBuilderMixin
from rpython.jit.backend.x86.rx86 import X86_32_CodeBuilder, X86_64_CodeBuilder
from rpython.jit.backend.x86.regloc import LocationCodeBuilder
from rpython.jit.backend.x86.arch import IS_X86_32, IS_X86_64, WORD
from rpython.jit.backend.x86 import rx86, valgrind

# XXX: Seems nasty to change the superclass of MachineCodeBlockWrapper
# like this
if IS_X86_32:
    codebuilder_cls = X86_32_CodeBuilder
    backend_name = 'x86'
elif IS_X86_64:
    codebuilder_cls = X86_64_CodeBuilder
    backend_name = 'x86_64'

class ShortJumpTooFar(Exception):
    pass


class MachineCodeBlockWrapper(BlockBuilderMixin,
                              LocationCodeBuilder,
                              codebuilder_cls):
    def __init__(self):
        self.init_block_builder()
        codebuilder_cls.__init__(self)
        # a list of relative positions; for each position p, the bytes
        # at [p-4:p] encode an absolute address that will need to be
        # made relative.  Only works on 32-bit!
        if WORD == 4:
            self.relocations = []
        else:
            self.relocations = None
        #
        # ResOperation --> offset in the assembly.
        # ops_offset[None] represents the beginning of the code after the last op
        # (i.e., the tail of the loop)
        self.ops_offset = {}

    def add_pending_relocation(self):
        self.relocations.append(self.get_relative_pos(break_basic_block=False))

    def mark_op(self, op):
        pos = self.get_relative_pos(break_basic_block=False)
        self.ops_offset[op] = pos

    def copy_to_raw_memory(self, addr):
        self._copy_to_raw_memory(addr)
        if self.relocations is not None:
            for reloc in self.relocations:       # for 32-bit only
                p = addr + reloc
                adr = rffi.cast(rffi.INTP, p - 4)
                adr[0] = rffi.cast(rffi.INT, intmask(adr[0]) - p)
        valgrind.discard_translations(addr, self.get_relative_pos())
        self._dump(addr, "jit-backend-dump", backend_name)

    @specialize.arg(1)
    def emit_forward_jump(self, condition_string):
        return self.emit_forward_jump_cond(rx86.Conditions[condition_string])

    def emit_forward_jump_cond(self, cond):
        self.J_il8(cond, 0)
        return self.get_relative_pos(break_basic_block=False)

    def emit_forward_jump_uncond(self):
        self.JMP_l8(0)
        return self.get_relative_pos(break_basic_block=False)

    def patch_forward_jump(self, jcond_location):
        offset = self.get_relative_pos() - jcond_location
        assert offset >= 0
        if offset > 127:
            raise ShortJumpTooFar
        self.overwrite(jcond_location-1, chr(offset))

    def get_relative_pos(self, break_basic_block=True):
        if break_basic_block:
            self.forget_scratch_register()
        return BlockBuilderMixin.get_relative_pos(self)


class SlowPath(object):
    def __init__(self, mc, condition):
        mc.J_il(condition, 0xfffff)     # patched later
        self.cond_jump_addr = mc.get_relative_pos(break_basic_block=False)
        self.saved_scratch_value_1 = mc.get_scratch_register_known_value()
        self.frame_size = mc._frame_size

    def set_continue_addr(self, mc):
        self.continue_addr = mc.get_relative_pos(break_basic_block=False)
        self.saved_scratch_value_2 = mc.get_scratch_register_known_value()
        assert self.frame_size == mc._frame_size

    def generate(self, assembler, mc):
        # no alignment here, prefer compactness for these slow-paths.
        # patch the original jump to go here
        offset = mc.get_relative_pos() - self.cond_jump_addr
        mc.overwrite32(self.cond_jump_addr-4, offset)
        # restore the knowledge of the scratch register value
        # (this does not emit any code)
        mc.force_frame_size(self.frame_size)
        mc.restore_scratch_register_known_value(self.saved_scratch_value_1)
        # generate the body of the slow-path
        self.generate_body(assembler, mc)
        # reload (if needed) the (possibly different) scratch register value
        mc.load_scratch_if_known(self.saved_scratch_value_2)
        # jump back
        curpos = mc.get_relative_pos() + 5
        mc.JMP_l(self.continue_addr - curpos)
