import dis
import unittest
from test.support import cpython_only

from test.support.bytecode_helper import BytecodeTestCase


def count_instr_recursively(f, opname):
    count = 0
    for instr in dis.get_instructions(f):
        if instr.opname == opname:
            count += 1
    if hasattr(f, '__code__'):
        f = f.__code__
    for c in f.co_consts:
        if hasattr(c, 'co_code'):
            count += count_instr_recursively(c, opname)
    return count


class TestTranforms(BytecodeTestCase):

    def check_jump_targets(self, code):
        instructions = list(dis.get_instructions(code))
        targets = {instr.offset: instr for instr in instructions}
        for instr in instructions:
            if 'JUMP_' not in instr.opname:
                continue
            tgt = targets[instr.argval]
            # jump to unconditional jump
            if tgt.opname in ('JUMP_ABSOLUTE', 'JUMP_FORWARD'):
                self.fail(f'{instr.opname} at {instr.offset} '
                          f'jumps to {tgt.opname} at {tgt.offset}')
            # unconditional jump to RETURN_VALUE
            if (instr.opname in ('JUMP_ABSOLUTE', 'JUMP_FORWARD') and
                tgt.opname == 'RETURN_VALUE'):
                self.fail(f'{instr.opname} at {instr.offset} '
                          f'jumps to {tgt.opname} at {tgt.offset}')
            # JUMP_IF_*_OR_POP jump to conditional jump
            if '_OR_POP' in instr.opname and 'JUMP_IF_' in tgt.opname:
                self.fail(f'{instr.opname} at {instr.offset} '
                          f'jumps to {tgt.opname} at {tgt.offset}')

    def check_lnotab(self, code):
        "Check that the lnotab byte offsets are sensible."
        code = dis._get_code_object(code)
        lnotab = list(dis.findlinestarts(code))
        # Don't bother checking if the line info is sensible, because
        # most of the line info we can get at comes from lnotab.
        min_bytecode = min(t[0] for t in lnotab)
        max_bytecode = max(t[0] for t in lnotab)
        self.assertGreaterEqual(min_bytecode, 0)
        self.assertLess(max_bytecode, len(code.co_code))
        # This could conceivably test more (and probably should, as there
        # aren't very many tests of lnotab), if peepholer wasn't scheduled
        # to be replaced anyway.

    def test_unot(self):
        # UNARY_NOT POP_JUMP_IF_FALSE  -->  POP_JUMP_IF_TRUE'
        def unot(x):
            if not x == 2:
                del x
        self.assertNotInBytecode(unot, 'UNARY_NOT')
        self.assertNotInBytecode(unot, 'POP_JUMP_IF_FALSE')
        self.assertInBytecode(unot, 'POP_JUMP_IF_TRUE')
        self.check_lnotab(unot)

    def test_elim_inversion_of_is_or_in(self):
        for line, cmp_op, invert in (
            ('not a is b', 'IS_OP', 1,),
            ('not a is not b', 'IS_OP', 0,),
            ('not a in b', 'CONTAINS_OP', 1,),
            ('not a not in b', 'CONTAINS_OP', 0,),
            ):
            code = compile(line, '', 'single')
            self.assertInBytecode(code, cmp_op, invert)
            self.check_lnotab(code)

    def test_global_as_constant(self):
        # LOAD_GLOBAL None/True/False  -->  LOAD_CONST None/True/False
        def f():
            x = None
            x = None
            return x
        def g():
            x = True
            return x
        def h():
            x = False
            return x

        for func, elem in ((f, None), (g, True), (h, False)):
            self.assertNotInBytecode(func, 'LOAD_GLOBAL')
            self.assertInBytecode(func, 'LOAD_CONST', elem)
            self.check_lnotab(func)

        def f():
            'Adding a docstring made this test fail in Py2.5.0'
            return None

        self.assertNotInBytecode(f, 'LOAD_GLOBAL')
        self.assertInBytecode(f, 'LOAD_CONST', None)
        self.check_lnotab(f)

    def test_while_one(self):
        # Skip over:  LOAD_CONST trueconst  POP_JUMP_IF_FALSE xx
        def f():
            while 1:
                pass
            return list
        for elem in ('LOAD_CONST', 'POP_JUMP_IF_FALSE'):
            self.assertNotInBytecode(f, elem)
        for elem in ('JUMP_ABSOLUTE',):
            self.assertInBytecode(f, elem)
        self.check_lnotab(f)

    def test_pack_unpack(self):
        # On PyPy, "a, b = ..." is even more optimized, by removing
        # the ROT_TWO.  But the ROT_TWO is not removed if assigning
        # to more complex expressions, so check that.
        for line, elem in (
            ('a, = a,', 'LOAD_CONST',),
            ('a[1], b = a, b', 'ROT_TWO',),
            ('a, b[2], c = a, b, c', 'ROT_THREE',),
            ):
            code = compile(line,'','single')
            self.assertInBytecode(code, elem)
            self.assertNotInBytecode(code, 'BUILD_TUPLE')
            self.assertNotInBytecode(code, 'UNPACK_TUPLE')
            self.check_lnotab(code)

    def test_folding_of_tuples_of_constants(self):
        # On CPython, "a,b,c=1,2,3" turns into "a,b,c=<constant (1,2,3)>"
        # but on PyPy, it turns into "a=1;b=2;c=3".
        for line, elem in (
            ('a = 1,2,3', (1, 2, 3)),
            ('("a","b","c")', ('a', 'b', 'c')),
            ('(None, 1, None)', (None, 1, None)),
            ('((1, 2), 3, 4)', ((1, 2), 3, 4)),
            ):
            code = compile(line,'','single')
            self.assertInBytecode(code, 'LOAD_CONST', elem)
            self.assertNotInBytecode(code, 'BUILD_TUPLE')
            self.check_lnotab(code)

        # Long tuples should be folded too.
        code = compile(repr(tuple(range(10000))),'','single')
        self.assertNotInBytecode(code, 'BUILD_TUPLE')
        # One LOAD_CONST for the tuple, one for the None return value
        load_consts = [instr for instr in dis.get_instructions(code)
                              if instr.opname == 'LOAD_CONST']
        self.assertEqual(len(load_consts), 2)
        self.check_lnotab(code)

        # Bug 1053819:  Tuple of constants misidentified when presented with:
        # . . . opcode_with_arg 100   unary_opcode   BUILD_TUPLE 1  . . .
        # The following would segfault upon compilation
        def crater():
            (~[
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
                0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
            ],)
        self.check_lnotab(crater)

    def test_folding_of_lists_of_constants(self):
        for line, elem in (
            # in/not in constants with BUILD_LIST should be folded to a tuple:
            ('a in [1,2,3]', (1, 2, 3)),
            ('a not in ["a","b","c"]', ('a', 'b', 'c')),
            ('a in [None, 1, None]', (None, 1, None)),
            ('a not in [(1, 2), 3, 4]', ((1, 2), 3, 4)),
            ):
            code = compile(line, '', 'single')
            self.assertInBytecode(code, 'LOAD_CONST', elem)
            self.assertNotInBytecode(code, 'BUILD_LIST')
            self.check_lnotab(code)

    def test_folding_of_sets_of_constants(self):
        for line, elem in (
            # in/not in constants with BUILD_SET should be folded to a frozenset:
            ('a in {1,2,3}', frozenset({1, 2, 3})),
            ('a not in {"a","b","c"}', frozenset({'a', 'c', 'b'})),
            ('a in {None, 1, None}', frozenset({1, None})),
            ('a not in {(1, 2), 3, 4}', frozenset({(1, 2), 3, 4})),
            ('a in {1, 2, 3, 3, 2, 1}', frozenset({1, 2, 3})),
            ):
            code = compile(line, '', 'single')
            self.assertNotInBytecode(code, 'BUILD_SET')
            self.assertInBytecode(code, 'LOAD_CONST', elem)
            self.check_lnotab(code)

        # Ensure that the resulting code actually works:
        def f(a):
            return a in {1, 2, 3}

        def g(a):
            return a not in {1, 2, 3}

        self.assertTrue(f(3))
        self.assertTrue(not f(4))
        self.check_lnotab(f)

        self.assertTrue(not g(3))
        self.assertTrue(g(4))
        self.check_lnotab(g)


    def test_folding_of_binops_on_constants(self):
        for line, elem in (
            ('a = 2+3+4', 9),                   # chained fold
            ('"@"*4', '@@@@'),                  # check string ops
            ('a="abc" + "def"', 'abcdef'),      # check string ops
            ('a = 3**4', 81),                   # binary power
            ('a = 3*4', 12),                    # binary multiply
            ('a = 13//4', 3),                   # binary floor divide
            ('a = 14%4', 2),                    # binary modulo
            ('a = 2+3', 5),                     # binary add
            ('a = 13-4', 9),                    # binary subtract
            ('a = (12,13)[1]', 13),             # binary subscr
            ('a = 13 << 2', 52),                # binary lshift
            ('a = 13 >> 2', 3),                 # binary rshift
            ('a = 13 & 7', 5),                  # binary and
            ('a = 13 ^ 7', 10),                 # binary xor
            ('a = 13 | 7', 15),                 # binary or
            ):
            code = compile(line, '', 'single')
            self.assertInBytecode(code, 'LOAD_CONST', elem)
            for instr in dis.get_instructions(code):
                self.assertFalse(instr.opname.startswith('BINARY_'))
            self.check_lnotab(code)

        # Verify that unfoldables are skipped
        code = compile('a=2+"b"', '', 'single')
        self.assertInBytecode(code, 'LOAD_CONST', 2)
        self.assertInBytecode(code, 'LOAD_CONST', 'b')
        self.check_lnotab(code)

        # Verify that large sequences do not result from folding
        code = compile('a="x"*10000', '', 'single')
        self.assertInBytecode(code, 'LOAD_CONST', 10000)
        self.assertNotIn("x"*10000, code.co_consts)
        self.check_lnotab(code)
        code = compile('a=1<<1000', '', 'single')
        self.assertInBytecode(code, 'LOAD_CONST', 1000)
        self.assertNotIn(1<<1000, code.co_consts)
        self.check_lnotab(code)
        # difference to CPython: PyPy allows slightly larger constants to be
        # created
        code = compile('a=2**10000', '', 'single')
        self.assertInBytecode(code, 'LOAD_CONST', 10000)
        self.assertNotIn(2**10000, code.co_consts)
        self.check_lnotab(code)

    @cpython_only # we currently not bother to implement that
    def test_binary_subscr_on_unicode(self):
        # valid code get optimized
        code = compile('"foo"[0]', '', 'single')
        self.assertInBytecode(code, 'LOAD_CONST', 'f')
        self.assertNotInBytecode(code, 'BINARY_SUBSCR')
        self.check_lnotab(code)
        code = compile('"\u0061\uffff"[1]', '', 'single')
        self.assertInBytecode(code, 'LOAD_CONST', '\uffff')
        self.assertNotInBytecode(code,'BINARY_SUBSCR')
        self.check_lnotab(code)

        # With PEP 393, non-BMP char get optimized
        code = compile('"\U00012345"[0]', '', 'single')
        self.assertInBytecode(code, 'LOAD_CONST', '\U00012345')
        self.assertNotInBytecode(code, 'BINARY_SUBSCR')
        self.check_lnotab(code)

        # invalid code doesn't get optimized
        # out of range
        code = compile('"fuu"[10]', '', 'single')
        self.assertInBytecode(code, 'BINARY_SUBSCR')
        self.check_lnotab(code)

    def test_folding_of_unaryops_on_constants(self):
        for line, elem in (
            ('-0.5', -0.5),                     # unary negative
            ('-0.0', -0.0),                     # -0.0
            ('-(1.0-1.0)', -0.0),               # -0.0 after folding
            ('-0', 0),                          # -0
            ('~-2', 1),                         # unary invert
            ('+1', 1),                          # unary positive
        ):
            code = compile(line, '', 'single')
            self.assertInBytecode(code, 'LOAD_CONST', elem)
            for instr in dis.get_instructions(code):
                self.assertFalse(instr.opname.startswith('UNARY_'))
            self.check_lnotab(code)

        # Check that -0.0 works after marshaling
        def negzero():
            return -(1.0-1.0)

        for instr in dis.get_instructions(negzero):
            self.assertFalse(instr.opname.startswith('UNARY_'))
        self.check_lnotab(negzero)

        # Verify that unfoldables are skipped
        for line, elem, opname in (
            ('-"abc"', 'abc', 'UNARY_NEGATIVE'),
            ('~"abc"', 'abc', 'UNARY_INVERT'),
        ):
            code = compile(line, '', 'single')
            self.assertInBytecode(code, 'LOAD_CONST', elem)
            self.assertInBytecode(code, opname)
            self.check_lnotab(code)

    def test_elim_extra_return(self):
        # RETURN LOAD_CONST None RETURN  -->  RETURN
        def f(x):
            return x
        self.assertNotInBytecode(f, 'LOAD_CONST', None)
        returns = [instr for instr in dis.get_instructions(f)
                          if instr.opname == 'RETURN_VALUE']
        self.assertEqual(len(returns), 1)
        self.check_lnotab(f)

    def test_elim_jump_to_return(self):
        # JUMP_FORWARD to RETURN -->  RETURN
        def f(cond, true_value, false_value):
            # Intentionally use two-line expression to test issue37213.
            return (true_value if cond
                    else false_value)
        self.check_jump_targets(f)
        self.assertNotInBytecode(f, 'JUMP_FORWARD')
        self.assertNotInBytecode(f, 'JUMP_ABSOLUTE')
        returns = [instr for instr in dis.get_instructions(f)
                          if instr.opname == 'RETURN_VALUE']
        self.assertEqual(len(returns), 2)
        self.check_lnotab(f)

    def test_elim_jump_to_uncond_jump(self):
        # POP_JUMP_IF_FALSE to JUMP_FORWARD --> POP_JUMP_IF_FALSE to non-jump
        def f():
            if a:
                # Intentionally use two-line expression to test issue37213.
                if (c
                    or d):
                    foo()
            else:
                baz()
        self.check_jump_targets(f)
        self.check_lnotab(f)

    def test_elim_jump_to_uncond_jump2(self):
        # POP_JUMP_IF_FALSE to JUMP_ABSOLUTE --> POP_JUMP_IF_FALSE to non-jump
        def f():
            while a:
                # Intentionally use two-line expression to test issue37213.
                if (c
                    or d):
                    a = foo()
        self.check_jump_targets(f)
        self.check_lnotab(f)

    def test_elim_jump_to_uncond_jump3(self):
        # Intentionally use two-line expressions to test issue37213.
        # JUMP_IF_FALSE_OR_POP to JUMP_IF_FALSE_OR_POP --> JUMP_IF_FALSE_OR_POP to non-jump
        def f(a, b, c):
            return ((a and b)
                    and c)
        self.check_jump_targets(f)
        self.check_lnotab(f)
        self.assertEqual(count_instr_recursively(f, 'JUMP_IF_FALSE_OR_POP'), 2)
        # JUMP_IF_TRUE_OR_POP to JUMP_IF_TRUE_OR_POP --> JUMP_IF_TRUE_OR_POP to non-jump
        def f(a, b, c):
            return ((a or b)
                    or c)
        self.check_jump_targets(f)
        self.check_lnotab(f)
        self.assertEqual(count_instr_recursively(f, 'JUMP_IF_TRUE_OR_POP'), 2)
        # JUMP_IF_FALSE_OR_POP to JUMP_IF_TRUE_OR_POP --> POP_JUMP_IF_FALSE to non-jump
        def f(a, b, c):
            return ((a and b)
                    or c)
        self.check_jump_targets(f)
        self.check_lnotab(f)
        self.assertNotInBytecode(f, 'JUMP_IF_FALSE_OR_POP')
        self.assertInBytecode(f, 'JUMP_IF_TRUE_OR_POP')
        self.assertInBytecode(f, 'POP_JUMP_IF_FALSE')
        # JUMP_IF_TRUE_OR_POP to JUMP_IF_FALSE_OR_POP --> POP_JUMP_IF_TRUE to non-jump
        def f(a, b, c):
            return ((a or b)
                    and c)
        self.check_jump_targets(f)
        self.check_lnotab(f)
        self.assertNotInBytecode(f, 'JUMP_IF_TRUE_OR_POP')
        self.assertInBytecode(f, 'JUMP_IF_FALSE_OR_POP')
        self.assertInBytecode(f, 'POP_JUMP_IF_TRUE')

    def test_elim_jump_after_return1(self):
        # Eliminate dead code: jumps immediately after returns can't be reached
        def f(cond1, cond2):
            if cond1: return 1
            if cond2: return 2
            while 1:
                return 3
            while 1:
                if cond1: return 4
                return 5
            return 6
        self.assertNotInBytecode(f, 'JUMP_FORWARD')
        self.assertNotInBytecode(f, 'JUMP_ABSOLUTE')
        returns = [instr for instr in dis.get_instructions(f)
                          if instr.opname == 'RETURN_VALUE']
        self.assertLessEqual(len(returns), 6)
        self.check_lnotab(f)

    def test_elim_jump_after_return2(self):
        # Eliminate dead code: jumps immediately after returns can't be reached
        def f(cond1, cond2):
            while 1:
                if cond1: return 4
        self.assertNotInBytecode(f, 'JUMP_FORWARD')
        # There should be one jump for the while loop.
        returns = [instr for instr in dis.get_instructions(f)
                          if instr.opname == 'JUMP_ABSOLUTE']
        self.assertEqual(len(returns), 1)
        returns = [instr for instr in dis.get_instructions(f)
                          if instr.opname == 'RETURN_VALUE']
        self.assertLessEqual(len(returns), 2)
        self.check_lnotab(f)

    def test_make_function_doesnt_bail(self):
        def f():
            def g()->1+1:
                pass
            return g
        self.assertNotInBytecode(f, 'BINARY_ADD')
        self.check_lnotab(f)

    def test_constant_folding(self):
        # Issue #11244: aggressive constant folding.
        exprs = [
            '3 * -5',
            '-3 * 5',
            '2 * (3 * 4)',
            '(2 * 3) * 4',
            '(-1, 2, 3)',
            '(1, -2, 3)',
            '(1, 2, -3)',
            '(1, 2, -3) * 6',
            'lambda x: x in {(3 * -5) + (-1 - 6), (1, -2, 3) * 2, None}',
        ]
        for e in exprs:
            code = compile(e, '', 'single')
            for instr in dis.get_instructions(code):
                self.assertFalse(instr.opname.startswith('UNARY_'))
                self.assertFalse(instr.opname.startswith('BINARY_'))
                self.assertFalse(instr.opname.startswith('BUILD_'))
            self.check_lnotab(code)

    @cpython_only
    def test_in_literal_list(self):
        def containtest():
            return x in [a, b]
        self.assertEqual(count_instr_recursively(containtest, 'BUILD_LIST'), 0)
        self.check_lnotab(containtest)

    @cpython_only
    def test_iterate_literal_list(self):
        def forloop():
            for x in [a, b]:
                pass
        self.assertEqual(count_instr_recursively(forloop, 'BUILD_LIST'), 0)
        self.check_lnotab(forloop)

    def test_condition_with_binop_with_bools(self):
        def f():
            if True or False:
                return 1
            return 0
        self.assertEqual(f(), 1)
        self.check_lnotab(f)

    def test_if_with_if_expression(self):
        # Check bpo-37289
        def f(x):
            if (True if x else False):
                return True
            return False
        self.assertTrue(f(True))
        self.check_lnotab(f)

    def test_trailing_nops(self):
        # Check the lnotab of a function that even after trivial
        # optimization has trailing nops, which the lnotab adjustment has to
        # handle properly (bpo-38115).
        def f(x):
            while 1:
                return 3
            while 1:
                return 5
            return 6
        self.check_lnotab(f)

    def test_assignment_idiom_in_comprehensions(self):
        def listcomp():
            return [y for x in a for y in [f(x)]]
        self.assertEqual(count_instr_recursively(listcomp, 'FOR_ITER'), 1)
        def setcomp():
            return {y for x in a for y in [f(x)]}
        self.assertEqual(count_instr_recursively(setcomp, 'FOR_ITER'), 1)
        def dictcomp():
            return {y: y for x in a for y in [f(x)]}
        self.assertEqual(count_instr_recursively(dictcomp, 'FOR_ITER'), 1)
        def genexpr():
            return (y for x in a for y in [f(x)])
        self.assertEqual(count_instr_recursively(genexpr, 'FOR_ITER'), 1)


class TestBuglets(unittest.TestCase):

    def test_bug_11510(self):
        # folded constant set optimization was commingled with the tuple
        # unpacking optimization which would fail if the set had duplicate
        # elements so that the set length was unexpected
        def f():
            x, y = {1, 1}
            return x, y
        with self.assertRaises(ValueError):
            f()

    def test_bpo_42057(self):
        for i in range(10):
            try:
                raise Exception
            except Exception or Exception:
                pass


if __name__ == "__main__":
    unittest.main()
