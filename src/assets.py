# File to quickly generate zig code for array of all game assets, based on folder structure.
# While it's just a bunch of string manipulation to write some zig code,
# it's also not pretty, but should be understandable by looking at the code and the output it makes (assets.zig).

from os import path, scandir

FILE_HEADER = (
    """\
/// File generated by """
    + path.split(__file__)[-1]
    + """ - Manual changes will probably be overwritten.
const SDL_Texture = @import("sdl2").SDL_Texture;
const StaticMap = @import("utils.zig").StaticMap;

pub const Texture = struct {
    ptr: *SDL_Texture,
    width: usize,
    height: usize,
};

pub const TextureMap = @TypeOf(StaticMap(ID.size(), []Texture, ID));

pub const Asset = struct {
    path: []const u8,
    id: ID,
};
"""
)

ENUM_HEADER = """\
pub const ID = enum(u16) {
"""

ENUM_FOOTER = """\
    __LAST__,

    inline fn size() u16 {
        return @intFromEnum(ID.__LAST__);
    }
};
"""


ASSETS_PRE_HEADER = "pub const ALL: ["

ASSETS_POST_HEADER = "]Asset = .{\n"

ASSETS_FOOTER = """\
};
"""

BACKING_INTEGER = "u16"

MODE_PRE_HEADER = "const "

MODE_POST_HEADER = "Mode = enum(" + BACKING_INTEGER + ") {\n"

ENTITY_MODE_HEADER = "pub const EntityMode = union(enum(" + BACKING_INTEGER + ")) {\n"

ID_FROM_MODE_HEADER = """\
pub fn IDFromEntityMode(mode: EntityMode) ID {
    switch (mode) {
"""

ID_FROM_MODE_FOOTER = """\
    }
    unreachable; // shouldn't happen
}
"""

# Run this file from the location it resides in. Paths are relative.
if __name__ == "__main__":
    TAB_SIZE = 4
    asset_dir = path.join(path.pardir, "assets")

    with open("assets.zig", "w") as outfile:
        print(FILE_HEADER, file=outfile)

        enum_string = ENUM_HEADER
        assets_string = "" 
        assets_per_id = []
        mode_strings = []
        entity_mode_string = ENTITY_MODE_HEADER
        id_from_mode_string = ID_FROM_MODE_HEADER

        total_num_assets = 0
        for asset_type_dir in scandir(asset_dir):
            if not asset_type_dir.is_dir():
                continue

            asset_type = asset_type_dir.name

            for asset_subtype_dir in scandir(asset_type_dir.path):
                if not asset_subtype_dir.is_dir():
                    continue

                asset_subtype = asset_subtype_dir.name
                entity_mode_field = asset_type.lower() + "_" + asset_subtype.lower()
                mode_type = asset_type + asset_subtype
                mode_string = MODE_PRE_HEADER + mode_type + MODE_POST_HEADER
                id_from_mode = (
                    "\t\t."
                    + entity_mode_field
                    + " => |"
                    + entity_mode_field
                    + "_mode| switch("
                    + entity_mode_field
                    + "_mode) {\n"
                )

                has_animations = False
                for animation_dir in scandir(asset_subtype_dir.path):
                    if not animation_dir.is_dir():
                        continue

                    has_animations = True
                    animation = animation_dir.name
                    id = (
                        asset_type.upper()
                        + "_"
                        + asset_subtype.upper()
                        + "_"
                        + animation.upper()
                    )
                    num_assets = 0

                    # BUG: need to sort directory for animation ordering
                    for image in scandir(animation_dir.path):
                        if not image.is_file():
                            continue

                        num_assets += 1
                        assets_string += (
                            '\t.{ .path = "' + path.relpath(image.path, "..") + '", .id = .' + id + " },\n"
                        )

                    if num_assets > 0:
                        mode = animation.upper()
                        enum_string += "\t" + id + ",\n"
                        mode_string += "\t" + mode + ",\n"
                        id_from_mode += "\t\t\t." + mode + " => return ID." + id + ",\n"
                        assets_per_id.append(num_assets)
                        total_num_assets += num_assets

                if has_animations:
                    entity_mode_string += (
                        "\t" + entity_mode_field + ": " + mode_type + "Mode,\n"
                    )
                    mode_strings.append(mode_string + "};\n")
                    id_from_mode += "\t\t},\n"
                    id_from_mode_string += id_from_mode

        enum_string += ENUM_FOOTER
        print(enum_string.expandtabs(TAB_SIZE), file=outfile)

        id_from_mode_string += ID_FROM_MODE_FOOTER
        print(id_from_mode_string.expandtabs(TAB_SIZE), file=outfile)

        print((entity_mode_string + "};\n").expandtabs(TAB_SIZE), file=outfile)
        for string in mode_strings:
            print(string.expandtabs(TAB_SIZE), file=outfile)

        assets_string = ASSETS_PRE_HEADER + str(total_num_assets) + ASSETS_POST_HEADER + assets_string
        assets_string += ASSETS_FOOTER
        print(assets_string.expandtabs(TAB_SIZE), file=outfile)

        assets_per_id_string = "pub const ASSETS_PER_ID: [ID.size()]usize = .{ " + str(assets_per_id)[1:-1] + " };\n"
        print(assets_per_id_string.expandtabs(TAB_SIZE), file=outfile)
