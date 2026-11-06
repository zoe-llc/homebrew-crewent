# frozen_string_literal: true

require "json"

# Internal CLI distribution Formula.
class Crewent < Formula
  desc "Internal CLI distribution"
  homepage "https://github.com/zoe-llc/crewent"
  url "https://github.com/zoe-llc/crewent/releases/download/cli-v0.1.4/crewent-cli-0.1.4.tgz"
  sha256 "f28f4dd76f560d2960221c0754b459618c914512f7baf9b28170727c9a82d460"
  license :cannot_represent

  bottle do
    root_url "https://ghcr.io/v2/zoe-llc/crewent"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "b96e01db7680e3790af5a9784fa18036e112b451295ccc0064f311ab3505c198"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "3213568bcd520b5ea294ab7a77bd938a5321568835d807b26195da50597dd009"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "b6d709b01611db5a5b1073e07c97a4f84bf2c7e4027cf178f5b0ccdf63bc8179"
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
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/crewent --version")
    assert_match "Usage:", shell_output("#{bin}/crewent --help")
  end
end
