// Stages a movespeed modifier contributes to, applied in this order
/// Plain additive delay
#define MOVESPEED_STAGE_ADD 1
/// Additive delay whose sum cannot go below MOVESPEED_REDUCIBLE_CAP
#define MOVESPEED_STAGE_REDUCIBLE 2
/// Additive delay applied after the reducible sum
#define MOVESPEED_STAGE_POST 3
/// Factors multiplied onto the running delay
#define MOVESPEED_STAGE_MULT 4
/// Additive delay applied after everything else
#define MOVESPEED_STAGE_FINAL 5

#define MOVESPEED_REDUCIBLE_CAP -0.7

// Ids
#define MOVESPEED_ID_BUMP "bump"
#define MOVESPEED_ID_DROWSY "drowsy"
#define MOVESPEED_ID_PULL "pull"
#define MOVESPEED_ID_SPECIES "species"
#define MOVESPEED_ID_SHOES "shoes"
#define MOVESPEED_ID_LIMBS "limbs"
#define MOVESPEED_ID_PAIN "pain"
#define MOVESPEED_ID_HUNGER "hunger"
#define MOVESPEED_ID_UNIFORM "uniform"
#define MOVESPEED_ID_SUIT "suit"
#define MOVESPEED_ID_REAGENTS "reagents"
#define MOVESPEED_ID_COLD "cold"
#define MOVESPEED_ID_TEMPORARY "temporary_slowdown"
#define MOVESPEED_ID_SHIELD "shield"
#define MOVESPEED_ID_HELD_GUN "held_gun"
#define MOVESPEED_ID_SLOWED "slowed"
#define MOVESPEED_ID_SPECIES_SLOWED "species_slowed"
#define MOVESPEED_ID_CONFIG "config"
#define MOVESPEED_ID_ABILITY "ability"
#define MOVESPEED_ID_FRENZY "frenzy"
#define MOVESPEED_ID_AGILITY "agility"
#define MOVESPEED_ID_OWN_WEEDS "own_weeds"
#define MOVESPEED_ID_FAST_RESIN "fast_resin"
#define MOVESPEED_ID_CRAWLING "crawling"

/// Extra delay while crawling
#define CRAWLING_SLOWDOWN 6
