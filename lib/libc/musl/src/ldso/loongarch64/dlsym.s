.global dlsym
.hidden __dlsym
.type   dlsym,@function
dlsym:
	move      $a2, $ra
	la.global $t0, __dlsym
	jr        $t0
