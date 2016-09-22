#!/usr/bin/env ruby
# Comments out transitive dependencies
# Usage:
#
#     brew bundle dump        # writes Brewfile
#     ruby ./bundle-clean.rb  # updates Brewfile
#
module Utils
  extend self
  def hash_inspect(hash)
    hash.map do |key, value|
      "#{key}: #{value.inspect}"
    end.join(', ').gsub(/"/, "'")
  end
end

class Brewfile
  attr_reader :taps
  attr_reader :brews
  attr_reader :casks

  def initialize
    @taps = {}
    @brews = {}
    @casks = {}
  end

  def as_json
    { taps: @taps, brews: @brews, casks: @casks }
  end

  def to_s
    to_s_section(@taps, 'tap') +
    to_s_section(@brews, 'brew') +
    to_s_section(@casks, 'cask')
  end

  def to_s_section(list, cmd)
    list.map do |key, value|
      dependents = value.delete(:dependents)
      s = "#{cmd} '#{key}'"
      s << ", #{Utils.hash_inspect(value)}" if value != {}
      s = "# #{s} # dependents: #{dependents.join(', ')}" if dependents
      s << "\n"
      s
    end.join('')
  end

  def tap(tap, options = {})
    @taps[tap] = options
  end

  def brew(brew, options = {})
    @brews[brew] = options
  end

  def cask(cask, options = {})
    @casks[cask] = options
  end
end

module BrewfileCleaner
  extend self

  TAPS_PATH = "/usr/local/Homebrew/Library/Taps"
  TAPS = Dir["#{TAPS_PATH}/*/*/Formula"]

  def clean(bf)
    @bf = bf
    dep_tree = trasitives
    dep_tree.each do |pkg, dependents|
      @bf.brews[pkg][:dependents] = dependents
    end
  end

  def trasitives
    files = @bf.brews.map { |k, _| "#{k}.rb" }

    # List of [dependent, pkg] tuples
    dep_map = TAPS.flat_map do |tap_path|
      files_here = files.select { |fn| File.exists?(File.join(tap_path, fn)) }
      `cd #{tap_path.inspect} && git grep "depends_on \\"" #{files_here.join(' ')}`
        .strip
        .split("\n")
        .map { |s| s =~ /^([^.]+).*depends_on "([^"]+)"/ && [$1, $2] }
    end.sort.uniq

    dep_tree = dep_map.reduce({}) do |hash, (dependent, pkg)|
      hash[pkg] ||= []
      hash[pkg] << dependent
      hash
    end
  end
end

module BrewfileCleanerCLI
  extend self
  def run
    bf = Brewfile.new
    bf.instance_eval File.read('Brewfile')
    BrewfileCleaner.clean(bf)
    File.write('Brewfile', bf.to_s)
  end
end

BrewfileCleanerCLI.run
