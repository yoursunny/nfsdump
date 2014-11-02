# pathtree tools

These scripts reconstruct the full path for each NFS request.

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

