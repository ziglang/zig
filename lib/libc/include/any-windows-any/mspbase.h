#ifndef __MSPBASE_H_
#define __MSPBASE_H_

#define _ATL_FREE_THREADED

#include <atlbase.h>

extern CComModule _Module;

#include <atlcom.h>
#include <tapi.h>

#include <strmif.h>
#include <control.h>
#include <uuids.h>

#include <termmgr.h>

#include <msp.h>
#include <tapi3err.h>
#include <tapi3if.h>

EXTERN_C const IID LIBID_TAPI3Lib;

#include "mspenum.h"
#include "msplog.h"
#include "msputils.h"
#include "mspaddr.h"
#include "mspcall.h"
#include "mspstrm.h"
#include "mspthrd.h"
#include "mspcoll.h"

#include "mspterm.h"
#include "msptrmac.h"
#include "msptrmar.h"
#include "msptrmvc.h"

#endif
