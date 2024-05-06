/*

	dxerr8.c - DirectX 8 Error Functions

	Written by Filip Navara <xnavara@volny.cz>

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

*/

#define DXGetErrorString	DXGetErrorString8A
#define DXGetErrorDescription	DXGetErrorDescription8A
#define DXTrace	DXTraceA
#define DXERROR8(v,n,d) {v, n, d},
#define DXERROR8LAST(v,n,d) {v, n, d}
#include "dxerr.c"
