from pypy.interpreter.astcompiler import ast, misc
from pypy.interpreter.error import OperationError


class UnacceptableExpressionContext(Exception):

    def __init__(self, node, msg):
        self.node = node
        self.msg = msg
setattr(ast, "UnacceptableExpressionContext", UnacceptableExpressionContext)


class __extend__(ast.AST):

    def as_node_list(self, space):
        raise AssertionError("only for expressions")

    def set_context_copy(self, ctx):
        """ make a copy of the node, with ctx set """
        raise AssertionError("should only be on expressions")

    def get_source_segment(self, source, padded=False):
        lineno = self.lineno - 1 # both 0-based
        end_lineno = self.end_lineno - 1
        if lineno < 0:
            return None
        if end_lineno < 0:
            return None
        col_offset = self.col_offset
        end_col_offset = self.end_col_offset
        if col_offset < 0:
            return None
        if end_col_offset < 0:
            return None
        s = source.splitlines(True)
        if lineno == end_lineno:
            return s[lineno][col_offset:end_col_offset]
        first = s[lineno][col_offset:]
        if padded:
            first = " " * col_offset + first
        res = [first]
        for i in range(lineno+1, end_lineno):
            res.append(s[i])
        res.append(s[end_lineno][:end_col_offset])
        return "".join(res)

    def location(self):
        return (self.lineno, self.col_offset, self.end_lineno, self.end_col_offset)


class __extend__(ast.expr):

    constant = False
    _description = None
    _type_name = None

    def _get_descr(self, space):
        return self._description or "???" # better than a crash

    def _get_type_name(self, space):
        return self._type_name

    def as_node_list(self, space):
        return None

    def set_context_copy(self, ctx):
        assert 0, "should be unreachable"


class __extend__(ast.List):
    _description = "list"

    def as_node_list(self, space):
        return self.elts

    def set_context_copy(self, ctx):
        return ast.List(
            set_context_copy_list(self.elts, ctx),
            ctx,
            *self.location())


class __extend__(ast.Attribute):

    def set_context_copy(self, ctx):
        return ast.Attribute(
            self.value,
            self.attr,
            ctx,
            *self.location())
        self.ctx = ctx


class __extend__(ast.Subscript):

    def set_context_copy(self, ctx):
        return ast.Subscript(
            self.value,
            self.slice,
            ctx,
            *self.location())


class __extend__(ast.Name):

    def set_context_copy(self, ctx):
        return ast.Name(
            self.id,
            ctx,
            *self.location())


class __extend__(ast.Tuple):

    _description = "tuple"
    _type_name = "tuple"

    def as_node_list(self, space):
        return self.elts

    def set_context_copy(self, ctx):
        return ast.Tuple(
            set_context_copy_list(self.elts, ctx),
            ctx,
            *self.location())


class __extend__(ast.Lambda):

    _description = "lambda"
    _type_name = "function"


class __extend__(ast.Call):

    _description = "function call"


class __extend__(ast.BoolOp, ast.BinOp, ast.UnaryOp):

    _description = "operator"


class __extend__(ast.GeneratorExp):

    _description = "generator expression"
    _type_name = "generator"


class __extend__(ast.Yield):

    _description = "yield expression"


class __extend__(ast.ListComp):

    _description = "list comprehension"
    _type_name = "list"


class __extend__(ast.SetComp):

    _description = "set comprehension"
    _type_name = "set"


class __extend__(ast.DictComp):

    _description = "dict comprehension"
    _type_name = "dict"


class __extend__(ast.List):
    _type_name = "list"

class __extend__(ast.Dict):
    _description = "dict display"
    _type_name = "dict"

class __extend__(ast.Set):
    _description = "set display"
    _type_name = "set"

class __extend__(ast.JoinedStr, ast.FormattedValue):
    _description = "f-string expression"
    _type_name = "str"

class __extend__(ast.Compare):

    _description = "comparison"

class __extend__(ast.Starred):

    _description = "starred expression"

    def set_context_copy(self, ctx):
        return ast.Starred(
            self.value.set_context_copy(ctx),
            ctx,
            *self.location())

class __extend__(ast.NamedExpr):
    _description = "named expression"

class __extend__(ast.IfExp):

    _description = "conditional expression"


class __extend__(ast.Constant):

    constant = True
    _description = 'literal'

    def as_node_list(self, space):
        try:
            values_w = space.unpackiterable(self.value)
        except OperationError:
            return None
        line = self.lineno
        column = self.col_offset
        return [ast.Constant(w_obj, space.w_None, line, column, self.end_lineno, self.end_col_offset) for w_obj in values_w]

    def _get_descr(self, space):
        for singleton, name in [
            (space.w_True, 'True'),
            (space.w_False, 'False'),
            (space.w_None, 'None'),
            (space.w_Ellipsis, 'Ellipsis')
        ]:
            if space.is_w(self.value, singleton):
                return name
        return self._description

    def _get_type_name(self, space):
        return space.type(self.value).name


def set_context_copy_list(elts, ctx):
    if elts is None:
        return elts
    return [elt.set_context_copy(ctx) for elt in elts]

