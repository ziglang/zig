import pytest
from pypy.interpreter.pyparser import pyparse
from pypy.interpreter.astcompiler import ast, consts
from pypy.interpreter.astcompiler.unparse import unparse, unparse_annotations


class TestAstUnparser:
    def setup_class(cls):
        cls.parser = pyparse.PythonParser(cls.space)

    def get_ast(self, source, p_mode="exec", flags=None):
        if flags is None:
            flags = consts.CO_FUTURE_WITH_STATEMENT
        ec = self.space.getexecutioncontext()
        ast_node = ec.compiler.compile_to_ast(source, "?", p_mode, flags)
        return ast_node

    def get_first_expr(self, source, p_mode="exec", flags=None):
        mod = self.get_ast(source, p_mode, flags)
        assert len(mod.body) == 1
        expr = mod.body[0]
        assert isinstance(expr, ast.Expr)
        return expr.value

    def check(self, expr, unparsed=None):
        if unparsed is None:
            unparsed = expr
        ast = self.get_first_expr(expr)
        assert unparse(self.space, ast) == unparsed
        # should be stable
        if expr != unparsed:
            ast = self.get_first_expr(unparsed)
            assert unparse(self.space, ast) == unparsed

    def test_constant(self):
        w_one = self.space.newint(1)
        node = ast.Constant(w_one, self.space.w_None, 0, 0, 0, 0)
        assert unparse(self.space, node) == "1"

    def test_num(self):
        self.check("1")
        self.check("1.64")

    def test_str(self):
        self.check("u'a'", "'a'")

    def test_bytes(self):
        self.check("b'a'")

    def test_name(self):
        self.check('a')

    def test_name_constant(self):
        self.check('True')
        self.check('False')
        self.check('None')

    def test_unaryop(self):
        self.check('+a')
        self.check('-a')
        self.check('~a')
        self.check('not a')

    def test_binaryop(self):
        self.check('b+a', "b + a")
        self.check('c*(b+a)', "c * (b + a)")
        self.check('c**(b+a)', "c ** (b + a)")
        self.check('2**2**3', "2 ** 2 ** 3")
        self.check('(2**2)**3', "(2 ** 2) ** 3")
        
        self.check('2 << 2 << 3')
        self.check('2<<(2<<3)', "2 << (2 << 3)")

    def test_compare(self):
        self.check('b == 5 == c == d')

    def test_boolop(self):
        self.check('b and a and c or d')

    def test_if(self):
        self.check('a if b else c')
        self.check('0 if not x else 1 if x > 0 else -1')

    def test_list(self):
        self.check('[]')
        self.check('[1, 2, 3, 4]')

    def test_tuple(self):
        self.check('()')
        self.check('(a,)')
        self.check('([1, 2], a + 6, 3, 4)')

    def test_sets(self):
        self.check('{1}')
        self.check('{(1, 2), a + 6, 3, 4}')

    def test_dict(self):
        self.check('{}')
        self.check('{a: b, c: d}')
        self.check('{1: 2, **x}')

    def test_list_comprehension(self):
        self.check('[a for x in y if b if c]')

    def test_genexp(self):
        self.check('(a for x in y for z in b)')

    def test_set_comprehension(self):
        self.check('{a for x, in y for z in b}')

    def test_dict_comprehension(self):
        self.check('{a: b for x in y}')

    def test_ellipsis(self):
        self.check('...')

    def test_index(self):
        self.check('a[1]')
        self.check('a[1:5]')
        self.check('a[1:5, 7:12, :, 5]')
        self.check('a[::1]')
        self.check('dict[(str, int)]', 'dict[str, int]')

    def test_attribute(self):
        self.check('a.b.c')
        self.check('1 .b')
        self.check('1.5.b')

    def test_yield(self):
        self.check('(yield)')
        self.check('(yield 4 + 6)')

    def test_yield_from(self):
        self.check('(yield from a)')

    def test_call(self):
        self.check('f()')
        self.check('f(a)')
        self.check('f(a, b, 1)')
        self.check('f(a, b, 1, a=4, b=78)')
        self.check('f(a, x=y, **b, **c)')
        self.check('f(*a)')
        self.check('f(x for y in z)')

    def test_lambda(self):
        self.check('lambda: 1')
        self.check('lambda a: 1')
        self.check('lambda a=1: 1')
        self.check('lambda b, c: 1')
        self.check('lambda *l: 1')
        self.check('lambda *, m, l=5: 1')
        self.check('lambda **foo: 1')
        self.check('lambda a, **b: 45')

    def test_fstrings(self):
        self.check('f"abc"', "'abc'")
        self.check("f'{{{a}'", "f'{{{a}'")
        self.check("f'{{{a}'", "f'{{{a}'")
        self.check("f'{x+1!a}'", "f'{x + 1!a}'")
        self.check("f'{x+1:x}'", "f'{x + 1:x}'")
        self.check("f'some f-string with {a} {few():.2f} {formatted.values!r}'")
        self.check('''f"{f'{nested} inner'} outer"''')
        self.check("f'space between opening braces: { {a for a in (1, 2, 3)}}'")
        self.check("f'{(lambda x: x)}'")
        self.check("f'{(None if a else lambda x: x)}'")

class TestAstUnparseAnnotations(object):
    def setup_class(cls):
        cls.parser = pyparse.PythonParser(cls.space)

    def get_ast(self, source, p_mode="exec", flags=None):
        if flags is None:
            flags = consts.CO_FUTURE_WITH_STATEMENT
        ec = self.space.getexecutioncontext()
        ast_node = ec.compiler.compile_to_ast(source, "?", p_mode, flags)
        return ast_node

    def test_function(self):
        ast = self.get_ast("""def f(a: b) -> 1 + 2: return a + 12""")
        func = ast.body[0]
        res = unparse_annotations(self.space, func)
        assert self.space.text_w(res.args.args[0].annotation.value) == "b"
        assert self.space.text_w(res.returns.value) == "1 + 2"

    def test_global(self):
        ast = self.get_ast("""a: list[int]""")
        res = unparse_annotations(self.space, ast)
        assert self.space.text_w(res.body[0].annotation.value) == 'list[int]'

    def test_await(self):
        ast = self.get_ast("""def f() -> await some.complicated[0].call(with_args=True or 1 is not 1): pass""")
        func = ast.body[0]
        res = unparse_annotations(self.space, func)
        assert self.space.text_w(res.returns.value) == "await some.complicated[0].call(with_args=True or 1 is not 1)"
