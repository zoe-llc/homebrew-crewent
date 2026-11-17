# frozen_string_literal: true

require "json"

# Internal CLI distribution Formula.
class Crewent < Formula
  desc "Internal CLI distribution"
  homepage "https://github.com/zoe-llc/crewent"
  url "https://github.com/zoe-llc/crewent/releases/download/cli-v0.1.13/crewent-cli-0.1.13.tgz"
  sha256 "eea7b7a455c5aed69f3fea85381e676e168ea2b5b599574e7f1d8b36fe23bd89"
  license :cannot_represent

  bottle do
    root_url "https://ghcr.io/v2/zoe-llc/crewent"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "4a573b56c30019b2e28957134c0fe50f08542c1ffcf74bfbe43d571d3f5c2a5b"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "a8902556abfa111e7f16e545602555552e7747d17a550202e74f24d526b479c7"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "b4ba9c2dca3095db0e894ed1e683f5567178a69f212cd68a5db1840acc1565cb"
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
      parts = relative.is_a?(String) ? relative.delete_prefix("./").split("/") : []
      safe_parts = parts.any? && parts.none? do |part|
        part.empty? || part == "." || part == ".." || !part.match?(/\A[A-Za-z0-9_.-]+\z/)
      end
      odie "package command path is unsafe" unless safe_parts
      entry = libexec.join(*parts).cleanpath
      odie "package command escapes libexec" unless entry.to_s.start_with?("#{libexec}/")
      (bin/command).write_env_script entry, PATH: "#{formula_opt_bin("node@22")}:$PATH"
    end

    command_aliases = ["crw"]
    command_aliases.each do |command_alias|
      odie "package command alias conflicts with a package command" if bin_map.key?(command_alias)
      relative = bin_map.fetch("crewent")
      entry = libexec.join(*relative.delete_prefix("./").split("/")).cleanpath
      (bin/command_alias).write_env_script entry, PATH: "#{formula_opt_bin("node@22")}:$PATH"
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/crewent --version")
    assert_match "Usage:", shell_output("#{bin}/crewent --help")
    assert_match version.to_s, shell_output("#{bin}/crw --version")
  end
end
