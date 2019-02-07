# This file is split out to provide better code coverage.
	.global	split
	.type	split,@function
split:
	retq

	.size	split,. - split

	.section	.note.GNU-stack,"",@progbits
	.section	.note.GNU-split-stack,"",@progbits
