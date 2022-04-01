import os
from pytest import raises
from pypy.interpreter.error import OperationError
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.astcompiler import ast
from pypy.interpreter.astcompiler import validate

POS = (0, 0, 0, 0)

class TestASTValidator:
    def mod(self, mod, msg=None, mode="exec", exc=validate.ValidationError):
        space = self.space
        if isinstance(exc, W_Root):
            w_exc = exc
            exc = OperationError
        else:
            w_exc = None
        with raises(exc) as cm:
            validate.validate_ast(space, mod)
        if w_exc is not None:
            w_value = cm.value.get_w_value(space)
            assert cm.value.match(space, w_exc)
            exc_msg = str(cm.value)
        else:
            exc_msg = str(cm.value)
        if msg is not None:
            assert msg in exc_msg

    def expr(self, node, msg=None, exc=validate.ValidationError):
        mod = ast.Module([ast.Expr(node, *POS)], [])
        self.mod(mod, msg, exc=exc)

    def stmt(self, stmt, msg=None):
        mod = ast.Module([stmt], [])
        self.mod(mod, msg)

    def test_module(self):
        m = ast.Interactive([ast.Expr(ast.Name("x", ast.Store, *POS), *POS)])
        self.mod(m, "must have Load context", "single")
        m = ast.Expression(ast.Name("x", ast.Store, *POS))
        self.mod(m, "must have Load context", "eval")

    def _check_arguments(self, fac, check):
        def arguments(args=None, posonlyargs=None, vararg=None,
                      kwonlyargs=None, kwarg=None,
                      defaults=None, kw_defaults=None):
            if args is None:
                args = []
            if posonlyargs is None:
                posonlyargs = []
            if kwonlyargs is None:
                kwonlyargs = []
            if defaults is None:
                defaults = []
            if kw_defaults is None:
                kw_defaults = []
            args = ast.arguments(args, posonlyargs, vararg, kwonlyargs,
                                 kw_defaults, kwarg, defaults)
            return fac(args)
        args = [ast.arg("x", ast.Name("x", ast.Store, *POS), None, *POS)]
        check(arguments(args=args), "must have Load context")
        check(arguments(posonlyargs=args), "must have Load context")
        check(arguments(kwonlyargs=args), "must have Load context")
        check(arguments(defaults=[ast.Constant(self.space.wrap(3), self.space.w_None, *POS)]),
                       "more positional defaults than args")
        check(arguments(kw_defaults=[ast.Constant(self.space.wrap(4), self.space.w_None, *POS)]),
                       "length of kwonlyargs is not the same as kw_defaults")
        args = [ast.arg("x", ast.Name("x", ast.Load, *POS), None, *POS)]
        check(arguments(args=args, defaults=[ast.Name("x", ast.Store, *POS)]),
                       "must have Load context")
        args = [ast.arg("a", ast.Name("x", ast.Load, *POS), None, *POS),
                ast.arg("b", ast.Name("y", ast.Load, *POS), None, *POS)]
        check(arguments(kwonlyargs=args,
                          kw_defaults=[None, ast.Name("x", ast.Store, *POS)]),
                          "must have Load context")

    def test_funcdef(self):
        a = ast.arguments(None, [], None, [], [], None, [])
        f = ast.FunctionDef("x", a, [], [], None, None, *POS)
        self.stmt(f, "empty body on FunctionDef")
        f = ast.FunctionDef("x", a, [ast.Pass(*POS)], [ast.Name("x", ast.Store, *POS)],
                            None, None, *POS)
        self.stmt(f, "must have Load context")
        f = ast.FunctionDef("x", a, [ast.Pass(*POS)], [],
                            ast.Name("x", ast.Store, *POS), None, *POS)
        self.stmt(f, "must have Load context")
        def fac(args):
            return ast.FunctionDef("x", args, [ast.Pass(*POS)], [], None, None, *POS)
        self._check_arguments(fac, self.stmt)

    def test_classdef(self):
        def cls(bases=None, keywords=None, body=None, decorator_list=None):
            if bases is None:
                bases = []
            if keywords is None:
                keywords = []
            if body is None:
                body = [ast.Pass(*POS)]
            if decorator_list is None:
                decorator_list = []
            return ast.ClassDef("myclass", bases, keywords,
                                body, decorator_list, *POS)
        self.stmt(cls(bases=[ast.Name("x", ast.Store, *POS)]),
                  "must have Load context")
        self.stmt(cls(keywords=[ast.keyword("x", ast.Name("x", ast.Store, *POS), *POS)]),
                  "must have Load context")
        self.stmt(cls(body=[]), "empty body on ClassDef")
        self.stmt(cls(body=[None]), "None disallowed")
        self.stmt(cls(decorator_list=[ast.Name("x", ast.Store, *POS)]),
                  "must have Load context")

    def test_delete(self):
        self.stmt(ast.Delete([], *POS), "empty targets on Delete")
        self.stmt(ast.Delete([None], *POS), "None disallowed")
        self.stmt(ast.Delete([ast.Name("x", ast.Load, *POS)], *POS),
                  "must have Del context")

    def test_assign(self):
        self.stmt(ast.Assign([], ast.Constant(self.space.wrap(3), self.space.w_None, *POS), None, *POS), "empty targets on Assign")
        self.stmt(ast.Assign([None], ast.Constant(self.space.wrap(3), self.space.w_None, *POS), None, *POS), "None disallowed")
        self.stmt(ast.Assign([ast.Name("x", ast.Load, *POS)], ast.Constant(self.space.wrap(3), self.space.w_None, *POS), None, *POS),
                  "must have Store context")
        self.stmt(ast.Assign([ast.Name("x", ast.Store, *POS)],
                                ast.Name("y", ast.Store, *POS), None, *POS),
                  "must have Load context")

    def test_augassign(self):
        aug = ast.AugAssign(ast.Name("x", ast.Load, *POS), ast.Add,
                            ast.Name("y", ast.Load, *POS), *POS)
        self.stmt(aug, "must have Store context")
        aug = ast.AugAssign(ast.Name("x", ast.Store, *POS), ast.Add,
                            ast.Name("y", ast.Store, *POS), *POS)
        self.stmt(aug, "must have Load context")

    def test_for(self):
        x = ast.Name("x", ast.Store, *POS)
        y = ast.Name("y", ast.Load, *POS)
        p = ast.Pass(*POS)
        self.stmt(ast.For(x, y, [], [], None, *POS), "empty body on For")
        self.stmt(ast.For(ast.Name("x", ast.Load, *POS), y, [p], [], None, *POS),
                  "must have Store context")
        self.stmt(ast.For(x, ast.Name("y", ast.Store, *POS), [p], [], None, *POS),
                  "must have Load context")
        e = ast.Expr(ast.Name("x", ast.Store, *POS), *POS)
        self.stmt(ast.For(x, y, [e], [], None, *POS), "must have Load context")
        self.stmt(ast.For(x, y, [p], [e], None, *POS), "must have Load context")

    def test_while(self):
        self.stmt(ast.While(ast.Constant(self.space.wrap(3), self.space.w_None, *POS), [], [], *POS), "empty body on While")
        self.stmt(ast.While(ast.Name("x", ast.Store, *POS), [ast.Pass(*POS)], [], *POS),
                  "must have Load context")
        self.stmt(ast.While(ast.Constant(self.space.wrap(3), self.space.w_None, *POS), [ast.Pass(*POS)],
                             [ast.Expr(ast.Name("x", ast.Store, *POS), *POS)], *POS),
                             "must have Load context")

    def test_if(self):
        self.stmt(ast.If(ast.Constant(self.space.wrap(3), self.space.w_None, *POS), [], [], *POS), "empty body on If")
        i = ast.If(ast.Name("x", ast.Store, *POS), [ast.Pass(*POS)], [], *POS)
        self.stmt(i, "must have Load context")
        i = ast.If(ast.Constant(self.space.wrap(3), self.space.w_None, *POS), [ast.Expr(ast.Name("x", ast.Store, *POS), *POS)], [], *POS)
        self.stmt(i, "must have Load context")
        i = ast.If(ast.Constant(self.space.wrap(3), self.space.w_None, *POS), [ast.Pass(*POS)],
                   [ast.Expr(ast.Name("x", ast.Store, *POS), *POS)], *POS)
        self.stmt(i, "must have Load context")

    def test_with(self):
        p = ast.Pass(*POS)
        self.stmt(ast.With([], [p], None, *POS), "empty items on With")
        i = ast.withitem(ast.Constant(self.space.wrap(3), self.space.w_None, *POS), None)
        self.stmt(ast.With([i], [], None, *POS), "empty body on With")
        i = ast.withitem(ast.Name("x", ast.Store, *POS), None)
        self.stmt(ast.With([i], [p], None, *POS), "must have Load context")
        i = ast.withitem(ast.Constant(self.space.wrap(3), self.space.w_None, *POS), ast.Name("x", ast.Load, *POS))
        self.stmt(ast.With([i], [p], None, *POS), "must have Store context")

    def test_raise(self):
        r = ast.Raise(None, ast.Constant(self.space.wrap(3), self.space.w_None, *POS), *POS)
        self.stmt(r, "Raise with cause but no exception")
        r = ast.Raise(ast.Name("x", ast.Store, *POS), None, *POS)
        self.stmt(r, "must have Load context")
        r = ast.Raise(ast.Constant(self.space.wrap(4), self.space.w_None, *POS), ast.Name("x", ast.Store, *POS), *POS)
        self.stmt(r, "must have Load context")

    def test_try(self):
        p = ast.Pass(*POS)
        t = ast.Try([], [], [], [p], *POS)
        self.stmt(t, "empty body on Try")
        t = ast.Try([ast.Expr(ast.Name("x", ast.Store, *POS), *POS)], [], [], [p], *POS)
        self.stmt(t, "must have Load context")
        t = ast.Try([p], [], [], [], *POS)
        self.stmt(t, "Try has neither except handlers nor finalbody")
        t = ast.Try([p], [], [p], [p], *POS)
        self.stmt(t, "Try has orelse but no except handlers")
        t = ast.Try([p], [ast.ExceptHandler(None, "x", [], *POS)], [], [], *POS)
        self.stmt(t, "empty body on ExceptHandler")
        e = [ast.ExceptHandler(ast.Name("x", ast.Store, *POS), "y", [p], *POS)]
        self.stmt(ast.Try([p], e, [], [], *POS), "must have Load context")
        e = [ast.ExceptHandler(None, "x", [p], *POS)]
        t = ast.Try([p], e, [ast.Expr(ast.Name("x", ast.Store, *POS), *POS)], [p], *POS)
        self.stmt(t, "must have Load context")
        t = ast.Try([p], e, [p], [ast.Expr(ast.Name("x", ast.Store, *POS), *POS)], *POS)
        self.stmt(t, "must have Load context")

    def test_assert(self):
        self.stmt(ast.Assert(ast.Name("x", ast.Store, *POS), None, *POS),
                  "must have Load context")
        assrt = ast.Assert(ast.Name("x", ast.Load, *POS),
                           ast.Name("y", ast.Store, *POS), *POS)
        self.stmt(assrt, "must have Load context")

    def test_import(self):
        self.stmt(ast.Import([], *POS), "empty names on Import")

    def test_importfrom(self):
        imp = ast.ImportFrom(None, [ast.alias("x", None)], -42, *POS)
        self.stmt(imp, "Negative ImportFrom level")
        self.stmt(ast.ImportFrom(None, [], 0, *POS), "empty names on ImportFrom")

    def test_global(self):
        self.stmt(ast.Global([], *POS), "empty names on Global")

    def test_nonlocal(self):
        self.stmt(ast.Nonlocal([], *POS), "empty names on Nonlocal")

    def test_expr(self):
        e = ast.Expr(ast.Name("x", ast.Store, *POS), *POS)
        self.stmt(e, "must have Load context")

    def test_name(self):
        for name in ("True", "False", "None"):
            e = ast.Name(name, ast.Load, *POS)
            self.expr(e, "can't be used with '%s' constant" % name)

    def test_boolop(self):
        b = ast.BoolOp(ast.And, [], *POS)
        self.expr(b, "less than 2 values")
        b = ast.BoolOp(ast.And, None, *POS)
        self.expr(b, "less than 2 values")
        b = ast.BoolOp(ast.And, [ast.Constant(self.space.wrap(3), self.space.w_None, *POS)], *POS)
        self.expr(b, "less than 2 values")
        b = ast.BoolOp(ast.And, [ast.Constant(self.space.wrap(4), self.space.w_None, *POS), None], *POS)
        self.expr(b, "None disallowed")
        b = ast.BoolOp(ast.And, [ast.Constant(self.space.wrap(4), self.space.w_None, *POS), ast.Name("x", ast.Store, *POS)], *POS)
        self.expr(b, "must have Load context")

    def test_unaryop(self):
        u = ast.UnaryOp(ast.Not, ast.Name("x", ast.Store, *POS), *POS)
        self.expr(u, "must have Load context")

    def test_lambda(self):
        a = ast.arguments(None, [], None, [], [], None, [])
        self.expr(ast.Lambda(a, ast.Name("x", ast.Store, *POS), *POS),
                  "must have Load context")
        def fac(args):
            return ast.Lambda(args, ast.Name("x", ast.Load, *POS), *POS)
        self._check_arguments(fac, self.expr)

    def test_ifexp(self):
        l = ast.Name("x", ast.Load, *POS)
        s = ast.Name("y", ast.Store, *POS)
        for args in (s, l, l), (l, s, l), (l, l, s):
            self.expr(ast.IfExp(*(args + POS)), "must have Load context")

    def test_dict(self):
        d = ast.Dict([], [ast.Name("x", ast.Load, *POS)], *POS)
        self.expr(d, "same number of keys as values")
        # This is now valid, and used for ``{**x}``
        #d = ast.Dict([None], [ast.Name("x", ast.Load, *POS)], *POS)
        #self.expr(d, "None disallowed")
        d = ast.Dict([ast.Name("x", ast.Load, *POS)], [None], *POS)
        self.expr(d, "None disallowed")

    def test_set(self):
        self.expr(ast.Set([None], *POS), "None disallowed")
        s = ast.Set([ast.Name("x", ast.Store, *POS)], *POS)
        self.expr(s, "must have Load context")

    def _check_comprehension(self, fac):
        self.expr(fac([]), "comprehension with no generators")
        g = ast.comprehension(ast.Name("x", ast.Load, *POS),
                              ast.Name("x", ast.Load, *POS), [], False)
        self.expr(fac([g]), "must have Store context")
        g = ast.comprehension(ast.Name("x", ast.Store, *POS),
                              ast.Name("x", ast.Store, *POS), [], False)
        self.expr(fac([g]), "must have Load context")
        x = ast.Name("x", ast.Store, *POS)
        y = ast.Name("y", ast.Load, *POS)
        g = ast.comprehension(x, y, [None], False)
        self.expr(fac([g]), "None disallowed")
        g = ast.comprehension(x, y, [ast.Name("x", ast.Store, *POS)], False)
        self.expr(fac([g]), "must have Load context")

    def _simple_comp(self, fac):
        g = ast.comprehension(ast.Name("x", ast.Store, *POS),
                              ast.Name("x", ast.Load, *POS), [], False)
        self.expr(fac(ast.Name("x", ast.Store, *POS), [g], *POS),
                  "must have Load context")
        def wrap(gens):
            return fac(ast.Name("x", ast.Store, *POS), gens, *POS)
        self._check_comprehension(wrap)

    def test_listcomp(self):
        self._simple_comp(ast.ListComp)

    def test_setcomp(self):
        self._simple_comp(ast.SetComp)

    def test_generatorexp(self):
        self._simple_comp(ast.GeneratorExp)

    def test_dictcomp(self):
        g = ast.comprehension(ast.Name("y", ast.Store, *POS),
                              ast.Name("p", ast.Load, *POS), [], False)
        c = ast.DictComp(ast.Name("x", ast.Store, *POS),
                         ast.Name("y", ast.Load, *POS), [g], *POS)
        self.expr(c, "must have Load context")
        c = ast.DictComp(ast.Name("x", ast.Load, *POS),
                         ast.Name("y", ast.Store, *POS), [g], *POS)
        self.expr(c, "must have Load context")
        def factory(comps):
            k = ast.Name("x", ast.Load, *POS)
            v = ast.Name("y", ast.Load, *POS)
            return ast.DictComp(k, v, comps, *POS)
        self._check_comprehension(factory)

    def test_yield(self):
        self.expr(ast.Yield(ast.Name("x", ast.Store, *POS), *POS), "must have Load")
        self.expr(ast.YieldFrom(ast.Name("x", ast.Store, *POS), *POS), "must have Load")

    def test_compare(self):
        left = ast.Name("x", ast.Load, *POS)
        comp = ast.Compare(left, [ast.In], [], *POS)
        self.expr(comp, "no comparators")
        comp = ast.Compare(left, [ast.In], [ast.Constant(self.space.wrap(4), self.space.w_None, *POS), ast.Constant(self.space.wrap(5), self.space.w_None, *POS)], *POS)
        self.expr(comp, "different number of comparators and operands")

    def test_call(self):
        func = ast.Name("x", ast.Load, *POS)
        args = [ast.Name("y", ast.Load, *POS)]
        keywords = [ast.keyword("w", ast.Name("z", ast.Load, *POS), *POS)]
        call = ast.Call(ast.Name("x", ast.Store, *POS), args, keywords, *POS)
        self.expr(call, "must have Load context")
        call = ast.Call(func, [None], keywords, *POS)
        self.expr(call, "None disallowed")
        bad_keywords = [ast.keyword("w", ast.Name("z", ast.Store, *POS), *POS)]
        call = ast.Call(func, args, bad_keywords, *POS)
        self.expr(call, "must have Load context")

    def test_attribute(self):
        attr = ast.Attribute(ast.Name("x", ast.Store, *POS), "y", ast.Load, *POS)
        self.expr(attr, "must have Load context")

    def test_subscript(self):
        sub = ast.Subscript(ast.Name("x", ast.Store, *POS), ast.Constant(self.space.wrap(3), self.space.w_None, *POS),
                            ast.Load, *POS)
        self.expr(sub, "must have Load context")
        x = ast.Name("x", ast.Load, *POS)
        sub = ast.Subscript(x, ast.Name("y", ast.Store, *POS),
                            ast.Load, *POS)
        self.expr(sub, "must have Load context")
        s = ast.Name("x", ast.Store, *POS)
        for args in (s, None, None), (None, s, None), (None, None, s):
            sl = ast.Slice(*args + POS)
            self.expr(ast.Subscript(x, sl, ast.Load, *POS),
                      "must have Load context")

    def test_starred(self):
        left = ast.List([ast.Starred(ast.Name("x", ast.Load, *POS), ast.Store, *POS)],
                        ast.Store, *POS)
        assign = ast.Assign([left], ast.Constant(self.space.wrap(4), self.space.w_None, *POS), None, *POS)
        self.stmt(assign, "must have Store context")

    def _sequence(self, fac):
        self.expr(fac([None], ast.Load, *POS), "None disallowed")
        self.expr(fac([ast.Name("x", ast.Store, *POS)], ast.Load, *POS),
                  "must have Load context")

    def test_list(self):
        self._sequence(ast.List)

    def test_tuple(self):
        self._sequence(ast.Tuple)

    def test_constant(self):
        node = ast.Constant(self.space.newlist([1]), self.space.w_None, *POS)
        self.expr(node, "got an invalid type in Constant: list",
                  exc=validate.ValidationTypeError)

    def test_constant_subtypes(self):
        space = self.space
        w_objs = space.appexec([], """():
        class subint(int):
            pass
        class subfloat(float):
            pass
        class subcomplex(complex):
            pass
        return (subint(), subfloat(), subcomplex())
        """)
        for w_obj in space.unpackiterable(w_objs):
            self.expr(ast.Constant(w_obj, self.space.w_None, *POS), "got an invalid type in Constant")

    def test_subscript_tuple(self):
        # check that this valid code validates
        ec = self.space.getexecutioncontext()
        ast_node = ec.compiler.compile_to_ast("x = nd[()]", "?", "exec", 0)
        validate.validate_ast(self.space, ast_node)

    def test_stdlib_validates(self):
        stdlib = os.path.join(os.path.dirname(ast.__file__), '../../../lib-python/3')
        if 0:    # enable manually for a complete test
            tests = [fn for fn in os.listdir(stdlib) if fn.endswith('.py')]
            tests += ['test/'+fn for fn in os.listdir(stdlib+'/test')
                                 if fn.endswith('.py')
                                    and not fn.startswith('bad')]
            tests.sort()
        else:
            tests = ["os.py", "test/test_grammar.py", "test/test_unpack_ex.py"]
        #
        for module in tests:
            fn = os.path.join(stdlib, module)
            print 'compiling', fn
            with open(fn, "r") as fp:
                source = fp.read()
            ec = self.space.getexecutioncontext()
            ast_node = ec.compiler.compile_to_ast(source, fn, "exec", 0)
            ec.compiler.validate_ast(ast_node)
            ast_node.to_object(self.space) # does not crash
