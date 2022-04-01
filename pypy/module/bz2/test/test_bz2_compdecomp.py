import os

if os.name == "nt":
    from pytest import skip
    skip("bz2 module is not available on Windows")

import py
import glob
import bz2

from pypy.module.bz2.test.support import CheckAllocation
from pypy.module.bz2 import interp_bz2
from pypy.interpreter import gateway

HUGE_OK = False

def setup_module(mod):
    DATA = 'BZh91AY&SY.\xc8N\x18\x00\x01>_\x80\x00\x10@\x02\xff\xf0\x01\x07n\x00?\xe7\xff\xe00\x01\x99\xaa\x00\xc0\x03F\x86\x8c#&\x83F\x9a\x03\x06\xa6\xd0\xa6\x93M\x0fQ\xa7\xa8\x06\x804hh\x12$\x11\xa4i4\xf14S\xd2<Q\xb5\x0fH\xd3\xd4\xdd\xd5\x87\xbb\xf8\x94\r\x8f\xafI\x12\xe1\xc9\xf8/E\x00pu\x89\x12]\xc9\xbbDL\nQ\x0e\t1\x12\xdf\xa0\xc0\x97\xac2O9\x89\x13\x94\x0e\x1c7\x0ed\x95I\x0c\xaaJ\xa4\x18L\x10\x05#\x9c\xaf\xba\xbc/\x97\x8a#C\xc8\xe1\x8cW\xf9\xe2\xd0\xd6M\xa7\x8bXa<e\x84t\xcbL\xb3\xa7\xd9\xcd\xd1\xcb\x84.\xaf\xb3\xab\xab\xad`n}\xa0lh\tE,\x8eZ\x15\x17VH>\x88\xe5\xcd9gd6\x0b\n\xe9\x9b\xd5\x8a\x99\xf7\x08.K\x8ev\xfb\xf7xw\xbb\xdf\xa1\x92\xf1\xdd|/";\xa2\xba\x9f\xd5\xb1#A\xb6\xf6\xb3o\xc9\xc5y\\\xebO\xe7\x85\x9a\xbc\xb6f8\x952\xd5\xd7"%\x89>V,\xf7\xa6z\xe2\x9f\xa3\xdf\x11\x11"\xd6E)I\xa9\x13^\xca\xf3r\xd0\x03U\x922\xf26\xec\xb6\xed\x8b\xc3U\x13\x9d\xc5\x170\xa4\xfa^\x92\xacDF\x8a\x97\xd6\x19\xfe\xdd\xb8\xbd\x1a\x9a\x19\xa3\x80ankR\x8b\xe5\xd83]\xa9\xc6\x08\x82f\xf6\xb9"6l$\xb8j@\xc0\x8a\xb0l1..\xbak\x83ls\x15\xbc\xf4\xc1\x13\xbe\xf8E\xb8\x9d\r\xa8\x9dk\x84\xd3n\xfa\xacQ\x07\xb1%y\xaav\xb4\x08\xe0z\x1b\x16\xf5\x04\xe9\xcc\xb9\x08z\x1en7.G\xfc]\xc9\x14\xe1B@\xbb!8`'

    def decompress(cls, data):
        import subprocess
        import bz2
        pop = subprocess.Popen("bunzip2", stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        pop.stdin.write(data)
        stdout, stderr = pop.communicate()
        res = stdout
        if pop.wait() != 0:
            res = bz2.decompress(data)
        return res

    mod.TEXT = 'root:x:0:0:root:/root:/bin/bash\nbin:x:1:1:bin:/bin:\ndaemon:x:2:2:daemon:/sbin:\nadm:x:3:4:adm:/var/adm:\nlp:x:4:7:lp:/var/spool/lpd:\nsync:x:5:0:sync:/sbin:/bin/sync\nshutdown:x:6:0:shutdown:/sbin:/sbin/shutdown\nhalt:x:7:0:halt:/sbin:/sbin/halt\nmail:x:8:12:mail:/var/spool/mail:\nnews:x:9:13:news:/var/spool/news:\nuucp:x:10:14:uucp:/var/spool/uucp:\noperator:x:11:0:operator:/root:\ngames:x:12:100:games:/usr/games:\ngopher:x:13:30:gopher:/usr/lib/gopher-data:\nftp:x:14:50:FTP User:/var/ftp:/bin/bash\nnobody:x:65534:65534:Nobody:/home:\npostfix:x:100:101:postfix:/var/spool/postfix:\nniemeyer:x:500:500::/home/niemeyer:/bin/bash\npostgres:x:101:102:PostgreSQL Server:/var/lib/pgsql:/bin/bash\nmysql:x:102:103:MySQL server:/var/lib/mysql:/bin/bash\nwww:x:103:104::/var/www:/bin/false\n'
    mod.DATA = DATA
    mod.BUGGY_DATA = py.path.local(__file__).dirpath().join('data.bz2').read()
    mod.decompress = decompress
    #
    # For tests, patch the value of SMALLCHUNK
    mod.OLD_SMALLCHUNK = interp_bz2.INITIAL_BUFFER_SIZE
    interp_bz2.INITIAL_BUFFER_SIZE = 32

def teardown_module(mod):
    interp_bz2.INITIAL_BUFFER_SIZE = mod.OLD_SMALLCHUNK

class AppTestBZ2Compressor(CheckAllocation):
    spaceconfig = dict(usemodules=('bz2', 'time', 'struct'))

    def setup_class(cls):
        cls.w_TEXT = cls.space.newbytes(TEXT)
        if cls.runappdirect:
            cls.w_decompress = decompress
        else:
            @gateway.unwrap_spec(data='bytes')
            def decompress_w(space, data):
                return space.newbytes(decompress(cls, data))
            cls.w_decompress = cls.space.wrap(gateway.interp2app(decompress_w))
        cls.w_HUGE_OK = cls.space.wrap(HUGE_OK)

        cls.space.appexec([], """(): import warnings""")  # Work around a recursion limit

    def test_creation(self):
        from _bz2 import BZ2Compressor

        raises(TypeError, BZ2Compressor, "foo")
        raises(ValueError, BZ2Compressor, 10)

        BZ2Compressor(1)
        BZ2Compressor(9)

    def test_compress(self):
        from _bz2 import BZ2Compressor

        bz2c = BZ2Compressor()
        raises(TypeError, bz2c.compress)
        data = bz2c.compress(self.TEXT)
        data += bz2c.flush()
        assert self.decompress(data) == self.TEXT

    def test_compress_huge_data(self):
        if not self.HUGE_OK:
            skip("skipping test requiring lots of memory")
        from _bz2 import BZ2Compressor

        HUGE_DATA = self.TEXT * 10000
        bz2c = BZ2Compressor()
        raises(TypeError, bz2c.compress)
        data = bz2c.compress(HUGE_DATA)
        data += bz2c.flush()
        assert self.decompress(data) == HUGE_DATA

    def test_compress_chunks_10(self):
        from _bz2 import BZ2Compressor

        bz2c = BZ2Compressor()
        n = 0
        data = b""
        while True:
            temp = self.TEXT[n * 10:(n + 1) * 10]
            if not temp:
                break
            data += bz2c.compress(temp)
            n += 1
        data += bz2c.flush()
        assert self.decompress(data) == self.TEXT

    def test_buffer(self):
        from _bz2 import BZ2Compressor
        bz2c = BZ2Compressor()
        data = bz2c.compress(memoryview(self.TEXT))
        data += bz2c.flush()
        assert self.decompress(data) == self.TEXT

    def test_compressor_pickle_error(self):
        from _bz2 import BZ2Compressor
        import pickle

        exc = raises(TypeError, pickle.dumps, BZ2Compressor())
        assert exc.value.args[0] == "cannot serialize '_bz2.BZ2Compressor' object"


class AppTestBZ2Decompressor(CheckAllocation):
    spaceconfig = dict(usemodules=('bz2', 'time', 'struct'))

    def setup_class(cls):
        cls.w_TEXT = cls.space.newbytes(TEXT)
        cls.w_DATA = cls.space.newbytes(DATA)
        cls.w_BUGGY_DATA = cls.space.newbytes(BUGGY_DATA)

        cls.space.appexec([], """(): import warnings""")  # Work around a recursion limit

    def test_creation(self):
        from _bz2 import BZ2Decompressor

        raises(TypeError, BZ2Decompressor, "foo")

        BZ2Decompressor()

    def test_attribute(self):
        from _bz2 import BZ2Decompressor

        bz2d = BZ2Decompressor()
        assert bz2d.unused_data == b""

    def test_decompress(self):
        from _bz2 import BZ2Decompressor

        bz2d = BZ2Decompressor()
        raises(TypeError, bz2d.decompress)
        decompressed_data = bz2d.decompress(self.DATA)
        assert decompressed_data == self.TEXT

    def test_decompress_chunks_10(self):
        from _bz2 import BZ2Decompressor

        bz2d = BZ2Decompressor()
        decompressed_data = b""
        n = 0
        while True:
            temp = self.DATA[n * 10:(n + 1) * 10]
            if not temp:
                break
            decompressed_data += bz2d.decompress(temp)
            n += 1

        assert decompressed_data == self.TEXT

    def test_decompress_unused_data(self):
        # test with unused data. (data after EOF)
        from _bz2 import BZ2Decompressor

        bz2d = BZ2Decompressor()
        unused_data = b"this is unused data"
        decompressed_data = bz2d.decompress(self.DATA + unused_data)
        assert decompressed_data == self.TEXT
        assert bz2d.unused_data == unused_data

    def test_EOF_error(self):
        from _bz2 import BZ2Decompressor

        bz2d = BZ2Decompressor()
        bz2d.decompress(self.DATA)
        raises(EOFError, bz2d.decompress, b"foo")
        raises(EOFError, bz2d.decompress, b"")

    def test_buffer(self):
        from _bz2 import BZ2Decompressor
        bz2d = BZ2Decompressor()
        decompressed_data = bz2d.decompress(memoryview(self.DATA))
        assert decompressed_data == self.TEXT

    def test_subsequent_read(self):
        from _bz2 import BZ2Decompressor
        bz2d = BZ2Decompressor()
        decompressed_data = bz2d.decompress(self.BUGGY_DATA)
        assert decompressed_data == b''
        raises(IOError, bz2d.decompress, self.BUGGY_DATA)

    def test_decompressor_pickle_error(self):
        from _bz2 import BZ2Decompressor
        import pickle

        exc = raises(TypeError, pickle.dumps, BZ2Decompressor())
        assert exc.value.args[0] == "cannot serialize '_bz2.BZ2Decompressor' object"

    def test_decompress_max_length(self):
        from _bz2 import BZ2Decompressor

        bz2d = BZ2Decompressor()
        decomp= []

        length = len(self.DATA)
        decomp.append(bz2d.decompress(self.DATA, max_length=100))
        assert len(decomp[-1]) == 100

        while not bz2d.eof:
            decomp.append(bz2d.decompress(b"", max_length=200))
            assert len(decomp[-1]) <= 200

        assert b''.join(decomp) == self.TEXT

