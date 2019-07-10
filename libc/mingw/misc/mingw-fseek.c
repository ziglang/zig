/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <windows.h>
#include <stdio.h>
#include <io.h>
#include <stdlib.h>

#define ZEROBLOCKSIZE 512
static int __mingw_fseek_called;

int __mingw_fseek (FILE *fp, int offset, int whence);

int
__mingw_fseek (FILE *fp, int offset, int whence)
{
# undef fseek 
  __mingw_fseek_called = 1;
  return fseek (fp, offset, whence);
}

int __mingw_fseeko64 (FILE *fp, long offset, int whence);

int
__mingw_fseeko64 (FILE *fp, long offset, int whence)
{
# undef fseeko64
  __mingw_fseek_called = 1;
  return fseeko64 (fp, offset, whence);
}

size_t __mingw_fwrite (const void *buffer, size_t size, size_t count, FILE *fp);

size_t
__mingw_fwrite (const void *buffer, size_t size, size_t count, FILE *fp)
{
# undef fwrite 
  if ((_osver & 0x8000) &&  __mingw_fseek_called)
    {
      ULARGE_INTEGER actual_length;
      LARGE_INTEGER current_position;

      memset (&current_position, 0, sizeof (LARGE_INTEGER));
      __mingw_fseek_called = 0;
      fflush (fp);
      actual_length.LowPart = GetFileSize ((HANDLE) _get_osfhandle (fileno (fp)), 
					   &actual_length.HighPart);
      if (actual_length.LowPart == 0xFFFFFFFF 
          && GetLastError() != NO_ERROR )
        return -1;
      current_position.LowPart = SetFilePointer ((HANDLE) _get_osfhandle (fileno (fp)),
                                         	 current_position.LowPart,
					 	 &current_position.HighPart,
						 FILE_CURRENT);
      if (current_position.LowPart == 0xFFFFFFFF
          && GetLastError() != NO_ERROR )
        return -1;

#ifdef DEBUG
      printf ("__mingw_fwrite: current %I64u, actual %I64u\n", 
	      current_position.QuadPart, actual_length.QuadPart);
#endif /* DEBUG */
      if ((size_t)current_position.QuadPart > (size_t)actual_length.QuadPart)
	{
	  static char __mingw_zeros[ZEROBLOCKSIZE];
	  long long numleft;

	  SetFilePointer ((HANDLE) _get_osfhandle (fileno (fp)), 
	                  0, 0, FILE_END);
	  numleft = current_position.QuadPart - actual_length.QuadPart;

#ifdef DEBUG
	  printf ("__mingw_fwrite: Seeking %I64d bytes past end\n", numleft);
#endif /* DEBUG */
	  while (numleft > 0LL)
	    {
	      DWORD nzeros = (numleft > ZEROBLOCKSIZE)
	                     ? ZEROBLOCKSIZE : numleft;
	      DWORD written;
	      if (! WriteFile ((HANDLE) _get_osfhandle (fileno (fp)),
	                       __mingw_zeros, nzeros, &written, NULL))
	        {
		  /* Best we can hope for, or at least DJ says so. */
	          SetFilePointer ((HANDLE) _get_osfhandle (fileno (fp)), 
	                          0, 0, FILE_BEGIN);
		  return -1;
		}
	      if (written < nzeros)
	        {
		  /* Likewise. */
	          SetFilePointer ((HANDLE) _get_osfhandle (fileno (fp)), 
	                          0, 0, FILE_BEGIN);
		  return -1;
		}

	      numleft -= written;
	    }
	    FlushFileBuffers ((HANDLE) _get_osfhandle (fileno (fp)));
	}
    }
  return fwrite (buffer, size, count, fp);
}
