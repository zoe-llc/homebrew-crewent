# frozen_string_literal: true

require "json"

# Internal CLI distribution Formula.
class Crewent < Formula
  desc "Internal CLI distribution"
  homepage "https://github.com/zoe-llc/crewent"
  url "https://github.com/zoe-llc/crewent/releases/download/cli-v0.1.0/crewent-cli-0.1.0.tgz"
  sha256 "96528ae9b04fd7eaaaec8c54e6978147e0d312b35005f88e686e6023f3967c28"
  license :cannot_represent

  bottle do
    root_url "https://ghcr.io/v2/zoe-llc/crewent"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "e7498089de1b7828bec765c3669e4e17ed1c66440c796c10034cd7c9cdc6d12d"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "13d85015f4d974936a1aa07f5eb3979e43ee0b28fb1f27e225df1a34168dee06"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "397deda99175e8dad1b081eff66ec9b4ddb5ea4753c8d3c40a6403ffbf53a4fb"
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
      (bin/command).write_env_script entry, PATH: formula_opt_bin("node@22")
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/crewent --version")
    assert_match "Usage:", shell_output("#{bin}/crewent --help")
  end
end
