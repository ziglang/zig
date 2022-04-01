import os
import posixpath
import unittest
from posixpath import realpath, abspath, dirname, basename
from test import support, test_genericpath
from test.support import FakePath
from unittest import mock

try:
    import posix
except ImportError:
    posix = None


# An absolute path to a temporary filename for testing. We can't rely on TESTFN
# being an absolute path, so we need this.

ABSTFN = abspath(support.TESTFN)

def skip_if_ABSTFN_contains_backslash(test):
    """
    On Windows, posixpath.abspath still returns paths with backslashes
    instead of posix forward slashes. If this is the case, several tests
    fail, so skip them.
    """
    found_backslash = '\\' in ABSTFN
    msg = "ABSTFN is not a posix path - tests fail"
    return [test, unittest.skip(msg)(test)][found_backslash]

def safe_rmdir(dirname):
    try:
        os.rmdir(dirname)
    except OSError:
        pass

class PosixPathTest(unittest.TestCase):

    def setUp(self):
        self.tearDown()

    def tearDown(self):
        for suffix in ["", "1", "2"]:
            support.unlink(support.TESTFN + suffix)
            safe_rmdir(support.TESTFN + suffix)

    def test_join(self):
        self.assertEqual(posixpath.join("/foo", "bar", "/bar", "baz"),
                         "/bar/baz")
        self.assertEqual(posixpath.join("/foo", "bar", "baz"), "/foo/bar/baz")
        self.assertEqual(posixpath.join("/foo/", "bar/", "baz/"),
                         "/foo/bar/baz/")

        self.assertEqual(posixpath.join(b"/foo", b"bar", b"/bar", b"baz"),
                         b"/bar/baz")
        self.assertEqual(posixpath.join(b"/foo", b"bar", b"baz"),
                         b"/foo/bar/baz")
        self.assertEqual(posixpath.join(b"/foo/", b"bar/", b"baz/"),
                         b"/foo/bar/baz/")

    def test_split(self):
        self.assertEqual(posixpath.split("/foo/bar"), ("/foo", "bar"))
        self.assertEqual(posixpath.split("/"), ("/", ""))
        self.assertEqual(posixpath.split("foo"), ("", "foo"))
        self.assertEqual(posixpath.split("////foo"), ("////", "foo"))
        self.assertEqual(posixpath.split("//foo//bar"), ("//foo", "bar"))

        self.assertEqual(posixpath.split(b"/foo/bar"), (b"/foo", b"bar"))
        self.assertEqual(posixpath.split(b"/"), (b"/", b""))
        self.assertEqual(posixpath.split(b"foo"), (b"", b"foo"))
        self.assertEqual(posixpath.split(b"////foo"), (b"////", b"foo"))
        self.assertEqual(posixpath.split(b"//foo//bar"), (b"//foo", b"bar"))

    def splitextTest(self, path, filename, ext):
        self.assertEqual(posixpath.splitext(path), (filename, ext))
        self.assertEqual(posixpath.splitext("/" + path), ("/" + filename, ext))
        self.assertEqual(posixpath.splitext("abc/" + path),
                         ("abc/" + filename, ext))
        self.assertEqual(posixpath.splitext("abc.def/" + path),
                         ("abc.def/" + filename, ext))
        self.assertEqual(posixpath.splitext("/abc.def/" + path),
                         ("/abc.def/" + filename, ext))
        self.assertEqual(posixpath.splitext(path + "/"),
                         (filename + ext + "/", ""))

        path = bytes(path, "ASCII")
        filename = bytes(filename, "ASCII")
        ext = bytes(ext, "ASCII")

        self.assertEqual(posixpath.splitext(path), (filename, ext))
        self.assertEqual(posixpath.splitext(b"/" + path),
                         (b"/" + filename, ext))
        self.assertEqual(posixpath.splitext(b"abc/" + path),
                         (b"abc/" + filename, ext))
        self.assertEqual(posixpath.splitext(b"abc.def/" + path),
                         (b"abc.def/" + filename, ext))
        self.assertEqual(posixpath.splitext(b"/abc.def/" + path),
                         (b"/abc.def/" + filename, ext))
        self.assertEqual(posixpath.splitext(path + b"/"),
                         (filename + ext + b"/", b""))

    def test_splitext(self):
        self.splitextTest("foo.bar", "foo", ".bar")
        self.splitextTest("foo.boo.bar", "foo.boo", ".bar")
        self.splitextTest("foo.boo.biff.bar", "foo.boo.biff", ".bar")
        self.splitextTest(".csh.rc", ".csh", ".rc")
        self.splitextTest("nodots", "nodots", "")
        self.splitextTest(".cshrc", ".cshrc", "")
        self.splitextTest("...manydots", "...manydots", "")
        self.splitextTest("...manydots.ext", "...manydots", ".ext")
        self.splitextTest(".", ".", "")
        self.splitextTest("..", "..", "")
        self.splitextTest("........", "........", "")
        self.splitextTest("", "", "")

    def test_isabs(self):
        self.assertIs(posixpath.isabs(""), False)
        self.assertIs(posixpath.isabs("/"), True)
        self.assertIs(posixpath.isabs("/foo"), True)
        self.assertIs(posixpath.isabs("/foo/bar"), True)
        self.assertIs(posixpath.isabs("foo/bar"), False)

        self.assertIs(posixpath.isabs(b""), False)
        self.assertIs(posixpath.isabs(b"/"), True)
        self.assertIs(posixpath.isabs(b"/foo"), True)
        self.assertIs(posixpath.isabs(b"/foo/bar"), True)
        self.assertIs(posixpath.isabs(b"foo/bar"), False)

    def test_basename(self):
        self.assertEqual(posixpath.basename("/foo/bar"), "bar")
        self.assertEqual(posixpath.basename("/"), "")
        self.assertEqual(posixpath.basename("foo"), "foo")
        self.assertEqual(posixpath.basename("////foo"), "foo")
        self.assertEqual(posixpath.basename("//foo//bar"), "bar")

        self.assertEqual(posixpath.basename(b"/foo/bar"), b"bar")
        self.assertEqual(posixpath.basename(b"/"), b"")
        self.assertEqual(posixpath.basename(b"foo"), b"foo")
        self.assertEqual(posixpath.basename(b"////foo"), b"foo")
        self.assertEqual(posixpath.basename(b"//foo//bar"), b"bar")

    def test_dirname(self):
        self.assertEqual(posixpath.dirname("/foo/bar"), "/foo")
        self.assertEqual(posixpath.dirname("/"), "/")
        self.assertEqual(posixpath.dirname("foo"), "")
        self.assertEqual(posixpath.dirname("////foo"), "////")
        self.assertEqual(posixpath.dirname("//foo//bar"), "//foo")

        self.assertEqual(posixpath.dirname(b"/foo/bar"), b"/foo")
        self.assertEqual(posixpath.dirname(b"/"), b"/")
        self.assertEqual(posixpath.dirname(b"foo"), b"")
        self.assertEqual(posixpath.dirname(b"////foo"), b"////")
        self.assertEqual(posixpath.dirname(b"//foo//bar"), b"//foo")

    def test_islink(self):
        self.assertIs(posixpath.islink(support.TESTFN + "1"), False)
        self.assertIs(posixpath.lexists(support.TESTFN + "2"), False)

        with open(support.TESTFN + "1", "wb") as f:
            f.write(b"foo")
        self.assertIs(posixpath.islink(support.TESTFN + "1"), False)

        if support.can_symlink():
            os.symlink(support.TESTFN + "1", support.TESTFN + "2")
            self.assertIs(posixpath.islink(support.TESTFN + "2"), True)
            os.remove(support.TESTFN + "1")
            self.assertIs(posixpath.islink(support.TESTFN + "2"), True)
            self.assertIs(posixpath.exists(support.TESTFN + "2"), False)
            self.assertIs(posixpath.lexists(support.TESTFN + "2"), True)

        self.assertIs(posixpath.islink(support.TESTFN + "\udfff"), False)
        self.assertIs(posixpath.islink(os.fsencode(support.TESTFN) + b"\xff"), False)
        self.assertIs(posixpath.islink(support.TESTFN + "\x00"), False)
        self.assertIs(posixpath.islink(os.fsencode(support.TESTFN) + b"\x00"), False)

    def test_ismount(self):
        self.assertIs(posixpath.ismount("/"), True)
        self.assertIs(posixpath.ismount(b"/"), True)

    def test_ismount_non_existent(self):
        # Non-existent mountpoint.
        self.assertIs(posixpath.ismount(ABSTFN), False)
        try:
            os.mkdir(ABSTFN)
            self.assertIs(posixpath.ismount(ABSTFN), False)
        finally:
            safe_rmdir(ABSTFN)

        self.assertIs(posixpath.ismount('/\udfff'), False)
        self.assertIs(posixpath.ismount(b'/\xff'), False)
        self.assertIs(posixpath.ismount('/\x00'), False)
        self.assertIs(posixpath.ismount(b'/\x00'), False)

    @unittest.skipUnless(support.can_symlink(),
                         "Test requires symlink support")
    def test_ismount_symlinks(self):
        # Symlinks are never mountpoints.
        try:
            os.symlink("/", ABSTFN)
            self.assertIs(posixpath.ismount(ABSTFN), False)
        finally:
            os.unlink(ABSTFN)

    @unittest.skipIf(posix is None, "Test requires posix module")
    def test_ismount_different_device(self):
        # Simulate the path being on a different device from its parent by
        # mocking out st_dev.
        save_lstat = os.lstat
        def fake_lstat(path):
            st_ino = 0
            st_dev = 0
            if path == ABSTFN:
                st_dev = 1
                st_ino = 1
            return posix.stat_result((0, st_ino, st_dev, 0, 0, 0, 0, 0, 0, 0))
        try:
            os.lstat = fake_lstat
            self.assertIs(posixpath.ismount(ABSTFN), True)
        finally:
            os.lstat = save_lstat

    @unittest.skipIf(posix is None, "Test requires posix module")
    def test_ismount_directory_not_readable(self):
        # issue #2466: Simulate ismount run on a directory that is not
        # readable, which used to return False.
        save_lstat = os.lstat
        def fake_lstat(path):
            st_ino = 0
            st_dev = 0
            if path.startswith(ABSTFN) and path != ABSTFN:
                # ismount tries to read something inside the ABSTFN directory;
                # simulate this being forbidden (no read permission).
                raise OSError("Fake [Errno 13] Permission denied")
            if path == ABSTFN:
                st_dev = 1
                st_ino = 1
            return posix.stat_result((0, st_ino, st_dev, 0, 0, 0, 0, 0, 0, 0))
        try:
            os.lstat = fake_lstat
            self.assertIs(posixpath.ismount(ABSTFN), True)
        finally:
            os.lstat = save_lstat

    def test_expanduser(self):
        self.assertEqual(posixpath.expanduser("foo"), "foo")
        self.assertEqual(posixpath.expanduser(b"foo"), b"foo")

    def test_expanduser_home_envvar(self):
        with support.EnvironmentVarGuard() as env:
            env['HOME'] = '/home/victor'
            self.assertEqual(posixpath.expanduser("~"), "/home/victor")

            # expanduser() strips trailing slash
            env['HOME'] = '/home/victor/'
            self.assertEqual(posixpath.expanduser("~"), "/home/victor")

            for home in '/', '', '//', '///':
                with self.subTest(home=home):
                    env['HOME'] = home
                    self.assertEqual(posixpath.expanduser("~"), "/")
                    self.assertEqual(posixpath.expanduser("~/"), "/")
                    self.assertEqual(posixpath.expanduser("~/foo"), "/foo")

    def test_expanduser_pwd(self):
        pwd = support.import_module('pwd')

        self.assertIsInstance(posixpath.expanduser("~/"), str)
        self.assertIsInstance(posixpath.expanduser(b"~/"), bytes)

        # if home directory == root directory, this test makes no sense
        if posixpath.expanduser("~") != '/':
            self.assertEqual(
                posixpath.expanduser("~") + "/",
                posixpath.expanduser("~/")
            )
            self.assertEqual(
                posixpath.expanduser(b"~") + b"/",
                posixpath.expanduser(b"~/")
            )
        self.assertIsInstance(posixpath.expanduser("~root/"), str)
        self.assertIsInstance(posixpath.expanduser("~foo/"), str)
        self.assertIsInstance(posixpath.expanduser(b"~root/"), bytes)
        self.assertIsInstance(posixpath.expanduser(b"~foo/"), bytes)

        with support.EnvironmentVarGuard() as env:
            # expanduser should fall back to using the password database
            del env['HOME']

            home = pwd.getpwuid(os.getuid()).pw_dir
            # $HOME can end with a trailing /, so strip it (see #17809)
            home = home.rstrip("/") or '/'
            self.assertEqual(posixpath.expanduser("~"), home)

            # bpo-10496: If the HOME environment variable is not set and the
            # user (current identifier or name in the path) doesn't exist in
            # the password database (pwd.getuid() or pwd.getpwnam() fail),
            # expanduser() must return the path unchanged.
            with mock.patch.object(pwd, 'getpwuid', side_effect=KeyError), \
                 mock.patch.object(pwd, 'getpwnam', side_effect=KeyError):
                for path in ('~', '~/.local', '~vstinner/'):
                    self.assertEqual(posixpath.expanduser(path), path)

    def test_normpath(self):
        self.assertEqual(posixpath.normpath(""), ".")
        self.assertEqual(posixpath.normpath("/"), "/")
        self.assertEqual(posixpath.normpath("//"), "//")
        self.assertEqual(posixpath.normpath("///"), "/")
        self.assertEqual(posixpath.normpath("///foo/.//bar//"), "/foo/bar")
        self.assertEqual(posixpath.normpath("///foo/.//bar//.//..//.//baz"),
                         "/foo/baz")
        self.assertEqual(posixpath.normpath("///..//./foo/.//bar"), "/foo/bar")

        self.assertEqual(posixpath.normpath(b""), b".")
        self.assertEqual(posixpath.normpath(b"/"), b"/")
        self.assertEqual(posixpath.normpath(b"//"), b"//")
        self.assertEqual(posixpath.normpath(b"///"), b"/")
        self.assertEqual(posixpath.normpath(b"///foo/.//bar//"), b"/foo/bar")
        self.assertEqual(posixpath.normpath(b"///foo/.//bar//.//..//.//baz"),
                         b"/foo/baz")
        self.assertEqual(posixpath.normpath(b"///..//./foo/.//bar"),
                         b"/foo/bar")

    @skip_if_ABSTFN_contains_backslash
    def test_realpath_curdir(self):
        self.assertEqual(realpath('.'), os.getcwd())
        self.assertEqual(realpath('./.'), os.getcwd())
        self.assertEqual(realpath('/'.join(['.'] * 100)), os.getcwd())

        self.assertEqual(realpath(b'.'), os.getcwdb())
        self.assertEqual(realpath(b'./.'), os.getcwdb())
        self.assertEqual(realpath(b'/'.join([b'.'] * 100)), os.getcwdb())

    @skip_if_ABSTFN_contains_backslash
    def test_realpath_pardir(self):
        self.assertEqual(realpath('..'), dirname(os.getcwd()))
        self.assertEqual(realpath('../..'), dirname(dirname(os.getcwd())))
        self.assertEqual(realpath('/'.join(['..'] * 100)), '/')

        self.assertEqual(realpath(b'..'), dirname(os.getcwdb()))
        self.assertEqual(realpath(b'../..'), dirname(dirname(os.getcwdb())))
        self.assertEqual(realpath(b'/'.join([b'..'] * 100)), b'/')

    @unittest.skipUnless(hasattr(os, "symlink"),
                         "Missing symlink implementation")
    @skip_if_ABSTFN_contains_backslash
    def test_realpath_basic(self):
        # Basic operation.
        try:
            os.symlink(ABSTFN+"1", ABSTFN)
            self.assertEqual(realpath(ABSTFN), ABSTFN+"1")
        finally:
            support.unlink(ABSTFN)

    @unittest.skipUnless(hasattr(os, "symlink"),
                         "Missing symlink implementation")
    @skip_if_ABSTFN_contains_backslash
    def test_realpath_relative(self):
        try:
            os.symlink(posixpath.relpath(ABSTFN+"1"), ABSTFN)
            self.assertEqual(realpath(ABSTFN), ABSTFN+"1")
        finally:
            support.unlink(ABSTFN)

    @unittest.skipUnless(hasattr(os, "symlink"),
                         "Missing symlink implementation")
    @skip_if_ABSTFN_contains_backslash
    def test_realpath_symlink_loops(self):
        # Bug #930024, return the path unchanged if we get into an infinite
        # symlink loop.
        try:
            os.symlink(ABSTFN, ABSTFN)
            self.assertEqual(realpath(ABSTFN), ABSTFN)

            os.symlink(ABSTFN+"1", ABSTFN+"2")
            os.symlink(ABSTFN+"2", ABSTFN+"1")
            self.assertEqual(realpath(ABSTFN+"1"), ABSTFN+"1")
            self.assertEqual(realpath(ABSTFN+"2"), ABSTFN+"2")

            self.assertEqual(realpath(ABSTFN+"1/x"), ABSTFN+"1/x")
            self.assertEqual(realpath(ABSTFN+"1/.."), dirname(ABSTFN))
            self.assertEqual(realpath(ABSTFN+"1/../x"), dirname(ABSTFN) + "/x")
            os.symlink(ABSTFN+"x", ABSTFN+"y")
            self.assertEqual(realpath(ABSTFN+"1/../" + basename(ABSTFN) + "y"),
                             ABSTFN + "y")
            self.assertEqual(realpath(ABSTFN+"1/../" + basename(ABSTFN) + "1"),
                             ABSTFN + "1")

            os.symlink(basename(ABSTFN) + "a/b", ABSTFN+"a")
            self.assertEqual(realpath(ABSTFN+"a"), ABSTFN+"a/b")

            os.symlink("../" + basename(dirname(ABSTFN)) + "/" +
                       basename(ABSTFN) + "c", ABSTFN+"c")
            self.assertEqual(realpath(ABSTFN+"c"), ABSTFN+"c")

            # Test using relative path as well.
            with support.change_cwd(dirname(ABSTFN)):
                self.assertEqual(realpath(basename(ABSTFN)), ABSTFN)
        finally:
            support.unlink(ABSTFN)
            support.unlink(ABSTFN+"1")
            support.unlink(ABSTFN+"2")
            support.unlink(ABSTFN+"y")
            support.unlink(ABSTFN+"c")
            support.unlink(ABSTFN+"a")

    @unittest.skipUnless(hasattr(os, "symlink"),
                         "Missing symlink implementation")
    @skip_if_ABSTFN_contains_backslash
    def test_realpath_repeated_indirect_symlinks(self):
        # Issue #6975.
        try:
            os.mkdir(ABSTFN)
            os.symlink('../' + basename(ABSTFN), ABSTFN + '/self')
            os.symlink('self/self/self', ABSTFN + '/link')
            self.assertEqual(realpath(ABSTFN + '/link'), ABSTFN)
        finally:
            support.unlink(ABSTFN + '/self')
            support.unlink(ABSTFN + '/link')
            safe_rmdir(ABSTFN)

    @unittest.skipUnless(hasattr(os, "symlink"),
                         "Missing symlink implementation")
    @skip_if_ABSTFN_contains_backslash
    def test_realpath_deep_recursion(self):
        depth = 10
        try:
            os.mkdir(ABSTFN)
            for i in range(depth):
                os.symlink('/'.join(['%d' % i] * 10), ABSTFN + '/%d' % (i + 1))
            os.symlink('.', ABSTFN + '/0')
            self.assertEqual(realpath(ABSTFN + '/%d' % depth), ABSTFN)

            # Test using relative path as well.
            with support.change_cwd(ABSTFN):
                self.assertEqual(realpath('%d' % depth), ABSTFN)
        finally:
            for i in range(depth + 1):
                support.unlink(ABSTFN + '/%d' % i)
            safe_rmdir(ABSTFN)

    @unittest.skipUnless(hasattr(os, "symlink"),
                         "Missing symlink implementation")
    @skip_if_ABSTFN_contains_backslash
    def test_realpath_resolve_parents(self):
        # We also need to resolve any symlinks in the parents of a relative
        # path passed to realpath. E.g.: current working directory is
        # /usr/doc with 'doc' being a symlink to /usr/share/doc. We call
        # realpath("a"). This should return /usr/share/doc/a/.
        try:
            os.mkdir(ABSTFN)
            os.mkdir(ABSTFN + "/y")
            os.symlink(ABSTFN + "/y", ABSTFN + "/k")

            with support.change_cwd(ABSTFN + "/k"):
                self.assertEqual(realpath("a"), ABSTFN + "/y/a")
        finally:
            support.unlink(ABSTFN + "/k")
            safe_rmdir(ABSTFN + "/y")
            safe_rmdir(ABSTFN)

    @unittest.skipUnless(hasattr(os, "symlink"),
                         "Missing symlink implementation")
    @skip_if_ABSTFN_contains_backslash
    def test_realpath_resolve_before_normalizing(self):
        # Bug #990669: Symbolic links should be resolved before we
        # normalize the path. E.g.: if we have directories 'a', 'k' and 'y'
        # in the following hierarchy:
        # a/k/y
        #
        # and a symbolic link 'link-y' pointing to 'y' in directory 'a',
        # then realpath("link-y/..") should return 'k', not 'a'.
        try:
            os.mkdir(ABSTFN)
            os.mkdir(ABSTFN + "/k")
            os.mkdir(ABSTFN + "/k/y")
            os.symlink(ABSTFN + "/k/y", ABSTFN + "/link-y")

            # Absolute path.
            self.assertEqual(realpath(ABSTFN + "/link-y/.."), ABSTFN + "/k")
            # Relative path.
            with support.change_cwd(dirname(ABSTFN)):
                self.assertEqual(realpath(basename(ABSTFN) + "/link-y/.."),
                                 ABSTFN + "/k")
        finally:
            support.unlink(ABSTFN + "/link-y")
            safe_rmdir(ABSTFN + "/k/y")
            safe_rmdir(ABSTFN + "/k")
            safe_rmdir(ABSTFN)

    @unittest.skipUnless(hasattr(os, "symlink"),
                         "Missing symlink implementation")
    @skip_if_ABSTFN_contains_backslash
    def test_realpath_resolve_first(self):
        # Bug #1213894: The first component of the path, if not absolute,
        # must be resolved too.

        try:
            os.mkdir(ABSTFN)
            os.mkdir(ABSTFN + "/k")
            os.symlink(ABSTFN, ABSTFN + "link")
            with support.change_cwd(dirname(ABSTFN)):
                base = basename(ABSTFN)
                self.assertEqual(realpath(base + "link"), ABSTFN)
                self.assertEqual(realpath(base + "link/k"), ABSTFN + "/k")
        finally:
            support.unlink(ABSTFN + "link")
            safe_rmdir(ABSTFN + "/k")
            safe_rmdir(ABSTFN)

    def test_relpath(self):
        (real_getcwd, os.getcwd) = (os.getcwd, lambda: r"/home/user/bar")
        try:
            curdir = os.path.split(os.getcwd())[-1]
            self.assertRaises(ValueError, posixpath.relpath, "")
            self.assertEqual(posixpath.relpath("a"), "a")
            self.assertEqual(posixpath.relpath(posixpath.abspath("a")), "a")
            self.assertEqual(posixpath.relpath("a/b"), "a/b")
            self.assertEqual(posixpath.relpath("../a/b"), "../a/b")
            self.assertEqual(posixpath.relpath("a", "../b"), "../"+curdir+"/a")
            self.assertEqual(posixpath.relpath("a/b", "../c"),
                             "../"+curdir+"/a/b")
            self.assertEqual(posixpath.relpath("a", "b/c"), "../../a")
            self.assertEqual(posixpath.relpath("a", "a"), ".")
            self.assertEqual(posixpath.relpath("/foo/bar/bat", "/x/y/z"), '../../../foo/bar/bat')
            self.assertEqual(posixpath.relpath("/foo/bar/bat", "/foo/bar"), 'bat')
            self.assertEqual(posixpath.relpath("/foo/bar/bat", "/"), 'foo/bar/bat')
            self.assertEqual(posixpath.relpath("/", "/foo/bar/bat"), '../../..')
            self.assertEqual(posixpath.relpath("/foo/bar/bat", "/x"), '../foo/bar/bat')
            self.assertEqual(posixpath.relpath("/x", "/foo/bar/bat"), '../../../x')
            self.assertEqual(posixpath.relpath("/", "/"), '.')
            self.assertEqual(posixpath.relpath("/a", "/a"), '.')
            self.assertEqual(posixpath.relpath("/a/b", "/a/b"), '.')
        finally:
            os.getcwd = real_getcwd

    def test_relpath_bytes(self):
        (real_getcwdb, os.getcwdb) = (os.getcwdb, lambda: br"/home/user/bar")
        try:
            curdir = os.path.split(os.getcwdb())[-1]
            self.assertRaises(ValueError, posixpath.relpath, b"")
            self.assertEqual(posixpath.relpath(b"a"), b"a")
            self.assertEqual(posixpath.relpath(posixpath.abspath(b"a")), b"a")
            self.assertEqual(posixpath.relpath(b"a/b"), b"a/b")
            self.assertEqual(posixpath.relpath(b"../a/b"), b"../a/b")
            self.assertEqual(posixpath.relpath(b"a", b"../b"),
                             b"../"+curdir+b"/a")
            self.assertEqual(posixpath.relpath(b"a/b", b"../c"),
                             b"../"+curdir+b"/a/b")
            self.assertEqual(posixpath.relpath(b"a", b"b/c"), b"../../a")
            self.assertEqual(posixpath.relpath(b"a", b"a"), b".")
            self.assertEqual(posixpath.relpath(b"/foo/bar/bat", b"/x/y/z"), b'../../../foo/bar/bat')
            self.assertEqual(posixpath.relpath(b"/foo/bar/bat", b"/foo/bar"), b'bat')
            self.assertEqual(posixpath.relpath(b"/foo/bar/bat", b"/"), b'foo/bar/bat')
            self.assertEqual(posixpath.relpath(b"/", b"/foo/bar/bat"), b'../../..')
            self.assertEqual(posixpath.relpath(b"/foo/bar/bat", b"/x"), b'../foo/bar/bat')
            self.assertEqual(posixpath.relpath(b"/x", b"/foo/bar/bat"), b'../../../x')
            self.assertEqual(posixpath.relpath(b"/", b"/"), b'.')
            self.assertEqual(posixpath.relpath(b"/a", b"/a"), b'.')
            self.assertEqual(posixpath.relpath(b"/a/b", b"/a/b"), b'.')

            self.assertRaises(TypeError, posixpath.relpath, b"bytes", "str")
            self.assertRaises(TypeError, posixpath.relpath, "str", b"bytes")
        finally:
            os.getcwdb = real_getcwdb

    def test_commonpath(self):
        def check(paths, expected):
            self.assertEqual(posixpath.commonpath(paths), expected)
            self.assertEqual(posixpath.commonpath([os.fsencode(p) for p in paths]),
                             os.fsencode(expected))
        def check_error(exc, paths):
            self.assertRaises(exc, posixpath.commonpath, paths)
            self.assertRaises(exc, posixpath.commonpath,
                              [os.fsencode(p) for p in paths])

        self.assertRaises(ValueError, posixpath.commonpath, [])
        check_error(ValueError, ['/usr', 'usr'])
        check_error(ValueError, ['usr', '/usr'])

        check(['/usr/local'], '/usr/local')
        check(['/usr/local', '/usr/local'], '/usr/local')
        check(['/usr/local/', '/usr/local'], '/usr/local')
        check(['/usr/local/', '/usr/local/'], '/usr/local')
        check(['/usr//local', '//usr/local'], '/usr/local')
        check(['/usr/./local', '/./usr/local'], '/usr/local')
        check(['/', '/dev'], '/')
        check(['/usr', '/dev'], '/')
        check(['/usr/lib/', '/usr/lib/python3'], '/usr/lib')
        check(['/usr/lib/', '/usr/lib64/'], '/usr')

        check(['/usr/lib', '/usr/lib64'], '/usr')
        check(['/usr/lib/', '/usr/lib64'], '/usr')

        check(['spam'], 'spam')
        check(['spam', 'spam'], 'spam')
        check(['spam', 'alot'], '')
        check(['and/jam', 'and/spam'], 'and')
        check(['and//jam', 'and/spam//'], 'and')
        check(['and/./jam', './and/spam'], 'and')
        check(['and/jam', 'and/spam', 'alot'], '')
        check(['and/jam', 'and/spam', 'and'], 'and')

        check([''], '')
        check(['', 'spam/alot'], '')
        check_error(ValueError, ['', '/spam/alot'])

        self.assertRaises(TypeError, posixpath.commonpath,
                          [b'/usr/lib/', '/usr/lib/python3'])
        self.assertRaises(TypeError, posixpath.commonpath,
                          [b'/usr/lib/', 'usr/lib/python3'])
        self.assertRaises(TypeError, posixpath.commonpath,
                          [b'usr/lib/', '/usr/lib/python3'])
        self.assertRaises(TypeError, posixpath.commonpath,
                          ['/usr/lib/', b'/usr/lib/python3'])
        self.assertRaises(TypeError, posixpath.commonpath,
                          ['/usr/lib/', b'usr/lib/python3'])
        self.assertRaises(TypeError, posixpath.commonpath,
                          ['usr/lib/', b'/usr/lib/python3'])


class PosixCommonTest(test_genericpath.CommonTest, unittest.TestCase):
    pathmodule = posixpath
    attributes = ['relpath', 'samefile', 'sameopenfile', 'samestat']


class PathLikeTests(unittest.TestCase):

    path = posixpath

    def setUp(self):
        self.file_name = support.TESTFN
        self.file_path = FakePath(support.TESTFN)
        self.addCleanup(support.unlink, self.file_name)
        with open(self.file_name, 'xb', 0) as file:
            file.write(b"test_posixpath.PathLikeTests")

    def assertPathEqual(self, func):
        self.assertEqual(func(self.file_path), func(self.file_name))

    def test_path_normcase(self):
        self.assertPathEqual(self.path.normcase)

    def test_path_isabs(self):
        self.assertPathEqual(self.path.isabs)

    def test_path_join(self):
        self.assertEqual(self.path.join('a', FakePath('b'), 'c'),
                         self.path.join('a', 'b', 'c'))

    def test_path_split(self):
        self.assertPathEqual(self.path.split)

    def test_path_splitext(self):
        self.assertPathEqual(self.path.splitext)

    def test_path_splitdrive(self):
        self.assertPathEqual(self.path.splitdrive)

    def test_path_basename(self):
        self.assertPathEqual(self.path.basename)

    def test_path_dirname(self):
        self.assertPathEqual(self.path.dirname)

    def test_path_islink(self):
        self.assertPathEqual(self.path.islink)

    def test_path_lexists(self):
        self.assertPathEqual(self.path.lexists)

    def test_path_ismount(self):
        self.assertPathEqual(self.path.ismount)

    def test_path_expanduser(self):
        self.assertPathEqual(self.path.expanduser)

    def test_path_expandvars(self):
        self.assertPathEqual(self.path.expandvars)

    def test_path_normpath(self):
        self.assertPathEqual(self.path.normpath)

    def test_path_abspath(self):
        self.assertPathEqual(self.path.abspath)

    def test_path_realpath(self):
        self.assertPathEqual(self.path.realpath)

    def test_path_relpath(self):
        self.assertPathEqual(self.path.relpath)

    def test_path_commonpath(self):
        common_path = self.path.commonpath([self.file_path, self.file_name])
        self.assertEqual(common_path, self.file_name)


if __name__=="__main__":
    unittest.main()
