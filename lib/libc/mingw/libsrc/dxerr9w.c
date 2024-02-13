/*

	dxerr9w.c - DirectX 9 Wide Character Error Functions

	Written by Filip Navara <xnavara@volny.cz>

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

*/

#define UNICODE
#define _UNICODE
#define DXGetErrorString	DXGetErrorString9W
#define DXGetErrorDescription	DXGetErrorDescription9W
#define DXTrace	DXTraceW
#define DXERROR9(v,n,d) {v, L##n, L##d},
#define DXERROR9LAST(v,n,d) {v, L##n, L##d}
#include "dxerr.c"

