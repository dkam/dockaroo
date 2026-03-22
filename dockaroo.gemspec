# frozen_string_literal: true

require_relative "lib/dockaroo/version"

Gem::Specification.new do |spec|
  spec.name = "dockaroo"
  spec.version = Dockaroo::VERSION
  spec.authors = ["Dan Milne"]
  spec.email = ["d@nmilne.com"]

  spec.summary = "Lightweight Docker container manager for multi-host deployments over SSH"
  spec.description = "Dockaroo deploys pre-built Docker images across multiple hosts using SSH and direct docker commands. Supports host networking (Tailscale-compatible), replicas, and an interactive TUI for status and log monitoring."
  spec.homepage = "https://github.com/dkam/dockaroo"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dkam/dockaroo"
  spec.metadata["changelog_uri"] = "https://github.com/dkam/dockaroo/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "bubbletea"
  spec.add_dependency "lipgloss"
  spec.add_dependency "bubbles"
  spec.add_dependency "sshkit", ">= 1.23.0", "< 2.0"
end
