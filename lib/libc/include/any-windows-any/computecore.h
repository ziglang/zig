/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _HYPERV_COMPUTECORE_H_
#define _HYPERV_COMPUTECORE_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#include <computedefs.h>

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI HcsEnumerateComputeSystems (PCWSTR query, HCS_OPERATION operation);
HRESULT WINAPI HcsEnumerateComputeSystemsInNamespace (PCWSTR idNamespace, PCWSTR query, HCS_OPERATION operation);
HCS_OPERATION WINAPI HcsCreateOperation (const void *context, HCS_OPERATION_COMPLETION callback);
void WINAPI HcsCloseOperation (HCS_OPERATION operation);
void* WINAPI HcsGetOperationContext (HCS_OPERATION operation);
HRESULT WINAPI HcsSetOperationContext (HCS_OPERATION operation, const void *context);
HCS_SYSTEM WINAPI HcsGetComputeSystemFromOperation (HCS_OPERATION operation);
HCS_PROCESS WINAPI HcsGetProcessFromOperation (HCS_OPERATION operation);
HCS_OPERATION_TYPE WINAPI HcsGetOperationType (HCS_OPERATION operation);
UINT64 WINAPI HcsGetOperationId (HCS_OPERATION operation);
HRESULT WINAPI HcsGetOperationResult (HCS_OPERATION operation, PWSTR *resultDocument);
HRESULT WINAPI HcsGetOperationResultAndProcessInfo (HCS_OPERATION operation, HCS_PROCESS_INFORMATION *processInformation, PWSTR *resultDocument);
HRESULT WINAPI HcsGetProcessorCompatibilityFromSavedState (PCWSTR RuntimeFileName, PCWSTR *ProcessorFeaturesString);
HRESULT WINAPI HcsWaitForOperationResult (HCS_OPERATION operation, DWORD timeoutMs, PWSTR *resultDocument);
HRESULT WINAPI HcsWaitForOperationResultAndProcessInfo (HCS_OPERATION operation, DWORD timeoutMs, HCS_PROCESS_INFORMATION *processInformation, PWSTR *resultDocument);
HRESULT WINAPI HcsSetOperationCallback (HCS_OPERATION operation, const void *context, HCS_OPERATION_COMPLETION callback);
HRESULT WINAPI HcsCancelOperation (HCS_OPERATION operation);
HRESULT WINAPI HcsCreateComputeSystem (PCWSTR id, PCWSTR configuration, HCS_OPERATION operation, const SECURITY_DESCRIPTOR *securityDescriptor, HCS_SYSTEM *computeSystem);
HRESULT WINAPI HcsCreateComputeSystemInNamespace (PCWSTR idNamespace, PCWSTR id, PCWSTR configuration, HCS_OPERATION operation, const HCS_CREATE_OPTIONS *options, HCS_SYSTEM *computeSystem);
HRESULT WINAPI HcsOpenComputeSystem (PCWSTR id, DWORD requestedAccess, HCS_SYSTEM *computeSystem);
HRESULT WINAPI HcsOpenComputeSystemInNamespace (PCWSTR idNamespace, PCWSTR id, DWORD requestedAccess, HCS_SYSTEM *computeSystem);
void WINAPI HcsCloseComputeSystem (HCS_SYSTEM computeSystem);
HRESULT WINAPI HcsStartComputeSystem (HCS_SYSTEM computeSystem, HCS_OPERATION operation, PCWSTR options);
HRESULT WINAPI HcsShutDownComputeSystem (HCS_SYSTEM computeSystem, HCS_OPERATION operation, PCWSTR options);
HRESULT WINAPI HcsTerminateComputeSystem (HCS_SYSTEM computeSystem, HCS_OPERATION operation, PCWSTR options);
HRESULT WINAPI HcsCrashComputeSystem (HCS_SYSTEM computeSystem, HCS_OPERATION operation, PCWSTR options);
HRESULT WINAPI HcsPauseComputeSystem (HCS_SYSTEM computeSystem, HCS_OPERATION operation, PCWSTR options);
HRESULT WINAPI HcsResumeComputeSystem (HCS_SYSTEM computeSystem, HCS_OPERATION operation, PCWSTR options);
HRESULT WINAPI HcsSaveComputeSystem (HCS_SYSTEM computeSystem, HCS_OPERATION operation, PCWSTR options);
HRESULT WINAPI HcsGetComputeSystemProperties (HCS_SYSTEM computeSystem, HCS_OPERATION operation, PCWSTR propertyQuery);
HRESULT WINAPI HcsModifyComputeSystem (HCS_SYSTEM computeSystem, HCS_OPERATION operation, PCWSTR configuration, HANDLE identity);
HRESULT WINAPI HcsWaitForComputeSystemExit (HCS_SYSTEM computeSystem, DWORD timeoutMs, PWSTR *result);
HRESULT WINAPI HcsSetComputeSystemCallback (HCS_SYSTEM computeSystem, HCS_EVENT_OPTIONS callbackOptions, const void *context, HCS_EVENT_CALLBACK callback);
HRESULT WINAPI HcsCreateProcess (HCS_SYSTEM computeSystem, PCWSTR processParameters, HCS_OPERATION operation, const SECURITY_DESCRIPTOR *securityDescriptor, HCS_PROCESS *process);
HRESULT WINAPI HcsOpenProcess (HCS_SYSTEM computeSystem, DWORD processId, DWORD requestedAccess, HCS_PROCESS *process);
void WINAPI HcsCloseProcess (HCS_PROCESS process);
HRESULT WINAPI HcsTerminateProcess (HCS_PROCESS process, HCS_OPERATION operation, PCWSTR options);
HRESULT WINAPI HcsSignalProcess (HCS_PROCESS process, HCS_OPERATION operation, PCWSTR options);
HRESULT WINAPI HcsGetProcessInfo (HCS_PROCESS process, HCS_OPERATION operation);
HRESULT WINAPI HcsGetProcessProperties (HCS_PROCESS process, HCS_OPERATION operation, PCWSTR propertyQuery);
HRESULT WINAPI HcsModifyProcess (HCS_PROCESS process, HCS_OPERATION operation, PCWSTR settings);
HRESULT WINAPI HcsSetProcessCallback (HCS_PROCESS process, HCS_EVENT_OPTIONS callbackOptions, void *context, HCS_EVENT_CALLBACK callback);
HRESULT WINAPI HcsWaitForProcessExit (HCS_PROCESS computeSystem, DWORD timeoutMs, PWSTR *result);
HRESULT WINAPI HcsGetServiceProperties (PCWSTR propertyQuery, PWSTR *result);
HRESULT WINAPI HcsModifyServiceSettings (PCWSTR settings, PWSTR *result);
HRESULT WINAPI HcsSubmitWerReport (PCWSTR settings);
HRESULT WINAPI HcsCreateEmptyGuestStateFile (PCWSTR guestStateFilePath);
HRESULT WINAPI HcsCreateEmptyRuntimeStateFile (PCWSTR runtimeStateFilePath);
HRESULT WINAPI HcsGrantVmAccess (PCWSTR vmId, PCWSTR filePath);
HRESULT WINAPI HcsRevokeVmAccess (PCWSTR vmId, PCWSTR filePath);
HRESULT WINAPI HcsGrantVmGroupAccess (PCWSTR filePath);
HRESULT WINAPI HcsRevokeVmGroupAccess (PCWSTR filePath);

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_PARTITION_DESKTOP */

#endif /* _HYPERV_COMPUTECORE_H_ */
