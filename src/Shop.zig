const std = @import("std");
const rl = @import("raylib");

const build_options = @import("build_options");

const Board = @import("Board.zig");

const SHOP_BG: rl.Color = .{ .r = 128, .g = 42, .b = 98, .a = 255 };
const SHOP_TEXT: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
const SHOP_PADDING: rl.Vector2 = .{ .x = 20, .y = 20 };

const BUTTON_COLOR: rl.Color = .{ .r = 0, .g = 148, .b = 121, .a = 255 };
const BUTTON_HOVER_COLOR: rl.Color = .{ .r = 9, .g = 219, .b = 47, .a = 255 };
const BUTTON_CLICK_COLOR: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
const BUTTON_DISABLED_COLOR: rl.Color = .{ .r = 255, .g = 0, .b = 0, .a = 255 };

const BUTTON_TEXT_COLOR: rl.Color = .{ .r = 0, .g = 55, .b = 110, .a = 255 };

const TITLE_FONT_SIZE = 44;
const MONEY_FONT_SIZE = 22;
const UPGRADE_FONT_SIZE = 44;
const UPGRADE_DESC_FONT_SIZE = 22;
const UPGRADE_COUNT_FONT_SIZE = 22;

const UPGRADE_PADDING = 5;

const AI_BUY_PC = 1;

pub const Upgrade = enum { spread, monkey, focus, monkey_focus, monkey_spread };

const UpgradeInfo = struct {
    name: [:0]const u8,
    desc: [:0]const u8,

    base_cost: f32,
    mult: f32,
};
const UpgradeFields = packed struct(u8) {
    focused: bool = false,
    click: bool = false,
    disabled: bool = true,
    padding: u5 = undefined,
};

const UPGRADE_DATA: std.enums.EnumArray(Upgrade, UpgradeInfo) = .init(.{
    .spread = .{
        .name = "Spread",
        .desc = "Throw multiple darts at once",

        .base_cost = 100,
        .mult = 1.5,
    },
    .monkey = .{
        .name = "Monkey",
        .desc = "Throws darts for you",

        .base_cost = 300,
        .mult = 1.75,
    },
    .focus = .{
        .name = "Focus",
        .desc = "Throw darts more accurately",

        .base_cost = 500,
        .mult = 1.5,
    },
    .monkey_focus = .{
        .name = "Monkey focus",
        .desc = "Help Monkeys throw darts\nmore accurately",

        .base_cost = 800,
        .mult = 1.5,
    },
    .monkey_spread = .{
        .name = "Monkey spread",
        .desc = "Monkeys throw more darts\nat once",

        .base_cost = 1000,
        .mult = 1.5,
    },
});

const Shop = @This();

upgrade_fields: std.enums.EnumArray(Upgrade, UpgradeFields) = .initFill(.{}),

pub fn update(self: *Shop, board: *Board, bounds: rl.Rectangle, dt: f32) void {
    switch (board.player) {
        .user => {
            var pos: rl.Vector2 = .{
                .x = bounds.x + SHOP_PADDING.x,
                .y = bounds.y + SHOP_PADDING.y,
            };
            pos.y += TITLE_FONT_SIZE; // SHOP TITLE
            pos.y += MONEY_FONT_SIZE; // MONEY TEXT
            pos.y += UPGRADE_PADDING; // PAD

            const mouse_pos = rl.getMousePosition();
            for (std.enums.values(Upgrade)) |upgrade| {
                const info = UPGRADE_DATA.getPtrConst(upgrade);
                const fields = self.upgrade_fields.getPtr(upgrade);

                pos.y += UPGRADE_PADDING;

                const total_lines: f32 = @floatFromInt(std.mem.count(u8, info.desc, "\n") + 1);
                const total_height: f32 = UPGRADE_PADDING + UPGRADE_FONT_SIZE + UPGRADE_DESC_FONT_SIZE * total_lines + UPGRADE_PADDING;

                fields.focused = rl.checkCollisionPointRec(mouse_pos, .{
                    .x = pos.x - SHOP_PADDING.x,
                    .y = pos.y,
                    .width = bounds.width,
                    .height = total_height + UPGRADE_PADDING,
                });

                pos.y += total_height;

                const cost = upgradeCost(board, upgrade);

                fields.disabled = cost > board.money;

                if (fields.disabled) {
                    fields.focused = false;
                    fields.click = false;

                    continue;
                }

                if (rl.isMouseButtonReleased(.left)) {
                    if (fields.focused and fields.click) {
                        std.log.info("Player buy {s}", .{info.name});
                        board.buyUpgrade(upgrade);
                        board.money -= @intCast(cost);
                        board.upgrade_counts.getPtr(upgrade).* += 1;
                    }

                    fields.click = false;
                }

                if (fields.focused and rl.isMouseButtonPressed(.left))
                    fields.click = true;
            }
        },
        .ai => {
            for (std.enums.values(Upgrade)) |upgrade| {
                const info = UPGRADE_DATA.getPtrConst(upgrade);

                const cost = upgradeCost(board, upgrade);
                if (cost > board.money)
                    continue;

                if (rl.getRandomValue(0, 100) < AI_BUY_PC) {
                    std.log.info("Ai buy {s}", .{info.name});
                    board.buyUpgrade(upgrade);
                    board.money -= @intCast(cost);
                    board.upgrade_counts.getPtr(upgrade).* += 1;
                }
            }
        },
        .web => @panic("Todo"),
    }

    _ = dt;
}

pub fn draw(self: *const Shop, board: *const Board, bounds: rl.Rectangle) void {
    var fmt_buf: [64]u8 = undefined;

    rl.drawRectangleRec(bounds, SHOP_BG);

    var pos: rl.Vector2 = .{
        .x = bounds.x + SHOP_PADDING.x,
        .y = bounds.y + SHOP_PADDING.y,
    };

    //draw title
    rl.drawText(
        build_options.GAME_NAME,
        @intFromFloat(pos.x),
        @intFromFloat(pos.y),
        TITLE_FONT_SIZE,
        SHOP_TEXT,
    );
    pos.y += TITLE_FONT_SIZE;

    //draw money/points
    const money_text = std.fmt.bufPrintSentinel(
        &fmt_buf,
        "Points: {d}",
        .{board.money},
        0,
    ) catch unreachable;

    rl.drawText(
        money_text,
        @intFromFloat(pos.x),
        @intFromFloat(pos.y),
        MONEY_FONT_SIZE,
        SHOP_TEXT,
    );
    pos.y += MONEY_FONT_SIZE;
    pos.y += UPGRADE_PADDING;

    for (std.enums.values(Upgrade)) |upgrade| {
        pos.y += UPGRADE_PADDING;

        const info = UPGRADE_DATA.getPtrConst(upgrade);
        const fields = self.upgrade_fields.getPtrConst(upgrade);

        const total_lines: f32 = @floatFromInt(std.mem.count(u8, info.desc, "\n") + 1);
        const total_height: f32 = UPGRADE_PADDING + UPGRADE_FONT_SIZE + UPGRADE_DESC_FONT_SIZE * total_lines + UPGRADE_PADDING;

        rl.drawRectangleRounded(.{
            .x = pos.x,
            .y = pos.y,
            .width = bounds.width - SHOP_PADDING.x * 2,
            .height = total_height,
        }, 0.2, 10, if (fields.disabled)
            BUTTON_DISABLED_COLOR
        else if (fields.click)
            BUTTON_CLICK_COLOR
        else if (fields.focused)
            BUTTON_HOVER_COLOR
        else
            BUTTON_COLOR);

        pos.y += UPGRADE_PADDING;

        const count_text = std.fmt.bufPrintSentinel(
            &fmt_buf,
            "({})",
            .{board.upgrade_counts.get(upgrade)},
            0,
        ) catch unreachable;
        const width: f32 = @floatFromInt(rl.measureText(count_text, UPGRADE_FONT_SIZE));

        rl.drawText(
            count_text,
            @intFromFloat(bounds.x + bounds.width - SHOP_PADDING.x - width),
            @intFromFloat(pos.y),
            UPGRADE_COUNT_FONT_SIZE,
            BUTTON_TEXT_COLOR,
        );

        rl.drawText(
            info.name,
            @intFromFloat(pos.x + UPGRADE_PADDING),
            @intFromFloat(pos.y),
            UPGRADE_FONT_SIZE,
            BUTTON_TEXT_COLOR,
        );
        pos.y += UPGRADE_FONT_SIZE;
        rl.drawText(
            info.desc,
            @intFromFloat(pos.x + UPGRADE_PADDING),
            @intFromFloat(pos.y),
            UPGRADE_DESC_FONT_SIZE,
            BUTTON_TEXT_COLOR,
        );
        pos.y += UPGRADE_DESC_FONT_SIZE * total_lines;

        pos.y += UPGRADE_PADDING;
    }
}

pub fn upgradeCost(board: *const Board, upgrade: Upgrade) i32 {
    const info = UPGRADE_DATA.getPtrConst(upgrade);

    const purchased = @as(f32, @floatFromInt(board.upgrade_counts.get(upgrade)));

    return @intFromFloat(info.base_cost * std.math.pow(f32, info.mult, purchased));
}
