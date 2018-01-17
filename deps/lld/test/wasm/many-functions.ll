; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %p/Inputs/many-funcs.ll -o %t.many.o
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %s -o %t.o
; RUN: lld -flavor wasm -r -o %t.wasm %t.many.o %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

; Test that relocations within the CODE section correctly handle
; linking object with different header sizes.  many-funcs.ll has
; 128 function and so the final output requires a 2-byte LEB in
; the CODE section header to store the function count.

define i32 @func() {
entry:
  %call = tail call i32 @func()
  ret i32 %call
}

; CHECK:        - Type:            CODE
; CHECK-NEXT:     Relocations:
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000008
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000014
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000020
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000002C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000038
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000044
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000050
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000005C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000068
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000074
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000080
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000008C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000098
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000000A4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000000B0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000000BC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000000C8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000000D4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000000E0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000000EC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000000F8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000104
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000110
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000011C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000128
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000134
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000140
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000014C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000158
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000164
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000170
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000017C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000188
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000194
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000001A0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000001AC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000001B8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000001C4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000001D0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000001DC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000001E8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000001F4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000200
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000020C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000218
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000224
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000230
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000023C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000248
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000254
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000260
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000026C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000278
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000284
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000290
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000029C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000002A8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000002B4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000002C0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000002CC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000002D8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000002E4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000002F0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000002FC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000308
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000314
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000320
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000032C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000338
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000344
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000350
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000035C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000368
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000374
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000380
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000038C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000398
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000003A4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000003B0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000003BC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000003C8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000003D4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000003E0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000003EC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000003F8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000404
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000410
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000041C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000428
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000434
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000440
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000044C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000458
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000464
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000470
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000047C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000488
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000494
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000004A0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000004AC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000004B8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000004C4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000004D0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000004DC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000004E8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000004F4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000500
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000050C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000518
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000524
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000530
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000053C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000548
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000554
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000560
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000056C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000578
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000584
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x00000590
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000059C
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000005A8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000005B4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000005C0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000005CC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000005D8
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000005E4
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x000005F0
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x000005FC
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000608
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_FUNCTION_INDEX_LEB
; CHECK-NEXT:         Index:           129
; CHECK-NEXT:         Offset:          0x00000611
; CHECK-NEXT:     Functions:
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280284808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280280808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            4100280280808080000B
; CHECK-NEXT:       - Locals:
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
; CHECK-NEXT:     DataSize:        8
; CHECK-NEXT:     SegmentInfo:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            .data.g0
; CHECK-NEXT:         Alignment:       4
; CHECK-NEXT:         Flags:           [ ]
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Name:            .data.foo
; CHECK-NEXT:         Alignment:       4
; CHECK-NEXT:         Flags:           [ ]
