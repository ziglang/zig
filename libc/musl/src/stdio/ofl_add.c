#include "stdio_impl.h"

FILE *__ofl_add(FILE *f)
{
	FILE **head = __ofl_lock();
	f->next = *head;
	if (*head) (*head)->prev = f;
	*head = f;
	__ofl_unlock();
	return f;
}
