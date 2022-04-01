from rpython.annotator.model import unionof, SomeObject
from rpython.annotator.signature import annotation, SignatureError
from rpython.rtyper.extregistry import ExtRegistryEntry, lookup
from rpython.rtyper.lltypesystem.lltype import (
    typeOf, FuncType, functionptr, _ptr, Void)
from rpython.rtyper.error import TyperError
from rpython.rtyper.rmodel import Repr

class SomeExternalFunction(SomeObject):
    def __init__(self, name, args_s, s_result):
        self.name = name
        self.args_s = args_s
        self.s_result = s_result

    def check_args(self, callspec):
        params_s = self.args_s
        args_s, kwargs = callspec.unpack()
        if kwargs:
            raise SignatureError(
                "External functions cannot be called with keyword arguments")
        if len(args_s) != len(params_s):
            raise SignatureError("Argument number mismatch")
        for i, s_param in enumerate(params_s):
            arg = unionof(args_s[i], s_param)
            if not s_param.contains(arg):
                raise SignatureError(
                    "In call to external function %r:\n"
                    "arg %d must be %s,\n"
                    "          got %s" % (
                        self.name, i + 1, s_param, args_s[i]))

    def call(self, callspec):
        self.check_args(callspec)
        return self.s_result

    def rtyper_makerepr(self, rtyper):
        if not self.is_constant():
            raise TyperError("Non-constant external function!")
        entry = lookup(self.const)
        impl = getattr(entry, 'lltypeimpl', None)
        fakeimpl = getattr(entry, 'lltypefakeimpl', None)
        return ExternalFunctionRepr(self, impl, fakeimpl)

    def rtyper_makekey(self):
        return self.__class__, self

class ExternalFunctionRepr(Repr):
    lowleveltype = Void

    def __init__(self, s_func, impl, fakeimpl):
        self.s_func = s_func
        self.impl = impl
        self.fakeimpl = fakeimpl

    def rtype_simple_call(self, hop):
        rtyper = hop.rtyper
        args_r = [rtyper.getrepr(s_arg) for s_arg in self.s_func.args_s]
        r_result = rtyper.getrepr(self.s_func.s_result)
        obj = self.get_funcptr(rtyper, args_r, r_result)
        hop2 = hop.copy()
        hop2.r_s_popfirstarg()
        vlist = [hop2.inputconst(typeOf(obj), obj)] + hop2.inputargs(*args_r)
        hop2.exception_is_here()
        return hop2.genop('direct_call', vlist, r_result)

    def get_funcptr(self, rtyper, args_r, r_result):
        from rpython.rtyper.rtyper import llinterp_backend
        args_ll = [r_arg.lowleveltype for r_arg in args_r]
        ll_result = r_result.lowleveltype
        name = self.s_func.name
        if self.fakeimpl and rtyper.backend is llinterp_backend:
            FT = FuncType(args_ll, ll_result)
            return functionptr(
                FT, name, _external_name=name, _callable=self.fakeimpl)
        elif self.impl:
            if isinstance(self.impl, _ptr):
                return self.impl
            else:
                # store some attributes to the 'impl' function, where
                # the eventual call to rtyper.getcallable() will find them
                # and transfer them to the final lltype.functionptr().
                self.impl._llfnobjattrs_ = {'_name': name}
                return rtyper.getannmixlevel().delayedfunction(
                    self.impl, self.s_func.args_s, self.s_func.s_result)
        else:
            fakeimpl = self.fakeimpl or self.s_func.const
            FT = FuncType(args_ll, ll_result)
            return functionptr(
                FT, name, _external_name=name, _callable=fakeimpl)


class ExtFuncEntry(ExtRegistryEntry):
    safe_not_sandboxed = False

    def compute_annotation(self):
        s_result = SomeExternalFunction(
            self.name, self.signature_args, self.signature_result)
        if (self.bookkeeper.annotator.translator.config.translation.sandbox
                and not self.safe_not_sandboxed):
            s_result.needs_sandboxing = True
        return s_result


def register_external(function, args, result=None, export_name=None,
                       llimpl=None, llfakeimpl=None, sandboxsafe=False):
    """
    function: the RPython function that will be rendered as an external function (e.g.: math.floor)
    args: a list containing the annotation of the arguments
    result: surprisingly enough, the annotation of the result
    export_name: the name of the function as it will be seen by the backends
    llimpl: optional; if provided, this RPython function is called instead of the target function
    llfakeimpl: optional; if provided, called by the llinterpreter
    sandboxsafe: use True if the function performs no I/O (safe for --sandbox)
    """

    if export_name is None:
        export_name = function.__name__
    params_s = [annotation(arg) for arg in args]
    s_result = annotation(result)

    class FunEntry(ExtFuncEntry):
        _about_ = function
        safe_not_sandboxed = sandboxsafe
        signature_args = params_s
        signature_result = s_result
        name = export_name
        if llimpl:
            lltypeimpl = staticmethod(llimpl)
        if llfakeimpl:
            lltypefakeimpl = staticmethod(llfakeimpl)

def is_external(func):
    if hasattr(func, 'value'):
        func = func.value
    if hasattr(func, '_external_name'):
        return True
    return False
