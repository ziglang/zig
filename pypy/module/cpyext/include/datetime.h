#ifndef DATETIME_H
#define DATETIME_H
#ifdef __cplusplus
extern "C" {
#endif

#include "cpyext_datetime.h"

PyAPI_DATA(PyDateTime_CAPI*) PyDateTimeAPI;

#define PyDateTime_IMPORT (PyDateTimeAPI = _PyDateTime_Import())

/* Macro for access to the UTC singleton */
#define PyDateTime_TimeZone_UTC PyDateTimeAPI->TimeZone_UTC

/* Macros for accessing constructors in a simplified fashion. */
#define PyDate_FromDate(year, month, day) \
    PyDateTimeAPI->Date_FromDate(year, month, day, PyDateTimeAPI->DateType)

#define PyDateTime_FromDateAndTime(year, month, day, hour, min, sec, usec) \
    PyDateTimeAPI->DateTime_FromDateAndTime(year, month, day, hour, \
        min, sec, usec, Py_None, PyDateTimeAPI->DateTimeType)

#define PyDateTime_FromDateAndTimeAndFold(year, month, day, hour, min, sec, usec, fold) \
    PyDateTimeAPI->DateTime_FromDateAndTimeAndFold(year, month, day, hour, \
        min, sec, usec, Py_None, fold, PyDateTimeAPI->DateTimeType)

#define PyTime_FromTime(hour, minute, second, usecond) \
    PyDateTimeAPI->Time_FromTime(hour, minute, second, usecond, \
        Py_None, PyDateTimeAPI->TimeType)

#define PyTime_FromTimeAndFold(hour, minute, second, usecond, fold) \
    PyDateTimeAPI->Time_FromTimeAndFold(hour, minute, second, usecond, \
        Py_None, fold, PyDateTimeAPI->TimeType)

#define PyDelta_FromDSU(days, seconds, useconds) \
    PyDateTimeAPI->Delta_FromDelta(days, seconds, useconds, 1, \
        PyDateTimeAPI->DeltaType)

#define PyTimeZone_FromOffset(offset) \
    PyDateTimeAPI->TimeZone_FromTimeZone(offset, NULL)

#define PyTimeZone_FromOffsetAndName(offset, name) \
    PyDateTimeAPI->TimeZone_FromTimeZone(offset, name)

#define PyDateTime_TimeZone_UTC PyDateTimeAPI->TimeZone_UTC

/* Issue 3627: PEP 495 defines PyDateTime_GET_FOLD but CPython implemented
 * PyDateTime_DATE_GET_FOLD
 */
#define PyDateTime_DATE_GET_FOLD PyDateTime_GET_FOLD

#ifdef __cplusplus
}
#endif
#endif
