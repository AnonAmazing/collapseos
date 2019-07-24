; 8K of onboard RAM
.equ	RAMSTART	0xc000
; Memory register at the end of RAM. Must not overwrite
.equ	RAMEND		0xddd0

	jp	init

; *** JUMP TABLE ***
	jp	strncmp
	jp	addDE
	jp	addHL
	jp	upcase
	jp	unsetZ
	jp	intoDE
	jp	intoHL
	jp	writeHLinDE
	jp	findchar
	jp	parseHex
	jp	parseHexPair
	jp	blkSel
	jp	blkSet
	jp	fsFindFN
	jp	fsOpen
	jp	fsGetC
	jp	fsPutC
	jp	fsSetSize
	jp	cpHLDE
	jp	parseArgs
	jp	printstr
	jp	_blkGetC
	jp	_blkPutC
	jp	_blkSeek
	jp	_blkTell
	jp	printcrlf
	jp	stdioPutC
	jp	stdioReadLine

.fill 0x66-$
	retn

#include "err.h"
#include "core.asm"
#include "parse.asm"

#include "sms/kbd.asm"
.equ	KBD_RAMSTART	RAMSTART
.equ	KBD_FETCHKC	smskbdFetchKCB
#include "kbd.asm"

.equ	VDP_RAMSTART	KBD_RAMEND
#include "sms/vdp.asm"

.equ	STDIO_RAMSTART	VDP_RAMEND
#include "stdio.asm"

.equ	MMAP_START	0xd800
.equ	MMAP_LEN	RAMEND-MMAP_START
#include "mmap.asm"

.equ	BLOCKDEV_RAMSTART	STDIO_RAMEND
.equ	BLOCKDEV_COUNT		3
#include "blockdev.asm"
; List of devices
.dw	mmapGetC, mmapPutC
.dw	f0GetC, f0PutC
.dw	f1GetC, f1PutC


.equ	FS_RAMSTART	BLOCKDEV_RAMEND
.equ	FS_HANDLE_COUNT	2
#include "fs.asm"

.equ	SHELL_RAMSTART	FS_RAMEND
.equ	SHELL_EXTRA_CMD_COUNT 11
#include "shell.asm"
.dw	edCmd, zasmCmd, fnewCmd, fdelCmd, fopnCmd, flsCmd, fsOnCmd, blkBselCmd
.dw	blkSeekCmd, blkLoadCmd, blkSaveCmd

#include "blockdev_cmds.asm"
#include "fs_cmds.asm"

init:
	di
	im	1

	ld	sp, RAMEND

	; init a FS in mmap
	ld	hl, MMAP_START
	ld	a, 'C'
	ld	(hl), a
	inc	hl
	ld	a, 'F'
	ld	(hl), a
	inc	hl
	ld	a, 'S'
	ld	(hl), a

	ld	hl, kbdGetC
	ld	de, vdpPutC
	call	stdioInit
	call	fsInit
	xor	a
	ld	de, BLOCKDEV_SEL
	call	blkSel
	call	fsOn

	call	kbdInit
	call	vdpInit

	call	shellInit
	jp	shellLoop

f0GetC:
	ld	ix, FS_HANDLES
	jp	fsGetC

f0PutC:
	ld	ix, FS_HANDLES
	jp	fsPutC

f1GetC:
	ld	ix, FS_HANDLES+FS_HANDLE_SIZE
	jp	fsGetC

f1PutC:
	ld	ix, FS_HANDLES+FS_HANDLE_SIZE
	jp	fsPutC

edCmd:
	.db	"ed", 0, 0, 0b1001, 0, 0
	push	hl \ pop ix
	ld	l, (ix)
	ld	h, (ix+1)
	jp	0x1900

zasmCmd:
	.db	"zasm", 0b1001, 0, 0
	push	hl \ pop ix
	ld	l, (ix)
	ld	h, (ix+1)
	jp	0x1d00

; last time I checked, PC at this point was 0x183c. Let's give us a nice margin
; for the start of ed.
.fill 0x1900-$
.bin "ed.bin"

; Last check: 0x1c4e
.fill 0x1d00-$
.bin "zasm.bin"

.fill 0x7ff0-$
.db "TMR SEGA", 0x00, 0x00, 0xfb, 0x68, 0x00, 0x00, 0x00, 0x4c


