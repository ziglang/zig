/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef MAP_TO_7SEGMENT_H
#define MAP_TO_7SEGMENT_H
#include <linux/errno.h>
#define BIT_SEG7_A 0
#define BIT_SEG7_B 1
#define BIT_SEG7_C 2
#define BIT_SEG7_D 3
#define BIT_SEG7_E 4
#define BIT_SEG7_F 5
#define BIT_SEG7_G 6
#define BIT_SEG7_RESERVED 7
struct seg7_conversion_map {
  unsigned char table[128];
};
#define SEG7_CONVERSION_MAP(_name,_map) struct seg7_conversion_map _name = {.table = { _map } }
#define MAP_TO_SEG7_SYSFS_FILE "map_seg7"
#define _SEG7(l,a,b,c,d,e,f,g) (a << BIT_SEG7_A | b << BIT_SEG7_B | c << BIT_SEG7_C | d << BIT_SEG7_D | e << BIT_SEG7_E | f << BIT_SEG7_F | g << BIT_SEG7_G)
#define _MAP_0_32_ASCII_SEG7_NON_PRINTABLE 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
#define _MAP_33_47_ASCII_SEG7_SYMBOL _SEG7('!', 0, 0, 0, 0, 1, 1, 0), _SEG7('"', 0, 1, 0, 0, 0, 1, 0), _SEG7('#', 0, 1, 1, 0, 1, 1, 0), _SEG7('$', 1, 0, 1, 1, 0, 1, 1), _SEG7('%', 0, 0, 1, 0, 0, 1, 0), _SEG7('&', 1, 0, 1, 1, 1, 1, 1), _SEG7('\'', 0, 0, 0, 0, 0, 1, 0), _SEG7('(', 1, 0, 0, 1, 1, 1, 0), _SEG7(')', 1, 1, 1, 1, 0, 0, 0), _SEG7('*', 0, 1, 1, 0, 1, 1, 1), _SEG7('+', 0, 1, 1, 0, 0, 0, 1), _SEG7(',', 0, 0, 0, 0, 1, 0, 0), _SEG7('-', 0, 0, 0, 0, 0, 0, 1), _SEG7('.', 0, 0, 0, 0, 1, 0, 0), _SEG7('/', 0, 1, 0, 0, 1, 0, 1),
#define _MAP_48_57_ASCII_SEG7_NUMERIC _SEG7('0', 1, 1, 1, 1, 1, 1, 0), _SEG7('1', 0, 1, 1, 0, 0, 0, 0), _SEG7('2', 1, 1, 0, 1, 1, 0, 1), _SEG7('3', 1, 1, 1, 1, 0, 0, 1), _SEG7('4', 0, 1, 1, 0, 0, 1, 1), _SEG7('5', 1, 0, 1, 1, 0, 1, 1), _SEG7('6', 1, 0, 1, 1, 1, 1, 1), _SEG7('7', 1, 1, 1, 0, 0, 0, 0), _SEG7('8', 1, 1, 1, 1, 1, 1, 1), _SEG7('9', 1, 1, 1, 1, 0, 1, 1),
#define _MAP_58_64_ASCII_SEG7_SYMBOL _SEG7(':', 0, 0, 0, 1, 0, 0, 1), _SEG7(';', 0, 0, 0, 1, 0, 0, 1), _SEG7('<', 1, 0, 0, 0, 0, 1, 1), _SEG7('=', 0, 0, 0, 1, 0, 0, 1), _SEG7('>', 1, 1, 0, 0, 0, 0, 1), _SEG7('?', 1, 1, 1, 0, 0, 1, 0), _SEG7('@', 1, 1, 0, 1, 1, 1, 1),
#define _MAP_65_90_ASCII_SEG7_ALPHA_UPPR _SEG7('A', 1, 1, 1, 0, 1, 1, 1), _SEG7('B', 1, 1, 1, 1, 1, 1, 1), _SEG7('C', 1, 0, 0, 1, 1, 1, 0), _SEG7('D', 1, 1, 1, 1, 1, 1, 0), _SEG7('E', 1, 0, 0, 1, 1, 1, 1), _SEG7('F', 1, 0, 0, 0, 1, 1, 1), _SEG7('G', 1, 1, 1, 1, 0, 1, 1), _SEG7('H', 0, 1, 1, 0, 1, 1, 1), _SEG7('I', 0, 1, 1, 0, 0, 0, 0), _SEG7('J', 0, 1, 1, 1, 0, 0, 0), _SEG7('K', 0, 1, 1, 0, 1, 1, 1), _SEG7('L', 0, 0, 0, 1, 1, 1, 0), _SEG7('M', 1, 1, 1, 0, 1, 1, 0), _SEG7('N', 1, 1, 1, 0, 1, 1, 0), _SEG7('O', 1, 1, 1, 1, 1, 1, 0), _SEG7('P', 1, 1, 0, 0, 1, 1, 1), _SEG7('Q', 1, 1, 1, 1, 1, 1, 0), _SEG7('R', 1, 1, 1, 0, 1, 1, 1), _SEG7('S', 1, 0, 1, 1, 0, 1, 1), _SEG7('T', 0, 0, 0, 1, 1, 1, 1), _SEG7('U', 0, 1, 1, 1, 1, 1, 0), _SEG7('V', 0, 1, 1, 1, 1, 1, 0), _SEG7('W', 0, 1, 1, 1, 1, 1, 1), _SEG7('X', 0, 1, 1, 0, 1, 1, 1), _SEG7('Y', 0, 1, 1, 0, 0, 1, 1), _SEG7('Z', 1, 1, 0, 1, 1, 0, 1),
#define _MAP_91_96_ASCII_SEG7_SYMBOL _SEG7('[', 1, 0, 0, 1, 1, 1, 0), _SEG7('\\', 0, 0, 1, 0, 0, 1, 1), _SEG7(']', 1, 1, 1, 1, 0, 0, 0), _SEG7('^', 1, 1, 0, 0, 0, 1, 0), _SEG7('_', 0, 0, 0, 1, 0, 0, 0), _SEG7('`', 0, 1, 0, 0, 0, 0, 0),
#define _MAP_97_122_ASCII_SEG7_ALPHA_LOWER _SEG7('A', 1, 1, 1, 0, 1, 1, 1), _SEG7('b', 0, 0, 1, 1, 1, 1, 1), _SEG7('c', 0, 0, 0, 1, 1, 0, 1), _SEG7('d', 0, 1, 1, 1, 1, 0, 1), _SEG7('E', 1, 0, 0, 1, 1, 1, 1), _SEG7('F', 1, 0, 0, 0, 1, 1, 1), _SEG7('G', 1, 1, 1, 1, 0, 1, 1), _SEG7('h', 0, 0, 1, 0, 1, 1, 1), _SEG7('i', 0, 0, 1, 0, 0, 0, 0), _SEG7('j', 0, 0, 1, 1, 0, 0, 0), _SEG7('k', 0, 0, 1, 0, 1, 1, 1), _SEG7('L', 0, 0, 0, 1, 1, 1, 0), _SEG7('M', 1, 1, 1, 0, 1, 1, 0), _SEG7('n', 0, 0, 1, 0, 1, 0, 1), _SEG7('o', 0, 0, 1, 1, 1, 0, 1), _SEG7('P', 1, 1, 0, 0, 1, 1, 1), _SEG7('q', 1, 1, 1, 0, 0, 1, 1), _SEG7('r', 0, 0, 0, 0, 1, 0, 1), _SEG7('S', 1, 0, 1, 1, 0, 1, 1), _SEG7('T', 0, 0, 0, 1, 1, 1, 1), _SEG7('u', 0, 0, 1, 1, 1, 0, 0), _SEG7('v', 0, 0, 1, 1, 1, 0, 0), _SEG7('W', 0, 1, 1, 1, 1, 1, 1), _SEG7('X', 0, 1, 1, 0, 1, 1, 1), _SEG7('y', 0, 1, 1, 1, 0, 1, 1), _SEG7('Z', 1, 1, 0, 1, 1, 0, 1),
#define _MAP_123_126_ASCII_SEG7_SYMBOL _SEG7('{', 1, 0, 0, 1, 1, 1, 0), _SEG7('|', 0, 0, 0, 0, 1, 1, 0), _SEG7('}', 1, 1, 1, 1, 0, 0, 0), _SEG7('~', 1, 0, 0, 0, 0, 0, 0),
#define MAP_ASCII7SEG_ALPHANUM _MAP_0_32_ASCII_SEG7_NON_PRINTABLE _MAP_33_47_ASCII_SEG7_SYMBOL _MAP_48_57_ASCII_SEG7_NUMERIC _MAP_58_64_ASCII_SEG7_SYMBOL _MAP_65_90_ASCII_SEG7_ALPHA_UPPR _MAP_91_96_ASCII_SEG7_SYMBOL _MAP_97_122_ASCII_SEG7_ALPHA_LOWER _MAP_123_126_ASCII_SEG7_SYMBOL
#define MAP_ASCII7SEG_ALPHANUM_LC _MAP_0_32_ASCII_SEG7_NON_PRINTABLE _MAP_33_47_ASCII_SEG7_SYMBOL _MAP_48_57_ASCII_SEG7_NUMERIC _MAP_58_64_ASCII_SEG7_SYMBOL _MAP_97_122_ASCII_SEG7_ALPHA_LOWER _MAP_91_96_ASCII_SEG7_SYMBOL _MAP_97_122_ASCII_SEG7_ALPHA_LOWER _MAP_123_126_ASCII_SEG7_SYMBOL
#define SEG7_DEFAULT_MAP(_name) SEG7_CONVERSION_MAP(_name, MAP_ASCII7SEG_ALPHANUM)
#endif