/// Width and height of one spatial grid cell, in tiles
#define SPATIAL_GRID_CELLSIZE 16

/// The mob has a client, tracked as a player
#define SPATIAL_GRID_TRACK_CLIENT (1<<0)
/// The mob is an AI-piloted hostile with no client
#define SPATIAL_GRID_TRACK_NPC (1<<1)
/// The mob is an AI-piloted human, kept apart from the hostile NPC list
#define SPATIAL_GRID_TRACK_HUMAN_AI (1<<2)
#define SPATIAL_GRID_TRACK_ALL (SPATIAL_GRID_TRACK_CLIENT|SPATIAL_GRID_TRACK_NPC|SPATIAL_GRID_TRACK_HUMAN_AI)

/// 1-based cell column or row holding a tile coordinate
#define SPATIAL_GRID_CELL_INDEX(coord) (floor(((coord) - 1) / SPATIAL_GRID_CELLSIZE) + 1)

/// Leave observers out of the result
#define SPATIAL_GRID_EXCLUDE_OBSERVER (1<<0)
/// Return mobs instead of clients
#define SPATIAL_GRID_SCAN_MOBS (1<<1)
/// Also return AI-piloted hostile mobs, always as mobs
#define SPATIAL_GRID_INCLUDE_NPC_HOSTILES (1<<2)
