const rl = @import("raylib");
const std = @import("std");

const DEFAULT_COLOR: rl.Color = .{ .r = 0, .g = 148, .b = 121, .a = 255 };
const HOVER_COLOR: rl.Color = .{ .r = 9, .g = 219, .b = 47, .a = 255 };
const TEXT_COLOR: rl.Color = .black;

state: packed struct {
    focused: bool = false,
    active: bool = false,
} = .{},
bounds: rl.Rectangle,
text_size: i32,
text: std.ArrayList(u8),

const TextBox = @This();

pub fn update(self: *TextBox) void {
    const mouse_pos = rl.getMousePosition();

    self.state.focused = rl.checkCollisionPointRec(mouse_pos, self.bounds);
    if (rl.isMouseButtonPressed(.left))
        self.state.active = self.state.focused;

    if (self.state.active) {
        const ch: u8 = @intCast(@mod(rl.getCharPressed(), 256));
        if (ch != 0)
            self.text.appendBounded(ch) catch {};
    }

    if (rl.isKeyPressed(.backspace) or
        rl.isKeyPressedRepeat(.backspace))
        _ = self.text.pop();
}

pub fn draw(self: *const TextBox) void {
    rl.drawRectangleRounded(self.bounds, 0.2, 10, if (self.state.focused)
        HOVER_COLOR
    else
        DEFAULT_COLOR);

    var fmt_buf: [64]u8 = undefined;

    const text = std.fmt.bufPrintSentinel(
        &fmt_buf,
        "{s}{s}",
        .{ self.text.items, if (self.state.active) "_" else "" },
        0,
    ) catch unreachable;

    rl.drawText(
        text,
        @intFromFloat(self.bounds.x + 5),
        @intFromFloat(self.bounds.y + (self.bounds.height - @as(f32, @floatFromInt(self.text_size))) * 0.5),
        self.text_size,
        TEXT_COLOR,
    );
}

pub fn getText(self: *const TextBox) []const u8 {
    return self.text.items;
}
