# frozen_string_literal: true

require "json"
require "shellwords"

# Internal CLI distribution Formula.
class Crewent < Formula
  desc "Internal CLI distribution"
  homepage "https://github.com/zoe-llc/crewent"
  url "https://github.com/zoe-llc/crewent/releases/download/cli-v0.1.25/crewent-cli-0.1.25.tgz"
  sha256 "b6c4191a5ea969a827544005a826e6c61459af7b6a69ac3eed9843627e029a14"
  license :cannot_represent

  bottle do
    root_url "https://ghcr.io/v2/zoe-llc/crewent"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "6d79b44d4cfd068ab6edf448fa0d9d2dca99b8d2e1d7bc8833195662ad5b2f58"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "77b73bceb632eff76e0f18dc19ecc0588d6cb040c310c79fcfb7cd7a0441e0a8"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "bc212609b722fcb54997ca420ee78403025429372d874c30e9ee5c947f2344f9"
  end

  depends_on "node@22"

  def install
    if ENV["HOMEBREW_CLI_DISTRIBUTION_BOTTLE_BUILD"] != "1"
      odie "Prebuilt bottle required; consumer source fallback is disabled"
    end

    package_root = buildpath
    odie "npm package metadata is missing" unless (package_root/"package.json").file?
    libexec.install package_root.children

    metadata = JSON.parse((libexec/"package.json").read)
    bin_map = metadata.fetch("bin")
    expected_commands = ["crewent"]
    if bin_map.keys.sort != expected_commands.sort
      odie "package command set does not match the release manifest"
    end

    expected_commands.each do |command|
      relative = bin_map.fetch(command)
      odie "package command path is unsafe" unless relative.is_a?(String)

      parts = relative.delete_prefix("./").split("/")
      safe_parts = parts.any? && parts.none? do |part|
        part.empty? || part == "." || part == ".." || !part.match?(/\A[A-Za-z0-9_.-]+\z/)
      end
      odie "package command path is unsafe" unless safe_parts
      entry = libexec.join(*parts).cleanpath
      odie "package command escapes libexec" unless entry.to_s.start_with?("#{libexec}/")
      write_launcher bin/command, entry
    end

    command_aliases = ["crw"]
    command_aliases.each do |command_alias|
      odie "package command alias conflicts with a package command" if bin_map.key?(command_alias)
      relative = bin_map.fetch("crewent")
      entry = libexec.join(*relative.delete_prefix("./").split("/")).cleanpath
      write_launcher bin/command_alias, entry
    end
  end

  def write_launcher(launcher, entry)
    node = formula_opt_bin("node@22")/"node"
    launcher.dirname.mkpath
    launcher.write "#!/bin/bash\nexec #{node.to_s.shellescape} #{entry.to_s.shellescape} " + '"$@"' + "\n"
    launcher.chmod 0555
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/crewent --version")
    assert_match "Usage:", shell_output("#{bin}/crewent --help")
    assert_match version.to_s, shell_output("#{bin}/crw --version")
  end
end
