from rpython.rlib.rutf8 import Utf8StringBuilder
from rpython.rlib.objectmodel import specialize
from pypy.interpreter.error import oefmt, OperationError
from pypy.interpreter.astcompiler import ast


PRIORITY_TUPLE = 0
PRIORITY_TEST = 1                   # 'if'-'else', 'lambda'
PRIORITY_OR = 2                     # 'or'
PRIORITY_AND = 3                    # 'and'
PRIORITY_NOT = 4                    # 'not'
PRIORITY_CMP = 5                    # '<', '>', '==', '>=', '<=', '!=',
                                    #   'in', 'not in', 'is', 'is not'
PRIORITY_EXPR = 6
PRIORITY_BOR = PRIORITY_EXPR = 7    # '|'
PRIORITY_BXOR = 8                   # '^'
PRIORITY_BAND = 9                   # '&'
PRIORITY_SHIFT = 10                 # '<<', '>>'
PRIORITY_ARITH = 11                 # '+', '-'
PRIORITY_TERM = 12                  # '*', '@', '/', '%', '//'
PRIORITY_FACTOR = 13                # unary '+', '-', '~'
PRIORITY_POWER = 14                 # '**'
PRIORITY_AWAIT = 15                 # 'await'
PRIORITY_ATOM = 16


class Parenthesizer(object):
    def __init__(self, visitor, priority):
        self.visitor = visitor
        self.priority = priority

    def __enter__(self):
        visitor = self.visitor
        level = visitor.level
        if level > self.priority:
            visitor.append_ascii("(")

    def __exit__(self, *args):
        visitor = self.visitor
        level = visitor.level
        if level > self.priority:
            visitor.append_ascii(")")

class Utf8BuilderVisitor(ast.ASTVisitor):
    def __init__(self, space):
        self.space = space
        self.builder = Utf8StringBuilder()

    def append_w_str(self, w_s):
        s, l = self.space.utf8_len_w(w_s)
        self.builder.append_utf8(s, l)

    def append_ascii(self, s):
        self.builder.append_utf8(s, len(s))

    def append_utf8(self, s):
        self.builder.append(s)


class UnparseVisitor(Utf8BuilderVisitor):
    def __init__(self, space, startlevel=PRIORITY_TEST):
        Utf8BuilderVisitor.__init__(self, space)
        self.level = startlevel

    def maybe_parenthesize(self, priority):
        return Parenthesizer(self, priority)

    def append_expr(self, node, priority=PRIORITY_TEST):
        level = self.level
        self.level = priority
        try:
            node.walkabout(self)
        finally:
            self.level = level

    def append_if_not_first(self, first, s):
        if not first:
            self.append_ascii(s)
        return False

    def default_visitor(self, node):
        raise OperationError(self.space.w_SystemError,
                    self.space.newtext("expression type not supported yet" + str(node)))

    def visit_Constant(self, node):
        if self.space.is_w(node.value, self.space.w_Ellipsis):
            return self.append_ascii("...")

        if (
            self.space.isinstance_w(node.value, self.space.w_bytes)
            or self.space.isinstance_w(node.value, self.space.w_unicode)
        ):
            res = self.space.repr(node.value)
        else:
            res = self.space.str(node.value)
        self.append_w_str(res)

    def visit_Name(self, node):
        self.builder.append(node.id)

    def visit_UnaryOp(self, node):
        op = node.op
        if op == ast.Invert:
            priority = PRIORITY_FACTOR
            op = "~"
        elif op == ast.Not:
            priority = PRIORITY_NOT
            op = "not "
        elif op == ast.UAdd:
            priority = PRIORITY_FACTOR
            op = "+"
        elif op == ast.USub:
            priority = PRIORITY_FACTOR
            op = "-"
        else:
            raise oefmt(self.space.w_SystemError,
                        "unknown unary operator")
        with self.maybe_parenthesize(priority):
            self.append_ascii(op)
            self.append_expr(node.operand, priority)

    def visit_BinOp(self, node):
        right_associative = False
        op = node.op
        if op == ast.Add:
            op = " + "
            priority = PRIORITY_ARITH
        elif op == ast.Sub:
            op = " - "
            priority = PRIORITY_ARITH
        elif op == ast.Mult:
            op = " * "
            priority = PRIORITY_TERM
        elif op == ast.MatMult:
            op = " @ "
            priority = PRIORITY_TERM
        elif op == ast.Div:
            op = " / "
            priority = PRIORITY_TERM
        elif op == ast.FloorDiv:
            op = " // "
            priority = PRIORITY_TERM
        elif op == ast.Mod:
            op = " % "
            priority = PRIORITY_TERM
        elif op == ast.LShift:
            op = " << "
            priority = PRIORITY_SHIFT
        elif op == ast.RShift:
            op = " >> "
            priority = PRIORITY_SHIFT
        elif op == ast.BitOr:
            op = " | "
            priority = PRIORITY_BOR
        elif op == ast.BitXor:
            op = " ^ "
            priority = PRIORITY_BXOR
        elif op == ast.BitAnd:
            op = " & "
            priority = PRIORITY_BAND
        elif op == ast.Pow:
            op = " ** "
            priority = PRIORITY_POWER
            right_associative = True
        else:
            raise oefmt(self.space.w_SystemError,
                        "unknown unary operator")
        with self.maybe_parenthesize(priority):
            self.append_expr(node.left, priority + right_associative)
            self.append_ascii(op)
            self.append_expr(node.right, priority + (not right_associative))

    def visit_BoolOp(self, node):
        if node.op == ast.And:
            op = " and "
            priority = PRIORITY_AND
        else:
            op = " or "
            priority = PRIORITY_OR
        with self.maybe_parenthesize(priority):
            for i, value in enumerate(node.values):
                if i > 0:
                    self.append_ascii(op)
                self.append_expr(value, priority + 1)

    def visit_Compare(self, node):
        with self.maybe_parenthesize(PRIORITY_CMP):
            self.append_expr(node.left, PRIORITY_CMP + 1)
            for i in range(len(node.comparators)):
                op = node.ops[i]
                value = node.comparators[i]
                if op == ast.Eq:
                    op = " == "
                elif op == ast.NotEq:
                    op = " != "
                elif op == ast.Lt:
                    op = " < "
                elif op == ast.LtE:
                    op = " <= "
                elif op == ast.Gt:
                    op = " > "
                elif op == ast.GtE:
                    op = " >= "
                elif op == ast.Is:
                    op = " is "
                elif op == ast.IsNot:
                    op = " is not "
                elif op == ast.In:
                    op = " in "
                elif op == ast.NotIn:
                    op = " not in "
                else:
                    raise oefmt(self.space.w_SystemError,
                                "unknown comparator")
                self.append_ascii(op)
                self.append_expr(value, PRIORITY_CMP + 1)


    def visit_IfExp(self, node):
        with self.maybe_parenthesize(PRIORITY_TEST):
            self.append_expr(node.body, PRIORITY_TEST + 1)
            self.append_ascii(" if ")
            self.append_expr(node.test, PRIORITY_TEST + 1)
            self.append_ascii(" else ")
            self.append_expr(node.orelse, PRIORITY_TEST)

    def visit_List(self, node):
        if node.elts is None:
            self.append_ascii("[]")
            return
        self.append_ascii("[")
        for i, elt in enumerate(node.elts):
            if i > 0:
                self.append_ascii(", ")
            self.append_expr(elt)
        self.append_ascii("]")

    def visit_Tuple(self, node):
        if node.elts is None:
            self.append_ascii("()")
            return
        with self.maybe_parenthesize(PRIORITY_TUPLE):
            for i, elt in enumerate(node.elts):
                if i > 0:
                    self.append_ascii(", ")
                self.append_expr(elt)
            if len(node.elts) == 1:
                self.append_ascii(",")

    def visit_Set(self, node):
        self.append_ascii("{")
        for i, elt in enumerate(node.elts):
            if i > 0:
                self.append_ascii(", ")
            self.append_expr(elt)
        self.append_ascii("}")

    def visit_Dict(self, node):
        if node.keys is None:
            self.append_ascii("{}")
            return
        self.append_ascii("{")
        for i, key in enumerate(node.keys):
            value = node.values[i]
            if i > 0:
                self.append_ascii(", ")
            if key is not None:
                self.append_expr(key)
                self.append_ascii(": ")
                self.append_expr(value)
            else:
                self.append_ascii("**")
                self.append_expr(value)
        self.append_ascii("}")

    def append_generators(self, generators):
        for generator in generators:
            assert isinstance(generator, ast.comprehension)
            if generator.is_async:
                self.append_ascii(' async for ')
            else:
                self.append_ascii(' for ')
            self.append_expr(generator.target, PRIORITY_TUPLE)
            self.append_ascii(' in ')
            self.append_expr(generator.iter, PRIORITY_TEST + 1)
            if generator.ifs:
                for if_ in generator.ifs:
                    self.append_ascii(' if ')
                    self.append_expr(if_, PRIORITY_TEST + 1)

    def visit_ListComp(self, node):
        self.append_ascii('[')
        self.append_expr(node.elt)
        self.append_generators(node.generators)
        self.append_ascii(']')

    def visit_GeneratorExp(self, node):
        self.append_ascii('(')
        self.append_expr(node.elt)
        self.append_generators(node.generators)
        self.append_ascii(')')

    def visit_SetComp(self, node):
        self.append_ascii('{')
        self.append_expr(node.elt)
        self.append_generators(node.generators)
        self.append_ascii('}')

    def visit_DictComp(self, node):
        self.append_ascii('{')
        self.append_expr(node.key)
        self.append_ascii(': ')
        self.append_expr(node.value)
        self.append_generators(node.generators)
        self.append_ascii('}')

    def visit_Subscript(self, node):
        self.append_expr(node.value, PRIORITY_ATOM)
        self.append_ascii('[')
        self.append_expr(node.slice, PRIORITY_TUPLE)
        self.append_ascii(']')

    def visit_Slice(self, node):
        if node.lower:
            self.append_expr(node.lower)
        self.append_ascii(':')
        if node.upper:
            self.append_expr(node.upper)
        if node.step:
            self.append_ascii(':')
            self.append_expr(node.step)

    def visit_Attribute(self, node):
        value = node.value
        self.append_expr(value, PRIORITY_ATOM)
        if isinstance(value, ast.Constant) and \
                self.space.isinstance_w(value.value, self.space.w_int):
            period = ' .'
        else:
            period = '.'
        self.append_ascii(period)
        self.append_utf8(node.attr)

    def visit_Yield(self, node):
        if node.value:
            self.append_ascii("(yield ")
            self.append_expr(node.value)
            self.append_ascii(")")
        else:
            self.append_ascii("(yield)")

    def visit_YieldFrom(self, node):
        self.append_ascii("(yield from ")
        self.append_expr(node.value)
        self.append_ascii(")")

    def visit_Call(self, node):
        self.append_expr(node.func, PRIORITY_ATOM)
        args = node.args
        if (args and len(args) == 1
                and not node.keywords
                and isinstance(args[0], ast.GeneratorExp)):
            self.append_expr(args[0])
            return

        self.append_ascii('(')
        first = True
        if args:
            for i, arg in enumerate(args):
                first = self.append_if_not_first(first, ', ')
                self.append_expr(arg)
        if node.keywords:
            for i, keyword in enumerate(node.keywords):
                first = self.append_if_not_first(first, ', ')
                assert isinstance(keyword, ast.keyword)
                if keyword.arg is None:
                    self.append_ascii('**')
                else:
                    self.append_utf8(keyword.arg)
                    self.append_ascii('=')
                self.append_expr(keyword.value)
        self.append_ascii(')')

    def visit_Starred(self, node):
        self.append_ascii('*')
        self.append_expr(node.value, PRIORITY_EXPR)

    def visit_arg(self, node):
        self.append_utf8(node.arg)
        if node.annotation:
            # is this reachable? don't think so!
            self.append_ascii(': ')
            self.append_expr(node.annotation)

    def visit_Lambda(self, node):
        with self.maybe_parenthesize(PRIORITY_TEST):
            args = node.args
            if not args.args and not args.vararg and not args.kwarg and not args.kwonlyargs:
                self.append_ascii("lambda: ")
            else:
                self.append_ascii("lambda ")
                first = True
                if args.defaults:
                    default_count = len(args.defaults)
                else:
                    default_count = 0
                if args.args:
                    for i, arg in enumerate(args.args):
                        first = self.append_if_not_first(first, ', ')
                        di = i - (len(args.args) - default_count)
                        self.append_expr(arg)
                        if di >= 0:
                            self.append_ascii('=')
                            self.append_expr(args.defaults[di])
                if args.vararg or args.kwonlyargs:
                    first = self.append_if_not_first(first, ', ')
                    self.append_ascii('*')
                    if args.vararg:
                        self.append_expr(args.vararg)
                if args.kwonlyargs:
                    for i, arg in enumerate(args.kwonlyargs):
                        first = self.append_if_not_first(first, ', ')
                        di = i - (len(args.kwonlyargs) - default_count)
                        self.append_expr(arg)
                        default = args.kw_defaults[i]
                        if default:
                            self.append_ascii('=')
                            self.append_expr(default)
                if args.kwarg:
                    first = self.append_if_not_first(first, ', ')
                    self.append_ascii('**')
                    self.append_expr(args.kwarg)
                self.append_ascii(': ')
            self.append_expr(node.body)

    def visit_JoinedStr(self, node):
        need_f = False
        subvisitor = FstringVisitor(self.space)
        for i, elt in enumerate(node.values):
            if not isinstance(elt, ast.Constant):
                need_f = True
            elt.walkabout(subvisitor)
        s = subvisitor.builder.build()
        l = subvisitor.builder.getlength()
        if need_f:
            self.append_ascii("f")
        self.append_w_str(self.space.repr(self.space.newutf8(s, l)))

    def visit_Await(self, node):
        with self.maybe_parenthesize(PRIORITY_AWAIT):
            self.append_ascii("await ")
            self.append_expr(node.value)


class FstringVisitor(Utf8BuilderVisitor):

    def default_visitor(self, node):
        raise OperationError(self.space.w_SystemError,
                self.space.newtext("expression type not supported yet:" + str(node)))

    def visit_Constant(self, node):
        from rpython.rlib import rstring
        s, l = self.space.utf8_len_w(node.value)
        s = rstring.replace(s, "{", "{{")
        s = rstring.replace(s, "}", "}}")
        self.append_utf8(s)

    def visit_FormattedValue(self, node):
        outer_brace = "{"
        s = unparse(self.space, node.value, PRIORITY_TEST + 1)
        if s.startswith("{"):
            outer_brace = "{ "
        self.append_ascii(outer_brace)
        self.append_utf8(s)
        conversion = node.conversion
        if conversion >= 0:
            if conversion == ord('a'):
                conversion = '!a'
            elif conversion == ord('r'):
                conversion = '!r'
            elif conversion == ord('s'):
                conversion = '!s'
            else:
                raise oefmt(self.space.w_SystemError,
                    "unknown f-string conversion kind %s", chr(conversion))
            self.append_ascii(conversion)

        if node.format_spec:
            self.append_ascii(":")
            node.format_spec.walkabout(self)
        self.append_ascii("}")

    def visit_JoinedStr(self, node):
        for i, elt in enumerate(node.values):
            elt.walkabout(self)


def unparse(space, ast, level=PRIORITY_TEST):
    visitor = UnparseVisitor(space, level)
    ast.walkabout(visitor)
    return visitor.builder.build()

def w_unparse(space, ast, level=PRIORITY_TEST):
    visitor = UnparseVisitor(space, level)
    ast.walkabout(visitor)
    return space.newutf8(visitor.builder.build(), visitor.builder.getlength())

class UnparseAnnotationsVisitor(ast.ASTVisitor):
    def __init__(self, space):
        self.space = space

    @specialize.argtype(1)
    def default_visitor(self, node):
        return node

    def unparse(self, node):
        return ast.Constant(
                    w_unparse(self.space, node),
                    self.space.w_None,
                    node.lineno,
                    node.col_offset,
                    node.end_lineno,
                    node.end_col_offset)

    def visit_arg(self, node):
        annotation = node.annotation
        if annotation:
            node.annotation = self.unparse(annotation)
        return node

    def visit_FunctionDef(self, node):
        returns = node.returns
        if returns:
            node.returns = self.unparse(returns)
        return node

    def visit_AsyncFunctionDef(self, node):
        returns = node.returns
        if returns:
            node.returns = self.unparse(returns)
        return node

    def visit_AnnAssign(self, node):
        node.annotation = self.unparse(node.annotation)
        return node

def unparse_annotations(space, ast):
    visitor = UnparseAnnotationsVisitor(space)
    return ast.mutate_over(visitor)


