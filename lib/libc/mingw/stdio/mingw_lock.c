#define _CRTIMP
#include <stdio.h>
#include <synchapi.h>
#include "internal.h"

/***
 * Copy of MS functions _lock_file, _unlock_file which are missing from
 * msvcrt.dll and msvcr80.dll. They are needed to atomic/lock stdio
 * functions (printf, fprintf, vprintf, vfprintf). We need exactly the same
 * lock that MS uses in msvcrt.dll because we can mix mingw-w64 code with
 * original MS functions (puts, fputs for example).
***/ 


_CRTIMP void __cdecl _lock(int locknum);
_CRTIMP void __cdecl _unlock(int locknum);
#define _STREAM_LOCKS   16
#define _IOLOCKED       0x8000


/***
* _lock_file - Lock a FILE
*
*Purpose:
*       Assert the lock for a stdio-level file
*
*Entry:
*       pf = __piob[] entry (pointer to a FILE or _FILEX)
*
*Exit:
*
*Exceptions:
*
*******************************************************************************/

void __cdecl _lock_file( FILE *pf )
{
    /*
     * The way the FILE (pointed to by pf) is locked depends on whether
     * it is part of _iob[] or not
     */
    if ( (pf >= __acrt_iob_func(0)) && (pf <= __acrt_iob_func(_IOB_ENTRIES-1)) )
    {
        /*
         * FILE lies in _iob[] so the lock lies in _locktable[].
         */
        _lock( _STREAM_LOCKS + (int)(pf - __acrt_iob_func(0)) );
        /* We set _IOLOCKED to indicate we locked the stream */
        pf->_flag |= _IOLOCKED;
    }
    else
        /*
         * Not part of _iob[]. Therefore, *pf is a _FILEX and the
         * lock field of the struct is an initialized critical
         * section.
         */
        EnterCriticalSection( &(((_FILEX *)pf)->lock) );
}

void *__MINGW_IMP_SYMBOL(_lock_file) = _lock_file;


/***
* _unlock_file - Unlock a FILE
*
*Purpose:
*       Release the lock for a stdio-level file
*
*Entry:
*       pf = __piob[] entry (pointer to a FILE or _FILEX)
*
*Exit:
*
*Exceptions:
*
*******************************************************************************/

void __cdecl _unlock_file( FILE *pf )
{
    /*
     * The way the FILE (pointed to by pf) is unlocked depends on whether
     * it is part of _iob[] or not
     */
    if ( (pf >= __acrt_iob_func(0)) && (pf <= __acrt_iob_func(_IOB_ENTRIES-1)) )
    {
        /*
         * FILE lies in _iob[] so the lock lies in _locktable[].
         * We reset _IOLOCKED to indicate we unlock the stream.
         */
        pf->_flag &= ~_IOLOCKED;
        _unlock( _STREAM_LOCKS + (int)(pf - __acrt_iob_func(0)) );
    }
    else
        /*
         * Not part of _iob[]. Therefore, *pf is a _FILEX and the
         * lock field of the struct is an initialized critical
         * section.
         */
        LeaveCriticalSection( &(((_FILEX *)pf)->lock) );
}

void *__MINGW_IMP_SYMBOL(_unlock_file) = _unlock_file;
