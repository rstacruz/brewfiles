#!/usr/bin/env ruby
# Finds dependents that can be removed
#
#     ruby ./brew-uninstall.rb ffmpeg
#     # These packages will be removed: ffmpeg faac lame libvorbis libvpx x264 xvid
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

module BrewLoader
  def self.load(brewfile)
    `brew list -1`.strip.split("\n").each do |pkg|
      brewfile.brews[pkg] = {}
    end
    brewfile
  end
end

# Marks dependents in a Brewfile tree
module BrewExplorer
  extend self

  TAPS_PATH = "/usr/local/Homebrew/Library/Taps"
  TAPS = Dir["#{TAPS_PATH}/*/*/Formula"]

  def find_deps(bf)
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

module BrewDepChecker
  def self.check_dependencies(brewfile, pkgs)
    brews = brewfile.brews
    to_uninstall = []
    brews.each do |pkg, options|
      dependents = options[:dependents] || []
      if dependents.length != 0 && (dependents | pkgs) == pkgs
        to_uninstall << pkg
      end
    end

    to_uninstall.sort!.uniq!

    # Repeat if necessary
    if to_uninstall.length != 0
      to_uninstall = BrewDepChecker.check_dependencies(brewfile, to_uninstall)
    end

    pkgs + to_uninstall
  end
end

module BrewUninstaller
  extend self
  def run
    bf = Brewfile.new
    bf = BrewLoader.load(bf)
    bf = BrewExplorer.find_deps(bf)

    pkgs = ARGV

    # dependents = BrewDepChecker.check_dependencies(bf, pkgs)
    # puts "These packages depend on #{pkgs.join(' ')}: #{dependents.join(' ')}"

    output = BrewDepChecker.check_dependencies(bf, pkgs)
    puts "These packages will be removed: #{output.join(' ')}"
  end
end

BrewUninstaller.run
