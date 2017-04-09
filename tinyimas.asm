; 
; TINYIM@S For MZ-700
; 

GETKY			EQU	001Bh
WAITKEY			EQU	09B3h
BLNK			EQU	0DA6h	; ?BLNK

;;
PICNUM			EQU	34				; �G�̖���

CODE_LOCATE		EQU	0FCh			; �`��ʒu�����w��
CODE_BCHG		EQU	0FDh			; �������E�Ђ炪�� xor�t���O
CODE_CR			EQU	0FEh			; ���s�R�[�h
CODE_EOS		EQU	0FFh			; ������I��

MESWIN_X		EQU	4				; �E�B���h�E�w�ʒu
MESWIN_Y		EQU	22				; �E�B���h�E�x�ʒu
MESWIN_W		EQU	29				; �E�B���h�E��
MESWIN_H		EQU	3				; �E�B���h�E����

MESPOS_X		EQU	5				; ���b�Z�[�W�w�ʒu
MESPOS_Y		EQU	22				; ���b�Z�[�W�x�ʒu

DISP_SEI		EQU	0D7H			; ��

PROF_WAIT_TIME	equ	01E0h			; �v���t�B�[���E�F�C�g����
ANM_WAIT_TIME	equ	0E8h			; �A�j���E�F�C�g����


	ORG 1200h

START:
	JP		ENTRY
	;------------------------------------------------
	; ���[�N�G���A
	;------------------------------------------------
PUTS_X:
	DS	1
PUTS_Y:
	DS	1
PUTS_SMALL:	; �������^�Ђ炪�ȃt���O
	DS	1

	; �W�J���[�N�G���A
EXPAND_BUF:
	DS	1				; +0 ���kBIT
	DS	1				; +1 �f�[�^
	DS	2				; +2 �W�J��̃T�C�Y
	DS	1				; +4 8BIT���[�v�J�E���^


	;------------------------------------------------
	; ���������g���r㻂���̃T�u���[�`����������
	;------------------------------------------------
;============================================================================
;	�e�[�v����f�[�^��ǂ�ŃX�s�[�J�[�ɗ�����
;	VRAM�ɃL�����O���f�[�^��]������
;
;	IN:	HL = �L�����O���f�[�^�A�h���X
;			(Chr�~1000�o�C�g, Attr�~1000�o�C�g)
;	OUT:	�Ȃ�
;	�j��:	�S���W�X�^
;
TRANS_WITH_TAPEPLAY:

;	DI					; ���荞�݋֎~��ԂŌĂԂ��ƁI
	LD	(SPSAVE+1), SP

	LD	BC, 100*256+20H			; B: 10*100=1000
						; C: 8255 RDATA�}�X�N �� 8253�R���g���[�����[�h��RL[1:0]
	LD	DE, 10				; �|�C���^����
	LD	IX, 0D000H + 10			; �]����A�h���X(�L�����N�^)
	LD	IY, 0D800H + 10			; �]����A�h���X(�A�g���r���[�g)

	LD	A, (0D000H)			; �ŏ���VRAM�A�N�Z�X���\�����Ԃɍs����悤�ɂ��邽�߁A
						; VRAM�̃E�F�C�g���g���ĊJ�n�^�C�~���O�����킹��

LOOP0:						; ���߂̃N���b�N�� (���v) {�\�����Ԃɂ����鍇�v}
	; �e�[�v�̍Đ�
	LD	A, (0E002H)			; 13		8255 PortC����RDATA��ǂ�
	AND	C				;  4		RDATA�����o��
	RRCA					;  4		Bit5 �� Bit3 ��
	RRCA					;  4		(RDATA=1�Ȃ�Mode4, 0�Ȃ�Mode0���Z�b�g)
	OR	C				;  4		Read/Load = 10B
	LD	(0E007H), A			; 13 (42) {42}	8253 Ch.0 ���[�h�Z�b�g

	; �]���f�[�^��ǂݏo��
	LD	SP, HL				;  6
	EXX					;  4
	POP	AF				; 10
	EX	AF, AF'				;  4 '
	POP	AF				; 10
	POP	BC				; 10
	POP	DE				; 10
	POP	HL				; 10
	LD	SP, IX				; 10 (74) {116}

	; �]���f�[�^����������
	PUSH	HL				; 11 (5/3+3) [�\������ 5 / �u�����N���� 6] {121}
	PUSH	DE				; 11 (17)
	PUSH	BC				; 11 (28)
	PUSH	AF				; 11 (39)
	EX	AF, AF'				;  4 (43)'
	PUSH	AF				; 11 (54)
	EXX					;  4 (58) [�u�����N���Ԏc�� 5] {116}

	ADD	HL, DE				; 11
	ADD	IX, DE				; 15 (26) {142}

	DJNZ	LOOP0				; 13 {155}

	LD	B, 100				;  7 {157}

LOOP1:
	LD	A, (0E002H)
	AND	C
	RRCA
	RRCA
	OR	C
	LD	(0E007H), A

	LD	SP, HL
	EXX
	POP	AF
	EX	AF, AF'
	POP	AF
	POP	BC
	POP	DE
	POP	HL
	LD	SP, IY

	PUSH	HL
	PUSH	DE
	PUSH	BC
	PUSH	AF
	EX	AF, AF'
	PUSH	AF
	EXX

	ADD	HL, DE
	ADD	IY, DE

	DJNZ	LOOP1

SPSAVE:
	LD	SP, 0
	RET

;============================================================================
;	�e�[�v����f�[�^��ǂ�ŃX�s�[�J�[�ɗ�����
;	�����ԃ��[�v����
;
;	IN:	BC = ���[�v�� (1�� ��3.1ms)
;	OUT:	�Ȃ�
;	�j��:	AF, BC, BC', DE', HL'
;
WAIT_WITH_TAPEPLAY:
	EXX
	LD	HL, 0E002H
	LD	DE, 0E007H
	LD	BC,  0020H
	EXX
	DEC	BC			;16bit�̃��[�v[BC]��8bit��2�d���[�v[[B]C]�ɑg�ݑւ���
	INC	B			; if (C!=0) B++;
	INC	C
	LD	A, B
	LD	B, C
	LD	C, A
L2:	EXX
L1:	LD	A, (HL)			; 7
	AND	C			; 4
	RRCA				; 4
	RRCA				; 4
	OR	C			; 4
	LD	(DE), A			; 7 (30)
	DJNZ	L1			;13 (43)
	EXX
	DJNZ	L2
	DEC	C
	JP	NZ, L2
	RET
	;------------------------------------------------
	; ���������g���r㻂���̃T�u���[�`����������
	;------------------------------------------------

	;------------------------------------------------
	; VSYNC���w��̕������҂�
	;------------------------------------------------
	; B=�҂�
WAIT_VSYNC:
	CALL	BLNK
	DJNZ	WAIT_VSYNC
	RET

	;------------------------------------------------
	; �L�[���͂�҂��X�g���[�~���O
	;------------------------------------------------
PAUSE:
	LD	HL, 0E002H
	LD	DE, 0E007H
	LD	BC,  0020H
	
	LD	A, (HL)			; 7
	AND	C			; 4
	RRCA				; 4
	RRCA				; 4
	OR	C			; 4
	LD	(DE), A			; 7 (30)

	;
	CALL	GETKY
	CP		00h
	JR		Z, PAUSE
	RET

	;------------------------------------------------
	; �L�[���͂�҂��X�g���[�~���O
	;------------------------------------------------
WAIT_SOUNDSTART:
	LD	HL, 0E002H
	LD	DE, 0E007H
	LD	BC,  0020H
WAIT_SNDLP:
	LD	A, (HL)			; 7
	AND	C			; 4
	RRCA				; 4
	RRCA				; 4
	OR	C			; 4
	LD	(DE), A			; 7 (30)
	
	BIT		3,A
	JR		NZ,WAIT_SNDEXIT

	;
	CALL	GETKY
	CP		00h
	JR		Z, WAIT_SNDLP
WAIT_SNDEXIT:
	RET

	;------------------------------------------------
	; ��������҂�
	; ADDR:012C0h
	;------------------------------------------------
WAIT_NOSND:
	LD	DE, 0000H		; DE'=�����J�E���^

	EXX
	LD	HL, 0E002H
	LD	DE, 0E007H
	LD	BC, 0FF20H		; 0020H+(100*256)
WAIT_NOSNDLP:
	; �T�E���h�Đ�
	LD	A, (HL)			; 7
	AND	C			; 4
	RRCA				; 4
	RRCA				; 4
	OR	C			; 4
	LD	(DE), A			; 7 (30)
	
	;
	BIT		3,A
	JR		Z,@f	; �����A����������X�L�b�v 12D5 Z=28 NZ=20
	;
	EXX
	INC		DE		; �����J�E���^++
	EXX
@@:	
	DJNZ	WAIT_NOSNDLP
	
	EXX
	LD		A,E
	CP		01h			; �����J�E���^��1�����������烋�[�v(12DFh)
	JR		NC,WAIT_NOSND


WAIT_NOSNDEXIT:
	RET

	;------------------------------------------------
	; �������t�B��
	;------------------------------------------------
	; HL=�A�h���X
	; BC=�o�C�g��
	; A=���߂�f�[�^
MEMFILL:
	LD		D,H
	LD		E,L
	INC		DE
	DEC		BC
	LD		(HL),A
	LDIR
	RET

	;------------------------------------------------
	; ��ʃN���A
	;------------------------------------------------
CLS:
	CALL	BLNK
	LD		HL,0D000H
	LD		BC,1000
	XOR		A
	CALL	MEMFILL
	; �J���[RAM�N���A
	LD		HL,0D800H
	LD		BC,1000
	LD		A,070h
	CALL	MEMFILL
	RET

	;------------------------------------------------
	; ���C��
	;------------------------------------------------
ENTRY:
	; �o���i�����S
	DI
	LD		A,0
	CALL	CGPUT_EXP

	; ���ԑ҂�
	LD		B,180			; �R�b��180V
	CALL	WAIT_VSYNC

	; �i���R���S
	LD		A,1
	CALL	CGPUT_EXP

	; ���ԑ҂�
	LD		B,240			; �S�b��240V
	CALL	WAIT_VSYNC

	; ProjectIM@S���S
	LD		A,3
	CALL	CGPUT_EXP

	; ���ԑ҂�
;	LD		B,240			; �S�b��240V
	LD		B,60			; �P�b��60V
	CALL	WAIT_VSYNC
;	EI

	; ���X�g���b�Z�[�W�@�e�X�g
;	JP		LAST

	; ��[�L�[���͑҂�
;	CALL	PAUSE

	; ���荞�݋֎~
;	DI

	; �^�C�g����ʁ@���O�W�J
	LD		HL,CG04			; HL = CG�P����
	LD		DE,CG05			; DE = CG�Q����
	CALL	EXP_URARAM

	; �������n�܂�܂ő҂�
	CALL	WAIT_SOUNDSTART

	; �^�C�g�����
	LD		HL, 0000h
	CALL	CGPUT_IMD_URA

	; �e�[�v�Đ�
;ADDR:
;	LD		BC,11025		; ��R�S�b HEX=2B11h
	LD		BC,10864		; HEX=2A70h
	CALL	WAIT_WITH_TAPEPLAY

	; �V�U�T�v�����
;	LD		A,5
;	CALL	CGPUT_EXP
	LD		HL, 0800h
	CALL	CGPUT_IMD_URA

	LD		HL,CG06			; HL = CG�P����
	LD		DE,0000H		; DE = CG�Q����
	CALL	EXP_URARAM

	; �e�[�v�Đ�
	LD		BC,323		; ��P�b
	CALL	WAIT_WITH_TAPEPLAY

	; �В��\��
;	LD		A,6						; 765Pro+�В�
;	CALL	CGPUT_EXP
	LD		HL, 0000h
	CALL	CGPUT_IMD_URA

	; �e�[�v�Đ�
	LD		BC,323		; ��P�b
	CALL	WAIT_WITH_TAPEPLAY

	; �В� �O�����b�Z�[�W
	LD		A,0						; ���[�A�����ł��������݂Ă��邫�݁I
	CALL	MESPUT

	; �e�[�v�Đ�
	LD		BC,2580		; ��8�b		; 012D8
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,1						; �ق��A�Ȃ�Ƃ����@�炪�܂���(10sec)
	CALL	MESPUT

	; �e�[�v�Đ�
	LD		BC,3225
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,2						; �킪����͂���(8sec)
	CALL	MESPUT

	; �e�[�v�Đ�
	LD		BC,2580
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,3						; �킪����ɂ��傼������(7sec)
	CALL	MESPUT

	; �e�[�v�Đ�
	LD		BC,2258
	CALL	WAIT_WITH_TAPEPLAY

	;-------
	; �t��
	;-------
	; ���O�ɃL�����O���W�J
	LD		HL,CG10
	LD		DE,CG12
	CALL	EXP_URARAM

	; CG10
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

	; �e�[�v�Đ�
;	LD		BC,162		; ��0.5�b
	LD		BC,ANM_WAIT_TIME		; 130Eh
	CALL	WAIT_WITH_TAPEPLAY

	; CG11
	LD		A,11
	CALL	CGPUT

	; �e�[�v�Đ�
	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY

	; CG12
	LD		HL,0800h
	CALL	CGPUT_IMD_URA

	; �e�[�v�Đ�
	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY

	; CG13
	LD		A,13
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG14
	LD		A,14
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; addr:133B
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; ��������҂�
	CALL	WAIT_NOSND

	;-------
	; �瑁
	;-------
	; ���O�ɃL�����O���W�J
	LD		HL,CG15
	LD		DE,CG17
	CALL	EXP_URARAM

	; CG15
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

;	LD		BC,162				; ��0.5�b
	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG16
	LD		A,16
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG17
	LD		HL,0800h
	CALL	CGPUT_IMD_URA

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG18
	LD		A,18
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG19
	LD		A,19
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; 
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; ��������҂�
	CALL	WAIT_NOSND

	;-------
	; ���
	;-------
	; ���O�ɃL�����O���W�J
	LD		HL,CG20
	LD		DE,0000h
	CALL	EXP_URARAM

	; CG20
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG21
	LD		A,21
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG22
	LD		A,22
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG23
	LD		A,23
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG24
	LD		A,24
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; 
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; ��������҂�
	CALL	WAIT_NOSND

	;-------
	; ��悢
	;-------
	; ���O�ɃL�����O���W�J
	LD		HL,CG25
	LD		DE,0000h
	CALL	EXP_URARAM

	; CG25
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG26
	LD		A,26
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG27
	LD		A,27
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG28
	LD		A,28
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG29
	LD		A,29
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; 
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; ��������҂�
	CALL	WAIT_NOSND

	;-------
	; ���q
	;-------
	; ���O�ɃL�����O���W�J
	LD		HL,CG30
	LD		DE,0000h
	CALL	EXP_URARAM

	; CG30
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG31
	LD		A,31
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG32
	LD		A,32
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG33
	LD		A,33
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; CG34
	LD		A,34
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; 
	CALL	WAIT_WITH_TAPEPLAY	; �e�[�v�Đ�

	; ��������҂�
	CALL	WAIT_NOSND

	; �В��\��
	LD		A,6						; 765Pro+�В�
	CALL	CGPUT_EXP

	; �e�[�v�Đ�
	LD		BC,323		; ��P�b
	CALL	WAIT_WITH_TAPEPLAY

	; �В� �㔼���b�Z�[�W
	LD		A,4						; �ǂ����A�݂�ȁ@�Ȃ��Ȃ��@�䂤�ڂ���������
	CALL	MESPUT

;	LD		BC,3225		; 
	LD		BC,3000		; 
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,5						; �܁A���킵���́A�ɂイ���Ⴕ�Ă���Ƃ������Ƃ�
	CALL	MESPUT

	LD		BC,2580		; 
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,6						; ���A���[���A�ǂ��ւ����񂾂�
	CALL	MESPUT

	LD		BC,3225					; 10sec
	CALL	WAIT_WITH_TAPEPLAY

LAST:
	CALL	CLS						; ��ʃN���A
	; �G���f�B���O���b�Z�[�W�\��
	LD		DE,MSGLAST1
	CALL	MSGPUT

	; �Ă��Ă��ā[
	LD		BC,3225					; 10sec
	CALL	WAIT_WITH_TAPEPLAY
	
	CALL	CLS						; ��ʃN���A
	; �G���f�B���O���b�Z�[�W�\��
	LD		DE,MSGLAST2
	CALL	MSGPUT
	
;TETETE_LOOP:
	LD		BC,3225					; 10sec
	CALL	WAIT_WITH_TAPEPLAY
;	JR		TETETE_LOOP

	EI
	CALL	WAITKEY
	JP	0000H

	;------------------------------------------------
	; ���k�W�J
	;------------------------------------------------
	; HL = ���k�f�[�^
	; DE = �W�J��
EXPAND:
	LD		IX,EXPAND_BUF
	LD		IY,0
	; �W�J��̃T�C�Y�@�Q�b�g
	LD		A,(HL)
	LD		(IX+2),A
	INC		HL
	LD		A,(HL)
	LD		(IX+3),A
	INC		HL
EXPAND_LOOP:
	; ���k�t���O�Q�b�g
	LD		A,(HL)
	INC		HL
	LD		(IX),A		; ���k�t���O�Ҕ�

	LD		B,8			; �r�b�g�W�J���[�v��
EXPAND_8EXT:
	LD		(IX+4),B	; 8BIT ���[�v�J�E���^�Ҕ�
	
	RLC		(IX)
	JR		NC,EXPAND_BETA
	
	; ���k�t���OON
	LD		A,(HL)		; �f�[�^�Q�b�g
	INC		HL
	LD		(IX+1),A	; �f�[�^�Ҕ�
	LD		A,(HL)		; ���[�v���擾
	INC		HL

	LD		B,A			; B=���[�v��
	LD		A,(IX+1)	; A=�W�J�f�[�^
EXPAND_ELP:
	LD		(DE),A
	INC		DE
	INC		IY			; �W�J�T�C�Y�@���Z
	DJNZ	EXPAND_ELP
	
	JR		EXPAND_CNT
	
	; ���k�t���Ooff
EXPAND_BETA:
	LD		A,(HL)		; �f�[�^�Q�b�g
	INC		HL
	LD		(DE),A		; �f�[�^�Z�b�g
	INC		DE
	INC		IY

	; ���[�v���@�c��`�F�b�N
EXPAND_CNT:
	LD		A,IYL
	CP		(IX+2)
	JR		NZ,@f
	LD		A,IYH
	CP		(IX+3)
	JR		NZ,@f
	
	JR		EXPAND_END
@@:	
	LD		B,(IX+4)
	DJNZ	EXPAND_8EXT
	
	JR		EXPAND_LOOP
	
EXPAND_END:	
	RET

	;------------------------------------------------
	; �E�B���h�E�N���A
	;------------------------------------------------
WINCLR:
	LD		C,MESWIN_X
	LD		B,MESWIN_Y
	CALL	CALC_VADR		; HL=VRAM�A�h���X

	LD		B,MESWIN_H
@@:
	PUSH	HL
	PUSH	BC

	; �P�s�N���A
	PUSH	HL
	LD		(HL),00h
	POP		DE
	INC		DE
	LD		BC,MESWIN_W
	LDIR

	POP		BC
	POP		HL
	LD		DE,40
	ADD		HL,DE
	DJNZ	@b

	RET

	;------------------------------------------------
	; �L�����O���\��
	;------------------------------------------------
	; C = �\����
	; B = �\���x
	; RET : HL = ���������A�h���X
CALC_VADR:
	PUSH	BC
	PUSH	DE

	LD		H,0
	LD		L,B
	ADD		HL,HL	; x2
	ADD		HL,HL	; x4
	ADD		HL,HL	; x8
	PUSH	HL
	ADD		HL,HL	; x16
	ADD		HL,HL	; x32
	POP		DE
	ADD		HL,DE	; HL=Yx40
	LD		B,0
	ADD		HL,BC	; +X
	LD		DE,0D000h
	ADD		HL,DE

	POP		DE
	POP		BC
	RET

	;------------------------------------------------
	; ���b�Z�[�W�\��
	;------------------------------------------------
	; B = �\���x
	; C = �\����
	; DE = ���b�Z�[�W�f�[�^�A�h���X
MSGPUT:
	LD		IX,PUTS_X
	LD		(IX),C
	LD		(IX+1),B
	LD		(IX+2),0 		; �������^�Ђ炪�ȃt���O�@���Z�b�g
	JR		PUTS_ENTER
	
	;------------------------------------------------
	; ���b�Z�[�W�\��
	;------------------------------------------------
	; A = ���b�Z�[�W�ԍ�
	; B = �\���x
	; C = �\����
PUTS:
	LD		IX,PUTS_X
	LD		(IX),C
	LD		(IX+1),B
	LD		(IX+2),0 		; �������^�Ђ炪�ȃt���O�@���Z�b�g

	LD		H,0
	LD		L,A
	ADD		HL,HL
	EX		DE,HL
	LD		HL,MSGTBL
	ADD		HL,DE
	LD		E,(HL)
	INC		HL
	LD		D,(HL)			; DE=���b�Z�[�W�A�h���X

PUTS_ENTER:
	CALL	CALC_VADR		; HL=VRAM�A�h���X

PUTS_LP:
	LD		A,(DE)
	CP		CODE_EOS		; ������I�[
	JR		Z,PUTS_END

	CP		CODE_LOCATE		; �\���ʒu�w��
	JR		NZ,@f

	; �\���ʒu�w��
	INC		DE
	LD		A,(DE)			; X�擾
	LD		(IX),A
	LD		C,A
	INC		DE
	LD		A,(DE)			; Y�擾
	LD		(IX+1),A
	LD		B,A
	CALL	CALC_VADR		; HL=VRAM�A�h���X �Čv�Z
	JR		PUTS_CNT2

@@:
	CP		CODE_BCHG		; �����o���N�؂�ւ�
	JR		NZ,@f

	; �t���O���]
	LD		A,(IX+2)
	XOR		01H
	LD		(IX+2),A
	JR		PUTS_CNT2

@@:	CP		CODE_CR			; ���s
	JR		NZ,PUTS_NOCR

	; ���s
	INC		B
	LD		(IX+1),B
	CALL	CALC_VADR		; HL=VRAM�A�h���X�Čv�Z
	JR		PUTS_CNT

PUTS_NOCR:
	LD		(HL),A			; �f�B�X�v���C�R�[�h�ݒ�

	SET		3,H				; VRAM | 0800H
	LD		A,070h
	BIT		0,(IX+2)		; �������E�Ђ炪�ȃt���O
	JR		Z,@f

	OR		0F0h			; �������E�Ђ炪��

@@:	LD		(HL),A			; �J���[�R�[�h�ݒ�
	RES		3,H

PUTS_CNT:
	INC		HL
PUTS_CNT2:
	INC		DE
	JR		PUTS_LP

PUTS_END:
	RET

	;------------------------------------------------
	; ���b�Z�[�W�E�B���h�E�\��
	;------------------------------------------------
	; A = ���b�Z�[�W�ԍ�
MESPUT:
	CALL	WINCLR			; �E�B���h�E�N���A
	;
	LD		C,MESPOS_X		; X
	LD		B,MESPOS_Y		; Y
	CALL	PUTS

	RET

	;------------------------------------------------
	; �L�����O���\��
	;------------------------------------------------
	; A = �b�f�ԍ�
CGPUT:
	LD		H,0
	LD		L,A
	ADD		HL,HL
	EX		DE,HL
	LD		HL,CGTBL
	ADD		HL,DE
	LD		E,(HL)
	INC		HL
	LD		D,(HL)
	EX		DE,HL

	; �e�[�v���Đ����L�����O���]��
	CALL	TRANS_WITH_TAPEPLAY

;	;JMP	(HL)
	; �L�����]��
;	PUSH 	HL
;	LD		DE,0D000H
;	LD		BC,1000
;	LDIR

	;	�J���[�]��
;	POP	HL
;	LD		DE,1000
;	ADD		HL,DE
;	LD		DE,0D800H
;	LD		BC,1000
;	LDIR

	RET

	;------------------------------------------------
	; �L�����O���W�J���Ȃ���\��
	;------------------------------------------------
	; A = �b�f�ԍ�
CGPUT_EXP:
	LD		H,0
	LD		L,A
	ADD		HL,HL
	EX		DE,HL
	LD		HL,CGTBL
	ADD		HL,DE
	LD		E,(HL)
	INC		HL
	LD		D,(HL)
	EX		DE,HL
	
;	DI
	; $0000-$0FFF��RAM��
	OUT		(0E0h),A
	
	; ���k�W�J
	; HL = ���k�f�[�^
	; DE = �W�J��
	LD		DE,0000h
	CALL	EXPAND

	; �o���N�����j�^ROM��
	OUT		(0E2h),A
	; vsync�҂�
	CALL	BLNK
	
	; $0000-$0FFF��RAM��
	OUT		(0E0h),A

	; �L�����]��
	LD		HL,00000H
	LD		DE,0D000H
	LD		BC,1000
	LDIR

	;	�J���[�]��
	LD		HL,1000
	LD		DE,0D800H
	LD		BC,1000
	LDIR
	
	; �o���N�����j�^ROM��
	OUT		(0E2h),A
	
;	EI
	RET

	;------------------------------------------------
	; ���ڃA�h���X�̃L�����O����\��
	;------------------------------------------------
	; HL = �f�[�^�A�h���X
CGPUT_IMD_URA:
;	DI
	; $0000-$0FFF��RAM��
	OUT		(0E0h),A

	; �e�[�v���Đ����L�����O���]��
	CALL	TRANS_WITH_TAPEPLAY

	; �L�����]��
;	LD		DE,0D000H
;	LD		BC,1000
;	PUSH	HL
;	LDIR

	;	�J���[�]��
;	POP		HL
;	LD		DE,1000
;	ADD		HL,DE
;	LD		DE,0D800H
;	LD		BC,1000
;	LDIR
	
	; �o���N�����j�^ROM��
	OUT		(0E2h),A
;	EI
	RET

	;------------------------------------------------
	; �Q���̃L�����O���𗠂q�`�l�ɓW�J
	;------------------------------------------------
	; HL = CG�P����
	; DE = CG�Q����
EXP_URARAM:
;	DI
	; $0000-$0FFF��RAM��
	OUT		(0E0h),A

	; �P����
	PUSH	DE
	LD		DE,0000h
	CALL	EXPAND

	; �Q����
	POP		HL
	LD		A,H
	OR		L
	JR		Z,@f

	LD		DE,0800h
	CALL	EXPAND

@@:
	; �o���N�����j�^ROM��
	OUT		(0E2h),A
;	EI
	RET

	;-------------------------------------------------------------------------
	; DATA�Z�N�V����
	;-------------------------------------------------------------------------
DATA:

	; ���b�Z�[�W�e�[�u��
MSGTBL:
	DW	MSG00,MSG01,MSG02,MSG03
	DW	MSG04,MSG05,MSG06

	;
MSG00:
	DB	CODE_BCHG
	DISPC	'�������޺��� �ò� ��!'
	DB	CODE_CR
	DISPC	'�� ����֤��! ϧ����ͷŻ��'
	DB	CODE_EOS

MSG01:
	DB	CODE_BCHG
	DISPC	'�γ���Ĳ� �׶�ϴ�ޡ'
	DB	CODE_BCHG
	DISPC	'�߰�'
	DB	CODE_BCHG
	DISPC	'ķ�!'
	DB	CODE_CR
	DISPC	'���ֳ� ��ݻ޲� ���ò����!�'
	DB	CODE_EOS

MSG02:
	DB	CODE_BCHG
	DISPC	'�ܶ޼�� �Ϥ'
	DB	CODE_BCHG
	DISPC	'�����'
	DB	CODE_BCHG
	DISPC	'���'
	DB	DISP_SEI
	DISPC	'���'
	DB	CODE_BCHG
	DISPC	'į��'
	DB	CODE_CR
	DISPC	'�����'
	DB	CODE_BCHG
	DISPC	'����޸�'
	DB	CODE_BCHG
	DISPC	'����ޭ���'
	DB	CODE_BCHG
	DISPC	'��޼��'
	DB	CODE_CR
	DISPC	'�����!�'
	DB	CODE_EOS

MSG03:
	DB	CODE_BCHG
	DISPC	'�ܶ޼�� ���޸�٤'
	DB	CODE_BCHG
	DISPC	'�����'
	DB	CODE_BCHG
	DISPC	'���'
	DB	DISP_SEI
	DISPC	'�'
	DB	CODE_CR
	DISPC	'���ɺ�   �ɺ����!�'
	DB	CODE_EOS

MSG04:
	DB	CODE_BCHG
	DISPC	'��޳�ޤ��� ŶŶ ճ�޳����ۡ'
	DB	CODE_CR
	DISPC	'��� �ɼޮ��Ӥ�Ц �Ʋ��'
	DB	CODE_CR
	DISPC	'�ӳ֣'
	DB	CODE_EOS

MSG05:
	DB	CODE_BCHG
	DISPC	'�Ϥ�ܼ�� ƭ����ö�Ĳ����ޤ'
	DB	CODE_CR
	DISPC	'Ͻ��'
	DB	CODE_BCHG
	DISPC	'�ް�'
	DB	CODE_BCHG
	DISPC	'�ʼ��ø��ϴ�'
	DB	CODE_EOS

MSG06:
	DB	CODE_BCHG
	DISPC	'�����������޺Ʋ�����? ܶ�'
	DB	CODE_CR
	DB	CODE_BCHG
	DISPC	'765���'
	DB	CODE_BCHG
	DISPC	'ʤ����� �Ц ϯòٿ�'
	DB		0E3h		; �`
	DISPC	'�'
	DB	CODE_EOS

	; ���X�g���b�Z�[�W�P
MSGLAST1:
	;
	DB		CODE_LOCATE,3,5
	DISPC	'T'
	DB		CODE_BCHG
	DISPC	'INY '
	DB		CODE_BCHG
	DISPC	'IDOLM@STER OPENING FOR MZ-700'
	;
	DB		CODE_LOCATE,9,10
	DISPC	'S'
	DB		CODE_BCHG
	DISPC	'PECIAL '
	DB		CODE_BCHG
	DISPC	'R'
	DB		CODE_BCHG
	DISPC	'ESPECT '
	DB		CODE_BCHG
	DISPC	'T'
	DB		CODE_BCHG
	DISPC	'O �Ⱥ��'
	DB		CODE_BCHG
	DISPC	'P'
	DB		CODE_LOCATE,23,12
	DB		CODE_BCHG
	DISPC	'(SM2855320)'
	DB		CODE_BCHG
	;
	DB		CODE_LOCATE,21,16
	DISPC	'��׸��  '
	DB		CODE_BCHG
	DISPC	'�Ⱥ��'
	DB		CODE_BCHG
	DISPC	'P'
	;
	DB		CODE_LOCATE,21,18
	DISPC	'��۸��� '
	DB		CODE_BCHG
	DISPC	'�ٸ�'
	DB		CODE_BCHG
	DISPC	'P'
	DB		CODE_LOCATE,29,19
	DB		CODE_BCHG
	DISPC	'YOUKAN'
	DB		CODE_BCHG
	DISPC	'P'

	DB	CODE_EOS
	
	; ���X�g���b�Z�[�W2
MSGLAST2:
	DB		CODE_LOCATE,18,22
	DISPC	'�����'
	DB		CODE_BCHG
	DISPC	'�ݶ� ���Ͼ�ֳơ'
	DB	CODE_EOS
	
	; �L�����O���e�[�u��
CGTBL:
	DW	CG00,CG01,CG02,CG03,CG04,CG05,CG06,CG07,CG08,CG09
	DW	CG10,CG11,CG12,CG13,CG14,CG15,CG16,CG17,CG18,CG19
	DW	CG20,CG21,CG22,CG23,CG24,CG25,CG26,CG27,CG28,CG29
	DW	CG30,CG31,CG32,CG33,CG34

CG00:	; �����k
	BINCLUDE "chara/00_logo0.bin"
CG01:	; �����k
	BINCLUDE "chara/01_logo1.bin"
CG02:	; �����k
;	BINCLUDE "chara/02_logo2.bin"	; CRI LOGO Cut
CG03:	; �����k
	BINCLUDE "chara/03_ProjectIMAS.bin"
CG04:	; �����k
	BINCLUDE "chara/04_TITLE.bin"
CG05:	; �����k
	BINCLUDE "chara/05_765pro.bin"
CG06:
CG07:
CG08:
CG09:
	; �����k
	BINCLUDE "chara/06a_���Ⴟ�傤.bin"
	
	; �t��
CG10:
	; �����k
	BINCLUDE "chara/10_haruka0.bin"
CG11:
	BINCLUDE "chara/11_haruka1.bin"
CG12:
	; �����k
	BINCLUDE "chara/12_haruka2.bin"
CG13:
	BINCLUDE "chara/13_haruka3.bin"
CG14:
	BINCLUDE "chara/14_haruka4.bin"
	
	; �瑁
CG15:
	; �����k
	BINCLUDE "chara/15_chihaya0.bin"
CG16:
	BINCLUDE "chara/16_chihaya1.bin"
CG17:
	; �����k
	BINCLUDE "chara/17_chihaya2.bin"
CG18:
	BINCLUDE "chara/18_chihaya3.bin"
CG19:
	BINCLUDE "chara/19_chihaya4.bin"
	
	; �䂫��
CG20:
	; �����k
	BINCLUDE "chara/20_yukiho0.bin"
CG21:
	BINCLUDE "chara/21_yukiho1.bin"
CG22:
	BINCLUDE "chara/22_yukiho2.bin"
CG23:
	BINCLUDE "chara/23_yukiho3.bin"
CG24:
	BINCLUDE "chara/24_yukiho4.bin"
	
	; ��悢
CG25:
	; �����k
	BINCLUDE "chara/25_yayoi0.bin"
CG26:
	BINCLUDE "chara/26_yayoi1.bin"
CG27:
	BINCLUDE "chara/27_yayoi2.bin"
CG28:
	BINCLUDE "chara/28_yayoi3.bin"
CG29:
	BINCLUDE "chara/29_yayoi4.bin"
	
	; ��������
CG30:
	; �����k
		BINCLUDE "chara/30_rituko0.bin"
CG31:
	BINCLUDE "chara/31_rituko1.bin"
CG32:
	BINCLUDE "chara/32_rituko2.bin"
CG33:
	BINCLUDE "chara/33_rituko3.bin"
CG34:
	BINCLUDE "chara/34_rituko4.bin"

	END
