#ifndef TCP_PACKET_H
#define TCP_PACKET_H

#define ATTEMPT_CONNECTION_TIME 1000

enum {
	TCP_HEADER_LENGTH = 13,
	TCP_MAX_PAYLOAD_SIZE = PACKET_MAX_PAYLOAD_SIZE - TCP_HEADER_LENGTH
};

enum tcpFlags {
    ACK = 4,
    SYN = 2,
    FIN = 1
};

typedef nx_struct tcp_pack {
    // nx_uint8_t = nx_socket_port_t;
    nx_uint8_t sourcePort;
    nx_uint8_t destPort;
    nx_uint8_t flags;
    nx_uint32_t sequenceNum;
    nx_uint32_t acknowledgement;
    nx_uint8_t advertisedWindow;
    nx_uint8_t length;
    nx_uint8_t payload[TCP_MAX_PAYLOAD_SIZE];
} tcp_pack;

char* getTcpFlagsAsString(nx_uint8_t flags) {
    char flagLabel[32] = "";
            
    if (flags & SYN) strcat(flagLabel, "SYN+");
    if (flags & ACK) strcat(flagLabel, "ACK+");
    if (flags & FIN) strcat(flagLabel, "FIN+");

    if (strlen(flagLabel) > 0) {
        // Remove last '+'
        flagLabel[strlen(flagLabel) - 1] = '\0';
    }

    if (flags == 0) strcat(flagLabel, "None");
    else if (strlen(flagLabel) == 0) strcat(flagLabel, "Unknown");

    return flagLabel;
}

#endif