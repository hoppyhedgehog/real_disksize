BASH Script(Tool) to calculate the actual amount of data on a disk.

It will display the actual disk size, the start time, and how long it took to scan the disk.

The tool reads the First and Last Logical Block address to then calculate how much data is ACTUALLY 

on the disk.

*note: It may take a LONG time depending on the size of the disk and how much data.

Usage:
$  ./real_disksize.sh
Usage: real_disksize.sh /dev/sdX [-c <chunk_MB>]
  -c <chunk_MB>   Chunk size in MiB (64,128,256,512,1024). Default: 128


Execution (using default chunk size of 128)

$ ./real_disksize.sh  /dev/sda

Execution (Using chunk size 512)

$ ./real_disksize.sh  -c 512 /dev/sda


Execution (Running in the background)
To run it in the background you may use

$ nohup bash -c "./real_disksize.sh -c 512 /dev/sdo" nohup.out &
$
$ tail -f nohup.out
 Device            : /dev/sdo
 Logical Sector    : 512 bytes
 dd Block Size     : 65536 bytes (64 KiB)
 Total Sectors     : 7501476528
 Total Bytes       : 3840755982336
 Disk Size         : 3576.98 GiB
 Chunk Size        : 512 MiB (8192 x 64KiB blocks)
====================================================

Phase 1: Coarse scan in 512 MiB steps...

