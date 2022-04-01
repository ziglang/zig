import struct, sys
from rpython.jit.backend.x86.rx86 import R, fits_in_32bits
from rpython.jit.backend.x86.regloc import *
from rpython.jit.backend.x86.test.test_rx86 import CodeBuilder32, CodeBuilder64, assert_encodes_as
from rpython.jit.backend.x86.assembler import heap
from rpython.jit.backend.x86.arch import IS_X86_64, IS_X86_32
from rpython.jit.backend.x86 import codebuf
from rpython.jit.backend.x86.callbuilder import follow_jump
from rpython.rlib.rarithmetic import intmask
import py.test

class LocationCodeBuilder32(CodeBuilder32, LocationCodeBuilder):
    def force_frame_size(self, frame_size):
        pass

    def stack_frame_size_delta(self, delta):
        pass

class LocationCodeBuilder64(CodeBuilder64, LocationCodeBuilder):
    def force_frame_size(self, frame_size):
        pass

    def stack_frame_size_delta(self, delta):
        pass

cb32 = LocationCodeBuilder32
cb64 = LocationCodeBuilder64

def test_mov_8():
    assert_encodes_as(cb32, "MOV8_ri", (R.cl, 25), '\xB1\x19')

def test_mov_16():
    # only 'MOV16_*r' and 'MOV16_*i' are supported
    # 32-bit
    assert_encodes_as(cb32, "MOV16", (ecx, ebx), '\x66\x89\xD9')
    assert_encodes_as(cb32, "MOV16",
                      (AddressLoc(ecx, ImmedLoc(16), 0, 0), ebx),
                      '\x66\x89\x59\x10')
    # 64-bit
    assert_encodes_as(cb64, "MOV16", (r8, ebx), '\x66\x41\x89\xD8')  # 11 011 000
    assert_encodes_as(cb64, "MOV16", (ebx, r8), '\x66\x44\x89\xC3')  # 11 000 011
    assert_encodes_as(cb64, "MOV16", (ecx, ebx), '\x66\x89\xD9')
    # for the next case we don't pick the most efficient encoding, but well
    expected = '\x66\xC7\xC1\x39\x30'      # could be '\x66\xB9\x39\x30'
    assert_encodes_as(cb64, "MOV16", (ecx, ImmedLoc(12345)), expected)
    # for the next case we don't pick the most efficient encoding, but well
    expected = '\x66\xC7\xC1\xC7\xCF'      # could be '\x66\xB9\xC7\xCF'
    assert_encodes_as(cb64, "MOV16", (ecx, ImmedLoc(-12345)), expected)
    # for the next case we don't pick the most efficient encoding, but well
    expected = '\x66\x41\xC7\xC1\x39\x30'  # could be '\x66\x41\xB9\x39\x30'
    assert_encodes_as(cb64, "MOV16", (r9, ImmedLoc(12345)), expected)
    # for the next case we don't pick the most efficient encoding, but well
    expected = '\x66\x41\xC7\xC1\xC7\xCF'  # could be '\x66\x41\xB9\xC7\xCF'
    assert_encodes_as(cb64, "MOV16", (r9, ImmedLoc(-12345)), expected)
    assert_encodes_as(cb64, "MOV16",
                      (AddressLoc(r13, ImmedLoc(0), 0, 0), ImmedLoc(12345)),
                      '\x66\x41\xC7\x45\x00\x39\x30')

def test_cmp_16():
    # only 'CMP16_mi' is supported
    # 32-bit
    assert_encodes_as(cb32, "CMP16",
                      (AddressLoc(ecx, ImmedLoc(0), 0, 0), ImmedLoc(21324)),
                      '\x66\x81\x39\x4c\x53')
    assert_encodes_as(cb32, "CMP16",
                      (AddressLoc(esi, ImmedLoc(2), 0, 0), ImmedLoc(-12345)),
                      '\x66\x81\x7e\x02\xc7\xcf')
    # 64-bit
    assert_encodes_as(cb64, "CMP16",
                      (AddressLoc(r13, ImmedLoc(0), 0, 0), ImmedLoc(12345)),
                      '\x66\x41\x81\x7D\x00\x39\x30')

def test_relocation():
    from rpython.rtyper.lltypesystem import lltype, rffi
    for target in [0x01020304, -0x05060708, 0x0102030405060708]:
        if target > sys.maxint:
            continue
        mc = codebuf.MachineCodeBlockWrapper()
        mc.CALL(ImmedLoc(target))
        length = mc.get_relative_pos()
        buf = lltype.malloc(rffi.CCHARP.TO, length, flavor='raw')
        rawstart = rffi.cast(lltype.Signed, buf)
        if IS_X86_32:
            assert length == 5
            assert mc.relocations == [5]
            expected = "\xE8" + struct.pack('<i', target - (rawstart + 5))
        elif IS_X86_64:
            assert mc.relocations is None
            if 0 <= target <= 0xffffffff:
                assert length == 9
                expected = (
                    "\x41\xBB\x04\x03\x02\x01"      # MOV %r11, target
                    "\x41\xFF\xD3")                 # CALL *%r11
            elif -0x80000000 <= target < 0:
                assert length == 10
                expected = (
                    "\x49\xC7\xC3\xF8\xF8\xF9\xFA"  # MOV %r11, target
                    "\x41\xFF\xD3")                 # CALL *%r11
            else:
                assert length == 13
                expected = (
                    "\x49\xBB\x08\x07\x06\x05\x04\x03\x02\x01" # MOV %r11, targ
                    "\x41\xFF\xD3")                 # CALL *%r11
        mc.copy_to_raw_memory(rawstart)
        assert ''.join([buf[i] for i in range(length)]) == expected
        lltype.free(buf, flavor='raw')

class Fake32CodeBlockWrapper(codebuf.MachineCodeBlockWrapper):
    def check_stack_size_at_ret(self):
        pass
        
def test_follow_jump_instructions_32():
    buf = lltype.malloc(rffi.CCHARP.TO, 80, flavor='raw')
    raw = rffi.cast(lltype.Signed, buf)
    if not fits_in_32bits(raw):
        lltype.free(buf, flavor='raw')
        py.test.skip("not testable")
    mc = Fake32CodeBlockWrapper(); mc.WORD = 4; mc.relocations = []
    mc.RET()
    mc.copy_to_raw_memory(raw)
    mc = Fake32CodeBlockWrapper(); mc.WORD = 4; mc.relocations = []
    assert follow_jump(raw) == raw
    mc.JMP(imm(raw))
    mc.copy_to_raw_memory(raw + 20)
    assert buf[20] == '\xE9'    # JMP
    assert buf[21] == '\xE7'    #     -25
    assert buf[22] == '\xFF'
    assert buf[23] == '\xFF'
    assert buf[24] == '\xFF'
    mc = Fake32CodeBlockWrapper(); mc.WORD = 4; mc.relocations = []
    assert follow_jump(raw + 20) == raw
    mc.JMP(imm(raw))
    mc.copy_to_raw_memory(raw + 40)
    assert buf[40] == '\xE9'    # JMP
    assert buf[41] == '\xD3'    #     -45
    assert buf[42] == '\xFF'
    assert buf[43] == '\xFF'
    assert buf[44] == '\xFF'
    assert follow_jump(raw + 40) == raw
    lltype.free(buf, flavor='raw')


class Test64Bits:

    def setup_class(cls):
        if not IS_X86_64:
            py.test.skip()

    def test_reuse_scratch_register(self):
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(ecx, heap(base_addr))
        cb.MOV(ecx, heap(base_addr + 8))

        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE' +
                # mov rcx, [r11]
                '\x49\x8B\x0B' +
                # mov rcx, [r11+8]
                '\x49\x8B\x4B\x08'
        )
        assert cb.getvalue() == expected_instructions

    # ------------------------------------------------------------

    def test_64bit_address_1(self):
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.CMP(ecx, AddressLoc(ImmedLoc(0), ImmedLoc(0), 0, base_addr))
        # this case is a CMP_rj
        #
        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # cmp rcx, [r11]
                '\x49\x3B\x0B'
        )
        assert cb.getvalue() == expected_instructions

    def test_64bit_address_2(self):
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(ecx, AddressLoc(ImmedLoc(0), edx, 3, base_addr))
        # this case is a CMP_ra
        #
        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # mov rcx, [r11+8*rdx]
                '\x49\x8B\x0C\xD3'
        )
        assert cb.getvalue() == expected_instructions

    def test_64bit_address_3(self):
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(ecx, AddressLoc(edx, ImmedLoc(0), 0, base_addr))
        # this case is a CMP_rm
        #
        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # lea r11, [rdx+r11]
                '\x4E\x8D\x1C\x1A'
                # mov rcx, [r11]
                '\x49\x8B\x0B'
        )
        assert cb.getvalue() == expected_instructions

    def test_64bit_address_4(self):
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        assert cb._scratch_register_value == -1
        cb.MOV(ecx, AddressLoc(edx, esi, 2, base_addr))
        assert cb._scratch_register_value == -1
        # this case is a CMP_ra
        #
        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # lea r11, [rdx+r11]
                '\x4E\x8D\x1C\x1A'
                # mov rcx, [r11+4*rsi]
                '\x49\x8B\x0C\xB3'
        )
        assert cb.getvalue() == expected_instructions

    # ------------------------------------------------------------

    def test_MOV_64bit_constant_into_r11(self):
        base_constant = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(r11, imm(base_constant))

        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
        )
        assert cb.getvalue() == expected_instructions

    def test_MOV_64bit_constant_into_rax(self):
        base_constant = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(eax, imm(base_constant))

        expected_instructions = (
                # mov rax, 0xFEDCBA9876543210
                '\x48\xB8\x10\x32\x54\x76\x98\xBA\xDC\xFE'
        )
        assert cb.getvalue() == expected_instructions

    def test_MOV_64bit_address_into_r11(self):
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(r11, heap(base_addr))

        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE' +
                # mov r11, [r11]
                '\x4D\x8B\x1B'
        )
        assert cb.getvalue() == expected_instructions

    def test_MOV_immed32_into_64bit_address_1(self):
        immed = -0x01234567
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(AddressLoc(ImmedLoc(0), ImmedLoc(0), 0, base_addr),
               ImmedLoc(immed))
        # this case is a MOV_ji
        #
        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # mov [r11], -0x01234567
                '\x49\xC7\x03\x99\xBA\xDC\xFE'
        )
        assert cb.getvalue() == expected_instructions

    def test_MOV_immed32_into_64bit_address_2(self):
        immed = -0x01234567
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(AddressLoc(ImmedLoc(0), edx, 3, base_addr),
               ImmedLoc(immed))
        # this case is a MOV_ai
        #
        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # mov [r11+8*rdx], -0x01234567
                '\x49\xC7\x04\xD3\x99\xBA\xDC\xFE'
        )
        assert cb.getvalue() == expected_instructions

    def test_MOV_immed32_into_64bit_address_3(self):
        immed = -0x01234567
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(AddressLoc(edx, ImmedLoc(0), 0, base_addr),
               ImmedLoc(immed))
        # this case is a MOV_mi
        #
        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # lea r11, [rdx+r11]
                '\x4E\x8D\x1C\x1A'
                # mov [r11], -0x01234567
                '\x49\xC7\x03\x99\xBA\xDC\xFE'
        )
        assert cb.getvalue() == expected_instructions

    def test_MOV_immed32_into_64bit_address_4(self):
        immed = -0x01234567
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(AddressLoc(edx, esi, 2, base_addr), ImmedLoc(immed))
        # this case is a MOV_ai
        #
        expected_instructions = (
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # lea r11, [rdx+r11]
                '\x4E\x8D\x1C\x1A'
                # mov [r11+4*rsi], -0x01234567
                '\x49\xC7\x04\xB3\x99\xBA\xDC\xFE'
        )
        assert cb.getvalue() == expected_instructions

    # ------------------------------------------------------------

    def test_MOV_immed64_into_64bit_address_1(self):
        immed = 0x0123456789ABCDEF
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(AddressLoc(ImmedLoc(0), ImmedLoc(0), 0, base_addr),
               ImmedLoc(immed))
        # this case is a MOV_ji
        #
        expected_instructions = (
                # push rax
                '\x50'
                # mov rax, 0x0123456789ABCDEF
                '\x48\xB8\xEF\xCD\xAB\x89\x67\x45\x23\x01'
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # mov [r11], rax
                '\x49\x89\x03'
                # pop rax
                '\x58'
        )
        assert cb.getvalue() == expected_instructions

    def test_MOV_immed64_into_64bit_address_2(self):
        immed = 0x0123456789ABCDEF
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(AddressLoc(ImmedLoc(0), edx, 3, base_addr),
               ImmedLoc(immed))
        # this case is a MOV_ai
        #
        expected_instructions = (
                # push rax
                '\x50'
                # mov rax, 0x0123456789ABCDEF
                '\x48\xB8\xEF\xCD\xAB\x89\x67\x45\x23\x01'
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # mov [r11+8*rdx], rax
                '\x49\x89\x04\xD3'
                # pop rax
                '\x58'
        )
        assert cb.getvalue() == expected_instructions

    def test_MOV_immed64_into_64bit_address_3(self):
        immed = 0x0123456789ABCDEF
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(AddressLoc(eax, ImmedLoc(0), 0, base_addr),
               ImmedLoc(immed))
        # this case is a MOV_mi
        #
        expected_instructions = (
                # push rdx
                '\x52'
                # mov rdx, 0x0123456789ABCDEF
                '\x48\xBA\xEF\xCD\xAB\x89\x67\x45\x23\x01'
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # lea r11, [rax+r11]
                '\x4E\x8D\x1C\x18'
                # mov [r11], rdx
                '\x49\x89\x13'
                # pop rdx
                '\x5A'
        )
        assert cb.getvalue() == expected_instructions

    def test_MOV_immed64_into_64bit_address_4(self):
        immed = 0x0123456789ABCDEF
        base_addr = intmask(0xFEDCBA9876543210)
        cb = LocationCodeBuilder64()
        cb.MOV(AddressLoc(edx, eax, 2, base_addr), ImmedLoc(immed))
        # this case is a MOV_ai
        #
        expected_instructions = (
                # push rcx
                '\x51'
                # mov rcx, 0x0123456789ABCDEF
                '\x48\xB9\xEF\xCD\xAB\x89\x67\x45\x23\x01'
                # mov r11, 0xFEDCBA9876543210
                '\x49\xBB\x10\x32\x54\x76\x98\xBA\xDC\xFE'
                # lea r11, [rdx+r11]
                '\x4E\x8D\x1C\x1A'
                # mov [r11+4*rax], rcx
                '\x49\x89\x0C\x83'
                # pop rcx
                '\x59'
        )
        assert cb.getvalue() == expected_instructions

    # ------------------------------------------------------------

    def test_push_immed64(self):
        immed = 0x0123456789ABCDEF
        cb = LocationCodeBuilder64()
        cb.PUSH(imm(immed))
        #
        expected_instructions = (
                # mov r11, 0x0123456789ABCDEF
                '\x49\xBB\xEF\xCD\xAB\x89\x67\x45\x23\x01'
                # push r11
                '\x41\x53'
        )
        assert cb.getvalue() == expected_instructions

    def test_inc_64bit_address_1(self):
        base_addr = 0x0123456789ABCDEF
        cb = LocationCodeBuilder64()
        cb.INC(AddressLoc(ImmedLoc(0), ImmedLoc(0), 0, base_addr))
        # this case is a INC_j
        #
        expected_instructions = (
                # mov r11, 0x0123456789ABCDEF
                '\x49\xBB\xEF\xCD\xAB\x89\x67\x45\x23\x01'
                # inc [r11]
                '\x49\xFF\x03'
        )
        assert cb.getvalue() == expected_instructions

    def test_inc_64bit_address_2(self):
        py.test.skip("there is no unary instruction INSN_a so far")
        base_addr = 0x0123456789ABCDEF
        cb = LocationCodeBuilder64()
        cb.INC(AddressLoc(ImmedLoc(0), edx, 3, base_addr))
        # this case would be a INC_a
        xxx

    def test_inc_64bit_address_3(self):
        base_addr = 0x0123456789ABCDEF
        cb = LocationCodeBuilder64()
        cb.INC(AddressLoc(eax, ImmedLoc(0), 0, base_addr))
        # this case is a INC_m
        #
        expected_instructions = (
                # mov r11, 0x0123456789ABCDEF
                '\x49\xBB\xEF\xCD\xAB\x89\x67\x45\x23\x01'
                # lea r11, [rax+r11]
                '\x4E\x8D\x1C\x18'
                # inc [r11]
                '\x49\xFF\x03'
        )
        assert cb.getvalue() == expected_instructions
