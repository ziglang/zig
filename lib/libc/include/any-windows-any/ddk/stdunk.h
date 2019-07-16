/*
    ReactOS Kernel-Mode COM
    IUnknown implementations

    This file is in the public domain.

    AUTHORS
        Andrew Greenwood
*/

#ifndef STDUNK_H
#define STDUNK_H

#include <punknown.h>

/* ===============================================================
    INonDelegatingUnknown interface
*/

DECLARE_INTERFACE(INonDelegatingUnknown)
{
    STDMETHOD_(NTSTATUS, NonDelegatingQueryInterface)( THIS_
        IN  REFIID,
        OUT PVOID*) PURE;

    STDMETHOD_(ULONG, NonDelegatingAddRef)( THIS ) PURE;
    STDMETHOD_(ULONG, NonDelegatingRelease)( THIS ) PURE;
};

typedef INonDelegatingUnknown *PNONDELEGATINGUNKNOWN;


/* ===============================================================
    CUnknown declaration / definition

    There are 2 variants for this, and I'm not sure if the C
    version is correct.
*/

#ifdef __cplusplus

class CUnknown : public INonDelegatingUnknown
{
    private :
        LONG m_ref_count;
        PUNKNOWN m_outer_unknown;

    public :
        /* CUnknown */
        CUnknown(PUNKNOWN pUnknownOuter);
        virtual ~CUnknown();

        PUNKNOWN GetOuterUnknown()
        { return m_outer_unknown; }

        /* INonDelegatingUnknown */
        STDMETHODIMP_(ULONG) NonDelegatingAddRef();
        STDMETHODIMP_(ULONG) NonDelegatingRelease();

        STDMETHODIMP_(NTSTATUS) NonDelegatingQueryInterface(
            REFIID  rIID,
            PVOID* ppVoid);
};

#define DECLARE_STD_UNKNOWN() \
    STDMETHODIMP_(NTSTATUS) NonDelegatingQueryInterface( \
        REFIID iid, \
        PVOID* ppvObject); \
\
    STDMETHODIMP_(NTSTATUS) QueryInterface( \
        REFIID riid, \
        void** ppv) \
    { \
        return GetOuterUnknown()->QueryInterface(riid, ppv); \
    } \
\
    STDMETHODIMP_(ULONG) AddRef() \
    { \
        return GetOuterUnknown()->AddRef(); \
    } \
\
    STDMETHODIMP_(ULONG) Release() \
    { \
        return GetOuterUnknown()->Release(); \
    }

#define DEFINE_STD_CONSTRUCTOR(classname) \
    classname(PUNKNOWN outer_unknown) \
    : CUnknown(outer_unknown) \
    { }

#else   /* Not C++ - this is probably very buggy... */

NTSTATUS
STDMETHODCALLTYPE
Unknown_QueryInterface(
    IUnknown* this,
    IN  REFIID refiid,
    OUT PVOID* output);

ULONG
STDMETHODCALLTYPE
Unknown_AddRef(
    IUnknown* unknown_this);

ULONG
STDMETHODCALLTYPE
Unknown_Release(
    IUnknown* unknown_this);

typedef struct CUnknown
{
    __GNU_EXTENSION union
    {
        IUnknown IUnknown;
        INonDelegatingUnknown INonDelegatingUnknown;
    };

    LONG m_ref_count;
    PUNKNOWN m_outer_unknown;
} CUnknown;

#endif  /* __cplusplus */



#ifdef __cplusplus


/* ===============================================================
    Construction helpers
*/

#define QICAST(typename) \
    PVOID( (typename) (this) )

#define QICASTUNKNOWN(typename) \
    PVOID( PUNKNOWN( (typename) (this) ) )

#define STD_CREATE_BODY_WITH_TAG_(classname, unknown, outer_unknown, pool_type, tag, base) \
    classname *new_ptr = new(pool_type, tag) classname(outer_unknown); \
\
    if ( ! new_ptr ) \
        return STATUS_INSUFFICIENT_RESOURCES; \
\
    *unknown = PUNKNOWN((base)(new_ptr)); \
    (*unknown)->AddRef(); \
    return STATUS_SUCCESS

#define STD_CREATE_BODY_WITH_TAG(classname, unknown, outer_unknown, pool_type, tag, base) \
    STD_CREATE_BODY_WITH_TAG_(classname, unknown, outer_unknown, pool_type, tag, PUNKNOWN)

#define STD_CREATE_BODY_(classname, unknown, outer_unknown, pool_type, base) \
    STD_CREATE_BODY_WITH_TAG_(classname, unknown, outer_unknown, pool_type, 'rCcP', base)

#define STD_CREATE_BODY(classname, unknown, outer_unknown, pool_type) \
    STD_CREATE_BODY_(classname, unknown, outer_unknown, pool_type, PUNKNOWN)


/* ===============================================================
    Custom "new" and "delete" C++ operators
*/

#ifndef _NEW_DELETE_OPERATORS_
#define _NEW_DELETE_OPERATORS_

inline PVOID
KCOM_New(
    size_t size,
    POOL_TYPE pool_type,
    ULONG tag)
{
    PVOID result;

    result = ExAllocatePoolWithTag(pool_type, size, tag);

    if ( result )
        RtlZeroMemory(result, size);

    return result;
}

inline PVOID
operator new (
    size_t  size,
    POOL_TYPE pool_type)
{
    return KCOM_New(size, pool_type, 'wNcP');
}

inline PVOID
operator new (
    size_t size,
    POOL_TYPE pool_type,
    ULONG tag)
{
    return KCOM_New(size, pool_type, tag);
}

inline void __cdecl
operator delete(
    PVOID ptr)
{
    ExFreePool(ptr);
}

#endif  /* ALLOCATION_OPERATORS_DEFINED */


#else   /* Being compiled with C */


#endif  /* __cplusplus */

#endif  /* include guard */
