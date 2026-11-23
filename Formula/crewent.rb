# frozen_string_literal: true

require "json"
require "shellwords"

# Internal CLI distribution Formula.
class Crewent < Formula
  desc "Internal CLI distribution"
  homepage "https://github.com/zoe-llc/crewent"
  url "https://github.com/zoe-llc/crewent/releases/download/cli-v0.1.19/crewent-cli-0.1.19.tgz"
  sha256 "bbb63a6869293dd004f6dec08bda90f52da7d5609b4c9f1484eebe6798f28028"
  license :cannot_represent

  bottle do
    root_url "https://ghcr.io/v2/zoe-llc/crewent"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "e1989e8dcf2e59a8e12d80dc364c348977f10f21aca44679494cbff2e2f01ade"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "33fb7880c7957f73dcd26be22f629e175f0de5a8b6e3ce015321385cff7a8454"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "e7de53a41c7ca789ad61d93050f5ea18b2ef41fcf77f708d2edb3c71990badcb"
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
