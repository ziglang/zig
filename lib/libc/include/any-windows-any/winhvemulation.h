/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _WINHVEMUAPI_H_
#define _WINHVEMUAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#include <winhvplatformdefs.h>

#if defined(__x86_64__)

typedef union WHV_EMULATOR_STATUS {
    __C89_NAMELESS struct {
        UINT32 EmulationSuccessful : 1;
        UINT32 InternalEmulationFailure : 1;
        UINT32 IoPortCallbackFailed : 1;
        UINT32 MemoryCallbackFailed : 1;
        UINT32 TranslateGvaPageCallbackFailed : 1;
        UINT32 TranslateGvaPageCallbackGpaIsNotAligned : 1;
        UINT32 GetVirtualProcessorRegistersCallbackFailed : 1;
        UINT32 SetVirtualProcessorRegistersCallbackFailed : 1;
        UINT32 InterruptCausedIntercept : 1;
        UINT32 GuestCannotBeFaulted : 1;
        UINT32 Reserved : 22;
    };
    UINT32 AsUINT32;
} WHV_EMULATOR_STATUS;

typedef struct WHV_EMULATOR_MEMORY_ACCESS_INFO {
    WHV_GUEST_PHYSICAL_ADDRESS GpaAddress;
    UINT8 Direction;
    UINT8 AccessSize;
    UINT8 Data[8];
} WHV_EMULATOR_MEMORY_ACCESS_INFO;

typedef struct WHV_EMULATOR_IO_ACCESS_INFO {
    UINT8 Direction;
    UINT16 Port;
    UINT16 AccessSize;
    UINT32 Data;
} WHV_EMULATOR_IO_ACCESS_INFO;

typedef HRESULT (CALLBACK *WHV_EMULATOR_IO_PORT_CALLBACK)(VOID *Context, WHV_EMULATOR_IO_ACCESS_INFO *IoAccess);
typedef HRESULT (CALLBACK *WHV_EMULATOR_MEMORY_CALLBACK)(VOID *Context, WHV_EMULATOR_MEMORY_ACCESS_INFO *MemoryAccess);
typedef HRESULT (CALLBACK *WHV_EMULATOR_GET_VIRTUAL_PROCESSOR_REGISTERS_CALLBACK)(VOID *Context, const WHV_REGISTER_NAME *RegisterNames, UINT32 RegisterCount, WHV_REGISTER_VALUE *RegisterValues);
typedef HRESULT (CALLBACK *WHV_EMULATOR_SET_VIRTUAL_PROCESSOR_REGISTERS_CALLBACK)(VOID *Context, const WHV_REGISTER_NAME *RegisterNames, UINT32 RegisterCount, const WHV_REGISTER_VALUE *RegisterValues);
typedef HRESULT (CALLBACK *WHV_EMULATOR_TRANSLATE_GVA_PAGE_CALLBACK)(VOID *Context, WHV_GUEST_VIRTUAL_ADDRESS Gva, WHV_TRANSLATE_GVA_FLAGS TranslateFlags, WHV_TRANSLATE_GVA_RESULT_CODE *TranslationResult, WHV_GUEST_PHYSICAL_ADDRESS *Gpa);

typedef struct WHV_EMULATOR_CALLBACKS {
    UINT32 Size;
    UINT32 Reserved;
    WHV_EMULATOR_IO_PORT_CALLBACK WHvEmulatorIoPortCallback;
    WHV_EMULATOR_MEMORY_CALLBACK WHvEmulatorMemoryCallback;
    WHV_EMULATOR_GET_VIRTUAL_PROCESSOR_REGISTERS_CALLBACK WHvEmulatorGetVirtualProcessorRegisters;
    WHV_EMULATOR_SET_VIRTUAL_PROCESSOR_REGISTERS_CALLBACK WHvEmulatorSetVirtualProcessorRegisters;
    WHV_EMULATOR_TRANSLATE_GVA_PAGE_CALLBACK WHvEmulatorTranslateGvaPage;
} WHV_EMULATOR_CALLBACKS;

typedef VOID* WHV_EMULATOR_HANDLE;

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI WHvEmulatorCreateEmulator(const WHV_EMULATOR_CALLBACKS *Callbacks, WHV_EMULATOR_HANDLE *Emulator);
HRESULT WINAPI WHvEmulatorDestroyEmulator(WHV_EMULATOR_HANDLE Emulator);
HRESULT WINAPI WHvEmulatorTryIoEmulation(WHV_EMULATOR_HANDLE Emulator, VOID *Context, const WHV_VP_EXIT_CONTEXT *VpContext, const WHV_X64_IO_PORT_ACCESS_CONTEXT *IoInstructionContext, WHV_EMULATOR_STATUS *EmulatorReturnStatus);
HRESULT WINAPI WHvEmulatorTryMmioEmulation(WHV_EMULATOR_HANDLE Emulator, VOID *Context, const WHV_VP_EXIT_CONTEXT *VpContext, const WHV_MEMORY_ACCESS_CONTEXT *MmioInstructionContext, WHV_EMULATOR_STATUS *EmulatorReturnStatus);

#ifdef __cplusplus
}
#endif

#endif  /* defined(__x86_64__) */

#endif  /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#endif
