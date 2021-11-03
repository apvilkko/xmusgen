;================================
; LOADER
;================================

	org $07ff
	db $01,$08 ; prg header (BASIC program memory start $0801)

; BASIC loader
	db $0c,$08 ; pointer to next BASIC line
	db $0a,$00 ; line number (10)
	db $9e ; SYS token
	text "11904" ; program start in decimal
	db $00 ; end of basic line
	db $00,$00 ; end of program

;================================
; DEFINITIONS
;================================

	org $2e80

	include "defs.asm"
	include "macros.asm"

scanresult = $10
tick = $18
color = $19
beatcounter = $1a
voiceframe1 = $1b
temp = $1c
offset = $1d
voiceframe2 = $1e
voiceframe3 = $1f
quartercount = $20
voiceframe4 = $21

SIXTEENTH1 = 8
EIGHTH = 13
SIXTEENTH2 = 20

;================================
; PROGRAM START
;================================

Start:
	jsr Init
	jmp Loop

Init:
	sei
	cld

	lda #%01111111
	sta INT_CTL_STA		; switch off interrupt signals from CIA-1

	and SCREEN_CTL_1	; clear most significant bit of VIC's raster register
	sta SCREEN_CTL_1

	lda INT_CTL_STA		; acknowledge pending interrupts
	lda INT_CTL_STA2

	lda #$20
	sta RASTER_LINE

	lda #<Isr		; set ISR vector
	sta ISR_LO
	lda #>Isr
	sta ISR_HI

	lda #$01
	sta INT_CTL		; enable raster interrupt

	lda #COLOR_GREY_3
	sta SCR_COLOR_BORDER
	lda #COLOR_BLACK
	sta color
	sta SCR_COLOR_BACKGROUND

	tax
	lda #PETSCII_SPACE
clearScreenLoop:
	sta SCREEN_MEM,x
	sta SCREEN_MEM + $100,x
	sta SCREEN_MEM + $200,x
	sta SCREEN_MEM + $300,x
	dex
	bne clearScreenLoop

ClearSid:
	ldx #$1d
	lda #$00
.clearloop:
	sta SID_REGS
	dex
	bne .clearloop

	lda #%00001111	; volume to max
	sta SID_FLT_VM

	lda #$ff
	sta voiceframe1
	sta voiceframe2
	sta voiceframe3
	sta voiceframe4
	lda #$00
	sta quartercount

	cli 			; clear interrupt flag, allowing the CPU to respond to interrupt requests

	rts

Loop:
	jmp Loop

;================================
; INTERRUPT
;================================

Isr:
	asl INT_STATUS	; acknowledge the interrupt by clearing the VIC's interrupt flag
	jsr ReadKeyboard
	inc tick
	inc beatcounter

	gte_branch #24, beatcounter, SkipBeat
	inc color
	lda color
	sta SCR_COLOR_BACKGROUND
	lda #0
	sta beatcounter

	inc quartercount
	lda quartercount
	cmp #4
	bne SkipBeat
	lda #0
	sta quartercount

SkipBeat:

	jsr SoundEngine

	jmp $EA81

;================================
; SUBROUTINES
;================================

SoundEngine:

	lda beatcounter
	cmp #0
	beq OnSixteenth
	cmp #SIXTEENTH1
	beq OnSixteenth
	cmp #EIGHTH
	beq OnSixteenth
	cmp #SIXTEENTH2
	beq OnSixteenth

	jmp RunSounds

OnSixteenth:

	cmp #0
	beq DoTriggerKick
	cmp #SIXTEENTH2
	beq PossiblyTriggerKick
	cmp #EIGHTH
	beq PossiblyTriggerKick
	jmp CheckHihat
PossiblyTriggerKick:
	if_rand #$10, DoTriggerKick
	jmp CheckHihat
DoTriggerKick:
	jsr TriggerKick
CheckHihat:
	lda beatcounter
	cmp #EIGHTH
	beq DoTriggerHihat
	cmp #SIXTEENTH2
	beq PossiblyTriggerHihat
	jmp CheckSnare
PossiblyTriggerHihat:
	if_rand #$40, DoTriggerHihat
	jmp CheckSnare
DoTriggerHihat:
	jsr TriggerHihat
CheckSnare:
	lda quartercount
	cmp #1
	beq IsOffBeat
	cmp #3
	beq IsOffBeat
	lda beatcounter
	cmp #SIXTEENTH1
	beq PossiblyTriggerSnare
	if_rand #$20, DoTriggerBass
	jmp RunSounds
IsOffBeat:
	lda beatcounter
	cmp #0
	beq DoTriggerSnare
	jmp RunSounds
PossiblyTriggerSnare:
	if_rand #$30, DoTriggerSnare
	jmp RunSounds
DoTriggerSnare:
	jsr TriggerSnare
	jmp RunSounds
DoTriggerBass:
	jsr TriggerBass
	jmp RunSounds

TriggerKick:
	lda #0
	sta voiceframe1
	rts
TriggerHihat:
	lda #0
	sta voiceframe2
	rts
TriggerSnare:
	lda #0
	sta voiceframe3
	rts
TriggerBass:
	; don't trigger when snare started since same channel
	lda voiceframe3
	cmp #$ff
	bne DontPlayBass
	lda #0
	sta voiceframe4
DontPlayBass:
	rts

RunSounds:
	lda voiceframe1
	cmp #$ff
	beq SkipVoice1

	jsr SetSoundOffset

	ldy #0
.loopframe:
	tya
	clc
	adc offset
	tax
	lda Kick1,x
	sta SID_V1_FREQ_1,y
	iny
	cpy #7
	bne .loopframe

	inc voiceframe1
	lda voiceframe1
	cmp #8
	beq ResetVoiceFrame1
	jmp SkipVoice1

ResetVoiceFrame1:
	lda #$ff
	sta voiceframe1

SkipVoice1:
	lda voiceframe2
	cmp #$ff
	beq SkipVoice2
	jsr SetSoundOffset

	ldy #0
.loopframe:
	tya
	clc
	adc offset
	tax
	lda Hihat1,x
	sta SID_V2_FREQ_1,y
	iny
	cpy #7
	bne .loopframe

	inc voiceframe2
	lda voiceframe2
	cmp #8
	beq ResetVoiceFrame2
	jmp SkipVoice2
ResetVoiceFrame2:
	lda #$ff
	sta voiceframe2

SkipVoice2:
	lda voiceframe3
	cmp #$ff
	beq SkipVoice3
	jsr SetSoundOffset

	ldy #0
.loopframe:
	tya
	clc
	adc offset
	tax
	lda Snare1,x
	sta SID_V3_FREQ_1,y
	iny
	cpy #7
	bne .loopframe

	inc voiceframe3
	lda voiceframe3
	cmp #8
	beq ResetVoiceFrame3
	jmp SkipVoice3
ResetVoiceFrame3:
	lda #$ff
	sta voiceframe3

SkipVoice3:
	lda voiceframe4
	cmp #$ff
	beq SkipVoice4
	jsr SetSoundOffset

	ldy #0
.loopframe:
	tya
	clc
	adc offset
	tax
	lda Bass1,x
	sta SID_V3_FREQ_1,y
	iny
	cpy #7
	bne .loopframe

	inc voiceframe4
	lda voiceframe4
	cmp #8
	beq ResetVoiceFrame4
	jmp SkipVoice4
ResetVoiceFrame4:
	lda #$ff
	sta voiceframe4

SkipVoice4:
	rts

SetSoundOffset:
	tax
	lda #-8
	sta offset
.addoffset:
	lda #8
	clc
	adc offset
	sta offset
	dex
	bmi .exit
	jmp .addoffset
.exit:
	rts

ReadKeyboard:
	lda #%11111110
	sta CIA_PORT_A
	ldy CIA_PORT_B
	sty scanresult+7
	sec
	rol
	sta CIA_PORT_A
	ldy CIA_PORT_B
	sty scanresult+6
	rol
	sta CIA_PORT_A
	ldy CIA_PORT_B
	sty scanresult+5
	rol
	sta CIA_PORT_A
	ldy CIA_PORT_B
	sty scanresult+4
	rol
	sta CIA_PORT_A
	ldy CIA_PORT_B
	sty scanresult+3
	rol
	sta CIA_PORT_A
	ldy CIA_PORT_B
	sty scanresult+2
	rol
	sta CIA_PORT_A
	ldy CIA_PORT_B
	sty scanresult+1
	rol
	sta CIA_PORT_A
	ldy CIA_PORT_B
	sty scanresult
	rts

Rand:
	stx temp
	lda #$ff
	sta SID_V3_FREQ_1
	sta SID_V3_FREQ_2
	lda SID_V3_OSC
	cmp temp
	bcs .other
	lda #1
	rts
.other:
	lda #0
	rts


;================================
; DATA
;================================

	;  FRL  FRH  PWL  PWH  CTL  AD   SR   Unused
Kick1:
	db $29, $34, $00, $04, $81, $00, $f4, $00
	db $29, $34, $00, $04, $81, $00, $f4, $00
	db $e8, $06, $00, $04, $41, $00, $f4, $00
	db $74, $03, $00, $04, $41, $00, $f4, $00
	db $96, $02, $00, $04, $41, $00, $f4, $00
	db $2d, $02, $00, $04, $41, $00, $f4, $00
	db $2d, $02, $00, $04, $11, $00, $f4, $00
	db $2d, $02, $00, $04, $10, $00, $f4, $00

Hihat1:
	db $ff, $ff, $00, $04, $81, $00, $a2, $00
	db $f0, $c4, $00, $04, $81, $00, $a2, $00
	db $10, $7c, $00, $04, $81, $00, $a2, $00
	db $74, $af, $00, $04, $11, $00, $a2, $00
	db $10, $7c, $00, $04, $81, $00, $a2, $00
	db $10, $7c, $00, $04, $80, $00, $a2, $00
	db $10, $7c, $00, $04, $80, $00, $a2, $00
	db $10, $7c, $00, $04, $80, $00, $a2, $00

Snare1:
	db $20, $f8, $00, $04, $81, $00, $f3, $00
	db $20, $f8, $00, $04, $81, $00, $f3, $00
	db $15, $1a, $00, $04, $81, $00, $f3, $00
	db $0a, $0d, $00, $04, $21, $00, $f3, $00
	db $96, $02, $00, $04, $80, $00, $f3, $00
	db $2d, $02, $00, $04, $80, $00, $f3, $00
	db $2d, $02, $00, $04, $80, $00, $f3, $00
	db $2d, $02, $00, $04, $80, $00, $f3, $00

Bass1:
	db $96, $02, $00, $04, $41, $00, $f4, $00
	db $96, $02, $00, $04, $41, $00, $f4, $00
	db $96, $02, $00, $04, $41, $00, $f4, $00
	db $96, $02, $00, $04, $41, $00, $f4, $00
	db $96, $02, $00, $04, $41, $00, $f4, $00
	db $96, $02, $00, $04, $41, $00, $f4, $00
	db $96, $02, $00, $04, $41, $00, $f4, $00
	db $96, $02, $00, $04, $40, $00, $f4, $00