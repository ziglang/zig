"""Annotation and rtyping support for the result of os.stat(), os.lstat()
and os.fstat().  In RPython like in plain Python the stat result can be
indexed like a tuple but also exposes the st_xxx attributes.
"""

import os, sys
import collections

from rpython.flowspace.model import Constant
from rpython.flowspace.operation import op
from rpython.annotator import model as annmodel
from rpython.rtyper import extregistry
from rpython.tool.pairtype import pairtype
from rpython.rtyper.tool import rffi_platform as platform
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rtyper.rmodel import Repr
from rpython.rtyper.rint import IntegerRepr
from rpython.rtyper.error import TyperError

from rpython.rlib._os_support import _preferred_traits, string_traits
from rpython.rlib.objectmodel import specialize, we_are_translated, not_rpython
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.rarithmetic import widen
from rpython.rlib.rposix import (
    replace_os_function, handle_posix_error, _as_bytes0)
from rpython.rlib import rposix

_WIN32 = sys.platform.startswith('win')
_LINUX = sys.platform.startswith('linux')
_MACOS = sys.platform.startswith('darwin')
_BSD = sys.platform.startswith('openbsd')

if _WIN32:
    from rpython.rlib import rwin32
    from rpython.rlib.rwin32file import make_win32_traits

# Support for float times is here.
# - ALL_STAT_FIELDS contains Float fields if the system can retrieve
#   sub-second timestamps.
# - TIMESPEC is defined when the "struct stat" contains st_atim field.
if _LINUX or _MACOS or _BSD:
    from rpython.rlib.rposix import TIMESPEC
else:
    TIMESPEC = None


# all possible fields - some of them are not available on all platforms
ALL_STAT_FIELDS = [
    ("st_mode",      lltype.Signed),
    ("st_ino",       lltype.SignedLongLong),
    ("st_dev",       lltype.SignedLongLong),
    ("st_nlink",     lltype.Signed),
    ("st_uid",       lltype.Signed),
    ("st_gid",       lltype.Signed),
    ("st_size",      lltype.SignedLongLong),
    ("st_atime",     lltype.SignedLongLong),   # integral number of seconds
    ("st_mtime",     lltype.SignedLongLong),   #
    ("st_ctime",     lltype.SignedLongLong),   #
    ("st_blksize",   lltype.Signed),
    ("st_blocks",    lltype.Signed),
    ("st_rdev",      lltype.Signed),
    ("st_flags",     lltype.Signed),
    #("st_gen",       lltype.Signed),     -- new in CPy 2.5, not implemented
    #("st_birthtime", lltype.Float),      -- new in CPy 2.5, not implemented
    ("nsec_atime",   lltype.Signed),   # number of nanoseconds
    ("nsec_mtime",   lltype.Signed),   #
    ("nsec_ctime",   lltype.Signed),   #
]
if sys.platform == 'win32':
    ALL_STAT_FIELDS.append(("st_file_attributes", lltype.Signed))
    ALL_STAT_FIELDS.append(("st_reparse_tag", lltype.Signed))

N_INDEXABLE_FIELDS = 10

# For OO backends, expose only the portable fields (the first 10).
PORTABLE_STAT_FIELDS = ALL_STAT_FIELDS[:N_INDEXABLE_FIELDS]

STATVFS_FIELDS = [
    ("f_bsize", lltype.Signed),
    ("f_frsize", lltype.Signed),
    ("f_blocks", lltype.Signed),
    ("f_bfree", lltype.Signed),
    ("f_bavail", lltype.Signed),
    ("f_files", lltype.Signed),
    ("f_ffree", lltype.Signed),
    ("f_favail", lltype.Signed),
    ("f_flag", lltype.Signed),
    ("f_namemax", lltype.Signed),
    ("f_fsid", lltype.Unsigned),
]

@specialize.arg(1)
def get_stat_ns_as_bigint(st, name):
    """'name' is one of the strings "atime", "mtime" or "ctime".
    Returns a bigint that represents the number of nanoseconds
    stored inside the RPython-level os.stat_result 'st'.

    Note that when running untranslated, the os.stat_result type
    is from Python 2.7, which doesn't store more precision than
    a float anyway.  You will only get more after translation.
    """
    from rpython.rlib.rbigint import rbigint

    if not we_are_translated():
        as_float = getattr(st, "st_" + name)
        return rbigint.fromfloat(as_float * 1e9)

    if name == "atime":
        i, j = 7, -3
    elif name == "mtime":
        i, j = 8, -2
    elif name == "ctime":
        i, j = 9, -1
    else:
        raise AssertionError(name)

    sec = st[i]
    nsec = st[j]
    result = rbigint.fromrarith_int(sec).int_mul(1000000000)
    result = result.int_add(nsec)
    return result


# ____________________________________________________________
#
# Annotation support

class SomeStatResult(annmodel.SomeObject):
    knowntype = os.stat_result

    def rtyper_makerepr(self, rtyper):
        return StatResultRepr(rtyper)

    def rtyper_makekey(self):
        return self.__class__,

    def getattr(self, s_attr):
        if not s_attr.is_constant():
            raise annmodel.AnnotatorError("non-constant attr name in getattr()")
        attrname = s_attr.const
        if attrname in ('st_atime', 'st_mtime', 'st_ctime'):
            # like CPython, in RPython we can read the st_Xtime
            # attribute and get a floating-point result.  We can also
            # get a full-precision bigint with get_stat_ns_as_bigint().
            # The floating-point result is computed like a property
            # by _ll_get_st_Xtime().
            TYPE = lltype.Float
        else:
            TYPE = STAT_FIELD_TYPES[attrname]
        return lltype_to_annotation(TYPE)

    if sys.platform == 'win32':
        def _get_rmarshall_support_(self):     # for rlib.rmarshal
            # reduce and recreate stat_result objects from 10-tuples
            # (we ignore the extra values here for simplicity and portability)
            def stat_result_reduce(st):
                return (st[0], st[1], st[2], st[3], st[4],
                        st[5], st[6], st.st_atime, st.st_mtime, st.st_ctime,
                        st.st_file_attributes, st.st_reparse_tag)

            def stat_result_recreate(tup):
                atime, mtime, ctime = tup[7:10]
                result = tup[:7]
                result += (int(atime), int(mtime), int(ctime))
                result += extra_zeroes
                result += (int((atime - result[7]) * 1e9),
                           int((mtime - result[8]) * 1e9),
                           int((ctime - result[9]) * 1e9))
                result += tup[10:]
                return make_stat_result(result)
            s_reduced = annmodel.SomeTuple([lltype_to_annotation(TYPE)
                                        for name, TYPE in PORTABLE_STAT_FIELDS[:7]]
                                 + 3 * [lltype_to_annotation(lltype.Float)]
                                 + 2 * [lltype_to_annotation(lltype.Int)])
            extra_zeroes = (0,) * (len(STAT_FIELDS) - len(PORTABLE_STAT_FIELDS) - 3)
            return s_reduced, stat_result_reduce, stat_result_recreate
    else:
        def _get_rmarshall_support_(self):     # for rlib.rmarshal
            # reduce and recreate stat_result objects from 10-tuples
            # (we ignore the extra values here for simplicity and portability)
            def stat_result_reduce(st):
                return (st[0], st[1], st[2], st[3], st[4],
                        st[5], st[6], st.st_atime, st.st_mtime, st.st_ctime)

            def stat_result_recreate(tup):
                atime, mtime, ctime = tup[7:]
                result = tup[:7]
                result += (int(atime), int(mtime), int(ctime))
                result += extra_zeroes
                result += (int((atime - result[7]) * 1e9),
                           int((mtime - result[8]) * 1e9),
                           int((ctime - result[9]) * 1e9))
                return make_stat_result(result)
            s_reduced = annmodel.SomeTuple([lltype_to_annotation(TYPE)
                                        for name, TYPE in PORTABLE_STAT_FIELDS[:7]]
                                 + 3 * [lltype_to_annotation(lltype.Float)])
            extra_zeroes = (0,) * (len(STAT_FIELDS) - len(PORTABLE_STAT_FIELDS) - 3)
            return s_reduced, stat_result_reduce, stat_result_recreate


class __extend__(pairtype(SomeStatResult, annmodel.SomeInteger)):
    def getitem((s_sta, s_int)):
        assert s_int.is_constant(), "os.stat()[index]: index must be constant"
        index = s_int.const
        assert -3 <= index < N_INDEXABLE_FIELDS, "os.stat()[index] out of range"
        name, TYPE = STAT_FIELDS[index]
        return lltype_to_annotation(TYPE)


class StatResultRepr(Repr):

    def __init__(self, rtyper):
        self.rtyper = rtyper
        self.stat_field_indexes = {}
        for i, (name, TYPE) in enumerate(STAT_FIELDS):
            self.stat_field_indexes[name] = i

        self.s_tuple = annmodel.SomeTuple(
            [lltype_to_annotation(TYPE) for name, TYPE in STAT_FIELDS])
        self.r_tuple = rtyper.getrepr(self.s_tuple)
        self.lowleveltype = self.r_tuple.lowleveltype

    def redispatch_getfield(self, hop, index):
        rtyper = self.rtyper
        s_index = rtyper.annotator.bookkeeper.immutablevalue(index)
        hop2 = hop.copy()
        spaceop = op.getitem(hop.args_v[0], Constant(index))
        spaceop.result = hop.spaceop.result
        hop2.spaceop = spaceop
        hop2.args_v = spaceop.args
        hop2.args_s = [self.s_tuple, s_index]
        hop2.args_r = [self.r_tuple, rtyper.getrepr(s_index)]
        return hop2.dispatch()

    def rtype_getattr(self, hop):
        s_attr = hop.args_s[1]
        attr = s_attr.const
        if attr in ('st_atime', 'st_mtime', 'st_ctime'):
            ll_func = globals()['_ll_get_' + attr]
            v_tuple = hop.inputarg(self, arg=0)
            return hop.gendirectcall(ll_func, v_tuple)
        try:
            index = self.stat_field_indexes[attr]
        except KeyError:
            raise TyperError("os.stat().%s: field not available" % (attr,))
        return self.redispatch_getfield(hop, index)

@specialize.memo()
def _stfld(name):
    index = STAT_FIELD_NAMES.index(name)
    return 'item%d' % index

def _ll_get_st_atime(tup):
    return (float(getattr(tup, _stfld("st_atime"))) +
            1E-9 * getattr(tup, _stfld("nsec_atime")))

def _ll_get_st_mtime(tup):
    return (float(getattr(tup, _stfld("st_mtime"))) +
            1E-9 * getattr(tup, _stfld("nsec_mtime")))

def _ll_get_st_ctime(tup):
    return (float(getattr(tup, _stfld("st_ctime"))) +
            1E-9 * getattr(tup, _stfld("nsec_ctime")))


class __extend__(pairtype(StatResultRepr, IntegerRepr)):
    def rtype_getitem((r_sta, r_int), hop):
        s_int = hop.args_s[1]
        index = s_int.const
        if index < 0:
            index += len(STAT_FIELDS)
        return r_sta.redispatch_getfield(hop, index)

s_StatResult = SomeStatResult()

@not_rpython
def make_stat_result(tup):
    """Turn a tuple into an os.stat_result object."""
    assert len(tup) == len(STAT_FIELDS)
    assert float not in [type(x) for x in tup]
    positional = []
    for i in range(N_INDEXABLE_FIELDS):
        name, TYPE = STAT_FIELDS[i]
        value = lltype.cast_primitive(TYPE, tup[i])
        positional.append(value)
    kwds = {}
    if sys.platform == 'win32':
        kwds['st_atime'] = tup[7] + 1e-9 * tup[-5]
        kwds['st_mtime'] = tup[8] + 1e-9 * tup[-4]
        kwds['st_ctime'] = tup[9] + 1e-9 * tup[-3]
        kwds['st_file_attributes'] = tup[-2]
        kwds['st_reparse_tag'] = tup[-1]
    else:
        kwds['st_atime'] = tup[7] + 1e-9 * tup[-3]
        kwds['st_mtime'] = tup[8] + 1e-9 * tup[-2]
        kwds['st_ctime'] = tup[9] + 1e-9 * tup[-1]
    for value, (name, TYPE) in zip(tup, STAT_FIELDS)[N_INDEXABLE_FIELDS:]:
        if name.startswith('nsec_'):
            continue   # ignore the nsec_Xtime here
        kwds[name] = lltype.cast_primitive(TYPE, value)
    return os.stat_result(positional, kwds)


class MakeStatResultEntry(extregistry.ExtRegistryEntry):
    _about_ = make_stat_result

    def compute_result_annotation(self, s_tup):
        return s_StatResult

    def specialize_call(self, hop):
        r_StatResult = hop.rtyper.getrepr(s_StatResult)
        [v_result] = hop.inputargs(r_StatResult.r_tuple)
        # no-op conversion from r_StatResult.r_tuple to r_StatResult
        hop.exception_cannot_occur()
        return v_result


class SomeStatvfsResult(annmodel.SomeObject):
    if hasattr(os, 'statvfs_result'):
        knowntype = os.statvfs_result
    else:
        knowntype = None # will not be used

    def rtyper_makerepr(self, rtyper):
        return StatvfsResultRepr(rtyper)

    def rtyper_makekey(self):
        return self.__class__,

    def getattr(self, s_attr):
        assert s_attr.is_constant()
        TYPE = STATVFS_FIELD_TYPES[s_attr.const]
        return lltype_to_annotation(TYPE)


class __extend__(pairtype(SomeStatvfsResult, annmodel.SomeInteger)):
    def getitem((s_stat, s_int)):
        assert s_int.is_constant()
        name, TYPE = STATVFS_FIELDS[s_int.const]
        return lltype_to_annotation(TYPE)


s_StatvfsResult = SomeStatvfsResult()


class StatvfsResultRepr(Repr):
    def __init__(self, rtyper):
        self.rtyper = rtyper
        self.statvfs_field_indexes = {}
        for i, (name, TYPE) in enumerate(STATVFS_FIELDS):
            self.statvfs_field_indexes[name] = i

        self.s_tuple = annmodel.SomeTuple(
            [lltype_to_annotation(TYPE) for name, TYPE in STATVFS_FIELDS])
        self.r_tuple = rtyper.getrepr(self.s_tuple)
        self.lowleveltype = self.r_tuple.lowleveltype

    def redispatch_getfield(self, hop, index):
        rtyper = self.rtyper
        s_index = rtyper.annotator.bookkeeper.immutablevalue(index)
        hop2 = hop.copy()
        spaceop = op.getitem(hop.args_v[0], Constant(index))
        spaceop.result = hop.spaceop.result
        hop2.spaceop = spaceop
        hop2.args_v = spaceop.args
        hop2.args_s = [self.s_tuple, s_index]
        hop2.args_r = [self.r_tuple, rtyper.getrepr(s_index)]
        return hop2.dispatch()

    def rtype_getattr(self, hop):
        s_attr = hop.args_s[1]
        attr = s_attr.const
        try:
            index = self.statvfs_field_indexes[attr]
        except KeyError:
            raise TyperError("os.statvfs().%s: field not available" % (attr,))
        return self.redispatch_getfield(hop, index)


class __extend__(pairtype(StatvfsResultRepr, IntegerRepr)):
    def rtype_getitem((r_sta, r_int), hop):
        s_int = hop.args_s[1]
        index = s_int.const
        return r_sta.redispatch_getfield(hop, index)

def make_statvfs_result(tup):
    args = tuple(
        lltype.cast_primitive(TYPE, value) for value, (name, TYPE) in
            zip(tup, STATVFS_FIELDS))
    # only used untranslated 
    return statvfs_result(*args)

class MakeStatvfsResultEntry(extregistry.ExtRegistryEntry):
    _about_ = make_statvfs_result

    def compute_result_annotation(self, s_tup):
        return s_StatvfsResult

    def specialize_call(self, hop):
        r_StatvfsResult = hop.rtyper.getrepr(s_StatvfsResult)
        [v_result] = hop.inputargs(r_StatvfsResult.r_tuple)
        hop.exception_cannot_occur()
        return v_result

# ____________________________________________________________
#
# RFFI support

if sys.platform.startswith('win'):
    _name_struct_stat = '_stati64'
    INCLUDES = ['sys/types.h', 'sys/stat.h', 'sys/statvfs.h']
else:
    if _LINUX:
        _name_struct_stat = 'stat64'
    else:
        _name_struct_stat = 'stat'
    INCLUDES = ['sys/types.h', 'sys/stat.h', 'sys/statvfs.h', 'unistd.h']

compilation_info = ExternalCompilationInfo(
    # This must be set to 64 on some systems to enable large file support.
    #pre_include_bits = ['#define _FILE_OFFSET_BITS 64'],
    # ^^^ nowadays it's always set in all C files we produce.
    includes=INCLUDES
)


def posix_declaration(try_to_add=None):
    global STAT_STRUCT, STATVFS_STRUCT

    LL_STAT_FIELDS = STAT_FIELDS[:]
    if try_to_add:
        LL_STAT_FIELDS.append(try_to_add)

    if TIMESPEC is not None:

        def _expand(lst, originalname, timespecname):
            if _MACOS:  # fields are named e.g. st_atimespec
                timespecname = originalname + "spec"
            else:  # fields are named e.g. st_atim, with no e
                timespecname = originalname[:-1]

            for i, (_name, _TYPE) in enumerate(lst):
                if _name == originalname:
                    # replace the 'st_atime' field of type rffi.DOUBLE
                    # with the corresponding 'struct timespec' field
                    lst[i] = (timespecname, TIMESPEC)
                    break

        _expand(LL_STAT_FIELDS, 'st_atime', 'st_atim')
        _expand(LL_STAT_FIELDS, 'st_mtime', 'st_mtim')
        _expand(LL_STAT_FIELDS, 'st_ctime', 'st_ctim')

        del _expand
    else:
        # Replace float fields with integers
        for name in ('st_atime', 'st_mtime', 'st_ctime', 'st_birthtime'):
            for i, (_name, _TYPE) in enumerate(LL_STAT_FIELDS):
                if _name == name:
                    LL_STAT_FIELDS[i] = (_name, lltype.Signed)
                    break

    class CConfig:
        _compilation_info_ = compilation_info
        STAT_STRUCT = platform.Struct('struct %s' % _name_struct_stat, LL_STAT_FIELDS)
        STATVFS_STRUCT = platform.Struct('struct statvfs', STATVFS_FIELDS)

    try:
        config = platform.configure(CConfig, ignore_errors=try_to_add is not None)
    except platform.CompilationError:
        if try_to_add:
            return    # failed to add this field, give up
        raise

    STAT_STRUCT = lltype.Ptr(config['STAT_STRUCT'])
    STATVFS_STRUCT = lltype.Ptr(config['STATVFS_STRUCT'])
    if try_to_add:
        STAT_FIELDS.append(try_to_add)


# This lists only the fields that have been found on the underlying platform.
# Initially only the PORTABLE_STAT_FIELDS, but more may be added by the
# following loop.
STAT_FIELDS = PORTABLE_STAT_FIELDS[:]

if sys.platform != 'win32':
    posix_declaration()
    for _i in range(len(PORTABLE_STAT_FIELDS), len(ALL_STAT_FIELDS)):
        posix_declaration(ALL_STAT_FIELDS[_i])
    del _i

if sys.platform == 'win32':
    STAT_FIELDS += ALL_STAT_FIELDS[-5:]   # nsec_Xtime, st_file_attributes, st_reparse_tag
else:
    STAT_FIELDS += ALL_STAT_FIELDS[-3:]   # nsec_Xtime

# these two global vars only list the fields defined in the underlying platform
STAT_FIELD_TYPES = dict(STAT_FIELDS)      # {'st_xxx': TYPE}
STAT_FIELD_NAMES = [_name for (_name, _TYPE) in STAT_FIELDS]
del _name, _TYPE

STATVFS_FIELD_TYPES = dict(STATVFS_FIELDS)
STATVFS_FIELD_NAMES = [name for name, tp in STATVFS_FIELDS]
statvfs_result = collections.namedtuple('statvfs_result', STATVFS_FIELD_NAMES)

def build_stat_result(st):
    # only for LL backends
    if TIMESPEC is not None:
        if _MACOS:
            atim = st.c_st_atimespec
            mtim = st.c_st_mtimespec
            ctim = st.c_st_ctimespec
        else:
            atim = st.c_st_atim
            mtim = st.c_st_mtim
            ctim = st.c_st_ctim
        atime, extra_atime = atim.c_tv_sec, int(atim.c_tv_nsec)
        mtime, extra_mtime = mtim.c_tv_sec, int(mtim.c_tv_nsec)
        ctime, extra_ctime = ctim.c_tv_sec, int(ctim.c_tv_nsec)
    else:
        atime, extra_atime = st.c_st_atime, 0
        mtime, extra_mtime = st.c_st_mtime, 0
        ctime, extra_ctime = st.c_st_ctime, 0

    result = (st.c_st_mode,
              st.c_st_ino,
              st.c_st_dev,
              st.c_st_nlink,
              st.c_st_uid,
              st.c_st_gid,
              st.c_st_size,
              atime,
              mtime,
              ctime)

    if "st_blksize" in STAT_FIELD_TYPES: result += (st.c_st_blksize,)
    if "st_blocks"  in STAT_FIELD_TYPES: result += (st.c_st_blocks,)
    if "st_rdev"    in STAT_FIELD_TYPES: result += (st.c_st_rdev,)
    if "st_flags"   in STAT_FIELD_TYPES: result += (st.c_st_flags,)

    result += (extra_atime,
               extra_mtime,
               extra_ctime)

    return make_stat_result(result)


def build_statvfs_result(st):
    return make_statvfs_result((
        st.c_f_bsize,
        st.c_f_frsize,
        st.c_f_blocks,
        st.c_f_bfree,
        st.c_f_bavail,
        st.c_f_files,
        st.c_f_ffree,
        st.c_f_favail,
        st.c_f_flag,
        st.c_f_namemax,
        st.c_f_fsid,
    ))


# Implement and register os.stat() & variants

if not _WIN32:
  c_fstat = rffi.llexternal('fstat64' if _LINUX else 'fstat',
                            [rffi.INT, STAT_STRUCT], rffi.INT,
                            compilation_info=compilation_info,
                            save_err=rffi.RFFI_SAVE_ERRNO,
                            macro=True)
  c_stat = rffi.llexternal('stat64' if _LINUX else 'stat',
                           [rffi.CCHARP, STAT_STRUCT], rffi.INT,
                           compilation_info=compilation_info,
                           save_err=rffi.RFFI_SAVE_ERRNO,
                           macro=True)
  c_lstat = rffi.llexternal('lstat64' if _LINUX else 'lstat',
                            [rffi.CCHARP, STAT_STRUCT], rffi.INT,
                            compilation_info=compilation_info,
                            save_err=rffi.RFFI_SAVE_ERRNO,
                            macro=True)

  c_fstatvfs = rffi.llexternal('fstatvfs',
                               [rffi.INT, STATVFS_STRUCT], rffi.INT,
                               compilation_info=compilation_info,
                               save_err=rffi.RFFI_SAVE_ERRNO)
  c_statvfs = rffi.llexternal('statvfs',
                              [rffi.CCHARP, STATVFS_STRUCT], rffi.INT,
                              compilation_info=compilation_info,
                              save_err=rffi.RFFI_SAVE_ERRNO)

@replace_os_function('fstat')
def fstat(fd):
    if not _WIN32:
        with lltype.scoped_alloc(STAT_STRUCT.TO) as stresult:
            handle_posix_error('fstat', c_fstat(fd, stresult))
            return build_stat_result(stresult)
    else:
        handle = rwin32.get_osfhandle(fd)
        win32traits = make_win32_traits(string_traits)
        filetype = win32traits.GetFileType(handle)
        if filetype == win32traits.FILE_TYPE_CHAR:
            # console or LPT device
            return make_stat_result((win32traits._S_IFCHR,
                                     0, 0, 0, 0, 0,
                                     0, 0, 0, 0,
                                     0, 0, 0, 0, 0))
        elif filetype == win32traits.FILE_TYPE_PIPE:
            # socket or named pipe
            return make_stat_result((win32traits._S_IFIFO,
                                     0, 0, 0, 0, 0,
                                     0, 0, 0, 0,
                                     0, 0, 0, 0, 0))
        elif filetype == win32traits.FILE_TYPE_UNKNOWN:
            error = rwin32.GetLastError_saved()
            if error != 0:
                raise WindowsError(error, "os_fstat failed")
            # else: unknown but valid file

        # normal disk file (FILE_TYPE_DISK)
        with lltype.scoped_alloc(win32traits.BY_HANDLE_FILE_INFORMATION,
                             zero=True) as fileInfo:
            res = win32traits.GetFileInformationByHandle(handle, fileInfo)
            if res == 0:
                raise WindowsError(rwin32.GetLastError_saved(),
                                   "os_fstat failed")
            return win32_by_handle_info_to_stat(win32traits, fileInfo, 0)

@replace_os_function('stat')
@specialize.argtype(0)
def stat(path):
    if not _WIN32:
        with lltype.scoped_alloc(STAT_STRUCT.TO) as stresult:
            arg = _as_bytes0(path)
            handle_posix_error('stat', c_stat(arg, stresult))
            return build_stat_result(stresult)
    else:
        traits = _preferred_traits(path)
        path = traits.as_str0(path)
        return win32_xstat3(traits, path, traverse=True)

@replace_os_function('lstat')
@specialize.argtype(0)
def lstat(path):
    if not _WIN32:
        with lltype.scoped_alloc(STAT_STRUCT.TO) as stresult:
            arg = _as_bytes0(path)
            handle_posix_error('lstat', c_lstat(arg, stresult))
            return build_stat_result(stresult)
    else:
        traits = _preferred_traits(path)
        path = traits.as_str0(path)
        return win32_xstat3(traits, path, traverse=False)

@specialize.argtype(0)
def stat3(path):
    if _WIN32:
        # On Windows, the algorithm behind os.stat() changed a lot between
        # Python 2 and Python 3.  This is the Python 3 version.
        traits = _preferred_traits(path)
        path = traits.as_str0(path)
        return win32_xstat3(traits, path, traverse=True)
    else:
        return stat(path)

@specialize.argtype(0)
def lstat3(path):
    if _WIN32:
        # On Windows, the algorithm behind os.lstat() changed a lot between
        # Python 2 and Python 3.  This is the Python 3 version.
        traits = _preferred_traits(path)
        path = traits.as_str0(path)
        return win32_xstat3(traits, path, traverse=False)
    else:
        return lstat(path)

if rposix.HAVE_FSTATAT:
    from rpython.rlib.rposix import AT_FDCWD, AT_SYMLINK_NOFOLLOW
    c_fstatat = rffi.llexternal('fstatat64' if _LINUX else 'fstatat',
        [rffi.INT, rffi.CCHARP, STAT_STRUCT, rffi.INT], rffi.INT,
        compilation_info=compilation_info,
        save_err=rffi.RFFI_SAVE_ERRNO, macro=True)

    def fstatat(pathname, dir_fd=AT_FDCWD, follow_symlinks=True):
        if follow_symlinks:
            flags = 0
        else:
            flags = AT_SYMLINK_NOFOLLOW
        with lltype.scoped_alloc(STAT_STRUCT.TO) as stresult:
            error = c_fstatat(dir_fd, pathname, stresult, flags)
            handle_posix_error('fstatat', error)
            return build_stat_result(stresult)

@replace_os_function('fstatvfs')
def fstatvfs(fd):
    with lltype.scoped_alloc(STATVFS_STRUCT.TO) as stresult:
        handle_posix_error('fstatvfs', c_fstatvfs(fd, stresult))
        return build_statvfs_result(stresult)

@replace_os_function('statvfs')
@specialize.argtype(0)
def statvfs(path):
    with lltype.scoped_alloc(STATVFS_STRUCT.TO) as stresult:
        arg = _as_bytes0(path)
        handle_posix_error('statvfs', c_statvfs(arg, stresult))
        return build_statvfs_result(stresult)

#__________________________________________________
# Helper functions for win32
if _WIN32:
    from rpython.rlib.rwin32file import FILE_TIME_to_time_t_nsec

    def make_longlong(high, low):
        return (rffi.r_longlong(high) << 32) + rffi.r_longlong(low)

    def IsReparseTagNameSurrogate(_tag):
        return widen(_tag) & 0x20000000

    @specialize.arg(0)
    def win32_xstat3(traits, path0, traverse=False):
        # This is the Python3 version of os.stat() or lstat().
        win32traits = make_win32_traits(traits)
        path = traits.as_str0(path0)

        with lltype.scoped_alloc(win32traits.BY_HANDLE_FILE_INFORMATION,
                                 zero=True) as fileInfo:
            with lltype.scoped_alloc(win32traits.FILE_ATTRIBUTE_TAG_INFO,
                                     zero=True) as tagInfo:
                return win32_xstat_impl(win32traits, path, traverse, fileInfo, tagInfo)

    @specialize.arg(0)
    def win32_xstat_impl(traits, path, traverse, fileInfo, tagInfo):
        access = traits.FILE_READ_ATTRIBUTES
        flags = traits.FILE_FLAG_BACKUP_SEMANTICS
        isUnhandledTag = False
        if not traverse:
            flags |= traits.FILE_FLAG_OPEN_REPARSE_POINT
        hFile = traits.CreateFile(path, access, 0,
            lltype.nullptr(rwin32.LPSECURITY_ATTRIBUTES.TO),
            traits.OPEN_EXISTING,
            flags,
            rwin32.NULL_HANDLE)

        if hFile == rwin32.INVALID_HANDLE_VALUE:
            # Either the path doesn't exist, or the caller lacks access
            errcode = rwin32.GetLastError_saved()
            if (errcode == traits.ERROR_ACCESS_DENIED or
                errcode == traits.ERROR_SHARING_VIOLATION):
                # Try reading the parent directory 
                if win32_attributes_from_dir(traits, path, fileInfo, tagInfo) == 0:
                    raise WindowsError(rwin32.GetLastError_saved(),
                                       "win32_attributes_from_dir failed")
                if widen(fileInfo.c_dwFileAttributes) & traits.FILE_ATTRIBUTE_REPARSE_POINT:
                    if traverse or not IsReparseTagNameSurrogate(tagInfo.c_ReparseTag):
                        raise WindowsError(rwin32.GetLastError_saved(),
                                           "win32_xstat failed")
            elif errcode == traits.ERROR_INVALID_PARAMETER:
                # \\.\con requires read or write access.
                hFile = traits.CreateFile(path,
                            access | traits.GENERIC_READ,
                            traits.FILE_SHARE_READ | traits.FILE_SHARE_WRITE,
                            lltype.nullptr(rwin32.LPSECURITY_ATTRIBUTES.TO),
                            traits.OPEN_EXISTING, flags,
                            rwin32.NULL_HANDLE)
                if hFile == rwin32.INVALID_HANDLE_VALUE:
                    raise WindowsError(rwin32.GetLastError_saved(),
                                       "win32_xstat failed")
            elif errcode == traits.ERROR_CANT_ACCESS_FILE:
                # bpo37834: opne unhandled reparse points if traverse fails
                if traverse:
                    traverse = False
                    isUnhandledTag = True
                    hFile = traits.CreateFile(path, access, 0,
                        lltype.nullptr(rwin32.LPSECURITY_ATTRIBUTES.TO),
                        traits.OPEN_EXISTING,
                        flags | traits.FILE_FLAG_OPEN_REPARSE_POINT,
                        rwin32.NULL_HANDLE)
                if hFile == rwin32.INVALID_HANDLE_VALUE:
                    raise WindowsError(rwin32.GetLastError_saved(),
                                       "win32_xstat failed")
            else:
                raise WindowsError(errcode, "os_stat failed")
        
        if hFile != rwin32.INVALID_HANDLE_VALUE:
            # Handle types other than files on disk.
            fileType = traits.GetFileType(hFile)
            if fileType != traits.FILE_TYPE_DISK:
                errcode = rwin32.GetLastError_saved()
                if fileType == traits.FILE_TYPE_UNKNOWN and errcode != 0:
                    rwin32.CloseHandle(hFile)
                    raise WindowsError(errcode, "os_stat failed")
                fileAttributes = widen(traits.GetFileAttributes(path))
                st_mode = 0
                if (fileAttributes != traits.INVALID_FILE_ATTRIBUTES and
                        fileAttributes & traits.FILE_ATTRIBUTE_DIRECTORY):
                    # \\.\pipe\ or \\.\mailslot\
                    st_mode = traits._S_IFDIR
                elif fileType == traits.FILE_TYPE_CHAR:
                    # \\.\nul
                    st_mode = traits._S_IFCHR
                elif fileType == traits.FILE_TYPE_PIPE:
                    # \\.\pipe\spam
                    st_mode = traits._S_IFIFO
                rwin32.CloseHandle(hFile)
                result = (st_mode,
                  0, 0, 0, 0, 0,
                  0,
                  0, 0, 0,
                  0, 0, 0,
                  0, 0)
                # FILE_TYPE_UNKNOWN, e.g. \\.\mailslot\waitfor.exe\spam
                return make_stat_result(result)
            # Query the reparse tag, and traverse a non-link.
            if not traverse:
                if not traits.GetFileInformationByHandleEx(hFile,
                            traits.FileAttributeTagInfo, tagInfo,
                            traits.TagInfoSize):
                    errcode = rwin32.GetLastError_saved()
                    if errcode in (traits.ERROR_INVALID_PARAMETER,
                                   traits.ERROR_INVALID_FUNCTION,
                                   traits.ERROR_NOT_SUPPORTED):
                        tagInfo.c_FileAttributes = rffi.cast(
                                    rwin32.DWORD, traits.FILE_ATTRIBUTE_NORMAL)
                        tagInfo.c_ReparseTag = rffi.cast(rwin32.DWORD, 0)
                    else:
                        rwin32.CloseHandle(hFile)
                        raise WindowsError(errcode, "os_stat failed")
                elif widen(tagInfo.c_FileAttributes) & traits.FILE_ATTRIBUTE_REPARSE_POINT:
                    if IsReparseTagNameSurrogate(tagInfo.c_ReparseTag):
                        if isUnhandledTag:
                            # Traversing previously failed for either this
                            # link or its target.
                            rwin32.CloseHandle(hFile)
                            raise WindowsError(
                                traits.ERROR_CANT_ACCESS_FILE,
                                "os_stat failed")
                    # Traverse a non-link, but not if traversing already
                    # failed for an unhandled tag.
                    elif not isUnhandledTag:
                        rwin32.CloseHandle(hFile)
                        return win32_xstat_impl(traits, path, True, fileInfo, tagInfo)

        res = traits.GetFileInformationByHandle(hFile, fileInfo)
        errcode = rwin32.GetLastError_saved()
        rwin32.CloseHandle(hFile)
        if res == 0:
            raise WindowsError(errcode, "GetFileInformationByHandle failed")
        result = win32_by_handle_info_to_stat(traits, fileInfo, tagInfo.c_ReparseTag)
        
        # TBD: adjust the file execute permissions by finding the file extension
        # if fileExtension in ('exe', 'bat', 'cmd', 'com'):
        #    result.st_mode |= 0x0111
        return result

    @specialize.arg(0)
    def win32_attributes_to_mode(win32traits, attributes):
        m = 0
        attributes = widen(attributes)
        if attributes & win32traits.FILE_ATTRIBUTE_DIRECTORY:
            m |= win32traits._S_IFDIR | 0111 # IFEXEC for user,group,other
        else:
            m |= win32traits._S_IFREG
        if attributes & win32traits.FILE_ATTRIBUTE_READONLY:
            m |= 0444
        else:
            m |= 0666
        return m

    @specialize.arg(0)
    def win32_attribute_data_to_stat(win32traits, info):
        st_mode = win32_attributes_to_mode(win32traits, info.c_dwFileAttributes)
        st_size = make_longlong(info.c_nFileSizeHigh, info.c_nFileSizeLow)
        ctime, extra_ctime = FILE_TIME_to_time_t_nsec(info.c_ftCreationTime)
        mtime, extra_mtime = FILE_TIME_to_time_t_nsec(info.c_ftLastWriteTime)
        atime, extra_atime = FILE_TIME_to_time_t_nsec(info.c_ftLastAccessTime)

        st_ino = 0
        st_dev = 0
        st_nlink = 0
        st_file_attributes = info.c_dwFileAttributes
        st_reparse_tag = 0

        result = (st_mode,
                  st_ino, st_dev, st_nlink, 0, 0,
                  st_size,
                  atime, mtime, ctime,
                  extra_atime, extra_mtime, extra_ctime,
                  st_file_attributes, st_reparse_tag)

        return make_stat_result(result)

    @specialize.arg(0)
    def win32_by_handle_info_to_stat(win32traits, info, reparse_tag):
        # similar to the one above
        st_mode = win32_attributes_to_mode(win32traits, info.c_dwFileAttributes)
        st_size = make_longlong(info.c_nFileSizeHigh, info.c_nFileSizeLow)
        ctime, extra_ctime = FILE_TIME_to_time_t_nsec(info.c_ftCreationTime)
        mtime, extra_mtime = FILE_TIME_to_time_t_nsec(info.c_ftLastWriteTime)
        atime, extra_atime = FILE_TIME_to_time_t_nsec(info.c_ftLastAccessTime)

        # specific to fstat()
        st_ino = make_longlong(info.c_nFileIndexHigh, info.c_nFileIndexLow)
        st_dev = info.c_dwVolumeSerialNumber
        st_nlink = info.c_nNumberOfLinks
        st_file_attributes = info.c_dwFileAttributes
        st_reparse_tag = reparse_tag

        result = (st_mode,
                  st_ino, st_dev, st_nlink, 0, 0,
                  st_size,
                  atime, mtime, ctime,
                  extra_atime, extra_mtime, extra_ctime,
                  st_file_attributes, st_reparse_tag)

        return make_stat_result(result)

    @specialize.arg(0)
    def win32_attributes_from_dir(traits, path, info, tagInfo):
        with lltype.scoped_alloc(traits.WIN32_FIND_DATA) as filedata:
            hFindFile = traits.FindFirstFile(path, filedata)
            if hFindFile == rwin32.INVALID_HANDLE_VALUE:
                return 0
            traits.FindClose(hFindFile)
            tagInfo.c_ReparseTag = win32_find_data_to_file_info(traits, filedata, info)
            return 1

    @specialize.arg(0)
    def win32_find_data_to_file_info(traits, filedata, info):
        info.c_dwFileAttributes = filedata.c_dwFileAttributes
        rffi.structcopy(info.c_ftCreationTime, filedata.c_ftCreationTime)
        rffi.structcopy(info.c_ftLastAccessTime, filedata.c_ftLastAccessTime)
        rffi.structcopy(info.c_ftLastWriteTime, filedata.c_ftLastWriteTime)
        info.c_nFileSizeHigh    = filedata.c_nFileSizeHigh
        info.c_nFileSizeLow     = filedata.c_nFileSizeLow
        attr = widen(filedata.c_dwFileAttributes)
        if attr & traits.FILE_ATTRIBUTE_REPARSE_POINT:
            return filedata.c_dwReserved0
        return 0
