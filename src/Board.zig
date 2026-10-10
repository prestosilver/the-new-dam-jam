const rl = @import("raylib");
const std = @import("std");
const build_options = @import("build_options");

const util = @import("util.zig");

const emasm = @import("emasm.zig");

const Shop = @import("Shop.zig");

pub const MAX_DARTS = 1_000_000;
const MAX_VISIBLE = 500;
const MAX_FADE = 600;
const MAX_RENDER = 750;
const FADE_TIME = 0.2;

const BOARD_VALUES = [20]u32{ 20, 1, 18, 4, 13, 6, 10, 15, 2, 13, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5 };

const BULL_RADIUS = 0.071;
const DOUBLE_BULL_RADIUS = 0.028;

const INNER_DOUBLE_RING = 0.72;
const OUTER_DOUBLE_RING = 0.75;

const INNER_TRIPLE_RING = 0.44;
const OUTER_TRIPLE_RING = 0.47;

pub var board_texture: rl.Texture = undefined;
pub var background_texture: rl.Texture = undefined;
pub var dart_texture: rl.Texture = undefined;

const Player = union(enum) {
    ai: struct {
        throw_countdown: f32 = 0,
        darts_per_second: f32,
        upgrade_rate: i32,
    },
    user: struct {
        send_timer: f32 = 0.0,
    },
    web: struct {
        last_sync: usize = 0,
        poll_timer: f32 = 0.0,
    },
};

font_size: f32 = 66,

player: Player = .{ .user = .{} },
first_dart: usize = 0,
processed_darts: usize = 0,
thrown_darts: usize = 0,
money: u32 = 0,

shot_stats: extern struct {
    darts_per_shot: u32 = 1,
    aim_focus: f32 = 200.0,
} = .{},

dart_monkey_timer: f64 = 0.0,
monkey_stats: extern struct {
    shots_per_second: f32 = 0.0,
    darts_per_shot: u32 = 1,
    aim_focus: f32 = 1.0,
} = .{},

// update
dart_states: [MAX_DARTS]enum(u8) { thrown, fall, fade } = undefined,
dart_velocities: [MAX_DARTS]rl.Vector2 = undefined,

// drawing
dart_positions: [MAX_DARTS]rl.Vector2 = undefined,
dart_fades: [MAX_DARTS]f32 = undefined,

upgrade_counts: std.enums.EnumArray(Shop.Upgrade, u32) = .initFill(0),

const DART_FALL_SPEED = 500;

const Board = @This();

pub fn update(self: *Board, done: bool, bounds: rl.Rectangle, dt: f32) void {
    const mouse_pos = rl.getMousePosition();

    // dart logic
    {
        self.first_dart = @min(self.first_dart, @max(MAX_RENDER, self.thrown_darts) - MAX_RENDER);

        for (
            self.dart_positions[self.first_dart..self.thrown_darts],
            self.dart_velocities[self.first_dart..self.thrown_darts],
            self.dart_states[self.first_dart..self.thrown_darts],
            self.dart_fades[self.first_dart..self.thrown_darts],
        ) |*position, *velocity, *state, *fade| {
            if (state.* == .fade) {
                fade.* -= dt / FADE_TIME;
            } else {
                if (state.* == .fall or state.* == .fade) {
                    velocity.y += @floatCast(dt * DART_FALL_SPEED);
                }

                position.x += velocity.x * dt;
                position.y += velocity.y * dt;
            }
        }

        while (self.first_dart < self.thrown_darts and
            (self.dart_positions[self.first_dart].y > (bounds.y + bounds.height) or
                self.dart_fades[self.first_dart] < 0))
        {
            self.first_dart += 1;
        }

        var idx: usize = self.first_dart;
        while (idx < @max(MAX_VISIBLE, self.thrown_darts) - MAX_VISIBLE) : (idx += 1) {
            if (idx < @max(MAX_FADE, self.thrown_darts) - MAX_FADE) {
                self.dart_states[idx] = .fade;
            } else {
                self.dart_states[idx] = .fall;
            }
        }
    }

    // darts dont throw at the end of the game
    if (done)
        return;

    if (self.player == .user) {
        self.player.user.send_timer += dt;
        if (self.player.user.send_timer > 0.25) {
            self.shopSend();

            self.player.user.send_timer = 0;
        }
    }

    // monkey logic
    {
        self.dart_monkey_timer += dt * @min(500.0, self.monkey_stats.shots_per_second);

        while (self.dart_monkey_timer > 1.0) {
            if (self.monkey_stats.shots_per_second < 25.0) {
                const x = @as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0 * bounds.width * self.monkey_stats.aim_focus + (bounds.width * (1.0 - self.monkey_stats.aim_focus)) / 2;
                const y = @as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0 * bounds.height * self.monkey_stats.aim_focus + (bounds.height * (1.0 - self.monkey_stats.aim_focus)) / 2;

                for (0..self.monkey_stats.darts_per_shot) |_| {
                    const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0 * std.math.pi * 2;
                    const mag = std.math.sqrt(@as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0) * 50.0;

                    self.throwDart(bounds, .{
                        .x = x + @sin(angle) * mag + bounds.x,
                        .y = y + @cos(angle) * mag + bounds.y,
                    });
                }
            } else {
                const x = @as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0 * bounds.width * self.monkey_stats.aim_focus + (bounds.width * (1.0 - self.monkey_stats.aim_focus)) / 2;
                const y = @as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0 * bounds.height * self.monkey_stats.aim_focus + (bounds.height * (1.0 - self.monkey_stats.aim_focus)) / 2;

                const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0 * std.math.pi * 2;
                const mag = std.math.sqrt(@as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0) * 50.0;

                const pos: rl.Vector2 = .{
                    .x = x + @sin(angle) * mag + bounds.x,
                    .y = y + @cos(angle) * mag + bounds.y,
                };

                for (0..self.monkey_stats.darts_per_shot) |_| {
                    self.throwDart(bounds, pos);
                }
            }

            self.dart_monkey_timer -= 1.0 / self.monkey_stats.shots_per_second;
        }
    }

    switch (self.player) {
        .ai => |*ai| {
            while (ai.throw_countdown <= 1.0 / ai.darts_per_second) {
                const random_x: f32 = @floatFromInt(rl.getRandomValue(
                    0,
                    @intFromFloat(bounds.width),
                ));
                const random_y: f32 = @floatFromInt(rl.getRandomValue(
                    0,
                    @intFromFloat(bounds.height),
                ));

                self.throwDart(bounds, .{
                    .x = bounds.x + random_x,
                    .y = bounds.y + random_y,
                });
                ai.throw_countdown += 1.0 / ai.darts_per_second;
            }
            ai.throw_countdown -= dt;
        },
        .user => {
            if (rl.isMouseButtonPressed(.left) and
                rl.checkCollisionPointRec(mouse_pos, bounds))
            {
                for (0..self.shot_stats.darts_per_shot) |_| {
                    self.throwDart(bounds, mouse_pos);
                }
            }
        },
        .web => {},
    }
}

pub fn draw(self: *const Board, done: bool, bounds: rl.Rectangle) void {
    rl.beginScissorMode(
        @intFromFloat(bounds.x),
        @intFromFloat(bounds.y),
        @intFromFloat(bounds.width),
        @intFromFloat(bounds.height),
    );
    defer {
        //rl.drawRectangleLinesEx(bounds, 1, .white);
        rl.endScissorMode();
    }

    var fmt_buf: [64]u8 = undefined;

    const center = rl.Vector2{
        .x = bounds.x + bounds.width * 0.5,
        .y = bounds.y + bounds.height * 0.5,
    };

    const half_board_side = @min(bounds.width, bounds.height) * 0.5;
    const board_pos = rl.Rectangle{
        .x = center.x - half_board_side,
        .y = center.y - half_board_side,
        .width = half_board_side * 2,
        .height = half_board_side * 2,
    };

    background_texture.drawPro(
        .{
            .x = 100,
            .y = 0,
            .width = @floatFromInt(background_texture.height),
            .height = @floatFromInt(background_texture.height),
        },
        board_pos,
        .{ .x = 0, .y = 0 },
        0,
        .white,
    );

    board_texture.drawPro(
        .{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(board_texture.width),
            .height = @floatFromInt(board_texture.height),
        },
        board_pos,
        .{ .x = 0, .y = 0 },
        0,
        .white,
    );

    const dart_size = rl.Vector2{
        .x = half_board_side * 2 / @as(f32, @floatFromInt(board_texture.width)) * @as(f32, @floatFromInt(dart_texture.width)),
        .y = half_board_side * 2 / @as(f32, @floatFromInt(board_texture.height)) * @as(f32, @floatFromInt(dart_texture.height)),
    };

    for (
        self.dart_positions[self.first_dart..self.thrown_darts],
        self.dart_fades[self.first_dart..self.thrown_darts],
    ) |position, fade| {
        dart_texture.drawPro(
            .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(dart_texture.width),
                .height = @floatFromInt(dart_texture.height),
            },
            .{ .x = position.x, .y = position.y, .width = dart_size.x, .height = dart_size.y },
            .{ .x = 0, .y = 0 },
            0,
            .alpha(.white, fade),
        );
    }

    rl.drawRectangleRec(.{
        .x = bounds.x,
        .y = bounds.y,
        .width = bounds.width,
        .height = self.font_size,
    }, .alpha(.black, 0.5));

    const darts_text = std.fmt.bufPrintSentinel(
        &fmt_buf,
        "{:06}",
        .{Board.MAX_DARTS - self.processed_darts},
        0,
    ) catch unreachable;

    const size: f32 = rl.measureTextEx(
        util.font,
        darts_text,
        self.font_size,
        0,
    ).x;

    rl.drawTextEx(
        util.font,
        if (done) (if (self.processed_darts == MAX_DARTS) "Winner" else "Loser") else darts_text,
        .{
            .x = center.x - size / 2,
            .y = bounds.y,
        },
        self.font_size,
        0,
        .white,
    );
}

pub fn throwDart(self: *Board, bounds: rl.Rectangle, position: rl.Vector2) void {
    if (self.thrown_darts >= MAX_DARTS or
        self.processed_darts >= MAX_DARTS) return;

    const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0 * std.math.pi * 2;
    const mag = std.math.sqrt(@as(f32, @floatFromInt(rl.getRandomValue(0, 100))) / 100.0) * self.shot_stats.aim_focus;

    const throw_position = rl.Vector2{
        .x = position.x + @sin(angle) * mag,
        .y = position.y + @cos(angle) * mag,
    };

    const twenty_angle = -0.5 / 20.0 * std.math.pi * 2.0;

    const center = rl.Vector2{
        .x = bounds.x + bounds.width * 0.5,
        .y = bounds.y + bounds.height * 0.5,
    };

    const dart_angle = rl.math.vector2Angle(.{
        .x = @sin(twenty_angle) * bounds.width * 0.5,
        .y = @cos(twenty_angle) * bounds.height * 0.5,
    }, .{
        .x = center.x - throw_position.x,
        .y = center.y - throw_position.y,
    });

    const dart_sector: u32 = @mod(@as(u32, @intFromFloat(dart_angle / std.math.pi / 2.0 * 20 + 21)), 20);

    const board_radius = @min(bounds.width, bounds.height) * 0.5;
    const shot_radius = throw_position.distance(center);

    const outer_double_radius = board_radius * OUTER_DOUBLE_RING;
    const inner_double_radius = board_radius * INNER_DOUBLE_RING;

    const outer_triple_radius = board_radius * OUTER_TRIPLE_RING;
    const inner_triple_radius = board_radius * INNER_TRIPLE_RING;

    const bull_radius = board_radius * BULL_RADIUS;
    const double_bull_radius = board_radius * DOUBLE_BULL_RADIUS;

    var value: u32 = BOARD_VALUES[dart_sector];

    if (shot_radius > inner_double_radius and
        shot_radius < outer_double_radius)
        value *= 2;

    if (shot_radius > inner_triple_radius and
        shot_radius < outer_triple_radius)
        value *= 3;

    if (shot_radius < double_bull_radius) {
        value = 25;

        if (shot_radius > bull_radius)
            value *= 2;
    }

    if (shot_radius > outer_double_radius)
        value = 0;

    self.money += value;

    self.dart_states[self.thrown_darts] = if (value > 0)
        .thrown
    else
        .fall;

    self.dart_positions[self.thrown_darts] = throw_position;
    self.dart_fades[self.thrown_darts] = 1.0;
    self.dart_velocities[self.thrown_darts] = .{ .x = 0, .y = 0 };
    self.thrown_darts += 1;
    self.processed_darts += 1;
}

pub fn buyUpgrade(self: *Board, upgrade: Shop.Upgrade) void {
    switch (upgrade) {
        .spread => {
            self.shot_stats.darts_per_shot += 1;
        },
        .monkey => {
            self.monkey_stats.shots_per_second += 1;
            self.monkey_stats.shots_per_second *= 1.1;
        },
        .focus => {
            self.shot_stats.aim_focus *= 0.75;
        },
        .monkey_focus => {
            self.monkey_stats.aim_focus *= 0.9;
        },
        .monkey_spread => {
            self.monkey_stats.darts_per_shot += 1;
        },
    }
}

var web_idx: usize = 0;

pub fn shopSend(board: *const Board) void {
    const data: Shop.WebPayload = .{
        .payload_idx = web_idx,
        .processed_darts = board.processed_darts,
        .shot_stats = @bitCast(board.shot_stats),
        .monkey_stats = @bitCast(board.monkey_stats),
    };

    emasm.EM_ASM(
        \\const stringBytes = new Uint8Array(wasmMemory.buffer, $0, $1);
        \\shop_purchase(JSON.stringify(stringBytes));
    , .{ &data, @as(i32, @sizeOf(Shop.WebPayload)) });

    web_idx += 1;
}
