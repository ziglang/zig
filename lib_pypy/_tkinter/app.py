# The TkApp class.

from .tklib_cffi import ffi as tkffi, lib as tklib
from . import TclError
from .tclobj import (Tcl_Obj, FromObj, FromTclString, AsObj, TypeCache,
                     FromBignumObj, FromWideIntObj)

import contextlib
import sys
import threading
import time
import warnings


class _DummyLock(object):
    "A lock-like object that does not do anything"
    def acquire(self):
        pass
    def release(self):
        pass
    def __enter__(self):
        pass
    def __exit__(self, *exc):
        pass


def varname_converter(input):
    if isinstance(input, Tcl_Obj):
        input = input.string
    if isinstance(input, str):
        input = input.encode('utf-8')
    if b'\0' in input:
        raise ValueError("NUL character in string")
    return input


def Tcl_AppInit(app):
    # For portable builds, try to load a local version of the libraries
    from os.path import join, dirname, exists, sep
    if sys.platform == 'win32':
        lib_path = join(dirname(dirname(dirname(__file__))), 'tcl')
        tcl_path = join(lib_path, 'tcl8.6')
        tk_path = join(lib_path, 'tk8.6')
        tcl_path = tcl_path.replace(sep, '/')
        tk_path = tk_path.replace(sep, '/')
    else:
        lib_path = join(dirname(dirname(dirname(__file__))), 'lib')
        tcl_path = join(lib_path, 'tcl')
        tk_path = join(lib_path, 'tk')
    if exists(tcl_path):
        tklib.Tcl_Eval(app.interp, 'set tcl_library "{0}"'.format(tcl_path).encode('utf-8'))
    if exists(tk_path):    
        tklib.Tcl_Eval(app.interp, 'set tk_library "{0}"'.format(tk_path).encode('utf-8'))

    if tklib.Tcl_Init(app.interp) == tklib.TCL_ERROR:
        app.raiseTclError()
    skip_tk_init = tklib.Tcl_GetVar(
        app.interp, b"_tkinter_skip_tk_init", tklib.TCL_GLOBAL_ONLY)
    if skip_tk_init and tkffi.string(skip_tk_init) == b"1":
        return

    if tklib.Tk_Init(app.interp) == tklib.TCL_ERROR:
        app.raiseTclError()

class _CommandData(object):
    def __new__(cls, app, name, func):
        self = object.__new__(cls)
        self.app = app
        self.name = name
        self.func = func
        handle = tkffi.new_handle(self)
        app._commands[name] = handle  # To keep the command alive
        return tkffi.cast("ClientData", handle)

    @tkffi.callback("Tcl_CmdProc")
    def PythonCmd(clientData, interp, argc, argv):
        self = tkffi.from_handle(clientData)
        assert self.app.interp == interp
        with self.app._tcl_lock_released():
            try:
                args = [FromTclString(tkffi.string(arg)) for arg in argv[1:argc]]
                result = self.func(*args)
                obj = AsObj(result)
                tklib.Tcl_SetObjResult(interp, obj)
            except:
                self.app.errorInCmd = True
                self.app.exc_info = sys.exc_info()
                return tklib.TCL_ERROR
            else:
                return tklib.TCL_OK

    @tkffi.callback("Tcl_CmdDeleteProc")
    def PythonCmdDelete(clientData):
        self = tkffi.from_handle(clientData)
        app = self.app
        del app._commands[self.name]
        return


class TkApp(object):
    _busywaitinterval = 0.02  # 20ms.

    def __new__(cls, screenName, className,
                interactive, wantobjects, wantTk, sync, use):
        if not wantobjects:
            raise NotImplementedError("wantobjects=True only")
        self = object.__new__(cls)
        self.interp = tklib.Tcl_CreateInterp()
        self._wantobjects = wantobjects
        self.threaded = bool(tklib.Tcl_GetVar2Ex(
            self.interp, b"tcl_platform", b"threaded",
            tklib.TCL_GLOBAL_ONLY))
        self.thread_id = tklib.Tcl_GetCurrentThread()
        self.dispatching = False
        self.quitMainLoop = False
        self.errorInCmd = False

        if not self.threaded:
            # TCL is not thread-safe, calls needs to be serialized.
            self._tcl_lock = threading.RLock()
        else:
            self._tcl_lock = _DummyLock()

        self._typeCache = TypeCache()
        self._commands = {}

        # Delete the 'exit' command, which can screw things up
        tklib.Tcl_DeleteCommand(self.interp, b"exit")

        if screenName is not None:
            tklib.Tcl_SetVar2(self.interp, b"env", b"DISPLAY",
                              screenName.encode('utf-8'),
                              tklib.TCL_GLOBAL_ONLY)

        if interactive:
            tklib.Tcl_SetVar(self.interp, b"tcl_interactive", b"1",
                             tklib.TCL_GLOBAL_ONLY)
        else:
            tklib.Tcl_SetVar(self.interp, b"tcl_interactive", b"0",
                             tklib.TCL_GLOBAL_ONLY)

        # This is used to get the application class for Tk 4.1 and up
        argv0 = className.lower().encode('utf-8')
        tklib.Tcl_SetVar(self.interp, b"argv0", argv0,
                         tklib.TCL_GLOBAL_ONLY)

        if not wantTk:
            tklib.Tcl_SetVar(self.interp, b"_tkinter_skip_tk_init", b"1",
                             tklib.TCL_GLOBAL_ONLY)

        # some initial arguments need to be in argv
        if sync or use:
            args = ""
            if sync:
                args += "-sync"
            if use:
                if sync:
                    args += " "
                args += "-use " + use

            tklib.Tcl_SetVar(self.interp, "argv", args,
                             tklib.TCL_GLOBAL_ONLY)

        Tcl_AppInit(self)
        # EnableEventHook()
        self._typeCache.add_extra_types(self)
        return self

    def __del__(self):
        tklib.Tcl_DeleteInterp(self.interp)
        # DisableEventHook()

    def raiseTclError(self):
        if self.errorInCmd:
            self.errorInCmd = False
            raise self.exc_info[1].with_traceback(self.exc_info[2])
        raise TclError(tkffi.string(
                tklib.Tcl_GetStringResult(self.interp)).decode('utf-8'))

    def wantobjects(self):
        return self._wantobjects

    def _check_tcl_appartment(self):
        if self.threaded and self.thread_id != tklib.Tcl_GetCurrentThread():
            raise RuntimeError("Calling Tcl from different appartment")

    @contextlib.contextmanager
    def _tcl_lock_released(self):
        "Context manager to temporarily release the tcl lock."
        self._tcl_lock.release()
        yield
        self._tcl_lock.acquire()

    def loadtk(self):
        # We want to guard against calling Tk_Init() multiple times
        err = tklib.Tcl_Eval(self.interp, b"info exists     tk_version")
        if err == tklib.TCL_ERROR:
            self.raiseTclError()
        tk_exists = tklib.Tcl_GetStringResult(self.interp)
        if not tk_exists or tkffi.string(tk_exists) != b"1":
            err = tklib.Tk_Init(self.interp)
            if err == tklib.TCL_ERROR:
                self.raiseTclError()

    def interpaddr(self):
        return int(tkffi.cast('size_t', self.interp))

    def _var_invoke(self, func, *args, **kwargs):
        if self.threaded and self.thread_id != tklib.Tcl_GetCurrentThread():
            # The current thread is not the interpreter thread.
            # Marshal the call to the interpreter thread, then wait
            # for completion.
            raise NotImplementedError("Call from another thread")
        return func(*args, **kwargs)

    def _getvar(self, name1, name2=None, global_only=False):
        name1 = varname_converter(name1)
        if not name2:
            name2 = tkffi.NULL
        flags=tklib.TCL_LEAVE_ERR_MSG
        if global_only:
            flags |= tklib.TCL_GLOBAL_ONLY
        with self._tcl_lock:
            res = tklib.Tcl_GetVar2Ex(self.interp, name1, name2, flags)
            if not res:
                self.raiseTclError()
            assert self._wantobjects
            return FromObj(self, res)

    def _setvar(self, name1, value, global_only=False):
        name1 = varname_converter(name1)
        # XXX Acquire tcl lock???
        newval = AsObj(value)
        flags=tklib.TCL_LEAVE_ERR_MSG
        if global_only:
            flags |= tklib.TCL_GLOBAL_ONLY
        with self._tcl_lock:
            res = tklib.Tcl_SetVar2Ex(self.interp, name1, tkffi.NULL,
                                      newval, flags)
            if not res:
                self.raiseTclError()

    def _unsetvar(self, name1, name2=None, global_only=False):
        name1 = varname_converter(name1)
        if not name2:
            name2 = tkffi.NULL
        flags=tklib.TCL_LEAVE_ERR_MSG
        if global_only:
            flags |= tklib.TCL_GLOBAL_ONLY
        with self._tcl_lock:
            res = tklib.Tcl_UnsetVar2(self.interp, name1, name2, flags)
            if res == tklib.TCL_ERROR:
                self.raiseTclError()

    def getvar(self, name1, name2=None):
        return self._var_invoke(self._getvar, name1, name2)

    def globalgetvar(self, name1, name2=None):
        return self._var_invoke(self._getvar, name1, name2, global_only=True)

    def setvar(self, name1, value):
        return self._var_invoke(self._setvar, name1, value)

    def globalsetvar(self, name1, value):
        return self._var_invoke(self._setvar, name1, value, global_only=True)

    def unsetvar(self, name1, name2=None):
        return self._var_invoke(self._unsetvar, name1, name2)

    def globalunsetvar(self, name1, name2=None):
        return self._var_invoke(self._unsetvar, name1, name2, global_only=True)

    # COMMANDS

    def createcommand(self, cmdName, func):
        if not callable(func):
            raise TypeError("command not callable")

        if self.threaded and self.thread_id != tklib.Tcl_GetCurrentThread():
            raise NotImplementedError("Call from another thread")

        clientData = _CommandData(self, cmdName, func)

        if self.threaded and self.thread_id != tklib.Tcl_GetCurrentThread():
            raise NotImplementedError("Call from another thread")

        with self._tcl_lock:
            res = tklib.Tcl_CreateCommand(
                self.interp, cmdName.encode('utf-8'), _CommandData.PythonCmd,
                clientData, _CommandData.PythonCmdDelete)
        if not res:
            raise TclError("can't create Tcl command")

    def deletecommand(self, cmdName):
        if self.threaded and self.thread_id != tklib.Tcl_GetCurrentThread():
            raise NotImplementedError("Call from another thread")

        with self._tcl_lock:
            res = tklib.Tcl_DeleteCommand(self.interp, cmdName.encode('utf-8'))
        if res == -1:
            raise TclError("can't delete Tcl command")

    def call(self, *args):
        flags = tklib.TCL_EVAL_DIRECT | tklib.TCL_EVAL_GLOBAL

        # If args is a single tuple, replace with contents of tuple
        if len(args) == 1 and isinstance(args[0], tuple):
            args = args[0]

        if self.threaded and self.thread_id != tklib.Tcl_GetCurrentThread():
            # We cannot call the command directly. Instead, we must
            # marshal the parameters to the interpreter thread.
            raise NotImplementedError("Call from another thread")

        objects = tkffi.new("Tcl_Obj*[]", len(args))
        argc = len(args)
        try:
            for i, arg in enumerate(args):
                if arg is None:
                    argc = i
                    break
                obj = AsObj(arg)
                tklib.Tcl_IncrRefCount(obj)
                objects[i] = obj

            with self._tcl_lock:
                res = tklib.Tcl_EvalObjv(self.interp, argc, objects, flags)
                if res == tklib.TCL_ERROR:
                    self.raiseTclError()
                else:
                    result = self._callResult()
        finally:
            for obj in objects:
                if obj:
                    tklib.Tcl_DecrRefCount(obj)
        return result

    def _callResult(self):
        assert self._wantobjects
        value = tklib.Tcl_GetObjResult(self.interp)
        # Not sure whether the IncrRef is necessary, but something
        # may overwrite the interpreter result while we are
        # converting it.
        tklib.Tcl_IncrRefCount(value)
        res = FromObj(self, value)
        tklib.Tcl_DecrRefCount(value)
        return res

    def eval(self, script):
        self._check_tcl_appartment()
        with self._tcl_lock:
            res = tklib.Tcl_Eval(self.interp, script.encode('utf-8'))
            if res == tklib.TCL_ERROR:
                self.raiseTclError()
            result = tkffi.string(tklib.Tcl_GetStringResult(self.interp))
            return FromTclString(result)

    def evalfile(self, filename):
        self._check_tcl_appartment()
        with self._tcl_lock:
            res = tklib.Tcl_EvalFile(self.interp, filename.encode('utf-8'))
            if res == tklib.TCL_ERROR:
                self.raiseTclError()
            result = tkffi.string(tklib.Tcl_GetStringResult(self.interp))
            return FromTclString(result)

    def split(self, arg):
        warnings.warn("split() is deprecated; consider using splitlist() instead",
                      DeprecationWarning)
        if isinstance(arg, Tcl_Obj):
            objc = tkffi.new("int*")
            objv = tkffi.new("Tcl_Obj***")
            status = tklib.Tcl_ListObjGetElements(self.interp, arg._value, objc, objv)
            if status == tklib.TCL_ERROR:
                return FromObj(self, arg._value)
            if objc == 0:
                return ''
            elif objc == 1:
                return FromObj(self, objv[0][0])
            result = []
            for i in range(objc[0]):
                result.append(FromObj(self, objv[0][i]))
            return tuple(result)
        elif isinstance(arg, (tuple, list)):
            return self._splitObj(arg)
        if isinstance(arg, str):
            arg = arg.encode('utf-8')
        return self._split(arg)

    def splitlist(self, arg):
        if isinstance(arg, Tcl_Obj):
            objc = tkffi.new("int*")
            objv = tkffi.new("Tcl_Obj***")
            status = tklib.Tcl_ListObjGetElements(self.interp, arg._value, objc, objv)
            if status == tklib.TCL_ERROR:
                self.raiseTclError()
            result = []
            for i in range(objc[0]):
                result.append(FromObj(self, objv[0][i]))
            return tuple(result)
        elif isinstance(arg, tuple):
            return arg
        elif isinstance(arg, list):
            return tuple(arg)
        elif isinstance(arg, str):
            arg = arg.encode('utf8')

        argc = tkffi.new("int*")
        argv = tkffi.new("char***")
        res = tklib.Tcl_SplitList(self.interp, arg, argc, argv)
        if res == tklib.TCL_ERROR:
            self.raiseTclError()

        result = tuple(FromTclString(tkffi.string(argv[0][i]))
                       for i in range(argc[0]))
        tklib.Tcl_Free(argv[0])
        return result

    def _splitObj(self, arg):
        if isinstance(arg, tuple):
            size = len(arg)
            result = None
            # Recursively invoke SplitObj for all tuple items.
            # If this does not return a new object, no action is
            # needed.
            for i in range(size):
                elem = arg[i]
                newelem = self._splitObj(elem)
                if result is None:
                    if newelem == elem:
                        continue
                    result = [None] * size
                    for k in range(i):
                        result[k] = arg[k]
                result[i] = newelem
            if result is not None:
                return tuple(result)
        if isinstance(arg, list):
            # Recursively invoke SplitObj for all list items.
            return tuple(self._splitObj(elem) for elem in arg)
        elif isinstance(arg, str):
            argc = tkffi.new("int*")
            argv = tkffi.new("char***")
            list_ = arg.encode('utf-8')
            res = tklib.Tcl_SplitList(tkffi.NULL, list_, argc, argv)
            if res != tklib.TCL_OK:
                return arg
            tklib.Tcl_Free(argv[0])
            if argc[0] > 1:
                return self._split(list_)
        elif isinstance(arg, bytes):
            argc = tkffi.new("int*")
            argv = tkffi.new("char***")
            list_ = arg
            res = tklib.Tcl_SplitList(tkffi.NULL, list_, argc, argv)
            if res != tklib.TCL_OK:
                return arg
            tklib.Tcl_Free(argv[0])
            if argc[0] > 1:
                return self._split(list_)
        return arg

    def _split(self, arg):
        argc = tkffi.new("int*")
        argv = tkffi.new("char***")
        res = tklib.Tcl_SplitList(tkffi.NULL, arg, argc, argv)
        if res == tklib.TCL_ERROR:
            # Not a list.
            # Could be a quoted string containing funnies, e.g. {"}.
            # Return the string itself.
            return FromTclString(arg)

        try:
            if argc[0] == 0:
                return ""
            elif argc[0] == 1:
                return FromTclString(tkffi.string(argv[0][0]))
            else:
                return tuple(self._split(argv[0][i])
                             for i in range(argc[0]))
        finally:
            tklib.Tcl_Free(argv[0])

    def merge(self, *args):
        warnings.warn("merge is deprecated and will be removed in 3.4",
                      DeprecationWarning)
        s = self._merge(args)
        return s.decode('utf-8')

    def _merge(self, args):
        argv = []
        for arg in args:
            if isinstance(arg, tuple):
                argv.append(self._merge(arg))
            elif arg is None:
                break
            elif isinstance(arg, bytes):
                argv.append(arg)
            else:
                argv.append(str(arg).encode('utf-8'))
        argv_array = [tkffi.new("char[]", arg) for arg in argv]
        res = tklib.Tcl_Merge(len(argv), argv_array)
        if not res:
            raise TclError("merge failed")
        try:
            return tkffi.string(res)
        finally:
            tklib.Tcl_Free(res)

    def getboolean(self, s):
        if isinstance(s, int):
            return bool(s)
        try:
            s = s.encode('utf-8')
        except AttributeError:
            raise TypeError
        if b'\x00' in s:
            raise TypeError
        v = tkffi.new("int*")
        res = tklib.Tcl_GetBoolean(self.interp, s, v)
        if res == tklib.TCL_ERROR:
            self.raiseTclError()
        return bool(v[0])

    def getint(self, s):
        if isinstance(s, int):
            return s
        try:
            s = s.encode('utf-8')
        except AttributeError:
            raise TypeError
        if b'\x00' in s:
            raise TypeError
        if tklib.HAVE_LIBTOMMATH or tklib.HAVE_WIDE_INT_TYPE:
            value = tklib.Tcl_NewStringObj(s, -1)
            if not value:
                self.raiseTclError()
            try:
                if tklib.HAVE_LIBTOMMATH:
                    return FromBignumObj(self, value)
                else:
                    return FromWideIntObj(self, value)
            finally:
                tklib.Tcl_DecrRefCount(value)
        else:
            v = tkffi.new("int*")
            res = tklib.Tcl_GetInt(self.interp, s, v)
            if res == tklib.TCL_ERROR:
                self.raiseTclError()
            return v[0]

    def getdouble(self, s):
        if isinstance(s, (float, int)):
            return float(s)
        try:
            s = s.encode('utf-8')
        except AttributeError:
            raise TypeError
        if b'\x00' in s:
            raise TypeError
        v = tkffi.new("double*")
        res = tklib.Tcl_GetDouble(self.interp, s, v)
        if res == tklib.TCL_ERROR:
            self.raiseTclError()
        return v[0]

    def exprboolean(self, s):
        if '\x00' in s:
            raise TypeError
        s = s.encode('utf-8')
        v = tkffi.new("int*")
        res = tklib.Tcl_ExprBoolean(self.interp, s, v)
        if res == tklib.TCL_ERROR:
            self.raiseTclError()
        return v[0]

    def exprlong(self, s):
        if '\x00' in s:
            raise TypeError
        s = s.encode('utf-8')
        v = tkffi.new("long*")
        res = tklib.Tcl_ExprLong(self.interp, s, v)
        if res == tklib.TCL_ERROR:
            self.raiseTclError()
        return v[0]

    def exprdouble(self, s):
        if '\x00' in s:
            raise TypeError
        s = s.encode('utf-8')
        v = tkffi.new("double*")
        res = tklib.Tcl_ExprDouble(self.interp, s, v)
        if res == tklib.TCL_ERROR:
            self.raiseTclError()
        return v[0]

    def exprstring(self, s):
        if '\x00' in s:
            raise TypeError
        s = s.encode('utf-8')
        res = tklib.Tcl_ExprString(self.interp, s)
        if res == tklib.TCL_ERROR:
            self.raiseTclError()
        return FromTclString(tkffi.string(
            tklib.Tcl_GetStringResult(self.interp)))

    def mainloop(self, threshold):
        self._check_tcl_appartment()
        self.dispatching = True
        while (tklib.Tk_GetNumMainWindows() > threshold and
               not self.quitMainLoop and not self.errorInCmd):

            if self.threaded:
                result = tklib.Tcl_DoOneEvent(0)
            else:
                with self._tcl_lock:
                    result = tklib.Tcl_DoOneEvent(tklib.TCL_DONT_WAIT)
                if result == 0:
                    time.sleep(self._busywaitinterval)

            if result < 0:
                break
        self.dispatching = False
        self.quitMainLoop = False
        if self.errorInCmd:
            self.errorInCmd = False
            raise self.exc_info[1].with_traceback(self.exc_info[2])

    def quit(self):
        self.quitMainLoop = True

    def _createbytearray(self, buf):
        """Convert Python string or any buffer compatible object to Tcl
        byte-array object.  Use it to pass binary data (e.g. image's
        data) to Tcl/Tk commands."""
        cdata = tkffi.new("char[]", buf)
        res = tklib.Tcl_NewByteArrayObj(cdata, len(buf))
        if not res:
            self.raiseTclError()
        return TclObject(res)
