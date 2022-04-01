import py
import pytest
import sys
import os

# XXX: copied from pypy/tool/cpyext/extbuild.py
if os.name != 'nt':
    so_ext = 'so'
else:
    so_ext = 'dll'

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
# end copy

def compile_so_file(udir):
    cfile = py.path.local(__file__).dirpath().join("_ctypes_test.c")

    if sys.platform == 'win32':
        libraries = ['oleaut32']
    else:
        libraries = []

    return c_compile([cfile], str(udir / '_ctypes_test'), libraries=libraries)

@pytest.fixture(scope='session')
def sofile(tmpdir_factory):
    udir = tmpdir_factory.mktemp('_ctypes_test')
    return str(compile_so_file(udir))

@pytest.fixture
def dll(sofile):
    from ctypes import CDLL
    return CDLL(str(sofile))
