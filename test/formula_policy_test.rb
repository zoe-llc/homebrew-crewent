# frozen_string_literal: true

require "minitest/autorun"
require_relative "../scripts/verify_formula_activation_policy"

class FormulaPolicyTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  FORMULA = File.join(ROOT, "Formula", "crewent.rb")

  def test_public_formula_surface_contains_only_crewent
    assert_equal [FORMULA], Dir.glob(File.join(ROOT, "Formula", "*.rb")).sort
  end

  def test_formula_preserves_exact_source_and_bottle_only_policy
    source = File.read(FORMULA)

    assert_includes source, "class Crewent < Formula"
    assert_includes source, 'homepage "https://github.com/zoe-llc/crewent"'
    assert_match(%r{url "https://github\.com/zoe-llc/crewent/releases/download/cli-v[^/]+/crewent-cli-[^"]+\.tgz"}, source)
    assert_includes source, 'ENV["HOMEBREW_CLI_DISTRIBUTION_BOTTLE_BUILD"] != "1"'
    assert_includes source, 'odie "Prebuilt bottle required; consumer source fallback is disabled"'
    assert_includes source, "package_root = buildpath"
    refute_includes source, 'buildpath/"package"'
    assert_includes source, 'odie "npm package metadata is missing" unless (package_root/"package.json").file?'
    assert_includes source, '["crewent"]'
    refute_match(/secrets\.|GH_TOKEN|GITHUB_TOKEN|HOMEBREW_GITHUB_API_TOKEN/, source)
    refute_match(/system\s+['"](?:curl|git|gh)['"]/, source)
  end

  def test_stable_main_formula_is_disabled_until_activation_evidence_exists
    PublicTap::FormulaActivationPolicy.verify!(root: ROOT)
  end

  def test_activated_formula_requires_closed_activation_evidence
    Dir.mktmpdir do |tmpdir|
      root = Pathname(tmpdir)
      write_activated_formula(root)
      error = assert_raises(PublicTap::FormulaActivationPolicyError) do
        PublicTap::FormulaActivationPolicy.verify!(root: root)
      end
      assert_match(/activation evidence/, error.message)
    end
  end

  private

  def write_activated_formula(root)
    root.join("Formula").mkpath
    root.join("docs", "verification").mkpath
    root.join("Formula", "crewent.rb").write(<<~RUBY)
      # frozen_string_literal: true
      class Crewent < Formula
        url "https://github.com/zoe-llc/crewent/releases/download/cli-v0.1.0/crewent-cli-0.1.0.tgz"
        sha256 "96528ae9b04fd7eaaaec8c54e6978147e0d312b35005f88e686e6023f3967c28"
        bottle do
          root_url "https://ghcr.io/v2/zoe-llc/crewent"
          sha256 cellar: :any_skip_relocation, arm64_sequoia: "e7498089de1b7828bec765c3669e4e17ed1c66440c796c10034cd7c9cdc6d12d"
          sha256 cellar: :any_skip_relocation, arm64_linux:   "13d85015f4d974936a1aa07f5eb3979e43ee0b28fb1f27e225df1a34168dee06"
          sha256 cellar: :any_skip_relocation, x86_64_linux:  "397deda99175e8dad1b081eff66ec9b4ddb5ea4753c8d3c40a6403ffbf53a4fb"
        end
        def install; end
        test { }
      end
    RUBY
  end
end
