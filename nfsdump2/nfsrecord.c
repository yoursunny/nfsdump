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
 * $Id: nfsrecord.c,v 1.1 2009/12/03 14:11:40 ellard Exp ellard $
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <sys/param.h>
#include <sys/time.h>
#include <sys/socket.h>

#include <netinet/in.h>
#include <rpc/rpc.h>

#include <stdio.h>
#include <stdlib.h>
#include <pcap.h>
#include <assert.h>

#include "interface.h"

#include "ether.h"
#include "ip.h"
#include "udp.h"
#include "tcp.h"

#include "nfsrecord.h"

nfs_v3_stat_t	v3statsBlock;
nfs_v2_stat_t	v2statsBlock;

typedef	struct	_hash_t	{
	u_int32_t	rpcXID;
	u_int32_t	srcHost;		/* invoking host */
	u_int32_t	srcPort;		/* port on invoking host */
	u_int32_t	nfsVersion;
	u_int32_t	nfsProc;
	u_int32_t	call_time;	/* For aging. */
	struct _hash_t	*next;
} hash_t;

typedef	struct	{

	u_int32_t	secs, usecs;		/* timestamp */
	u_int32_t	srcHost, dstHost;	/* IP of src and dst hosts */
	u_int32_t	srcPort, dstPort;	/* ports... */
	u_int32_t	ipLen;
	char		ipProto;
} nfs_pkt_t;

void printPacketHeader(nfs_pkt_t *h, FILE *out)
{

	fprintf(out, "%u.%.6u", h->secs, h->usecs);

	fprintf(out, " %u.%u.%u.%u",
		0xff & (h->srcHost >> 24), 0xff & (h->srcHost >> 16),
		0xff & (h->srcHost >>  8), 0xff & (h->srcHost >>  0));
	
	fprintf(out, " -> %u.%u.%u.%u %d",
		0xff & (h->dstHost >> 24), 0xff & (h->dstHost >> 16),
		0xff & (h->dstHost >>  8), 0xff & (h->dstHost >>  0),
		h->dstPort);

	fprintf(out, " %.8x %.8x %5u", h->srcHost, h->dstHost, h->dstPort);

	fprintf(out, " %5u %c\n", h->ipLen, h->ipProto);

	return ;
}


void packetPrinter (u_char *user, struct pcap_pkthdr *h, u_char *pp);
int processPacket (struct pcap_pkthdr *h, u_char *pp, nfs_pkt_t *record);
int getEtherHeader (u_int32_t packet_len,
		u_char *bp, unsigned int *proto, u_int32_t *len);
int getIpHeader (struct ip *ip_b, unsigned int *proto, u_int32_t *len,
		u_int32_t *src, u_int32_t *dst);
int getTcpHeader (struct tcphdr *tcp_b);
int getUdpHeader (struct udphdr *udp_b);

void packetPrinter (u_char *user, struct pcap_pkthdr *h, u_char *pp)
{
	int rc;
	nfs_pkt_t record;

	rc = processPacket (h, pp, &record);

}

#define	MIN_ETHER_HDR_LEN	14		/* RFC 894 */
#define	MIN_IP_HDR_LEN		20		/* w/o options */
#define	MIN_TCP_HDR_LEN		20		/* w/o options */
#define	MIN_UDP_HDR_LEN		8

FILE	*OutFile	= NULL;

/*
 * Returns 1 if the packet is interesting, 0 if the packet was
 * uninteresting and should be discarded, and -1 if there was an
 * unexpected error while processing the packet.
 */

int processPacket (struct pcap_pkthdr *h,	/* Captured stuff */
		u_char *pp,			/* packet pointer */
		nfs_pkt_t *record
		)
{
	struct	ip	*ip_b		= NULL;
	struct	tcphdr	*tcp_b		= NULL;
	struct	udphdr	*udp_b		= NULL;
	u_int32_t	tot_len		= h->caplen;
	u_int32_t	consumed	= 0;
	u_int32_t	src_port	= 0;
	u_int32_t	dst_port	= 0;
	int	e_len, i_len, h_len;
	u_int32_t	rpc_len;
	unsigned int	length;
	u_int32_t srcHost, dstHost;
	unsigned int proto;

	if (OutFile == NULL) {
		OutFile = stdout;
	}

	/*
	 * It doesn't make any sense to run this program with a small
	 * caplen (aka snap length) because the important stuff will
	 * get lost.
	 *
	 * Too-short packets *should* never happen, since the min
	 * packet length is longer than this, but it's always better
	 * to be safe than to be sucker-punched by a bug elsewhere...
	 */

	if (tot_len <= (MIN_ETHER_HDR_LEN + MIN_IP_HDR_LEN + MIN_UDP_HDR_LEN)) {
		return (0);
	}

	e_len = getEtherHeader (tot_len, pp, &proto, &length);
	if (e_len <= 0) {
		return (-1);
	}
	consumed += e_len;

	/*
	 * If the type of the packet isn't IP, then we're not
	 * interested in it-- chuck it now.
	 *
	 * Note-- ordinarily by the time we get here, we've already
	 * filtered out the packets using a pattern in the pcap
	 * library, so this shouldn't happen (unless we are running
	 * off a capture of the entire traffic on the wire).
	 */

	if (proto != 0x0800) {
		return (0);
	}

	ip_b = (struct ip *) (pp + e_len);

	i_len = getIpHeader (ip_b, &proto, &length, &srcHost, &dstHost);
	if (i_len <= 0) {
		return (-2);
	}

	record->ipLen = length;

	consumed += i_len;

	/*
	 * Truncated packet-- what's up with that?  At this point,
	 * this can only happen if the packet is very short and the IP
	 * options are very long.  Still, must be cautious...
	 */

	if (consumed >= tot_len) {
		return (0);
	}

	if (proto == IPPROTO_TCP) {
		if (consumed + MIN_TCP_HDR_LEN >= tot_len) {
/* 			fprintf (OutFile, "XX 1: TCP pkt too short.\n"); */
			return (0);
		}

		tcp_b = (struct tcphdr *) (pp + consumed);
		h_len = getTcpHeader (tcp_b);
		if (h_len <= 0) {
/* 			fprintf (OutFile, "XX 2: TCP header error\n"); */
			return (-3);
		}

		consumed += h_len;
		if (consumed >= tot_len) {
/* 			fprintf (OutFile, */
/* 			"XX 3: Dropped (consumed = %d, tot_len = %d)\n", */
/* 					consumed, tot_len); */
			return (0);
		}

		h_len += sizeof (u_int32_t);

		src_port = ntohs (tcp_b->th_sport);
		dst_port = ntohs (tcp_b->th_dport);
		record->ipProto = 'T';

	}
	else if (proto == IPPROTO_UDP) {
		if (consumed + MIN_UDP_HDR_LEN >= tot_len) {
			return (0);
		}

		udp_b = (struct udphdr *) (pp + consumed);
		h_len = getUdpHeader (udp_b);
		if (h_len <= 0) {
			return (-4);
		}

		consumed += h_len;
		if (consumed >= tot_len) {
			return (0);
		}

		src_port = ntohs (udp_b->uh_sport);
		dst_port = ntohs (udp_b->uh_dport);

		rpc_len = tot_len - consumed;
		record->ipProto = 'U';

	}
	else {

		/* 
		 * If it's not TCP or UPD, then no matter what it is,
		 * we don't care about it, so just ignore it.
		 */

/* 		fprintf (OutFile, "XX 5: Not TCP or UDP.\n"); */
		return (0);
	}

	/*
	 * If we get to this point, there's a good chance this packet
	 * contains something interesting, so we start filling in the
	 * fields of the record immediately.
	 */

	record->secs	= h->ts.tv_sec;
	record->usecs	= h->ts.tv_usec;
	record->srcHost	= srcHost;
	record->dstHost	= dstHost;
	record->srcPort	= src_port;
	record->dstPort	= dst_port;
	record->ipLen   = length;

	printPacketHeader(record, stdout);

	return 0;

}

/*
 * bp is assumed to point to the start of an ethernet header.  If
 * sanity checks pass, fills in eth_b with the contents of the header,
 * returns the number of bytes consumed by the header (which can
 * depend on the precise ethernet protocol), and fills in *len with
 * the number of bytes in the REST of the packet (not counting the
 * header).
 */

#define	OLD_ETHERMTU	1500	/* somewhat archaic, because jumbo frames */

int getEtherHeader (u_int32_t packet_len,
		u_char *bp, unsigned int *proto, unsigned int *len)
{
	unsigned int length = (bp [12] << 8) | bp [13];

	/*
	 * Look for either 802.3 or RFC 894:
	 *
	 * if "length" <= OLD_ETHERMTU).  Note that we let the pcap
	 * library make the decision for jumbo frames-- pcap has
	 * already calculated the apparent packet length, and if it
	 * agrees with the 802.3 length field, and the next few fields
	 * make sense according to the 802.3 spec, then we assume that
	 * this is an 802.3 packet.  This is not riskless, but I have
	 * no better way to tell the difference.
	 */

	if ((length <= ETHERMTU) || 
			(length == (packet_len - 22) &&	/* jumbo? */
			(bp [14] == 0xAA) &&		/* DSAP */
			(bp [15] == 0xAA) &&		/* SSAP */
			(bp [16] == 0x03))) {		/* CNTL */
		*proto = (bp [20] << 8) | bp [21];
		*len = length;
		return (22);
	}
	else {
		*len = packet_len - 14;
		*proto = length;
		return (14);
	}
}

/*
 * ip_b is assumed to point to the start of an IP header.  If sanity
 * checks pass, returns the number of bytes consumed by the header
 * (including options).
 */

int getIpHeader (struct ip *ip_b, unsigned int *proto, unsigned int *len,
		u_int32_t *src, u_int32_t *dst)
{
	u_int32_t *ip = (u_int32_t *) ip_b;
	u_int32_t off;

	/*
	 * If it's not IPv4, then we're completely lost.
	 */

	if (IP_V (ip_b) != 4) {
		return (-1);
	}

	/*
	 * If this isn't fragment zero of an higher-level "packet",
	 * then it's not something that we're interested in, so dump
	 * it.
	 */

	off = ntohs(ip_b->ip_off);
	if ((off & 0x1fff) != 0) {
		return (0);
	}

	*proto = ip_b->ip_p;
	*len = ntohs (ip_b->ip_len);
	*src = ntohl (ip [3]);
	*dst = ntohl (ip [4]);

	return (IP_HL (ip_b) * 4);
}

/*
 * Right now, all we want out of the tcp header is the length,
 * so we can skip over it.  If all goes well, we pluck out the
 * ports elsewhere.
 */

int getTcpHeader (struct tcphdr *tcp_b)
{

	return (4 * TH_OFF (tcp_b));
}

int getUdpHeader (struct udphdr *udp_b)
{

	return (8);
}

/*
 * end of nfsrecord.c
 */
