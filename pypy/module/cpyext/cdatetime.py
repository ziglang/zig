from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.annlowlevel import llhelper
from rpython.rlib.rarithmetic import widen
from pypy.module.cpyext.pyobject import (PyObject, make_ref, make_typedescr, decref)
from pypy.module.cpyext.api import (cpython_api, CANNOT_FAIL, cpython_struct,
    PyObjectFields, cts, parse_dir, bootstrap_function, slot_function,
    Py_TPFLAGS_HEAPTYPE)
from pypy.module.cpyext.import_ import PyImport_Import
from pypy.module.cpyext.typeobject import PyTypeObjectPtr
from pypy.interpreter.error import OperationError
from pypy.interpreter.argument import Arguments
from pypy.module.__pypy__.interp_pypydatetime import (W_DateTime_Date,
    W_DateTime_Time, W_DateTime_Delta)
from rpython.tool.sourcetools import func_renamer
from pypy.module.cpyext.state import State

cts.parse_header(parse_dir / 'cpyext_datetime.h')


PyDateTime_CAPI = cts.gettype('PyDateTime_CAPI')


@cpython_api([], lltype.Ptr(PyDateTime_CAPI))
def _PyDateTime_Import(space):
    state = space.fromcache(State)
    if len(state.datetimeAPI) > 0:
        return state.datetimeAPI[0]
    datetimeAPI = lltype.malloc(PyDateTime_CAPI, flavor='raw',
                                track_allocation=False)

    w_datetime = PyImport_Import(space, space.newtext("datetime"))

    w_type = space.getattr(w_datetime, space.newtext("date"))
    datetimeAPI.c_DateType = rffi.cast(
        PyTypeObjectPtr, make_ref(space, w_type))
    # convenient place to modify this, needed since the make_typedescr attach
    # links the "wrong" struct to W_DateTime_Date, which in turn is needed
    # because datetime, with a tzinfo entry, inherits from date, without one
    datetimeAPI.c_DateType.c_tp_basicsize = rffi.sizeof(PyObject.TO)

    w_type = space.getattr(w_datetime, space.newtext("datetime"))
    datetimeAPI.c_DateTimeType = rffi.cast(
        PyTypeObjectPtr, make_ref(space, w_type))

    w_type = space.getattr(w_datetime, space.newtext("time"))
    datetimeAPI.c_TimeType = rffi.cast(
        PyTypeObjectPtr, make_ref(space, w_type))

    w_delta = space.getattr(w_datetime, space.newtext("timedelta"))
    datetimeAPI.c_DeltaType = rffi.cast(
        PyTypeObjectPtr, make_ref(space, w_delta))

    w_tzinfo = space.getattr(w_datetime, space.newtext("tzinfo"))
    datetimeAPI.c_TZInfoType = rffi.cast(
        PyTypeObjectPtr, make_ref(space, w_tzinfo))

    # singleton
    w_timezone = space.getattr(w_datetime, space.newtext("timezone"))
    w_d0 = space.call_function(w_delta)
    w_tzobj = space.call_function(w_timezone, w_d0)
    datetimeAPI.c_TimeZone_UTC = make_ref(space, w_tzobj)

    w_type = space.getattr(w_datetime, space.newtext("timezone"))
    w_utc = space.getattr(w_type, space.newtext("utc"))
    datetimeAPI.c_TimeZone_UTC = make_ref(space, w_utc)

    datetimeAPI.c_Date_FromDate = llhelper(
        _PyDate_FromDate.api_func.functype,
        _PyDate_FromDate.api_func.get_wrapper(space))
    datetimeAPI.c_Time_FromTime = llhelper(
        _PyTime_FromTime.api_func.functype,
        _PyTime_FromTime.api_func.get_wrapper(space))
    datetimeAPI.c_Time_FromTimeAndFold = llhelper(
        _PyTime_FromTimeAndFold.api_func.functype,
        _PyTime_FromTimeAndFold.api_func.get_wrapper(space))
    datetimeAPI.c_DateTime_FromDateAndTime = llhelper(
        _PyDateTime_FromDateAndTime.api_func.functype,
        _PyDateTime_FromDateAndTime.api_func.get_wrapper(space))
    datetimeAPI.c_DateTime_FromDateAndTimeAndFold = llhelper(
        _PyDateTime_FromDateAndTimeAndFold.api_func.functype,
        _PyDateTime_FromDateAndTimeAndFold.api_func.get_wrapper(space))
    datetimeAPI.c_Delta_FromDelta = llhelper(
        _PyDelta_FromDelta.api_func.functype,
        _PyDelta_FromDelta.api_func.get_wrapper(space))

    datetimeAPI.c_DateTime_FromTimestamp = llhelper(
        _PyDateTime_FromTimestamp.api_func.functype,
        _PyDateTime_FromTimestamp.api_func.get_wrapper(space))

    datetimeAPI.c_Date_FromTimestamp = llhelper(
        _PyDate_FromTimestamp.api_func.functype,
        _PyDate_FromTimestamp.api_func.get_wrapper(space))

    datetimeAPI.c_TimeZone_FromTimeZone = llhelper(
        _PyTimeZone_FromTimeZone.api_func.functype,
        _PyTimeZone_FromTimeZone.api_func.get_wrapper(space))

    state.datetimeAPI.append(datetimeAPI)
    return state.datetimeAPI[0]

PyDateTime_Time = cts.gettype('PyDateTime_Time*')
PyDateTime_DateTime = cts.gettype('PyDateTime_DateTime*')
PyDateTime_Date = cts.gettype('PyDateTime_Date*')
PyDateTime_Delta = cts.gettype('PyDateTime_Delta*')

# Check functions

def make_check_function(func_name, type_name):
    @cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
    @func_renamer(func_name)
    def check(space, w_obj):
        try:
            return space.is_true(
                space.appexec([w_obj], """(obj):
                    from datetime import %s as datatype
                    return isinstance(obj, datatype)
                    """ % (type_name,)))
        except OperationError:
            return 0

    @cpython_api([PyObject], rffi.INT_real, error=CANNOT_FAIL)
    @func_renamer(func_name + "Exact")
    def check_exact(space, w_obj):
        try:
            return space.is_true(
                space.appexec([w_obj], """(obj):
                    from datetime import %s as datatype
                    return type(obj) is datatype
                    """ % (type_name,)))
        except OperationError:
            return 0
    return check, check_exact

PyDateTime_Check, PyDateTime_CheckExact = make_check_function(
    "PyDateTime_Check", "datetime")
PyDate_Check, PyDate_CheckExact = make_check_function("PyDate_Check", "date")
PyTime_Check, PyTime_CheckExact = make_check_function("PyTime_Check", "time")
PyDelta_Check, PyDelta_CheckExact = make_check_function(
    "PyDelta_Check", "timedelta")
PyTZInfo_Check, PyTZInfo_CheckExact = make_check_function(
    "PyTZInfo_Check", "tzinfo")

@bootstrap_function
def init_datetime(space):
    # no realize functions since there are no getters
    make_typedescr(W_DateTime_Time.typedef,
                   basestruct=PyDateTime_Time.TO,
                   attach=type_attach,
                   dealloc=type_dealloc,
                  )

    make_typedescr(W_DateTime_Date.typedef,
                   basestruct=PyDateTime_DateTime.TO,
                   attach=type_attach,
                   dealloc=type_dealloc,
                  )

    make_typedescr(W_DateTime_Delta.typedef,
                   basestruct=PyDateTime_Delta.TO,
                   attach=timedeltatype_attach,
                  )

def type_attach(space, py_obj, w_obj, w_userdata=None):
    '''Fills a newly allocated py_obj from the w_obj
    If it is a datetime.time or datetime.datetime, it may have tzinfo
    '''
    state = space.fromcache(State)
    if len(state.datetimeAPI) ==0:
        # can happen in subclassing
        _PyDateTime_Import(space)
    if state.datetimeAPI[0].c_TimeType == py_obj.c_ob_type:
        py_datetime = rffi.cast(PyDateTime_Time, py_obj)
        w_tzinfo = space.getattr(w_obj, space.newtext('tzinfo'))
        if space.is_none(w_tzinfo):
            py_datetime.c_hastzinfo = cts.cast('unsigned char', 0)
            py_datetime.c_tzinfo = lltype.nullptr(PyObject.TO)
        else:
            py_datetime.c_hastzinfo = cts.cast('unsigned char', 1)
            py_datetime.c_tzinfo = make_ref(space, w_tzinfo)
    elif state.datetimeAPI[0].c_DateTimeType == py_obj.c_ob_type:
        # For now this is exactly the same structure as PyDateTime_Time
        py_datetime = rffi.cast(PyDateTime_DateTime, py_obj)
        w_tzinfo = space.getattr(w_obj, space.newtext('tzinfo'))
        if space.is_none(w_tzinfo):
            py_datetime.c_hastzinfo = cts.cast('unsigned char', 0)
            py_datetime.c_tzinfo = lltype.nullptr(PyObject.TO)
        else:
            py_datetime.c_hastzinfo = cts.cast('unsigned char', 1)
            py_datetime.c_tzinfo = make_ref(space, w_tzinfo)

@slot_function([PyObject], lltype.Void)
def type_dealloc(space, py_obj):
    from pypy.module.cpyext.object import _dealloc
    state = space.fromcache(State)
    # cannot raise here, so just crash
    assert len(state.datetimeAPI) > 0
    if state.datetimeAPI[0].c_TimeType == py_obj.c_ob_type:
        py_datetime = rffi.cast(PyDateTime_Time, py_obj)
        if (widen(py_datetime.c_hastzinfo) != 0):
            decref(space, py_datetime.c_tzinfo)
    elif state.datetimeAPI[0].c_DateTimeType == py_obj.c_ob_type:
        py_datetime = rffi.cast(PyDateTime_DateTime, py_obj)
        if (widen(py_datetime.c_hastzinfo) != 0):
            decref(space, py_datetime.c_tzinfo)
    _dealloc(space, py_obj)

def timedeltatype_attach(space, py_obj, w_obj, w_userdata=None):
    "Fills a newly allocated py_obj from the w_obj"
    py_delta = rffi.cast(PyDateTime_Delta, py_obj)
    days = space.int_w(space.getattr(w_obj, space.newtext('days')))
    py_delta.c_days = cts.cast('int', days)
    seconds = space.int_w(space.getattr(w_obj, space.newtext('seconds')))
    py_delta.c_seconds = cts.cast('int', seconds)
    microseconds = space.int_w(space.getattr(w_obj, space.newtext('microseconds')))
    py_delta.c_microseconds = cts.cast('int', microseconds)

# Constructors. They are better used as macros.

@cpython_api([rffi.INT_real, rffi.INT_real, rffi.INT_real, PyTypeObjectPtr],
             PyObject)
def _PyDate_FromDate(space, year, month, day, w_type):
    """Return a datetime.date object with the specified year, month and day.
    """
    year = rffi.cast(lltype.Signed, year)
    month = rffi.cast(lltype.Signed, month)
    day = rffi.cast(lltype.Signed, day)
    return space.call_function(
        w_type,
        space.newint(year), space.newint(month), space.newint(day))

@cpython_api([rffi.INT_real, rffi.INT_real, rffi.INT_real, rffi.INT_real,
              PyObject, PyTypeObjectPtr], PyObject)
def _PyTime_FromTime(space, hour, minute, second, usecond, w_tzinfo, w_type):
    """Return a ``datetime.time`` object with the specified hour, minute, second and
    microsecond."""
    hour = rffi.cast(lltype.Signed, hour)
    minute = rffi.cast(lltype.Signed, minute)
    second = rffi.cast(lltype.Signed, second)
    usecond = rffi.cast(lltype.Signed, usecond)
    return space.call_function(
        w_type,
        space.newint(hour), space.newint(minute), space.newint(second),
        space.newint(usecond), w_tzinfo)

@cpython_api([rffi.INT_real, rffi.INT_real, rffi.INT_real,
              rffi.INT_real, rffi.INT_real, rffi.INT_real, rffi.INT_real,
              PyObject, PyTypeObjectPtr], PyObject)
def _PyDateTime_FromDateAndTime(space, year, month, day,
                                hour, minute, second, usecond,
                                w_tzinfo, w_type):
    """Return a datetime.datetime object with the specified year, month, day, hour,
    minute, second and microsecond.
    """
    year = rffi.cast(lltype.Signed, year)
    month = rffi.cast(lltype.Signed, month)
    day = rffi.cast(lltype.Signed, day)
    hour = rffi.cast(lltype.Signed, hour)
    minute = rffi.cast(lltype.Signed, minute)
    second = rffi.cast(lltype.Signed, second)
    usecond = rffi.cast(lltype.Signed, usecond)
    return space.call_function(
        w_type,
        space.newint(year), space.newint(month), space.newint(day),
        space.newint(hour), space.newint(minute), space.newint(second),
        space.newint(usecond), w_tzinfo)

@cpython_api([rffi.INT_real, rffi.INT_real, rffi.INT_real,
              rffi.INT_real, rffi.INT_real, rffi.INT_real, rffi.INT_real,
              PyObject, rffi.INT_real, PyTypeObjectPtr], PyObject)
def _PyDateTime_FromDateAndTimeAndFold(space, year, month, day,
                                hour, minute, second, usecond,
                                w_tzinfo, fold, w_type):
    """Return a datetime.datetime object with the specified year, month, day, hour,
    minute, second,  microsecond and fold.
    """
    year = rffi.cast(lltype.Signed, year)
    month = rffi.cast(lltype.Signed, month)
    day = rffi.cast(lltype.Signed, day)
    hour = rffi.cast(lltype.Signed, hour)
    minute = rffi.cast(lltype.Signed, minute)
    second = rffi.cast(lltype.Signed, second)
    usecond = rffi.cast(lltype.Signed, usecond)
    fold = rffi.cast(lltype.Signed, fold)
    args = Arguments(space,
                    [space.newint(year), space.newint(month), space.newint(day),
                     space.newint(hour), space.newint(minute), space.newint(second),
                     space.newint(usecond), w_tzinfo],
                    keyword_names_w=[space.newtext('fold')],
                    keywords_w = [space.newint(fold)],
                )
    return space.call_args(w_type, args)


@cpython_api([rffi.INT_real, rffi.INT_real, rffi.INT_real, rffi.INT_real,
              PyObject, rffi.INT_real, PyTypeObjectPtr], PyObject)
def _PyTime_FromTimeAndFold(space, hour, minute, second, usecond,
                                w_tzinfo, fold, w_type):
    """Return a datetime.time object with the specified hour,
    minute, second, microsecond, and fold.
    """
    hour = rffi.cast(lltype.Signed, hour)
    minute = rffi.cast(lltype.Signed, minute)
    second = rffi.cast(lltype.Signed, second)
    usecond = rffi.cast(lltype.Signed, usecond)
    fold = rffi.cast(lltype.Signed, fold)
    args = Arguments(space,
                    [space.newint(hour), space.newint(minute), space.newint(second),
                     space.newint(usecond), w_tzinfo],
                    keyword_names_w=[space.newtext('fold')],
                    keywords_w = [space.newint(fold)],
                )

    return space.call_args(w_type, args)

@cpython_api([PyObject], PyObject)
def PyDateTime_FromTimestamp(space, w_args):
    """Create and return a new datetime.datetime object given an argument tuple
    suitable for passing to datetime.datetime.fromtimestamp().
    """
    w_datetime = PyImport_Import(space, space.newtext("datetime"))
    w_type = space.getattr(w_datetime, space.newtext("datetime"))
    return _PyDateTime_FromTimestamp(space, w_type, w_args, None)

@cpython_api([PyObject, PyObject, PyObject], PyObject)
def _PyDateTime_FromTimestamp(space, w_type, w_args, w_kwds):
    """Implementation of datetime.fromtimestamp that matches the signature for
    PyDateTimeCAPI.DateTime_FromTimestamp
    """
    w_method = space.getattr(w_type, space.newtext("fromtimestamp"))

    return space.call(w_method, w_args, w_kwds=w_kwds)

@cpython_api([PyObject], PyObject)
def PyDate_FromTimestamp(space, w_args):
    """Create and return a new datetime.date object given an argument tuple
    suitable for passing to datetime.date.fromtimestamp().
    """
    w_datetime = PyImport_Import(space, space.newtext("datetime"))
    w_type = space.getattr(w_datetime, space.newtext("date"))
    return _PyDate_FromTimestamp(space, w_type, w_args)

@cpython_api([PyObject, PyObject], PyObject)
def _PyDate_FromTimestamp(space, w_type, w_args):
    """Implementation of date.fromtimestamp that matches the signature for
    PyDateTimeCAPI.Date_FromTimestamp"""
    w_method = space.getattr(w_type, space.newtext("fromtimestamp"))
    return space.call(w_method, w_args)

@cpython_api([rffi.INT_real, rffi.INT_real, rffi.INT_real, rffi.INT_real,
              PyTypeObjectPtr],
             PyObject)
def _PyDelta_FromDelta(space, days, seconds, useconds, normalize, w_type):
    """Return a datetime.timedelta object representing the given number of days,
    seconds and microseconds.  Normalization is performed so that the resulting
    number of microseconds and seconds lie in the ranges documented for
    datetime.timedelta objects.
    """
    days = rffi.cast(lltype.Signed, days)
    seconds = rffi.cast(lltype.Signed, seconds)
    useconds = rffi.cast(lltype.Signed, useconds)
    return space.call_function(
        w_type,
        space.newint(days), space.newint(seconds), space.newint(useconds))


@cpython_api([PyObject, PyObject], PyObject)
def _PyTimeZone_FromTimeZone(space, w_offset, w_name):
    """Return a datetime.timezone object with an unnamed fixed offset
    represented by the offset argument.
    """
    w_datetime = PyImport_Import(space, space.newtext("datetime"))
    w_type = space.getattr(w_datetime, space.newtext("timezone"))

    if w_name is not None:
        return space.call_function(w_type, w_offset, w_name)

    return space.call_function(w_type, w_offset)


# Accessors
@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_GET_YEAR(space, w_obj):
    """Return the year, as a positive int.
    """
    return space.int_w(space.getattr(w_obj, space.newtext("year")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_GET_MONTH(space, w_obj):
    """Return the month, as an int from 1 through 12.
    """
    return space.int_w(space.getattr(w_obj, space.newtext("month")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_GET_DAY(space, w_obj):
    """Return the day, as an int from 1 through 31.
    """
    return space.int_w(space.getattr(w_obj, space.newtext("day")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_GET_FOLD(space, w_obj):
    """Return the fold, as an int 0 or 1
    """
    return space.int_w(space.getattr(w_obj, space.newtext("fold")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_DATE_GET_HOUR(space, w_obj):
    """Return the hour, as an int from 0 through 23.
    """
    # w_obj must be a datetime.timedate object.  However, I've seen libraries
    # call this macro with a datetime.date object.  I think it returns
    # nonsense in CPython, but it doesn't crash.  We'll just return zero
    # in case there is no field 'hour'.
    try:
        return space.int_w(space.getattr(w_obj, space.newtext("hour")))
    except OperationError:
        return 0

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_DATE_GET_MINUTE(space, w_obj):
    """Return the minute, as an int from 0 through 59.
    """
    try:
        return space.int_w(space.getattr(w_obj, space.newtext("minute")))
    except OperationError:
        return 0     # see comments in PyDateTime_DATE_GET_HOUR

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_DATE_GET_SECOND(space, w_obj):
    """Return the second, as an int from 0 through 59.
    """
    try:
        return space.int_w(space.getattr(w_obj, space.newtext("second")))
    except OperationError:
        return 0     # see comments in PyDateTime_DATE_GET_HOUR

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_DATE_GET_MICROSECOND(space, w_obj):
    """Return the microsecond, as an int from 0 through 999999.
    """
    try:
        return space.int_w(space.getattr(w_obj, space.newtext("microsecond")))
    except OperationError:
        return 0     # see comments in PyDateTime_DATE_GET_HOUR

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_TIME_GET_HOUR(space, w_obj):
    """Return the hour, as an int from 0 through 23.
    """
    return space.int_w(space.getattr(w_obj, space.newtext("hour")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_TIME_GET_MINUTE(space, w_obj):
    """Return the minute, as an int from 0 through 59.
    """
    return space.int_w(space.getattr(w_obj, space.newtext("minute")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_TIME_GET_SECOND(space, w_obj):
    """Return the second, as an int from 0 through 59.
    """
    return space.int_w(space.getattr(w_obj, space.newtext("second")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_TIME_GET_MICROSECOND(space, w_obj):
    """Return the microsecond, as an int from 0 through 999999.
    """
    return space.int_w(space.getattr(w_obj, space.newtext("microsecond")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_TIME_GET_FOLD(space, w_obj):
    """Return the fold, either 0 or 1
    """
    return space.int_w(space.getattr(w_obj, space.newtext("fold")))

# XXX these functions are not present in the Python API
# But it does not seem possible to expose a different structure
# for types defined in a python module like lib/datetime.py.

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_DELTA_GET_DAYS(space, w_obj):
    return space.int_w(space.getattr(w_obj, space.newtext("days")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_DELTA_GET_SECONDS(space, w_obj):
    return space.int_w(space.getattr(w_obj, space.newtext("seconds")))

@cpython_api([rffi.VOIDP], rffi.INT_real, error=CANNOT_FAIL)
def PyDateTime_DELTA_GET_MICROSECONDS(space, w_obj):
    return space.int_w(space.getattr(w_obj, space.newtext("microseconds")))
