require 'json'
require 'open3'
require 'timeout'

module JPods
  module Oversight
    PYTHON_CANDIDATES = ['python3', '/usr/bin/python3'].freeze

    class LoadObserver < Sketchup::AppObserver
      def onOpenModel(model)
        JPods::StructurePlacer.cps_shown = false if defined?(JPods::StructurePlacer)
        JPods::Oversight.run_for_model(model, source: 'on_open_model')
      end

      def onNewModel(model)
        JPods::StructurePlacer.cps_shown = false if defined?(JPods::StructurePlacer)
        JPods::Oversight.run_for_model(model, source: 'on_new_model')
      end
    end

    # Only reset flags on first load — not on reload (double-load guard).
    @observer_installed = false unless defined?(@observer_installed)
    @observer = nil unless defined?(@observer)

    def self.install_observer_once
      return if @observer_installed
      @observer = LoadObserver.new
      Sketchup.add_observer(@observer)
      @observer_installed = true
      puts 'JPods Oversight: model-load observer installed.'
    rescue => e
      puts "JPods Oversight install error: #{e.message}"
    end

    def self.run_for_model(model, source: 'manual')
      return unless model
      return if model.path.to_s.empty?

      paths = model_paths(model)
      return unless File.exist?(paths[:network_json])

      noelle = run_noelle(paths)
      natalie = run_natalie(paths)

      summary = [
        "Noelle fixes=#{noelle[:fixed]} removed=#{noelle[:removed]}",
        "Natalie vehicles=#{natalie[:vehicles]} fixes=#{natalie[:fixed]} errors=#{natalie[:errors]}"
      ].join(' | ')
      puts "JPods Oversight (#{source}): #{summary}"
      model.set_attribute('JPods', 'oversight_last', {
        source: source,
        ran_at: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        noelle: noelle,
        natalie: natalie,
      }.to_json)
    rescue => e
      puts "JPods Oversight run error: #{e.message}"
    end

    def self.model_paths(model)
      skp_path = model.path
      dir = File.dirname(skp_path)
      base = File.basename(skp_path, '.skp')
      followme_json = File.join(dir, "#{base}.followme.json")
      {
        skp: skp_path,
        dir: dir,
        base: base,
        network_json: followme_json,
        vehicles_json: File.join(dir, "#{base}.vehicles.json"),
        itineraries_json: File.join(dir, "#{base}_itineraries.json"),
      }
    end

    def self.python_executable
      PYTHON_CANDIDATES.find { |p| system("#{p} --version >/dev/null 2>&1") }
    end

    def self.run_python(script_path, args, timeout_s: 20)
      py = python_executable
      return({ ok: false, message: 'python3 not found' }) unless py

      stdout = ''
      stderr = ''
      status = nil
      Timeout.timeout(timeout_s) do
        stdout, stderr, status = Open3.capture3(py, script_path, *args)
      end

      data = {}
      begin
        data = JSON.parse(stdout)
      rescue
        data = { ok: status && status.success?, stdout: stdout.to_s.strip }
      end
      data['stderr'] = stderr.to_s.strip unless stderr.to_s.strip.empty?
      data
    rescue Timeout::Error
      { ok: false, message: 'timeout' }
    rescue => e
      { ok: false, message: e.message }
    end

    def self.run_noelle(paths)
      script = File.join(__dir__, 'noelle_oversight.py')
      return { ok: false, fixed: 0, removed: 0, message: 'noelle_oversight.py missing' } unless File.exist?(script)

      result = run_python(script, ['--network-json', paths[:network_json]])
      {
        ok: result['ok'] == true,
        fixed: result['fixed'].to_i,
        removed: result['removed'].to_i,
        message: result['message'].to_s,
      }
    end

    def self.run_natalie(paths)
      script = File.join(__dir__, 'natalie_oversight.py')
      return { ok: false, vehicles: 0, fixed: 0, errors: 0, message: 'natalie_oversight.py missing' } unless File.exist?(script)

      args = [
        '--network-json', paths[:network_json],
        '--itineraries-json', paths[:itineraries_json],
        '--vehicles-json', paths[:vehicles_json],
      ]
      result = run_python(script, args)
      {
        ok: result['ok'] == true,
        vehicles: result['vehicles'].to_i,
        fixed: result['fixed'].to_i,
        errors: result['errors'].to_i,
        message: result['message'].to_s,
      }
    end
  end
end
