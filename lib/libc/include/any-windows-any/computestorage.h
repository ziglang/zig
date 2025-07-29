/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _HYPERV_COMPUTESTORAGE_H_
#define _HYPERV_COMPUTESTORAGE_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI HcsImportLayer (PCWSTR layerPath, PCWSTR sourceFolderPath, PCWSTR layerData);
HRESULT WINAPI HcsExportLayer (PCWSTR layerPath, PCWSTR exportFolderPath, PCWSTR layerData, PCWSTR options);
HRESULT WINAPI HcsExportLegacyWritableLayer (PCWSTR writableLayerMountPath, PCWSTR writableLayerFolderPath, PCWSTR exportFolderPath, PCWSTR layerData);
HRESULT WINAPI HcsDestroyLayer (PCWSTR layerPath);
HRESULT WINAPI HcsSetupBaseOSLayer (PCWSTR layerPath, HANDLE vhdHandle, PCWSTR options);
HRESULT WINAPI HcsInitializeWritableLayer (PCWSTR writableLayerPath, PCWSTR layerData, PCWSTR options);
HRESULT WINAPI HcsInitializeLegacyWritableLayer (PCWSTR writableLayerMountPath, PCWSTR writableLayerFolderPath, PCWSTR layerData, PCWSTR options);
HRESULT WINAPI HcsAttachLayerStorageFilter (PCWSTR layerPath, PCWSTR layerData);
HRESULT WINAPI HcsDetachLayerStorageFilter (PCWSTR layerPath);
HRESULT WINAPI HcsFormatWritableLayerVhd (HANDLE vhdHandle);
HRESULT WINAPI HcsGetLayerVhdMountPath (HANDLE vhdHandle, PWSTR *mountPath);
HRESULT WINAPI HcsSetupBaseOSVolume (PCWSTR layerPath, PCWSTR volumePath, PCWSTR options);
HRESULT WINAPI HcsAttachOverlayFilter (PCWSTR VolumeMountPoint, PCWSTR LayerData);
HRESULT WINAPI HcsDetachOverlayFilter (PCWSTR VolumeMountPoint, PCWSTR LayerData);

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_PARTITION_DESKTOP */

#endif /* _HYPERV_COMPUTESTORAGE_H_ */
