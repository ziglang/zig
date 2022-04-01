
"""
Run tinyframe.py <input file> [int value reg0] [int value reg1] ...

Interpreter for a tiny interpreter with frame introspection. Supports
integer values and function values. The machine is
register based with untyped registers.

Opcodes:
ADD r1 r2 => r3 # integer addition or function combination,
                 # depending on argument types
                 # if r1 has a function f and r2 has a function g
                 # the result will be a function lambda arg : f(g(arg))
                 # this is also a way to achieve indirect call
INTROSPECT r1 => r2 # frame introspection - load a register with number
                    # pointed by r1 (must be int) to r2
PRINT r # print a register
CALL r1 r2 => r3 # call a function in register one with argument in r2 and
                 # result in r3
LOAD_FUNCTION <name> => r # load a function named name into register r
LOAD <int constant> => r # load an integer constant into register r
RETURN r1
JUMP @label # jump + or - by x opcodes
JUMP_IF_ABOVE r1 r2 @label # jump if value in r1 is above
# value in r2

function argument always comes in r0
"""

from rpython.rlib.streamio import open_file_as_stream
from rpython.jit.tl.tinyframe.support import sort
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.jit import JitDriver, hint, dont_look_inside

opcodes = ['ADD', 'INTROSPECT', 'PRINT', 'CALL', 'LOAD', 'LOAD_FUNCTION',
           'RETURN', 'JUMP', 'JUMP_IF_ABOVE']
unrolling_opcodes = unrolling_iterable(opcodes)
for i, opcode in enumerate(opcodes):
    globals()[opcode] = i

class Code(object):
    def __init__(self, code, regno, functions, name):
        self.code = code
        self.regno = regno
        self.functions = functions
        self.name = name

class Parser(object):

    name = None
    
    def compile(self, strrepr):
        self.code = []
        self.maxregno = 0
        self.functions = {}
        self.labels = {}
        lines = strrepr.splitlines()
        for line in lines:
            comment = line.find('#')
            if comment != -1:
                assert comment >= 0
                line = line[:comment]
            line = line.strip(" ")
            if not line:
                continue
            if line.endswith(':'):
                # a name
                self.finish_currect_code()
                self.name = line[:-1]
                continue
            if line.startswith('@'):
                self.labels[line[1:]] = len(self.code)
                continue
            firstspace = line.find(" ")
            assert firstspace >= 0
            opcode = line[:firstspace]
            args = line[firstspace + 1:]
            for name in unrolling_opcodes:
                if opcode == name:
                    getattr(self, 'compile_' + name)(args)
        values = self.functions.values()
        sort(values)
        functions = [code for i, code in values]
        assert self.name == 'main'
        return Code("".join([chr(i) for i in self.code]), self.maxregno + 1,
                    functions, self.name)

    def finish_currect_code(self):
        if self.name is None:
            assert not self.code
            return
        code = Code("".join([chr(i) for i in self.code]), self.maxregno + 1,
                    [], self.name)
        self.functions[self.name] = (len(self.functions), code)
        self.name = None
        self.labels = {}
        self.code = []
        self.maxregno = 0

    def rint(self, arg):
        assert arg.startswith('r')
        no = int(arg[1:])
        self.maxregno = max(self.maxregno, no)
        return no

    def compile_ADD(self, args):
        args, result = args.split("=")
        result = result[1:]
        arg0, arg1 = args.strip(" ").split(" ")
        self.code += [ADD, self.rint(arg0), self.rint(arg1),
                      self.rint(result.strip(" "))]

    def compile_LOAD(self, args):
        arg0, result = args.split("=")
        result = result[1:]
        arg0 = arg0.strip(" ")
        self.code += [LOAD, int(arg0), self.rint(result.strip(" "))]

    def compile_PRINT(self, args):
        arg = self.rint(args.strip(" "))
        self.code += [PRINT, arg]

    def compile_RETURN(self, args):
        arg = self.rint(args.strip(" "))
        self.code += [RETURN, arg]

    def compile_JUMP_IF_ABOVE(self, args):
        arg0, arg1, label = args.split(" ")
        self.code += [JUMP_IF_ABOVE, self.rint(arg0.strip(" ")),
                      self.rint(arg1.strip(" ")), self.labels[label[1:]]]

    def compile_LOAD_FUNCTION(self, args):
        name, res = args.split("=")
        res = res[1:]
        no, code = self.functions[name.strip(" ")]
        self.code += [LOAD_FUNCTION, no, self.rint(res.strip(" "))]

    def compile_CALL(self, args):
        args, res = args.split("=")
        res = res[1:]
        arg0, arg1 = args.strip(" ").split(" ")
        self.code += [CALL, self.rint(arg0.strip(" ")),
                      self.rint(arg1.strip(" ")),
                      self.rint(res.strip(" "))]

    def compile_INTROSPECT(self, args):
        arg, res = args.split("=")
        res = res[1:]
        self.code += [INTROSPECT, self.rint(arg.strip(" ")),
                      self.rint(res.strip(" "))]

    def compile_JUMP(self, args):
        raise NotImplementedError

def compile(strrepr):
    parser = Parser()
    return parser.compile(strrepr)

def disassemble(code):
    return [ord(i) for i in code.code]

class Object(object):
    def __init__(self):
        raise NotImplementedError("abstract base class")

    def add(self, other):
        raise NotImplementedError("abstract base class")

    def gt(self, other):
        raise NotImplementedError("abstract base class")

    def repr(self):
        raise NotImplementedError("abstract base class")

class Int(Object):
    def __init__(self, val):
        self.val = val

    def add(self, other):
        return Int(self.val + other.val)

    def gt(self, other):
        return self.val > other.val

    def repr(self):
        return str(self.val)

class Func(Object):
    def __init__(self, code):
        self.code = code

    def call(self, arg):
        f = Frame(self.code, arg)
        return f.interpret()

    def add(self, other):
        return CombinedFunc(self, other)

    def repr(self):
        return "<function %s>" % self.code.name

class CombinedFunc(Func):
    def __init__(self, outer, inner):
        self.outer = outer
        self.inner = inner

    def call(self, arg):
        return self.outer.call(self.inner.call(arg))

    def repr(self):
        return "<function %s(%s)>" % (self.outer.repr(), self.inner.repr())

driver = JitDriver(greens = ['i', 'code'], reds = ['self'],
                   virtualizables = ['self'])

class Frame(object):
    _virtualizable_ = ['registers[*]', 'code']
    
    def __init__(self, code, arg=None):
        self = hint(self, access_directly=True, fresh_virtualizable=True)
        self.code = code
        self.registers = [None] * code.regno
        self.registers[0] = arg

    def interpret(self):
        i = 0
        code = self.code.code
        while True:
            driver.jit_merge_point(self=self, code=code, i=i)
            opcode = ord(code[i])
            if opcode == LOAD:
                self.registers[ord(code[i + 2])] = Int(ord(code[i + 1]))
                i += 3
            elif opcode == ADD:
                arg1 = self.registers[ord(code[i + 1])]
                arg2 = self.registers[ord(code[i + 2])]
                self.registers[ord(code[i + 3])] = arg1.add(arg2)
                i += 4
            elif opcode == RETURN:
                return self.registers[ord(code[i + 1])]
            elif opcode == JUMP_IF_ABOVE:
                arg0 = self.registers[ord(code[i + 1])]
                arg1 = self.registers[ord(code[i + 2])]
                tgt = ord(code[i + 3])
                if arg0.gt(arg1):
                    i = tgt
                    driver.can_enter_jit(code=code, i=tgt, self=self)
                else:
                    i += 4
            elif opcode == LOAD_FUNCTION:
                f = self.code.functions[ord(code[i + 1])]
                self.registers[ord(code[i + 2])] = Func(f)
                i += 3
            elif opcode == CALL:
                f = self.registers[ord(code[i + 1])]
                arg = self.registers[ord(code[i + 2])]
                assert isinstance(f, Func)
                self.registers[ord(code[i + 3])] = f.call(arg)
                i += 4
            elif opcode == PRINT:
                arg = self.registers[ord(code[i + 1])]
                print arg.repr()
                i += 2
            elif opcode == INTROSPECT:
                self.introspect(ord(code[i + 1]), ord(code[i + 2]))
                i += 3
            else:
                raise Exception("unimplemented opcode %s" % opcodes[opcode])

    @dont_look_inside
    def introspect(self, rarg, rresult):
        source = self.registers[rarg]
        assert isinstance(source, Int)
        self.registers[rresult] = self.registers[source.val]

def interpret(code):
    return Frame(code).interpret()

def main(fname, argv):
    f = open_file_as_stream(fname, "r")
    input = f.readall()
    f.close()
    code = compile(input)
    mainframe = Frame(code)
    for i in range(len(argv)):
        mainframe.registers[i] = Int(int(argv[i]))
    res = mainframe.interpret()
    print "Result:", res.repr()

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print __doc__
        sys.exit(1)
    fname = sys.argv[1]
    main(fname, sys.argv[2:])
