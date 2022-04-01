import string
import py
from pypy.interpreter.astcompiler import ast, symtable, consts
from pypy.interpreter.pyparser import pyparse
from pypy.interpreter.pyparser.error import SyntaxError


class TestSymbolTable:

    def setup_class(cls):
        cls.parser = pyparse.PythonParser(cls.space)

    def mod_scope(self, source, mode="exec"):
        ec = self.space.getexecutioncontext()
        module = ec.compiler.compile_to_ast(source, "<test>", mode, 0)
        info = pyparse.CompileInfo("<test>", mode, 0)
        builder = symtable.SymtableBuilder(self.space, module, info)
        scope = builder.find_scope(module)
        assert isinstance(scope, symtable.ModuleScope)
        return scope

    def func_scope(self, func_code):
        mod_scope = self.mod_scope(func_code)
        assert len(mod_scope.children) == 1
        func_name = mod_scope.lookup("f")
        assert func_name == symtable.SCOPE_LOCAL
        func_scope = mod_scope.children[0]
        assert isinstance(func_scope, symtable.FunctionScope)
        return func_scope

    def class_scope(self, class_code):
        mod_scope = self.mod_scope(class_code)
        assert len(mod_scope.children) == 1
        class_name = mod_scope.lookup("x")
        assert class_name == symtable.SCOPE_LOCAL
        class_scope = mod_scope.children[0]
        assert isinstance(class_scope, symtable.ClassScope)
        return class_scope

    def gen_scope(self, gen_code):
        mod_scope = self.mod_scope(gen_code)
        assert len(mod_scope.children) == 1
        gen_scope = mod_scope.children[0]
        assert isinstance(gen_scope, symtable.FunctionScope)
        assert not gen_scope.children
        assert gen_scope.name == "<genexpr>"
        return mod_scope, gen_scope

    def check_unknown(self, scp, *names):
        for name in names:
            assert scp.lookup(name) == symtable.SCOPE_UNKNOWN

    def test_toplevel(self):
        scp = self.mod_scope("x = 4")
        assert scp.lookup("x") == symtable.SCOPE_LOCAL
        assert not scp.optimized
        scp = self.mod_scope("x = 4", "single")
        assert not scp.optimized
        assert scp.lookup("x") == symtable.SCOPE_LOCAL
        scp = self.mod_scope("x*4*6", "eval")
        assert not scp.optimized
        assert scp.lookup("x") == symtable.SCOPE_GLOBAL_IMPLICIT

    def test_duplicate_argument(self):
        input = "def f(x, x): pass"
        exc = py.test.raises(SyntaxError, self.mod_scope, input).value
        assert exc.msg == "duplicate argument 'x' in function definition"
        input = "def f(x,\nx): pass"
        exc = py.test.raises(SyntaxError, self.mod_scope, input).value
        assert exc.msg == "duplicate argument 'x' in function definition"
        assert exc.lineno == 2

    def test_function_defaults(self):
        scp = self.mod_scope("y = w = 4\ndef f(x=y, *, z=w): return x")
        self.check_unknown(scp, "x")
        self.check_unknown(scp, "z")
        assert scp.lookup("y") == symtable.SCOPE_LOCAL
        assert scp.lookup("w") == symtable.SCOPE_LOCAL
        scp = scp.children[0]
        assert scp.lookup("x") == symtable.SCOPE_LOCAL
        assert scp.lookup("z") == symtable.SCOPE_LOCAL
        self.check_unknown(scp, "y")
        self.check_unknown(scp, "w")

    def test_function_annotations(self):
        scp = self.mod_scope("def f(x : X) -> Y: pass")
        assert scp.lookup("X") == symtable.SCOPE_GLOBAL_IMPLICIT
        assert scp.lookup("Y") == symtable.SCOPE_GLOBAL_IMPLICIT
        scp = scp.children[0]
        self.check_unknown(scp, "X")
        self.check_unknown(scp, "Y")

    def check_comprehension(self, template):
        def brack(s):
            return template % (s,)
        scp, gscp = self.gen_scope(brack("y[1] for y in z"))
        assert scp.lookup("z") == symtable.SCOPE_GLOBAL_IMPLICIT
        self.check_unknown(scp, "y", "x")
        self.check_unknown(gscp, "z")
        assert gscp.lookup("y") == symtable.SCOPE_LOCAL
        assert gscp.lookup(".0") == symtable.SCOPE_LOCAL
        scp, gscp = self.gen_scope(brack("x for x in z if x"))
        self.check_unknown(scp, "x")
        assert gscp.lookup("x") == symtable.SCOPE_LOCAL
        scp, gscp = self.gen_scope(brack("x for y in g for f in n if f[h]"))
        self.check_unknown(scp, "f")
        assert gscp.lookup("f") == symtable.SCOPE_LOCAL

    def test_genexp(self):
        self.check_comprehension("(%s)")

    def test_listcomp(self):
        self.check_comprehension("[%s]")

    def test_setcomp(self):
        self.check_comprehension("{%s}")

    def test_dictcomp(self):
        scp, gscp = self.gen_scope("{x : x[3] for x in y}")
        assert scp.lookup("y") == symtable.SCOPE_GLOBAL_IMPLICIT
        self.check_unknown(scp, "a", "b", "x")
        self.check_unknown(gscp, "y")
        assert gscp.lookup("x") == symtable.SCOPE_LOCAL
        assert gscp.lookup(".0") == symtable.SCOPE_LOCAL
        scp, gscp = self.gen_scope("{x : x[1] for x in y if x[23]}")
        self.check_unknown(scp, "x")
        assert gscp.lookup("x") == symtable.SCOPE_LOCAL

    def test_arguments(self):
        scp = self.func_scope("def f(): pass")
        assert not scp.children
        self.check_unknown(scp, "x", "y")
        assert not scp.symbols
        assert not scp.roles
        scp = self.func_scope("def f(x): pass")
        assert scp.lookup("x") == symtable.SCOPE_LOCAL
        scp = self.func_scope("def f(*x): pass")
        assert scp.has_variable_arg
        assert not scp.has_keywords_arg
        assert scp.lookup("x") == symtable.SCOPE_LOCAL
        scp = self.func_scope("def f(**x): pass")
        assert scp.has_keywords_arg
        assert not scp.has_variable_arg
        assert scp.lookup("x") == symtable.SCOPE_LOCAL

    def test_arguments_kwonly(self):
        scp = self.func_scope("def f(a, *b, c, **d): pass")
        varnames = ["a", "c", "b", "d"]
        for name in varnames:
            assert scp.lookup(name) == symtable.SCOPE_LOCAL
        assert scp.varnames == varnames
        scp = self.func_scope("def f(a, b=0, *args, k1, k2=0): pass")
        assert scp.varnames == ["a", "b", "k1", "k2", "args"]

    def test_function(self):
        scp = self.func_scope("def f(): x = 4")
        assert scp.lookup("x") == symtable.SCOPE_LOCAL
        scp = self.func_scope("def f(): x")
        assert scp.lookup("x") == symtable.SCOPE_GLOBAL_IMPLICIT

    def test_exception_variable(self):
        scp = self.mod_scope("try: pass\nexcept ValueError as e: pass")
        assert scp.lookup("e") == symtable.SCOPE_LOCAL

    def test_nested_scopes(self):
        def nested_scope(*bodies):
            names = enumerate("f" + string.ascii_letters)
            lines = []
            for body, (level, name) in zip(bodies, names):
                lines.append(" " * level + "def %s():\n" % (name,))
                if body:
                    if isinstance(body, str):
                        body = [body]
                    lines.extend(" " * (level + 1) + line + "\n"
                                 for line in body)
            return self.func_scope("".join(lines))
        scp = nested_scope("x = 1", "return x")
        assert not scp.has_free
        assert scp.child_has_free
        assert scp.lookup("x") == symtable.SCOPE_CELL
        child = scp.children[0]
        assert child.has_free
        assert child.lookup("x") == symtable.SCOPE_FREE
        scp = nested_scope("x = 1", None, "return x")
        assert not scp.has_free
        assert scp.child_has_free
        assert scp.lookup("x") == symtable.SCOPE_CELL
        child = scp.children[0]
        assert not child.has_free
        assert child.child_has_free
        assert child.lookup("x") == symtable.SCOPE_FREE
        child = child.children[0]
        assert child.has_free
        assert not child.child_has_free
        assert child.lookup("x") == symtable.SCOPE_FREE
        scp = nested_scope("x = 1", "x = 3", "return x")
        assert scp.child_has_free
        assert not scp.has_free
        assert scp.lookup("x") == symtable.SCOPE_LOCAL
        child = scp.children[0]
        assert child.child_has_free
        assert not child.has_free
        assert child.lookup("x") == symtable.SCOPE_CELL
        child = child.children[0]
        assert child.has_free
        assert child.lookup("x") == symtable.SCOPE_FREE

    def test_class(self):
        scp = self.mod_scope("class x(A, B): pass")
        cscp = scp.children[0]
        for name in ("A", "B"):
            assert scp.lookup(name) == symtable.SCOPE_GLOBAL_IMPLICIT
            self.check_unknown(cscp, name)
        scp = self.func_scope("""def f(x):
    class X:
         def n():
              return x
         a = x
    return X()""")
        self.check_unknown(scp, "a")
        assert scp.lookup("x") == symtable.SCOPE_CELL
        assert scp.lookup("X") == symtable.SCOPE_LOCAL
        cscp = scp.children[0]
        assert cscp.lookup("a") == symtable.SCOPE_LOCAL
        assert cscp.lookup("x") == symtable.SCOPE_FREE
        fscp = cscp.children[0]
        assert fscp.lookup("x") == symtable.SCOPE_FREE
        self.check_unknown(fscp, "a")
        scp = self.func_scope("""def f(n):
    class X:
         def n():
             return y
         def x():
             return n""")
        assert scp.lookup("n") == symtable.SCOPE_CELL
        cscp = scp.children[0]
        assert cscp.lookup("n") == symtable.SCOPE_LOCAL
        assert "n" in cscp.free_vars
        xscp = cscp.children[1]
        assert xscp.lookup("n") == symtable.SCOPE_FREE

    def test_class_kwargs(self):
        scp = self.func_scope("""def f(n):
            class X(meta=Z, *args, **kwargs):
                 pass""")
        assert scp.lookup("X") == symtable.SCOPE_LOCAL
        assert scp.lookup("Z") == symtable.SCOPE_GLOBAL_IMPLICIT
        assert scp.lookup("args") == symtable.SCOPE_GLOBAL_IMPLICIT
        assert scp.lookup("kwargs") == symtable.SCOPE_GLOBAL_IMPLICIT

    def test_lambda(self):
        scp = self.mod_scope("lambda x: y")
        self.check_unknown(scp, "x", "y")
        assert len(scp.children) == 1
        lscp = scp.children[0]
        assert isinstance(lscp, symtable.FunctionScope)
        assert lscp.name == "<lambda>"
        assert lscp.lookup("x") == symtable.SCOPE_LOCAL
        assert lscp.lookup("y") == symtable.SCOPE_GLOBAL_IMPLICIT
        scp = self.mod_scope("lambda x=a: b")
        self.check_unknown(scp, "x", "b")
        assert scp.lookup("a") == symtable.SCOPE_GLOBAL_IMPLICIT
        lscp = scp.children[0]
        self.check_unknown(lscp, "a")

    def test_import(self):
        scp = self.mod_scope("import x")
        assert scp.lookup("x") == symtable.SCOPE_LOCAL
        scp = self.mod_scope("import x as y")
        assert scp.lookup("y") == symtable.SCOPE_LOCAL
        self.check_unknown(scp, "x")
        scp = self.mod_scope("import x.y")
        assert scp.lookup("x") == symtable.SCOPE_LOCAL
        self.check_unknown(scp, "y")

    def test_from_import(self):
        scp = self.mod_scope("from x import y")
        self.check_unknown("x")
        assert scp.lookup("y") == symtable.SCOPE_LOCAL
        scp = self.mod_scope("from a import b as y")
        assert scp.lookup("y") == symtable.SCOPE_LOCAL
        self.check_unknown(scp, "a", "b")
        scp = self.mod_scope("from x import *")
        self.check_unknown("x")

    def test_global(self):
        scp = self.func_scope("def f():\n   global x\n   x = 4")
        assert scp.lookup("x") == symtable.SCOPE_GLOBAL_EXPLICIT
        scp = self.func_scope("""def f():
    y = 3
    def x():
        global y
        y = 4
    def z():
        return y""")
        assert scp.lookup("y") == symtable.SCOPE_CELL
        xscp, zscp = scp.children
        assert xscp.lookup("y") == symtable.SCOPE_GLOBAL_EXPLICIT
        assert zscp.lookup("y") == symtable.SCOPE_FREE

        src = "def f(x):\n   global x"
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.msg == "name 'x' is parameter and global"
        assert exc.lineno == 2

    def test_global_nested(self):
        src = """
def f(x):
    def g(x):
        global x"""
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.lineno == 4
        assert exc.msg == "name 'x' is parameter and global"

        scp = self.func_scope("""
def f(x):
    def g():
        global x""")
        g = scp.children[0]
        assert g.name == 'g'
        x = g.lookup_role('x')
        assert x == symtable.SYM_GLOBAL

    def test_global_after_assignment(self):
        src = ("def f():\n"
               "    x = 1\n"
               "    global x\n")
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.lineno == 3
        assert exc.msg == "name 'x' is assigned to before global declaration"

    def test_nonlocal(self):
        src = """
x = 1
def f():
    nonlocal x"""
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.msg == "no binding for nonlocal 'x' found"
        assert exc.lineno == 4

        src = str(py.code.Source("""
                     def f(x):
                         nonlocal x
                 """))
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.msg == "name 'x' is parameter and nonlocal"
        assert exc.lineno == 3
        #
        src = str(py.code.Source("""
                     def f():
                         nonlocal x
                 """))
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.msg == "no binding for nonlocal 'x' found"
        #
        src = "nonlocal x"
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.msg == "nonlocal declaration not allowed at module level"
        assert exc.lineno == 1

        src = "x = 2\nnonlocal x"
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.msg == "nonlocal declaration not allowed at module level"
        assert exc.lineno == 2

    def test_nonlocal_and_global(self):
        """This test differs from CPython3 behaviour. CPython points to the
        first occurance of the global/local expression. PyPy will point to the
        last expression which makes the problem."""
        src = """
def f():
    nonlocal x
    global x"""
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.msg == "name 'x' is nonlocal and global"
        assert exc.lineno == 4

        src = """
def f():
    global x
    nonlocal x """
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.msg == "name 'x' is nonlocal and global"
        assert exc.lineno == 4

    def test_nonlocal_nested(self):
        scp = self.func_scope("""
def f(x):
    def g():
        nonlocal x""")
        g = scp.children[0]
        x = g.lookup_role('x')
        assert x == symtable.SYM_NONLOCAL

        scp = self.func_scope("""
def f():
    def g():
        nonlocal x
    x = 1""")
        g = scp.children[0]
        x = g.lookup_role('x')
        assert x == symtable.SYM_NONLOCAL

        src = """
def f(x):
    def g(x):
        nonlocal x"""
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.msg == "name 'x' is parameter and nonlocal"
        assert exc.lineno == 4

    def test_nonlocal_after_assignment(self):
        src = ("def f():\n"
               "    x = 1\n"
               "    nonlocal x\n")
        exc = py.test.raises(SyntaxError, self.func_scope, src).value
        assert exc.lineno == 3
        assert exc.msg == "name 'x' is assigned to before nonlocal declaration"

    def test_optimization(self):
        assert not self.mod_scope("").can_be_optimized
        assert not self.class_scope("class x: pass").can_be_optimized
        assert self.func_scope("def f(): pass").can_be_optimized

    def test_importstar_nonglobal(self):
        src = str(py.code.Source("""
                     def f():
                         from re import *
                     """))
        exc = py.test.raises(SyntaxError, self.mod_scope, src)
        assert exc.value.msg == "import * only allowed at module level"
        #
        src = str(py.code.Source("""
                     def f():
                         def g():
                             from re import *
                     """))
        exc = py.test.raises(SyntaxError, self.mod_scope, src)
        assert exc.value.msg == "import * only allowed at module level"

        src = str(py.code.Source("""
                     if True:
                         from re import *
                     """))
        scp = self.mod_scope(src)
        assert scp # did not raise

    def test_yield(self):
        scp = self.func_scope("def f(): yield x")
        assert scp.is_generator
        for input in ("yield x", "class y: yield x"):
            exc = py.test.raises(SyntaxError, self.mod_scope, "yield x").value
            assert exc.msg == "'yield' outside function"
        for input in ("yield\n    return x", "return x\n    yield"):
            input = "def f():\n    " + input
            scp = self.func_scope(input)
        scp = self.func_scope("def f():\n    return\n    yield x")

    def test_async_def(self):
        # CPython compatibility only; "is_generator" is otherwise ignored
        scp = self.func_scope("async def f(): pass")
        assert not scp.is_generator
        scp = self.func_scope("async def f(): await 5")
        assert not scp.is_generator

    def test_yield_inside_try(self):
        scp = self.func_scope("def f(): yield x")
        assert not scp.has_yield_inside_try
        scp = self.func_scope("def f():\n  try:\n    yield x\n  except: pass")
        assert scp.has_yield_inside_try
        scp = self.func_scope("def f():\n  try:\n    yield x\n  finally: pass")
        assert scp.has_yield_inside_try
        scp = self.func_scope("def f():\n    with x: yield y")
        assert scp.has_yield_inside_try

    def test_yield_outside_try(self):
        for input in ("try: pass\n    except: pass",
                      "try: pass\n    except: yield y",
                      "try: pass\n    finally: pass",
                      "try: pass\n    finally: yield y",
                      "with x: pass"):
            input = "def f():\n    yield y\n    %s\n    yield y" % (input,)
            assert not self.func_scope(input).has_yield_inside_try

    def test_return(self):
        for input in ("class x: return", "return"):
            exc = py.test.raises(SyntaxError, self.func_scope, input).value
            assert exc.msg == "return outside function"

    def test_tmpnames(self):
        scp = self.mod_scope("with x: pass")
        assert scp.lookup("_[1]") == symtable.SCOPE_LOCAL

    def test_annotation_global(self):
        src_global = ("def f():\n"
                      "    x: int\n"
                      "    global x\n")
        exc_global = py.test.raises(SyntaxError, self.func_scope, src_global).value
        assert exc_global.msg == "annotated name 'x' can't be global"
        assert exc_global.lineno == 3

    def test_annotation_global2(self):
        src_global = ("def f():\n"
                      "    global x\n"
                      "    x: int\n")
        exc_global = py.test.raises(SyntaxError, self.func_scope, src_global).value
        assert exc_global.msg == "annotated name 'x' can't be global"
        assert exc_global.lineno == 3

    def test_annotation_nonlocal(self):
        src_nonlocal = ("def f():\n"
                        "    x: int\n"
                        "    nonlocal x\n")
        exc_nonlocal = py.test.raises(SyntaxError, self.func_scope, src_nonlocal).value
        assert exc_nonlocal.msg == "annotated name 'x' can't be nonlocal"
        assert exc_nonlocal.lineno == 3

    def test_annotation_assignment(self):
        scp = self.mod_scope("x: int = 1")
        assert scp.contains_annotated == True

        scp2 = self.mod_scope("x = 1")
        assert scp2.contains_annotated == False

        fscp = self.func_scope("def f(): x: int")
        assert fscp.contains_annotated == False
        assert fscp.lookup("x") == symtable.SCOPE_LOCAL

    def test_nonsimple_annotation(self):
        fscp = self.func_scope("def f(): implicit_global[0]: int")
        assert fscp.lookup("implicit_global") == symtable.SCOPE_GLOBAL_IMPLICIT

        fscp = self.func_scope("def f(): (implicit_global): int")
        assert fscp.lookup("implicit_global") == symtable.SCOPE_UNKNOWN

    def test_issue13343(self):
        scp = self.mod_scope("lambda *, k1=x, k2: None")
        assert scp.lookup("x") == symtable.SCOPE_GLOBAL_IMPLICIT

    def test_named_expr_list_comprehension(self):
        fscp = self.func_scope("def f(): [(y := x) for x in range(5)]")
        assert fscp.lookup("y") == symtable.SCOPE_CELL
