# nfsdump

nfsdump is a tool to capture and pretty-print NFSv2 and NFSv3 traces. It is based on tcpdump, but has been optimized and extended for NFS capture. Better tools have been written, but nfsdump is still useful in a few contexts.

http://www.eecs.harvard.edu/sos/software/

## Build on Ubuntu

This program does not work in 64-bit mode because `rpc_msg` expects `u_long` to be 4-octet, but `u_long` is 8-octet on 64-bit platform.
Therefore, we must compile it as 32-bit executable.

    sudo apt-get install gcc-multilib libpcap0.8-dev:i386
    CFLAGS="-O0 -g3 -m32" ./configure
    make


