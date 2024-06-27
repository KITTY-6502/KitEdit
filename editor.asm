.cpu kitty

.var R0 2
.var R1 2
.var R2 2
.var R3 2
.var R4 2
.var R5 2
.var R6 2
.var R7 2
.var AtCursor

# Gap Buffer
.var Update
.var PagePTR    2
.var PageDIST   2
.var BufBottom  2
.var BufCursor  2
.var BufAfter   2
.var BufTop     2
.var BufSize    2
.var BufUsed    2
.var char_cur
.var char_repeat
.var char_repeat_timer
.var char_timer
.var keyboard_cache 5
.val bgc $F1

.val LEFT   $F0
.val UP     $F1
.val RIGHT  $F2
.val DOWN   $F3
.val BACK   $08
.val DEL    $7F
.val LF     $0A

.org [$8000]
_RESET
    # Silence Audio
    stz [$70F0]; stz [$70F1]; stz [$70F2]; stz [$70F3]
    # Clear Screen
    ldx 0
    __clrloop
        lda ' '
        sta [$6800+X]; sta [$6900+X]; sta [$6A00+X]; sta [$6B00+X]
        lda $1F
        sta [$6C00+X]; sta [$6D00+X]; sta [$6E00+X]; sta [$6F00+X]
        lda 0
        sta <$00+X>
    inc X; bne (clrloop)
    
    lda EditorIRQ.lo; sta <$FE>
    lda EditorIRQ.hi; sta <$FF>
    
    # Init Gap Buffer Variables
    lda $00; sta <BufBottom+0>; sta <BufCursor+0>; sta <PagePTR+0>; 
    lda $03; sta <BufBottom+1>; sta <BufCursor+1>; sta <PagePTR+1>; 
    lda $FF; sta <BufTop+0>; sta <BufAfter+0>
    lda $67; sta <BufTop+1>; sta <BufAfter+1>
    lda 0; tay; sta [<BufAfter>+Y]
    lda 0; tay; sta [<BufCursor>+Y]
    
    stz <PageDIST+0>; stz <PageDIST+1>
    
    cli
    lda 1; sta <Update>
    
    sec
    lda <BufTop+0>; sbc <BufBottom+0>; sta <R7+0>; sta <BufSize+0>
    lda <BufTop+1>; sbc <BufBottom+1>; sta <R7+1>; sta <BufSize+1>
    
    jsr [BinToDec]
    
    ldx $00
    __drawValue
        lda $F9; sta [$6FE0+X]
    inc X; cpx $20; bne (drawValue)
    
    # Seperator
    lda '/'; sta [$6BFA]
    # Draw Total
    lda <BufSize+0>; sta <R7+0>
    lda <BufSize+1>; sta <R7+1>
    jsr [BinToDec]
    ldx 0
    __DrawMaxSize
        lda <R3+X>; sta [$6BFB+X]
    inc X; cpx 5; bne (DrawMaxSize)

_EditorLoop
    wai
    lda <Update>; beq (EditorLoop)
    sei
    jsr [DrawScreen]
    cli
    lda $03; sta <BufBottom+1>
    

jmp [EditorLoop]

_MAIN
    lda <char_cur>
    bne (yesinput)
        jmp [noinput]
    __yesinput
    #jsr [DrawScreen]
    
    lda <char_cur>
    bpl (notspecial)
    jmp [special]
    __notspecial
    #cmp LF; bne (noReturn)
    #    pha; jsr [ScreenClear]; pla
    #___noReturn
    cmp BACK; beq (backspace)
    cmp DEL; beq (delete)
        
    ldy 0; sta [<BufCursor>+Y]
    clc
    lda <BufCursor+0>; adc 1; sta <BufCursor+0>
    lda <BufCursor+1>; adc 0; sta <BufCursor+1>
jmp [hadinput]

__backspace
    lda <BufCursor+0>; cmp <BufBottom+0>; bne (notend)
    lda <BufCursor+1>; cmp <BufBottom+1>; bne (notend)
        bra (break)
    ___notend
    sec
    lda <BufCursor+0>; sbc 1; sta <BufCursor+0>
    lda <BufCursor+1>; sbc 0; sta <BufCursor+1>
    ___break
    jmp [hadinput]
__delete
    lda <BufAfter+0>; cmp <BufTop+0>; bne (notend)
    lda <BufAfter+1>; cmp <BufTop+1>; bne (notend)
        bra (break)
    ___notend
    clc
    lda <BufAfter+0>; adc 1; sta <BufAfter+0>
    lda <BufAfter+1>; adc 0; sta <BufAfter+1>
    ___break
    jmp [hadinput]
__special
    cmp LEFT; beq (leftmove)
    cmp RIGHT; beq (rightmove)
    cmp UP; beq (upmove)
    cmp DOWN; beq (downmove)
    bra (break)
    ___leftmove
        lda %1000_0000; bit <keyboard_cache+0>; beq (singlemove)
        ____loop
            jsr [MoveLeft]; bne (break)
            lda [<BufAfter>+Y]
            cmp LF; beq (break)
            cmp ' '; beq (break)
        bra (loop)
        ____singlemove
        jsr [MoveLeft]
    bra (break)
    ___rightmove
        lda %1000_0000; bit <keyboard_cache+0>; beq (singlemove)
        ____loop
            jsr [MoveRight]; bne (break)
            lda [<BufAfter>+Y]
            cmp LF; beq (break)
            cmp ' '; beq (break)
        bra (loop)
        ____singlemove
        jsr [MoveRight]
    bra (break)
    ___upmove
        jsr [MoveLeft]; bne (break)
        ldy 0
        lda [<BufAfter>+Y]; cmp LF; beq (break)
    bra (upmove)
    ___downmove
        jsr [MoveRight]; bne (break)
        ldy 0
        lda [<BufAfter>+Y]; cmp LF; beq (break)
    bra (downmove)
        
    ___break
    __hadinput
    inc <Update>
    #jsr [DrawScreen]
    stz <char_cur>
    
    __noinput
    sec
    lda <BufCursor+0>; sbc <BufBottom+0>; sta <BufUsed+0>
    lda <BufCursor+1>; sbc <BufBottom+1>; sta <BufUsed+1>
    
    sec
    lda <BufTop+0>; sbc <BufAfter+0>; sta <R0+0>
    lda <BufTop+1>; sbc <BufAfter+1>; sta <R0+1>
    
    clc
    lda <R0+0>; adc <BufUsed+0>; sta <BufUsed+0>
    lda <R0+1>; adc <BufUsed+1>; sta <BufUsed+1>
rts
#jmp [MAIN]

_UpdatePage
    stz <PageDIST+0>; stz <PageDIST+1>
    # chECK IF SMALLER
    sec
    lda <PagePTR+0>; sbc <BufCursor+0> 
    lda <PagePTR+1>; sbc <BufCursor+1>
    bcc (downmove)
        jmp [UpdatePageUp]
    __downmove
    ldy 0
    lda <BufCursor+0>; sta <R0+0>
    lda <BufCursor+1>; sta <R0+1>
    __loop
        lda <PagePTR+0>; cmp <R0+0>; bne (continue)
        lda <PagePTR+1>; cmp <R0+1>; bne (continue)
            bra (break)
        __continue
        sec
        lda <R0+0>; sbc 1; sta <R0+0>
        lda <R0+1>; sbc 0; sta <R0+1>
        lda [<R0>+Y]; cmp LF; beq (ENTER)
            clc
            lda %0000_1000; adc <PageDIST+0>; sta <PageDIST+0>
            lda 0; adc <PageDIST+1>; sta <PageDIST+1>
        bra (loopend)
        __ENTER
            inc <PageDIST+1>; stz <PageDIST+0>
        __loopend
        lda <PageDIST+1>; cmp 31; beq (newStart)
    bra (loop)
    __break
rts
__newStart
    clc
    lda <R0+0>; adc 1; sta <PagePTR+0>
    lda <R0+1>; adc 0; sta <PagePTR+1>
rts

_UpdatePageUp
    lda <BufCursor+0>; sta <PagePTR+0>
    lda <BufCursor+1>; sta <PagePTR+1>
    ldy 0
    __loop
        lda <PagePTR+0>; cmp <BufBottom+0>; bne (notstart)
        lda <PagePTR+1>; cmp <BufBottom+1>; bne (notstart)
            bra (break)
        __notstart
        lda [<PagePTR>+Y]; cmp LF; beq (enter)
        
        sec
        lda <PagePTR+0>; sbc 1; sta <PagePTR+0>
        lda <PagePTR+1>; sbc 0; sta <PagePTR+1>
    jmp [loop]
    __enter
        #clc
        #lda <PagePTR+0>; adc 1; sta <PagePTR+0>
        #lda <PagePTR+1>; adc 0; sta <PagePTR+1>
    __break
rts


_MoveLeft
    lda <BufCursor+0>; cmp <BufBottom+0>; bne (notend)
    lda <BufCursor+1>; cmp <BufBottom+1>; bne (notend)
        lda 1
        bra (break)
    __notend
    sec
    lda <BufCursor+0>; sbc 1; sta <BufCursor+0>
    lda <BufCursor+1>; sbc 0; sta <BufCursor+1>
    
    sec
    lda <BufAfter+0>; sbc 1; sta <BufAfter+0>
    lda <BufAfter+1>; sbc 0; sta <BufAfter+1>
    
    __noincAfter

    ldy 0
    lda [<BufCursor>+Y]; sta [<BufAfter>+Y]
    lda 0; sta [<BufCursor>+Y]
    __break
rts

_MoveRight
    lda <BufAfter+0>; cmp <BufTop+0>; bne (notend)
    lda <BufAfter+1>; cmp <BufTop+1>; bne (notend)
        lda 1
        bra (break)
    __notend
    ldy 0
    lda [<BufAfter>+Y]; beq (break); sta [<BufCursor>+Y]
    
    clc
    lda <BufAfter+0>; adc 1; sta <BufAfter+0>
    lda <BufAfter+1>; adc 0; sta <BufAfter+1>
    clc
    lda <BufCursor+0>; adc 1; sta <BufCursor+0>
    lda <BufCursor+1>; adc 0; sta <BufCursor+1>
    
    lda 0
    __break
rts

# Moves all of the text to the lowest position, ran when exiting editor
_MoveStart
    jsr [MoveRight]
    beq (MoveStart)
rts

_DrawScreen
    jsr [UpdatePage]
    stz <Update>
    lda ' '; sta [<R2>+Y]
    ldy 0
    lda $00; sta <R0+0>
    lda $68; sta <R0+1>
    lda <PagePTR+0>; sta <R1+0>
    lda <PagePTR+1>; sta <R1+1>
    ldy 0
    __PreCursor
        lda <R1+0>; cmp <BufCursor+0>; bne (notsame)
        lda <R1+1>; cmp <BufCursor+1>; bne (notsame)
            bra (break)
        ___notsame
        
        lda [<R1>+Y]; bne (notend)
            jmp [GoEND]
        ____notend
        cmp LF; bne (continue)
            jsr [HandleLF]
            jmp [return]
        ____continue
        sta [<R0>+Y]
        ____return
        inc <R1+0>; bne (noinc)
            inc <R1+1>
        ___noinc
        
        inc <R0+0>; bne (noinc2)
            inc <R0+1>;
        ___noinc2
        lda <R0+1>; cmp $6B
            bcc (PreCursor); bne (End)
        lda <R0+0>; cmp $E0
            bcs (End)
    bra (PreCursor)
    ___break
    __PreCursorEnd
    stz [Update]
    lda <R0+0>; sta <R2+0>
    lda <R0+1>; sta <R2+1>
    lda ' '; sta [<R2>+Y]
    
    lda <BufAfter+0>; sta <R1+0>
    lda <BufAfter+1>; sta <R1+1>
    __PostCursor
        lda <R1+0>; cmp <BufTop+0>; bne (notsame)
        lda <R1+1>; cmp <BufTop+1>; bne (notsame)
            bra (GoEND)
        ___notsame
        
        lda [<R1>+Y]; beq (End)
        cmp LF; bne (continue)
            jsr [HandleLF]
            jmp [return]
        ____continue
        sta [<R0>+Y]
        ____return
        clc
        lda <R1+0>; adc 1; sta <R1+0>
        lda <R1+1>; adc 0; sta <R1+1>
        
        inc <R0+0>; bne (noinc2)
            inc <R0+1>
        ___noinc2
            lda <R0+1>; cmp $6B
                bcc (PostCursor); bne (End)
            lda <R0+0>; cmp $E0
                bcs (End)
    bra (PostCursor)
    __GoEND
        lda <R0+1>; cmp $6B
            bcc (continue); bne (End)
        lda <R0+0>; cmp $E0
            bcs (End)
        __continue
        
        
        lda ' '; sta [<R0>+Y]
        inc <R0+0>; bne (noinc)
            inc <R0+1>
        ___noinc
    bra (GoEND)
    ___break
    __End
    
    lda [<R2>+Y]; sta <AtCursor>
    stz <char_timer>
    
    phx; phy
    
    # Draw Used Bytes
    lda <BufUsed+0>; sta <R7+0>
    lda <BufUsed+1>; sta <R7+1>
    jsr [BinToDec]
    ldx 0
    __DrawUsedSize
        lda <R3+X>; sta [$6BFA-5+X]
    inc X; cpx 5; bne (DrawUsedSize)
    
    ply;plx
rts

_Blip
    ldx <AtCursor>
    lda %0010_0000; and <char_timer>; bne (noblip)
        ldx $1F
    __noblip
    txa; sta [<R2>+Y]
rts
_HandleLF
    __loop
        lda ' '; sta [<R0+0>+Y]
        lda <R0+0>
        and %000_11111; cmp %000_11111; beq (break)
        inc <R0+0>
    bra (loop)
    __break
rts

_ScreenClear
    ldx 0
    __clrloop
        lda ' '
        sta [$6800+X]; sta [$6900+X]; sta [$6A00+X]; sta [$6B00+X]
    inc X; bne (clrloop)
rts 

_NMI
_IRQ
    jmp [[$00FE]]
_EditorIRQ
    pha; phx; phy; php
    
    jsr [Blip]
    inc <char_timer>
    stz [char_cur]
    ldx 4
    ldy 0
    _keyloop
        psh X
        txa; asl A; asl A; asl A; asl A; tax
        lda [$7000+X]
        pul X
        
        psh A           # PUSH 01
        cmp [keyboard_cache+X]; bne (change)
        jmp [nochange]
        _change
            
        __bit0
        lsr [keyboard_cache+X]; bcs (bit1)
        bit %0000_0001; beq (bit1)
        psh A; lda [kKeys0+X]; beq (modifier); sta [char_cur]
        ___modifier
        pul A
        __bit1
        lsr [keyboard_cache+X]; bcs (bit2)
        bit %0000_0010; beq (bit2)
        psh A; lda [kKeys1+X]; beq (modifier); sta [char_cur];
        ___modifier
         pul A
        __bit2
        lsr [keyboard_cache+X]; bcs (bit3)
        bit %0000_0100; beq (bit3)
        psh A; lda [kKeys2+X]; beq (modifier); sta [char_cur]
        ___modifier
        pul A
        __bit3
        lsr [keyboard_cache+X]; bcs (bit4)
        bit %0000_1000; beq (bit4)
        psh A; lda [kKeys3+X]; beq (modifier); sta [char_cur]
        ___modifier
        pul A
        __bit4
        lsr [keyboard_cache+X]; bcs (bit5)
        bit %0001_0000; beq (bit5)
        psh A; lda [kKeys4+X]; beq (modifier); sta [char_cur]
        ___modifier
        pul A
        __bit5
        lsr [keyboard_cache+X]; bcs (bit6)
        bit %0010_0000; beq (bit6)
        psh A; lda [kKeys5+X]; beq (modifier); sta [char_cur]
        ___modifier
        pul A
        __bit6
        lsr [keyboard_cache+X]; bcs (bit7)
        bit %0100_0000; beq (bit7)
        psh A; lda [kKeys6+X]; beq (modifier); sta [char_cur]
        ___modifier
        pul A
        __bit7
        lsr [keyboard_cache+X]; bcs (bitend)
        bit %1000_0000; beq (bitend)
        psh A; lda [kKeys7+X]; beq (modifier); sta [char_cur]
        ___modifier
        pul A
        
        __bitend
        inc Y
        _nochange
        pul A # PULL 01
        sta [keyboard_cache+X]
    dec X; bmi (keyend); jmp [keyloop]
    __keyend
    lda <char_cur>; bmi (modend)
    tax
    __normalchar
    lda $80; bit <keyboard_cache+2>; beq (noshift)
    lda [kShift+X]; sta <char_cur>; tax
    #bra (modend)
    ___noshift
    lda $80; bit <keyboard_cache+3>; beq (modend)
    lda [kAlt+X]; sta <char_cur>
    bra (modend)
    __modend
    
    cpy 0; beq (notnew)
        lda <char_cur>; sta <char_repeat>; lda 20; sta <char_repeat_timer>
    __notnew
    dec <char_repeat_timer>; bne (norepeat)
        lda <char_repeat>; sta <char_cur>
        lda 2; sta <char_repeat_timer>
    __norepeat
    
    jsr [MAIN]
    
    plp; ply; plx; pla
rti

_HexToText
# Converts a value in A into a Hex String at <$00-$01>
    sta <$10>
    and $F0; lsr A; lsr A; lsr A; lsr A
    tax; lda [tHex+X]; sta <$00>
    lda <$10>
    and $0F
    tax; lda [tHex+X]; sta <$01>
    stz <$02>; stz <$03>; stz <$04>; stz <$05>
    
    lda <$10>; rts
    
_TextToHex
# Converts a character in A into a number, outputs 80 if invalid
    sec; sbc $30; bmi (invalid)
    cmp $0A; bpl (letter)
    # Is A value from 0-9
    clc; adc 0
    rts
    __letter
    and %1101_1111
    sec; sbc 7; bmi (invalid)
    cmp $10; bpl (invalid)
    clc; adc 0
    rts
__invalid
    lda $80; rts


_BinToDec
    # Input: R0
    # Output: R3~R4
    ldy 0
    ldx 0
    lda '0'
    sta <R3+0>; sta <R3+1>; sta <R3+2>; sta <R3+3>; sta <R3+4>
    
    __loop
        lda <R7+1>; cmp [tableHi+X]
            bcc (break)
            bne (continue)
        lda <R7+0>; cmp [tableLo+X]
            bcc (break)
        __continue
        inc <R3+X>
        sec
        lda <R7+0>; sbc [tableLo+X]; sta <R7+0>
        lda <R7+1>; sbc [tableHi+X]; sta <R7+1>
    bra (loop)
    __break
    inc Y; inc Y; inc Y
    inc X; cpx 5;bne (loop)
rts
__tableHi
.byte 10000.hi, 1000.hi, 100.hi, 10.hi, 1.hi
__tableLo
.byte 10000.lo, 1000.lo, 100.lo, 10.lo, 1.lo

_tHex
.byte '0123456789abcdef'

#--------------------------
# Keyboard Layout Data
_kKeys7
.byte $00,$00,$00,$00,$82
_kKeys6
.byte 'x','z','a','q','w'
_kKeys5
.byte 'c','f','d','s','e'
_kKeys4
.byte ' ','b','v','g','r'

_kKeys3
.byte $F1,'n','h','y','t'
_kKeys2
.byte $F0,'|','m','j','u'
_kKeys1
.byte $F3,'.','l','k','i'
_kKeys0
.byte $F2,LF,BACK,'p','o'

_kShift
.byte $00,$01,$02,$03,$04,$05,$06,$07,$7F,$09,$0A,$0B,$0C,$0D,$0E,$0F
.byte $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F
.byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,',',$2F
.byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F
.byte $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F
.byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F
.byte $60,'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O'
.byte 'P','Q','R','S','T','U','V','W','X','Y','Z',$7B,'\',$7D,$7E,$7F
_kAlt
.byte $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F
.byte $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F
.byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,'^',$2D,'`',$2F
.byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F
.byte $40,'%',$42,$43,'~',$45,'<','>','[',$49,']','{','}',$4D,$4E,$4F
.byte $50,$51,$52,'=',$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F
.byte $60,'@',';',$27,'$','3','_','&','-','8','+','(',')','?','!','9'
.byte '0','1','4',$23,'5','7',':','2','"','6','*',$7B,'/',$7D,$7E,$7F
rti



.pad [VECTORS]
_VEC
.word NMI
.word RESET
.word IRQ