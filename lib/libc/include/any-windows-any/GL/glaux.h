/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __GLAUX_H__
#define __GLAUX_H__

#include <windows.h>
#include <GL/gl.h>
#include <GL/glu.h>

#ifdef __cplusplus
extern "C" {
#endif

#define AUX_RGB 0
#define AUX_RGBA AUX_RGB
#define AUX_INDEX 1
#define AUX_SINGLE 0
#define AUX_DOUBLE 2
#define AUX_DIRECT 0
#define AUX_INDIRECT 4

#define AUX_ACCUM 8
#define AUX_ALPHA 16
#define AUX_DEPTH24 32
#define AUX_STENCIL 64
#define AUX_AUX 128
#define AUX_DEPTH16 256
#define AUX_FIXED_332_PAL 512
#define AUX_DEPTH AUX_DEPTH16

#define AUX_WIND_IS_RGB(x) (((x) & AUX_INDEX)==0)
#define AUX_WIND_IS_INDEX(x) (((x) & AUX_INDEX)!=0)
#define AUX_WIND_IS_SINGLE(x) (((x) & AUX_DOUBLE)==0)
#define AUX_WIND_IS_DOUBLE(x) (((x) & AUX_DOUBLE)!=0)
#define AUX_WIND_IS_INDIRECT(x) (((x) & AUX_INDIRECT)!=0)
#define AUX_WIND_IS_DIRECT(x) (((x) & AUX_INDIRECT)==0)
#define AUX_WIND_HAS_ACCUM(x) (((x) & AUX_ACCUM)!=0)
#define AUX_WIND_HAS_ALPHA(x) (((x) & AUX_ALPHA)!=0)
#define AUX_WIND_HAS_DEPTH(x) (((x) & (AUX_DEPTH24 | AUX_DEPTH16))!=0)
#define AUX_WIND_HAS_STENCIL(x) (((x) & AUX_STENCIL)!=0)
#define AUX_WIND_USES_FIXED_332_PAL(x) (((x) & AUX_FIXED_332_PAL)!=0)

typedef struct _AUX_EVENTREC {
    GLint event;
    GLint data[4];
} AUX_EVENTREC;

#define AUX_EXPOSE 1
#define AUX_CONFIG 2
#define AUX_DRAW 4
#define AUX_KEYEVENT 8
#define AUX_MOUSEDOWN 16
#define AUX_MOUSEUP 32
#define AUX_MOUSELOC 64

#define AUX_WINDOWX 0
#define AUX_WINDOWY 1
#define AUX_MOUSEX 0
#define AUX_MOUSEY 1
#define AUX_MOUSESTATUS 3
#define AUX_KEY 0
#define AUX_KEYSTATUS 1

#define AUX_LEFTBUTTON 1
#define AUX_RIGHTBUTTON 2
#define AUX_MIDDLEBUTTON 4
#define AUX_SHIFT 1
#define AUX_CONTROL 2

#define AUX_RETURN 0x0D
#define AUX_ESCAPE 0x1B
#define AUX_SPACE 0x20
#define AUX_LEFT 0x25
#define AUX_UP 0x26
#define AUX_RIGHT 0x27
#define AUX_DOWN 0x28
#define AUX_A 'A'
#define AUX_B 'B'
#define AUX_C 'C'
#define AUX_D 'D'
#define AUX_E 'E'
#define AUX_F 'F'
#define AUX_G 'G'
#define AUX_H 'H'
#define AUX_I 'I'
#define AUX_J 'J'
#define AUX_K 'K'
#define AUX_L 'L'
#define AUX_M 'M'
#define AUX_N 'N'
#define AUX_O 'O'
#define AUX_P 'P'
#define AUX_Q 'Q'
#define AUX_R 'R'
#define AUX_S 'S'
#define AUX_T 'T'
#define AUX_U 'U'
#define AUX_V 'V'
#define AUX_W 'W'
#define AUX_X 'X'
#define AUX_Y 'Y'
#define AUX_Z 'Z'
#define AUX_a 'a'
#define AUX_b 'b'
#define AUX_c 'c'
#define AUX_d 'd'
#define AUX_e 'e'
#define AUX_f 'f'
#define AUX_g 'g'
#define AUX_h 'h'
#define AUX_i 'i'
#define AUX_j 'j'
#define AUX_k 'k'
#define AUX_l 'l'
#define AUX_m 'm'
#define AUX_n 'n'
#define AUX_o 'o'
#define AUX_p 'p'
#define AUX_q 'q'
#define AUX_r 'r'
#define AUX_s 's'
#define AUX_t 't'
#define AUX_u 'u'
#define AUX_v 'v'
#define AUX_w 'w'
#define AUX_x 'x'
#define AUX_y 'y'
#define AUX_z 'z'
#define AUX_0 '0'
#define AUX_1 '1'
#define AUX_2 '2'
#define AUX_3 '3'
#define AUX_4 '4'
#define AUX_5 '5'
#define AUX_6 '6'
#define AUX_7 '7'
#define AUX_8 '8'
#define AUX_9 '9'

#define AUX_FD 1
#define AUX_COLORMAP 3
#define AUX_GREYSCALEMAP 4
#define AUX_FOGMAP 5
#define AUX_ONECOLOR 6

#define AUX_BLACK 0
#define AUX_RED 13
#define AUX_GREEN 14
#define AUX_YELLOW 15
#define AUX_BLUE 16
#define AUX_MAGENTA 17
#define AUX_CYAN 18
#define AUX_WHITE 19

extern float auxRGBMap[20][3];

#define AUX_SETCOLOR(x,y) (AUX_WIND_IS_RGB((x)) ? glColor3fv(auxRGBMap[(y)]) : glIndexf((y)))

typedef struct _AUX_RGBImageRec {
    GLint sizeX,sizeY;
    unsigned char *data;
} AUX_RGBImageRec;

void APIENTRY auxInitDisplayMode(GLenum);
void APIENTRY auxInitPosition(int,int,int,int);

#ifdef UNICODE
#define auxInitWindow auxInitWindowW
#else
#define auxInitWindow auxInitWindowA
#endif
GLenum APIENTRY auxInitWindowA(LPCSTR);
GLenum APIENTRY auxInitWindowW(LPCWSTR);

void APIENTRY auxCloseWindow(void);
void APIENTRY auxQuit(void);
void APIENTRY auxSwapBuffers(void);

typedef void (CALLBACK *AUXMAINPROC)(void);
void APIENTRY auxMainLoop(AUXMAINPROC);

typedef void (CALLBACK *AUXEXPOSEPROC)(int,int);
void APIENTRY auxExposeFunc(AUXEXPOSEPROC);

typedef void (CALLBACK *AUXRESHAPEPROC)(GLsizei,GLsizei);
void APIENTRY auxReshapeFunc(AUXRESHAPEPROC);

typedef void (CALLBACK *AUXIDLEPROC)(void);
void APIENTRY auxIdleFunc(AUXIDLEPROC);

typedef void (CALLBACK *AUXKEYPROC)(void);
void APIENTRY auxKeyFunc(int,AUXKEYPROC);

typedef void (CALLBACK *AUXMOUSEPROC)(AUX_EVENTREC *);
void APIENTRY auxMouseFunc(int,int,AUXMOUSEPROC);

int APIENTRY auxGetColorMapSize(void);
void APIENTRY auxGetMouseLoc(int *,int *);
void APIENTRY auxSetOneColor(int,float,float,float);
void APIENTRY auxSetFogRamp(int,int);
void APIENTRY auxSetGreyRamp(void);
void APIENTRY auxSetRGBMap(int,float *);

#ifdef UNICODE
#define auxRGBImageLoad auxRGBImageLoadW
#else
#define auxRGBImageLoad auxRGBImageLoadA
#endif
AUX_RGBImageRec *APIENTRY auxRGBImageLoadA(LPCSTR);
AUX_RGBImageRec *APIENTRY auxRGBImageLoadW(LPCWSTR);

#ifdef UNICODE
#define auxDIBImageLoad auxDIBImageLoadW
#else
#define auxDIBImageLoad auxDIBImageLoadA
#endif
AUX_RGBImageRec *APIENTRY auxDIBImageLoadA(LPCSTR);
AUX_RGBImageRec *APIENTRY auxDIBImageLoadW(LPCWSTR);

void APIENTRY auxCreateFont(void);

#ifdef UNICODE
#define auxDrawStr auxDrawStrW
#else
#define auxDrawStr auxDrawStrA
#endif
void APIENTRY auxDrawStrA(LPCSTR);
void APIENTRY auxDrawStrW(LPCWSTR);

void APIENTRY auxWireSphere(GLdouble);
void APIENTRY auxSolidSphere(GLdouble);
void APIENTRY auxWireCube(GLdouble);
void APIENTRY auxSolidCube(GLdouble);
void APIENTRY auxWireBox(GLdouble,GLdouble,GLdouble);
void APIENTRY auxSolidBox(GLdouble,GLdouble,GLdouble);
void APIENTRY auxWireTorus(GLdouble,GLdouble);
void APIENTRY auxSolidTorus(GLdouble,GLdouble);
void APIENTRY auxWireCylinder(GLdouble,GLdouble);
void APIENTRY auxSolidCylinder(GLdouble,GLdouble);
void APIENTRY auxWireIcosahedron(GLdouble);
void APIENTRY auxSolidIcosahedron(GLdouble);
void APIENTRY auxWireOctahedron(GLdouble);
void APIENTRY auxSolidOctahedron(GLdouble);
void APIENTRY auxWireTetrahedron(GLdouble);
void APIENTRY auxSolidTetrahedron(GLdouble);
void APIENTRY auxWireDodecahedron(GLdouble);
void APIENTRY auxSolidDodecahedron(GLdouble);
void APIENTRY auxWireCone(GLdouble,GLdouble);
void APIENTRY auxSolidCone(GLdouble,GLdouble);
void APIENTRY auxWireTeapot(GLdouble);
void APIENTRY auxSolidTeapot(GLdouble);

HWND APIENTRY auxGetHWND(void);
HDC APIENTRY auxGetHDC(void);
HGLRC APIENTRY auxGetHGLRC(void);

enum {
    AUX_USE_ID = 1,AUX_EXACT_MATCH,AUX_MINIMUM_CRITERIA
};
void APIENTRY auxInitDisplayModePolicy(GLenum);
GLenum APIENTRY auxInitDisplayModeID(GLint);
GLenum APIENTRY auxGetDisplayModePolicy(void);
GLint APIENTRY auxGetDisplayModeID(void);
GLenum APIENTRY auxGetDisplayMode(void);

#ifdef __cplusplus
}
#endif
#endif
