from pypy.interpreter.mixedmodule import MixedModule
from rpython.rlib.rwinreg import constants

class Module(MixedModule):
    """This module provides access to the Windows registry API.

Functions:

CloseKey() - Closes a registry key.
ConnectRegistry() - Establishes a connection to a predefined registry handle
                    on another computer.
CreateKey() - Creates the specified key, or opens it if it already exists.
DeleteKey() - Deletes the specified key.
DeleteValue() - Removes a named value from the specified registry key.
EnumKey() - Enumerates subkeys of the specified open registry key.
EnumValue() - Enumerates values of the specified open registry key.
ExpandEnvironmentStrings() - Expand the env strings in a REG_EXPAND_SZ string.
FlushKey() - Writes all the attributes of the specified key to the registry.
LoadKey() - Creates a subkey under HKEY_USER or HKEY_LOCAL_MACHINE and stores
            registration information from a specified file into that subkey.
OpenKey() - Alias for <om win32api.RegOpenKeyEx>
OpenKeyEx() - Opens the specified key.
QueryValue() - Retrieves the value associated with the unnamed value for a
               specified key in the registry.
QueryValueEx() - Retrieves the type and data for a specified value name
                 associated with an open registry key.
QueryInfoKey() - Returns information about the specified key.
SaveKey() - Saves the specified key, and all its subkeys a file.
SetValue() - Associates a value with a specified key.
SetValueEx() - Stores data in the value field of an open registry key.

Special objects:

HKEYType -- type object for HKEY objects
error -- exception raised for Win32 errors

Integer constants:
Many constants are defined - see the documentation for each function
to see what constants are used, and where."""

    applevel_name = 'winreg'

    appleveldefs = {
    }
    interpleveldefs = {
        'error'          : 'space.w_WindowsError',
        'HKEYType'       : 'interp_winreg.W_HKEY',
        'SetValue'       : 'interp_winreg.SetValue',
        'SetValueEx'     : 'interp_winreg.SetValueEx',
        'QueryValue'     : 'interp_winreg.QueryValue',
        'QueryValueEx'   : 'interp_winreg.QueryValueEx',
        'CreateKey'      : 'interp_winreg.CreateKey',
        'CreateKeyEx'    : 'interp_winreg.CreateKeyEx',
        'DeleteKey'      : 'interp_winreg.DeleteKey',
        'DeleteValue'    : 'interp_winreg.DeleteValue',
        'OpenKey'        : 'interp_winreg.OpenKey',
        'OpenKeyEx'      : 'interp_winreg.OpenKey',
        'EnumValue'      : 'interp_winreg.EnumValue',
        'EnumKey'        : 'interp_winreg.EnumKey',
        'FlushKey'       : 'interp_winreg.FlushKey',
        'CloseKey'       : 'interp_winreg.CloseKey',
        'QueryInfoKey'   : 'interp_winreg.QueryInfoKey',
        'LoadKey'        : 'interp_winreg.LoadKey',
        'SaveKey'        : 'interp_winreg.SaveKey',
        'ConnectRegistry': 'interp_winreg.ConnectRegistry',

        'ExpandEnvironmentStrings': 'interp_winreg.ExpandEnvironmentStrings',

        'DisableReflectionKey': 'interp_winreg.DisableReflectionKey',
        'EnableReflectionKey': 'interp_winreg.EnableReflectionKey',
        'QueryReflectionKey': 'interp_winreg.QueryReflectionKey',
        'DeleteKeyEx': 'interp_winreg.DeleteKeyEx',
    }

    for name, value in constants.iteritems():
        interpleveldefs[name] = "space.wrap(%s)" % (value,)

    import pypy.module.sys.version
    if pypy.module.sys.version.CPYTHON_VERSION < (3, 6):
        del interpleveldefs["REG_QWORD"]
        del interpleveldefs["REG_QWORD_LITTLE_ENDIAN"]
