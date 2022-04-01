from pypy.interpreter.error import oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef, interp_attrproperty
from pypy.interpreter.typedef import GetSetProperty
from pypy.interpreter.gateway import interp2app
from rpython.rlib import jit

from pypy.module._cffi_backend.cdataobj import W_CData
from pypy.module._cffi_backend.cdataobj import W_CDataPtrToStructOrUnion
from pypy.module._cffi_backend.ctypeptr import W_CTypePtrOrArray
from pypy.module._cffi_backend.ctypeptr import W_CTypePointer
from pypy.module._cffi_backend.ctypefunc import W_CTypeFunc
from pypy.module._cffi_backend.ctypestruct import W_CTypeStructOrUnion
from pypy.module._cffi_backend import allocator


class W_FunctionWrapper(W_Root):
    """A wrapper around a real W_CData which points to a function
    generated in the C code.  The real W_CData has got no struct/union
    argument (only pointers to it), and no struct/union return type
    (it is replaced by a hidden pointer as first argument).  This
    wrapper is callable, and the arguments it expects and returns
    are directly the struct/union.  Calling ffi.typeof(wrapper)
    also returns the original struct/union signature.

    This class cannot be used for variadic functions.
    """
    _immutable_ = True

    def __init__(self, space, ffi, fnptr, directfnptr,
                 rawfunctype, fnname, modulename):
        # everything related to the type of the function is accessed
        # as immutable attributes of the 'rawfunctype' object, which
        # is a W_RawFuncType.  This gives us an obvious thing to
        # promote in order to do the call.
        ctype = rawfunctype.nostruct_ctype
        locs = rawfunctype.nostruct_locs
        assert isinstance(ctype, W_CTypeFunc)
        assert ctype.cif_descr is not None     # not for '...' functions
        assert locs is None or len(ctype.fargs) == len(locs)
        #
        self.space = space
        self.ffi = ffi
        self.fnptr = fnptr
        self.directfnptr = directfnptr
        self.rawfunctype = rawfunctype
        self.fnname = fnname
        self.modulename = modulename

    def typeof(self, ffi):
        return self.rawfunctype.unwrap_as_fnptr(ffi)

    def descr_call(self, args_w):
        space = self.space
        rawfunctype = jit.promote(self.rawfunctype)
        ctype = rawfunctype.nostruct_ctype
        locs = rawfunctype.nostruct_locs
        nargs_expected = rawfunctype.nostruct_nargs
        #
        if len(args_w) != nargs_expected:
            if nargs_expected == 0:
                raise oefmt(space.w_TypeError,
                            "%s() takes no arguments (%d given)",
                            self.fnname, len(args_w))
            elif nargs_expected == 1:
                raise oefmt(space.w_TypeError,
                            "%s() takes exactly one argument (%d given)",
                            self.fnname, len(args_w))
            else:
                raise oefmt(space.w_TypeError,
                            "%s() takes exactly %d arguments (%d given)",
                            self.fnname, nargs_expected, len(args_w))
        #
        if locs is not None:
            # This case is if there are structs as arguments or return values.
            # If the result we want to present to the user is "returns struct",
            # then internally allocate the struct and pass a pointer to it as
            # a first argument.
            if locs[0] == 'R':
                w_result_cdata = ctype.fargs[0].newp(space.w_None,
                                                    allocator.nonzero_allocator)
                args_w = [w_result_cdata] + args_w
                prepare_args(space, rawfunctype, args_w, 1)
                #
                ctype._call(self.fnptr, args_w)    # returns w_None
                #
                ctyperesptr = w_result_cdata.ctype
                assert isinstance(ctyperesptr, W_CTypePointer)
                return w_result_cdata._do_getitem(ctyperesptr, 0)
            else:
                args_w = args_w[:]
                prepare_args(space, rawfunctype, args_w, 0)
        #
        return ctype._call(self.fnptr, args_w)

    def descr_repr(self, space):
        doc = self.rawfunctype.repr_fn_type(self.ffi, self.fnname)
        return space.newtext("<FFIFunctionWrapper '%s'>" % (doc,))

    def descr_get_doc(self, space):
        doc = self.rawfunctype.repr_fn_type(self.ffi, self.fnname)
        doc = '%s;\n\nCFFI C function from %s.lib' % (doc, self.modulename)
        return space.newtext(doc)

    def descr_get(self, space, w_obj, w_type=None):
        # never bind anything, but a __get__ is still present so that
        # pydoc displays useful information (namely, the __repr__)
        return self


@jit.unroll_safe
def prepare_args(space, rawfunctype, args_w, start_index):
    # replaces struct/union arguments with ptr-to-struct/union arguments
    # as well as complex numbers
    locs = rawfunctype.nostruct_locs
    fargs = rawfunctype.nostruct_ctype.fargs
    for i in range(start_index, len(locs)):
        if locs[i] != 'A':
            continue
        w_arg = args_w[i]
        farg = fargs[i]      # <ptr to struct/union/complex>
        assert isinstance(farg, W_CTypePtrOrArray)
        if isinstance(w_arg, W_CData) and w_arg.ctype is farg.ctitem:
            # fast way: we are given a W_CData "struct", so just make
            # a new W_CData "ptr-to-struct" which points to the same
            # raw memory.  We use unsafe_escaping_ptr(), so we have to
            # make sure the original 'w_arg' stays alive; the easiest
            # is to build an instance of W_CDataPtrToStructOrUnion.
            w_arg = W_CDataPtrToStructOrUnion(
                space, w_arg.unsafe_escaping_ptr(), farg, w_arg)
        else:
            # slow way: build a new "ptr to struct" W_CData by calling
            # the equivalent of ffi.new()
            if space.is_w(w_arg, space.w_None):
                continue
            w_arg = farg.newp(w_arg, allocator.default_allocator)
        args_w[i] = w_arg


W_FunctionWrapper.typedef = TypeDef(
        '_cffi_backend.__FFIFunctionWrapper',
        __repr__ = interp2app(W_FunctionWrapper.descr_repr),
        __call__ = interp2app(W_FunctionWrapper.descr_call),
        __name__ = interp_attrproperty('fnname', cls=W_FunctionWrapper, wrapfn="newtext"),
        __module__ = interp_attrproperty('modulename', cls=W_FunctionWrapper, wrapfn="newtext"),
        __doc__ = GetSetProperty(W_FunctionWrapper.descr_get_doc),
        __get__ = interp2app(W_FunctionWrapper.descr_get),
        )
W_FunctionWrapper.typedef.acceptable_as_base_class = False
