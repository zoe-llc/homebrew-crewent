# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "json"
require "pathname"
require_relative "../scripts/verify_formula_activation_policy"

class VerifyFormulaActivationPolicyTest < Minitest::Test
  FIXTURE = Pathname(__dir__).join("fixtures", "activated-0.1.0")

  def test_fixture_tree_satisfies_activated_policy
    skip("post-finalize fixture not populated yet") unless FIXTURE.join("Formula", "crewent.rb").file?

    PublicTap::FormulaActivationPolicy.verify!(root: FIXTURE)
  end

  def test_rejects_disabled_formula_with_activation_artifacts
    Dir.mktmpdir do |tmpdir|
      root = Pathname(tmpdir)
      root.join("Formula").mkpath
      root.join("docs", "verification").mkpath
      root.join("Formula", "crewent.rb").write(disabled_formula)
      root.join("docs", "verification", "bottle-candidate-0.1.0.json").write("{}")
      error = assert_raises(PublicTap::FormulaActivationPolicyError) do
        PublicTap::FormulaActivationPolicy.verify!(root: root)
      end
      assert_match(/must not commit bottle-candidate activation evidence/, error.message)
    end
  end

  private

  def disabled_formula
    <<~RUBY
      # frozen_string_literal: true
      class Crewent < Formula
        url "https://github.com/zoe-llc/crewent/releases/download/cli-v0.1.0/crewent-cli-0.1.0.tgz"
        sha256 "c7c5c1d70c5dec4416ab6158afd0b223ef40c29b1dc1f97ed9428b94d4cadb1c"
        disable! date: "2026-10-21", because: "has no activated internal 0.1.0 distribution"
        def install; end
        test { }
      end
    RUBY
  end

  def copy_tree(source, destination)
    return unless source.directory?

    source.find do |path|
      relative = path.relative_path_from(source)
      target = destination.join(relative)
      if path.directory?
        target.mkpath
      else
        target.dirname.mkpath
        FileUtils.cp(path, target)
      end
    end
  end
end
