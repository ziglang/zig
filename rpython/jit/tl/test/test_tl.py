import py
import operator
from rpython.jit.tl.tlopcode import *

from rpython.translator.c.test import test_boehm
from rpython.annotator import policy

def list2bytecode(insn):
    return ''.join([chr(i & 0xff) for i in insn])

# actual tests go here

class TestTL(test_boehm.AbstractGCTestClass):
    from rpython.jit.tl.tl import interp
    interp = staticmethod(interp)

    def test_tl_push(self):
        assert self.interp(list2bytecode([PUSH, 16])) == 16

    def test_tl_pop(self):
        assert self.interp( list2bytecode([PUSH,16, PUSH,42, PUSH,100, POP]) ) == 42

    def test_tl_add(self):
        assert self.interp( list2bytecode([PUSH,42, PUSH,100, ADD]) ) == 142
        assert self.interp( list2bytecode([PUSH,16, PUSH,42, PUSH,100, ADD]) ) == 142

    def test_tl_error(self):
        py.test.raises(IndexError, self.interp, list2bytecode([POP]))
        py.test.raises(IndexError, self.interp, list2bytecode([ADD]))
        py.test.raises(IndexError, self.interp, list2bytecode([PUSH,100, ADD]))

    def test_tl_invalid_codetype(self):
        py.test.raises(TypeError, self.interp,[INVALID])

    def test_tl_invalid_bytecode(self):
        py.test.raises(RuntimeError, self.interp, list2bytecode([INVALID]))

    def test_tl_translatable(self):
        code = list2bytecode([PUSH,42, PUSH,100, ADD])
        fn = self.getcompiled(self.interp, [str, int, int])
        assert self.interp(code, 0, 0) == fn(code, 0, 0)

    def test_swap(self):
        code = [PUSH,42, PUSH, 84]
        assert self.interp(list2bytecode(code)) == 84
        code.append(SWAP)
        assert self.interp(list2bytecode(code)) == 42
        code.append(POP)
        assert self.interp(list2bytecode(code)) == 84

    def test_pick(self):
        values = [7, 8, 9]
        code = []
        for v in values[::-1]:
            code.extend([PUSH, v])

        for i, v in enumerate(values):
            assert self.interp(list2bytecode(code + [PICK,i])) == v

    def test_put(self):
        values = [1,2,7,-3]
        code = [PUSH,0] * len(values)
        for i, v in enumerate(values):
            code += [PUSH,v, PUT,i]

        for i, v in enumerate(values):
            assert self.interp(list2bytecode(code + [PICK,i])) == v

    ops = [ (ADD, operator.add, ((2, 4), (1, 1), (-1, 1))),
            (SUB, operator.sub, ((2, 4), (4, 2), (1, 1))),
            (MUL, operator.mul, ((2, 4), (4, 2), (1, 1), (-1, 6), (0, 5))),
            (DIV, operator.div, ((2, 4), (4, 2), (1, 1), (-4, -2), (0, 9), (9, -3))),
            (EQ, operator.eq, ((0, 0), (0, 1), (1, 0), (1, 1), (-1, 0), (0, -1), (-1, -1), (1, -1),  (-1, 1))),
            (NE, operator.ne, ((0, 0), (0, 1), (1, 0), (1, 1), (-1, 0), (0, -1), (-1, -1), (1, -1),  (-1, 1))),
            (LT, operator.lt, ((0, 0), (0, 1), (1, 0), (1, 1), (-1, 0), (0, -1), (-1, -1), (1, -1),  (-1, 1))),
            (LE, operator.le, ((0, 0), (0, 1), (1, 0), (1, 1), (-1, 0), (0, -1), (-1, -1), (1, -1),  (-1, 1))),
            (GT, operator.gt, ((0, 0), (0, 1), (1, 0), (1, 1), (-1, 0), (0, -1), (-1, -1), (1, -1),  (-1, 1))),
            (GE, operator.ge, ((0, 0), (0, 1), (1, 0), (1, 1), (-1, 0), (0, -1), (-1, -1), (1, -1),  (-1, 1))),
          ]

    def test_ops(self):
        for insn, pyop, values in self.ops:
            for first, second in values:
                code = [PUSH, first, PUSH, second, insn]
                assert self.interp(list2bytecode(code)) == pyop(first, second)


    def test_branch_forward(self):
        assert self.interp(list2bytecode([PUSH,1, PUSH,0, BR_COND,2, PUSH,-1])) == -1
        assert self.interp(list2bytecode([PUSH,1, PUSH,1, BR_COND,2, PUSH,-1])) == 1
        assert self.interp(list2bytecode([PUSH,1, PUSH,-1, BR_COND,2, PUSH,-1])) == 1

    def test_branch_backwards(self):
        assert self.interp(list2bytecode([PUSH,0, PUSH,1, BR_COND,6, PUSH,-1, PUSH,3, BR_COND,4, PUSH,2, BR_COND,-10])) == -1

    def test_branch0(self):
        assert self.interp(list2bytecode([PUSH,7, PUSH,1, BR_COND,0])) == 7

    def test_return(self):
        assert py.test.raises(IndexError, self.interp, list2bytecode([RETURN]))
        assert self.interp(list2bytecode([PUSH,7, RETURN, PUSH,5])) == 7

    def test_rot(self):

        code = [PUSH,1, PUSH,2, PUSH,3, ROLL, 3] 
        assert self.interp(list2bytecode(code)) == 1
        assert self.interp(list2bytecode(code + [POP])) == 3
        assert self.interp(list2bytecode(code + [POP, POP])) == 2

        py.test.raises(IndexError, self.interp, list2bytecode([PUSH,1, PUSH,2, PUSH,3, ROLL,4]))

        code = [PUSH,1, PUSH,2, PUSH,3, ROLL, -3] 
        assert self.interp(list2bytecode(code)) == 2
        assert self.interp(list2bytecode(code + [POP])) == 1
        assert self.interp(list2bytecode(code + [POP, POP])) == 3

        py.test.raises(IndexError, self.interp, list2bytecode([PUSH,1, PUSH,2, PUSH,3, ROLL,-4]))

    def test_call_ret(self):
        assert self.interp(list2bytecode([CALL,1, RETURN, PUSH,2])) == 2
        assert self.interp(list2bytecode([PUSH,6, CALL,2, MUL, RETURN, PUSH,7, RETURN])) == 42

    def test_compile_branch_backwards(self):
        code = compile("""
    main:
        PUSH 0
        PUSH 1
        BR_COND somename
    label1:
        PUSH -1
        PUSH 3
        BR_COND end
    somename:   ;
        PUSH 2  //
        BR_COND label1//
    end:// comment
        //
    //
    //comment
    """)
        assert code == list2bytecode([PUSH,0, PUSH,1, BR_COND,6, PUSH,-1, PUSH,3, BR_COND,4, PUSH,2, BR_COND,-10])

    def test_compile_call_ret(self):
        code = compile("""PUSH 1
        CALL func1
        PUSH 3
        CALL func2
        RETURN

    func1:
        PUSH 2
        RETURN  # comment

    func2:
        PUSH 4   ;comment
        PUSH 5
        ADD
        RETURN""")
        assert code == list2bytecode([PUSH,1, CALL,5, PUSH,3, CALL,4, RETURN,
                                      PUSH,2, RETURN,
                                      PUSH,4, PUSH,5, ADD, RETURN])

    def test_factorial_seven(self):
        code = compile('''
                PUSH 1   #  accumulator
                PUSH 7   #  N

            start:
                PICK 0
                PUSH 1
                LE
                BR_COND exit

                SWAP
                PICK 1
                MUL
                SWAP
                PUSH 1
                SUB
                PUSH 1
                BR_COND start

            exit:
                POP
                RETURN
        ''')
        res = self.interp(code)
        assert res == 5040

    def test_factorial_seven_harder(self):
        code = compile('''
                PUSH 1   #  accumulator
                PUSH 7   #  N

            start:
                PICK 0
                PUSH 1
                LE
                PUSH exit
                BR_COND_STK

                SWAP
                PICK 1
                MUL
                SWAP
                PUSH 1
                SUB
                PUSH 1
                BR_COND start

            exit:
                NOP      # BR_COND_STK skips this instruction
                POP
                RETURN
        ''')
        res = self.interp(code)
        assert res == 5040



    def test_factorial_with_arg(self):
        code = compile(FACTORIAL_SOURCE) # see below
        res = self.interp(code, 0, 6)
        assert res == 720

    def test_translate_factorial(self):
        py.test.skip("?")
        # use py.test --benchmark to do the benchmarking
        code = compile(FACTORIAL_SOURCE)
        interp = self.interp
        def driver():
            bench = Benchmark()
            while 1:
                res = interp(code, 0, 2500)
                if bench.stop():
                    break
            return res

        fn = self.getcompiled(driver, [])
        res = fn()
        assert res == 0       # too many powers of 2 to be anything else

FACTORIAL_SOURCE = '''
            PUSH 1   #  accumulator
            PUSHARG

        start:
            PICK 0
            PUSH 1
            LE
            BR_COND exit

            SWAP
            PICK 1
            MUL
            SWAP
            PUSH 1
            SUB
            PUSH 1
            BR_COND start

        exit:
            POP
            RETURN
    '''

if __name__ == '__main__':
    code = compile(FACTORIAL_SOURCE)
    print ','.join([str(ord(c)) for c in code])
