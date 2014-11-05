# pathtree tools

These scripts reconstruct the full path for each NFS request.

Requirements: nodejs, gawk, php-cli

## fhparent

This tool parses `nfsdump` output, and extract filehandle-name-parent relations.

Invocation:

    nodejs fhparent.js < x.nfsdump > x.fhparent

The output is CSV format. Columns:

1. filehandle
2. name (file name, directory name, etc)
3. parent filehandle

As a special case, if column 3 is "MOUNTPOINT", column 2 is the full path of a mount point.

Example:

    cf46,/export1,MOUNTPOINT
    6adf,A,cf46
    5f35,B,cf46
    77ad,C,9a65
    1fd1,D,77ad

This means:

* The mountpoint "/export1" has filehandle cf46.
* cf46 contains child "A" with filehandle 6adf, and "B" with filehandle 5f35.
* Name for filehandle 77ad is "C", and its parent is 9a65.
* Name for filehandle 1fd1 is "D", and its parent is 77ad ("C").

## fullpath

This tool reads `fhparent` output, and derives full path for each filehandle.

Invocation:

    (undecided)

The output is CSV format. Columns:

1. filehandle
2. top level unresolved filehandle, or empty
3. path

If the mountpoint containing a filehandle is found, the full path is constructed: column 2 is empty, column 3 is an absolute path.  
If the mountpoint containing a filehandle cannot be found, the full path cannot be constructed: column 2 is the top level filehandle that can be tracked to, and column 3 is the relative path beginning from that filehandle.

Example (derived from fhparent example):

    cf46,,/export1
    6adf,,/export1/A
    5f35,,/export1/B
    9a65,9a65,
    77ad,9a65,C
    1fd1,9a65,C/D

## clients

This tool parses `nfsdump` output, and extract client IP address.

Invocation:

    bash clients.sh < x.nfsdump > x.clients

The output is CSV format. Columns:

1. client IP hex
2. client IP textual representation

Example:

    c0a87e10,192.168.126.16
    c0a87e11,192.168.126.17

Note: It's necessary to ignore port numbers, because NFSv3 and MOUNTv3 use different port numbers.

## operations

This tool parses `nfsdump` output, and reconstruct operations from a particular client.

Invocation:

    nodejs operations.js x.fullpath clientIP-hex < x.nfsdump > x.clientIP.operations

The output is CSV format. Columns:

1. timestamp (start time)
2. operation, one of: attr, readlink, read, write, dir, setattr, create, mkdir, symlink, remove, rmdir, rename
3. full name
4. (read/write only) file version
5. (read/write only) segment start
6. (read/write only) segment count

File version is the mtime before read/write operation starts, as observed by the client.

Each segment is 4096 octets.
Reading/writing any portion of a segment is converted to reading/writing the whole segment.
Multiple consequtive read/write operations on sequential range are merged and shown as one operation.
