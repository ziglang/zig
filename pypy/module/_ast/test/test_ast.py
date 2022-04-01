# encoding: utf-8
import py


class AppTestAST:
    spaceconfig = {
        "usemodules": ['struct', 'binascii'],
    }

    def setup_class(cls):
        cls.w_ast = cls.space.getbuiltinmodule('_ast')

    def w_get_ast(self, source, mode="exec", flags=0, feature_version=-1):
        ast = self.ast
        mod = compile(source, "<test>", mode, ast.PyCF_ONLY_AST | flags, _feature_version=feature_version)
        assert isinstance(mod, ast.mod)
        return mod

    def test_module(self):
        ast = self.ast
        assert isinstance(ast.__version__, str)

    def test_flags(self):
        from copyreg import _HEAPTYPE
        assert self.ast.AST.__flags__ & _HEAPTYPE == 0
        assert self.ast.Module.__flags__ & _HEAPTYPE == _HEAPTYPE

    def test_build_ast(self):
        ast = self.ast
        mod = self.get_ast("x = 4")
        assert isinstance(mod, ast.Module)
        assert len(mod.body) == 1

    def test_simple_sums(self):
        ast = self.ast
        mod = self.get_ast("x = 4 + 5")
        expr = mod.body[0].value
        assert isinstance(expr, ast.BinOp)
        assert isinstance(expr.op, ast.Add)
        expr.op = ast.Sub()
        assert isinstance(expr.op, ast.Sub)
        co = compile(mod, "<example>", "exec")
        ns = {}
        exec(co, ns)
        assert ns["x"] == -1
        mod = self.get_ast("4 < 5 < 6", "eval")
        assert isinstance(mod.body, ast.Compare)
        assert len(mod.body.ops) == 2
        for op in mod.body.ops:
            assert isinstance(op, ast.Lt)
        mod.body.ops[0] = ast.Gt()
        co = compile(mod, "<string>", "eval")
        assert not eval(co)

    def test_string(self):
        mod = self.get_ast("'hi'", "eval")
        s = mod.body
        assert s.value == "hi"
        s.value = "pypy"
        assert eval(compile(mod, "<test>", "eval")) == "pypy"

    def test_empty_initialization(self):
        ast = self.ast
        def com(node):
            return compile(node, "<test>", "exec")
        mod = ast.Module()
        raises(AttributeError, getattr, mod, "body")
        exc = raises(TypeError, com, mod).value
        assert str(exc) == "required field 'body' missing from Module"
        expr = ast.Name()
        expr.id = "hi"
        expr.ctx = ast.Load()
        expr.lineno = 4
        exc = raises(TypeError, com, ast.Module([ast.Expr(expr)], [])).value
        assert (str(exc) == "required field \"lineno\" missing from stmt" or # cpython
                str(exc) == "required field 'lineno' missing from Expr")   # pypy, better

    def test_int(self):
        ast = self.ast
        imp = ast.ImportFrom("", ["apples"], -1)
        assert imp.level == -1
        imp.level = 3
        assert imp.level == 3

        body = [ast.ImportFrom(module='time',
                               names=[ast.alias(name='sleep')],
                               level=None,
                               lineno=1, col_offset=2)]
        mod = ast.Module(body, [])
        compile(mod, 'test', 'exec')

    def test_bad_int(self):
        ast = self.ast
        body = [ast.ImportFrom(module='time',
                               names=[ast.alias(name='sleep')],
                               level='A',
                               lineno=1, col_offset=2)]
        mod = ast.Module(body, [])
        exc = raises(ValueError, compile, mod, 'test', 'exec')
        assert str(exc.value) == "invalid integer value: 'A'"

    def test_identifier(self):
        ast = self.ast
        name = ast.Name("name_word", ast.Load())
        assert name.id == "name_word"
        name.id = "hi"
        assert name.id == "hi"

    def test_name_pep3131(self):
        name = self.get_ast("日本", "eval").body
        assert isinstance(name, self.ast.Name)
        assert name.id == "日本"

    def test_function_pep3131(self):
        fn = self.get_ast("def µ(µ='foo'): pass").body[0]
        assert isinstance(fn, self.ast.FunctionDef)
        # µ normalized to NFKC
        expected = '\u03bc'
        assert fn.name == expected
        assert fn.args.args[0].arg == expected

    def test_import_pep3131(self):
        ast = self.ast
        im = self.get_ast("from packageµ import modµ as µ").body[0]
        assert isinstance(im, ast.ImportFrom)
        expected = '\u03bc'
        assert im.module == 'package' + expected
        alias = im.names[0]
        assert alias.name == 'mod' + expected
        assert alias.asname == expected

    def test_object(self):
        ast = self.ast
        const = ast.Constant(4, None)
        assert const.value == 4
        assert const.kind is None
        const.value = 5
        assert const.value == 5

    def test_optional(self):
        mod = self.get_ast("x(32)", "eval")
        call = mod.body
        assert len(call.args) == 1
        assert call.args[0].value == 32
        co = compile(mod, "<test>", "eval")
        ns = {"x" : lambda x: x}
        assert eval(co, ns) == 32

    def test_list_syncing(self):
        ast = self.ast
        mod = ast.Module([ast.Lt()], [])
        raises(TypeError, compile, mod, "<string>", "exec")
        mod = self.get_ast("x = y = 3")
        assign = mod.body[0]
        assert len(assign.targets) == 2
        assign.targets[1] = ast.Name("lemon", ast.Store(),
                                     lineno=0, col_offset=0)
        name = ast.Name("apple", ast.Store(),
                        lineno=0, col_offset=0)
        mod.body.append(ast.Assign([name], ast.Constant(4, None, lineno=0, col_offset=0), None,
                                   lineno=0, col_offset=0))
        co = compile(mod, "<test>", "exec")
        ns = {}
        exec(co, ns)
        assert "y" not in ns
        assert ns["x"] == ns["lemon"] == 3
        assert ns["apple"] == 4

    def test_empty_module(self):
        compile(self.ast.Module([], []), "<test>", "exec")

    def test_ast_types(self):
        ast = self.ast
        expr = ast.Expr()
        expr.value = ast.Lt()

    def test_abstract_ast_types(self):
        ast = self.ast
        ast.expr()
        ast.AST()
        class X(ast.AST):
            pass
        X()
        class Y(ast.expr):
            pass
        Y()
        exc = raises(TypeError, ast.AST, 2)
        assert exc.value.args[0] == "_ast.AST constructor takes at most 0 positional argument"

    def test_constructor(self):
        ast = self.ast
        body = []
        mod = ast.Module(body, [])
        assert mod.body is body
        target = ast.Name("hi", ast.Store())
        expr = ast.Name("apples", ast.Load())
        otherwise = []
        fr = ast.For(target, expr, body, otherwise, None, lineno=0, col_offset=1)
        assert fr.target is target
        assert fr.iter is expr
        assert fr.orelse is otherwise
        assert fr.body is body
        assert fr.lineno == 0
        assert fr.col_offset == 1
        fr = ast.For(body=body, target=target, iter=expr, col_offset=1,
                     type_comment = None, lineno=0, orelse=otherwise)
        assert fr.target is target
        assert fr.iter is expr
        assert fr.orelse is otherwise
        assert fr.body is body
        assert fr.lineno == 0
        assert fr.col_offset == 1
        exc = raises(TypeError, ast.Module, 1, 2, 3).value
        msg = str(exc)
        assert msg == "Module constructor takes at most 2 positional argument"
        ast.Module(nothing=23)

    def test_future(self):
        mod = self.get_ast("from __future__ import with_statement")
        compile(mod, "<test>", "exec")
        mod = self.get_ast(""""I am a docstring."\n
from __future__ import generators""")
        compile(mod, "<test>", "exec")
        mod = self.get_ast("from __future__ import with_statement; import y; " \
                               "from __future__ import nested_scopes")
        raises(SyntaxError, compile, mod, "<test>", "exec")
        mod = self.get_ast("from __future__ import division\nx = 1/2")
        co = compile(mod, "<test>", "exec")
        ns = {}
        exec(co, ns)
        assert ns["x"] == .5

    def test_field_attr_writable(self):
        import _ast as ast
        x = ast.Constant()
        # We can assign to _fields
        x._fields = 666
        assert x._fields == 666

    def test_pickle(self):
        import pickle
        mod = self.get_ast("if y: x = 4")
        co = compile(mod, "<example>", "exec")

        s = pickle.dumps(mod)
        mod2 = pickle.loads(s)
        ns = {"y" : 1}
        co2 = compile(mod2, "<example>", "exec")
        exec(co2, ns)
        assert ns["x"] == 4

    def test_classattrs(self):
        import _ast as ast
        x = ast.Constant()
        assert x._fields == ('value', 'kind')
        exc = raises(AttributeError, getattr, x, 'value')
        assert str(exc.value) == "'Constant' object has no attribute 'value'"

        x = ast.Constant(42)
        assert x.value == 42
        exc = raises(AttributeError, getattr, x, 'lineno')
        assert str(exc.value) == "'Constant' object has no attribute 'lineno'"

        y = ast.Constant()
        x.lineno = y
        assert x.lineno == y

        exc = raises(AttributeError, getattr, x, 'foobar')
        assert str(exc.value) == "'Constant' object has no attribute 'foobar'"

        x = ast.Constant(lineno=2)
        assert x.lineno == 2

        x = ast.Constant(42, None, lineno=0)
        assert x.lineno == 0
        assert x._fields == ('value', 'kind')
        assert x.value == 42
        assert x.kind is None

        raises(TypeError, ast.Constant, 1, 2, 3)
        raises(TypeError, ast.Constant, 1, 2, 3, lineno=0)

    def test_issue1680_nonseq(self):
        # Test deleting an attribute manually

        _ast = self.ast
        mod = self.get_ast("self.attr")
        assert isinstance(mod, _ast.Module)
        assert len(mod.body) == 1
        assert isinstance(mod.body[0], _ast.Expr)
        assert isinstance(mod.body[0].value, _ast.Attribute)
        assert isinstance(mod.body[0].value.value, _ast.Name)
        attr = mod.body[0].value
        assert hasattr(attr, 'value')
        delattr(attr, 'value')
        assert not hasattr(attr, 'value')

        # Test using a node transformer to delete an attribute

        tree = self.get_ast("self.attr2")

        import ast
        class RemoveSelf( ast.NodeTransformer ):
          """NodeTransformer class to remove all references to 'self' in the ast"""
          def visit_Name( self, node ):
            if node.id == 'self':
              return None
            return node

        assert hasattr(tree.body[0].value, 'value')
        #print ast.dump( tree )
        new_tree = RemoveSelf().visit( tree )
        #print ast.dump( new_tree )
        assert not hasattr(new_tree.body[0].value, 'value')

        # Setting an attribute manually, then deleting it

        mod = self.get_ast("class MyClass(object): pass")
        import ast
        assert isinstance(mod.body[0], _ast.ClassDef)
        mod.body[0].name = 42
        delattr(mod.body[0], 'name')
        assert not hasattr(mod.body[0], 'name')

    def test_issue1680_seq(self):
        # Test deleting an attribute manually

        _ast = self.ast
        mod = self.get_ast("self.attr")
        assert isinstance(mod, _ast.Module)
        assert len(mod.body) == 1
        assert isinstance(mod.body[0], _ast.Expr)
        assert isinstance(mod.body[0].value, _ast.Attribute)
        assert isinstance(mod.body[0].value.value, _ast.Name)
        assert hasattr(mod, 'body')
        delattr(mod, 'body')
        assert not hasattr(mod, 'body')

    def test_node_identity(self):
        import _ast as ast
        n1 = ast.Constant(1, None)
        n3 = ast.Constant(3, None)
        addop = ast.Add()
        x = ast.BinOp(n1, addop, n3)
        assert x.left == n1
        assert x.op == addop
        assert x.right == n3

    def test_functiondef(self):
        import ast as ast_utils
        import _ast as ast
        fAst = ast.FunctionDef(
            name="foo",
            args=ast.arguments(
                args=[], vararg=None, kwarg=None, defaults=[],
                kwonlyargs=[], kw_defaults=[], posonlyargs=[]),
            body=[ast.Expr(ast.Constant('docstring', None))],
            decorator_list=[], lineno=5, col_offset=0)
        exprAst = ast.Interactive(body=[fAst])
        ast_utils.fix_missing_locations(exprAst)
        compiled = compile(exprAst, "<foo>", "single")
        #
        d = {}
        eval(compiled, d, d)
        assert type(d['foo']) is type(lambda: 42)
        assert d['foo']() is None

    def test_missing_name(self):
        import _ast as ast
        n = ast.FunctionDef(name=None)
        n.name = "foo"
        n.name = "foo"
        n.name = "foo"
        assert n.name == "foo"

    def test_issue793(self):
        import _ast as ast
        body = ast.Module([
            ast.Try([ast.Pass(lineno=2, col_offset=4)],
                [ast.ExceptHandler(ast.Name('Exception', ast.Load(),
                                            lineno=3, col_offset=0),
                                   None, [ast.Pass(lineno=4, col_offset=0)],
                                   lineno=4, col_offset=0)],
                [], [], lineno=1, col_offset=0)
        ], [])
        exec(compile(body, '<string>', 'exec'))

    def test_empty_set(self):
        import ast as ast_utils
        import _ast as ast
        m = ast.Module(body=[ast.Expr(value=ast.Set(elts=[]))], type_ignores=[])
        ast_utils.fix_missing_locations(m)
        compile(m, "<test>", "exec")

    def test_invalid_sum(self):
        import _ast as ast
        pos = dict(lineno=2, col_offset=3)
        m = ast.Module([ast.Expr(ast.expr(**pos), **pos)], [])
        exc = raises(TypeError, compile, m, "<test>", "exec")

    def test_invalid_identitifer(self):
        import ast as ast_utils
        import _ast as ast
        m = ast.Module([ast.Expr(ast.Name(b"x", ast.Load()))], [])
        ast_utils.fix_missing_locations(m)
        exc = raises(TypeError, compile, m, "<test>", "exec")

    def test_invalid_constant(self):
        import ast as ast_utils
        import _ast as ast
        m = ast.Module([ast.Expr(ast.Constant(ast.List([], ast.Load()), None))], [])
        ast_utils.fix_missing_locations(m)
        exc = raises(TypeError, compile, m, "<test>", "exec")

    def test_hacked_lineno(self):
        import _ast
        stmt = '''if 1:
            try:
                foo
            except Exception as error:
                bar
            except Baz as error:
                bar
            '''
        mod = compile(stmt, "<test>", "exec", _ast.PyCF_ONLY_AST)
        # These lineno are invalid, but should not crash the interpreter.
        mod.body[0].body[0].handlers[0].lineno = 7
        mod.body[0].body[0].handlers[1].lineno = 6
        code = compile(mod, "<test>", "exec")

    def test_dict_astNode(self):
        import _ast as ast
        num_node = ast.Constant(value=2, kind=None, lineno=2, col_offset=3)
        dict_res = num_node.__dict__
        assert dict_res == {'value':2, 'kind': None, 'lineno':2, 'col_offset':3}

    def test_issue1673_Num_notfullinit(self):
        import _ast as ast
        import copy
        num_node = ast.Constant(value=2,lineno=2)
        num_node2 = copy.deepcopy(num_node)
        assert num_node2.value == 2
        assert num_node2.lineno == 2

    def test_issue1673_Num_fullinit(self):
        import _ast as ast
        import copy
        num_node = ast.Constant(value=2,kind=None,lineno=2,col_offset=3)
        num_node2 = copy.deepcopy(num_node)
        assert num_node.value == num_node2.value
        assert num_node.kind is num_node2.kind
        assert num_node.lineno == num_node2.lineno
        assert num_node.col_offset == num_node2.col_offset
        dict_res = num_node2.__dict__
        assert dict_res == {'value':2, 'kind': None, 'lineno':2, 'col_offset':3}

    def test_issue1673_Str(self):
        import _ast as ast
        import copy
        str_node = ast.Constant(value=2,kind=None,lineno=2)
        assert str_node.value == 2
        assert str_node.lineno == 2
        str_node2 = copy.deepcopy(str_node)
        str_node2.kind = 'u'
        dict_res = str_node2.__dict__
        assert dict_res == {'value':2, 'kind': 'u', 'lineno':2}

    def test_bug_null_in_objspace_type(self):
        import _ast as ast
        code = ast.Expression(lineno=1, col_offset=1, body=ast.ListComp(lineno=1, col_offset=1, elt=ast.Call(lineno=1, col_offset=1, func=ast.Name(lineno=1, col_offset=1, id='str', ctx=ast.Load(lineno=1, col_offset=1)), args=[ast.Name(lineno=1, col_offset=1, id='x', ctx=ast.Load(lineno=1, col_offset=1))], keywords=[]), generators=[ast.comprehension(lineno=1, col_offset=1, target=ast.Name(lineno=1, col_offset=1, id='x', ctx=ast.Store(lineno=1, col_offset=1)), iter=ast.List(lineno=1, col_offset=1, elts=[ast.Constant(lineno=1, col_offset=1, value=23)], ctx=ast.Load(lineno=1, col_offset=1, )), ifs=[], is_async=False)]))
        compile(code, '<template>', 'eval')

    def test_empty_yield_from(self):
        # Issue 16546: yield from value is not optional.
        import ast
        empty_yield_from = ast.parse("def f():\n yield from g()")
        empty_yield_from.body[0].body[0].value.value = None
        exc = raises(ValueError, compile, empty_yield_from, "<test>", "exec")
        assert "field 'value' is required for YieldFrom" in str(exc.value)

    def test_compare(self):
        import ast as ast_utils
        import _ast as ast
        
        def _mod(mod, msg=None, mode="exec", exc=ValueError):
            mod.lineno = mod.col_offset = 0
            ast_utils.fix_missing_locations(mod)
            exc = raises(exc, compile, mod, "<test>", mode)
            if msg is not None:
                assert msg in str(exc.value)
        def _expr(node, msg=None, exc=ValueError):
            mod = ast.Module([ast.Expr(node)], [])
            _mod(mod, msg, exc=exc)
        left = ast.Name("x", ast.Load())
        comp = ast.Compare(left, [ast.In()], [])
        _expr(comp, "no comparators")
        comp = ast.Compare(left, [ast.In()], [ast.Constant(4, None), ast.Constant(5, None)])
        _expr(comp, "different number of comparators and operands")

    def test_dict_unpacking(self):
        self.get_ast("{**{1:2}, 2:3}")

    def test_type_comments(self):
        mod = self.get_ast("a = 5 # type: int", flags=self.ast.PyCF_TYPE_COMMENTS)
        assert mod.body[0].type_comment == "int"

        mod = self.get_ast("a = 5 # type: ignore", flags=self.ast.PyCF_TYPE_COMMENTS)
        assert len(mod.type_ignores) == 1
        assert mod.type_ignores[0].tag == ""
        assert mod.type_ignores[0].lineno == 1

        mod = self.get_ast("a = 5")
        assert mod.body[0].type_comment is None

    def test_type_comments_are_None_by_default(self):
        mod = self.get_ast("a = 5 # type: int")
        assert mod.body[0].type_comment is None

        mod = self.get_ast("a = 5 # type: int")
        assert mod.body[0].type_comment is None
        mod = self.get_ast("""def fkwo(
            a, # type: 1
            *,
            b  # type: 2
        ):
            pass
        """)
        assert mod.body[0].args.args[0].type_comment is None

    def test_ast_initalization(self):
        import _ast as ast

        zero = ast.Module()
        assert not hasattr(zero, "body")
        assert not hasattr(zero, "type_ignores")

        one = ast.Module(1)
        assert one.body == 1
        assert not hasattr(one, "type_ignores")

        full = ast.Module(1, 2)
        assert full.body == 1
        assert full.type_ignores == 2

        exc = raises(TypeError, ast.Module, 1, 2, 3).value
        msg = str(exc)
        assert msg == "Module constructor takes at most 2 positional argument"

        raises(TypeError, ast.Module, 1, 2, type_ignores=3)

    def test_ast_feature_version(self):
        raises(SyntaxError, self.get_ast, "await = x")
        raises(SyntaxError, self.get_ast, "await = x", feature_version=9)
        raises(SyntaxError, self.get_ast, "await = x", feature_version=-1)

        tree_36 = self.get_ast("await = x", feature_version=6)
        assert tree_36.body[0].targets[0].id == 'await'

        tree_35 = self.get_ast("await = x", feature_version=5)
        assert tree_35.body[0].targets[0].id == 'await'

    def test_ast_feature_version_with_type_comments(self):

        import ast
        import textwrap

        ignores = textwrap.dedent("""\
        def foo():
            pass  # type: ignore

        def bar():
            x = 1  # type: ignore

        def baz():
            pass  # type: ignore[excuse]
            pass  # type: ignore=excuse
            pass  # type: ignore [excuse]
            x = 1  # type: ignore whatever
        """)

        for version in range(9):
            tree_1 = ast.parse(ignores, type_comments=True, feature_version=version)
            tree_2 = ast.parse(ignores, type_comments=True, feature_version=(3, version))

            assert len(tree_1.type_ignores) == 6
            assert len(tree_2.type_ignores) == 6

    def test_fstring_self_documenting_feature_version(self):
        raises(SyntaxError, self.get_ast, "f'{x=}'", feature_version=7)
        self.get_ast("'f{x=}'", feature_version=7)

    def test_ast_feature_version_asynccomp_bug(self):
        import ast
        raises(SyntaxError, ast.parse, 'async def foo(xs):\n    [x async for x in xs]\n', feature_version=(3, 4))

    def test_ast_feature_version_underscore_number(self):
        import ast
        raises(SyntaxError, ast.parse, '12_12', feature_version=(3, 4))

    def test_crash_bug(self):
        import ast
        raises(SyntaxError, ast.parse, 'def fa(\n    a = 1,  # type: A\n    /\n):\n    pass\n\ndef fab(\n    a,  # type: A\n    /,\n    b,  # type: B\n):\n    pass\n\ndef fav(\n    a,  # type: A\n    /,\n    *v,  # type: V\n):\n    pass\n\ndef fak(\n    a,  # type: A\n    /,\n    **k,  # type: K\n):\n    pass\n\ndef favk(\n    a,  # type: A\n    /,\n    *v,  # type: V\n    **k,  # type: K\n):\n    pass\n\n', feature_version=4)

    def test_module(self):
        import ast
        assert ast.expr.__module__ == 'ast'
