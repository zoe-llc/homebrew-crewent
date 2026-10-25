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

  def test_distribution_canary_matches_the_formula_that_was_actually_installed
    candidate = bottle_candidate(
      source_formula_sha256: "1" * 64,
      candidate_formula_sha256: "2" * 64
    )
    distribution = distribution_canary(
      formula_sha256: "2" * 64,
      candidate_head_sha: "3" * 40
    )

    PublicTap::FormulaActivationPolicy.verify_distribution_canary!(
      distribution,
      candidate: candidate
    )
  end

  def test_distribution_canary_keeps_the_pre_finalize_candidate_head
    candidate = bottle_candidate(
      source_formula_sha256: "2" * 64,
      candidate_formula_sha256: "2" * 64
    )
    distribution = distribution_canary(
      formula_sha256: "2" * 64,
      candidate_head_sha: "3" * 40
    )

    with_github_sha("4" * 40) do
      PublicTap::FormulaActivationPolicy.verify_distribution_canary!(
        distribution,
        candidate: candidate
      )
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

  def bottle_candidate(source_formula_sha256:, candidate_formula_sha256:)
    {
      "version" => "0.1.1",
      "sourceSha" => "5" * 40,
      "authorizationSha" => "6" * 40,
      "artifactSha256" => "7" * 64,
      "manifestSha256" => "8" * 64,
      "sourceFormulaSha256" => source_formula_sha256,
      "candidateFormulaSha256" => candidate_formula_sha256,
      "bottleMatrixSha256" => "9" * 64
    }
  end

  def distribution_canary(formula_sha256:, candidate_head_sha:)
    {
      "schema" => "crewent.homebrew-distribution-canary-matrix/v1",
      "identity" => {
        "version" => "0.1.1",
        "sourceSha" => "5" * 40,
        "authorizationSha" => "6" * 40,
        "artifactSha256" => "7" * 64,
        "manifestSha256" => "8" * 64,
        "formulaSha256" => formula_sha256,
        "bottleMatrixSha256" => "9" * 64,
        "tapRepository" => "zoe-llc/homebrew-crewent",
        "candidateHeadSha" => candidate_head_sha
      },
      "targets" => Array.new(3) { { "status" => "PASS" } }
    }
  end

  def with_github_sha(value)
    previous = ENV.fetch("GITHUB_SHA", nil)
    ENV["GITHUB_SHA"] = value
    yield
  ensure
    ENV["GITHUB_SHA"] = previous
  end
end
