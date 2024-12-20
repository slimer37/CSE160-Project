// Starting value for link lifetimes
#define NEIGHBOR_LIFETIME 5

#define NEIGHBOR_TABLE_LENGTH PACKET_MAX_PAYLOAD_SIZE

typedef struct {
    // How many replies left to fail until this link is considered broken
    uint8_t linkLifetime;

    bool recentlyReplied;

} NeighborStats;

typedef struct {
    uint16_t dest;
    uint8_t cost;
    uint16_t nextHop;
} ProbableHop;