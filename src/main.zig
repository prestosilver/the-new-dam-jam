const std = @import("std");
const rl = @import("raylib");
const build_options = @import("build_options");

var background: rl.Texture = undefined;

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

const BG_COLOR: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };

const State = enum { title, game, end };
var state: State = .title;

/// This is the percent progress of the current state transition
var transition_timer: f64 = 0.0;

pub fn setState(new_state: State, io: std.Io) void {
    _ = io;

    switch (new_state) {
        .title => {},
        .game => {},
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

    rl.hideCursor();

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();
        transition_timer += dt / 2.0;
        transition_timer = @min(1.0, transition_timer);

        {
            // update state
            switch (state) {
                .title => {},
                .game => {},
                .end => {},
            }
        }

        {
            // draw frame
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(BG_COLOR);
            rl.drawTexture(background, 0, 0, .white);

            switch (state) {
                .title => {},
                .game => {},
                .end => {},
            }
        }
    }
}
