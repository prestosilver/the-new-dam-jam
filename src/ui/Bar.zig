const std = @import("std");
const rl = @import("raylib");

const util = @import("../util.zig");

const BACKGROUND_COLOR: rl.Color = .{ .r = 0, .g = 148, .b = 121, .a = 255 };
const FILL_COLOR: rl.Color = .{ .r = 9, .g = 219, .b = 47, .a = 255 };

const TEXT_COLOR: rl.Color = .black;

const INC_SPEED = 0.5;
const INC_SCALE = 0.1;

const DEC_SPEED = 0.4;
const DEC_SCALE = 0.1;

const SPEED_STEPS = 10.0;

bounds: rl.Rectangle,
value: f32 = 0,
target: f32 = 0,
step: f32 = 1000,

const Bar = @This();

pub fn update(self: *Bar, dt: f32) void {
    const speed_step = self.step / SPEED_STEPS;

    if (self.value < self.target) {
        const inc_speed = self.step * INC_SPEED;
        const inc_speed_scale = self.step * INC_SCALE;

        const diff = @divFloor(self.target, speed_step) - @divFloor(self.value, speed_step);

        self.value += (inc_speed + inc_speed_scale * diff) * dt;
        self.value = @min(self.value, self.target);
    }

    if (self.value > self.target) {
        const dec_speed = self.step * DEC_SPEED;
        const dec_speed_scale = self.step * DEC_SCALE;

        const diff = @divFloor(self.value, speed_step) - @divFloor(self.target, speed_step);

        self.value -= (dec_speed + dec_speed_scale * diff) * dt;
        self.value = @max(self.value, 0);
    }
}

pub fn draw(self: *const Bar) void {
    const fill_pc = @rem(self.value / self.step, 1.0);

    rl.drawRectangleRec(self.bounds, BACKGROUND_COLOR);
    rl.drawRectangleRec(.{
        .x = self.bounds.x,
        .y = self.bounds.y,
        .width = self.bounds.width * fill_pc,
        .height = self.bounds.height,
    }, FILL_COLOR);

    var fmt_buf: [64]u8 = undefined;
    const text = std.fmt.bufPrintSentinel(
        &fmt_buf,
        "{}%",
        .{@as(i32, @intFromFloat(fill_pc * 100))},
        0,
    ) catch unreachable;
    rl.drawTextEx(
        util.font,
        text,
        .{
            .x = self.bounds.x + 5,
            .y = self.bounds.y,
        },
        self.bounds.height,
        0,
        TEXT_COLOR,
    );
}
