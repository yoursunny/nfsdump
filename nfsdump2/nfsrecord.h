/*
 * Copyright (c) 2002-2003 by the President and Fellows of Harvard
 * College.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that:  (1) source code
 * distributions retain the above copyright notice and this paragraph
 * in its entirety, (2) distributions including binary code include
 * the above copyright notice and this paragraph in its entirety in
 * the documentation or other materials provided with the
 * distribution, and (3) all advertising materials mentioning features
 * or use of this software display the following acknowledgement: 
 * ``This product includes software developed by the Harvard
 * University, and its contributors.'' Neither the name of the
 * University nor the names of its contributors may be used to endorse
 * or promote products derived from this software without specific
 * prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

/*
 * $Id: nfsrecord.h,v 1.1 2009/12/03 14:11:40 ellard Exp ellard $
 */

typedef	struct	nfs_v3_stat_t {
	unsigned long	c3_total, r3_total;
	unsigned long 	c3_null, r3_null;
	unsigned long 	c3_getattr, r3_getattr;
	unsigned long 	c3_setattr, r3_setattr;
	unsigned long 	c3_lookup, r3_lookup;
	unsigned long 	c3_access, r3_access;
	unsigned long 	c3_readlink, r3_readlink;
	unsigned long 	c3_read, r3_read, r3_read_b, r3_read_m;
	unsigned long 	c3_write, r3_write, c3_write_b, c3_write_m;
	unsigned long 	c3_create, r3_create;
	unsigned long 	c3_mkdir, r3_mkdir;
	unsigned long 	c3_symlink, r3_symlink;
	unsigned long 	c3_mknod, r3_mknod;
	unsigned long 	c3_remove, r3_remove;
	unsigned long 	c3_rmdir, r3_rmdir;
	unsigned long 	c3_rename, r3_rename;
	unsigned long 	c3_link, r3_link;
	unsigned long 	c3_readdir, r3_readdir;
	unsigned long 	c3_readdirp, r3_readdirp;
	unsigned long 	c3_fsstat, r3_fsstat;
	unsigned long 	c3_fsinfo, r3_fsinfo;
	unsigned long 	c3_pathconf, r3_pathconf;
	unsigned long 	c3_commit, r3_commit;
	unsigned long 	c3_unknown, r3_unknown;
} nfs_v3_stat_t;

typedef	struct	nfs_v2_stat_t {
	unsigned long c2_total, r2_total;
	unsigned long c2_null, r2_null;
	unsigned long c2_getattr, r2_getattr;
	unsigned long c2_setattr, r2_setattr;
	unsigned long c2_root, r2_root;
	unsigned long c2_lookup, r2_lookup;
	unsigned long c2_readlink, r2_readlink;
	unsigned long c2_read, r2_read, r2_read_b, r2_read_m;
	unsigned long c2_write, r2_write, c2_write_b, c2_write_m;
	unsigned long c2_writecache, r2_writecache;
	unsigned long c2_create, r2_create;
	unsigned long c2_remove, r2_remove;
	unsigned long c2_rename, r2_rename;
	unsigned long c2_symlink, r2_symlink;
	unsigned long c2_link, r2_link;
	unsigned long c2_mkdir, r2_mkdir;
	unsigned long c2_rmdir, r2_rmdir;
	unsigned long c2_readdir, r2_readdir;
	unsigned long c2_statfs, r2_statfs;
	unsigned long c2_unknown, r2_unknown;
} nfs_v2_stat_t;

#define	print_uid3(p, e, l)		print_uint32(p, e, l, NULL)
#define	print_gid3(p, e, l)		print_uint32(p, e, l, NULL)
#define	print_size3(p, e, l)		print_uint64(p, e, l)
#define	print_offset3(p, e, l)		print_uint64(p, e, l)
#define	print_cookie3(p, e, l)		print_uint64(p, e, l)
#define	print_count3(p, e, l, c)	print_uint32(p, e, l, c)
#define	print_mode3(p, e, l)		print_uint32(p, e, l, NULL)
#define	print_nfspath3(p, e, l)		print_fn3(p, e, l)

int nfs_v3_print_call (u_int32_t op, u_int32_t xid, u_int32_t *p,
		u_int32_t payload_len, u_int32_t actual_len,
		nfs_v3_stat_t *stats);

u_int32_t *print_fh3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_sattr3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_fn3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_access3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_sattrguard3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_stable3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_mknoddata3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_diropargs3  (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_createhow3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_symlink3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_cookieverf3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_nfstime3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_cookieverf3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_createverf3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_writeverf3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_post_op_attr3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_post_op_attr3_p (u_int32_t *p, u_int32_t *e, int print,
		unsigned num);
u_int32_t *print_post_op_fh3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_pre_op_attr3 (u_int32_t *p, u_int32_t *e, int print);

u_int32_t *print_uint64 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_o_uint32 (u_int32_t *p, u_int32_t *e, int print, char *l);
u_int32_t *print_o_uint64 (u_int32_t *p, u_int32_t *e, int print, char *l);
u_int32_t *print_o_nfstime3 (u_int32_t *p, u_int32_t *e, int print,
		char *label);
u_int32_t *print_fattr3 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_fattr3_p (u_int32_t *p, u_int32_t *e, int print,
		unsigned num);
u_int32_t *print_wcc_data3 (u_int32_t *p, u_int32_t *e, int print);


#define	print_offset2(p, e, print)	print_uint32(p, e, print, NULL)
#define	print_count2(p, e, print, c)	print_uint32(p, e, print, c)

int nfs_v2_print_call (u_int32_t op, u_int32_t xid,
		u_int32_t *p, u_int32_t payload_len, u_int32_t actual_len,
		nfs_v2_stat_t *stats);

u_int32_t *print_fh2 (u_int32_t *p, u_int32_t *e, int print, char *fh_str);
u_int32_t *print_sattr2 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_fn2 (u_int32_t *p, u_int32_t *e, int print, char *fn_str);
u_int32_t *print_access2 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_uint64 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_uint32 (u_int32_t *p, u_int32_t *e, int print, u_int32_t *val);
u_int32_t *print_diropargs2  (u_int32_t *p, u_int32_t *e, int print,
		char *fh_str, char *fn_str);
u_int32_t *print_symlink2 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_nfstime2 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_cookie2 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_opaque (u_int32_t *p, u_int32_t *e, int print, int n_words);
u_int32_t *print_statfsokres2 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_diropokres2 (u_int32_t *p, u_int32_t *e, int print);
u_int32_t *print_fattr2 (u_int32_t *p, u_int32_t *e, int print);

extern	FILE	*OutFile;

extern	nfs_v3_stat_t	v3statsBlock;
extern	nfs_v2_stat_t	v2statsBlock;

extern	void	nfs_v2_stat_print (nfs_v2_stat_t *p, FILE *out);
extern	void	nfs_v2_stat_init (nfs_v2_stat_t *p);

extern	void	nfs_v3_stat_print (nfs_v3_stat_t *p, FILE *out);
extern	void	nfs_v3_stat_init (nfs_v3_stat_t *p);

extern	int	omitReaddirContents;

/*
 * end of nfsrecord.h
 */

