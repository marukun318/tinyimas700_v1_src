; 
; TINYIM@S For MZ-700
; 

GETKY			EQU	001Bh
WAITKEY			EQU	09B3h
BLNK			EQU	0DA6h	; ?BLNK

;;
PICNUM			EQU	34				; 絵の枚数

CODE_LOCATE		EQU	0FCh			; 描画位置強制指定
CODE_BCHG		EQU	0FDh			; 小文字・ひらがな xorフラグ
CODE_CR			EQU	0FEh			; 改行コード
CODE_EOS		EQU	0FFh			; 文字列終了

MESWIN_X		EQU	4				; ウィンドウＸ位置
MESWIN_Y		EQU	22				; ウィンドウＹ位置
MESWIN_W		EQU	29				; ウィンドウ幅
MESWIN_H		EQU	3				; ウィンドウ高さ

MESPOS_X		EQU	5				; メッセージＸ位置
MESPOS_Y		EQU	22				; メッセージＹ位置

DISP_SEI		EQU	0D7H			; 生

PROF_WAIT_TIME	equ	01E0h			; プロフィールウェイト時間
ANM_WAIT_TIME	equ	0E8h			; アニメウェイト時間


	ORG 1200h

START:
	JP		ENTRY
	;------------------------------------------------
	; ワークエリア
	;------------------------------------------------
PUTS_X:
	DS	1
PUTS_Y:
	DS	1
PUTS_SMALL:	; 小文字／ひらがなフラグ
	DS	1

	; 展開ワークエリア
EXPAND_BUF:
	DS	1				; +0 圧縮BIT
	DS	1				; +1 データ
	DS	2				; +2 展開後のサイズ
	DS	1				; +4 8BITループカウンタ


	;------------------------------------------------
	; ↓↓↓↓紅茶羊羹さんのサブルーチン↓↓↓↓
	;------------------------------------------------
;============================================================================
;	テープからデータを読んでスピーカーに流しつつ
;	VRAMにキャラグラデータを転送する
;
;	IN:	HL = キャラグラデータアドレス
;			(Chr×1000バイト, Attr×1000バイト)
;	OUT:	なし
;	破壊:	全レジスタ
;
TRANS_WITH_TAPEPLAY:

;	DI					; 割り込み禁止状態で呼ぶこと！
	LD	(SPSAVE+1), SP

	LD	BC, 100*256+20H			; B: 10*100=1000
						; C: 8255 RDATAマスク 兼 8253コントロールワードのRL[1:0]
	LD	DE, 10				; ポインタ増分
	LD	IX, 0D000H + 10			; 転送先アドレス(キャラクタ)
	LD	IY, 0D800H + 10			; 転送先アドレス(アトリビュート)

	LD	A, (0D000H)			; 最初のVRAMアクセスが表示期間に行われるようにするため、
						; VRAMのウェイトを使って開始タイミングを合わせる

LOOP0:						; 命令のクロック数 (合計) {表示期間における合計}
	; テープの再生
	LD	A, (0E002H)			; 13		8255 PortCからRDATAを読む
	AND	C				;  4		RDATAを取り出す
	RRCA					;  4		Bit5 → Bit3 へ
	RRCA					;  4		(RDATA=1ならMode4, 0ならMode0をセット)
	OR	C				;  4		Read/Load = 10B
	LD	(0E007H), A			; 13 (42) {42}	8253 Ch.0 モードセット

	; 転送データを読み出す
	LD	SP, HL				;  6
	EXX					;  4
	POP	AF				; 10
	EX	AF, AF'				;  4 '
	POP	AF				; 10
	POP	BC				; 10
	POP	DE				; 10
	POP	HL				; 10
	LD	SP, IX				; 10 (74) {116}

	; 転送データを書き込む
	PUSH	HL				; 11 (5/3+3) [表示期間 5 / ブランク期間 6] {121}
	PUSH	DE				; 11 (17)
	PUSH	BC				; 11 (28)
	PUSH	AF				; 11 (39)
	EX	AF, AF'				;  4 (43)'
	PUSH	AF				; 11 (54)
	EXX					;  4 (58) [ブランク期間残り 5] {116}

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
;	テープからデータを読んでスピーカーに流しつつ
;	一定期間ループする
;
;	IN:	BC = ループ回数 (1周 約3.1ms)
;	OUT:	なし
;	破壊:	AF, BC, BC', DE', HL'
;
WAIT_WITH_TAPEPLAY:
	EXX
	LD	HL, 0E002H
	LD	DE, 0E007H
	LD	BC,  0020H
	EXX
	DEC	BC			;16bitのループ[BC]を8bitの2重ループ[[B]C]に組み替える
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
	; ↑↑↑↑紅茶羊羹さんのサブルーチン↑↑↑↑
	;------------------------------------------------

	;------------------------------------------------
	; VSYNCを指定の分だけ待つ
	;------------------------------------------------
	; B=待つ回数
WAIT_VSYNC:
	CALL	BLNK
	DJNZ	WAIT_VSYNC
	RET

	;------------------------------------------------
	; キー入力を待ちつつストリーミング
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
	; キー入力を待ちつつストリーミング
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
	; 無音部を待つ
	; ADDR:012C0h
	;------------------------------------------------
WAIT_NOSND:
	LD	DE, 0000H		; DE'=無音カウンタ

	EXX
	LD	HL, 0E002H
	LD	DE, 0E007H
	LD	BC, 0FF20H		; 0020H+(100*256)
WAIT_NOSNDLP:
	; サウンド再生
	LD	A, (HL)			; 7
	AND	C			; 4
	RRCA				; 4
	RRCA				; 4
	OR	C			; 4
	LD	(DE), A			; 7 (30)
	
	;
	BIT		3,A
	JR		Z,@f	; 音声アリだったらスキップ 12D5 Z=28 NZ=20
	;
	EXX
	INC		DE		; 無音カウンタ++
	EXX
@@:	
	DJNZ	WAIT_NOSNDLP
	
	EXX
	LD		A,E
	CP		01h			; 無音カウンタが1未満だったらループ(12DFh)
	JR		NC,WAIT_NOSND


WAIT_NOSNDEXIT:
	RET

	;------------------------------------------------
	; メモリフィル
	;------------------------------------------------
	; HL=アドレス
	; BC=バイト数
	; A=埋めるデータ
MEMFILL:
	LD		D,H
	LD		E,L
	INC		DE
	DEC		BC
	LD		(HL),A
	LDIR
	RET

	;------------------------------------------------
	; 画面クリア
	;------------------------------------------------
CLS:
	CALL	BLNK
	LD		HL,0D000H
	LD		BC,1000
	XOR		A
	CALL	MEMFILL
	; カラーRAMクリア
	LD		HL,0D800H
	LD		BC,1000
	LD		A,070h
	CALL	MEMFILL
	RET

	;------------------------------------------------
	; メイン
	;------------------------------------------------
ENTRY:
	; バンナムロゴ
	DI
	LD		A,0
	CALL	CGPUT_EXP

	; 時間待ち
	LD		B,180			; ３秒＝180V
	CALL	WAIT_VSYNC

	; ナムコロゴ
	LD		A,1
	CALL	CGPUT_EXP

	; 時間待ち
	LD		B,240			; ４秒＝240V
	CALL	WAIT_VSYNC

	; ProjectIM@Sロゴ
	LD		A,3
	CALL	CGPUT_EXP

	; 時間待ち
;	LD		B,240			; ４秒＝240V
	LD		B,60			; １秒＝60V
	CALL	WAIT_VSYNC
;	EI

	; ラストメッセージ　テスト
;	JP		LAST

	; 一端キー入力待ち
;	CALL	PAUSE

	; 割り込み禁止
;	DI

	; タイトル画面　事前展開
	LD		HL,CG04			; HL = CG１枚目
	LD		DE,CG05			; DE = CG２枚目
	CALL	EXP_URARAM

	; 音声が始まるまで待つ
	CALL	WAIT_SOUNDSTART

	; タイトル画面
	LD		HL, 0000h
	CALL	CGPUT_IMD_URA

	; テープ再生
;ADDR:
;	LD		BC,11025		; 約３４秒 HEX=2B11h
	LD		BC,10864		; HEX=2A70h
	CALL	WAIT_WITH_TAPEPLAY

	; ７６５プロ画面
;	LD		A,5
;	CALL	CGPUT_EXP
	LD		HL, 0800h
	CALL	CGPUT_IMD_URA

	LD		HL,CG06			; HL = CG１枚目
	LD		DE,0000H		; DE = CG２枚目
	CALL	EXP_URARAM

	; テープ再生
	LD		BC,323		; 約１秒
	CALL	WAIT_WITH_TAPEPLAY

	; 社長表示
;	LD		A,6						; 765Pro+社長
;	CALL	CGPUT_EXP
	LD		HL, 0000h
	CALL	CGPUT_IMD_URA

	; テープ再生
	LD		BC,323		; 約１秒
	CALL	WAIT_WITH_TAPEPLAY

	; 社長 前半メッセージ
	LD		A,0						; あー、そこでこっちをみているきみ！
	CALL	MESPUT

	; テープ再生
	LD		BC,2580		; 約8秒		; 012D8
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,1						; ほう、なんといい　つらがまえだ(10sec)
	CALL	MESPUT

	; テープ再生
	LD		BC,3225
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,2						; わがしゃはいま(8sec)
	CALL	MESPUT

	; テープ再生
	LD		BC,2580
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,3						; わがしゃにしょぞくする(7sec)
	CALL	MESPUT

	; テープ再生
	LD		BC,2258
	CALL	WAIT_WITH_TAPEPLAY

	;-------
	; 春香
	;-------
	; 事前にキャラグラ展開
	LD		HL,CG10
	LD		DE,CG12
	CALL	EXP_URARAM

	; CG10
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

	; テープ再生
;	LD		BC,162		; 約0.5秒
	LD		BC,ANM_WAIT_TIME		; 130Eh
	CALL	WAIT_WITH_TAPEPLAY

	; CG11
	LD		A,11
	CALL	CGPUT

	; テープ再生
	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY

	; CG12
	LD		HL,0800h
	CALL	CGPUT_IMD_URA

	; テープ再生
	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY

	; CG13
	LD		A,13
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG14
	LD		A,14
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; addr:133B
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; 無音部を待つ
	CALL	WAIT_NOSND

	;-------
	; 千早
	;-------
	; 事前にキャラグラ展開
	LD		HL,CG15
	LD		DE,CG17
	CALL	EXP_URARAM

	; CG15
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

;	LD		BC,162				; 約0.5秒
	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG16
	LD		A,16
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG17
	LD		HL,0800h
	CALL	CGPUT_IMD_URA

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG18
	LD		A,18
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG19
	LD		A,19
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; 
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; 無音部を待つ
	CALL	WAIT_NOSND

	;-------
	; 雪歩
	;-------
	; 事前にキャラグラ展開
	LD		HL,CG20
	LD		DE,0000h
	CALL	EXP_URARAM

	; CG20
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG21
	LD		A,21
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG22
	LD		A,22
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG23
	LD		A,23
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG24
	LD		A,24
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; 
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; 無音部を待つ
	CALL	WAIT_NOSND

	;-------
	; やよい
	;-------
	; 事前にキャラグラ展開
	LD		HL,CG25
	LD		DE,0000h
	CALL	EXP_URARAM

	; CG25
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG26
	LD		A,26
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG27
	LD		A,27
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG28
	LD		A,28
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG29
	LD		A,29
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; 
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; 無音部を待つ
	CALL	WAIT_NOSND

	;-------
	; 律子
	;-------
	; 事前にキャラグラ展開
	LD		HL,CG30
	LD		DE,0000h
	CALL	EXP_URARAM

	; CG30
	LD		HL,0000h
	CALL	CGPUT_IMD_URA

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG31
	LD		A,31
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG32
	LD		A,32
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG33
	LD		A,33
	CALL	CGPUT

	LD		BC,ANM_WAIT_TIME
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; CG34
	LD		A,34
	CALL	CGPUT

	LD		BC,PROF_WAIT_TIME			; 
	CALL	WAIT_WITH_TAPEPLAY	; テープ再生

	; 無音部を待つ
	CALL	WAIT_NOSND

	; 社長表示
	LD		A,6						; 765Pro+社長
	CALL	CGPUT_EXP

	; テープ再生
	LD		BC,323		; 約１秒
	CALL	WAIT_WITH_TAPEPLAY

	; 社長 後半メッセージ
	LD		A,4						; どうだ、みんな　なかなか　ゆうぼうそうだろ
	CALL	MESPUT

;	LD		BC,3225		; 
	LD		BC,3000		; 
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,5						; ま、くわしくは、にゅうしゃしてからということで
	CALL	MESPUT

	LD		BC,2580		; 
	CALL	WAIT_WITH_TAPEPLAY

	LD		A,6						; あ、おーい、どこへいくんだね
	CALL	MESPUT

	LD		BC,3225					; 10sec
	CALL	WAIT_WITH_TAPEPLAY

LAST:
	CALL	CLS						; 画面クリア
	; エンディングメッセージ表示
	LD		DE,MSGLAST1
	CALL	MSGPUT

	; てってってー
	LD		BC,3225					; 10sec
	CALL	WAIT_WITH_TAPEPLAY
	
	CALL	CLS						; 画面クリア
	; エンディングメッセージ表示
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
	; 圧縮展開
	;------------------------------------------------
	; HL = 圧縮データ
	; DE = 展開先
EXPAND:
	LD		IX,EXPAND_BUF
	LD		IY,0
	; 展開後のサイズ　ゲット
	LD		A,(HL)
	LD		(IX+2),A
	INC		HL
	LD		A,(HL)
	LD		(IX+3),A
	INC		HL
EXPAND_LOOP:
	; 圧縮フラグゲット
	LD		A,(HL)
	INC		HL
	LD		(IX),A		; 圧縮フラグ待避

	LD		B,8			; ビット展開ループ回数
EXPAND_8EXT:
	LD		(IX+4),B	; 8BIT ループカウンタ待避
	
	RLC		(IX)
	JR		NC,EXPAND_BETA
	
	; 圧縮フラグON
	LD		A,(HL)		; データゲット
	INC		HL
	LD		(IX+1),A	; データ待避
	LD		A,(HL)		; ループ数取得
	INC		HL

	LD		B,A			; B=ループ数
	LD		A,(IX+1)	; A=展開データ
EXPAND_ELP:
	LD		(DE),A
	INC		DE
	INC		IY			; 展開サイズ　加算
	DJNZ	EXPAND_ELP
	
	JR		EXPAND_CNT
	
	; 圧縮フラグoff
EXPAND_BETA:
	LD		A,(HL)		; データゲット
	INC		HL
	LD		(DE),A		; データセット
	INC		DE
	INC		IY

	; ループ数　残りチェック
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
	; ウィンドウクリア
	;------------------------------------------------
WINCLR:
	LD		C,MESWIN_X
	LD		B,MESWIN_Y
	CALL	CALC_VADR		; HL=VRAMアドレス

	LD		B,MESWIN_H
@@:
	PUSH	HL
	PUSH	BC

	; １行クリア
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
	; キャラグラ表示
	;------------------------------------------------
	; C = 表示ｘ
	; B = 表示Ｙ
	; RET : HL = ｖｒａｍアドレス
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
	; メッセージ表示
	;------------------------------------------------
	; B = 表示Ｙ
	; C = 表示ｘ
	; DE = メッセージデータアドレス
MSGPUT:
	LD		IX,PUTS_X
	LD		(IX),C
	LD		(IX+1),B
	LD		(IX+2),0 		; 小文字／ひらがなフラグ　リセット
	JR		PUTS_ENTER
	
	;------------------------------------------------
	; メッセージ表示
	;------------------------------------------------
	; A = メッセージ番号
	; B = 表示Ｙ
	; C = 表示ｘ
PUTS:
	LD		IX,PUTS_X
	LD		(IX),C
	LD		(IX+1),B
	LD		(IX+2),0 		; 小文字／ひらがなフラグ　リセット

	LD		H,0
	LD		L,A
	ADD		HL,HL
	EX		DE,HL
	LD		HL,MSGTBL
	ADD		HL,DE
	LD		E,(HL)
	INC		HL
	LD		D,(HL)			; DE=メッセージアドレス

PUTS_ENTER:
	CALL	CALC_VADR		; HL=VRAMアドレス

PUTS_LP:
	LD		A,(DE)
	CP		CODE_EOS		; 文字列終端
	JR		Z,PUTS_END

	CP		CODE_LOCATE		; 表示位置指定
	JR		NZ,@f

	; 表示位置指定
	INC		DE
	LD		A,(DE)			; X取得
	LD		(IX),A
	LD		C,A
	INC		DE
	LD		A,(DE)			; Y取得
	LD		(IX+1),A
	LD		B,A
	CALL	CALC_VADR		; HL=VRAMアドレス 再計算
	JR		PUTS_CNT2

@@:
	CP		CODE_BCHG		; 文字バンク切り替え
	JR		NZ,@f

	; フラグ反転
	LD		A,(IX+2)
	XOR		01H
	LD		(IX+2),A
	JR		PUTS_CNT2

@@:	CP		CODE_CR			; 改行
	JR		NZ,PUTS_NOCR

	; 改行
	INC		B
	LD		(IX+1),B
	CALL	CALC_VADR		; HL=VRAMアドレス再計算
	JR		PUTS_CNT

PUTS_NOCR:
	LD		(HL),A			; ディスプレイコード設定

	SET		3,H				; VRAM | 0800H
	LD		A,070h
	BIT		0,(IX+2)		; 小文字・ひらがなフラグ
	JR		Z,@f

	OR		0F0h			; 小文字・ひらがな

@@:	LD		(HL),A			; カラーコード設定
	RES		3,H

PUTS_CNT:
	INC		HL
PUTS_CNT2:
	INC		DE
	JR		PUTS_LP

PUTS_END:
	RET

	;------------------------------------------------
	; メッセージウィンドウ表示
	;------------------------------------------------
	; A = メッセージ番号
MESPUT:
	CALL	WINCLR			; ウィンドウクリア
	;
	LD		C,MESPOS_X		; X
	LD		B,MESPOS_Y		; Y
	CALL	PUTS

	RET

	;------------------------------------------------
	; キャラグラ表示
	;------------------------------------------------
	; A = ＣＧ番号
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

	; テープを再生しつつキャラグラ転送
	CALL	TRANS_WITH_TAPEPLAY

;	;JMP	(HL)
	; キャラ転送
;	PUSH 	HL
;	LD		DE,0D000H
;	LD		BC,1000
;	LDIR

	;	カラー転送
;	POP	HL
;	LD		DE,1000
;	ADD		HL,DE
;	LD		DE,0D800H
;	LD		BC,1000
;	LDIR

	RET

	;------------------------------------------------
	; キャラグラ展開しながら表示
	;------------------------------------------------
	; A = ＣＧ番号
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
	; $0000-$0FFFをRAMに
	OUT		(0E0h),A
	
	; 圧縮展開
	; HL = 圧縮データ
	; DE = 展開先
	LD		DE,0000h
	CALL	EXPAND

	; バンクをモニタROMに
	OUT		(0E2h),A
	; vsync待ち
	CALL	BLNK
	
	; $0000-$0FFFをRAMに
	OUT		(0E0h),A

	; キャラ転送
	LD		HL,00000H
	LD		DE,0D000H
	LD		BC,1000
	LDIR

	;	カラー転送
	LD		HL,1000
	LD		DE,0D800H
	LD		BC,1000
	LDIR
	
	; バンクをモニタROMに
	OUT		(0E2h),A
	
;	EI
	RET

	;------------------------------------------------
	; 直接アドレスのキャラグラを表示
	;------------------------------------------------
	; HL = データアドレス
CGPUT_IMD_URA:
;	DI
	; $0000-$0FFFをRAMに
	OUT		(0E0h),A

	; テープを再生しつつキャラグラ転送
	CALL	TRANS_WITH_TAPEPLAY

	; キャラ転送
;	LD		DE,0D000H
;	LD		BC,1000
;	PUSH	HL
;	LDIR

	;	カラー転送
;	POP		HL
;	LD		DE,1000
;	ADD		HL,DE
;	LD		DE,0D800H
;	LD		BC,1000
;	LDIR
	
	; バンクをモニタROMに
	OUT		(0E2h),A
;	EI
	RET

	;------------------------------------------------
	; ２枚のキャラグラを裏ＲＡＭに展開
	;------------------------------------------------
	; HL = CG１枚目
	; DE = CG２枚目
EXP_URARAM:
;	DI
	; $0000-$0FFFをRAMに
	OUT		(0E0h),A

	; １枚目
	PUSH	DE
	LD		DE,0000h
	CALL	EXPAND

	; ２枚目
	POP		HL
	LD		A,H
	OR		L
	JR		Z,@f

	LD		DE,0800h
	CALL	EXPAND

@@:
	; バンクをモニタROMに
	OUT		(0E2h),A
;	EI
	RET

	;-------------------------------------------------------------------------
	; DATAセクション
	;-------------------------------------------------------------------------
DATA:

	; メッセージテーブル
MSGTBL:
	DW	MSG00,MSG01,MSG02,MSG03
	DW	MSG04,MSG05,MSG06

	;
MSG00:
	DB	CODE_BCHG
	DISPC	'｢ｱｰ､ｿｺﾃﾞｺｯﾁｦ ﾐﾃｲﾙ ｷﾐ!'
	DB	CODE_CR
	DISPC	'ｿｳ ｷﾐﾀﾞﾖ､ｷﾐ! ﾏｧ､ｺｯﾁﾍｷﾅｻｲ｣'
	DB	CODE_EOS

MSG01:
	DB	CODE_BCHG
	DISPC	'｢ﾎｳ､ﾅﾝﾄｲｲ ﾂﾗｶﾞﾏｴﾀﾞ｡'
	DB	CODE_BCHG
	DISPC	'ﾋﾟｰﾝ'
	DB	CODE_BCHG
	DISPC	'ﾄｷﾀ!'
	DB	CODE_CR
	DISPC	'ｷﾐﾉﾖｳﾅ ｼﾞﾝｻﾞｲｦ ﾓﾄﾒﾃｲﾀﾝﾀﾞ!｣'
	DB	CODE_EOS

MSG02:
	DB	CODE_BCHG
	DISPC	'｢ﾜｶﾞｼｬﾊ ｲﾏ､'
	DB	CODE_BCHG
	DISPC	'ｱｲﾄﾞﾙ'
	DB	CODE_BCHG
	DISPC	'ｺｳﾎ'
	DB	DISP_SEI
	DISPC	'ﾀﾁｦ'
	DB	CODE_BCHG
	DISPC	'ﾄｯﾌﾟ'
	DB	CODE_CR
	DISPC	'ｱｲﾄﾞﾙ'
	DB	CODE_BCHG
	DISPC	'ﾆﾐﾁﾋﾞｸ､'
	DB	CODE_BCHG
	DISPC	'ﾌﾟﾛﾃﾞｭｰｻｰ'
	DB	CODE_BCHG
	DISPC	'ｦﾎﾞｼｭｳ'
	DB	CODE_CR
	DISPC	'ﾁｭｳﾀﾞ!｣'
	DB	CODE_EOS

MSG03:
	DB	CODE_BCHG
	DISPC	'｢ﾜｶﾞｼｬﾆ ｼｮｿﾞｸｽﾙ､'
	DB	CODE_BCHG
	DISPC	'ｱｲﾄﾞﾙ'
	DB	CODE_BCHG
	DISPC	'ｺｳﾎ'
	DB	DISP_SEI
	DISPC	'ﾉ'
	DB	CODE_CR
	DISPC	'ｵﾝﾅﾉｺﾊ   ｺﾉｺﾀﾁﾀﾞ!｣'
	DB	CODE_EOS

MSG04:
	DB	CODE_BCHG
	DISPC	'｢ﾄﾞｳﾀﾞ､ﾐﾝﾅ ﾅｶﾅｶ ﾕｳﾎﾞｳｿｳﾀﾞﾛ｡'
	DB	CODE_CR
	DISPC	'ｷｯﾄ ｶﾉｼﾞｮﾀﾁﾓ､ｷﾐｦ ｷﾆｲﾙﾄ'
	DB	CODE_CR
	DISPC	'ｵﾓｳﾖ｣'
	DB	CODE_EOS

MSG05:
	DB	CODE_BCHG
	DISPC	'｢ﾏ､ｸﾜｼｸﾊ ﾆｭｳｼｬｼﾃｶﾗﾄｲｳｺﾄﾃﾞ､'
	DB	CODE_CR
	DISPC	'ﾏｽﾞﾊ'
	DB	CODE_BCHG
	DISPC	'ｹﾞｰﾑ'
	DB	CODE_BCHG
	DISPC	'ｦﾊｼﾞﾒﾃｸﾚﾀﾏｴ｣'
	DB	CODE_EOS

MSG06:
	DB	CODE_BCHG
	DISPC	'｢ｰｰｰｱ､ｵｰｲ､ﾄﾞｺﾆｲｸﾝﾀﾞﾈ? ﾜｶﾞ'
	DB	CODE_CR
	DB	CODE_BCHG
	DISPC	'765ﾌﾟﾛ'
	DB	CODE_BCHG
	DISPC	'ﾊ､ｲﾂﾃﾞﾓ ｷﾐｦ ﾏｯﾃｲﾙｿﾞ'
	DB		0E3h		; ～
	DISPC	'｣'
	DB	CODE_EOS

	; ラストメッセージ１
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
	DISPC	'O ｶﾈｺﾞﾝ'
	DB		CODE_BCHG
	DISPC	'P'
	DB		CODE_LOCATE,23,12
	DB		CODE_BCHG
	DISPC	'(SM2855320)'
	DB		CODE_BCHG
	;
	DB		CODE_LOCATE,21,16
	DISPC	'ｷｬﾗｸﾞﾗ  '
	DB		CODE_BCHG
	DISPC	'ｶﾈｺﾞﾝ'
	DB		CODE_BCHG
	DISPC	'P'
	;
	DB		CODE_LOCATE,21,18
	DISPC	'ﾌﾟﾛｸﾞﾗﾑ '
	DB		CODE_BCHG
	DISPC	'ﾏﾙｸﾝ'
	DB		CODE_BCHG
	DISPC	'P'
	DB		CODE_LOCATE,29,19
	DB		CODE_BCHG
	DISPC	'YOUKAN'
	DB		CODE_BCHG
	DISPC	'P'

	DB	CODE_EOS
	
	; ラストメッセージ2
MSGLAST2:
	DB		CODE_LOCATE,18,22
	DISPC	'ﾊﾞﾝﾅﾑ'
	DB		CODE_BCHG
	DISPC	'ｻﾝｶﾞ ｵｺﾘﾏｾﾝﾖｳﾆ｡'
	DB	CODE_EOS
	
	; キャラグラテーブル
CGTBL:
	DW	CG00,CG01,CG02,CG03,CG04,CG05,CG06,CG07,CG08,CG09
	DW	CG10,CG11,CG12,CG13,CG14,CG15,CG16,CG17,CG18,CG19
	DW	CG20,CG21,CG22,CG23,CG24,CG25,CG26,CG27,CG28,CG29
	DW	CG30,CG31,CG32,CG33,CG34

CG00:	; ＊圧縮
	BINCLUDE "chara/00_logo0.bin"
CG01:	; ＊圧縮
	BINCLUDE "chara/01_logo1.bin"
CG02:	; ＊圧縮
;	BINCLUDE "chara/02_logo2.bin"	; CRI LOGO Cut
CG03:	; ＊圧縮
	BINCLUDE "chara/03_ProjectIMAS.bin"
CG04:	; ＊圧縮
	BINCLUDE "chara/04_TITLE.bin"
CG05:	; ＊圧縮
	BINCLUDE "chara/05_765pro.bin"
CG06:
CG07:
CG08:
CG09:
	; ＊圧縮
	BINCLUDE "chara/06a_しゃちょう.bin"
	
	; 春香
CG10:
	; ＊圧縮
	BINCLUDE "chara/10_haruka0.bin"
CG11:
	BINCLUDE "chara/11_haruka1.bin"
CG12:
	; ＊圧縮
	BINCLUDE "chara/12_haruka2.bin"
CG13:
	BINCLUDE "chara/13_haruka3.bin"
CG14:
	BINCLUDE "chara/14_haruka4.bin"
	
	; 千早
CG15:
	; ＊圧縮
	BINCLUDE "chara/15_chihaya0.bin"
CG16:
	BINCLUDE "chara/16_chihaya1.bin"
CG17:
	; ＊圧縮
	BINCLUDE "chara/17_chihaya2.bin"
CG18:
	BINCLUDE "chara/18_chihaya3.bin"
CG19:
	BINCLUDE "chara/19_chihaya4.bin"
	
	; ゆきぽ
CG20:
	; ＊圧縮
	BINCLUDE "chara/20_yukiho0.bin"
CG21:
	BINCLUDE "chara/21_yukiho1.bin"
CG22:
	BINCLUDE "chara/22_yukiho2.bin"
CG23:
	BINCLUDE "chara/23_yukiho3.bin"
CG24:
	BINCLUDE "chara/24_yukiho4.bin"
	
	; やよい
CG25:
	; ＊圧縮
	BINCLUDE "chara/25_yayoi0.bin"
CG26:
	BINCLUDE "chara/26_yayoi1.bin"
CG27:
	BINCLUDE "chara/27_yayoi2.bin"
CG28:
	BINCLUDE "chara/28_yayoi3.bin"
CG29:
	BINCLUDE "chara/29_yayoi4.bin"
	
	; りっちゃん
CG30:
	; ＊圧縮
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
