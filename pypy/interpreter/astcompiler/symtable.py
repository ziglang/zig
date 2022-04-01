"""
Symbol tabling building.
"""

from pypy.interpreter.astcompiler import ast, consts, misc
from pypy.interpreter.pyparser.error import SyntaxError

# These are for internal use only:
SYM_BLANK = 0
SYM_GLOBAL = 1
SYM_ASSIGNED = 2  # (DEF_LOCAL in CPython3). Or deleted actually.
SYM_PARAM = 2 << 1
SYM_NONLOCAL = 2 << 2
SYM_USED = 2 << 3
SYM_ANNOTATED = 2 << 4
SYM_COMP_ITER = 2 << 5
SYM_BOUND = (SYM_PARAM | SYM_ASSIGNED)

# codegen.py actually deals with these:
SCOPE_UNKNOWN = 0
SCOPE_GLOBAL_IMPLICIT = 1
SCOPE_GLOBAL_EXPLICIT = 2
SCOPE_LOCAL = 3
SCOPE_FREE = 4
SCOPE_CELL = 5
SCOPE_CELL_CLASS = 6     # for "__class__" inside class bodies only


class Scope(object):

    can_be_optimized = False
    is_coroutine = False

    def __init__(self, name, lineno=0, col_offset=0):
        self.lineno = lineno
        self.col_offset = col_offset
        self.parent = None
        self.name = name
        self.optimized = False
        self.symbols = None
        self.roles = {}
        self.varnames = []
        self.children = []
        self.free_vars = []    # a bag of names: the order doesn't matter here
        self.temp_name_counter = 1
        self.has_free = False
        self.child_has_free = False
        self.nested = False
        self.doc_removable = False
        self.contains_annotated = False
        self.nonlocal_directives = {} # name -> ast node
        self._in_try_body_depth = 0
        self.comp_iter_target = False
        self.comp_iter_expr = 0

    def error(self, msg, ast_node=None):
        if ast_node is None:
            lineno = self.lineno
            col_offset = self.col_offset
        else:
            lineno = ast_node.lineno
            col_offset = ast_node.col_offset
        raise SyntaxError(msg, lineno, col_offset)

    def lookup(self, name):
        """Find the scope of identifier 'name'."""
        return self.symbols.get(self.mangle(name), SCOPE_UNKNOWN)

    def lookup_role(self, name):
        return self.roles.get(self.mangle(name), SYM_BLANK)

    def new_temporary_name(self):
        """Return the next temporary name.

        This must be in sync with PythonCodeGenerator's counter.
        """
        self.note_symbol("_[%d]" % (self.temp_name_counter,), SYM_ASSIGNED)
        self.temp_name_counter += 1

    def note_symbol(self, identifier, role, ast_node=None):
        """Record that identifier occurs in this scope."""
        mangled = self.mangle(identifier)
        new_role = role
        if mangled in self.roles:
            old_role = self.roles[mangled]
            if old_role & SYM_PARAM and role & SYM_PARAM:
                err = "duplicate argument '%s' in function definition" % \
                    (identifier,)
                self.error(err, ast_node)
            new_role |= old_role
        if self.comp_iter_target:
            if new_role & (SYM_GLOBAL | SYM_NONLOCAL):
                raise SyntaxError(
                    "comprehension inner loop cannot rebind assignment expression target '%s'" % identifier,
                    self.lineno, self.col_offset)
            new_role |= SYM_COMP_ITER
        self.roles[mangled] = new_role
        if role & SYM_PARAM:
            self.varnames.append(mangled)
        return mangled

    def note_try_start(self, try_node):
        """Called when a try is found, before visiting the body."""
        self._in_try_body_depth += 1

    def note_try_end(self, try_node):
        """Called after visiting a try body."""
        self._in_try_body_depth -= 1

    def note_yield(self, yield_node):
        """Called when a yield is found."""
        self.error("'yield' outside function", yield_node)

    def note_yieldFrom(self, yieldFrom_node):
        """Called when a yield from is found."""
        self.error("'yield' outside function", yieldFrom_node)

    def note_await(self, await_node):
        """Called when await is found."""
        self.error("'await' outside function", await_node)

    def note_return(self, ret):
        """Called when a return statement is found."""
        self.error("return outside function", ret)

    def note_import_star(self, imp):
        """Called when a star import is found."""
        return False

    def mangle(self, name):
        if self.parent:
            return self.parent.mangle(name)
        else:
            return name

    def add_child(self, child_scope):
        """Note a new child scope."""
        child_scope.parent = self
        self.children.append(child_scope)
        # like CPython, disallow *all* assignment expressions in the outermost
        # iterator expression of a comprehension, even those inside a nested
        # comprehension or a lambda expression.
        child_scope.comp_iter_expr = self.comp_iter_expr

    def _finalize_name(self, name, flags, local, bound, free, globs):
        """Decide on the scope of a name."""
        if flags & SYM_GLOBAL:
            self.symbols[name] = SCOPE_GLOBAL_EXPLICIT
            globs[name] = None
            if bound:
                try:
                    del bound[name]
                except KeyError:
                    pass
        elif flags & SYM_NONLOCAL:
            if name not in bound:
                err = "no binding for nonlocal '%s' found" % (name,)
                self.error(err, self.nonlocal_directives.get(name, None))
            self.symbols[name] = SCOPE_FREE
            if not self._hide_bound_from_nested_scopes:
                self.free_vars.append(name)
            free[name] = None
            self.has_free = True
        elif flags & (SYM_BOUND | SYM_ANNOTATED):
            self.symbols[name] = SCOPE_LOCAL
            local[name] = None
            try:
                del globs[name]
            except KeyError:
                pass
        elif bound and name in bound:
            self.symbols[name] = SCOPE_FREE
            self.free_vars.append(name)
            free[name] = None
            self.has_free = True
        elif name in globs:
            self.symbols[name] = SCOPE_GLOBAL_IMPLICIT
        else:
            if self.nested:
                self.has_free = True
            self.symbols[name] = SCOPE_GLOBAL_IMPLICIT

    def _pass_on_bindings(self, local, bound, globs, new_bound, new_globs):
        """Allow child scopes to see names bound here and in outer scopes."""
        new_globs.update(globs)
        if bound:
            new_bound.update(bound)

    def _finalize_cells(self, free):
        """Hook for FunctionScope."""
        pass

    def _check_optimization(self):
        pass

    _hide_bound_from_nested_scopes = False

    def finalize(self, bound, free, globs):
        """Enter final bookeeping data in to self.symbols."""
        self.symbols = {}
        local = {}
        new_globs = {}
        new_bound = {}
        new_free = {}
        if self._hide_bound_from_nested_scopes:
            self._pass_on_bindings(local, bound, globs, new_bound, new_globs)
        for name, flags in self.roles.iteritems():
            self._finalize_name(name, flags, local, bound, free, globs)
        if not self._hide_bound_from_nested_scopes:
            self._pass_on_bindings(local, bound, globs, new_bound, new_globs)
        else:
            self._pass_special_names(local, new_bound)
        child_frees = {}
        for child in self.children:
            # Symbol dictionaries are copied to avoid having child scopes
            # pollute each other's.
            child_free = new_free.copy()
            child.finalize(new_bound.copy(), child_free, new_globs.copy())
            child_frees.update(child_free)
            if child.has_free or child.child_has_free:
                self.child_has_free = True
        new_free.update(child_frees)
        self._finalize_cells(new_free)
        for name in new_free:
            try:
                role_here = self.roles[name]
            except KeyError:
                if bound and name in bound:
                    self.symbols[name] = SCOPE_FREE
                    self.free_vars.append(name)
            else:
                if role_here & (SYM_BOUND | SYM_GLOBAL) and \
                        self._hide_bound_from_nested_scopes and \
                        not role_here & SYM_NONLOCAL:
                    # This happens when a class level attribute or method has
                    # the same name as a free variable passing through the class
                    # scope.  We add the name to the class scope's list of free
                    # vars, so it will be passed through by the interpreter, but
                    # we leave the scope alone, so it can be local on its own.
                    self.free_vars.append(name)
        self._check_optimization()
        free.update(new_free)


class ModuleScope(Scope):

    def __init__(self, allow_top_level_await=False):
        Scope.__init__(self, "<top-level>")
        self.allow_top_level_await = allow_top_level_await

    def note_await(self, await_node):
        if not self.allow_top_level_await:
            Scope.note_await(self, await_node)

class FunctionScope(Scope):

    can_be_optimized = True

    def __init__(self, name, lineno, col_offset):
        Scope.__init__(self, name, lineno, col_offset)
        self.has_variable_arg = False
        self.has_keywords_arg = False
        self.is_generator = False
        self.has_yield_inside_try = False
        self.optimized = True
        self.return_with_value = False
        self.import_star = None

    def note_symbol(self, identifier, role, ast_node=None):
        # Special-case super: it counts as a use of __class__
        if role == SYM_USED and identifier == 'super':
            self.note_symbol('__class__', SYM_USED, ast_node)
        return Scope.note_symbol(self, identifier, role, ast_node)

    def note_yield(self, yield_node):
        self.is_generator = True
        if self._in_try_body_depth > 0:
            self.has_yield_inside_try = True

    def note_yieldFrom(self, yield_node):
        self.is_generator = True
        if self._in_try_body_depth > 0:
            self.has_yield_inside_try = True

    def note_await(self, await_node):
        self.is_coroutine = True

    def note_return(self, ret):
        if ret.value:
            if self.is_coroutine and self.is_generator:
                self.error("'return' with value in async generator", ret)
            self.return_with_value = True
            self.ret = ret

    def note_import_star(self, imp):
        return True

    def note_variable_arg(self, vararg):
        self.has_variable_arg = True

    def note_keywords_arg(self, kwarg):
        self.has_keywords_arg = True

    def add_child(self, child_scope):
        Scope.add_child(self, child_scope)
        child_scope.nested = True

    def _pass_on_bindings(self, local, bound, globs, new_bound, new_globs):
        new_bound.update(local)
        Scope._pass_on_bindings(self, local, bound, globs, new_bound,
                                new_globs)

    def _finalize_cells(self, free):
        for name, role in self.symbols.iteritems():
            if role == SCOPE_LOCAL and name in free:
                self.symbols[name] = SCOPE_CELL
                del free[name]

    def _check_optimization(self):
        if (self.has_free or self.child_has_free) and not self.optimized:
            raise AssertionError("unknown reason for unoptimization")


class AsyncFunctionScope(FunctionScope):

    def __init__(self, name, lineno, col_offset):
        FunctionScope.__init__(self, name, lineno, col_offset)
        self.is_coroutine = True

    def note_yieldFrom(self, yield_node):
        self.error("'yield from' inside async function", yield_node)


class ComprehensionScope(FunctionScope):
    pass

class ClassScope(Scope):

    _hide_bound_from_nested_scopes = True

    def __init__(self, clsdef):
        Scope.__init__(self, clsdef.name, clsdef.lineno, clsdef.col_offset)

    def mangle(self, name):
        return misc.mangle(name, self.name)

    def _pass_special_names(self, local, new_bound):
        #assert '__class__' in local
        new_bound['__class__'] = None

    def _finalize_cells(self, free):
        for name, role in self.symbols.iteritems():
            if role == SCOPE_LOCAL and name in free and name == '__class__':
                self.symbols[name] = SCOPE_CELL_CLASS
                del free[name]


class SymtableBuilder(ast.GenericASTVisitor):
    """Find symbol information from AST."""

    def __init__(self, space, module, compile_info):
        self.space = space
        self.module = module
        self.compile_info = compile_info
        self.scopes = {}
        self.scope = None
        self.stack = []
        allow_top_level_await = compile_info.flags & consts.PyCF_ALLOW_TOP_LEVEL_AWAIT
        top = ModuleScope(allow_top_level_await=allow_top_level_await)
        self.globs = top.roles
        self.push_scope(top, module)
        try:
            module.walkabout(self)
            top.finalize(None, {}, {})
        except SyntaxError as e:
            e.filename = compile_info.filename
            raise
        self.pop_scope()
        assert not self.stack

    def error(self, msg, node):
        # NB: SyntaxError's offset is 1-based!
        raise SyntaxError(msg, node.lineno, node.col_offset + 1,
                          filename=self.compile_info.filename)

    def push_scope(self, scope, node):
        """Push a child scope."""
        if self.stack:
            self.stack[-1].add_child(scope)
        self.stack.append(scope)
        self.scopes[node] = scope
        # Convenience
        self.scope = scope

    def pop_scope(self):
        self.stack.pop()
        if self.stack:
            self.scope = self.stack[-1]
        else:
            self.scope = None

    def find_scope(self, scope_node):
        """Lookup the scope for a given AST node."""
        return self.scopes[scope_node]

    def implicit_arg(self, pos):
        """Note a implicit arg for implicit tuple unpacking."""
        name = ".%d" % (pos,)
        self.note_symbol(name, SYM_PARAM)

    def note_symbol(self, identifier, role, ast_node=None):
        """Note the identifer on the current scope."""
        mangled = self.scope.note_symbol(identifier, role, ast_node)
        if role & SYM_GLOBAL:
            if mangled in self.globs:
                role |= self.globs[mangled]
            self.globs[mangled] = role

    def visit_FunctionDef(self, func):
        self.note_symbol(func.name, SYM_ASSIGNED)
        # Function defaults and decorators happen in the outer scope.
        args = func.args
        assert isinstance(args, ast.arguments)
        self.visit_sequence(args.defaults)
        self.visit_kwonlydefaults(args.kw_defaults)
        self._visit_annotations(func)
        self.visit_sequence(func.decorator_list)
        new_scope = FunctionScope(func.name, func.lineno, func.col_offset)
        self.push_scope(new_scope, func)
        func.args.walkabout(self)
        self.visit_sequence(func.body)
        self.pop_scope()

    def visit_AsyncFunctionDef(self, func):
        self.note_symbol(func.name, SYM_ASSIGNED)
        # Function defaults and decorators happen in the outer scope.
        args = func.args
        assert isinstance(args, ast.arguments)
        self.visit_sequence(args.defaults)
        self.visit_kwonlydefaults(args.kw_defaults)
        self._visit_annotations(func)
        self.visit_sequence(func.decorator_list)
        new_scope = AsyncFunctionScope(func.name, func.lineno, func.col_offset)
        self.push_scope(new_scope, func)
        func.args.walkabout(self)
        self.visit_sequence(func.body)
        self.pop_scope()

    def visit_Await(self, aw):
        self.scope.note_await(aw)
        ast.GenericASTVisitor.visit_Await(self, aw)

    def visit_Return(self, ret):
        self.scope.note_return(ret)
        ast.GenericASTVisitor.visit_Return(self, ret)

    def visit_AnnAssign(self, assign):
        # __annotations__ is not setup or used in functions.
        if not isinstance(self.scope, FunctionScope):
            self.scope.contains_annotated = True
        target = assign.target
        if isinstance(target, ast.Name):
            name = target.id
            old_role = self.scope.lookup_role(name)
            if assign.simple:
                if old_role & SYM_GLOBAL:
                    self.error(
                        "annotated name '%s' can't be global" % name,
                        assign)
                if old_role & SYM_NONLOCAL:
                    self.error(
                        "annotated name '%s' can't be nonlocal" % name,
                        assign)
            scope = SYM_BLANK
            if assign.simple:
                scope |= SYM_ANNOTATED
            if assign.value:
                scope |= SYM_ASSIGNED
            if scope:
                self.note_symbol(name, scope)
        else:
            target.walkabout(self)
        if assign.value is not None:
            assign.value.walkabout(self)
        if assign.annotation is not None:
            assign.annotation.walkabout(self)

    def visit_ClassDef(self, clsdef):
        self.note_symbol(clsdef.name, SYM_ASSIGNED)
        self.visit_sequence(clsdef.bases)
        self.visit_sequence(clsdef.keywords)
        self.visit_sequence(clsdef.decorator_list)
        self.push_scope(ClassScope(clsdef), clsdef)
        self.note_symbol('__class__', SYM_ASSIGNED)
        self.note_symbol('__locals__', SYM_PARAM)
        self.visit_sequence(clsdef.body)
        self.pop_scope()

    def visit_ImportFrom(self, imp):
        for alias in imp.names:
            if self._visit_alias(alias):
                if self.scope.note_import_star(imp):
                    msg = "import * only allowed at module level"
                    self.error(msg, imp)

    def _visit_alias(self, alias):
        assert isinstance(alias, ast.alias)
        if alias.asname:
            store_name = alias.asname
        else:
            store_name = alias.name
            if store_name == "*":
                return True
            dot = store_name.find(".")
            if dot > 0:
                store_name = store_name[:dot]
        self.note_symbol(store_name, SYM_ASSIGNED)
        return False

    def visit_alias(self, alias):
        self._visit_alias(alias)

    def visit_ExceptHandler(self, handler):
        if handler.name:
            self.note_symbol(handler.name, SYM_ASSIGNED)
        ast.GenericASTVisitor.visit_ExceptHandler(self, handler)

    def visit_Yield(self, yie):
        self.scope.note_yield(yie)
        ast.GenericASTVisitor.visit_Yield(self, yie)

    def visit_YieldFrom(self, yfr):
        self.scope.note_yieldFrom(yfr)
        ast.GenericASTVisitor.visit_YieldFrom(self, yfr)

    def visit_Global(self, glob):
        for name in glob.names:
            old_role = self.scope.lookup_role(name)
            if (self.scope._hide_bound_from_nested_scopes and
                   name == '__class__'):
                msg = ("'global __class__' inside a class statement is not "
                       "implemented in PyPy")
                self.error(msg, glob)
            if old_role & SYM_PARAM:
                msg = "name '%s' is parameter and global" % (name,)
                self.error(msg, glob)
            if old_role & SYM_NONLOCAL:
                msg = "name '%s' is nonlocal and global" % (name,)
                self.error(msg, glob)

            if old_role & (SYM_USED | SYM_ASSIGNED | SYM_ANNOTATED):
                if old_role & SYM_ASSIGNED:
                    msg = "name '%s' is assigned to before global declaration"\
                        % (name,)
                elif old_role & SYM_ANNOTATED:
                    msg = "annotated name '%s' can't be global" \
                        % (name,)
                else:
                    msg = "name '%s' is used prior to global declaration" % \
                        (name,)
                self.error(msg, glob)
            self.note_symbol(name, SYM_GLOBAL)

    def visit_Nonlocal(self, nonl):
        for name in nonl.names:
            old_role = self.scope.lookup_role(name)
            msg = ""
            if old_role & SYM_GLOBAL:
                msg = "name '%s' is nonlocal and global" % (name,)
            if old_role & SYM_PARAM:
                msg = "name '%s' is parameter and nonlocal" % (name,)
            if isinstance(self.scope, ModuleScope):
                msg = "nonlocal declaration not allowed at module level"
            if old_role & SYM_ANNOTATED:
                msg = "annotated name '%s' can't be nonlocal" \
                    % (name,)
            if msg is not "":
                self.error(msg, nonl)

            if (old_role & (SYM_USED | SYM_ASSIGNED) and not
                    (name == '__class__' and
                     self.scope._hide_bound_from_nested_scopes)):
                if old_role & SYM_ASSIGNED:
                    msg = "name '%s' is assigned to before nonlocal declaration" \
                        % (name,)
                else:
                    msg = "name '%s' is used prior to nonlocal declaration" % \
                        (name,)
                self.error(msg, nonl)

            self.note_symbol(name, SYM_NONLOCAL)
            if name not in self.scope.nonlocal_directives:
                self.scope.nonlocal_directives[name] = nonl

    def visit_Lambda(self, lamb):
        args = lamb.args
        assert isinstance(args, ast.arguments)
        self.visit_sequence(args.defaults)
        self.visit_kwonlydefaults(args.kw_defaults)
        new_scope = FunctionScope("<lambda>", lamb.lineno, lamb.col_offset)
        self.push_scope(new_scope, lamb)
        lamb.args.walkabout(self)
        lamb.body.walkabout(self)
        self.pop_scope()

    def visit_comprehension(self, comp):
        self.scope.comp_iter_target = True
        comp.target.walkabout(self)
        self.scope.comp_iter_target = False
        self.scope.comp_iter_expr += 1
        comp.iter.walkabout(self)
        self.scope.comp_iter_expr -= 1
        self.visit_sequence(comp.ifs)
        if comp.is_async:
            self.scope.note_await(comp)

    def _visit_comprehension(self, node, kind, comps, *consider):
        outer = comps[0]
        assert isinstance(outer, ast.comprehension)
        self.scope.comp_iter_expr += 1
        outer.iter.walkabout(self)
        self.scope.comp_iter_expr -= 1
        new_scope = ComprehensionScope("<genexpr>", node.lineno, node.col_offset)
        self.push_scope(new_scope, node)
        self.implicit_arg(0)
        new_scope.is_coroutine |= outer.is_async
        new_scope.comp_iter_target = True
        outer.target.walkabout(self)
        new_scope.comp_iter_target = False
        self.visit_sequence(outer.ifs)
        self.visit_sequence(comps[1:])
        for item in list(consider):
            item.walkabout(self)
        self.pop_scope()
        # http://bugs.python.org/issue10544: this became an error in 3.8
        if new_scope.is_generator:
            msg = "'yield' inside %s" % kind
            space = self.space
            self.error(msg, node)

        new_scope.is_generator |= isinstance(node, ast.GeneratorExp)

    def visit_ListComp(self, listcomp):
        self._visit_comprehension(listcomp, "list comprehension", listcomp.generators, listcomp.elt)

    def visit_GeneratorExp(self, genexp):
        self._visit_comprehension(genexp, "generator expression", genexp.generators, genexp.elt)

    def visit_SetComp(self, setcomp):
        self._visit_comprehension(setcomp, "set comprehension", setcomp.generators, setcomp.elt)

    def visit_DictComp(self, dictcomp):
        self._visit_comprehension(dictcomp, "dict comprehension", dictcomp.generators,
                                  dictcomp.value, dictcomp.key)

    def visit_With(self, wih):
        self.scope.new_temporary_name()
        self.visit_sequence(wih.items)
        self.scope.note_try_start(wih)
        self.visit_sequence(wih.body)
        self.scope.note_try_end(wih)

    def visit_withitem(self, witem):
        witem.context_expr.walkabout(self)
        if witem.optional_vars:
            witem.optional_vars.walkabout(self)

    def visit_AsyncWith(self, aw):
        self.scope.new_temporary_name()
        self.visit_sequence(aw.items)
        self.scope.note_try_start(aw)
        self.visit_sequence(aw.body)
        self.scope.note_try_end(aw)

    def visit_arguments(self, arguments):
        scope = self.scope
        assert isinstance(scope, FunctionScope)  # Annotator hint.
        if arguments.posonlyargs:
            self._handle_params(arguments.posonlyargs, True)
        if arguments.args:
            self._handle_params(arguments.args, True)
        if arguments.kwonlyargs:
            self._handle_params(arguments.kwonlyargs, True)
        if arguments.vararg:
            self.check_forbidden_name(arguments.vararg.arg, arguments.vararg)
            self.note_symbol(arguments.vararg.arg, SYM_PARAM)
            scope.note_variable_arg(arguments.vararg)
        if arguments.kwarg:
            self.check_forbidden_name(arguments.kwarg.arg, arguments.kwarg)
            self.note_symbol(arguments.kwarg.arg, SYM_PARAM)
            scope.note_keywords_arg(arguments.kwarg)

    def check_forbidden_name(self, name, node):
        if misc.check_forbidden_name(self.space, name):
            self.error(
                "cannot assign to " + name,
                node)

    def _handle_params(self, params, is_toplevel):
        for param in params:
            assert isinstance(param, ast.arg)
            arg = param.arg
            self.check_forbidden_name(arg, param)
            self.note_symbol(arg, SYM_PARAM, param)

    def _visit_annotations(self, func):
        args = func.args
        assert isinstance(args, ast.arguments)
        if args.posonlyargs:
            self._visit_arg_annotations(args.posonlyargs)
        if args.args:
            self._visit_arg_annotations(args.args)
        if args.vararg:
            self._visit_arg_annotation(args.vararg)
        if args.kwarg:
            self._visit_arg_annotation(args.kwarg)
        if args.kwonlyargs:
            self._visit_arg_annotations(args.kwonlyargs)
        if func.returns:
            func.returns.walkabout(self)

    def _visit_arg_annotations(self, args):
        for arg in args:
            assert isinstance(arg, ast.arg)
            self._visit_arg_annotation(arg)

    def _visit_arg_annotation(self, arg):
        if arg.annotation:
            arg.annotation.walkabout(self)

    def visit_Name(self, name):
        if name.ctx == ast.Load:
            role = SYM_USED
        else:
            role = SYM_ASSIGNED
        self.note_symbol(name.id, role)

    def visit_Try(self, node):
        self.scope.note_try_start(node)
        self.visit_sequence(node.body)
        self.scope.note_try_end(node)
        self.visit_sequence(node.handlers)
        self.visit_sequence(node.orelse)
        self.visit_sequence(node.finalbody)

    def visit_NamedExpr(self, node):
        scope = self.scope
        target = node.target
        assert isinstance(target, ast.Name)
        name = target.id
        if scope.comp_iter_expr > 0:
            self.error(
                "assignment expression cannot be used in a comprehension iterable expression",
                node)
        if isinstance(scope, ComprehensionScope):
            for i in range(len(self.stack) - 1, -1, -1):
                parent = self.stack[i]
                if isinstance(parent, ComprehensionScope):
                    if parent.lookup_role(name) & SYM_COMP_ITER:
                        self.error(
                            "assignment expression cannot rebind comprehension iteration variable '%s'" % name,
                            node)
                    continue

                if isinstance(parent, FunctionScope):
                    parent.note_symbol(name, SYM_ASSIGNED)
                    if parent.lookup_role(name) & SYM_GLOBAL:
                        flag = SYM_GLOBAL
                    else:
                        flag = SYM_NONLOCAL
                    scope.note_symbol(name, flag)
                    break
                elif isinstance(parent, ModuleScope):
                    parent.note_symbol(name, SYM_GLOBAL)
                    scope.note_symbol(name, SYM_GLOBAL)
                elif isinstance(parent, ClassScope):
                    self.error(
                        "assignment expression within a comprehension cannot be used in a class body",
                        node)

        node.target.walkabout(self)
        node.value.walkabout(self)
