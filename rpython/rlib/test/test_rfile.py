import os, sys, py, errno, gc
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.tool.udir import udir
from rpython.rlib import rfile


class TestFile(BaseRtypingTest):
    def setup_class(cls):
        cls.tmpdir = udir.join('test_rfile')
        cls.tmpdir.ensure(dir=True)

    def test_open(self):
        fname = str(self.tmpdir.join('file_1'))

        def f():
            f = open(fname, "w")
            f.write("dupa")
            f.close()
            try:
                f.write("dupb")
            except ValueError:
                pass
            else:
                assert False
            f.close()

        f()
        with open(fname, "r") as fid:
            assert fid.read() == "dupa"
        os.unlink(fname)
        self.interpret(f, [])
        with open(fname, "r") as fid:
            assert fid.read() == "dupa"

    def test_open_errors(self):
        def f(run):
            try:
                open('zzz', 'badmode')
            except ValueError:
                pass
            else:
                assert False

            try:
                open('zzz')
            except IOError as e:
                assert e.errno == errno.ENOENT
            else:
                assert False

            try:
                open('.')
            except IOError as e:
                if os.name == 'posix':
                    assert e.errno == errno.EISDIR
                else:
                    assert e.errno == errno.EACCES
            else:
                assert False

            try:
                rfile.create_fdopen_rfile(42, "badmode")
            except  ValueError:
                pass
            else:
                assert False

            try:
                fd = os.open('.', os.O_RDONLY, 0777)
            except OSError as e:
                assert os.name == 'nt' and e.errno == errno.EACCES
            else:
                assert os.name != 'nt'
                if run:
                    try:
                        os.fdopen(fd)
                    except IOError as e:
                        assert e.errno == errno.EISDIR
                    else:
                        assert False
                os.close(fd)

            try:
                os.fdopen(12345)
            except OSError as e:
                assert e.errno == errno.EBADF
            else:
                assert False

        f(sys.version_info >= (2, 7, 9))
        self.interpret(f, [True])

    @py.test.mark.skipif("sys.platform == 'win32'")
    # http://msdn.microsoft.com/en-us/library/86cebhfs.aspx
    def test_open_buffering_line(self):
        fname = str(self.tmpdir.join('file_1a'))

        def f():
            f = open(fname, 'w', 1)
            f.write('dupa\ndupb')
            f2 = open(fname, 'r')
            assert f2.read() == 'dupa\n'
            f.close()
            assert f2.read() == 'dupb'
            f2.close()

        f()
        os.unlink(fname)
        self.interpret(f, [])

    @py.test.mark.skipif("sys.platform == 'win32'")
    # http://msdn.microsoft.com/en-us/library/86cebhfs.aspx
    def test_fdopen_buffering_line(self):
        fname = str(self.tmpdir.join('file_1a'))

        def f():
            g = open(fname, 'w')
            f = os.fdopen(os.dup(g.fileno()), 'w', 1)
            g.close()
            f.write('dupa\ndupb')
            f2 = open(fname, 'r')
            assert f2.read() == 'dupa\n'
            f.close()
            assert f2.read() == 'dupb'
            f2.close()

        f()
        os.unlink(fname)
        self.interpret(f, [])

    def test_open_buffering_full(self):
        fname = str(self.tmpdir.join('file_1b'))

        def f():
            f = open(fname, 'w', 128)
            f.write('dupa\ndupb')
            f2 = open(fname, 'r')
            assert f2.read() == ''
            f.write('z' * 120)
            assert f2.read() != ''
            f.close()
            assert f2.read() != ''
            f2.close()

        f()
        os.unlink(fname)
        self.interpret(f, [])

    def test_fdopen_buffering_full(self):
        fname = str(self.tmpdir.join('file_1b'))

        def f():
            g = open(fname, 'w')
            f = os.fdopen(os.dup(g.fileno()), 'w', 128)
            g.close()
            f.write('dupa\ndupb')
            f2 = open(fname, 'r')
            assert f2.read() == ''
            f.write('z' * 120)
            assert f2.read() != ''
            f.close()
            assert f2.read() != ''
            f2.close()

        f()
        os.unlink(fname)
        self.interpret(f, [])

    def test_read_write(self):
        fname = str(self.tmpdir.join('file_2'))

        def f():
            f = open(fname, "w")
            try:
                f.read()
            except IOError as e:
                pass
            else:
                assert False
            try:
                f.readline()
            except IOError as e:
                pass
            else:
                assert False
            f.write("dupa\x00dupb")
            f.close()
            for mode in ['r', 'U']:
                f2 = open(fname, mode)
                try:
                    f2.write('z')
                except IOError as e:
                    pass
                else:
                    assert False
                dupa = f2.read(0)
                assert dupa == ""
                dupa = f2.read()
                assert dupa == "dupa\x00dupb"
                f2.seek(0)
                dupa = f2.readline(0)
                assert dupa == ""
                dupa = f2.readline(2)
                assert dupa == "du"
                dupa = f2.readline(100)
                assert dupa == "pa\x00dupb"
                f2.seek(0)
                dupa = f2.readline()
                assert dupa == "dupa\x00dupb"
                f2.close()

        f()
        os.unlink(fname)
        self.interpret(f, [])

    def test_read_sequentially(self):
        fname = self.tmpdir.join('file_3')
        fname.write("dupa")
        fname = str(fname)

        def f():
            f = open(fname)
            a = f.read(1)
            b = f.read(1)
            c = f.read(1)
            d = f.read(1)
            e = f.read()
            f.close()
            assert a == "d"
            assert b == "u"
            assert c == "p"
            assert d == "a"
            assert e == ""

        f()
        self.interpret(f, [])

    def test_read_universal(self):
        fname = str(self.tmpdir.join('read_univ'))
        with open(fname, 'wb') as f:
            f.write("dupa\ndupb\r\ndupc\rdupd")

        def f():
            f = open(fname, 'U')
            assert f.read() == "dupa\ndupb\ndupc\ndupd"
            assert f.read() == ""
            f.seek(0)
            assert f.read(10) == "dupa\ndupb\n"
            assert f.read(42) == "dupc\ndupd"
            assert f.read(1) == ""
            f.seek(0)
            assert f.readline() == "dupa\n"
            assert f.tell() == 5
            assert f.readline() == "dupb\n"
            assert f.tell() == 11
            assert f.readline() == "dupc\n"
            assert f.tell() == 16
            assert f.readline() == "dupd"
            assert f.tell() == 20
            assert f.readline() == ""
            f.seek(0)
            assert f.readline() == "dupa\n"
            assert f.readline() == "dupb\n"
            f.seek(4)
            assert f.read(1) == "\n"
            f.close()

        f()
        self.interpret(f, [])

    def test_seek(self):
        fname = str(self.tmpdir.join('file_4'))

        def f():
            f = open(fname, "w+")
            f.write("abcdef")
            f.seek(0)
            assert f.read() == "abcdef"
            f.seek(1)
            assert f.read() == "bcdef"
            f.seek(2)
            f.seek(-2, 2)
            assert f.read() == "ef"
            f.seek(2)
            f.seek(-1, 1)
            assert f.read() == "bcdef"
            #---is the following behavior interesting in RPython?
            #---I claim not, and it doesn't work on Windows
            #try:
            #    f.seek(0, 42)
            #except IOError as e:
            #    assert e.errno == errno.EINVAL
            #else:
            #    assert False
            f.close()

        f()
        os.unlink(fname)
        self.interpret(f, [])

    def test_tempfile(self):
        def f():
            f = os.tmpfile()
            f.write("xxx")
            f.seek(0)
            assert f.read() == "xxx"
            f.close()

        f()
        self.interpret(f, [])

    def test_fdopen(self):
        fname = str(self.tmpdir.join('file_4a'))

        def f():
            f = open(fname, "w")
            new_fno = os.dup(f.fileno())
            f2 = os.fdopen(new_fno, "w")
            f.close()
            try:
                f2.read()
            except IOError as e:
                pass
            else:
                assert False
            f2.write("xxx")
            f2.close()

        f()
        with open(fname) as fid:
            assert fid.read() == "xxx"
        os.unlink(fname)
        self.interpret(f, [])
        with open(fname) as fid:
            assert fid.read() == "xxx"

    def test_fileno(self):
        fname = str(self.tmpdir.join('file_5'))

        def f():
            f = open(fname, "w")
            assert not f.isatty()
            try:
                return f.fileno()
            finally:
                f.close()

        res = f()
        assert res > 2
        os.unlink(fname)
        res = self.interpret(f, [])
        assert res > 2

    def test_tell(self):
        fname = str(self.tmpdir.join('file_tell'))

        def f():
            f = open(fname, "w")
            f.write("xyz")
            try:
                return f.tell()
            finally:
                f.close()

        res = f()
        assert res == 3
        os.unlink(fname)
        res = self.interpret(f, [])
        assert res == 3

    def test_flush(self):
        fname = str(self.tmpdir.join('file_flush'))

        def f():
            f = open(fname, "w")
            f.write("xyz")
            f.flush()
            f2 = open(fname)
            assert f2.read() == "xyz"
            f2.close()
            f.close()

        f()
        os.unlink(fname)
        self.interpret(f, [])

    def test_truncate(self):
        fname = str(self.tmpdir.join('file_trunc'))

        def f():
            f = open(fname, "w+b")
            f.write("hello world")
            f.seek(7)
            f.truncate()
            f.seek(0)
            data = f.read()
            assert data == "hello w"
            f.close()
            f = open(fname)
            try:
                f.truncate()
            except IOError as e:
                pass
            else:
                assert False
            f.close()

        f()
        os.unlink(fname)
        self.interpret(f, [])

    def test_with_statement(self):
        fname = str(self.tmpdir.join('file_6'))

        def f():
            with open(fname, "w") as f:
                f.write("dupa")
                assert not f.closed

            try:
                assert f.closed
                f.write("dupb")
            except ValueError:
                pass
            else:
                assert False

        f()
        with open(fname) as fid:
            assert fid.read() == "dupa"
        os.unlink(fname)
        self.interpret(f, [])
        with open(fname) as fid:
            assert fid.read() == "dupa"


class TestDirect:
    def setup_class(cls):
        cls.tmpdir = udir.join('test_rfile_direct')
        cls.tmpdir.ensure(dir=True)

    def test_stdio(self):
        i, o, e = rfile.create_stdio()
        o.write("test\n")
        i.close()
        o.close()
        e.close()

    def test_auto_close(self):
        fname = str(self.tmpdir.join('file_auto_close'))
        f = rfile.create_file(fname, 'w')
        f.write('a')    # remains in buffers
        assert os.path.getsize(fname) == 0
        del f
        for i in range(5):
            if os.path.getsize(fname) != 0:
                break
            gc.collect()
        assert os.path.getsize(fname) == 1

    def test_read_a_lot(self):
        fname = str(self.tmpdir.join('file_read_a_lot'))
        with open(fname, 'w') as f:
            f.write('dupa' * 999)
        f = rfile.create_file(fname, 'r')
        s = f.read()
        assert s == 'dupa' * 999
        f.close()

    def test_readline(self):
        fname = str(self.tmpdir.join('file_readline'))
        j = 0
        expected = []
        with open(fname, 'w') as f:
            for i in range(250):
                s = ''.join([chr(32+(k&63)) for k in range(j, j + i)])
                j += 1
                print >> f, s
        with open(fname) as fid:
            expected = fid.readlines()
        expected += ['', '']
        assert len(expected) == 252

        f = rfile.create_file(fname, 'r')
        for j in range(252):
            got = f.readline()
            assert got == expected[j]
        f.close()

    def test_readline_without_eol_at_the_end(self):
        fname = str(self.tmpdir.join('file_readline_without_eol_at_the_end'))
        for n in [1, 10, 97, 98, 99, 100, 101, 102, 103, 150,
                  196, 197, 198, 199, 200, 201, 202, 203, 204, 250]:
            s = ''.join([chr(32+(k&63)) for k in range(n)])
            with open(fname, 'wb') as f:
                f.write(s)

            f = rfile.create_file(fname, 'r')
            got = f.readline()
            assert got == s
            got = f.readline()
            assert got == ''
            f.close()


class TestPopen(object):
    def setup_class(cls):
        if sys.platform == 'win32':
            py.test.skip("not for win32")

    def test_popen(self):
        f = rfile.create_popen_file("python -c 'print(42)'", "r")
        s = f.read()
        f.close()
        assert s == '42\n'

    def test_pclose(self):
        retval = 32
        printval = 42
        cmd = "python -c 'import sys; print(%s); sys.exit(%s)'" % (
            printval, retval)
        f = rfile.create_popen_file(cmd, "r")
        s = f.read()
        r = f.close()
        assert s == "%s\n" % printval
        assert os.WEXITSTATUS(r) == retval


class TestPopenR(BaseRtypingTest):
    def setup_class(cls):
        if sys.platform == 'win32':
            py.test.skip("not for win32")

    def test_popen(self):
        printval = 42
        cmd = "python -c 'print(%s)'" % printval
        def f():
            f = rfile.create_popen_file(cmd, "r")
            s = f.read()
            f.close()
            assert s == "%s\n" % printval
        self.interpret(f, [])

    def test_pclose(self):
        printval = 42
        retval = 32
        cmd = "python -c 'import sys; print(%s); sys.exit(%s)'" % (
            printval, retval)
        def f():
            f = rfile.create_popen_file(cmd, "r")
            s = f.read()
            assert s == "%s\n" % printval
            return f.close()
        r = self.interpret(f, [])
        assert os.WEXITSTATUS(r) == retval
