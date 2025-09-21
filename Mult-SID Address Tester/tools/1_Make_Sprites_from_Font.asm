.pc = $0801 "SYS 2064"
:BasicUpstart($0810) 
.pc = $0810 "Main Code"

.const KERNAL_PRINT = $AB1E
.const TXT2SPR_PTR_LO = $FB
.const TXT2SPR_PTR_HI = $FC

    jsr $e544                      // Clear the screen

// Clear Sprite data area (e.g. 80 sprites @ 64 bytes each, from $2000-$33ff)
    lda #<clearSpriteDataLog        // Debug: Print output log to the screen
    ldy #>clearSpriteDataLog
    jsr KERNAL_PRINT

    lda #$20
    sta spriteClearLoop+2
    lda #$00
    sta spriteClearLoop+1
    tax
spriteClearLoop:
    sta $2000,x
    inx
    bne spriteClearLoop
    inc spriteClearLoop+2
    ldy spriteClearLoop+2
    cpy #$40
    bne spriteClearLoop


// Main loop to step through the textToSprite table and write each text character to a sprite
    lda #<beginTxt2SpriteCopyLog    // Debug: Print output log to the screen
    ldy #>beginTxt2SpriteCopyLog
    jsr KERNAL_PRINT

    lda $dc0e                       // Deactivate Char ROM Interrupts
    and #$fe
    sta $dc0e
    lda #$33                        // Make charset ROM bank visible in RAM
    sta $01

    lda #<textToSprite              // Set the textToSprite table pointer
    sta TXT2SPR_PTR_LO
    lda #>textToSprite
    sta TXT2SPR_PTR_HI
    
    lda #$00                        
    sta textToSpriteIndex           // Reset textToSpriteIndex
    sta spriteCounter               // Reset spriteCounter
    sta spriteColumnIndex           // Reset spriteColumnIndex
nextCharToSprite:
    jsr setCharCopyAddr             // Determine where to look in the Character set ROM for the required Character definition
    jsr setSpriteDataAddr           // Determine where to write the character sprite data to in memory
    ldy textToSpriteIndex           
    lda (TXT2SPR_PTR_LO),y              // Get the next character from the textToSprite table
    cmp #$ff                        // Check if we've reached the end of the table
    beq doneWithChars2Sprites
    cmp #$00                        // Check if we've reached the end of the line
    bne prepareToWriteChars
    inc textToSpriteIndex           // Skip the line feed character
    lda textToSpriteIndex
    bne withinPageBounds2
    inc TXT2SPR_PTR_HI
withinPageBounds2:
    jmp nextCharToSprite
prepareToWriteChars:
    jsr writeCharToSprite           // Copy character data from Character Set ROM to spriteData
//    jsr writeCharDebug              // debug: Thorough debug log with details of character conversion
    inc spriteColumnIndex           // Move to the next column in the sprite
    lda spriteColumnIndex
    cmp #$03                        // Check if we've reached the 3rd byte (column) of the sprite
    bne notReadyForNextSprite
    lda #$00
    sta spriteColumnIndex           // Reset spriteColumnIndex
    inc spriteCounter               // Move to the next sprite
notReadyForNextSprite:
    inc textToSpriteIndex           // Move to the next character in the textToSprite table
    lda textToSpriteIndex
    bne withinPageBounds
    inc TXT2SPR_PTR_HI
withinPageBounds:
    jmp nextCharToSprite
doneWithChars2Sprites:
    lda #$37                        // Restore charset ROM banking defaults
    sta $01
    lda $dc0e                       // Reenable Char ROM Interrupts
    ora #$01
    sta $dc0e
    lda #<endTxt2SpriteCopyLog      // debug: Processing completed
    ldy #>endTxt2SpriteCopyLog
    jsr KERNAL_PRINT

// Display Sprites that contain text
displaySprites:
    ldx #$00                        // Set the sprite data pointers for $2000-$33ff
    ldy #$0b                        // Choose which set of character sprite definitions to display
    lda spriteCharDefs,y
    tay
spritePointerLoop:
    tya
    sta $07f8,x
    iny
    inx
    cpx #$08
    bne spritePointerLoop

    ldx #$00
    ldy #$00
SetSpritePos:
    lda SPRITE_POS_X, x
    sta $d000,y
    lda SPRITE_POS_Y, x
    sta $d001,y
    lda #$01
    sta $d027,x
    iny
    iny
    inx
    cpx #$08
    bne SetSpritePos

    lda #$ff
    sta $d015 // Enable sprites 0-6
    rts


// Debug: Log details for the current Char, it's Chargen ROM address & the target Sprite address
writeCharDebug:
    ldy textToSpriteIndex
    lda (TXT2SPR_PTR_LO),y
    ldx #$06
    jsr Hex2Txt
    lda charLookupIndex+1
    sta printFirstByte+2
    ldx #$0f
    jsr Hex2Txt
    lda charLookupIndex
    sta printFirstByte+1
    ldx #$11
    jsr Hex2Txt
    lda spriteDataOffset+1
    ldx #$18
    jsr Hex2Txt
    lda spriteDataOffset
    ldx #$1A
    jsr Hex2Txt
printFirstByte:
    lda $D000
    ldx #$23
    jsr Hex2Txt
    lda #<writeCharDebugLog        // Print output log to the screen
    ldy #>writeCharDebugLog
    jsr KERNAL_PRINT
    rts

// Debug: Convert a byte to a 2-digit hex string
Hex2Txt:
    sta Hex2TxtByte
    ldy #$02
NextHexDigit:
    and #$0F
    cmp #$0A
    bmi HexNumeric
    clc
    adc #$07
HexNumeric:
    adc #$30
    sta writeCharDebugLog,x
    dey
    beq Hex2TxtDone
    dex
    lda Hex2TxtByte
    lsr
    lsr
    lsr
    lsr
    jmp NextHexDigit
Hex2TxtDone:
    rts

// Determine where to look in the Chargen ROM for the required Character definition
setCharCopyAddr:
    lda #$00
    sta charLookupIndex
    sta charLookupIndex+1
    ldy textToSpriteIndex
copyNextTxt:
    clc
    lda (TXT2SPR_PTR_LO),y          // Get the next character from the textToSprite table
    asl                             // Multiply by 8 to get the offset into the Character Set ROM
    rol charLookupIndex+1
    asl
    rol charLookupIndex+1
    asl
    rol charLookupIndex+1
    sta charLookupIndex
    clc
    lda charLookupIndex+1
    adc #$d0
    sta charLookupIndex+1
    rts

// Determine which sprite data address to write the character data into (e.g., spriteCounter * 64)
setSpriteDataAddr:
    clc
    lda #$00
    sta spriteDataOffset            // Reset spriteDataOffset
    sta spriteDataOffset+1
    lda spriteCounter               // Multiply spriteCounter by 64 to get the offset into the spriteData area
    asl
    rol spriteDataOffset+1
    asl
    rol spriteDataOffset+1
    asl
    rol spriteDataOffset+1
    asl
    rol spriteDataOffset+1
    asl
    rol spriteDataOffset+1
    asl
    rol spriteDataOffset+1
    sta spriteDataOffset
    bcc skipSpriteDataInc1
    inc spriteDataOffset+1
skipSpriteDataInc1:
    clc
    lda spriteDataOffset+1
    adc #$20
    sta spriteDataOffset+1
    rts


// Copy character data from Character Set ROM to spriteData
writeCharToSprite:
    lda charLookupIndex           // Set the address of the Current character definition in the Character Set ROM into readCharData (using self-modifying code)
    sta readCharData+1
    lda charLookupIndex+1
    sta readCharData+2
    lda spriteDataOffset          // Set the address of the Sprite to write character Data info (using self-modifying code)
    sta writeSpriteData+1
    lda spriteDataOffset+1
    sta writeSpriteData+2
    ldy #$00
    ldx spriteColumnIndex
readCharData:
    lda $d000,y                   // Read the next byte from the Character Set ROM
writeSpriteData:
    sta $2000,x
    inx
    inx
    inx
skipSpriteDataInc2:
    iny
    cpy #$08                      // Check if we've read all 8 bytes of the character definition
    bne readCharData
    rts


// Table containing text to be converted into  text to sprites
textToSprite:                    
.byte  52, 48, 48, 52, 50, 48, 52, 52, 48, 52, 54, 48, 52, 56, 48, 52,  1, 48, 52,  3, 48, 52,  5, 48,  0
.byte  53, 48, 48, 53, 50, 48, 53, 52, 48, 53, 54, 48, 53, 56, 48, 53,  1, 48, 53,  3, 48, 53,  5, 48,  0
.byte  54, 48, 48, 54, 50, 48, 54, 52, 48, 54, 54, 48, 54, 56, 48, 54,  1, 48, 54,  3, 48, 54,  5, 48,  0
.byte  55, 48, 48, 55, 50, 48, 55, 52, 48, 55, 54, 48, 55, 56, 48, 55,  1, 48, 55,  3, 48, 55,  5, 48,  0
.byte   5, 48, 48,  5, 50, 48,  5, 52, 48,  5, 54, 48,  5, 56, 48,  5,  1, 48,  5,  3, 48,  5,  5, 48,  0
.byte   6, 48, 48,  6, 50, 48,  6, 52, 48,  6, 54, 48,  6, 56, 48,  6,  1, 48,  6,  3, 48,  6,  5, 48,  0
.byte  32, 32, 27,  6, 51, 29, 32, 20, 15,  7,  7, 12,  5, 19, 32, 13, 21, 19,  9,  3, 32,  0
.byte  27,  6, 53, 47,  6, 54, 29, 32, 20, 15, 32, 19, 23,  9, 20,  3,  8, 32, 19,  9,  4,  0
.byte  27,  6, 55, 29, 32,  3, 12,  5,  1, 18, 19, 32, 20,  8,  5, 32,  7, 18,  9,  4, 32,  0
.byte   1,  3, 20,  9, 22,  5, 32, 19,  9,  4, 32, 15, 14, 58, 32, 32, 36,  4,  0
.byte  13, 15, 22,  5, 32, 45, 32,  3, 21, 18, 19, 15, 18, 19, 32, 47, 32, 10, 15, 25, 50,  0
.byte  19,  5, 12,  5,  3, 20, 32, 45, 32, 19, 16,  1,  3,  5, 32, 47, 32,  6,  9, 18,  5,  0
.byte 255


// Output log strings
clearSpriteDataLog:
.text "CLEARING SPRITE DATA"
.byte 13, 0

beginTxt2SpriteCopyLog:
.text "BEGIN TEXT TO SPRITE CONVERSION"
.byte 13, 0

endTxt2SpriteCopyLog:
.text "COMPLETED TEXT TO SPRITE CONVERSION"
.byte 13, 0

writeCharDebugLog:
.text "CHR:$"
.byte 0, 0                          // Char offset: 5-6
.text " FROM:$"
.byte 0, 0, 0, 0                    // Char offset: 14-17
.text " TO:$"
.byte 0, 0, 0, 0                    // Char offset: 23-26
.text " BYT1:$"
.byte 0, 0, 13, 0                   // Char offset: 34-35


// Temporary byte for Hex2Txt conversion
Hex2TxtByte:
.byte 0

// Temporary index into character definitions in Character Set ROM
charLookupIndex:              
.byte 0, 0

// Index into the textToSprite table to lookup new characters to convert to sprites
textToSpriteIndex:            
.byte 0

// Counter to keep track of of the number of sprites that have been created so far (max = 80)
spriteCounter:                
.byte 0

// Index to keep track of which column is being written to in the currently selected sprite
spriteColumnIndex:            
.byte 0

spriteDataOffset:
.byte 0, 0, 0, 0

// Sprite positions
SPRITE_POS_X:
.byte 86, 110, 134, 158, 182, 206, 230, 254

SPRITE_POS_X_OFFSET:
.byte 0, 0, 0, 0, 0, 0, 0, 0

SPRITE_POS_Y:
.byte 240, 240, 240, 240, 240, 240, 240, 240

spriteCharDefs:
.byte $80, $88, $90, $98, $a0, $a8, $b0, $b7, $be, $c5, $cb, $d2, $db, $e2, $e9, $f0, $f7, $fe
