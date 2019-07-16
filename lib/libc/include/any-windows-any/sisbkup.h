/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __SISBKUP_H__
#define __SISBKUP_H__

#ifdef __cplusplus
extern "C" {
#endif

  WINBOOL __stdcall SisCreateBackupStructure(PWCHAR volumeRoot,PVOID *sisBackupStructure,PWCHAR *commonStoreRootPathname,PULONG countOfCommonStoreFilesToBackup,PWCHAR **commonStoreFilesToBackup);
  WINBOOL __stdcall SisCSFilesToBackupForLink(PVOID sisBackupStructure,PVOID reparseData,ULONG reparseDataSize,PVOID thisFileContext,PVOID *matchingFileContext,PULONG countOfCommonStoreFilesToBackup,PWCHAR **commonStoreFilesToBackup);
  WINBOOL __stdcall SisFreeBackupStructure(PVOID sisBackupStructure);
  WINBOOL __stdcall SisCreateRestoreStructure(PWCHAR volumeRoot,PVOID *sisRestoreStructure,PWCHAR *commonStoreRootPathname,PULONG countOfCommonStoreFilesToRestore,PWCHAR **commonStoreFilesToRestore);
  WINBOOL __stdcall SisRestoredLink(PVOID sisRestoreStructure,PWCHAR restoredFileName,PVOID reparseData,ULONG reparseDataSize,PULONG countOfCommonStoreFilesToRestore,PWCHAR **commonStoreFilesToRestore);
  WINBOOL __stdcall SisRestoredCommonStoreFile(PVOID sisRestoreStructure,PWCHAR commonStoreFileName);
  WINBOOL __stdcall SisFreeRestoreStructure(PVOID sisRestoreStructure);
  VOID __stdcall SisFreeAllocatedMemory(PVOID allocatedSpace);

  typedef WINBOOL (__stdcall *PF_SISCREATEBACKUPSTRUCTURE)(PWCHAR,PVOID *,PWCHAR *,PULONG,PWCHAR **);
  typedef WINBOOL (__stdcall *PF_SISCSFILESTOBACKUPFORLINK) (PVOID,PVOID,ULONG,PVOID,PVOID *,PULONG,PWCHAR **);
  typedef WINBOOL (__stdcall *PF_SISFREEBACKUPSTRUCTURE) (PVOID);
  typedef WINBOOL (__stdcall *PF_SISCREATERESTORESTRUCTURE) (PWCHAR,PVOID *,PWCHAR *,PULONG,PWCHAR **);
  typedef WINBOOL (__stdcall *PF_SISRESTOREDLINK) (PVOID,PWCHAR,PVOID,ULONG,PULONG,PWCHAR **);
  typedef WINBOOL (__stdcall *PF_SISRESTOREDCOMMONSTORFILE) (PVOID,PWCHAR);
  typedef WINBOOL (__stdcall *PF_SISFREERESTORESTRUCTURE)(PVOID);
  typedef WINBOOL (__stdcall *PF_SISFREEALLOCATEDMEMORY)(PVOID);

#ifdef __cplusplus
}
#endif
#endif
