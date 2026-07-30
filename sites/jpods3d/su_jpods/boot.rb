require 'sketchup.rb'
require 'extensions.rb'

# ── Extension registration ─────────────────────────────────────────────────────
JPODS_ROOT = File.dirname(__FILE__).freeze unless defined?(JPODS_ROOT)

unless $jpods_booted

  # ── Logger ────────────────────────────────────────────────────────────────
  begin
    load File.join(JPODS_ROOT, 'jpod_logging.rb')
    JPods::Logging.install! if defined?(JPods::Logging)
  rescue => e
    STDERR.puts "JPods logging install warning: #{e.message}"
  end

  # ── Core modules in dependency order ───────────────────────────────────────
  # v2 architecture: clean modules, single duty, no legacy
  [
    # Infrastructure
    'jpod_constants',
    'jpod_defaults',
    'jpod_layer_manager',
    'jpod_utilities',
    'jpod_project',
    'jpod_terrain',
    'jpod_loader',
    # Tools
    'jpod_structure_tool',
    'jpod_station_names_dialog',
    # Build pipeline — migrated to v2
    'compute/connection_point',           # ConnectionPoint value object (migrated)
    'build/build_extrude',                # Upright FollowMe beam extrusion (migrated)
    'build/build_path',                   # PathBuilder — terrain following, grade limits (migrated)
    # jpod_platform — DEAD for v2. vehicle_path_for migrated to compat shim.
    'build/build_bezier',                 # Proven bezier math (migrated from jpod_network.rb)
    'build/build_helpers',                # Entity lookup, CP resolution (migrated)
    'build/build_entities',               # Beam geometry, columns, solar (migrated)
    'build/build',                        # Build orchestrator — Plan → PathBuilder → BeamExtrude
    'network/network_editor',             # NetworkEditor v2 — slim JSON I/O (migrated from 2520-line codearchive)
    'tools/connect_tool',                 # Connect Guideways viewport tool (migrated from codearchive)
    'crew_journal',                       # Per-network crew journal + trip report purge
    'crew_health',                        # Crew health check — each agent verifies their domain
    'jpod_console2',                      # Console v2 — clean, v2-native, no legacy
    'jpod_log',                 # Crew-adjustable log verbosity
    'pod_helpers',              # Pod entity creation utilities
    # v2 modules
    'compute/compute',        # Compute v2 — three-phase pipeline
    'sally/sally',            # Sally v2 — rich ParkingSlot + PodRecord objects
    'sally/sally_compat',     # Sally compat — console tests call JPods::Sally (old API)
    'natalie/natalie',        # Natalie v2 — BFS routing + maneuver building
    'nora/nora',              # Nora v2 — pod state machine + movement
    'noelle_v2/noelle_v2',    # Noelle v2 — network.json from Compute output
    'animation/animation',    # Animation v2 — tick loop orchestrator
    'jpod_ezone',             # EZone — zipper merge at junctions
    'station_tests',            # v2 station tests (shuffle, depart, arrive)
    # Compatibility shim (console still calls old module names)
    'jpod_guideway_compat',
    # Services
    'jpod_oversight',
    'jpod_conflict_detector',
    # UI (last)
    'jpod_console',
  ].each do |name|
    path = File.join(JPODS_ROOT, "#{name}.rb")
    if File.exist?(path)
      begin
        prev_verbose = $VERBOSE
        $VERBOSE = nil
        load path
      rescue => e
        puts "JPods load error — #{name}: #{e.message}"
        puts e.backtrace.first(3).join("\n")
      ensure
        $VERBOSE = prev_verbose
      end
    else
      puts "⚠️  JPods: #{name}.rb not found"
    end
  end

  # ── Observer registration ─────────────────────────────────────────────────
  module JPods
    JPods::Oversight.install_observer_once if defined?(JPods::Oversight)

    unless $jpods_app_observer_installed
      $jpods_app_observer_installed = true
      Sketchup.add_observer(
        Class.new(Sketchup::AppObserver) do
          def on_model(model)
            JPods::LayerManager.ensure_tags(model) if defined?(JPods::LayerManager)
            if defined?(JPods::StructurePlacer) && JPods::StructurePlacer.respond_to?(:install_paste_observer)
              JPods::StructurePlacer.install_paste_observer(model)
            end
          end
          alias onOpenModel on_model
          alias onNewModel  on_model
        end.new
      )
    end
  end

  $jpods_booted = true
  puts '✅  JPods plugin loaded  (v4.0 — su_jpods v2)'

  # First-run setup offer
  UI.start_timer(3.0, false) do
    begin
      JPods::Project.offer_setup(trigger: :startup) if defined?(JPods::Project)
    rescue => e
      puts "JPods setup offer error: #{e.message}"
    end
  end

  # Tag seeding for auto-opened model
  UI.start_timer(4.0, false) do
    begin
      model = Sketchup.active_model
      JPods::LayerManager.ensure_tags(model) if model && defined?(JPods::LayerManager)
    rescue => e
      puts "JPods startup check error: #{e.message}"
    end
  end

  # Register menus
  $jpods_main_loaded = true
  begin
    load File.join(JPODS_ROOT, 'main.rb')
  rescue => e
    puts "JPods menu registration error: #{e.message}"
    puts e.backtrace.first(3).join("\n")
  end

end # unless $jpods_booted

# ── Reload helper ────────────────────────────────────────────────────────────
module JPods
  def self.reload_plugin
    $jpods_booted = nil
    load File.join(JPODS_ROOT, 'boot.rb')
    puts 'JPods plugin reloaded.'
  rescue => e
    puts "Reload failed: #{e.message}"
  end
end
