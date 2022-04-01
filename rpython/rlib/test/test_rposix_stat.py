import os, sys
import py
from rpython.rlib import rposix_stat
from rpython.tool.udir import udir
from rpython.translator.c.test.test_genc import compile
from rpython.rtyper.lltypesystem import lltype


class TestPosixStatFunctions:
    @py.test.mark.skipif("sys.platform == 'win32'",
                         reason="win32 only has the portable fields")
    def test_has_all_fields(self):
        if sys.platform == "darwin":
            assert rposix_stat.STAT_FIELDS == rposix_stat.ALL_STAT_FIELDS
        # XXX this test is obscure!  it will fail if the exact set of
        # XXX stat fields found differs from the one we expect on Linux.
        # XXX Why?
        else:
            assert rposix_stat.STAT_FIELDS == (
                rposix_stat.ALL_STAT_FIELDS[:13] +
                rposix_stat.ALL_STAT_FIELDS[-3:])

    def test_stat(self):
        def check(f):
            # msec resolution, +- rounding error
            expected = int(os.stat(f).st_mtime * 1000)
            assert abs(int(rposix_stat.stat(f).st_mtime * 1000) - expected) < 2
            assert abs(int(rposix_stat.stat(unicode(f)).st_mtime * 1000) - expected) < 2

        if sys.platform == 'win32':
            check(os.environ['SYSTEMDRIVE'])   # C:
            check(os.environ['PROGRAMDATA'])  # C:\ProgramData
        else:
            check('/')
            check('/dev')
            # don't test with /tmp, because if another process is also
            # creating files in /tmp it is more likely that the mtime
            # we get during successive calls was actually changed
        check(sys.executable)

    def test_fstat(self):
        stat = rposix_stat.fstat(0)  # stdout
        assert stat.st_mode != 0

    def test_stat_large_number(self):
        fname = udir.join('test_stat_large_number.txt')
        fname.ensure()
        t1 = 5000000000.0
        try:
            os.utime(str(fname), (t1, t1))
        except OverflowError:
            py.test.skip("This platform doesn't support setting stat times "
                         "to large values")
        assert rposix_stat.stat(str(fname)).st_mtime == t1

    @py.test.mark.skipif(not hasattr(os, 'statvfs'),
                         reason='posix specific function')
    def test_statvfs(self):
        try:
            os.statvfs('.')
        except OSError as e:
            py.test.skip("the underlying os.statvfs() failed: %s" % e)
        rposix_stat.statvfs('.')

    @py.test.mark.skipif(not hasattr(os, 'fstatvfs'),
                         reason='posix specific function')
    def test_fstatvfs(self):
        try:
            os.fstatvfs(0)
        except OSError as e:
            py.test.skip("the underlying os.fstatvfs() failed: %s" % e)
        rposix_stat.fstatvfs(0)

    @py.test.mark.skipif(sys.platform != 'win32', reason='win32 test')
    def test_stat3_ino_dev(self):
        st = rposix_stat.stat('C:\\')
        assert st.st_dev == st.st_ino == 0
        st = rposix_stat.stat3('C:\\')
        assert st.st_dev != 0 and st.st_ino != 0
        assert st.st_file_attributes & 0x16  # FILE_ATTRIBUTE_DIRECTORY
        assert st.st_reparse_tag == 0
        st2 = rposix_stat.lstat3('C:\\')
        assert (st2.st_dev, st2.st_ino) == (st.st_dev, st.st_ino)

@py.test.mark.skipif("not hasattr(rposix_stat, 'fstatat')")
def test_fstatat(tmpdir):
    tmpdir.join('file').write('text')
    dirfd = os.open(str(tmpdir), os.O_RDONLY)
    try:
        result = rposix_stat.fstatat('file', dir_fd=dirfd, follow_symlinks=False)
    finally:
        os.close(dirfd)
    assert result.st_atime == tmpdir.join('file').atime()

def test_high_precision_stat_time():
    def f():
        st = os.stat('.')
        # should be supported on all platforms, but give a result whose
        # precision might be lower than full nanosecond
        highprec = rposix_stat.get_stat_ns_as_bigint(st, "ctime")
        return '%s;%s' % (st.st_ctime, highprec.str())
    fc = compile(f, [])
    as_string = fc()
    asfloat, highprec = as_string.split(';')
    asfloat = float(asfloat)
    highprec = int(highprec)
    st = os.stat('.')
    assert abs(asfloat - st.st_ctime) < 500e-9
    assert abs(highprec - int(st.st_ctime * 1e9)) < 500
    assert abs(rposix_stat.get_stat_ns_as_bigint(st, "ctime").tolong()
               - st.st_ctime * 1e9) < 3
    if rposix_stat.TIMESPEC is not None:
        with lltype.scoped_alloc(rposix_stat.STAT_STRUCT.TO) as stresult:
            rposix_stat.c_stat(".", stresult)
            if sys.platform == "darwin":
                assert 0 <= stresult.c_st_ctimespec.c_tv_nsec <= 999999999
                assert highprec == (int(stresult.c_st_ctimespec.c_tv_sec) * 1000000000
                                    + int(stresult.c_st_ctimespec.c_tv_nsec))
            else:
                assert 0 <= stresult.c_st_ctim.c_tv_nsec <= 999999999
                assert highprec == (int(stresult.c_st_ctim.c_tv_sec) * 1000000000
                                    + int(stresult.c_st_ctim.c_tv_nsec))
