import sys, os
import py
from rpython.rlib import rposix_scandir

if sys.platform == 'win32':
    basedir = os.environ.get('LOCALAPPDATA', r'C:\users')
    funcs = [rposix_scandir.get_name_bytes, rposix_scandir.get_name_unicode]
else:
    basedir = '/'
    funcs = [rposix_scandir.get_name_bytes,]

class TestScanDir(object):

    def test_name_bytes(self):
        for func in funcs:
            scan = rposix_scandir.opendir(basedir, len(basedir))
            found = []
            while True:
                p = rposix_scandir.nextentry(scan)
                if not p:
                    break
                found.append(func(p))
            rposix_scandir.closedir(scan)
            found.remove('.')
            found.remove('..')
        # win32 listdir must use unicode
        assert sorted(found) == sorted(os.listdir(basedir))
