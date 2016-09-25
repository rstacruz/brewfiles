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
  attr_accessor :taps
  attr_accessor :brews
  attr_accessor :casks

  def initialize
    @taps = {}
    @brews = {}
    @casks = {}
  end
end

class BrewfileReader
  attr_reader :brewfile

  def self.read(brewfile, source)
    self.new(brewfile).read(source).brewfile
  end

  def initialize(brewfile)
    @brewfile = brewfile
  end

  def read(source)
    instance_eval source
    self
  end

  def tap(tap, options = {})
    brewfile.taps[tap] = options
  end

  def brew(brew, options = {})
    brewfile.brews[brew] = options
  end

  def cask(cask, options = {})
    brewfile.casks[cask] = options
  end
end

# Marks dependents in a Brewfile tree
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

    @bf
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

    dep_map.reduce({}) do |hash, (dependent, pkg)|
      hash[pkg] ||= []
      hash[pkg] << dependent
      hash
    end
  end
end

module BrewfileRenderer
  extend self

  def render(brewfile)
    to_s_section(brewfile.taps, 'tap') +
    to_s_section(brewfile.brews, 'brew') +
    to_s_section(brewfile.casks, 'cask')
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

end

module BrewfileCleanerCLI
  extend self
  def run
    bf = Brewfile.new
    bf = BrewfileReader.read(bf, File.read('Brewfile'))
    bf = BrewfileCleaner.clean(bf)
    data = BrewfileRenderer.render(bf)
    File.write('Brewfile', data)
  end
end

BrewfileCleanerCLI.run
