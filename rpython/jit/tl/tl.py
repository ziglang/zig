'''Toy Language'''

import py
from rpython.jit.tl.tlopcode import *
from rpython.rlib.jit import JitDriver, hint, dont_look_inside, promote

def char2int(c):
    t = ord(c)
    if t & 128:
        t = -(-ord(c) & 0xff)
    return t

class Stack(object):
    _virtualizable_ = ['stackpos', 'stack[*]']

    def __init__(self, size):
        self = hint(self, access_directly=True, fresh_virtualizable=True)
        self.stack = [0] * size
        self.stackpos = 0        # always store a known-nonneg integer here

    def append(self, elem):
        self.stack[self.stackpos] = elem
        self.stackpos += 1

    def pop(self):
        stackpos = self.stackpos - 1
        if stackpos < 0:
            raise IndexError
        self.stackpos = stackpos     # always store a known-nonneg integer here
        return self.stack[stackpos]

    def pick(self, i):
        n = self.stackpos - i - 1
        assert n >= 0
        self.append(self.stack[n])

    def put(self, i):
        elem = self.pop()
        n = self.stackpos - i - 1
        assert n >= 0
        self.stack[n] = elem

    @dont_look_inside
    def roll(self, r):
        if r < -1:
            i = self.stackpos + r
            if i < 0:
                raise IndexError
            n = self.stackpos - 1
            assert n >= 0
            elem = self.stack[n]
            for j in range(self.stackpos - 2, i - 1, -1):
                assert j >= 0
                self.stack[j + 1] = self.stack[j]
            self.stack[i] = elem
        elif r > 1:
            i = self.stackpos - r
            if i < 0:
                raise IndexError
            elem = self.stack[i]
            for j in range(i, self.stackpos - 1):
                self.stack[j] = self.stack[j + 1]
            n = self.stackpos - 1
            assert n >= 0
            self.stack[n] = elem


def make_interp(supports_call):
    myjitdriver = JitDriver(greens = ['pc', 'code'],
                            reds = ['inputarg', 'stack'],
                            virtualizables = ['stack'])
    def interp(code='', pc=0, inputarg=0):
        if not isinstance(code,str):
            raise TypeError("code '%s' should be a string" % str(code))

        stack = Stack(len(code))

        stack = hint(stack, access_directly=True)

        while True:
            myjitdriver.jit_merge_point(pc=pc, code=code,
                                        stack=stack, inputarg=inputarg)

            if pc >= len(code):
                break

            opcode = ord(code[pc])
            stack.stackpos = promote(stack.stackpos)
            pc += 1

            if opcode == NOP:
                pass

            elif opcode == PUSH:
                stack.append( char2int(code[pc]) )
                pc += 1

            elif opcode == POP:
                stack.pop()

            elif opcode == SWAP:
                a, b = stack.pop(), stack.pop()
                stack.append(a)
                stack.append(b)

            elif opcode == ROLL: #rotate stack top to somewhere below
                r = char2int(code[pc])
                stack.roll(r)
                pc += 1

            elif opcode == PICK:
                stack.pick(char2int(code[pc]))
                pc += 1

            elif opcode == PUT:
                stack.put(char2int(code[pc]))
                pc += 1

            elif opcode == ADD:
                a, b = stack.pop(), stack.pop()
                stack.append( b + a )

            elif opcode == SUB:
                a, b = stack.pop(), stack.pop()
                stack.append( b - a )

            elif opcode == MUL:
                a, b = stack.pop(), stack.pop()
                stack.append( b * a )

            elif opcode == DIV:
                a, b = stack.pop(), stack.pop()
                stack.append( b / a )

            elif opcode == EQ:
                a, b = stack.pop(), stack.pop()
                stack.append( b == a )

            elif opcode == NE:
                a, b = stack.pop(), stack.pop()
                stack.append( b != a )

            elif opcode == LT:
                a, b = stack.pop(), stack.pop()
                stack.append( b <  a )

            elif opcode == LE:
                a, b = stack.pop(), stack.pop()
                stack.append( b <= a )

            elif opcode == GT:
                a, b = stack.pop(), stack.pop()
                stack.append( b >  a )

            elif opcode == GE:
                a, b = stack.pop(), stack.pop()
                stack.append( b >= a )

            elif opcode == BR_COND:
                if stack.pop():
                    pc += char2int(code[pc]) + 1
                    myjitdriver.can_enter_jit(pc=pc, code=code,
                                              stack=stack, inputarg=inputarg)
                else:
                    pc += 1

            elif opcode == BR_COND_STK:
                offset = stack.pop()
                if stack.pop():
                    pc += offset
                    myjitdriver.can_enter_jit(pc=pc, code=code,
                                              stack=stack, inputarg=inputarg)

            elif supports_call and opcode == CALL:
                offset = char2int(code[pc])
                pc += 1
                res = interp(code, pc + offset)
                stack.append( res )

            elif opcode == RETURN:
                break

            elif opcode == PUSHARG:
                stack.append( inputarg )

            else:
                raise RuntimeError("unknown opcode: " + str(opcode))

        return stack.pop()

    return interp


interp              = make_interp(supports_call = True)
interp_without_call = make_interp(supports_call = False)
