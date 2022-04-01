from __future__ import with_statement
import sys

from pypy.interpreter.error import exception_from_saved_errno
from pypy.interpreter.gateway import unwrap_spec
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rlib import rtime
from rpython.rlib.rtime import HAS_CLOCK_GETTIME


if HAS_CLOCK_GETTIME:

    @unwrap_spec(clk_id="c_int")
    def clock_gettime(space, clk_id):
        with lltype.scoped_alloc(rtime.TIMESPEC) as tp:
            ret = rtime.c_clock_gettime(clk_id, tp)
            if ret != 0:
                raise exception_from_saved_errno(space, space.w_IOError)
            t = (float(rffi.getintfield(tp, 'c_tv_sec')) +
                 float(rffi.getintfield(tp, 'c_tv_nsec')) * 0.000000001)
        return space.newfloat(t)

    @unwrap_spec(clk_id="c_int")
    def clock_getres(space, clk_id):
        with lltype.scoped_alloc(rtime.TIMESPEC) as tp:
            ret = rtime.c_clock_getres(clk_id, tp)
            if ret != 0:
                raise exception_from_saved_errno(space, space.w_IOError)
            t = (float(rffi.getintfield(tp, 'c_tv_sec')) +
                 float(rffi.getintfield(tp, 'c_tv_nsec')) * 0.000000001)
        return space.newfloat(t)
