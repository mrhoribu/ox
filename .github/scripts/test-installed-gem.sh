#!/bin/sh
# Installs a precompiled Ox gem and runs the test suite against it.
#
# Usage: .github/scripts/test-installed-gem.sh PLATFORM GEM_DIR
#
# GEM_DIR holds the source gem and the PLATFORM gem. Ox is installed by name, as
# a user would, so this also checks that RubyGems picks the native gem over the
# source gem.
#
# Run from the repository root. It deletes lib/ and ext/ first so the tests
# cannot load the in-tree sources and must use the installed gem, so only run
# it in a throwaway checkout (CI).
set -eu

platform=$1
gem_dir=$2

rm -rf lib ext

(cd "$gem_dir" && gem install --local --no-document ox)

# Fail if RubyGems picked the source gem or would have compiled anything, and
# if Ox did not load the binary built for this Ruby's minor version.
# shellcheck disable=SC2016 # Ruby code, not shell expansions
ruby -e '
  spec = Gem::Specification.find_by_name("ox")
  abort "RubyGems picked the source gem over the #{ARGV[0]} gem" if spec.platform.to_s == "ruby"
  abort "the native gem still declares extensions: #{spec.extensions}" unless spec.extensions.empty?
  require "ox"
  loaded = $LOADED_FEATURES.grep(%r{/ox/\d+\.\d+/ox\.(so|bundle)\z})
  abort "did not load a precompiled binary" if loaded.empty?
  puts "ox #{Ox::VERSION} (#{spec.platform}) on ruby #{RUBY_VERSION}: #{loaded.first}"
' "$platform"

ruby test/tests.rb
ruby test/sax/sax_test.rb

# The same files rake test runs (see the Rakefile for why these are excluded).
tests=$(find test -name '*_test.rb' \
  ! -path test/cache_test.rb \
  ! -path test/cache8_test.rb \
  ! -path test/sax/smart_test.rb \
  ! -path test/sax/sax_test.rb | sort)
# shellcheck disable=SC2086 # split the file list into arguments
# ARGV is cleared so test-unit does not also treat the paths as its own options.
ruby -e 'files = ARGV.dup; ARGV.clear; files.each { |f| require File.expand_path(f) }' $tests
