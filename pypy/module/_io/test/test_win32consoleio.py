import os
import pytest

if os.name != 'nt':
    pytest.skip('Windows only tests')

from rpython.tool.udir import udir
from pypy.interpreter.gateway import interp2app
from pypy.module._io import interp_win32consoleio
from pypy.conftest import option
from rpython.rtyper.lltypesystem import rffi

class AppTestWinConsoleIO:
    spaceconfig = dict(usemodules=['_io', '_cffi_backend'])

    def setup_class(cls):
        tmpfile = udir.join('tmpfile')
        tmpfile.write("a\nb\nc", mode='wb')
        cls.w_tmpfile = cls.space.wrap(str(tmpfile))   
        cls.w_posix = cls.space.appexec([], """():
            import %s as m;
            return m""" % os.name)
        cls.w_conout_path = cls.space.wrap(str(udir.join('CONOUT$')))
        if option.runappdirect:
            def write_input(module, console, s):
                from pypy.module._io.test._testconsole import write_input as tst_write_input
                return tst_write_input(console, s)
            cls.w_write_input = write_input
        else:
            def cls_write_input(w_console, w_s):
                from lib_pypy._testconsole import write_input as tst_write_input
                space = cls.space
                handle = rffi.cast(rffi.INT_real, w_console.handle)
                s = space.utf8_w(w_s).decode('utf-8')
                return space.wrap(tst_write_input(handle, s))
            cls.w_write_input = cls.space.wrap(interp2app(cls_write_input))

    def test_open_fd(self):
        import _io
        os = self.posix
        fd = os.open(self.tmpfile, os.O_RDONLY, 0o666)
        #w_fd = self.tmpfile.fileno()
        # Windows 10: "Cannot open non-console file"
        # Earlier: "Cannot open console output buffer for reading"
        raises(ValueError, _io._WindowsConsoleIO, fd)

        raises(ValueError, _io._WindowsConsoleIO, -1)

        try:
            f = _io._WindowsConsoleIO(0)
        except ValueError:
            # cannot open console because it's not a real console
            pass
        else:
            assert f.readable()
            assert not f.writable()
            assert 0 == f.fileno()
            f.close()   # multiple close should not crash
            f.close()

        try:
            f = _io._WindowsConsoleIO(1, 'w')
        except ValueError:
            # cannot open console because it's not a real console
            pass
        else:
            assert not f.readable()
            assert f.writable()
            assert 1 == f.fileno()
            f.close()
            f.close()

        try:
            f = _io._WindowsConsoleIO(2, 'w')
        except ValueError:
            # cannot open console because it's not a real console
            pass
        else:
            assert not f.readable()
            assert f.writable()
            assert 2 == f.fileno()
            f.close()
            f.close()

    def test_constructor(self):
        import _io

        f = _io._WindowsConsoleIO("CON")
        assert f.readable()
        assert not f.writable()
        assert f.fileno() != None
        f.close()   # multiple close should not crash
        f.close()

        f = _io._WindowsConsoleIO('CONIN$')
        assert f.readable()
        assert not f.writable()
        assert f.fileno() != None
        f.close()
        f.close()

        f = _io._WindowsConsoleIO('CONOUT$', 'w')
        assert not f.readable()
        assert f.writable()
        assert f.fileno() != None
        f.close()
        f.close()

        f = open('C:\\con', 'rb', buffering=0)
        assert isinstance(f,_io._WindowsConsoleIO)
        f.close()

    def test_conin_conout_names(self):
        import _io
        f = open(r'\\.\conin$', 'rb', buffering=0)
        assert type(f) is _io._WindowsConsoleIO
        f.close()

        f = open('//?/conout$', 'wb', buffering=0)
        assert isinstance(f , _io._WindowsConsoleIO)
        f.close()
        
    def test_conout_path(self):
        import _io

        with open(self.conout_path, 'wb', buffering=0) as f:
            assert type(f) is _io._WindowsConsoleIO
            
    def test_write_empty_data(self):
        import _io
        with _io._WindowsConsoleIO('CONOUT$', 'w') as f:
            assert f.write(b'') == 0
            
    def test_write_data(self):
        import _io
        with _io._WindowsConsoleIO('CONOUT$', 'w') as f:
            assert f.write(b'abdefg') == 6
            assert f.write(b'\r\r') == 2
            
    @pytest.mark.skip('test hangs')
    def test_partial_reads(self):
        import _io
        # Test that reading less than 1 full character works when stdin
        # contains multibyte UTF-8 sequences. Converted to utf-16-le.
        source = '\u03fc\u045e\u0422\u03bb\u0424\u0419\u005c\u0072\u005c\u006e'
        # converted to utf-8
        expected = '\xcf\xbc\xd1\x9e\xd0\xa2\xce\xbb\xd0\xa4\xd0\x99\x5c\x72\x5c\x6e'
        for read_count in range(1, 16):
            with open('CONIN$', 'rb', buffering=0) as stdin:
                self.write_input(stdin, source)

                actual = b''
                while not actual.endswith(b'\n'):
                    b = stdin.read(read_count)
                    print('got', b)
                    actual += b

                self.assertEqual(actual, expected, 'stdin.read({})'.format(read_count))

        assert actual == source


            
class TestGetConsoleType:
    def test_conout(self, space):
        w_file = space.newtext('CONOUT$')
        consoletype = interp_win32consoleio._pyio_get_console_type(space, w_file)
        assert consoletype == 'w'

    def test_conin(self, space):
        w_file = space.newtext('CONIN$')
        consoletype = interp_win32consoleio._pyio_get_console_type(space, w_file)
        assert consoletype == 'r'
        
    def test_con(self, space):
        w_file = space.newtext('CON')
        consoletype = interp_win32consoleio._pyio_get_console_type(space, w_file)
        assert consoletype == 'x'

    def test_conin2(self, space):
        w_file = space.newtext('\\\\.\\conin$')
        consoletype = interp_win32consoleio._pyio_get_console_type(space, w_file)
        assert consoletype == 'r'        
        
    def test_con2(self, space):
        w_file = space.newtext('\\\\?\\con')
        consoletype = interp_win32consoleio._pyio_get_console_type(space, w_file)
        assert consoletype == 'x'
