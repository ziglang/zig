from __future__ import with_statement
import os

if os.name == "nt":
    from pytest import skip
    skip("bz2 module is not available on Windows")

from pypy.module.bz2.test.support import CheckAllocation
import random

import py

from pypy.interpreter import gateway
from pypy.module.bz2.test.support import CheckAllocation


def setup_module(mod):
    DATA = 'BZh91AY&SY.\xc8N\x18\x00\x01>_\x80\x00\x10@\x02\xff\xf0\x01\x07n\x00?\xe7\xff\xe00\x01\x99\xaa\x00\xc0\x03F\x86\x8c#&\x83F\x9a\x03\x06\xa6\xd0\xa6\x93M\x0fQ\xa7\xa8\x06\x804hh\x12$\x11\xa4i4\xf14S\xd2<Q\xb5\x0fH\xd3\xd4\xdd\xd5\x87\xbb\xf8\x94\r\x8f\xafI\x12\xe1\xc9\xf8/E\x00pu\x89\x12]\xc9\xbbDL\nQ\x0e\t1\x12\xdf\xa0\xc0\x97\xac2O9\x89\x13\x94\x0e\x1c7\x0ed\x95I\x0c\xaaJ\xa4\x18L\x10\x05#\x9c\xaf\xba\xbc/\x97\x8a#C\xc8\xe1\x8cW\xf9\xe2\xd0\xd6M\xa7\x8bXa<e\x84t\xcbL\xb3\xa7\xd9\xcd\xd1\xcb\x84.\xaf\xb3\xab\xab\xad`n}\xa0lh\tE,\x8eZ\x15\x17VH>\x88\xe5\xcd9gd6\x0b\n\xe9\x9b\xd5\x8a\x99\xf7\x08.K\x8ev\xfb\xf7xw\xbb\xdf\xa1\x92\xf1\xdd|/";\xa2\xba\x9f\xd5\xb1#A\xb6\xf6\xb3o\xc9\xc5y\\\xebO\xe7\x85\x9a\xbc\xb6f8\x952\xd5\xd7"%\x89>V,\xf7\xa6z\xe2\x9f\xa3\xdf\x11\x11"\xd6E)I\xa9\x13^\xca\xf3r\xd0\x03U\x922\xf26\xec\xb6\xed\x8b\xc3U\x13\x9d\xc5\x170\xa4\xfa^\x92\xacDF\x8a\x97\xd6\x19\xfe\xdd\xb8\xbd\x1a\x9a\x19\xa3\x80ankR\x8b\xe5\xd83]\xa9\xc6\x08\x82f\xf6\xb9"6l$\xb8j@\xc0\x8a\xb0l1..\xbak\x83ls\x15\xbc\xf4\xc1\x13\xbe\xf8E\xb8\x9d\r\xa8\x9dk\x84\xd3n\xfa\xacQ\x07\xb1%y\xaav\xb4\x08\xe0z\x1b\x16\xf5\x04\xe9\xcc\xb9\x08z\x1en7.G\xfc]\xc9\x14\xe1B@\xbb!8`'
    DATA_CRLF = 'BZh91AY&SY\xaez\xbbN\x00\x01H\xdf\x80\x00\x12@\x02\xff\xf0\x01\x07n\x00?\xe7\xff\xe0@\x01\xbc\xc6`\x86*\x8d=M\xa9\x9a\x86\xd0L@\x0fI\xa6!\xa1\x13\xc8\x88jdi\x8d@\x03@\x1a\x1a\x0c\x0c\x83 \x00\xc4h2\x19\x01\x82D\x84e\t\xe8\x99\x89\x19\x1ah\x00\r\x1a\x11\xaf\x9b\x0fG\xf5(\x1b\x1f?\t\x12\xcf\xb5\xfc\x95E\x00ps\x89\x12^\xa4\xdd\xa2&\x05(\x87\x04\x98\x89u\xe40%\xb6\x19\'\x8c\xc4\x89\xca\x07\x0e\x1b!\x91UIFU%C\x994!DI\xd2\xfa\xf0\xf1N8W\xde\x13A\xf5\x9cr%?\x9f3;I45A\xd1\x8bT\xb1<l\xba\xcb_\xc00xY\x17r\x17\x88\x08\x08@\xa0\ry@\x10\x04$)`\xf2\xce\x89z\xb0s\xec\x9b.iW\x9d\x81\xb5-+t\x9f\x1a\'\x97dB\xf5x\xb5\xbe.[.\xd7\x0e\x81\xe7\x08\x1cN`\x88\x10\xca\x87\xc3!"\x80\x92R\xa1/\xd1\xc0\xe6mf\xac\xbd\x99\xcca\xb3\x8780>\xa4\xc7\x8d\x1a\\"\xad\xa1\xabyBg\x15\xb9l\x88\x88\x91k"\x94\xa4\xd4\x89\xae*\xa6\x0b\x10\x0c\xd6\xd4m\xe86\xec\xb5j\x8a\x86j\';\xca.\x01I\xf2\xaaJ\xe8\x88\x8cU+t3\xfb\x0c\n\xa33\x13r2\r\x16\xe0\xb3(\xbf\x1d\x83r\xe7M\xf0D\x1365\xd8\x88\xd3\xa4\x92\xcb2\x06\x04\\\xc1\xb0\xea//\xbek&\xd8\xe6+t\xe5\xa1\x13\xada\x16\xder5"w]\xa2i\xb7[\x97R \xe2IT\xcd;Z\x04dk4\xad\x8a\t\xd3\x81z\x10\xf1:^`\xab\x1f\xc5\xdc\x91N\x14$+\x9e\xae\xd3\x80'

    def create_temp_file(cls, crlf=False):
        with open(cls.temppath, 'wb') as f:
            data = (cls.DATA, cls.DATA_CRLF)[crlf]
            f.write(data)

    def create_broken_temp_file(cls):
        with open(cls.temppath, 'wb') as f:
            data = cls.DATA[:100]
            f.write(data)

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
    mod.DATA_CRLF = DATA_CRLF
    mod.create_temp_file = create_temp_file
    mod.decompress = decompress
    mod.create_broken_temp_file = create_broken_temp_file
    s = 'abcdefghijklmnop'
    mod.RANDOM_DATA = ''.join([s[int(random.random() * len(s))] for i in range(30000)])


class AppTestBZ2File: #(CheckAllocation):
    # XXX: CheckAllocation fails on py3 (seems to false positive on
    # BZ2File's RLocks)
    spaceconfig = {
        'usemodules': ['bz2', 'binascii', 'time', 'struct', 'thread']
    }

    def setup_class(cls):
        cls.w_TEXT = cls.space.newbytes(TEXT)
        cls.DATA = DATA
        cls.w_DATA = cls.space.newbytes(DATA)
        cls.DATA_CRLF = DATA_CRLF
        cls.w_DATA_CRLF = cls.space.newbytes(DATA_CRLF)
        cls.temppath = str(py.test.ensuretemp("bz2").join("foo"))
        cls.w_temppath = cls.space.wrap(cls.temppath)
        if cls.runappdirect:
            cls.w_create_temp_file = create_temp_file
            cls.w_create_broken_temp_file = create_broken_temp_file
            cls.w_decompress = decompress
        else:
            @gateway.unwrap_spec(crlf=bool)
            def create_temp_file_w(crlf=False):
                create_temp_file(cls, crlf)
            cls.w_create_temp_file = cls.space.wrap(
                gateway.interp2app(create_temp_file_w))

            @gateway.unwrap_spec(data='bytes')
            def decompress_w(space, data):
                return space.newbytes(decompress(cls, data))
            cls.w_decompress = cls.space.wrap(gateway.interp2app(decompress_w))

            def create_broken_temp_file_w():
                create_broken_temp_file(cls)
            cls.w_create_broken_temp_file = cls.space.wrap(
                gateway.interp2app(create_broken_temp_file_w))
        cls.w_random_data = cls.space.newbytes(RANDOM_DATA)

        cls.space.appexec([], """(): import warnings""")  # Work around a recursion limit

    def test_attributes(self):
        from bz2 import BZ2File

        bz2f = BZ2File(self.temppath, mode="w")
        assert bz2f.closed == False
        bz2f.close()
        assert bz2f.closed == True

    def test_creation(self):
        from bz2 import BZ2File

        raises(ValueError, BZ2File, self.temppath, mode='w', compresslevel=10)
        raises(ValueError, BZ2File, self.temppath, mode='XYZ')
        # XXX the following is fine, currently:
        #raises(ValueError, BZ2File, self.temppath, mode='ww')

        BZ2File(self.temppath, mode='w', compresslevel=8)
        BZ2File(self.temppath, mode='wb')

        exc = raises(IOError, BZ2File, 'xxx', 'r')
        assert "'xxx'" in str(exc.value)

    def test_close(self):
        from bz2 import BZ2File

        # writeonly
        bz2f = BZ2File(self.temppath, mode='w')
        bz2f.close()
        bz2f.close()

        # readonly
        bz2f = BZ2File(self.temppath, mode='r')
        bz2f.close()
        bz2f.close()

    def test_tell(self):
        from bz2 import BZ2File

        bz2f = BZ2File(self.temppath, mode='w')
        bz2f.close()
        raises(ValueError, bz2f.tell)

        bz2f = BZ2File(self.temppath, mode='w')
        pos = bz2f.tell()
        bz2f.close()
        assert pos == 0

    def test_seek(self):
        from bz2 import BZ2File

        # hack to create a foo file
        open(self.temppath, "w").close()

        # cannot seek if close
        bz2f = BZ2File(self.temppath, mode='r')
        bz2f.close()
        raises(ValueError, bz2f.seek, 0)

        # cannot seek if 'w'
        bz2f = BZ2File(self.temppath, mode='w')
        raises(IOError, bz2f.seek, 0)
        bz2f.close()

        bz2f = BZ2File(self.temppath, mode='r')
        raises(TypeError, bz2f.seek)
        raises(TypeError, bz2f.seek, "foo")
        raises((TypeError, ValueError), bz2f.seek, 0, "foo")

        bz2f.seek(0)
        assert bz2f.tell() == 0
        bz2f.close()
        del bz2f   # delete from this frame, which is captured in the traceback

    def test_open_close_del(self):
        from bz2 import BZ2File
        self.create_temp_file()

        for i in range(10):
            f = BZ2File(self.temppath)
            f.close()
            del f

    def test_open_non_existent(self):
        from bz2 import BZ2File
        raises(IOError, BZ2File, "/non/existent/path")

    def test_seek_forward(self):
        from bz2 import BZ2File
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        bz2f.seek(150) # (150, 0)
        assert bz2f.read() == self.TEXT[150:]
        bz2f.close()

    def test_seek_backwards(self):
        #skip("currently does not work")
        from bz2 import BZ2File
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        bz2f.read(500)
        bz2f.seek(-150, 1)
        assert bz2f.read() == self.TEXT[500 - 150:]
        bz2f.close()

    def test_seek_backwards_from_end(self):
        #skip("currently does not work")
        from bz2 import BZ2File
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        bz2f.seek(-150, 2)
        assert bz2f.read() == self.TEXT[len(self.TEXT) - 150:]
        bz2f.close()

    def test_seek_post_end(self):
        from bz2 import BZ2File
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        bz2f.seek(150000)
        assert bz2f.tell() == len(self.TEXT)
        assert bz2f.read() == b""
        bz2f.close()

    def test_seek_post_end_twice(self):
        from bz2 import BZ2File
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        bz2f.seek(150000)
        bz2f.seek(150000)
        assert bz2f.tell() == len(self.TEXT)
        assert bz2f.read() == b""
        bz2f.close()

    def test_seek_pre_start(self):
        from bz2 import BZ2File
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        bz2f.seek(-150)
        assert bz2f.tell() == 0
        assert bz2f.read() == self.TEXT
        bz2f.close()

    def test_readline(self):
        from bz2 import BZ2File
        from io import BytesIO
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        raises(TypeError, bz2f.readline, None)
        sio = BytesIO(self.TEXT)
        for line in sio.readlines():
            line_read = bz2f.readline()
            assert line_read == line
        bz2f.close()

    def test_read(self):
        from bz2 import BZ2File
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        text_read = bz2f.read()
        assert text_read == self.TEXT
        bz2f.close()

    def test_silently_closes(self):
        from bz2 import BZ2File
        self.create_broken_temp_file()
        BZ2File(self.temppath)
        # check that no C-level malloc is left behind

    def test_read_broken_file(self):
        from bz2 import BZ2File
        self.create_broken_temp_file()
        bz2f = BZ2File(self.temppath)
        raises(EOFError, bz2f.read)
        bz2f.close()

    def test_subsequent_read_broken_file(self):
        from bz2 import BZ2File
        counter = 0
        self.create_broken_temp_file()
        bz2f = BZ2File(self.temppath)
        try:
            bz2f.read(10)
            counter += 1
            if counter > 100:
                raise Exception("should generate EOFError earlier")
        except EOFError:
            pass
        bz2f.close()

    def test_read_chunk9(self):
        from bz2 import BZ2File
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        text_read = b""
        while True:
            data = bz2f.read(9) # 9 doesn't divide evenly into data length
            if not data:
                break
            text_read += data
        assert text_read == self.TEXT
        bz2f.close()

    def test_read_100_bytes(self):
        from bz2 import BZ2File
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        assert bz2f.read(100) == self.TEXT[:100]
        bz2f.close()

    def test_readlines(self):
        from bz2 import BZ2File
        from io import BytesIO
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        raises(TypeError, bz2f.readlines, None)
        sio = BytesIO(self.TEXT)
        assert bz2f.readlines() == sio.readlines()
        bz2f.close()

    def test_iterator(self):
        from bz2 import BZ2File
        from io import BytesIO
        self.create_temp_file()

        bz2f = BZ2File(self.temppath)
        sio = BytesIO(self.TEXT)
        assert list(iter(bz2f)) == sio.readlines()
        bz2f.close()

    def test_write(self):
        from bz2 import BZ2File

        bz2f = BZ2File(self.temppath, 'w')
        raises(TypeError, bz2f.write)
        bz2f.write(self.TEXT)
        bz2f.close()

        f = open(self.temppath, "rb")
        assert self.decompress(f.read()) == self.TEXT
        f.close()

    def test_write_chunks_10(self):
        from bz2 import BZ2File

        bz2f = BZ2File(self.temppath, 'w')
        n = 0
        while True:
            data = self.TEXT[n * 10:(n + 1) * 10]
            if not data:
                break

            bz2f.write(data)
            n += 1
        bz2f.close()

        f = open(self.temppath, "rb")
        assert self.decompress(f.read()) == self.TEXT
        f.close()

    def test_writelines(self):
        from bz2 import BZ2File
        from io import BytesIO

        bz2f = BZ2File(self.temppath, 'w')
        raises(TypeError, bz2f.writelines)
        sio = BytesIO(self.TEXT)
        bz2f.writelines(sio.readlines())
        bz2f.close()
        f = open(self.temppath, "rb")
        assert self.decompress(f.read()) == self.TEXT
        f.close()

    def test_write_methods_on_readonly_file(self):
        from bz2 import BZ2File

        bz2f = BZ2File(self.temppath, 'r')
        raises(IOError, bz2f.write, b"abc")
        raises(IOError, bz2f.writelines, [b"abc"])
        bz2f.close()

    def test_write_bigger_file(self):
        from bz2 import BZ2File
        import random
        bz2f = BZ2File(self.temppath, 'w')
        bz2f.write(self.random_data)
        bz2f.close()
        bz2f = BZ2File(self.temppath, 'r')
        assert bz2f.read() == self.random_data
        del bz2f   # delete from this frame, which is captured in the traceback

    def test_context_manager(self):
        from bz2 import BZ2File

        with BZ2File(self.temppath, 'w') as f:
            assert not f.closed
            f.write(b"abc")
        assert f.closed
        with BZ2File(self.temppath, 'r') as f:
            data = f.read()
            assert data == b"abc"
        assert f.closed



# has_cmdline_bunzip2 = sys.platform not in ("win32", "os2emx", "riscos")
#
# if has_cmdline_bunzip2:
#     def decompress(self, data):
#         pop = popen2.Popen3("bunzip2", capturestderr=1)
#         pop.tochild.write(data)
#         pop.tochild.close()
#         ret = pop.fromchild.read()
#         pop.fromchild.close()
#         if pop.wait() != 0:
#             ret = bz2.decompress(data)
#         return ret
#
# else:
#     # popen2.Popen3 doesn't exist on Windows, and even if it did, bunzip2
#     # isn't available to run.
#     def decompress(self, data):
#         return bz2.decompress(data)
