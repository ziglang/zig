"""Rewrite assertion AST to produce nice error messages"""
from pypy.interpreter.astcompiler import ast
import itertools


def rewrite_asserts(space, source, filename):
    """Parse the source code and rewrite asserts statements

    Returns a module object.
    """
    c = space.createcompiler()
    tree = c.compile_to_ast(source, filename, "exec", 0)
    AssertionRewriter(space).run(tree)
    co = c.compile_ast(tree, filename, 'exec', 0)
    return co

def rewrite_asserts_ast(space, tree):
    AssertionRewriter(space).run(tree)
    return tree


unary_map = {
    ast.Not: "not %s",
    ast.Invert: "~%s",
    ast.USub: "-%s",
    ast.UAdd: "+%s"
}

binop_map = {
    ast.BitOr: "|",
    ast.BitXor: "^",
    ast.BitAnd: "&",
    ast.LShift: "<<",
    ast.RShift: ">>",
    ast.Add: "+",
    ast.Sub: "-",
    ast.Mult: "*",
    ast.Div: "/",
    ast.FloorDiv: "//",
    ast.Mod: "%%",  # escaped for string formatting
    ast.Eq: "==",
    ast.NotEq: "!=",
    ast.Lt: "<",
    ast.LtE: "<=",
    ast.Gt: ">",
    ast.GtE: ">=",
    ast.Pow: "**",
    ast.Is: "is",
    ast.IsNot: "is not",
    ast.In: "in",
    ast.NotIn: "not in",
    ast.MatMult: "@",
}


def set_location(node, lineno, col_offset):
    """Set node location information recursively."""
    def _fix(node, lineno, col_offset):
        if hasattr(node, "lineno"):
            node.lineno = lineno
        if hasattr(node, "col_offset"):
            node.col_offset = col_offset
        for field, value in iter_fields(node):
            if isinstance(value, list):
                for child in value:
                    _fix(child, lineno, col_offset)
    _fix(node, lineno, col_offset)
    return node

FIELDS = {name: (fields1 or []) + (fields2 or [])
        for (name, base, fields1, fields2, _, _) in ast.State.AST_TYPES}

def iter_fields(node):
    fields = FIELDS[type(node).__name__]
    for name in fields:
        yield name, getattr(node, name)

def b(cls, *args):
    return cls(*args + (-1, -1, -1, -1))

class AssertionRewriter(ast.ASTVisitor):
    """Assertion rewriting implementation.

    The main entrypoint is to call .run() with an ast.Module instance,
    this will then find all the assert statements and rewrite them to
    provide intermediate values and a detailed assertion error.  See
    http://pybites.blogspot.be/2011/07/behind-scenes-of-pytests-new-assertion.html
    for an overview of how this works.

    The entry point here is .run() which will iterate over all the
    statements in an ast.Module and for each ast.Assert statement it
    finds call .visit() with it.  Then .visit_Assert() takes over and
    is responsible for creating new ast statements to replace the
    original assert statement: it rewrites the test of an assertion
    to provide intermediate values and replace it with an if statement
    which raises an assertion error with a detailed explanation in
    case the expression is false.

    For this .visit_Assert() uses the visitor pattern to visit all the
    AST nodes of the ast.Assert.test field, each visit call returning
    an AST node and the corresponding explanation string.  During this
    state is kept in several instance attributes:

    :statements: All the AST statements which will replace the assert
       statement.

    :variables: This is populated by .variable() with each variable
       used by the statements so that they can all be set to None at
       the end of the statements.

    :variable_counter: Counter to create new unique variables needed
       by statements.  Variables are created using .variable() and
       have the form of "@py_assert0".

    :on_failure: The AST statements which will be executed if the
       assertion test fails.  This is the code which will construct
       the failure message and raises the AssertionError.

    :explanation_specifiers: A dict filled by .explanation_param()
       with %-formatting placeholders and their corresponding
       expressions to use in the building of an assertion message.
       This is used by .pop_format_context() to build a message.

    :stack: A stack of the explanation_specifiers dicts maintained by
       .push_format_context() and .pop_format_context() which allows
       to build another %-formatted string while already building one.

    This state is reset on every new assert statement visited and used
    by the other visitors.

    """

    def __init__(self, space):
        self.space = space

    def visit(self, node):
        return getattr(self, "visit_" + type(node).__name__, self.default_visitor)(node)

    def Str(self, s):
        return b(ast.Constant, self.space.newtext(s), None)

    def Num(self, i):
        return b(ast.Constant, self.space.newint(i), None)

    def run(self, mod):
        """Find all assert statements in *mod* and rewrite them."""
        if not mod.body:
            # Nothing to do.
            return
        # Insert some special imports at the top of the module but after any
        # docstrings and __future__ imports.
        builtin_name = 'builtins'
        aliases = [ast.alias(builtin_name, "@py_builtins"),
                   ast.alias("pytest", "@pytest")]
        doc = getattr(mod, "docstring", None)
        expect_docstring = doc is None
        if doc is not None and self.is_rewrite_disabled(doc):
            return
        pos = 0
        lineno = 1
        for item in mod.body:
            if (expect_docstring and isinstance(item, ast.Expr) and
                    isinstance(item.value, ast.Constant) and
                    self.space.isinstance_w(item.value.value, self.space.w_unicode)):
                doc = item.value.value
                if self.is_rewrite_disabled(doc):
                    return
                expect_docstring = False
            elif (not isinstance(item, ast.ImportFrom) or item.level > 0 or
                  item.module != "__future__"):
                lineno = item.lineno
                break
            pos += 1
        else:
            lineno = item.lineno
        imports = [ast.Import([alias], lineno=lineno, col_offset=0, end_lineno=lineno, end_col_offset=0)
                   for alias in aliases]
        mod.body[pos:pos] = imports
        # Collect asserts.
        nodes = [mod]
        while nodes:
            node = nodes.pop()
            for name, field in iter_fields(node):
                if isinstance(field, list):
                    new = []
                    for i, child in enumerate(field):
                        if isinstance(child, ast.Assert):
                            # Transform assert.
                            new.extend(self.visit(child))
                        else:
                            new.append(child)
                            if isinstance(child, ast.AST):
                                nodes.append(child)
                    setattr(node, name, new)
                elif (isinstance(field, ast.AST) and
                      # Don't recurse into expressions as they can't contain
                      # asserts.
                      not isinstance(field, ast.expr)):
                    nodes.append(field)

    def is_rewrite_disabled(self, docstring):
        return "PYTEST_DONT_REWRITE" in self.space.text_w(docstring)

    def variable(self):
        """Get a new variable."""
        # Use a character invalid in python identifiers to avoid clashing.
        name = "@py_assert" + str(next(self.variable_counter))
        self.variables.append(name)
        return name

    def assign(self, expr):
        """Give *expr* a name."""
        name = self.variable()
        self.statements.append(b(ast.Assign, [b(ast.Name, name, ast.Store)], expr, None))
        return b(ast.Name, name, ast.Load)

    def display(self, expr):
        """Call py.io.saferepr on the expression."""
        return self.helper("saferepr", expr)

    def helper(self, name, *args):
        """Call a helper in this module."""
        py_name = b(ast.Name, "@pytest", ast.Load)
        attr = b(ast.Attribute, py_name, "ar_" + name, ast.Load)
        return b(ast.Call, attr, list(args), [])

    def builtin(self, name):
        """Return the builtin called *name*."""
        builtin_name = b(ast.Name, "@py_builtins", ast.Load)
        return b(ast.Attribute, builtin_name, name, ast.Load)

    def explanation_param(self, expr):
        """Return a new named %-formatting placeholder for expr.

        This creates a %-formatting placeholder for expr in the
        current formatting context, e.g. ``%(py0)s``.  The placeholder
        and expr are placed in the current format context so that it
        can be used on the next call to .pop_format_context().

        """
        specifier = "py" + str(next(self.variable_counter))
        self.explanation_specifiers[specifier] = expr
        return "%(" + specifier + ")s"

    def push_format_context(self):
        """Create a new formatting context.

        The format context is used for when an explanation wants to
        have a variable value formatted in the assertion message.  In
        this case the value required can be added using
        .explanation_param().  Finally .pop_format_context() is used
        to format a string of %-formatted values as added by
        .explanation_param().

        """
        self.explanation_specifiers = {}
        self.stack.append(self.explanation_specifiers)

    def pop_format_context(self, expl_expr):
        """Format the %-formatted string with current format context.

        The expl_expr should be an ast.Str instance constructed from
        the %-placeholders created by .explanation_param().  This will
        add the required code to format said string to .on_failure and
        return the ast.Name instance of the formatted string.

        """
        current = self.stack.pop()
        if self.stack:
            self.explanation_specifiers = self.stack[-1]
        keys = [self.Str(key) for key in current.keys()]
        format_dict = b(ast.Dict, keys, list(current.values()))
        form = b(ast.BinOp, expl_expr, ast.Mod, format_dict)
        name = "@py_format" + str(next(self.variable_counter))
        self.on_failure.append(b(ast.Assign, [b(ast.Name, name, ast.Store)], form, None))
        return b(ast.Name, name, ast.Load)

    def default_visitor(self, node):
        """Handle expressions we don't have custom code for."""
        assert isinstance(node, ast.expr)
        res = self.assign(node)
        return res, self.explanation_param(self.display(res))

    def visit_Assert(self, assert_):
        """Return the AST statements to replace the ast.Assert instance.

        This rewrites the test of an assertion to provide
        intermediate values and replace it with an if statement which
        raises an assertion error with a detailed explanation in case
        the expression is false.

        """
        self.statements = []
        self.variables = []
        self.variable_counter = itertools.count()
        self.stack = []
        self.on_failure = []
        self.push_format_context()
        # Rewrite assert into a bunch of statements.
        top_condition, explanation = self.visit(assert_.test)
        # Create failure message.
        body = self.on_failure
        negation = b(ast.UnaryOp, ast.Not, top_condition)
        self.statements.append(b(ast.If, negation, body, []))
        if assert_.msg:
            assertmsg = self.helper('format_assertmsg', assert_.msg)
            explanation = "\n>assert " + explanation
        else:
            assertmsg = self.Str("")
            explanation = "assert " + explanation
        template = b(ast.BinOp, assertmsg, ast.Add, self.Str(explanation))
        msg = self.pop_format_context(template)
        fmt = self.helper("format_explanation", msg)
        err_name = b(ast.Name, "AssertionError", ast.Load)
        exc = b(ast.Call, err_name, [fmt], [])
        raise_ = b(ast.Raise, exc, None)
        body.append(raise_)
        # Clear temporary variables by setting them to None.
        if self.variables:
            variables = [b(ast.Name, name, ast.Store)
                         for name in self.variables]
            clear = b(ast.Assign, variables, b(ast.Constant, self.space.w_None, None), None)
            self.statements.append(clear)
        # Fix line numbers.
        for stmt in self.statements:
            set_location(stmt, assert_.lineno, assert_.col_offset)
        return self.statements

    def visit_Name(self, name):
        # Display the repr of the name if it's a local variable or
        # _should_repr_global_name() thinks it's acceptable.
        locs = b(ast.Call, self.builtin("locals"), [], [])
        inlocs = b(ast.Compare, self.Str(name.id), [ast.In], [locs])
        dorepr = self.helper("should_repr_global_name", name)
        test = b(ast.BoolOp, ast.Or, [inlocs, dorepr])
        expr = b(ast.IfExp, test, self.display(name), self.Str(name.id))
        return name, self.explanation_param(expr)

    def visit_BoolOp(self, boolop):
        res_var = self.variable()
        expl_list = self.assign(b(ast.List, [], ast.Load))
        app = b(ast.Attribute, expl_list, "append", ast.Load)
        is_or = boolop.op == ast.Or
        body = save = self.statements
        fail_save = self.on_failure
        levels = len(boolop.values) - 1
        self.push_format_context()
        # Process each operand, short-circuting if needed.
        for i, v in enumerate(boolop.values):
            if i:
                fail_inner = []
                # cond is set in a prior loop iteration below
                self.on_failure.append(b(ast.If, cond, fail_inner, []))  # noqa
                self.on_failure = fail_inner
            self.push_format_context()
            res, expl = self.visit(v)
            body.append(b(ast.Assign, [b(ast.Name, res_var, ast.Store)], res, None))
            expl_format = self.pop_format_context(self.Str(expl))
            call = b(ast.Call, app, [expl_format], [])
            self.on_failure.append(b(ast.Expr, call))
            if i < levels:
                cond = res
                if is_or:
                    cond = b(ast.UnaryOp, ast.Not, cond)
                inner = []
                self.statements.append(b(ast.If, cond, inner, []))
                self.statements = body = inner
        self.statements = save
        self.on_failure = fail_save
        expl_template = self.helper("format_boolop", expl_list, self.Num(is_or))
        expl = self.pop_format_context(expl_template)
        return b(ast.Name, res_var, ast.Load), self.explanation_param(expl)

    def visit_UnaryOp(self, unary):
        pattern = unary_map[unary.op]
        operand_res, operand_expl = self.visit(unary.operand)
        res = self.assign(b(ast.UnaryOp, unary.op, operand_res))
        return res, pattern % (operand_expl,)

    def visit_BinOp(self, binop):
        symbol = binop_map[binop.op]
        left_expr, left_expl = self.visit(binop.left)
        right_expr, right_expl = self.visit(binop.right)
        explanation = "(%s %s %s)" % (left_expl, symbol, right_expl)
        res = self.assign(b(ast.BinOp, left_expr, binop.op, right_expr))
        return res, explanation

    def visit_Call(self, call):
        """
        visit `ast.Call` nodes on Python3.5 and after
        """
        new_func, func_expl = self.visit(call.func)
        arg_expls = []
        new_args = []
        new_kwargs = []
        for arg in call.args or []:
            res, expl = self.visit(arg)
            arg_expls.append(expl)
            new_args.append(res)
        for keyword in call.keywords or []:
            res, expl = self.visit(keyword.value)
            new_kwargs.append(b(ast.keyword, keyword.arg, res))
            if keyword.arg:
                arg_expls.append(keyword.arg + "=" + expl)
            else:  # **args have `arg` keywords with an .arg of None
                arg_expls.append("**" + expl)

        expl = "%s(%s)" % (func_expl, ', '.join(arg_expls))
        new_call = b(ast.Call, new_func, new_args, new_kwargs)
        res = self.assign(new_call)
        res_expl = self.explanation_param(self.display(res))
        outer_expl = "%s\n{%s = %s\n}" % (res_expl, res_expl, expl)
        return res, outer_expl

    def visit_Starred(self, starred):
        # From Python 3.5, a Starred node can appear in a function call
        res, expl = self.visit(starred.value)
        return starred, '*' + expl

    def visit_Attribute(self, attr):
        if attr.ctx != ast.Load:
            return self.default_visitor(attr)
        value, value_expl = self.visit(attr.value)
        res = self.assign(b(ast.Attribute, value, attr.attr, ast.Load))
        res_expl = self.explanation_param(self.display(res))
        pat = "%s\n{%s = %s.%s\n}"
        expl = pat % (res_expl, res_expl, value_expl, attr.attr)
        return res, expl

    def visit_Compare(self, comp):
        self.push_format_context()
        left_res, left_expl = self.visit(comp.left)
        if isinstance(comp.left, (ast.Compare, ast.BoolOp)):
            left_expl = "({0})".format(left_expl)
        res_variables = [self.variable() for i in range(len(comp.ops))]
        load_names = [b(ast.Name, v, ast.Load) for v in res_variables]
        store_names = [b(ast.Name, v, ast.Store) for v in res_variables]
        it = zip(range(len(comp.ops)), comp.ops, comp.comparators)
        expls = []
        syms = []
        results = [left_res]
        for i, op, next_operand in it:
            next_res, next_expl = self.visit(next_operand)
            if isinstance(next_operand, (ast.Compare, ast.BoolOp)):
                next_expl = "({0})".format(next_expl)
            results.append(next_res)
            sym = binop_map[op]
            syms.append(self.Str(sym))
            expl = "%s %s %s" % (left_expl, sym, next_expl)
            expls.append(self.Str(expl))
            res_expr = b(ast.Compare, left_res, [op], [next_res])
            self.statements.append(b(ast.Assign, [store_names[i]], res_expr, None))
            left_res, left_expl = next_res, next_expl
        # Use pytest.assertion.util._reprcompare if that's available.
        expl_call = self.helper("call_reprcompare",
                                b(ast.Tuple, syms, ast.Load),
                                b(ast.Tuple, load_names, ast.Load),
                                b(ast.Tuple, expls, ast.Load),
                                b(ast.Tuple, results, ast.Load))
        if len(comp.ops) > 1:
            res = b(ast.BoolOp, ast.And, load_names)
        else:
            res = load_names[0]
        return res, self.explanation_param(self.pop_format_context(expl_call))
