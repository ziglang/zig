
	.def __DllMainCRTStartup@12
		.type 32
		.scl 2
	.endef
	.global __DllMainCRTStartup@12
__DllMainCRTStartup@12:
	ret

	.data
	.def _Data
		.type 0
		.scl 2
	.endef
	.global _Data
_Data:
	.long ___CFConstantStringClassReference

	.section .drectve
	.ascii " -export:_Data"

