/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _PARSER_H
#define _PARSER_H

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#include <stdio.h>

#undef CLASS_IMPORT_EXPORT
#ifdef HHCTRL
#define CLASS_IMPORT_EXPORT
#elif defined (HHSETUP)
#define CLASS_IMPORT_EXPORT __declspec (dllexport)
#else
#define CLASS_IMPORT_EXPORT __declspec (dllimport)
#endif

#define PARSER_API_INLINE
#define MAX_LINE_LEN 1024

#define F_OK 0
#define F_NOFILE 1
#define F_READ 2
#define F_WRITE 3
#define F_MEMORY 4
#define F_EOF 5
#define F_END 6
#define F_TAGMISSMATCH 7
#define F_MISSINGENDTAG 8
#define F_NOTFOUND 9
#define F_NOPARENT 10
#define F_NULL 11
#define F_NOTITLE 12
#define F_LOCATION 13
#define F_REFERENCED 14
#define F_DUPLICATE 15
#define F_DELETE 16
#define F_CLOSE 17
#define F_EXISTCHECK 19

class CParseXML {
private:
  CHAR m_cCurToken[MAX_LINE_LEN];
  CHAR m_cCurWord[MAX_LINE_LEN];
  CHAR m_cCurBuffer[MAX_LINE_LEN];
  FILE *m_fh;
  CHAR *m_pCurrentIndex;
  DWORD m_dwError;
private:
  DWORD Read ();
  DWORD SetError (DWORD dw) { m_dwError = dw; return m_dwError; }
public:
  CParseXML () {
    m_fh = NULL;
    m_cCurBuffer[0] = '\0';
    m_pCurrentIndex = NULL;
    m_dwError = F_OK;
  }
  ~CParseXML () {
    End ();
  }
  CHAR *GetFirstWord (CHAR *);
  CHAR *GetValue (CHAR *);
  DWORD Start (const CHAR *szFile);
  void End ();
  CHAR *GetToken ();
  DWORD GetError () { return m_dwError; }
};

typedef struct fifo {
  CHAR *string;
  fifo *prev;
} FIFO;

class CLASS_IMPORT_EXPORT CFIFOString {
private:
  FIFO *m_fifoTail;
public:
  CFIFOString () { m_fifoTail = NULL; }
  ~CFIFOString ();
  void RemoveAll ();
  DWORD AddTail (CHAR *sz);
  DWORD GetTail (PZPSTR sz);
};
#endif

#endif
