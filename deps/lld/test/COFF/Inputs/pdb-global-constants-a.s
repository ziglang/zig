	.text
	.def	 @feat.00;
	.scl	3;
	.type	0;
	.endef
	.globl	@feat.00
.set @feat.00, 0
	.file	"t.cpp"
	.def	 main;
	.scl	2;
	.type	32;
	.endef
	.globl	main                    # -- Begin function main
	.p2align	4, 0x90
main:                                   # @main
.Lfunc_begin0:
	.cv_func_id 0
	.cv_file	1 "C:\\src\\testing\\t.cpp" "D28AB0CC784E17E5DF9BBB49CB629C81" 1
	.cv_loc	0 1 4 0                 # t.cpp:4:0
.seh_proc main
# %bb.0:                                # %entry
	pushq	%rax
	.seh_stackalloc 8
	.seh_endprologue
	movl	$0, 4(%rsp)
.Ltmp0:
	movl	$83, %eax
	popq	%rcx
	retq
.Ltmp1:
.Lfunc_end0:
	.seh_handlerdata
	.text
	.seh_endproc
                                        # -- End function
	.section	.debug$S,"dr"
	.p2align	2
	.long	4                       # Debug section magic
	.long	241
	.long	.Ltmp3-.Ltmp2           # Subsection size
.Ltmp2:
	.short	.Ltmp5-.Ltmp4           # Record length
.Ltmp4:
	.short	4412                    # Record kind: S_COMPILE3
	.long	1                       # Flags and language
	.short	208                     # CPUType
	.short	9                       # Frontend version
	.short	0
	.short	0
	.short	0
	.short	9000                    # Backend version
	.short	0
	.short	0
	.short	0
	.asciz	"clang version 9.0.0 (https://github.com/llvm/llvm-project.git ad522e17b285b1f2667163d52da5abf0968ec650)" # Null-terminated compiler version string
	.p2align	2
.Ltmp5:
.Ltmp3:
	.p2align	2
	.long	241                     # Symbol subsection for main
	.long	.Ltmp7-.Ltmp6           # Subsection size
.Ltmp6:
	.short	.Ltmp9-.Ltmp8           # Record length
.Ltmp8:
	.short	4423                    # Record kind: S_GPROC32_ID
	.long	0                       # PtrParent
	.long	0                       # PtrEnd
	.long	0                       # PtrNext
	.long	.Lfunc_end0-main        # Code size
	.long	0                       # Offset after prologue
	.long	0                       # Offset before epilogue
	.long	4098                    # Function type index
	.secrel32	main            # Function section relative address
	.secidx	main                    # Function section index
	.byte	0                       # Flags
	.asciz	"main"                  # Function name
	.p2align	2
.Ltmp9:
	.short	.Ltmp11-.Ltmp10         # Record length
.Ltmp10:
	.short	4114                    # Record kind: S_FRAMEPROC
	.long	8                       # FrameSize
	.long	0                       # Padding
	.long	0                       # Offset of padding
	.long	0                       # Bytes of callee saved registers
	.long	0                       # Exception handler offset
	.short	0                       # Exception handler section
	.long	81920                   # Flags (defines frame register)
	.p2align	2
.Ltmp11:
	.short	2                       # Record length
	.short	4431                    # Record kind: S_PROC_ID_END
.Ltmp7:
	.p2align	2
	.cv_linetable	0, main, .Lfunc_end0
	.long	241                     # Symbol subsection for globals
	.long	.Ltmp13-.Ltmp12         # Subsection size
.Ltmp12:
	.short	.Ltmp15-.Ltmp14         # Record length
.Ltmp14:
	.short	4359                    # Record kind: S_CONSTANT
	.long	4099                    # Type
	.byte	0x29, 0x00              # Value
	.asciz	"Foo"                   # Name
	.p2align	2
.Ltmp15:
	.short	.Ltmp17-.Ltmp16         # Record length
.Ltmp16:
	.short	4359                    # Record kind: S_CONSTANT
	.long	4099                    # Type
	.byte	0x2a, 0x00              # Value
	.asciz	"Bar"                   # Name
	.p2align	2
.Ltmp17:
.Ltmp13:
	.p2align	2
	.cv_filechecksums               # File index to string table offset subsection
	.cv_stringtable                 # String table
	.long	241
	.long	.Ltmp19-.Ltmp18         # Subsection size
.Ltmp18:
	.short	.Ltmp21-.Ltmp20         # Record length
.Ltmp20:
	.short	4428                    # Record kind: S_BUILDINFO
	.long	4102                    # LF_BUILDINFO index
	.p2align	2
.Ltmp21:
.Ltmp19:
	.p2align	2
	.section	.debug$T,"dr"
	.p2align	2
	.long	4                       # Debug section magic
	# ArgList (0x1000) {
	#   TypeLeafKind: LF_ARGLIST (0x1201)
	#   NumArgs: 0
	#   Arguments [
	#   ]
	# }
	.byte	0x06, 0x00, 0x01, 0x12
	.byte	0x00, 0x00, 0x00, 0x00
	# Procedure (0x1001) {
	#   TypeLeafKind: LF_PROCEDURE (0x1008)
	#   ReturnType: int (0x74)
	#   CallingConvention: NearC (0x0)
	#   FunctionOptions [ (0x0)
	#   ]
	#   NumParameters: 0
	#   ArgListType: () (0x1000)
	# }
	.byte	0x0e, 0x00, 0x08, 0x10
	.byte	0x74, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x10, 0x00, 0x00
	# FuncId (0x1002) {
	#   TypeLeafKind: LF_FUNC_ID (0x1601)
	#   ParentScope: 0x0
	#   FunctionType: int () (0x1001)
	#   Name: main
	# }
	.byte	0x12, 0x00, 0x01, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x01, 0x10, 0x00, 0x00
	.byte	0x6d, 0x61, 0x69, 0x6e
	.byte	0x00, 0xf3, 0xf2, 0xf1
	# Modifier (0x1003) {
	#   TypeLeafKind: LF_MODIFIER (0x1001)
	#   ModifiedType: int (0x74)
	#   Modifiers [ (0x1)
	#     Const (0x1)
	#   ]
	# }
	.byte	0x0a, 0x00, 0x01, 0x10
	.byte	0x74, 0x00, 0x00, 0x00
	.byte	0x01, 0x00, 0xf2, 0xf1
	# StringId (0x1004) {
	#   TypeLeafKind: LF_STRING_ID (0x1605)
	#   Id: 0x0
	#   StringData: C:\src\testing
	# }
	.byte	0x16, 0x00, 0x05, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x43, 0x3a, 0x5c, 0x73
	.byte	0x72, 0x63, 0x5c, 0x74
	.byte	0x65, 0x73, 0x74, 0x69
	.byte	0x6e, 0x67, 0x00, 0xf1
	# StringId (0x1005) {
	#   TypeLeafKind: LF_STRING_ID (0x1605)
	#   Id: 0x0
	#   StringData: t.cpp
	# }
	.byte	0x0e, 0x00, 0x05, 0x16
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x74, 0x2e, 0x63, 0x70
	.byte	0x70, 0x00, 0xf2, 0xf1
	# BuildInfo (0x1006) {
	#   TypeLeafKind: LF_BUILDINFO (0x1603)
	#   NumArgs: 5
	#   Arguments [
	#     ArgType: C:\src\testing (0x1004)
	#     ArgType: 0x0
	#     ArgType: t.cpp (0x1005)
	#     ArgType: 0x0
	#     ArgType: 0x0
	#   ]
	# }
	.byte	0x1a, 0x00, 0x03, 0x16
	.byte	0x05, 0x00, 0x04, 0x10
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x05, 0x10
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0x00, 0x00
	.byte	0x00, 0x00, 0xf2, 0xf1

	.addrsig
