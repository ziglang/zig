/*	$NetBSD: wsksymdef.h,v 1.77 2021/09/22 17:37:32 nia Exp $ */

/*-
 * Copyright (c) 1997 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Juergen Hannken-Illjes.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _DEV_WSCONS_WSKSYMDEF_H_
#define _DEV_WSCONS_WSKSYMDEF_H_

/*
 * Keysymbols encoded as 16-bit Unicode. Special symbols
 * are encoded in the private area (0xe000 - 0xf8ff).
 * Currently only ISO Latin-1 subset is supported.
 *
 * This file is parsed from userland. Encode keysyms as:
 *
 *	#define KS_[^ \t]* 0x[0-9a-f]*
 *
 * and don't modify the border comments.
 */


/*BEGINKEYSYMDECL*/

/*
 * Group Ascii (ISO Latin1) character in low byte
 */

#define	KS_BackSpace 		0x08
#define	KS_Tab 			0x09
#define	KS_Linefeed 		0x0a
#define	KS_Clear 		0x0b
#define	KS_Return 		0x0d
#define	KS_Escape 		0x1b
#define	KS_space 		0x20
#define	KS_exclam 		0x21
#define	KS_quotedbl 		0x22
#define	KS_numbersign 		0x23
#define	KS_dollar 		0x24
#define	KS_percent 		0x25
#define	KS_ampersand 		0x26
#define	KS_apostrophe 		0x27
#define	KS_parenleft 		0x28
#define	KS_parenright 		0x29
#define	KS_asterisk 		0x2a
#define	KS_plus 		0x2b
#define	KS_comma 		0x2c
#define	KS_minus 		0x2d
#define	KS_period 		0x2e
#define	KS_slash 		0x2f
#define	KS_0 			0x30
#define	KS_1 			0x31
#define	KS_2 			0x32
#define	KS_3 			0x33
#define	KS_4 			0x34
#define	KS_5 			0x35
#define	KS_6 			0x36
#define	KS_7 			0x37
#define	KS_8 			0x38
#define	KS_9 			0x39
#define	KS_colon 		0x3a
#define	KS_semicolon 		0x3b
#define	KS_less 		0x3c
#define	KS_equal 		0x3d
#define	KS_greater 		0x3e
#define	KS_question 		0x3f
#define	KS_at 			0x40
#define	KS_A 			0x41
#define	KS_B 			0x42
#define	KS_C 			0x43
#define	KS_D 			0x44
#define	KS_E 			0x45
#define	KS_F 			0x46
#define	KS_G 			0x47
#define	KS_H 			0x48
#define	KS_I 			0x49
#define	KS_J 			0x4a
#define	KS_K 			0x4b
#define	KS_L 			0x4c
#define	KS_M 			0x4d
#define	KS_N 			0x4e
#define	KS_O 			0x4f
#define	KS_P 			0x50
#define	KS_Q 			0x51
#define	KS_R 			0x52
#define	KS_S 			0x53
#define	KS_T 			0x54
#define	KS_U 			0x55
#define	KS_V 			0x56
#define	KS_W 			0x57
#define	KS_X 			0x58
#define	KS_Y 			0x59
#define	KS_Z 			0x5a
#define	KS_bracketleft 		0x5b
#define	KS_backslash 		0x5c
#define	KS_bracketright 	0x5d
#define	KS_asciicircum 		0x5e
#define	KS_underscore 		0x5f
#define	KS_grave 		0x60
#define	KS_a 			0x61
#define	KS_b 			0x62
#define	KS_c 			0x63
#define	KS_d 			0x64
#define	KS_e 			0x65
#define	KS_f 			0x66
#define	KS_g 			0x67
#define	KS_h 			0x68
#define	KS_i 			0x69
#define	KS_j 			0x6a
#define	KS_k 			0x6b
#define	KS_l 			0x6c
#define	KS_m 			0x6d
#define	KS_n 			0x6e
#define	KS_o 			0x6f
#define	KS_p 			0x70
#define	KS_q 			0x71
#define	KS_r 			0x72
#define	KS_s 			0x73
#define	KS_t 			0x74
#define	KS_u 			0x75
#define	KS_v 			0x76
#define	KS_w 			0x77
#define	KS_x 			0x78
#define	KS_y 			0x79
#define	KS_z 			0x7a
#define	KS_braceleft 		0x7b
#define	KS_bar 			0x7c
#define	KS_braceright 		0x7d
#define	KS_asciitilde 		0x7e
#define	KS_Delete 		0x7f
#define	KS_nobreakspace 	0xa0
#define	KS_exclamdown 		0xa1
#define	KS_cent 		0xa2
#define	KS_sterling 		0xa3
#define	KS_currency 		0xa4
#define	KS_yen 			0xa5
#define	KS_brokenbar 		0xa6
#define	KS_section 		0xa7
#define	KS_diaeresis 		0xa8
#define	KS_copyright 		0xa9
#define	KS_ordfeminine 		0xaa
#define	KS_guillemotleft 	0xab
#define	KS_notsign 		0xac
#define	KS_hyphen 		0xad
#define	KS_registered 		0xae
#define	KS_macron 		0xaf
#define	KS_degree 		0xb0
#define	KS_plusminus 		0xb1
#define	KS_twosuperior 		0xb2
#define	KS_threesuperior 	0xb3
#define	KS_acute 		0xb4
#define	KS_mu 			0xb5
#define	KS_paragraph 		0xb6
#define	KS_periodcentered 	0xb7
#define	KS_cedilla 		0xb8
#define	KS_onesuperior 		0xb9
#define	KS_masculine 		0xba
#define	KS_guillemotright 	0xbb
#define	KS_onequarter 		0xbc
#define	KS_onehalf 		0xbd
#define	KS_threequarters 	0xbe
#define	KS_questiondown 	0xbf
#define	KS_Agrave 		0xc0
#define	KS_Aacute 		0xc1
#define	KS_Acircumflex 		0xc2
#define	KS_Atilde 		0xc3
#define	KS_Adiaeresis 		0xc4
#define	KS_Aring 		0xc5
#define	KS_AE 			0xc6
#define	KS_Ccedilla 		0xc7
#define	KS_Egrave 		0xc8
#define	KS_Eacute 		0xc9
#define	KS_Ecircumflex 		0xca
#define	KS_Ediaeresis 		0xcb
#define	KS_Igrave 		0xcc
#define	KS_Iacute 		0xcd
#define	KS_Icircumflex 		0xce
#define	KS_Idiaeresis 		0xcf
#define	KS_ETH 			0xd0
#define	KS_Ntilde 		0xd1
#define	KS_Ograve 		0xd2
#define	KS_Oacute 		0xd3
#define	KS_Ocircumflex 		0xd4
#define	KS_Otilde 		0xd5
#define	KS_Odiaeresis 		0xd6
#define	KS_multiply 		0xd7
#define	KS_Ooblique 		0xd8
#define	KS_Ugrave 		0xd9
#define	KS_Uacute 		0xda
#define	KS_Ucircumflex 		0xdb
#define	KS_Udiaeresis 		0xdc
#define	KS_Yacute 		0xdd
#define	KS_THORN 		0xde
#define	KS_ssharp 		0xdf
#define	KS_agrave 		0xe0
#define	KS_aacute 		0xe1
#define	KS_acircumflex 		0xe2
#define	KS_atilde 		0xe3
#define	KS_adiaeresis 		0xe4
#define	KS_aring 		0xe5
#define	KS_ae 			0xe6
#define	KS_ccedilla 		0xe7
#define	KS_egrave 		0xe8
#define	KS_eacute 		0xe9
#define	KS_ecircumflex 		0xea
#define	KS_ediaeresis 		0xeb
#define	KS_igrave 		0xec
#define	KS_iacute 		0xed
#define	KS_icircumflex 		0xee
#define	KS_idiaeresis 		0xef
#define	KS_eth 			0xf0
#define	KS_ntilde 		0xf1
#define	KS_ograve 		0xf2
#define	KS_oacute 		0xf3
#define	KS_ocircumflex 		0xf4
#define	KS_otilde 		0xf5
#define	KS_odiaeresis 		0xf6
#define	KS_division 		0xf7
#define	KS_oslash 		0xf8
#define	KS_ugrave 		0xf9
#define	KS_uacute 		0xfa
#define	KS_ucircumflex 		0xfb
#define	KS_udiaeresis 		0xfc
#define	KS_yacute 		0xfd
#define KS_thorn		0xfe
#define	KS_ydiaeresis 		0xff
#define KS_Abreve		0x0102
#define KS_abreve		0x0103
#define KS_Aogonek		0x0104
#define KS_aogonek		0x0105
#define KS_Cacute		0x0106
#define KS_cacute		0x0107
#define KS_Ccaron		0x010c
#define KS_ccaron		0x010d
#define KS_Dcaron		0x010e
#define KS_dcaron		0x010f
#define KS_Dstroke		0x0110
#define KS_dstroke		0x0111
#define KS_Eogonek		0x0118
#define KS_eogonek		0x0119
#define KS_Ecaron		0x011a
#define KS_ecaron		0x011b
#define KS_Lacute		0x0139
#define KS_lacute		0x013a
#define KS_Lcaron		0x013d
#define KS_lcaron		0x013e
#define KS_Lstroke		0x0141
#define KS_lstroke		0x0142
#define KS_Nacute		0x0143
#define KS_nacute		0x0144
#define KS_Ncaron		0x0147
#define KS_ncaron		0x0148
#define KS_Odoubleacute 	0x0150
#define KS_odoubleacute 	0x0151
#define KS_Racute		0x0154
#define KS_racute		0x0155
#define KS_Rcaron		0x0158
#define KS_rcaron		0x0159
#define KS_Sacute		0x015a
#define KS_sacute		0x015b
#define KS_Scedilla		0x015e
#define KS_scedilla		0x015f
#define KS_Scaron		0x0160
#define KS_scaron		0x0161
#define KS_Tcedilla		0x0162
#define KS_tcedilla		0x0163
#define KS_Tcaron		0x0164
#define KS_tcaron		0x0165
#define KS_Uabovering		0x016e
#define KS_uabovering		0x016f
#define KS_Udoubleacute 	0x0170
#define KS_udoubleacute 	0x0171
#define KS_Zacute		0x0179
#define KS_zacute		0x017a
#define KS_Zabovedot		0x017b
#define KS_zabovedot		0x017c
#define KS_Zcaron		0x017d
#define KS_zcaron		0x017e

#define KS_caron		0x02c7
#define KS_breve		0x02d8
#define KS_abovedot		0x02d9
#define KS_ogonek		0x02db
#define KS_doubleacute		0x02dd

/*
 * Group Dead (dead accents)
 * http://www.unicode.org/charts/PDF/U0300.pdf
 * dotaccent	= "dot above"
 * hungarumlaut	= "double acute"
 * slash	= "short solidus"
 */

#define	KS_dead_grave 		0x0300
#define	KS_dead_acute 		0x0301
#define	KS_dead_circumflex 	0x0302
#define	KS_dead_tilde 		0x0303
#define KS_dead_breve		0x0306
#define	KS_dead_diaeresis 	0x0308
#define	KS_dead_abovering 	0x030a
#define KS_dead_caron		0x030c
#define KS_dead_dotaccent	0x0307
#define KS_dead_hungarumlaut	0x030b
#define KS_dead_ogonek		0x0328
#define KS_dead_slash		0x0337
#define	KS_dead_cedilla 	0x0327
#define KS_dead_semi		0x0328
#define KS_dead_colon		0x0329

/*
 * Group Greek
 */

#define KS_gr_At		0xb6
#define KS_gr_Et		0xb8
#define KS_gr_Ht		0xb9
#define KS_gr_It		0xba
#define KS_gr_Ot		0xbc
#define KS_gr_Yt		0xbe
#define KS_gr_Vt		0xbf
#define KS_gr_itd		0xc0
#define KS_gr_A		0xc1
#define KS_gr_B		0xc2
#define KS_gr_G		0xc3
#define KS_gr_D		0xc4
#define KS_gr_E		0xc5
#define KS_gr_Z		0xc6
#define KS_gr_H		0xc7
#define KS_gr_U		0xc8
#define KS_gr_I		0xc9
#define KS_gr_K		0xca
#define KS_gr_L		0xcb
#define KS_gr_M		0xcc
#define KS_gr_N		0xcd
#define KS_gr_J		0xce
#define KS_gr_O		0xcf
#define KS_gr_P		0xd0
#define KS_gr_R		0xd1
#define KS_gr_S		0xd3
#define KS_gr_T		0xd4
#define KS_gr_Y		0xd5
#define KS_gr_F		0xd6
#define KS_gr_X		0xd7
#define KS_gr_C		0xd8
#define KS_gr_V		0xd9
#define KS_gr_Id		0xda
#define KS_gr_Yd		0xdb
#define KS_gr_at		0xdc
#define KS_gr_et		0xdd
#define KS_gr_ht		0xde
#define KS_gr_it		0xdf
#define KS_gr_ytd		0xe0
#define KS_gr_a		0xe1
#define KS_gr_b		0xe2
#define KS_gr_g		0xe3
#define KS_gr_d		0xe4
#define KS_gr_e		0xe5
#define KS_gr_z		0xe6
#define KS_gr_h		0xe7
#define KS_gr_u		0xe8
#define KS_gr_i		0xe9
#define KS_gr_k		0xea
#define KS_gr_l		0xeb
#define KS_gr_m		0xec
#define KS_gr_n		0xed
#define KS_gr_j		0xee
#define KS_gr_o		0xef
#define KS_gr_p		0xf0
#define KS_gr_r		0xf1
#define KS_gr_teliko_s		0xf2
#define KS_gr_s		0xf3
#define KS_gr_t		0xf4
#define KS_gr_y		0xf5
#define KS_gr_f		0xf6
#define KS_gr_x		0xf7
#define KS_gr_c		0xf8
#define KS_gr_v		0xf9
#define KS_gr_id		0xfa
#define KS_gr_yd		0xfb
#define KS_gr_ot		0xfc
#define KS_gr_yt		0xfd
#define KS_gr_vt		0xfe

/*
 * Group 1 (modifiers)
 */

#define	KS_Shift_L 		0xf101
#define	KS_Shift_R 		0xf102
#define	KS_Control_L 		0xf103
#define	KS_Control_R 		0xf104
#define	KS_Caps_Lock 		0xf105
#define	KS_Shift_Lock 		0xf106
#define	KS_Alt_L 		0xf107
#define	KS_Alt_R 		0xf108
#define	KS_Multi_key 		0xf109
#define	KS_Mode_switch 		0xf10a
#define	KS_Num_Lock 		0xf10b
#define KS_Hold_Screen		0xf10c
#define KS_Cmd			0xf10d
#define KS_Cmd1			0xf10e
#define KS_Cmd2			0xf10f
#define KS_Meta_L		0xf110
#define KS_Meta_R		0xf111
#define KS_Zenkaku_Hankaku	0xf112	/* Zenkaku/Hankaku toggle */
#define KS_Hiragana_Katakana	0xf113	/* Hiragana/Katakana toggle */
#define KS_Henkan_Mode		0xf114	/* Start/Stop Conversion */
#define KS_Henkan		0xf115	/* Alias for Henkan_Mode */
#define KS_Muhenkan		0xf116	/* Cancel Conversion */

/*
 * Group 2 (keypad) character in low byte
 */

#define	KS_KP_F1 		0xf291
#define	KS_KP_F2 		0xf292
#define	KS_KP_F3 		0xf293
#define	KS_KP_F4 		0xf294
#define	KS_KP_Home 		0xf295
#define	KS_KP_Left 		0xf296
#define	KS_KP_Up 		0xf297
#define	KS_KP_Right 		0xf298
#define	KS_KP_Down 		0xf299
#define	KS_KP_Prior 		0xf29a
#define	KS_KP_Next 		0xf29b
#define	KS_KP_End 		0xf29c
#define	KS_KP_Begin 		0xf29d
#define	KS_KP_Insert 		0xf29e
#define	KS_KP_Delete 		0xf29f

#define	KS_KP_Space 		0xf220
#define	KS_KP_Tab 		0xf209
#define	KS_KP_Enter 		0xf20d
#define	KS_KP_Equal 		0xf23d
#define	KS_KP_Numbersign	0xf223
#define	KS_KP_Multiply 		0xf22a
#define	KS_KP_Add 		0xf22b
#define	KS_KP_Separator 	0xf22c
#define	KS_KP_Subtract 		0xf22d
#define	KS_KP_Decimal 		0xf22e
#define	KS_KP_Divide 		0xf22f
#define	KS_KP_0 		0xf230
#define	KS_KP_1 		0xf231
#define	KS_KP_2 		0xf232
#define	KS_KP_3 		0xf233
#define	KS_KP_4 		0xf234
#define	KS_KP_5 		0xf235
#define	KS_KP_6 		0xf236
#define	KS_KP_7 		0xf237
#define	KS_KP_8 		0xf238
#define	KS_KP_9 		0xf239

/*
 * Group 3 (function)
 */

#define KS_f1			0xf300
#define KS_f2			0xf301
#define KS_f3			0xf302
#define KS_f4			0xf303
#define KS_f5			0xf304
#define KS_f6			0xf305
#define KS_f7			0xf306
#define KS_f8			0xf307
#define KS_f9			0xf308
#define KS_f10			0xf309
#define KS_f11			0xf30a
#define KS_f12			0xf30b
#define KS_f13			0xf30c
#define KS_f14			0xf30d
#define KS_f15			0xf30e
#define KS_f16			0xf30f
#define KS_f17			0xf310
#define KS_f18			0xf311
#define KS_f19			0xf312
#define KS_f20			0xf313

#define KS_F1			0xf340
#define KS_F2			0xf341
#define KS_F3			0xf342
#define KS_F4			0xf343
#define KS_F5			0xf344
#define KS_F6			0xf345
#define KS_F7			0xf346
#define KS_F8			0xf347
#define KS_F9			0xf348
#define KS_F10			0xf349
#define KS_F11			0xf34a
#define KS_F12			0xf34b
#define KS_F13			0xf34c
#define KS_F14			0xf34d
#define KS_F15			0xf34e
#define KS_F16			0xf34f
#define KS_F17			0xf350
#define KS_F18			0xf351
#define KS_F19			0xf352
#define KS_F20			0xf353

#define KS_Power		0xf36d

#define KS_Home			0xf381
#define KS_Prior		0xf382
#define KS_Next			0xf383
#define KS_Up			0xf384
#define KS_Down			0xf385
#define KS_Left			0xf386
#define KS_Right		0xf387
#define KS_End			0xf388
#define KS_Insert		0xf389
#define KS_Help			0xf38a
#define KS_Execute		0xf38b
#define KS_Find			0xf38c
#define KS_Select		0xf38d
#define KS_Again                0xf38e
#define KS_Props                0xf38f
#define KS_Undo                 0xf390
#define KS_Front                0xf391
#define KS_Copy                 0xf392
#define KS_Open                 0xf393
#define KS_Paste                0xf394
#define KS_Cut                  0xf395
#define KS_Stop                 0xf396

#define KS_Menu			0xf3c0
#define KS_Pause		0xf3c1
#define KS_Print_Screen		0xf3c2

/*
 * Group 4 (command)
 */

#define KS_Cmd_Screen0		0xf400
#define KS_Cmd_Screen1		0xf401
#define KS_Cmd_Screen2		0xf402
#define KS_Cmd_Screen3		0xf403
#define KS_Cmd_Screen4		0xf404
#define KS_Cmd_Screen5		0xf405
#define KS_Cmd_Screen6		0xf406
#define KS_Cmd_Screen7		0xf407
#define KS_Cmd_Screen8		0xf408
#define KS_Cmd_Screen9		0xf409
#define KS_Cmd_Debugger		0xf420
#define KS_Cmd_ResetEmul	0xf421
#define KS_Cmd_ResetClose	0xf422
#define KS_Cmd_BacklightOn	0xf423
#define KS_Cmd_BacklightOff	0xf424
#define KS_Cmd_BacklightToggle	0xf425
#define KS_Cmd_BrightnessUp	0xf426
#define KS_Cmd_BrightnessDown	0xf427
#define KS_Cmd_BrightnessRotate	0xf428
#define KS_Cmd_ContrastUp	0xf429
#define KS_Cmd_ContrastDown	0xf42a
#define KS_Cmd_ContrastRotate	0xf42b
#define KS_Cmd_ScrollFastUp	0xf42c
#define KS_Cmd_ScrollFastDown	0xf42d
#define KS_Cmd_ScrollSlowUp	0xf42e
#define KS_Cmd_ScrollSlowDown	0xf42f
#define KS_Cmd_VolumeUp		0xf430
#define KS_Cmd_VolumeDown	0xf431
#define KS_Cmd_VolumeToggle	0xf432

/*
 * Group 5 (internal)
 */

#define KS_voidSymbol		0xf500


/*
 * Group Latin-5 (iso8859-9)
 */

#define KS_L5_Gbreve		0xd0
#define KS_L5_Idotabove		0xdd
#define KS_L5_Scedilla		0xde
#define KS_L5_gbreve		0xf0
#define KS_L5_idotless		0xfd
#define KS_L5_scedilla		0xfe

/*ENDKEYSYMDECL*/

/*
 * keysym groups
 */

#define KS_GROUP_Mod		0xf100U
#define KS_GROUP_Keypad		0xf200U
#define KS_GROUP_Function	0xf300U
#define KS_GROUP_Command	0xf400U
#define KS_GROUP_Internal	0xf500U
#define KS_GROUP_Dead		0xf801U		/* not encoded in keysym */
#define KS_GROUP_Plain		0xf802U		/* not encoded in keysym */
#define KS_GROUP_Keycode	0xf803U		/* not encoded in keysym */

#define KS_NUMKEYCODES	0x1000
#define KS_KEYCODE(v)	((v) | 0xe000)

#define KS_GROUP(k)	((k) >= 0x0300 && (k) < 0x0370 ? KS_GROUP_Dead : \
			    (((k) & 0xf000) == 0xe000 ? KS_GROUP_Keycode : \
			      (((k) & 0xf800) == 0xf000 ? ((k) & 0xff00) : \
				KS_GROUP_Plain)))

#define KS_VALUE(k)	(((k) & 0xf000) == 0xe000 ? ((k) & 0x0fff) : \
			    (((k) & 0xf800) == 0xf000 ? ((k) & 0x00ff) : (k)))

/*
 * Keyboard types: 8bit encoding, 24bit variant
 */

#define KB_ENCODING(e)		((e) & 0x0000ff00)
#define KB_VARIANT(e)		((e) & 0xffff00ff)

#define KB_NODEAD		0x0001
#define KB_DECLK		0x0002	/* DEC LKnnn layout */
#define KB_LK401		0x0004	/* DEC LK401 instead LK201 */
#define KB_SWAPCTRLCAPS		0x0008	/* Swap Left-Control and Caps-Lock */
#define KB_DVORAK		0x0010	/* Dvorak layout */
#define KB_METAESC		0x0020	/* generate ESC prefix on ALT-key */
#define KB_IOPENER		0x0040	/* f1-f12 -> ESC,f1-f11 */
#define KB_MACHDEP		0x0080	/* machine dependent */
#define KB_COLEMAK	    0x00010000	/* Colemak layout */
#define KB_APPLE	    0x00020000	/* Apple USB layout */

/*
 * Define keyboard type and texts all in one table.
 * Include default variants (and their text form) for sysinst.
 * Sort (loosely) by country name.
 */
#define KB_ENC_FUN(action) \
action(KB_USER,	0,	0x0100,	"user",	,	"User-defined")		\
action(KB_US,	0,	0x0200,	"us",	,	"US-English")		\
action(KB_UK,	0,	0x0700,	"uk",	,	"UK-English")		\
action(KB_BE,	0,	0x1300,	"be",	,	"Belgian")		\
action(KB_BR,	0,	0x1800,	"br",	,	"Brazilian")		\
action(KB_CF,	0,	0x1c00,	"cf",	,	"Canadian French")	\
action(KB_CZ,	0,	0x1500, "cz",	,	"Czech")		\
action(KB_DK,	0,	0x0400,	"dk",	,	"Danish")		\
action(KB_NL,	0,	0x1600,	"nl",	,	"Dutch") 		\
action(KB_EE,	0,	0x1900,	"ee",	,	"Estonian") 		\
action(KB_FI,	0,	0x0900,	"fi",	,	"Finnish")		\
action(KB_FR,	0,	0x0600,	"fr",	,	"French (AZERTY)")	\
action(KB_BEPO,	0,	0x2100,	"bepo",	,	"French (BEPO)")	\
action(KB_DE, KB_NODEAD,0x0300,	"de",".nodead",	"German (QWERTZ)")	\
action(KB_NEO,  0,	0x2000,	"neo",	,	"German (Neo 2)")	\
action(KB_GR,	0,	0x1400,	"gr",	,	"Greek")		\
action(KB_HU,	0,	0x0c00,	"hu",	,	"Hungarian")		\
action(KB_IS,	0,	0x1a00,	"is",	,	"Icelandic")		\
action(KB_IT,	0,	0x0500,	"it",	,	"Italian")		\
action(KB_JP,	0,	0x0800,	"jp",	,	"Japanese")		\
action(KB_LA,	0,	0x1b00,	"la",	,	"Latin American")	\
action(KB_NO,	0,	0x0a00,	"no",	,	"Norwegian")		\
action(KB_PL,	0,	0x0d00,	"pl",	,	"Polish")		\
action(KB_PT,	0,	0x1100,	"pt",	,	"Portuguese")		\
action(KB_RU,	0,	0x0e00,	"ru",	,	"Russian")		\
action(KB_ES,	0,	0x0b00,	"es",	,	"Spanish")		\
action(KB_SV,	0,	0x0900,	"sv",	,	"Swedish")		\
action(KB_SF,	0,	0x1000,	"sf",	,	"Swiss French")		\
action(KB_SG,	0,	0x0f00,	"sg",	,	"Swiss German")		\
action(KB_TR,	0,	0x1700,	"tr",	,	"Turkish (Q-Layout)")	\
action(KB_UA,	0,	0x1200,	"ua",	,	"Ukrainian")	
#define KB_NONE 0x0000

/* Define all the KB_xx numeric values using above table */
#define KBF_ENUM(tag, tagf, value, cc, ccf, country) tag=value,
enum { KB_ENC_FUN(KBF_ENUM) KB_NEXT=0x1d00 };

/* Define list of KB_xxx and country codes for array initialisation */
#define KBF_ENCTAB(tag, tagf, value, cc, ccf, country) { tag, cc },
#define KB_ENCTAB KB_ENC_FUN(KBF_ENCTAB)

#define KB_VARTAB \
	{ KB_NODEAD,	"nodead" }, \
	{ KB_DECLK,	"declk" }, \
	{ KB_LK401,	"lk401" }, \
	{ KB_SWAPCTRLCAPS, "swapctrlcaps" }, \
	{ KB_DVORAK,	"dvorak" }, \
	{ KB_METAESC,	"metaesc" }, \
	{ KB_IOPENER,	"iopener" }, \
	{ KB_MACHDEP,	"machdep" }, \
	{ KB_COLEMAK,	"colemak" }, \
	{ KB_APPLE,	"apple" }

#endif /* !_DEV_WSCONS_WSKSYMDEF_H_ */