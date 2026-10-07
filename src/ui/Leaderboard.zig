const std = @import("std");
const rl = @import("raylib");
const mmr = @import("../mmr.zig");

const TEXT_COLOR: rl.Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 };

pub const Entry = extern struct {
    valid: bool = false,
    name: [15:0]u8 = @bitCast([_]u8{0} ** 16),
    mmr: u32 = 0,
};

bounds: rl.Rectangle,
entry: *const Entry,

const Leaderboard = @This();

pub fn draw(self: *const Leaderboard) void {
    if (!self.entry.valid) return;

    rl.drawText(
        &self.entry.name,
        @intFromFloat(self.bounds.x),
        @intFromFloat(self.bounds.y),
        @intFromFloat(self.bounds.height),
        TEXT_COLOR,
    );

    const score_text = mmr.getRank(self.entry.mmr);
    rl.drawText(
        score_text,
        @intFromFloat(self.bounds.x + 500),
        @intFromFloat(self.bounds.y),
        @intFromFloat(self.bounds.height),
        TEXT_COLOR,
    );
}
