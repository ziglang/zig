import os
import sys
from rpython.annotator import model as annmodel
from rpython.rlib._os_support import _WIN32, StringTraits, UnicodeTraits
from rpython.rlib.objectmodel import enforceargs
# importing rposix here creates a cycle on Windows
from rpython.rtyper.controllerentry import Controller
from rpython.rtyper.extfunc import register_external
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.translator.tool.cbuild import ExternalCompilationInfo

str0 = annmodel.s_Str0

def llexternal(name, args, result, **kwds):
    # Issue #2840
    # All functions defined here should be releasegil=False, both
    # because it doesn't make much sense to release the GIL and
    # because the OS environment functions are usually not thread-safe
    return rffi.llexternal(name, args, result, releasegil=False, **kwds)

# ____________________________________________________________
#
# Annotation support to control access to 'os.environ' in the RPython
# program

class OsEnvironController(Controller):
    knowntype = os.environ.__class__

    def convert(self, obj):
        # 'None' is good enough, there is only one os.environ
        return None

    def getitem(self, obj, key):
        # in the RPython program reads of 'os.environ[key]' are
        # redirected here
        result = r_getenv(key)
        if result is None:
            raise KeyError
        return result

    @enforceargs(None, None, str0, None)
    def setitem(self, obj, key, value):
        # in the RPython program, 'os.environ[key] = value' is
        # redirected here
        r_putenv(key, value)

    def delitem(self, obj, key):
        # in the RPython program, 'del os.environ[key]' is redirected
        # here
        absent = r_getenv(key) is None
        # Always call unsetenv(), to get eventual OSErrors
        r_unsetenv(key)
        if absent:
            raise KeyError

    def get_keys(self, obj):
        # 'os.environ.keys' is redirected here - note that it's the
        # getattr that arrives here, not the actual method call!
        return r_envkeys

    def get_items(self, obj):
        # 'os.environ.items' is redirected here (not the actual method
        # call!)
        return r_envitems

    def get_get(self, obj):
        # 'os.environ.get' is redirected here (not the actual method
        # call!)
        return r_getenv

# ____________________________________________________________
# Access to the 'environ' external variable
prefix = ''
if sys.platform.startswith('darwin'):
    CCHARPPP = rffi.CArrayPtr(rffi.CCHARPP)
    _os_NSGetEnviron = llexternal(
        '_NSGetEnviron', [], CCHARPPP,
        compilation_info=ExternalCompilationInfo(includes=['crt_externs.h'])
        )
    def os_get_environ():
        return _os_NSGetEnviron()[0]
elif _WIN32:
    eci = ExternalCompilationInfo(includes=['stdlib.h'])
    CWCHARPP = lltype.Ptr(lltype.Array(rffi.CWCHARP, hints={'nolength': True}))

    os_get_environ, _os_set_environ = rffi.CExternVariable(
        rffi.CCHARPP, '_environ', eci)
    get__wenviron, _set__wenviron = rffi.CExternVariable(
        CWCHARPP, '_wenviron', eci, c_type='wchar_t **')
    prefix = '_'
else:
    os_get_environ, _os_set_environ = rffi.CExternVariable(
        rffi.CCHARPP, 'environ', ExternalCompilationInfo())

# ____________________________________________________________
#
# Lower-level interface: dummy placeholders and external registations

def r_envkeys():
    just_a_placeholder

def envkeys_llimpl():
    environ = os_get_environ()
    result = []
    i = 0
    while environ[i]:
        name_value = rffi.charp2str(environ[i])
        p = name_value.find('=')
        if p >= 0:
            result.append(name_value[:p])
        i += 1
    return result

register_external(r_envkeys, [], [str0],   # returns a list of strings
                  export_name='ll_os.ll_os_envkeys',
                  llimpl=envkeys_llimpl)

# ____________________________________________________________

def r_envitems():
    just_a_placeholder

def r_getenv(name):
    just_a_placeholder     # should return None if name not found

def r_putenv(name, value):
    just_a_placeholder

os_getenv = llexternal('getenv', [rffi.CCHARP], rffi.CCHARP)
os_putenv = llexternal(prefix + 'putenv', [rffi.CCHARP], rffi.INT,
                            save_err=rffi.RFFI_SAVE_ERRNO)
if _WIN32:
    _wgetenv = llexternal('_wgetenv', [rffi.CWCHARP], rffi.CWCHARP,
                               compilation_info=eci)
    _wputenv = llexternal('_wputenv', [rffi.CWCHARP], rffi.INT,
                               compilation_info=eci,
                               save_err=rffi.RFFI_SAVE_LASTERROR)

class EnvKeepalive:
    pass
envkeepalive = EnvKeepalive()
envkeepalive.byname = {}
envkeepalive.bywname = {}

def make_env_impls(win32=False):
    if not win32:
        traits = StringTraits()
        get_environ, getenv, putenv = os_get_environ, os_getenv, os_putenv
        byname, eq = envkeepalive.byname, '='
        def last_error(msg):
            from rpython.rlib import rposix
            raise OSError(rposix.get_saved_errno(), msg)
    else:
        traits = UnicodeTraits()
        get_environ, getenv, putenv = get__wenviron, _wgetenv, _wputenv
        byname, eq = envkeepalive.bywname, u'='
        from rpython.rlib.rwin32 import lastSavedWindowsError as last_error

    def envitems_llimpl():
        environ = get_environ()
        result = []
        if not environ:
            return result
        i = 0
        while environ[i]:
            name_value = traits.charp2str(environ[i])
            p = name_value.find(eq)
            if p >= 0:
                result.append((name_value[:p], name_value[p+1:]))
            i += 1
        return result

    def getenv_llimpl(name):
        with traits.scoped_str2charp(name) as l_name:
            l_result = getenv(l_name)
            return traits.charp2str(l_result) if l_result else None

    def putenv_llimpl(name, value):
        l_string = traits.str2charp(name + eq + value)
        error = rffi.cast(lltype.Signed, putenv(l_string))
        if error:
            traits.free_charp(l_string)
            last_error("putenv failed")
        # keep 'l_string' alive - we know that the C library needs it
        # until the next call to putenv() with the same 'name'.
        l_oldstring = byname.get(name, lltype.nullptr(traits.CCHARP.TO))
        byname[name] = l_string
        if l_oldstring:
            traits.free_charp(l_oldstring)

    return envitems_llimpl, getenv_llimpl, putenv_llimpl

envitems_llimpl, getenv_llimpl, putenv_llimpl = make_env_impls()

register_external(r_envitems, [], [(str0, str0)],
                  export_name='ll_os.ll_os_envitems',
                  llimpl=envitems_llimpl)
register_external(r_getenv, [str0],
                  annmodel.SomeString(can_be_None=True, no_nul=True),
                  export_name='ll_os.ll_os_getenv',
                  llimpl=getenv_llimpl)
register_external(r_putenv, [str0, str0], annmodel.s_None,
                  export_name='ll_os.ll_os_putenv',
                  llimpl=putenv_llimpl)

# ____________________________________________________________

def r_unsetenv(name):
    # default implementation for platforms without a real unsetenv()
    r_putenv(name, '')

REAL_UNSETENV = False

if hasattr(__import__(os.name), 'unsetenv'):
    os_unsetenv = llexternal('unsetenv', [rffi.CCHARP], rffi.INT,
                                  save_err=rffi.RFFI_SAVE_ERRNO)

    def unsetenv_llimpl(name):
        with rffi.scoped_str2charp(name) as l_name:
            error = rffi.cast(lltype.Signed, os_unsetenv(l_name))
        if error:
            from rpython.rlib import rposix
            raise OSError(rposix.get_saved_errno(), "os_unsetenv failed")
        try:
            l_oldstring = envkeepalive.byname[name]
        except KeyError:
            pass
        else:
            del envkeepalive.byname[name]
            rffi.free_charp(l_oldstring)

    register_external(r_unsetenv, [str0], annmodel.s_None,
                      export_name='ll_os.ll_os_unsetenv',
                      llimpl=unsetenv_llimpl)
    REAL_UNSETENV = True
