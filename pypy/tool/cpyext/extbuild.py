import os
import sys
import py
from pypy import pypydir

if os.name != 'nt':
    so_ext = 'so'
else:
    so_ext = 'dll'

HERE = py.path.local(pypydir) / 'module' / 'cpyext' / 'test'

class SystemCompilationInfo(object):
    """Bundles all the generic information required to compile extensions.

    Note: here, 'system' means OS + target interpreter + test config + ...
    """
    def __init__(self, builddir_base, include_extra=None, compile_extra=None,
            link_extra=None, extra_libs=None, ext=None):
        self.builddir_base = builddir_base
        self.include_extra = include_extra or []
        self.compile_extra = compile_extra
        self.link_extra = link_extra
        self.extra_libs = extra_libs
        self.ext = ext

    def get_builddir(self, name):
        builddir = py.path.local.make_numbered_dir(
            rootdir=py.path.local(self.builddir_base),
            prefix=name + '-',
            keep=0)  # keep everything
        return builddir

    def compile_extension_module(self, name, include_dirs=None,
            source_files=None, source_strings=None):
        """
        Build an extension module and return the filename of the resulting
        native code file.

        name is the name of the module, possibly including dots if it is a
        module inside a package.
        """
        include_dirs = include_dirs or []
        modname = name.split('.')[-1]
        dirname = self.get_builddir(name=modname)
        if source_strings:
            assert not source_files
            files = convert_sources_to_files(source_strings, dirname)
            source_files = files
        soname = c_compile(source_files, outputfilename=str(dirname / modname),
            compile_extra=self.compile_extra,
            link_extra=self.link_extra,
            include_dirs=self.include_extra + include_dirs,
            libraries=self.extra_libs)
        pydname = soname.new(purebasename=modname, ext=self.ext)
        soname.rename(pydname)
        return str(pydname)

    def import_module(self, name, init=None, body='', filename=None,
                      include_dirs=None, PY_SSIZE_T_CLEAN=False, use_imp=False):
        """
        init specifies the overall template of the module.

        if init is None, the module source will be loaded from a file in this
        test directory, give a name given by the filename parameter.

        if filename is None, the module name will be used to construct the
        filename.
        """
        if body or init:
            if init is None:
                init = "return PyModule_Create(&moduledef);"
        if init is not None:
            code = make_source(name, init, body, PY_SSIZE_T_CLEAN)
            kwds = dict(source_strings=[code])
        else:
            assert not PY_SSIZE_T_CLEAN
            if filename is None:
                filename = name
            filename = HERE / (filename + ".c")
            kwds = dict(source_files=[filename])
        mod = self.compile_extension_module(
            name, include_dirs=include_dirs, **kwds)
        return self.load_module(mod, name, use_imp)

    def import_extension(self, modname, functions, prologue="",
            include_dirs=None, more_init="", PY_SSIZE_T_CLEAN=False):
        body = prologue + make_methods(functions, modname)
        init = """PyObject *mod = PyModule_Create(&moduledef);
               """
        if more_init:
            init += """#define INITERROR return NULL
                    """
            init += more_init
        init += "\nreturn mod;"
        return self.import_module(
            name=modname, init=init, body=body, include_dirs=include_dirs,
            PY_SSIZE_T_CLEAN=PY_SSIZE_T_CLEAN)

class ExtensionCompiler(SystemCompilationInfo):
    """Extension compiler for appdirect mode"""
    def load_module(space, mod, name, use_imp=False):
        # use_imp is ignored, it is useful only for non-appdirect mode
        import imp
        return imp.load_dynamic(name, mod)

def convert_sources_to_files(sources, dirname):
    files = []
    for i, source in enumerate(sources):
        filename = dirname / ('source_%d.c' % i)
        with filename.open('w') as f:
            f.write(str(source))
        files.append(filename)
    return files


def make_methods(functions, modname):
    methods_table = []
    codes = []
    for funcname, flags, code in functions:
        cfuncname = "%s_%s" % (modname, funcname)
        if 'METH_FASTCALL' in flags and 'METH_KEYWORDS' in flags:
            signature = ('(PyObject *self, PyObject *const *args, '
                         'Py_ssize_t len_args, PyObject *kwnames)')
        elif 'METH_KEYWORDS' in flags:
            signature = '(PyObject *self, PyObject *args, PyObject *kwargs)'
        elif 'METH_FASTCALL' in flags:
            signature = ('(PyObject *self, PyObject *const *args, '
                         'Py_ssize_t len_args)')
        else:
            signature = '(PyObject *self, PyObject *args)'
        methods_table.append(
            "{\"%s\", (PyCFunction)%s, %s}," % (funcname, cfuncname, flags))
        func_code = """
        static PyObject* {cfuncname}{signature}
        {{
        {code}
        }}
        """.format(cfuncname=cfuncname, signature=signature, code=code)
        codes.append(func_code)

    body = "\n".join(codes) + """
    static PyMethodDef methods[] = {
    %(methods)s
    { NULL }
    };
    static struct PyModuleDef moduledef = {
        PyModuleDef_HEAD_INIT,
        "%(modname)s",  /* m_name */
        NULL,           /* m_doc */
        -1,             /* m_size */
        methods,        /* m_methods */
    };
    """ % dict(methods='\n'.join(methods_table), modname=modname)
    return body

def make_source(name, init, body, PY_SSIZE_T_CLEAN):
    code = """
    %(PY_SSIZE_T_CLEAN)s
    #include <Python.h>

    %(body)s

    PyMODINIT_FUNC
    PyInit_%(name)s(void) {
    %(init)s
    }
    """ % dict(
        name=name, init=init, body=body,
        PY_SSIZE_T_CLEAN='#define PY_SSIZE_T_CLEAN'
            if PY_SSIZE_T_CLEAN else '')
    return code


def c_compile(cfilenames, outputfilename,
        compile_extra=None, link_extra=None,
        include_dirs=None, libraries=None, library_dirs=None):
    compile_extra = compile_extra or []
    link_extra = link_extra or []
    include_dirs = include_dirs or []
    libraries = libraries or []
    library_dirs = library_dirs or []
    if sys.platform == 'win32':
        link_extra = link_extra + ['/DEBUG']  # generate .pdb file
    if sys.platform == 'darwin':
        # support Fink & Darwinports
        for s in ('/sw/', '/opt/local/'):
            if (s + 'include' not in include_dirs
                    and os.path.exists(s + 'include')):
                include_dirs.append(s + 'include')
            if s + 'lib' not in library_dirs and os.path.exists(s + 'lib'):
                library_dirs.append(s + 'lib')

    outputfilename = py.path.local(outputfilename).new(ext=so_ext)
    saved_environ = os.environ.copy()
    try:
        _build(
            cfilenames, outputfilename,
            compile_extra, link_extra,
            include_dirs, libraries, library_dirs)
    finally:
        # workaround for a distutils bugs where some env vars can
        # become longer and longer every time it is used
        for key, value in saved_environ.items():
            if os.environ.get(key) != value:
                os.environ[key] = value
    return outputfilename

def _build(cfilenames, outputfilename, compile_extra, link_extra,
        include_dirs, libraries, library_dirs):
    try:
        # monkeypatch distutils for some versions of msvc compiler
        import setuptools
    except ImportError:
        # XXX if this fails and is required,
        #     we must call pypy -mensurepip after translation
        pass
    from distutils.ccompiler import new_compiler
    from distutils import sysconfig

    # XXX for Darwin running old versions of CPython 2.7.x
    sysconfig.get_config_vars()

    compiler = new_compiler(force=1)
    sysconfig.customize_compiler(compiler)  # XXX
    objects = []
    for cfile in cfilenames:
        cfile = py.path.local(cfile)
        old = cfile.dirpath().chdir()
        try:
            res = compiler.compile([cfile.basename],
                include_dirs=include_dirs, extra_preargs=compile_extra)
            assert len(res) == 1
            cobjfile = py.path.local(res[0])
            assert cobjfile.check()
            objects.append(str(cobjfile))
        finally:
            old.chdir()

    compiler.link_shared_object(
        objects, str(outputfilename),
        libraries=libraries,
        extra_preargs=link_extra,
        library_dirs=library_dirs)

def get_so_suffix():
    from imp import get_suffixes, C_EXTENSION
    for suffix, mode, typ in get_suffixes():
        if typ == C_EXTENSION:
            return suffix
    else:
        raise RuntimeError("This interpreter does not define a filename "
            "suffix for C extensions!")

def get_sys_info_app(base_dir):
    from distutils.sysconfig import get_python_inc
    if sys.platform == 'win32':
        compile_extra = ["/we4013"]
        link_extra = ["/LIBPATH:" + os.path.join(sys.exec_prefix, 'libs')]
    elif sys.platform.startswith('linux'):
        compile_extra = [
            "-O0", "-g", "-Werror=implicit-function-declaration", "-fPIC"]
        link_extra = None
    else:
        compile_extra = link_extra = None
        pass
    return ExtensionCompiler(
        builddir_base=base_dir,
        include_extra=[get_python_inc()],
        compile_extra=compile_extra,
        link_extra=link_extra,
        ext=get_so_suffix())
