import pytest

from pypy.module.cpyext.test.test_cpyext import AppTestCpythonExtensionBase
from pypy.module.cpyext.test.test_api import BaseApiTest
from pypy.module.cpyext.cdatetime import *
from pypy.module.cpyext.cdatetime import (
    _PyDateTime_Import, _PyDateTime_FromDateAndTime, _PyDate_FromDate,
    _PyTime_FromTime, _PyDelta_FromDelta, _PyTime_FromTimeAndFold,
    _PyDateTime_FromDateAndTimeAndFold)
import datetime

class TestDatetime(BaseApiTest):
    def test_date(self, space):
        date_api = _PyDateTime_Import(space)
        w_date = _PyDate_FromDate(space, 2010, 6, 3, date_api.c_DateType)
        assert space.unwrap(space.str(w_date)) == '2010-06-03'

        assert PyDate_Check(space, w_date)
        assert PyDate_CheckExact(space, w_date)

        assert PyDateTime_GET_YEAR(space, w_date) == 2010
        assert PyDateTime_GET_MONTH(space, w_date) == 6
        assert PyDateTime_GET_DAY(space, w_date) == 3

    def test_time(self, space):
        date_api = _PyDateTime_Import(space)
        w_time = _PyTime_FromTime(
            space, 23, 15, 40, 123456, space.w_None, date_api.c_TimeType)
        assert space.unwrap(space.str(w_time)) == '23:15:40.123456'

        assert PyTime_Check(space, w_time)
        assert PyTime_CheckExact(space, w_time)

        assert PyDateTime_TIME_GET_HOUR(space, w_time) == 23
        assert PyDateTime_TIME_GET_MINUTE(space, w_time) == 15
        assert PyDateTime_TIME_GET_SECOND(space, w_time) == 40
        assert PyDateTime_TIME_GET_MICROSECOND(space, w_time) == 123456

        w_time = _PyTime_FromTimeAndFold(
            space, 23, 15, 40, 123456, space.w_None, 0, date_api.c_TimeType)
        assert space.unwrap(space.str(w_time)) == '23:15:40.123456'

        assert PyTime_Check(space, w_time)
        assert PyTime_CheckExact(space, w_time)

        assert PyDateTime_TIME_GET_HOUR(space, w_time) == 23
        assert PyDateTime_TIME_GET_MINUTE(space, w_time) == 15
        assert PyDateTime_TIME_GET_SECOND(space, w_time) == 40
        assert PyDateTime_TIME_GET_MICROSECOND(space, w_time) == 123456


    def test_datetime(self, space):
        date_api = _PyDateTime_Import(space)
        w_date = _PyDateTime_FromDateAndTime(
            space, 2010, 6, 3, 23, 15, 40, 123456, space.w_None,
            date_api.c_DateTimeType)
        assert space.unwrap(space.str(w_date)) == '2010-06-03 23:15:40.123456'

        assert PyDateTime_Check(space, w_date)
        assert PyDateTime_CheckExact(space, w_date)
        assert PyDate_Check(space, w_date)
        assert not PyDate_CheckExact(space, w_date)

        assert PyDateTime_GET_YEAR(space, w_date) == 2010
        assert PyDateTime_GET_MONTH(space, w_date) == 6
        assert PyDateTime_GET_DAY(space, w_date) == 3
        assert PyDateTime_DATE_GET_HOUR(space, w_date) == 23
        assert PyDateTime_DATE_GET_MINUTE(space, w_date) == 15
        assert PyDateTime_DATE_GET_SECOND(space, w_date) == 40
        assert PyDateTime_DATE_GET_MICROSECOND(space, w_date) == 123456

        w_date = _PyDateTime_FromDateAndTimeAndFold(
            space, 2010, 6, 3, 23, 15, 40, 123456, space.w_None,
            0, date_api.c_DateTimeType)
        assert space.unwrap(space.str(w_date)) == '2010-06-03 23:15:40.123456'

        assert PyDateTime_Check(space, w_date)
        assert PyDateTime_CheckExact(space, w_date)
        assert PyDate_Check(space, w_date)
        assert not PyDate_CheckExact(space, w_date)

        assert PyDateTime_GET_YEAR(space, w_date) == 2010
        assert PyDateTime_GET_MONTH(space, w_date) == 6
        assert PyDateTime_GET_DAY(space, w_date) == 3
        assert PyDateTime_DATE_GET_HOUR(space, w_date) == 23
        assert PyDateTime_DATE_GET_MINUTE(space, w_date) == 15
        assert PyDateTime_DATE_GET_SECOND(space, w_date) == 40
        assert PyDateTime_DATE_GET_MICROSECOND(space, w_date) == 123456

    def test_delta(self, space):
        date_api = _PyDateTime_Import(space)
        w_delta = space.appexec(
            [space.wrap(3), space.wrap(15)], """(days, seconds):
            from datetime import timedelta
            return timedelta(days, seconds)
        """)
        assert PyDelta_Check(space, w_delta)
        assert PyDelta_CheckExact(space, w_delta)

        w_delta = _PyDelta_FromDelta(space, 10, 20, 30, True, date_api.c_DeltaType)
        assert PyDelta_Check(space, w_delta)
        assert PyDelta_CheckExact(space, w_delta)

        assert PyDateTime_DELTA_GET_DAYS(space, w_delta) == 10
        assert PyDateTime_DELTA_GET_SECONDS(space, w_delta) == 20
        assert PyDateTime_DELTA_GET_MICROSECONDS(space, w_delta) == 30

    def test_fromtimestamp(self, space):
        w_args = space.wrap((0,))
        w_date = PyDate_FromTimestamp(space, w_args)
        date = datetime.date.fromtimestamp(0)
        assert space.unwrap(space.str(w_date)) == str(date)

        w_args = space.wrap((0,))
        w_date = PyDateTime_FromTimestamp(space, w_args)
        date = datetime.datetime.fromtimestamp(0)
        assert space.unwrap(space.str(w_date)) == str(date)

    @pytest.mark.parametrize('name', ['Time', 'DateTime', 'Date', 'Delta'])
    def test_basicsize(self, space, name):
        datetime = _PyDateTime_Import(space)
        py_size = getattr(datetime, "c_%sType" % name).c_tp_basicsize
        c_size = rffi.sizeof(cts.gettype("PyDateTime_%s" % name))
        assert py_size == c_size


class AppTestDatetime(AppTestCpythonExtensionBase):
    def test_CAPI(self):
        module = self.import_extension('foo', [
            ("get_types", "METH_NOARGS",
             """
                 PyDateTime_IMPORT;
                 if (!PyDateTimeAPI) {
                     PyErr_SetString(PyExc_RuntimeError, "No PyDateTimeAPI");
                     return NULL;
                 }
                 return PyTuple_Pack(5,
                                     PyDateTimeAPI->DateType,
                                     PyDateTimeAPI->DateTimeType,
                                     PyDateTimeAPI->TimeType,
                                     PyDateTimeAPI->DeltaType,
                                     PyDateTimeAPI->TZInfoType);
             """),
            ("clear_types", "METH_NOARGS",
             """
                 Py_DECREF(PyDateTimeAPI->DateType);
                 Py_DECREF(PyDateTimeAPI->DateTimeType);
                 Py_DECREF(PyDateTimeAPI->TimeType);
                 Py_DECREF(PyDateTimeAPI->DeltaType);
                 Py_DECREF(PyDateTimeAPI->TZInfoType);
                 Py_RETURN_NONE;
             """
             )
            ], prologue='#include "datetime.h"\n')
        import datetime
        assert module.get_types() == (datetime.date,
                                      datetime.datetime,
                                      datetime.time,
                                      datetime.timedelta,
                                      datetime.tzinfo)
        module.clear_types()

    def test_constructors(self):
        module = self.import_extension('foo', [
            ("new_date", "METH_NOARGS",
             """ PyDateTime_IMPORT;
                 return PyDateTimeAPI->Date_FromDate(
                    2000, 6, 6, PyDateTimeAPI->DateType);
             """),
            ("new_time", "METH_NOARGS",
             """ PyDateTime_IMPORT;
                 return PyDateTimeAPI->Time_FromTime(
                    6, 6, 6, 6, Py_None, PyDateTimeAPI->TimeType);
             """),
            ("new_datetime", "METH_NOARGS",
             """ PyDateTime_IMPORT;
                 return PyDateTimeAPI->DateTime_FromDateAndTime(
                    2000, 6, 6, 6, 6, 6, 6, Py_None,
                    PyDateTimeAPI->DateTimeType);
             """),
            ("new_datetime_fromtimestamp", "METH_NOARGS",
             """ PyDateTime_IMPORT;
                 PyObject *ts = PyFloat_FromDouble(200000.0);
                 Py_INCREF(Py_None);
                 PyObject *tsargs = PyTuple_Pack(2, ts, Py_None);
                 PyObject *rv = PyDateTimeAPI->DateTime_FromTimestamp(
                    (PyObject *)PyDateTimeAPI->DateTimeType, tsargs, NULL);
                 Py_DECREF(tsargs);
                 return rv;
             """),
            ("new_dt_fromts_tzinfo", "METH_O",
             """ PyDateTime_IMPORT;
                 PyObject *ts = PyFloat_FromDouble(200000.0);
                 PyObject *tsargs = PyTuple_Pack(1, ts);
                 PyObject *tskwargs = PyDict_New();

                 Py_INCREF(args);
                 PyDict_SetItemString(tskwargs, "tz", args);
                 PyObject *rv = PyDateTimeAPI->DateTime_FromTimestamp(
                    (PyObject *)PyDateTimeAPI->DateTimeType, tsargs, tskwargs);
                 Py_DECREF(tsargs);
                 Py_DECREF(tskwargs);
                 return rv;
             """),
            ("new_date_fromtimestamp", "METH_NOARGS",
             """ PyDateTime_IMPORT;
                 PyObject *ts = PyFloat_FromDouble(1430366400.0);
                 Py_INCREF(Py_None);
                 PyObject *tsargs = PyTuple_Pack(1, ts);
                 PyObject *rv = PyDateTimeAPI->Date_FromTimestamp(
                    (PyObject *)PyDateTimeAPI->DateType, tsargs);
                 Py_DECREF(tsargs);
                 return rv;
             """),
        ], prologue='#include "datetime.h"\n')
        import datetime
        assert module.new_date() == datetime.date(2000, 6, 6)
        assert module.new_time() == datetime.time(6, 6, 6, 6)
        assert module.new_datetime() == datetime.datetime(
            2000, 6, 6, 6, 6, 6, 6)

        utc = datetime.timezone.utc

        # .fromtimestamp tests
        assert (module.new_datetime_fromtimestamp() ==
                datetime.datetime.fromtimestamp(200000.0))

        assert (module.new_dt_fromts_tzinfo(utc) ==
                datetime.datetime.fromtimestamp(200000.0, tz=utc))

        assert (module.new_date_fromtimestamp() ==
                datetime.date.fromtimestamp(1430366400.0))

    def test_timezone_constructors(self):
        # Testing that we can build timezones via the C api
        module = self.import_extension('foo', [
            ("new_timezone_fromoffset", "METH_NOARGS",
             """ PyDateTime_IMPORT;
                 PyObject *delta = PyDelta_FromDSU(0, 60 * 60, 0);
                 PyObject *tzinfo = PyTimeZone_FromOffset(delta);
                 Py_DECREF(delta);
                 return tzinfo;
             """),
            ("new_timezone_fromoffset_and_name", "METH_NOARGS",
             """ PyDateTime_IMPORT;
                 PyObject *delta = PyDelta_FromDSU(0, 60 * 60, 0);
                 PyObject *name = PyUnicode_FromString("spam");
                 PyObject *tzinfo = PyTimeZone_FromOffsetAndName(delta, name);
                 Py_DECREF(delta);
                 Py_DECREF(name);
                 return tzinfo;
             """),
            ("utc_singleton_access", "METH_NOARGS",
             """ PyDateTime_IMPORT;
                 Py_INCREF(PyDateTime_TimeZone_UTC);
                 return PyDateTime_TimeZone_UTC;
             """),
        ], prologue='#include "datetime.h"\n')
        import datetime

        one_hour = datetime.timedelta(hours=1)
        expected = datetime.timezone(one_hour)
        assert module.new_timezone_fromoffset() == expected

        expected = datetime.timezone(one_hour, "spam")
        assert module.new_timezone_fromoffset_and_name() == expected

        assert module.utc_singleton_access() == datetime.timezone.utc

    def test_macros(self):
        module = self.import_extension('foo', [
            ("test_date_macros", "METH_NOARGS",
             """
                 PyObject* obj;
                 PyDateTime_Date* d;
                 PyDateTime_IMPORT;
                 if (!PyDateTimeAPI) {
                     PyErr_SetString(PyExc_RuntimeError, "No PyDateTimeAPI");
                     return NULL;
                 }
                 obj = PyDate_FromDate(2000, 6, 6);
                 d = (PyDateTime_Date*)obj;

                 PyDateTime_GET_YEAR(obj);
                 PyDateTime_GET_YEAR(d);

                 PyDateTime_GET_MONTH(obj);
                 PyDateTime_GET_MONTH(d);

                 PyDateTime_GET_DAY(obj);
                 PyDateTime_GET_DAY(d);

                 return obj;
             """),
            ("test_datetime_macros", "METH_NOARGS",
             """
                 PyObject* obj;
                 PyDateTime_DateTime *dt;
                 PyDateTime_IMPORT;
                 if (!PyDateTimeAPI) {
                     PyErr_SetString(PyExc_RuntimeError, "No PyDateTimeAPI");
                     return NULL;
                 }
                 obj = PyDateTime_FromDateAndTime(2000, 6, 6, 6, 6, 6, 6);
                 dt = (PyDateTime_DateTime*)obj;

                 PyDateTime_GET_YEAR(obj);
                 PyDateTime_GET_YEAR(dt);

                 PyDateTime_GET_MONTH(obj);
                 PyDateTime_GET_MONTH(dt);

                 PyDateTime_GET_DAY(obj);
                 PyDateTime_GET_DAY(dt);

                 PyDateTime_DATE_GET_HOUR(obj);
                 PyDateTime_DATE_GET_HOUR(dt);

                 PyDateTime_DATE_GET_MINUTE(obj);
                 PyDateTime_DATE_GET_MINUTE(dt);

                 PyDateTime_DATE_GET_SECOND(obj);
                 PyDateTime_DATE_GET_SECOND(dt);

                 PyDateTime_DATE_GET_MICROSECOND(obj);
                 PyDateTime_DATE_GET_MICROSECOND(dt);
                
                 PyDateTime_GET_FOLD(obj);
                 PyDateTime_DATE_GET_FOLD(obj);

                 return obj;
             """),
            ("test_time_macros", "METH_NOARGS",
             """
                 PyObject* obj;
                 PyDateTime_Time* t;
                 PyDateTime_IMPORT;
                 if (!PyDateTimeAPI) {
                     PyErr_SetString(PyExc_RuntimeError, "No PyDateTimeAPI");
                     return NULL;
                 }
                 obj = PyTime_FromTime(6, 6, 6, 6);
                 t = (PyDateTime_Time*)obj;

                 PyDateTime_TIME_GET_HOUR(obj);
                 PyDateTime_TIME_GET_HOUR(t);

                 PyDateTime_TIME_GET_MINUTE(obj);
                 PyDateTime_TIME_GET_MINUTE(t);

                 PyDateTime_TIME_GET_SECOND(obj);
                 PyDateTime_TIME_GET_SECOND(t);

                 PyDateTime_TIME_GET_MICROSECOND(obj);
                 PyDateTime_TIME_GET_MICROSECOND(t);

                 return obj;
             """),
            ("test_delta_macros", "METH_NOARGS",
             """
                 PyObject* obj;
                 PyDateTime_Delta* delta;
                 PyDateTime_IMPORT;
                 if (!PyDateTimeAPI) {
                     PyErr_SetString(PyExc_RuntimeError, "No PyDateTimeAPI");
                     return NULL;
                 }
                 obj = PyDelta_FromDSU(6, 6, 6);
                 delta = (PyDateTime_Delta*)obj;

#if defined(PYPY_VERSION) || PY_VERSION_HEX >= 0x03030000
                 // These macros are only defined in CPython 3.x and PyPy.
                 // See: http://bugs.python.org/issue13727
                 PyDateTime_DELTA_GET_DAYS(obj);
                 PyDateTime_DELTA_GET_DAYS(delta);

                 PyDateTime_DELTA_GET_SECONDS(obj);
                 PyDateTime_DELTA_GET_SECONDS(delta);

                 PyDateTime_DELTA_GET_MICROSECONDS(obj);
                 PyDateTime_DELTA_GET_MICROSECONDS(delta);
#endif
                 return obj;
             """),
            ], prologue='#include "datetime.h"\n')
        import datetime
        assert module.test_date_macros() == datetime.date(2000, 6, 6)
        assert module.test_datetime_macros() == datetime.datetime(
            2000, 6, 6, 6, 6, 6, 6)
        assert module.test_time_macros() == datetime.time(6, 6, 6, 6)
        assert module.test_delta_macros() == datetime.timedelta(6, 6, 6)

    def test_tzinfo(self):
        module = self.import_extension('foo', [
            ("time_with_tzinfo", "METH_O",
             """ PyDateTime_IMPORT;
                 return PyDateTimeAPI->Time_FromTime(
                    6, 6, 6, 6, args, PyDateTimeAPI->TimeType);
             """),
            ("datetime_with_tzinfo", "METH_O",
             """
                 PyObject * obj;
                 int tzrefcnt = args->ob_refcnt;
                 PyDateTime_IMPORT;
                 obj = PyDateTimeAPI->DateTime_FromDateAndTime(
                    2000, 6, 6, 6, 6, 6, 6, args,
                    PyDateTimeAPI->DateTimeType);
                if (!((PyDateTime_DateTime*)obj)->hastzinfo)
                {
                    Py_DECREF(obj);
                    PyErr_SetString(PyExc_ValueError, "missing tzinfo");
                    return NULL;
                }
                if (((PyDateTime_DateTime*)obj)->tzinfo->ob_refcnt <= tzrefcnt)
                {
                    Py_DECREF(obj);
                    PyErr_SetString(PyExc_ValueError, "tzinfo refcnt not incremented");
                    return NULL;
                }
                return obj;

             """),
        ], prologue='#include "datetime.h"\n')
        from datetime import tzinfo, datetime, timedelta, time

        # copied from datetime documentation
        class GMT1(tzinfo):
            def __del__(self):
                print('deleting GMT1')
            def utcoffset(self, dt):
                return timedelta(hours=1) + self.dst(dt)
            def dst(self, dt):
                return timedelta(0)
            def tzname(self,dt):
                return "GMT +1"

        gmt1 = GMT1()
        dt1 = module.time_with_tzinfo(gmt1)
        assert dt1 == time(6, 6, 6, 6, gmt1)
        assert '+01' in str(dt1)
        dt_tz = module.datetime_with_tzinfo(gmt1)
        assert dt_tz == datetime(2000, 6, 6, 6, 6, 6, 6, gmt1)

    def test_checks(self):
        module = self.import_extension('foo', [
            ("checks", "METH_O",
             """ PyDateTime_IMPORT;
                 return PyTuple_Pack(10,
                    PyBool_FromLong(PyDateTime_Check(args)),
                    PyBool_FromLong(PyDateTime_CheckExact(args)),
                    PyBool_FromLong(PyDate_Check(args)),
                    PyBool_FromLong(PyDate_CheckExact(args)),
                    PyBool_FromLong(PyTime_Check(args)),
                    PyBool_FromLong(PyTime_CheckExact(args)),
                    PyBool_FromLong(PyDelta_Check(args)),
                    PyBool_FromLong(PyDelta_CheckExact(args)),
                    PyBool_FromLong(PyTZInfo_Check(args)),
                    PyBool_FromLong(PyTZInfo_CheckExact(args))
                );
             """),
        ], prologue='#include "datetime.h"\n')
        from datetime import tzinfo, datetime, timedelta, time, date
        o = date(1, 1, 1)
        assert module.checks(o) == (False,) * 2 + (True,) * 2 + (False,) * 6
        o = time(1, 1, 1)
        assert module.checks(o) == (False,) * 4 + (True,) * 2 + (False,) * 4
        o = timedelta(1, 1, 1)
        assert module.checks(o) == (False,) * 6 + (True,) * 2 + (False,) * 2
        o = datetime(1, 1, 1)
        assert module.checks(o) == (True,) * 3 + (False,) * 7 # isinstance(datetime, date)
        o = tzinfo()
        assert module.checks(o) == (False,) * 8 + (True,) * 2

