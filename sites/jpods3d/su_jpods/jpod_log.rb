# ── JPods Log — per-agent verbosity + memory ──────────────────────────────────
#
# Each crew member has their own log level and memory (facet).
# The crew controls their own verbosity independently:
#
#   JPods::Log.set(:sally, :debug)    # Sally verbose, others unchanged
#   JPods::Log.set(:natalie, :quiet)  # Natalie quiet
#   JPods::Log.level = :normal        # set global default for all
#
# Per-agent logging:
#   JPods::Log.sally("arrived ps4")           # respects Sally's level
#   JPods::Log.natalie("route s002→s003")     # respects Natalie's level
#   JPods::Log.nora("t=0.456 gw_c_1_2")      # respects Nora's level
#   JPods::Log.noelle("24 tracks validated")  # respects Noelle's level
#
# Generic logging (uses global level):
#   JPods::Log.info("message")       # :normal and above
#   JPods::Log.detail("message")     # :detailed and above
#   JPods::Log.debug("message")      # :debug only
#   JPods::Log.fault("message")      # always shown
#   JPods::Log.event("message")      # :normal and above, timestamped
#
# Memory (facets):
#   JPods::Log.remember(:sally, "ps3 high turnover — 47 arrivals")
#   JPods::Log.recall(:sally)  → reads facet observations
#
# Facets persist at ~/Allie/facets/{agent}/facet.json

require 'json'

module JPods
  module Log

    LEVELS = { quiet: 0, normal: 1, detailed: 2, debug: 3 }.freeze
    AGENTS = %i[sally natalie nora noelle animation claude].freeze

    @@global_level = :normal
    @@agent_levels = {}  # agent → level (overrides global)
    @@facet_dir = File.expand_path('~/Allie/facets')

    # ── Global level ───────────────────────────────────────────────────────

    def self.level
      @@global_level
    end

    def self.level=(new_level)
      new_level = new_level.to_sym
      unless LEVELS.key?(new_level)
        puts "[JPods Log] unknown level '#{new_level}' — use: #{LEVELS.keys.join(', ')}"
        return
      end
      old = @@global_level
      @@global_level = new_level
      puts "[JPods Log] global: #{old} → #{new_level}"
    end

    # ── Per-agent level ────────────────────────────────────────────────────

    def self.set(agent, level)
      agent = agent.to_sym
      level = level.to_sym
      unless LEVELS.key?(level)
        puts "[JPods Log] unknown level '#{level}'"
        return
      end
      old = @@agent_levels[agent] || @@global_level
      @@agent_levels[agent] = level
      puts "[JPods Log] #{agent}: #{old} → #{level}"
    end

    def self.agent_level(agent)
      @@agent_levels[agent.to_sym] || @@global_level
    end

    def self.show_levels
      puts "[JPods Log] global: #{@@global_level}"
      AGENTS.each do |a|
        lvl = @@agent_levels[a]
        puts "  #{a}: #{lvl || '(global)'}"
      end
    end

    # ── Per-agent log methods ──────────────────────────────────────────────

    AGENTS.each do |agent|
      # JPods::Log.sally("msg")          → info level for sally
      # JPods::Log.sally_detail("msg")   → detail level for sally
      # JPods::Log.sally_debug("msg")    → debug level for sally
      # JPods::Log.sally_fault("msg")    → always shown

      define_singleton_method(agent) do |msg|
        return unless LEVELS[agent_level(agent)] >= LEVELS[:normal]
        puts "[#{agent.capitalize}] #{msg}"
      end

      define_singleton_method("#{agent}_detail") do |msg|
        return unless LEVELS[agent_level(agent)] >= LEVELS[:detailed]
        puts "[#{agent.capitalize}] #{msg}"
      end

      define_singleton_method("#{agent}_debug") do |msg|
        return unless LEVELS[agent_level(agent)] >= LEVELS[:debug]
        puts "[#{agent.capitalize}] #{msg}"
      end

      define_singleton_method("#{agent}_fault") do |msg|
        puts "⛔ [#{agent.capitalize}] #{msg}"
      end

      define_singleton_method("#{agent}_event") do |msg|
        return unless LEVELS[agent_level(agent)] >= LEVELS[:normal]
        ts = Time.now.strftime('%H:%M:%S')
        puts "[#{ts}] [#{agent.capitalize}] #{msg}"
      end
    end

    # ── Generic log methods (global level) ─────────────────────────────────

    def self.fault(msg)
      puts "⛔ #{msg}"
    end

    def self.event(msg)
      return unless LEVELS[@@global_level] >= LEVELS[:normal]
      ts = Time.now.strftime('%H:%M:%S')
      puts "[#{ts}] #{msg}"
    end

    def self.info(msg)
      return unless LEVELS[@@global_level] >= LEVELS[:normal]
      puts msg
    end

    def self.detail(msg)
      return unless LEVELS[@@global_level] >= LEVELS[:detailed]
      puts msg
    end

    def self.debug(msg)
      return unless LEVELS[@@global_level] >= LEVELS[:debug]
      puts msg
    end

    # ── Convenience modes ──────────────────────────────────────────────────

    def self.template_mode!
      self.level = :detailed
    end

    def self.network_mode!
      self.level = :normal
    end

    # ── Agent memory (facets) ──────────────────────────────────────────────
    # Each agent can remember observations. Stored at ~/Allie/facets/{agent}/facet.json
    # Allie reads these nightly. Crew health check reports accumulated experience.

    def self.remember(agent, observation, data: nil)
      agent = agent.to_sym
      facet = _load_facet(agent)
      facet['observations'] ||= []
      entry = {
        'ts' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'observation' => observation.to_s,
      }
      entry['data'] = data if data
      facet['observations'] << entry

      # Keep last 100 observations per agent
      facet['observations'] = facet['observations'].last(100)
      _save_facet(agent, facet)

      puts "[#{agent.capitalize} memory] #{observation}" if LEVELS[agent_level(agent)] >= LEVELS[:normal]
    end

    def self.recall(agent, n: 10)
      agent = agent.to_sym
      facet = _load_facet(agent)
      obs = facet['observations'] || []
      recent = obs.last(n)
      if recent.empty?
        puts "[#{agent.capitalize} memory] no observations"
      else
        puts "[#{agent.capitalize} memory] #{obs.size} total, last #{recent.size}:"
        recent.each { |o| puts "  #{o['ts']}: #{o['observation']}" }
      end
      recent
    end

    def self.recall_all
      AGENTS.each do |agent|
        facet = _load_facet(agent)
        obs = facet['observations'] || []
        next if obs.empty?
        puts "[#{agent.capitalize}] #{obs.size} observation(s), latest: #{obs.last['observation']}"
      end
    end

    # ── Defect log ──────────────────────────────────────────────────────
    # Append-only JSON lines file. Each line is one defect record.
    # Agents call JPods::Log.defect() when they detect a problem.
    # Designer calls JPods::Log.flag() to report what they see.
    # Allie reads this nightly for pattern detection.
    #
    # defect.json lives next to the model file so each network has its own log.

    @@defect_path = nil

    def self.defect_path
      return @@defect_path if @@defect_path
      model = Sketchup.active_model rescue nil
      return nil unless model && model.path && !model.path.empty?
      dir = File.dirname(model.path)
      @@defect_path = File.join(dir, 'defect.json')
    end

    def self.reset_defect_path
      @@defect_path = nil
    end

    # Agent-reported defect
    def self.defect(agent, type, detail, data: nil)
      path = defect_path
      return unless path

      anim_t = defined?(AnimationV2) ? (AnimationV2.elapsed_s rescue nil) : nil

      record = {
        'dt'         => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'local'      => Time.now.strftime('%H:%M:%S'),
        'model_time' => anim_t&.round(1),
        'source'     => 'agent',
        'agent'      => agent.to_s,
        'type'       => type.to_s,
        'detail'     => detail.to_s,
      }
      record['data'] = data if data

      File.open(path, 'a') { |f| f.puts(record.to_json) }
      puts "⛔ [Defect] #{agent}/#{type}: #{detail}"
    rescue => ex
      puts "[Defect] write error: #{ex.message}"
    end

    # Designer-reported flag (user saw a problem)
    def self.flag(note, agent: nil, data: nil)
      path = defect_path
      return unless path

      anim_t = defined?(AnimationV2) ? (AnimationV2.elapsed_s rescue nil) : nil

      record = {
        'dt'         => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'local'      => Time.now.strftime('%H:%M:%S'),
        'model_time' => anim_t&.round(1),
        'source'     => 'designer',
        'agent'      => agent&.to_s,
        'type'       => 'user_flag',
        'detail'     => note.to_s,
      }
      record['data'] = data if data

      File.open(path, 'a') { |f| f.puts(record.to_json) }
      puts "🚩 [Flag] #{note}"
    rescue => ex
      puts "[Flag] write error: #{ex.message}"
    end

    # Read defects (for display or analysis)
    def self.defects(last_n: 20)
      path = defect_path
      return [] unless path && File.exist?(path)
      lines = File.readlines(path, encoding: 'utf-8').last(last_n)
      lines.map { |l| JSON.parse(l.strip) rescue nil }.compact
    rescue
      []
    end

    private

    def self._facet_path(agent)
      dir = File.join(@@facet_dir, agent.to_s)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      File.join(dir, 'facet.json')
    end

    def self._load_facet(agent)
      path = _facet_path(agent)
      File.exist?(path) ? JSON.parse(File.read(path, encoding: 'utf-8')) : {}
    rescue
      {}
    end

    def self._save_facet(agent, data)
      path = _facet_path(agent)
      File.write(path, JSON.pretty_generate(data), encoding: 'utf-8')
    rescue => ex
      puts "[JPods Log] facet save error (#{agent}): #{ex.message}"
    end

  end
end
