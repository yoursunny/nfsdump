#include "tcp_reassembly.h"
#include <assert.h>
#include <stdlib.h>

#define	HASHSIZE	3301
#define	HASH(nextSeq,srcHost,srcPort,dstHost,dstPort) \
	(((nextSeq) % HASHSIZE + (srcHost) % HASHSIZE + (dstHost) % HASHSIZE + \
	  (((srcPort) << 16) | (dstPort)) % HASHSIZE) % HASHSIZE)

static tcp_fragment_t *tcpHashTable [HASHSIZE];
int	tcpHashElemCnt	= 0;

#define	MAX_AGE		30

tcp_fragment_t *tcpLookup (uint32_t now, uint32_t nextSeq,
		uint32_t srcHost, uint16_t srcPort, uint32_t dstHost, uint16_t dstPort)
{
	uint32_t hashval;
	tcp_fragment_t *curr, **prev_p;

	hashval = HASH (nextSeq, srcHost, srcPort, dstHost, dstPort);
	prev_p = &tcpHashTable [hashval];
	for (curr = tcpHashTable [hashval]; curr != NULL; curr = curr->next) {
		if ((curr->nextSeq == nextSeq) &&
				(curr->srcHost == srcHost) && (curr->srcPort == srcPort) &&
				(curr->dstHost == dstHost) && (curr->dstPort == dstPort)) {
			*prev_p = curr->next;
			tcpHashElemCnt--;
			return (curr);
		}
		prev_p = &curr->next;
	}


	return (NULL);
}

int tcpInsert (uint32_t now, uint32_t nextSeq,
		uint32_t srcHost, uint16_t srcPort, uint32_t dstHost, uint16_t dstPort,
		uint8_t* buffer, uint32_t rpc_len, uint32_t firstSeq)
{
	static int CullIndex = 0;
	uint32_t then;
	uint32_t hashval = HASH (nextSeq, srcHost, srcPort, dstHost, dstPort);
	tcp_fragment_t *new = (tcp_fragment_t *) malloc (sizeof (tcp_fragment_t));
	tcp_fragment_t *curr, *next, *old;

	new->srcHost = srcHost;
	new->srcPort = srcPort;
	new->dstHost = dstHost;
	new->dstPort = dstPort;
	new->nextSeq = nextSeq;
	new->buffer = buffer;
	new->rpc_len = rpc_len;
	new->firstSeq = firstSeq;
	new->time = now;

	new->next = tcpHashTable [hashval];
	tcpHashTable [hashval] = new;

	tcpHashElemCnt++;

	/*
	 * HACK ALERT!
	 *
	 * Due to dropped packets, some requests never get responses. 
	 * This causes the table to leak.  To make sure that
	 * eventually all the garbage has a chance to be collected,
	 * every time we do a lookup, we pick a hash bucket to cull. 
	 * In order to prevent garbage from hiding, we cull a
	 * different bucket each time, working our way around the
	 * whole table.
	 */

	then = now - MAX_AGE;
	for (curr = tcpHashTable [CullIndex]; curr != NULL; curr = next) {
		next = curr->next;

		if (curr->time < then) {
			old = tcpLookup (now, curr->nextSeq, curr->srcHost,
					curr->srcPort, curr->dstHost, curr->dstPort);
			assert (old != NULL);
			if (old->buffer != 0)
				free (old->buffer);
			free (old);
		}
	}
	CullIndex = (CullIndex + 1) % HASHSIZE;

	return (0);
}

