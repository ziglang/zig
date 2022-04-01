import py, sys
from os.path import abspath, commonprefix, dirname

THIS_DIR = dirname(__file__)

@py.test.mark.tryfirst
def pytest_runtest_setup(item):
    if not disabled and py.path.local.sysfind('genreflex') is None:
        import pypy.module._cppyy.capi.loadable_capi as lcapi
        if 'dummy' in lcapi.backend_library:
            # run only tests that are covered by the dummy backend and tests
            # that do not rely on reflex
            import os
            infomsg = 'backend is not installed'
            tst = os.path.basename(item.location[0])
            if not tst in ('test_helper.py', 'test_cppyy.py', 'test_pythonify.py',
                           'test_cpp11features.py', 'test_datatypes.py',
                           'test_pythonization.py'):
                py.test.skip(infomsg)
            import re
            if tst == 'test_pythonify.py' and \
                not re.search("AppTestPYTHONIFY.test0[1-5]", item.location[2]):
                py.test.skip(infomsg)
            elif tst == 'test_cpp11features.py' and \
                not re.search("AppTestCPP11FEATURES.test02", item.location[2]):
                py.test.skip(infomsg)
            elif tst == 'test_datatypes.py' and \
                not re.search("AppTestDATATYPES.test0[1-7]", item.location[2]):
                py.test.skip(infomsg)
            elif tst == 'test_pythonization.py' and \
                not re.search("AppTestPYTHONIZATION.test0[0]", item.location[2]):
                py.test.skip(infomsg)

def pytest_ignore_collect(path, config):
    path = str(path)
    if disabled:
        if commonprefix([path, THIS_DIR]) == THIS_DIR:  # workaround for bug in pytest<3.0.5
            return True

disabled = None
if sys.maxsize > 2**32 and sys.platform == 'win32':
    # cppyy not yet supported on windows 64 bit
    disabled = True

def pytest_configure(config):
    global disabled
    if disabled or config.getoption('runappdirect') or config.getoption('direct_apptest'):
        if py.path.local.sysfind('genreflex') is None:
            disabled = True  # can't run dummy tests in -A
        return
    if py.path.local.sysfind('genreflex') is None:
        import pypy.module._cppyy.capi.loadable_capi as lcapi
        try:
            import ctypes
            ctypes.CDLL(lcapi.backend_library)
        except Exception as e:
            # build dummy backend (which has reflex info and calls hard-wired)
            import os
            from rpython.translator.tool.cbuild import ExternalCompilationInfo
            from rpython.translator.platform import platform, CompilationError
            from rpython.translator import cdir

            from rpython.rtyper.lltypesystem import rffi

            pkgpath = py.path.local(__file__).dirpath().join(os.pardir)
            srcpath = pkgpath.join('src')
            incpath = pkgpath.join('include')
            tstpath = pkgpath.join('test')
            compile_extra = ['-DRPY_EXTERN=RPY_EXPORTED', '-DCPPYY_DUMMY_BACKEND']
            if platform.name == 'msvc':
                compile_extra += ['-std:c++14']
            else:
                compile_extra += ['-fno-strict-aliasing', '-std=c++14']

            eci = ExternalCompilationInfo(
                separate_module_files=[srcpath.join('dummy_backend.cxx')],
                include_dirs=[incpath, tstpath, cdir],
                compile_extra=compile_extra,
                use_cpp_linker=True,
            )

            try:
                soname = platform.compile(
                    [], eci,
                    outputfilename='libcppyy_dummy_backend',
                    standalone=False)
            except CompilationError as e:
                if '-std=c++14' in str(e):
                    disabled = str(e)
                    return
                raise

            lcapi.backend_library = str(soname)
