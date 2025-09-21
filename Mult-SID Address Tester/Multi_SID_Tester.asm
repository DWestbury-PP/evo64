/* -------------------------------------------------------------------------------------------
MultiSID Tester - A simple utility to test SIDs listening on different addresses

By: Darrell Westbury (DWestbury_505@msn.com)
Version: 0.9 (Beta)
Preview Release: May 6th 2024 

Background:
This is the first Assembly Language code I've written since 1992.
It's been a blast rolling the sleeves up again, but I'm 'clearly' a bit rusty.

Usage:
I'm hoping the simple Grid-based navigation system, combined with the lower status bar and
the Command Reference make this tool pretty easy and intuitive to use.

Credits:
When I was looking for a Music Player routine that I could modify easily to support multiple SID addresses,
I was thrilled to find some code by Cadaver (loorni@gmail.com) that just what the Doctor ordered.
https://cadaver.github.io/rants/music.html

I also made good use of this nifty PETSCII editor to create the Command Reference screen.
https://petscii.krissz.hu/

Other great tools I used include:
KickAssembler: http://theweb.dk/KickAssembler/Main.html
VICE: https://vice-emu.sourceforge.io/
Ultimate II+ Cartridge: https://www.ultimate64.com/
EVO64: https://www.evo64.com/

Considerations:
> This is an early work in progress, and I'm sure there are many bugs and opportunities for improvements to be made.
> You will experience instability if you're using a cartridge like RetroReplay and tryin to use SIDs addressing in the $DE00-$DFE0 range.
> I welcome suggestions and feedback, so please feel free to reach out to me at: DWestbury_505@msn.com
*/

#import "music_player.asm"     // $1000 - Music Player routine by Cadaver
#import "sprite_data.asm"      // $2000 - Sprite data for the Grid Block and Status Bar
#import "screen_char_data.asm" // $4000 - Character data for the Grid Block and Info Page


.pc = $0801 "Basic SYS 2064"   // BASIC Header with default start address
:BasicUpstart($810)

.pc = $810 "SID-Grid Interface"

// Define labels and constants
.const SCREEN_MEM    = $0400   // Start of C64 screen memory
.const COLOR_MEM     = $D800   // Start of C64 color memory
.const CHAR_GRID_X   = $02     // Zeropage reference for the current X positon on the Grid
.const CHAR_GRID_Y   = $03     // Zeropage reference for the current Y positon on the Grid

// Main program start
    jsr DrawSIDGrid           // Draw the SID address table with Sprite0 for navigation
    jsr InitializeStatusBar   // Initialize the status bar
    jsr SetUpRasterInterrupt  // Set up a raster interrupt for Sprite0 color cycling
    lda #$00                  // Initialize the music player for SID 1 @ $D400
    jsr MUSIC_INIT              

// Main loop to scan for key presses and joystick movements
MainLoop:
    jsr $FFE4                 // C64 Kernal routine to check for key press
    bne KeyPressed            // check if no key has been pressed
    inc JOYSTICK_DEBOUNCE     // Read Joystick in port 2 with debounce logic (e.g., every 1,280 MainLoop cycles)
    lda JOYSTICK_DEBOUNCE
    bne MainLoop
    inc JOYSTICK_DEBOUNCE +1
    lda JOYSTICK_DEBOUNCE +1
    cmp #$05
    bne MainLoop
    lda #$00
    sta JOYSTICK_DEBOUNCE +1
    lda $DC00                 // Read joystick port 2
    cmp #$7F                  // Check for joystick movement
    bne Joystick_handler 
    jmp MainLoop

Joystick_handler:
    cmp #$7E                  // Joystick 2 up
    beq CursorUp
    cmp #$7D                  // Joystick 2 down
    beq CursorDown
    cmp #$77                  // Joystick 2 left
    beq CursorLeft
    cmp #$7B                  // Joystick 2 right
    beq CursorRight
    cmp #$6F                  // Joystick 2 fire button
    beq SpaceSelect
    jmp MainLoop

KeyPressed:
    cmp #$11                  // cursor down
    beq CursorDown
    cmp #$91                  // cursor up
    beq CursorUp
    cmp #$1D                  // cursor left
    beq CursorLeft
    cmp #$9D                  // cursor right
    beq CursorRight
    cmp #$20                  // space bar to select
    beq SpaceSelect
    cmp #$85                  // F1 to Activate Command Reference
    beq CMDRefJump
    jmp MainLoop

//Jump table for Grid movement (maintains relative branching distances below 128 bytes)
CursorDown:
    jmp exCursorDown

CursorUp:  
    jmp exCursorUp

CursorLeft:
    jmp exCursorLeft

CursorRight:
    jmp exCursorRight

SpaceSelect:
    jmp exSpaceSelect

CMDRefJump:
    jmp CommandRefScreen


exCursorDown:
    lda SPRITE_GRID_Y
    clc
    adc #$01
    cmp #$06
    beq CursorDownBypass
    sta SPRITE_GRID_Y
    jsr MoveGridBlock
CursorDownBypass:
    jmp MainLoop

exCursorUp:
    lda SPRITE_GRID_Y
    sec
    sbc #$01
    cmp #$FF
    beq CursorUpBypass
    sta SPRITE_GRID_Y
    jsr MoveGridBlock
CursorUpBypass:
    jmp MainLoop

exCursorLeft:
    lda SPRITE_GRID_X
    clc
    adc #$01
    cmp #$08
    beq CursorLeftBypass
    sta SPRITE_GRID_X
    jsr MoveGridBlock
CursorLeftBypass:
    jmp MainLoop

exCursorRight:
    lda SPRITE_GRID_X
    sec
    sbc #$01
    cmp #$FF
    beq CursorRightBypass
    sta SPRITE_GRID_X
    jsr MoveGridBlock
CursorRightBypass:
    jmp MainLoop

exSpaceSelect:
    clc
    lda SPRITE_GRID_Y         // load the Y counter for the currently selected SID
    asl                       // Multiply by 8 to get the Y position in the grid
    asl
    asl
    clc
    adc SPRITE_GRID_X         // add the X counter to get the complete grid position
    sta NEW_SID_INDEX         // store the new SID index

    lda MUSIC_PLAY_FLAG       // If no SIDs are playing, active the Grid cell and start the music
    bne DeterminePlayState

NoMusicIsPlaying:
    lda #$01
    ldx NEW_SID_INDEX
    sta BOX_GRID_STATE, x     // store the new state of the box
    stx ACTIVE_SID_PLAY_INDEX
    sta MUSIC_PLAY_FLAG
    jsr DrawClosedbox
    jmp EndGridSelect

DeterminePlayState:           // Check whether a previous Grid cell was active
    lda NEW_SID_INDEX
    cmp ACTIVE_SID_PLAY_INDEX
    beq DeselectOld

DeselectOldAndSelectnew:      // Clear the old Grid cell and deactivate SID Playback
    ldx ACTIVE_SID_PLAY_INDEX
    lda #$00
    sta BOX_GRID_STATE, x     
    jsr DrawOpenBox

    ldx NEW_SID_INDEX         // Set the Grid cell and state for the new SID
    lda #$01
    sta BOX_GRID_STATE, x
    sta MUSIC_PLAY_FLAG
    stx ACTIVE_SID_PLAY_INDEX
    jsr DrawClosedbox
    jmp EndGridSelect

DeselectOld:                  // Clear the old Grid cell and deactivates SID Playback
    tax
    lda #$00
    sta BOX_GRID_STATE, x
    sta MUSIC_PLAY_FLAG
    jsr DrawOpenBox

EndGridSelect:
    lda ACTIVE_SID_PLAY_INDEX
    jsr MUSIC_INIT
    jmp MainLoop


DrawOpenBox:
    lda BOX_GRID_LB,x
    sta CHAR_GRID_X
    lda BOX_GRID_HB,x
    sta CHAR_GRID_Y
    ldy #$00
    lda #$70
    sta (CHAR_GRID_X),y
    iny
    lda #$6E
    sta (CHAR_GRID_X),y
    ldy #$28
    lda #$6D
    sta (CHAR_GRID_X),y
    iny
    lda #$7D
    sta (CHAR_GRID_X),y
    lda CHAR_GRID_Y
    clc
    adc #$D4
    sta CHAR_GRID_Y
    ldy #$00
    lda #$0F
    sta (CHAR_GRID_X),y
    iny
    sta (CHAR_GRID_X),y
    ldy #$28
    sta (CHAR_GRID_X),y
    iny
    sta (CHAR_GRID_X),y
    rts

DrawClosedbox:
    lda BOX_GRID_LB,x
    sta CHAR_GRID_X
    lda BOX_GRID_HB,x
    sta CHAR_GRID_Y
    ldy #$00
    lda #$6C
    sta (CHAR_GRID_X),y
    iny
    lda #$7B
    sta (CHAR_GRID_X),y
    ldy #$28
    lda #$7C
    sta (CHAR_GRID_X),y
    iny
    lda #$7E
    sta (CHAR_GRID_X),y
    lda CHAR_GRID_Y
    clc
    adc #$D4
    sta CHAR_GRID_Y
    ldy #$00
    lda #$02
    sta (CHAR_GRID_X),y
    iny
    sta (CHAR_GRID_X),y
    ldy #$28
    sta (CHAR_GRID_X),y
    iny
    sta (CHAR_GRID_X),y
    rts


// Draws the Command Reference Screen
CommandRefScreen:
    ldx #$00
    stx $D015 // Disable sprite 0
CopyCMDRefCharLoop:
    lda SCREEN_MEM       + 00,x
    sta $C000            + 00,x
    lda COLOR_MEM        + 00,x
    sta $c400            + 00,x
    lda MENU_SCREEN_DATA + 00,x
    sta SCREEN_MEM       + 00,x
    lda MENU_COLOR_DATA  + 00,x
    sta COLOR_MEM        + 00,x

    lda SCREEN_MEM       + 256,x
    sta $C000            + 256,x
    lda COLOR_MEM        + 256,x
    sta $c400            + 256,x
    lda MENU_SCREEN_DATA + 256,x
    sta SCREEN_MEM       + 256,x
    lda MENU_COLOR_DATA  + 256,x
    sta COLOR_MEM        + 256,x

    lda SCREEN_MEM       + 512,x
    sta $C000            + 512,x
    lda COLOR_MEM        + 512,x
    sta $c400            + 512,x
    lda MENU_SCREEN_DATA + 512,x
    sta SCREEN_MEM       + 512,x
    lda MENU_COLOR_DATA  + 512,x
    sta COLOR_MEM        + 512,x

    lda SCREEN_MEM       + 768,x
    sta $C000            + 768,x
    lda COLOR_MEM        + 768,x
    sta $c400            + 768,x
    lda MENU_SCREEN_DATA + 768,x
    sta SCREEN_MEM       + 768,x
    lda MENU_COLOR_DATA  + 768,x
    sta COLOR_MEM        + 768,x
    inx
    bne CopyCMDRefCharLoop

// Check for F1 key to exit Command Reference and return to Mainloop
MenuLoop:
    jsr $FFE4                 // C64 Kernal routine to check for key press
    cmp #$85                  // F1 to Exit Menu and Return to Mainloop
    beq ExitCMDRef
    cmp #$20                  // Space bar also Exits Menu
    beq ExitCMDRef
    jmp MenuLoop

ExitCMDRef:    
    ldx #$00
RestoreScreenState:
    lda $C000            + 00,x
    sta SCREEN_MEM       + 00,x
    lda $c400            + 00,x
    sta COLOR_MEM        + 00,x

    lda $C000            + 256,x
    sta SCREEN_MEM       + 256,x
    lda $c400            + 256,x
    sta COLOR_MEM        + 256,x

    lda $C000            + 512,x
    sta SCREEN_MEM       + 512,x
    lda $c400            + 512,x
    sta COLOR_MEM        + 512,x

    lda $C000            + 768,x
    sta SCREEN_MEM       + 768,x
    lda $c400            + 768,x
    sta COLOR_MEM        + 768,x
    inx
    bne RestoreScreenState
    lda #$FF
    sta $D015                 // Reenable sprites
    jmp MainLoop


// Subroutine to draw the main screen grid with SID address table
DrawSIDGrid:
    ldx #$00
    stx $d021                 // Set border color
//  inx
    stx $d020                 // Set screen background color
    lda #$01
    sta $0286                 // Set the active screen color (cursor) to white
    jsr $E544                 // Call C64 Kernal routine to clear the screen and fill color mem with white
    lda #$85                  // Set the character mode to Upper case
    jsr $FFE4
    lda #$08                  // Disable character change from upper to lower case
    jsr $FFE4


    ldx #$00    
CopySIDGridChars:
    lda MAIN_SCREEN_DATA + 00,x
    sta SCREEN_MEM       + 00,x
    lda MAIN_COLOR_DATA  + 00,x
    sta COLOR_MEM        + 00,x
    lda MAIN_SCREEN_DATA + 256,x
    sta SCREEN_MEM       + 256,x
    lda MAIN_COLOR_DATA  + 256,x
    sta COLOR_MEM        + 256,x
    lda MAIN_SCREEN_DATA + 512,x
    sta SCREEN_MEM       + 512,x
    lda MAIN_COLOR_DATA  + 512,x
    sta COLOR_MEM        + 512,x
    lda MAIN_SCREEN_DATA + 768,x
    sta SCREEN_MEM       + 768,x
    lda MAIN_COLOR_DATA  + 768,x
    sta COLOR_MEM        + 768,x
    inx
    bne CopySIDGridChars


// Place Grid Block Sprite on the screen
    lda #(SPR_GRID_BLOCK/64)   // Set sprite definition to Grid Block
    sta $07f8 
    lda #$02
    sta $d027                  // Set sprite color to red
    lda #$01
    sta $d015                  // Enable sprite 0
    
    lda #$00                   // Initialize the grid block position
    sta SPRITE_GRID_X
    sta SPRITE_GRID_Y

MoveGridBlock:
    ldx SPRITE_GRID_X          // Pointer to a table of fixed X coordinates 
    ldy SPRITE_GRID_Y          // Pointer to a table of fixed Y coordinates
    lda SPRITE_POS_X, x
    sta $d000                  // Set Grid Block (sprite 0) x position
    lda SPRITE_POS_X_OFFSET, x
    sta $d010
    lda SPRITE_POS_Y, y
    sta $d001                  // Set Grid Block (sprite 0) y position
    rts

// Status Bar Sprites
InitializeStatusBar:
    lda #$ff
    sta $d015                   // Enable Status Bar Sprites
    lda #$00
    sta STATUS_BAR_MSG_INDEX    // Initialize the status bar message index
    tay
    tax
InitStatusBarLoop:
    lda STATUS_BAR_SPRITE_X,y
    sta $d002,x
    lda #$F2
    sta $d003,x
    lda #$01
    sta $d028,y
    inx
    inx
    iny
    cpy #$07
    bne InitStatusBarLoop


UpdateStatusBar:
    lda #$00
    sta STATUS_BAR_SPR_DEF_OFFSET
    clc
    lda STATUS_BAR_MSG_INDEX
    asl
    rol STATUS_BAR_SPR_DEF_OFFSET
    asl
    rol STATUS_BAR_SPR_DEF_OFFSET
    asl
    rol STATUS_BAR_SPR_DEF_OFFSET
    clc
    adc #<STATUS_BAR_SPRITE_DEF
    sta UpdateStatusBarLoop + 1
    lda STATUS_BAR_SPR_DEF_OFFSET
    adc #>STATUS_BAR_SPRITE_DEF
    sta UpdateStatusBarLoop + 2    
    ldx #$00
UpdateStatusBarLoop:
    lda STATUS_BAR_SPRITE_DEF,x
    sta $07f9,x
    inx
    cpx #$07
    bne UpdateStatusBarLoop
    rts

StatusBarCycle:
    ldx STATUS_BAR_CYCLE_INDEX      // Cycle through SID play status and most commonly used menu options
    lda STATUS_BAR_CYCLE_STEP,x
    cmp #$FF                        // Check for special status messages (e.g., show the currently active SID or explain how to select & activate them)
    bne ContinueCycle
    lda MUSIC_PLAY_FLAG             // Check flag to see if SIDs are active. If not, cycle messages related to grid navigation & SID activation
    bne SIDsAreActive
    lda STATUS_BAR_CYCLE_WHEN_SIDS_OFF
    jmp ContinueCycle
SIDsAreActive:                      // If SIDs are active, show which SID is currently playing
    lda ACTIVE_SID_PLAY_INDEX
ContinueCycle:
    sta STATUS_BAR_MSG_INDEX

    inc STATUS_BAR_CYCLE_COUNTER    // Delay timer to hold current status message
    lda STATUS_BAR_CYCLE_COUNTER
    cmp #$80                        // Set number of screen refreshes to hold the message
    bne StatusBarDisplay
    lda #$00
    sta STATUS_BAR_CYCLE_COUNTER

    ldx STATUS_BAR_CYCLE_INDEX      // If SIDs are inactive, cycle through the activation tips
    lda STATUS_BAR_CYCLE_STEP,x
    cmp #$ff
    bne SkipInactiveSIDCycle
    lda NO_ACTIVE_SIDS
    bne SkipInactiveSIDCycle
    lda STATUS_BAR_CYCLE_WHEN_SIDS_OFF
    eor #$07
    sta STATUS_BAR_CYCLE_WHEN_SIDS_OFF

SkipInactiveSIDCycle:               // Increment through status bar messages
    inc STATUS_BAR_CYCLE_INDEX
    lda STATUS_BAR_CYCLE_INDEX
    cmp #$06
    bne StatusBarDisplay
    lda #$00
    sta STATUS_BAR_CYCLE_INDEX
StatusBarDisplay:
    jmp UpdateStatusBar



// Set up the raster interrupt
SetUpRasterInterrupt:
    sei                       // Disable interrupts while setting up
    lda #$7f                  // Mask all but the raster interrupt
    sta $DC0D                 // in CIA 1 interrupt control register
    sta $DD0D
    lda #$FF                  // Raster line at the beginning of the lower border
    sta $D012                 // Raster line low byte
    lda $D011                 // Load current value of $D011
    and #%01111111            // Clear bit 7
//    ora #%10000000          // Set bit 7 if LOWER_BORDER_RASTER_LINE is greater than 255
    sta $D011                 // Store back to $D011
    lda #$01
    sta $D01A                 // Enable raster interrupts
    lda #<RasterInterruptISR
    sta $0314
    lda #>RasterInterruptISR
    sta $0315
    cli                       // Re-enable interrupts
    rts

// Raster Interrupt Service Routine
RasterInterruptISR:
    pha                       // Save registers
    txa
    pha
    tya
    pha
//  inc $d020                 // Debug: Check ISR timing by changing the border color, before and after the interrupt
    jsr Sprite_Color_Cycle
    jsr StatusBarCycle
    jsr Play_Music
//  dec $d020                 // Debug: Reset the border color
    inc $D019                 // Acknowledge the interrupt
    pla                       // Restore registers
    tay
    pla
    tax
    pla
    jmp $EA31                 // Exit to Kernal routine to scan the keyboard


// Increment the color cycle of Sprite 0
Sprite_Color_Cycle:
    ldx CURRENT_COLOR_INDEX
    lda COLOR_SEQUENCE,x
    sta $D027
    sta $d028
    sta $d029
    sta $d02a
    sta $d02b
    sta $d02c
    sta $d02d
    sta $d02e
    inc CURRENT_COLOR_INDEX
    lda CURRENT_COLOR_INDEX
    cmp #$24
    bne SkipReset
    lda #$00
    sta CURRENT_COLOR_INDEX
SkipReset:
    rts

Play_Music:
    lda MUSIC_PLAY_FLAG
    beq SkipMusic
    ldx ACTIVE_SID_PLAY_INDEX
    lda BOX_GRID_STATE, x
    beq SkipMusic
    jsr MUSIC_PLAYER
SkipMusic:
    rts


// ----------------------------------------------------------
// Various Flags, Counters and Indices
// ----------------------------------------------------------

SPRITE_POS_X:
.byte 109, 133, 157, 181, 205, 229, 253, 277

SPRITE_POS_X_OFFSET:
.byte  0, 0, 0, 0, 0, 0, 0, 1

SPRITE_POS_Y:
.byte  103, 127, 151, 175, 199, 223

SPRITE_GRID_X:
.byte 0

SPRITE_GRID_Y:
.byte 0

BOX_GRID_LB:
.byte $FA, $FD, $00, $03, $06, $09, $0C, $0F 
.byte $72, $75, $78, $7B, $7E, $81, $84, $87
.byte $EA, $ED, $F0, $F3, $F6, $F9, $FC, $FF 
.byte $62, $65, $68, $6B, $6E, $71, $74, $77 
.byte $DA, $DD, $E0, $E3, $E6, $E9, $EC, $EF 
.byte $52, $55, $58, $5B, $5E, $61, $64, $67 

BOX_GRID_HB:
.byte $04, $04, $05, $05, $05, $05, $05, $05 
.byte $05, $05, $05, $05, $05, $05, $05, $05 
.byte $05, $05, $05, $05, $05, $05, $05, $05 
.byte $06, $06, $06, $06, $06, $06, $06, $06 
.byte $06, $06, $06, $06, $06, $06, $06, $06
.byte $07, $07, $07, $07, $07, $07, $07, $07 

BOX_GRID_STATE:
.byte 0, 0, 0, 0, 0, 0, 0, 0 
.byte 0, 0, 0, 0, 0, 0, 0, 0
.byte 0, 0, 0, 0, 0, 0, 0, 0
.byte 0, 0, 0, 0, 0, 0, 0, 0
.byte 0, 0, 0, 0, 0, 0, 0, 0
.byte 0, 0, 0, 0, 0, 0, 0, 0

// Color cycle for Sprite 0: White, Yellow, Light Red... 
COLOR_SEQUENCE:
.byte   1,  1,  1,  1,  1,  7,  7,  7
.byte   7,  7, 10, 10, 10, 10, 10, 10
.byte  10,  2,  2,  2,  2,  2,  2,  2
.byte   2,  2, 10, 10, 10, 10, 10,  7
.byte   7,  7,  7,  7

// Status Bar Sprite Positions
STATUS_BAR_SPRITE_X:
.const SPRITE_BAR_X = 111
.byte  SPRITE_BAR_X +24*0
.byte  SPRITE_BAR_X +24*1
.byte  SPRITE_BAR_X +24*2
.byte  SPRITE_BAR_X +24*3
.byte  SPRITE_BAR_X +24*4
.byte  SPRITE_BAR_X +24*5
.byte  SPRITE_BAR_X +24*6


STATUS_BAR_MSG_INDEX:
.byte 0

STATUS_BAR_SPR_DEF_OFFSET:
.byte 0

STATUS_BAR_CYCLE_COUNTER:
.byte 0

STATUS_BAR_CYCLE_INDEX:
.byte 0

STATUS_BAR_CYCLE_WHEN_SIDS_OFF:
.byte $34

STATUS_BAR_CYCLE_STEP:
//.byte 48, 255, 49, 255, 50, 255
.byte 255, 255, 255, 255, 255, 255

// Flags & indicies
CURRENT_COLOR_INDEX:
.byte 0

ACTIVE_SID_PLAY_INDEX:
.byte 0

NEW_SID_INDEX:
.byte 0

NO_ACTIVE_SIDS:
.byte 0

MUSIC_PLAY_FLAG:
.byte 0

JOYSTICK_DEBOUNCE:
.byte 0, 0


// -----------------------------------------------
// Sprite Definition Sets for the Lower Status Bar
// -----------------------------------------------
STATUS_BAR_SPRITE_DEF:
// -----------------------
// SIDS in the $D400 Range
// -----------------------
// ACTIVE SID ON:  $D400
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +0
.byte 0

// ACTIVE SID ON:  $D420
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +1
.byte 0

// ACTIVE SID ON:  $D440
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +2
.byte 0

// ACTIVE SID ON:  $D460
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +3
.byte 0

// ACTIVE SID ON:  $D480
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +4
.byte 0

// ACTIVE SID ON:  $D4A0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +5
.byte 0

// ACTIVE SID ON:  $D4C0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +6
.byte 0

// ACTIVE SID ON:  $D4E0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +7
.byte 0

// -----------------------
// SIDS in the $D500 Range
// -----------------------
// ACTIVE SID ON:  $D500
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +8
.byte 0

// ACTIVE SID ON:  $D520
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +9
.byte 0

// ACTIVE SID ON:  $D540
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +10
.byte 0

// ACTIVE SID ON:  $D560
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +11
.byte 0

// ACTIVE SID ON:  $D580
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +12
.byte 0

// ACTIVE SID ON:  $D5A0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +13
.byte 0

// ACTIVE SID ON:  $D5C0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +14
.byte 0

// ACTIVE SID ON:  $D5E0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +15
.byte 0

// -----------------------
// SIDS in the $D600 Range
// -----------------------
// ACTIVE SID ON:  $D600
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +16
.byte 0

// ACTIVE SID ON:  $D620
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +17
.byte 0

// ACTIVE SID ON:  $D640
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +18
.byte 0

// ACTIVE SID ON:  $D660
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +19
.byte 0

// ACTIVE SID ON:  $D680
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +20
.byte 0

// ACTIVE SID ON:  $D6A0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +21
.byte 0

// ACTIVE SID ON:  $D6C0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +22
.byte 0

// ACTIVE SID ON:  $D6E0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +23
.byte 0

// -----------------------
// SIDS in the $D700 Range
// -----------------------
// ACTIVE SID ON:  $D700
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +24
.byte 0

// ACTIVE SID ON:  $D720
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +25
.byte 0

// ACTIVE SID ON:  $D740
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +26
.byte 0

// ACTIVE SID ON:  $D760
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +27
.byte 0

// ACTIVE SID ON:  $D780
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +28
.byte 0

// ACTIVE SID ON:  $D7A0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +29
.byte 0

// ACTIVE SID ON:  $D7C0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +30
.byte 0

// ACTIVE SID ON:  $D7E0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +31
.byte 0

// -----------------------
// SIDS in the $DE00 Range
// -----------------------
// ACTIVE SID ON:  $DE00
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +32
.byte 0

// ACTIVE SID ON:  $DE20
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +33
.byte 0

// ACTIVE SID ON:  $DE40
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +34
.byte 0

// ACTIVE SID ON:  $DE60
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +35
.byte 0

// ACTIVE SID ON:  $DE80
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +36
.byte 0

// ACTIVE SID ON:  $DEA0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +37
.byte 0

// ACTIVE SID ON:  $DEC0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +38
.byte 0

// ACTIVE SID ON:  $DEE0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +39
.byte 0

// -----------------------
// SIDS in the $DF00 Range
// -----------------------
// ACTIVE SID ON:  $DF00
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +40
.byte 0

// ACTIVE SID ON:  $DF20
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +41
.byte 0

// ACTIVE SID ON:  $DF40
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +42
.byte 0

// ACTIVE SID ON:  $DF60
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +43
.byte 0

// ACTIVE SID ON:  $DF80
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +44
.byte 0

// ACTIVE SID ON:  $DFA0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +45
.byte 0

// ACTIVE SID ON:  $DFC0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +46
.byte 0

// ACTIVE SID ON:  $DFE0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +47
.byte 0

// [F3] TOGGLES MUSIC
.byte (SPR_STATUS1/64) +0
.byte (SPR_STATUS1/64) +1
.byte (SPR_STATUS1/64) +2
.byte (SPR_STATUS1/64) +3
.byte (SPR_STATUS1/64) +4
.byte (SPR_STATUS1/64) +5
.byte (SPR_STATUS1/64) +6
.byte 0

// [F5/F6] TO SWITCH SID
.byte (SPR_STATUS2/64) +0
.byte (SPR_STATUS2/64) +1
.byte (SPR_STATUS2/64) +2
.byte (SPR_STATUS2/64) +3
.byte (SPR_STATUS2/64) +4
.byte (SPR_STATUS2/64) +5
.byte (SPR_STATUS2/64) +6
.byte 0

// [F7] CLEARS THE GRID
.byte (SPR_STATUS3/64) +0
.byte (SPR_STATUS3/64) +1
.byte (SPR_STATUS3/64) +2
.byte (SPR_STATUS3/64) +3
.byte (SPR_STATUS3/64) +4
.byte (SPR_STATUS3/64) +5
.byte (SPR_STATUS3/64) +6
.byte 0

// MOVE - CURSORS / JOY2
.byte (SPR_STATUS5/64) +0
.byte (SPR_STATUS5/64) +1
.byte (SPR_STATUS5/64) +2
.byte (SPR_STATUS5/64) +3
.byte (SPR_STATUS5/64) +4
.byte (SPR_STATUS5/64) +5
.byte (SPR_STATUS5/64) +6
.byte 0

// SELECT - SPACE / FIRE
.byte (SPR_STATUS6/64) +0
.byte (SPR_STATUS6/64) +1
.byte (SPR_STATUS6/64) +2
.byte (SPR_STATUS6/64) +3
.byte (SPR_STATUS6/64) +4
.byte (SPR_STATUS6/64) +5
.byte (SPR_STATUS6/64) +6
.byte 0

