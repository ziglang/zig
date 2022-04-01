import py, os, sys
from .support import setup_make, soext

from pypy.interpreter.gateway import interp2app, unwrap_spec
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator import platform
from rpython.translator.gensupp import uniquemodulename
from rpython.tool.udir import udir

from pypy.module.cpyext import api
from pypy.module.cpyext.state import State

currpath = py.path.local(__file__).dirpath()
test_dct = str(currpath.join("crossingDict"))+soext

def setup_module(mod):
    setup_make("crossing")


# from pypy/module/cpyext/test/test_cpyext.py; modified to accept more external
# symbols and called directly instead of import_module
def compile_extension_module(space, modname, **kwds):
    """
    Build an extension module and return the filename of the resulting native
    code file.

    modname is the name of the module, possibly including dots if it is a module
    inside a package.

    Any extra keyword arguments are passed on to ExternalCompilationInfo to
    build the module (so specify your source with one of those).
    """
    state = space.fromcache(State)
    api_library = state.api_lib
    if sys.platform == 'win32':
        kwds["libraries"] = []#[api_library]
        # '%s' undefined; assuming extern returning int
        kwds["compile_extra"] = ["/we4013"]
        # prevent linking with PythonXX.lib
        w_maj, w_min = space.fixedview(space.sys.get('version_info'), 5)[:2]
        kwds["link_extra"] = ["/NODEFAULTLIB:Python%d%d.lib" %
                              (space.int_w(w_maj), space.int_w(w_min))]
    elif sys.platform == 'darwin':
        kwds["link_files"] = [str(api_library + '.dylib')]
    else:
        kwds["link_files"] = [str(api_library + '.so')]
        if sys.platform.startswith('linux'):
            kwds["compile_extra"]=["-Werror", "-g", "-O0"]
            kwds["link_extra"]=["-g"]

    modname = modname.split('.')[-1]
    eci = ExternalCompilationInfo(
        include_dirs=api.include_dirs,
        **kwds
        )
    eci = eci.convert_sources_to_files()
    dirname = (udir/uniquemodulename('module')).ensure(dir=1)
    soname = platform.platform.compile(
        [], eci,
        outputfilename=str(dirname/modname),
        standalone=False)
    from pypy.module.imp.importing import get_so_extension
    pydname = soname.new(purebasename=modname, ext=get_so_extension(space))
    soname.rename(pydname)
    return str(pydname)

class AppTestCrossing:
    spaceconfig = dict(usemodules=['_cppyy', '_rawffi', 'itertools'])

    def setup_class(cls):
        # _cppyy specific additions (note that test_dct is loaded late
        # to allow the generated extension module be loaded first)
        cls.w_test_dct    = cls.space.newtext(test_dct)
        cls.w_pre_imports = cls.space.appexec([], """():
            import ctypes, _cppyy
            _cppyy._post_import_startup()""")   # early import of ctypes
                  # prevents leak-checking complaints on ctypes' statics

    def setup_method(self, func):
        @unwrap_spec(name='text', init='text', body='text')
        def create_cdll(space, name, init, body):
            # the following is loosely from test_cpyext.py import_module; it
            # is copied here to be able to tweak the call to
            # compile_extension_module and to get a different return result
            # than in that function
            code = """
            #include <Python.h>
            /* fix for cpython 2.7 Python.h if running tests with -A
               since pypy compiles with -fvisibility-hidden */
            #undef PyMODINIT_FUNC
            #define PyMODINIT_FUNC RPY_EXPORTED void

            %(body)s

            PyMODINIT_FUNC
            #if PY_MAJOR_VERSION >= 3
            PyInit_%(name)s(void)
            #else
            init%(name)s(void) 
            #endif
            {
            %(init)s
            }
            """ % dict(name=name, init=init, body=body)
            kwds = dict(separate_module_sources=[code])
            mod = compile_extension_module(space, name, **kwds)

            # explicitly load the module as a CDLL rather than as a module
            from pypy.module.imp.importing import get_so_extension
            fullmodname = os.path.join(
                os.path.dirname(mod), name + get_so_extension(space))
            return space.newtext(fullmodname)

        self.w_create_cdll = self.space.wrap(interp2app(create_cdll))

    def test01_build_bar_extension(self):
        """Test that builds the needed extension; runs as test to keep it loaded"""

        import os, ctypes

        name = 'bar'

        init = """
        #if PY_MAJOR_VERSION >= 3
            static struct PyModuleDef moduledef = {
                PyModuleDef_HEAD_INIT,
                "bar", "Module Doc", -1, methods, NULL, NULL, NULL, NULL,
            };
        #endif

        if (Py_IsInitialized()) {
        #if PY_MAJOR_VERSION >= 3
            PyObject *module = PyModule_Create(&moduledef);
        #else
            Py_InitModule("bar", methods);
        #endif
        }
        """

        # note: only the symbols are needed for C, none for python
        body = """
        RPY_EXPORTED
        long bar_unwrap(PyObject* arg)
        {
            return 13;//PyLong_AsLong(arg);
        }
        RPY_EXPORTED
        PyObject* bar_wrap(long l)
        {
            return PyLong_FromLong(l);
        }
        static PyMethodDef methods[] = {
            { NULL }
        };
        """
        # explicitly load the module as a CDLL rather than as a module
        import ctypes
        self.cmodule = ctypes.CDLL(
            self.create_cdll(name, init, body), ctypes.RTLD_GLOBAL)

    def test02_crossing_dict(self):
        """Test availability of all needed classes in the dict"""

        import _cppyy, ctypes
        lib = ctypes.CDLL(self.test_dct, ctypes.RTLD_GLOBAL)

        assert _cppyy.gbl.crossing == _cppyy.gbl.crossing
        crossing = _cppyy.gbl.crossing

        assert crossing.A == crossing.A

    @py.test.mark.dont_track_allocations("fine when running standalone, though?!")
    def test03_send_pyobject(self):
        """Test sending a true pyobject to C++"""

        import _cppyy
        crossing = _cppyy.gbl.crossing

        a = crossing.A()
        assert a.unwrap(13) == 13

    @py.test.mark.dont_track_allocations("fine when running standalone, though?!")
    def test04_send_and_receive_pyobject(self):
        """Test receiving a true pyobject from C++"""

        import _cppyy
        crossing = _cppyy.gbl.crossing

        a = crossing.A()

        assert a.wrap(41) == 41
