// Starting value for link lifetimes
#define NEIGHBOR_LIFETIME 5

#define ND_MOVING_AVERAGE_N 5

typedef struct {
    // Link quality percentage as integer from 0-100
    uint8_t linkQuality;

    bool responseSamples[ND_MOVING_AVERAGE_N];

    // How many replies left to fail until this link is considered broken
    uint8_t linkLifetime;

    bool recentlyReplied;
} NeighborInfo;