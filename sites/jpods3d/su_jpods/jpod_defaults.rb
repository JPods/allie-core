require 'json'

# JPods::Defaults — plugin-wide operational defaults with two-level override.
#
# Priority (highest first):
#   1. network.json "defaults" section   — per-network override (speed, dwell, etc.)
#   2. defaults.json                     — plugin-wide setting; written by Set Speed
#   3. FALLBACK hash                     — hardcoded last resort if file is missing
#
# Speed is NEVER read from or written to SketchUp entity attributes.
# models carry geometry; this module carries operational state.
#
# Network override example — add to network.json alongside your model.skp:
#   { "defaults": { "speed_ms": 6.0, "authorized_speed_ms": 6.0 } }

module JPods
  module Defaults

    DEFAULTS_PATH = File.join(File.dirname(__FILE__), 'defaults.json').freeze

    FALLBACK = {
      'speed_ms'                  => 8.3,
      'authorized_speed_ms'       => 8.3,
      'speed_deviation_ratio_min' => 0.3,
      'speed_deviation_ratio_max' => 1.5,
      'anim_fps'                  => 24,
      'natalie_period_s'          => 2.0,
      'natalie_dispatch_n'        => 3,
      'platform_dwell_s'          => 10.0,
      'min_spacing_m'             => 3.0
    }.freeze

    @cache = nil

    # Read one key. Optional model enables network.json overrides.
    def self.get(key, model: nil)
      k = key.to_s
      if model
        net = _network_overrides(model)
        return net[k] if net.key?(k)
      end
      d = _load
      d.key?(k) ? d[k] : FALLBACK[k]
    end

    # Write one key to defaults.json (invalidates cache).
    # Does NOT touch any SketchUp entity attribute.
    def self.set(key, value)
      d = _load.merge(key.to_s => value)
      File.write(DEFAULTS_PATH, JSON.pretty_generate(d))
      @cache = d
    rescue => e
      puts "[Defaults] write failed: #{e.message}"
    end

    # Full merged hash: FALLBACK < defaults.json < network.json.
    def self.all(model: nil)
      net = model ? _network_overrides(model) : {}
      FALLBACK.merge(_load).merge(net)
    end

    # Invalidate cache (call after external edits to defaults.json).
    def self.reload
      @cache = nil
    end

    private

    def self._load
      return @cache if @cache
      return FALLBACK.dup unless File.exist?(DEFAULTS_PATH)
      @cache = JSON.parse(File.read(DEFAULTS_PATH))
    rescue => e
      puts "[Defaults] load failed: #{e.message} — using fallback"
      FALLBACK.dup
    end

    # Read the "defaults" section from network.json in the model directory.
    # Returns {} if the model has no path, no network.json, or no "defaults" key.
    def self._network_overrides(model)
      return {} unless model.respond_to?(:path) && !model.path.to_s.empty?
      net_path = File.join(File.dirname(model.path), 'network.json')
      return {} unless File.exist?(net_path)
      data = JSON.parse(File.read(net_path))
      data['defaults'] || {}
    rescue
      {}
    end

  end
end
