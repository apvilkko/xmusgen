; branches to \3 when \1 >= \2
gte_branch	macro
	lda \1
	cmp \2
	bcs \3
	endmacro

; branches to \2 with probability \1
if_rand	macro
	ldx \1
	jsr Rand
	cmp #1
	beq \2
	endmacro