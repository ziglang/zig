import os
import py

if os.name != 'posix':
    py.test.skip('crypt module only available on unix')

class AppTestCrypt: 
    spaceconfig = dict(usemodules=['crypt'])

    def test_crypt(self):
        import crypt 
        res = crypt.crypt("pass", "ab")
        assert isinstance(res, str)
        assert res 

