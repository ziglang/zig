.syntax unified
.text
.global __unmapself
.type   __unmapself,%function
__unmapself:
	mov r7,#91
	svc 0
	mov r7,#1
	svc 0
