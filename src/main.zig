const std = @import("std");
const rl = @import("raylib");
const build_options = @import("build_options");

const Button = @import("Button.zig");
const Board = @import("Board.zig");
const Shop = @import("Shop.zig");

const emasm = @import("emasm.zig");

const RANKS = [_][:0]const u8{ "F", "D-", "D", "D+", "C-", "C", "C+", "B-", "B", "B+", "A-", "A", "A+", "A++", "S-", "S", "S+", "SS", "SS+", "SSS+" };
const BG_COLOR: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
const PLAY_SIZE: rl.Vector2 = .{ .x = 500, .y = 150 };
const PRACTICE_SIZE: rl.Vector2 = .{ .x = 250, .y = 75 };
const P2_SIZE = 150;
const SHOP_WIDTH = 450;
const UI_PAD = 50;
const POLL_INTERVAL = 0.2;

fn customLogFn(
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

const std_options: std.Options = .{
    // Fix a emscripten bug in 0.16 that breaks std.defaultLog
    .logFn = customLogFn,
};

const State = enum { lobby, game, end };
var state: State = undefined;

const debug_text: bool = @import("builtin").mode == .Debug;
const debug_web: bool = @import("builtin").mode == .Debug;

/// This is the percent progress of the current state transition
var transition_timer: f64 = 0.0;

// The lobbys state
var lobby_state: enum { lobby, ready, matched, waiting } = .lobby;

var p1_board: Board = .{};
var p2_board: Board = .{};

var shop: Shop = .{};
var mms: u32 = 0;
var render_mms: f32 = 0;
var wait_timer: f32 = 0.0;
var poll_timer: f32 = 0.0;
var game_begin: f32 = 3.0;

var practice_mode: bool = false;

var fmt_buf: [64]u8 = undefined;
var fmt_buf_two: [64]u8 = undefined;

fn setState(new_state: State) void {
    switch (new_state) {
        .lobby => {
            lobby_state = .lobby;
        },
        .game => {
            game_begin = 3.0;

            p1_board = .{ .player = .user, .font_size = 66 };
            if (practice_mode) {
                p2_board = .{
                    .player = .{ .ai = .{
                        .darts_per_second = 10,
                        .upgrade_rate = 1,
                    } },
                    .font_size = 25,
                };
            } else {
                p2_board = .{
                    .player = .web,
                    .font_size = 25,
                };
            }
        },
        .end => {},
    }

    state = new_state;
    transition_timer = 0.0;
}

fn getRank(score: u64, buf: []u8) [:0]const u8 {
    const idx = @divFloor(score, 1000);

    if (idx < RANKS.len)
        return RANKS[@intCast(idx)];

    return std.fmt.bufPrintSentinel(
        buf,
        RANKS[RANKS.len - 1] ++ "{d}",
        .{idx - RANKS.len + 1},
        0,
    ) catch unreachable;
}

fn playClick() void {
    switch (lobby_state) {
        .lobby => {
            lobby_state = .ready;
            wait_timer = 0.0;

            // queue match
            if (!debug_web) {
                emasm.EM_ASM("join_match()", .{});
            }
        },
        .ready => {
            lobby_state = .lobby;
            // cancel match
            if (!debug_web) {
                emasm.EM_ASM("cancel_match()", .{});
            }
        },
        .matched => {
            lobby_state = .waiting;
            wait_timer = 0.0;

            if (!debug_web) {
                emasm.EM_ASM("ready_match()", .{});
            }
        },
        .waiting => {},
    }
}

pub fn main(_: std.process.Init) !void {
    rl.initWindow(build_options.SCREEN_WIDTH, build_options.SCREEN_HEIGHT, build_options.GAME_NAME);
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(60);
    rl.setExitKey(.null);

    setState(.lobby);

    mms = @intCast(emasm.EM_ASM_INT("return get_score();", .{}));
    render_mms = @floatFromInt(mms);

    //rl.hideCursor();

    Board.board_texture = try rl.loadTexture("board.png");
    defer Board.board_texture.unload();

    Board.background_texture = try rl.loadTexture("background.png");
    defer Board.background_texture.unload();

    const board_width = (build_options.SCREEN_WIDTH - SHOP_WIDTH);
    const p1_bounds = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = board_width,
        .height = build_options.SCREEN_HEIGHT,
    };
    const p2_bounds = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = P2_SIZE,
        .height = P2_SIZE,
    };

    const shop_bounds = rl.Rectangle{
        .x = build_options.SCREEN_WIDTH - SHOP_WIDTH,
        .y = 0,
        .width = SHOP_WIDTH,
        .height = build_options.SCREEN_HEIGHT,
    };

    var play_button: Button = .{
        .bounds = .{
            .x = (build_options.SCREEN_WIDTH - PLAY_SIZE.x) * 0.5,
            .y = build_options.SCREEN_HEIGHT - PLAY_SIZE.y - UI_PAD,
            .width = PLAY_SIZE.x,
            .height = PLAY_SIZE.y,
        },
        .text_size = PLAY_SIZE.y - 20,
    };

    var practice_button: Button = .{
        .bounds = .{
            .x = build_options.SCREEN_WIDTH - UI_PAD - PRACTICE_SIZE.x,
            .y = build_options.SCREEN_HEIGHT - UI_PAD - PRACTICE_SIZE.y,
            .width = PRACTICE_SIZE.x,
            .height = PRACTICE_SIZE.y,
        },
        .text_size = PRACTICE_SIZE.y - 20,
    };

    shop.init(shop_bounds);

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        transition_timer += dt / 2.0;
        transition_timer = @min(1.0, transition_timer);

        const done = p1_board.thrown_darts == Board.MAX_DARTS or
            p2_board.thrown_darts == Board.MAX_DARTS;

        update: {
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
                        play_button.update();
                        practice_button.update();

                        if (play_button.isPressed()) {
                            playClick();
                        }

                        if (practice_button.isPressed()) {
                            practice_mode = !practice_mode;
                        }
                    }

                    if (lobby_state == .ready or
                        lobby_state == .waiting)
                    {
                        wait_timer += dt;
                        poll_timer += dt;

                        if (poll_timer > POLL_INTERVAL) {
                            if (lobby_state == .ready and
                                emasm.EM_ASM_INT("return poll_match();", .{}) == 1)
                                lobby_state = .matched;

                            if (lobby_state == .waiting and
                                emasm.EM_ASM_INT("return poll_ready();", .{}) == 1)
                                setState(.game);

                            poll_timer = 0.0;
                        }
                    }

                    if (practice_mode) {
                        if (lobby_state == .ready)
                            lobby_state = .matched;
                        if (lobby_state == .waiting)
                            setState(.game);
                    }

                    if (!debug_web) break :update;

                    // debug update
                    if (lobby_state == .ready) {
                        if (rl.isKeyPressed(.b)) {
                            lobby_state = .matched;
                        }
                    } else if (lobby_state == .waiting) {
                        if (rl.isKeyPressed(.b)) {
                            setState(.game);
                        }
                    }
                },
                .game => {
                    if (game_begin > 0) {
                        game_begin -= dt;

                        break :update;
                    }

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

        draw: {
            // draw frame
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(BG_COLOR);

            var y: i32 = 0;
            defer if (debug_text) {
                const state_text = std.fmt.bufPrintSentinel(
                    &fmt_buf,
                    "state v: {s} f: {}",
                    .{ @tagName(state), rl.getFPS() },
                    0,
                ) catch unreachable;
                rl.drawText(state_text, 0, y, 22, .white);
            };

            switch (state) {
                .lobby => {
                    // play button
                    play_button.state.disabled = lobby_state == .waiting;
                    const play_text = switch (lobby_state) {
                        .lobby => "Ready",
                        .ready => "Cancel",
                        .matched => "Begin",
                        .waiting => "Waiting",
                    };
                    play_button.draw(play_text);

                    const practice_text = if (practice_mode) "Practice" else "PVP";
                    practice_button.draw(practice_text);

                    if (!debug_text) break :draw;

                    // Debug draw
                    const visible_mms: u64 = @intFromFloat(render_mms);

                    const rank_score = @mod(visible_mms, 1000);
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

                    const lobby_state_text = std.fmt.bufPrintSentinel(
                        &fmt_buf,
                        "lobby s: {s} w: {d}",
                        .{ @tagName(lobby_state), @as(i32, @intFromFloat(wait_timer)) },
                        0,
                    ) catch unreachable;
                    rl.drawText(lobby_state_text, 0, y, 22, .white);
                    y += 22;

                    const rank_text = getRank(visible_mms, &fmt_buf_two);
                    const mms_text = std.fmt.bufPrintSentinel(
                        &fmt_buf,
                        "score r: {s} v: {d} x: {d}",
                        .{ rank_text, visible_mms, rank_score },
                        0,
                    ) catch unreachable;
                    rl.drawText(mms_text, 0, y, 22, .white);
                    y += 22;
                },
                .game => {
                    // draw game
                    p1_board.draw(done, p1_bounds);
                    p2_board.draw(done, p2_bounds);
                    shop.draw(&p1_board, shop_bounds);

                    if (game_begin > 0) {
                        const countdown_text = std.fmt.bufPrintSentinel(
                            &fmt_buf,
                            "{d}",
                            .{
                                @as(i32, @intFromFloat(@ceil(game_begin))),
                            },
                            0,
                        ) catch unreachable;

                        const text_width = rl.measureText(countdown_text, 200);

                        rl.drawText(
                            countdown_text,
                            @divTrunc(build_options.SCREEN_WIDTH - text_width, 2),
                            @divTrunc(build_options.SCREEN_HEIGHT - 200, 2),
                            200,
                            .white,
                        );
                    }

                    if (!debug_text) break :draw;

                    // debug
                    y += 100;
                    const p1_text = std.fmt.bufPrintSentinel(
                        &fmt_buf,
                        "p1 v:{d} {s}",
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

                    if (game_begin > 0) {
                        const begin_text = std.fmt.bufPrintSentinel(
                            &fmt_buf,
                            "timer {d}",
                            .{@as(i32, @intFromFloat(@ceil(game_begin)))},
                            0,
                        ) catch unreachable;

                        rl.drawText(begin_text, 0, y, 22, .white);
                        y += 22;
                    }
                },
                .end => {},
            }
        }
    }
}
