"""
Two bytecodes to speed up method calls.  Here is how a method call looks
like: (on the left, without the new bytecodes; on the right, with them)

    <push self>                    <push self>
    LOAD_ATTR       name           LOAD_METHOD   name
    <push arg 0>                   <push arg 0>
    ...                            ...
    <push arg n-1>                 <push arg n-1>
    CALL_FUNCTION   n              CALL_METHOD     n
"""

from pypy.interpreter import function
from rpython.rlib import jit
from pypy.objspace.std.mapdict import LOAD_METHOD_mapdict, \
    LOAD_METHOD_mapdict_fill_cache_method


# This module exports two extra methods for StdObjSpaceFrame implementing
# the LOAD_METHOD and CALL_METHOD opcodes in an efficient way, as well
# as a version of space.call_method() that uses the same approach.
# See pypy.objspace.std.objspace for where these functions are used from.


def LOAD_METHOD(f, nameindex, *ignored):
    from pypy.objspace.std.typeobject import MutableCell
    #   stack before                 after
    #  --------------    --fast-method----fallback-case------------
    #
    #                      w_object       None
    #    w_object    =>    w_function     w_boundmethod_or_whatever
    #   (more stuff)      (more stuff)   (more stuff)
    #
    space = f.space
    w_obj = f.popvalue()

    if not jit.we_are_jitted():
        # mapdict has an extra-fast version of this function
        if LOAD_METHOD_mapdict(f, nameindex, w_obj):
            return

    w_name = f.getname_w(nameindex)
    w_value = None

    w_type = space.type(w_obj)
    if w_type.has_object_getattribute():
        name = space.text_w(w_name)
        # bit of a mess to use these internal functions, but it allows the
        # mapdict caching below to work without an additional lookup
        version_tag = w_type.version_tag()
        if version_tag is None:
            _, w_descr = w_type._lookup_where(name)
            w_descr_cell = None
        else:
            _, w_descr_cell = w_type._pure_lookup_where_with_method_cache(
                name, version_tag)
            w_descr = w_descr_cell
            if isinstance(w_descr, MutableCell):
                w_descr = w_descr.unwrap_cell(space)
        if w_descr is None:
            # this handles directly the common case
            #   module.function(args..)
            w_value = w_obj.getdictvalue(space, name)
            # xxx we could also use the mapdict cache in that case, probably
        else:
            typ = type(w_descr)
            if typ is function.Function or typ is function.FunctionWithFixedCode:
                w_value = w_obj.getdictvalue(space, name)
                if w_value is None:
                    # fast method path: a function object in the class,
                    # nothing in the instance
                    f.pushvalue(w_descr)
                    f.pushvalue(w_obj)
                    if not jit.we_are_jitted():
                        # let mapdict cache stuff
                        LOAD_METHOD_mapdict_fill_cache_method(
                            space, f.getcode(), name, nameindex, w_obj, w_type,
                            w_descr_cell)
                    return
    if w_value is None:
        w_value = space.getattr(w_obj, w_name)
    f.pushvalue(w_value)
    f.pushvalue_none()

@jit.unroll_safe
def CALL_METHOD(f, oparg, *ignored):
    # opargs contains the arg, and kwarg count, excluding the implicit 'self'
    n_args = oparg
    w_self = f.peekvalue_maybe_none(n_args)
    n = n_args + (w_self is not None)

    w_callable = f.peekvalue(n_args + 1)
    try:
        w_result = f.space.call_valuestack(
                w_callable, n, f, methodcall=w_self is not None)
    finally:
        f.dropvalues(n_args + 2)
    f.pushvalue(w_result)

@jit.unroll_safe
def CALL_METHOD_KW(f, n_arguments, *ignored):
    from pypy.objspace.std.tupleobject import W_AbstractTupleObject
    # opargs contains the arg + kwarg count, excluding the implicit 'self'
    w_self = f.peekvalue_maybe_none(n_arguments + 1)

    space = f.space
    # like in BUILD_CONST_KEY_MAP we can't use space.fixedview because then
    # the immutability of the tuple is lost
    w_tup_varnames = space.interp_w(W_AbstractTupleObject, f.popvalue())
    n_keywords = space.len_w(w_tup_varnames)
    keyword_names_w = [None] * n_keywords
    keywords_w = [None] * n_keywords
    for i in range(n_keywords):
        keyword_names_w[i] = w_tup_varnames.getitem(space, i)
        w_value = f.peekvalue(n_keywords - 1 - i)
        keywords_w[i] = w_value
    f.dropvalues(n_keywords)
    n_arguments -= n_keywords
    n = n_arguments + (w_self is not None)
    arguments = f.popvalues(n)    # includes w_self if it is not None
    if w_self is None:
        f.popvalue_maybe_none()    # removes w_self, which is None
    w_callable = f.popvalue()
    args = f.argument_factory(
            arguments, keyword_names_w, keywords_w, None, None,
            methodcall=w_self is not None, w_function=w_callable)
    if f.get_is_being_profiled() and function.is_builtin_code(w_callable):
        w_result = f.space.call_args_and_c_profile(f, w_callable, args)
    else:
        w_result = f.space.call_args(w_callable, args)
    f.pushvalue(w_result)


def call_method_opt(space, w_obj, methname, *arg_w):
    """An optimized version of space.call_method()
    based on the same principle as above.
    """
    w_type = space.type(w_obj)
    if w_type.has_object_getattribute():
        w_descr = space.lookup(w_obj, methname)
        typ = type(w_descr)
        if typ is function.Function or typ is function.FunctionWithFixedCode:
            w_value = w_obj.getdictvalue(space, methname)
            if w_value is None:
                # fast method path: a function object in the class,
                # nothing in the instance
                return space.call_function(w_descr, w_obj, *arg_w)
    w_name = space.newtext(methname)
    w_meth = space.getattr(w_obj, w_name)
    return space.call_function(w_meth, *arg_w)
