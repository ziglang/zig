import py

from rpython.rlib.rzipfile import RZipFile
from rpython.tool.udir import udir
from zipfile import ZIP_STORED, ZIP_DEFLATED, ZipInfo, ZipFile
from rpython.rtyper.test.tool import BaseRtypingTest
from rpython.rlib import clibffi # for side effect of testing lib_c_name on win32
import os
import time

try:
    from rpython.rlib import rzlib
except CompilationError as e:
    py.test.skip("zlib not installed: %s " % (e, ))

class BaseTestRZipFile(BaseRtypingTest):

    def setup_class(cls):
        tmpdir = udir.ensure('zipimport_%s' % cls.__name__, dir=1)
        zipname = str(tmpdir.join("somezip.zip"))
        cls.zipname = zipname
        zipfile = ZipFile(zipname, "w", compression=cls.compression)
        cls.year = time.localtime(time.time())[0]
        zipfile.writestr("one", "stuff\n")
        zipfile.writestr("dir" + os.path.sep + "two", "otherstuff")
        # Value selected to produce a CRC32 which is negative if
        # interpreted as a signed 32 bit integer.  This exercises the
        # masking behavior necessary on 64 bit platforms.
        zipfile.writestr("three", "hello, world")
        zipfile.close()

    def test_rzipfile(self):
        zipname = self.zipname
        year = self.year
        compression = self.compression
        def one():
            rzip = RZipFile(zipname, "r", compression)
            info = rzip.getinfo('one')
            return (info.date_time[0] == year and
                    rzip.read('one') == 'stuff\n' and
                    rzip.read('three') == 'hello, world')

        assert one()
        assert self.interpret(one, [])

class TestRZipFile(BaseTestRZipFile):
    compression = ZIP_STORED

class TestRZipFileCompressed(BaseTestRZipFile):
    compression = ZIP_DEFLATED
