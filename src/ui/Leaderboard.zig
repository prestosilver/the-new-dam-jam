const std = @import("std");
const rl = @import("raylib");

const util = @import("../util.zig");

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

    rl.drawTextEx(
        util.font,
        &self.entry.name,
        .{
            .x = self.bounds.x,
            .y = self.bounds.y,
        },
        self.bounds.height,
        0,
        TEXT_COLOR,
    );

    const score_text = util.getRank(self.entry.mmr);
    rl.drawTextEx(
        util.font,
        score_text,
        .{
            .x = self.bounds.x + 500,
            .y = self.bounds.y,
        },
        self.bounds.height,
        0,
        TEXT_COLOR,
    );
}
