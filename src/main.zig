const std = @import("std");
const rl = @import("raylib");
const build_options = @import("build_options");

const Board = @import("Board.zig");
const Shop = @import("Shop.zig");

const BG_COLOR: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
const PLAY_SIZE: rl.Vector2 = .{ .x = 500, .y = 150 };
const SHOP_WIDTH = 450;
const BOTTOM_PAD = 50;

pub fn customLogFn(
    comptime level: std.log.Level,
    comptime _: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    var buf: [1024]u8 = undefined;
    const log: [*c]const u8 = std.fmt.bufPrintZ(&buf, format, args) catch unreachable;

    rl.traceLog(switch (level) {
        .debug => .debug,
        .info => .info,
        .warn => .warning,
        .err => .err,
    }, "%s", .{log});
}

pub const std_options: std.Options = .{
    // Fix a emscripten bug in 0.16 that breaks std.defaultLog
    .logFn = customLogFn,
};

const State = enum { lobby, game, end };
var state: State = undefined;

/// This is the percent progress of the current state transition
var transition_timer: f64 = 0.0;

var p1_board: Board = .{};
var p2_board: Board = .{};

var shop: Shop = .{};
var mms: u32 = 0;
var render_mms: f32 = 0;
var play: packed struct(u8) {
    focused: bool = false,
    click: bool = false,
    disabled: bool = false,
    padding: u5 = undefined,
} = .{};

pub fn setState(new_state: State, io: std.Io) void {
    _ = io;

    switch (new_state) {
        .lobby => {},
        .game => {
            p1_board = .{ .player = .user };
            p2_board = .{ .player = .{ .ai = .{
                .darts_per_second = 10,
                .upgrade_rate = 1,
            } } };
        },
        .end => {},
    }

    state = new_state;
    transition_timer = 0.0;
}

var fmt_buf: [64]u8 = undefined;

const RANKS = [_][:0]const u8{
    "F",
    "D-",
    "D",
    "D+",
    "C-",
    "C",
    "C+",
    "B-",
    "B",
    "B+",
    "A-",
    "A",
    "A+",
    "A++",
    "S-",
    "S",
    "S+",
    "SS",
    "SS+",
    "SSS+",
};
pub fn getRank(score: u64, buf: []u8) [:0]const u8 {
    const idx = @divFloor(score, 1000);

    if (idx < RANKS.len)
        return RANKS[idx];

    return std.fmt.bufPrintSentinel(
        buf,
        RANKS[RANKS.len - 1] ++ "{d}",
        .{idx - RANKS.len + 1},
        0,
    ) catch unreachable;
}

pub fn main(init: std.process.Init) !void {
    rl.initWindow(build_options.SCREEN_WIDTH, build_options.SCREEN_HEIGHT, build_options.GAME_NAME);
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(60);
    rl.setExitKey(.null);

    setState(.lobby, init.io);

    //rl.hideCursor();

    Board.board_texture = try rl.loadTexture("board.png");
    defer Board.board_texture.unload();

    const board_width = (build_options.SCREEN_WIDTH - SHOP_WIDTH) / 2;
    const p1_bounds = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = board_width,
        .height = build_options.SCREEN_HEIGHT,
    };
    const p2_bounds = rl.Rectangle{
        .x = board_width,
        .y = 0,
        .width = board_width,
        .height = build_options.SCREEN_HEIGHT,
    };

    const shop_bounds = rl.Rectangle{
        .x = build_options.SCREEN_WIDTH - SHOP_WIDTH,
        .y = 0,
        .width = SHOP_WIDTH,
        .height = build_options.SCREEN_HEIGHT,
    };

    const play_bounds = rl.Rectangle{
        .x = (build_options.SCREEN_WIDTH - PLAY_SIZE.x) * 0.5,
        .y = build_options.SCREEN_HEIGHT - PLAY_SIZE.y - BOTTOM_PAD,
        .width = PLAY_SIZE.x,
        .height = PLAY_SIZE.y,
    };

    const play_text_width: f32 = @floatFromInt(rl.measureText(
        "PLAY",
        play_bounds.height - 20,
    ));

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        transition_timer += dt / 2.0;
        transition_timer = @min(1.0, transition_timer);

        const done = p1_board.thrown_darts == Board.MAX_DARTS or
            p2_board.thrown_darts == Board.MAX_DARTS;

        {
            const mouse_pos = rl.getMousePosition();

            // update state
            switch (state) {
                .lobby => {
                    const render_mms_int = @as(u32, @intFromFloat(render_mms));
                    if (render_mms_int < mms) {
                        const diff: f32 = @floatFromInt(@divFloor(mms, 100) - @divFloor(render_mms_int, 100));

                        render_mms += (500 + 100 * diff) * dt;
                        render_mms = @min(render_mms, @as(f32, @floatFromInt(mms)));
                    }

                    if (render_mms_int > mms) {
                        const diff: f32 = @floatFromInt(@divFloor(render_mms_int, 100) - @divFloor(mms, 100));

                        render_mms -= @min(render_mms, (400 + 50 * diff) * dt);
                    }

                    {
                        // Play button logic
                        play.focused = rl.checkCollisionPointRec(mouse_pos, play_bounds);

                        if (rl.isMouseButtonReleased(.left)) {
                            if (play.focused and play.click) {
                                setState(.game, init.io);
                            }

                            play.click = false;
                        }

                        if (play.focused and rl.isMouseButtonPressed(.left))
                            play.click = true;
                    }
                },
                .game => {
                    p1_board.update(done, p1_bounds, dt);
                    p2_board.update(done, p2_bounds, dt);

                    if (!done) {
                        shop.update(&p1_board, shop_bounds, dt);
                        shop.update(&p2_board, shop_bounds, dt);
                    }
                },
                .end => {},
            }
        }

        {
            // draw frame
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(BG_COLOR);

            var y: i32 = 0;
            defer rl.drawText(@tagName(state), 0, y, 22, .white);

            switch (state) {
                .lobby => {
                    // play button
                    rl.drawRectangleRounded(play_bounds, 0.2, 10, if (play.disabled)
                        Shop.BUTTON_DISABLED_COLOR
                    else if (play.click)
                        Shop.BUTTON_CLICK_COLOR
                    else if (play.focused)
                        Shop.BUTTON_HOVER_COLOR
                    else
                        Shop.BUTTON_COLOR);

                    rl.drawText(
                        "PLAY",
                        @intFromFloat(play_bounds.x + @divFloor(play_bounds.width - play_text_width, 2)),
                        play_bounds.y + 10,
                        play_bounds.height - 20,
                        Shop.BUTTON_TEXT_COLOR,
                    );

                    // Debug draw
                    const visible_mms: u64 = @intFromFloat(render_mms);

                    const mms_text = std.fmt.bufPrintSentinel(
                        &fmt_buf,
                        "mms: {d}",
                        .{visible_mms},
                        0,
                    ) catch unreachable;

                    rl.drawText(mms_text, 0, y, 22, .white);
                    y += 22;

                    const rank_text = getRank(visible_mms, &fmt_buf);
                    rl.drawText(rank_text, 0, y, 22, .white);
                    y += 22;

                    const rank_score = @mod(visible_mms, 1000);
                    const xp_text = std.fmt.bufPrintSentinel(
                        &fmt_buf,
                        "xp: {d}",
                        .{rank_score},
                        0,
                    ) catch unreachable;
                    rl.drawText(xp_text, 0, y, 22, .white);
                    y += 22;

                    rl.drawRectangleRec(.{
                        .x = 0,
                        .y = @floatFromInt(y),
                        .width = 500,
                        .height = 50,
                    }, .gray);
                    rl.drawRectangleRec(.{
                        .x = 0,
                        .y = @floatFromInt(y),
                        .width = 500 * (@as(f32, @floatFromInt(rank_score)) / 1000.0),
                        .height = 50,
                    }, .white);
                    y += 50;
                },
                .game => {
                    // draw game
                    p1_board.draw(done, p1_bounds);
                    p2_board.draw(done, p2_bounds);
                    shop.draw(&p1_board, shop_bounds);

                    // debug
                    y += 100;
                    const p1_text = std.fmt.bufPrintSentinel(
                        &fmt_buf,
                        "p2 v:{d} {s}",
                        .{
                            p1_board.thrown_darts - p1_board.first_dart,
                            @tagName(p1_board.player),
                        },
                        0,
                    ) catch unreachable;

                    rl.drawText(p1_text, 0, y, 22, .white);
                    y += 22;

                    const p2_text = std.fmt.bufPrintSentinel(
                        &fmt_buf,
                        "p2 v:{d} {s}",
                        .{
                            p2_board.thrown_darts - p2_board.first_dart,
                            @tagName(p2_board.player),
                        },
                        0,
                    ) catch unreachable;

                    rl.drawText(p2_text, 0, y, 22, .white);
                    y += 22;
                },
                .end => {},
            }
        }
    }
}
