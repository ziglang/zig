
/************************************************************/
 /***  C header subsection: support functions              ***/

#ifndef _SRC_SUPPORT_H
#define _SRC_SUPPORT_H

#define RUNNING_ON_LLINTERP	0
#define OP_JIT_RECORD_EXACT_CLASS(i, c, r)  /* nothing */

#define FAIL_OVF(msg) _RPyRaiseSimpleException(RPyExc_OverflowError)

/* Extra checks can be enabled with the RPY_ASSERT or RPY_LL_ASSERT
 * macros.  They differ in the level at which the tests are made.
 * Remember that RPython lists, for example, are implemented as a
 * GcStruct pointing to an over-allocated GcArray.  With RPY_ASSERT you
 * get list index out of bound checks from rlist.py; such tests must be
 * manually written so made we've forgotten a case.  Conversely, with
 * RPY_LL_ASSERT, all GcArray indexing are checked, which is safer
 * against attacks and segfaults - but less precise in the case of
 * lists, because of the overallocated bit.
 *
 * For extra safety, in programs translated with --sandbox we always
 * assume that we want RPY_LL_ASSERT.  You can change it below to trade
 * safety for performance, though the hit is not huge (~10%?).
 */
#ifdef RPY_ASSERT
#  define RPyAssert(x, msg)                                             \
     if (!(x)) RPyAssertFailed(__FILE__, __LINE__, __FUNCTION__, msg)

RPY_EXTERN
void RPyAssertFailed(const char* filename, long lineno,
                     const char* function, const char *msg);
#else
#  define RPyAssert(x, msg)   /* nothing */
#endif

RPY_EXTERN
void RPyAbort(void);

RPY_EXTERN
double _PyPy_dg_stdnan(int sign);

#if defined(RPY_LL_ASSERT) || defined(RPY_SANDBOXED)
/* obscure macros that can be used as expressions and lvalues to refer
 * to a field of a structure or an item in an array in a "safe" way --
 * they abort() in case of null pointer or out-of-bounds index.  As a
 * speed trade-off, RPyItem actually segfaults if the array is null, but
 * it's a "guaranteed" segfault and not one that can be used by
 * attackers.
 */
#  define RPyCHECK(x)           ((x)?(void)0:RPyAbort())
#  define RPyField(ptr, name)   ((RPyCHECK(ptr), (ptr))->name)
#  define RPyItem(array, index)                                             \
     ((RPyCHECK((index) >= 0 && (index) < (array)->length),                 \
      (array))->items[index])
#  define RPyFxItem(ptr, index, fixedsize)                                  \
     ((RPyCHECK((ptr) != NULL && (index) >= 0 && (index) < (fixedsize)),    \
      (ptr))[index])
#  define RPyNLenItem(array, index)                                         \
     ((RPyCHECK((array) != NULL && (index) >= 0), (array))->items[index])
#  define RPyBareItem(array, index)                                         \
     ((RPyCHECK((array) != NULL && (index) >= 0), (array))[index])

#else
#  define RPyField(ptr, name)                ((ptr)->name)
#  define RPyItem(array, index)              ((array)->items[index])
#  define RPyFxItem(ptr, index, fixedsize)   ((ptr)[index])
#  define RPyNLenItem(array, index)          ((array)->items[index])
#  define RPyBareItem(array, index)          ((array)[index])
#endif

#endif  /* _SRC_SUPPORT_H */
