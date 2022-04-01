from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rtyper.lltypesystem import rffi, lltype
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter import executioncontext
from pypy.interpreter.executioncontext import ExecutionContext
from rpython.rtyper.annlowlevel import llhelper
from rpython.rlib.rdynload import DLLHANDLE
from rpython.rlib import rawrefcount, rgil
import sys


# Keep track of exceptions raised in cpyext for a particular execution
# context.
ExecutionContext.cpyext_operror = None


class State:
    def __init__(self, space):
        self.space = space
        self.reset()
        self.programname = lltype.nullptr(rffi.CWCHARP.TO)
        self.version = lltype.nullptr(rffi.CCHARP.TO)
        self.builder = None
        self.C = CNamespace()

    def reset(self):
        from pypy.module.cpyext.modsupport import PyMethodDef
        ec = self.space.getexecutioncontext()
        ec.cpyext_operror = None
        self.new_method_def = lltype.nullptr(PyMethodDef)

        # When importing a package, use this to keep track
        # of its name and path (as a 2-tuple).  This is
        # necessary because an extension module in a package might not supply
        # its own fully qualified name to Py_InitModule.  If it doesn't, we need
        # to be able to figure out what module is being initialized.  Recursive
        # imports will clobber this value, which might be confusing, but it
        # doesn't hurt anything because the code that cares about it will have
        # already read it by that time.
        self.package_context = None, None

        # A mapping {filename: copy-of-the-w_dict}, similar to CPython's
        # variable 'extensions' in Python/import.c.
        self.extensions = {}
        # XXX will leak if _PyDateTime_Import already called
        self.datetimeAPI = []

        self.cpyext_is_imported = False

    def make_sure_cpyext_is_imported(self):
        if not self.cpyext_is_imported:
            self.space.getbuiltinmodule("cpyext")    # mandatory to init cpyext
            self.cpyext_is_imported = True

    def set_exception(self, operror):
        self.clear_exception()
        ec = self.space.getexecutioncontext()
        ec.cpyext_operror = operror

    def clear_exception(self):
        """Clear the current exception state, and return the operror."""
        ec = self.space.getexecutioncontext()
        operror = ec.cpyext_operror
        ec.cpyext_operror = None
        return operror

    def get_exception(self):
        ec = self.space.getexecutioncontext()
        return ec.cpyext_operror

    @specialize.arg(1)
    def check_and_raise_exception(self, always=False):
        ec = self.space.getexecutioncontext()
        operror = ec.cpyext_operror
        if operror:
            self.clear_exception()
            raise operror
        if always:
            raise oefmt(self.space.w_SystemError,
                        "Function returned an error result without setting an "
                        "exception")

    def setup_rawrefcount(self):
        space = self.space
        if not self.space.config.translating:
            def dealloc_trigger():
                from pypy.module.cpyext.pyobject import PyObject, decref
                print 'dealloc_trigger...'
                while True:
                    ob = rawrefcount.next_dead(PyObject)
                    if not ob:
                        break
                    print 'deallocating PyObject', ob
                    decref(space, ob)
                print 'dealloc_trigger DONE'
                return "RETRY"
            rawrefcount.init(dealloc_trigger)
        else:
            if space.config.translation.gc == "boehm":
                action = BoehmPyObjDeallocAction(space)
                space.actionflag.register_periodic_action(action,
                    use_bytecode_counter=True)
            else:
                pyobj_dealloc_action = PyObjDeallocAction(space)
                self.dealloc_trigger = lambda: pyobj_dealloc_action.fire()

    def build_api(self):
        """NOT_RPYTHON
        This function is called when at object space creation,
        and drives the compilation of the cpyext library
        """
        self.setup_rawrefcount()
        from pypy.module.cpyext import api
        if not self.space.config.translating:
            self.api_lib = str(api.build_bridge(self.space))
        else:
            api.setup_library(self.space)

    def install_dll(self, eci):
        """NOT_RPYTHON
        Called when the dll has been compiled"""
        if sys.platform == 'win32':
            self.get_pythonapi_handle = rffi.llexternal(
                'pypy_get_pythonapi_handle', [], DLLHANDLE,
                compilation_info=eci)

    def startup(self, space):
        "This function is called when the program really starts"
        from pypy.module.cpyext.typeobject import setup_new_method_def
        from pypy.module.cpyext.api import INIT_FUNCTIONS

        if we_are_translated():
            if space.config.translation.gc != "boehm":
                # This must be called in RPython, the untranslated version
                # does something different. Sigh.
                rawrefcount.init(
                    llhelper(rawrefcount.RAWREFCOUNT_DEALLOC_TRIGGER,
                    self.dealloc_trigger))
            self.builder.attach_all(space)

        setup_new_method_def(space)

        for func in INIT_FUNCTIONS:
            func(space)
            self.check_and_raise_exception()

    def get_programname(self):
        if not self.programname:
            space = self.space
            argv = space.sys.get('argv')
            if space.len_w(argv):
                argv0 = space.getitem(argv, space.newint(0))
                progname = space.utf8_w(argv0)
                lgt = space.len_w(argv0)
            else:
                progname = "pypy3"
                lgt = len(progname)
            self.programname = rffi.utf82wcharp(progname, lgt)
            lltype.render_immortal(self.programname)
        return self.programname

    def get_version(self):
        if not self.version:
            space = self.space
            w_version = space.sys.get('version')
            version = space.text_w(w_version)
            self.version = rffi.str2charp(version)
            lltype.render_immortal(self.version)
        return self.version
        foo = self.import_module(name='foo', init=init)

    def find_extension(self, name, path):
        from pypy.module.cpyext.import_ import PyImport_AddModule
        from pypy.interpreter.module import Module
        try:
            w_dict = self.extensions[path]
        except KeyError:
            return None
        with rffi.scoped_str2charp(name) as ll_name:
            w_mod = PyImport_AddModule(self.space, ll_name)
        assert isinstance(w_mod, Module)
        w_mdict = w_mod.getdict(self.space)
        self.space.call_method(w_mdict, 'update', w_dict)
        return w_mod

    def fixup_extension(self, w_mod, name, path):
        from pypy.interpreter.module import Module
        space = self.space
        w_modules = space.sys.get('modules')
        space.setitem_str(w_modules, name, w_mod)
        w_dict = w_mod.getdict(space)
        w_copy = space.call_method(w_dict, 'copy')
        self.extensions[path] = w_copy
        return w_mod

    @specialize.arg(1)
    def ccall(self, name, *args):
        return getattr(self.C, name)(*args)


class CNamespace:
    def _freeze_(self):
        return True


def _rawrefcount_perform(space):
    from pypy.module.cpyext.pyobject import PyObject, decref
    while True:
        py_obj = rawrefcount.next_dead(PyObject)
        if not py_obj:
            break
        decref(space, py_obj)

class PyObjDeallocAction(executioncontext.AsyncAction):
    """An action that invokes _Py_Dealloc() on the dying PyObjects.
    """
    def perform(self, executioncontext, frame):
        _rawrefcount_perform(self.space)

class BoehmPyObjDeallocAction(executioncontext.PeriodicAsyncAction):
    # This variant is used with Boehm, which doesn't have the explicit
    # callback.  Instead we must periodically check ourselves.
    def perform(self, executioncontext, frame):
        if we_are_translated():
            _rawrefcount_perform(self.space)
