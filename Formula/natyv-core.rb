class NatyvCore < Formula
  desc "natyv-core: the runtime a natyv app actually ships as and runs on"
  homepage "https://github.com/natyv-io/core"
  url "https://github.com/natyv-io/core/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "74f86fc887684e843291223625bd40af021d213869d4d59bd57be76c0d0a9c84"
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

    # Zig's own package manager requires a `.path` dependency's value to
    # be relative to the *consuming* build.zig.zon's own directory. Real,
    # confirmed gotcha: even though `-Dnatyv-core-src=` (set by the
    # `natyv` formula) points at this formula's stable `opt_prefix`
    # symlink, zig's own build runner resolves its actual working
    # directory to the real, symlink-followed Cellar keg path before
    # doing any relative-path arithmetic -- computing this relative to
    # `opt_prefix` instead produced a real, reproduced "FileNotFound" one
    # directory shallower than the real target. `prefix` (this formula's
    # own real, versioned Cellar path, no symlink involved) on both sides
    # matches what zig actually sees. Known, accepted limitation this
    # creates: the resulting relative path is only valid for the exact
    # natyv-shared version installed right now -- upgrading natyv-shared
    # independently later requires reinstalling natyv-core too, to
    # regenerate a correct one.
    shared_relative = Formula["natyv-shared"].prefix.relative_path_from(prefix)
    zon_path = prefix/"build.zig.zon"
    contents = zon_path.read
    contents.sub!(/\.shared\s*=\s*\.\{[^}]*\}/, ".shared = .{ .path = \"#{shared_relative}\" }")
    zon_path.atomic_write(contents)
  end

  test do
    assert_match "shared = .{", (prefix/"build.zig.zon").read
    assert_predicate prefix/"src/main.zig", :exist?
  end
end
