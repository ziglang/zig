import py
from pypy.module.micronumpy.compile import (numpy_compile, Assignment,
    ArrayConstant, NumberConstant, Operator, Variable, RangeConstant, Execute,
    FunctionCall, FakeSpace, W_NDimArray)


class TestCompiler(object):
    def compile(self, code):
        return numpy_compile(code)

    def test_vars(self):
        code = """
        a = 2
        b = 3
        """
        interp = self.compile(code)
        assert isinstance(interp.code.statements[0], Assignment)
        assert interp.code.statements[0].name == 'a'
        assert interp.code.statements[0].expr.v == 2
        assert interp.code.statements[1].name == 'b'
        assert interp.code.statements[1].expr.v == 3

    def test_array_literal(self):
        code = "a = [1,2,3]"
        interp = self.compile(code)
        assert isinstance(interp.code.statements[0].expr, ArrayConstant)
        st = interp.code.statements[0]
        assert st.expr.items == [NumberConstant(1), NumberConstant(2),
                                 NumberConstant(3)]

    def test_array_literal2(self):
        code = "a = [[1],[2],[3]]"
        interp = self.compile(code)
        assert isinstance(interp.code.statements[0].expr, ArrayConstant)
        st = interp.code.statements[0]
        assert st.expr.items == [ArrayConstant([NumberConstant(1)]),
                                 ArrayConstant([NumberConstant(2)]),
                                 ArrayConstant([NumberConstant(3)])]

    def test_expr_1(self):
        code = "b = a + 1"
        interp = self.compile(code)
        assert (interp.code.statements[0].expr ==
                Operator(Variable("a"), "+", NumberConstant(1)))

    def test_expr_2(self):
        code = "b = a + b - 3"
        interp = self.compile(code)
        assert (interp.code.statements[0].expr ==
                Operator(Operator(Variable("a"), "+", Variable("b")), "-",
                         NumberConstant(3)))

    def test_expr_3(self):
        # an equivalent of range
        code = "a = |20|"
        interp = self.compile(code)
        assert interp.code.statements[0].expr == RangeConstant(20)

    def test_expr_only(self):
        code = "3 + a"
        interp = self.compile(code)
        assert interp.code.statements[0] == Execute(
            Operator(NumberConstant(3), "+", Variable("a")))

    def test_array_access(self):
        code = "a -> 3"
        interp = self.compile(code)
        assert interp.code.statements[0] == Execute(
            Operator(Variable("a"), "->", NumberConstant(3)))

    def test_function_call(self):
        code = "sum(a)"
        interp = self.compile(code)
        assert interp.code.statements[0] == Execute(
            FunctionCall("sum", [Variable("a")]))

    def test_comment(self):
        code = """
        # some comment
        a = b + 3  # another comment
        """
        interp = self.compile(code)
        assert interp.code.statements[0] == Assignment(
            'a', Operator(Variable('b'), "+", NumberConstant(3)))


class TestRunner(object):
    def run(self, code):
        interp = numpy_compile(code)
        space = FakeSpace()
        interp.run(space)
        return interp

    def test_one(self):
        code = """
        a = 3
        b = 4
        a + b
        """
        interp = self.run(code)
        assert sorted(interp.variables.keys()) == ['a', 'b']
        assert interp.results[0]

    def test_array_add(self):
        code = """
        a = [1,2,3,4]
        b = [4,5,6,5]
        c = a + b
        c -> 3
        """
        interp = self.run(code)
        assert interp.results[-1].value == 9

    def test_array_getitem(self):
        code = """
        a = [1,2,3,4]
        b = [4,5,6,5]
        a + b -> 3
        """
        interp = self.run(code)
        assert interp.results[0].value == 3 + 6

    def test_range_getitem(self):
        code = """
        r = |20| + 3
        r -> 3
        """
        interp = self.run(code)
        assert interp.results[0].value == 6

    def test_sum(self):
        code = """
        a = [1,2,3,4,5]
        r = sum(a)
        r
        """
        interp = self.run(code)
        assert interp.results[0].get_scalar_value().value == 15

    def test_sum2(self):
        code = """
        a = |30|
        b = a + a
        sum(b)
        """
        interp = self.run(code)
        assert interp.results[0].get_scalar_value().value == 30 * (30 - 1)


    def test_array_write(self):
        code = """
        a = [1,2,3,4,5]
        a[3] = 15
        a -> 3
        """
        interp = self.run(code)
        assert interp.results[0].value == 15

    def test_min(self):
        interp = self.run("""
        a = |30|
        a[15] = -12
        b = a + a
        min(b)
        """)
        assert interp.results[0].get_scalar_value().value == -24

    def test_max(self):
        interp = self.run("""
        a = |30|
        a[13] = 128
        b = a + a
        max(b)
        """)
        assert interp.results[0].get_scalar_value().value == 256

    def test_slice(self):
        interp = self.run("""
        a = [1,2,3,4]
        b = a -> :
        b -> 3
        """)
        assert interp.results[0].value == 4

    def test_slice_step(self):
        interp = self.run("""
        a = |30|
        b = a -> ::2
        b -> 3
        """)
        assert interp.results[0].value == 6

    def test_setslice(self):
        interp = self.run("""
        a = |30|
        b = |10|
        b[1] = 5
        a[::3] = b
        a -> 3
        """)
        assert interp.results[0].value == 5


    def test_slice2(self):
        interp = self.run("""
        a = |30|
        s1 = a -> 0:20:2
        s2 = a -> 0:30:3
        b = s1 + s2
        b -> 3
        """)
        assert interp.results[0].value == 15

    def test_multidim_getitem(self):
        interp = self.run("""
        a = [[1,2]]
        a -> 0 -> 1
        """)
        assert interp.results[0].value == 2

    def test_multidim_getitem_2(self):
        interp = self.run("""
        a = [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10]]
        b = a + a
        b -> 1 -> 1
        """)
        assert interp.results[0].value == 8

    def test_set_slice(self):
        interp = self.run("""
        a = |30|
        b = |30|
        b[:] = a + a
        b -> 3
        """)
        assert interp.results[0].value == 6

    def test_set_slice2(self):
        interp = self.run("""
        a = |30|
        b = |10|
        b[1] = 5.5
        c = b + b
        a[0:30:3] = c
        a -> 3
        """)
        assert interp.results[0].value == 11

    def test_dot(self):
        interp = self.run("""
        a = [[1, 2], [3, 4]]
        b = [[5, 6], [7, 8]]
        c = dot(a, b)
        c -> 0 -> 0
        """)
        assert interp.results[0].value == 19

    def test_flat_iter(self):
        interp = self.run('''
        a = |30|
        b = flat(a)
        b -> 3
        ''')
        assert interp.results[0].value == 3

    def test_take(self):
        py.test.skip("unsupported")
        interp = self.run("""
        a = |10|
        b = take(a, [1, 1, 3, 2])
        b -> 2
        """)
        assert interp.results[0].value == 3

    def test_any(self):
        interp = self.run("""
        a = [0,0,0,0,0.1,0,0,0,0]
        b = any(a)
        b -> 0
        """)
        assert interp.results[0].value == 1

    def test_where(self):
        interp = self.run('''
        a = [1, 0, 3, 0]
        b = [1, 1, 1, 1]
        c = [0, 0, 0, 0]
        d = where(a, b, c)
        d -> 1
        ''')
        assert interp.results[0].value == 0

    def test_complex(self):
        interp = self.run('''
        a = (0, 1)
        b = [(0, 1), (1, 0)]
        b -> 0
        ''')
        assert interp.results[0].real == 0
        assert interp.results[0].imag == 1

    def test_view_none(self):
        interp = self.run('''
        a = [1, 0, 3, 0]
        b = None
        c = view(a, b)
        c -> 0
        ''')
        assert interp.results[0].value == 1

    def test_view_ndarray(self):
        interp = self.run('''
        a = [1, 0, 3, 0]
        b = ndarray
        c = view(a, b)
        c
        ''')
        results = interp.results[0]
        assert isinstance(results, W_NDimArray)

    def test_view_dtype(self):
        interp = self.run('''
        a = [1, 0, 3, 0]
        b = int
        c = view(a, b)
        c
        ''')
        results = interp.results[0]
        assert isinstance(results, W_NDimArray)

    def test_astype_dtype(self):
        interp = self.run('''
        a = [1, 0, 3, 0]
        b = int
        c = astype(a, b)
        c
        ''')
        results = interp.results[0]
        assert isinstance(results, W_NDimArray)
        assert results.get_dtype().is_int()

    def test_searchsorted(self):
        interp = self.run('''
        a = [1, 4, 5, 6, 9]
        b = |30| -> ::-1
        c = searchsorted(a, b)
        c -> -1
        ''')
        assert interp.results[0].value == 0
