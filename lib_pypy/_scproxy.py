"""Helper methods for urllib to fetch the proxy configuration settings using
the SystemConfiguration framework.

"""
import sys
if sys.platform != 'darwin':
    raise ModuleNotFoundError('Requires Mac OS X', name='_scproxy')

from ctypes import c_int32, c_int64, c_void_p, c_char_p, c_int, cdll
from ctypes import pointer, create_string_buffer
from ctypes.util import find_library

kCFNumberSInt32Type = 3
kCFStringEncodingUTF8 = 134217984

def _CFSetup():
    sc = cdll.LoadLibrary(find_library("SystemConfiguration"))
    cf = cdll.LoadLibrary(find_library("CoreFoundation"))
    sctable = [
        ('SCDynamicStoreCopyProxies', [c_void_p], c_void_p),
    ]
    cftable = [
        ('CFArrayGetCount', [c_void_p], c_int64),
        ('CFArrayGetValueAtIndex', [c_void_p, c_int64], c_void_p),
        ('CFDictionaryGetValue', [c_void_p, c_void_p], c_void_p),
        ('CFStringCreateWithCString', [c_void_p, c_char_p, c_int32], c_void_p),
        ('CFStringGetLength', [c_void_p], c_int32),
        ('CFStringGetCString', [c_void_p, c_char_p, c_int32, c_int32], c_int32),
        ('CFNumberGetValue', [c_void_p, c_int, c_void_p], c_int32),
        ('CFRelease', [c_void_p], None),
    ]
    scconst = [
        'kSCPropNetProxiesExceptionsList',
        'kSCPropNetProxiesExcludeSimpleHostnames',
        'kSCPropNetProxiesHTTPEnable',
        'kSCPropNetProxiesHTTPProxy',
        'kSCPropNetProxiesHTTPPort',
        'kSCPropNetProxiesHTTPSEnable',
        'kSCPropNetProxiesHTTPSProxy',
        'kSCPropNetProxiesHTTPSPort',
        'kSCPropNetProxiesFTPEnable',
        'kSCPropNetProxiesFTPProxy',
        'kSCPropNetProxiesFTPPort',
        'kSCPropNetProxiesGopherEnable',
        'kSCPropNetProxiesGopherProxy',
        'kSCPropNetProxiesGopherPort',
    ]
    class CFProxy(object):
        def __init__(self):
            for mod, table in [(sc, sctable), (cf, cftable)]:
                for fname, argtypes, restype in table:
                    func = getattr(mod, fname)
                    func.argtypes = argtypes
                    func.restype = restype
                    setattr(self, fname, func)
            for k in scconst:
                v = None
                try:
                    v = c_void_p.in_dll(sc, k)
                except ValueError:
                    v = None
                setattr(self, k, v)
    return CFProxy()
ffi = _CFSetup()

def cfstring_to_pystring(value):
    length = (ffi.CFStringGetLength(value) * 4) + 1
    buff = create_string_buffer(length)
    ffi.CFStringGetCString(value, buff, length * 4, kCFStringEncodingUTF8)
    return str(buff.value, 'utf8')

def cfnum_to_int32(num):
    result_ptr = pointer(c_int32(0))
    ffi.CFNumberGetValue(num, kCFNumberSInt32Type, result_ptr)
    return result_ptr[0]

def _get_proxy_settings():
    result = {'exclude_simple': False}
    cfdct = ffi.SCDynamicStoreCopyProxies(None)
    if not cfdct:
        return result
    try:
        k = ffi.kSCPropNetProxiesExcludeSimpleHostnames
        if k:
            cfnum = ffi.CFDictionaryGetValue(cfdct, k)
            if cfnum:
                result['exclude_simple'] = bool(cfnum_to_int32(cfnum))
        k = ffi.kSCPropNetProxiesExceptionsList
        if k:
            cfarr = ffi.CFDictionaryGetValue(cfdct, k)
            if cfarr:
                lst = []
                for i in range(ffi.CFArrayGetCount(cfarr)):
                    cfstr = ffi.CFArrayGetValueAtIndex(cfarr, i)
                    if cfstr:
                        v = cfstring_to_pystring(cfstr)
                    else:
                        v = None
                    lst.append(v)
                result['exceptions'] = lst
        return result
    finally:
        ffi.CFRelease(cfdct)

def _get_proxies():
    result = {}
    cfdct = ffi.SCDynamicStoreCopyProxies(None)
    if not cfdct:
        return result
    try:
        for proto in 'HTTP', 'HTTPS', 'FTP', 'Gopher':
            enabled_key = getattr(ffi, 'kSCPropNetProxies' + proto + 'Enable')
            proxy_key = getattr(ffi, 'kSCPropNetProxies' + proto + 'Proxy')
            port_key = getattr(ffi, 'kSCPropNetProxies' + proto + 'Port')
            cfnum = ffi.CFDictionaryGetValue(cfdct, enabled_key)
            if cfnum and cfnum_to_int32(cfnum):
                cfhoststr = ffi.CFDictionaryGetValue(cfdct, proxy_key)
                cfportnum = ffi.CFDictionaryGetValue(cfdct, port_key)
                if cfhoststr:
                    host = cfstring_to_pystring(cfhoststr)
                    if host:
                        if cfportnum:
                            port = cfnum_to_int32(cfportnum)
                            v = 'http://%s:%d' % (host, port)
                        else:
                            v = 'http://%s' % (host,)
                        result[proto.lower()] = v
        return result
    finally:
        ffi.CFRelease(cfdct)
