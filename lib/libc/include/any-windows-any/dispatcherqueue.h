/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _DISPATCHERQUEUE_H_
#define _DISPATCHERQUEUE_H_

#include <windows.system.h>

enum DISPATCHERQUEUE_THREAD_APARTMENTTYPE {
    DQTAT_COM_NONE = 0,
    DQTAT_COM_ASTA = 1,
    DQTAT_COM_STA  = 2
};

enum DISPATCHERQUEUE_THREAD_TYPE {
    DQTYPE_THREAD_DEDICATED = 1,
    DQTYPE_THREAD_CURRENT   = 2
};

struct DispatcherQueueOptions {
    DWORD                                dwSize;
    DISPATCHERQUEUE_THREAD_TYPE          threadType;
    DISPATCHERQUEUE_THREAD_APARTMENTTYPE apartmentType;
};

EXTERN_C HRESULT WINAPI CreateDispatcherQueueController(DispatcherQueueOptions,ABI::Windows::System::IDispatcherQueueController**);

#endif /* _DISPATCHERQUEUE_H_ */
