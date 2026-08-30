class NatyvCore < Formula
  desc "natyv-core: the runtime a natyv app actually ships as and runs on"
  homepage "https://github.com/natyv-io/core"
  url "https://github.com/natyv-io/core/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "3e936dfcc840dfd9549957d5702df9a758bf5c418593c4a142c3f0fd10403fed"
  license "Apache-2.0"

  depends_on "natyv-shared"

  # Not a binary a user runs directly: `natyv build` (from the `natyv`
  # formula) shells out to a real `zig build install-core` against
  # wherever `-Dnatyv-core-src=`/`NATYV_CORE_SRC` points, once per app the
  # developer builds -- so this formula's own job is just to leave a real,
  # buildable natyv-core source tree on disk (SDL3/Extism get fetched by
  # that later `zig build` invocation itself, on the developer's own
  # machine, outside Homebrew's install sandbox entirely -- not this
  # formula's concern).
  def install
    prefix.install Dir["*"]

    zon_path = prefix/"build.zig.zon"
    contents = zon_path.read
    contents.sub!(/\.shared\s*=\s*\.\{[^}]*\}/, ".shared = .{ .path = \"#{Formula["natyv-shared"].opt_prefix}\" }")
    zon_path.atomic_write(contents)
  end

  test do
    assert_match "shared = .{", (prefix/"build.zig.zon").read
    assert_predicate prefix/"src/main.zig", :exist?
  end
end
