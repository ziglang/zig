# NOT_RPYTHON

from _structseq import structseqtype, structseqfield, SimpleNamespace
import time

class struct_time(metaclass=structseqtype):
    __module__ = 'time'
    name = 'time.struct_time'

    n_sequence_fields = 9

    tm_year   = structseqfield(0, "year, for example, 1993")
    tm_mon    = structseqfield(1, "month of year, range [1, 12]")
    tm_mday   = structseqfield(2, "day of month, range [1, 31]")
    tm_hour   = structseqfield(3, "hours, range [0, 23]")
    tm_min    = structseqfield(4, "minutes, range [0, 59]")
    tm_sec    = structseqfield(5, "seconds, range [0, 61])")
    tm_wday   = structseqfield(6, "day of week, range [0, 6], Monday is 0")
    tm_yday   = structseqfield(7, "day of year, range [1, 366]")
    tm_isdst  = structseqfield(8, "1 if summer time is in effect, 0 if not"
                                  ", and -1 if unknown")
    tm_zone   = structseqfield(9, "abbreviation of timezone name")
    tm_gmtoff = structseqfield(10,"offset from UTC in seconds")


def strptime(string, format="%a %b %d %H:%M:%S %Y"):
    """strptime(string, format) -> struct_time

    Parse a string to a time tuple according to a format specification.
    See the library reference manual for formatting codes
    (same as strftime())."""

    import _strptime     # from the CPython standard library
    return _strptime._strptime_time(string, format)

def get_clock_info(name):
    info = SimpleNamespace()
    info.implementation = ""
    info.monotonic = 0
    info.adjustable = 0
    info.resolution = 1.0

    time._get_time_info(name, info)
    return info

__doc__ = """This module provides various functions to manipulate time values.

There are two standard representations of time.  One is the number
of seconds since the Epoch, in UTC (a.k.a. GMT).  It may be an integer
or a floating point number (to represent fractions of seconds).
The Epoch is system-defined; on Unix, it is generally January 1st, 1970.
The actual value can be retrieved by calling gmtime(0).

The other representation is a tuple of 9 integers giving local time.
The tuple items are:
  year (four digits, e.g. 1998)
  month (1-12)
  day (1-31)
  hours (0-23)
  minutes (0-59)
  seconds (0-59)
  weekday (0-6, Monday is 0)
  Julian day (day in the year, 1-366)
  DST (Daylight Savings Time) flag (-1, 0 or 1)
If the DST flag is 0, the time is given in the regular time zone;
if it is 1, the time is given in the DST time zone;
if it is -1, mktime() should guess based on the date and time.

Variables:

timezone -- difference in seconds between UTC and local standard time
altzone -- difference in  seconds between UTC and local DST time
daylight -- whether local time should reflect DST
tzname -- tuple of (standard time zone name, DST time zone name)

Functions:

time() -- return current time in seconds since the Epoch as a float
clock() -- return CPU time since process start as a float
sleep() -- delay for a number of seconds given as a float
gmtime() -- convert seconds since Epoch to UTC tuple
localtime() -- convert seconds since Epoch to local time tuple
asctime() -- convert time tuple to string
ctime() -- convert time in seconds to string
mktime() -- convert local time tuple to seconds since Epoch
strftime() -- convert time tuple to string according to format specification
strptime() -- parse string to time tuple according to format specification
tzset() -- change the local timezone"""

