# frozen_string_literal: true

require "json"

# Internal CLI distribution Formula.
class Crewent < Formula
  desc "Internal CLI distribution"
  homepage "https://github.com/zoe-llc/crewent"
  url "https://github.com/zoe-llc/crewent/releases/download/cli-v0.1.16/crewent-cli-0.1.16.tgz"
  sha256 "30a8ec3bf4d8e8862f5868a0eed3fa6682e0f86c32ea87a0d0dfe5d76b5dfe6e"
  license :cannot_represent

  bottle do
    root_url "https://ghcr.io/v2/zoe-llc/crewent"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "f68f01f6330efd1c4c5345bb44e9ee979e8074607c88518518aa1d58315be178"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "a73d11ae5d8a4bb8d9a634a3169d99008d5d458f62fc34de7a24107f3b42a537"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "f8690a83751207c07b18d385da81c09a4c2ef0a8968b2c4bb64ebddb285eef0c"
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
