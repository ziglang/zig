#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <ws2tcpip.h>

WCHAR *gai_strerrorW(int ecode)
{
	DWORD dwMsgLen __attribute__((unused));
	static WCHAR buff[GAI_STRERROR_BUFFER_SIZE + 1];
	dwMsgLen = FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM|FORMAT_MESSAGE_IGNORE_INSERTS|FORMAT_MESSAGE_MAX_WIDTH_MASK,
				  NULL, ecode, MAKELANGID(LANG_NEUTRAL,SUBLANG_DEFAULT), (LPWSTR)buff,
				  GAI_STRERROR_BUFFER_SIZE, NULL);
	return buff;
}
