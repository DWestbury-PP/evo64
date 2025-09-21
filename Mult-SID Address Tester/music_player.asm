//------------------------------------------------------------------------------
//-Musicroutine by: Cadaver (loorni@gmail.com)
//-https://cadaver.github.io/rants/music.html                                                  
//                                                                              
//-Additions by: Darrell Westbury (dwestbury_505@msn.com)
// > Converted code for KickAssembler
// > Added Multi-SID support
//-----------------------------------------------------------------------------
.pc = $1000 "Multi-SID Music Player"

MUSIC_INIT:     jmp init                //Jump to the initialization routine
MUSIC_PLAYER:   jmp play                //Jump to the play routine

.const temp1    = $fb                   //zeropage addresses for indirect indexing
.const temp2    = $fc
.const temp3    = $fd                   //Multi-SID address vectoring
.const temp4    = $fe

.const C0       = $00                   //Definitions for note data.
.const CIS0     = $01                   //Note numbers are always followed
.const D0       = $02                   //by the note duration in frames
.const DIS0     = $03
.const E0       = $04
.const F0       = $05
.const FIS0     = $06
.const G0       = $07
.const GIS0     = $08
.const A0       = $09
.const B0       = $0a
.const H0       = $0b
.const C1       = $0c
.const CIS1     = $0d
.const D1       = $0e
.const DIS1     = $0f
.const E1       = $10
.const F1       = $11
.const FIS1     = $12
.const G1       = $13
.const GIS1     = $14
.const A1       = $15
.const B1       = $16
.const H1       = $17
.const C2       = $18
.const CIS2     = $19
.const D2       = $1a
.const DIS2     = $1b
.const E2       = $1c
.const F2       = $1d
.const FIS2     = $1e
.const G2       = $1f
.const GIS2     = $20
.const A2       = $21
.const B2       = $22
.const H2       = $23
.const C3       = $24
.const CIS3     = $25
.const D3       = $26
.const DIS3     = $27
.const E3       = $28
.const F3       = $29
.const FIS3     = $2a
.const G3       = $2b
.const GIS3     = $2c
.const A3       = $2d
.const B3       = $2e
.const H3       = $2f
.const C4       = $30
.const CIS4     = $31
.const D4       = $32
.const DIS4     = $33
.const E4       = $34
.const F4       = $35
.const FIS4     = $36
.const G4       = $37
.const GIS4     = $38
.const A4       = $39
.const B4       = $3a
.const H4       = $3b
.const C5       = $3c
.const CIS5     = $3d
.const D5       = $3e
.const DIS5     = $3f
.const E5       = $40
.const F5       = $41
.const FIS5     = $42
.const G5       = $43
.const GIS5     = $44
.const A5       = $45
.const B5       = $46
.const H5       = $47
.const C6       = $48
.const CIS6     = $49
.const D6       = $4a
.const DIS6     = $4b
.const E6       = $4c
.const F6       = $4d
.const FIS6     = $4e
.const G6       = $4f
.const GIS6     = $50
.const A6       = $51
.const B6       = $52
.const H6       = $53
.const C7       = $54
.const CIS7     = $55
.const D7       = $56
.const DIS7     = $57
.const E7       = $58
.const F7       = $59
.const FIS7     = $5a
.const G7       = $5b
.const GIS7     = $5c
.const A7       = $5d
.const B7       = $5e
.const H7       = $5f
.const REST     = $60                   //Rest clears the gatebit
.const CONTINUE = $61                   //Continue just continues the note
.const INSTR    = $80                   //Values $80-$fe are instrument changes
.const END      = $ff                   //End voice data// followed by a 16-bit jump
                                        //address

//-----------------------------------------------------------------------------
//-Initialize Routine: Sets the song number and clears all SID registers
//-----------------------------------------------------------------------------
init:           sta sid_address_index   //Receive Multi-SID address index from caller
                lda #$00
                sta play_flag+1         //Set the Song to be played
                tax                     //Clear SID registers for each SID addresses
set_sid_addr:   lda sid_address_lo,x
                sta temp3
                lda sid_address_hi,x
                sta temp4
                ldy #$00
clear_reg_loop: sta (temp3),y
                iny
                cpy #$20
                bne clear_reg_loop
                inx
                cpx #$30                //Only clear the first 32 SIDs to avoid conflict with Retro Replay cart.
                bne set_sid_addr        //Loop until all SID registers are cleared
                ldx sid_address_index   //Load the Multi-SID address index
                lda sid_address_lo,x    //Set the specific SID address to be used
                sta temp3
                lda sid_address_hi,x
                sta temp4
                lda #$FF
                ldy #$18
                sta (temp3),y           //Set the volume to maximum for active SID
                rts

//-----------------------------------------------------------------------------
//-Interrupt Service Routine (ISR) to play sounds once per screen refresh cycle
//-----------------------------------------------------------------------------
play:           ldx #$00                //X will be the voice index
play_flag:      lda #$00                //Check the init/play flag
                bmi play_playloop       //Nonnegative value -> init song
                                        //(song number is the value)
                                        //Negative value -> play
                asl
                sta temp1               //Multiply songnumber by 6 to get
                asl                     //index to song startaddresstable
                adc temp1
                tay

play_initloop:  lda songtbl,y           //Copy start address of music data
                sta v_ptrlo,x           //to voice data pointer (16bit
                lda songtbl+1,y         //value)
                sta v_ptrhi,x
                iny                     //Increment index for next voice
                iny
                lda #$02                //Reset note-duration counter to 2
                sta v_counter,x         //(new notes will be fetched)
                lda #$08                //Set testbit in waveform, to reset
                sta v_waveform,x        //noise waveform if it has been stuck
                inx
                cpx #$03                //Loop thru all 3 voices
                bcc play_initloop
                lda #$00                //Reset filter bits - this musicroutine
                ldy #$17
                sta (temp3),y           //doesn't use filter - Now Multi-SID compatible
                lda #$0f                //Reset volume to maximum
                ldy #$18
                sta (temp3),y           //Now Multi-SID compatible
                lda #$ff                //Set negative value to the playing flag
                sta play_flag+1         //so that playing can start
                rts

play_initnew:   ldy v_note,x            //Get notenumber
                cpy #REST               //If it's a rest or continue, do nothing
                bcs play_initonlycounter
                lda freqtbllo,y         //Get note's frequency from the
                sta v_freqlo,x          //frequency table
                lda freqtblhi,y
                sta v_freqhi,x
                ldy v_instr,x           //Get voice instrument number
                lda i_pulselo,y         //Copy pulse width initial value,
                sta v_pulselo,x         //waveform and ADSR from instrument
                lda i_pulsehi,y         //data to voice variables
                sta v_pulsehi,x
                lda i_waveform,y
                sta v_waveform,x
                lda i_ad,y
                sta v_ad,x
                lda i_sr,y
                sta v_sr,x
play_initonlycounter:
                lda v_counternew,x      //New value for the note duration
                sta v_counter,x         //counter
                jmp play_deccounter

play_playloop:  lda v_counter,x         //Time to init new notes?
                beq play_initnew
                cmp #$02                //Or fetch new notes?
                beq play_fetchnew
play_pulsemod:  ldy v_instr,x
                lda v_pulselo,x         //If not, do the pulsewidth modulation,
                clc                     //decrement note duration counter,
                adc i_pulsespeed,y      //dump voice variables to SID and
                sta v_pulselo,x         //go to the next channel.
                lda v_pulsehi,x
                adc #$00
                sta v_pulsehi,x
play_deccounter:dec v_counter,x
                ldy v_regindex,x        //Get SID register index (0,7,14 for
                lda v_freqlo,x          //different voices)
                sta (temp3),y           //Frequency - Now Multi-SID compatible
                lda v_freqhi,x
                iny
                sta (temp3),y           //Now Multi-SID compatible
                lda v_pulselo,x
                iny
                sta (temp3),y           //Pulse - Now Multi-SID compatible
                lda v_pulsehi,x
                iny
                sta (temp3),y           //Now Multi-SID compatible
                lda v_waveform,x
                iny
                sta (temp3),y           //Waveform - Now Multi-SID compatible
                lda v_ad,x
                iny
                sta (temp3),y           //Attack/Decay - Now Multi-SID compatible
                lda v_sr,x
                iny
                sta (temp3),y           //Sustain/Release - Now Multi-SID compatible
play_nextvoice: inx                     //Loop until all 3 voices done
                cpx #$03
                bcc play_playloop
                rts

play_fetchnew:  lda v_ptrlo,x           //Put voice data pointer to zeropage
                sta temp1               //for indirect access
                lda v_ptrhi,x
                sta temp2
                ldy #$00                //Y register for indexing voice data
play_fetchloop: lda (temp1),y           //Get byte from voice data
                bpl play_fetchnote      //Nonnegative value = note
                iny                     //Increment index already here to avoid
                                        //having to do it twice
                cmp #$ff                //A jump command?
                bcc play_instrchange    //No, an instrument change
                lda (temp1),y           //Get lowbyte of jump address
                sta v_ptrlo,x
                iny
                lda (temp1),y           //Get highbyte of jump address and
                sta v_ptrhi,x           //go back to fetch loop hoping it isn't
                jmp play_fetchnew       //an endless loop :)
play_instrchange:
                and #$7f                //Clear the high bit and we have the
                sta v_instr,x           //instrument number
                jmp play_fetchloop
play_fetchnote: sta v_note,x            //Store note number
                iny
                lda (temp1),y           //Then get note duration
                sta v_counternew,x
                iny
                lda v_note,x            //Is it a "continue note"-command?
                cmp #CONTINUE           //If yes, skip the gatebit reset
                beq play_skipgatebit
                lda v_waveform,x
                and #$fe
                sta v_waveform,x
play_skipgatebit:
                tya                     //Now move the voice data pointer by
                clc                     //the amount of bytes that were
                adc temp1               //fetched
                sta v_ptrlo,x
                lda temp2
                adc #$00
                sta v_ptrhi,x
                jmp play_deccounter     //And go back to the loop (note: pulse
                                        //modulation is omitted to save some
                                        //time)

//-----------------------------------------------------------------------------
//-Voice variables for each voice                                              
//-----------------------------------------------------------------------------
v_regindex:     .byte 0,7,14             //SID register index
v_freqlo:       .byte 0,0,0              //Frequency lowbyte (ghost register)
v_freqhi:       .byte 0,0,0              //Frequency highbyte (ghost register)
v_pulselo:      .byte 0,0,0              //Pulse lowbyte (ghost register)
v_pulsehi:      .byte 0,0,0              //Pulse highbyte (ghost register)
v_waveform:     .byte 0,0,0              //Waveform (ghost register)
v_ad:           .byte 0,0,0              //Attack/Decay (ghost register)
v_sr:           .byte 0,0,0              //Sustain/Release (ghost register)
v_instr:        .byte 0,0,0              //Instrument number
v_note:         .byte 0,0,0              //Note number
v_counter:      .byte 0,0,0              //Note duration counter
v_counternew:   .byte 0,0,0              //Duration of new note
v_ptrlo:        .byte 0,0,0              //Voice data pointer lowbyte
v_ptrhi:        .byte 0,0,0              //Voice data pointer highbyte

//-----------------------------------------------------------------------------
//-Frequency tables (from GoatTracker playroutines)                            
//-----------------------------------------------------------------------------
freqtblhi:      
.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02
.byte $02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04
.byte $04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08
.byte $08,$09,$09,$0a,$0a,$0b,$0c,$0c,$0d,$0e,$0f,$10
.byte $11,$12,$13,$14,$15,$17,$18,$19,$1b,$1d,$1e,$20
.byte $22,$24,$26,$29,$2b,$2e,$30,$33,$36,$3a,$3d,$41
.byte $45,$49,$4d,$52,$57,$5c,$61,$67,$6d,$74,$7b,$82
.byte $8a,$92,$9b,$a4,$ae,$b8,$c3,$cf,$db,$e8,$f6,$ff

freqtbllo:
.byte $15,$25,$36,$49,$5c,$71,$87,$9f,$b7,$d1,$ed,$0a
.byte $2a,$4a,$6d,$92,$b9,$e3,$0f,$3e,$6f,$a3,$db,$15
.byte $54,$95,$db,$25,$73,$c7,$1e,$7c,$de,$47,$b6,$2b
.byte $a8,$2b,$b7,$4b,$e7,$8e,$3d,$f8,$bd,$8e,$6c,$57
.byte $50,$57,$6e,$96,$cf,$1c,$7b,$f0,$7b,$1d,$d8,$ae
.byte $a0,$af,$dd,$2d,$9f,$38,$f7,$e0,$f6,$3b,$b1,$5d
.byte $40,$5e,$bb,$5a,$3f,$70,$ef,$c1,$ed,$76,$63,$ba
.byte $80,$bc,$76,$b4,$7f,$e0,$de,$83,$da,$ed,$c7,$ff

//-----------------------------------------------------------------------------
//-Instrument data (each value sequentially for each instrument)               
//-----------------------------------------------------------------------------
i_pulselo:      .byte $00,$00,$00        //Pulse width lowbyte
i_pulsehi:      .byte $02,$00,$00        //Pulse width highbyte
i_pulsespeed:   .byte $20,$00,$00        //Pulse width speed
i_ad:           .byte $09,$58,$0a        //Attack/Decay
i_sr:           .byte $00,$aa,$00        //Sustain/Release
i_waveform:     .byte $41,$21,$11        //Waveform (must have gatebit on)

//-----------------------------------------------------------------------------
//-Song table (address of voice data start for each voice)                     
//-----------------------------------------------------------------------------
songtbl:
.word song0voice1
.word song0voice2
.word song0voice3
//More songs could be added here

//-----------------------------------------------------------------------------
//-Voice 1 data                                                                
//-----------------------------------------------------------------------------
song0voice1:    .byte INSTR+0            //Set instrument 0
                .byte A2,14              //Note/duration pairs
                .byte A2,14
                .byte A2,14
                .byte H2,7
                .byte C3,7
                .byte D3,14
                .byte D3,14
                .byte D3,14
                .byte C3,14
                .byte G2,14
                .byte G2,14
                .byte G2,14
                .byte A2,7
                .byte H2,7
                .byte C3,14
                .byte C3,14
                .byte C3,14
                .byte H2,14
                .byte F2,14
                .byte F2,14
                .byte F2,14
                .byte G2,7
                .byte A2,7
                .byte H2,14
                .byte H2,14
                .byte H2,14
                .byte A2,14
                .byte E2,14
                .byte E2,14
                .byte E2,14
                .byte E2,14
                .byte E2,7
                .byte F2,7
                .byte E2,7
                .byte D2,7
                .byte E2,7
                .byte F2,7
                .byte G2,7
                .byte H2,7
                .byte END                        //End command, followed by
                .word song0voice1                //restart address

//-----------------------------------------------------------------------------
//-Voice 2 data                                                                
//-----------------------------------------------------------------------------
song0voice2:    .byte INSTR+1                    //Set instrument 1
                .byte C4,7
                .byte REST,7                     //Rest also has a duration
                .byte C4,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte D4,7
                .byte C4,7
                .byte H3,7
                .byte A3,7
                .byte G3,7
                .byte A3,7
                .byte H3,7
                .byte C4,7
                .byte H3,7
                .byte REST,7
                .byte H3,7
                .byte REST,7
                .byte H3,7
                .byte REST,7
                .byte H3,7
                .byte REST,7
                .byte C4,7
                .byte H3,7
                .byte A3,7
                .byte G3,7
                .byte A3,7
                .byte H3,7
                .byte C4,7
                .byte D4,7
                .byte A3,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte D4,7
                .byte C4,7
                .byte H3,7
                .byte A3,7
                .byte GIS3,7
                .byte FIS3,7
                .byte GIS3,7
                .byte A3,7
                .byte C4,42
                .byte H3,7
                .byte A3,7
                .byte H3,42
                .byte REST,14
                .byte E4,7
                .byte REST,7
                .byte C4,7
                .byte H3,7
                .byte C4,7
                .byte REST,7
                .byte A4,7
                .byte REST,7
                .byte A4,7
                .byte G4,7
                .byte F4,7
                .byte E4,7
                .byte D4,7
                .byte E4,7
                .byte F4,7
                .byte G4,7
                .byte D4,7
                .byte REST,7
                .byte G3,7
                .byte FIS3,7
                .byte G3,7
                .byte REST,7
                .byte F4,7
                .byte REST,7
                .byte F4,7
                .byte E4,7
                .byte D4,7
                .byte E4,7
                .byte C4,7
                .byte REST,7
                .byte E4,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte F3,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte DIS4,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte DIS4,7
                .byte REST,7
                .byte E4,28
                .byte FIS4,28
                .byte GIS4,42
                .byte REST,14
                .byte END
                .word song0voice2

//-----------------------------------------------------------------------------
//-Voice 3 data                                                                
//-----------------------------------------------------------------------------
song0voice3:    .byte INSTR+2                    //Set instrument 2
                .byte A4,42
                .byte H4,7
                .byte C5,7
                .byte D5,56
                .byte G4,42
                .byte A4,7
                .byte H4,7
                .byte C5,56
                .byte F4,42
                .byte G4,7
                .byte A4,7
                .byte H4,56
                .byte E4,35
                .byte F4,7
                .byte E4,7
                .byte D4,7
                .byte E4,56
                .byte A4,42
                .byte H4,7
                .byte C5,7
                .byte D5,56
                .byte G4,42
                .byte A4,7
                .byte H4,7
                .byte C5,56
                .byte F4,42
                .byte G4,7
                .byte A4,7
                .byte H4,56
                .byte E4,35
                .byte A4,7
                .byte H4,7
                .byte C5,7
                .byte D5,56
                .byte END
                .word song0voice3

temp_vars:
.byte 0, 0, 0, 0

//-----------------------------------------------------------------------------
//-Tables below added for Multi-SID support
//-----------------------------------------------------------------------------
sid_address_lo:
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0

sid_address_hi:
.byte $d4, $d4, $d4, $d4, $d4, $d4, $d4, $d4
.byte $d5, $d5, $d5, $d5, $d5, $d5, $d5, $d5
.byte $d6, $d6, $d6, $d6, $d6, $d6, $d6, $d6
.byte $d7, $d7, $d7, $d7, $d7, $d7, $d7, $d7
.byte $de, $de, $de, $de, $de, $de, $de, $de
.byte $df, $df, $df, $df, $df, $df, $df, $df

sid_address_index:
.byte 0

