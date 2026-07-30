# ── ConnectionPoint — typed value object for CP keys ──────────────────────────
#
# Canonical format: lowercase station id + dot + integer stub index.
#   "s020.0"   ← current standard
#
# Legacy format (stored in older .skp entity attributes):
#   "S020.CP0"
#
# parse() accepts both.  normalize() converts either to canonical form.
#
# Examples:
#   cp = JPods::ConnectionPoint.new(structure_id: 's020', index: 0)
#   cp.to_key   #=> "s020.0"
#
#   cp = JPods::ConnectionPoint.parse("S020.CP0")
#   cp.structure_id  #=> "s020"
#   cp.index         #=> 0
#   cp.to_key        #=> "s020.0"
#
#   JPods::ConnectionPoint.normalize("S020.CP0")  #=> "s020.0"

module JPods
  class ConnectionPoint
    attr_reader :structure_id, :index

    def initialize(structure_id:, index:)
      @structure_id = structure_id.to_s.downcase
      @index = index.to_i
    end

    def self.parse(key)
      s = key.to_s.strip
      # Canonical: "s020.0"
      m = s.match(/\A([A-Za-z][A-Za-z0-9]*)\.(\d+)\z/)
      return new(structure_id: m[1], index: m[2].to_i) if m
      # Legacy: "S020.CP0"
      m = s.match(/\A([^.]+)\.CP(\d+)\z/i)
      return new(structure_id: m[1], index: m[2].to_i) if m
      nil
    end

    def self.normalize(key)
      cp = parse(key)
      cp ? cp.to_key : key.to_s.downcase.strip
    end

    def to_key
      "#{@structure_id}.#{@index}"
    end

    def to_s
      to_key
    end

    def ==(other)
      other.is_a?(ConnectionPoint) && to_key == other.to_key
    end

    def hash
      to_key.hash
    end

    alias eql? ==
  end
end
