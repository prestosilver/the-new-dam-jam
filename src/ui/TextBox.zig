const emasm = @import("../emasm.zig");
const rl = @import("raylib");
const std = @import("std");

const util = @import("../util.zig");

const DEFAULT_COLOR: rl.Color = .{ .r = 0, .g = 148, .b = 121, .a = 255 };
const HOVER_COLOR: rl.Color = .{ .r = 9, .g = 219, .b = 47, .a = 255 };
const TEXT_COLOR: rl.Color = .black;

state: packed struct {
    focused: bool = false,
    active: bool = false,
} = .{},
bounds: rl.Rectangle,
text_size: f32,
text: [12:0]u8 = std.mem.zeroes([12:0]u8),

const TextBox = @This();

pub fn update(self: *TextBox) void {
    const mouse_pos = rl.getMousePosition();

    self.state.focused = rl.checkCollisionPointRec(mouse_pos, self.bounds);
    if (rl.isMouseButtonPressed(.left)) {
        if (self.state.active == self.state.focused) return;
        self.state.active = self.state.focused;

        if (self.state.active) {
            emasm.EM_ASM("showKeyboard($0, 12)", .{
                &self.text,
            });
        } else emasm.EM_ASM("hideKeyboard()", .{
            &self.text,
        });
    }
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
        .{ self.getText(), if (self.state.active) "_" else "" },
        0,
    ) catch unreachable;

    rl.drawTextEx(
        util.font,
        text,
        .{
            .x = self.bounds.x + 10,
            .y = self.bounds.y + (self.bounds.height - self.text_size) * 0.5,
        },
        self.text_size,
        0,
        TEXT_COLOR,
    );
}

pub fn getText(self: *const TextBox) []const u8 {
    return std.mem.span(@as([*:0]const u8, &self.text));
}
