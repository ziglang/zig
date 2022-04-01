import py
import sys, stat, os
from rpython.translator.sandbox.vfs import *
from rpython.tool.udir import udir

HASLINK = hasattr(os, 'symlink')

def setup_module(mod):
    d = udir.ensure('test_vfs', dir=1)
    d.join('file1').write('somedata1')
    d.join('file2').write('somelongerdata2')
    os.chmod(str(d.join('file2')), stat.S_IWUSR)     # unreadable
    d.join('.hidden').write('secret')
    d.ensure('subdir1', dir=1).join('subfile1').write('spam')
    d.ensure('.subdir2', dir=1).join('subfile2').write('secret as well')
    if HASLINK:
        d.join('symlink1').mksymlinkto(str(d.join('subdir1')))
        d.join('symlink2').mksymlinkto('.hidden')
        d.join('symlink3').mksymlinkto('BROKEN')


def test_dir():
    d = Dir({'foo': Dir()})
    assert d.keys() == ['foo']
    py.test.raises(OSError, d.open)
    assert 0 <= d.getsize() <= sys.maxint
    d1 = d.join('foo')
    assert stat.S_ISDIR(d1.kind)
    assert d1.keys() == []
    py.test.raises(OSError, d.join, 'bar')
    st = d.stat()
    assert stat.S_ISDIR(st.st_mode)
    assert d.access(os.R_OK | os.X_OK)
    assert not d.access(os.W_OK)

def test_file():
    f = File('hello world')
    assert stat.S_ISREG(f.kind)
    py.test.raises(OSError, f.keys)
    assert f.getsize() == 11
    h = f.open()
    data = h.read()
    assert data == 'hello world'
    h.close()
    st = f.stat()
    assert stat.S_ISREG(st.st_mode)
    assert st.st_size == 11
    assert f.access(os.R_OK)
    assert not f.access(os.W_OK)

def test_realdir_realfile():
    for show_dotfiles in [False, True]:
        for follow_links in [False, True]:
            v_udir = RealDir(str(udir), show_dotfiles = show_dotfiles,
                                        follow_links  = follow_links)
            v_test_vfs = v_udir.join('test_vfs')
            names = v_test_vfs.keys()
            names.sort()
            assert names == (show_dotfiles * ['.hidden', '.subdir2'] +
                                          ['file1', 'file2', 'subdir1'] +
                             HASLINK * ['symlink1', 'symlink2', 'symlink3'])
            py.test.raises(OSError, v_test_vfs.open)
            assert 0 <= v_test_vfs.getsize() <= sys.maxint

            f = v_test_vfs.join('file1')
            assert f.open().read() == 'somedata1'

            f = v_test_vfs.join('file2')
            assert f.getsize() == len('somelongerdata2')
            if os.name != 'nt':     # can't have unreadable files there?
                py.test.raises(OSError, f.open)

            py.test.raises(OSError, v_test_vfs.join, 'does_not_exist')
            py.test.raises(OSError, v_test_vfs.join, 'symlink3')
            if follow_links and HASLINK:
                d = v_test_vfs.join('symlink1')
                assert stat.S_ISDIR(d.stat().st_mode)
                assert d.keys() == ['subfile1']
                assert d.join('subfile1').open().read() == 'spam'

                f = v_test_vfs.join('symlink2')
                assert stat.S_ISREG(f.stat().st_mode)
                assert f.access(os.R_OK)
                assert f.open().read() == 'secret'
            else:
                py.test.raises(OSError, v_test_vfs.join, 'symlink1')
                py.test.raises(OSError, v_test_vfs.join, 'symlink2')

            if show_dotfiles:
                f = v_test_vfs.join('.hidden')
                assert f.open().read() == 'secret'

                d = v_test_vfs.join('.subdir2')
                assert d.keys() == ['subfile2']
                assert d.join('subfile2').open().read() == 'secret as well'
            else:
                py.test.raises(OSError, v_test_vfs.join, '.hidden')
                py.test.raises(OSError, v_test_vfs.join, '.subdir2')

def test_realdir_exclude():
    xdir = udir.ensure('test_realdir_exclude', dir=1)
    xdir.ensure('test_realdir_exclude.yes')
    xdir.ensure('test_realdir_exclude.no')
    v_udir = RealDir(str(udir), exclude=['.no'])
    v_xdir = v_udir.join('test_realdir_exclude')
    assert 'test_realdir_exclude.yes' in v_xdir.keys()
    assert 'test_realdir_exclude.no' not in v_xdir.keys()
    v_xdir.join('test_realdir_exclude.yes')    # works
    py.test.raises(OSError, v_xdir.join, 'test_realdir_exclude.no')
    # Windows and Mac tests, for the case
    py.test.raises(OSError, v_xdir.join, 'Test_RealDir_Exclude.no')
    py.test.raises(OSError, v_xdir.join, 'test_realdir_exclude.No')
    py.test.raises(OSError, v_xdir.join, 'test_realdir_exclude.nO')
    py.test.raises(OSError, v_xdir.join, 'test_realdir_exclude.NO')
