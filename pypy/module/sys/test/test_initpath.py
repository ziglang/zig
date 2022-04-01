import pytest
import py
import os.path
from pypy.module.sys.initpath import (compute_stdlib_path_sourcetree,
    find_executable, find_stdlib, resolvedirof, pypy_init_home, pypy_init_free,
    find_pyvenv_cfg)
from pypy.module.sys.version import PYPY_VERSION, CPYTHON_VERSION
from rpython.rtyper.lltypesystem import rffi

def build_hierarchy_srctree(prefix):
    dirname = '%d' % CPYTHON_VERSION[0]
    a = prefix.join('lib_pypy').ensure(dir=1)
    b = prefix.join('lib-python', dirname).ensure(dir=1)
    return a, b

def build_hierarchy_package(prefix, platlibdir="lib"):
    dot_ver = 'pypy%d.%d' % CPYTHON_VERSION[:2]
    b = prefix.join(platlibdir, dot_ver).ensure(dir=1)
    b.join('site.py').ensure(dir=0)
    return b

def test_find_stdlib(tmpdir):
    bin_dir = tmpdir.join('bin').ensure(dir=True)
    pypy = bin_dir.join('pypy3').ensure(file=True)
    build_hierarchy_srctree(tmpdir)
    path, prefix = find_stdlib(None, "lib", str(pypy))
    assert prefix == tmpdir
    # if executable is None look for stdlib based on the working directory
    # see lib-python/2.7/test/test_sys.py:test_executable
    _, prefix = find_stdlib(None, "lib", '')
    cwd = os.path.dirname(os.path.realpath(__file__))
    assert prefix is not None
    assert cwd.startswith(str(prefix))

@pytest.mark.parametrize("platlibdir", ["lib", "lib64"])
def test_find_stdlib_package(tmpdir, platlibdir):
    bin_dir = tmpdir.join('bin').ensure(dir=True)
    pypy = bin_dir.join('pypy3').ensure(file=True)
    build_hierarchy_package(tmpdir, platlibdir)
    path, prefix = find_stdlib(None, platlibdir, str(pypy))
    assert prefix == tmpdir
    # if executable is None look for stdlib based on the working directory
    # see lib-python/2.7/test/test_sys.py:test_executable
    _, prefix = find_stdlib(None, platlibdir, '')
    cwd = os.path.dirname(os.path.realpath(__file__))
    assert prefix is not None
    assert cwd.startswith(str(prefix))

@py.test.mark.skipif('not hasattr(os, "symlink")')
def test_find_stdlib_follow_symlink(tmpdir):
    pypydir = tmpdir.join('opt', 'pypy3-xxx')
    pypy = pypydir.join('bin', 'pypy3').ensure(file=True)
    build_hierarchy_srctree(pypydir)
    pypy_sym = tmpdir.join('pypy3_sym')
    os.symlink(str(pypy), str(pypy_sym))
    path, prefix = find_stdlib(None, "lib", str(pypy_sym))
    assert prefix == pypydir

def test_pypy_init_home():
    p = pypy_init_home()
    assert p
    s = rffi.charp2str(p)
    pypy_init_free(p)
    assert os.path.exists(s)

def test_compute_stdlib_path(tmpdir):
    dirs = build_hierarchy_srctree(tmpdir)
    path = compute_stdlib_path_sourcetree(None, "lib", str(tmpdir))
    # we get at least 'dirs'
    assert path[:len(dirs)] == map(str, dirs)

def test_find_executable(tmpdir, monkeypatch):
    from pypy.module.sys import initpath
    tmpdir = py.path.local(os.path.realpath(str(tmpdir)))
    # /tmp/a/pypy3
    # /tmp/b/pypy3
    # /tmp/c
    a = tmpdir.join('a').ensure(dir=True)
    b = tmpdir.join('b').ensure(dir=True)
    c = tmpdir.join('c').ensure(dir=True)
    a.join('pypy3').ensure(file=True)
    b.join('pypy3').ensure(file=True)
    #
    monkeypatch.setattr(os, 'access', lambda x, y: True)
    # if there is already a slash, don't do anything
    monkeypatch.chdir(tmpdir)
    assert find_executable('a/pypy3') == a.join('pypy3')
    #
    # if path is None, try abspath (if the file exists)
    monkeypatch.setenv('PATH', None)
    monkeypatch.chdir(a)
    assert find_executable('pypy3') == a.join('pypy3')
    monkeypatch.chdir(tmpdir) # no pypy3 there
    assert find_executable('pypy3') == ''
    #
    # find it in path
    monkeypatch.setenv('PATH', str(a))
    assert find_executable('pypy3') == a.join('pypy3')
    #
    # find it in the first dir in path
    monkeypatch.setenv('PATH', '%s%s%s' % (b, os.pathsep, a))
    assert find_executable('pypy3') == b.join('pypy3')
    #
    # find it in the second, because in the first it's not there
    monkeypatch.setenv('PATH', '%s%s%s' % (c, os.pathsep, a))
    assert find_executable('pypy3') == a.join('pypy3')
    # if pypy3 is found but it's not a file, ignore it
    c.join('pypy3').ensure(dir=True)
    assert find_executable('pypy3') == a.join('pypy3')
    # if pypy3 is found but it's not executable, ignore it
    monkeypatch.setattr(os, 'access', lambda x, y: False)
    assert find_executable('pypy3') == ''
    #
    monkeypatch.setattr(os, 'access', lambda x, y: True)
    monkeypatch.setattr(initpath, 'we_are_translated', lambda: True)
    monkeypatch.setattr(initpath, '_WIN32', True)
    monkeypatch.setenv('PATH', str(a))
    a.join('pypy3.exe').ensure(file=True)
    assert find_executable('pypy3') == a.join('pypy3.exe')

def test_resolvedirof(tmpdir):
    assert resolvedirof('') == os.path.abspath(os.path.join(os.getcwd(), '..'))
    foo = tmpdir.join('foo').ensure(dir=True)
    bar = tmpdir.join('bar').ensure(dir=True)
    myfile = foo.join('myfile').ensure(file=True)
    assert resolvedirof(str(myfile)) == foo
    if hasattr(myfile, 'mksymlinkto'):
        myfile2 = bar.join('myfile')
        myfile2.mksymlinkto(myfile)
        assert resolvedirof(str(myfile2)) == foo

def test_find_pyvenv_cfg(tmpdir):
    subdir = tmpdir.join('find_cfg').ensure(dir=True)
    assert find_pyvenv_cfg(str(subdir)) == ''
    subdir.join('pyvenv.cfg').write('foobar')
    assert find_pyvenv_cfg(str(subdir)) == ''
    subdir.join('pyvenv.cfg').write('foobar\nhome=xyz')
    assert find_pyvenv_cfg(str(subdir)) == 'xyz'
    subdir.join('pyvenv.cfg').write('foohome=xyz')
    assert find_pyvenv_cfg(str(subdir)) == ''
    subdir.join('pyvenv.cfg').write('home = xyx \nbar = baz\n')
    assert find_pyvenv_cfg(str(subdir)) == 'xyx'

def test_find_stdlib_follow_pyvenv_cfg(tmpdir):
    mydir = tmpdir.join('follow_pyvenv_cfg').ensure(dir=True)
    otherdir = tmpdir.join('otherdir').ensure(dir=True)
    bin_dir = mydir.join('bin').ensure(dir=True)
    pypy = bin_dir.join('pypy3').ensure(file=True)
    build_hierarchy_srctree(otherdir)
    for homedir in [otherdir, otherdir.join('bin')]:
        mydir.join('pyvenv.cfg').write('home = %s\n' % (homedir,))
        _, prefix = find_stdlib(None, "lib", str(pypy))
        assert prefix == otherdir
