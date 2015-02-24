vartab = $2a
dir_a_ptr = $4b
dir_b_ptr = $4d
target_ptr = $b7
L790D = $790D
pdos_prompt = $7A05
try_extrnl_cmd = $7A47
input_device = $7AD1
drive_sel = $7f91
track = $7f92
sector = $7f93
num_sectors = $7f96
next_incr = $EC74
read_sectors = $ECE4
write_sectors = $ED3F
puts = $EFE7
chrout = $FFD2

    *=$7c00

    jmp start

L7C03:
    !byte 0
L7C04:
    !byte $09

disk_compression:
    !text $0d,"** DISK COMPRESSION **",$0d
    !text "   KEYBOARD LOCKED",0
moving_file:
    !text $0d,"MOVING FILE ",0
cant_read_file:
    !text $0d," CANNOT READ-DELETE FILE ",0
cant_write_index:
    !text $0d," CANNOT WRITE NEW INDEX-REFORMAT DISK",$0d
    !text "         ALL DATA IS LOST!",0
cant_write_file:
    !text $0d," CANNOT WRITE FILE ",0

start:
    ;Print banner and "KEYBOARD LOCKED"
    lda #<disk_compression
    ldy #>disk_compression
    jsr puts

    ;Print "DEVICE?" and get a valid drive number from the user
    ;  Sets drive_sel with the drive select pattern
    jsr input_device
    sta drive_sel

    lda #$60
    sta $7F9A
    ldx #$00
    stx track
    inx
    stx sector
    lda #$08
    sta num_sectors
    lda #$00
    sta target_ptr
    sta dir_a_ptr
    sta dir_b_ptr
    lda #$04
    sta target_ptr+1
    sta dir_a_ptr+1
    sta dir_b_ptr+1
    jsr read_sectors
    beq L7CE8           ;Branch if read succeeded
    jmp pdos_prompt

L7CE8:
    lda #$00
    sta $0408

L7CED:
    ;Advance to the next directory entry in dir_b
    lda dir_b_ptr
    clc
    adc #$10
    sta dir_b_ptr
    bcc L7CF8
    inc dir_b_ptr+1

L7CF8:
    ;Advance to the next directory entry in dir_a
    lda dir_a_ptr
    clc
    adc #$10
    sta dir_a_ptr
    bcc L7D03
    inc dir_a_ptr+1

L7D03:
    ;Check for end of directory
    ldy #$00            ;Y=$00 index to first byte of filename
    lda (dir_a_ptr),y   ;Get first byte of filename
    cmp #$FF            ;Is it equal to $FF (end of directory)?
    bne L7D0E           ;  No: branch to handle this entry
    jmp L7E36           ;  Yes: done with all entries, jump to finish up

L7D0E:
    ;Check if file was deleted
    ldy #$05            ;Y=$05 index to last byte of filename
    lda (dir_a_ptr),y   ;Get last byte of filename
    cmp #$FF            ;Is it equal to $FF (file deleted)?
    beq L7CF8

    inc $0408

    ldy #$0C            ;Y=$0c index to file track number
    lda (dir_a_ptr),y
    sta $7F98

    iny                 ;Y=$0d index to file sector number
    lda (dir_a_ptr),y
    sta $7F99
    iny                 ;Y=$0e index to file sector count low byte

    lda (dir_a_ptr),y
    sta (dir_b_ptr),y
    sta $7F9B
    iny                 ;Y=$0f index to file sector count high byte

    lda (dir_a_ptr),y
    sta (dir_b_ptr),y
    sta $7F9C

    ldy #$0C            ;Y=$0c index to file track number
    lda L7C03
    sta (dir_b_ptr),y
    iny

    lda L7C04
    sta (dir_b_ptr),y

    ldy #$0B            ;Y=$0b index to unknown byte
L7D45:
    lda (dir_a_ptr),y
    sta (dir_b_ptr),y
    dey
    bpl L7D45

    lda $7F99
    cmp L7C04
    bne L7D8A
    lda $7F98
    cmp L7C03
    bne L7D8A
    lda $7F9B
    sta $7FAE
    lda $7F9C
    sta $7FAF
    jsr L790D
    lda L7C04
    clc
    adc $59
    cmp #$1D            ;TODO Past last sector?  28 sectors per track on 5.25"
    bmi L7D7B
    sec
    sbc #$1C            ;TODO 28 sectors per track?
    inc L7C03
L7D7B:
    sta L7C04
    lda L7C03
    clc
    adc $58
    sta L7C03
L7D87:
    jmp L7CED
L7D8A:
    lda $7F9B
    ora $7F9C
    beq L7D87
    lda $7F9B
    sta num_sectors
    sec
    sbc $7F9A
    sta $7F9B
    bcs L7DB0
    dec $7F9C
    bpl L7DB0
    lda #$00
    sta $7F9B
    sta $7F9C
    beq L7DB6
L7DB0:
    lda $7F9A
    sta num_sectors
L7DB6:
    lda num_sectors
    sta $7F97
    lda $7F98
    sta track
    lda $7F99
    sta sector
    lda #$00
    sta target_ptr
    lda #$08
    sta target_ptr+1
    jsr read_sectors
    beq L7DE2           ;Branch if read succeeded

    ;Print " CANNOT READ-DELETE FILE "
    lda #<cant_read_file
    ldy #>cant_read_file
    jsr puts

    ;Print the filename at (dir_b_ptr)
    jsr put_dir_b_file

    jmp L7E65
L7DE2:
    jsr next_incr
    bcc L7DEA
    jmp L7E65
L7DEA:
    lda track
    sta $7F98
    lda sector
    sta $7F99
    lda $7F97
    sta num_sectors
    lda L7C03
    sta track
    lda L7C04
    sta sector

    ;Print "MOVING FILE "
    lda #<moving_file
    ldy #>moving_file
    jsr puts

    ;Print the filename at (dir_b_ptr)
    jsr put_dir_b_file

    lda #$00
    sta target_ptr
    lda #$08
    sta target_ptr+1
    jsr write_sectors
    bne L7E5B           ;Branch if a disk error occurred
    jsr next_incr
    bcc L7E27
    jmp L7E65
L7E27:
    lda track
    sta L7C03
    lda sector
    sta L7C04
    jmp L7D8A
L7E36:
    lda L7C03
    sta $0409
    lda L7C04
    sta $040A
    lda dir_b_ptr
    tay
    lda #$00
    sta dir_b_ptr
    lda #$FF
L7E4B:
    sta (dir_b_ptr),y
    iny
    bne L7E4B
    ldx dir_b_ptr+1
    inx
    stx dir_b_ptr+1
    cpx #$08
    bmi L7E4B
    bpl L7E65
L7E5B:
    ;Print "CANNOT WRITE FILE "
    lda #<cant_write_file
    ldy #>cant_write_file
    jsr puts

    ;Print the filename at (dir_b_ptr)
    jsr put_dir_b_file

L7E65:
    lda #$08
    sta num_sectors
    lda #$00
    sta target_ptr
    lda #$04
    sta target_ptr+1
    ldy #$00
    sty track
    iny
    sty sector
    jsr write_sectors
    beq L7E8A           ;Branch if write succeeded

    ;Print "CANNOT WRITE NEW INDEX-REFORMAT DISK"
    ;  and "ALL DATA IS LOST!"
    lda #<cant_write_index
    ldy #>cant_write_index
    jsr puts

    jmp pdos_prompt
L7E8A:
    lda #$04
    sta vartab
    sta vartab+1
    lda #$00
    sta $0400
    sta $0401
    sta $0402
    lda #'P'            ;P-PRINT DISK DIRECTORY
    jmp try_extrnl_cmd

put_dir_b_file:
;Print the filename at (dir_b_ptr)
;
    ldy #$00
pdbf1:
    lda (dir_b_ptr),y
    jsr chrout
    iny
    cpy #$06
    bmi pdbf1
    rts

filler:
    !byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    !byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    !byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    !byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    !byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    !byte $FF,$FF,$FF
