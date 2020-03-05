/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WSLAPI_H_
#define _WSLAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <wtypes.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

BOOL WslIsDistributionRegistered(PCWSTR distributionName);
HRESULT WslRegisterDistribution(PCWSTR distributionName, PCWSTR tarGzFilename);
HRESULT WslUnregisterDistribution(PCWSTR distributionName);

typedef enum {
    WSL_DISTRIBUTION_FLAGS_NONE = 0x0,
    WSL_DISTRIBUTION_FLAGS_ENABLE_INTEROP = 0x1,
    WSL_DISTRIBUTION_FLAGS_APPEND_NT_PATH = 0x2,
    WSL_DISTRIBUTION_FLAGS_ENABLE_DRIVE_MOUNTING = 0x4
} WSL_DISTRIBUTION_FLAGS;

#define WSL_DISTRIBUTION_FLAGS_VALID (WSL_DISTRIBUTION_FLAGS_ENABLE_INTEROP | WSL_DISTRIBUTION_FLAGS_APPEND_NT_PATH | WSL_DISTRIBUTION_FLAGS_ENABLE_DRIVE_MOUNTING)
#define WSL_DISTRIBUTION_FLAGS_DEFAULT (WSL_DISTRIBUTION_FLAGS_ENABLE_INTEROP | WSL_DISTRIBUTION_FLAGS_APPEND_NT_PATH | WSL_DISTRIBUTION_FLAGS_ENABLE_DRIVE_MOUNTING)

HRESULT WslConfigureDistribution(PCWSTR distributionName, ULONG defaultUID, WSL_DISTRIBUTION_FLAGS wslDistributionFlags);
HRESULT WslGetDistributionConfiguration(PCWSTR distributionName, ULONG* distributionVersion, ULONG* defaultUID, WSL_DISTRIBUTION_FLAGS* wslDistributionFlags, PSTR** defaultEnvironmentVariables, ULONG* defaultEnvironmentVariableCount);
HRESULT WslLaunchInteractive(PCWSTR distributionName, PCWSTR command, BOOL useCurrentWorkingDirectory, DWORD* exitCode);
HRESULT WslLaunch(PCWSTR distributionName, PCWSTR command, BOOL useCurrentWorkingDirectory, HANDLE stdIn, HANDLE stdOut, HANDLE stdErr, HANDLE* process);

#endif
#ifdef __cplusplus
}
#endif
#endif
