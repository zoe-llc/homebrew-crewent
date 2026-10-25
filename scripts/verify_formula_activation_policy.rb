#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "pathname"

module PublicTap
  class FormulaActivationPolicyError < StandardError; end

  module FormulaActivationPolicy
    module_function

    DISABLED_BECAUSE = /\Ahas no activated internal (?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*) distribution\z/
    VERSION_FROM_URL = %r{
      url\s+"https://github\.com/zoe-llc/crewent/releases/download/
      cli-v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))/
      crewent-cli-\k<version>\.tgz"
    }x
    URL_SHA256 = /^\s*sha256\s+"(?<digest>[a-f0-9]{64})"\s*$/
    BOTTLE_ROOT_URL = 'root_url "https://ghcr.io/v2/zoe-llc/crewent"'
    BOTTLE_SHA256 = /
      sha256\s+cellar:\s+:any_skip_relocation,\s+
      (?<tag>[a-z0-9_]+):\s+"(?<digest>[a-f0-9]{64})"
    /x
    COMMIT = /\A[a-f0-9]{40}\z/
    SHA256 = /\A[a-f0-9]{64}\z/
    ACTIVATION_FILE_STEMS = %w[
      bottle-candidate
      bottle-matrix
      distribution-canary
      activation-authorization
    ].freeze
    SENSITIVE = /secret-sentinel|bearer\s|cookie=|_authtoken|-----BEGIN .*PRIVATE KEY-----/i

    def verify!(root:)
      root = Pathname(root)
      formula_path = root.join("Formula", "crewent.rb")
      verification_root = root.join("docs", "verification")
      source = read_file(formula_path)

      if source.match?(/^\s*disable!/m)
        verify_disabled!(source, verification_root)
      else
        verify_activated!(source, formula_path, verification_root)
      end
    end

    def verify_disabled!(source, verification_root)
      fail!("disabled Formula must not declare a bottle block") if source.match?(/^\s*bottle\s+do/m)
      match = source.match(
        /disable!\s+date:\s*"\d{4}-\d{2}-\d{2}",\s*because:\s*"(?<because>[^"]+)"/m
      )
      fail!("disabled Formula must declare disable! with an explicit date and because") unless match
      because = match[:because]
      fail!("disabled Formula because must describe missing internal activation") unless DISABLED_BECAUSE.match?(because)

      ACTIVATION_FILE_STEMS.each do |stem|
        matches = Dir.glob(verification_root.join("#{stem}-*.json").to_s)
        fail!("disabled Formula must not commit #{stem} activation evidence") unless matches.empty?
      end
    end

    def verify_activated!(source, formula_path, verification_root)
      fail!("activated Formula must not declare disable!") if source.match?(/^\s*disable!/m)
      fail!("activated Formula must declare a private GHCR bottle block") unless source.include?(BOTTLE_ROOT_URL)

      version = extract_version!(source)
      artifact_sha256 = extract_url_sha256!(source)
      formula_sha256 = Digest::SHA256.file(formula_path).hexdigest
      bottle_digests = extract_bottle_digests!(source)

      candidate = read_json(verification_root.join("bottle-candidate-#{version}.json"))
      matrix = read_json(verification_root.join("bottle-matrix-#{version}.json"))
      distribution = read_json(verification_root.join("distribution-canary-#{version}.json"))
      activation = read_json(verification_root.join("activation-authorization-#{version}.json"))

      verify_bottle_candidate!(candidate, version: version, artifact_sha256: artifact_sha256, formula_sha256: formula_sha256)
      verify_bottle_matrix!(matrix, candidate: candidate, bottle_digests: bottle_digests)
      verify_distribution_canary!(distribution, candidate: candidate)
      verify_activation_authorization!(activation, candidate: candidate)
    end

    def extract_version!(source)
      match = source.match(VERSION_FROM_URL)
      fail!("Formula url must reference an exact cli-v SemVer release asset") unless match
      version = match[:version]
      fail!("Formula version must not be a placeholder") if version == "0.0.0"
      version
    end

    def extract_url_sha256!(source)
      match = source.lines.grep(URL_SHA256).first&.match(URL_SHA256)
      fail!("Formula must pin an exact source artifact sha256") unless match
      match[:digest]
    end

    def extract_bottle_digests!(source)
      bottle_section = source[/^\s*bottle\s+do.*?^\s*end/m]
      fail!("Formula bottle block is missing or malformed") unless bottle_section

      digests = {}
      bottle_section.scan(BOTTLE_SHA256) do
        digests[Regexp.last_match[:tag]] = Regexp.last_match[:digest]
      end
      fail!("Formula bottle block must declare exactly three digests") unless digests.length == 3
      digests
    end

    def verify_bottle_candidate!(value, version:, artifact_sha256:, formula_sha256:)
      require_schema!(value, "crewent.homebrew-bottle-candidate/v1")
      equal!(value.fetch("version"), version, "bottle-candidate.version")
      equal!(value.fetch("artifactSha256"), artifact_sha256, "bottle-candidate.artifactSha256")
      equal!(value.fetch("candidateFormulaSha256"), formula_sha256, "bottle-candidate.candidateFormulaSha256")
      pattern!(value.fetch("sourceSha"), COMMIT, "bottle-candidate.sourceSha")
      pattern!(value.fetch("authorizationSha"), COMMIT, "bottle-candidate.authorizationSha")
      pattern!(value.fetch("manifestSha256"), SHA256, "bottle-candidate.manifestSha256")
      pattern!(value.fetch("sourceFormulaSha256"), SHA256, "bottle-candidate.sourceFormulaSha256")
      pattern!(value.fetch("bottleMatrixSha256"), SHA256, "bottle-candidate.bottleMatrixSha256")
    end

    def verify_bottle_matrix!(value, candidate:, bottle_digests:)
      require_schema!(value, "crewent.homebrew-bottle-matrix/v1")
      %w[version sourceSha authorizationSha manifestSha256].each do |key|
        equal!(value.fetch(key), candidate.fetch(key), "bottle-matrix.#{key}")
      end
      equal!(value.fetch("formulaSha256"), candidate.fetch("sourceFormulaSha256"), "bottle-matrix.formulaSha256")

      bottles = value.fetch("bottles")
      fail!("bottle-matrix must contain exactly three PASS targets") unless bottles.is_a?(Array) && bottles.length == 3

      observed_tags = {}
      bottles.each do |entry|
        require_schema!(entry, "crewent.homebrew-bottle-evidence/v1")
        equal!(entry.fetch("status"), "PASS", "bottle-matrix entry status")
        tag = entry.dig("bottle", "tag")
        digest = entry.dig("bottle", "sha256")
        observed_tags[tag] = digest
        equal!(bottle_digests.fetch(tag), digest, "Formula bottle digest for #{tag}")
      end
      fail!("Formula bottle tags must match the bottle matrix") unless observed_tags.keys.sort == bottle_digests.keys.sort
    end

    def verify_distribution_canary!(value, candidate:)
      require_schema!(value, "crewent.homebrew-distribution-canary-matrix/v1")
      identity = value.fetch("identity")
      %w[version sourceSha authorizationSha artifactSha256 manifestSha256 bottleMatrixSha256].each do |key|
        equal!(identity.fetch(key), candidate.fetch(key), "distribution-canary.identity.#{key}")
      end
      equal!(
        identity.fetch("formulaSha256"),
        candidate.fetch("candidateFormulaSha256"),
        "distribution-canary.identity.formulaSha256"
      )
      equal!(identity.fetch("tapRepository"), "zoe-llc/homebrew-crewent", "distribution-canary.identity.tapRepository")
      pattern!(identity.fetch("candidateHeadSha"), COMMIT, "distribution-canary.identity.candidateHeadSha")

      targets = value.fetch("targets")
      fail!("distribution-canary must contain exactly three PASS targets") unless targets.is_a?(Array) && targets.length == 3
      targets.each do |target|
        equal!(target.fetch("status"), "PASS", "distribution-canary target status")
      end
    end

    def verify_activation_authorization!(value, candidate:)
      require_schema!(value, "crewent.homebrew-activation-authorization/v1")
      equal!(value.fetch("version"), candidate.fetch("version"), "activation-authorization.version")
      equal!(value.fetch("sourceSha"), candidate.fetch("sourceSha"), "activation-authorization.sourceSha")
      pattern!(value.fetch("releaseAuthorizationSha"), COMMIT, "activation-authorization.releaseAuthorizationSha")
      equal!(value.fetch("releaseAuthorizationSha"), candidate.fetch("authorizationSha"), "activation-authorization.releaseAuthorizationSha")
      pattern!(value.fetch("activationAuthorizationSha"), COMMIT, "activation-authorization.activationAuthorizationSha")
      if value.fetch("releaseAuthorizationSha") == value.fetch("activationAuthorizationSha")
        fail!("activation authorization must be distinct from release authorization")
      end
      pattern!(value.fetch("executor"), /\Agithub:[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})\z/, "activation-authorization.executor")
      %w[startsAt endsAt rollbackPoint].each { |key| require_string!(value.fetch(key), "activation-authorization.#{key}") }
    end

    def read_file(path)
      fail!("missing required file #{path}") unless path.file?
      contents = path.read
      fail!("#{path} contains prohibited sensitive data") if SENSITIVE.match?(contents)
      contents
    end

    def read_json(path)
      fail!("missing required activation evidence #{path.basename}") unless path.file?
      JSON.parse(read_file(path))
    rescue JSON::ParserError
      fail!("activation evidence #{path.basename} must be valid JSON")
    end

    def require_schema!(value, schema)
      fail!("evidence must be an object") unless value.is_a?(Hash)
      equal!(value.fetch("schema"), schema, "schema")
    end

    def require_string!(value, path)
      fail!("#{path} must be a string") unless value.is_a?(String) && !value.empty?
      fail!("#{path} contains prohibited sensitive data") if SENSITIVE.match?(value)
    end

    def equal!(actual, expected, path)
      fail!("#{path} must match exact activation identity") unless actual == expected
    end

    def pattern!(value, expression, path)
      require_string!(value, path)
      fail!("#{path} has an invalid format") unless expression.match?(value)
      value
    end

    def fail!(message)
      raise FormulaActivationPolicyError, message
    end
  end
end

if $PROGRAM_NAME == __FILE__
  PublicTap::FormulaActivationPolicy.verify!(root: Pathname(__dir__).join(".."))
  puts "Formula activation policy OK"
end
