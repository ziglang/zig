import os
from rpython.tool.udir import udir
import tempfile

class ASMInstruction(object):

    asm_opts = '-march=armv8-a'
    body = """.section .text
_start: .global _start
        .global main
        b main
main:
    .ascii "START   "
    %s
    .ascii "END     "
"""
    begin_tag = 'START   '
    end_tag = 'END     '
    base_name = 'test_%d.asm' 
    index = 0

    def __init__(self, instr):
        self.instr = instr
        self.file = udir.join(self.base_name % self.index)
        while self.file.check():
            self.index += 1
            self.file = udir.join(self.base_name % self.index)

    def encode(self):
        f = open("%s/a.out" % (udir),'rb')
        data = f.read()
        f.close()
        i = data.find(self.begin_tag)
        assert i>=0
        j = data.find(self.end_tag, i)
        assert j>=0
        as_code = data[i+len(self.begin_tag):j]
        return as_code

    def assemble(self, *args):
        res = self.body % (self.instr)
        self.file.write(res)
        os.system("as --fatal-warnings %s %s -o %s/a.out" % (self.asm_opts, self.file, udir))

    #def __del__(self):
    #    self.file.close()

def assemble(instr):
    a = ASMInstruction(instr)
    a.assemble(instr)
    return a.encode()
