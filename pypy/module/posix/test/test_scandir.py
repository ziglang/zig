import sys, os
import py
from rpython.tool.udir import udir
from pypy.module.posix.test import test_posix2


def _make_dir(dirname, content):
    d = os.path.join(str(udir), dirname)
    os.mkdir(d)
    for key, value in content.items():
        filename = os.path.join(d, key)
        if value == 'dir':
            os.mkdir(filename)
        elif value == 'file':
            with open(filename, 'w') as f:
                pass
        elif value == 'symlink-file':
            os.symlink(str(udir.ensure('some_file')), filename)
        elif value == 'symlink-dir':
            os.symlink(str(udir), filename)
        elif value == 'symlink-broken':
            os.symlink(filename + '-broken', filename)
        elif value == 'symlink-error':
            os.symlink(filename, filename)
        else:
            raise NotImplementedError(repr(value))
    return d.decode(sys.getfilesystemencoding())


class AppTestScandir(object):
    spaceconfig = {'usemodules': test_posix2.USEMODULES}

    def setup_class(cls):
        space = cls.space
        cls.w_WIN32 = space.wrap(sys.platform == 'win32')
        cls.w_sep = space.newtext(os.sep)
        cls.w_sepB = space.newbytes(os.sep)
        cls.w_posix = space.appexec([], test_posix2.GET_POSIX)
        cls.w_dir_empty = space.wrap(_make_dir('empty', {}))
        cls.w_dir0 = space.wrap(_make_dir('dir0', {'f1': 'file',
                                                   'f2': 'file',
                                                   'f3': 'file'}))
        cls.w_dir1 = space.wrap(_make_dir('dir1', {'file1': 'file'}))
        cls.w_dir2 = space.wrap(_make_dir('dir2', {'subdir2': 'dir'}))
        if sys.platform != 'win32':
            cls.w_dir3 = space.wrap(_make_dir('dir3', {'sfile3': 'symlink-file'}))
            cls.w_dir4 = space.wrap(_make_dir('dir4', {'sdir4': 'symlink-dir'}))
            cls.w_dir5 = space.wrap(_make_dir('dir5', {'sbrok5': 'symlink-broken'}))
            cls.w_dir6 = space.wrap(_make_dir('dir6', {'serr6': 'symlink-error'}))

    def test_scandir_empty(self):
        posix = self.posix
        sd = posix.scandir(self.dir_empty)
        assert list(sd) == []
        assert list(sd) == []

    def test_scandir_files(self):
        posix = self.posix
        sd = posix.scandir(self.dir0)
        names = [d.name for d in sd]
        assert sorted(names) == ['f1', 'f2', 'f3']

    def test_unicode_versus_bytes(self):
        posix = self.posix
        d = next(posix.scandir())
        assert type(d.name) is str
        assert type(d.path) is str
        assert d.path == '.' + self.sep + d.name
        d = next(posix.scandir(None))
        assert type(d.name) is str
        assert type(d.path) is str
        assert d.path == '.' + self.sep + d.name
        d = next(posix.scandir(u'.'))
        assert type(d.name) is str
        assert type(d.path) is str
        assert d.path == '.' + self.sep + d.name
        d = next(posix.scandir(self.sep))
        assert type(d.name) is str
        assert type(d.path) is str
        assert d.path == self.sep + d.name
        d = next(posix.scandir(b'.'))
        assert type(d.name) is bytes
        assert type(d.path) is bytes
        assert d.path == b'.' + self.sepB + d.name
        d = next(posix.scandir(b'/'))
        assert type(d.name) is bytes
        assert type(d.path) is bytes
        assert d.path == b'/' + d.name

    def test_stat1(self):
        posix = self.posix
        d = next(posix.scandir(self.dir1))
        assert d.name == 'file1'
        assert d.stat().st_mode & 0o170000 == 0o100000    # S_IFREG
        assert d.stat().st_size == 0

    @py.test.mark.skipif(sys.platform == "win32", reason="no symlink support so far")
    def test_stat4(self):
        posix = self.posix
        d = next(posix.scandir(self.dir4))
        assert d.name == 'sdir4'
        assert d.stat().st_mode & 0o170000 == 0o040000    # S_IFDIR
        assert d.stat(follow_symlinks=True).st_mode &0o170000 == 0o040000
        assert d.stat(follow_symlinks=False).st_mode&0o170000 == 0o120000 #IFLNK

    def test_dir1(self):
        posix = self.posix
        d = next(posix.scandir(self.dir1))
        assert d.name == 'file1'
        assert     d.is_file()
        assert not d.is_dir()
        assert not d.is_symlink()
        raises(TypeError, d.is_file, True)
        assert     d.is_file(follow_symlinks=False)
        assert not d.is_dir(follow_symlinks=False)

    def test_dir2(self):
        posix = self.posix
        d = next(posix.scandir(self.dir2))
        assert d.name == 'subdir2'
        assert not d.is_file()
        assert     d.is_dir()
        assert not d.is_symlink()
        assert not d.is_file(follow_symlinks=False)
        assert     d.is_dir(follow_symlinks=False)

    @py.test.mark.skipif(sys.platform == "win32", reason="no symlink support so far")
    def test_dir3(self):
        posix = self.posix
        d = next(posix.scandir(self.dir3))
        assert d.name == 'sfile3'
        assert     d.is_file()
        assert not d.is_dir()
        assert     d.is_symlink()
        assert     d.is_file(follow_symlinks=True)
        assert not d.is_file(follow_symlinks=False)

    @py.test.mark.skipif(sys.platform == "win32", reason="no symlink support so far")
    def test_dir4(self):
        posix = self.posix
        d = next(posix.scandir(self.dir4))
        assert d.name == 'sdir4'
        assert not d.is_file()
        assert     d.is_dir()
        assert     d.is_symlink()
        assert     d.is_dir(follow_symlinks=True)
        assert not d.is_dir(follow_symlinks=False)

    @py.test.mark.skipif(sys.platform == "win32", reason="no symlink support so far")
    def test_dir5(self):
        posix = self.posix
        d = next(posix.scandir(self.dir5))
        assert d.name == 'sbrok5'
        assert not d.is_file()
        assert not d.is_dir()
        assert     d.is_symlink()
        raises(OSError, d.stat)

    @py.test.mark.skipif(sys.platform == "win32", reason="no symlink support so far")
    def test_dir6(self):
        posix = self.posix
        d = next(posix.scandir(self.dir6))
        assert d.name == 'serr6'
        raises(OSError, d.is_file)
        raises(OSError, d.is_dir)
        assert d.is_symlink()

    def test_fdopendir(self):
        posix = self.posix
        import stat
        if 'HAVE_FDOPENDIR' in posix._have_functions:
            raises(OSError, posix.scandir, 1234)
            # do like shutil._rmtree_safe_fd
            topfd = posix.open(self.dir2, posix.O_RDONLY)
            try:
                with posix.scandir(topfd) as scandir_it:
                    entries = list(scandir_it)
                assert len(entries) > 0
                entry = entries[0]
                stat_val = entry.stat(follow_symlinks=False)
                assert stat.S_ISDIR(stat_val.st_mode)
            finally:
                posix.close(topfd)
            fd = posix.open(self.dir0 + self.sep + 'f1', posix.O_RDONLY)
            try:
                with raises(NotADirectoryError):
                    posix.scandir(fd)
            finally:
                posix.close(fd)
        else:
            raises(TypeError, posix.scandir, 1234)

    @py.test.mark.skipif(sys.platform == "win32", reason="no inode support")
    def test_inode(self):
        posix = self.posix
        d = next(posix.scandir(self.dir1))
        assert d.name == 'file1'
        ino = d.inode()
        assert ino == d.stat().st_ino

    def test_repr(self):
        posix = self.posix
        d = next(posix.scandir(self.dir1))
        assert isinstance(d, posix.DirEntry)
        assert repr(d) == "<DirEntry 'file1'>"

    def test_fspath(self):
        posix = self.posix
        d = next(posix.scandir(self.dir1))
        assert self.posix.fspath(d).endswith('dir1' + self.sep + 'file1')

    def test_resource_warning(self):
        posix = self.posix
        import warnings, gc
        iterator = posix.scandir(self.dir1)
        next(iterator)
        with warnings.catch_warnings(record=True) as l:
            warnings.simplefilter("always")
            del iterator
            gc.collect()
        assert isinstance(l[0].message, ResourceWarning)
        #
        iterator = posix.scandir(self.dir1)
        next(iterator)
        with warnings.catch_warnings(record=True) as l:
            warnings.simplefilter("always")
            iterator.close()
            del iterator
            gc.collect()
        assert len(l) == 0

    def test_context_manager(self):
        posix = self.posix
        import warnings, gc
        with warnings.catch_warnings(record=True) as l:
            warnings.simplefilter("always")
            with posix.scandir(self.dir1) as iterator:
                next(iterator)
            del iterator
            gc.collect()
        assert not l

    def test_lstat(self):
        posix = self.posix
        d = next(posix.scandir(self.dir1))
        with open(d) as fp:
            length = len(fp.read())
        assert posix.lstat(d).st_size == length
