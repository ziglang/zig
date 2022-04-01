from __future__ import with_statement
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.tool import rffi_platform as platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.rarithmetic import intmask
from rpython.rlib import rwin32

eci = ExternalCompilationInfo(
    includes = ['windows.h',
                ],
    libraries = ('Advapi32', 'kernel32')
    )
class CConfig:
    _compilation_info_ = eci


constant_names = '''
KEY_QUERY_VALUE KEY_SET_VALUE KEY_CREATE_SUB_KEY KEY_ENUMERATE_SUB_KEYS
KEY_NOTIFY KEY_CREATE_LINK KEY_READ KEY_WRITE KEY_EXECUTE KEY_ALL_ACCESS
KEY_WOW64_64KEY KEY_WOW64_32KEY REG_OPTION_RESERVED REG_OPTION_NON_VOLATILE
REG_OPTION_VOLATILE REG_OPTION_CREATE_LINK REG_OPTION_BACKUP_RESTORE
REG_OPTION_OPEN_LINK REG_LEGAL_OPTION REG_CREATED_NEW_KEY
REG_OPENED_EXISTING_KEY REG_WHOLE_HIVE_VOLATILE REG_REFRESH_HIVE
REG_NO_LAZY_FLUSH REG_NOTIFY_CHANGE_NAME REG_NOTIFY_CHANGE_ATTRIBUTES
REG_NOTIFY_CHANGE_LAST_SET REG_NOTIFY_CHANGE_SECURITY REG_LEGAL_CHANGE_FILTER
REG_NONE REG_SZ REG_EXPAND_SZ REG_BINARY REG_DWORD REG_DWORD_LITTLE_ENDIAN
REG_DWORD_BIG_ENDIAN REG_LINK REG_MULTI_SZ REG_RESOURCE_LIST
REG_FULL_RESOURCE_DESCRIPTOR REG_RESOURCE_REQUIREMENTS_LIST
REG_QWORD REG_QWORD_LITTLE_ENDIAN

HKEY_LOCAL_MACHINE HKEY_CLASSES_ROOT HKEY_CURRENT_CONFIG HKEY_CURRENT_USER
HKEY_DYN_DATA HKEY_LOCAL_MACHINE HKEY_PERFORMANCE_DATA HKEY_USERS

ERROR_MORE_DATA
'''.split()
for name in constant_names:
    setattr(CConfig, name, platform.DefinedConstantInteger(name))

constants = {}
cConfig = platform.configure(CConfig)
constants.update(cConfig)
globals().update(cConfig)

def external(name, args, result, **kwds):
    return rffi.llexternal(name, args, result, compilation_info=eci,
                           calling_conv='win', **kwds)

HKEY = rwin32.HANDLE
PHKEY = rffi.CArrayPtr(HKEY)
REGSAM = rwin32.DWORD

def get_traits(suffix):
    if suffix == 'A':
        strp = rffi.CCHARP
    else:
        strp = rffi.CWCHARP
    RegSetValue = external(
        'RegSetValue' + suffix,
        [HKEY, strp, rwin32.DWORD, strp, rwin32.DWORD],
        rffi.LONG)

    RegSetValueEx = external(
        'RegSetValueEx' + suffix,
        [HKEY, strp, rwin32.DWORD,
         rwin32.DWORD, strp, rwin32.DWORD],
        rffi.LONG)

    RegQueryValue = external(
        'RegQueryValue' + suffix,
        [HKEY, strp, strp, rwin32.PLONG],
        rffi.LONG)

    RegQueryValueEx = external(
        'RegQueryValueEx' + suffix,
        [HKEY, strp, rwin32.LPDWORD, rwin32.LPDWORD,
         strp, rwin32.LPDWORD],
        rffi.LONG)

    RegCreateKey = external(
        'RegCreateKey' + suffix,
        [HKEY, strp, PHKEY],
        rffi.LONG)

    RegCreateKeyEx = external(
        'RegCreateKeyEx' + suffix,
        [HKEY, strp, rwin32.DWORD, strp, rwin32.DWORD,
         REGSAM, rffi.VOIDP, PHKEY, rwin32.LPDWORD],
        rffi.LONG)

    RegDeleteValue = external(
        'RegDeleteValue' + suffix,
        [HKEY, strp],
        rffi.LONG)

    RegDeleteKey = external(
        'RegDeleteKey' + suffix,
        [HKEY, strp],
        rffi.LONG)

    RegOpenKeyEx = external(
        'RegOpenKeyEx' + suffix,
        [HKEY, strp, rwin32.DWORD, REGSAM, PHKEY],
        rffi.LONG)

    RegEnumValue = external(
        'RegEnumValue' + suffix,
        [HKEY, rwin32.DWORD, strp,
         rwin32.LPDWORD, rwin32.LPDWORD, rwin32.LPDWORD,
         rffi.CCHARP, rwin32.LPDWORD],
        rffi.LONG)

    RegEnumKeyEx = external(
        'RegEnumKeyEx' + suffix,
        [HKEY, rwin32.DWORD, strp,
         rwin32.LPDWORD, rwin32.LPDWORD,
         strp, rwin32.LPDWORD, rwin32.PFILETIME],
        rffi.LONG)

    RegQueryInfoKey = external(
        'RegQueryInfoKey' + suffix,
        [HKEY, strp, rwin32.LPDWORD, rwin32.LPDWORD,
         rwin32.LPDWORD, rwin32.LPDWORD, rwin32.LPDWORD,
         rwin32.LPDWORD, rwin32.LPDWORD, rwin32.LPDWORD,
         rwin32.LPDWORD, rwin32.PFILETIME],
        rffi.LONG)

    RegLoadKey = external(
        'RegLoadKey' + suffix,
        [HKEY, strp, strp],
        rffi.LONG)

    RegSaveKey = external(
        'RegSaveKey' + suffix,
        [HKEY, strp, rffi.VOIDP],
        rffi.LONG)

    RegConnectRegistry = external(
        'RegConnectRegistry' + suffix,
        [strp, HKEY, PHKEY],
        rffi.LONG)

    return (RegSetValue, RegSetValueEx, RegQueryValue, RegQueryValueEx,
            RegCreateKey, RegCreateKeyEx, RegDeleteValue, RegDeleteKey,
            RegOpenKeyEx, RegEnumValue, RegEnumKeyEx, RegQueryInfoKey,
            RegLoadKey, RegSaveKey, RegConnectRegistry)

RegSetValueW, RegSetValueExW, RegQueryValueW, RegQueryValueExW, \
    RegCreateKeyW, RegCreateKeyExW, RegDeleteValueW, RegDeleteKeyW, \
    RegOpenKeyExW, RegEnumValueW, RegEnumKeyExW, RegQueryInfoKeyW, \
    RegLoadKeyW, RegSaveKeyW, RegConnectRegistryW = get_traits('W')

RegSetValueA, RegSetValueExA, RegQueryValueA, RegQueryValueExA, \
    RegCreateKeyA, RegCreateKeyExA, RegDeleteValueA, RegDeleteKeyA, \
    RegOpenKeyExA, RegEnumValueA, RegEnumKeyExA, RegQueryInfoKeyA, \
    RegLoadKeyA, RegSaveKeyA, RegConnectRegistryA = get_traits('A')

RegCloseKey = external(
    'RegCloseKey',
    [HKEY],
    rffi.LONG)

RegFlushKey = external(
    'RegFlushKey',
    [HKEY],
    rffi.LONG)

_ExpandEnvironmentStringsW = external(
    'ExpandEnvironmentStringsW',
    [rffi.CWCHARP, rffi.CWCHARP, rwin32.DWORD],
    rwin32.DWORD,
    save_err=rffi.RFFI_SAVE_LASTERROR)

def ExpandEnvironmentStrings(source, unicode_len):
    with rffi.scoped_utf82wcharp(source, unicode_len) as src_buf:
        size = _ExpandEnvironmentStringsW(src_buf,
                                          lltype.nullptr(rffi.CWCHARP.TO), 0)
        if size == 0:
            raise rwin32.lastSavedWindowsError("ExpandEnvironmentStrings")
        size = intmask(size)
        with rffi.scoped_alloc_unicodebuffer(size) as dest_buf:
            if _ExpandEnvironmentStringsW(src_buf,
                                          dest_buf.raw, size) == 0:
                raise rwin32.lastSavedWindowsError("ExpandEnvironmentStrings")
            res = dest_buf.str(size-1) # remove trailing \0
            return res.encode('utf8'), len(res)
