const rl = @import("raylib");
const std = @import("std");

const PasswordBox = @This();

const BUTTON_COLOR: rl.Color = .{ .r = 0, .g = 148, .b = 121, .a = 255 };
const BUTTON_HOVER_COLOR: rl.Color = .{ .r = 9, .g = 219, .b = 47, .a = 255 };
const BUTTON_CLICK_COLOR: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
const BUTTON_DISABLED_COLOR: rl.Color = .{ .r = 255, .g = 0, .b = 0, .a = 255 };

const TEXT_COLOR: rl.Color = .white;

state: packed struct {
    top_focused: bool = false,
    top_clicked: bool = false,
    top_disabled: bool = false,
    bot_focused: bool = false,
    bot_clicked: bool = false,
    bot_disabled: bool = false,
} = .{},
bounds: rl.Rectangle,
text_size: i32,
char: *u8,

pub fn update(self: *PasswordBox) void {
    self.state.top_disabled = self.char.* >= 'j';
    self.state.bot_disabled = self.char.* <= 'a';

    const mouse_pos = rl.getMousePosition();

    const extra = (self.bounds.height - @as(f32, @floatFromInt(self.text_size))) * 0.5;

    top: {
        const top_bounds = rl.Rectangle{
            .x = self.bounds.x + 5,
            .y = self.bounds.y,
            .width = self.bounds.width - 10,
            .height = extra,
        };

        self.state.top_focused = rl.checkCollisionPointRec(mouse_pos, top_bounds);

        if (self.state.top_disabled) {
            self.state.top_focused = false;
            self.state.top_clicked = false;

            break :top;
        }

        if (rl.isMouseButtonReleased(.left)) {
            if (self.state.top_focused and self.state.top_clicked)
                self.char.* += 1;

            self.state.top_clicked = false;
        }

        if (self.state.top_focused and rl.isMouseButtonPressed(.left))
            self.state.top_clicked = true;
    }

    bot: {
        const bot_bounds = rl.Rectangle{
            .x = self.bounds.x + 5,
            .y = self.bounds.y + self.bounds.height - extra,
            .width = self.bounds.width - 10,
            .height = extra,
        };

        self.state.bot_focused = rl.checkCollisionPointRec(mouse_pos, bot_bounds);

        if (self.state.bot_disabled) {
            self.state.bot_focused = false;
            self.state.bot_clicked = false;

            break :bot;
        }

        if (rl.isMouseButtonReleased(.left)) {
            if (self.state.bot_focused and self.state.bot_clicked)
                self.char.* -= 1;

            self.state.bot_clicked = false;
        }

        if (self.state.bot_focused and rl.isMouseButtonPressed(.left))
            self.state.bot_clicked = true;
    }
}

pub fn draw(self: *PasswordBox) void {
    const text = [_:0]u8{self.char.*};
    const text_width: f32 = @floatFromInt(rl.measureText(&text, self.text_size));

    const extra = (self.bounds.height - @as(f32, @floatFromInt(self.text_size))) * 0.5;

    rl.drawRectangleRec(.{
        .x = self.bounds.x + 5,
        .y = self.bounds.y,
        .width = self.bounds.width - 10,
        .height = extra,
    }, if (self.state.top_disabled)
        BUTTON_DISABLED_COLOR
    else if (self.state.top_clicked)
        BUTTON_CLICK_COLOR
    else if (self.state.top_focused)
        BUTTON_HOVER_COLOR
    else
        BUTTON_COLOR);

    rl.drawRectangleRec(.{
        .x = self.bounds.x + 5,
        .y = self.bounds.y + self.bounds.height - extra,
        .width = self.bounds.width - 10,
        .height = extra,
    }, if (self.state.bot_disabled)
        BUTTON_DISABLED_COLOR
    else if (self.state.bot_clicked)
        BUTTON_CLICK_COLOR
    else if (self.state.bot_focused)
        BUTTON_HOVER_COLOR
    else
        BUTTON_COLOR);

    rl.drawText(
        &text,
        @intFromFloat(self.bounds.x + (self.bounds.width - text_width) * 0.5),
        @intFromFloat(self.bounds.y + (self.bounds.height - @as(f32, @floatFromInt(self.text_size))) * 0.5),
        self.text_size,
        TEXT_COLOR,
    );
}
