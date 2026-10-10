const std = @import("std");
const rl = @import("raylib");
const build_options = @import("build_options");

const Leaderboard = @import("ui/Leaderboard.zig");
const PasswordBox = @import("ui/PasswordBox.zig");
const TextBox = @import("ui/TextBox.zig");
const Button = @import("ui/Button.zig");
const Bar = @import("ui/Bar.zig");

const Board = @import("Board.zig");
const Shop = @import("Shop.zig");

const util = @import("util.zig");

const emasm = @import("emasm.zig");

const LEADERBOARD_LEN = 10;

const BG_COLOR: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
const USER_SIZE: rl.Vector2 = .{ .x = 700, .y = 100 };
const PLAY_SIZE: rl.Vector2 = .{ .x = 500, .y = 150 };
const LOGIN_SIZE: rl.Vector2 = .{ .x = 400, .y = 100 };
const PASS_SIZE: rl.Vector2 = .{ .x = 100, .y = 200 };
const CONTINUE_SIZE: rl.Vector2 = .{ .x = 550, .y = 150 };
const PRACTICE_SIZE: rl.Vector2 = .{ .x = 250, .y = 75 };
const LEVEL_BAR_SIZE: rl.Vector2 = .{ .x = 700, .y = 96 };
const P2_SIZE = 150;
const SHOP_WIDTH = 450;
const UI_PAD = 50;
const POLL_INTERVAL = 0.2;

const LEADERBOARD_HEIGHT = (build_options.SCREEN_HEIGHT - UI_PAD - PLAY_SIZE.y) / @as(f32, @floatFromInt(LEADERBOARD_LEN));

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

const State = enum { loading, login, lobby, game, end, leaderboard };
var state: State = .loading;
var last_state: State = .loading;

const debug_text: bool = @import("builtin").mode == .Debug;
const debug_web: bool = @import("builtin").mode == .Debug;

/// This is the percent progress of the current state transition
var transition_timer: f32 = 0.0;

// The lobbys state
var lobby_state: enum { lobby, ready, matched, waiting } = .lobby;

var p1_board: Board = .{ .name = "" };
var p2_board: Board = .{ .name = "" };

var shop: Shop = .{};
var mmr_value: u32 = 0;
var wait_timer: f32 = 0.0;
var poll_timer: f32 = 0.0;
var game_begin: f32 = 3.0;

var practice_mode: bool = false;

var fmt_buf: [64]u8 = undefined;
var user_buf: [12:0]u8 = std.mem.zeroes([12:0]u8);

var opponent_buf: [12:0]u8 = std.mem.zeroes([12:0]u8);

var name_buf: [12]u8 = undefined;
var pass_buf: [4]u8 = "aaaa".*; // A serializable char

var password_boxes: [4]PasswordBox = undefined;
var login_box: TextBox = undefined;

var login_button: Button = undefined;
var play_button: Button = undefined;
var continue_button: Button = undefined;
var practice_button: Button = undefined;
var back_button: Button = undefined;
var next_button: Button = undefined;
var prev_button: Button = undefined;
var leaderboard_button: Button = undefined;
var leaderboard_page: i32 = 0;

var p1_bounds: rl.Rectangle = undefined;
var p2_bounds: rl.Rectangle = undefined;
var shop_bounds: rl.Rectangle = undefined;

var game_started: bool = false;

var leaderboard_entries: [LEADERBOARD_LEN + 1]Leaderboard.Entry = [_]Leaderboard.Entry{.{}} ** (LEADERBOARD_LEN + 1);
var leaderboard: [LEADERBOARD_LEN + 1]Leaderboard = undefined;

var level_bar: Bar = undefined;

fn login(name: ?[]const u8, password: ?[4]u8) bool {
    if (name == null or password == null) {
        if (@import("builtin").target.os.tag == .emscripten) {
            return emasm.EM_ASM_INT(
                \\return try_login(null, null);
            , .{}) != 0;
        } else {
            @memcpy(user_buf[0..5], "TEST\x00");
            return true;
        }
    } else {
        if (@import("builtin").target.os.tag == .emscripten) {
            const tmp_password = password.?;
            return emasm.EM_ASM_INT(
                \\const decoder = new TextDecoder();
                \\const nameBytes = new Uint8Array(wasmMemory.buffer, $1, $2);
                \\const passBytes = new Uint8Array(wasmMemory.buffer, $3, 4);
                \\const name = decoder.decode(nameBytes);
                \\const pass = decoder.decode(passBytes);
                \\return try_login(name, pass);
            , .{
                @as(*const anyopaque, &user_buf),
                @as(*const anyopaque, name.?.ptr),
                name.?.len,
                @as(*const anyopaque, &tmp_password),
            }) != 0;
        } else {
            @memcpy(user_buf[0..5], "TEST\x00");
            return true;
        }
    }

    unreachable;
}

fn setState(new_state: State) void {
    switch (new_state) {
        .loading => {},
        .login => {},
        .lobby => {
            lobby_state = .lobby;
        },
        .game => {
            game_started = true;
            game_begin = 3.0;

            p1_board = .{
                .player = .{ .user = .{} },
                .font_size = 66,
                .name = std.mem.span(@as([*:0]const u8, &user_buf)),
            };
            if (practice_mode) {
                p2_board = .{
                    .player = .{ .ai = .{
                        .darts_per_second = 10,
                        .upgrade_rate = 1,
                    } },
                    .font_size = 25,
                    .name = "Albert Bot",
                };
            } else {
                p2_board = .{
                    .player = .{ .web = .{} },
                    .font_size = 25,
                    .name = std.mem.span(@as([*:0]const u8, &opponent_buf)),
                };
            }
        },
        .end => {},
        .leaderboard => {
            leaderboard_page = 0;
            emasm.EM_ASM("leaderboard_page($0, $1)", .{
                LEADERBOARD_LEN * leaderboard_page,
                @as(i32, LEADERBOARD_LEN + 1),
            });
        },
    }

    last_state = state;
    state = new_state;
    if (last_state != state)
        transition_timer = 0.0;
}

fn playClick() void {
    switch (lobby_state) {
        .lobby => {
            lobby_state = .ready;
            wait_timer = 0.0;

            // queue match
            emasm.EM_ASM("join_match()", .{});
        },
        .ready => {
            lobby_state = .lobby;
            // cancel match
            emasm.EM_ASM("cancel_match()", .{});
        },
        .matched => {
            lobby_state = .waiting;
            wait_timer = 0.0;

            emasm.EM_ASM("ready_match()", .{});
        },
        .waiting => {},
    }
}

fn draw(draw_state: State, game_done: bool, offset: rl.Vector2) void {
    rl.beginMode2D(.{
        .offset = offset,
        .target = .{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1.0,
    });
    defer rl.endMode2D();

    // draw frame

    var y: i32 = 0;
    defer if (debug_text) {
        const state_text = std.fmt.bufPrintSentinel(
            &fmt_buf,
            "draw_state v: {s} f: {}",
            .{ @tagName(state), rl.getFPS() },
            0,
        ) catch unreachable;
        rl.drawText(state_text, 0, y, 22, .white);
    };

    switch (draw_state) {
        .loading => {},
        .login => {
            login_button.draw("Login");
            login_box.draw();

            for (&password_boxes) |*box|
                box.draw();
        },
        .lobby => {
            // play button
            leaderboard_button.state.disabled = lobby_state != .lobby;
            practice_button.state.disabled = lobby_state != .lobby;
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
            leaderboard_button.draw("Leaders");
            level_bar.draw();

            if (!debug_text) return;

            // Debug draw
            const rank_score = @mod(mmr_value, util.RANK_STEP);
            rl.drawRectangleRec(.{
                .x = 0,
                .y = @floatFromInt(y),
                .width = 500,
                .height = 50,
            }, .gray);
            rl.drawRectangleRec(.{
                .x = 0,
                .y = @floatFromInt(y),
                .width = 500 * (@as(f32, @floatFromInt(rank_score)) / util.RANK_STEP),
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

            const user_state_text = std.fmt.bufPrintSentinel(
                &fmt_buf,
                "user v: {s}",
                .{user_buf},
                0,
            ) catch unreachable;
            rl.drawText(user_state_text, 0, y, 22, .white);
            y += 22;

            const rank_text = util.getRank(mmr_value);
            const mmr_text = std.fmt.bufPrintSentinel(
                &fmt_buf,
                "score r: {s} v: {d} x: {d}",
                .{ rank_text, mmr_value, rank_score },
                0,
            ) catch unreachable;
            rl.drawText(mmr_text, 0, y, 22, .white);
            y += 22;
        },
        .game => {
            // draw game
            p1_board.draw(game_done, p1_bounds);
            p2_board.draw(game_done, p2_bounds);
            shop.draw(&p1_board, shop_bounds);

            if (game_started and game_done) {
                game_started = false;
                transition_timer = 0.0;
            }

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

            if (game_done) {
                rl.drawRectangleRec(.{
                    .x = 0,
                    .y = 0,
                    .width = build_options.SCREEN_WIDTH,
                    .height = build_options.SCREEN_HEIGHT,
                }, .alpha(.black, transition_timer));

                continue_button.draw("Continue");
            }

            if (!debug_text) return;

            // debug
            y += P2_SIZE;
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
        .end => {
            continue_button.draw("Return");
            level_bar.draw();
        },
        .leaderboard => {
            for (leaderboard[0 .. leaderboard.len - 1]) |entry|
                entry.draw();

            back_button.draw("Back");
            next_button.draw("Next");
            prev_button.draw("Prev");
        },
    }
}

pub fn main(_: std.process.Init) !void {
    rl.initWindow(build_options.SCREEN_WIDTH, build_options.SCREEN_HEIGHT, build_options.GAME_NAME);
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(60);
    rl.setExitKey(.null);

    setState(.login);

    transition_timer = 1.0;

    //rl.hideCursor();

    Board.dart_texture = try .init("dart.png");
    defer Board.dart_texture.unload();

    Board.board_texture = try .init("board.png");
    defer Board.board_texture.unload();

    util.font = try .initEx("HopeGold.ttf", 128, null);
    defer util.font.unload();

    Board.background_texture = try .init("background.png");
    defer Board.background_texture.unload();

    const board_width = (build_options.SCREEN_WIDTH - SHOP_WIDTH);
    p1_bounds = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = board_width,
        .height = build_options.SCREEN_HEIGHT,
    };
    p2_bounds = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = P2_SIZE,
        .height = P2_SIZE,
    };

    shop_bounds = rl.Rectangle{
        .x = build_options.SCREEN_WIDTH - SHOP_WIDTH,
        .y = 0,
        .width = SHOP_WIDTH,
        .height = build_options.SCREEN_HEIGHT,
    };

    for (&password_boxes, &pass_buf, 0..) |*box, *char, idx| {
        box.* = .{
            .bounds = .{
                .x = @as(f32, @floatFromInt(build_options.SCREEN_WIDTH)) / 2 - PASS_SIZE.x * 2 + (PASS_SIZE.x * @as(f32, @floatFromInt(idx))),
                .y = @floatFromInt(10 + build_options.SCREEN_HEIGHT / 2),
                .width = PASS_SIZE.x,
                .height = PASS_SIZE.y,
            },
            .text_size = USER_SIZE.y - 20,
            .char = char,
        };
    }

    login_box = .{
        .bounds = .{
            .x = (build_options.SCREEN_WIDTH - USER_SIZE.x) * 0.5,
            .y = (build_options.SCREEN_HEIGHT) * 0.5 - USER_SIZE.y,
            .width = USER_SIZE.x,
            .height = USER_SIZE.y,
        },
        .text_size = USER_SIZE.y - 20,
        .text = .initBuffer(&name_buf),
    };

    login_button = .{
        .bounds = .{
            .x = (build_options.SCREEN_WIDTH - LOGIN_SIZE.x) * 0.5,
            .y = build_options.SCREEN_HEIGHT - LOGIN_SIZE.y - UI_PAD,
            .width = LOGIN_SIZE.x,
            .height = LOGIN_SIZE.y,
        },
        .text_size = LOGIN_SIZE.y - 20,
    };

    play_button = .{
        .bounds = .{
            .x = (build_options.SCREEN_WIDTH - PLAY_SIZE.x) * 0.5,
            .y = build_options.SCREEN_HEIGHT - PLAY_SIZE.y - UI_PAD,
            .width = PLAY_SIZE.x,
            .height = PLAY_SIZE.y,
        },
        .text_size = PLAY_SIZE.y - 20,
    };

    level_bar = .{
        .bounds = .{
            .x = (build_options.SCREEN_WIDTH - LEVEL_BAR_SIZE.x) * 0.5,
            .y = (build_options.SCREEN_HEIGHT - LEVEL_BAR_SIZE.y) * 0.5,
            .width = LEVEL_BAR_SIZE.x,
            .height = LEVEL_BAR_SIZE.y,
        },
        .target = @floatFromInt(mmr_value),
        .value = @floatFromInt(mmr_value),
        .step = util.RANK_STEP,
    };

    continue_button = .{
        .bounds = .{
            .x = (build_options.SCREEN_WIDTH - CONTINUE_SIZE.x) * 0.5,
            .y = build_options.SCREEN_HEIGHT - CONTINUE_SIZE.y - UI_PAD,
            .width = CONTINUE_SIZE.x,
            .height = CONTINUE_SIZE.y,
        },
        .text_size = CONTINUE_SIZE.y - 20,
    };

    practice_button = .{
        .bounds = .{
            .x = build_options.SCREEN_WIDTH - UI_PAD - PRACTICE_SIZE.x,
            .y = build_options.SCREEN_HEIGHT - UI_PAD - PRACTICE_SIZE.y,
            .width = PRACTICE_SIZE.x,
            .height = PRACTICE_SIZE.y,
        },
        .text_size = PRACTICE_SIZE.y - 20,
    };

    back_button = .{
        .bounds = .{
            .x = build_options.SCREEN_WIDTH - UI_PAD - PRACTICE_SIZE.x,
            .y = build_options.SCREEN_HEIGHT - 1 * (UI_PAD + PRACTICE_SIZE.y),
            .width = PRACTICE_SIZE.x,
            .height = PRACTICE_SIZE.y,
        },
        .text_size = PRACTICE_SIZE.y - 20,
    };

    next_button = .{
        .bounds = .{
            .x = build_options.SCREEN_WIDTH - 2 * (UI_PAD + PRACTICE_SIZE.x),
            .y = build_options.SCREEN_HEIGHT - 1 * (UI_PAD + PRACTICE_SIZE.y),
            .width = PRACTICE_SIZE.x,
            .height = PRACTICE_SIZE.y,
        },
        .text_size = PRACTICE_SIZE.y - 20,
    };

    prev_button = .{
        .bounds = .{
            .x = UI_PAD,
            .y = build_options.SCREEN_HEIGHT - 1 * (UI_PAD + PRACTICE_SIZE.y),
            .width = PRACTICE_SIZE.x,
            .height = PRACTICE_SIZE.y,
        },
        .text_size = PRACTICE_SIZE.y - 20,
    };

    leaderboard_button = .{
        .bounds = .{
            .x = UI_PAD,
            .y = build_options.SCREEN_HEIGHT - UI_PAD - PRACTICE_SIZE.y,
            .width = PRACTICE_SIZE.x,
            .height = PRACTICE_SIZE.y,
        },
        .text_size = PRACTICE_SIZE.y - 20,
    };

    for (&leaderboard, &leaderboard_entries, 0..) |*render, *value, idx| {
        render.* = .{
            .bounds = .{
                .x = UI_PAD,
                .y = UI_PAD + LEADERBOARD_HEIGHT * @as(f32, @floatFromInt(idx)),
                .width = build_options.SCREEN_WIDTH - PRACTICE_SIZE.x,
                .height = LEADERBOARD_HEIGHT - 5,
            },
            .entry = value,
        };
    }

    shop.init(shop_bounds);

    // Register the set_leaderboard function
    emasm.EM_ASM(
        \\set_leaderboard = function (idx, name, mmr) {
        \\    if (name.length > $6) throw new Error("name " + name + " is too long for set_leaderboard");
        \\    const tmp_name = name + "\0";
        \\    const object_start = $0 + idx * $1;
        \\    const encoder = new TextEncoder();
        \\    const stringBytes = encoder.encode(tmp_name);
        \\    const entryBytes = new Uint8Array(wasmMemory.buffer, object_start + $3, stringBytes.length);
        \\    entryBytes.set(stringBytes);
        \\    const view = new DataView(wasmMemory.buffer);
        \\    view.setInt32(object_start + $4, mmr, true); 
        \\    view.setUint8(object_start + $2, 1, true); 
        \\}
        \\unset_leaderboard = function (idx) {
        \\    if (name.length > $6) throw new Error("name " + name + " is too long for set_leaderboard");
        \\    const object_start = $0 + idx * $1;
        \\    const view = new DataView(wasmMemory.buffer);
        \\    view.setUint8(object_start + $2, 0, true); 
        \\}
    , .{
        &leaderboard_entries,
        @intFromPtr(&leaderboard_entries[1]) - @intFromPtr(&leaderboard_entries[0]),
        @as(i32, @intCast(@offsetOf(Leaderboard.Entry, "valid"))), // $2
        @as(i32, @intCast(@offsetOf(Leaderboard.Entry, "name"))), // $3
        @as(i32, @intCast(@offsetOf(Leaderboard.Entry, "mmr"))), // $4
        @as(i32, LEADERBOARD_LEN + 1), // $5
    });

    // set_username function
    emasm.EM_ASM(
        \\set_username = function (name) {
        \\    if (name.length > 12) throw new Error("opponent name " + name + " is too long for set_leaderboard");
        \\    const tmp_name = name + "\0";
        \\    const encoder = new TextEncoder();
        \\    const stringBytes = encoder.encode(tmp_name);
        \\    const entryBytes = new Uint8Array(wasmMemory.buffer, $0, stringBytes.length);
        \\    entryBytes.set(stringBytes);
        \\}
    , .{
        @intFromPtr(&user_buf), // $0
    });

    // set_opponent function
    emasm.EM_ASM(
        \\set_opponent = function (name) {
        \\    if (name.length > 12) throw new Error("opponent name " + name + " is too long for set_leaderboard");
        \\    const tmp_name = name + "\0";
        \\    const encoder = new TextEncoder();
        \\    const stringBytes = encoder.encode(tmp_name);
        \\    const entryBytes = new Uint8Array(wasmMemory.buffer, $0, stringBytes.length);
        \\    entryBytes.set(stringBytes);
        \\}
    , .{
        @intFromPtr(&opponent_buf), // $0
    });

    // set_score function
    emasm.EM_ASM(
        \\set_score = function (score) {
        \\    if (score == -1) return;
        \\    const view = new DataView(wasmMemory.buffer);
        \\    view.setInt32($0, score, true); 
        \\}
    , .{
        @intFromPtr(&mmr_value), // $0
    });

    _ = login(null, null);

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        transition_timer += dt * 4.0;
        transition_timer = @min(1.0, transition_timer);

        const game_done = p1_board.processed_darts == Board.MAX_DARTS or
            p2_board.processed_darts == Board.MAX_DARTS;

        update: {
            // update state
            switch (state) {
                .loading => {},
                .login => {
                    login_button.update();
                    login_box.update();
                    for (&password_boxes) |*box|
                        box.update();

                    if (login_button.isPressed() or rl.isKeyPressed(.enter)) {
                        _ = login(login_box.getText(), pass_buf);
                    }

                    poll_timer += dt;
                    if (poll_timer > POLL_INTERVAL) {
                        if (user_buf[0] != 0)
                            setState(.lobby);

                        poll_timer = 0.0;
                    }
                },
                .lobby => {
                    {
                        level_bar.target = @floatFromInt(mmr_value);

                        // Play button logic
                        play_button.update();
                        practice_button.update();
                        leaderboard_button.update();
                        level_bar.update(dt);

                        if (play_button.isPressed())
                            playClick();

                        if (practice_button.isPressed())
                            practice_mode = !practice_mode;

                        if (leaderboard_button.isPressed())
                            setState(.leaderboard);
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

                    if (!debug_web) break :update;
                },
                .game => {
                    if (game_done) {
                        continue_button.update();
                        if (continue_button.isPressed())
                            setState(.end);
                    }

                    if (game_begin > 0) {
                        game_begin -= dt;

                        break :update;
                    }

                    if (debug_web) {
                        if (rl.isKeyPressed(.e))
                            p1_board.processed_darts = Board.MAX_DARTS;
                    }

                    p1_board.update(game_done, p1_bounds, dt);
                    p2_board.update(game_done, p2_bounds, dt);

                    shop.update(game_done, &p1_board, shop_bounds, dt);
                    shop.update(game_done, &p2_board, shop_bounds, dt);
                },
                .end => {
                    level_bar.target = @floatFromInt(mmr_value);

                    level_bar.update(dt);
                    continue_button.update();
                    if (continue_button.isPressed())
                        setState(.lobby);
                },
                .leaderboard => {
                    prev_button.state.disabled = !(leaderboard_page > 0);
                    next_button.state.disabled = !(leaderboard_entries[LEADERBOARD_LEN].valid);

                    back_button.update();
                    next_button.update();
                    prev_button.update();

                    if (back_button.isPressed())
                        setState(.lobby);

                    if (next_button.isPressed()) {
                        leaderboard_page += 1;

                        emasm.EM_ASM("leaderboard_page($0, $1)", .{
                            LEADERBOARD_LEN * leaderboard_page,
                            @as(i32, LEADERBOARD_LEN + 1),
                        });
                    }

                    if (prev_button.isPressed()) {
                        leaderboard_page -= 1;

                        emasm.EM_ASM("leaderboard_page($0, $1)", .{
                            LEADERBOARD_LEN * leaderboard_page,
                            @as(i32, LEADERBOARD_LEN + 1),
                        });
                    }
                },
            }
        }
        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(BG_COLOR);

            if (!(state == .game and !game_started and game_done) and transition_timer < 1.0) {
                const last_position: ?rl.Vector2 = switch (state) {
                    .lobby => if (last_state == .end) .{
                        .x = build_options.SCREEN_WIDTH * transition_timer,
                        .y = 0,
                    } else .{
                        .x = -build_options.SCREEN_WIDTH * transition_timer,
                        .y = 0,
                    },
                    .game => .{
                        .x = 0,
                        .y = build_options.SCREEN_HEIGHT * transition_timer,
                    },
                    .leaderboard => .{
                        .x = build_options.SCREEN_WIDTH * transition_timer,
                        .y = 0,
                    },
                    else => null,
                };
                const current_position: rl.Vector2 = switch (state) {
                    .lobby => if (last_state == .end) .{
                        .x = build_options.SCREEN_WIDTH * transition_timer - build_options.SCREEN_WIDTH,
                        .y = 0,
                    } else .{
                        .x = build_options.SCREEN_WIDTH - build_options.SCREEN_WIDTH * transition_timer,
                        .y = 0,
                    },
                    .game => .{
                        .x = 0,
                        .y = build_options.SCREEN_HEIGHT * transition_timer - build_options.SCREEN_HEIGHT,
                    },
                    .leaderboard => .{
                        .x = build_options.SCREEN_WIDTH * transition_timer - build_options.SCREEN_WIDTH,
                        .y = 0,
                    },
                    else => .{ .x = 0, .y = 0 },
                };

                if (last_position) |last|
                    draw(last_state, game_done, last);

                draw(state, game_done, current_position);
            } else {
                draw(state, game_done, .{ .x = 0, .y = 0 });
            }
        }
    }
}
