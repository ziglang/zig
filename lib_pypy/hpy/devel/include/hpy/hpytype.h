#ifndef HPY_UNIVERSAL_HPYTYPE_H
#define HPY_UNIVERSAL_HPYTYPE_H

#include <stdbool.h>
#ifdef __GNUC__
#define HPyAPI_UNUSED __attribute__((unused)) static inline
#else
#define HPyAPI_UNUSED static inline
#endif /* __GNUC__ */

typedef struct {
    const char* name;
    int basicsize;
    int itemsize;
    unsigned long flags;
    int legacy;
    void *legacy_slots; // PyType_Slot *
    HPyDef **defines;   /* points to an array of 'HPyDef *' */
    const char* doc;    /* UTF-8 doc string or NULL */
} HPyType_Spec;

typedef enum {
    HPyType_SpecParam_Base = 1,
    HPyType_SpecParam_BasesTuple = 2,
    //HPyType_SpecParam_Metaclass = 3,
    //HPyType_SpecParam_Module = 4,
} HPyType_SpecParam_Kind;

typedef struct {
    HPyType_SpecParam_Kind kind;
    HPy object;
} HPyType_SpecParam;

/* All types are dynamically allocated */
#define _Py_TPFLAGS_HEAPTYPE (1UL << 9)
#define _Py_TPFLAGS_HAVE_VERSION_TAG (1UL << 18)
#define HPy_TPFLAGS_DEFAULT (_Py_TPFLAGS_HEAPTYPE | _Py_TPFLAGS_HAVE_VERSION_TAG)

/* HPy_TPFLAGS_INTERNAL_PURE is set automatically on pure types created with
   HPyType_FromSpec. This flag should not be used directly. Set
   `.legacy = false` or `.legacy = true` instead.

   A custom type is a pure type if its struct does not include PyObject_HEAD.
   A type whose struct does start with PyObject_HEAD is a legacy type. A
   legacy type must set .legacy = true in its HPyType_Spec.

   A type with .legacy_slots not NULL is required to have .legacy = true and to
   include PyObject_HEAD at the start of its struct. It would be easy to
   relax this requirement on CPython (where the PyObject_HEAD fields are
   always present) but a large burden on other implementations (e.g. PyPy,
   GraalPython) where a struct starting with PyObject_HEAD might not exist.

   Types that do not define a struct of their own, should set the value of
   .legacy to the same value as the type they inherit from. If they inherit
   from a built-in type, they may .legacy to either true or false, depending on
   whether they still use .legacy_slots or not.

   Types created via the old Python C API are automatically legacy types.

   Note on the choice of bit 8: Bit 8 looks likely to be the last free TPFLAG
   bit that C Python will allocate. Bits 0 to 8 were dropped in Python 3.0 and
   are being re-allocated slowly from 0 towards 8. As of 3.10, only bit 0 has
   been re-allocated.
*/
#define HPy_TPFLAGS_INTERNAL_PURE (1UL << 8)

/* Set if the type allows subclassing */
#define HPy_TPFLAGS_BASETYPE (1UL << 10)


/* A macro for creating (static inline) helper functions for custom types.

   Two versions of the helper exist. One for legacy types and one for pure
   HPy types.

   Example for a pure HPy custom type:

       HPyType_HELPERS(PointObject)

   This would generate the following:

   * `PointObject * PointObject_AsStruct(HPyContext *ctx, HPy h)`: a static
     inline function that uses HPy_AsStruct to return the PointObject struct
     associated with a given handle. The behaviour is undefined if `h`
     is associated with an object that is not an instance of PointObject.

   * `PointObject_IS_LEGACY`: an enum value set to 0 so that in the
     HPyType_Spec for PointObject one can write
     `.legacy = PointObject_IS_LEGACY` and not have to remember to
     update the spec when the helpers used changes.

   Example for a legacy custom type:

       HPyType_LEGACY_HELPERS(PointObject)

   This would generate the same functions and constants as above, except:

   * `HPy_AsStructLegacy` is used instead of `HPy_AsStruct`.

   * `PointObject_IS_LEGACY` is set to 1.
*/

#define HPyType_HELPERS(TYPE) \
    _HPyType_GENERIC_HELPERS(TYPE, HPy_AsStruct, 0)

#define HPyType_LEGACY_HELPERS(TYPE) \
    _HPyType_GENERIC_HELPERS(TYPE, HPy_AsStructLegacy, 1)

#define _HPyType_GENERIC_HELPERS(TYPE, CAST, IS_LEGACY)              \
                                                                     \
enum { TYPE##_IS_LEGACY = IS_LEGACY };                               \
                                                                     \
HPyAPI_UNUSED TYPE *                                                 \
TYPE##_AsStruct(HPyContext *ctx, HPy h)                              \
{                                                                    \
    return (TYPE*) CAST(ctx, h);                                     \
}

#endif /* HPY_UNIVERSAL_HPYTYPE_H */
