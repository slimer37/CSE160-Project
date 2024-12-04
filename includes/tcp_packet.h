#ifndef TCP_PACKET_H
#define TCP_PACKET_H

#define ATTEMPT_CONNECTION_TIME 500

enum {
	TCP_HEADER_LENGTH = 13,
	TCP_MAX_PAYLOAD_SIZE = PACKET_MAX_PAYLOAD_SIZE - TCP_HEADER_LENGTH
};

typedef nx_struct tcp_pack {
    // nx_uint8_t = nx_socket_port_t;
    nx_uint8_t sourcePort;
    nx_uint8_t destPort;
    nx_uint8_t flags;
    nx_uint32_t sequenceNum;
    nx_uint32_t acknowledgement;
    nx_uint16_t advertisedWindow;
    nx_uint8_t payload[TCP_MAX_PAYLOAD_SIZE];
} tcp_pack;

#endif