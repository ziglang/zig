#define _GNU_SOURCE
#include <link.h>
#include <stdint.h>

struct find_exidx_data {
	uintptr_t pc, exidx_start;
	int exidx_len;
};

static int find_exidx(struct dl_phdr_info *info, size_t size, void *ptr)
{
	struct find_exidx_data *data = ptr;
	const ElfW(Phdr) *phdr = info->dlpi_phdr;
	uintptr_t addr, exidx_start = 0;
	int i, match = 0, exidx_len = 0;

	for (i = info->dlpi_phnum; i > 0; i--, phdr++) {
		addr = info->dlpi_addr + phdr->p_vaddr;
		switch (phdr->p_type) {
		case PT_LOAD:
			match |= data->pc >= addr && data->pc < addr + phdr->p_memsz;
			break;
		case PT_ARM_EXIDX:
			exidx_start = addr;
			exidx_len = phdr->p_memsz;
			break;
		}
	}
	data->exidx_start = exidx_start;
	data->exidx_len = exidx_len;
	return match;
}

uintptr_t __gnu_Unwind_Find_exidx(uintptr_t pc, int *pcount)
{
	struct find_exidx_data data;
	data.pc = pc;
	if (dl_iterate_phdr(find_exidx, &data) <= 0)
		return 0;
	*pcount = data.exidx_len / 8;
	return data.exidx_start;
}
