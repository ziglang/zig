import os, sys
import pytest, py
import re
import textwrap

PY2 = sys.version_info[0] == 2

def reindent(s, indent):
    s = textwrap.dedent(s)
    return ''.join(' '*indent + line if line.strip() else line
        for line in s.splitlines(True))

class DefaultExtensionTemplate(object):

    INIT_TEMPLATE = textwrap.dedent("""
    static HPyDef *moduledefs[] = {
        %(defines)s
        NULL
    };
    static HPyModuleDef moduledef = {
        HPyModuleDef_HEAD_INIT,
        .m_name = "%(name)s",
        .m_doc = "some test for hpy",
        .m_size = -1,
        .legacy_methods = %(legacy_methods)s,
        .defines = moduledefs
    };

    HPy_MODINIT(%(name)s)
    static HPy init_%(name)s_impl(HPyContext *ctx)
    {
        HPy m = HPy_NULL;
        m = HPyModule_Create(ctx, &moduledef);
        if (HPy_IsNull(m))
            goto MODINIT_ERROR;
        %(init_types)s
        return m;

        MODINIT_ERROR:

        if (!HPy_IsNull(m))
            HPy_Close(ctx, m);
        return HPy_NULL;
    }
    """)

    r_marker = re.compile(r"^\s*@([A-Za-z_]+)(\(.*\))?$")

    def __init__(self, src, name):
        self.src = textwrap.dedent(src)
        self.name = name
        self.defines_table = None
        self.legacy_methods = 'NULL'
        self.type_table = None

    def expand(self):
        self.defines_table = []
        self.type_table = []
        self.output = ['#include <hpy.h>']
        for line in self.src.split('\n'):
            match = self.r_marker.match(line)
            if match:
                name, args = self.parse_marker(match)
                meth = getattr(self, name)
                out = meth(*args)
                if out is not None:
                    out = textwrap.dedent(out)
                    self.output.append(out)
            else:
                self.output.append(line)
        return '\n'.join(self.output)

    def parse_marker(self, match):
        name = match.group(1)
        args = match.group(2)
        if args is None:
            args = ()
        else:
            assert args[0] == '('
            assert args[-1] == ')'
            args = args[1:-1].split(',')
            args = [x.strip() for x in args]
        return name, args

    def INIT(self):
        if self.type_table:
            init_types = '\n'.join(self.type_table)
        else:
            init_types = ''

        exp = self.INIT_TEMPLATE % {
            'legacy_methods': self.legacy_methods,
            'defines': '\n        '.join(self.defines_table),
            'init_types': init_types,
            'name': self.name}
        self.output.append(exp)
        # make sure that we don't fill the tables any more
        self.defines_table = None
        self.type_table = None

    def EXPORT(self, meth):
        self.defines_table.append('&%s,' % meth)

    def EXPORT_LEGACY(self, pymethoddef):
        self.legacy_methods = pymethoddef

    def EXPORT_TYPE(self, name, spec):
        src = """
            if (!HPyHelpers_AddType(ctx, m, {name}, &{spec}, NULL)) {{
                goto MODINIT_ERROR;
            }}
            """
        src = reindent(src, 4)
        self.type_table.append(src.format(
            name=name,
            spec=spec))

    def EXTRA_INIT_FUNC(self, func):
        src = """
            {func}(ctx, m);
            if (HPyErr_Occurred(ctx))
                goto MODINIT_ERROR;
            """
        src = reindent(src, 4)
        self.type_table.append(src.format(func=func))


class Spec(object):
    def __init__(self, name, origin):
        self.name = name
        self.origin = origin


class ExtensionCompiler:
    def __init__(self, tmpdir, hpy_devel, hpy_abi, compiler_verbose=False,
                 ExtensionTemplate=DefaultExtensionTemplate,
                 extra_include_dirs=None):
        """
        hpy_devel is an instance of HPyDevel which specifies where to find
        include/, runtime/src, etc. Usually it will point to hpy/devel/, but
        alternate implementations can point to their own place (e.g. pypy puts
        it into pypy/module/_hpy_universal/_vendored)

        extra_include_dirs is a list of include dirs which is put BEFORE all
        others. By default it is empty, but it is used e.g. by PyPy to make
        sure that #include <Python.h> picks its own version, instead of the
        system-wide one.
        """
        self.tmpdir = tmpdir
        self.hpy_devel = hpy_devel
        self.hpy_abi = hpy_abi
        self.compiler_verbose = compiler_verbose
        self.ExtensionTemplate=ExtensionTemplate
        self.extra_include_dirs = extra_include_dirs

    def _expand(self, ExtensionTemplate, name, template):
        source = ExtensionTemplate(template, name).expand()
        filename = self.tmpdir.join(name + '.c')
        if PY2:
            # this code is used also by pypy tests, which run on python2. In
            # this case, we need to write as binary, because source is
            # "bytes". If we don't and source contains a non-ascii char, we
            # get an UnicodeDecodeError
            filename.write(source, mode='wb')
        else:
            filename.write(source)
        return name + '.c'

    def compile_module(self, ExtensionTemplate, main_src, name, extra_sources):
        """
        Create and compile a HPy module from the template
        """
        from distutils.core import Extension
        filename = self._expand(ExtensionTemplate, name, main_src)
        sources = [str(filename)]
        for i, src in enumerate(extra_sources):
            extra_filename = self._expand(ExtensionTemplate, 'extmod_%d' % i, src)
            sources.append(extra_filename)
        #
        if sys.platform == 'win32':
            # not strictly true, could be mingw
            compile_args = [
                '/Od',
                '/WX',               # turn warnings into errors (all, for now)
                # '/Wall',           # this is too aggresive, makes windows itself fail
                '/Zi',
                '-D_CRT_SECURE_NO_WARNINGS', # something about _snprintf and _snprintf_s
                '/FS',               # Since the tests run in parallel
            ]
            link_args = [
                '/DEBUG',
                '/LTCG',
            ]
        else:
            compile_args = [
                '-g', '-O0',
                '-Wfatal-errors',    # stop after one error (unrelated to warnings)
                '-Werror',           # turn warnings into errors (all, for now)
            ]
            link_args = [
                '-g',
            ]
        #
        ext = Extension(
            name,
            sources=sources,
            include_dirs=self.extra_include_dirs,
            extra_compile_args=compile_args,
            extra_link_args=link_args)

        hpy_abi = self.hpy_abi
        if hpy_abi == 'debug':
            # there is no compile-time difference between universal and debug
            # extensions. The only difference happens at load time
            hpy_abi = 'universal'
        so_filename = c_compile(str(self.tmpdir), ext,
                                hpy_devel=self.hpy_devel,
                                hpy_abi=hpy_abi,
                                compiler_verbose=self.compiler_verbose)
        return so_filename

    def make_module(self, main_src, ExtensionTemplate=None, name='mytest',
                    extra_sources=()):
        """
        Compile & load a module. This is NOT a proper import: e.g.
        the module is not put into sys.modules.

        We don't want to unnecessarily modify the global state inside tests:
        if you are writing a test which needs a proper import, you should not
        use make_module but explicitly use compile_module and import it
        manually as required by your test.
        """
        if ExtensionTemplate is None:
            ExtensionTemplate = self.ExtensionTemplate
        so_filename = self.compile_module(
            ExtensionTemplate, main_src, name, extra_sources)
        if self.hpy_abi == 'universal':
            return self.load_universal_module(name, so_filename, debug=False)
        elif self.hpy_abi == 'debug':
            return self.load_universal_module(name, so_filename, debug=True)
        elif self.hpy_abi == 'cpython':
            return self.load_cpython_module(name, so_filename)
        else:
            assert False

    def load_universal_module(self, name, so_filename, debug):
        assert self.hpy_abi in ('universal', 'debug')
        import sys
        import hpy.universal
        assert name not in sys.modules
        mod = hpy.universal.load(name, so_filename, debug=debug)
        mod.__file__ = so_filename
        return mod

    def load_cpython_module(self, name, so_filename):
        assert self.hpy_abi == 'cpython'
        # we've got a normal CPython module compiled with the CPython API/ABI,
        # let's load it normally. It is important to do the imports only here,
        # because this file will be imported also by PyPy tests which runs on
        # Python2
        import importlib.util
        import sys
        assert name not in sys.modules
        spec = importlib.util.spec_from_file_location(name, so_filename)
        try:
            # module_from_spec adds the module to sys.modules
            module = importlib.util.module_from_spec(spec)
        finally:
            if name in sys.modules:
                del sys.modules[name]
        spec.loader.exec_module(module)
        return module


@pytest.mark.usefixtures('initargs')
class HPyTest:
    ExtensionTemplate = DefaultExtensionTemplate

    @pytest.fixture()
    def initargs(self, compiler):
        self.compiler = compiler

    def make_module(self, main_src, name='mytest', extra_sources=()):
        ExtensionTemplate = self.ExtensionTemplate
        return self.compiler.make_module(main_src, ExtensionTemplate, name,
                                         extra_sources)

    def supports_refcounts(self):
        """ Returns True if the underlying Python implementation supports
            reference counts.

            By default returns True on CPython and False on other
            implementations.
        """
        return sys.implementation.name == "cpython"

    def supports_ordinary_make_module_imports(self):
        """ Returns True if `.make_module(...)` loads modules using a
            standard Python import mechanism (e.g. `importlib.import_module`).

            By default returns True because the base implementation of
            `.make_module(...)` uses an ordinary import. Sub-classes that
            override `.make_module(...)` may also want to override this
            method.
        """
        return True

    def supports_sys_executable(self):
        """ Returns True is `sys.executable` is set to a value that allows
            a Python equivalent to the current Python to be launched via, e.g.,
            `subprocess.run(...)`.

            By default returns `True` if sys.executable is set to a true value.
        """
        return bool(getattr(sys, "executable", None))



class HPyDebugTest(HPyTest):
    """
    Like HPyTest, but force hpy_abi=='debug' and thus run only [debug] tests
    """

    # override initargs to avoid using hpy_debug (we don't want to detect
    # leaks here, we make them on purpose!
    @pytest.fixture()
    def initargs(self, compiler):
        self.compiler = compiler

    @pytest.fixture(params=['debug'])
    def hpy_abi(self, request):
        return request.param

# the few functions below are copied and adapted from cffi/ffiplatform.py

def c_compile(tmpdir, ext, hpy_devel, hpy_abi, compiler_verbose=0, debug=None):
    """Compile a C extension module using distutils."""
    saved_environ = os.environ.copy()
    try:
        outputfilename = _build(tmpdir, ext, hpy_devel, hpy_abi, compiler_verbose, debug)
        outputfilename = os.path.abspath(outputfilename)
    finally:
        # workaround for a distutils bugs where some env vars can
        # become longer and longer every time it is used
        for key, value in saved_environ.items():
            if os.environ.get(key) != value:
                os.environ[key] = value
    return outputfilename


def _build(tmpdir, ext, hpy_devel, hpy_abi, compiler_verbose=0, debug=None):
    # XXX compact but horrible :-(
    from distutils.core import Distribution
    import distutils.errors
    import distutils.log
    #
    dist = Distribution()
    dist.parse_config_files()
    if debug is None:
        debug = sys.flags.debug
    options_build_ext = dist.get_option_dict('build_ext')
    options_build_ext['debug'] = ('ffiplatform', debug)
    options_build_ext['force'] = ('ffiplatform', True)
    options_build_ext['build_lib'] = ('ffiplatform', tmpdir)
    options_build_ext['build_temp'] = ('ffiplatform', tmpdir)
    options_build_py = dist.get_option_dict('build_py')
    options_build_py['build_lib'] = ('ffiplatform', tmpdir)

    # this is the equivalent of passing --hpy-abi from setup.py's command line
    dist.hpy_abi = hpy_abi
    dist.hpy_ext_modules = [ext]
    hpy_devel.fix_distribution(dist)

    old_level = distutils.log.set_threshold(0) or 0
    old_dir = os.getcwd()
    try:
        os.chdir(tmpdir)
        distutils.log.set_verbosity(compiler_verbose)
        dist.run_command('build_ext')
        cmd_obj = dist.get_command_obj('build_ext')
        outputs = cmd_obj.get_outputs()
        sonames = [x for x in outputs if
                   not x.endswith(".py") and not x.endswith(".pyc")]
        assert len(sonames) == 1, 'build_ext is not supposed to return multiple DLLs'
        soname = sonames[0]
    finally:
        os.chdir(old_dir)
        distutils.log.set_threshold(old_level)

    return soname
