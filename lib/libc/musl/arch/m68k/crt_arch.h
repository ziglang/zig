__asm__(
".text\n"
".weak _DYNAMIC \n"
".hidden _DYNAMIC \n"
".global " START "\n"
START ":\n"
"	suba.l %fp,%fp \n"
"	movea.l %sp,%a0 \n"
"	lea _DYNAMIC-.-8,%a1 \n"
"	pea (%pc,%a1) \n"
"	pea (%a0) \n"
"	lea " START "_c-.-8,%a1 \n"
"	jsr (%pc,%a1) \n"
);
