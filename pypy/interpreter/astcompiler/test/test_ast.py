from pypy.interpreter.astcompiler import ast
class TestAstToObject:
    def test_types(self, space):
        assert space.issubtype_w(
                ast.get(space).w_Module, ast.get(space).w_mod)
                                  
    def test_constant_num(self, space):
        value = space.wrap(42)
        node = ast.Constant(value, space.w_None, lineno=1, col_offset=1, end_lineno=-1, end_col_offset=-1)
        w_node = node.to_object(space)
        assert space.is_w(space.getattr(w_node, space.wrap("value")), value)

    def test_expr(self, space):
        value = space.wrap(42)
        node = ast.Constant(value, space.w_None, lineno=1, col_offset=1, end_lineno=-1, end_col_offset=-1)
        expr = ast.Expr(node, lineno=1, col_offset=1, end_lineno=-1, end_col_offset=-1)
        w_node = expr.to_object(space)
        # node.value.n
        assert space.is_w(space.getattr(space.getattr(w_node, space.wrap("value")),
                             space.wrap("value")), value)

    def test_operation(self, space):
        val1 = ast.Constant(space.wrap(1), space.w_None, lineno=1, col_offset=1, end_lineno=-1, end_col_offset=-1)
        val2 = ast.Constant(space.wrap(2), space.w_None, lineno=1, col_offset=1, end_lineno=-1, end_col_offset=-1)
        node = ast.BinOp(left=val1, right=val2, op=ast.Add,
                         lineno=1, col_offset=1, end_lineno=-1, end_col_offset=-1)
        w_node = node.to_object(space)
        w_op = space.getattr(w_node, space.wrap("op"))
        assert space.isinstance_w(w_op, ast.get(space).w_operator)

    def test_to_object_does_not_add_optional_attributes(self, space):
        val1 = ast.Constant(space.wrap(1), None, lineno=1, col_offset=1, end_lineno=-1, end_col_offset=-1)
        w_const = val1.to_object(space)
        w_dict = w_const.getdict(space)
        space.raises_w(space.w_KeyError, space.getitem, w_dict, space.newtext("kind"))
        space.is_w(space.getattr(w_const, space.newtext("kind")), space.w_None)

    def test_from_object(self, space):
        value = space.wrap(42)
        w_node = space.call_function(ast.get(space).w_Constant)
        space.setattr(w_node, space.wrap('value'), value)
        space.setattr(w_node, space.wrap('kind'), space.w_None)
        space.setattr(w_node, space.wrap('lineno'), space.wrap(1))
        space.setattr(w_node, space.wrap('col_offset'), space.wrap(1))
        node = ast.Constant.from_object(space, w_node)
        assert node.value is value

    def test_from_object_error(self, space):
        w_node = space.call_function(ast.get(space).w_Module)
        excinfo = space.raises_w(space.w_TypeError, ast.Module.from_object, space, w_node)
        error = space.text_w(excinfo.value.get_w_value(space))
        assert error == "required field 'body' missing from Module"
        w_node = space.call_function(ast.get(space).w_Expression, space.w_None)
        excinfo = space.raises_w(space.w_ValueError, ast.Expression.from_object, space, w_node)
        error = space.text_w(excinfo.value.get_w_value(space))
        assert error == "field 'body' is required for Expression"

    def test_docstring(self, space):
        doc = space.text_w(space.getattr(ast.get(space).w_arguments, space.newtext("__doc__")))
        assert doc == "arguments(arg* posonlyargs, arg* args, arg? vararg, arg* kwonlyargs, expr* kw_defaults, arg? kwarg, expr* defaults)"

    def test_fields(self, space):
        w_fields = space.getattr(ast.get(space).w_FunctionDef,
                                 space.wrap("_fields"))
        assert space.eq_w(w_fields, space.wrap(
            ('name', 'args', 'body', 'decorator_list', 'returns', 'type_comment')))
        w_fields = space.getattr(ast.get(space).w_arguments,
                                 space.wrap("_fields"))
        assert space.eq_w(w_fields, space.wrap(
            ('posonlyargs', 'args', 'vararg', 'kwonlyargs', 'kw_defaults',
             'kwarg', 'defaults')))
        
    def test_attributes(self, space):
        w_attrs = space.getattr(ast.get(space).w_FunctionDef,
                                space.wrap("_attributes"))
        assert space.eq_w(w_attrs, space.wrap(('lineno', 'col_offset', 'end_lineno', 'end_col_offset')))
        
    def test_end_lineno_end_col_offset_None_default(self):
        space = self.space
        w_node = space.call_function(ast.get(space).w_Constant)
        assert space.is_w(space.w_None, space.getattr(w_node, space.newtext("end_lineno")))
        assert space.is_w(space.w_None, space.getattr(w_node, space.newtext("end_col_offset")))
