
"""Python's standard exception class hierarchy.

Before Python 1.5, the standard exceptions were all simple string objects.
In Python 1.5, the standard exceptions were converted to classes organized
into a relatively flat hierarchy.  String-based standard exceptions were
optional, or used as a fallback if some problem occurred while importing
the exception module.  With Python 1.6, optional string-based standard
exceptions were removed (along with the -X command line flag).

The class exceptions were implemented in such a way as to be almost
completely backward compatible.  Some tricky uses of IOError could
potentially have broken, but by Python 1.6, all of these should have
been fixed.  As of Python 1.6, the class-based standard exceptions are
now implemented in C, and are guaranteed to exist in the Python
interpreter.

Here is a rundown of the class hierarchy.  The classes found here are
inserted into both the exceptions module and the `built-in' module.  It is
recommended that user defined class based exceptions be derived from the
`Exception' class, although this is currently not enforced.

BaseException
 +-- SystemExit
 +-- KeyboardInterrupt
 +-- GeneratorExit
 +-- Exception
      +-- StopIteration
      +-- ArithmeticError
      |    +-- FloatingPointError
      |    +-- OverflowError
      |    +-- ZeroDivisionError
      +-- AssertionError
      +-- AttributeError
      +-- BufferError
      +-- OSError
      |    = EnvironmentError
      |    = IOError
      |    = WindowsError (Windows)
      |    = VMSError (VMS)
      |    +-- BlockingIOError
      |    +-- ChildProcessError
      |    +-- ConnectionError
      |    |    +-- BrokenPipeError
      |    |    +-- ConnectionAbortedError
      |    |    +-- ConnectionRefusedError
      |    |    +-- ConnectionResetError
      |    +-- FileExistsError
      |    +-- FileNotFoundError
      |    +-- InterruptedError
      |    +-- IsADirectoryError
      |    +-- NotADirectoryError
      |    +-- PermissionError
      |    +-- ProcessLookupError
      |    +-- TimeoutError
      +-- EOFError
      +-- ImportError
      +-- LookupError
      |    +-- IndexError
      |    +-- KeyError
      +-- MemoryError
      +-- NameError
      |    +-- UnboundLocalError
      +-- ReferenceError
      +-- RuntimeError
      |    +-- NotImplementedError
      |    +-- RecursionError
      +-- StopAsyncIteration
      +-- SyntaxError
      |    +-- IndentationError
      |         +-- TabError
      +-- SystemError
      +-- TypeError
      +-- ValueError
      |    +-- UnicodeError
      |         +-- UnicodeDecodeError
      |         +-- UnicodeEncodeError
      |         +-- UnicodeTranslateError
      +-- Warning
           +-- DeprecationWarning
           +-- PendingDeprecationWarning
           +-- RuntimeWarning
           +-- SyntaxWarning
           +-- UserWarning
           +-- FutureWarning
           +-- ImportWarning
           +-- UnicodeWarning
           +-- BytesWarning
           +-- ResourceWarning
"""
import errno
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import (
    TypeDef, GetSetProperty, interp_attrproperty,
    descr_get_dict, descr_set_dict, descr_del_dict)
from pypy.interpreter.gateway import interp2app, unwrap_spec, WrappedDefault
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.pytraceback import PyTraceback, check_traceback
from rpython.rlib import rwin32, jit


def readwrite_attrproperty_w(name, cls):
    def fget(space, obj):
        return getattr(obj, name)

    def fset(space, obj, w_val):
        setattr(obj, name, w_val)
    return GetSetProperty(fget, fset, cls=cls)


class W_BaseException(W_Root):
    """Superclass representing the base of the exception hierarchy."""
    w_dict = None
    args_w = []
    w_cause = None
    w_context = None
    w_traceback = None
    suppress_context = False

    def __init__(self, space):
        pass

    def descr_init(self, space, args_w):
        self.args_w = args_w

    def descr_str(self, space):
        lgt = len(self.args_w)
        if lgt == 0:
            return space.newtext('')
        elif lgt == 1:
            return space.str(self.args_w[0])
        else:
            return space.str(space.newtuple(self.args_w))

    def descr_unicode(self, space):
        w_str = space.lookup(self, "__str__")
        w_base_type = space.gettypeobject(W_BaseException.typedef)
        w_base_str = w_base_type.dict_w["__str__"]
        if not space.is_w(w_str, w_base_str):
            w_as_str = space.get_and_call_function(w_str, self)
            return space.call_function(space.w_unicode, w_as_str)
        lgt = len(self.args_w)
        if lgt == 0:
            return space.newutf8("", 0)
        if lgt == 1:
            return space.call_function(space.w_unicode, self.args_w[0])
        else:
            w_tup = space.newtuple(self.args_w)
            return space.call_function(space.w_unicode, w_tup)

    def descr_repr(self, space):
        lgt = len(self.args_w)
        if lgt == 0:
            args_repr = b"()"
        elif lgt == 1:
            args_repr = (b"(" +
                space.utf8_w(space.repr(self.args_w[0])) +
                b")")
        else:
            args_repr = space.utf8_w(
                space.repr(space.newtuple(self.args_w)))
        clsname = self.getclass(space).getname(space)
        return space.newtext(clsname + args_repr)

    def __repr__(self):
        """representation for debugging purposes"""
        return '%s(%s)' % (self.__class__.__name__, self.args_w)

    def descr_getargs(self, space):
        return space.newtuple(self.args_w)

    def descr_setargs(self, space, w_newargs):
        self.args_w = space.fixedview(w_newargs)

    def descr_getcause(self, space):
        return self.w_cause

    def descr_setcause(self, space, w_newcause):
        if space.is_w(w_newcause, space.w_None):
            w_newcause = None
        elif not space.exception_is_valid_class_w(space.type(w_newcause)):
            raise oefmt(space.w_TypeError,
                        "exception cause must be None or derive from "
                        "BaseException")
        self.w_cause = w_newcause
        self.suppress_context = True

    def descr_getcontext(self, space):
        return self.w_context

    def descr_setcontext(self, space, w_newcontext):
        if not (space.is_w(w_newcontext, space.w_None) or
                space.exception_is_valid_class_w(space.type(w_newcontext))):
            raise oefmt(space.w_TypeError,
                        "exception context must be None or derive from "
                        "BaseException")
        self.w_context = w_newcontext

    def descr_gettraceback(self, space):
        tb = self.w_traceback
        if tb is not None and isinstance(tb, PyTraceback):
            # tb escapes to app level (see OperationError.get_traceback)
            tb.frame.mark_as_escaped()
        return tb

    def descr_getsuppresscontext(self, space):
        return space.newbool(self.suppress_context)

    def descr_setsuppresscontext(self, space, w_value):
        self.suppress_context = space.bool_w(w_value)

    def descr_settraceback(self, space, w_newtraceback):
        msg = '__traceback__ must be a traceback or None'
        if not space.is_w(w_newtraceback, space.w_None):
            w_newtraceback = check_traceback(space, w_newtraceback, msg)
        self.w_traceback = w_newtraceback

    def getdict(self, space):
        if self.w_dict is None:
            self.w_dict = space.newdict(instance=True)
        return self.w_dict

    def setdict(self, space, w_dict):
        if not space.isinstance_w(w_dict, space.w_dict):
            raise oefmt(space.w_TypeError,
                        "setting exceptions's dictionary to a non-dict")
        self.w_dict = w_dict

    def descr_reduce(self, space):
        lst = [self.getclass(space), space.newtuple(self.args_w)]
        if self.w_dict is not None and space.is_true(self.w_dict):
            lst = lst + [self.w_dict]
        return space.newtuple(lst)

    def descr_setstate(self, space, w_dict):
        w_olddict = self.getdict(space)
        space.call_method(w_olddict, 'update', w_dict)

    def descr_with_traceback(self, space, w_traceback):
        self.descr_settraceback(space, w_traceback)
        return self

    def _cleanup_(self):
        raise Exception("Prebuilt instances of (subclasses of) BaseException "
                        "must be avoided in Python 3.x.  They have mutable "
                        "attributes related to tracebacks, so whenever they "
                        "are raised in the actual program they will "
                        "accumulate more frames and never free them.")

def _new(cls, basecls=None):
    if basecls is None:
        basecls = cls
    def descr_new_base_exception(space, w_subtype, __args__):
        args_w, kwds_w = __args__.unpack()  # ignore kwds
        exc = space.allocate_instance(cls, w_subtype)
        basecls.__init__(exc, space)
        exc.args_w = args_w
        return exc
    descr_new_base_exception.func_name = 'descr_new_' + cls.__name__
    return interp2app(descr_new_base_exception)

W_BaseException.typedef = TypeDef(
    'BaseException',
    __doc__ = W_BaseException.__doc__,
    __new__ = _new(W_BaseException),
    __init__ = interp2app(W_BaseException.descr_init),
    __str__ = interp2app(W_BaseException.descr_str),
    __unicode__ = interp2app(W_BaseException.descr_unicode),
    __repr__ = interp2app(W_BaseException.descr_repr),
    __dict__ = GetSetProperty(descr_get_dict, descr_set_dict, descr_del_dict,
                              cls=W_BaseException),
    __reduce__ = interp2app(W_BaseException.descr_reduce),
    __setstate__ = interp2app(W_BaseException.descr_setstate),
    with_traceback = interp2app(W_BaseException.descr_with_traceback),
    args = GetSetProperty(W_BaseException.descr_getargs,
                          W_BaseException.descr_setargs),
    __cause__ = GetSetProperty(W_BaseException.descr_getcause,
                               W_BaseException.descr_setcause),
    __context__ = GetSetProperty(W_BaseException.descr_getcontext,
                                 W_BaseException.descr_setcontext),
    __suppress_context__  = GetSetProperty(
        W_BaseException.descr_getsuppresscontext,
        W_BaseException.descr_setsuppresscontext),
    __traceback__ = GetSetProperty(W_BaseException.descr_gettraceback,
                                   W_BaseException.descr_settraceback),
)

def _new_exception(name, base, docstring, **kwargs):
    # Create a subclass W_Exc of the class 'base'.  Note that there is
    # hackery going on on the typedef of W_Exc: when we make further
    # app-level subclasses, they inherit at interp-level from 'realbase'
    # instead of W_Exc.  This allows multiple inheritance to work (see
    # test_multiple_inheritance in test_exc.py).

    class W_Exc(base):
        __doc__ = docstring

    W_Exc.__name__ = 'W_' + name

    realbase = base.typedef.applevel_subclasses_base or base

    for k, v in kwargs.items():
        kwargs[k] = interp2app(v.__get__(None, realbase))
    W_Exc.typedef = TypeDef(
        name,
        base.typedef,
        __doc__ = W_Exc.__doc__,
        **kwargs
    )
    W_Exc.typedef.applevel_subclasses_base = realbase
    return W_Exc

W_Exception = _new_exception('Exception', W_BaseException,
                         """Common base class for all non-exit exceptions.""")

W_GeneratorExit = _new_exception('GeneratorExit', W_BaseException,
                          """Request that a generator exit.""")

W_BufferError = _new_exception('BufferError', W_Exception,
                         """Buffer error.""")

W_ValueError = _new_exception('ValueError', W_Exception,
                         """Inappropriate argument value (of correct type).""")


class W_ImportError(W_Exception):
    """Import can't find module, or can't find name in module."""
    w_name = None
    w_path = None
    w_msg = None

    @jit.unroll_safe
    @unwrap_spec(w_name=WrappedDefault(None), w_path=WrappedDefault(None))
    def descr_init(self, space, args_w, __kwonly__, w_name=None, w_path=None):
        self.w_name = w_name
        self.w_path = w_path
        if len(args_w) == 1:
            self.w_msg = args_w[0]
        else:
            self.w_msg = space.w_None
        W_Exception.descr_init(self, space, args_w)

    def descr_reduce(self, space):
        lst = [self.getclass(space), space.newtuple(self.args_w)]
        if self.w_dict is not None and space.is_true(self.w_dict):
            w_dict = space.call_method(self.w_dict, "copy")
        else:
            w_dict = space.newdict()
        if not space.is_w(self.w_name, space.w_None):
            space.setitem(w_dict, space.newtext("name"), self.w_name)
        if not space.is_w(self.w_path, space.w_None):
            space.setitem(w_dict, space.newtext("path"), self.w_path)
        if space.is_true(w_dict):
            lst = [lst[0], lst[1], w_dict]
        return space.newtuple(lst)

    def descr_setstate(self, space, w_dict):
        self.w_name = space.call_method(w_dict, "pop", space.newtext("name"), space.w_None)
        self.w_path = space.call_method(w_dict, "pop", space.newtext("path"), space.w_None)
        w_olddict = self.getdict(space)
        space.call_method(w_olddict, 'update', w_dict)


W_ImportError.typedef = TypeDef(
    'ImportError',
    W_Exception.typedef,
    __doc__ = W_ImportError.__doc__,
    __module__ = 'builtins',
    __new__ = _new(W_ImportError),
    __init__ = interp2app(W_ImportError.descr_init),
    __reduce__ = interp2app(W_ImportError.descr_reduce),
    __setstate__ = interp2app(W_ImportError.descr_setstate),
    name = readwrite_attrproperty_w('w_name', W_ImportError),
    path = readwrite_attrproperty_w('w_path', W_ImportError),
    msg = readwrite_attrproperty_w('w_msg', W_ImportError),
)


W_RuntimeError = _new_exception('RuntimeError', W_Exception,
                     """Unspecified run-time error.""")

W_UnicodeError = _new_exception('UnicodeError', W_ValueError,
                          """Unicode related error.""")

W_ModuleNotFoundError = _new_exception(
    'ModuleNotFoundError', W_ImportError, """Module not found."""
)


class W_UnicodeTranslateError(W_UnicodeError):
    """Unicode translation error."""
    w_object = None
    w_start = None
    w_end = None
    w_reason = None

    def descr_init(self, space, w_object, w_start, w_end, w_reason):
        # typechecking
        space.utf8_w(w_object)
        space.int_w(w_start)
        space.int_w(w_end)
        space.realtext_w(w_reason)
        # assign attributes
        self.w_object = w_object
        self.w_start = w_start
        self.w_end = w_end
        self.w_reason = w_reason
        W_BaseException.descr_init(self, space, [w_object, w_start,
                                                 w_end, w_reason])

    def descr_str(self, space):
        return space.appexec([self], r"""(self):
            if self.object is None:
                return ""
            if self.end == self.start + 1:
                badchar = ord(self.object[self.start])
                if badchar <= 0xff:
                    return "can't translate character '\\x%02x' in position %d: %s" % (badchar, self.start, self.reason)
                if badchar <= 0xffff:
                    return "can't translate character '\\u%04x' in position %d: %s"%(badchar, self.start, self.reason)
                return "can't translate character '\\U%08x' in position %d: %s"%(badchar, self.start, self.reason)
            return "can't translate characters in position %d-%d: %s" % (self.start, self.end - 1, self.reason)
        """)

W_UnicodeTranslateError.typedef = TypeDef(
    'UnicodeTranslateError',
    W_UnicodeError.typedef,
    __doc__ = W_UnicodeTranslateError.__doc__,
    __new__ = _new(W_UnicodeTranslateError),
    __init__ = interp2app(W_UnicodeTranslateError.descr_init),
    __str__ = interp2app(W_UnicodeTranslateError.descr_str),
    object = readwrite_attrproperty_w('w_object', W_UnicodeTranslateError),
    start  = readwrite_attrproperty_w('w_start', W_UnicodeTranslateError),
    end    = readwrite_attrproperty_w('w_end', W_UnicodeTranslateError),
    reason = readwrite_attrproperty_w('w_reason', W_UnicodeTranslateError),
)

W_LookupError = _new_exception('LookupError', W_Exception,
                               """Base class for lookup errors.""")

def key_error_str(self, space):
    if len(self.args_w) == 0:
        return space.newtext('')
    elif len(self.args_w) == 1:
        return space.repr(self.args_w[0])
    else:
        return space.str(space.newtuple(self.args_w))

W_KeyError = _new_exception('KeyError', W_LookupError,
                            """Mapping key not found.""",
                            __str__ = key_error_str)


class W_StopIteration(W_Exception):
    """Signal the end from iterator.__next__()."""
    def __init__(self, space):
        self.w_value = space.w_None
        W_Exception.__init__(self, space)

    def descr_init(self, space, args_w):
        if len(args_w) > 0:
            self.w_value = args_w[0]
        W_Exception.descr_init(self, space, args_w)

W_StopIteration.typedef = TypeDef(
    'StopIteration',
    W_Exception.typedef,
    __doc__ = W_StopIteration.__doc__,
    __module__ = 'builtins',
    __new__ = _new(W_StopIteration),
    __init__ = interp2app(W_StopIteration.descr_init),
    value = readwrite_attrproperty_w('w_value', W_StopIteration),
)


W_Warning = _new_exception('Warning', W_Exception,
                           """Base class for warning categories.""")

W_PendingDeprecationWarning = _new_exception('PendingDeprecationWarning',
                                             W_Warning,
       """Base class for warnings about features which will be deprecated in the future.""")

class W_OSError(W_Exception):
    """OS system call failed."""

    def __init__(self, space):
        self.w_errno = None
        self.w_winerror = None
        self.w_strerror = None
        self.w_filename = None
        self.w_filename2 = None
        self.written = -1  # only for BlockingIOError.
        W_BaseException.__init__(self, space)

    @staticmethod
    def _use_init(space, w_subtype):
        # When __init__ is defined in a OSError subclass, we want any
        # extraneous argument to __new__ to be ignored.  The only reasonable
        # solution, given __new__ takes a variable number of arguments,
        # is to defer arg parsing and initialization to __init__.
        #
        # But when __new__ is overriden as well, it should call our __new__
        # with the right arguments.
        #
        # (see http://bugs.python.org/issue12555#msg148829 )
        if space.is_w(w_subtype, space.w_OSError):
            return False
        if ((space.getattr(w_subtype, space.newtext('__init__')) !=
             space.getattr(space.w_OSError, space.newtext('__init__'))) and
            (space.getattr(w_subtype, space.newtext('__new__')) ==
             space.getattr(space.w_OSError, space.newtext('__new__')))):
            return True
        return False

    @staticmethod
    def _parse_init_args(space, args_w):
        if 2 <= len(args_w) <= 5:
            w_errno = args_w[0]
            w_strerror = args_w[1]
            w_filename = None
            w_winerror = None
            w_filename2 = None
            if len(args_w) > 2:
                w_filename = args_w[2]
                if len(args_w) > 3:
                    w_winerror = args_w[3]
                    if len(args_w) > 4:
                        w_filename2 = args_w[4]
            if rwin32.WIN32 and w_winerror:
                # Under Windows, if the winerror constructor argument is
                # an integer, the errno attribute is determined from the
                # Windows error code, and the errno argument is
                # ignored.
                # On other platforms, the winerror argument is
                # ignored, and the winerror attribute does not exist.
                try:
                    winerror = space.int_w(w_winerror)
                except OperationError:
                    w_winerror = None
                else:
                    w_errno = space.newint(
                        WINERROR_TO_ERRNO.get(winerror, DEFAULT_WIN32_ERRNO))
            return w_errno, w_winerror, w_strerror, w_filename, w_filename2
        return None, None, None, None, None

    @staticmethod
    def descr_new(space, w_subtype, __args__):
        args_w, kwds_w = __args__.unpack()
        w_errno = None
        w_winerror = None
        w_strerror = None
        w_filename = None
        w_filename2 = None
        if not W_OSError._use_init(space, w_subtype):
            if kwds_w:
                raise oefmt(space.w_TypeError,
                            "OSError does not take keyword arguments")
            (w_errno, w_winerror, w_strerror, w_filename, w_filename2
             ) = W_OSError._parse_init_args(space, args_w)
        if (not space.is_none(w_errno) and
            space.is_w(w_subtype, space.gettypeobject(W_OSError.typedef))):
            try:
                errno = space.int_w(w_errno)
            except OperationError:
                pass
            else:
                try:
                    subclass = ERRNO_MAP[errno]
                except KeyError:
                    pass
                else:
                    w_subtype = space.gettypeobject(subclass.typedef)
        exc = space.allocate_instance(W_OSError, w_subtype)
        W_OSError.__init__(exc, space)
        if not W_OSError._use_init(space, w_subtype):
            exc._init_error(space, args_w, w_errno, w_winerror, w_strerror,
                            w_filename, w_filename2)
        return exc

    def descr_init(self, space, __args__):
        args_w, kwds_w = __args__.unpack()
        if not W_OSError._use_init(space, space.type(self)):
            # Everything already done in OSError_new
            return
        if kwds_w:
            raise oefmt(space.w_TypeError,
                        "OSError does not take keyword arguments")
        (w_errno, w_winerror, w_strerror, w_filename, w_filename2
         ) = W_OSError._parse_init_args(space, args_w)
        self._init_error(space, args_w, w_errno, w_winerror, w_strerror,
                         w_filename, w_filename2)

    def _init_error(self, space, args_w, w_errno, w_winerror, w_strerror,
                    w_filename, w_filename2):
        W_BaseException.descr_init(self, space, args_w)
        self.w_errno = w_errno
        self.w_winerror = w_winerror
        self.w_strerror = w_strerror

        if not space.is_none(w_filename):
            if space.isinstance_w(
                    self, space.gettypeobject(W_BlockingIOError.typedef)):
                try:
                    self.written = space.int_w(w_filename)
                except OperationError:
                    self.w_filename = w_filename
            else:
                if not space.is_none(w_filename):
                    self.w_filename = w_filename
                if not space.is_none(w_filename2):
                    self.w_filename2 = w_filename2
                # filename is removed from the args tuple (for compatibility
                # purposes, see test_exceptions.py)
                self.args_w = [w_errno, w_strerror]

    # since we rebind args_w, we need special reduce, grump
    def descr_reduce(self, space):
        extra = []
        if self.w_filename:
            extra.append(self.w_filename)
            if self.w_filename2:
                extra.append(space.w_None)
                extra.append(self.w_filename2)
        lst = [self.getclass(space), space.newtuple(self.args_w + extra)]
        if self.w_dict is not None and space.is_true(self.w_dict):
            lst = lst + [self.w_dict]
        return space.newtuple(lst)

    def descr_str(self, space):
        if self.w_errno:
            errno = space.utf8_w(space.str(self.w_errno))
        else:
            errno = b""
        if self.w_strerror:
            strerror = space.utf8_w(space.str(self.w_strerror))
        else:
            strerror = b""
        if rwin32.WIN32 and self.w_winerror:
            winerror = space.utf8_w(space.str(self.w_winerror))
            # If available, winerror has the priority over errno
            if self.w_filename:
                if self.w_filename2:
                    return space.newtext(b"[WinError %s] %s: %s -> %s" % (
                        winerror, strerror,
                        space.utf8_w(space.repr(self.w_filename)),
                        space.utf8_w(space.repr(self.w_filename2))))
                return space.newtext(b"[WinError %s] %s: %s" % (
                    winerror, strerror,
                    space.utf8_w(space.repr(self.w_filename))))
            return space.newtext(b"[WinError %s] %s" % (
                winerror, strerror))
        if self.w_filename:
            if self.w_filename2:
                return space.newtext(b"[Errno %s] %s: %s -> %s" % (
                    errno, strerror,
                    space.utf8_w(space.repr(self.w_filename)),
                    space.utf8_w(space.repr(self.w_filename2))))
            return space.newtext(b"[Errno %s] %s: %s" % (
                errno, strerror,
                space.utf8_w(space.repr(self.w_filename))))
        if self.w_errno and self.w_strerror:
            return space.newtext(b"[Errno %s] %s" % (
                errno, strerror))
        return W_BaseException.descr_str(self, space)

    def descr_get_written(self, space):
        if self.written == -1:
            raise oefmt(space.w_AttributeError, "characters_written")
        return space.newint(self.written)

    def descr_set_written(self, space, w_written):
        self.written = space.int_w(w_written)

    def descr_del_written(self, space):
        if self.written == -1:
            raise oefmt(space.w_AttributeError, "characters_written")
        self.written = -1


if hasattr(rwin32, 'build_winerror_to_errno'):
    WINERROR_TO_ERRNO, DEFAULT_WIN32_ERRNO = rwin32.build_winerror_to_errno()
else:
    WINERROR_TO_ERRNO, DEFAULT_WIN32_ERRNO = {}, 22 # EINVAL

if rwin32.WIN32:
    _winerror_property = dict(
        winerror = readwrite_attrproperty_w('w_winerror', W_OSError),
    )
else:
    _winerror_property = dict()


W_OSError.typedef = TypeDef(
    'OSError',
    W_Exception.typedef,
    __doc__ = W_OSError.__doc__,
    __new__ = interp2app(W_OSError.descr_new),
    __reduce__ = interp2app(W_OSError.descr_reduce),
    __init__ = interp2app(W_OSError.descr_init),
    __str__ = interp2app(W_OSError.descr_str),
    errno    = readwrite_attrproperty_w('w_errno',    W_OSError),
    strerror = readwrite_attrproperty_w('w_strerror', W_OSError),
    filename = readwrite_attrproperty_w('w_filename', W_OSError),
    filename2= readwrite_attrproperty_w('w_filename2',W_OSError),
    characters_written = GetSetProperty(W_OSError.descr_get_written,
                                        W_OSError.descr_set_written,
                                        W_OSError.descr_del_written),
    **_winerror_property
    )

W_BlockingIOError = _new_exception(
    "BlockingIOError", W_OSError, "I/O operation would block")
W_ConnectionError = _new_exception(
    "ConnectionError", W_OSError, "Connection error.")
W_ChildProcessError = _new_exception(
    "ChildProcessError", W_OSError, "Child process error.")
W_BrokenPipeError = _new_exception(
    "BrokenPipeError", W_ConnectionError, "Broken pipe.")
W_ConnectionAbortedError = _new_exception(
    "ConnectionAbortedError", W_ConnectionError, "Connection aborted.")
W_ConnectionRefusedError = _new_exception(
    "ConnectionRefusedError", W_ConnectionError, "Connection refused.")
W_ConnectionResetError = _new_exception(
    "ConnectionResetError", W_ConnectionError, "Connection reset.")
W_FileExistsError = _new_exception(
    "FileExistsError", W_OSError, "File already exists.")
W_FileNotFoundError = _new_exception(
    "FileNotFoundError", W_OSError, "File not found.")
W_IsADirectoryError = _new_exception(
    "IsADirectoryError", W_OSError, "Operation doesn't work on directories.")
W_NotADirectoryError = _new_exception(
    "NotADirectoryError", W_OSError, "Operation only works on directories.")
W_InterruptedError = _new_exception(
    "InterruptedError", W_OSError, "Interrupted by signal.")
W_PermissionError = _new_exception(
    "PermissionError", W_OSError, "Not enough permissions.")
W_ProcessLookupError = _new_exception(
    "ProcessLookupError", W_OSError, "Process not found.")
W_TimeoutError = _new_exception(
    "TimeoutError", W_OSError, "Timeout expired.")


W_BytesWarning = _new_exception('BytesWarning', W_Warning,
                                """Mixing bytes and unicode""")

W_DeprecationWarning = _new_exception('DeprecationWarning', W_Warning,
                        """Base class for warnings about deprecated features.""")

W_ResourceWarning = _new_exception('ResourceWarning', W_Warning,
         """Base class for warnings about resource usage.""")

W_ArithmeticError = _new_exception('ArithmeticError', W_Exception,
                         """Base class for arithmetic errors.""")

W_FloatingPointError = _new_exception('FloatingPointError', W_ArithmeticError,
                                      """Floating point operation failed.""")

W_ReferenceError = _new_exception('ReferenceError', W_Exception,
                           """Weak ref proxy used after referent went away.""")

class W_NameError(W_Exception):
    """Name not found globally."""
    name = None

    def __init__(self, space):
        pass

    @unwrap_spec(w_name=WrappedDefault(None))
    def descr_init(self, space, args_w, __kwonly__, w_name=None):
        self.args_w = args_w
        self.w_name = w_name


W_NameError.typedef = TypeDef('NameError', W_Exception.typedef,
    __doc__ = W_NameError.__doc__,
    __new__ = _new(W_NameError),
    __init__ = interp2app(W_NameError.descr_init),
    name = readwrite_attrproperty_w('w_name', W_NameError),
)

class W_SyntaxError(W_Exception):
    """Invalid syntax."""

    def __init__(self, space):
        self.w_filename = space.w_None
        self.w_lineno   = space.w_None
        self.w_offset   = space.w_None
        self.w_text     = space.w_None
        self.w_msg      = space.w_None
        self.w_print_file_and_line = space.w_None # what's that?
        self.w_lastlineno = space.w_None          # this is a pypy extension
        W_BaseException.__init__(self, space)

    def descr_init(self, space, args_w):
        if len(args_w) > 0:
            self.w_msg = args_w[0]
        if len(args_w) == 2:
            values_w = space.fixedview(args_w[1])
            if len(values_w) > 0:
                self.w_filename = values_w[0]
            if len(values_w) > 1:
                self.w_lineno = values_w[1]
            if len(values_w) > 2:
                self.w_offset = values_w[2]
            if len(values_w) > 3:
                self.w_text = values_w[3]
            if len(values_w) > 4:
                self.w_lastlineno = values_w[4]   # PyPy extension
                # kill the extra items from args_w to prevent undesired effects
                args_w = args_w[:]
                args_w[1] = space.newtuple(values_w[:4])
        W_BaseException.descr_init(self, space, args_w)
        if self.w_text and space.isinstance_w(self.w_text, space.w_unicode):
            self._report_missing_parentheses(space)

    def descr_str(self, space):
        return space.appexec([self], """(self):
            if type(self.msg) is not str:
                return str(self.msg)

            lineno = None
            buffer = self.msg
            have_filename = type(self.filename) is str
            if type(self.lineno) is int:
                if (type(self.lastlineno) is int and
                       self.lastlineno > self.lineno):
                    lineno = 'lines %d-%d' % (self.lineno, self.lastlineno)
                else:
                    lineno = 'line %d' % (self.lineno,)
            if have_filename:
                import os
                fname = os.path.basename(self.filename or "???")
                if lineno:
                    buffer = "%s (%s, %s)" % (self.msg, fname, lineno)
                else:
                    buffer ="%s (%s)" % (self.msg, fname)
            elif lineno:
                buffer = "%s (%s)" % (self.msg, lineno)
            return buffer
        """)

    def descr_repr(self, space):
        if (len(self.args_w) == 2
            and not space.is_w(self.w_lastlineno, space.w_None)
            and space.len_w(self.args_w[1]) == 4):
            # fake a 5-element tuple in the repr, suitable for calling
            # __init__ again
            values_w = space.fixedview(self.args_w[1])
            w_tuple = space.newtuple(values_w + [self.w_lastlineno])
            args_w = [self.args_w[0], w_tuple]
            args_repr = space.utf8_w(space.repr(space.newtuple(args_w)))
            clsname = self.getclass(space).getname(space)
            return space.newtext(clsname + args_repr)
        else:
            return W_Exception.descr_repr(self, space)

    # CPython Issue #21669: Custom error for 'print' & 'exec' as statements
    def _report_missing_parentheses(self, space):
        if not space.text_w(self.w_msg).startswith("Missing parentheses in call to "):
            # the parser identifies the correct places where the error should
            # be produced
            return
        text = space.utf8_w(self.w_text)
        if b'(' in text:
            # Use default error message for any line with an opening paren
            return
        # handle the simple statement case
        if self._check_for_legacy_statements(space, text, 0):
            return
        # Handle the one-line complex statement case
        pos = text.find(b':')
        if pos < 0:
            return
        # Check again, starting from just after the colon
        self._check_for_legacy_statements(space, text, pos+1)

    def _check_for_legacy_statements(self, space, text, start):
        # Ignore leading whitespace
        while start < len(text) and text[start] == b' ':
            start += 1
        # Checking against an empty or whitespace-only part of the string
        if start == len(text):
            return False
        if start > 0:
            text = text[start:]
        # Check for legacy print statements
        if text.startswith(b"print "):
            self._set_legacy_print_statement_msg(space, text)
            return True
        # Check for legacy exec statements
        if text.startswith(b"exec "):
            self.w_msg = space.newtext("Missing parentheses in call to 'exec'")
            return True
        return False

    def _set_legacy_print_statement_msg(self, space, text):
        text = text[len("print"):]
        text = text.strip()
        if text.endswith(";"):
            end = len(text) - 1
            assert end >= 0
            text = text[:end].strip()

        maybe_end = ""
        if text.endswith(","):
            maybe_end = " end=\" \""

        suggestion = "print(%s%s)" % (
                text, maybe_end)

        # try to see whether the suggestion would compile, otherwise discard it
        compiler = space.createcompiler()
        try:
            compiler.compile(suggestion, '?', 'eval', 0)
        except OperationError:
            pass
        else:
            self.w_msg = space.newtext(
                "Missing parentheses in call to 'print'. Did you mean %s?" % (
                    suggestion, ))


W_SyntaxError.typedef = TypeDef(
    'SyntaxError',
    W_Exception.typedef,
    __new__ = _new(W_SyntaxError),
    __init__ = interp2app(W_SyntaxError.descr_init),
    __str__ = interp2app(W_SyntaxError.descr_str),
    __repr__ = interp2app(W_SyntaxError.descr_repr),
    __doc__ = W_SyntaxError.__doc__,
    msg      = readwrite_attrproperty_w('w_msg', W_SyntaxError),
    filename = readwrite_attrproperty_w('w_filename', W_SyntaxError),
    lineno   = readwrite_attrproperty_w('w_lineno', W_SyntaxError),
    offset   = readwrite_attrproperty_w('w_offset', W_SyntaxError),
    text     = readwrite_attrproperty_w('w_text', W_SyntaxError),
    print_file_and_line = readwrite_attrproperty_w('w_print_file_and_line',
                                                   W_SyntaxError),
    lastlineno = readwrite_attrproperty_w('w_lastlineno', W_SyntaxError),
)

W_FutureWarning = _new_exception('FutureWarning', W_Warning,
    """Base class for warnings about constructs that will change semantically in the future.""")

class W_SystemExit(W_BaseException):
    """Request to exit from the interpreter."""

    def __init__(self, space):
        self.w_code = space.w_None
        W_BaseException.__init__(self, space)

    def descr_init(self, space, args_w):
        if len(args_w) == 1:
            self.w_code = args_w[0]
        elif len(args_w) > 1:
            self.w_code = space.newtuple(args_w)
        W_BaseException.descr_init(self, space, args_w)

W_SystemExit.typedef = TypeDef(
    'SystemExit',
    W_BaseException.typedef,
    __new__ = _new(W_SystemExit),
    __init__ = interp2app(W_SystemExit.descr_init),
    __doc__ = W_SystemExit.__doc__,
    code    = readwrite_attrproperty_w('w_code', W_SystemExit)
)

W_EOFError = _new_exception('EOFError', W_Exception,
                            """Read beyond end of file.""")

W_IndentationError = _new_exception('IndentationError', W_SyntaxError,
                                    """Improper indentation.""")

W_TabError = _new_exception('TabError', W_IndentationError,
                            """Improper mixture of spaces and tabs.""")

W_ZeroDivisionError = _new_exception('ZeroDivisionError', W_ArithmeticError,
            """Second argument to a division or modulo operation was zero.""")

W_SystemError = _new_exception('SystemError', W_Exception,
            """Internal error in the Python interpreter.

Please report this to the Python maintainer, along with the traceback,
the Python version, and the hardware/OS platform and version.""")

W_AssertionError = _new_exception('AssertionError', W_Exception,
                                  """Assertion failed.""")

W_StopAsyncIteration = _new_exception('StopAsyncIteration', W_Exception,
                                  """Signal the end from iterator.__anext__().""")

class W_UnicodeDecodeError(W_UnicodeError):
    """Unicode decoding error."""
    w_encoding = None
    w_object = None
    w_start = None
    w_end = None
    w_reason = None

    def descr_init(self, space, w_encoding, w_object, w_start, w_end, w_reason):
        # typechecking
        if space.isinstance_w(w_object, space.w_bytearray):
            w_bytes = space.newbytes(space.charbuf_w(w_object))
        else:
            w_bytes = w_object
        space.realtext_w(w_encoding)
        space.bytes_w(w_bytes)
        space.int_w(w_start)
        space.int_w(w_end)
        space.realtext_w(w_reason)
        # assign attributes
        self.w_encoding = w_encoding
        self.w_object = w_bytes
        self.w_start = w_start
        self.w_end = w_end
        self.w_reason = w_reason
        W_BaseException.descr_init(self, space, [w_encoding, w_object,
                                                 w_start, w_end, w_reason])

    def descr_str(self, space):
        return space.appexec([self], """(self):
            if self.object is None:
                return ""
            if self.end == self.start + 1:
                return "'%s' codec can't decode byte 0x%02x in position %d: %s"%(
                    self.encoding,
                    self.object[self.start], self.start, self.reason)
            return "'%s' codec can't decode bytes in position %d-%d: %s" % (
                self.encoding, self.start, self.end - 1, self.reason)
        """)

W_UnicodeDecodeError.typedef = TypeDef(
    'UnicodeDecodeError',
    W_UnicodeError.typedef,
    __doc__ = W_UnicodeDecodeError.__doc__,
    __new__ = _new(W_UnicodeDecodeError),
    __init__ = interp2app(W_UnicodeDecodeError.descr_init),
    __str__ = interp2app(W_UnicodeDecodeError.descr_str),
    encoding = readwrite_attrproperty_w('w_encoding', W_UnicodeDecodeError),
    object = readwrite_attrproperty_w('w_object', W_UnicodeDecodeError),
    start  = readwrite_attrproperty_w('w_start', W_UnicodeDecodeError),
    end    = readwrite_attrproperty_w('w_end', W_UnicodeDecodeError),
    reason = readwrite_attrproperty_w('w_reason', W_UnicodeDecodeError),
)

W_TypeError = _new_exception('TypeError', W_Exception,
                             """Inappropriate argument type.""")

W_IndexError = _new_exception('IndexError', W_LookupError,
                              """Sequence index out of range.""")

W_RuntimeWarning = _new_exception('RuntimeWarning', W_Warning,
                """Base class for warnings about dubious runtime behavior.""")

W_KeyboardInterrupt = _new_exception('KeyboardInterrupt', W_BaseException,
                                     """Program interrupted by user.""")

W_UserWarning = _new_exception('UserWarning', W_Warning,
                       """Base class for warnings generated by user code.""")

W_SyntaxWarning = _new_exception('SyntaxWarning', W_Warning,
                         """Base class for warnings about dubious syntax.""")

W_UnicodeWarning = _new_exception('UnicodeWarning', W_Warning,
            """Base class for warnings about Unicode related problems, mostly
related to conversion problems.""")

W_ImportWarning = _new_exception('ImportWarning', W_Warning,
    """Base class for warnings about probable mistakes in module imports""")

W_MemoryError = _new_exception('MemoryError', W_Exception,
                               """Out of memory.""")

W_UnboundLocalError = _new_exception('UnboundLocalError', W_NameError,
                        """Local name referenced but not bound to a value.""")

W_NotImplementedError = _new_exception('NotImplementedError', W_RuntimeError,
                        """Method or function hasn't been implemented yet.""")

W_RecursionError = _new_exception('RecursionError', W_RuntimeError,
                        """Recursion limit exceeded.""")


class W_AttributeError(W_Exception):
    """Attribute not found."""
    name = None
    obj = None

    def __init__(self, space):
        pass

    @unwrap_spec(w_name=WrappedDefault(None), w_obj=WrappedDefault(None))
    def descr_init(self, space, args_w, __kwonly__, w_obj=None, w_name=None):
        self.args_w = args_w
        self.w_name = w_name
        self.w_obj = w_obj


W_AttributeError.typedef = TypeDef('AttributeError', W_Exception.typedef,
    __doc__ = W_AttributeError.__doc__,
    __new__ = _new(W_AttributeError),
    __init__ = interp2app(W_AttributeError.descr_init),
    name = readwrite_attrproperty_w('w_name', W_AttributeError),
    obj = readwrite_attrproperty_w('w_obj', W_AttributeError),
)

W_OverflowError = _new_exception('OverflowError', W_ArithmeticError,
                                 """Result too large to be represented.""")

class W_UnicodeEncodeError(W_UnicodeError):
    """Unicode encoding error."""
    w_encoding = None
    w_object = None
    w_start = None
    w_end = None
    w_reason = None

    def descr_init(self, space, w_encoding, w_object, w_start, w_end, w_reason):
        # typechecking
        space.realtext_w(w_encoding)
        space.realutf8_w(w_object)
        space.int_w(w_start)
        space.int_w(w_end)
        space.realtext_w(w_reason)
        # assign attributes
        self.w_encoding = w_encoding
        self.w_object = w_object
        self.w_start = w_start
        self.w_end = w_end
        self.w_reason = w_reason
        W_BaseException.descr_init(self, space, [w_encoding, w_object,
                                                 w_start, w_end, w_reason])

    def descr_str(self, space):
        return space.appexec([self], r"""(self):
            if self.object is None:
                return ""
            if self.end == self.start + 1:
                badchar = ord(self.object[self.start])
                if badchar <= 0xff:
                    return "'%s' codec can't encode character '\\x%02x' in position %d: %s"%(
                        self.encoding, badchar, self.start, self.reason)
                if badchar <= 0xffff:
                    return "'%s' codec can't encode character '\\u%04x' in position %d: %s"%(
                        self.encoding, badchar, self.start, self.reason)
                return "'%s' codec can't encode character '\\U%08x' in position %d: %s"%(
                    self.encoding, badchar, self.start, self.reason)
            return "'%s' codec can't encode characters in position %d-%d: %s" % (
                self.encoding, self.start, self.end - 1, self.reason)
        """)

W_UnicodeEncodeError.typedef = TypeDef(
    'UnicodeEncodeError',
    W_UnicodeError.typedef,
    __doc__ = W_UnicodeEncodeError.__doc__,
    __new__ = _new(W_UnicodeEncodeError),
    __init__ = interp2app(W_UnicodeEncodeError.descr_init),
    __str__ = interp2app(W_UnicodeEncodeError.descr_str),
    encoding = readwrite_attrproperty_w('w_encoding', W_UnicodeEncodeError),
    object = readwrite_attrproperty_w('w_object', W_UnicodeEncodeError),
    start  = readwrite_attrproperty_w('w_start', W_UnicodeEncodeError),
    end    = readwrite_attrproperty_w('w_end', W_UnicodeEncodeError),
    reason = readwrite_attrproperty_w('w_reason', W_UnicodeEncodeError),
)

ERRNO_MAP = {
    errno.EAGAIN: W_BlockingIOError,
    errno.EALREADY: W_BlockingIOError,
    errno.EINPROGRESS: W_BlockingIOError,
    errno.EWOULDBLOCK: W_BlockingIOError,
    errno.EPIPE: W_BrokenPipeError,
    errno.ESHUTDOWN: W_BrokenPipeError,
    errno.ECHILD: W_ChildProcessError,
    errno.ECONNABORTED: W_ConnectionAbortedError,
    errno.ECONNREFUSED: W_ConnectionRefusedError,
    errno.ECONNRESET: W_ConnectionResetError,
    errno.EEXIST: W_FileExistsError,
    errno.ENOENT: W_FileNotFoundError,
    errno.EISDIR: W_IsADirectoryError,
    errno.ENOTDIR: W_NotADirectoryError,
    errno.EINTR: W_InterruptedError,
    errno.EACCES: W_PermissionError,
    errno.EPERM: W_PermissionError,
    errno.ESRCH: W_ProcessLookupError,
    errno.ETIMEDOUT: W_TimeoutError,
}
