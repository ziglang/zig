"""
Generate Python bytecode from a Abstract Syntax Tree.
"""

# NOTE TO READERS: All the ugly and "obvious" isinstance assertions here are to
# help the annotator.  To it, unfortunately, everything is not so obvious.  If
# you figure out a way to remove them, great, but try a translation first,
# please.
import struct

from rpython.rlib.objectmodel import specialize
from pypy.interpreter.astcompiler import ast, assemble, symtable, consts, misc
from pypy.interpreter.astcompiler import optimize # For side effects
from pypy.interpreter.pyparser.error import SyntaxError
from pypy.tool import stdlib_opcode as ops

C_INT_MAX = (2 ** (struct.calcsize('i') * 8)) / 2 - 1

def compile_ast(space, module, info):
    """Generate a code object from AST."""
    symbols = symtable.SymtableBuilder(space, module, info)
    return TopLevelCodeGenerator(space, module, symbols, info).assemble()

MAX_STACKDEPTH_CONTAINERS = 100

name_ops_default = misc.dict_to_switch({
    ast.Load: ops.LOAD_NAME,
    ast.Store: ops.STORE_NAME,
    ast.Del: ops.DELETE_NAME
})

name_ops_fast = misc.dict_to_switch({
    ast.Load: ops.LOAD_FAST,
    ast.Store: ops.STORE_FAST,
    ast.Del: ops.DELETE_FAST
})

name_ops_deref = misc.dict_to_switch({
    ast.Load: ops.LOAD_DEREF,
    ast.Store: ops.STORE_DEREF,
    ast.Del: ops.DELETE_DEREF,
})

name_ops_global = misc.dict_to_switch({
    ast.Load: ops.LOAD_GLOBAL,
    ast.Store: ops.STORE_GLOBAL,
    ast.Del: ops.DELETE_GLOBAL
})


unary_operations = misc.dict_to_switch({
    ast.Invert: ops.UNARY_INVERT,
    ast.Not: ops.UNARY_NOT,
    ast.UAdd: ops.UNARY_POSITIVE,
    ast.USub: ops.UNARY_NEGATIVE
})

binary_operations = misc.dict_to_switch({
    ast.Add: ops.BINARY_ADD,
    ast.Sub: ops.BINARY_SUBTRACT,
    ast.Mult: ops.BINARY_MULTIPLY,
    ast.Div: ops.BINARY_TRUE_DIVIDE,
    ast.Mod: ops.BINARY_MODULO,
    ast.Pow: ops.BINARY_POWER,
    ast.LShift: ops.BINARY_LSHIFT,
    ast.RShift: ops.BINARY_RSHIFT,
    ast.BitOr: ops.BINARY_OR,
    ast.BitAnd: ops.BINARY_AND,
    ast.BitXor: ops.BINARY_XOR,
    ast.FloorDiv: ops.BINARY_FLOOR_DIVIDE,
    ast.MatMult: ops.BINARY_MATRIX_MULTIPLY
})

inplace_operations = misc.dict_to_switch({
    ast.Add: ops.INPLACE_ADD,
    ast.Sub: ops.INPLACE_SUBTRACT,
    ast.Mult: ops.INPLACE_MULTIPLY,
    ast.Div: ops.INPLACE_TRUE_DIVIDE,
    ast.Mod: ops.INPLACE_MODULO,
    ast.Pow: ops.INPLACE_POWER,
    ast.LShift: ops.INPLACE_LSHIFT,
    ast.RShift: ops.INPLACE_RSHIFT,
    ast.BitOr: ops.INPLACE_OR,
    ast.BitAnd: ops.INPLACE_AND,
    ast.BitXor: ops.INPLACE_XOR,
    ast.FloorDiv: ops.INPLACE_FLOOR_DIVIDE,
    ast.MatMult: ops.INPLACE_MATRIX_MULTIPLY
})

compare_operations = misc.dict_to_switch({
    ast.Eq: (ops.COMPARE_OP, 2),
    ast.NotEq: (ops.COMPARE_OP, 3),
    ast.Lt: (ops.COMPARE_OP, 0),
    ast.LtE: (ops.COMPARE_OP, 1),
    ast.Gt: (ops.COMPARE_OP, 4),
    ast.GtE: (ops.COMPARE_OP, 5),
    ast.In: (ops.CONTAINS_OP, 0),
    ast.NotIn: (ops.CONTAINS_OP, 1),
    ast.Is: (ops.IS_OP, 0),
    ast.IsNot: (ops.IS_OP, 1)
})


class __extend__(ast.AST):
    _literal_type = False

class __extend__(
        ast.Constant,
        ast.Tuple,
        ast.List,
        ast.ListComp,
        ast.Dict,
        ast.DictComp,
        ast.Set,
        ast.SetComp,
        ast.GeneratorExp,
        ast.JoinedStr,
        ast.FormattedValue
    ):
    _literal_type = True

class __extend__(ast.GeneratorExp):

    def build_container_and_load_iter(self, codegen):
        codegen.comprehension_load_iter()

    def get_generators(self):
        return self.generators

    def accept_comp_iteration(self, codegen, index):
        self.elt.walkabout(codegen)
        codegen.emit_op(ops.YIELD_VALUE)
        codegen.emit_op(ops.POP_TOP)


class __extend__(ast.ListComp):

    def build_container_and_load_iter(self, codegen):
        single = False
        if len(self.generators) == 1:
            gen, = self.generators
            assert isinstance(gen, ast.comprehension)
            if not gen.ifs:
                single = True
        if single:
            codegen.comprehension_load_iter()
            codegen.emit_op(ops.BUILD_LIST_FROM_ARG)
        else:
            codegen.emit_op_arg(ops.BUILD_LIST, 0)
            codegen.comprehension_load_iter()

    def get_generators(self):
        return self.generators

    def accept_comp_iteration(self, codegen, index):
        self.elt.walkabout(codegen)
        codegen.emit_op_arg(ops.LIST_APPEND, index + 1)


class __extend__(ast.SetComp):

    def build_container_and_load_iter(self, codegen):
        codegen.emit_op_arg(ops.BUILD_SET, 0)
        codegen.comprehension_load_iter()

    def get_generators(self):
        return self.generators

    def accept_comp_iteration(self, codegen, index):
        self.elt.walkabout(codegen)
        codegen.emit_op_arg(ops.SET_ADD, index + 1)


class __extend__(ast.DictComp):

    def build_container_and_load_iter(self, codegen):
        codegen.emit_op_arg(ops.BUILD_MAP, 0)
        codegen.comprehension_load_iter()

    def get_generators(self):
        return self.generators

    def accept_comp_iteration(self, codegen, index):
        self.key.walkabout(codegen)
        self.value.walkabout(codegen)
        codegen.emit_op_arg(ops.MAP_ADD, index + 1)


# These are frame blocks.
fblock_kind_to_str = []
for i, name in enumerate("F_WHILE_LOOP F_FOR_LOOP F_TRY_EXCEPT F_FINALLY_TRY F_FINALLY_END F_WITH F_ASYNC_WITH F_HANDLER_CLEANUP F_POP_VALUE F_EXCEPTION_HANDLER".split()):
    globals()[name] = i
    fblock_kind_to_str.append(name)
del name, i


class FrameBlockInfo(object):
    def __init__(self, kind, block, end, datum):
        self.kind = kind
        self.block = block
        self.end = end
        self.datum = datum # an ast node needed for specific kinds of blocks

    def __repr__(self):
        # for debugging
        return "<FrameBlockInfo kind=%s block=%s end=%s>" % (fblock_kind_to_str[self.kind], self.block, self.end)

def update_pos_expr(func):
    def updater(self, expr):
        assert isinstance(expr, ast.expr)
        if expr.lineno > 1:
            new_lineno = expr.lineno
        else:
            new_lineno = self.lineno
        old_lineno = self.lineno
        self.lineno = new_lineno
        try:
            return func(self, expr)
        finally:
            self.lineno = old_lineno
    updater.func_name = func.func_name + "_pos_updater"
    return updater


class PythonCodeGenerator(assemble.PythonCodeMaker):
    """Base code generator.

    A subclass of this is created for every scope to be compiled.  It walks
    across the AST tree generating bytecode as needed.
    """

    def __init__(self, space, name, tree, lineno, symbols, compile_info,
                 qualname):
        self.scope = symbols.find_scope(tree)
        assemble.PythonCodeMaker.__init__(self, space, name, lineno,
                                          self.scope, compile_info)
        self.symbols = symbols
        self.frame_blocks = []
        self.interactive = False
        self.temporary_name_counter = 1
        if isinstance(self.scope, symtable.FunctionScope):
            self.qualname = qualname + '.<locals>'
        else:
            self.qualname = qualname
        self._allow_top_level_await = compile_info.flags & consts.PyCF_ALLOW_TOP_LEVEL_AWAIT
        self._compile(tree)

    def _compile(self, tree):
        """Override in subclasses to compile a scope."""
        raise NotImplementedError

    def sub_scope(self, kind, name, node, lineno):
        """Convenience function for compiling a sub scope."""
        if self.scope.lookup(name) == symtable.SCOPE_GLOBAL_EXPLICIT:
            qualname = name
        elif self.qualname:
            qualname = '%s.%s' % (self.qualname, name)
        else:
            qualname = name
        generator = kind(self.space, name, node, lineno, self.symbols,
                         self.compile_info, qualname)
        return generator.assemble(), qualname

    def push_frame_block(self, kind, block, end=None, datum=None):
        self.frame_blocks.append(FrameBlockInfo(kind, block, end, datum))

    def pop_frame_block(self, kind, block):
        fblock = self.frame_blocks.pop()
        assert fblock.kind == kind and fblock.block is block, \
            "mismatched frame blocks"

    def unwind_fblock(self, fblock, preserve_tos):
        """ Unwind a frame block.  If preserve_tos is true, the TOS before
        popping the blocks will be restored afterwards, unless another return,
        break or continue is found. In which case, the TOS will be popped."""

        kind = fblock.kind
        if kind == F_FOR_LOOP:
            if preserve_tos:
                self.emit_op(ops.ROT_TWO)
            self.emit_op(ops.POP_TOP) # pop iterator
        elif kind == F_WHILE_LOOP or kind == F_EXCEPTION_HANDLER:
            pass
        elif kind == F_TRY_EXCEPT:
            self.emit_op(ops.POP_BLOCK)
        elif kind == F_FINALLY_TRY:
            self.emit_op(ops.POP_BLOCK)
            if preserve_tos:
                self.push_frame_block(F_POP_VALUE, None)
            # emit the finally block, restoring the line number when done
            finallyblock = fblock.datum
            assert isinstance(finallyblock, ast.Try)
            assert finallyblock.finalbody
            saved_lineno = self.lineno
            self._visit_body(finallyblock.finalbody)
            self.lineno = saved_lineno
            if preserve_tos:
                self.pop_frame_block(F_POP_VALUE, None)
        elif kind == F_FINALLY_END:
            if preserve_tos:
                self.emit_op(ops.ROT_TWO)
            self.emit_op(ops.POP_TOP) # remove SApplicationException
            self.emit_op(ops.POP_EXCEPT)

        elif kind == F_WITH or kind == F_ASYNC_WITH:
            self.emit_op(ops.POP_BLOCK)
            if preserve_tos:
                self.emit_op(ops.ROT_TWO)
            self.call_exit_with_nones()
            if kind == F_ASYNC_WITH:
                self.emit_op(ops.GET_AWAITABLE)
                self.load_const(self.space.w_None)
                self.emit_op(ops.YIELD_FROM)
            self.emit_op(ops.POP_TOP)
        elif kind == F_HANDLER_CLEANUP:
            if fblock.datum:
                self.emit_op(ops.POP_BLOCK)
            self.emit_op(ops.POP_EXCEPT)
            if fblock.datum:
                self.load_const(self.space.w_None)
                excepthandler = fblock.datum
                assert isinstance(excepthandler, ast.ExceptHandler)
                self.name_op(excepthandler.name, ast.Store, excepthandler)
                self.name_op(excepthandler.name, ast.Del, excepthandler)
        elif kind == F_POP_VALUE:
            if preserve_tos:
                self.emit_op(ops.ROT_TWO)
            self.emit_op(ops.POP_TOP)
        else:
            assert 0, "unreachable"

    def unwind_fblock_stack(self, preserve_tos, find_loop_block=False):
        """ Unwind block stack. If find_loop_block is True, return the first
        loop block, otherwise return None. """
        # XXX This is a bit ridiculous, but we really need to remove the
        # blocks and then re-add them for the benefit of unwinding a try with
        # a finally block, which will emit the code of the finally block in
        # situ, which might then do more unwinding!
        if not self.frame_blocks:
            return None
        fblock_top = self.frame_blocks[-1]
        if find_loop_block and (fblock_top.kind == F_WHILE_LOOP
                or fblock_top.kind == F_FOR_LOOP):
            return fblock_top
        fblock = self.frame_blocks.pop()
        self.unwind_fblock(fblock, preserve_tos)
        res = self.unwind_fblock_stack(preserve_tos, find_loop_block)
        self.frame_blocks.append(fblock)
        return res

    def error(self, msg, node):
        # NB: SyntaxError's offset is 1-based!
        raise SyntaxError(msg, node.lineno, node.col_offset + 1,
                          filename=self.compile_info.filename)

    def name_op(self, identifier, ctx, node):
        """Generate an operation appropriate for the scope of the identifier."""
        # node is used only for the possible syntax error
        self.check_forbidden_name(identifier, node, ctx)

        scope = self.scope.lookup(identifier)
        op = ops.NOP
        container = self.names
        if scope == symtable.SCOPE_LOCAL:
            if self.scope.can_be_optimized:
                container = self.var_names
                op = name_ops_fast(ctx)
        elif scope == symtable.SCOPE_FREE:
            op = name_ops_deref(ctx)
            if op == ops.LOAD_DEREF and isinstance(self, ClassCodeGenerator):
                op = ops.LOAD_CLASSDEREF
            container = self.free_vars
        elif scope == symtable.SCOPE_CELL:
            op = name_ops_deref(ctx)
            container = self.cell_vars
        elif scope == symtable.SCOPE_GLOBAL_IMPLICIT:
            if self.scope.optimized:
                op = name_ops_global(ctx)
        elif scope == symtable.SCOPE_GLOBAL_EXPLICIT:
            op = name_ops_global(ctx)
        if op == ops.NOP:
            op = name_ops_default(ctx)
        self.emit_op_arg(op, self.add_name(container, identifier))

    def possible_docstring(self, node):
        if isinstance(node, ast.Expr) and self.compile_info.optimize < 2:
            expr_value = node.value
            if isinstance(expr_value, ast.Constant) and self.space.isinstance_w(expr_value.value, self.space.w_unicode):
                return expr_value
        return None

    def ensure_docstring_constant(self, body):
        # If there's a docstring, store it as the first constant.
        if body:
            doc_expr = self.possible_docstring(body[0])
        else:
            doc_expr = None
        if doc_expr is not None:
            self.add_const(doc_expr.value)
            self.scope.doc_removable = True
            return True
        else:
            self.add_const(self.space.w_None)
            return False

    def _get_code_flags(self):
        return 0

    def _check_async_function(self):
        """Returns true if 'await' is allowed."""
        return False

    def _handle_body(self, body):
        """Compile a list of statements, handling doc strings if needed."""
        if body:
            start = 0
            doc_expr = self.possible_docstring(body[0])
            if doc_expr is not None:
                start = 1
                doc_expr.walkabout(self)
                if doc_expr.lineno > 0:
                    self.update_position(doc_expr.lineno)
                self.name_op("__doc__", ast.Store, doc_expr)
                self.scope.doc_removable = True
            self._visit_body(body, start)
            return True
        else:
            return False

    def _maybe_setup_annotations(self):
        # if the scope contained an annotated variable assignment,
        # this will emit the requisite SETUP_ANNOTATIONS
        if self.scope.contains_annotated and not isinstance(self, AbstractFunctionCodeGenerator):
            return self.emit_op(ops.SETUP_ANNOTATIONS)

    def call_exit_with_nones(self):
        self.load_const(self.space.w_None)
        self.emit_op(ops.DUP_TOP)
        self.emit_op(ops.DUP_TOP)
        self.emit_op_arg(ops.CALL_FUNCTION, 3)

    def visit_Module(self, mod):
        if not self._handle_body(mod.body):
            self.first_lineno = self.lineno = 1

    def visit_Interactive(self, mod):
        self.interactive = True
        self._visit_body(mod.body)

    def visit_Expression(self, mod):
        self.add_none_to_final_return = False
        mod.body.walkabout(self)

    def _visit_body(self, body, start=0):
        if body is None:
            return
        for i in range(start, len(body)):
            stmt = body[i]
            if stmt is not None:
                assert isinstance(stmt, ast.stmt)
                if stmt.lineno > 0:
                    self.update_position(stmt.lineno)
                stmt.walkabout(self)

    def _make_function(self, code, oparg=0, qualname=None):
        """Emit the opcodes to turn a code object into a function."""
        w_qualname = self.space.newtext(qualname or code.co_name)
        if code.co_freevars:
            oparg = oparg | 0x08
            # Load cell and free vars to pass on.
            for free in code.co_freevars:
                free_scope = self.scope.lookup(free)
                if free_scope in (symtable.SCOPE_CELL,
                                  symtable.SCOPE_CELL_CLASS):
                    index = self.cell_vars[free]
                else:
                    index = self.free_vars[free]
                self.emit_op_arg(ops.LOAD_CLOSURE, index)
            self.emit_op_arg(ops.BUILD_TUPLE, len(code.co_freevars))
        self.load_const(code)
        self.load_const(w_qualname)
        self.emit_op_arg(ops.MAKE_FUNCTION, oparg)

    def _visit_kwonlydefaults(self, args):
        defaults = 0
        keys_w = []
        for i, default in enumerate(args.kw_defaults):
            if default:
                kwonly = args.kwonlyargs[i]
                assert isinstance(kwonly, ast.arg)
                mangled = self.scope.mangle(kwonly.arg)
                keys_w.append(self.space.newtext(mangled))
                default.walkabout(self)
                defaults += 1
        if keys_w:
            w_tup = self.space.newtuple(keys_w)
            self.load_const(w_tup)
            self.emit_op_arg(ops.BUILD_CONST_KEY_MAP, len(keys_w))
        return defaults

    def _visit_arg_annotation(self, name, ann, names):
        if ann:
            ann.walkabout(self)
            names.append(self.scope.mangle(name))

    def _visit_arg_annotations(self, args, names):
        if args:
            for arg in args:
                assert isinstance(arg, ast.arg)
                self._visit_arg_annotation(arg.arg, arg.annotation, names)

    @specialize.argtype(1)
    def _visit_annotations(self, func, args, returns):
        space = self.space
        names = []
        self._visit_arg_annotations(args.posonlyargs, names)
        self._visit_arg_annotations(args.args, names)
        vararg = args.vararg
        if vararg:
            self._visit_arg_annotation(vararg.arg, vararg.annotation,
                                       names)
        self._visit_arg_annotations(args.kwonlyargs, names)
        kwarg = args.kwarg
        if kwarg:
            self._visit_arg_annotation(kwarg.arg, kwarg.annotation,
                                       names)
        self._visit_arg_annotation("return", returns, names)
        l = len(names)
        if l:
            if l > 65534:
                self.error("too many annotations", func)
            w_tup = space.newtuple([space.newtext(name) for name in names])
            self.load_const(w_tup)
            self.emit_op_arg(ops.BUILD_CONST_KEY_MAP, l)
        return l

    def _visit_defaults(self, defaults):
        assert len(defaults) > 0
        w_tup = self._tuple_of_consts(defaults)
        if w_tup:
            self.update_position(defaults[-1].lineno)
            self.load_const(w_tup)
        else:
            self.visit_sequence(defaults)
            self.emit_op_arg(ops.BUILD_TUPLE, len(defaults))

    @specialize.arg(2)
    def _visit_function(self, func, function_code_generator):
        # Load decorators first, but apply them after the function is created.
        if func.decorator_list:
            for dec in func.decorator_list:
                if dec.lineno > 0:
                    self.update_position(dec.lineno)
                dec.walkabout(self)

        if func.lineno > 0:
            self.update_position(func.lineno)

        args = func.args

        assert isinstance(args, ast.arguments)

        oparg = 0

        if args.defaults is not None and len(args.defaults):
            oparg = oparg | 0x01
            self._visit_defaults(args.defaults)

        if args.kwonlyargs:
            kw_default_count = self._visit_kwonlydefaults(args)
            if kw_default_count:
                oparg = oparg | 0x02

        num_annotations = self._visit_annotations(func, args, func.returns)
        if num_annotations:
            oparg = oparg | 0x04

        code, qualname = self.sub_scope(function_code_generator, func.name,
                                        func, func.lineno)
        self._make_function(code, oparg, qualname=qualname)
        # Apply decorators.
        if func.decorator_list:
            for i in range(len(func.decorator_list)):
                self.emit_op_arg(ops.CALL_FUNCTION, 1)
        self.name_op(func.name, ast.Store, func)

    def visit_FunctionDef(self, func):
        self._visit_function(func, FunctionCodeGenerator)

    def visit_AsyncFunctionDef(self, func):
        self._visit_function(func, AsyncFunctionCodeGenerator)

    @update_pos_expr
    def visit_Lambda(self, lam):
        args = lam.args
        assert isinstance(args, ast.arguments)

        oparg = 0
        if args.defaults is not None and len(args.defaults):
            oparg = oparg | 0x01
            self._visit_defaults(args.defaults)

        if args.kwonlyargs:
            kw_default_count = self._visit_kwonlydefaults(args)
            if kw_default_count:
                oparg = oparg | 0x02
        code, qualname = self.sub_scope(
            LambdaCodeGenerator, "<lambda>", lam, lam.lineno)
        self._make_function(code, oparg, qualname=qualname)

    def visit_ClassDef(self, cls):
        self.visit_sequence(cls.decorator_list)
        # 1. compile the class body into a code object
        code, qualname = self.sub_scope(
            ClassCodeGenerator, cls.name, cls, cls.lineno)
        # 2. load the 'build_class' function
        self.emit_op(ops.LOAD_BUILD_CLASS)
        # 3. load a function (or closure) made from the code object
        self._make_function(code, qualname=qualname)
        # 4. load class name
        self.load_const(self.space.newtext(cls.name))
        # 5. generate the rest of the code for the call
        self._make_call(2, cls.bases, cls.keywords)
        # 6. apply decorators
        if cls.decorator_list:
            for i in range(len(cls.decorator_list)):
                self.emit_op_arg(ops.CALL_FUNCTION, 1)
        # 7. store into <name>
        self.name_op(cls.name, ast.Store, cls)

    def visit_AugAssign(self, assign):
        target = assign.target
        if isinstance(target, ast.Attribute):
            self.check_forbidden_name(target.attr, target)
            target.value.walkabout(self)
            self.emit_op(ops.DUP_TOP)
            self.emit_op_name(ops.LOAD_ATTR, self.names, target.attr)
            assign.value.walkabout(self)
            self.emit_op(inplace_operations(assign.op))
            self.emit_op(ops.ROT_TWO)
            self.emit_op_name(ops.STORE_ATTR, self.names, target.attr)
        elif isinstance(target, ast.Subscript):
            target.value.walkabout(self)
            target.slice.walkabout(self)
            self.emit_op(ops.DUP_TOP_TWO)
            self.emit_op(ops.BINARY_SUBSCR)
            assign.value.walkabout(self)
            self.emit_op(inplace_operations(assign.op))
            self.emit_op(ops.ROT_THREE)
            self.emit_op(ops.STORE_SUBSCR)
        elif isinstance(target, ast.Name):
            self.name_op(target.id, ast.Load, target)
            assign.value.walkabout(self)
            self.emit_op(inplace_operations(assign.op))
            self.name_op(target.id, ast.Store, target)
        else:
            self.error("illegal expression for augmented assignment", assign)

    def visit_Assert(self, asrt):
        if self.compile_info.optimize >= 1:
            return
        assert self.compile_info.optimize == 0
        if isinstance(asrt.test, ast.Tuple):
            test = asrt.test
            assert isinstance(test, ast.Tuple)
            if len(test.elts) > 0:
                misc.syntax_warning(
                    self.space,
                    "assertion is always true, perhaps remove parentheses?",
                    self.compile_info.filename,
                    asrt.lineno,
                    asrt.col_offset
                )
        end = self.new_block()
        asrt.test.accept_jump_if(self, True, end)
        self.emit_op(ops.LOAD_ASSERTION_ERROR)
        if asrt.msg:
            asrt.msg.walkabout(self)
            self.emit_op_arg(ops.CALL_FUNCTION, 1)
        self.emit_op_arg(ops.RAISE_VARARGS, 1)
        self.use_next_block(end)

    def _binop(self, op):
        return binary_operations(op)

    @update_pos_expr
    def visit_BinOp(self, binop):
        binop.left.walkabout(self)
        binop.right.walkabout(self)
        self.emit_op(self._binop(binop.op))

    def visit_Return(self, ret):
        preserve_tos = ret.value is not None and not isinstance(ret.value, ast.Constant)
        if preserve_tos:
            ret.value.walkabout(self)
        self.unwind_fblock_stack(preserve_tos)
        if ret.value is None:
            self.load_const(self.space.w_None)
        elif not preserve_tos:
            ret.value.walkabout(self) # Constant
        self.emit_op(ops.RETURN_VALUE)

    def visit_Delete(self, delete):
        self.visit_sequence(delete.targets)

    def visit_If(self, if_):
        end = self.new_block()
        test_constant = if_.test.as_constant_truth(
            self.space, self.compile_info)
        if test_constant == optimize.CONST_FALSE:
            with self.all_dead_code():
                self._visit_body(if_.body)
            self._visit_body(if_.orelse)
        elif test_constant == optimize.CONST_TRUE:
            self._visit_body(if_.body)
            with self.all_dead_code():
                self._visit_body(if_.orelse)
        else:
            if if_.orelse:
                otherwise = self.new_block()
            else:
                otherwise = end
            if_.test.accept_jump_if(self, False, otherwise)
            self._visit_body(if_.body)
            if if_.orelse:
                self.emit_jump(ops.JUMP_FORWARD, end)
                self.use_next_block(otherwise)
                self._visit_body(if_.orelse)
        self.use_next_block(end)

    def visit_Break(self, br):
        loop_fblock = self.unwind_fblock_stack(False, find_loop_block=True)
        if loop_fblock is None:
            self.error("'break' not properly in loop", br)
        self.unwind_fblock(loop_fblock, False)
        assert loop_fblock.end is not None
        self.emit_jump(ops.JUMP_ABSOLUTE, loop_fblock.end, True)

    def visit_Continue(self, cont):
        loop_fblock = self.unwind_fblock_stack(False, find_loop_block=True)
        if loop_fblock is None:
            self.error("'continue' not properly in loop", cont)
        self.emit_jump(ops.JUMP_ABSOLUTE, loop_fblock.block, True)

    def visit_For(self, fr):
        start = self.new_block()
        cleanup = self.new_block()
        end = self.new_block()
        # self.emit_jump(ops.SETUP_LOOP, end)
        self.push_frame_block(F_FOR_LOOP, start, end)
        fr.iter.walkabout(self)
        self.emit_op(ops.GET_ITER)
        self.use_next_block(start)
        self.emit_jump(ops.FOR_ITER, cleanup)
        fr.target.walkabout(self)
        self._visit_body(fr.body)
        self.emit_jump(ops.JUMP_ABSOLUTE, start, True)
        self.use_next_block(cleanup)
        self.pop_frame_block(F_FOR_LOOP, start)
        self._visit_body(fr.orelse)
        self.use_next_block(end)

    def visit_AsyncFor(self, fr):
        if not self._check_async_function():
            self.error("'async for' outside async function", fr)
        b_start = self.new_block()
        b_except = self.new_block()
        b_end = self.new_block()

        fr.iter.walkabout(self)
        self.emit_op(ops.GET_AITER)

        self.use_next_block(b_start)
        self.push_frame_block(F_FOR_LOOP, b_start, b_end)

        self.emit_jump(ops.SETUP_EXCEPT, b_except)
        self.emit_op(ops.GET_ANEXT)
        self.load_const(self.space.w_None)
        self.emit_op(ops.YIELD_FROM)
        self.emit_op(ops.POP_BLOCK)
        fr.target.walkabout(self)
        self._visit_body(fr.body)
        self.emit_jump(ops.JUMP_ABSOLUTE, b_start, True)
        self.pop_frame_block(F_FOR_LOOP, b_start)

        # except block for errors from __anext__
        self.use_next_block(b_except)
        self.emit_op(ops.END_ASYNC_FOR)
        self._visit_body(fr.orelse)

        self.use_next_block(b_end)

    def visit_While(self, wh):
        test_constant = wh.test.as_constant_truth(self.space, self.compile_info)
        if test_constant == optimize.CONST_FALSE:
            with self.all_dead_code():
                end = self.new_block()
                loop = self.new_block()
                self.push_frame_block(F_WHILE_LOOP, loop, end)
                self._visit_body(wh.body)
                self.pop_frame_block(F_WHILE_LOOP, loop)
            self._visit_body(wh.orelse)
        else:
            end = self.new_block()
            anchor = None
            if test_constant == optimize.CONST_NOT_CONST:
                anchor = self.new_block()
            loop = self.new_block()
            self.push_frame_block(F_WHILE_LOOP, loop, end)
            self.use_next_block(loop)
            if test_constant == optimize.CONST_NOT_CONST:
                wh.test.accept_jump_if(self, False, anchor)
            self._visit_body(wh.body)
            self.emit_jump(ops.JUMP_ABSOLUTE, loop, True)
            if test_constant == optimize.CONST_NOT_CONST:
                self.use_next_block(anchor)
            self.pop_frame_block(F_WHILE_LOOP, loop)
            self._visit_body(wh.orelse)
            self.use_next_block(end)

    def _visit_try_except(self, tr):
        body = self.new_block()
        exc = self.new_block()
        otherwise = self.new_block()
        end = self.new_block()
        # XXX CPython uses SETUP_FINALLY here too
        self.emit_jump(ops.SETUP_EXCEPT, exc)
        body = self.use_next_block(body)
        self.push_frame_block(F_TRY_EXCEPT, body)
        self._visit_body(tr.body)
        self.emit_op(ops.POP_BLOCK)
        self.pop_frame_block(F_TRY_EXCEPT, body)
        self.emit_jump(ops.JUMP_FORWARD, otherwise)
        self.use_next_block(exc)
        self.push_frame_block(F_EXCEPTION_HANDLER, None)
        for i, handler in enumerate(tr.handlers):
            assert isinstance(handler, ast.ExceptHandler)
            self.update_position(handler.lineno)
            next_except = self.new_block()
            if handler.type:
                self.emit_op(ops.DUP_TOP)
                handler.type.walkabout(self)
                self.emit_jump(ops.JUMP_IF_NOT_EXC_MATCH, next_except, True)
            else:
                if i != len(tr.handlers) - 1:
                    self.error(
                        "bare 'except:' must be the last except block", handler)
            self.emit_op(ops.POP_TOP)
            if handler.name:
                ## generate the equivalent of:
                ##
                ## try:
                ##     # body
                ## except type as name:
                ##     try:
                ##         # body
                ##     finally:
                ##         name = None
                ##         del name
                #
                cleanup_end = self.new_block()
                self.name_op(handler.name, ast.Store, handler)
                self.emit_op(ops.POP_TOP)
                # second try
                self.emit_jump(ops.SETUP_FINALLY, cleanup_end)
                cleanup_body = self.use_next_block()
                self.push_frame_block(F_HANDLER_CLEANUP, cleanup_body, None, handler)
                # second # body
                self._visit_body(handler.body)
                self.pop_frame_block(F_HANDLER_CLEANUP, cleanup_body)
                self.emit_op(ops.POP_BLOCK)
                self.emit_op(ops.POP_EXCEPT)
                # name = None; del name
                self.load_const(self.space.w_None)
                self.name_op(handler.name, ast.Store, handler)
                self.name_op(handler.name, ast.Del, handler)
                self.emit_jump(ops.JUMP_FORWARD, end)

                # finally
                self.use_next_block(cleanup_end)
                # this is a hack! we emit a NOP to distinguish this from a
                # "regular" finally. the reason for that is that we do not want
                # to emit a line trace event if sys.settrace is set for the
                # following instructions, and the interpeter can use the NOP to
                # detect this case. CPython has really complicated and broken
                # logic for this situation instead. See code in
                # FinallyBlock.handle.
                self.emit_op(ops.NOP)
                # name = None; del name
                self.load_const(self.space.w_None)
                self.name_op(handler.name, ast.Store, handler)
                self.name_op(handler.name, ast.Del, handler)

                self.emit_op(ops.RERAISE)
            else:
                self.emit_op(ops.POP_TOP)
                self.emit_op(ops.POP_TOP)
                cleanup_body = self.use_next_block()
                self.push_frame_block(F_HANDLER_CLEANUP, cleanup_body)
                self._visit_body(handler.body)
                self.pop_frame_block(F_HANDLER_CLEANUP, cleanup_body)
                self.emit_op(ops.POP_EXCEPT)
                self.emit_jump(ops.JUMP_FORWARD, end)
            #
            self.use_next_block(next_except)
        self.pop_frame_block(F_EXCEPTION_HANDLER, None)
        # pypy difference: get rid of exception
        self.emit_op(ops.POP_TOP)
        self.emit_op(ops.POP_TOP)
        self.emit_op(ops.RERAISE) # reraise uses the SApplicationException
        self.use_next_block(otherwise)
        self._visit_body(tr.orelse)
        self.use_next_block(end)

    def _visit_try_finally(self, tr):
        body = self.new_block()
        end = self.new_block()
        exit = self.new_block()

        # try block

        self.emit_jump(ops.SETUP_FINALLY, end)
        self.use_next_block(body)
        self.push_frame_block(F_FINALLY_TRY, body, end, tr)
        if tr.handlers:
            self._visit_try_except(tr)
        else:
            self._visit_body(tr.body)
        self.emit_op(ops.POP_BLOCK)
        self.pop_frame_block(F_FINALLY_TRY, body)
        self._visit_body(tr.finalbody)
        self.emit_jump(ops.JUMP_FORWARD, exit)

        # finally block, exceptional case
        self.use_next_block(end)
        self.push_frame_block(F_FINALLY_END, end)
        self._visit_body(tr.finalbody)
        self.pop_frame_block(F_FINALLY_END, end)
        self.emit_op(ops.RERAISE)
        self.use_next_block(exit)


    def visit_Try(self, tr):
        if tr.finalbody:
            return self._visit_try_finally(tr)
        else:
            return self._visit_try_except(tr)

    def _import_as(self, alias, imp):
        # in CPython this is roughly compile_import_as
        # The IMPORT_NAME opcode was already generated.  This function
        # merely needs to bind the result to a name.

        # If there is a dot in name, we need to split it and emit a
        # IMPORT_FROM for each name.
        source_name = alias.name
        dot = source_name.find(".")
        if dot > 0:
            # Consume the base module name to get the first attribute
            while True:
                start = dot + 1
                dot = source_name.find(".", start)
                if dot < 0:
                    end = len(source_name)
                else:
                    end = dot
                attr = source_name[start:end]
                self.emit_op_name(ops.IMPORT_FROM, self.names, attr)
                if dot < 0:
                    break
                self.emit_op(ops.ROT_TWO)
                self.emit_op(ops.POP_TOP)
            self.name_op(alias.asname, ast.Store, imp)
            self.emit_op(ops.POP_TOP)
            return
        self.name_op(alias.asname, ast.Store, imp)

    def visit_Import(self, imp):
        for alias in imp.names:
            assert isinstance(alias, ast.alias)
            level = 0
            self.load_const(self.space.newint(level))
            self.load_const(self.space.w_None)
            self.emit_op_name(ops.IMPORT_NAME, self.names, alias.name)
            # If there's no asname then we store the root module.  If there is
            # an asname, _import_as stores the last module of the chain into it.
            if alias.asname:
                self._import_as(alias, imp)
            else:
                dot = alias.name.find(".")
                if dot < 0:
                    store_name = alias.name
                else:
                    store_name = alias.name[:dot]
                self.name_op(store_name, ast.Store, imp)

    def visit_ImportFrom(self, imp):
        space = self.space
        first = imp.names[0]
        assert isinstance(first, ast.alias)
        star_import = len(imp.names) == 1 and first.name == "*"
        # Various error checking for future imports.
        if imp.module == "__future__":
            last_line, last_offset = self.compile_info.last_future_import
            if imp.lineno > last_line or \
                    imp.lineno == last_line and imp.col_offset > last_offset:
                self.error("__future__ statements must appear at beginning "
                               "of file", imp)
            if star_import:
                self.error("* not valid in __future__ imports", imp)
            compiler = space.createcompiler()
            for alias in imp.names:
                assert isinstance(alias, ast.alias)
                if alias.name not in compiler.future_flags.compiler_features:
                    if alias.name == "braces":
                        self.error("not a chance", imp)
                    self.error("future feature %s is not defined" %
                               (alias.name,), imp)
        self.load_const(space.newint(imp.level))
        names_w = [None]*len(imp.names)
        for i in range(len(imp.names)):
            alias = imp.names[i]
            assert isinstance(alias, ast.alias)
            names_w[i] = space.newtext(alias.name)
        self.load_const(space.newtuple(names_w))
        if imp.module:
            mod_name = imp.module
        else:
            # In the case of a relative import.
            mod_name = ""
        self.emit_op_name(ops.IMPORT_NAME, self.names, mod_name)
        if star_import:
            self.emit_op(ops.IMPORT_STAR)
        else:
            for alias in imp.names:
                assert isinstance(alias, ast.alias)
                self.emit_op_name(ops.IMPORT_FROM, self.names, alias.name)
                if alias.asname:
                    store_name = alias.asname
                else:
                    store_name = alias.name
                self.name_op(store_name, ast.Store, imp)
            self.emit_op(ops.POP_TOP)

    def visit_Assign(self, assign):
        # paranoia assert in this stmt subclass: make sure that the lineno is
        # already set, should be done by _visit_body
        assert assign.lineno < 1 or self.lineno == assign.lineno

        if self._optimize_unpacking(assign):
            return
        assign.value.walkabout(self)
        duplications = len(assign.targets) - 1
        for i in range(len(assign.targets)):
            if i < duplications:
                self.emit_op(ops.DUP_TOP)
            assign.targets[i].walkabout(self)

    def _optimize_unpacking(self, assign):
        """Try to optimize out BUILD_TUPLE and UNPACK_SEQUENCE opcodes."""
        if len(assign.targets) != 1:
            return False
        targets = assign.targets[0].as_node_list(self.space)
        if targets is None:
            return False
        values = assign.value.as_node_list(self.space)
        if values is None:
            return False
        targets_count = len(targets)
        values_count = len(values)
        if targets_count != values_count:
            return False
        for value in values:
            if isinstance(value, ast.Starred):
                return False # more complicated
        for target in targets:
            if not isinstance(target, ast.Name):
                if isinstance(target, ast.Starred):
                    # these require extra checks
                    return False
                break
        else:
            self.visit_sequence(values)
            seen_names = {}
            for i in range(targets_count - 1, -1, -1):
                target = targets[i]
                assert isinstance(target, ast.Name)
                if target.id not in seen_names:
                    seen_names[target.id] = True
                    self.name_op(target.id, ast.Store, target)
                else:
                    self.emit_op(ops.POP_TOP)
            return True
        if values_count > 3:
            return False
        self.visit_sequence(values)
        if values_count == 2:
            self.emit_op(ops.ROT_TWO)
        elif values_count == 3:
            self.emit_op(ops.ROT_THREE)
            self.emit_op(ops.ROT_TWO)
        self.visit_sequence(targets)
        return True

    def _annotation_evaluate(self, item):
        # PEP 526 requires that some things be evaluated, to avoid bugs
        # where a non-assigning variable annotation references invalid items
        # this is effectively a NOP, but will fail if e.g. item is an
        # Attribute and one of the chained names does not exist
        item.walkabout(self)
        self.emit_op(ops.POP_TOP)

    def _annotation_eval_slice(self, target):
        if isinstance(target, ast.Slice):
            for val in [target.lower, target.upper, target.step]:
                if val:
                    self._annotation_evaluate(val)
        elif isinstance(target, ast.Tuple):
            for val in target.elts:
                self._annotation_eval_slice(val)
        else:
            self._annotation_evaluate(target)

    def visit_AnnAssign(self, assign):
        target = assign.target
        # if there's an assignment to be done, do it
        if assign.value:
            assign.value.walkabout(self)
            target.walkabout(self)
        # the PEP requires that certain parts of the target be evaluated at runtime
        # to avoid silent annotation-related errors
        if isinstance(target, ast.Name):
            self.check_forbidden_name(target.id, assign)
            # if it's just a simple name and we're not in a function, store
            # the annotation in __annotations__
            if assign.simple and not isinstance(self.scope, symtable.FunctionScope):
                assign.annotation.walkabout(self)
                self.emit_op_arg(ops.LOAD_NAME, self.add_name(self.names, '__annotations__'))
                name = target.id
                w_name = self.space.newtext(self.scope.mangle(name))
                self.load_const(misc.intern_if_common_string(self.space, w_name))
                self.emit_op(ops.STORE_SUBSCR)
        elif isinstance(target, ast.Attribute):
            # the spec requires that `a.b: int` evaluates `a`
            # and in a non-function scope, also evaluates `int`
            # (N.B.: if the target is of the form `a.b.c`, `a.b` will be evaluated)
            if not assign.value:
                attr = target.value
                self._annotation_evaluate(attr)
        elif isinstance(target, ast.Subscript):
            if not assign.value:
                # similar to the above, `a[0:5]: int` evaluates the name and the slice argument
                # and if not in a function, also evaluates the annotation
                sl = target.slice
                self._annotation_evaluate(target.value)
                self._annotation_eval_slice(sl)
        else:
            self.error("can't handle annotation with %s" % (target,), target)
        # if this is not in a function, evaluate the annotation
        if not (assign.simple or isinstance(self.scope, symtable.FunctionScope)):
            self._annotation_evaluate(assign.annotation)


    def visit_With(self, wih):
        self.handle_withitem(wih, 0, is_async=False)

    @specialize.argtype(1)
    def handle_withitem(self, wih, pos, is_async):
        body_block = self.new_block()
        cleanup = self.new_block()
        exit = self.new_block()
        witem = wih.items[pos]
        assert isinstance(witem, ast.withitem)
        witem.context_expr.walkabout(self)
        if not is_async:
            self.emit_jump(ops.SETUP_WITH, cleanup)
            fblock_kind = F_WITH
        else:
            self.emit_op(ops.BEFORE_ASYNC_WITH)
            self.emit_op(ops.GET_AWAITABLE)
            self.load_const(self.space.w_None)
            self.emit_op(ops.YIELD_FROM)
            self.emit_jump(ops.SETUP_ASYNC_WITH, cleanup)
            fblock_kind = F_ASYNC_WITH

        self.use_next_block(body_block)
        self.push_frame_block(fblock_kind, body_block, cleanup)
        if witem.optional_vars:
            witem.optional_vars.walkabout(self)
        else:
            self.emit_op(ops.POP_TOP)
        if pos == len(wih.items) - 1:
            self._visit_body(wih.body)
        else:
            self.handle_withitem(wih, pos + 1, is_async=is_async)
        self.emit_op(ops.POP_BLOCK)
        self.pop_frame_block(fblock_kind, body_block)

        # end of body, successful outcome, start cleanup
        self.call_exit_with_nones()
        if is_async:
            self.emit_op(ops.GET_AWAITABLE)
            self.load_const(self.space.w_None)
            self.emit_op(ops.YIELD_FROM)
        self.emit_op(ops.POP_TOP)
        self.emit_jump(ops.JUMP_ABSOLUTE, exit, True)

        # exceptional outcome
        self.use_next_block(cleanup)
        self.emit_op(ops.WITH_EXCEPT_START)
        if is_async:
            self.emit_op(ops.GET_AWAITABLE)
            self.load_const(self.space.w_None)
            self.emit_op(ops.YIELD_FROM)
        exit2 = self.new_block()
        self.emit_jump(ops.POP_JUMP_IF_TRUE, exit2, True)
        self.emit_op(ops.RERAISE)
        self.use_next_block(exit2)
        self.emit_op(ops.POP_TOP)
        self.emit_op(ops.POP_EXCEPT)
        self.use_next_block(exit)

    def visit_AsyncWith(self, wih):
        if not self._check_async_function():
            self.error("'async with' outside async function", wih)
        self.handle_withitem(wih, 0, is_async=True)

    def visit_Raise(self, rais):
        arg = 0
        if rais.exc:
            rais.exc.walkabout(self)
            arg += 1
            if rais.cause:
                rais.cause.walkabout(self)
                arg += 1
        self.emit_op_arg(ops.RAISE_VARARGS, arg)

    def visit_Global(self, glob):
        # Handled in symbol table building.
        pass

    def visit_Nonlocal(self, glob):
        # Handled in symbol table building.
        pass

    def visit_Pass(self, pas):
        pass

    def visit_Expr(self, expr):
        if self.interactive:
            expr.value.walkabout(self)
            self.emit_op(ops.PRINT_EXPR)
        elif not isinstance(expr.value, ast.Constant):
            expr.value.walkabout(self)
            self.emit_op(ops.POP_TOP)

    @update_pos_expr
    def visit_Yield(self, yie):
        if yie.value:
            yie.value.walkabout(self)
        else:
            self.load_const(self.space.w_None)
        self.emit_op(ops.YIELD_VALUE)

    @update_pos_expr
    def visit_YieldFrom(self, yfr):
        yfr.value.walkabout(self)
        self.emit_op(ops.GET_YIELD_FROM_ITER)
        self.load_const(self.space.w_None)
        self.emit_op(ops.YIELD_FROM)

    @update_pos_expr
    def visit_Await(self, aw):
        if not self._check_async_function():
            self.error("'await' outside async function", aw)
        aw.value.walkabout(self)
        self.emit_op(ops.GET_AWAITABLE)
        self.load_const(self.space.w_None)
        self.emit_op(ops.YIELD_FROM)

    @update_pos_expr
    def visit_Constant(self, const):
        self.load_const(const.value)

    @update_pos_expr
    def visit_UnaryOp(self, op):
        op.operand.walkabout(self)
        self.emit_op(unary_operations(op.op))

    @update_pos_expr
    def visit_BoolOp(self, op):
        if op.op == ast.And:
            instr = ops.JUMP_IF_FALSE_OR_POP
        else:
            instr = ops.JUMP_IF_TRUE_OR_POP
        end = self.new_block()
        we_are_and = op.op == ast.And
        last = len(op.values) - 1
        for index in range(last):
            value = op.values[index]
            truth = value.as_constant_truth(
                    self.space, self.compile_info)
            if truth == optimize.CONST_NOT_CONST:
                value.walkabout(self)
                self.emit_jump(instr, end, True)
                continue
            if (truth != optimize.CONST_TRUE) == we_are_and:
                last = index
                with self.all_dead_code(): # error checking
                    for i in range(index + 1, len(op.values)):
                        op.values[i].walkabout(self)
                break
            else:
                with self.all_dead_code(): # error checking
                    value.walkabout(self)
        op.values[last].walkabout(self)
        self.use_next_block(end)

    @update_pos_expr
    def visit_Compare(self, comp):
        self._check_compare(comp)
        comp.left.walkabout(self)
        ops_count = len(comp.ops)
        cleanup = None
        if ops_count > 1:
            cleanup = self.new_block()
            comp.comparators[0].walkabout(self)
        for i in range(1, ops_count):
            self.emit_op(ops.DUP_TOP)
            self.emit_op(ops.ROT_THREE)
            opcode, op_kind = compare_operations(comp.ops[i - 1])
            self.emit_op_arg(opcode, op_kind)
            self.emit_jump(ops.JUMP_IF_FALSE_OR_POP, cleanup, True)
            if i < (ops_count - 1):
                comp.comparators[i].walkabout(self)
        last_op, last_comparator = comp.ops[-1], comp.comparators[-1]
        if not self._optimize_comparator(last_op, last_comparator):
            last_comparator.walkabout(self)
        opcode, op_kind = compare_operations(last_op)
        self.emit_op_arg(opcode, op_kind)
        if ops_count > 1:
            end = self.new_block()
            self.emit_jump(ops.JUMP_FORWARD, end)
            self.use_next_block(cleanup)
            self.emit_op(ops.ROT_TWO)
            self.emit_op(ops.POP_TOP)
            self.use_next_block(end)

    def _is_literal(self, node):
        # to-do(isidentical): maybe include list, dict, sets?
        if not isinstance(node, ast.Constant):
            return False

        for singleton in [
            self.space.w_None,
            self.space.w_True,
            self.space.w_False,
            self.space.w_Ellipsis
        ]:
            if self.space.is_w(node.value, singleton):
                return False

        return True

    def _check_compare(self, node):
        left = node.left
        for i in range(min(len(node.ops), len(node.comparators))):
            op = node.ops[i]
            right = node.comparators[i]
            if op in (ast.Is, ast.IsNot) and (self._is_literal(left) or self._is_literal(right)):
                if op is ast.Is:
                    operator, replacement = "is", "=="
                else:
                    operator, replacement = "is not", "!="
                misc.syntax_warning(
                    self.space,
                    '"%s" with a literal. Did you mean "%s"?'
                    % (operator, replacement),
                    self.compile_info.filename,
                    node.lineno,
                    node.col_offset
                )
            left = right

    def _optimize_comparator(self, op, node):
        """Fold lists/sets of constants in the context of "in"/"not in".

        lists are folded into tuples, sets into frozensets, otherwise
        returns False
        """
        if op in (ast.In, ast.NotIn):
            is_list = isinstance(node, ast.List)
            if is_list or isinstance(node, ast.Set):
                w_const = self._tuple_of_consts(node.elts)
                if w_const is not None:
                    if not is_list:
                        from pypy.objspace.std.setobject import (
                            W_FrozensetObject)
                        w_const = W_FrozensetObject(self.space, w_const)
                    self.load_const(w_const)
                    return True
        return False

    def _tuple_of_consts(self, elts):
        """Return a tuple of consts from elts if possible, or None"""
        count = len(elts) if elts is not None else 0
        consts_w = [None] * count
        for i in range(count):
            w_value = elts[i].as_constant(self.space, self.compile_info)
            if w_value is None:
                # Not all constants
                return None
            consts_w[i] = w_value
        return self.space.newtuple(consts_w)

    @update_pos_expr
    def visit_IfExp(self, ifexp):
        end = self.new_block()
        otherwise = self.new_block()
        ifexp.test.accept_jump_if(self, False, otherwise)
        ifexp.body.walkabout(self)
        self.emit_jump(ops.JUMP_FORWARD, end)
        self.use_next_block(otherwise)
        ifexp.orelse.walkabout(self)
        self.use_next_block(end)

    def _visit_starunpack(self, node, elts, build_op, add_op, extend_op, is_tuple=False):
        elt_count = len(elts) if elts else 0
        contains_starred = False
        for i in range(elt_count):
            elt = elts[i]
            if isinstance(elt, ast.Starred):
                contains_starred = True
                break
        if not contains_starred:
            if elt_count > MAX_STACKDEPTH_CONTAINERS:
                if is_tuple:
                    self.emit_op_arg(ops.BUILD_LIST, 0)
                    add_op = ops.LIST_APPEND
                else:
                    self.emit_op_arg(build_op, 0)
                for elt in elts:
                    elt.walkabout(self)
                    self.emit_op_arg(add_op, 1)
                if is_tuple:
                    self.emit_op(ops.LIST_TO_TUPLE)
            else:
                for i in range(elt_count):
                    elt = elts[i]
                    elt.walkabout(self)
                if is_tuple:
                    self.emit_op_arg(ops.BUILD_TUPLE, elt_count)
                else:
                    self.emit_op_arg(build_op, elt_count)
            return

        seen_star = False
        for i in range(elt_count):
            elt = elts[i]
            if isinstance(elt, ast.Starred):
                if not seen_star:
                    self.emit_op_arg(build_op, i)
                    seen_star = True
                elt.value.walkabout(self)
                self.emit_op_arg(extend_op, 1)
            else:
                elt.walkabout(self)
                if seen_star:
                    self.emit_op_arg(add_op, 1)
        assert seen_star
        if is_tuple:
            self.emit_op(ops.LIST_TO_TUPLE)

    def _visit_assignment(self, node, elts, ctx):
        elt_count = len(elts) if elts else 0
        if ctx == ast.Store:
            seen_star = False
            for i in range(elt_count):
                elt = elts[i]
                is_starred = isinstance(elt, ast.Starred)
                if is_starred and not seen_star:
                    if i >= 1 << 8 or elt_count - i - 1 >= (C_INT_MAX >> 8):
                        self.error("too many expressions in star-unpacking "
                                   "assignment", node)
                    self.emit_op_arg(ops.UNPACK_EX,
                                     i + ((elt_count - i - 1) << 8))
                    seen_star = True
                    elts[i] = elt.value
                elif is_starred:
                    self.error("multiple starred expressions in assignment", elt)
            if not seen_star:
                self.emit_op_arg(ops.UNPACK_SEQUENCE, elt_count)
        self.visit_sequence(elts)

    def visit_Starred(self, star):
        if star.ctx != ast.Store:
            self.error("can't use starred expression here",
                       star)
        self.error("starred assignment target must be in a list or tuple", star)

    @update_pos_expr
    def visit_Tuple(self, tup):
        if tup.ctx == ast.Store:
            self._visit_assignment(tup, tup.elts, tup.ctx)
        elif tup.ctx == ast.Load:
            self._visit_starunpack(tup, tup.elts, ops.BUILD_LIST, ops.LIST_APPEND, ops.LIST_EXTEND, is_tuple=True)
        else:
            self.visit_sequence(tup.elts)

    @update_pos_expr
    def visit_List(self, l):
        if l.ctx == ast.Store:
            self._visit_assignment(l, l.elts, l.ctx)
        elif l.ctx == ast.Load:
            self._visit_starunpack(l, l.elts, ops.BUILD_LIST, ops.LIST_APPEND, ops.LIST_EXTEND)
        else:
            self.visit_sequence(l.elts)

    @update_pos_expr
    def visit_Dict(self, d):
        containers = 0
        elements = 0
        is_unpacking = False
        all_constant_keys_w = None
        if d.values:
            unpacking_anywhere = False
            for key in d.keys:
                if key is None:
                    unpacking_anywhere = True
                    break
            if not unpacking_anywhere and len(d.keys) > MAX_STACKDEPTH_CONTAINERS:
                # do it in a small amount of stack
                self.emit_op_arg(ops.BUILD_MAP, 0)
                for i in range(len(d.values)):
                    key = d.keys[i]
                    assert key is not None
                    key.walkabout(self)
                    d.values[i].walkabout(self)
                    self.emit_op_arg(ops.MAP_ADD, 1)
                return
            assert len(d.keys) < 0xffff
            all_constant_keys_w = []
            for key in d.keys:
                if key is None:
                    constant_key = None
                else:
                    constant_key = key.as_constant(
                        self.space, self.compile_info)
                if constant_key is None:
                    all_constant_keys_w = None
                    break
                else:
                    all_constant_keys_w.append(constant_key)
            for i in range(len(d.values)):
                key = d.keys[i]
                is_unpacking = key is None
                if elements == 0xFFFF or (elements and is_unpacking):
                    assert all_constant_keys_w is None
                    self.emit_op_arg(ops.BUILD_MAP, elements)
                    if containers > 0:
                        self.emit_op(ops.DICT_UPDATE)
                    else:
                        containers = 1
                    elements = 0
                if is_unpacking:
                    if containers == 0:
                        self.emit_op_arg(ops.BUILD_MAP, 0)
                        containers = 1
                    assert all_constant_keys_w is None
                    d.values[i].walkabout(self)
                    self.emit_op(ops.DICT_UPDATE)
                else:
                    if not all_constant_keys_w:
                        key.walkabout(self)
                    d.values[i].walkabout(self)
                    elements += 1
        if elements or containers == 0:
            if all_constant_keys_w:
                w_tup = self.space.newtuple(all_constant_keys_w)
                self.load_const(w_tup)
                self.emit_op_arg(ops.BUILD_CONST_KEY_MAP, elements)
                containers = 1
            else:
                self.emit_op_arg(ops.BUILD_MAP, elements)
                if containers > 0:
                    self.emit_op(ops.DICT_UPDATE)
                else:
                    containers = 1
        assert containers == 1

    @update_pos_expr
    def visit_Set(self, s):
        self._visit_starunpack(s, s.elts, ops.BUILD_SET, ops.SET_ADD, ops.SET_UPDATE)

    @update_pos_expr
    def visit_Name(self, name):
        self.name_op(name.id, name.ctx, name)

    def visit_keyword(self, keyword):
        if keyword.arg is not None:
            self.load_const(self.space.newtext(keyword.arg))
        keyword.value.walkabout(self)

    def _load_constant_tuple(self, content_w):
        self.load_const(self.space.newtuple(content_w[:]))

    def _make_call(self, nargs_pushed, args, keywords):
        space = self.space
        CallCodeGenerator(self, nargs_pushed, args, keywords).emit_call()

    @update_pos_expr
    def visit_Call(self, call):
        if self._optimize_method_call(call):
            return
        self._check_caller(call.func)
        call.func.walkabout(self)
        self._make_call(0, call.args, call.keywords)

    def _check_caller(self, func):
        if func._literal_type:
            misc.syntax_warning(
                self.space,
                "'%s' object is not callable; perhaps you "
                "missed a comma?" % func._get_type_name(self.space),
                self.compile_info.filename,
                func.lineno,
                func.col_offset
            )

    def _call_has_no_star_args(self, call):
        if call.args is not None:
            for elt in call.args:
                if isinstance(elt, ast.Starred):
                    return False
        if call.keywords is not None:
            for kw in call.keywords:
                assert isinstance(kw, ast.keyword)
                if kw.arg is None:
                    return False
        return True

    def _call_has_simple_args(self, call):
        return self._call_has_no_star_args(call) and not call.keywords

    def _optimize_method_call(self, call):
        space = self.space
        if not self._call_has_no_star_args(call) or \
           not isinstance(call.func, ast.Attribute):
            return False
        attr_lookup = call.func
        assert isinstance(attr_lookup, ast.Attribute)
        attr_lookup.value.walkabout(self)
        self.emit_op_name(ops.LOAD_METHOD, self.names, attr_lookup.attr)
        self.visit_sequence(call.args)
        arg_count = len(call.args) if call.args is not None else 0
        if not call.keywords:
            self.emit_op_arg(ops.CALL_METHOD, arg_count)
        else:
            keyword_names_w = []
            for kw in call.keywords:
                assert isinstance(kw, ast.keyword)
                assert kw.arg  # checked by self._call_has_no_star_args
                w_name = space.newtext(kw.arg)
                keyword_names_w.append(misc.intern_if_common_string(space, w_name))
                kw.value.walkabout(self)
            self._load_constant_tuple(keyword_names_w)
            self.emit_op_arg(ops.CALL_METHOD_KW, len(keyword_names_w) + arg_count)
        return True

    @update_pos_expr
    def visit_ListComp(self, lc):
        self._compile_comprehension(lc, "<listcomp>",
                                    ComprehensionCodeGenerator)

    def _comp_generator(self, node, generators, gen_index):
        gen = generators[gen_index]
        assert isinstance(gen, ast.comprehension)
        if gen.is_async:
            self._comp_async_generator(node, generators, gen_index)
        else:
            self._comp_sync_generator(node, generators, gen_index)

    def _comp_sync_generator(self, node, generators, gen_index):
        start = self.new_block()
        if_cleanup = self.new_block()
        anchor = self.new_block()
        gen = generators[gen_index]
        assert isinstance(gen, ast.comprehension)
        if gen_index > 0:
            gen.iter.walkabout(self)
            self.emit_op(ops.GET_ITER)
        self.use_next_block(start)
        self.emit_jump(ops.FOR_ITER, anchor)
        self.use_next_block()
        gen.target.walkabout(self)
        if gen.ifs:
            for if_ in gen.ifs:
                if_.accept_jump_if(self, False, if_cleanup)
                self.use_next_block()
        gen_index += 1
        if gen_index < len(generators):
            self._comp_generator(node, generators, gen_index)
        else:
            node.accept_comp_iteration(self, gen_index)
        self.use_next_block(if_cleanup)
        self.emit_jump(ops.JUMP_ABSOLUTE, start, True)
        self.use_next_block(anchor)

    def _comp_async_generator(self, node, generators, gen_index):
        b_start = self.new_block()
        b_except = self.new_block()
        b_if_cleanup = self.new_block()
        gen = generators[gen_index]
        assert isinstance(gen, ast.comprehension)
        if gen_index > 0:
            gen.iter.walkabout(self)
            self.emit_op(ops.GET_AITER)

        self.use_next_block(b_start)

        self.emit_jump(ops.SETUP_EXCEPT, b_except)
        self.emit_op(ops.GET_ANEXT)
        self.load_const(self.space.w_None)
        self.emit_op(ops.YIELD_FROM)
        self.emit_op(ops.POP_BLOCK)
        gen.target.walkabout(self)

        if gen.ifs:
            for if_ in gen.ifs:
                if_.accept_jump_if(self, False, b_if_cleanup)
                self.use_next_block()
        gen_index += 1

        if gen_index < len(generators):
            self._comp_generator(node, generators, gen_index)
        else:
            node.accept_comp_iteration(self, gen_index)

        self.use_next_block(b_if_cleanup)
        self.emit_jump(ops.JUMP_ABSOLUTE, b_start, True)

        self.use_next_block(b_except)
        self.emit_op(ops.END_ASYNC_FOR)

    def _compile_comprehension(self, node, name, sub_scope):
        is_async_function = self.scope.is_coroutine
        code, qualname = self.sub_scope(sub_scope, name, node, node.lineno)
        is_async_comprehension = self.symbols.find_scope(node).is_coroutine
        if is_async_comprehension and not is_async_function:
            if not isinstance(node, ast.GeneratorExp):
                if self.allows_top_level_await():
                    self.is_async_seen = True
                else:
                    self.error("asynchronous comprehension outside of "
                               "an asynchronous function", node)

        self.update_position(node.lineno)
        self._make_function(code, qualname=qualname)
        first_comp = node.get_generators()[0]
        assert isinstance(first_comp, ast.comprehension)
        first_comp.iter.walkabout(self)
        if first_comp.is_async:
            self.emit_op(ops.GET_AITER)
        else:
            self.emit_op(ops.GET_ITER)
        self.emit_op_arg(ops.CALL_FUNCTION, 1)
        if is_async_comprehension and sub_scope is not GenExpCodeGenerator:
            self.emit_op(ops.GET_AWAITABLE)
            self.load_const(self.space.w_None)
            self.emit_op(ops.YIELD_FROM)

    @update_pos_expr
    def visit_GeneratorExp(self, genexp):
        self._compile_comprehension(genexp, "<genexpr>", GenExpCodeGenerator)

    @update_pos_expr
    def visit_SetComp(self, setcomp):
        self._compile_comprehension(setcomp, "<setcomp>",
                                    ComprehensionCodeGenerator)

    @update_pos_expr
    def visit_DictComp(self, dictcomp):
        self._compile_comprehension(dictcomp, "<dictcomp>",
                                    ComprehensionCodeGenerator)

    def check_forbidden_name(self, name, node, ctx=ast.Store):
        if misc.check_forbidden_name(self.space, name):
            if ctx == ast.Store:
                self.error("cannot assign to " + name, node)
            elif ctx == ast.Load:
                # XXX not in CPython, but needed for __debug__ += 1
                pass
            else:
                assert ctx == ast.Del
                self.error("cannot delete " + name, node)

    @update_pos_expr
    def visit_Attribute(self, attr):
        names = self.names
        ctx = attr.ctx
        attr.value.walkabout(self)
        if ctx == ast.Load:
            self.emit_op_name(ops.LOAD_ATTR, names, attr.attr)
            return
        self.check_forbidden_name(attr.attr, attr, ctx)
        if ctx == ast.Store:
            self.emit_op_name(ops.STORE_ATTR, names, attr.attr)
        elif ctx == ast.Del:
            self.emit_op_name(ops.DELETE_ATTR, names, attr.attr)
        else:
            raise AssertionError("unknown context")

    @update_pos_expr
    def visit_Slice(self, slc):
        if slc.lower:
            slc.lower.walkabout(self)
        else:
            self.load_const(self.space.w_None)
        if slc.upper:
            slc.upper.walkabout(self)
        else:
            self.load_const(self.space.w_None)
        arg = 2
        if slc.step:
            slc.step.walkabout(self)
            arg += 1
        self.emit_op_arg(ops.BUILD_SLICE, arg)

    @update_pos_expr
    def visit_Subscript(self, sub):
        ctx = sub.ctx
        if ctx == ast.Load:
            self._check_subscripter(sub.value)
            self._check_index(sub, sub.value, sub.slice)
            op = ops.BINARY_SUBSCR
        elif ctx == ast.Store:
            op = ops.STORE_SUBSCR
        elif ctx == ast.Del:
            op = ops.DELETE_SUBSCR
        else:
            assert 0
        sub.value.walkabout(self)
        sub.slice.walkabout(self)
        self.emit_op(op)

    def _check_subscripter(self, sub):
        if (
            isinstance(sub, ast.Constant)
            and (
                self.space.isinstance_w(sub.value, self.space.w_tuple)
                or self.space.isinstance_w(sub.value, self.space.w_unicode)
                or self.space.isinstance_w(sub.value, self.space.w_bytes)
            )
        ):
            return None
        elif (type(sub) is not ast.Constant and type(sub) is not ast.Set and
              type(sub) is not ast.SetComp and
              type(sub) is not ast.GeneratorExp and
              type(sub) is not ast.Lambda):
            return None

        misc.syntax_warning(
            self.space,
            "'%s' object is not subscriptable; perhaps"
            " you missed a comma?" % sub._get_type_name(self.space),
            self.compile_info.filename,
            sub.lineno,
            sub.col_offset
        )

    def _check_index(self, node, sub, index):
        if not index._literal_type:
            return None

        if isinstance(index, ast.Constant) and self.space.isinstance_w(
            index.value, self.space.w_int
        ):
            return None

        if not (
            isinstance(sub, ast.Constant)
            and (
                self.space.isinstance_w(sub.value, self.space.w_tuple)
                or self.space.isinstance_w(sub.value, self.space.w_unicode)
                or self.space.isinstance_w(sub.value, self.space.w_bytes)
            )
        ):
            return None

        if (
            type(sub) is not ast.Constant and
            type(sub) is not ast.Tuple and
            type(sub) is not ast.List and
            type(sub) is not ast.ListComp and
            type(sub) is not ast.JoinedStr and
            type(sub) is not ast.FormattedValue
        ):
            return None

        # not quotes (on purpose to comply with TypeErrors)
        misc.syntax_warning(
            self.space,
            "%s indices must be integers or slices, "
            "not %s; perhaps you missed a comma?" % (
                sub._get_type_name(self.space),
                index._get_type_name(self.space)
            ),
            self.compile_info.filename,
            node.lineno,
            node.col_offset
        )

    @update_pos_expr
    def visit_JoinedStr(self, joinedstr):
        for node in joinedstr.values:
            node.walkabout(self)
        if len(joinedstr.values) != 1:
            self.emit_op_arg(ops.BUILD_STRING, len(joinedstr.values))

    @update_pos_expr
    def visit_FormattedValue(self, fmt):
        fmt.value.walkabout(self)
        arg = 0
        if fmt.conversion == ord('s'): arg = consts.FVC_STR
        if fmt.conversion == ord('r'): arg = consts.FVC_REPR
        if fmt.conversion == ord('a'): arg = consts.FVC_ASCII
        if fmt.format_spec is not None:
            arg |= consts.FVS_HAVE_SPEC
            fmt.format_spec.walkabout(self)
        self.emit_op_arg(ops.FORMAT_VALUE, arg)

    @update_pos_expr
    def visit_NamedExpr(self, namedexpr):
        namedexpr.value.walkabout(self)
        self.emit_op(ops.DUP_TOP)
        namedexpr.target.walkabout(self)

    def _revdb_metavar(self, node):
        # moved in its own function for the import statement
        from pypy.interpreter.reverse_debugging import dbstate
        if not dbstate.standard_code:
            self.emit_op_arg(ops.LOAD_REVDB_VAR, node.metavar)
            return True
        return False

    @update_pos_expr
    def visit_RevDBMetaVar(self, node):
        if self.space.reverse_debugging and self._revdb_metavar(node):
            return
        self.error("Unknown character ('$NUM' is only valid in the "
                   "reverse-debugger)", node)

    def allows_top_level_await(self):
        return (
            self._allow_top_level_await
            and isinstance(self.scope, symtable.ModuleScope)
        )


class TopLevelCodeGenerator(PythonCodeGenerator):

    def __init__(self, space, tree, symbols, compile_info):
        self.is_async_seen = False
        PythonCodeGenerator.__init__(self, space, "<module>", tree, -1,
                                     symbols, compile_info, qualname=None)

    def _compile(self, tree):
        if isinstance(tree, ast.Module):
            if tree.body:
                self.first_lineno = tree.body[0].lineno
            else:
                self.first_lineno = self.lineno = 1

        self._maybe_setup_annotations()
        tree.walkabout(self)

    def _get_code_flags(self):
        flags = 0
        if not self.cell_vars and not self.free_vars:
            flags |= consts.CO_NOFREE
        if self.scope.doc_removable:
            flags |= consts.CO_KILL_DOCSTRING
        if self.is_async_seen:
            flags |= consts.CO_COROUTINE
        return flags

    def _check_async_function(self):
        top_level = self.allows_top_level_await()
        if top_level:
            self.is_async_seen = True
        return top_level


class AbstractFunctionCodeGenerator(PythonCodeGenerator):

    def _get_code_flags(self):
        scope = self.scope
        assert isinstance(scope, symtable.FunctionScope)
        flags = consts.CO_NEWLOCALS
        if scope.optimized:
            flags |= consts.CO_OPTIMIZED
        if scope.nested:
            flags |= consts.CO_NESTED
        if scope.is_generator and not scope.is_coroutine:
            flags |= consts.CO_GENERATOR
        if not scope.is_generator and scope.is_coroutine:
            flags |= consts.CO_COROUTINE
        if scope.is_generator and scope.is_coroutine:
            flags |= consts.CO_ASYNC_GENERATOR
        if scope.has_yield_inside_try:
            flags |= consts.CO_YIELD_INSIDE_TRY
        if scope.has_variable_arg:
            flags |= consts.CO_VARARGS
        if scope.has_keywords_arg:
            flags |= consts.CO_VARKEYWORDS
        if scope.doc_removable:
            flags |= consts.CO_KILL_DOCSTRING
        if not self.cell_vars and not self.free_vars:
            flags |= consts.CO_NOFREE
        return PythonCodeGenerator._get_code_flags(self) | flags

    def _init_argcounts(self, args):
        if args.posonlyargs:
            self.argcount += len(args.posonlyargs)
            self.posonlyargcount = len(args.posonlyargs)
        if args.args:
            self.argcount += len(args.args)
        if args.kwonlyargs:
            self.kwonlyargcount = len(args.kwonlyargs)


class FunctionCodeGenerator(AbstractFunctionCodeGenerator):

    def _compile(self, func):
        assert isinstance(func, ast.FunctionDef)
        self.first_lineno = func.lineno
        if func.decorator_list and func.decorator_list[0].lineno > 0:
            self.first_lineno = func.decorator_list[0].lineno
        has_docstring = self.ensure_docstring_constant(func.body)
        args = func.args
        assert isinstance(args, ast.arguments)
        self._init_argcounts(args)
        start = 1 if has_docstring else 0
        self._visit_body(func.body, start)

class AsyncFunctionCodeGenerator(AbstractFunctionCodeGenerator):

    def _compile(self, func):
        assert isinstance(func, ast.AsyncFunctionDef)
        self.first_lineno = func.lineno
        if func.decorator_list and func.decorator_list[0].lineno > 0:
            self.first_lineno = func.decorator_list[0].lineno
        has_docstring = self.ensure_docstring_constant(func.body)
        args = func.args
        assert isinstance(args, ast.arguments)
        self._init_argcounts(args)
        start = 1 if has_docstring else 0
        self._visit_body(func.body, start)

    def _check_async_function(self):
        return True

class LambdaCodeGenerator(AbstractFunctionCodeGenerator):

    def _compile(self, lam):
        assert isinstance(lam, ast.Lambda)
        args = lam.args
        assert isinstance(args, ast.arguments)
        self._init_argcounts(args)
        # Prevent a string from being the first constant and thus a docstring.
        self.add_const(self.space.w_None)
        lam.body.walkabout(self)
        self.emit_op(ops.RETURN_VALUE)


class ComprehensionCodeGenerator(AbstractFunctionCodeGenerator):

    def _compile(self, node):
        self.argcount = 1
        assert isinstance(node, ast.expr)
        self.update_position(node.lineno)
        node.build_container_and_load_iter(self)
        self._comp_generator(node, node.get_generators(), 0)
        self._end_comp()

    def comprehension_load_iter(self):
        self.emit_op_arg(ops.LOAD_FAST, 0)

    def _end_comp(self):
        self.emit_op(ops.RETURN_VALUE)

    def _check_async_function(self):
        return True


class GenExpCodeGenerator(ComprehensionCodeGenerator):

    def _end_comp(self):
        pass

    def _get_code_flags(self):
        flags = ComprehensionCodeGenerator._get_code_flags(self)
        return flags | consts.CO_GENERATOR


class ClassCodeGenerator(PythonCodeGenerator):

    def _compile(self, cls):
        assert isinstance(cls, ast.ClassDef)
        self.ensure_docstring_constant(cls.body)
        self.first_lineno = cls.lineno
        if cls.decorator_list and cls.decorator_list[0].lineno > 0:
            self.first_lineno = cls.decorator_list[0].lineno
        self.lineno = self.first_lineno
        self.argcount = 1
        # load (global) __name__ ...
        self.name_op("__name__", ast.Load, None)
        # ... and store it as __module__
        self.name_op("__module__", ast.Store, None)
        # store the qualname
        w_qualname = self.space.newtext(self.qualname)
        self.load_const(w_qualname)
        self.name_op("__qualname__", ast.Store, None)
        self._maybe_setup_annotations()
        # compile the body proper
        self._handle_body(cls.body)
        # return the (empty) __class__ cell
        scope = self.scope.lookup("__class__")
        if scope == symtable.SCOPE_CELL_CLASS:
            # Return the cell where to store __class__
            self.emit_op_arg(ops.LOAD_CLOSURE, self.cell_vars["__class__"])
            self.emit_op(ops.DUP_TOP)
            self.name_op("__classcell__", ast.Store, None)
        else:
            # This happens when nobody references the cell
            self.load_const(self.space.w_None)
        self.emit_op(ops.RETURN_VALUE)

    def _get_code_flags(self):
        flags = 0
        if self.scope.doc_removable:
            flags |= consts.CO_KILL_DOCSTRING
        return PythonCodeGenerator._get_code_flags(self) | flags


class CallCodeGenerator(object):
    def __init__(self, codegenerator, nargs_pushed, args, keywords):
        self.space = codegenerator.space
        self.codegenerator = codegenerator
        self.nargs_pushed = nargs_pushed
        self.args = args
        self.keywords = keywords

        self.have_starargs = False
        # the number of dictionaries on the stack
        self.have_kwargs = False
        self.keyword_names_w = []
        self.seen_keyword_names = {}

    def _make_starargs_list(self):
        if not self.have_starargs:
            self.codegenerator.emit_op_arg(ops.BUILD_LIST, self.nargs_pushed)
            self.have_starargs = True
            self.nargs_pushed = 0
        else:
            assert self.nargs_pushed == 0

    def _push_args(self):
        if len(self.args) == 1 and not self.nargs_pushed:
            arg = self.args[0]
            if isinstance(arg, ast.Starred):
                arg.value.walkabout(self.codegenerator)
                self.have_starargs = True
                return

        for elt in self.args:
            if isinstance(elt, ast.Starred):
                # we have a *arg
                self._make_starargs_list()
                elt.value.walkabout(self.codegenerator)
                self.codegenerator.emit_op_arg(ops.LIST_EXTEND, 1)
                continue
            if self.nargs_pushed >= MAX_STACKDEPTH_CONTAINERS // 2:
                # stack depth getting too big
                self._make_starargs_list()
            elt.walkabout(self.codegenerator)
            if self.have_starargs:
                self.codegenerator.emit_op_arg(ops.LIST_APPEND, 1)
            else:
                self.nargs_pushed += 1
        if self.have_starargs:
            self.codegenerator.emit_op(ops.LIST_TO_TUPLE)

    def _pack_kwargs_into_dict(self):
        if self.keyword_names_w:
            self.codegenerator._load_constant_tuple(self.keyword_names_w)
            # XXX use BUILD_MAP for size 1?
            self.codegenerator.emit_op_arg(ops.BUILD_CONST_KEY_MAP, len(self.keyword_names_w))
            self.keyword_names_w = []
            if self.have_kwargs: # we already have a map, merge the new one in
                self.codegenerator.emit_op(ops.DICT_MERGE)
            self.have_kwargs = True

    def _push_kwargs(self):
        if len(self.keywords) == 1:
            kw = self.keywords[0]
            assert isinstance(kw, ast.keyword)
            if kw.arg is None:
                # exactly a **kwarg, no need to copy dicts around
                # (cpython cannot do this, because the call machinery really
                # *needs* a dict. but in argument.py deals with non-dicts just
                # fine)
                kw.value.walkabout(self.codegenerator)
                self.have_kwargs = True
                return
        for kw in self.keywords:
            assert isinstance(kw, ast.keyword)
            self.codegenerator.check_forbidden_name(kw.arg, kw)
            if kw.arg is None:
                # if we see **args or if the number of keywords is huge,
                # pack up keywords on the stack so far
                self._pack_kwargs_into_dict()
                if not self.have_kwargs:
                    # no kwargs, build an empty dict
                    self.codegenerator.emit_op_arg(ops.BUILD_MAP, 0)
                kw.value.walkabout(self.codegenerator)
                self.codegenerator.emit_op(ops.DICT_MERGE)
                self.have_kwargs = True
                continue
            if kw.arg in self.seen_keyword_names:
                self.codegenerator.error(
                        "keyword argument repeated: '%s'" % (kw.arg, ), kw)
            self.seen_keyword_names[kw.arg] = None
            if len(self.keyword_names_w) > MAX_STACKDEPTH_CONTAINERS // 2:
                self._pack_kwargs_into_dict()
            w_name = self.space.newtext(kw.arg)
            self.keyword_names_w.append(misc.intern_if_common_string(self.space, w_name))
            kw.value.walkabout(self.codegenerator)

    def _make_starargs_at_end(self):
        if self.nargs_pushed == 0:
            self.codegenerator._load_constant_tuple([])
        else:
            self.codegenerator.emit_op_arg(ops.BUILD_TUPLE, self.nargs_pushed)
        self.have_starargs = True

    def _push_tuple_positional_args_if_necessary(self):
        if self.have_starargs:
            # can't use CALL_FUNCTION_KW anyway, because we already have a
            # tuple as the positional args
            return
        # we might get away with using CALL_FUNCTION_KW if there are no **kwargs
        for kw in self.keywords:
            assert isinstance(kw, ast.keyword)
            if kw.arg is None:
                # we found a **kwarg, thus we're using CALL_FUNCTION_EX, we
                # need to pack up positional arguments first
                self._make_starargs_at_end()
                break
        if not self.have_starargs and len(self.keywords) > MAX_STACKDEPTH_CONTAINERS // 2:
            # we have a huge amount of keyword args, thus we also need to use
            # CALL_FUNCTION_EX
            self._make_starargs_at_end()

    def emit_call(self):
        keywords = self.keywords
        codegenerator = self.codegenerator
        space = self.space
        if self.args is not None:
            self._push_args()

        # Repeat procedure for keyword args
        if keywords is None or len(keywords) == 0:
            if not self.have_starargs:
                # no *args, no keyword args, no **kwargs
                codegenerator.emit_op_arg(ops.CALL_FUNCTION, self.nargs_pushed)
                return
        else:
            self._push_tuple_positional_args_if_necessary()
            self._push_kwargs()

        if not self.have_kwargs and not self.have_starargs:
            # can use CALL_FUNCTION_KW
            assert len(self.keyword_names_w) > 0 # otherwise we would have used CALL_FUNCTION
            codegenerator._load_constant_tuple(self.keyword_names_w)
            codegenerator.emit_op_arg(ops.CALL_FUNCTION_KW, self.nargs_pushed + len(self.keyword_names_w))
        else:
            self._pack_kwargs_into_dict()
            codegenerator.emit_op_arg(ops.CALL_FUNCTION_EX, int(self.have_kwargs))

