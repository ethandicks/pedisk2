target_ptr    = $b7       ;Pointer: PEDISK target address for memory ops **
dos           = $7800     ;Base address for the RAM-resident portion
track         = dos+$0792 ;Track number to write to WD1793 (0-76 or $00-4c)
sector        = dos+$0793 ;Sector number to write to WD1793 (1-26 or $01-1a)
num_sectors   = dos+$0796 ;Number of sectors to read or write
write_sectors = $ed3f     ;Number of sectors to write
deselect      = $eb0b     ;Deselect drive
setnam        = $ffbd     ;KERNAL Set filename
setlfs        = $ffba     ;KERNAL Set logical file
chrout        = $ffd2     ;KERNAL write by to default output (screen)
load          = $ffd5     ;KERNAL Load file

data          = $0800   ;Base address where track data will be loaded
data_track    = data+0  ;Track number for the data
data_sec_cnt  = data+1  ;Count of sectors in the data
data_next_trk = data+2  ;Next track after this one, or $FF if none
data_sectors  = data+3  ;Sector data (128 bytes * data_sec_cnt)

    *=$0400

bas_header:
    !byte $00           ;Null byte at start of BASIC program
    !word bas_eol+1     ;Pointer to the next BASIC line
bas_line:
    !word $000a         ;Line number
    !byte $9e           ;Token for SYS command
    !text "1037"        ;Arguments for SYS
bas_eol:
    !byte $00           ;End of BASIC line
    !byte $00,$00       ;End of BASIC program

loop:
    jsr print_filename
    jsr load_track_file
    ;jsr write_track
    lda data_next_trk
    cmp #$ff
    beq done
    jsr update_filename
    jmp loop
done:
    rts

print_filename:
    ldx #0
msg_loop:
    txa
    pha
    lda filename,x
    jsr chrout
    pla
    tax
    inx
    cpx #filename_len
    bne msg_loop
    lda #$0d
    jsr chrout
    rts

load_track_file:
;Load the track data from a CBM program file
;
    lda #0
    sta $96             ;Clear status byte ST

    lda #0
    sta $9d             ;Set load/Verify select flag: 0 = Load

    lda #filename_len
    sta $d1             ;Set length of filename = 12 bytes

    lda #<filename
    sta $da             ;Set low address of filename
    lda #>filename
    sta $da+1           ;Set high address of filename

    lda #8
    sta $d4             ;Device number = 8

    lda #1
    sta $d3             ;Secondary address = 1

    lda #<data
    sta $fb             ;Set low address to load data into
    lda #>data
    sta $fb+1           ;Set high address to load data into

    jsr $f356           ;Load ($f356 address is BASIC 4 specific)
                        ;  If loading fails, $f356 does not return control.
                        ;  An error message like "?file not found in 10" will
                        ;  be printed and the BASIC prompt will return.
    rts

update_filename:
    lda data_next_trk
    lsr
    lsr
    lsr
    lsr
    and #$0f
    tax
    lda hex_chars,x
    sta filename_end-2
    lda data_next_trk
    and #$0f
    tax
    lda hex_chars,x
    sta filename_end-1
    rts
hex_chars:
  !text "0123456789ABCDEF"

write_track:
;Write the track data to the PEDISK
;
    lda data_track
    sta track
    lda #1
    sta sector
    lda data_sec_cnt
    sta num_sectors
    lda #<data_sectors
    sta target_ptr
    lda #>data_sectors
    sta target_ptr+1
    jsr write_sectors
    jsr deselect
    rts

filename:     !text "TRACK $00"
filename_end = *
filename_len = filename_end - filename
