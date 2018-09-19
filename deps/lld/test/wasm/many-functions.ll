; RUN: llc -filetype=obj %p/Inputs/many-funcs.ll -o %t.many.o
; RUN: llc -filetype=obj %s -o %t.o
; RUN: wasm-ld -r -o %t.wasm %t.many.o %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

; Test that relocations within the CODE section correctly handle
; linking object with different header sizes.  many-funcs.ll has
; 128 function and so the final output requires a 2-byte LEB in
; the CODE section header to store the function count.

target triple = "wasm32-unknown-unknown"

define i32 @func() {
entry:
  %call = tail call i32 @func()
  ret i32 %call
}

; CHECK:        - Type:            CODE
; CHECK-NEXT:     Relocations:
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000008
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000014
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000020
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000002C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000038
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000044
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000050
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000005C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000068
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000074
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000080
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000008C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000098
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000000A4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000000B0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000000BC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000000C8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000000D4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000000E0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000000EC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000000F8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000104
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000110
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000011C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000128
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000134
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000140
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000014C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000158
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000164
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000170
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000017C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000188
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000194
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000001A0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000001AC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000001B8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000001C4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000001D0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000001DC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000001E8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000001F4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000200
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000020C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000218
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000224
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000230
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000023C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000248
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000254
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000260
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000026C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000278
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000284
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000290
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000029C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000002A8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000002B4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000002C0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000002CC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000002D8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000002E4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000002F0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000002FC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000308
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000314
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000320
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000032C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000338
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000344
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000350
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000035C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000368
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000374
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000380
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000038C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000398
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000003A4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000003B0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000003BC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000003C8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000003D4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000003E0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000003EC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000003F8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000404
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000410
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000041C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000428
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000434
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000440
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000044C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000458
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000464
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000470
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000047C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000488
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000494
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000004A0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000004AC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000004B8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000004C4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000004D0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000004DC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000004E8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000004F4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000500
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000050C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000518
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000524
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000530
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000053C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000548
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000554
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000560
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000056C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000578
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000584
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000590
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x0000059C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000005A8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000005B4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000005C0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000005CC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000005D8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000005E4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000005F0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           129
; CHECK-NEXT:         Offset:          0x000005FC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           129
; CHECK-NEXT:         Offset:          0x00000608
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_FUNCTION_INDEX_LEB
; CHECK-NEXT:         Index:           131
; CHECK-NEXT:         Offset:          0x00000611
; CHECK-NEXT:     Functions:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           3
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           4
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           5
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           6
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           7
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           8
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           9
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           10
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           11
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           12
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           13
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           14
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           15
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           16
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           17
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           18
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           19
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           20
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           21
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           22
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           23
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           24
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           25
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           26
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           27
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           28
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           29
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           30
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           31
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           32
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           33
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           34
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           35
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           36
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           37
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           38
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           39
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           40
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           41
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           42
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           43
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           44
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           45
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           46
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           47
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           48
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           49
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           50
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           51
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           52
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           53
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           54
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           55
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           56
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           57
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           58
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           59
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           60
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           61
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           62
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           63
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           64
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           65
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           66
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           67
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           68
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           69
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           70
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           71
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           72
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           73
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           74
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           75
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           76
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           77
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           78
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           79
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           80
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           81
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           82
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           83
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           84
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           85
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           86
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           87
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           88
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           89
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           90
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           91
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           92
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           93
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           94
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           95
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           96
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           97
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           98
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           99
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           100
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           101
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           102
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           103
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           104
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           105
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           106
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           107
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           108
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           109
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           110
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           111
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           112
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           113
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           114
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           115
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           116
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           117
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           118
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           119
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           120
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           121
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           122
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           123
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           124
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           125
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           126
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Index:           127
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280280808080000B
; CHECK-NEXT:       - Index:           128
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            4100280280808080000B
; CHECK-NEXT:       - Index:           129
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            1081818080000B
; CHECK-NEXT:   - Type:            DATA
; CHECK-NEXT:     Segments:
; CHECK-NEXT:       - SectionOffset:   6
; CHECK-NEXT:         MemoryIndex:     0
; CHECK-NEXT:         Offset:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           0
; CHECK-NEXT:         Content:         '01000000'
; CHECK-NEXT:       - SectionOffset:   15
; CHECK-NEXT:         MemoryIndex:     0
; CHECK-NEXT:         Offset:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           4
; CHECK-NEXT:         Content:         '01000000'
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            linking
; CHECK-NEXT:     Version:         1
; CHECK-NEXT:     SymbolTable:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f1
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        0
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Kind:            DATA
; CHECK-NEXT:         Name:            foo
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Segment:         1
; CHECK-NEXT:         Size:            4
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f2
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        1
; CHECK-NEXT:       - Index:           3
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f3
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        2
; CHECK-NEXT:       - Index:           4
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f4
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        3
; CHECK-NEXT:       - Index:           5
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f5
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        4
; CHECK-NEXT:       - Index:           6
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f6
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        5
; CHECK-NEXT:       - Index:           7
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f7
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        6
; CHECK-NEXT:       - Index:           8
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f8
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        7
; CHECK-NEXT:       - Index:           9
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f9
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        8
; CHECK-NEXT:       - Index:           10
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f10
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        9
; CHECK-NEXT:       - Index:           11
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f11
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        10
; CHECK-NEXT:       - Index:           12
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f12
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        11
; CHECK-NEXT:       - Index:           13
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f13
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        12
; CHECK-NEXT:       - Index:           14
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f14
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        13
; CHECK-NEXT:       - Index:           15
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f15
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        14
; CHECK-NEXT:       - Index:           16
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f16
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        15
; CHECK-NEXT:       - Index:           17
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f17
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        16
; CHECK-NEXT:       - Index:           18
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f18
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        17
; CHECK-NEXT:       - Index:           19
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f19
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        18
; CHECK-NEXT:       - Index:           20
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f20
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        19
; CHECK-NEXT:       - Index:           21
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f21
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        20
; CHECK-NEXT:       - Index:           22
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f22
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        21
; CHECK-NEXT:       - Index:           23
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f23
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        22
; CHECK-NEXT:       - Index:           24
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f24
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        23
; CHECK-NEXT:       - Index:           25
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f25
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        24
; CHECK-NEXT:       - Index:           26
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f26
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        25
; CHECK-NEXT:       - Index:           27
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f27
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        26
; CHECK-NEXT:       - Index:           28
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f28
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        27
; CHECK-NEXT:       - Index:           29
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f29
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        28
; CHECK-NEXT:       - Index:           30
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f30
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        29
; CHECK-NEXT:       - Index:           31
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f31
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        30
; CHECK-NEXT:       - Index:           32
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f32
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        31
; CHECK-NEXT:       - Index:           33
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f33
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        32
; CHECK-NEXT:       - Index:           34
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f34
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        33
; CHECK-NEXT:       - Index:           35
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f35
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        34
; CHECK-NEXT:       - Index:           36
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f36
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        35
; CHECK-NEXT:       - Index:           37
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f37
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        36
; CHECK-NEXT:       - Index:           38
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f38
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        37
; CHECK-NEXT:       - Index:           39
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f39
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        38
; CHECK-NEXT:       - Index:           40
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f40
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        39
; CHECK-NEXT:       - Index:           41
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f41
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        40
; CHECK-NEXT:       - Index:           42
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f42
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        41
; CHECK-NEXT:       - Index:           43
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f43
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        42
; CHECK-NEXT:       - Index:           44
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f44
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        43
; CHECK-NEXT:       - Index:           45
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f45
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        44
; CHECK-NEXT:       - Index:           46
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f46
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        45
; CHECK-NEXT:       - Index:           47
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f47
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        46
; CHECK-NEXT:       - Index:           48
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f48
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        47
; CHECK-NEXT:       - Index:           49
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f49
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        48
; CHECK-NEXT:       - Index:           50
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f50
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        49
; CHECK-NEXT:       - Index:           51
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f51
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        50
; CHECK-NEXT:       - Index:           52
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f52
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        51
; CHECK-NEXT:       - Index:           53
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f53
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        52
; CHECK-NEXT:       - Index:           54
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f54
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        53
; CHECK-NEXT:       - Index:           55
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f55
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        54
; CHECK-NEXT:       - Index:           56
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f56
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        55
; CHECK-NEXT:       - Index:           57
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f57
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        56
; CHECK-NEXT:       - Index:           58
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f58
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        57
; CHECK-NEXT:       - Index:           59
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f59
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        58
; CHECK-NEXT:       - Index:           60
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f60
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        59
; CHECK-NEXT:       - Index:           61
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f61
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        60
; CHECK-NEXT:       - Index:           62
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f62
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        61
; CHECK-NEXT:       - Index:           63
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f63
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        62
; CHECK-NEXT:       - Index:           64
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f64
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        63
; CHECK-NEXT:       - Index:           65
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f65
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        64
; CHECK-NEXT:       - Index:           66
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f66
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        65
; CHECK-NEXT:       - Index:           67
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f67
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        66
; CHECK-NEXT:       - Index:           68
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f68
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        67
; CHECK-NEXT:       - Index:           69
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f69
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        68
; CHECK-NEXT:       - Index:           70
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f70
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        69
; CHECK-NEXT:       - Index:           71
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f71
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        70
; CHECK-NEXT:       - Index:           72
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f72
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        71
; CHECK-NEXT:       - Index:           73
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f73
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        72
; CHECK-NEXT:       - Index:           74
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f74
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        73
; CHECK-NEXT:       - Index:           75
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f75
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        74
; CHECK-NEXT:       - Index:           76
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f76
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        75
; CHECK-NEXT:       - Index:           77
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f77
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        76
; CHECK-NEXT:       - Index:           78
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f78
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        77
; CHECK-NEXT:       - Index:           79
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f79
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        78
; CHECK-NEXT:       - Index:           80
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f80
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        79
; CHECK-NEXT:       - Index:           81
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f81
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        80
; CHECK-NEXT:       - Index:           82
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f82
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        81
; CHECK-NEXT:       - Index:           83
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f83
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        82
; CHECK-NEXT:       - Index:           84
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f84
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        83
; CHECK-NEXT:       - Index:           85
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f85
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        84
; CHECK-NEXT:       - Index:           86
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f86
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        85
; CHECK-NEXT:       - Index:           87
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f87
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        86
; CHECK-NEXT:       - Index:           88
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f88
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        87
; CHECK-NEXT:       - Index:           89
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f89
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        88
; CHECK-NEXT:       - Index:           90
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f90
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        89
; CHECK-NEXT:       - Index:           91
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f91
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        90
; CHECK-NEXT:       - Index:           92
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f92
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        91
; CHECK-NEXT:       - Index:           93
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f93
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        92
; CHECK-NEXT:       - Index:           94
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f94
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        93
; CHECK-NEXT:       - Index:           95
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f95
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        94
; CHECK-NEXT:       - Index:           96
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f96
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        95
; CHECK-NEXT:       - Index:           97
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f97
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        96
; CHECK-NEXT:       - Index:           98
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f98
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        97
; CHECK-NEXT:       - Index:           99
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f99
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        98
; CHECK-NEXT:       - Index:           100
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f100
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        99
; CHECK-NEXT:       - Index:           101
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f101
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        100
; CHECK-NEXT:       - Index:           102
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f102
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        101
; CHECK-NEXT:       - Index:           103
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f103
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        102
; CHECK-NEXT:       - Index:           104
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f104
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        103
; CHECK-NEXT:       - Index:           105
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f105
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        104
; CHECK-NEXT:       - Index:           106
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f106
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        105
; CHECK-NEXT:       - Index:           107
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f107
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        106
; CHECK-NEXT:       - Index:           108
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f108
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        107
; CHECK-NEXT:       - Index:           109
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f109
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        108
; CHECK-NEXT:       - Index:           110
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f110
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        109
; CHECK-NEXT:       - Index:           111
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f111
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        110
; CHECK-NEXT:       - Index:           112
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f112
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        111
; CHECK-NEXT:       - Index:           113
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f113
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        112
; CHECK-NEXT:       - Index:           114
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f114
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        113
; CHECK-NEXT:       - Index:           115
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f115
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        114
; CHECK-NEXT:       - Index:           116
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f116
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        115
; CHECK-NEXT:       - Index:           117
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f117
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        116
; CHECK-NEXT:       - Index:           118
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f118
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        117
; CHECK-NEXT:       - Index:           119
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f119
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        118
; CHECK-NEXT:       - Index:           120
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f120
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        119
; CHECK-NEXT:       - Index:           121
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f121
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        120
; CHECK-NEXT:       - Index:           122
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f122
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        121
; CHECK-NEXT:       - Index:           123
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f123
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        122
; CHECK-NEXT:       - Index:           124
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f124
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        123
; CHECK-NEXT:       - Index:           125
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f125
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        124
; CHECK-NEXT:       - Index:           126
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f126
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        125
; CHECK-NEXT:       - Index:           127
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f127
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        126
; CHECK-NEXT:       - Index:           128
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f128
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        127
; CHECK-NEXT:       - Index:           129
; CHECK-NEXT:         Kind:            DATA
; CHECK-NEXT:         Name:            g0
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Segment:         0
; CHECK-NEXT:         Size:            4
; CHECK-NEXT:       - Index:           130
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            f129
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        128
; CHECK-NEXT:       - Index:           131
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            func
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        129
; CHECK-NEXT:     SegmentInfo:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            .data.g0
; CHECK-NEXT:         Alignment:       4
; CHECK-NEXT:         Flags:           [ ]
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Name:            .data.foo
; CHECK-NEXT:         Alignment:       4
; CHECK-NEXT:         Flags:           [ ]
