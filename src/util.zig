const std = @import("std");
const rl = @import("raylib");

pub const RANK_STEP = 1000;
const RANKS = [_][:0]const u8{ "F", "D-", "D", "D+", "C-", "C", "C+", "B-", "B", "B+", "A-", "A", "A+", "A++", "S-", "S", "S+", "SS", "SS+", "SSS" };

var rank_buf: [32]u8 = undefined;

pub fn getRank(score: u32) [:0]const u8 {
    const idx = @divFloor(score, RANK_STEP);

    if (idx < RANKS.len)
        return RANKS[@intCast(idx)];

    if (idx == RANKS.len)
        return RANKS[RANKS.len - 1] ++ "+";

    if (idx == RANKS.len + 1)
        return RANKS[RANKS.len - 1] ++ "++";

    if (idx == RANKS.len + 2)
        return RANKS[RANKS.len - 1] ++ "+++";

    return std.fmt.bufPrintSentinel(
        &rank_buf,
        RANKS[RANKS.len - 1] ++ "+{d}",
        .{idx - RANKS.len + 1},
        0,
    ) catch unreachable;
}

pub var font: rl.Font = undefined;
