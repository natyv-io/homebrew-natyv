class NatyvShared < Formula
  desc "Code shared between natyv-core and the natyv CLI (currently the config schema)"
  homepage "https://github.com/natyv-io/shared"
  url "https://github.com/natyv-io/shared/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "b2f80b13a39539f5a1a7aeafeefb835b61de005ec4ee21555342d49a76c03099"
  license "Apache-2.0"

  # Not installed directly by end users -- this is a build-time-only
  # dependency of natyv-core and natyv (the CLI), which each import its
  # `Config` module via a real Zig build.zig.zon `.path` dependency
  # pointed at this formula's own install location. No compilation
  # needed here at all -- Zig just needs the real source tree (build.zig,
  # build.zig.zon, src/) physically present on disk.
  def install
    prefix.install Dir["*"]
  end

  test do
    # `zig` isn't declared as a build dependency (see natyv.rb's own
    # caveats block for why), so this can't assume it's on PATH for a
    # real `zig build test` -- just confirm the real package layout
    # natyv-core/natyv's own `.path` overrides expect is actually there.
    assert_predicate prefix/"build.zig.zon", :exist?
    assert_predicate prefix/"src/Config.zig", :exist?
  end
end
