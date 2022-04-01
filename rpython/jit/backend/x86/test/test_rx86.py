import py, struct
from rpython.rlib.rarithmetic import r_longlong
from rpython.jit.backend.x86.rx86 import *
globals().update(R.__dict__)

class CodeBuilderMixin(object):
    def __init__(self):
        self.buffer = []
        super(CodeBuilderMixin, self).__init__()

    def writechar(self, c):
        assert isinstance(c, str) and len(c) == 1
        self.buffer.append(c)    # append a character

    def getvalue(self):
        return ''.join(self.buffer)

    def force_frame_size(self, frame_size):
        pass

    def stack_frame_size_delta(self, delta):
        pass

def assert_encodes_as(code_builder_cls, insn_name, args, expected_encoding):
    s = code_builder_cls()
    getattr(s, insn_name)(*args)
    assert s.getvalue() == expected_encoding

class CodeBuilder32(CodeBuilderMixin, X86_32_CodeBuilder):
    pass

def test_mov_ri():
    s = CodeBuilder32()
    s.MOV_ri(ecx, -2)
    assert s.getvalue() == '\xB9\xFE\xFF\xFF\xFF'

def test_mov_rr():
    s = CodeBuilder32()
    s.MOV_rr(ebx, ebp)
    assert s.getvalue() == '\x89\xEB'

def test_mov_br():
    s = CodeBuilder32()
    s.MOV_br(-36, edx)
    assert s.getvalue() == '\x89\x55\xDC'

def test_mov_rb():
    s = CodeBuilder32()
    s.MOV_rb(edx, -36)
    assert s.getvalue() == '\x8B\x55\xDC'

def test_mov_rm():
    s = CodeBuilder32()
    s.MOV_rm(edx, (edi, 0))
    s.MOV_rm(edx, (edi, -128))
    s.MOV_rm(edx, (edi, 128))
    assert s.getvalue() == '\x8B\x17\x8B\x57\x80\x8B\x97\x80\x00\x00\x00'

def test_mov_mr():
    s = CodeBuilder32()
    s.MOV_mr((edi, 0), edx)
    s.MOV_mr((edi, -128), edx)
    s.MOV_mr((edi, 128), edx)
    assert s.getvalue() == '\x89\x17\x89\x57\x80\x89\x97\x80\x00\x00\x00'

def test_mov_ra():
    s = CodeBuilder32()
    s.MOV_ra(edx, (esi, edi, 2, 0))
    s.MOV_ra(edx, (esi, edi, 2, -128))
    s.MOV_ra(edx, (esi, edi, 2, 128))
    assert s.getvalue() == ('\x8B\x14\xBE' +
                            '\x8B\x54\xBE\x80' +
                            '\x8B\x94\xBE\x80\x00\x00\x00')

def test_mov_ra_no_base():
    s = CodeBuilder32()
    s.MOV_ra(edx, (NO_BASE_REGISTER, edi, 2, 0))
    assert s.getvalue() == '\x8B\x14\xBD\x00\x00\x00\x00'

    s = CodeBuilder32()
    s.MOV_ra(edx, (NO_BASE_REGISTER, edi, 2, 0xCD))
    assert s.getvalue() == '\x8B\x14\xBD\xCD\x00\x00\x00'

def test_mov_ar():
    s = CodeBuilder32()
    s.MOV_ar((esi, edi, 2, 0), edx)
    s.MOV_ar((esi, edi, 2, -128), edx)
    s.MOV_ar((esi, edi, 2, 128), edx)
    assert s.getvalue() == ('\x89\x14\xBE' +
                            '\x89\x54\xBE\x80' +
                            '\x89\x94\xBE\x80\x00\x00\x00')

def test_nop_add_rr():
    s = CodeBuilder32()
    s.NOP()
    s.ADD_rr(eax, eax)
    assert s.getvalue() == '\x90\x01\xC0'

def test_lea_rb():
    s = CodeBuilder32()
    s.LEA_rb(ecx, -36)
    assert s.getvalue() == '\x8D\x4D\xDC'

def test_lea32_rb():
    s = CodeBuilder32()
    s.LEA32_rb(ecx, -36)
    assert s.getvalue() == '\x8D\x8D\xDC\xFF\xFF\xFF'

def test_call_l(s=None):
    s = s or CodeBuilder32()
    s.CALL_l(0x01234567)   # relative offset
    assert s.getvalue() == '\xE8' + struct.pack("<i", 0x01234567)

def test_jmp_l():
    s = CodeBuilder32()
    s.JMP_l(0x01234567)   # relative offset
    assert s.getvalue() == '\xE9' + struct.pack("<i", 0x01234567)

def test_j_il():
    s = CodeBuilder32()
    s.J_il(5, 0x01234567)   # relative offset
    assert s.getvalue() == '\x0F\x85' + struct.pack("<i", 0x01234567)

def test_set_ir():
    s = CodeBuilder32()
    s.SET_ir(5, dl)
    assert s.getvalue() == '\x0F\x95\xC2'

def test_movsd_rj():
    s = CodeBuilder32()
    s.MOVSD_xj(xmm2, 0x01234567)
    assert s.getvalue() == '\xF2\x0F\x10\x15\x67\x45\x23\x01'

def test_movzx8_rm():
    s = CodeBuilder32()
    s.MOVZX8_rm(ecx, (eax, 16))
    assert s.getvalue() == '\x0F\xB6\x48\x10'

def test_movzx16_rm():
    s = CodeBuilder32()
    s.MOVZX16_rm(ecx, (eax, 16))
    assert s.getvalue() == '\x0F\xB7\x48\x10'

def test_div():
    s = CodeBuilder32()
    s.DIV_r(ecx)
    assert s.getvalue() == '\xF7\xF1'

def test_imul_rri():
    s = CodeBuilder32()
    # Multiply ecx by 0x01234567 and store the result in ebx
    s.IMUL_rri(ebx, ecx, 0x01234567)
    assert s.getvalue() == '\x69\xD9\x67\x45\x23\x01'

    s = CodeBuilder32()
    s.IMUL_rri(ebx, ecx, 0x2A)
    assert s.getvalue() == '\x6B\xD9\x2A'

def test_shifts():
    cb = CodeBuilder32
    assert_encodes_as(cb, 'SHL_ri', (edx, 1), '\xD1\xE2')
    assert_encodes_as(cb, 'SHL_ri', (edx, 5), '\xC1\xE2\x05')
    assert_encodes_as(cb, 'SHL_rr', (edx, ecx), '\xD3\xE2')

    assert_encodes_as(cb, 'SHR_ri', (edx, 1), '\xD1\xEA')
    assert_encodes_as(cb, 'SHR_ri', (edx, 5), '\xC1\xEA\x05')
    assert_encodes_as(cb, 'SHR_rr', (edx, ecx), '\xD3\xEA')

    assert_encodes_as(cb, 'SAR_ri', (edx, 1), '\xD1\xFA')
    assert_encodes_as(cb, 'SAR_ri', (edx, 5), '\xC1\xFA\x05')
    assert_encodes_as(cb, 'SAR_rr', (edx, ecx), '\xD3\xFA')

def test_and8_rr():
    assert_encodes_as(CodeBuilder32, 'AND8_rr', (bl, bh), '\x20\xFB')

def test_or8_rr():
    assert_encodes_as(CodeBuilder32, 'OR8_rr', (bl, bh), '\x08\xFB')

def test_test8_mi():
    assert_encodes_as(CodeBuilder32, 'TEST8_mi', ((edx, 16), 99),
                      '\xF6\x42\x10\x63')

def test_test8_ji():
    assert_encodes_as(CodeBuilder32, 'TEST8_ji', (0x12345678, 99),
                      '\xF6\x05\x78\x56\x34\x12\x63')

def test_mov8():
    cb = CodeBuilder32
    assert_encodes_as(cb, 'MOV8_mi', ((edx, 16), 99), '\xC6\x42\x10\x63')
    assert_encodes_as(cb, 'MOV8_ai', ((ebx, ecx, 2, 16), 99), '\xC6\x44\x8B\x10\x63')

def test_push32():
    cb = CodeBuilder32
    assert_encodes_as(cb, 'PUSH_i', (0x10009,), '\x68\x09\x00\x01\x00')
    assert_encodes_as(cb, 'PUSH_i', (9,), '\x6A\x09')

def test_sub_ji8():
    cb = CodeBuilder32
    assert_encodes_as(cb, 'SUB_ji8', (11223344, 55),
                      '\x83\x2D\x30\x41\xAB\x00\x37')
    assert_encodes_as(cb, 'SUB_mi8', ((edx, 16), 55),
                      '\x83\x6A\x10\x37')

class CodeBuilder64(CodeBuilderMixin, X86_64_CodeBuilder):
    pass

def test_mov_ri_64():
    s = CodeBuilder64()
    s.MOV_ri(ecx, -2)
    s.MOV_ri(r15, -3)
    s.MOV_ri(ebx, -0x80000003)
    s.MOV_ri(r13, -0x80000002)
    s.MOV_ri(ecx, 42)
    s.MOV_ri(r12, r_longlong(0x80000042))
    s.MOV_ri(r12, r_longlong(0x100000007))
    assert s.getvalue() == ('\x48\xC7\xC1\xFE\xFF\xFF\xFF' +
                            '\x49\xC7\xC7\xFD\xFF\xFF\xFF' +
                            '\x48\xBB\xFD\xFF\xFF\x7F\xFF\xFF\xFF\xFF' +
                            '\x49\xBD\xFE\xFF\xFF\x7F\xFF\xFF\xFF\xFF' +
                            '\xB9\x2A\x00\x00\x00' +
                            '\x41\xBC\x42\x00\x00\x80' +
                            '\x49\xBC\x07\x00\x00\x00\x01\x00\x00\x00')

def test_mov_rm_64():
    s = CodeBuilder64()
    s.MOV_rm(edx, (edi, 0))
    s.MOV_rm(edx, (r12, 0))
    s.MOV_rm(edx, (r13, 0))
    assert s.getvalue() == '\x48\x8B\x17\x49\x8b\x14\x24\x49\x8b\x55\x00'

def test_mov_rm_negative_64():
    s = CodeBuilder64()
    s.MOV_rm(edx, (edi, -1))
    assert s.getvalue() == '\x48\x8B\x57\xFF'

def test_movsd_xj_64():
    s = CodeBuilder64()
    s.MOVSD_xj(xmm2, 0x01234567)
    assert s.getvalue() == '\xF2\x0F\x10\x14\x25\x67\x45\x23\x01'

def test_multibyte_nops():
    for cls in [X86_64_CodeBuilder, X86_32_CodeBuilder]:
        assert len(cls.MULTIBYTE_NOPs) == 16
        for i in range(16):
            assert len(cls.MULTIBYTE_NOPs[i]) == i
