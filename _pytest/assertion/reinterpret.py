"""
Find intermediate evalutation results in assert statements through builtin AST.
"""
import ast
import sys

import _pytest._code
import py
from _pytest.assertion import util
u = py.builtin._totext


class AssertionError(util.BuiltinAssertionError):
    def __init__(self, *args):
        util.BuiltinAssertionError.__init__(self, *args)
        if args:
            # on Python2.6 we get len(args)==2 for: assert 0, (x,y)
            # on Python2.7 and above we always get len(args) == 1
            # with args[0] being the (x,y) tuple.
            if len(args) > 1:
                toprint = args
            else:
                toprint = args[0]
            try:
                self.msg = u(toprint)
            except Exception:
                self.msg = u(
                    "<[broken __repr__] %s at %0xd>"
                    % (toprint.__class__, id(toprint)))
        else:
            f = _pytest._code.Frame(sys._getframe(1))
            try:
                source = f.code.fullsource
                if source is not None:
                    try:
                        source = source.getstatement(f.lineno, assertion=True)
                    except IndexError:
                        source = None
                    else:
                        source = str(source.deindent()).strip()
            except py.error.ENOENT:
                source = None
                # this can also occur during reinterpretation, when the
                # co_filename is set to "<run>".
            if source:
                self.msg = reinterpret(source, f, should_fail=True)
            else:
                self.msg = "<could not determine information>"
            if not self.args:
                self.args = (self.msg,)

if sys.version_info > (3, 0):
    AssertionError.__module__ = "builtins"

if sys.platform.startswith("java"):
    # See http://bugs.jython.org/issue1497
    _exprs = ("BoolOp", "BinOp", "UnaryOp", "Lambda", "IfExp", "Dict",
              "ListComp", "GeneratorExp", "Yield", "Compare", "Call",
              "Repr", "Num", "Str", "Attribute", "Subscript", "Name",
              "List", "Tuple")
    _stmts = ("FunctionDef", "ClassDef", "Return", "Delete", "Assign",
              "AugAssign", "Print", "For", "While", "If", "With", "Raise",
              "TryExcept", "TryFinally", "Assert", "Import", "ImportFrom",
              "Exec", "Global", "Expr", "Pass", "Break", "Continue")
    _expr_nodes = set(getattr(ast, name) for name in _exprs)
    _stmt_nodes = set(getattr(ast, name) for name in _stmts)
    def _is_ast_expr(node):
        return node.__class__ in _expr_nodes
    def _is_ast_stmt(node):
        return node.__class__ in _stmt_nodes
else:
    def _is_ast_expr(node):
        return isinstance(node, ast.expr)
    def _is_ast_stmt(node):
        return isinstance(node, ast.stmt)

try:
    _Starred = ast.Starred
except AttributeError:
    # Python 2. Define a dummy class so isinstance() will always be False.
    class _Starred(object): pass


class Failure(Exception):
    """Error found while interpreting AST."""

    def __init__(self, explanation=""):
        self.cause = sys.exc_info()
        self.explanation = explanation


def reinterpret(source, frame, should_fail=False):
    mod = ast.parse(source)
    visitor = DebugInterpreter(frame)
    try:
        visitor.visit(mod)
    except Failure:
        failure = sys.exc_info()[1]
        return getfailure(failure)
    if should_fail:
        return ("(assertion failed, but when it was re-run for "
                "printing intermediate values, it did not fail.  Suggestions: "
                "compute assert expression before the assert or use --assert=plain)")

def run(offending_line, frame=None):
    if frame is None:
        frame = _pytest._code.Frame(sys._getframe(1))
    return reinterpret(offending_line, frame)

def getfailure(e):
    explanation = util.format_explanation(e.explanation)
    value = e.cause[1]
    if str(value):
        lines = explanation.split('\n')
        lines[0] += "  << %s" % (value,)
        explanation = '\n'.join(lines)
    text = "%s: %s" % (e.cause[0].__name__, explanation)
    if text.startswith('AssertionError: assert '):
        text = text[16:]
    return text

operator_map = {
    ast.BitOr : "|",
    ast.BitXor : "^",
    ast.BitAnd : "&",
    ast.LShift : "<<",
    ast.RShift : ">>",
    ast.Add : "+",
    ast.Sub : "-",
    ast.Mult : "*",
    ast.Div : "/",
    ast.FloorDiv : "//",
    ast.Mod : "%",
    ast.Eq : "==",
    ast.NotEq : "!=",
    ast.Lt : "<",
    ast.LtE : "<=",
    ast.Gt : ">",
    ast.GtE : ">=",
    ast.Pow : "**",
    ast.Is : "is",
    ast.IsNot : "is not",
    ast.In : "in",
    ast.NotIn : "not in"
}

unary_map = {
    ast.Not : "not %s",
    ast.Invert : "~%s",
    ast.USub : "-%s",
    ast.UAdd : "+%s"
}


class DebugInterpreter(ast.NodeVisitor):
    """Interpret AST nodes to gleam useful debugging information. """

    def __init__(self, frame):
        self.frame = frame

    def generic_visit(self, node):
        # Fallback when we don't have a special implementation.
        if _is_ast_expr(node):
            mod = ast.Expression(node)
            co = self._compile(mod)
            try:
                result = self.frame.eval(co)
            except Exception:
                raise Failure()
            explanation = self.frame.repr(result)
            return explanation, result
        elif _is_ast_stmt(node):
            mod = ast.Module([node])
            co = self._compile(mod, "exec")
            try:
                self.frame.exec_(co)
            except Exception:
                raise Failure()
            return None, None
        else:
            raise AssertionError("can't handle %s" %(node,))

    def _compile(self, source, mode="eval"):
        return compile(source, "<assertion interpretation>", mode)

    def visit_Expr(self, expr):
        return self.visit(expr.value)

    def visit_Module(self, mod):
        for stmt in mod.body:
            self.visit(stmt)

    def visit_Name(self, name):
        explanation, result = self.generic_visit(name)
        # See if the name is local.
        source = "%r in locals() is not globals()" % (name.id,)
        co = self._compile(source)
        try:
            local = self.frame.eval(co)
        except Exception:
            # have to assume it isn't
            local = None
        if local is None or not self.frame.is_true(local):
            return name.id, result
        return explanation, result

    def visit_Compare(self, comp):
        left = comp.left
        left_explanation, left_result = self.visit(left)
        for op, next_op in zip(comp.ops, comp.comparators):
            next_explanation, next_result = self.visit(next_op)
            op_symbol = operator_map[op.__class__]
            explanation = "%s %s %s" % (left_explanation, op_symbol,
                                        next_explanation)
            source = "__exprinfo_left %s __exprinfo_right" % (op_symbol,)
            co = self._compile(source)
            try:
                result = self.frame.eval(co, __exprinfo_left=left_result,
                                         __exprinfo_right=next_result)
            except Exception:
                raise Failure(explanation)
            try:
                if not self.frame.is_true(result):
                    break
            except KeyboardInterrupt:
                raise
            except:
                break
            left_explanation, left_result = next_explanation, next_result

        if util._reprcompare is not None:
            res = util._reprcompare(op_symbol, left_result, next_result)
            if res:
                explanation = res
        return explanation, result

    def visit_BoolOp(self, boolop):
        is_or = isinstance(boolop.op, ast.Or)
        explanations = []
        for operand in boolop.values:
            explanation, result = self.visit(operand)
            explanations.append(explanation)
            if result == is_or:
                break
        name = is_or and " or " or " and "
        explanation = "(" + name.join(explanations) + ")"
        return explanation, result

    def visit_UnaryOp(self, unary):
        pattern = unary_map[unary.op.__class__]
        operand_explanation, operand_result = self.visit(unary.operand)
        explanation = pattern % (operand_explanation,)
        co = self._compile(pattern % ("__exprinfo_expr",))
        try:
            result = self.frame.eval(co, __exprinfo_expr=operand_result)
        except Exception:
            raise Failure(explanation)
        return explanation, result

    def visit_BinOp(self, binop):
        left_explanation, left_result = self.visit(binop.left)
        right_explanation, right_result = self.visit(binop.right)
        symbol = operator_map[binop.op.__class__]
        explanation = "(%s %s %s)" % (left_explanation, symbol,
                                      right_explanation)
        source = "__exprinfo_left %s __exprinfo_right" % (symbol,)
        co = self._compile(source)
        try:
            result = self.frame.eval(co, __exprinfo_left=left_result,
                                     __exprinfo_right=right_result)
        except Exception:
            raise Failure(explanation)
        return explanation, result

    def visit_Call(self, call):
        func_explanation, func = self.visit(call.func)
        arg_explanations = []
        ns = {"__exprinfo_func" : func}
        arguments = []
        for arg in call.args:
            arg_explanation, arg_result = self.visit(arg)
            if isinstance(arg, _Starred):
                arg_name = "__exprinfo_star"
                ns[arg_name] = arg_result
                arguments.append("*%s" % (arg_name,))
                arg_explanations.append("*%s" % (arg_explanation,))
            else:
                arg_name = "__exprinfo_%s" % (len(ns),)
                ns[arg_name] = arg_result
                arguments.append(arg_name)
                arg_explanations.append(arg_explanation)
        for keyword in call.keywords:
            arg_explanation, arg_result = self.visit(keyword.value)
            if keyword.arg:
                arg_name = "__exprinfo_%s" % (len(ns),)
                keyword_source = "%s=%%s" % (keyword.arg)
                arguments.append(keyword_source % (arg_name,))
                arg_explanations.append(keyword_source % (arg_explanation,))
            else:
                arg_name = "__exprinfo_kwds"
                arguments.append("**%s" % (arg_name,))
                arg_explanations.append("**%s" % (arg_explanation,))

            ns[arg_name] = arg_result

        if getattr(call, 'starargs', None):
            arg_explanation, arg_result = self.visit(call.starargs)
            arg_name = "__exprinfo_star"
            ns[arg_name] = arg_result
            arguments.append("*%s" % (arg_name,))
            arg_explanations.append("*%s" % (arg_explanation,))

        if getattr(call, 'kwargs', None):
            arg_explanation, arg_result = self.visit(call.kwargs)
            arg_name = "__exprinfo_kwds"
            ns[arg_name] = arg_result
            arguments.append("**%s" % (arg_name,))
            arg_explanations.append("**%s" % (arg_explanation,))
        args_explained = ", ".join(arg_explanations)
        explanation = "%s(%s)" % (func_explanation, args_explained)
        args = ", ".join(arguments)
        source = "__exprinfo_func(%s)" % (args,)
        co = self._compile(source)
        try:
            result = self.frame.eval(co, **ns)
        except Exception:
            raise Failure(explanation)
        pattern = "%s\n{%s = %s\n}"
        rep = self.frame.repr(result)
        explanation = pattern % (rep, rep, explanation)
        return explanation, result

    def _is_builtin_name(self, name):
        pattern = "%r not in globals() and %r not in locals()"
        source = pattern % (name.id, name.id)
        co = self._compile(source)
        try:
            return self.frame.eval(co)
        except Exception:
            return False

    def visit_Attribute(self, attr):
        if not isinstance(attr.ctx, ast.Load):
            return self.generic_visit(attr)
        source_explanation, source_result = self.visit(attr.value)
        explanation = "%s.%s" % (source_explanation, attr.attr)
        source = "__exprinfo_expr.%s" % (attr.attr,)
        co = self._compile(source)
        try:
            try:
                result = self.frame.eval(co, __exprinfo_expr=source_result)
            except AttributeError:
                # Maybe the attribute name needs to be mangled?
                if not attr.attr.startswith("__") or attr.attr.endswith("__"):
                    raise
                source = "getattr(__exprinfo_expr.__class__, '__name__', '')"
                co = self._compile(source)
                class_name = self.frame.eval(co, __exprinfo_expr=source_result)
                mangled_attr = "_" + class_name +  attr.attr
                source = "__exprinfo_expr.%s" % (mangled_attr,)
                co = self._compile(source)
                result = self.frame.eval(co, __exprinfo_expr=source_result)
        except Exception:
            raise Failure(explanation)
        explanation = "%s\n{%s = %s.%s\n}" % (self.frame.repr(result),
                                              self.frame.repr(result),
                                              source_explanation, attr.attr)
        # Check if the attr is from an instance.
        source = "%r in getattr(__exprinfo_expr, '__dict__', {})"
        source = source % (attr.attr,)
        co = self._compile(source)
        try:
            from_instance = self.frame.eval(co, __exprinfo_expr=source_result)
        except Exception:
            from_instance = None
        if from_instance is None or self.frame.is_true(from_instance):
            rep = self.frame.repr(result)
            pattern = "%s\n{%s = %s\n}"
            explanation = pattern % (rep, rep, explanation)
        return explanation, result

    def visit_Assert(self, assrt):
        test_explanation, test_result = self.visit(assrt.test)
        explanation = "assert %s" % (test_explanation,)
        if not self.frame.is_true(test_result):
            try:
                raise util.BuiltinAssertionError
            except Exception:
                raise Failure(explanation)
        return explanation, test_result

    def visit_Assign(self, assign):
        value_explanation, value_result = self.visit(assign.value)
        explanation = "... = %s" % (value_explanation,)
        name = ast.Name("__exprinfo_expr", ast.Load(),
                        lineno=assign.value.lineno,
                        col_offset=assign.value.col_offset)
        new_assign = ast.Assign(assign.targets, name, lineno=assign.lineno,
                                col_offset=assign.col_offset)
        mod = ast.Module([new_assign])
        co = self._compile(mod, "exec")
        try:
            self.frame.exec_(co, __exprinfo_expr=value_result)
        except Exception:
            raise Failure(explanation)
        return explanation, value_result

