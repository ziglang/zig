# C bindings with libtcl and libtk.

from cffi import FFI
import sys, os

# XXX find a better way to detect paths
# XXX pick up CPPFLAGS and LDFLAGS and add to these paths?
if sys.platform.startswith("openbsd"):
    incdirs = ['/usr/local/include/tcl8.5', '/usr/local/include/tk8.5', '/usr/X11R6/include']
    linklibs = ['tk85', 'tcl85']
    libdirs = ['/usr/local/lib', '/usr/X11R6/lib']
elif sys.platform.startswith("freebsd"):
    incdirs = ['/usr/local/include/tcl8.6', '/usr/local/include/tk8.6', '/usr/local/include/X11', '/usr/local/include']
    linklibs = ['tk86', 'tcl86']
    libdirs = ['/usr/local/lib']
elif sys.platform == 'win32':
    incdirs = []
    linklibs = ['tcl86t', 'tk86t']
    libdirs = []
elif sys.platform == 'darwin':
    # homebrew
    incdirs = ['/usr/local/opt/tcl-tk/include']
    linklibs = ['tcl8.6', 'tk8.6']
    libdirs = ['/usr/local/opt/tcl-tk/lib']
else:
    # On some Linux distributions, the tcl and tk libraries are
    # stored in /usr/include, so we must check this case also
    libdirs = []
    found = False
    for _ver in ['', '8.6', '8.5']:
        incdirs = ['/usr/include/tcl' + _ver]
        linklibs = ['tcl' + _ver, 'tk' + _ver]
        if os.path.isdir(incdirs[0]):
            found = True
            break
    if not found:
        for _ver in ['8.6', '8.5', '']:
            incdirs = []
            linklibs = ['tcl' + _ver, 'tk' + _ver]
            for lib in ['/usr/lib/lib', '/usr/lib64/lib']: 
                if os.path.isfile(''.join([lib, linklibs[1], '.so'])):
                    found = True
                    break
            if found:
                break
    if not found:
        sys.stderr.write("*** TCL libraries not found!  Falling back...\n")
        incdirs = []
        linklibs = ['tcl', 'tk']

config_ffi = FFI()
config_ffi.cdef("""
#define TK_HEX_VERSION ...
#define HAVE_WIDE_INT_TYPE ...
""")
config_lib = config_ffi.verify("""
#include <tk.h>
#define TK_HEX_VERSION ((TK_MAJOR_VERSION << 24) | \
                        (TK_MINOR_VERSION << 16) | \
                        (TK_RELEASE_LEVEL << 8) | \
                        (TK_RELEASE_SERIAL << 0))
#ifdef TCL_WIDE_INT_TYPE
#define HAVE_WIDE_INT_TYPE 1
#else
#define HAVE_WIDE_INT_TYPE 0
#endif
""",
include_dirs=incdirs,
libraries=linklibs,
library_dirs = libdirs
)

TK_HEX_VERSION = config_lib.TK_HEX_VERSION

HAVE_LIBTOMMATH = int((0x08050208 <= TK_HEX_VERSION < 0x08060000) or
                      (0x08060200 <= TK_HEX_VERSION))
HAVE_WIDE_INT_TYPE = config_lib.HAVE_WIDE_INT_TYPE

tkffi = FFI()

tkffi.cdef("""
char *get_tk_version();
char *get_tcl_version();
#define HAVE_LIBTOMMATH ...
#define HAVE_WIDE_INT_TYPE ...

#define TCL_READABLE ...
#define TCL_WRITABLE ...
#define TCL_EXCEPTION ...
#define TCL_ERROR ...
#define TCL_OK ...

#define TCL_LEAVE_ERR_MSG ...
#define TCL_GLOBAL_ONLY ...
#define TCL_EVAL_DIRECT ...
#define TCL_EVAL_GLOBAL ...

#define TCL_DONT_WAIT ...

typedef unsigned short Tcl_UniChar;
typedef ... Tcl_Interp;
typedef ...* Tcl_ThreadId;
typedef ...* Tcl_Command;

typedef struct Tcl_ObjType {
    const char *name;
    ...;
} Tcl_ObjType;
typedef struct Tcl_Obj {
    char *bytes;
    int length;
    const Tcl_ObjType *typePtr;
    union {                     /* The internal representation: */
        long longValue;         /*   - an long integer value. */
        double doubleValue;     /*   - a double-precision floating value. */
        struct {                /*   - internal rep as two pointers. */
            void *ptr1;
            void *ptr2;
        } twoPtrValue;
    } internalRep;
    ...;
} Tcl_Obj;

Tcl_Interp *Tcl_CreateInterp();
void Tcl_DeleteInterp(Tcl_Interp* interp);
int Tcl_Init(Tcl_Interp* interp);
int Tk_Init(Tcl_Interp* interp);

void Tcl_Free(void* ptr);

const char *Tcl_SetVar(Tcl_Interp* interp, const char* varName, const char* newValue, int flags);
const char *Tcl_SetVar2(Tcl_Interp* interp, const char* name1, const char* name2, const char* newValue, int flags);
const char *Tcl_GetVar(Tcl_Interp* interp, const char* varName, int flags);
Tcl_Obj *Tcl_SetVar2Ex(Tcl_Interp* interp, const char* name1, const char* name2, Tcl_Obj* newValuePtr, int flags);
Tcl_Obj *Tcl_GetVar2Ex(Tcl_Interp* interp, const char* name1, const char* name2, int flags);
int Tcl_UnsetVar2(Tcl_Interp* interp, const char* name1, const char* name2, int flags);
const Tcl_ObjType *Tcl_GetObjType(const char* typeName);

Tcl_Obj *Tcl_NewStringObj(const char* bytes, int length);
Tcl_Obj *Tcl_NewUnicodeObj(const Tcl_UniChar* unicode, int numChars);
Tcl_Obj *Tcl_NewLongObj(long longValue);
Tcl_Obj *Tcl_NewBooleanObj(int boolValue);
Tcl_Obj *Tcl_NewDoubleObj(double doubleValue);

void Tcl_IncrRefCount(Tcl_Obj* objPtr);
void Tcl_DecrRefCount(Tcl_Obj* objPtr);

int Tcl_GetBoolean(Tcl_Interp* interp, const char* src, int* boolPtr);
int Tcl_GetInt(Tcl_Interp* interp, const char* src, int* intPtr);
int Tcl_GetDouble(Tcl_Interp* interp, const char* src, double* doublePtr);
int Tcl_GetBooleanFromObj(Tcl_Interp* interp, Tcl_Obj* objPtr, int* valuePtr);
char *Tcl_GetString(Tcl_Obj* objPtr);
char *Tcl_GetStringFromObj(Tcl_Obj* objPtr, int* lengthPtr);
unsigned char *Tcl_GetByteArrayFromObj(Tcl_Obj* objPtr, int* lengthPtr);
Tcl_Obj *Tcl_NewByteArrayObj(unsigned char *bytes, int length);

int Tcl_ExprBoolean(Tcl_Interp* interp, const char *expr, int *booleanPtr);
int Tcl_ExprLong(Tcl_Interp* interp, const char *expr, long* longPtr);
int Tcl_ExprDouble(Tcl_Interp* interp, const char *expr, double* doublePtr);
int Tcl_ExprString(Tcl_Interp* interp, const char *expr);

Tcl_UniChar *Tcl_GetUnicode(Tcl_Obj* objPtr);
int Tcl_GetCharLength(Tcl_Obj* objPtr);

Tcl_Obj *Tcl_NewListObj(int objc, Tcl_Obj* const objv[]);
int Tcl_ListObjGetElements(Tcl_Interp *interp, Tcl_Obj *listPtr, int *objcPtr, Tcl_Obj ***objvPtr);
int Tcl_ListObjLength(Tcl_Interp* interp, Tcl_Obj* listPtr, int* intPtr);
int Tcl_ListObjIndex(Tcl_Interp* interp, Tcl_Obj* listPtr, int index, Tcl_Obj** objPtrPtr);
int Tcl_SplitList(Tcl_Interp* interp, char* list, int* argcPtr, const char*** argvPtr);
char* Tcl_Merge(int argc, char** argv);

int Tcl_Eval(Tcl_Interp* interp, const char* script);
int Tcl_EvalFile(Tcl_Interp* interp, const char* filename);
int Tcl_EvalObjv(Tcl_Interp* interp, int objc, Tcl_Obj** objv, int flags);
Tcl_Obj *Tcl_GetObjResult(Tcl_Interp* interp);
const char *Tcl_GetStringResult(Tcl_Interp* interp);
void Tcl_SetObjResult(Tcl_Interp* interp, Tcl_Obj* objPtr);

typedef void* ClientData;
typedef int Tcl_CmdProc(
        ClientData clientData,
        Tcl_Interp *interp,
        int argc,
        const char *argv[]);
typedef void Tcl_CmdDeleteProc(
        ClientData clientData);
Tcl_Command Tcl_CreateCommand(Tcl_Interp* interp, const char* cmdName, Tcl_CmdProc proc, ClientData clientData, Tcl_CmdDeleteProc deleteProc);
int Tcl_DeleteCommand(Tcl_Interp* interp, const char* cmdName);

Tcl_ThreadId Tcl_GetCurrentThread();
int Tcl_DoOneEvent(int flags);

int Tk_GetNumMainWindows();
void Tcl_FindExecutable(char *argv0);
""")

if HAVE_WIDE_INT_TYPE:
    tkffi.cdef("""
typedef int... Tcl_WideInt;

int Tcl_GetWideIntFromObj(Tcl_Interp *interp, Tcl_Obj *obj, Tcl_WideInt *value);
Tcl_Obj *Tcl_NewWideIntObj(Tcl_WideInt value);
""")

if HAVE_LIBTOMMATH:
    tkffi.cdef("""
#define MP_OKAY ...
#define MP_ZPOS ...
#define MP_NEG ...
typedef struct {
    int sign;
    ...;
} mp_int;

int Tcl_GetBignumFromObj(Tcl_Interp *interp, Tcl_Obj *obj, mp_int *value);
Tcl_Obj *Tcl_NewBignumObj(mp_int *value);

int mp_unsigned_bin_size(mp_int *a);
int mp_to_unsigned_bin_n(mp_int * a, unsigned char *b, unsigned long *outlen);
int mp_read_radix(mp_int *a, const char *str, int radix);
int mp_init(mp_int *a);
void mp_clear(mp_int *a);
""")

tkffi.set_source("_tkinter.tklib_cffi", """
#define HAVE_LIBTOMMATH %(HAVE_LIBTOMMATH)s
#define HAVE_WIDE_INT_TYPE %(HAVE_WIDE_INT_TYPE)s
#include <tcl.h>
#include <tk.h>

#if HAVE_LIBTOMMATH
#include <tclTomMath.h>
#endif 

char *get_tk_version(void) { return TK_VERSION; }
char *get_tcl_version(void) { return TCL_VERSION; }
""" % globals(),
include_dirs=incdirs,
libraries=linklibs,
library_dirs = libdirs
)

if __name__ == "__main__":
    tkffi.compile(os.path.join(os.path.dirname(sys.argv[0]), '..'))
