import re
from rpython.translator import exceptiontransform
from rpython.rtyper.annlowlevel import llhelper
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.tool.sourcetools import func_with_new_name
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.objectmodel import specialize
from pypy.interpreter.error import OperationError
from pypy.module._hpy_universal import llapi

class APISet(object):

    def __init__(self, cts, is_debug, prefix=r'^_?HPy_?', force_c_name=False):
        self.cts = cts
        self.is_debug = is_debug
        self.prefix = re.compile(prefix)
        self.force_c_name = force_c_name
        self.all_functions = []
        self.frozen = False

    def _freeze_(self):
        self.all_functions = unrolling_iterable(self.all_functions)
        self.frozen = True
        return True

    def parse_signature(self, cdecl, error_value):
        d = self.cts.parse_func(cdecl)
        ARGS = d.get_llargs(self.cts)
        RESULT = d.get_llresult(self.cts)
        FUNC = lltype.Ptr(lltype.FuncType(ARGS, RESULT))
        return d.name, FUNC, self.get_ll_errval(d, FUNC, error_value)

    def get_ll_errval(self, d, FUNC, error_value):
        c_result_t = d.tp.result.get_c_name() # a string such as "HPy" or "void"
        if error_value is None:
            # automatically determine the error value from the return type
            if c_result_t == 'HPy':
                return 0
            elif c_result_t == 'void':
                return None
            elif isinstance(FUNC.TO.RESULT, lltype.Ptr):
                return lltype.nullptr(FUNC.TO.RESULT.TO)
            else:
                raise Exception(
                    "API function %s: you must explicitly specify an error_value "
                    "for functions returning %s" % (d.name, c_result_t))
        elif error_value == 'CANNOT_FAIL':
            # we need to specify an error_value anyway, let's just use the
            # exceptiontransform default
            return exceptiontransform.default_error_value(FUNC.TO.RESULT)
        else:
            assert c_result_t != 'HPy' # sanity check
            if lltype.typeOf(error_value) != FUNC.TO.RESULT:
                raise Exception(
                    "API function %s: the specified error_value has the "
                    "wrong lltype: expected %s, got %s" % (d.name, FUNC.TO.RESULT,
                                                           lltype.typeOf(error_value)))
            return error_value


    def func(self, cdecl, cpyext=False, func_name=None, error_value=None):
        """
        Declare an HPy API function.

        If the function is marked as cpyext=True, it will be included in the
        translation only if pypy.objspace.hpy_cpyext_API==True (the
        default). This is useful to exclude cpyext in test_ztranslation

        If func_name is given, the decorated function will be automatically
        renamed. Useful for automatically generated code, for example in
        interp_number.py

        error_value specifies the C value to return in case the function
        raises an RPython exception. The default behavior tries to be smart
        enough to work in the most common and standardized cases, but without
        guessing in case of doubts.  In particular, there is no default
        error_value for "int" functions, because CPython's behavior is not
        consistent.

        error_value can be:

            - None (the default): automatically determine the error value. It
              works only for the following return types:
                  * HPy: 0
                  * void: None
                  * pointers: NULL

            - 'CANNOT_FAIL': special string to specify that this function is
              not supposed to fail.

            - a specific value: in this case, the lltype must exactly match
              what is specified for the function type.
        """
        if self.frozen:
            raise RuntimeError(
                'Too late to call @api.func(), the API object has already been frozen. '
                'If you are calling @api.func() to decorate module-level functions, '
                'you might solve this by making sure that the module is imported '
                'earlier')
        def decorate(fn):
            from pypy.module._hpy_universal.state import State
            name, ll_functype, ll_errval = self.parse_signature(cdecl, error_value)
            if name != fn.__name__:
                raise ValueError(
                    'The name of the function and the signature do not match: '
                    '%s != %s' % (name, fn.__name__))
            #
            if func_name is not None:
                fn = func_with_new_name(fn, func_name)
            #
            # attach various helpers to fn, so you can access things like
            # HPyNumber_Add.get_llhelper(), HPyNumber_Add.basename, etc.

            # get_llhelper
            @specialize.memo()
            def make_wrapper(space):
                def wrapper(*args):
                    state = space.fromcache(State)
                    handles = state.get_handle_manager(self.is_debug)
                    try:
                        return fn(space, handles, *args)
                    except OperationError as e:
                        state.set_exception(e)
                        return ll_errval
                wrapper.__name__ = 'ctx_%s' % fn.__name__
                if self.force_c_name:
                    wrapper.c_name = fn.__name__
                return wrapper
            def get_llhelper(space):
                return llhelper(ll_functype, make_wrapper(space))
            get_llhelper.__name__ = 'get_llhelper_%s' % fn.__name__
            fn.get_llhelper = get_llhelper

            # basename
            fn.basename = self.prefix.sub(r'', fn.__name__)

            fn.cpyext = cpyext
            # record it into the API
            self.all_functions.append(fn)
            return fn
        return decorate

    @staticmethod
    def int(x):
        """
        Helper method to convert an RPython Signed into a C int
        """
        return rffi.cast(rffi.INT_real, x)

    @staticmethod
    def cast(typename, x):
        """
        Helper method to convert an RPython value into the correct C return
        type.
        """
        lltype = llapi.cts.gettype(typename)
        return rffi.cast(lltype, x)

    @staticmethod
    def ccharp2text(space, ptr):
        """
        Convert a C const char* into a W_UnicodeObject
        """
        s = rffi.constcharp2str(ptr)
        return space.newtext(s)



API = APISet(llapi.cts, is_debug=False)
DEBUG = APISet(llapi.cts, is_debug=True)
