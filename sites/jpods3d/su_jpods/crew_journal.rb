# ── Crew Journal — per-network log for events, issues, concerns ───────────────
#
# Each network model gets a {model}.crew.json in its folder.
# Any crew member can write entries. Allie reads these nightly.
#
# Usage:
#   JPods::CrewJournal.log(:sally, model, "ps3 full — 3 pods denied")
#   JPods::CrewJournal.log(:natalie, model, "EP12 stop-wait spike", severity: :warn)
#   JPods::CrewJournal.log(:nora, model, "speed cap 4.2ms on seg_s001_1_s003_1")
#   JPods::CrewJournal.read(model)            # show recent entries
#   JPods::CrewJournal.read(model, agent: :sally)  # Sally's entries only
#
# Also handles trip_reports purge — Natalie cleans old trip files.

require 'json'
require 'fileutils'

module JPods
  module CrewJournal

    MAX_ENTRIES = 500             # per network journal

    # Defaults — overridden per-network in network.json "natalie.trip_reports" section
    DEFAULT_TRIP_REPORTS_KEEP    = 50     # keep newest N per folder
    DEFAULT_TRIP_REPORTS_ARCHIVE = false  # false = delete, true = move to archive/

    # ── Log an entry ───────────────────────────────────────────────────────
    def self.log(agent, model, message, severity: :info, data: nil)
      path = _journal_path(model)
      return unless path

      journal = _load(path)
      journal['entries'] ||= []

      entry = {
        'ts'       => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'agent'    => agent.to_s,
        'severity' => severity.to_s,
        'message'  => message.to_s,
      }
      entry['data'] = data if data

      journal['entries'] << entry

      # Cap at MAX_ENTRIES
      journal['entries'] = journal['entries'].last(MAX_ENTRIES) if journal['entries'].size > MAX_ENTRIES

      # Update summary counts
      journal['summary'] ||= {}
      journal['summary']['total_entries'] = journal['entries'].size
      journal['summary']['last_updated'] = entry['ts']
      journal['summary']['by_agent'] = journal['entries'].group_by { |e| e['agent'] }
                                                          .transform_values(&:size)
      journal['summary']['by_severity'] = journal['entries'].group_by { |e| e['severity'] }
                                                             .transform_values(&:size)

      _save(path, journal)

      if defined?(JPods::Log)
        case severity.to_sym
        when :fault then JPods::Log.fault "[#{agent}] #{message}"
        when :warn  then JPods::Log.info "⚠ [#{agent}] #{message}"
        else JPods::Log.detail "[#{agent} journal] #{message}"
        end
      end
    end

    # ── Read entries ───────────────────────────────────────────────────────
    def self.read(model, agent: nil, n: 20)
      path = _journal_path(model)
      return unless path && File.exist?(path)

      journal = _load(path)
      entries = journal['entries'] || []
      entries = entries.select { |e| e['agent'] == agent.to_s } if agent
      recent = entries.last(n)

      puts ""
      puts "═══ Crew Journal — #{File.basename(path)} ═══"
      if recent.empty?
        puts "  (no entries#{agent ? " for #{agent}" : ''})"
      else
        recent.each do |e|
          sev = e['severity'] == 'fault' ? '⛔' : (e['severity'] == 'warn' ? '⚠' : '·')
          puts "  #{sev} #{e['ts']} [#{e['agent']}] #{e['message']}"
        end
      end

      # Show summary
      summary = journal['summary'] || {}
      if summary['by_agent']
        puts "  ── #{summary['total_entries']} total: #{summary['by_agent'].map { |a, n| "#{a}=#{n}" }.join(', ')}"
      end
      puts ""
      recent
    end

    # ── Natalie: manage trip reports ─────────────────────────────────────
    # Keep newest TRIP_REPORTS_KEEP per folder. Archive the rest.
    # Natalie needs history to understand patterns — don't blindly delete.
    # Read trip_reports settings from network.json
    # natalie.trip_reports: { keep: 50, archive: false }
    def self._trip_report_settings(model)
      nj_path = File.join(File.dirname(model.path),
                          "#{File.basename(model.path, '.skp')}.network.json")
      if File.exist?(nj_path)
        nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
        tr = nj.dig('natalie', 'trip_reports') || {}
        keep    = tr['keep'].to_i
        archive = tr['archive']
        {
          keep:    keep > 0 ? keep : DEFAULT_TRIP_REPORTS_KEEP,
          archive: archive.nil? ? DEFAULT_TRIP_REPORTS_ARCHIVE : archive,
        }
      else
        { keep: DEFAULT_TRIP_REPORTS_KEEP, archive: DEFAULT_TRIP_REPORTS_ARCHIVE }
      end
    rescue
      { keep: DEFAULT_TRIP_REPORTS_KEEP, archive: DEFAULT_TRIP_REPORTS_ARCHIVE }
    end

    def self.purge_trip_reports(model)
      settings = _trip_report_settings(model)
      managed = 0

      # Network trip_reports
      model_dir = File.dirname(model.path)
      managed += _manage_trip_folder(File.join(model_dir, 'trip_reports'), settings)

      # Template trip_reports
      plugin_dir = File.dirname(__FILE__)
      Dir.glob(File.join(plugin_dir, 'templates', 'track_formations', '*', 'trip_reports')).each do |dir|
        managed += _manage_trip_folder(dir, settings)
      end

      if managed > 0
        action = settings[:archive] ? 'archived' : 'deleted'
        msg = "#{action} #{managed} old trip report(s) — kept newest #{settings[:keep]} per folder"
        log(:natalie, model, msg)
        puts "[Natalie] #{msg}"
      end

      managed
    end

    def self._manage_trip_folder(dir, settings)
      return 0 unless File.directory?(dir)
      files = Dir.glob(File.join(dir, '*.json')).sort_by { |f| File.mtime(f) }
      return 0 if files.size <= settings[:keep]

      excess = files[0...(files.size - settings[:keep])]
      return 0 if excess.empty?

      if settings[:archive]
        archive_dir = File.join(dir, 'archive')
        FileUtils.mkdir_p(archive_dir)
        excess.each do |f|
          FileUtils.mv(f, File.join(archive_dir, File.basename(f))) rescue nil
        end
      else
        excess.each { |f| File.delete(f) rescue nil }
      end

      excess.size
    end

    private

    def self._journal_path(model)
      return nil unless model && model.path && !model.path.empty?
      model_dir = File.dirname(model.path)
      model_base = File.basename(model.path, '.skp')
      File.join(model_dir, "#{model_base}.crew.json")
    end

    def self._load(path)
      return {} unless File.exist?(path)
      JSON.parse(File.read(path, encoding: 'utf-8'))
    rescue
      {}
    end

    def self._save(path, data)
      File.write(path, JSON.pretty_generate(data), encoding: 'utf-8')
    rescue => ex
      puts "[CrewJournal] save error: #{ex.message}"
    end

  end
end
