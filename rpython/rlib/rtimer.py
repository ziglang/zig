import time

from rpython.rlib.rarithmetic import r_longlong, r_uint
from rpython.rlib.rarithmetic import intmask, longlongmask
from rpython.rtyper.extregistry import ExtRegistryEntry
from rpython.rtyper.lltypesystem import lltype, rffi

_is_64_bit = r_uint.BITS > 32

from rpython.annotator.model import SomeInteger
if _is_64_bit:
    s_TIMESTAMP = SomeInteger()
    TIMESTAMP_type = lltype.Signed
else:
    s_TIMESTAMP = SomeInteger(knowntype=r_longlong)
    TIMESTAMP_type = rffi.LONGLONG


# unit of values returned by read_timestamp. Should be in sync with the ones
# defined in translator/c/debug_print.h
UNIT_TSC = 0
UNIT_NS = 1 # nanoseconds
UNIT_QUERY_PERFORMANCE_COUNTER = 2

def read_timestamp():
    # Returns a longlong on 32-bit, and a regular int on 64-bit.
    # When running on top of python, build the result a bit arbitrarily.
    x = long(time.time() * 500000000)
    if _is_64_bit:
        return intmask(x)
    else:
        return longlongmask(x)

def get_timestamp_unit():
    # an unit which is as arbitrary as the way we build the result of
    # read_timestamp :)
    return UNIT_NS


class ReadTimestampEntry(ExtRegistryEntry):
    _about_ = read_timestamp

    def compute_result_annotation(self):
        return s_TIMESTAMP

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop("ll_read_timestamp", [], resulttype=TIMESTAMP_type)


class ReadTimestampEntry(ExtRegistryEntry):
    _about_ = get_timestamp_unit

    def compute_result_annotation(self):
        from rpython.annotator.model import SomeInteger
        return SomeInteger(nonneg=True)

    def specialize_call(self, hop):
        hop.exception_cannot_occur()
        return hop.genop("ll_get_timestamp_unit", [], resulttype=lltype.Signed)
