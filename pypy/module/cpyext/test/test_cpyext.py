import sys

import pytest

from pypy.tool.cpyext.extbuild import SystemCompilationInfo, HERE
from pypy.interpreter.gateway import unwrap_spec, interp2app
from pypy.interpreter.error import OperationError
from rpython.rtyper.lltypesystem import lltype
from pypy.module.cpyext import api
from pypy.module.cpyext.api import cts, create_extension_module
from pypy.module.cpyext.pyobject import from_ref
from pypy.module.cpyext.state import State
from rpython.tool import leakfinder
from rpython.rlib import rawrefcount
from rpython.tool.udir import udir

import pypy.module.cpyext.moduledef  # Make sure all the functions are registered

only_pypy ="config.option.runappdirect and '__pypy__' not in sys.builtin_module_names"

@api.cpython_api([], api.PyObject)
def PyPy_Crash1(space):
    1/0

@api.cpython_api([], lltype.Signed, error=-1)
def PyPy_Crash2(space):
    1/0

@api.cpython_api([api.PyObject], api.PyObject, result_is_ll=True)
def PyPy_Noop(space, pyobj):
    return pyobj

class TestApi:
    def test_signature(self):
        common_functions = api.FUNCTIONS_BY_HEADER[api.pypy_decl]
        assert 'PyModule_Check' in common_functions
        assert common_functions['PyModule_Check'].argtypes == [cts.gettype("void *")]
        assert 'PyModule_GetDict' in common_functions
        assert common_functions['PyModule_GetDict'].argtypes == [api.PyObject]


class SpaceCompiler(SystemCompilationInfo):
    """Extension compiler for regular (untranslated PyPy) mode"""
    def __init__(self, space, *args, **kwargs):
        self.space = space
        SystemCompilationInfo.__init__(self, *args, **kwargs)

    def load_module(self, mod, name, use_imp=False):
        space = self.space
        w_path = space.newtext(mod)
        w_name = space.newtext(name)
        if use_imp:
            # this is VERY slow and should be used only by tests which
            # actually needs it
            return space.appexec([w_name, w_path], '''(name, path):
                import imp
                return imp.load_dynamic(name, path)''')
        else:
            w_spec = space.appexec([w_name, w_path], '''(modname, path):
                class FakeSpec:
                    name = modname
                    origin = path
                return FakeSpec
            ''')
            w_mod = create_extension_module(space, w_spec)
            return w_mod


def get_cpyext_info(space):
    from pypy.module.imp.importing import get_so_extension
    state = space.fromcache(State)
    api_library = state.api_lib
    if sys.platform == 'win32':
        libraries = [api_library]
        # '%s' undefined; assuming extern returning int
        compile_extra = ["/we4013"]
        # prevent linking with PythonXX.lib
        w_maj, w_min = space.fixedview(space.sys.get('version_info'), 5)[:2]
        link_extra = ["/NODEFAULTLIB:Python%d%d.lib" %
            (space.int_w(w_maj), space.int_w(w_min))]
    else:
        libraries = []
        if sys.platform.startswith('linux'):
            compile_extra = [
                "-Werror", "-g", "-O0", "-Wp,-U_FORTIFY_SOURCE", "-fPIC"]
            link_extra = ["-g"]
        else:
            compile_extra = link_extra = None
    return SpaceCompiler(space,
        builddir_base=udir,
        include_extra=api.include_dirs,
        compile_extra=compile_extra,
        link_extra=link_extra,
        extra_libs=libraries,
        ext=get_so_extension(space))


def freeze_refcnts(self):
    rawrefcount._dont_free_any_more()

def is_interned_string(space, w_obj):
    try:
        u = space.utf8_w(w_obj)
    except OperationError:
        return False
    return space.interned_strings.get(u) is not None

def is_allowed_to_leak(space, obj):
    from pypy.module.cpyext.methodobject import W_PyCFunctionObject
    try:
        w_obj = from_ref(space, cts.cast('PyObject*', obj._as_ptr()))
    except:
        return False
    if isinstance(w_obj, W_PyCFunctionObject):
        return True
    # It's OK to "leak" some interned strings: if the pyobj is created by
    # the test, but the w_obj is referred to from elsewhere.
    return is_interned_string(space, w_obj)

def _get_w_obj(space, c_obj):
    return from_ref(space, cts.cast('PyObject*', c_obj._as_ptr()))

class CpyextLeak(leakfinder.MallocMismatch):
    def __str__(self):
        lines = [leakfinder.MallocMismatch.__str__(self), '']
        lines.append(
            "These objects are attached to the following W_Root objects:")
        for c_obj in self.args[0]:
            try:
                lines.append("  %s" % (_get_w_obj(self.args[1], c_obj),))
            except:
                pass
        return '\n'.join(lines)


class LeakCheckingTest(object):
    """Base class for all cpyext tests."""
    spaceconfig = {"usemodules" : ['cpyext', 'thread', 'struct', 'array',
                                   'itertools', 'time', 'binascii', 'mmap',
                                   '_cffi_backend',
                                   ],
                   "objspace.disable_entrypoints_in_cffi": True}
    spaceconfig["objspace.std.withspecialisedtuple"] = True

    @classmethod
    def preload_builtins(cls, space):
        """
        Eagerly create pyobjs for various builtins so they don't look like
        leaks.
        """
        from pypy.module.cpyext.pyobject import make_ref
        w_to_preload = space.appexec([], """():
            import sys
            import mmap
            #
            # copied&pasted to avoid importing the whole types.py, which is
            # expensive on py3k
            # <types.py>
            def _f(): pass
            FunctionType = type(_f)
            CodeType = type(_f.__code__)
            try:
                raise TypeError
            except TypeError:
                tb = sys.exc_info()[2]
                TracebackType = type(tb)
                FrameType = type(tb.tb_frame)
                del tb
            # </types.py>
            return [
                #buffer,   ## does not exist on py3k
                mmap.mmap,
                FunctionType,
                CodeType,
                TracebackType,
                FrameType,
                type(str.join),
            ]
        """)
        for w_obj in space.unpackiterable(w_to_preload):
            make_ref(space, w_obj)

    def cleanup(self):
        self.space.getexecutioncontext().cleanup_cpyext_state()
        for _ in range(5):
            rawrefcount._collect()
            self.space.user_del_action._run_finalizers()
        try:
            # set check=True to actually enable leakfinder
            leakfinder.stop_tracking_allocations(check=False)
        except leakfinder.MallocMismatch as e:
            result = e.args[0]
            filtered_result = {}
            for obj, value in result.iteritems():
                if not is_allowed_to_leak(self.space, obj):
                    filtered_result[obj] = value
            if filtered_result:
                raise CpyextLeak(filtered_result, self.space)
        assert not self.space.finalizer_queue.next_dead()


class AppTestApi(LeakCheckingTest):
    def setup_class(cls):
        from rpython.rlib.clibffi import get_libc_name
        if cls.runappdirect:
            cls.libc = get_libc_name()
        else:
            cls.w_libc = cls.space.wrap(get_libc_name())

    def setup_method(self, meth):
        if not self.runappdirect:
            freeze_refcnts(self)

    def teardown_method(self, meth):
        if self.runappdirect:
            return
        self.cleanup()

    @pytest.mark.skipif(only_pypy, reason='pypy only test')
    def test_only_import(self):
        import cpyext

    def test_dllhandle(self):
        import sys
        if sys.platform != "win32" or sys.version_info < (2, 6):
            skip("Windows Python >= 2.6 only")
        assert isinstance(sys.dllhandle, int)


def _unwrap_include_dirs(space, w_include_dirs):
    if w_include_dirs is None:
        return None
    else:
        return [space.text_w(s) for s in space.listview(w_include_dirs)]

def debug_collect(space):
    rawrefcount._collect()


class AppTestCpythonExtensionBase(LeakCheckingTest):
    def setup_class(cls):
        space = cls.space
        cls.w_here = space.wrap(str(HERE))
        cls.w_udir = space.wrap(str(udir))
        cls.w_runappdirect = space.wrap(cls.runappdirect)
        if not cls.runappdirect:
            cls.sys_info = get_cpyext_info(space)
            cls.w_debug_collect = space.wrap(interp2app(debug_collect))
            cls.preload_builtins(space)
        else:
            def w_import_module(self, name, init=None, body='', filename=None,
                    include_dirs=None, PY_SSIZE_T_CLEAN=False, use_imp=False):
                from extbuild import get_sys_info_app
                sys_info = get_sys_info_app(self.udir)
                return sys_info.import_module(
                    name, init=init, body=body, filename=filename,
                    include_dirs=include_dirs,
                    PY_SSIZE_T_CLEAN=PY_SSIZE_T_CLEAN)
            cls.w_import_module = w_import_module

            def w_import_extension(self, modname, functions, prologue="",
                include_dirs=None, more_init="", PY_SSIZE_T_CLEAN=False):
                from extbuild import get_sys_info_app
                sys_info = get_sys_info_app(self.udir)
                return sys_info.import_extension(
                    modname, functions, prologue=prologue,
                    include_dirs=include_dirs, more_init=more_init,
                    PY_SSIZE_T_CLEAN=PY_SSIZE_T_CLEAN)
            cls.w_import_extension = w_import_extension

            def w_compile_module(self, name,
                    source_files=None, source_strings=None):
                from extbuild import get_sys_info_app
                sys_info = get_sys_info_app(self.udir)
                return sys_info.compile_extension_module(name,
                    source_files=source_files, source_strings=source_strings)
            cls.w_compile_module = w_compile_module

            def w_load_module(self, mod, name):
                from extbuild import get_sys_info_app
                sys_info = get_sys_info_app(self.udir)
                return sys_info.load_module(mod, name)
            cls.w_load_module = w_load_module

            def w_debug_collect(self):
                import gc
                gc.collect()
                gc.collect()
                gc.collect()
            cls.w_debug_collect = w_debug_collect


    def record_imported_module(self, name):
        """
        Record a module imported in a test so that it can be cleaned up in
        teardown before the check for leaks is done.

        name gives the name of the module in the space's sys.modules.
        """
        self.imported_module_names.append(name)

    def setup_method(self, func):
        if self.runappdirect:
            return

        @unwrap_spec(name='text')
        def compile_module(space, name,
                           w_source_files=None,
                           w_source_strings=None):
            """
            Build an extension module linked against the cpyext api library.
            """
            if not space.is_none(w_source_files):
                source_files = space.unwrap(w_source_files)
            else:
                source_files = None
            if not space.is_none(w_source_strings):
                source_strings = space.listview_bytes(w_source_strings)
            else:
                source_strings = None
            pydname = self.sys_info.compile_extension_module(
                name,
                source_files=source_files,
                source_strings=source_strings)

            # hackish, but tests calling compile_module() always end up
            # importing the result
            self.record_imported_module(name)

            return space.wrap(pydname)

        @unwrap_spec(name='text', init='text_or_none', body='text',
                     filename='fsencode_or_none', PY_SSIZE_T_CLEAN=bool,
                     use_imp=bool)
        def import_module(space, name, init=None, body='',
                          filename=None, w_include_dirs=None,
                          PY_SSIZE_T_CLEAN=False, use_imp=False):
            include_dirs = _unwrap_include_dirs(space, w_include_dirs)
            w_result = self.sys_info.import_module(
                name, init, body, filename, include_dirs, PY_SSIZE_T_CLEAN,
                use_imp)
            self.record_imported_module(name)
            return w_result


        @unwrap_spec(mod='text', name='text')
        def load_module(space, mod, name):
            return self.sys_info.load_module(mod, name)

        @unwrap_spec(modname='text', prologue='text',
                             more_init='text', PY_SSIZE_T_CLEAN=bool)
        def import_extension(space, modname, w_functions, prologue="",
                             w_include_dirs=None, more_init="", PY_SSIZE_T_CLEAN=False):
            functions = space.unwrap(w_functions)
            include_dirs = _unwrap_include_dirs(space, w_include_dirs)
            w_result = self.sys_info.import_extension(
                modname, functions, prologue, include_dirs, more_init,
                PY_SSIZE_T_CLEAN)
            self.record_imported_module(modname)
            return w_result

        # A list of modules which the test caused to be imported (in
        # self.space).  These will be cleaned up automatically in teardown.
        self.imported_module_names = []

        wrap = self.space.wrap
        self.w_compile_module = wrap(interp2app(compile_module))
        self.w_load_module = wrap(interp2app(load_module))
        self.w_import_module = wrap(interp2app(import_module))
        self.w_import_extension = wrap(interp2app(import_extension))

        # create the file lock before we count allocations
        self.space.call_method(self.space.sys.get("stdout"), "flush")

        freeze_refcnts(self)

    def unimport_module(self, name):
        """
        Remove the named module from the space's sys.modules.
        """
        w_modules = self.space.sys.get('modules')
        w_name = self.space.wrap(name)
        self.space.delitem(w_modules, w_name)

    def teardown_method(self, func):
        if self.runappdirect:
            self.w_debug_collect()
            return
        debug_collect(self.space)
        for name in self.imported_module_names:
            self.unimport_module(name)
        self.cleanup()
        state = self.space.fromcache(State)
        assert 'operror' not in dir(state)


class AppTestCpythonExtension(AppTestCpythonExtensionBase):
    def test_createmodule(self):
        import sys
        self.import_module(name='foo')
        assert 'foo' in sys.modules

    def test_export_function(self):
        import sys
        if '__pypy__' in sys.modules:
            from cpyext import is_cpyext_function
        else:
            import inspect
            is_cpyext_function = inspect.isbuiltin
        body = """
        PyObject* foo_pi(PyObject* self, PyObject *args)
        {
            return PyFloat_FromDouble(3.14);
        }
        static PyMethodDef methods[] = {
            { "return_pi", foo_pi, METH_NOARGS },
            { NULL }
        };
        static struct PyModuleDef moduledef = {
            PyModuleDef_HEAD_INIT,
            "foo",          /* m_name */
            NULL,           /* m_doc */
            -1,             /* m_size */
            methods,        /* m_methods */
        };
        """
        module = self.import_module(name='foo', body=body)
        assert 'foo' in sys.modules
        assert 'return_pi' in dir(module)
        assert module.return_pi is not None
        assert is_cpyext_function(module.return_pi)
        assert module.return_pi() == 3.14
        assert module.return_pi.__module__ == 'foo'


    def test_export_docstring(self):
        body = """
        PyDoc_STRVAR(foo_pi_doc, "Return pi.");
        PyObject* foo_pi(PyObject* self, PyObject *args)
        {
            return PyFloat_FromDouble(3.14);
        }
        static PyMethodDef methods[] = {
            { "return_pi", foo_pi, METH_NOARGS, foo_pi_doc },
            { NULL }
        };
        static struct PyModuleDef moduledef = {
            PyModuleDef_HEAD_INIT,
            "foo",          /* m_name */
            NULL,           /* m_doc */
            -1,             /* m_size */
            methods,        /* m_methods */
        };
        """
        module = self.import_module(name='foo', body=body)
        doc = module.return_pi.__doc__
        assert doc == "Return pi."

    def test_load_dynamic(self):
        import sys
        body = """
        static struct PyModuleDef moduledef = {
            PyModuleDef_HEAD_INIT,
            "%(modname)s",  /* m_name */
            NULL,           /* m_doc */
            -1,             /* m_size */
            NULL,           /* m_methods */
        };
        """
        foo = self.import_module(name='foo', body=body, use_imp=True)
        assert 'foo' in sys.modules
        del sys.modules['foo']
        import imp
        foo2 = imp.load_dynamic('foo', foo.__file__)
        assert 'foo' in sys.modules
        assert foo.__dict__ == foo2.__dict__

    def test_InitModule4_dotted(self):
        """
        If the module name passed to Py_InitModule4 includes a package, only
        the module name (the part after the last dot) is considered when
        computing the name of the module initializer function.
        """
        expected_name = "pypy.module.cpyext.test.dotted"
        module = self.import_module(name=expected_name, filename="dotted")
        assert module.__name__ == expected_name


    def test_InitModule4_in_package(self):
        """
        If `apple.banana` is an extension module which calls Py_InitModule4 with
        only "banana" as a name, the resulting module nevertheless is stored at
        `sys.modules["apple.banana"]`.
        """
        module = self.import_module(name="apple.banana", filename="banana")
        assert module.__name__ == "apple.banana"


    def test_recursive_package_import(self):
        """
        If `cherry.date` is an extension module which imports `apple.banana`,
        the latter is added to `sys.modules` for the `"apple.banana"` key.
        """
        import sys, types, os
        # Build the extensions.
        banana = self.compile_module(
            "apple.banana", source_files=[os.path.join(self.here, 'banana.c')])
        date = self.compile_module(
            "cherry.date", source_files=[os.path.join(self.here, 'date.c')])

        # Set up some package state so that the extensions can actually be
        # imported.
        cherry = sys.modules['cherry'] = types.ModuleType('cherry')
        cherry.__path__ = [os.path.dirname(date)]

        apple = sys.modules['apple'] = types.ModuleType('apple')
        apple.__path__ = [os.path.dirname(banana)]

        import cherry.date

        assert sys.modules['apple.banana'].__name__ == 'apple.banana'
        assert sys.modules['cherry.date'].__name__ == 'cherry.date'


    def test_modinit_func(self):
        """
        A module can use the PyMODINIT_FUNC macro to declare or define its
        module initializer function.
        """
        module = self.import_module(name='modinit')
        assert module.__name__ == 'modinit'


    def test_export_function2(self):
        body = """
        static PyObject* my_objects[1];
        static PyObject* foo_cached_pi(PyObject* self, PyObject *args)
        {
            if (my_objects[0] == NULL) {
                my_objects[0] = PyFloat_FromDouble(3.14);
            }
            Py_INCREF(my_objects[0]);
            return my_objects[0];
        }
        static PyObject* foo_drop_pi(PyObject* self, PyObject *args)
        {
            if (my_objects[0] != NULL) {
                Py_DECREF(my_objects[0]);
                my_objects[0] = NULL;
            }
            Py_INCREF(Py_None);
            return Py_None;
        }
        static PyObject* foo_retinvalid(PyObject* self, PyObject *args)
        {
            return (PyObject*)0xAFFEBABE;
        }
        static PyMethodDef methods[] = {
            { "return_pi", foo_cached_pi, METH_NOARGS },
            { "drop_pi",   foo_drop_pi, METH_NOARGS },
            { "return_invalid_pointer", foo_retinvalid, METH_NOARGS },
            { NULL }
        };
        static struct PyModuleDef moduledef = {
            PyModuleDef_HEAD_INIT,
            "%(modname)s",  /* m_name */
            NULL,           /* m_doc */
            -1,             /* m_size */
            methods,        /* m_methods */
        };
        """
        module = self.import_module(name='foo', body=body)
        assert module.return_pi() == 3.14
        module.drop_pi()
        module.drop_pi()
        assert module.return_pi() == 3.14
        assert module.return_pi() == 3.14
        module.drop_pi()
        skip("Hmm, how to check for the exception?")
        raises(api.InvalidPointerException, module.return_invalid_pointer)

    def test_argument(self):
        import sys
        body = """
        PyObject* foo_test(PyObject* self, PyObject *args)
        {
            PyObject *t = PyTuple_GetItem(args, 0);
            Py_INCREF(t);
            return t;
        }
        static PyMethodDef methods[] = {
            { "test", foo_test, METH_VARARGS },
            { NULL }
        };
        static struct PyModuleDef moduledef = {
            PyModuleDef_HEAD_INIT,
            "%(modname)s",  /* m_name */
            NULL,           /* m_doc */
            -1,             /* m_size */
            methods,        /* m_methods */
        };
        """
        module = self.import_module(name='foo', body=body)
        assert module.test(True, True) == True

    def test_exception(self):
        import sys
        body = """
        static PyObject* foo_pi(PyObject* self, PyObject *args)
        {
            PyErr_SetString(PyExc_Exception, "moo!");
            return NULL;
        }
        static PyMethodDef methods[] = {
            { "raise_exception", foo_pi, METH_NOARGS },
            { NULL }
        };
        static struct PyModuleDef moduledef = {
            PyModuleDef_HEAD_INIT,
            "%(modname)s",  /* m_name */
            NULL,           /* m_doc */
            -1,             /* m_size */
            methods,        /* m_methods */
        };
        """
        module = self.import_module(name='foo', body=body)
        exc = raises(Exception, module.raise_exception)
        if type(exc.value) is not Exception:
            raise exc.value

        assert str(exc.value) == "moo!"

    def test_refcount(self):
        import sys
        body = """
        static PyObject* foo_pi(PyObject* self, PyObject *args)
        {
            PyObject *true_obj = Py_True;
            Py_ssize_t refcnt = true_obj->ob_refcnt;
            Py_ssize_t refcnt_after;
            Py_INCREF(true_obj);
            Py_INCREF(true_obj);
            if (!PyBool_Check(true_obj))
                Py_RETURN_NONE;
            refcnt_after = true_obj->ob_refcnt;
            Py_DECREF(true_obj);
            Py_DECREF(true_obj);
            fprintf(stderr, "REFCNT %ld %ld\\n", refcnt, refcnt_after);
            return PyBool_FromLong(refcnt_after == refcnt + 2);
        }
        static PyObject* foo_bar(PyObject* self, PyObject *args)
        {
            PyObject *true_obj = Py_True;
            PyObject *tup = NULL;
            Py_ssize_t refcnt = true_obj->ob_refcnt;
            Py_ssize_t refcnt_after;

            tup = PyTuple_New(1);
            Py_INCREF(true_obj);
            if (PyTuple_SetItem(tup, 0, true_obj) < 0)
                return NULL;
            refcnt_after = true_obj->ob_refcnt;
            Py_DECREF(tup);
            fprintf(stderr, "REFCNT2 %ld %ld %ld\\n", refcnt, refcnt_after,
                    true_obj->ob_refcnt);
            return PyBool_FromLong(refcnt_after == refcnt + 1 &&
                                   refcnt == true_obj->ob_refcnt);
        }

        static PyMethodDef methods[] = {
            { "test_refcount", foo_pi, METH_NOARGS },
            { "test_refcount2", foo_bar, METH_NOARGS },
            { NULL }
        };
        static struct PyModuleDef moduledef = {
            PyModuleDef_HEAD_INIT,
            "%(modname)s",  /* m_name */
            NULL,           /* m_doc */
            -1,             /* m_size */
            methods,        /* m_methods */
        };
        """
        module = self.import_module(name='foo', body=body)
        assert module.test_refcount()
        assert module.test_refcount2()


    def test_init_exception(self):
        import sys
        init = """
            PyErr_SetString(PyExc_Exception, "moo!");
            return NULL;
        """
        exc = raises(Exception, self.import_module, name='foo', init=init)
        if type(exc.value) is not Exception:
            raise exc.value

        assert str(exc.value) == "moo!"


    def test_internal_exceptions(self):
        if self.runappdirect:
            skip('cannot import module with undefined functions')
        import sys
        body = """
        PyAPI_FUNC(PyObject*) PyPy_Crash1(void);
        PyAPI_FUNC(Py_ssize_t) PyPy_Crash2(void);
        PyAPI_FUNC(PyObject*) PyPy_Noop(PyObject*);
        static PyObject* foo_crash1(PyObject* self, PyObject *args)
        {
            return PyPy_Crash1();
        }
        static PyObject* foo_crash2(PyObject* self, PyObject *args)
        {
            Py_ssize_t a = PyPy_Crash2();
            if (a == -1)
                return NULL;
            return PyFloat_FromDouble((double)a);
        }
        static PyObject* foo_crash3(PyObject* self, PyObject *args)
        {
            Py_ssize_t a = PyPy_Crash2();
            if (a == -1)
                PyErr_Clear();
            return PyFloat_FromDouble((double)a);
        }
        static PyObject* foo_crash4(PyObject* self, PyObject *args)
        {
            Py_ssize_t a = PyPy_Crash2();
            return PyFloat_FromDouble((double)a);
        }
        static PyObject* foo_noop(PyObject* self, PyObject* args)
        {
            Py_INCREF(args);
            return PyPy_Noop(args);
        }
        static PyObject* foo_set(PyObject* self, PyObject *args)
        {
            PyErr_SetString(PyExc_TypeError, "clear called with no error");
            if (PyLong_Check(args)) {
                Py_INCREF(args);
                return args;
            }
            return NULL;
        }
        static PyObject* foo_clear(PyObject* self, PyObject *args)
        {
            PyErr_Clear();
            if (PyLong_Check(args)) {
                Py_INCREF(args);
                return args;
            }
            return NULL;
        }
        static PyMethodDef methods[] = {
            { "crash1", foo_crash1, METH_NOARGS },
            { "crash2", foo_crash2, METH_NOARGS },
            { "crash3", foo_crash3, METH_NOARGS },
            { "crash4", foo_crash4, METH_NOARGS },
            { "clear",  foo_clear,  METH_O },
            { "set",    foo_set,    METH_O },
            { "noop",   foo_noop,   METH_O },
            { NULL }
        };
        static struct PyModuleDef moduledef = {
            PyModuleDef_HEAD_INIT,
            "%(modname)s",  /* m_name */
            NULL,           /* m_doc */
            -1,             /* m_size */
            methods,        /* m_methods */
        };
        """
        module = self.import_module(name='foo', body=body)

        # uncaught interplevel exceptions are turned into SystemError
        expected1 = "ZeroDivisionError('integer division or modulo by zero',)"
        # win64 uses long internally not int, which gives a different error
        expected2 = "ZeroDivisionError('integer division by zero',)"
        exc = raises(SystemError, module.crash1)
        v = exc.value.args[0]
        assert v == expected1 or v == expected2

        exc = raises(SystemError, module.crash2)
        assert v == expected1 or v == expected2

        # caught exception, api.cpython_api return value works
        assert module.crash3() == -1

        expected = 'An exception was set, but function returned a value'
        # PyPy only incompatibility/extension
        exc = raises(SystemError, module.crash4)
        assert v == expected1 or v == expected2

        # An exception was set by the previous call, it can pass
        # cleanly through a call that doesn't check error state
        assert module.noop(1) == 1

        # clear the exception but return NULL, signalling an error
        expected = 'Function returned a NULL result without setting an exception'
        exc = raises(SystemError, module.clear, None)
        assert exc.value.args[0] == expected

        # Set an exception and return NULL
        raises(TypeError, module.set, None)

        # clear any exception and return a value
        assert module.clear(1) == 1

        # Set an exception, but return non-NULL
        expected = 'An exception was set, but function returned a value'
        exc = raises(SystemError, module.set, 1)
        assert exc.value.args[0] == expected


        # Clear the exception and return a value, all is OK
        assert module.clear(1) == 1

    def test_new_exception(self):
        mod = self.import_extension('foo', [
            ('newexc', 'METH_VARARGS',
             '''
             char *name = _PyUnicode_AsString(PyTuple_GetItem(args, 0));
             return PyErr_NewException(name, PyTuple_GetItem(args, 1),
                                       PyTuple_GetItem(args, 2));
             '''
             ),
            ])
        raises(SystemError, mod.newexc, "name", Exception, {})

    @pytest.mark.skipif(only_pypy, reason='pypy specific test')
    def test_hash_pointer(self):
        mod = self.import_extension('foo', [
            ('get_hash', 'METH_NOARGS',
             '''
             return PyLong_FromLong(_Py_HashPointer(Py_None));
             '''
             ),
            ])
        h = mod.get_hash()
        assert h != 0
        assert h % 4 == 0 # it's the pointer value

    def test_types(self):
        """test the presence of random types"""

        mod = self.import_extension('foo', [
            ('get_names', 'METH_NOARGS',
             '''
             /* XXX in tests, the C type is not correct */
             #define NAME(type) ((PyTypeObject*)&type)->tp_name
             return Py_BuildValue("sssss",
                                  NAME(PyCell_Type),
                                  NAME(PyModule_Type),
                                  NAME(PyProperty_Type),
                                  NAME(PyStaticMethod_Type),
                                  NAME(PyCFunction_Type)
                                  );
             '''
             ),
            ])
        assert mod.get_names() == ('cell', 'module', 'property',
                                   'staticmethod',
                                   'builtin_function_or_method')

    def test_get_programname(self):
        mod = self.import_extension('foo', [
            ('get_programname', 'METH_NOARGS',
             '''
             wchar_t* name1 = Py_GetProgramName();
             wchar_t* name2 = Py_GetProgramName();
             if (name1 != name2)
                 Py_RETURN_FALSE;
             return PyUnicode_FromWideChar(name1, wcslen(name1));
             '''
             )],
            prologue='#include <wchar.h>')
        p = mod.get_programname()
        print(p)
        assert 'py' in p

    @pytest.mark.skipif(only_pypy, reason='pypy only test')
    def test_get_version(self):
        mod = self.import_extension('foo', [
            ('get_version', 'METH_NOARGS',
             '''
             char* name1 = Py_GetVersion();
             char* name2 = Py_GetVersion();
             if (name1 != name2)
                 Py_RETURN_FALSE;
             return PyUnicode_FromString(name1);
             '''
             ),
            ])
        p = mod.get_version()
        print(p)
        assert 'PyPy' in p

    def test_no_double_imports(self):
        import sys, os
        try:
            body = """
            static struct PyModuleDef moduledef = {
                PyModuleDef_HEAD_INIT,
                "%(modname)s",  /* m_name */
                NULL,           /* m_doc */
                -1,             /* m_size */
                NULL            /* m_methods */
            };
            """
            init = """
            static int _imported_already = 0;
            FILE *f = fopen("_imported_already", "w");
            fprintf(f, "imported_already: %d\\n", _imported_already);
            fclose(f);
            _imported_already = 1;
            return PyModule_Create(&moduledef);
            """
            self.import_module(name='foo', init=init, body=body)
            assert 'foo' in sys.modules

            f = open('_imported_already')
            data = f.read()
            f.close()
            assert data == 'imported_already: 0\n'

            f = open('_imported_already', 'w')
            f.write('not again!\n')
            f.close()
            m1 = sys.modules['foo']
            m2 = self.load_module(m1.__file__, name='foo')
            assert m1 is m2
            assert m1 is sys.modules['foo']

            f = open('_imported_already')
            data = f.read()
            f.close()
            assert data == 'not again!\n'

        finally:
            try:
                os.unlink('_imported_already')
            except OSError:
                pass

    def test_no_structmember(self):
        """structmember.h should not be included by default."""
        mod = self.import_extension('foo', [
            ('bar', 'METH_NOARGS',
             '''
             /* reuse a name that is #defined in structmember.h */
             int RO = 0; (void)RO;
             Py_RETURN_NONE;
             '''
             ),
        ])

    def test_consistent_flags(self):
        import sys
        mod = self.import_extension('foo', [
            ('test_optimize', 'METH_NOARGS',
             '''
                return PyLong_FromLong(Py_OptimizeFlag);
             '''),
        ])
        # This is intentionally set to -1 by default from missing.c
        # and should be set to sys.flags.optimize at startup
        assert mod.test_optimize() == sys.flags.optimize
