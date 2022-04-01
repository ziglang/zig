from rpython.rtyper.lltypesystem import lltype, rffi

from rpython.jit.backend.ppc.codebuilder import BasicPPCAssembler, PPCBuilder
from rpython.jit.backend.ppc.regname import *
from rpython.jit.backend.ppc.register import *
from rpython.jit.backend.ppc import form
from rpython.jit.backend import detect_cpu
from rpython.jit.backend.ppc.arch import IS_PPC_32, IS_PPC_64, IS_BIG_ENDIAN
from rpython.jit.backend.ppc.arch import WORD

cpu = detect_cpu.autodetect()

signed = lltype.Signed
unsigned = lltype.Unsigned
char = lltype.Char

def vec_asmtest(memory=[]):
    def testmaker(test):
        def newtest(self):
            memory_ptrs = []
            a = PPCBuilder()
            for (bytes, type, values) in memory:
                # alloc
                adr = lltype.malloc(rffi.CArray(char), bytes, flavor="raw")
                memory_ptrs.append(adr)
                address = adr
                for i,value in enumerate(values):
                    rffi.cast(rffi.CArrayPtr(type), adr)[i] = rffi.cast(type, value)

            expected = test(self, a, *[rffi.cast(lltype.Signed, m) for m in memory_ptrs])
            f = a.get_assembler_function()
            f()
            for expect, type, ptr in expected:
                value = rffi.cast(rffi.CArrayPtr(type), ptr)[0]
                assert value == expect

            while memory_ptrs:
                ptr = memory_ptrs.pop()
                lltype.free(ptr, flavor="raw")
        return newtest
    return testmaker


class TestAssemble(object):
    """
    See how tests are built in test_ppc.py

    Instead of asmtest, use vec_asmtest. It adds a parameter 'memory' that
    allocates memory.


    @vec_asmtest(memory=[(8, [1,2]), 'm2': (16, [1,2,3,4])])
    def test(self, builder, m, m2):
        # ...
        return [ (value, type, ptr), ... ]
    """
    def setup_class(cls):
        if cpu not in ["ppc", "ppc64", "ppc-64"]:
            py.test.skip("can't test all of ppcgen on non-PPC!")

    @vec_asmtest(memory=[(16, signed, [0,0])])
    def test_unaligned_load(self, a, mem):
        a.load_imm(r15, mem)
        a.lxvd2x(0, 0, r15.value)
        a.blr()
        return [ (0, signed, mem), (0, signed, mem+8) ]

    @vec_asmtest(memory=[(16, signed, [1,2]), (16, signed, [0,0])])
    def test_unaligned_load_and_store(self, a, mem_l, mem_t):
        a.load_imm(r15, mem_l)
        a.load_imm(r14, mem_t)
        a.lxvd2x(0, 0, r15.value)
        a.stxvd2x(0, 0, r14.value)
        a.blr()
        return [ (1, signed, mem_t), (2, signed, mem_t+8) ]

    def test_xx3_instr(self):
        a = PPCBuilder()
        def assign_to_self(v):
            self.last_value = v
        a.emit = assign_to_self

        a.xxspltdl(32, 32, 32)
        #                                               tttttaaaaabbbbb        abt
        assert hex(int(self.last_value)) == hex(0b11110000000000000000000001010111)
        a.xxspltdl(32, 2, 2)
        #                                               tttttaaaaabbbbb        abt
        assert hex(int(self.last_value)) == hex(0b11110000000000100001000001010001)
        a.xxspltdl(0, 63, 0)
        #                                               tttttaaaaabbbbb        abt
        assert hex(int(self.last_value)) == hex(0b11110000000111110000000001010100)
        a.xxspltdl(0, 0, 63)
        #                                               tttttaaaaabbbbb        abt
        assert hex(int(self.last_value)) == hex(0b11110000000000001111100001010010)

