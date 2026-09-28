class NatyvShared < Formula
  desc "Code shared between natyv-core, the natyv CLI, and ntx-lsp (config schema, .ntx transpiler)"
  homepage "https://github.com/natyv-io/shared"
  url "https://github.com/natyv-io/shared/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "67fc1e8d2d5b5cd7cc43368da88778fb1983634722ddab459dc0b281e7419af3"
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
