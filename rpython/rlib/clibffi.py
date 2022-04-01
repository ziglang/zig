""" Libffi wrapping
"""
from __future__ import with_statement

from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.tool import rffi_platform
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.rarithmetic import intmask, is_emulated_long
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.rmmap import alloc
from rpython.rlib.rdynload import dlopen, dlclose, dlsym, dlsym_byordinal
from rpython.rlib.rdynload import DLOpenError, DLLHANDLE
from rpython.rlib import jit, rposix
from rpython.rlib.objectmodel import specialize
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator.platform import platform
from rpython.translator import cdir
from platform import machine
import py
import os
import sys
import ctypes.util


# maaaybe isinstance here would be better. Think
_MSVC = platform.name == "msvc"
_MINGW = platform.name == "mingw32"
_WIN32 = _MSVC or _MINGW
_WIN64 = _WIN32 and is_emulated_long
_MAC_OS = platform.name == "darwin"

_LITTLE_ENDIAN = sys.byteorder == 'little'
_BIG_ENDIAN = sys.byteorder == 'big'

_ARM = rffi_platform.getdefined('__arm__', '')

if _WIN32:
    from rpython.rlib import rwin32
    separate_module_sources = ['''
    #include <stdio.h>
    #include <windows.h>

    /* Get the module where the "fopen" function resides in */
    RPY_EXTERN
    HMODULE pypy_get_libc_handle(void) {
        MEMORY_BASIC_INFORMATION  mi;
        char buf[1000];
        memset(&mi, 0, sizeof(mi));

        if( !VirtualQueryEx(GetCurrentProcess(), &fopen, &mi, sizeof(mi)) )
            return (HMODULE)0;

        GetModuleFileName((HMODULE)mi.AllocationBase, buf, 500);

        return (HMODULE)mi.AllocationBase;
    }
    ''']
    post_include_bits = ['RPY_EXTERN HMODULE pypy_get_libc_handle(void);\n',]
else:
    separate_module_sources = []
    post_include_bits = []


if not _WIN32:
    includes = ['ffi.h']

    if _MAC_OS:
        pre_include_bits = ['#define MACOSX']
    else:
        pre_include_bits = []

    libraries = ['ffi']
    link_files = []

    eci = ExternalCompilationInfo(
        pre_include_bits = pre_include_bits,
        includes = includes,
        libraries = libraries,
        separate_module_sources = separate_module_sources,
        post_include_bits = post_include_bits,
        include_dirs = platform.include_dirs_for_libffi(),
        library_dirs = platform.library_dirs_for_libffi(),
        link_files = link_files,
        testonly_libraries = ['ffi'],
    )
elif _MINGW:
    includes = ['ffi.h']
    libraries = ['libffi-5']

    eci = ExternalCompilationInfo(
        libraries = libraries,
        includes = includes,
        separate_module_sources = separate_module_sources,
        post_include_bits = post_include_bits,
        )

    eci = rffi_platform.configure_external_library(
        'ffi-5', eci,
        [dict(prefix='libffi-',
              include_dir='include', library_dir='.libs'),
         dict(prefix=r'c:\\mingw64', include_dir='include', library_dir='lib'),
         ])
else:
    eci = ExternalCompilationInfo(
        includes = ['ffi.h', 'windows.h'],
        libraries = ['kernel32', 'libffi-8'],
        separate_module_sources = separate_module_sources,
        post_include_bits = post_include_bits,
        )

FFI_TYPE_P = lltype.Ptr(lltype.ForwardReference())
FFI_TYPE_PP = rffi.CArrayPtr(FFI_TYPE_P)
FFI_TYPE_NULL = lltype.nullptr(FFI_TYPE_P.TO)

class CConfig:
    _compilation_info_ = eci

    FFI_OK = rffi_platform.ConstantInteger('FFI_OK')
    FFI_BAD_TYPEDEF = rffi_platform.ConstantInteger('FFI_BAD_TYPEDEF')
    FFI_DEFAULT_ABI = rffi_platform.ConstantInteger('FFI_DEFAULT_ABI')
    if _WIN32 and not _WIN64:
        FFI_STDCALL = rffi_platform.ConstantInteger('FFI_STDCALL')

    if _ARM:
        FFI_SYSV = rffi_platform.ConstantInteger('FFI_SYSV')
        FFI_VFP = rffi_platform.ConstantInteger('FFI_VFP')

    FFI_TYPE_STRUCT = rffi_platform.ConstantInteger('FFI_TYPE_STRUCT')

    size_t = rffi_platform.SimpleType("size_t", rffi.ULONG)
    ffi_abi = rffi_platform.SimpleType("ffi_abi", rffi.USHORT)
    ffi_arg = rffi_platform.SimpleType("ffi_arg", lltype.Signed)

    ffi_type = rffi_platform.Struct('ffi_type', [('size', rffi.ULONG),
                                                 ('alignment', rffi.USHORT),
                                                 ('type', rffi.USHORT),
                                                 ('elements', FFI_TYPE_PP)])

    ffi_cif = rffi_platform.Struct('ffi_cif', [])
    ffi_closure = rffi_platform.Struct('ffi_closure',
                                       [('user_data', rffi.VOIDP)])

def add_simple_type(type_name):
    for name in ['size', 'alignment', 'type']:
        setattr(CConfig, type_name + '_' + name,
            rffi_platform.ConstantInteger(type_name + '.' + name))

def configure_simple_type(type_name):
    l = lltype.malloc(FFI_TYPE_P.TO, flavor='raw', immortal=True)
    for tp, name in [(size_t, 'size'),
                     (rffi.USHORT, 'alignment'),
                     (rffi.USHORT, 'type')]:
        value = getattr(cConfig, '%s_%s' % (type_name, name))
        setattr(l, 'c_' + name, rffi.cast(tp, value))
    l.c_elements = lltype.nullptr(FFI_TYPE_PP.TO)
    return l

base_names = ['double', 'uchar', 'schar', 'sshort', 'ushort', 'uint', 'sint',
              # ffi_type_slong and ffi_type_ulong are omitted because
              # their meaning changes too much from one libffi version to
              # another.  DON'T USE THEM!  use cast_type_to_ffitype().
              'float', 'longdouble', 'pointer', 'void',
              # by size
              'sint8', 'uint8', 'sint16', 'uint16', 'sint32', 'uint32',
              'sint64', 'uint64']
type_names = ['ffi_type_%s' % name for name in base_names]
for i in type_names:
    add_simple_type(i)

class cConfig:
    pass

for k, v in rffi_platform.configure(CConfig).items():
    setattr(cConfig, k, v)

FFI_TYPE_P.TO.become(cConfig.ffi_type)
size_t = cConfig.size_t
FFI_ABI = cConfig.ffi_abi
ffi_arg = cConfig.ffi_arg

for name in type_names:
    locals()[name] = configure_simple_type(name)

def _signed_type_for(TYPE):
    sz = rffi.sizeof(TYPE)
    if sz == 1:   return ffi_type_sint8
    elif sz == 2: return ffi_type_sint16
    elif sz == 4: return ffi_type_sint32
    elif sz == 8: return ffi_type_sint64
    else: raise ValueError("unsupported type size for %r" % (TYPE,))

def _unsigned_type_for(TYPE):
    sz = rffi.sizeof(TYPE)
    if sz == 1:   return ffi_type_uint8
    elif sz == 2: return ffi_type_uint16
    elif sz == 4: return ffi_type_uint32
    elif sz == 8: return ffi_type_uint64
    else: raise ValueError("unsupported type size for %r" % (TYPE,))

__int_type_map = [
    (rffi.UCHAR, ffi_type_uchar),
    (rffi.SIGNEDCHAR, ffi_type_schar),
    (rffi.SHORT, ffi_type_sshort),
    (rffi.USHORT, ffi_type_ushort),
    (rffi.UINT, ffi_type_uint),
    (rffi.INT, ffi_type_sint),
    # xxx don't use ffi_type_slong and ffi_type_ulong - their meaning
    # changes from a libffi version to another :-((
    (rffi.ULONG, _unsigned_type_for(rffi.ULONG)),
    (rffi.LONG, _signed_type_for(rffi.LONG)),
    (rffi.ULONGLONG, _unsigned_type_for(rffi.ULONGLONG)),
    (rffi.LONGLONG, _signed_type_for(rffi.LONGLONG)),
    (lltype.UniChar, _unsigned_type_for(lltype.UniChar)),
    (lltype.Bool, _unsigned_type_for(lltype.Bool)),
    (lltype.Char, _signed_type_for(lltype.Char)),
    ]

__float_type_map = [
    (rffi.DOUBLE, ffi_type_double),
    (rffi.FLOAT, ffi_type_float),
    (rffi.LONGDOUBLE, ffi_type_longdouble),
    ]

__ptr_type_map = [
    (rffi.VOIDP, ffi_type_pointer),
    ]

__type_map = __int_type_map + __float_type_map + [
    (lltype.Void, ffi_type_void)
    ]

TYPE_MAP_INT = dict(__int_type_map)
TYPE_MAP_FLOAT = dict(__float_type_map)
TYPE_MAP = dict(__type_map)

ffitype_map_int = unrolling_iterable(__int_type_map)
ffitype_map_int_or_ptr = unrolling_iterable(__int_type_map + __ptr_type_map)
ffitype_map_float = unrolling_iterable(__float_type_map)
ffitype_map = unrolling_iterable(__type_map)

del __int_type_map, __float_type_map, __ptr_type_map, __type_map


def external(name, args, result, **kwds):
    return rffi.llexternal(name, args, result, compilation_info=eci, **kwds)

def winexternal(name, args, result):
    return rffi.llexternal(name, args, result, compilation_info=eci, calling_conv='win')


if 1 or not _MSVC:
    def check_fficall_result(result, flags):
        pass # No check
else:
    def check_fficall_result(result, flags):
        if result == 0:
            return
        # if win64:
        #     raises ValueError("ffi_call failed with code %d" % (result,))
        if result < 0:
            if flags & FUNCFLAG_CDECL:
                raise StackCheckError(
                    "Procedure called with not enough arguments"
                    " (%d bytes missing)"
                    " or wrong calling convention" % (-result,))
            else:
                raise StackCheckError(
                    "Procedure called with not enough arguments "
                    " (%d bytes missing) " % (-result,))
        else:
            raise StackCheckError(
                "Procedure called with too many "
                "arguments (%d bytes in excess) " % (result,))

if not _WIN32:
    libc_name = ctypes.util.find_library('c')
    assert libc_name is not None, "Cannot find C library, ctypes.util.find_library('c') returned None"

    def get_libc_name():
        return libc_name
elif _MSVC:
    get_libc_handle = external('pypy_get_libc_handle', [], DLLHANDLE)

    @jit.dont_look_inside
    def get_libc_name():
        return rwin32.GetModuleFileName(get_libc_handle())

    libc_name = get_libc_name().lower()
    assert "msvcr" in libc_name or 'ucrtbase' in libc_name, \
           "Suspect msvcrt library: %s" % (get_libc_name(),)
elif _MINGW:
    def get_libc_name():
        return 'msvcrt.dll'

if _WIN32:
    LoadLibrary = rwin32.LoadLibrary

FFI_OK = cConfig.FFI_OK
FFI_BAD_TYPEDEF = cConfig.FFI_BAD_TYPEDEF
FFI_DEFAULT_ABI = cConfig.FFI_DEFAULT_ABI
if _WIN32 and not _WIN64:
    FFI_STDCALL = cConfig.FFI_STDCALL
if _ARM:
    FFI_SYSV = cConfig.FFI_SYSV
    FFI_VFP = cConfig.FFI_VFP
FFI_TYPE_STRUCT = cConfig.FFI_TYPE_STRUCT
FFI_CIFP = lltype.Ptr(cConfig.ffi_cif)

FFI_CLOSUREP = lltype.Ptr(cConfig.ffi_closure)

VOIDPP = rffi.CArrayPtr(rffi.VOIDP)

c_ffi_prep_cif = external('ffi_prep_cif', [FFI_CIFP, FFI_ABI, rffi.UINT,
                                           FFI_TYPE_P, FFI_TYPE_PP], rffi.INT)
if 0 and _MSVC:
    c_ffi_call_return_type = rffi.INT
else:
    c_ffi_call_return_type = lltype.Void
c_ffi_call = external('ffi_call', [FFI_CIFP, rffi.VOIDP, rffi.VOIDP,
                                   VOIDPP], c_ffi_call_return_type,
                      save_err=rffi.RFFI_ERR_ALL | rffi.RFFI_ALT_ERRNO)
# Note: the RFFI_ALT_ERRNO flag matches the one in pyjitpl.direct_libffi_call
CALLBACK_TP = rffi.CCallback([FFI_CIFP, rffi.VOIDP, rffi.VOIDPP, rffi.VOIDP],
                             lltype.Void)
c_ffi_prep_closure = external('ffi_prep_closure', [FFI_CLOSUREP, FFI_CIFP,
                                                   CALLBACK_TP, rffi.VOIDP],
                              rffi.INT)

FFI_STRUCT_P = lltype.Ptr(lltype.Struct('FFI_STRUCT',
                                        ('ffistruct', FFI_TYPE_P.TO),
                                        ('members', lltype.Array(FFI_TYPE_P))))

@specialize.arg(3)
def make_struct_ffitype_e(size, aligment, field_types, track_allocation=True):
    """Compute the type of a structure.  Returns a FFI_STRUCT_P out of
       which the 'ffistruct' member is a regular FFI_TYPE.
    """
    tpe = lltype.malloc(FFI_STRUCT_P.TO, len(field_types)+1, flavor='raw',
                        track_allocation=track_allocation)
    tpe.ffistruct.c_type = rffi.cast(rffi.USHORT, FFI_TYPE_STRUCT)
    tpe.ffistruct.c_size = rffi.cast(rffi.SIZE_T, size)
    tpe.ffistruct.c_alignment = rffi.cast(rffi.USHORT, aligment)
    tpe.ffistruct.c_elements = rffi.cast(FFI_TYPE_PP,
                                         lltype.direct_arrayitems(tpe.members))
    n = 0
    while n < len(field_types):
        tpe.members[n] = field_types[n]
        n += 1
    tpe.members[n] = lltype.nullptr(FFI_TYPE_P.TO)
    return tpe

@specialize.memo()
def cast_type_to_ffitype(tp):
    """ This function returns ffi representation of rpython type tp
    """
    return TYPE_MAP[tp]

@specialize.argtype(1)
def push_arg_as_ffiptr(ffitp, arg, ll_buf):
    # This is for primitive types.  Note that the exact type of 'arg' may be
    # different from the expected 'c_size'.  To cope with that, we fall back
    # to a byte-by-byte copy.
    TP = lltype.typeOf(arg)
    TP_P = lltype.Ptr(rffi.CArray(TP))
    TP_size = rffi.sizeof(TP)
    c_size = intmask(ffitp.c_size)
    # if both types have the same size, we can directly write the
    # value to the buffer
    if c_size == TP_size:
        buf = rffi.cast(TP_P, ll_buf)
        buf[0] = arg
    else:
        # needs byte-by-byte copying.  Make sure 'arg' is an integer type.
        # Note that this won't work for rffi.FLOAT/rffi.DOUBLE.
        assert TP is not rffi.FLOAT and TP is not rffi.DOUBLE
        if TP_size <= rffi.sizeof(lltype.Signed):
            arg = rffi.cast(lltype.Unsigned, arg)
        else:
            arg = rffi.cast(lltype.UnsignedLongLong, arg)
        if _LITTLE_ENDIAN:
            for i in range(c_size):
                ll_buf[i] = chr(arg & 0xFF)
                arg >>= 8
        elif _BIG_ENDIAN:
            for i in range(c_size-1, -1, -1):
                ll_buf[i] = chr(arg & 0xFF)
                arg >>= 8
        else:
            raise AssertionError


# type defs for callback and closure userdata
USERDATA_P = lltype.Ptr(lltype.ForwardReference())
CALLBACK_TP = lltype.Ptr(lltype.FuncType([rffi.VOIDPP, rffi.VOIDP, USERDATA_P],
                                         lltype.Void))
USERDATA_P.TO.become(lltype.Struct('userdata',
                                   ('callback', CALLBACK_TP),
                                   ('addarg', lltype.Signed),
                                   hints={'callback':True}))


@jit.jit_callback("CLIBFFI")
def _ll_callback(ffi_cif, ll_res, ll_args, ll_userdata):
    """ Callback specification.
    ffi_cif - something ffi specific, don't care
    ll_args - rffi.VOIDPP - pointer to array of pointers to args
    ll_restype - rffi.VOIDP - pointer to result
    ll_userdata - a special structure which holds necessary information
                  (what the real callback is for example), casted to VOIDP
    """
    userdata = rffi.cast(USERDATA_P, ll_userdata)
    llop.revdb_do_next_call(lltype.Void)
    userdata.callback(ll_args, ll_res, userdata)

def ll_callback(ffi_cif, ll_res, ll_args, ll_userdata):
    rposix._errno_after(rffi.RFFI_ERR_ALL | rffi.RFFI_ALT_ERRNO)
    _ll_callback(ffi_cif, ll_res, ll_args, ll_userdata)
    rposix._errno_before(rffi.RFFI_ERR_ALL | rffi.RFFI_ALT_ERRNO)


class StackCheckError(ValueError):
    message = None
    def __init__(self, message):
        self.message = message

class LibFFIError(Exception):
    pass

CHUNK = 4096
CLOSURES = rffi.CArrayPtr(FFI_CLOSUREP.TO)

class ClosureHeap(object):

    def __init__(self):
        self.free_list = lltype.nullptr(rffi.VOIDP.TO)

    def _more(self):
        chunk = rffi.cast(CLOSURES, alloc(CHUNK))
        count = CHUNK//rffi.sizeof(FFI_CLOSUREP.TO)
        for i in range(count):
            rffi.cast(rffi.VOIDPP, chunk)[0] = self.free_list
            self.free_list = rffi.cast(rffi.VOIDP, chunk)
            chunk = rffi.ptradd(chunk, 1)

    def alloc(self):
        if not self.free_list:
            self._more()
        p = self.free_list
        self.free_list = rffi.cast(rffi.VOIDPP, p)[0]
        return rffi.cast(FFI_CLOSUREP, p)

    def free(self, p):
        rffi.cast(rffi.VOIDPP, p)[0] = self.free_list
        self.free_list = rffi.cast(rffi.VOIDP, p)

closureHeap = ClosureHeap()

FUNCFLAG_STDCALL   = 0    # on Windows: for WINAPI calls
FUNCFLAG_CDECL     = 1    # on Windows: for __cdecl calls
FUNCFLAG_PYTHONAPI = 4
FUNCFLAG_USE_ERRNO = 8
FUNCFLAG_USE_LASTERROR = 16

@specialize.arg(1)     # hack :-/
def get_call_conv(flags, from_jit):
    if _WIN32 and not _WIN64 and (flags & FUNCFLAG_CDECL == 0):
        return FFI_STDCALL
    else:
        return FFI_DEFAULT_ABI


class AbstractFuncPtr(object):
    ll_cif = lltype.nullptr(FFI_CIFP.TO)
    ll_argtypes = lltype.nullptr(FFI_TYPE_PP.TO)

    _immutable_fields_ = ['argtypes', 'restype']

    def __init__(self, name, argtypes, restype, flags=FUNCFLAG_CDECL):
        self.name = name
        self.argtypes = argtypes
        self.restype = restype
        self.flags = flags
        argnum = len(argtypes)
        self.ll_argtypes = lltype.malloc(FFI_TYPE_PP.TO, argnum, flavor='raw',
                                         track_allocation=False) # freed by the __del__
        for i in range(argnum):
            self.ll_argtypes[i] = argtypes[i]
        self.ll_cif = lltype.malloc(FFI_CIFP.TO, flavor='raw',
                                    track_allocation=False) # freed by the __del__

        if _MSVC:
            # This little trick works correctly with MSVC.
            # It returns small structures in registers
            if intmask(restype.c_type) == FFI_TYPE_STRUCT:
                if restype.c_size <= 4:
                    restype = ffi_type_sint32
                elif restype.c_size <= 8:
                    restype = ffi_type_sint64

        res = c_ffi_prep_cif(self.ll_cif,
                             rffi.cast(rffi.USHORT, get_call_conv(flags,False)),
                             rffi.cast(rffi.UINT, argnum), restype,
                             self.ll_argtypes)
        if not res == FFI_OK:
            raise LibFFIError

    def __del__(self):
        if self.ll_cif:
            lltype.free(self.ll_cif, flavor='raw', track_allocation=False)
            self.ll_cif = lltype.nullptr(FFI_CIFP.TO)
        if self.ll_argtypes:
            lltype.free(self.ll_argtypes, flavor='raw', track_allocation=False)
            self.ll_argtypes = lltype.nullptr(FFI_TYPE_PP.TO)

# as long as CallbackFuncPtr is kept alive, the underlaying userdata
# is kept alive as well
class CallbackFuncPtr(AbstractFuncPtr):
    ll_closure = lltype.nullptr(FFI_CLOSUREP.TO)
    ll_userdata = lltype.nullptr(USERDATA_P.TO)

    # additional_arg should really be a non-heap type like a integer,
    # it cannot be any kind of movable gc reference
    def __init__(self, argtypes, restype, func, additional_arg=0,
                 flags=FUNCFLAG_CDECL):
        AbstractFuncPtr.__init__(self, "callback", argtypes, restype, flags)
        self.ll_closure = closureHeap.alloc()
        self.ll_userdata = lltype.malloc(USERDATA_P.TO, flavor='raw',
                                         track_allocation=False)
        self.ll_userdata.callback = rffi.llhelper(CALLBACK_TP, func)
        self.ll_userdata.addarg = additional_arg
        res = c_ffi_prep_closure(self.ll_closure, self.ll_cif,
                                 ll_callback, rffi.cast(rffi.VOIDP,
                                                        self.ll_userdata))
        if not res == FFI_OK:
            raise LibFFIError

    def __del__(self):
        AbstractFuncPtr.__del__(self)
        if self.ll_closure:
            closureHeap.free(self.ll_closure)
            self.ll_closure = lltype.nullptr(FFI_CLOSUREP.TO)
        if self.ll_userdata:
            lltype.free(self.ll_userdata, flavor='raw', track_allocation=False)
            self.ll_userdata = lltype.nullptr(USERDATA_P.TO)

class RawFuncPtr(AbstractFuncPtr):

    def __init__(self, name, argtypes, restype, funcsym, flags=FUNCFLAG_CDECL,
                 keepalive=None):
        AbstractFuncPtr.__init__(self, name, argtypes, restype, flags)
        self.keepalive = keepalive
        self.funcsym = funcsym

    def call(self, args_ll, ll_result):
        # adjust_return_size() should always be used here on ll_result
        assert len(args_ll) == len(self.argtypes), (
            "wrong number of arguments in call to %s(): "
            "%d instead of %d" % (self.name, len(args_ll), len(self.argtypes)))
        ll_args = lltype.malloc(rffi.VOIDPP.TO, len(args_ll), flavor='raw')
        for i in range(len(args_ll)):
            assert args_ll[i] # none should be NULL
            ll_args[i] = args_ll[i]
        ffires = c_ffi_call(self.ll_cif, self.funcsym, ll_result, ll_args)
        lltype.free(ll_args, flavor='raw')
        check_fficall_result(ffires, self.flags)

class FuncPtr(AbstractFuncPtr):
    ll_args = lltype.nullptr(rffi.VOIDPP.TO)
    ll_result = lltype.nullptr(rffi.VOIDP.TO)

    def __init__(self, name, argtypes, restype, funcsym, flags=FUNCFLAG_CDECL,
                 keepalive=None):
        # initialize each one of pointers with null
        AbstractFuncPtr.__init__(self, name, argtypes, restype, flags)
        self.keepalive = keepalive
        self.funcsym = funcsym
        self.argnum = len(self.argtypes)
        self.pushed_args = 0
        self.ll_args = lltype.malloc(rffi.VOIDPP.TO, self.argnum, flavor='raw')
        for i in range(self.argnum):
            # space for each argument
            self.ll_args[i] = lltype.malloc(rffi.VOIDP.TO,
                                            intmask(argtypes[i].c_size),
                                            flavor='raw')
        if restype != ffi_type_void:
            self.restype_size = intmask(restype.c_size)
            size = adjust_return_size(self.restype_size)
            self.ll_result = lltype.malloc(rffi.VOIDP.TO, size,
                                           flavor='raw')
        else:
            self.restype_size = -1

    @specialize.argtype(1)
    def push_arg(self, value):
        #if self.pushed_args == self.argnum:
        #    raise TypeError("Too many arguments, eats %d, pushed %d" %
        #                    (self.argnum, self.argnum + 1))
        if not we_are_translated():
            TP = lltype.typeOf(value)
            if isinstance(TP, lltype.Ptr):
                if TP.TO._gckind != 'raw':
                    raise ValueError("Can only push raw values to C, not 'gc'")
                # XXX probably we should recursively check for struct fields
                # here, lets just ignore that for now
                if isinstance(TP.TO, lltype.Array):
                    try:
                        TP.TO._hints['nolength']
                    except KeyError:
                        raise ValueError("Can only push to C arrays without length info")
        push_arg_as_ffiptr(self.argtypes[self.pushed_args], value,
                           self.ll_args[self.pushed_args])
        self.pushed_args += 1

    def _check_args(self):
        if self.pushed_args < self.argnum:
            raise TypeError("Did not specify arg nr %d" % (self.pushed_args + 1))

    def _clean_args(self):
        self.pushed_args = 0

    @specialize.arg(1)
    def call(self, RES_TP):
        self._check_args()
        ffires = c_ffi_call(self.ll_cif, self.funcsym,
                            rffi.cast(rffi.VOIDP, self.ll_result),
                            rffi.cast(VOIDPP, self.ll_args))
        if RES_TP is not lltype.Void:
            TP = lltype.Ptr(rffi.CArray(RES_TP))
            ptr = self.ll_result
            if _BIG_ENDIAN and RES_TP in TYPE_MAP_INT:
                # we get a 8 byte value in big endian
                n = rffi.sizeof(lltype.Signed) - self.restype_size
                ptr = rffi.ptradd(ptr, n)
            res = rffi.cast(TP, ptr)[0]
        else:
            res = None
        self._clean_args()
        check_fficall_result(ffires, self.flags)
        return res

    def __del__(self):
        if self.ll_args:
            argnum = len(self.argtypes)
            for i in range(argnum):
                if self.ll_args[i]:
                    lltype.free(self.ll_args[i], flavor='raw')
            lltype.free(self.ll_args, flavor='raw')
            self.ll_args = lltype.nullptr(rffi.VOIDPP.TO)
        if self.ll_result:
            lltype.free(self.ll_result, flavor='raw')
            self.ll_result = lltype.nullptr(rffi.VOIDP.TO)
        AbstractFuncPtr.__del__(self)

class RawCDLL(object):
    def __init__(self, handle):
        self.lib = handle

    def getpointer(self, name, argtypes, restype, flags=FUNCFLAG_CDECL):
        # these arguments are already casted to proper ffi
        # structures!
        return FuncPtr(name, argtypes, restype, dlsym(self.lib, name),
                       flags=flags, keepalive=self)

    def getrawpointer(self, name, argtypes, restype, flags=FUNCFLAG_CDECL):
        # these arguments are already casted to proper ffi
        # structures!
        return RawFuncPtr(name, argtypes, restype, dlsym(self.lib, name),
                          flags=flags, keepalive=self)

    def getrawpointer_byordinal(self, ordinal, argtypes, restype,
                                flags=FUNCFLAG_CDECL):
        # these arguments are already casted to proper ffi
        # structures!
        return RawFuncPtr(name, argtypes, restype,
                          dlsym_byordinal(self.lib, ordinal), flags=flags,
                          keepalive=self)

    def getaddressindll(self, name):
        return dlsym(self.lib, name)

class CDLL(RawCDLL):
    def __init__(self, libname, mode=-1):
        """Load the library, or raises DLOpenError."""
        RawCDLL.__init__(self, rffi.cast(DLLHANDLE, -1))
        with rffi.scoped_str2charp(libname) as ll_libname:
            self.lib = dlopen(ll_libname, mode)

    def __del__(self):
        if self.lib != rffi.cast(DLLHANDLE, -1):
            dlclose(self.lib)
            self.lib = rffi.cast(DLLHANDLE, -1)


def adjust_return_size(memsize):
    # Workaround for a strange behavior of libffi: make sure that
    # we always have at least 8 bytes.  ffi_call() writes 8 bytes
    # into the buffer even if the function's result type asks for
    # less.  This strange behavior is documented.
    if memsize < 8:
        memsize = 8
    return memsize
