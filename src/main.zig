const std = @import("std");
const rl = @import("raylib");
const build_options = @import("build_options");

const Board = @import("Board.zig");
const Shop = @import("Shop.zig");

const BG_COLOR: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
const SHOP_WIDTH = 450;

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

const State = enum { title, game, end };
var state: State = undefined;

/// This is the percent progress of the current state transition
var transition_timer: f64 = 0.0;

var p1_board: Board = .{};
var p2_board: Board = .{};

var shop: Shop = .{};

pub fn setState(new_state: State, io: std.Io) void {
    _ = io;

    switch (new_state) {
        .title => {},
        .game => {
            p1_board = .{ .player = .user };
            // p1_board = .{ .player = .{ .ai = .{} } };
            p2_board = .{ .player = .{ .ai = .{} } };
        },
        .end => {},
    }

    state = new_state;
    transition_timer = 0.0;
}

pub fn main(init: std.process.Init) !void {
    rl.initWindow(build_options.SCREEN_WIDTH, build_options.SCREEN_HEIGHT, build_options.GAME_NAME);
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(60);
    rl.setExitKey(.null);

    setState(.title, init.io);

    //rl.hideCursor();

    Board.board_texture = try rl.loadTexture("board.png");
    defer Board.board_texture.unload();

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        transition_timer += dt / 2.0;
        transition_timer = @min(1.0, transition_timer);

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

        const done = p1_board.thrown_darts == Board.MAX_DARTS or
            p2_board.thrown_darts == Board.MAX_DARTS;

        {
            // update state
            switch (state) {
                .title => {
                    if (rl.isMouseButtonReleased(.left)) {
                        setState(.game, init.io);
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
            defer rl.drawText(@tagName(state), 0, 0, 22, .white);

            switch (state) {
                .title => {},
                .game => {
                    p1_board.draw(done, p1_bounds);
                    p2_board.draw(done, p2_bounds);
                    shop.draw(&p1_board, shop_bounds);
                },
                .end => {},
            }
        }
    }
}
