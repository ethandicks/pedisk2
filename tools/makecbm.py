'''
Make a CBM DOS image (e.g. D64 file) that can write a PEDISK disk.  The
CBM DOS image will contain track data for one PEDISK disk and a program
to write those tracks to the PEDISK.

Process for bootstrapping the PEDISK with no existing PEDISK media:
 - Run makeboot.py to make a bootable PEDISK disk image
 - Run makecbm.py (this file) to make a CBM DOS image from it
 - Write the CBM DOS image to a CBM drive
 - Run the "FORMAT8" program from the CBM drive to format a PEDISK 8" disk
 - Run the "BOOTSTRAP" program from the CBM drive to write the PEDISK tracks
 - Boot from the new PEDISK disk with "SYS 59904"

Usage: makecbm.py <input.img> <output.d64|output.d80|output.d82>
'''
import datetime
import os
import shutil
import sys
import tempfile

import imageutil

def extract_tracks_to_prg_files(imagename):
    img = imageutil.DiskImage.read_file(imagename)
    fs = imageutil.Filesystem(img)
    fs.compact()

    last_track = min(img.TRACKS - 1, fs.next_free_ts[0] + 1)

    for track in range(last_track + 1):
        img.seek(track=track, sector=1)
        data = img.read(img.SECTORS * img.SECTOR_SIZE)

        if track == last_track:
            next_track = 0xFF # no next track
        else:
            next_track = track + 1

        with open("track 0x%02x" % track, "wb") as f:
            f.write(bytearray([0x00, 0x08])) # load address = 0x0800
            f.write(bytearray([track])) # track number
            f.write(bytearray([img.SECTORS])) # number of sectors
            f.write(bytearray([next_track])) # next track number
            f.write(data) # sector data

def acme(srcfile, outfile):
    res = os.system("acme -v -f cbm -o '%s' '%s'" % (outfile, srcfile))
    assert res == 0

def petcat(srcfile, outfile):
    res = os.system("petcat -w4 -l 0401 -o '%s' -- '%s'" % (outfile, srcfile))
    assert res == 0

def create_cbm_image_from_dir(imagename, dirname):
    cbm_type = os.path.splitext(imagename)[1].lstrip('.').lower() # "d64"
    now = datetime.datetime.now()
    disk_name = now.strftime('%Y-%m-%d %H:%M')
    disk_id = now.strftime('%S')
    res = os.system("c1541 -format '%s','%s' '%s' '%s'" % (
        disk_name, disk_id, cbm_type, imagename))
    assert res == 0
    for filename in sorted(os.listdir(dirname)):
        os.system("c1541 -attach '%s' -write '%s'" % (imagename, filename))
        assert res == 0

def main(argv):
    if len(argv) != 3:
        sys.stderr.write(__doc__)
        sys.exit(1)
    pedisk_image, cbm_image = map(os.path.abspath, argv[1:])

    here = os.getcwd()
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    tempdir = tempfile.mkdtemp()
    os.chdir(tempdir)
    try:
        extract_tracks_to_prg_files(pedisk_image)
        acme(srcfile=os.path.join(root, 'tools', 'bootstrap', 'format8.asm'),
             outfile='format8')
        acme(srcfile=os.path.join(root, 'tools', 'bootstrap', 'bootstrap.asm'),
             outfile='bootstrap')
        petcat(srcfile=os.path.join(root, 'tools', 'bootstrap', 'tester.bas'),
               outfile='tester')
        create_cbm_image_from_dir(cbm_image, '.')
        print("CBM DOS image file written to %s" % cbm_image)
    finally:
        os.chdir(here)
        shutil.rmtree(tempdir)

if __name__ == '__main__':
    main(sys.argv)
