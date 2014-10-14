#include <stdint.h>

typedef	struct	_tcp_fragment_t	{
	uint32_t	srcHost;
	uint32_t	dstHost;
	uint16_t	srcPort;
	uint16_t	dstPort;
	uint32_t	nextSeq;	/* next sequence number */
	uint8_t	*buffer;	/* the RPC packet without rpc_len field, pre-allocated */
	uint32_t	rpc_len;	/* expected length of RPC packet */
	uint32_t	firstSeq;	/* sequence number of start of RPC packet (after rpc_len field) */
	uint32_t	time;	/* for aging */
	struct _tcp_fragment_t	*next;
} tcp_fragment_t;

tcp_fragment_t *tcpLookup (uint32_t now, uint32_t nextSeq,
		uint32_t srcHost, uint16_t srcPort, uint32_t dstHost, uint16_t dstPort);

int tcpInsert (uint32_t now, uint32_t nextSeq,
		uint32_t srcHost, uint16_t srcPort, uint32_t dstHost, uint16_t dstPort,
		uint8_t* buffer, uint32_t rpc_len, uint32_t firstSeq);

