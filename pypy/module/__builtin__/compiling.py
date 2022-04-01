"""
Implementation of the interpreter-level compile/eval builtins.
"""

from pypy.interpreter.pycode import PyCode
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.astcompiler import consts, ast
from pypy.interpreter.gateway import unwrap_spec
from pypy.interpreter.argument import Arguments
from pypy.interpreter.nestedscope import Cell
from pypy.interpreter.function import Function

@unwrap_spec(filename='fsencode', mode='text', flags=int, dont_inherit=int,
             optimize=int, _feature_version=int)
def compile(space, w_source, filename, mode, flags=0, dont_inherit=0,
            optimize=-1, _feature_version=-1):
    """Compile the source string (a Python module, statement or expression)
into a code object that can be executed by the exec statement or eval().
The filename will be used for run-time error messages.
The mode must be 'exec' to compile a module, 'single' to compile a
single (interactive) statement, or 'eval' to compile an expression.
The flags argument, if present, controls which future statements influence
the compilation of the code.
The dont_inherit argument, if non-zero, stops the compilation inheriting
the effects of any future statements in effect in the code calling
compile; if absent or zero these statements do influence the compilation,
in addition to any features explicitly specified.
"""
    from pypy.interpreter.pyopcode import source_as_str
    # only allow default value of _feature_version for now
    # we need to support the keyword argument, the ast module passes it (set to
    # -1, usually)
    if _feature_version >= 0 and (flags & consts.PyCF_ONLY_AST):
        feature_version = _feature_version
    else:
        feature_version = -1

    ec = space.getexecutioncontext()
    if flags & ~(ec.compiler.compiler_flags | consts.PyCF_ONLY_AST |
                 consts.PyCF_DONT_IMPLY_DEDENT | consts.PyCF_SOURCE_IS_UTF8 |
                 consts.PyCF_ACCEPT_NULL_BYTES | consts.PyCF_TYPE_COMMENTS |
                 consts.PyCF_ALLOW_TOP_LEVEL_AWAIT):
        raise oefmt(space.w_ValueError, "compile() unrecognized flags")

    only_ast = flags & consts.PyCF_ONLY_AST

    if not dont_inherit:
        caller = ec.gettopframe_nohidden()
        if caller:
            flags |= ec.compiler.getcodeflags(caller.getcode())

    if mode not in ('exec', 'eval', 'single', 'func_type'):
        if only_ast:
            raise oefmt(space.w_ValueError,
                        "compile() mode must be 'exec', 'eval', 'single' or 'func_type'")
        else:
            raise oefmt(space.w_ValueError,
                        "compile() arg 3 must be 'exec', 'eval' or 'single'")

    if mode == "func_type" and not only_ast:
        raise oefmt(space.w_ValueError,
                    "compile() mode 'func_type' requires flag PyCF_ONLY_AST")

    if optimize < -1 or optimize > 2:
        raise oefmt(space.w_ValueError,
            "compile(): invalid optimize value")

    if space.isinstance_w(w_source, space.gettypeobject(ast.W_AST.typedef)):
        if only_ast:
            return w_source
        ast_node = ast.mod.from_object(space, w_source)
        ec.compiler.validate_ast(ast_node)
        return ec.compiler.compile_ast(ast_node, filename, mode, flags,
                                       optimize=optimize)

    flags |= consts.PyCF_SOURCE_IS_UTF8
    source, flags = source_as_str(space, w_source, 'compile',
                                  "string, bytes or AST", flags)

    if only_ast:
        node = ec.compiler.compile_to_ast(source, filename, mode, flags, feature_version)
        return node.to_object(space)
    else:
        return ec.compiler.compile(source, filename, mode, flags,
                                   optimize=optimize)


def eval(space, w_prog, w_globals=None, w_locals=None):
    """Evaluate the source in the context of globals and locals.
The source may be a string representing a Python expression
or a code object as returned by compile().  The globals and locals
are dictionaries, defaulting to the current current globals and locals.
If only globals is given, locals defaults to it.
"""
    from pypy.interpreter.pyopcode import ensure_ns, source_as_str
    w_globals, w_locals = ensure_ns(space, w_globals, w_locals, 'eval')

    if space.isinstance_w(w_prog, space.gettypeobject(PyCode.typedef)):
        code = space.interp_w(PyCode, w_prog)
        space.audit("exec", [w_prog])
    else:
        source, flags = source_as_str(space, w_prog, 'eval',
                                      "string, bytes or code",
                                      consts.PyCF_SOURCE_IS_UTF8)
        ec = space.getexecutioncontext()
        code = ec.compiler.compile(source.lstrip(' \t'), "<string>", 'eval',
                                   flags)
    if space.finditem_str(w_globals, "__builtins__") is None:
        space.setitem_str(w_globals, "__builtins__", space.builtin)

    return code.exec_code(space, w_globals, w_locals)

def exec_(space, w_prog, w_globals=None, w_locals=None):
    """
    exec(source, globals=None, locals=None, /)

    Execute the given source in the context of globals and locals.

    The source may be a string representing one or more Python statements
    or a code object as returned by compile().
    The globals must be a dictionary and locals can be any mapping,
    defaulting to the current globals and locals.
    If only globals is given, locals defaults to it.
    """

    frame = space.getexecutioncontext().gettopframe()
    frame.exec_(w_prog, w_globals, w_locals)

def _update_bases(space, w_bases, bases_w):
    new_bases_w = None
    for i, w_base in enumerate(bases_w):
        if space.isinstance_w(w_base, space.w_type):
            if new_bases_w is not None:
                new_bases_w.append(w_base)
            continue
        w_meth = None
        try:
            # one of the few places where cpython uses getattr not lookup
            w_meth = space.getattr(w_base, space.newtext('__mro_entries__'))
        except OperationError as e:
            if not e.match(space, space.w_AttributeError):
                raise
            if new_bases_w is not None:
                new_bases_w.append(w_base)
        else:
            w_new_base = space.call_function(w_meth, w_bases)
            if not space.isinstance_w(w_new_base, space.w_tuple):
                raise oefmt(space.w_TypeError, "__mro_entries__ must return a tuple")
            if new_bases_w is None:
                new_bases_w = bases_w[:i]
            new_bases_w.extend(space.fixedview(w_new_base))
    if new_bases_w is None:
        return bases_w
    return new_bases_w[:]

def build_class(space, w_func, w_name, __args__):
    from pypy.objspace.std.typeobject import _calculate_metaclass, W_TypeObject
    from pypy.interpreter.nestedscope import Cell
    if not isinstance(w_func, Function):
        raise oefmt(space.w_TypeError, "__build_class__: func must be a function")
    orig_bases_w, kwds_w = __args__.unpack()
    w_orig_bases = space.newtuple(orig_bases_w)
    bases_w = _update_bases(space, w_orig_bases, orig_bases_w)
    w_bases = space.newtuple(bases_w)
    w_meta = kwds_w.pop('metaclass', None)
    if w_meta is not None:
        isclass = space.isinstance_w(w_meta, space.w_type)
    else:
        if bases_w:
            w_meta = space.type(bases_w[0])
        else:
            w_meta = space.w_type
        isclass = True
    if isclass:
        # w_meta is really a class, so check for a more derived
        # metaclass, or possible metaclass conflicts
        w_meta = _calculate_metaclass(space, w_meta, bases_w)

    try:
        w_prep = space.getattr(w_meta, space.newtext("__prepare__"))
    except OperationError as e:
        if not e.match(space, space.w_AttributeError):
            raise
        w_namespace = space.newdict(module=True)
    else:
        # XXX mess
        keyword_names_w = [space.newtext(kwd) for kwd in kwds_w.keys()]
        args = Arguments(space,
                         args_w=[w_name, w_bases],
                         keyword_names_w=keyword_names_w,
                         keywords_w=kwds_w.values())
        w_namespace = space.call_args(w_prep, args)
    if not space.ismapping_w(w_namespace):
        if isclass:
            raise oefmt(space.w_TypeError,
                "%N.__prepare__() must return a mapping, not %T",
                w_meta, w_namespace)
        else:
            raise oefmt(space.w_TypeError,
                "<metaclass>.__prepare__() must return a mapping, not %T",
                w_namespace)

    code = w_func.getcode()
    frame = space.createframe(code, w_func.w_func_globals, w_func)
    frame.setdictscope(w_namespace)
    w_cell = frame.run()
    if bases_w is not orig_bases_w:
        space.setitem(w_namespace, space.newtext("__orig_bases__"), w_orig_bases)
    keyword_names_w = [space.newtext(kwd) for kwd in kwds_w.keys()]
    args = Arguments(space,
                     args_w=[w_name, w_bases, w_namespace],
                     keyword_names_w=keyword_names_w,
                     keywords_w=kwds_w.values())
    try:
        w_class = space.call_args(w_meta, args)
    except OperationError as e:
        # give a more comprehensible error message for TypeErrors
        if e.got_any_traceback():
            raise
        if (not e.match(space, space.w_TypeError) or
                space.is_w(w_meta, space.w_type)):
            raise
        raise oefmt(space.w_TypeError,
            "metaclass found to be '%N', but calling %R "
            "with args (%R, %R, ...) raised %R",
            w_meta, w_meta, w_name, w_bases,
            e.get_w_value(space))
    if isinstance(w_cell, Cell) and isinstance(w_class, W_TypeObject):
        if w_cell.empty():
            raise oefmt(space.w_RuntimeError,
                "__class__ not set defining %S as %S. "
                "Was __classcell__ propagated to type.__new__?",
                    w_name,
                    w_class)

        else:
            w_class_from_cell = w_cell.get()
            if not space.is_w(w_class, w_class_from_cell):
                raise oefmt(
                        space.w_TypeError,
                        "__class__ set to %S defining %S as %S",
                        w_class_from_cell, w_name, w_class)
    return w_class
