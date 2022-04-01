import py
import os
from rpython.rlib import rpath

def test_rnormpath_posix():
    assert rpath._posix_rnormpath('///foo') == '/foo'
    assert rpath._posix_rnormpath("") == "."
    assert rpath._posix_rnormpath("/") == "/"
    assert rpath._posix_rnormpath("//") == "//"
    assert rpath._posix_rnormpath("///") == "/"
    assert rpath._posix_rnormpath("///foo/.//bar//") == "/foo/bar"
    assert rpath._posix_rnormpath("///foo/.//bar//.//..//.//baz") == "/foo/baz"
    assert rpath._posix_rnormpath("///..//./foo/.//bar") == "/foo/bar"

def test_rnormpath_nt():
    assert rpath._nt_rnormpath('A//////././//.//B') == r'A\B'
    assert rpath._nt_rnormpath('A/./B') == r'A\B'
    assert rpath._nt_rnormpath('A/foo/../B') == r'A\B'
    assert rpath._nt_rnormpath('C:A//B') == r'C:A\B'
    assert rpath._nt_rnormpath('D:A/./B') == r'D:A\B'
    assert rpath._nt_rnormpath('e:A/foo/../B') == r'e:A\B'
    assert rpath._nt_rnormpath('C:///A//B') == r'C:\A\B'
    assert rpath._nt_rnormpath('D:///A/./B') == r'D:\A\B'
    assert rpath._nt_rnormpath('e:///A/foo/../B') == r'e:\A\B'
    assert rpath._nt_rnormpath('..') == r'..'
    assert rpath._nt_rnormpath('.') == r'.'
    assert rpath._nt_rnormpath('') == r'.'
    assert rpath._nt_rnormpath('/') == '\\'
    assert rpath._nt_rnormpath('c:/') == 'c:\\'
    assert rpath._nt_rnormpath('/../.././..') == '\\'
    assert rpath._nt_rnormpath('c:/../../..') == 'c:\\'
    assert rpath._nt_rnormpath('../.././..') == r'..\..\..'
    assert rpath._nt_rnormpath('K:../.././..') == r'K:..\..\..'
    assert rpath._nt_rnormpath('C:////a/b') == r'C:\a\b'
    assert rpath._nt_rnormpath('//machine/share//a/b') == r'\\machine\share\a\b'
    assert rpath._nt_rnormpath('\\\\.\\NUL') == r'\\.\NUL'
    assert rpath._nt_rnormpath('\\\\?\\D:/XY\\Z') == r'\\?\D:/XY\Z'

def test_rabspath_relative(tmpdir):
    tmpdir.chdir()
    assert rpath.rabspath('foo') == os.path.realpath(str(tmpdir.join('foo')))

def test_rabspath_absolute_posix():
    assert rpath._posix_rabspath('/foo') == '/foo'
    assert rpath._posix_rabspath('/foo/bar/..') == '/foo'
    assert rpath._posix_rabspath('/foo/bar/../x') == '/foo/x'

@py.test.mark.skipif("os.name == 'nt'")
def test_missing_current_dir(tmpdir):
    tmpdir1 = str(tmpdir) + '/temporary_removed'
    curdir1 = os.getcwd()
    try:
        os.mkdir(tmpdir1)
        os.chdir(tmpdir1)
        os.rmdir(tmpdir1)
        result = rpath.rabspath('.')
    finally:
        os.chdir(curdir1)
    assert result == '.'

def test_rsplitdrive_nt():
    assert rpath._nt_rsplitdrive('D:\\FOO/BAR') == ('D:', '\\FOO/BAR')
    assert rpath._nt_rsplitdrive('//') == ('', '//')

@py.test.mark.skipif("os.name != 'nt'")
def test_rabspath_absolute_nt():
    assert rpath._nt_rabspath('d:\\foo') == 'd:\\foo'
    assert rpath._nt_rabspath('d:\\foo\\bar\\..') == 'd:\\foo'
    assert rpath._nt_rabspath('d:\\foo\\bar\\..\\x') == 'd:\\foo\\x'
    curdrive = _ = rpath._nt_rsplitdrive(os.getcwd())
    assert len(curdrive) == 2 and curdrive[0][1] == ':'
    assert rpath.rabspath('\\foo') == '%s\\foo' % curdrive[0]

def test_risabs_posix():
    assert rpath._posix_risabs('/foo/bar')
    assert not rpath._posix_risabs('foo/bar')
    assert not rpath._posix_risabs('\\foo\\bar')
    assert not rpath._posix_risabs('C:\\foo\\bar')

def test_risabs_nt():
    assert rpath._nt_risabs('/foo/bar')
    assert not rpath._nt_risabs('foo/bar')
    assert rpath._nt_risabs('\\foo\\bar')
    assert rpath._nt_risabs('C:\\FOO')
    assert not rpath._nt_risabs('C:FOO')

def test_risdir(tmpdir):
    tmpdir = str(tmpdir)
    assert rpath.risdir(tmpdir)
    assert not rpath.risdir('_some_non_existant_file_')
    assert not rpath.risdir(os.path.join(tmpdir, '_some_non_existant_file_'))
