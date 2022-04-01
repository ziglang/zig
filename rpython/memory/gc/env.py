"""
Utilities to get environ variables and platform-specific memory-related values.
"""
import os, sys, platform
from rpython.rlib.rarithmetic import r_uint
from rpython.rlib.debug import debug_print, debug_start, debug_stop
from rpython.rlib.rstring import assert_str0
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.translator.tool.cbuild import ExternalCompilationInfo

# ____________________________________________________________
# Reading env vars.  Supports returning ints, uints or floats,
# and in the first two cases accepts the suffixes B, KB, MB and GB
# (lower case or upper case).

def _read_float_and_factor_from_env(varname):
    value = os.environ.get(varname)
    if value:
        if len(value) > 1 and value[-1] in 'bB':
            value = value[:-1]
        realvalue = value[:-1]
        if value[-1] in 'kK':
            factor = 1024
        elif value[-1] in 'mM':
            factor = 1024*1024
        elif value[-1] in 'gG':
            factor = 1024*1024*1024
        else:
            factor = 1
            realvalue = value
        try:
            return (float(realvalue), factor)
        except ValueError:
            pass
    return (0.0, 0)

def read_from_env(varname):
    value, factor = _read_float_and_factor_from_env(varname)
    return int(value * factor)

def read_uint_from_env(varname):
    value, factor = _read_float_and_factor_from_env(varname)
    return r_uint(value * factor)

def read_float_from_env(varname):
    value, factor = _read_float_and_factor_from_env(varname)
    if factor != 1:
        return 0.0
    return value


# ____________________________________________________________
# Get the total amount of RAM installed in a system.
# On 32-bit systems, it will try to return at most the addressable size.
# If unknown, it will just return the addressable size, which
# will be huge on 64-bit systems.

if sys.maxint == 2147483647:    # 32-bit
    if sys.platform.startswith('linux'):
        addressable_size = float(2**32)     # 4GB
    elif sys.platform == 'win32':
        addressable_size = float(2**31)     # 2GB
    else:
        addressable_size = float(2**31 + 2**30)   # 3GB (compromise)
else:
    addressable_size = float(2**63)    # 64-bit


def get_total_memory_linux(filename):
    debug_start("gc-hardware")
    result = -1.0
    try:
        fd = os.open(filename, os.O_RDONLY, 0644)
        try:
            buf = os.read(fd, 4096)
        finally:
            os.close(fd)
    except OSError:
        pass
    else:
        if buf.startswith('MemTotal:'):
            start = _skipspace(buf, len('MemTotal:'))
            stop = start
            while stop < len(buf) and buf[stop].isdigit():
                stop += 1
            if start < stop:
                result = float(buf[start:stop]) * 1024.0   # assume kB
    if result < 0.0:
        debug_print("get_total_memory() failed")
        result = addressable_size
    else:
        debug_print("memtotal =", result)
        if result > addressable_size:
            result = addressable_size
    debug_stop("gc-hardware")
    return result
get_total_memory_linux2 = get_total_memory_linux3 = get_total_memory_linux

def get_total_memory_darwin(result):
    debug_start("gc-hardware")
    if result <= 0:
        debug_print("get_total_memory() failed")
        result = addressable_size
    else:
        debug_print("memtotal = ", result)
        if result > addressable_size:
            result = addressable_size
    debug_stop("gc-hardware")
    return result


if sys.platform.startswith('linux'):
    def get_total_memory():
        return get_total_memory_linux2('/proc/meminfo')

elif sys.platform == 'darwin':
    def get_total_memory():
        return get_total_memory_darwin(get_darwin_sysctl_signed('hw.memsize'))

elif 'freebsd' in sys.platform:
    def get_total_memory():
        return get_total_memory_darwin(get_darwin_sysctl_signed('hw.usermem'))

else:
    def get_total_memory():
        return addressable_size       # XXX implement me for other platforms


# ____________________________________________________________
# Estimation of the nursery size, based on the L2 cache.

# ---------- Linux2 ----------

def get_L2cache_linux2():
    arch = os.uname()[4]  # machine
    if arch.endswith('86') or arch == 'x86_64':
        return get_L2cache_linux2_cpuinfo()
    if arch in ('alpha', 'ppc'):
        return get_L2cache_linux2_cpuinfo(label='L2 cache')
    #if arch == 's390x':    untested
    #    return get_L2cache_linux2_cpuinfo_s390x()
    if arch == 'ia64':
        return get_L2cache_linux2_ia64()
    if arch in ('parisc', 'parisc64'):
        return get_L2cache_linux2_cpuinfo(label='D-cache')
    if arch in ('sparc', 'sparc64'):
        return get_L2cache_linux2_sparc()
    return -1

get_L2cache_linux3 = get_L2cache_linux2


def get_L2cache_linux2_cpuinfo(filename="/proc/cpuinfo", label='cache size'):
    debug_start("gc-hardware")
    L2cache = sys.maxint
    try:
        fd = os.open(filename, os.O_RDONLY, 0644)
        try:
            data = []
            while True:
                buf = os.read(fd, 4096)
                if not buf:
                    break
                data.append(buf)
        finally:
            os.close(fd)
    except OSError:
        pass
    else:
        data = ''.join(data)
        linepos = 0
        while True:
            start = _findend(data, '\n' + label, linepos)
            if start < 0:
                break    # done
            linepos = _findend(data, '\n', start)
            if linepos < 0:
                break    # no end-of-line??
            # *** data[start:linepos] == "   : 2048 KB\n"
            start = _skipspace(data, start)
            if data[start] != ':':
                continue
            # *** data[start:linepos] == ": 2048 KB\n"
            start = _skipspace(data, start + 1)
            # *** data[start:linepos] == "2048 KB\n"
            end = start
            while '0' <= data[end] <= '9':
                end += 1
            # *** data[start:end] == "2048"
            if start == end:
                continue
            number = int(data[start:end])
            # *** data[end:linepos] == " KB\n"
            end = _skipspace(data, end)
            if data[end] not in ('K', 'k'):    # assume kilobytes for now
                continue
            number = number * 1024
            # for now we look for the smallest of the L2 caches of the CPUs
            if number < L2cache:
                L2cache = number

    debug_print("L2cache =", L2cache)
    debug_stop("gc-hardware")

    if L2cache < sys.maxint:
        return L2cache
    else:
        # Print a top-level warning even in non-debug builds
        llop.debug_print(lltype.Void,
            "Warning: cannot find your CPU L2 cache size in /proc/cpuinfo")
        return -1

def get_L2cache_linux2_cpuinfo_s390x(filename="/proc/cpuinfo", label='cache2'):
    debug_start("gc-hardware")
    L2cache = sys.maxint
    try:
        fd = os.open(filename, os.O_RDONLY, 0644)
        try:
            data = []
            while True:
                buf = os.read(fd, 4096)
                if not buf:
                    break
                data.append(buf)
        finally:
            os.close(fd)
    except OSError:
        pass
    else:
        data = ''.join(data)
        linepos = 0
        while True:
            start = _findend(data, '\n' + label, linepos)
            if start < 0:
                break    # done
            start = _findend(data, 'size=', start)
            if start < 0:
                break
            end = _findend(data, ' ', start) - 1
            if end < 0:
                break
            linepos = end
            size = data[start:end]
            last_char = len(size)-1
            assert 0 <= last_char < len(size)
            if size[last_char] not in ('K', 'k'):    # assume kilobytes for now
                continue
            number = int(size[:last_char])* 1024
            # for now we look for the smallest of the L2 caches of the CPUs
            if number < L2cache:
                L2cache = number

    debug_print("L2cache =", L2cache)
    debug_stop("gc-hardware")

    if L2cache < sys.maxint:
        return L2cache
    else:
        # Print a top-level warning even in non-debug builds
        llop.debug_print(lltype.Void,
            "Warning: cannot find your CPU L2 cache size in /proc/cpuinfo")
        return -1

def get_L2cache_linux2_sparc():
    debug_start("gc-hardware")
    cpu = 0
    L2cache = sys.maxint
    while True:
        try:
            fd = os.open('/sys/devices/system/cpu/cpu' + assert_str0(str(cpu))
                         + '/l2_cache_size', os.O_RDONLY, 0644)
            try:
                line = os.read(fd, 4096)
            finally:
                os.close(fd)
            end = len(line) - 1
            assert end > 0
            number = int(line[:end])
        except OSError:
            break
        if number < L2cache:
            L2cache = number
        cpu += 1

    debug_print("L2cache =", L2cache)
    debug_stop("gc-hardware")
    if L2cache < sys.maxint:
        return L2cache
    else:
        # Print a top-level warning even in non-debug builds
        llop.debug_print(lltype.Void,
            "Warning: cannot find your CPU L2 cache size in "
            "/sys/devices/system/cpu/cpuX/l2_cache_size")
        return -1

def get_L2cache_linux2_ia64():
    debug_start("gc-hardware")
    cpu = 0
    L2cache = sys.maxint
    L3cache = sys.maxint
    while True:
        cpudir = '/sys/devices/system/cpu/cpu' + assert_str0(str(cpu))
        index = 0
        while True:
            cachedir = cpudir + '/cache/index' + assert_str0(str(index))
            try:
                fd = os.open(cachedir + '/level', os.O_RDONLY, 0644)
                try:
                    level = int(os.read(fd, 4096)[:-1])
                finally:
                    os.close(fd)
            except OSError:
                break
            if level not in (2, 3):
                index += 1
                continue
            try:
                fd = os.open(cachedir + '/size', os.O_RDONLY, 0644)
                try:
                    data = os.read(fd, 4096)
                finally:
                    os.close(fd)
            except OSError:
                break

            end = 0
            while '0' <= data[end] <= '9':
                end += 1
            if end == 0:
                index += 1
                continue
            if data[end] not in ('K', 'k'):    # assume kilobytes for now
                index += 1
                continue

            number = int(data[:end])
            number *= 1024

            if level == 2:
                if number < L2cache:
                    L2cache = number
            if level == 3:
                if number < L3cache:
                    L3cache = number

            index += 1

        if index == 0:
            break
        cpu += 1

    mangled = L2cache + L3cache
    debug_print("L2cache =", mangled)
    debug_stop("gc-hardware")
    if mangled > 0:
        return mangled
    else:
        # Print a top-level warning even in non-debug builds
        llop.debug_print(lltype.Void,
            "Warning: cannot find your CPU L2 & L3 cache size in "
            "/sys/devices/system/cpu/cpuX/cache")
        return -1


def _findend(data, pattern, pos):
    pos = data.find(pattern, pos)
    if pos < 0:
        return -1
    return pos + len(pattern)

def _skipspace(data, pos):
    while data[pos] in (' ', '\t'):
        pos += 1
    return pos

# ---------- Darwin ----------

sysctlbyname_eci = ExternalCompilationInfo(includes=["sys/sysctl.h"])
sysctlbyname = rffi.llexternal('sysctlbyname',
                               [rffi.CCHARP, rffi.VOIDP, rffi.SIZE_TP,
                                rffi.VOIDP, rffi.SIZE_T],
                               rffi.INT,
                               sandboxsafe=True,
                               compilation_info=sysctlbyname_eci)

def get_darwin_sysctl_signed(sysctl_name):
    rval_p = lltype.malloc(rffi.LONGLONGP.TO, 1, flavor='raw')
    try:
        len_p = lltype.malloc(rffi.SIZE_TP.TO, 1, flavor='raw')
        try:
            size = rffi.sizeof(rffi.LONGLONG)
            rval_p[0] = rffi.cast(rffi.LONGLONG, 0)
            len_p[0] = rffi.cast(rffi.SIZE_T, size)
            # XXX a hack for llhelper not being robust-enough
            result = sysctlbyname(sysctl_name,
                                  rffi.cast(rffi.VOIDP, rval_p),
                                  len_p,
                                  lltype.nullptr(rffi.VOIDP.TO),
                                  rffi.cast(rffi.SIZE_T, 0))
            rval = 0
            if (rffi.cast(lltype.Signed, result) == 0 and
                rffi.cast(lltype.Signed, len_p[0]) == size):
                rval = rffi.cast(lltype.Signed, rval_p[0])
                if rffi.cast(rffi.LONGLONG, rval) != rval_p[0]:
                    rval = 0    # overflow!
            return rval
        finally:
            lltype.free(len_p, flavor='raw')
    finally:
        lltype.free(rval_p, flavor='raw')


def get_L2cache_darwin():
    """Try to estimate the best nursery size at run-time, depending
    on the machine we are running on.
    """
    debug_start("gc-hardware")
    L2cache = get_darwin_sysctl_signed("hw.l2cachesize")
    L3cache = get_darwin_sysctl_signed("hw.l3cachesize")
    debug_print("L2cache =", L2cache)
    debug_print("L3cache =", L3cache)
    debug_stop("gc-hardware")

    mangled = L2cache + L3cache

    if mangled > 0:
        return mangled
    else:
        # Print a top-level warning even in non-debug builds
        llop.debug_print(lltype.Void,
            "Warning: cannot find your CPU L2 cache size with sysctl()")
        return -1


# --------------------

get_L2cache = globals().get('get_L2cache_' + sys.platform,
                            lambda: -1)     # implement me for other platforms

NURSERY_SIZE_UNKNOWN_CACHE = 1024*1024
# arbitrary 1M. better than default of 131k for most cases
# in case it didn't work

def best_nursery_size_for_L2cache(L2cache):
    # Heuristically, the best nursery size to choose is about half
    # of the L2 cache.
    if L2cache > 2 * 1024 * 1024: # we don't want to have nursery estimated
        # on L2 when L3 is present
        return L2cache // 2
    else:
        return NURSERY_SIZE_UNKNOWN_CACHE

def estimate_best_nursery_size():
    """Try to estimate the best nursery size at run-time, depending
    on the machine we are running on.  Linux code."""
    L2cache = get_L2cache()
    return best_nursery_size_for_L2cache(L2cache)
