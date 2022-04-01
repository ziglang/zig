
.386
.model flat, c

.code

slp_switch_raw PROC save_state:DWORD, restore_state:DWORD, extra:DWORD
  
  ;save registers. EAX ECX and EDX are available for function use and thus
  ;do not have to be stored.
  push ebx
  push esi
  push edi
  push ebp
  
  mov esi, restore_state ; /* save 'restore_state' for later */
  mov edi, extra ;         /* save 'extra' for later         */

  mov eax, esp

  push edi ;               /* arg 2: extra                       */
  push eax ;               /* arg 1: current (old) stack pointer */
  mov  ecx, save_state
  call ecx ;               /* call save_state()                  */

  test eax, eax;           /* skip the restore if the return value is null */
  jz exit

  mov esp, eax;            /* change the stack pointer */

  push edi ;               /* arg 2: extra                       */
  push eax ;               /* arg 1: current (new) stack pointer */
  call esi ;               /* call restore_state()               */

exit:
  add esp, 8
  pop  ebp
  pop  edi
  pop  esi
  pop  ebx
  ret
slp_switch_raw ENDP

end