from rpython.tool.udir import udir

import os, sys, py

if sys.platform != 'win32':
    py.test.skip("winreg is a win32 module")

try:
    # To call SaveKey, the process must have Backup Privileges
    import win32api
    import win32security
    priv_flags = win32security.TOKEN_ADJUST_PRIVILEGES | win32security.TOKEN_QUERY
    hToken = win32security.OpenProcessToken (win32api.GetCurrentProcess (), priv_flags)
    privilege_id = win32security.LookupPrivilegeValue (None, "SeBackupPrivilege")
    ret = win32security.AdjustTokenPrivileges (hToken, 0, [(privilege_id, win32security.SE_PRIVILEGE_ENABLED)])
except:
    canSaveKey = False
else:
    canSaveKey = len(ret) > 0

class AppTestHKey:
    spaceconfig = dict(usemodules=('_winreg',))

    def test_repr(self):
        import winreg
        k = winreg.HKEYType(0x123)
        assert str(k) == "<PyHKEY:0x123>"

class AppTestFfi:
    spaceconfig = dict(usemodules=('_winreg',))

    def setup_class(cls):
        import _winreg as winreg
        from platform import machine
        space = cls.space
        cls.root_key = winreg.HKEY_CURRENT_USER
        cls.test_key_name = "SOFTWARE\\Pypy Test Key - Delete Me [%d]" % os.getpid()
        cls.w_root_key = space.wrap(cls.root_key)
        cls.w_test_key_name = space.wrap(cls.test_key_name)
        cls.w_canSaveKey = space.wrap(canSaveKey)
        cls.w_tmpfilename = space.wrap(str(udir.join('winreg-temp')))
        cls.w_runappdirect = space.wrap(cls.runappdirect)
        cls.w_win64_machine = space.wrap(machine() == "AMD64")

        test_data = [
            ("Int Value", 0xFEDCBA98, winreg.REG_DWORD),
            ("Str Value", b"A string Value", winreg.REG_SZ),
            ("Unicode Value", "A unicode Value", winreg.REG_SZ),
            ("Str Expand", "The path is %path%", winreg.REG_EXPAND_SZ),
            ("Multi Str", [b"Several", u"string", u"values"], winreg.REG_MULTI_SZ),
            ("Multi Str Empty", ["", "", ""], winreg.REG_MULTI_SZ),
            ("Raw None", None, winreg.REG_BINARY),
            # issue 3342, round-trip invalid UTF-16 strings
            (u"Invalid \uDC00", u"\uDC00", winreg.REG_SZ),
            (u"Invalid \uD800", u"\uD800", winreg.REG_SZ),
            ]
        cls.w_test_data = w_test_data = space.wrap(test_data)
        w_btest = space.newtuple([space.wrap("Raw data"),
                                  space.newbytes("binary\x00data"),
                                  space.wrap(winreg.REG_BINARY)])
        w_test_data.append(w_btest)

    def teardown_class(cls):
        import _winreg
        try:
            _winreg.DeleteKey(cls.root_key, cls.test_key_name)
        except WindowsError as e:
            pass

    def test_constants(self):
        from winreg import (
            HKEY_LOCAL_MACHINE, HKEY_CLASSES_ROOT, HKEY_CURRENT_CONFIG,
            HKEY_CURRENT_USER, HKEY_DYN_DATA, HKEY_LOCAL_MACHINE,
            HKEY_PERFORMANCE_DATA, HKEY_USERS)

    def test_simple_write(self):
        from winreg import SetValue, QueryValue, REG_SZ
        value = u"Some Default value"
        SetValue(self.root_key, self.test_key_name, REG_SZ, value)
        assert QueryValue(self.root_key, self.test_key_name) == value

    def test_CreateKey(self):
        from winreg import CreateKey, QueryInfoKey
        key = CreateKey(self.root_key, self.test_key_name)
        sub_key = CreateKey(key, u"sub_key")

        nkeys, nvalues, since_mod = QueryInfoKey(key)
        assert nkeys == 1

        nkeys, nvalues, since_mod = QueryInfoKey(sub_key)
        assert nkeys == 0

    def test_CreateKeyEx(self):
        from winreg import CreateKeyEx, QueryInfoKey
        from winreg import KEY_ALL_ACCESS, KEY_READ
        key = CreateKeyEx(self.root_key, self.test_key_name, 0, KEY_ALL_ACCESS)
        sub_key = CreateKeyEx(key, u"sub_key", 0, KEY_READ)

        nkeys, nvalues, since_mod = QueryInfoKey(key)
        assert nkeys == 1

        nkeys, nvalues, since_mod = QueryInfoKey(sub_key)
        assert nkeys == 0

    def test_close(self):
        from winreg import OpenKey, CloseKey, FlushKey, QueryInfoKey
        key = OpenKey(self.root_key, self.test_key_name)
        sub_key = OpenKey(key, u"sub_key")

        int_sub_key = int(sub_key)
        FlushKey(sub_key)
        CloseKey(sub_key)
        raises(EnvironmentError, QueryInfoKey, int_sub_key)

        int_key = int(key)
        key.Close()
        raises(EnvironmentError, QueryInfoKey, int_key)

        key = OpenKey(self.root_key, self.test_key_name)
        int_key = key.Detach()
        QueryInfoKey(int_key) # works
        key.Close()
        QueryInfoKey(int_key) # still works
        CloseKey(int_key)
        raises(EnvironmentError, QueryInfoKey, int_key) # now closed

    def test_with(self):
        from winreg import OpenKey
        with OpenKey(self.root_key, self.test_key_name) as key:
            with OpenKey(key, u"sub_key") as sub_key:
                assert key.handle != 0
                assert sub_key.handle != 0
        assert key.handle == 0
        assert sub_key.handle == 0

    def test_exception(self):
        from winreg import QueryInfoKey
        import errno
        try:
            QueryInfoKey(0)
        except EnvironmentError as e:
            assert e.winerror == 6
            assert e.errno == errno.EBADF
            # XXX translations...
            assert ("invalid" in e.strerror.lower() or
                    "non valide" in e.strerror.lower())
        else:
            assert 0, "Did not raise"

    def test_SetValueEx(self):
        # this test leaves open keys. If it fails, others will too
        from winreg import CreateKey, SetValueEx, REG_BINARY, REG_DWORD
        key = CreateKey(self.root_key, self.test_key_name)
        sub_key = CreateKey(key, u"sub_key")
        SetValueEx(sub_key, 'Int Value', 0, REG_DWORD, None)
        SetValueEx(sub_key, 'Int Value', 0, REG_DWORD, 45)
        for name, value, type in self.test_data:
            SetValueEx(sub_key, name, 0, type, value)
        # cannot wrap a memoryview in setup_class for test_data
        SetValueEx(sub_key, u'test_name', None,
                            REG_BINARY, memoryview(b'abc'))

    def test_readValues(self):
        # needs the keys from test_SetValueEx
        from winreg import OpenKey, EnumValue, QueryValueEx, EnumKey
        from winreg import REG_SZ, REG_EXPAND_SZ
        try:
            key = OpenKey(self.root_key, self.test_key_name)
        except FileNotFoundError:
            raise RuntimeError("run test_SetValueEx first")
        sub_key = OpenKey(key, "sub_key")
        index = 0
        while 1:
            try:
                data = EnumValue(sub_key, index)
            except EnvironmentError as e:
                break
            if data[0] != 'test_name':
                # cannot wrap a memoryview in setup_class for test_data
                assert data in self.test_data
            index = index + 1
        assert index == len(self.test_data) + 1

        for name, value, type in self.test_data:
            result = QueryValueEx(sub_key, name)
            assert result == (value, type)
            if type == REG_SZ or type == REG_EXPAND_SZ:
                assert not isinstance(result[0], bytes)

        assert EnumKey(key, 0) == "sub_key"
        raises(EnvironmentError, EnumKey, key, 1)

    def test_qword(self):
        # REG_QWORD is added in Python 3.6, can't set in setup_class
        from winreg import CreateKey, SetValueEx, QueryValueEx, REG_QWORD
        key = CreateKey(self.root_key, self.test_key_name)
        sub_key = CreateKey(key, u"sub_key")
        name = 'Long Value'
        value = 0xFEDCBA9876543210
        SetValueEx(sub_key, name, 0, REG_QWORD, value)
        assert QueryValueEx(sub_key, name) == (value, REG_QWORD)

    def test_delete(self):
        # must be run after test_SetValueEx
        from winreg import OpenKey, KEY_ALL_ACCESS, DeleteValue, DeleteKey
        key = OpenKey(self.root_key, self.test_key_name, 0, KEY_ALL_ACCESS)
        sub_key = OpenKey(key, "sub_key", 0, KEY_ALL_ACCESS)

        for name, value, type in self.test_data:
            DeleteValue(sub_key, name)
        # cannot wrap a memoryview in setup_class for test_data
        DeleteValue(sub_key, 'test_name')
        # REG_QWORD is added in Python 3.6, can't set in setup_class
        DeleteValue(sub_key, 'Long Value')

        DeleteKey(key, "sub_key")

    def test_truncate_null(self):
        # bpo-25778: REG_SZ should not contain null characters
        from winreg import CreateKey, SetValueEx, QueryValueEx, DeleteValue
        from winreg import REG_SZ, HKEY_CURRENT_USER
        key = CreateKey(self.root_key, self.test_key_name)

        test_name = "test_truncate"
        test_val = "A string\x00 with a null"
        expected_val = "A string"
        SetValueEx(key, test_name, 0, REG_SZ, test_val)
        assert QueryValueEx(key, test_name) == (expected_val, REG_SZ)
        DeleteValue(key, test_name)

    def test_connect(self):
        from winreg import ConnectRegistry, HKEY_LOCAL_MACHINE
        h = ConnectRegistry(None, HKEY_LOCAL_MACHINE)
        h.Close()

    def test_savekey(self):
        # must be run after test_SetValueEx
        if not self.canSaveKey:
            skip("CPython needs win32api to set the SeBackupPrivilege security privilege")
        from winreg import OpenKey, KEY_ALL_ACCESS, SaveKey
        import os
        try:
            os.unlink(self.tmpfilename)
        except:
            pass

        with OpenKey(self.root_key, self.test_key_name, 0, KEY_ALL_ACCESS) as key:
            SaveKey(key, self.tmpfilename)

    def test_expand_environment_string(self):
        from winreg import ExpandEnvironmentStrings
        import nt
        r = ExpandEnvironmentStrings("%windir%\\test")
        assert isinstance(r, str)
        if 'WINDIR' in nt.environ:
            assert r == nt.environ["WINDIR"] + "\\test"
        elif 'windir' in nt.environ:
            assert r == nt.environ["windir"] + "\\test"
        else:
            skip('nt.environ not filled in for untranslated tests')

    def test_long_key(self):
        from winreg import (
            HKEY_CURRENT_USER, KEY_ALL_ACCESS, CreateKey, SetValue, EnumKey,
            REG_SZ, QueryInfoKey, OpenKey, DeleteKey)
        name = 'x'*256
        try:
            with CreateKey(HKEY_CURRENT_USER, self.test_key_name) as key:
                SetValue(key, name, REG_SZ, 'x')
                num_subkeys, num_values, t = QueryInfoKey(key)
                EnumKey(key, 0)
        finally:
            with OpenKey(HKEY_CURRENT_USER, self.test_key_name, 0,
                         KEY_ALL_ACCESS) as key:
                DeleteKey(key, name)
            DeleteKey(HKEY_CURRENT_USER, self.test_key_name)

    def test_dynamic_key(self):
        from winreg import EnumValue, QueryValueEx, HKEY_PERFORMANCE_DATA
        if not self.runappdirect:
            skip('very slow untranslated')
        try:
            EnumValue(HKEY_PERFORMANCE_DATA, 0)
        except WindowsError as e:
            import errno
            if e.errno in (errno.EPERM, errno.EACCES):
                skip("access denied to registry key "
                     "(are you running in a non-interactive session?)")
            raise
        QueryValueEx(HKEY_PERFORMANCE_DATA, 'Global')

    def test_reflection_unsupported(self):
        import sys
        if sys.getwindowsversion() >= (5, 2):
            skip("Requires Windows XP")
        from winreg import (
            CreateKey, DisableReflectionKey, EnableReflectionKey,
            QueryReflectionKey, DeleteKeyEx)
        with CreateKey(self.root_key, self.test_key_name) as key:
            raises(NotImplementedError, DisableReflectionKey, key)
            raises(NotImplementedError, EnableReflectionKey, key)
            raises(NotImplementedError, QueryReflectionKey, key)
            raises(NotImplementedError, DeleteKeyEx, self.root_key,
                   self.test_key_name)

    def test_reflection(self):
        import sys
        from winreg import DisableReflectionKey, EnableReflectionKey, \
                           QueryReflectionKey, OpenKey, HKEY_LOCAL_MACHINE
        # Adapted from lib-python test
        if not self.win64_machine:
            skip("Requires 64-bit host")
        # Test that we can call the query, enable, and disable functions
        # on a key which isn't on the reflection list with no consequences.
        with OpenKey(HKEY_LOCAL_MACHINE, "Software") as key:
            # HKLM\Software is redirected but not reflected in all OSes
            assert QueryReflectionKey(key)
            assert EnableReflectionKey(key) is None
            assert DisableReflectionKey(key) is None
            assert QueryReflectionKey(key)

    def test_named_arguments(self):
        from winreg import KEY_ALL_ACCESS, CreateKeyEx, DeleteKey, DeleteKeyEx, OpenKeyEx
        with CreateKeyEx(key=self.root_key, sub_key=self.test_key_name,
                         reserved=0, access=KEY_ALL_ACCESS) as ckey:
            assert ckey.handle != 0
        with OpenKeyEx(key=self.root_key, sub_key=self.test_key_name,
                       reserved=0, access=KEY_ALL_ACCESS) as okey:
            assert okey.handle != 0
        if self.win64_machine:
            DeleteKeyEx(key=self.root_key, sub_key=self.test_key_name,
                        access=KEY_ALL_ACCESS, reserved=0)
        else:
            DeleteKey(self.root_key, self.test_key_name)

    def test_open_with_surrogate(self):
        import winreg
        s = '\uac55\ud8ab\u2d00\u8800PVL'
        try:
            # issue 3345: fails to interpret subkey, raises UnicodeEncodeError
            with winreg.OpenKey(winreg.HKEY_CLASSES_ROOT, s) as key:
                pass
        except OSError:
            pass
        
