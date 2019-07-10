#ifdef TEST_FTRUNCATE64
#include <fcntl.h>
#include <sys/stat.h>
#endif /* TEST_FTRUNCATE64 */

#include <stdio.h>
#include <unistd.h>
#include <io.h>
#include <stdlib.h>
#include <errno.h>
#include <wchar.h>
#include <windows.h>
#include <psapi.h>

/* Mutually exclusive methods
  We check disk space as truncating more than the allowed space results
  in file getting mysteriously deleted
 */
#define _CHECK_SPACE_BY_VOLUME_METHOD_ 1 /* Needs to walk through all volumes */
#define _CHECK_SPACE_BY_PSAPI_METHOD_ 0 /* Requires psapi.dll */
#define _CHECK_SPACE_BY_VISTA_METHOD_ 0 /* Won't work on XP */

#if (_CHECK_SPACE_BY_PSAPI_METHOD_ == 1) /* Retrive actual volume path */
static LPWSTR getdirpath(const LPWSTR __str){
  int len, walk = 0;
  LPWSTR dirname;
  while (__str[walk] != L'\0'){
    walk++;
    if (__str[walk] == L'\\') len = walk + 1;
  }
  dirname = calloc(len + 1, sizeof(wchar_t));
  if (!dirname) return dirname; /* memory error */
  return wcsncpy(dirname,__str,len);
}

static LPWSTR xp_normalize_fn(const LPWSTR fn) {
  DWORD len, err, walker, isfound;
  LPWSTR drives = NULL;
  LPWSTR target = NULL;
  LPWSTR ret = NULL;
  wchar_t tmplt[3] = L" :"; /* Template */

  /*Get list of drive letters */
  len = GetLogicalDriveStringsW(0,NULL);
  drives = calloc(len,sizeof(wchar_t));
  if (!drives) return NULL;
  len = GetLogicalDriveStringsW(len,drives);

  /*Allocatate memory */
  target = calloc(MAX_PATH + 1,sizeof(wchar_t));
  if (!target) {
    free(drives);
    return NULL;
  }

  walker = 0;
  while ((walker < len) && !(drives[walker] == L'\0' && drives[walker + 1] == L'\0')){
    /* search through alphabets */
    if(iswalpha(drives[walker])) {
      *tmplt = drives[walker]; /* Put drive letter */
      err = QueryDosDeviceW(tmplt,target,MAX_PATH);
      if(!err) {
        free(drives);
        free(target);
        return NULL;
      }
      if( _wcsnicmp(target,fn,wcslen(target)) == 0) break;
      wmemset(target,L'\0',MAX_PATH);
      walker++;
    } else walker++;
  }

  if (!iswalpha(*tmplt)) {
    free(drives);
    free(target);
    return NULL; /* Finish walking without finding correct drive */
  }

  ret = calloc(MAX_PATH + 1,sizeof(wchar_t));
  if (!ret) {
    free(drives);
    free(target);
    return NULL;
  }
  _snwprintf(ret,MAX_PATH,L"%ws%ws",tmplt,fn+wcslen(target));

  return ret;
}

/* XP method of retrieving filename from handles, based on:
  http://msdn.microsoft.com/en-us/library/aa366789%28VS.85%29.aspx
 */
static LPWSTR xp_getfilepath(const HANDLE f, const LARGE_INTEGER fsize){
  HANDLE hFileMap = NULL;
  void* pMem = NULL;
  LPWSTR temp, ret;
  DWORD err;

  temp = calloc(MAX_PATH + 1, sizeof(wchar_t));
  if (!temp) goto errormap;

  /* CreateFileMappingW limitation: Cannot map 0 byte files, so extend it to 1 byte */
  if (!fsize.QuadPart) {
    SetFilePointer(f, 1, NULL, FILE_BEGIN);
    err = SetEndOfFile(f);
    if(!temp) goto errormap;
  }

  hFileMap = CreateFileMappingW(f,NULL,PAGE_READONLY,0,1,NULL);
  if(!hFileMap) goto errormap;
  pMem = MapViewOfFile(hFileMap, FILE_MAP_READ, 0, 0, 1);
  if(!pMem) goto errormap;
  err = GetMappedFileNameW(GetCurrentProcess(),pMem,temp,MAX_PATH);
  if(!err) goto errormap;

  if (pMem) UnmapViewOfFile(pMem);
  if (hFileMap) CloseHandle(hFileMap);
  ret = xp_normalize_fn(temp);
  free(temp);
  return ret;

  errormap:
  if (temp) free(temp);
  if (pMem) UnmapViewOfFile(pMem);
  if (hFileMap) CloseHandle(hFileMap);
  _set_errno(EBADF);
  return NULL;
}
#endif /* _CHECK_SPACE_BY_PSAPI_METHOD_ */

static int
checkfreespace (const HANDLE f, const ULONGLONG requiredspace)
{
  LPWSTR dirpath, volumeid, volumepath;
  ULARGE_INTEGER freespace;
  LARGE_INTEGER currentsize;
  DWORD check, volumeserial;
  BY_HANDLE_FILE_INFORMATION fileinfo;
  HANDLE vol;

  /* Get current size */
  check = GetFileSizeEx (f, &currentsize);
  if (!check)
  {
    _set_errno(EBADF);
    return -1; /* Error checking file size */
  }

  /* Short circuit disk space check if shrink operation */
  if ((ULONGLONG)currentsize.QuadPart >= requiredspace)
    return 0;

  /* We check available space to user before attempting to truncate */

#if (_CHECK_SPACE_BY_VISTA_METHOD_ == 1)
  /* Get path length */
  DWORD err;
  LPWSTR filepath = NULL;
  check = GetFinalPathNameByHandleW(f,filepath,0,FILE_NAME_NORMALIZED|VOLUME_NAME_GUID);
  err = GetLastError();
  if (err == ERROR_PATH_NOT_FOUND || err == ERROR_INVALID_PARAMETER) {
     _set_errno(EINVAL);
     return -1; /* IO error */
  }
  filepath = calloc(check + 1,sizeof(wchar_t));
  if (!filepath) {
    _set_errno(EBADF);
    return -1; /* Out of memory */
  }
  check = GetFinalPathNameByHandleW(f,filepath,check,FILE_NAME_NORMALIZED|VOLUME_NAME_GUID);
  /* FIXME: last error was set to error 87 (0x57)
  "The parameter is incorrect." for some reason but works out */
  if (!check) {
    _set_errno(EBADF);
    return -1; /* Error resolving filename */
  }
#endif /* _CHECK_SPACE_BY_VISTA_METHOD_ */

#if (_CHECK_SPACE_BY_PSAPI_METHOD_ ==  1)
  LPWSTR filepath = NULL;
  filepath = xp_getfilepath(f,currentsize);

  /* Get durectory path */
  dirpath = getdirpath(filepath);
  free(filepath);
  filepath =  NULL;
  if (!dirpath) {
    _set_errno(EBADF);
    return -1; /* Out of memory */
  }
#endif /* _CHECK_SPACE_BY_PSAPI_METHOD_ */

#if _CHECK_SPACE_BY_VOLUME_METHOD_
  if(!GetFileInformationByHandle(f,&fileinfo)) {
    _set_errno(EINVAL);
    return -1; /* Resolution failure */
  }

  volumeid = calloc(51,sizeof(wchar_t));
  volumepath = calloc(MAX_PATH+2,sizeof(wchar_t));
  if(!volumeid || !volumepath) {
  _set_errno(EBADF);
    return -1; /* Out of memory */
  }

  dirpath = NULL;

  vol = FindFirstVolumeW(volumeid,50);
  /* wprintf(L"%d - %ws\n",wcslen(volumeid),volumeid); */
  do {
    check = GetVolumeInformationW(volumeid,volumepath,MAX_PATH+1,&volumeserial,NULL,NULL,NULL,0);
    /* wprintf(L"GetVolumeInformationW %d id %ws path %ws error %d\n",check,volumeid,volumepath,GetLastError()); */
    if(volumeserial == fileinfo.dwVolumeSerialNumber) {
      dirpath = volumeid; 
      break;
    }
  } while (FindNextVolumeW(vol,volumeid,50));
  FindVolumeClose(vol);

  if(!dirpath) free(volumeid); /* we found the volume */
  free(volumepath);
#endif /* _CHECK_SPACE_BY_VOLUME_METHOD_ */

  /* Get available free space */
  check = GetDiskFreeSpaceExW(dirpath,&freespace,NULL,NULL);
  //wprintf(L"freespace %I64u\n",freespace);
  free(dirpath);
  if(!check) {
    _set_errno(EFBIG);
    return -1; /* Error getting free space */
  }
 
  /* Check space requirements */
  if ((requiredspace - currentsize.QuadPart) > freespace.QuadPart)
  {
    _set_errno(EFBIG); /* File too big for disk */
    return -1;
  } /* We have enough space to truncate/expand */
  return 0;
}

int ftruncate64(int __fd, _off64_t __length) {
  HANDLE f;
  LARGE_INTEGER quad;
  DWORD check;
  int ret = 0;
  __int64 pos;

  /* Sanity check */
  if (__length < 0) {
    goto errorout;
  }

  /* Get Win32 Handle */
  if(__fd == -1) {
    goto errorout;
  }

  f = (HANDLE)_get_osfhandle(__fd);
  if (f == INVALID_HANDLE_VALUE || (GetFileType(f) != FILE_TYPE_DISK)) {
    _set_errno(EBADF);
    return -1;
  }


  /* Save position */
  if((pos = _telli64(__fd)) == -1LL){
    goto errorout;
  }

  /* Check available space */
  check = checkfreespace(f,__length);
  if (check != 0) {
    return -1; /* Error, errno already set */
  }

  quad.QuadPart = __length;
  check = SetFilePointer(f, (LONG)quad.LowPart, &(quad.HighPart), FILE_BEGIN);
  if (check == INVALID_SET_FILE_POINTER && quad.LowPart != INVALID_SET_FILE_POINTER) {
    switch (GetLastError()) {
      case ERROR_NEGATIVE_SEEK:
        _set_errno(EFBIG); /* file too big? */
        return -1;
      case INVALID_SET_FILE_POINTER:
        _set_errno(EINVAL); /* shouldn't happen */
        return -1;
      default:
        _set_errno(EINVAL); /* shouldn't happen */
        return -1;
    }
  }

  check = SetEndOfFile(f);
  if (!check) {
    goto errorout;
  }

  if(_lseeki64(__fd,pos,SEEK_SET) == -1LL){
    goto errorout;
  }

  return ret;

  errorout:
  _set_errno(EINVAL);
  return -1;
}

#if (TEST_FTRUNCATE64 == 1)
int main(){
  LARGE_INTEGER sz;
  ULARGE_INTEGER freespace;
  int f;
  LPWSTR path, dir;
  sz.QuadPart = 0LL;
  f = _open("XXX.tmp", _O_BINARY|_O_CREAT|_O_RDWR, _S_IREAD | _S_IWRITE);
  wprintf(L"%d\n",ftruncate64(f,12));
  wprintf(L"%d\n",ftruncate64(f,20));
  wprintf(L"%d\n",ftruncate64(f,15));
/*  path = xp_getfilepath((HANDLE)_get_osfhandle(f),sz);
  dir = getdirpath(path);
  GetDiskFreeSpaceExW(dir,&freespace,NULL,NULL);
  wprintf(L"fs - %ws\n",path);
  wprintf(L"dirfs - %ws\n",dir);
  wprintf(L"free - %I64u\n",freespace.QuadPart);
  free(dir);
  free(path);*/
  _close(f);
  return 0;
}
#endif /* TEST_FTRUNCATE64 */

#if (TEST_FTRUNCATE64 == 2)
int main() {
FILE *f;
int fd;
char buf[100];
int cnt;
unlink("test.out");
f = fopen("test.out","w+");
fd = fileno(f);
write(fd,"abc",3);
fflush(f);
printf ("err: %d\n", ftruncate64(fd,10));
cnt = read(fd,buf,100);
printf("cnt = %d\n",cnt);
return 0;
}
#endif /* TEST_FTRUNCATE64 */

#if (TEST_FTRUNCATE64 == 3)
int main() {
FILE *f;
int fd;
char buf[100];
int cnt;
unlink("test.out");
f = fopen("test.out","w+");
fd = fileno(f);
write(fd,"abc",3);
fflush(f);
ftruncate64(fd,0);
write(fd,"def",3);
fclose(f);
f = fopen("test.out","r");
cnt = fread(buf,1,100,f);
printf("cnt = %d\n",cnt);
return 0;
}
#endif /* TEST_FTRUNCATE64 */

