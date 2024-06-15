__asm__(
".text \n"
".global " START "\n"
".type   " START ", @function\n"
START ":\n"
"	move $fp, $zero\n"
"	move $a0, $sp\n"
".weak _DYNAMIC\n"
".hidden _DYNAMIC\n"
"	la.local $a1, _DYNAMIC\n"
"	bstrins.d $sp, $zero, 3, 0\n"
"	b " START "_c\n"
);
