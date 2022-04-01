/* Define structure for C API. */
typedef struct {
    /* type objects */
    PyTypeObject *DateType;
    PyTypeObject *DateTimeType;
    PyTypeObject *TimeType;
    PyTypeObject *DeltaType;
    PyTypeObject *TZInfoType;

    /* singletons */
    PyObject *TimeZone_UTC;

    /* constructors */
    PyObject *(*Date_FromDate)(int, int, int, PyTypeObject*);
    PyObject *(*DateTime_FromDateAndTime)(int, int, int, int, int, int, int,
        PyObject*, PyTypeObject*);
    PyObject *(*Time_FromTime)(int, int, int, int, PyObject*, PyTypeObject*);
    PyObject *(*Delta_FromDelta)(int, int, int, int, PyTypeObject*);
    PyObject *(*TimeZone_FromTimeZone)(PyObject*, PyObject*);

    /* constructors for the DB API */
    PyObject *(*DateTime_FromTimestamp)(PyObject*, PyObject*, PyObject*);
    PyObject *(*Date_FromTimestamp)(PyObject*, PyObject*);

    /* PEP 495 constructors */
    PyObject *(*DateTime_FromDateAndTimeAndFold)(int, int, int, int, int, int, int,
        PyObject*, int, PyTypeObject*);
    PyObject *(*Time_FromTimeAndFold)(int, int, int, int, PyObject*, int, PyTypeObject*);

} PyDateTime_CAPI;

typedef struct
{
    PyObject_HEAD
    int days;                   /* -MAX_DELTA_DAYS <= days <= MAX_DELTA_DAYS */
    int seconds;                /* 0 <= seconds < 24*3600 is invariant */
    int microseconds;           /* 0 <= microseconds < 1000000 is invariant */
} PyDateTime_Delta;

/* The datetime and time types have an optional tzinfo member,
 * PyNone if hastzinfo is false.
 */
typedef struct
{
    PyObject_HEAD
    unsigned char hastzinfo;
    PyObject *tzinfo;
} PyDateTime_Time;

typedef struct
{
    PyObject_HEAD
    unsigned char hastzinfo;
    PyObject *tzinfo;
} PyDateTime_DateTime;


typedef struct {
    PyObject_HEAD
} PyDateTime_Date;


typedef struct {
    PyObject_HEAD
} PyDateTime_TZInfo;

