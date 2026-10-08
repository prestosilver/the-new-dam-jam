const rl = @import("raylib");

const util = @import("../util.zig");

pub const BUTTON_COLOR: rl.Color = .{ .r = 0, .g = 148, .b = 121, .a = 255 };
pub const BUTTON_HOVER_COLOR: rl.Color = .{ .r = 9, .g = 219, .b = 47, .a = 255 };
pub const BUTTON_CLICK_COLOR: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
pub const BUTTON_DISABLED_COLOR: rl.Color = .{ .r = 255, .g = 0, .b = 0, .a = 255 };

pub const TEXT_COLOR: rl.Color = .{ .r = 0, .g = 55, .b = 110, .a = 255 };

state: packed struct {
    focused: bool = false,
    clicked: bool = false,
    disabled: bool = false,
    pressed: bool = false,
} = .{},
bounds: rl.Rectangle,
text_size: f32,

const Button = @This();

pub fn update(self: *Button) void {
    const mouse_pos = rl.getMousePosition();

    self.state.focused = rl.checkCollisionPointRec(mouse_pos, self.bounds);
    self.state.pressed = false;

    if (self.state.disabled) {
        self.state.focused = false;
        self.state.clicked = false;

        return;
    }

    if (rl.isMouseButtonReleased(.left)) {
        if (self.state.focused and self.state.clicked)
            self.state.pressed = true;

        self.state.clicked = false;
    }

    if (self.state.focused and rl.isMouseButtonPressed(.left))
        self.state.clicked = true;
}

pub fn isPressed(self: *const Button) bool {
    return self.state.pressed;
}

pub fn draw(self: *const Button, text: [:0]const u8) void {
    const text_width: f32 = rl.measureTextEx(util.font, text, self.text_size, 0).x;

    rl.drawRectangleRounded(self.bounds, 0.2, 10, if (self.state.disabled)
        BUTTON_DISABLED_COLOR
    else if (self.state.clicked)
        BUTTON_CLICK_COLOR
    else if (self.state.focused)
        BUTTON_HOVER_COLOR
    else
        BUTTON_COLOR);

    rl.drawTextEx(
        util.font,
        text,
        .{
            .x = self.bounds.x + (self.bounds.width - text_width) * 0.5,
            .y = self.bounds.y + (self.bounds.height - self.text_size) * 0.5,
        },
        self.text_size,
        0,
        TEXT_COLOR,
    );
}
