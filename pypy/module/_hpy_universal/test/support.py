import py
import pytest
import sys
from rpython.tool.udir import udir
from pypy.interpreter.gateway import interp2app, unwrap_spec, W_Root
from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module._hpy_universal.llapi import BASE_DIR
from pypy.module._hpy_universal.test._vendored import support as _support
from pypy.module._hpy_universal._vendored.hpy.devel import HPyDevel
from ..state import State
from .. import llapi

COMPILER_VERBOSE = False


class HPyAppTest(object):
    """
    Base class for HPy app tests. This is used as a mixin, and individual
    subclasses are created by conftest.make_hpy_apptest
    """

    extra_link_args = []
    spaceconfig = {
        'usemodules': ['_hpy_universal'],
        'objspace.hpy_cpyext_API': False,
    }

    def setup_class(cls):
        if cls.runappdirect:
            pytest.skip()

    @pytest.fixture
    def compiler(self):
        # see setup_method below
        return 'The fixture "compiler" is not used on pypy'

    # NOTE: HPyTest has already an initargs fixture, but it's ignored here
    # because pypy is using an old pytest version which does not support
    # @pytest.mark.usefixtures on classes. To work around the limitation, we
    # redeclare initargs as autouse=True, so it's automatically used by all
    # tests.
    @pytest.fixture(params=['universal', 'debug'], autouse=True)
    def initargs(self, request):
        hpy_abi = request.param
        self._init(request, hpy_abi)

    def _init(self, request, hpy_abi):
        state = self.space.fromcache(State)
        if state.was_already_setup():
            state.reset()
        if self.space.config.objspace.usemodules.cpyext:
            from pypy.module import cpyext
            cpyext_include_dirs = cpyext.api.include_dirs
        else:
            cpyext_include_dirs = None
        #
        # it would be nice to use the 'compiler' fixture to provide
        # make_module as the std HPyTest do. However, we don't have the space
        # yet, so it is much easier to prove make_module() here
        tmpdir = py.path.local.make_numbered_dir(rootdir=udir,
                                                 prefix=request.function.__name__ + '-',
                                                 keep=0)  # keep everything

        hpy_devel = HPyDevel(str(BASE_DIR))
        compiler = _support.ExtensionCompiler(tmpdir, hpy_devel, 'universal',
                                              compiler_verbose=COMPILER_VERBOSE,
                                              extra_link_args=self.extra_link_args,
                                              extra_include_dirs=cpyext_include_dirs)
        ExtensionTemplate = self.ExtensionTemplate

        @unwrap_spec(main_src='text', name='text', w_extra_sources=W_Root)
        def descr_make_module(space, main_src, name='mytest',
                              w_extra_sources=None):
            if w_extra_sources is None:
                extra_sources = ()
            else:
                items_w = space.unpackiterable(w_extra_sources)
                extra_sources = [space.text_w(item) for item in items_w]
            py_filename = compiler.compile_module(ExtensionTemplate,
                                                  main_src, name, extra_sources)
            so_filename = py_filename.replace(".py", ".hpy.so")
            debug = hpy_abi == 'debug'
            w_mod = space.appexec([space.newtext(so_filename),
                                   space.newtext(name),
                                   space.newbool(debug)],
                """(path, modname, debug):
                    import _hpy_universal
                    return _hpy_universal.load(modname, path, debug)
                """
            )
            return w_mod
        self.w_make_module = self.space.wrap(interp2app(descr_make_module))

        def supports_refcounts(space):
            return space.w_False
        self.w_supports_refcounts = self.space.wrap(interp2app(supports_refcounts))

        def supports_ordinary_make_module_imports(space):
            return space.w_False
        self.w_supports_ordinary_make_module_imports = self.space.wrap(
            interp2app(supports_ordinary_make_module_imports))

        def supports_sys_executable(space):
            return space.w_False
        self.w_supports_sys_executable = self.space.wrap(
            interp2app(supports_sys_executable))

        self.w_compiler = self.space.appexec([self.space.newtext(hpy_abi)],
            """(abi):
                class compiler:
                    hpy_abi = abi
                return compiler
            """)

class HPyDebugAppTest(HPyAppTest):

    # override the initargs fixture to run the tests ONLY in debug mode, as
    # done by upstream's HPyDebugTest
    @pytest.fixture(autouse=True)
    def initargs(self, request):
        self._init(request, hpy_abi='debug')

    # make self.make_leak_module() available to the tests. Note that this is
    # code which will be run at applevel, and will call self.make_module,
    # which is finally executed at interp-level (see descr_make_module above)
    #w_make_leak_module = _support.HPyDebugTest.make_leak_module


if sys.platform == 'win32':
    # since we include Python.h, we must disable linking with the regular
    # import lib
    from pypy.module.sys import version
    ver = version.CPYTHON_VERSION[:2]
    untranslated_link_args = ["/NODEFAULTLIB:Python%d%d.lib" % ver]
    untranslated_link_args.append(str(udir / "module_cache" / "pypyapi.lib"))
else:
    untranslated_link_args = []

class HPyCPyextAppTest(AppTestCpythonExtensionBase, HPyAppTest):
    """
    Base class for hpy tests which also need cpyext
    """

    extra_link_args = untranslated_link_args

    # mmap is needed because it is imported by LeakCheckingTest.setup_class
    spaceconfig = {'usemodules': ['_hpy_universal', 'cpyext', 'mmap']}

    def setup_class(cls):
        AppTestCpythonExtensionBase.setup_class.im_func(cls)
        HPyAppTest.setup_class.im_func(cls)
