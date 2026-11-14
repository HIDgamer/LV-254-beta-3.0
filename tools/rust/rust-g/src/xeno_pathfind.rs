//! Native A* grid pathfinder for NPC Xenomorph AI movement (UCFSS13-specific).
//!
//! Ported unchanged from the standalone `tools/rust/xeno_pathfind/` crate -
//! see that crate's own doc comment/tests for the full design rationale and
//! `cargo test` coverage of the algorithm itself. That standalone DLL
//! reproducibly failed `call_ext()` with "undefined symbol" in production
//! despite being architecture/symbol/dependency-correct, while calls against
//! rust-g's own functions succeeded every time in the same process - so this
//! is that same algorithm merged into rust-g's own build instead, exposed
//! through the shared `byond_fn!`/`catch_panic` conventions every other
//! module here uses, rather than continuing to chase why a second library
//! wouldn't load.
//!
//! Two solvers live here:
//! - `xeno_pathfind` (bounded): BYOND supplies a bounded local grid
//!   (blocked/open per tile) around the chase area per call.
//! - `xeno_pathfind_route` (persistent): BYOND bulk-loads each z-level's
//!   walkability once at round start (`xeno_pathfind_init_z`), then pushes
//!   only deltas as turfs/doors change (`xeno_pathfind_update`). Routes are
//!   solved against this retained full-map grid - true long-range routing
//!   around whole buildings, plus a decaying "threat" cost layer
//!   (`xeno_pathfind_threat`/`xeno_pathfind_decay`) that bends paths away
//!   from tiles where hive members recently died.

use crate::byond::catch_panic;
use std::cmp::Ordering;
use std::collections::{BinaryHeap, HashMap};
use std::sync::{LazyLock, Mutex};

#[derive(Copy, Clone, Eq, PartialEq)]
struct OpenNode {
    priority: i32,
    x: i32,
    y: i32,
}

// BinaryHeap is a max-heap; reverse priority ordering to get a min-heap.
impl Ord for OpenNode {
    fn cmp(&self, other: &Self) -> Ordering {
        other.priority.cmp(&self.priority)
    }
}

impl PartialOrd for OpenNode {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

/// Manhattan distance heuristic - movement is 4-directional only (see
/// DIRECTIONS), so there's no diagonal cost component to approximate.
fn heuristic(x1: i32, y1: i32, x2: i32, y2: i32) -> i32 {
    let dx = (x1 - x2).abs();
    let dy = (y1 - y2).abs();
    10 * (dx + dy)
}

/// Cardinal moves only - deliberately no diagonals. Diagonal steps produced
/// the "conga line" effect when several xenos converged on the same target
/// (their near-identical diagonal shortcuts all funneled through the same
/// handful of corner tiles) and looked unnatural for a creature that isn't
/// actually cutting corners. Cardinal-only paths are longer in the open but
/// match BYOND's own cardinal movement more predictably.
const DIRECTIONS: [(i32, i32, i32); 4] = [(1, 0, 10), (-1, 0, 10), (0, 1, 10), (0, -1, 10)];

/// Cardinals plus diagonals, for profiles that allow them. The third field is
/// the step cost scale in tenths: 10 for a cardinal step, 14 for a diagonal.
const MOVES_WITH_DIAGONALS: [(i32, i32, i32); 8] = [
    (1, 0, 10),
    (-1, 0, 10),
    (0, 1, 10),
    (0, -1, 10),
    (1, 1, 14),
    (1, -1, 14),
    (-1, 1, 14),
    (-1, -1, 14),
];

/// A* over a bounded width x height grid. `blocked[y*width+x]` is true if
/// that tile can't be entered. Returns the path from start to end inclusive,
/// or None if unreachable. Cardinal movement only (see DIRECTIONS) - no
/// diagonal steps, so there's nothing to reject for corner-cutting.
fn find_path(
    width: i32,
    height: i32,
    start: (i32, i32),
    end: (i32, i32),
    blocked: &[bool],
) -> Option<Vec<(i32, i32)>> {
    if width <= 0 || height <= 0 {
        return None;
    }
    let idx = |x: i32, y: i32| -> usize { (y * width + x) as usize };
    let in_bounds = |x: i32, y: i32| -> bool { x >= 0 && y >= 0 && x < width && y < height };

    if !in_bounds(start.0, start.1) || !in_bounds(end.0, end.1) {
        return None;
    }
    if blocked.len() != (width * height) as usize {
        return None;
    }
    if blocked[idx(end.0, end.1)] {
        return None;
    }
    if start == end {
        return Some(vec![start]);
    }

    let cell_count = (width * height) as usize;
    let mut g_score = vec![i32::MAX; cell_count];
    let mut came_from = vec![-1i32; cell_count];
    let mut closed = vec![false; cell_count];

    g_score[idx(start.0, start.1)] = 0;

    let mut open = BinaryHeap::new();
    open.push(OpenNode {
        priority: heuristic(start.0, start.1, end.0, end.1),
        x: start.0,
        y: start.1,
    });

    // Bounds worst-case cost - this is meant for bounded local chase-area
    // pathing (the caller passes a small grid), not full-map routing.
    let max_iterations = cell_count.saturating_mul(4);
    let mut iterations = 0usize;

    while let Some(current) = open.pop() {
        iterations += 1;
        if iterations > max_iterations {
            return None;
        }

        let cur_idx = idx(current.x, current.y);
        if closed[cur_idx] {
            continue;
        }
        if current.x == end.0 && current.y == end.1 {
            let mut path = Vec::new();
            let mut trace = cur_idx as i32;
            while trace != -1 {
                let tx = trace % width;
                let ty = trace / width;
                path.push((tx, ty));
                trace = came_from[trace as usize];
            }
            path.reverse();
            return Some(path);
        }
        closed[cur_idx] = true;

        for (dx, dy, step_cost) in DIRECTIONS.iter() {
            let nx = current.x + dx;
            let ny = current.y + dy;
            if !in_bounds(nx, ny) {
                continue;
            }
            let n_idx = idx(nx, ny);
            if closed[n_idx] || blocked[n_idx] {
                continue;
            }
            let tentative = g_score[cur_idx].saturating_add(*step_cost);
            if tentative < g_score[n_idx] {
                g_score[n_idx] = tentative;
                came_from[n_idx] = cur_idx as i32;
                let priority = tentative + heuristic(nx, ny, end.0, end.1);
                open.push(OpenNode {
                    priority,
                    x: nx,
                    y: ny,
                });
            }
        }
    }

    None
}

// FFI entry point. `grid_desc` is "width,height,start_x,start_y,end_x,end_y"
// (grid-local coordinates, 0-indexed). `blocked_map` is a width*height
// length string of '0'/'1' characters, row-major. Returns a ';'-separated
// list of "x,y" grid-local coordinates from start to end inclusive, or an
// empty string if no path exists or the input was malformed.
// catch_panic became generic over the closure's return type in rust_g 7.0.0 (previously fixed
// to Result<String, Error>), so closures here return the plain value directly instead of Ok(..)
// wrapping it - matches the new call convention rust-g's own iconforge.rs uses.
byond_fn!(fn xeno_pathfind(grid_desc, blocked_map) {
    Some(catch_panic(|| pathfind_impl(grid_desc, blocked_map)).unwrap_or_default())
});

fn pathfind_impl(desc: &str, blocked_str: &str) -> String {
    let parts: Vec<i32> = desc
        .split(',')
        .filter_map(|s| s.trim().parse::<i32>().ok())
        .collect();
    if parts.len() != 6 {
        return String::new();
    }
    let (width, height, sx, sy, ex, ey) = (
        parts[0], parts[1], parts[2], parts[3], parts[4], parts[5],
    );

    if width <= 0 || height <= 0 || (width as i64 * height as i64) as usize != blocked_str.len() {
        return String::new();
    }

    let blocked: Vec<bool> = blocked_str.bytes().map(|b| b == b'1').collect();

    match find_path(width, height, (sx, sy), (ex, ey), &blocked) {
        Some(path) => {
            let encoded: Vec<String> = path.iter().map(|(x, y)| format!("{},{}", x, y)).collect();
            encoded.join(";")
        }
        None => String::new(),
    }
}

// ---------------------------------------------------------------------------
// Persistent full-map grid
// ---------------------------------------------------------------------------

/// Cell walkability codes as sent by BYOND in init/update payloads.
const CELL_OPEN: u8 = b'0';
const CELL_BLOCKED: u8 = b'1';
const CELL_DOOR: u8 = b'2';
const CELL_OBSTACLE: u8 = b'3';
/// A tile holding an ON_BORDER structure (platform, most barricades, flipped
/// tables) - directional/conditional blocking a full-tile cost can't
/// represent exactly, so this is a flat "usually cheap to cross, mildly worth
/// avoiding when a clearly better route exists" tier rather than an attempt
/// at precise direction-aware costing. Previously these tiles were skipped
/// entirely during grid classification (turf_cell_code(), DM side) and read
/// as plain CELL_OPEN - completely invisible to route planning even though
/// the real per-step movement can legitimately block one approach direction
/// and allow another, which is what let routes get planned straight through/
/// across clusters of them with no accounting for the real crossing cost.
const CELL_BORDER: u8 = b'4';
/// A door the walker cannot just open (locked, welded, electrified, trapped).
/// Priced like an ordinary door for the xeno profile (xenos force it open),
/// so a grid carrying these cells routes xenos exactly as before.
const CELL_SECURE_DOOR: u8 = b'5';

/// Base step cost of entering an open tile (matches the original solver's 10).
const STEP_COST_OPEN: i32 = 10;
/// Step cost of entering a closed-door tile - passable, so a door is always a
/// viable route the AI will open/smash on arrival, but expensive enough that
/// an actually-open corridor of similar length wins.
const STEP_COST_DOOR: i32 = 80;
/// Step cost of a tile holding a dense breakable structure (window, girder) -
/// passable in the same force-on-arrival sense as a door, but priced well
/// above one: without this, a window tile read as OPEN (windows are objects,
/// not turfs) and routes preferred smashing through glass over using the
/// actual door a few tiles away.
const STEP_COST_OBSTACLE: i32 = 200;
/// Step cost of a tile holding an ON_BORDER structure - between open and a
/// door: most of these (platforms especially, CLIMB_DELAY_SHORT) are a quick
/// vault in practice, so they shouldn't be priced anywhere near a real
/// obstacle, but they're also not literally free the way a plain floor tile
/// is - a route with a genuinely clear alternative should still take it.
const STEP_COST_BORDER: i32 = 40;

/// Route cost profile ids, the optional sixth field of a route descriptor.
const PROFILE_XENO: i32 = 0;
const PROFILE_HUMAN: i32 = 1;

/// Per-walker cost table. A route is solved against one profile; the grid
/// itself is shared by every profile.
#[derive(Copy, Clone)]
struct CostProfile {
    open: i32,
    door: i32,
    /// None = cannot be crossed at all.
    secure_door: Option<i32>,
    /// None = cannot be crossed at all.
    obstacle: Option<i32>,
    border: i32,
    /// Diagonal steps allowed (only around clean corners, never cutting past a door or obstacle).
    diagonals: bool,
    /// Adds the hive-death threat layer to step costs.
    uses_threat: bool,
    /// Adds the contact-danger layer to step costs.
    uses_danger: bool,
}

const XENO_PROFILE: CostProfile = CostProfile {
    open: STEP_COST_OPEN,
    door: STEP_COST_DOOR,
    secure_door: Some(STEP_COST_DOOR),
    obstacle: Some(STEP_COST_OBSTACLE),
    border: STEP_COST_BORDER,
    diagonals: false,
    uses_threat: true,
    uses_danger: false,
};

/// Humans open doors, vault low cover, never break windows, and treat locked or
/// trapped doors as a last resort. They steer around contact danger, not hive deaths.
const HUMAN_PROFILE: CostProfile = CostProfile {
    open: STEP_COST_OPEN,
    door: 25,
    secure_door: Some(600),
    obstacle: None,
    border: 30,
    diagonals: true,
    uses_threat: false,
    uses_danger: true,
};

fn profile_for(id: i32) -> Option<&'static CostProfile> {
    match id {
        PROFILE_XENO => Some(&XENO_PROFILE),
        PROFILE_HUMAN => Some(&HUMAN_PROFILE),
        _ => None,
    }
}

/// One z-level's retained state. `base[(y-1)*width + (x-1)]` holds the cell
/// code for world tile (x, y) - BYOND turf coordinates are 1-based.
struct ZGrid {
    width: i32,
    height: i32,
    base: Vec<u8>,
    threat: Vec<u16>,
    danger: Vec<u16>,
}

impl ZGrid {
    fn idx(&self, x: i32, y: i32) -> Option<usize> {
        if x < 1 || y < 1 || x > self.width || y > self.height {
            return None;
        }
        Some(((y - 1) * self.width + (x - 1)) as usize)
    }

    /// Cost of stepping onto (x, y) for a profile; None if impassable/out of bounds.
    fn step_cost(&self, x: i32, y: i32, profile: &CostProfile) -> Option<i32> {
        let i = self.idx(x, y)?;
        let base = match self.base[i] {
            CELL_OPEN => profile.open,
            CELL_DOOR => profile.door,
            CELL_SECURE_DOOR => profile.secure_door?,
            CELL_OBSTACLE => profile.obstacle?,
            CELL_BORDER => profile.border,
            _ => return None,
        };
        let mut cost = base;
        if profile.uses_threat {
            cost += self.threat[i] as i32;
        }
        if profile.uses_danger {
            cost += self.danger[i] as i32;
        }
        Some(cost)
    }

    /// True if (x, y) is plain floor or a low border structure, safe to brush past diagonally.
    fn is_clean_corner(&self, x: i32, y: i32, profile: &CostProfile) -> bool {
        match self.idx(x, y) {
            Some(i) => {
                matches!(self.base[i], CELL_OPEN | CELL_BORDER)
                    && self.step_cost(x, y, profile).is_some()
            }
            None => false,
        }
    }
}

static MAP: LazyLock<Mutex<HashMap<i32, ZGrid>>> = LazyLock::new(|| Mutex::new(HashMap::new()));

/// Locks the retained map, recovering from a poisoned mutex (a prior panic
/// while holding the lock) instead of propagating a panic on every later
/// call - the grid data is plain-old-data, safe to keep using.
fn map_lock() -> std::sync::MutexGuard<'static, HashMap<i32, ZGrid>> {
    MAP.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Octile distance for profiles that may step diagonally (10 per cardinal, 14 per
/// diagonal), a lower bound because no step ever costs less than that.
fn heuristic_octile(x1: i32, y1: i32, x2: i32, y2: i32) -> i32 {
    let dx = (x1 - x2).abs();
    let dy = (y1 - y2).abs();
    10 * dx.max(dy) + 4 * dx.min(dy)
}

/// Weighted A* over one retained z-grid, world (1-based) coordinates in and
/// out. Same iteration cap discipline as `find_path`. The xeno profile keeps
/// cardinal-only movement; the human profile also steps diagonally around
/// clean corners. Threat/danger/door costs only ever raise a step's cost above
/// the heuristic's per-tile assumption, so both heuristics stay admissible.
fn route_on_grid(
    grid: &ZGrid,
    start: (i32, i32),
    end: (i32, i32),
    profile: &CostProfile,
) -> Option<Vec<(i32, i32)>> {
    let start_idx = grid.idx(start.0, start.1)?;
    grid.idx(end.0, end.1)?;
    grid.step_cost(end.0, end.1, profile)?;
    if start == end {
        return Some(vec![start]);
    }

    let estimate = |x: i32, y: i32| -> i32 {
        if profile.diagonals {
            heuristic_octile(x, y, end.0, end.1)
        } else {
            heuristic(x, y, end.0, end.1)
        }
    };

    let cell_count = (grid.width * grid.height) as usize;
    let mut g_score = vec![i32::MAX; cell_count];
    let mut came_from = vec![-1i32; cell_count];
    let mut closed = vec![false; cell_count];

    g_score[start_idx] = 0;

    let mut open = BinaryHeap::new();
    open.push(OpenNode {
        priority: estimate(start.0, start.1),
        x: start.0,
        y: start.1,
    });

    let max_iterations = cell_count.saturating_mul(4);
    let mut iterations = 0usize;

    while let Some(current) = open.pop() {
        iterations += 1;
        if iterations > max_iterations {
            return None;
        }

        let cur_idx = grid.idx(current.x, current.y)?;
        if closed[cur_idx] {
            continue;
        }
        if current.x == end.0 && current.y == end.1 {
            let mut path = Vec::new();
            let mut trace = cur_idx as i32;
            while trace != -1 {
                let tx = trace % grid.width + 1;
                let ty = trace / grid.width + 1;
                path.push((tx, ty));
                trace = came_from[trace as usize];
            }
            path.reverse();
            return Some(path);
        }
        closed[cur_idx] = true;

        let moves: &[(i32, i32, i32)] = if profile.diagonals {
            &MOVES_WITH_DIAGONALS
        } else {
            &DIRECTIONS
        };
        for (dx, dy, step_scale) in moves.iter() {
            let nx = current.x + dx;
            let ny = current.y + dy;
            let Some(n_idx) = grid.idx(nx, ny) else {
                continue;
            };
            if closed[n_idx] {
                continue;
            }
            let Some(mut step_cost) = grid.step_cost(nx, ny, profile) else {
                continue;
            };
            if *dx != 0 && *dy != 0 {
                if !grid.is_clean_corner(current.x + dx, current.y, profile)
                    || !grid.is_clean_corner(current.x, current.y + dy, profile)
                {
                    continue;
                }
                step_cost = step_cost * step_scale / 10;
            }
            let tentative = g_score[cur_idx].saturating_add(step_cost);
            if tentative < g_score[n_idx] {
                g_score[n_idx] = tentative;
                came_from[n_idx] = cur_idx as i32;
                open.push(OpenNode {
                    priority: tentative + estimate(nx, ny),
                    x: nx,
                    y: ny,
                });
            }
        }
    }

    None
}

fn parse_ints(s: &str) -> Vec<i32> {
    s.split(',')
        .filter_map(|p| p.trim().parse::<i32>().ok())
        .collect()
}

// Bulk-loads one z-level's walkability. `z_desc` is "z,width,height";
// `packed_cells` is width*height chars of '0' (open) / '1' (blocked) /
// '2' (closed door) / '3' (breakable obstacle) / '4' (ON_BORDER structure),
// row-major from world tile (1,1). Returns "ok" on success, "" on malformed
// input.
byond_fn!(fn xeno_pathfind_init_z(z_desc, packed_cells) {
    Some(catch_panic(|| init_z_impl(z_desc, packed_cells)).unwrap_or_default())
});

fn init_z_impl(desc: &str, cells: &str) -> String {
    let parts = parse_ints(desc);
    if parts.len() != 3 {
        return String::new();
    }
    let (z, width, height) = (parts[0], parts[1], parts[2]);
    if width <= 0 || height <= 0 || (width as i64 * height as i64) as usize != cells.len() {
        return String::new();
    }
    if cells.bytes().any(|b| {
        b != CELL_OPEN
            && b != CELL_BLOCKED
            && b != CELL_DOOR
            && b != CELL_OBSTACLE
            && b != CELL_BORDER
            && b != CELL_SECURE_DOOR
    }) {
        return String::new();
    }

    let cell_count = (width * height) as usize;
    let grid = ZGrid {
        width,
        height,
        base: cells.as_bytes().to_vec(),
        threat: vec![0; cell_count],
        danger: vec![0; cell_count],
    };
    map_lock().insert(z, grid);
    "ok".to_string()
}

// Applies batched cell deltas: "z,x,y,c" entries separated by ';', where c
// is a cell code (0/1/2/3/4). Unknown z or out-of-bounds entries are skipped
// (the delta pipeline must never poison the whole batch). Returns "ok".
byond_fn!(fn xeno_pathfind_update(deltas) {
    Some(catch_panic(|| update_impl(deltas)).unwrap_or_default())
});

fn update_impl(payload: &str) -> String {
    let mut map = map_lock();
    for entry in payload.split(';') {
        let parts = parse_ints(entry);
        if parts.len() != 4 {
            continue;
        }
        let (z, x, y, code) = (parts[0], parts[1], parts[2], parts[3]);
        let code = match code {
            0 => CELL_OPEN,
            1 => CELL_BLOCKED,
            2 => CELL_DOOR,
            3 => CELL_OBSTACLE,
            4 => CELL_BORDER,
            5 => CELL_SECURE_DOOR,
            _ => continue,
        };
        let Some(grid) = map.get_mut(&z) else {
            continue;
        };
        if let Some(i) = grid.idx(x, y) {
            grid.base[i] = code;
        }
    }
    "ok".to_string()
}

// Solves a route on the retained grid. `route_desc` is "z,sx,sy,ex,ey" or
// "z,sx,sy,ex,ey,profile" (world 1-based coordinates; profile 0 = xeno, the
// default when omitted, 1 = human). Returns a ';'-separated "x,y" path from
// start to end inclusive, or "" if the z isn't loaded, the profile is
// unknown, input is malformed, or no route exists.
byond_fn!(fn xeno_pathfind_route(route_desc) {
    Some(catch_panic(|| route_impl(route_desc)).unwrap_or_default())
});

fn route_impl(desc: &str) -> String {
    let parts = parse_ints(desc);
    if parts.len() != 5 && parts.len() != 6 {
        return String::new();
    }
    let (z, sx, sy, ex, ey) = (parts[0], parts[1], parts[2], parts[3], parts[4]);
    let profile_id = if parts.len() == 6 { parts[5] } else { PROFILE_XENO };
    let Some(profile) = profile_for(profile_id) else {
        return String::new();
    };

    let map = map_lock();
    let Some(grid) = map.get(&z) else {
        return String::new();
    };
    match route_on_grid(grid, (sx, sy), (ex, ey), profile) {
        Some(path) => {
            let encoded: Vec<String> = path.iter().map(|(x, y)| format!("{},{}", x, y)).collect();
            encoded.join(";")
        }
        None => String::new(),
    }
}

// Adds threat at "z,x,y,amount" with linear falloff over a Chebyshev
// radius of 2 (amount, then 1/2, then 1/3 of it). Saturating - repeated
// deaths stack up to u16::MAX. Returns "ok" ("" on malformed input).
byond_fn!(fn xeno_pathfind_threat(threat_desc) {
    Some(catch_panic(|| threat_impl(threat_desc)).unwrap_or_default())
});

fn threat_impl(desc: &str) -> String {
    let parts = parse_ints(desc);
    if parts.len() != 4 {
        return String::new();
    }
    let (z, x, y, amount) = (parts[0], parts[1], parts[2], parts[3].max(0) as u16);

    let mut map = map_lock();
    let Some(grid) = map.get_mut(&z) else {
        return String::new();
    };
    for dy in -2i32..=2 {
        for dx in -2i32..=2 {
            let dist = dx.abs().max(dy.abs()) as u16;
            let add = amount / (dist + 1);
            if add == 0 {
                continue;
            }
            if let Some(i) = grid.idx(x + dx, y + dy) {
                grid.threat[i] = grid.threat[i].saturating_add(add);
            }
        }
    }
    "ok".to_string()
}

// Adds contact danger at "z,x,y,amount,radius" with linear falloff over a
// Chebyshev radius (1 to 8; amount, then 1/2, then 1/3 ... of it). Only the
// human profile reads this layer. Saturating. Returns "ok" ("" on malformed
// input or unknown z).
byond_fn!(fn xeno_pathfind_danger(danger_desc) {
    Some(catch_panic(|| danger_impl(danger_desc)).unwrap_or_default())
});

fn danger_impl(desc: &str) -> String {
    let parts = parse_ints(desc);
    if parts.len() != 5 {
        return String::new();
    }
    let (z, x, y, amount) = (parts[0], parts[1], parts[2], parts[3].clamp(0, u16::MAX as i32) as u16);
    let radius = parts[4].clamp(1, 8);

    let mut map = map_lock();
    let Some(grid) = map.get_mut(&z) else {
        return String::new();
    };
    for dy in -radius..=radius {
        for dx in -radius..=radius {
            let dist = dx.abs().max(dy.abs()) as u16;
            let add = amount / (dist + 1);
            if add == 0 {
                continue;
            }
            if let Some(i) = grid.idx(x + dx, y + dy) {
                grid.danger[i] = grid.danger[i].saturating_add(add);
            }
        }
    }
    "ok".to_string()
}

// Halves every danger value on every loaded z-level. Separate from the threat
// decay so contact danger can cool on its own, faster cadence. Returns "ok".
byond_fn!(fn xeno_pathfind_decay_danger() {
    Some(catch_panic(|| {
        let mut map = map_lock();
        for grid in map.values_mut() {
            for d in grid.danger.iter_mut() {
                *d /= 2;
            }
        }
        "ok".to_string()
    }).unwrap_or_default())
});

// Reports what this build supports so BYOND can degrade cleanly against an
// older library: "profiles=xeno,human;cells=0-5;danger=1;diagonals=human".
byond_fn!(fn xeno_pathfind_capabilities() {
    Some("profiles=xeno,human;cells=0-5;danger=1;diagonals=human".to_string())
});

// Halves every threat value on every loaded z-level - called periodically
// by BYOND so kill zones cool off over a couple of minutes. Returns "ok".
byond_fn!(fn xeno_pathfind_decay() {
    Some(catch_panic(|| {
        let mut map = map_lock();
        for grid in map.values_mut() {
            for t in grid.threat.iter_mut() {
                *t /= 2;
            }
        }
        "ok".to_string()
    }).unwrap_or_default())
});

// Wipes all retained state (round restart). Returns "ok".
byond_fn!(fn xeno_pathfind_clear() {
    Some(catch_panic(|| {
        map_lock().clear();
        "ok".to_string()
    }).unwrap_or_default())
});

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::{CStr, CString};
    use std::os::raw::{c_char, c_int};

    fn grid(width: i32, height: i32, blocked_coords: &[(i32, i32)]) -> Vec<bool> {
        let mut g = vec![false; (width * height) as usize];
        for (x, y) in blocked_coords {
            g[(y * width + x) as usize] = true;
        }
        g
    }

    #[test]
    fn straight_line_open_grid() {
        let b = grid(10, 10, &[]);
        let path = find_path(10, 10, (0, 0), (5, 0), &b).expect("path should exist");
        assert_eq!(path.first(), Some(&(0, 0)));
        assert_eq!(path.last(), Some(&(5, 0)));
        assert_eq!(path.len(), 6);
    }

    #[test]
    fn no_diagonal_steps_in_returned_path() {
        let b = grid(10, 10, &[]);
        let path = find_path(10, 10, (0, 0), (5, 5), &b).expect("path should exist");
        assert_eq!(path.len(), 11);
        for pair in path.windows(2) {
            let (x1, y1) = pair[0];
            let (x2, y2) = pair[1];
            let dx = (x2 - x1).abs();
            let dy = (y2 - y1).abs();
            assert!(
                (dx == 1 && dy == 0) || (dx == 0 && dy == 1),
                "found a non-cardinal step: {:?} -> {:?}",
                pair[0],
                pair[1]
            );
        }
    }

    #[test]
    fn routes_around_a_wall_with_a_gap() {
        let mut blocked_coords = vec![];
        for y in 0..9 {
            blocked_coords.push((5, y));
        }
        let b = grid(10, 10, &blocked_coords);
        let path = find_path(10, 10, (0, 0), (9, 0), &b).expect("path should exist through the gap");
        assert!(path.contains(&(5, 9)));
    }

    #[test]
    fn unreachable_target_returns_none() {
        let mut blocked_coords = vec![];
        for x in 4..=6 {
            for y in 4..=6 {
                if !(x == 5 && y == 5) {
                    blocked_coords.push((x, y));
                }
            }
        }
        let b = grid(10, 10, &blocked_coords);
        assert!(find_path(10, 10, (0, 0), (5, 5), &b).is_none());
    }

    #[test]
    fn blocked_start_or_end_out_of_bounds_is_handled_gracefully() {
        let b = grid(5, 5, &[]);
        assert!(find_path(5, 5, (-1, 0), (2, 2), &b).is_none());
        assert!(find_path(5, 5, (0, 0), (10, 10), &b).is_none());
    }

    /// Invokes an entry point exactly the way BYOND's call_ext() does:
    /// (argc, argv) with argv pointing at an array of C string pointers.
    fn byond(
        f: unsafe extern "C" fn(c_int, *const *const c_char) -> *const c_char,
        args: &[&str],
    ) -> String {
        let cstrings: Vec<CString> = args.iter().map(|s| CString::new(*s).unwrap()).collect();
        let ptrs: Vec<*const c_char> = cstrings.iter().map(|c| c.as_ptr()).collect();
        let result_ptr = unsafe { f(ptrs.len() as c_int, ptrs.as_ptr()) };
        unsafe { CStr::from_ptr(result_ptr) }
            .to_str()
            .unwrap()
            .to_string()
    }

    #[test]
    fn ffi_roundtrip_produces_expected_path_string() {
        let blocked = "0".repeat(25);
        let result = byond(xeno_pathfind, &["5,5,0,0,4,0", &blocked]);
        assert_eq!(result, "0,0;1,0;2,0;3,0;4,0");
    }

    #[test]
    fn ffi_malformed_input_returns_empty_string_not_a_crash() {
        assert_eq!(byond(xeno_pathfind, &["not,a,valid,grid", ""]), "");
        assert_eq!(byond(xeno_pathfind, &["5,5,0,0,4,0"]), "");
        let result_ptr = unsafe { xeno_pathfind(0, std::ptr::null()) };
        assert_eq!(unsafe { CStr::from_ptr(result_ptr) }.to_str().unwrap(), "");
    }

    // ------------------------------------------------------------------
    // Persistent grid tests. Each test uses its own z value - the MAP
    // static is shared across the parallel test threads.
    // ------------------------------------------------------------------

    fn call1(f: unsafe extern "C" fn(c_int, *const *const c_char) -> *const c_char, arg: &str) -> String {
        byond(f, &[arg])
    }

    fn call2(
        f: unsafe extern "C" fn(c_int, *const *const c_char) -> *const c_char,
        a: &str,
        b: &str,
    ) -> String {
        byond(f, &[a, b])
    }

    /// Builds a width x height all-open packed string with the given cells
    /// (1-based world coords) overridden to the given code char.
    fn packed(width: i32, height: i32, overrides: &[(i32, i32, u8)]) -> String {
        let mut cells = vec![b'0'; (width * height) as usize];
        for (x, y, code) in overrides {
            cells[((y - 1) * width + (x - 1)) as usize] = *code;
        }
        String::from_utf8(cells).unwrap()
    }

    #[test]
    fn persistent_init_and_route_roundtrip() {
        assert_eq!(
            call2(xeno_pathfind_init_z, "101,10,10", &packed(10, 10, &[])),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "101,1,1,5,1");
        assert_eq!(path, "1,1;2,1;3,1;4,1;5,1");
    }

    #[test]
    fn persistent_update_reroutes_around_new_wall() {
        let overrides: Vec<(i32, i32, u8)> = (1..10).map(|y| (5, y, b'1')).collect();
        assert_eq!(
            call2(xeno_pathfind_init_z, "102,10,10", &packed(10, 10, &overrides)),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "102,1,1,10,1");
        assert!(path.contains("5,10"), "route should use the only gap: {path}");
        assert_eq!(call1(xeno_pathfind_update, "102,5,10,1"), "ok");
        assert_eq!(call1(xeno_pathfind_route, "102,1,1,10,1"), "");
        assert_eq!(call1(xeno_pathfind_update, "102,5,5,0"), "ok");
        let path = call1(xeno_pathfind_route, "102,1,1,10,1");
        assert!(path.contains("5,5"), "route should use the reopened cell: {path}");
    }

    #[test]
    fn persistent_door_costs_prefer_open_route_but_pass_when_only_option() {
        let mut overrides: Vec<(i32, i32, u8)> = (1..=10).map(|y| (5, y, b'1')).collect();
        overrides[0] = (5, 1, b'2');
        overrides[2] = (5, 3, b'0');
        assert_eq!(
            call2(xeno_pathfind_init_z, "103,10,10", &packed(10, 10, &overrides)),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "103,4,1,6,1");
        assert!(path.contains("5,3"), "open gap should beat the door: {path}");
        assert!(!path.contains("5,1"), "door tile should be avoided: {path}");
        assert_eq!(call1(xeno_pathfind_update, "103,5,3,1"), "ok");
        let path = call1(xeno_pathfind_route, "103,4,1,6,1");
        assert!(path.contains("5,1"), "door should be used when only option: {path}");
    }

    #[test]
    fn persistent_door_preferred_over_window_obstacle() {
        let mut overrides: Vec<(i32, i32, u8)> = (1..=10).map(|y| (5, y, b'1')).collect();
        overrides[0] = (5, 1, b'3');
        overrides[2] = (5, 3, b'2');
        assert_eq!(
            call2(xeno_pathfind_init_z, "106,10,10", &packed(10, 10, &overrides)),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "106,4,1,6,1");
        assert!(path.contains("5,3"), "door should beat the window: {path}");
        assert!(!path.contains("5,1;"), "window tile should be avoided: {path}");
    }

    #[test]
    fn persistent_border_structure_costed_between_open_and_obstacle() {
        // Wall at x=5 with an ON_BORDER structure (platform/barricade, '4')
        // directly on the straight line at y=1 and a genuine breakable
        // obstacle ('3') two tiles south: the border tile should be crossed
        // in preference to smashing the obstacle (proving it's cheaper than
        // an obstacle), but a route should still be willing to use it at all
        // (proving it isn't priced as a hard block the way CELL_BLOCKED is).
        let mut overrides: Vec<(i32, i32, u8)> = (1..=10).map(|y| (5, y, b'1')).collect();
        overrides[0] = (5, 1, b'4');
        overrides[2] = (5, 3, b'3');
        assert_eq!(
            call2(xeno_pathfind_init_z, "107,10,10", &packed(10, 10, &overrides)),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "107,4,1,6,1");
        assert!(path.contains("5,1"), "border tile should be used, not avoided entirely: {path}");
        assert!(!path.contains("5,3"), "border tile should beat the heavier obstacle detour: {path}");
    }

    #[test]
    fn border_cost_is_between_open_and_obstacle() {
        // Direct check on the cost function itself rather than a routing
        // preference (which depends on detour length and is easy to get
        // wrong by hand) - the actual invariant that matters is that
        // CELL_BORDER isn't priced as free (unlike the old climbable-on-
        // CELL_OPEN behavior) but also isn't priced anywhere near a real
        // obstacle.
        let grid = ZGrid {
            width: 1,
            height: 1,
            base: vec![CELL_BORDER],
            threat: vec![0],
            danger: vec![0],
        };
        let cost = grid.step_cost(1, 1, &XENO_PROFILE).expect("a border tile should be passable, not a hard block");
        assert!(cost > STEP_COST_OPEN, "border should cost more than open ground: {cost}");
        assert!(cost < STEP_COST_OBSTACLE, "border should cost less than a real obstacle: {cost}");
    }

    #[test]
    fn persistent_threat_bends_route_and_decays() {
        assert_eq!(
            call2(xeno_pathfind_init_z, "104,11,11", &packed(11, 11, &[])),
            "ok"
        );
        assert_eq!(call1(xeno_pathfind_threat, "104,6,1,200"), "ok");
        let path = call1(xeno_pathfind_route, "104,1,1,11,1");
        assert!(
            !path.contains(";6,1;"),
            "route should detour around the threat epicenter: {path}"
        );
        for _ in 0..12 {
            assert_eq!(call1(xeno_pathfind_decay, ""), "ok");
        }
        let path = call1(xeno_pathfind_route, "104,1,1,11,1");
        assert!(
            path.contains(";6,1;"),
            "decayed threat should no longer bend the route: {path}"
        );
    }

    #[test]
    fn persistent_malformed_and_unknown_z_return_empty() {
        assert_eq!(call2(xeno_pathfind_init_z, "bad,desc", "000"), "");
        assert_eq!(call2(xeno_pathfind_init_z, "105,3,3", "not-nine!"), "");
        assert_eq!(call1(xeno_pathfind_route, "9999,1,1,2,2"), "");
        assert_eq!(call1(xeno_pathfind_route, "garbage"), "");
        assert_eq!(call1(xeno_pathfind_threat, "9999,1,1,50"), "");
        assert_eq!(call1(xeno_pathfind_update, "9999,1,1,1;garbage;;"), "ok");
    }

    // ------------------------------------------------------------------
    // Cost profile tests (profile id is the optional sixth route field).
    // ------------------------------------------------------------------

    /// A wall down x=5 with the given (y, code) gaps; everything else open.
    fn walled(width: i32, height: i32, gaps: &[(i32, u8)]) -> String {
        let mut overrides: Vec<(i32, i32, u8)> = (1..=height).map(|y| (5, y, b'1')).collect();
        for (y, code) in gaps {
            overrides[(*y - 1) as usize] = (5, *y, *code);
        }
        packed(width, height, &overrides)
    }

    #[test]
    fn xeno_route_is_unchanged_by_an_explicit_profile_and_secure_doors() {
        assert_eq!(
            call2(xeno_pathfind_init_z, "201,10,10", &walled(10, 10, &[(1, b'5')])),
            "ok"
        );
        let implicit = call1(xeno_pathfind_route, "201,4,1,6,1");
        let explicit = call1(xeno_pathfind_route, "201,4,1,6,1,0");
        assert_eq!(implicit, explicit);
        assert!(implicit.contains("5,1"), "xeno prices a secure door like a door: {implicit}");
    }

    #[test]
    fn human_profile_cannot_cross_a_breakable_obstacle() {
        assert_eq!(
            call2(xeno_pathfind_init_z, "202,10,10", &walled(10, 10, &[(1, b'3')])),
            "ok"
        );
        assert!(call1(xeno_pathfind_route, "202,4,1,6,1,0").contains("5,1"));
        assert_eq!(call1(xeno_pathfind_route, "202,4,1,6,1,1"), "");
    }

    #[test]
    fn human_profile_steps_diagonally_and_xeno_does_not() {
        assert_eq!(call2(xeno_pathfind_init_z, "203,10,10", &packed(10, 10, &[])), "ok");
        let human = call1(xeno_pathfind_route, "203,1,1,6,6,1");
        assert_eq!(human.split(';').count(), 6, "diagonal route should take 6 tiles: {human}");
        assert!(human.contains("2,2"));
        let xeno = call1(xeno_pathfind_route, "203,1,1,6,6,0");
        assert_eq!(xeno.split(';').count(), 11, "cardinal route should take 11 tiles: {xeno}");
    }

    #[test]
    fn human_diagonal_never_cuts_between_two_blocked_corners() {
        let overrides = [(3, 2, b'1'), (2, 3, b'1')];
        assert_eq!(
            call2(xeno_pathfind_init_z, "204,6,6", &packed(6, 6, &overrides)),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "204,2,2,3,3,1");
        assert!(!path.is_empty(), "a route around the corner should exist");
        assert_ne!(path, "2,2;3,3", "must not squeeze through the blocked corner");
        assert!(path.split(';').count() > 2, "{path}");
    }

    #[test]
    fn human_diagonal_does_not_brush_past_a_door() {
        assert_eq!(
            call2(xeno_pathfind_init_z, "205,6,6", &packed(6, 6, &[(3, 2, b'2')])),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "205,2,2,3,3,1");
        assert_ne!(path, "2,2;3,3", "diagonal past a door tile is not a clean corner");
    }

    #[test]
    fn human_secure_door_is_a_last_resort_but_still_a_route() {
        let gaps = [(1, b'5'), (9, b'0')];
        assert_eq!(call2(xeno_pathfind_init_z, "206,10,10", &walled(10, 10, &gaps)), "ok");
        let xeno = call1(xeno_pathfind_route, "206,4,1,6,1,0");
        assert!(xeno.contains("5,1"), "xeno forces the door: {xeno}");
        let human = call1(xeno_pathfind_route, "206,4,1,6,1,1");
        assert!(human.contains("5,9") && !human.contains("5,1"), "human takes the open gap: {human}");
        assert_eq!(call1(xeno_pathfind_update, "206,5,9,1"), "ok");
        let human = call1(xeno_pathfind_route, "206,4,1,6,1,1");
        assert!(human.contains("5,1"), "human uses the secure door when nothing else exists: {human}");
    }

    #[test]
    fn human_ignores_hive_threat_and_avoids_contact_danger() {
        assert_eq!(call2(xeno_pathfind_init_z, "207,11,11", &packed(11, 11, &[])), "ok");
        assert_eq!(call1(xeno_pathfind_threat, "207,6,1,200"), "ok");
        let human = call1(xeno_pathfind_route, "207,1,1,11,1,1");
        assert!(human.contains(";6,1;"), "hive threat must not bend a human route: {human}");
        let xeno = call1(xeno_pathfind_route, "207,1,1,11,1,0");
        assert!(!xeno.contains(";6,1;"), "hive threat still bends a xeno route: {xeno}");

        assert_eq!(call1(xeno_pathfind_danger, "207,6,1,200,2"), "ok");
        let human = call1(xeno_pathfind_route, "207,1,1,11,1,1");
        assert!(!human.contains(";6,1;"), "danger should bend a human route: {human}");
        for _ in 0..12 {
            assert_eq!(call1(xeno_pathfind_decay_danger, ""), "ok");
        }
        let human = call1(xeno_pathfind_route, "207,1,1,11,1,1");
        assert!(human.contains(";6,1;"), "decayed danger should no longer bend the route: {human}");
    }

    #[test]
    fn unknown_profile_and_malformed_descriptors_fail_closed() {
        assert_eq!(call2(xeno_pathfind_init_z, "208,5,5", &packed(5, 5, &[])), "ok");
        assert_eq!(call1(xeno_pathfind_route, "208,1,1,3,3,7"), "");
        assert_eq!(call1(xeno_pathfind_route, "208,1,1,3,3,-1"), "");
        assert_eq!(call1(xeno_pathfind_route, "208,1,1,3,3,1,9"), "");
        assert_eq!(call1(xeno_pathfind_danger, "208,1,1,50"), "");
        assert_eq!(call1(xeno_pathfind_danger, "9999,1,1,50,2"), "");
        assert_eq!(call2(xeno_pathfind_init_z, "209,3,3", "00000000x"), "");
    }

    #[test]
    fn capabilities_report_profiles_and_secure_doors() {
        let caps = byond(xeno_pathfind_capabilities, &[]);
        assert!(caps.contains("profiles=xeno,human"), "{caps}");
        assert!(caps.contains("cells=0-5"), "{caps}");
        assert!(caps.contains("danger=1"), "{caps}");
    }

    /// Timing probe, not a correctness test: cargo test --release -- --ignored --nocapture route_timing
    #[test]
    #[ignore]
    fn route_timing_probe() {
        let width = 255;
        let height = 255;
        let mut seed: u32 = 12345;
        let mut next = || {
            seed = seed.wrapping_mul(1664525).wrapping_add(1013904223);
            (seed >> 16) as i32
        };
        let mut overrides = Vec::new();
        for _ in 0..(width * height / 6) {
            let x = 1 + next() % width;
            let y = 1 + next() % height;
            let code = match next() % 10 {
                0 => b'2',
                1 => b'4',
                2 => b'5',
                _ => b'1',
            };
            overrides.push((x, y, code));
        }
        for y in 1..=height {
            overrides.push((1, y, b'0'));
            overrides.push((width, y, b'0'));
        }
        for x in 1..=width {
            overrides.push((x, 1, b'0'));
            overrides.push((x, height, b'0'));
        }
        assert_eq!(
            call2(xeno_pathfind_init_z, "250,255,255", &packed(width, height, &overrides)),
            "ok"
        );
        for profile in [0, 1] {
            let started = std::time::Instant::now();
            let mut found = 0;
            let routes = 200;
            for _ in 0..routes {
                let desc = format!(
                    "250,{},{},{},{},{}",
                    1,
                    1 + next() % height,
                    width,
                    1 + next() % height,
                    profile
                );
                if !call1(xeno_pathfind_route, &desc).is_empty() {
                    found += 1;
                }
            }
            let elapsed = started.elapsed();
            println!(
                "profile {profile}: {routes} routes ({found} found) in {:?}, {:.3} ms each",
                elapsed,
                elapsed.as_secs_f64() * 1000.0 / routes as f64
            );
        }
    }
}
