# frozen_string_literal: true

require "json"
require "shellwords"

# Internal CLI distribution Formula.
class Crewent < Formula
  desc "Internal CLI distribution"
  homepage "https://github.com/zoe-llc/crewent"
  url "https://github.com/zoe-llc/crewent/releases/download/cli-v0.1.26/crewent-cli-0.1.26.tgz"
  sha256 "027f12433a59958a470d34993ebffb55dfdba80d6f1ba340fb236a2b64352de1"
  license :cannot_represent

  bottle do
    root_url "https://ghcr.io/v2/zoe-llc/crewent"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "263db5bcb985804fe4de4415f372059b97074b6c6222c423ccaccee29e7e19f2"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "149e420b8030d770efc24eebadfb713477e123cb15c814c14e9750e7a882b322"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "f892561be369f711e84252cb35397a82257594adaaff66962f2a99cb2181eea3"
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
