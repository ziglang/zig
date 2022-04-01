# -*- coding: utf-8 -*-
import random
import string
import sys
import pytest
import functools
import textwrap
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.pyparser import pyparse
from pypy.interpreter.pyparser.error import SyntaxError
from pypy.interpreter.error import OperationError
from pypy.interpreter.astcompiler import ast, consts


class TestAstBuilding:

    def setup_class(cls):
        cls.parser = pyparse.PegParser(cls.space)

    def setup_method(self, method):
        self.info = None

    def get_ast(self, source, p_mode=None, flags=None, with_async_hacks=False):
        if p_mode is None:
            p_mode = "exec"
        if flags is None:
            flags = consts.CO_FUTURE_WITH_STATEMENT
        if with_async_hacks:
            flags |= consts.PyCF_ASYNC_HACKS
        info = pyparse.CompileInfo("<test>", p_mode, flags)
        self.info = info
        ast_node = self.parser.parse_source(source, info)
        ast_node.to_object(self.space) # does not crash
        return ast_node

    def get_first_expr(self, source, p_mode=None, flags=None):
        mod = self.get_ast(source, p_mode, flags)
        assert len(mod.body) == 1
        expr = mod.body[0]
        assert isinstance(expr, ast.Expr)
        return expr.value

    def get_first_stmt(self, source, p_mode=None, flags=None):
        mod = self.get_ast(source, p_mode, flags)
        assert len(mod.body) == 1
        return mod.body[0]

    def test_top_level(self):
        mod = self.get_ast("hi = 32")
        assert isinstance(mod, ast.Module)
        body = mod.body
        assert len(body) == 1

        mod = self.get_ast("hi", p_mode="eval")
        assert isinstance(mod, ast.Expression)
        assert isinstance(mod.body, ast.expr)

        mod = self.get_ast("x = 23", p_mode="single")
        assert isinstance(mod, ast.Interactive)
        assert len(mod.body) == 1
        mod = self.get_ast("x = 23; y = 23; b = 23", p_mode="single")
        assert isinstance(mod, ast.Interactive)
        assert len(mod.body) == 3
        for stmt in mod.body:
            assert isinstance(stmt, ast.Assign)
        assert mod.body[-1].targets[0].id == "b"

        mod = self.get_ast("x = 23; y = 23; b = 23")
        assert isinstance(mod, ast.Module)
        assert len(mod.body) == 3
        for stmt in mod.body:
            assert isinstance(stmt, ast.Assign)

    def test_constant_kind_bug(self):
        d = self.get_first_expr("None") # used to crash in to_object

    def test_del(self):
        d = self.get_first_stmt("del x")
        assert isinstance(d, ast.Delete)
        assert len(d.targets) == 1
        assert isinstance(d.targets[0], ast.Name)
        assert d.targets[0].ctx == ast.Del
        d = self.get_first_stmt("del x, y")
        assert len(d.targets) == 2
        assert d.targets[0].ctx == ast.Del
        assert d.targets[1].ctx == ast.Del
        d = self.get_first_stmt("del x.y")
        assert len(d.targets) == 1
        attr = d.targets[0]
        assert isinstance(attr, ast.Attribute)
        assert attr.ctx == ast.Del
        d = self.get_first_stmt("del x[:]")
        assert len(d.targets) == 1
        sub = d.targets[0]
        assert isinstance(sub, ast.Subscript)
        assert sub.ctx == ast.Del

    def test_break(self):
        br = self.get_first_stmt("while True: break").body[0]
        assert isinstance(br, ast.Break)

    def test_continue(self):
        cont = self.get_first_stmt("while True: continue").body[0]
        assert isinstance(cont, ast.Continue)

    def test_return(self):
        ret = self.get_first_stmt("def f(): return").body[0]
        assert isinstance(ret, ast.Return)
        assert ret.value is None
        ret = self.get_first_stmt("def f(): return x").body[0]
        assert isinstance(ret.value, ast.Name)

    def test_raise(self):
        ra = self.get_first_stmt("raise")
        assert ra.exc is None
        assert ra.cause is None
        ra = self.get_first_stmt("raise x")
        assert isinstance(ra.exc, ast.Name)
        assert ra.cause is None
        ra = self.get_first_stmt("raise x from 3")
        assert isinstance(ra.exc, ast.Name)
        assert isinstance(ra.cause, ast.Constant)

    def test_import(self):
        im = self.get_first_stmt("import x")
        assert isinstance(im, ast.Import)
        assert len(im.names) == 1
        alias = im.names[0]
        assert isinstance(alias, ast.alias)
        assert alias.name == "x"
        assert alias.asname is None
        im = self.get_first_stmt("import x.y")
        assert len(im.names) == 1
        alias = im.names[0]
        assert alias.name == "x.y"
        assert alias.asname is None
        im = self.get_first_stmt("import x as y")
        assert len(im.names) == 1
        alias = im.names[0]
        assert alias.name == "x"
        assert alias.asname == "y"
        im = self.get_first_stmt("import x, y as w")
        assert len(im.names) == 2
        a1, a2 = im.names
        assert a1.name == "x"
        assert a1.asname is None
        assert a2.name == "y"
        assert a2.asname == "w"
        with pytest.raises(SyntaxError) as excinfo:
            self.get_ast("import x a b")
        assert excinfo.value.text == "import x a b\n"

    def test_from_import(self):
        im = self.get_first_stmt("from x import y")
        assert isinstance(im, ast.ImportFrom)
        assert im.module == "x"
        assert im.level == 0
        assert len(im.names) == 1
        a = im.names[0]
        assert isinstance(a, ast.alias)
        assert a.name == "y"
        assert a.asname is None
        im = self.get_first_stmt("from . import y")
        assert im.level == 1
        assert im.module is None
        im = self.get_first_stmt("from ... import y")
        assert im.level == 3
        assert im.module is None
        im = self.get_first_stmt("from .x import y")
        assert im.level == 1
        assert im.module == "x"
        im = self.get_first_stmt("from ..x.y import m")
        assert im.level == 2
        assert im.module == "x.y"
        im = self.get_first_stmt("from x import *")
        assert len(im.names) == 1
        a = im.names[0]
        assert a.name == "*"
        assert a.asname is None
        for input in ("from x import x, y", "from x import (x, y)"):
            im = self.get_first_stmt(input)
            assert len(im.names) == 2
            a1, a2 = im.names
            assert a1.name == "x"
            assert a1.asname is None
            assert a2.name == "y"
            assert a2.asname is None
        for input in ("from x import a as b, w", "from x import (a as b, w)"):
            im = self.get_first_stmt(input)
            assert len(im.names) == 2
            a1, a2 = im.names
            assert a1.name == "a"
            assert a1.asname == "b"
            assert a2.name == "w"
            assert a2.asname is None

        input = "from x import y a b"
        with pytest.raises(SyntaxError) as excinfo:
            self.get_ast(input)
        assert excinfo.value.text == input + "\n"

        input = "from x import a, b,"
        with pytest.raises(SyntaxError) as excinfo:
            self.get_ast(input)
        assert excinfo.value.msg == "trailing comma not allowed without surrounding " \
            "parentheses"
        assert excinfo.value.text == input + "\n"

    def test_global(self):
        glob = self.get_first_stmt("global x")
        assert isinstance(glob, ast.Global)
        assert glob.names == ["x"]
        glob = self.get_first_stmt("global x, y")
        assert glob.names == ["x", "y"]

    def test_nonlocal(self):
        nonloc = self.get_first_stmt("nonlocal x")
        assert isinstance(nonloc, ast.Nonlocal)
        assert nonloc.names == ["x"]
        nonloc = self.get_first_stmt("nonlocal x, y")
        assert nonloc.names == ["x", "y"]

    def test_assert(self):
        asrt = self.get_first_stmt("assert x")
        assert isinstance(asrt, ast.Assert)
        assert isinstance(asrt.test, ast.Name)
        assert asrt.msg is None
        asrt = self.get_first_stmt("assert x, 'hi'")
        assert isinstance(asrt.test, ast.Name)
        assert isinstance(asrt.msg, ast.Constant)

    def test_suite(self):
        suite = self.get_first_stmt("while x: n;").body
        assert len(suite) == 1
        assert isinstance(suite[0].value, ast.Name)
        suite = self.get_first_stmt("while x: n").body
        assert len(suite) == 1
        suite = self.get_first_stmt("while x: \n    n;").body
        assert len(suite) == 1
        suite = self.get_first_stmt("while x: n;").body
        assert len(suite) == 1
        suite = self.get_first_stmt("while x:\n    n; f;").body
        assert len(suite) == 2

    def test_if(self):
        if_ = self.get_first_stmt("if x: 4")
        assert isinstance(if_, ast.If)
        assert isinstance(if_.test, ast.Name)
        assert if_.test.ctx == ast.Load
        assert len(if_.body) == 1
        assert isinstance(if_.body[0].value, ast.Constant)
        assert if_.orelse is None
        if_ = self.get_first_stmt("if x: 4\nelse: 'hi'")
        assert isinstance(if_.test, ast.Name)
        assert len(if_.body) == 1
        assert isinstance(if_.body[0].value, ast.Constant)
        assert len(if_.orelse) == 1
        assert isinstance(if_.orelse[0].value, ast.Constant)
        if_ = self.get_first_stmt("if x: 3\nelif 'hi': pass")
        assert isinstance(if_.test, ast.Name)
        assert len(if_.orelse) == 1
        sub_if = if_.orelse[0]
        assert isinstance(sub_if, ast.If)
        assert isinstance(sub_if.test, ast.Constant)
        assert sub_if.orelse is None
        if_ = self.get_first_stmt("if x: pass\nelif 'hi': 3\nelse: ()")
        assert isinstance(if_.test, ast.Name)
        assert len(if_.body) == 1
        assert isinstance(if_.body[0], ast.Pass)
        assert len(if_.orelse) == 1
        sub_if = if_.orelse[0]
        assert isinstance(sub_if, ast.If)
        assert isinstance(sub_if.test, ast.Constant)
        assert len(sub_if.body) == 1
        assert isinstance(sub_if.body[0].value, ast.Constant)
        assert len(sub_if.orelse) == 1
        assert isinstance(sub_if.orelse[0].value, ast.Tuple)

    def test_elif_pos_bug(self):
        if_ = self.get_first_stmt("if x: 3\nelif \\\n 'hi': pass")
        assert isinstance(if_.test, ast.Name)
        assert len(if_.orelse) == 1
        sub_if = if_.orelse[0]
        assert sub_if.lineno == 2
        assert sub_if.col_offset == 0
        if_ = self.get_first_stmt("if x: 3\nelif \\\n 'hi': pass\nelse: pass")
        assert isinstance(if_.test, ast.Name)
        assert len(if_.orelse) == 1
        sub_if = if_.orelse[0]
        assert sub_if.lineno == 2
        assert sub_if.col_offset == 0

    def test_while(self):
        wh = self.get_first_stmt("while x: pass")
        assert isinstance(wh, ast.While)
        assert isinstance(wh.test, ast.Name)
        assert wh.test.ctx == ast.Load
        assert len(wh.body) == 1
        assert isinstance(wh.body[0], ast.Pass)
        assert wh.orelse is None
        wh = self.get_first_stmt("while x: pass\nelse: 4")
        assert isinstance(wh.test, ast.Name)
        assert len(wh.body) == 1
        assert isinstance(wh.body[0], ast.Pass)
        assert len(wh.orelse) == 1
        assert isinstance(wh.orelse[0].value, ast.Constant)

    def test_for(self):
        fr = self.get_first_stmt("for x in y: pass")
        assert isinstance(fr, ast.For)
        assert isinstance(fr.target, ast.Name)
        assert fr.target.ctx == ast.Store
        assert isinstance(fr.iter, ast.Name)
        assert fr.iter.ctx == ast.Load
        assert len(fr.body) == 1
        assert isinstance(fr.body[0], ast.Pass)
        assert fr.orelse is None
        fr = self.get_first_stmt("for x, in y: pass")
        tup = fr.target
        assert isinstance(tup, ast.Tuple)
        assert tup.ctx == ast.Store
        assert len(tup.elts) == 1
        assert isinstance(tup.elts[0], ast.Name)
        assert tup.elts[0].ctx == ast.Store
        fr = self.get_first_stmt("for x, y in g: pass")
        tup = fr.target
        assert isinstance(tup, ast.Tuple)
        assert tup.ctx == ast.Store
        assert len(tup.elts) == 2
        for elt in tup.elts:
            assert isinstance(elt, ast.Name)
            assert elt.ctx == ast.Store
        fr = self.get_first_stmt("for x in g: pass\nelse: 4")
        assert len(fr.body) == 1
        assert isinstance(fr.body[0], ast.Pass)
        assert len(fr.orelse) == 1
        assert isinstance(fr.orelse[0].value, ast.Constant)

    def test_try(self):
        tr = self.get_first_stmt("try: x" + "\n" +
                                 "finally: pass")
        assert isinstance(tr, ast.Try)
        assert len(tr.body) == 1
        assert isinstance(tr.body[0].value, ast.Name)
        assert len(tr.finalbody) == 1
        assert isinstance(tr.finalbody[0], ast.Pass)
        assert tr.orelse is None
        tr = self.get_first_stmt("try: x" + "\n" +
                                 "except: pass")
        assert isinstance(tr, ast.Try)
        assert len(tr.body) == 1
        assert isinstance(tr.body[0].value, ast.Name)
        assert len(tr.handlers) == 1
        handler = tr.handlers[0]
        assert isinstance(handler, ast.excepthandler)
        assert handler.type is None
        assert handler.name is None
        assert len(handler.body) == 1
        assert isinstance(handler.body[0], ast.Pass)
        assert tr.orelse is None
        assert tr.finalbody is None
        tr = self.get_first_stmt("try: x" + "\n" +
                                 "except Exception: pass")
        assert len(tr.handlers) == 1
        handler = tr.handlers[0]
        assert isinstance(handler.type, ast.Name)
        assert handler.type.ctx == ast.Load
        assert handler.name is None
        assert len(handler.body) == 1
        assert tr.orelse is None
        tr = self.get_first_stmt("try: x" + "\n" +
                                 "except Exception as e: pass")
        assert len(tr.handlers) == 1
        handler = tr.handlers[0]
        assert isinstance(handler.type, ast.Name)
        assert handler.type.id == "Exception"
        assert handler.name == "e"
        assert len(handler.body) == 1
        tr = self.get_first_stmt("try: x" + "\n" +
                                 "except: pass" + "\n" +
                                 "else: 4")
        assert len(tr.body) == 1
        assert isinstance(tr.body[0].value, ast.Name)
        assert len(tr.handlers) == 1
        assert isinstance(tr.handlers[0].body[0], ast.Pass)
        assert len(tr.orelse) == 1
        assert isinstance(tr.orelse[0].value, ast.Constant)
        tr = self.get_first_stmt("try: x" + "\n" +
                                 "except Exc as a: 5" + "\n" +
                                 "except F: pass")
        assert len(tr.handlers) == 2
        h1, h2 = tr.handlers
        assert isinstance(h1.type, ast.Name)
        assert h1.name == "a"
        assert isinstance(h1.body[0].value, ast.Constant)
        assert isinstance(h2.type, ast.Name)
        assert h2.name is None
        assert isinstance(h2.body[0], ast.Pass)
        tr = self.get_first_stmt("try: x" + "\n" +
                                 "except Exc as a: 5" + "\n" +
                                 "except F: pass")
        assert len(tr.handlers) == 2
        h1, h2 = tr.handlers
        assert isinstance(h1.type, ast.Name)
        assert h1.name == "a"
        assert isinstance(h1.body[0].value, ast.Constant)
        assert isinstance(h2.type, ast.Name)
        assert h2.name is None
        assert isinstance(h2.body[0], ast.Pass)
        tr = self.get_first_stmt("try: x" + "\n" +
                                 "except: 4" + "\n" +
                                 "finally: pass")
        assert isinstance(tr, ast.Try)
        assert len(tr.finalbody) == 1
        assert isinstance(tr.finalbody[0], ast.Pass)
        assert len(tr.handlers) == 1
        assert len(tr.handlers[0].body) == 1
        assert isinstance(tr.handlers[0].body[0].value, ast.Constant)
        assert len(tr.body) == 1
        assert isinstance(tr.body[0].value, ast.Name)
        tr = self.get_first_stmt("try: x" + "\n" +
                                 "except: 4" + "\n" +
                                 "else: 'hi'" + "\n" +
                                 "finally: pass")
        assert isinstance(tr, ast.Try)
        assert len(tr.finalbody) == 1
        assert isinstance(tr.finalbody[0], ast.Pass)
        assert len(tr.body) == 1
        assert len(tr.orelse) == 1
        assert isinstance(tr.orelse[0].value, ast.Constant)
        assert len(tr.body) == 1
        assert isinstance(tr.body[0].value, ast.Name)
        assert len(tr.handlers) == 1

    def test_with(self):
        wi = self.get_first_stmt("with x: pass")
        assert isinstance(wi, ast.With)
        assert len(wi.items) == 1
        assert isinstance(wi.items[0], ast.withitem)
        assert isinstance(wi.items[0].context_expr, ast.Name)
        assert wi.items[0].optional_vars is None
        assert len(wi.body) == 1
        wi = self.get_first_stmt("with x as y: pass")
        assert isinstance(wi.items[0].context_expr, ast.Name)
        assert len(wi.body) == 1
        assert isinstance(wi.items[0].optional_vars, ast.Name)
        assert wi.items[0].optional_vars.ctx == ast.Store
        wi = self.get_first_stmt("with x as (y,): pass")
        assert isinstance(wi.items[0].optional_vars, ast.Tuple)
        assert len(wi.items[0].optional_vars.elts) == 1
        assert wi.items[0].optional_vars.ctx == ast.Store
        assert wi.items[0].optional_vars.elts[0].ctx == ast.Store
        input = "with x hi y: pass"
        with pytest.raises(SyntaxError) as excinfo:
            self.get_ast(input)
        wi = self.get_first_stmt("with x as y, b: pass")
        assert isinstance(wi, ast.With)
        assert len(wi.items) == 2
        assert isinstance(wi.items[0].context_expr, ast.Name)
        assert wi.items[0].context_expr.id == "x"
        assert isinstance(wi.items[0].optional_vars, ast.Name)
        assert wi.items[0].optional_vars.id == "y"
        assert isinstance(wi.items[1].context_expr, ast.Name)
        assert wi.items[1].context_expr.id == "b"
        assert wi.items[1].optional_vars is None
        assert len(wi.body) == 1
        assert isinstance(wi.body[0], ast.Pass)

    def test_class(self):
        for input in ("class X: pass", "class X(): pass"):
            cls = self.get_first_stmt(input)
            assert isinstance(cls, ast.ClassDef)
            assert cls.name == "X"
            assert len(cls.body) == 1
            assert isinstance(cls.body[0], ast.Pass)
            assert cls.bases is None
            assert cls.decorator_list is None
        for input in ("class X(Y): pass", "class X(Y,): pass"):
            cls = self.get_first_stmt(input)
            assert len(cls.bases) == 1
            base = cls.bases[0]
            assert isinstance(base, ast.Name)
            assert base.ctx == ast.Load
            assert base.id == "Y"
            assert cls.decorator_list is None
        cls = self.get_first_stmt("class X(Y, Z): pass")
        assert len(cls.bases) == 2
        for b in cls.bases:
            assert isinstance(b, ast.Name)
            assert b.ctx == ast.Load

        with pytest.raises(SyntaxError) as info:
            self.get_ast("class A(x for x in T): pass")

    def test_function(self):
        func = self.get_first_stmt("def f(): pass")
        assert isinstance(func, ast.FunctionDef)
        assert func.name == "f"
        assert len(func.body) == 1
        assert isinstance(func.body[0], ast.Pass)
        assert func.decorator_list is None
        args = func.args
        assert isinstance(args, ast.arguments)
        assert args.args is None
        assert args.defaults is None
        assert args.kwarg is None
        assert args.vararg is None
        assert func.returns is None
        args = self.get_first_stmt("def f(a, b): pass").args
        assert len(args.args) == 2
        a1, a2 = args.args
        assert isinstance(a1, ast.arg)
        assert a1.arg == "a"
        assert isinstance(a2, ast.arg)
        assert a2.arg == "b"
        assert args.vararg is None
        assert args.kwarg is None
        args = self.get_first_stmt("def f(a=b): pass").args
        assert len(args.args) == 1
        arg = args.args[0]
        assert isinstance(arg, ast.arg)
        assert arg.arg == "a"
        assert len(args.defaults) == 1
        default = args.defaults[0]
        assert isinstance(default, ast.Name)
        assert default.id == "b"
        assert default.ctx == ast.Load
        args = self.get_first_stmt("def f(*a): pass").args
        assert not args.args
        assert not args.defaults
        assert args.kwarg is None
        assert args.vararg.arg == "a"
        args = self.get_first_stmt("def f(**a): pass").args
        assert not args.args
        assert not args.defaults
        assert args.vararg is None
        assert args.kwarg.arg == "a"
        args = self.get_first_stmt("def f(a, b, c=d, *e, **f): pass").args
        assert len(args.args) == 3
        for arg in args.args:
            assert isinstance(arg, ast.arg)
        assert len(args.defaults) == 1
        assert isinstance(args.defaults[0], ast.Name)
        assert args.defaults[0].ctx == ast.Load
        assert args.vararg.arg == "e"
        assert args.kwarg.arg == "f"
        input = "def f(a=b, c): pass"
        with pytest.raises(SyntaxError) as excinfo:
            self.get_ast(input)
        assert excinfo.value.msg == "non-default argument follows default argument"
        input = "def f((x)=23): pass"
        with pytest.raises(SyntaxError) as excinfo:
            self.get_ast(input)
        assert excinfo.value.msg == "invalid syntax"

    def test_kwonly_arguments(self):
        fn = self.get_first_stmt("def f(a, b, c, *, kwarg): pass")
        assert isinstance(fn, ast.FunctionDef)
        assert len(fn.args.kwonlyargs) == 1
        assert isinstance(fn.args.kwonlyargs[0], ast.arg)
        assert fn.args.kwonlyargs[0].arg == "kwarg"
        assert fn.args.kw_defaults == [None]
        fn = self.get_first_stmt("def f(a, b, c, *args, kwarg): pass")
        assert isinstance(fn, ast.FunctionDef)
        assert len(fn.args.kwonlyargs) == 1
        assert isinstance(fn.args.kwonlyargs[0], ast.arg)
        assert fn.args.kwonlyargs[0].arg == "kwarg"
        assert fn.args.kw_defaults == [None]
        fn = self.get_first_stmt("def f(a, b, c, *, kwarg=2): pass")
        assert isinstance(fn, ast.FunctionDef)
        assert len(fn.args.kwonlyargs) == 1
        assert isinstance(fn.args.kwonlyargs[0], ast.arg)
        assert fn.args.kwonlyargs[0].arg == "kwarg"
        assert len(fn.args.kw_defaults) == 1
        assert isinstance(fn.args.kw_defaults[0], ast.Constant)
        input = "def f(p1, *, **k1):  pass"
        exc = pytest.raises(SyntaxError, self.get_ast, input).value
        assert exc.msg == "named arguments must follow bare *"

    def test_posonly_arguments(self):
        fn = self.get_first_stmt("def f(a, b, c, /, arg): pass")
        assert isinstance(fn, ast.FunctionDef)
        assert len(fn.args.posonlyargs) == 3
        assert len(fn.args.args) == 1
        assert isinstance(fn.args.args[0], ast.arg)
        assert fn.args.args[0].arg == "arg"

    def test_function_annotation(self):
        func = self.get_first_stmt("def f() -> X: pass")
        assert isinstance(func.returns, ast.Name)
        assert func.returns.id == "X"
        assert func.returns.ctx == ast.Load
        for stmt in "def f(x : 42): pass", "def f(x : 42=a): pass":
            func = self.get_first_stmt(stmt)
            assert isinstance(func.args.args[0].annotation, ast.Constant)
        assert isinstance(func.args.defaults[0], ast.Name)
        func = self.get_first_stmt("def f(*x : 42): pass")
        assert isinstance(func.args.vararg.annotation, ast.Constant)
        func = self.get_first_stmt("def f(**kw : 42): pass")
        assert isinstance(func.args.kwarg.annotation, ast.Constant)
        func = self.get_first_stmt("def f(*, kw : 42=a): pass")
        assert isinstance(func.args.kwonlyargs[0].annotation, ast.Constant)

    def test_lots_of_kwonly_arguments(self):
        fundef = "def f("
        for i in range(255):
            fundef += "i%d, "%i
        fundef += "*, key=100):\n pass\n"
        self.get_first_stmt(fundef) # no crash, works since 3.7

        fundef2 = "def foo(i,*,"
        for i in range(255):
            fundef2 += "i%d, "%i
        fundef2 += "lastarg):\n  pass\n"
        self.get_first_stmt(fundef2) # no crash, works since 3.7

        fundef3 = "def f(i,*,"
        for i in range(253):
            fundef3 += "i%d, "%i
        fundef3 += "lastarg):\n  pass\n"
        self.get_first_stmt(fundef3)

    def test_decorators(self):
        to_examine = (("def f(): pass", ast.FunctionDef),
                      ("class x: pass", ast.ClassDef))
        for stmt, node in to_examine:
            definition = self.get_first_stmt("@dec\n%s" % (stmt,))
            assert isinstance(definition, node)
            assert len(definition.decorator_list) == 1
            dec = definition.decorator_list[0]
            assert isinstance(dec, ast.Name)
            assert dec.id == "dec"
            assert dec.ctx == ast.Load
            definition = self.get_first_stmt("@mod.hi.dec\n%s" % (stmt,))
            assert len(definition.decorator_list) == 1
            dec = definition.decorator_list[0]
            assert isinstance(dec, ast.Attribute)
            assert dec.ctx == ast.Load
            assert dec.attr == "dec"
            assert isinstance(dec.value, ast.Attribute)
            assert dec.value.attr == "hi"
            assert isinstance(dec.value.value, ast.Name)
            assert dec.value.value.id == "mod"
            definition = self.get_first_stmt("@dec\n@dec2\n%s" % (stmt,))
            assert len(definition.decorator_list) == 2
            for dec in definition.decorator_list:
                assert isinstance(dec, ast.Name)
                assert dec.ctx == ast.Load
            assert definition.decorator_list[0].id == "dec"
            assert definition.decorator_list[1].id == "dec2"
            definition = self.get_first_stmt("@dec()\n%s" % (stmt,))
            assert len(definition.decorator_list) == 1
            dec = definition.decorator_list[0]
            assert isinstance(dec, ast.Call)
            assert isinstance(dec.func, ast.Name)
            assert dec.func.id == "dec"
            assert dec.args is None
            assert dec.keywords is None
            definition = self.get_first_stmt("@dec(a, b)\n%s" % (stmt,))
            assert len(definition.decorator_list) == 1
            dec = definition.decorator_list[0]
            assert isinstance(dec, ast.Call)
            assert dec.func.id == "dec"
            assert len(dec.args) == 2
            assert dec.keywords is None

    def test_annassign(self):
        simple = self.get_first_stmt('a: int')
        assert isinstance(simple, ast.AnnAssign)
        assert isinstance(simple.target, ast.Name)
        assert simple.target.ctx == ast.Store
        assert isinstance(simple.annotation, ast.Name)
        assert simple.value == None
        assert simple.simple == 1

        with_value = self.get_first_stmt('x: str = "test"')
        assert isinstance(with_value, ast.AnnAssign)
        assert isinstance(with_value.value, ast.Constant)
        assert self.space.eq_w(with_value.value.value, self.space.wrap("test"))

        not_simple = self.get_first_stmt('(a): int')
        assert isinstance(not_simple, ast.AnnAssign)
        assert isinstance(not_simple.target, ast.Name)
        assert not_simple.target.ctx == ast.Store
        assert not_simple.simple == 0

        attrs = self.get_first_stmt('a.b.c: int')
        assert isinstance(attrs, ast.AnnAssign)
        assert isinstance(attrs.target, ast.Attribute)

        subscript = self.get_first_stmt('a[0:2]: int')
        assert isinstance(subscript, ast.AnnAssign)
        assert isinstance(subscript.target, ast.Subscript)

        exc_tuple = pytest.raises(SyntaxError, self.get_ast, 'a, b: int').value
        assert exc_tuple.msg == "only single target (not tuple) can be annotated"

        exc_list = pytest.raises(SyntaxError, self.get_ast, '[]: int').value
        assert exc_list.msg == "only single target (not list) can be annotated"

        exc_bad_target = pytest.raises(SyntaxError, self.get_ast, '{}: int').value
        assert exc_bad_target.msg == "illegal target for annotation"


    def test_augassign(self):
        aug_assigns = (
            ("+=", ast.Add),
            ("-=", ast.Sub),
            ("/=", ast.Div),
            ("//=", ast.FloorDiv),
            ("%=", ast.Mod),
            ("@=", ast.MatMult),
            ("<<=", ast.LShift),
            (">>=", ast.RShift),
            ("&=", ast.BitAnd),
            ("|=", ast.BitOr),
            ("^=", ast.BitXor),
            ("*=", ast.Mult),
            ("**=", ast.Pow)
        )
        for op, ast_type in aug_assigns:
            input = "x %s 4" % (op,)
            assign = self.get_first_stmt(input)
            assert isinstance(assign, ast.AugAssign)
            assert assign.op is ast_type
            assert isinstance(assign.target, ast.Name)
            assert assign.target.ctx == ast.Store
            assert isinstance(assign.value, ast.Constant)

    def test_assign(self):
        assign = self.get_first_stmt("hi = 32")
        assert isinstance(assign, ast.Assign)
        assert len(assign.targets) == 1
        name = assign.targets[0]
        assert isinstance(name, ast.Name)
        assert name.ctx == ast.Store
        value = assign.value
        assert self.space.eq_w(value.value, self.space.wrap(32))
        assign = self.get_first_stmt("hi, = something")
        assert len(assign.targets) == 1
        tup = assign.targets[0]
        assert isinstance(tup, ast.Tuple)
        assert tup.ctx == ast.Store
        assert len(tup.elts) == 1
        assert isinstance(tup.elts[0], ast.Name)
        assert tup.elts[0].ctx == ast.Store

    def test_assign_starred(self):
        assign = self.get_first_stmt("*a, b = x")
        assert isinstance(assign, ast.Assign)
        assert len(assign.targets) == 1
        names = assign.targets[0]
        assert len(names.elts) == 2
        assert isinstance(names.elts[0], ast.Starred)
        assert isinstance(names.elts[1], ast.Name)
        assert isinstance(names.elts[0].value, ast.Name)
        assert names.elts[0].value.id == "a"

    def test_name(self):
        name = self.get_first_expr("hi")
        assert isinstance(name, ast.Name)
        assert name.ctx == ast.Load

    def test_tuple(self):
        tup = self.get_first_expr("()")
        assert isinstance(tup, ast.Tuple)
        assert tup.elts is None
        assert tup.ctx == ast.Load
        tup = self.get_first_expr("(3,)")
        assert len(tup.elts) == 1
        assert self.space.eq_w(tup.elts[0].value, self.space.wrap(3))
        tup = self.get_first_expr("2, 3, 4")
        assert len(tup.elts) == 3

    def test_list(self):
        seq = self.get_first_expr("[]")
        assert isinstance(seq, ast.List)
        assert seq.elts is None
        assert seq.ctx == ast.Load
        seq = self.get_first_expr("[3,]")
        assert len(seq.elts) == 1
        assert self.space.eq_w(seq.elts[0].value, self.space.wrap(3))
        seq = self.get_first_expr("[3]")
        assert len(seq.elts) == 1
        seq = self.get_first_expr("[1, 2, 3, 4, 5]")
        assert len(seq.elts) == 5
        nums = range(1, 6)
        assert [self.space.int_w(n.value) for n in seq.elts] == nums

    def test_dict(self):
        d = self.get_first_expr("{}")
        assert isinstance(d, ast.Dict)
        assert d.keys is None
        assert d.values is None
        d = self.get_first_expr("{4 : x, y : 7}")
        assert len(d.keys) == len(d.values) == 2
        key1, key2 = d.keys
        assert isinstance(key1, ast.Constant)
        assert isinstance(key2, ast.Name)
        assert key2.ctx == ast.Load
        v1, v2 = d.values
        assert isinstance(v1, ast.Name)
        assert v1.ctx == ast.Load
        assert isinstance(v2, ast.Constant)

    def test_set(self):
        s = self.get_first_expr("{1}")
        assert isinstance(s, ast.Set)
        assert len(s.elts) == 1
        assert isinstance(s.elts[0], ast.Constant)
        assert self.space.eq_w(s.elts[0].value, self.space.wrap(1))
        s = self.get_first_expr("{0, 1, 2, 3, 4, 5}")
        assert isinstance(s, ast.Set)
        assert len(s.elts) == 6
        for i, elt in enumerate(s.elts):
            assert isinstance(elt, ast.Constant)
            assert self.space.eq_w(elt.value, self.space.wrap(i))

    def test_set_unpack(self):
        s = self.get_first_expr("{*{1}}")
        assert isinstance(s, ast.Set)
        assert len(s.elts) == 1
        sta0 = s.elts[0]
        assert isinstance(sta0, ast.Starred)
        s0 = sta0.value
        assert isinstance(s0, ast.Set)
        assert len(s0.elts) == 1
        assert isinstance(s0.elts[0], ast.Constant)
        assert self.space.eq_w(s0.elts[0].value, self.space.wrap(1))
        s = self.get_first_expr("{*{0, 1, 2, 3, 4, 5}}")
        assert isinstance(s, ast.Set)
        assert len(s.elts) == 1
        sta0 = s.elts[0]
        assert isinstance(sta0, ast.Starred)
        s0 = sta0.value
        assert isinstance(s0, ast.Set)
        assert len(s0.elts) == 6
        for i, elt in enumerate(s0.elts):
            assert isinstance(elt, ast.Constant)
            assert self.space.eq_w(elt.value, self.space.wrap(i))

    def test_set_context(self):
        tup = self.get_ast("(a, b) = c").body[0].targets[0]
        assert all(elt.ctx == ast.Store for elt in tup.elts)
        seq = self.get_ast("[a, b] = c").body[0].targets[0]
        assert all(elt.ctx == ast.Store for elt in seq.elts)
        invalid_stores = (
            ("(lambda x: x)", "lambda"),
            ("f()", "function call"),
            ("~x", "operator"),
            ("+x", "operator"),
            ("-x", "operator"),
            ("(x or y)", "operator"),
            ("(x and y)", "operator"),
            ("(not g)", "operator"),
            ("(x for y in g)", "generator expression"),
            ("(yield x)", "yield expression"),
            ("[x for y in g]", "list comprehension"),
            ("{x for x in z}", "set comprehension"),
            ("{x : x for x in z}", "dict comprehension"),
            ("'str'", "literal"),
            ("b'bytes'", "literal"),
            ("23", "literal"),
            ("{}", "dict display"),
            ("{1, 2, 3}", "set display"),
            ("(x > 4)", "comparison"),
            ("(x if y else a)", "conditional expression"),
            ("...", "Ellipsis"),
        )
        test_contexts = (
            ("assign to", "%s = 23"),
            ("delete", "del %s")
        )
        for ctx_type, template in test_contexts:
            for expr, type_str in invalid_stores:
                input = template % (expr,)
                with pytest.raises(SyntaxError) as excinfo:
                    self.get_ast(input)
                assert excinfo.value.msg.startswith("cannot %s %s" % (ctx_type, type_str))

    def test_assignment_to_forbidden_names(self):
        invalid = (
            "%s = x",
            "%s, x = y",
            "[%s, x] = y",
            "[%s, x] = y",
            "*%s, x = y",
            "[*%s, x] = y",
            "def %s(): pass",
            "class %s(): pass",
            "def f(%s): pass",
            "def f(%s=x): pass",
            "def f(*%s): pass",
            "def f(**%s): pass",
            "f(%s=x)",
            "with x as %s: pass",
            "import %s",
            "import x as %s",
            "from x import %s",
            "from x import y as %s",
            "for %s in x: pass",
            "x.%s = y",
            "x.%s += y",
            "%s += 1",
        )
        for name in "__debug__",:
            for template in invalid:
                input = template % (name,)
                ast = self.get_ast(input) # error now caught during codegen!
                ec = self.space.getexecutioncontext()
                with pytest.raises(OperationError) as excinfo:
                    ec.compiler.compile_ast(ast, "", "exec")
                msg = self.space.text_w(self.space.repr(excinfo.value.get_w_value(self.space)))
                assert ("cannot assign to %s" % (name,)) in msg

    def test_delete_forbidden_name(self):
        invalid = (
            "del %s",
            "del %s, a",
            "del [%s, a]",
            "del a.%s",
        )
        for name in "__debug__",:
            for template in invalid:
                input = template % (name,)
                ast = self.get_ast(input) # error now caught during codegen!
                ec = self.space.getexecutioncontext()
                with pytest.raises(OperationError) as excinfo:
                    ec.compiler.compile_ast(ast, "", "exec")
                msg = self.space.text_w(self.space.repr(excinfo.value.get_w_value(self.space)))
                assert ("cannot delete %s" % (name,)) in msg

    def test_cannot_delete_messages(self):
        invalid = [
            ("del (1, x)", "cannot delete literal"),
            ("del [x, z, a, {1, 2}]", "cannot delete set display"),
            ("del [a, (b, *c)]", "cannot delete starred"),
            ("del (a := 5)", "cannot delete named expression"),
        ]
        for wrong, msg in invalid:
            with pytest.raises(SyntaxError) as excinfo:
                self.get_ast(wrong)
            assert msg in excinfo.value.msg

    def test_cannot_assign_messages(self):
        invalid = [
            ("(1, x) = 5", "cannot assign to literal"),
            ("[x, z, a, {1, 2}] = 12", "cannot assign to set display"),
            ("for (1, x) in []: pass", "cannot assign to literal"),
            ("with foo as (1, 2): pass", "cannot assign to literal"),
        ]
        for wrong, msg in invalid:
            with pytest.raises(SyntaxError) as excinfo:
                self.get_ast(wrong)
            assert msg in excinfo.value.msg

    def test_assign_bug(self):
        self.get_ast("direct = (__debug__ and optimize == 0)") # used to crash

    def test_lambda(self):
        lam = self.get_first_expr("lambda x: expr")
        assert isinstance(lam, ast.Lambda)
        args = lam.args
        assert isinstance(args, ast.arguments)
        assert args.vararg is None
        assert args.kwarg is None
        assert not args.defaults
        assert len(args.args) == 1
        assert isinstance(args.args[0], ast.arg)
        assert isinstance(lam.body, ast.Name)
        lam = self.get_first_expr("lambda: True")
        args = lam.args
        assert not args.args
        lam = self.get_first_expr("lambda x=x: y")
        assert len(lam.args.args) == 1
        assert len(lam.args.defaults) == 1
        assert isinstance(lam.args.defaults[0], ast.Name)
        input = "f(lambda x: x[0] = y)"
        with pytest.raises(SyntaxError) as excinfo:
            self.get_ast(input)
        assert excinfo.value.msg == 'expression cannot contain assignment, perhaps you meant "=="?'

    def test_ifexp(self):
        ifexp = self.get_first_expr("x if y else g")
        assert isinstance(ifexp, ast.IfExp)
        assert isinstance(ifexp.test, ast.Name)
        assert ifexp.test.ctx == ast.Load
        assert isinstance(ifexp.body, ast.Name)
        assert ifexp.body.ctx == ast.Load
        assert isinstance(ifexp.orelse, ast.Name)
        assert ifexp.orelse.ctx == ast.Load

    def test_boolop(self):
        for ast_type, op in ((ast.And, "and"), (ast.Or, "or")):
            bo = self.get_first_expr("x %s a" % (op,))
            assert isinstance(bo, ast.BoolOp)
            assert bo.op == ast_type
            assert len(bo.values) == 2
            assert isinstance(bo.values[0], ast.Name)
            assert isinstance(bo.values[1], ast.Name)
            bo = self.get_first_expr("x %s a %s b" % (op, op))
            assert bo.op == ast_type
            assert len(bo.values) == 3

    def test_not(self):
        n = self.get_first_expr("not x")
        assert isinstance(n, ast.UnaryOp)
        assert n.op == ast.Not
        assert isinstance(n.operand, ast.Name)
        assert n.operand.ctx == ast.Load

    def test_comparison(self):
        compares = (
            (">", ast.Gt),
            (">=", ast.GtE),
            ("<", ast.Lt),
            ("<=", ast.LtE),
            ("==", ast.Eq),
            ("!=", ast.NotEq),
            ("in", ast.In),
            ("is", ast.Is),
            ("is not", ast.IsNot),
            ("not in", ast.NotIn)
        )
        for op, ast_type in compares:
            comp = self.get_first_expr("x %s y" % (op,))
            assert isinstance(comp, ast.Compare)
            assert isinstance(comp.left, ast.Name)
            assert comp.left.ctx == ast.Load
            assert len(comp.ops) == 1
            assert comp.ops[0] == ast_type
            assert len(comp.comparators) == 1
            assert isinstance(comp.comparators[0], ast.Name)
            assert comp.comparators[0].ctx == ast.Load
        # Just for fun let's randomly combine operators. :)
        for j in range(10):
            vars = string.ascii_letters[:random.randint(3, 7)]
            ops = [random.choice(compares) for i in range(len(vars) - 1)]
            input = vars[0]
            for i, (op, _) in enumerate(ops):
                input += " %s %s" % (op, vars[i + 1])
            comp = self.get_first_expr(input)
            assert comp.ops == [tup[1] for tup in ops]
            names = comp.left.id + "".join(n.id for n in comp.comparators)
            assert names == vars

    def test_flufl(self):
        source = "x <> y"
        pytest.raises(SyntaxError, self.get_ast, source)
        comp = self.get_first_expr(source,
                                   flags=consts.CO_FUTURE_BARRY_AS_BDFL)
        assert isinstance(comp, ast.Compare)
        assert isinstance(comp.left, ast.Name)
        assert comp.left.ctx == ast.Load
        assert len(comp.ops) == 1
        assert comp.ops[0] == ast.NotEq
        assert len(comp.comparators) == 1
        assert isinstance(comp.comparators[0], ast.Name)
        assert comp.comparators[0].ctx == ast.Load

    def test_binop(self):
        binops = (
            ("|", ast.BitOr),
            ("&", ast.BitAnd),
            ("^", ast.BitXor),
            ("<<", ast.LShift),
            (">>", ast.RShift),
            ("+", ast.Add),
            ("-", ast.Sub),
            ("/", ast.Div),
            ("*", ast.Mult),
            ("//", ast.FloorDiv),
            ("%", ast.Mod),
            ("@", ast.MatMult)
        )
        for op, ast_type in binops:
            bin = self.get_first_expr("a %s b" % (op,))
            assert isinstance(bin, ast.BinOp)
            assert bin.op == ast_type
            assert isinstance(bin.left, ast.Name)
            assert isinstance(bin.right, ast.Name)
            assert bin.left.ctx == ast.Load
            assert bin.right.ctx == ast.Load
            bin = self.get_first_expr("a %s b %s c" % (op, op))
            assert isinstance(bin.left, ast.BinOp)
            assert bin.left.op == ast_type
            assert isinstance(bin.right, ast.Name)

    def test_yield(self):
        expr = self.get_first_expr("yield")
        assert isinstance(expr, ast.Yield)
        assert expr.value is None
        expr = self.get_first_expr("yield x")
        assert isinstance(expr.value, ast.Name)
        assign = self.get_first_stmt("x = yield x")
        assert isinstance(assign, ast.Assign)
        assert isinstance(assign.value, ast.Yield)

    def test_yield_from(self):
        expr = self.get_first_expr("yield from x")
        assert isinstance(expr, ast.YieldFrom)
        assert isinstance(expr.value, ast.Name)

    def test_unaryop(self):
        unary_ops = (
            ("+", ast.UAdd),
            ("-", ast.USub),
            ("~", ast.Invert)
        )
        for op, ast_type in unary_ops:
            unary = self.get_first_expr("%sx" % (op,))
            assert isinstance(unary, ast.UnaryOp)
            assert unary.op == ast_type
            assert isinstance(unary.operand, ast.Name)
            assert unary.operand.ctx == ast.Load

    def test_power(self):
        power = self.get_first_expr("x**5")
        assert isinstance(power, ast.BinOp)
        assert power.op == ast.Pow
        assert isinstance(power.left , ast.Name)
        assert power.left.ctx == ast.Load
        assert isinstance(power.right, ast.Constant)

    def test_call(self):
        call = self.get_first_expr("f()")
        assert isinstance(call, ast.Call)
        assert call.args is None
        assert call.keywords is None
        assert isinstance(call.func, ast.Name)
        assert call.func.ctx == ast.Load
        call = self.get_first_expr("f(2, 3)")
        assert len(call.args) == 2
        assert isinstance(call.args[0], ast.Constant)
        assert isinstance(call.args[1], ast.Constant)
        assert call.keywords is None
        call = self.get_first_expr("f(a=3)")
        assert call.args is None
        assert len(call.keywords) == 1
        keyword = call.keywords[0]
        assert isinstance(keyword, ast.keyword)
        assert keyword.arg == "a"
        assert isinstance(keyword.value, ast.Constant)
        call = self.get_first_expr("f(*a, **b)")
        assert isinstance(call.args[0], ast.Starred)
        assert isinstance(call.keywords[0], ast.keyword)
        assert call.args[0].value.id == "a"
        assert call.args[0].ctx == ast.Load
        assert call.keywords[0].value.id == "b"
        call = self.get_first_expr("f(a, b, x=4, *m, **f)")
        assert len(call.args) == 3
        assert isinstance(call.args[0], ast.Name)
        assert isinstance(call.args[1], ast.Name)
        assert isinstance(call.args[2], ast.Starred)
        assert len(call.keywords) == 2
        assert call.keywords[0].arg == "x"
        assert call.args[2].value.id == "m"
        assert call.keywords[1].value.id == "f"
        call = self.get_first_expr("f(x for x in y)")
        assert len(call.args) == 1
        assert isinstance(call.args[0], ast.GeneratorExp)
        input = "f(x for x in y, 1)"
        exc = pytest.raises(SyntaxError, self.get_ast, input).value
        assert exc.msg == "Generator expression must be parenthesized"

        input = "f(x for x in y, )"
        exc = pytest.raises(SyntaxError, self.get_ast, input).value
        assert exc.msg == "Generator expression must be parenthesized"

        many_args = ", ".join("x%i" % i for i in range(256))
        input = "f(%s)" % (many_args,)
        self.get_ast(input) # doesn't crash any more
        exc = pytest.raises(SyntaxError, self.get_ast, "f((a+b)=c)").value
        assert exc.msg == 'expression cannot contain assignment, perhaps you meant "=="?'
        exc = pytest.raises(SyntaxError, self.get_ast, "deff f(a=1, a=2): pass").value
        assert  'invalid syntax' in exc.msg # used to be "keyword argument repeated: 'a'"
        with pytest.raises(SyntaxError) as excinfo:
            self.get_ast("f((x)=1)")
        assert excinfo.value.msg == 'expression cannot contain assignment, perhaps you meant "=="?'
        with pytest.raises(SyntaxError) as excinfo:
            self.get_ast("f(True=1)")
        assert excinfo.value.msg == 'cannot assign to True'
        assert excinfo.value.offset == 3


    def test_attribute(self):
        attr = self.get_first_expr("x.y")
        assert isinstance(attr, ast.Attribute)
        assert isinstance(attr.value, ast.Name)
        assert attr.value.ctx == ast.Load
        assert attr.attr == "y"
        assert attr.ctx == ast.Load
        assign = self.get_first_stmt("x.y = 54")
        assert isinstance(assign, ast.Assign)
        assert len(assign.targets) == 1
        attr = assign.targets[0]
        assert isinstance(attr, ast.Attribute)
        assert attr.value.ctx == ast.Load
        assert attr.ctx == ast.Store

    def test_subscript_and_slices(self):
        sub = self.get_first_expr("x[y]")
        assert isinstance(sub, ast.Subscript)
        assert isinstance(sub.value, ast.Name)
        assert sub.value.ctx == ast.Load
        assert sub.ctx == ast.Load
        assert isinstance(sub.slice, ast.Name)
        slc = self.get_first_expr("x[:]").slice
        assert slc.upper is None
        assert slc.lower is None
        assert slc.step is None
        slc = self.get_first_expr("x[::]").slice
        assert slc.upper is None
        assert slc.lower is None
        assert slc.step is None
        slc = self.get_first_expr("x[1:]").slice
        assert isinstance(slc.lower, ast.Constant)
        assert slc.upper is None
        assert slc.step is None
        slc = self.get_first_expr("x[1::]").slice
        assert isinstance(slc.lower, ast.Constant)
        assert slc.upper is None
        assert slc.step is None
        slc = self.get_first_expr("x[:2]").slice
        assert slc.lower is None
        assert isinstance(slc.upper, ast.Constant)
        assert slc.step is None
        slc = self.get_first_expr("x[:2:]").slice
        assert slc.lower is None
        assert isinstance(slc.upper, ast.Constant)
        assert slc.step is None
        slc = self.get_first_expr("x[2:2]").slice
        assert isinstance(slc.lower, ast.Constant)
        assert isinstance(slc.upper, ast.Constant)
        assert slc.step is None
        slc = self.get_first_expr("x[2:2:]").slice
        assert isinstance(slc.lower, ast.Constant)
        assert isinstance(slc.upper, ast.Constant)
        assert slc.step is None
        slc = self.get_first_expr("x[::2]").slice
        assert slc.lower is None
        assert slc.upper is None
        assert isinstance(slc.step, ast.Constant)
        slc = self.get_first_expr("x[2::2]").slice
        assert isinstance(slc.lower, ast.Constant)
        assert slc.upper is None
        assert isinstance(slc.step, ast.Constant)
        slc = self.get_first_expr("x[:2:2]").slice
        assert slc.lower is None
        assert isinstance(slc.upper, ast.Constant)
        assert isinstance(slc.step, ast.Constant)
        slc = self.get_first_expr("x[1:2:3]").slice
        for field in (slc.lower, slc.upper, slc.step):
            assert isinstance(field, ast.Constant)
        sub = self.get_first_expr("x[1,2,3]")
        slc = sub.slice
        assert isinstance(slc, ast.Tuple)
        assert len(slc.elts) == 3
        assert slc.ctx == ast.Load
        slc = self.get_first_expr("x[1,3:4]").slice
        assert isinstance(slc, ast.Tuple)
        assert len(slc.elts) == 2
        complex_slc = slc.elts[1]
        assert isinstance(complex_slc, ast.Slice)
        assert isinstance(complex_slc.lower, ast.Constant)
        assert isinstance(complex_slc.upper, ast.Constant)
        assert complex_slc.step is None

    def test_ellipsis(self):
        e = self.get_first_expr("...")
        assert isinstance(e, ast.Constant)
        assert self.space.is_w(e.value, self.space.w_Ellipsis)

        sub = self.get_first_expr("x[...]")
        assert isinstance(sub.slice, ast.Constant)
        assert self.space.is_w(sub.slice.value, self.space.w_Ellipsis)

    def test_string(self):
        space = self.space
        s = self.get_first_expr("'hi'")
        assert isinstance(s, ast.Constant)
        assert space.eq_w(s.value, space.wrap("hi"))
        s = self.get_first_expr("'hi' ' implicitly' ' extra'")
        assert isinstance(s, ast.Constant)
        assert space.eq_w(s.value, space.wrap("hi implicitly extra"))
        s = self.get_first_expr("b'hi' b' implicitly' b' extra'")
        assert isinstance(s, ast.Constant)
        assert space.eq_w(s.value, space.newbytes("hi implicitly extra"))
        excinfo = pytest.raises(SyntaxError, self.get_first_expr, "b'hello' 'world'")
        assert excinfo.value.offset == 1
        excinfo = pytest.raises(SyntaxError, self.get_first_expr, "'foo' b'hello' 'world'")
        assert excinfo.value.offset == 7
        sentence = u"Die Männer ärgern sich!"
        source = u"# coding: utf-7\nstuff = '%s'" % (sentence,)
        s = self.get_first_stmt(source.encode("utf-7"))
        assert self.info.encoding == "utf-7"
        assert isinstance(s.value, ast.Constant)
        assert space.eq_w(s.value.value, space.wrap(sentence))

    def test_string_pep3120(self):
        space = self.space
        japan = u'日本'
        source = u"foo = '%s'" % japan
        s = self.get_first_stmt(source.encode("utf-8"))
        assert self.info.encoding == "utf-8"
        assert isinstance(s.value, ast.Constant)
        assert space.eq_w(s.value.value, space.wrap(japan))

    def test_name_pep3131(self):
        assign = self.get_first_stmt("日本 = 32")
        assert isinstance(assign, ast.Assign)
        name = assign.targets[0]
        assert isinstance(name, ast.Name)
        assert name.id == u"日本".encode('utf-8')

    def test_function_pep3131(self):
        fn = self.get_first_stmt("def µ(µ='foo'): pass")
        assert isinstance(fn, ast.FunctionDef)
        # µ normalized to NFKC
        expected = u'\u03bc'.encode('utf-8')
        assert fn.name == expected
        assert fn.args.args[0].arg == expected

    def test_import_pep3131(self):
        im = self.get_first_stmt("from packageµ import modµ as µ")
        assert isinstance(im, ast.ImportFrom)
        expected = u'\u03bc'.encode('utf-8')
        assert im.module == 'package' + expected
        alias = im.names[0]
        assert alias.name == 'mod' + expected
        assert alias.asname == expected

    def test_issue3574(self):
        space = self.space
        source = u'# coding: Latin-1\nu = "Ç"\n'
        info = pyparse.CompileInfo("<test>", "exec")
        s = self.get_first_stmt(source.encode("Latin-1")).value
        assert self.info.encoding == "iso-8859-1"
        assert isinstance(s, ast.Constant)
        assert space.eq_w(s.value, space.wrap(u'Ç'))

    def test_string_bug(self):
        space = self.space
        source = '# -*- encoding: utf8 -*-\nstuff = "x \xc3\xa9 \\n"\n'
        s = self.get_first_stmt(source).value
        assert self.info.encoding == "utf8"
        assert isinstance(s, ast.Constant)
        assert space.eq_w(s.value, space.wrap(u'x \xe9 \n'))

    def test_number(self):
        def get_num(s):
            node = self.get_first_expr(s)
            assert isinstance(node, ast.Constant)
            value = node.value
            assert isinstance(value, W_Root)
            return value
        space = self.space
        assert space.eq_w(get_num("32"), space.wrap(32))
        assert space.eq_w(get_num("32.5"), space.wrap(32.5))
        assert space.eq_w(get_num("2"), space.wrap(2))
        assert space.eq_w(get_num("13j"), space.wrap(13j))
        assert space.eq_w(get_num("13J"), space.wrap(13J))
        assert space.eq_w(get_num("0o53"), space.wrap(053))
        assert space.eq_w(get_num("0o0053"), space.wrap(053))
        for num in ("0x53", "0X53", "0x0000053", "0X00053"):
            assert space.eq_w(get_num(num), space.wrap(0x53))
        assert space.eq_w(get_num("0Xb0d2"), space.wrap(0xb0d2))
        assert space.eq_w(get_num("0X53"), space.wrap(0x53))
        assert space.eq_w(get_num("0"), space.wrap(0))
        assert space.eq_w(get_num("00000"), space.wrap(0))
        for num in ("0o53", "0O53", "0o0000053", "0O00053"):
            assert space.eq_w(get_num(num), space.wrap(053))
        for num in ("0b00101", "0B00101", "0b101", "0B101"):
            assert space.eq_w(get_num(num), space.wrap(5))

        pytest.raises(SyntaxError, self.get_ast, "0x")
        pytest.raises(SyntaxError, self.get_ast, "0b")
        pytest.raises(SyntaxError, self.get_ast, "0o")
        pytest.raises(SyntaxError, self.get_ast, "32L")
        pytest.raises(SyntaxError, self.get_ast, "32l")
        pytest.raises(SyntaxError, self.get_ast, "0L")
        pytest.raises(SyntaxError, self.get_ast, "-0xAAAAAAL")
        pytest.raises(SyntaxError, self.get_ast, "053")
        pytest.raises(SyntaxError, self.get_ast, "00053")

    def check_comprehension(self, brackets, ast_type):
        def brack(s):
            return brackets % s
        gen = self.get_first_expr(brack("x for x in y"))
        assert isinstance(gen, ast_type)
        assert isinstance(gen.elt, ast.Name)
        assert gen.elt.ctx == ast.Load
        assert len(gen.generators) == 1
        comp = gen.generators[0]
        assert isinstance(comp, ast.comprehension)
        assert comp.ifs is None
        assert isinstance(comp.target, ast.Name)
        assert isinstance(comp.iter, ast.Name)
        assert comp.target.ctx == ast.Store
        gen = self.get_first_expr(brack("x for x in y if w"))
        comp = gen.generators[0]
        assert len(comp.ifs) == 1
        test = comp.ifs[0]
        assert isinstance(test, ast.Name)
        gen = self.get_first_expr(brack("x for x, in y if w"))
        tup = gen.generators[0].target
        assert isinstance(tup, ast.Tuple)
        assert len(tup.elts) == 1
        assert tup.ctx == ast.Store
        gen = self.get_first_expr(brack("a for w in x for m in p if g"))
        gens = gen.generators
        assert len(gens) == 2
        comp1, comp2 = gens
        assert comp1.ifs is None
        assert len(comp2.ifs) == 1
        assert isinstance(comp2.ifs[0], ast.Name)
        gen = self.get_first_expr(brack("x for x in y if m if g"))
        comps = gen.generators
        assert len(comps) == 1
        assert len(comps[0].ifs) == 2
        if1, if2 = comps[0].ifs
        assert isinstance(if1, ast.Name)
        assert isinstance(if2, ast.Name)
        gen = self.get_first_expr(brack("x for x in y or z"))
        comp = gen.generators[0]
        assert isinstance(comp.iter, ast.BoolOp)
        assert len(comp.iter.values) == 2
        assert isinstance(comp.iter.values[0], ast.Name)
        assert isinstance(comp.iter.values[1], ast.Name)

    def test_genexp(self):
        self.check_comprehension("(%s)", ast.GeneratorExp)

    def test_listcomp(self):
        self.check_comprehension("[%s]", ast.ListComp)

    def test_setcomp(self):
        self.check_comprehension("{%s}", ast.SetComp)

    def test_dictcomp(self):
        gen = self.get_first_expr("{x : z for x in y}")
        assert isinstance(gen, ast.DictComp)
        assert isinstance(gen.key, ast.Name)
        assert gen.key.ctx == ast.Load
        assert isinstance(gen.value, ast.Name)
        assert gen.value.ctx == ast.Load
        assert len(gen.generators) == 1
        comp = gen.generators[0]
        assert isinstance(comp, ast.comprehension)
        assert comp.ifs is None
        assert isinstance(comp.target, ast.Name)
        assert isinstance(comp.iter, ast.Name)
        assert comp.target.ctx == ast.Store
        gen = self.get_first_expr("{x : z for x in y if w}")
        comp = gen.generators[0]
        assert len(comp.ifs) == 1
        test = comp.ifs[0]
        assert isinstance(test, ast.Name)
        gen = self.get_first_expr("{x : z for x, in y if w}")
        tup = gen.generators[0].target
        assert isinstance(tup, ast.Tuple)
        assert len(tup.elts) == 1
        assert tup.ctx == ast.Store
        gen = self.get_first_expr("{a : b for w in x for m in p if g}")
        gens = gen.generators
        assert len(gens) == 2
        comp1, comp2 = gens
        assert comp1.ifs is None
        assert len(comp2.ifs) == 1
        assert isinstance(comp2.ifs[0], ast.Name)
        gen = self.get_first_expr("{x : z for x in y if m if g}")
        comps = gen.generators
        assert len(comps) == 1
        assert len(comps[0].ifs) == 2
        if1, if2 = comps[0].ifs
        assert isinstance(if1, ast.Name)
        assert isinstance(if2, ast.Name)

    def test_cpython_issue12983(self):
        pytest.raises(SyntaxError, self.get_ast, r"""b'\x'""")
        pytest.raises(SyntaxError, self.get_ast, r"""b'\x0'""")

    def test_matmul(self):
        mod = self.get_ast("a @ b")
        assert isinstance(mod, ast.Module)
        body = mod.body
        assert len(body) == 1
        expr = body[0].value
        assert expr.op == ast.MatMult
        assert isinstance(expr.left, ast.Name)
        assert isinstance(expr.right, ast.Name)
        # imatmul is tested earlier search for @=

    @pytest.mark.parametrize('with_async_hacks', [False, True])
    def test_asyncFunctionDef(self, with_async_hacks):
        mod = self.get_ast("async def f():\n await something()", with_async_hacks=with_async_hacks)
        assert isinstance(mod, ast.Module)
        assert len(mod.body) == 1
        asyncdef = mod.body[0]
        assert isinstance(asyncdef, ast.AsyncFunctionDef)
        assert asyncdef.name == 'f'
        assert asyncdef.args.args == None
        assert len(asyncdef.body) == 1
        expr = asyncdef.body[0]
        assert isinstance(expr, ast.Expr)
        exprvalue = expr.value
        assert isinstance(exprvalue, ast.Await)
        awaitvalue = exprvalue.value
        assert isinstance(awaitvalue, ast.Call)
        func = awaitvalue.func
        assert isinstance(func, ast.Name)
        assert func.id == 'something'
        assert func.ctx == ast.Load

    @pytest.mark.parametrize('with_async_hacks', [False, True])
    def test_asyncFor(self, with_async_hacks):
        mod = self.get_ast("async def f():\n async for e in i: 1\n else: 2", with_async_hacks=with_async_hacks)
        assert isinstance(mod, ast.Module)
        assert len(mod.body) == 1
        asyncdef = mod.body[0]
        assert isinstance(asyncdef, ast.AsyncFunctionDef)
        assert asyncdef.name == 'f'
        assert asyncdef.args.args == None
        assert len(asyncdef.body) == 1
        asyncfor = asyncdef.body[0]
        assert isinstance(asyncfor, ast.AsyncFor)
        assert isinstance(asyncfor.target, ast.Name)
        assert isinstance(asyncfor.iter, ast.Name)
        assert len(asyncfor.body) == 1
        assert isinstance(asyncfor.body[0], ast.Expr)
        assert isinstance(asyncfor.body[0].value, ast.Constant)
        assert len(asyncfor.orelse) == 1
        assert isinstance(asyncfor.orelse[0], ast.Expr)
        assert isinstance(asyncfor.orelse[0].value, ast.Constant)

    @pytest.mark.parametrize('with_async_hacks', [False, True])
    def test_asyncWith(self, with_async_hacks):
        mod = self.get_ast("async def f():\n async with a as b: 1", with_async_hacks=with_async_hacks)
        assert isinstance(mod, ast.Module)
        assert len(mod.body) == 1
        asyncdef = mod.body[0]
        assert isinstance(asyncdef, ast.AsyncFunctionDef)
        assert asyncdef.name == 'f'
        assert asyncdef.args.args == None
        assert len(asyncdef.body) == 1
        asyncwith = asyncdef.body[0]
        assert isinstance(asyncwith, ast.AsyncWith)
        assert len(asyncwith.items) == 1
        asyncitem = asyncwith.items[0]
        assert isinstance(asyncitem, ast.withitem)
        assert isinstance(asyncitem.context_expr, ast.Name)
        assert isinstance(asyncitem.optional_vars, ast.Name)
        assert len(asyncwith.body) == 1
        assert isinstance(asyncwith.body[0], ast.Expr)
        assert isinstance(asyncwith.body[0].value, ast.Constant)

    @pytest.mark.parametrize('with_async_hacks', [False, True])
    def test_asyncYield(self, with_async_hacks):
        mod = self.get_ast("async def f():\n yield 5", with_async_hacks=with_async_hacks)
        assert isinstance(mod, ast.Module)
        assert len(mod.body) == 1
        asyncdef = mod.body[0]
        assert isinstance(asyncdef, ast.AsyncFunctionDef)
        assert asyncdef.name == 'f'
        assert asyncdef.args.args == None
        assert len(asyncdef.body) == 1
        expr = asyncdef.body[0]
        assert isinstance(expr, ast.Expr)
        assert isinstance(expr.value, ast.Yield)
        assert isinstance(expr.value.value, ast.Constant)

    @pytest.mark.parametrize('with_async_hacks', [False, True])
    def test_asyncComp(self, with_async_hacks):
        mod = self.get_ast("async def f():\n [i async for b in c]", with_async_hacks=with_async_hacks)
        asyncdef = mod.body[0]
        expr = asyncdef.body[0]
        comp = expr.value.generators[0]
        assert comp.target.id == 'b'
        assert comp.iter.id == 'c'
        assert comp.is_async is True

    def test_without_async_hacks(self):
        with pytest.raises(SyntaxError):
            self.get_ast("await = 1", with_async_hacks=False)

        mod = self.get_ast("await x()", with_async_hacks=False)
        assert isinstance(mod.body[0].value, ast.Await)

        mod = self.get_ast("async for x in y: pass", with_async_hacks=False)
        assert isinstance(mod.body[0], ast.AsyncFor)

    def test_with_async_hacks(self):
        mod = self.get_ast("await = 1", with_async_hacks=True)
        assert isinstance(mod.body[0], ast.Assign)
        assert isinstance(mod.body[0].targets[0], ast.Name)
        assert mod.body[0].targets[0].id == "await"

        with pytest.raises(SyntaxError):
            self.get_ast("await x()", with_async_hacks=True)

        with pytest.raises(SyntaxError):
            self.get_ast("await x()", with_async_hacks=True)

    def test_decode_error_in_string_literal(self):
        input = "u'\\x'"
        exc = pytest.raises(SyntaxError, self.get_ast, input).value
        assert exc.msg == ("(unicode error) 'unicodeescape' codec can't decode"
                           " bytes in position 0-1: truncated \\xXX escape")
        input = "u'\\x1'"
        exc = pytest.raises(SyntaxError, self.get_ast, input).value
        assert exc.msg == ("(unicode error) 'unicodeescape' codec can't decode"
                           " bytes in position 0-2: truncated \\xXX escape")

    def test_decode_error_in_string_literal_correct_line(self):
        input = "u'a' u'b'\\\n u'c' u'\\x'"
        exc = pytest.raises(SyntaxError, self.get_ast, input).value
        assert exc.msg == ("(unicode error) 'unicodeescape' codec can't decode"
                           " bytes in position 0-1: truncated \\xXX escape")
        assert exc.lineno == 2
        assert exc.offset == 7

    def test_fstring_lineno(self):
        mod = self.get_ast('x=1\nf"{    x + 1}"')
        assert mod.body[1].value.values[0].value.lineno == 2
        assert mod.body[1].value.values[0].value.col_offset == 7
        assert mod.body[1].value.values[0].value.end_lineno == 2
        assert mod.body[1].value.values[0].value.end_col_offset == 12

    def test_wrong_async_def_col_offset(self):
        mod = self.get_ast("async def f():\n pass")
        asyncdef = mod.body[0]
        assert asyncdef.col_offset == 0

    def get_first_typed_stmt(self, source):
        return self.get_first_stmt(source, flags=consts.PyCF_TYPE_COMMENTS)

    def test_type_comments(self):
        eq_w, w = self.space.eq_w, self.space.wrap
        assign = self.get_first_typed_stmt("a = 5 # type: int")
        assert eq_w(assign.type_comment, w('int'))
        lines = (
            "def func(\n"
            "  a, # type: List[int]\n"
            "  b = 5, # type: int\n"
            "  c = None\n"
            "): pass"
        )
        func = self.get_first_typed_stmt(lines)
        args = func.args
        assert eq_w(args.args[0].type_comment, w("List[int]"))
        assert eq_w(args.args[1].type_comment, w("int"))
        assert self.space.is_w(args.args[2].type_comment, self.space.w_None)

    def test_type_comments_func_body(self):
        eq_w, w = self.space.eq_w, self.space.wrap
        source = textwrap.dedent("""\
        def foo():
            # type: () -> int
            pass
        """)
        func = self.get_first_typed_stmt(source)
        assert eq_w(func.type_comment, w("() -> int"))

        source = textwrap.dedent("""\
        def foo(): # type: () -> int
            pass
        """)
        func = self.get_first_typed_stmt(source)
        assert eq_w(func.type_comment, w("() -> int"))

    def test_type_comments_statements(self):
        eq_w, w = self.space.eq_w, self.space.wrap
        asyncdef = textwrap.dedent("""\
        async def foo():
            # type: () -> int
            return await bar()
        """)
        node = self.get_first_typed_stmt(asyncdef)
        assert eq_w(node.type_comment, w("() -> int"))

        nonasciidef = textwrap.dedent("""\
        def foo():
            # type: () -> àçčéñt
            pass
        """)
        node = self.get_first_typed_stmt(nonasciidef)
        assert eq_w(node.type_comment, w("() -> àçčéñt"))

        forstmt = textwrap.dedent("""\
        for a in []:  # type: int
            pass
        """)
        node = self.get_first_typed_stmt(forstmt)
        assert eq_w(node.type_comment, w("int"))

        withstmt = textwrap.dedent("""\
        with context() as a:  # type: int
            pass
        """)
        node = self.get_first_typed_stmt(withstmt)
        assert eq_w(node.type_comment, w("int"))

        vardecl = textwrap.dedent("""\
        a = 0  # type: int
        """)
        node = self.get_first_typed_stmt(vardecl)
        assert eq_w(node.type_comment, w("int"))

    def test_type_ignore(self):
        eq_w, w = self.space.eq_w, self.space.wrap
        module = self.get_ast(textwrap.dedent("""\
        import x # type: ignore
        # type: ignore@abc
        test = 1 # type: ignore
        if test: # type: ignore
            ...
            ...
            ...
            with x() as y: # type: ignore@def
                ...
        """), flags=consts.PyCF_TYPE_COMMENTS)

        expecteds = [
            (1, ''),
            (2, '@abc'),
            (3, ''),
            (4, ''),
            (8, '@def')
        ]

        assert all([
            eq_w(type_ignore.tag, w(expected[1]))
            and type_ignore.lineno == expected[0]
            for type_ignore, expected in zip(module.type_ignores, expecteds)
        ])

    def test_type_comments_function_args(self):
        eq_w, w = self.space.eq_w, self.space.wrap
        module = self.get_ast(textwrap.dedent("""\
        def fa(
            a = 1,  # type: 1
        ):
            pass

        def fa(
            a = 1  # type: 1
        ):
            pass

        def fab(
            a,  # type: 1
            b,  # type: 2
        ):
            pass

        def fab(
            a,  # type: 1
            b  # type: 2
        ):
            pass

        def fv(
            *v,  # type: 1
        ):
            pass

        def fv(
            *v # type: 1
        ):
            pass

        def fk(
            **k,  # type: 1
        ):
            pass

        def fk(
            **k  # type: 1
        ):
            pass

        def fvk(
            *v,  # type: 1
            **k,  # type: 2
        ):
            pass

        def fvk(
            *v,  # type: 1
            **k  # type: 2
        ):
            pass

        def fav(
            a,  # type: 1
            *v,  # type: 2
        ):
            pass

        def fav(
            a,  # type: 1
            *v  # type: 2
        ):
            pass

        def fak(
            a,  # type: 1
            **k,  # type: 2
        ):
            pass

        def fak(
            a,  # type: 1
            **k  # type: 2
        ):
            pass

        def favk(
            a,  # type: 1
            *v,  # type: 2
            **k,  # type: 3
        ):
            pass

        def favk(
            a,  # type: 1
            *v,  # type: 2
            **k  # type: 3
        ):
            pass

        def fkwo(
            a, # type: 1
            *,
            b  # type: 2
        ):
            pass
        """), flags=consts.PyCF_TYPE_COMMENTS)

        for function in module.body:
            args = function.args
            all_args = []
            all_args.extend(args.args or [])
            all_args.extend(args.kwonlyargs or [])
            if args.vararg:
                all_args.append(args.vararg)
            if args.kwarg:
                all_args.append(args.kwarg)
            assert all([
                eq_w(arg.type_comment, w(str(i)))
                for i, arg in enumerate(all_args, 1)
            ])

    def test_double_type_comment(self):
        with pytest.raises(SyntaxError) as excinfo:
            tree = self.get_ast(textwrap.dedent("""\
            def foo():  # type: () -> int
                # type: () -> str
                return test
            """), flags=consts.PyCF_TYPE_COMMENTS)
        assert excinfo.value.msg.startswith("Cannot have two type comments on def")

    def test_invalid_type_comments(self):
        def check_both_ways(source):
            self.get_ast(source) # this is fine, no type_comments
            with pytest.raises(SyntaxError):
                self.get_ast(source, flags=consts.PyCF_TYPE_COMMENTS)

        check_both_ways("pass  # type: int\n")
        check_both_ways("foo()  # type: int\n")
        check_both_ways("x += 1  # type: int\n")
        check_both_ways("while True:  # type: int\n  continue\n")
        check_both_ways("while True:\n  continue  # type: int\n")
        check_both_ways("try:  # type: int\n  pass\nfinally:\n  pass\n")
        check_both_ways("try:\n  pass\nfinally:  # type: int\n  pass\n")
        check_both_ways("pass  # type: ignorewhatever\n")
        check_both_ways("pass  # type: ignoreé\n")

    def test_walrus(self):
        mod = self.get_ast("(a := 1)")
        expr = mod.body[0].value
        assert isinstance(expr, ast.NamedExpr)
        assert expr.target.id == 'a'
        assert expr.target.ctx == ast.Store
        assert isinstance(expr.value, ast.Constant)

    def test_func_type(self):
        func = self.get_ast("() -> int", p_mode="func_type")
        assert not func.argtypes
        assert isinstance(func.returns, ast.Name)
        assert func.returns.id == 'int'

        func = self.get_ast("(str, int) -> str", p_mode="func_type")
        assert len(func.argtypes) == 2
        assert [arg_type.id for arg_type in func.argtypes] == ['str', 'int']
        assert isinstance(func.returns, ast.Name)

    def test_constant_kind(self):
        expr = self.get_first_expr("'bruh'")
        assert isinstance(expr, ast.Constant)
        assert self.space.is_none(expr.kind)

        expr = self.get_first_expr("u'bruh'")
        assert isinstance(expr, ast.Constant)
        assert self.space.eq_w(expr.kind, self.space.wrap("u"))

    def test_end_positions(self):
        s = "a + b"
        expr = self.get_first_expr(s)
        assert expr.end_lineno == expr.lineno
        assert expr.col_offset + len(s) == expr.end_col_offset

        s = '''def func(x: int,
         *args: str,
         z: float = 0,
         **kwargs: Any) -> bool:
    return True'''
        fdef = self.get_ast(s).body[0]
        assert fdef.end_lineno == 5
        assert fdef.end_col_offset == 15
        assert fdef.get_source_segment(s) == s

        s = 'lambda a, b, *c: (a + b) * c'
        fdef = self.get_ast(s).body[0].value
        assert fdef.get_source_segment(s) == s
        assert fdef.args.args[0].get_source_segment(s) == "a"
        assert fdef.body.get_source_segment(s) == "(a + b) * c"

        s = '( ( ( a ) ) ) ( )'
        tree = self.get_first_expr(s)
        assert tree.end_col_offset == len(s)
        assert fdef.get_source_segment(s) == s

        s = "a.b"
        tree = self.get_first_expr(s)
        assert tree.end_col_offset == len(s)
        assert tree.col_offset == 0
        assert fdef.get_source_segment(s) == s

        s = "a[x:y]"
        tree = self.get_first_expr(s)
        assert tree.end_col_offset == len(s)
        assert tree.col_offset == 0
        assert fdef.get_source_segment(s) == s

        s = "f(x for x in y)"
        tree = self.get_first_expr(s)
        assert tree.end_col_offset == len(s)
        assert tree.col_offset == 0
        gen = tree.args[0]
        assert gen.end_col_offset in (len(s), len(s) - 1)
        assert gen.col_offset in (1, 2)
        assert fdef.get_source_segment(s) == s

        s = "(x for x in y)"
        tree = self.get_first_expr(s)
        assert tree.end_col_offset == len(s)
        assert tree.col_offset == 0

        s = "[x for x in y]"
        tree = self.get_first_expr(s)
        assert tree.end_col_offset == len(s)
        assert tree.col_offset == 0
        assert fdef.get_source_segment(s) == s

        s = "{x for x in y}"
        tree = self.get_first_expr(s)
        assert tree.end_col_offset == len(s)
        assert tree.col_offset == 0
        assert fdef.get_source_segment(s) == s

        s = "{x: x+1 for x in y}"
        tree = self.get_first_expr(s)
        assert tree.end_col_offset == len(s)
        assert tree.col_offset == 0
        assert fdef.get_source_segment(s) == s

    def test_binop_offset_bug(self):
        s = "1 + 2+3+4"
        tree = self.get_first_expr(s)
        assert tree.col_offset == 0
        assert tree.end_col_offset == len(s)

        parent_binop = self.get_first_expr('4+5+6+7')
        child_binop = parent_binop.left
        grandchild_binop = child_binop.left
        assert parent_binop.col_offset == 0
        assert parent_binop.end_col_offset == 7
        assert child_binop.col_offset == 0
        assert child_binop.end_col_offset == 5
        assert grandchild_binop.col_offset == 0
        assert grandchild_binop.end_col_offset == 3

    def test_binop_paren_bug(self):
        s = "(    1 + 2)"
        tree = self.get_first_expr(s)
        assert tree.col_offset == 5
        assert tree.end_col_offset == len(s) - 1

    def test_tuple_pos_bug(self):
        s = "(a, bccccccccccccccccccccc)"
        tree = self.get_first_expr(s)
        assert tree.col_offset == 0
        assert tree.end_col_offset == len(s)

    def test_tuple_assign_pos_bug(self):
        s = "(a, b) = c"
        tree = self.get_ast(s)
        assert tree.body[0].targets[0].col_offset == 0
        assert tree.body[0].targets[0].end_col_offset == 6

    def test_dotted_name_bug(self):
        tree = self.get_ast('@a.b.c\ndef f(): pass')
        attr_b = tree.body[0].decorator_list[0].value
        assert attr_b.end_col_offset == 4

    def test_get_source_segment(self):
        s = "a + (b + c)"
        tree = self.get_first_expr(s)
        assert tree.get_source_segment(s) == s
        assert tree.get_source_segment(s, padded=True) == s
        # single line, no padding
        assert tree.right.get_source_segment(s) == "b + c"
        assert tree.right.get_source_segment(s, padded=True) == "b + c"

        # padding
        s = "a + (b \n + c)"
        tree = self.get_first_expr(s)
        assert tree.get_source_segment(s) == s
        assert tree.get_source_segment(s, padded=True) == s
        assert tree.right.get_source_segment(s) == "b \n + c"
        assert tree.right.get_source_segment(s, padded=True) == "     b \n + c"

    def test_fstring_mismatch(self):
        with pytest.raises(SyntaxError) as excinfo:
            tree = self.get_ast("f'{((}')")
        assert excinfo.value.msg == "unmatched ')'"

    def test_keyword_position(self):
        tree = self.get_first_expr("f(a=1, **kwarg)")
        assert tree.keywords[0].col_offset == 2
        assert tree.keywords[0].end_col_offset == 5
        assert tree.keywords[1].col_offset == 7
        assert tree.keywords[1].end_col_offset == 14

