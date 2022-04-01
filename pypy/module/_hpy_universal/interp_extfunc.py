from rpython.rlib.objectmodel import import_from_mixin, specialize
from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.interpreter.error import oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.function import descr_function_get
from pypy.interpreter.typedef import TypeDef, interp_attrproperty
from pypy.interpreter.gateway import (
    interp2app, interpindirect2app, unwrap_spec)
from pypy.objspace.std.typeobject import W_TypeObject

from pypy.module._hpy_universal import llapi
from pypy.module._hpy_universal.state import State

SUPPORTED_SIGNATURES = (
    llapi.HPyFunc_VARARGS,
    llapi.HPyFunc_KEYWORDS,
    llapi.HPyFunc_NOARGS,
    llapi.HPyFunc_O
)

class W_AbstractExtensionFunction(W_Root):
    # XXX: should we have separate classes for each sig?
    def descr_call(self, space, __args__):
        raise NotImplementedError

class W_ExtensionFunctionMixin(object):
    _immutable_fields_ = ["sig", "name"]

    @specialize.arg(2)
    def __init__(self, space, handles, name, sig, doc, cfuncptr, w_self):
        self.handles = handles
        self.w_self = w_self
        self.name = name
        self.sig = sig
        if self.sig not in SUPPORTED_SIGNATURES:
            raise oefmt(space.w_ValueError, "Unsupported HPyMeth signature")
            #raise oefmt(space.w_ValueError, "Unsupported HPyMeth.signature: %d", self.sig)
        self.doc = doc
        self.cfuncptr = cfuncptr

    def call_noargs(self, space, h_self):
        func = llapi.cts.cast('HPyFunc_noargs', self.cfuncptr)
        h_result = func(self.handles.ctx, h_self)
        if not h_result:
            space.fromcache(State).raise_current_exception()
        return self.handles.consume(h_result)

    def call_o(self, space, h_self, w_arg):
        with self.handles.using(w_arg) as h_arg:
            func = llapi.cts.cast('HPyFunc_o', self.cfuncptr)
            h_result = func(self.handles.ctx, h_self, h_arg)
        if not h_result:
            space.fromcache(State).raise_current_exception()
        return self.handles.consume(h_result)

    def call_varargs_kw(self, space, h_self, __args__, skip_args, has_keywords):
        # this function is more or less the equivalent of
        # ctx_CallRealFunctionFromTrampoline in cpython-universal
        n = len(__args__.arguments_w) - skip_args

        # XXX this looks inefficient: ideally, we would like the equivalent of
        # alloca(): do we have it in RPython? The alternative is to wrap
        # arguments_w in a tuple, convert to handle and pass it to a C
        # function whichs calls alloca() and the forwards everything to the
        # functpr
        with lltype.scoped_alloc(rffi.CArray(llapi.HPy), n) as args_h:
            i = 0
            while i < n:
                args_h[i] = self.handles.new(__args__.arguments_w[i + skip_args])
                i += 1
            try:
                if has_keywords:
                    h_result = self.call_keywords(space, h_self, args_h, n, __args__)
                else:
                    h_result = self.call_varargs(space, h_self, args_h, n)
            finally:
                for i in range(n):
                    self.handles.close(args_h[i])

        if not h_result:
            space.fromcache(State).raise_current_exception()
        return self.handles.consume(h_result)

    def call_varargs(self, space, h_self, args_h, n):
        fptr = llapi.cts.cast('HPyFunc_varargs', self.cfuncptr)
        return fptr(self.handles.ctx, h_self, args_h, n)

    def call_keywords(self, space, h_self, args_h, n, __args__):
        # XXX: if there are no keywords, should we pass HPy_NULL or an empty
        # dict?
        h_kw = 0
        if __args__.keyword_names_w:
            w_kw = space.newdict()
            for i in range(len(__args__.keyword_names_w)):
                w_key = __args__.keyword_names_w[i]
                w_value = __args__.keywords_w[i]
                space.setitem(w_kw, w_key, w_value)
            h_kw = self.handles.new(w_kw)

        fptr = llapi.cts.cast('HPyFunc_keywords', self.cfuncptr)
        try:
            return fptr(self.handles.ctx, h_self, args_h, n, h_kw)
        finally:
            if h_kw:
                self.handles.consume(h_kw)


    def descr_call(self, space, __args__):
        with self.handles.using(self.w_self) as h_self:
            return self.call(space, h_self, __args__)

    def call(self, space, h_self, __args__, skip_args=0):
        sig = self.sig
        length = len(__args__.arguments_w) - skip_args

        if sig == llapi.HPyFunc_KEYWORDS:
            return self.call_varargs_kw(space, h_self, __args__, skip_args, has_keywords=True)

        if __args__.keyword_names_w:
            raise oefmt(space.w_TypeError,
                        "%s() takes no keyword arguments", self.name)

        if sig == llapi.HPyFunc_NOARGS:
            if length == 0:
                return self.call_noargs(space, h_self)
            raise oefmt(space.w_TypeError,
                        "%s() takes no arguments", self.name)

        if sig == llapi.HPyFunc_O:
            if length != 1:
                raise oefmt(space.w_TypeError,
                            "%s() takes exactly one argument (%d given)",
                            self.name, length)
            return self.call_o(space, h_self, __args__.arguments_w[skip_args])

        if sig == llapi.HPyFunc_VARARGS:
            return self.call_varargs_kw(space, h_self, __args__, skip_args, has_keywords=False)
        else:  # shouldn't happen!
            raise oefmt(space.w_RuntimeError, "unknown calling convention")

class W_ExtensionFunction_u(W_AbstractExtensionFunction):
    import_from_mixin(W_ExtensionFunctionMixin)

class W_ExtensionFunction_d(W_AbstractExtensionFunction):
    import_from_mixin(W_ExtensionFunctionMixin)


W_AbstractExtensionFunction.typedef = TypeDef(
    'extension_function',
    __call__ = interpindirect2app(W_AbstractExtensionFunction.descr_call),
    __doc__ = interp_attrproperty('doc', cls=W_AbstractExtensionFunction,
                                  wrapfn="newtext_or_none"),
    )
W_AbstractExtensionFunction.typedef.acceptable_as_base_class = False

class W_AbstractExtensionMethod(W_Root):
    def descr_call(self, space, __args__):
        raise NotImplementedError

class W_ExtensionMethodMixin(object):
    import_from_mixin(W_ExtensionFunctionMixin)
    def __init__(self, space, handles, name, sig, doc, cfuncptr, w_objclass):
        W_ExtensionFunctionMixin.__init__.__func__(self, space, handles, name, sig, doc,
                                     cfuncptr, space.w_None)
        self.w_objclass = w_objclass

    def descr_call(self, space, __args__):
        # XXX: basically a copy of cpyext's W_PyCMethodObject.descr_call()
        if len(__args__.arguments_w) == 0:
            w_objclass = self.w_objclass
            assert isinstance(w_objclass, W_TypeObject)
            raise oefmt(space.w_TypeError,
                "descriptor '%8' of '%s' object needs an argument",
                self.name, self.w_objclass.getname(space))
        w_instance = __args__.arguments_w[0]
        # XXX: needs a stricter test
        if not space.isinstance_w(w_instance, self.w_objclass):
            w_objclass = self.w_objclass
            assert isinstance(w_objclass, W_TypeObject)
            raise oefmt(space.w_TypeError,
                "descriptor '%8' requires a '%s' object but received a '%T'",
                self.name, w_objclass.name, w_instance)
        #
        with self.handles.using(w_instance) as h_instance:
            return self.call(space, h_instance, __args__, skip_args=1)

class W_ExtensionMethod_u(W_AbstractExtensionMethod):
    import_from_mixin(W_ExtensionMethodMixin)

class W_ExtensionMethod_d(W_AbstractExtensionMethod):
    import_from_mixin(W_ExtensionMethodMixin)

W_AbstractExtensionMethod.typedef = TypeDef(
    'method_descriptor_',
    __get__ = interp2app(descr_function_get),
    __call__ = interpindirect2app(W_AbstractExtensionMethod.descr_call),
    __doc__ = interp_attrproperty('doc', cls=W_AbstractExtensionMethod,
                                  wrapfn="newtext_or_none"),
    )
W_AbstractExtensionMethod.typedef.acceptable_as_base_class = False
