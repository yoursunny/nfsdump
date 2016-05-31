# pathtree tools

These scripts reconstruct the full path for each NFS request.

Requirements: nodejs, gawk, php-cli

Installation: `npm install csv`

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

Invocation NodeJS version:

    nodejs fullpath.js < x.fhparent > x.fullpath

Invocation C++ version:

    cat x.fhparent | tr ',' '\t' | ./fullpath > x.fullpath

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

## fullpath-svc

This tool is a lookup service for fullpath records.

Invocation:

    ./fullpath-svc < x.fullpath

The program reads the .fullpath file into memory, and listens on `fullpath-svc.sock` UNIX socket.

One client can connect at a time.
Filehandles are written into the socket one per line, and lookup result is returned on the socket.
If a filehandle is not found, it's echoed back.

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

`fullpath-svc` must be running and listening on `./fullpath-svc.sock`.

Invocation:

    nodejs operations.js clientIP-hex < x.nfsdump > x.clientIP.operations

The output is CSV format. Columns:

1. timestamp (start time)
2. operation, one of: attr, readlink, read, write, dir, setattr, create, mkdir, symlink, remove, rmdir, rename
3. full name
4. (except access/readlink/rename) file version (mtime or pre-mtime)
5. (read/write only) offset as integer; (readdir only) cookie as hex
6. (read/write only) count as integer; (readdir only) directory entry count as integer

## rwmerge

This tool merges consecutive read/write/readdir operations in `operations` output.

Invocation:

    sort -t, -k2,3 -k1nr x.clientIP.operations | nodejs rwmerge.js | sort -k1n > x.clientIP.ops

Each segment is 4096 octets.
Reading/writing any portion of a segment is converted to reading/writing the whole segment.
Multiple consequtive read/write operations on sequential range are merged and shown as one operation.

The output is CSV format. Columns:

1. timestamp (start time)
2. operation, one of: attr, readlink, read, write, dir, setattr, create, mkdir, symlink, remove, rmdir, rename
3. full name
4. (except access/readlink/rename) file version (mtime or pre-mtime)
5. (read/write) segment start; (readdir only) segment start, always 0
6. (read/write/readdir only) segment count
