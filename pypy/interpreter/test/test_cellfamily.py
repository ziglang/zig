""" some unit-level tests for the nested scope CellFamily optimization. """

from pypy.interpreter.nestedscope import Cell, CellFamily
from pypy.interpreter.pycode import _compute_args_as_cellvars

class TestCellFamily:
    def setup_class(cls):
        cls.compiler = cls.space.createcompiler()

    def test_mutation(self):
        f = CellFamily("x")
        c = Cell("value", f)
        assert c.family is f
        assert not c.family.ever_mutated

        c.set("othervalue")
        assert c.family.ever_mutated

    def test_mutation_after_empty_creation(self):
        f = CellFamily("x")
        c = Cell(None, f)
        assert not c.family.ever_mutated

        c.set("value")
        assert not c.family.ever_mutated

        c.set("surprise")
        assert c.family.ever_mutated

    def test_mutation(self):
        f = CellFamily("x")
        c = Cell("value", f)
        assert c.family is f
        assert not c.family.ever_mutated

        c.delete()
        assert c.family.ever_mutated

    def test_cellfamily_on_code(self):
        code = self.compiler.compile('lambda x: x + 5', '<hello>', 'eval', 0)
        lambdacode = code.co_consts_w[0]
        assert lambdacode.cell_families == [] # doesn't create any cells
        code = self.compiler.compile('lambda x, a: (lambda y: x + y + a)', '<hello>', 'eval', 0)
        lambdacode = code.co_consts_w[0]
        assert len(lambdacode.cell_families) == 2 # creates cells

    def test_nonarg_cell_indexes(self):
        args_as_cellvars = _compute_args_as_cellvars(["a", "b"], ["x", "b", "y"], 2)
        assert args_as_cellvars == [-1, 1]

        args_as_cellvars = _compute_args_as_cellvars(["a", "b"], ["a", "y", "z"], 2)
        assert args_as_cellvars == [0]

    def test_passing_args_doesnt_mutate_cells(self):
        space = self.space
        code = self.compiler.compile('lambda x: (lambda y: x + y)', '<hello>', 'eval', 0)
        w_outer = code.exec_code(space, space.newdict(), space.newdict())
        w_i = space.newint(5)
        w_inner = space.call_function(w_outer, w_i)
        cell = w_inner.closure[0]
        assert cell.w_value is w_i
        assert not cell.family.ever_mutated

    def test_integration(self):
        # it still works for x
        space = self.space
        code = self.compiler.compile("""def f(x):
            def g(y):
                return x + a * y
            a = x * 2
            return g
            """, '<hello>', 'exec', 0)
        w_d = space.newdict()
        code.exec_code(space, w_d, w_d)
        w_outer = space.finditem_str(w_d, "f")
        w_i = space.newint(5)
        w_inner = space.call_function(w_outer, w_i)
        # both x and a are never mutated (only initialized)
        for cell in w_inner.closure:
            assert not cell.family.ever_mutated

    def test_cells_dont_interfere(self):
        # it still works for x
        space = self.space
        code = self.compiler.compile("""def f(x):
            def g(y):
                return x + a * y
            a = x * 2
            a = x * 4 # really mutate it
            return g
            """, '<hello>', 'exec', 0)
        w_d = space.newdict()
        code.exec_code(space, w_d, w_d)
        w_outer = space.finditem_str(w_d, "f")
        w_i = space.newint(5)
        w_inner = space.call_function(w_outer, w_i)
        for cell in w_inner.closure:
            if cell.w_value is w_i:
                break
        assert not cell.family.ever_mutated
