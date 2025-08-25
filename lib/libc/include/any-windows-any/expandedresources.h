/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef __EXPANDEDRESOURCES_H__
#define __EXPANDEDRESOURCES_H__

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI GetExpandedResourceExclusiveCpuCount(ULONG *exclusiveCpuCount);
HRESULT WINAPI HasExpandedResources(BOOL *hasExpandedResources);
HRESULT WINAPI ReleaseExclusiveCpuSets(VOID);

#ifdef __cplusplus
}
#endif

#endif /* __EXPANDEDRESOURCES_H__ */
