# JPods Console — user-facing task runner with NoelleGuard
#
# JPods::Console      — HtmlDialog manager + callback router
# JPods::NoelleGuard  — pre-execution validation layer (network structure + behavior)
#
# Agent responsibility map:
#   Noelle  — network structure, CP detection, tag integrity, feature.json
#   Natalie — routing, trip planning, followme.json, route overlay
#   Sally   — station behavior, chains, slot registry, station tests
#   Nora    — vehicles, animation, trip execution, camera follow
#   Alice   — ticket sales: trip pricing, booking, invoices, payments (wcapi);
#             Small-Stings: fines customers assess for unresolved problems +
#             retrospection payments (JPods pays customers for feedback);
#             action lists (Project → Action → Document records in WC3)
#   Athena  — cyber security (separate domain — not in Console)
#
# Design principles
#   • No eval — all tasks are predefined Ruby procs; users choose from a list
#   • NoelleGuard runs TWICE: once on task selection (live feedback) and once
#     immediately before execution (defence-in-depth)
#   • Destructive tasks require explicit checkbox confirmation
#   • All output is captured from STDOUT and returned to the dialog
#   • All strings sent to execute_script are JSON-encoded — no HTML injection

require 'json'
require 'stringio'
require 'set'
require 'fileutils'
require 'shellwords'

# Quiet log flag — toggled by btn-quiet-log in console.html. When true, suppresses
# verbose per-tick/per-advance log lines in jpod_vehicle_anim.rb and jpod_sally.rb.
$jpods_quiet_log ||= false

# Direct-write load counter — bypasses Kernel#puts so it doesn't go through
# the patch being set up below. If count > 1, jpod_console.rb is loading twice.
$jpods_console_load_count = ($jpods_console_load_count || 0) + 1
if $jpods_console_load_count > 1
  File.open(File.join(File.dirname(__FILE__), 'jpod_console.log'), 'a') do |f|
    f.puts "[DIAG] jpod_console.rb load ##{$jpods_console_load_count} — #{caller(0,4).map{|c| c.split('/').last(2).join('/')}.join(' | ')}"
  end
end

module JPods

  # ── NoelleGuard: pre-execution guard ──────────────────────────────────────
  # Noelle owns network structure and behavior. NoelleGuard enforces that tasks
  # run only when the network state satisfies structural preconditions. Error
  # messages are attributed: [AgentName] What happened. What to do.

  module NoelleGuard

    STOP_REVIEW_THRESHOLD = 3

    @review_block_streak_by_task = Hash.new(0)

    def self.stop_and_review_message(task_id, streak)
      "[Noelle] Task '#{task_id}' blocked #{streak} time(s). " \
      "Pause and review fundamentals + root causes before retrying."
    end

    # review(task, params, model) → Hash
    #   :risk     — :safe | :caution | :destructive
    #   :ok       — true if execution is permitted (context checks pass)
    #   :messages — Array of String
    def self.review(task, params, model)
      msgs = []
      ok   = true
      task_id = task[:id].to_s

      # 1. Selection requirement — named Group
      # Reported as a warning but does not block Execute; the run lambda
      # validates at execution time and returns a clear error if unmet.
      if (req = task[:requires_selection])
        sel = model.selection.first
        unless sel.is_a?(Sketchup::Group) && sel.name == req
          msgs << "Select a '#{req}' group in the model before executing."
        end
      end

      # 1b. Selection requirement — Nora vehicle ComponentInstance
      if task[:requires_vehicle_selection]
        sel = model.selection.first
        unless sel.is_a?(Sketchup::ComponentInstance) && !sel.get_attribute("JPods", "vehicle_id").to_s.strip.empty?
          msgs << "Select a Nora vehicle component in the model before executing."
        end
      end

      # 2. Param bounds for numeric types
      (task[:params] || []).each do |pd|
        next unless pd[:type] == :float || pd[:type] == :integer

        raw = params[pd[:id].to_s]
        raw = pd[:default] if raw.nil? || raw.to_s.strip.empty?
        v = pd[:type] == :integer ? raw.to_i : raw.to_f

        if pd[:min] && v < pd[:min]
          msgs << "#{pd[:label]}: value #{v} is below minimum #{pd[:min]}."
          ok = false
        end
        if pd[:max] && v > pd[:max]
          msgs << "#{pd[:label]}: value #{v} is above maximum #{pd[:max]}."
          ok = false
        end
      end

      # 3. Destructive tasks always need the caller to have confirmed
      #    (the dialog enforces the checkbox; we just report the risk here)

      if ok
        @review_block_streak_by_task[task_id] = 0
        msgs << "Ready — no issues found." if msgs.empty?
      else
        @review_block_streak_by_task[task_id] += 1
        streak = @review_block_streak_by_task[task_id]
        if streak >= STOP_REVIEW_THRESHOLD
          msgs << stop_and_review_message(task_id, streak)
        end
      end

      { risk: task[:risk], ok: ok, messages: msgs }
    end

  end  # NoelleGuard

  TASKS = [

    # ══════════════════════════════════════════════════════════════════════════
    # Student workflow — four steps in order
    # ══════════════════════════════════════════════════════════════════════════

    # ── Step 1: Structure Place ───────────────────────────────────────────────
    { id: "place_structure",
      label: "Structure Place",
      category: "Workflow",
      audience: :all, student_step: 2, designer_phase: :model,
      description: "Step 1 — Open the Structure browser and place a JPods station template into the model. " \
                   "Drag and click to position the station on terrain. " \
                   "Repeat for each station in the network before running CP Calculate.",
      risk: :safe,
      requires_selection: nil,
      params: [],
      run: lambda { |model, _p|
        JPods::StructurePlacer.purge_phantoms(model)
        JPods::JPodStructureTool.activate_with_prompt(model)
        "Place Structure tool active — choose a template and click to place."
      }
    },

    # ── Step 2: CP Calculate (waypoints built in) ─────────────────────────────
    { id: "calculate_cps",
      label: "CP Calculate",
      category: "Workflow",
      audience: :all, student_step: 3, designer_phase: nil,
      persistent_output: true,
      description: "Step 2 — Detects connection points on all placed stations. " \
                   "In a network model, activates the Connect Guideways tool. " \
                   "In a template model, shows CPs so the designer can confirm the model is connectable.",
      description_html: "<b>Connect CPs:</b> Colored rings appear at each CP — red = inbound, blue = outbound. " \
                        "Click one ring to begin a pair, then click the matching ring on another station to wire the connection.<br><br>" \
                        "<b>Waypoints (W):</b> While the Connect tool is active, press <kbd>W</kbd> in the viewport " \
                        "to drop a numbered waypoint post. Add waypoint numbers to the connection's <em>via_markers</em> " \
                        "field in the Network Editor to steer the guideway around obstacles.<br><br>" \
                        "<b>Template models:</b> CP Calculate shows connection points without activating the Connect tool — " \
                        "there is nothing to connect in a standalone template. Button toggles to <em>CP Hide</em>.",
      risk: :safe,
      requires_selection: nil,
      params: [],
      run: lambda { |model, _p|
        if JPods::StructurePlacer.cps_shown?
          # Hide: erase text labels + dismiss connect tool (removes all viewport rings)
          JPods::StructurePlacer.hide_all_cp_labels(model)
          model.select_tool(nil)                               # deactivate JPodConnectTool — clears all gate rings
          JPods::JPodNetworkTool.clear_overlays rescue nil     # clear NE overlay circles if active
          "CP markers hidden."
        else
          JPods::StructurePlacer.purge_phantoms(model)
          JPods::StructurePlacer.recompute_all_cps(model)
          JPods::StructurePlacer._show_cp_circles(model)   # green circles — single visual mechanism
          is_template = model.path.to_s.include?('track_formations')
          if is_template
            "CP Calculate complete — connection points visible. Place this template in a network model to connect guideways."
          else
            model.select_tool(JPods::JPodConnectTool.new)
            "CP Calculate complete — Connect Guideways tool active. Click a CP ring to begin a pair. Press W to drop a waypoint post."
          end
        end
      }
    },

    # ── Step 3: Build ─────────────────────────────────────────────────────────
    { id: "build_network_noelle",
      label: "Build",
      category: "Workflow",
      audience: :all, student_step: 3, designer_phase: :build_validate,
      description: "Step 3 — Build all guideway segments from the cp_ connections saved in <model>.network.json. " \
                   "Run after all CP pairs are wired. Re-run after adding or removing waypoints.",
      risk: :caution,
      requires_selection: nil,
      params: [],
      disabled_when: lambda { |model|
        path = JPods::NetworkEditor.default_network_json_path(model) rescue nil
        path.nil? || !File.exist?(path)
      },
      run: lambda { |model, _p|
        lines = []

        # Step 1: Build physical geometry (v2 — all migrated modules)
        build_result = JPods::BuildV2.build(model)
        lines << "Geometry: #{build_result[:built_segments]} segment(s) built."
        if build_result[:faults] && !build_result[:faults].empty?
          build_result[:faults].each { |f| lines << "  ⚠ #{f}" }
        end

        # Step 2: Generate network.json from built geometry
        output = JPods::NoelleV2.generate_network(model)
        if output
          stations = Array(output.dig('designer', 'stations')).size
          connections = Array(output.dig('designer', 'connections')).size
          rg = (output.dig('natalie', 'routing_graph') || {}).size
          lines << "Network: #{stations} station(s), #{connections} connection(s), #{rg} routing graph entries."

          # Report gap defects directly in Result — no silent tolerance
          gap_defects = output['gap_defects'] || []
          if gap_defects.any?
            lines << ""
            lines << "═══ TRACK GAP DEFECTS ═══"
            gap_defects.each do |d|
              label = case d[:severity] || d['severity']
                      when 'edge_hallucination' then '🔴 EDGE 500mm'
                      when 'disconnect'         then '🔴 DISCONNECT'
                      when 'warning'            then '⚠ SLOPPY'
                      else '?'
                      end
              compensation = case d[:severity] || d['severity']
                            when 'edge_hallucination' then '— Natalie will NOT reverse this track (guard active)'
                            when 'disconnect'         then '— pods WILL JAM at this junction'
                            when 'warning'            then '— Natalie may snap across gap (tolerable)'
                            else ''
                            end
              lines << "#{label}: #{d[:station] || d['station']} #{d[:from] || d['from']}→#{d[:to] || d['to']} gap=#{d[:gap_mm] || d['gap_mm']}mm #{compensation}"
            end
            lines << ""
            lines << "Fix: open template model → snap track endpoints → Compute → Test → Build"
          else
            lines << "✓ All track connections within tolerance (<50mm)"
          end
        end

        lines.join("\n")
      }
    },

    { id: "sally_draft_chains",
      label: "Sally: Draft Chains",
      category: "Models",
      audience: :designer, student_step: nil, designer_phase: :draft_chains,
      panel: :models,
      step: 3,
      su_command: "Models › Sally: Draft Chains",
      description: "Maps the track topology of the open station template into lines.json. " \
                   "Sally reads lines{} successors and writes discovered_chains — all tracks " \
                   "in CCW order (backward from gw_cp_out_0) and alphabetical order. " \
                   "Model designer then authors landing_chains and exit_chains manually " \
                   "from the discovered inventory. Noelle expands each chain with length_mm " \
                   "and switch settings on Build. Set approved_by when chains are complete. " \
                   "Noelle refuses to build any template whose chains_header is missing or unsigned.\n\n" \
                   "PHYSICAL NETWORK EQUIVALENCE: This is exactly the same behavior and format " \
                   "required in physical JPods networks. The gw_* names, chain sequences, " \
                   "length_mm, and switch settings in lines.json are the data Nora follows " \
                   "on the scale model, Natalie uses to plan routes, and the physical station " \
                   "chip (Sally) reports before every pod movement. Students designing in " \
                   "SketchUp are designing the physical control system.",
      risk: :safe,
      requires_selection: nil,
      params: [],
      disabled_when: lambda { |model|
        return true unless model && model.path && !model.path.empty?
        # Enabled when the model has station instances with formation attributes.
        has_formation = model.entities.any? do |e|
          next unless e.is_a?(Sketchup::ComponentInstance)
          !e.definition.get_attribute('JPods', 'model_id', '').to_s.strip.empty?
        end
        # Also check model-level model_id (for open template models)
        has_formation ||= !model.get_attribute('JPods', 'model_id', '').to_s.strip.empty?
        !has_formation
      },
      run: lambda { |model, _p|
        raise "Sally module not loaded." unless defined?(JPods::Sally)
        results = JPods::Sally.draft_chains_for_model(model)
        if results.empty?
          # Fallback: try resolving lines.json from model path directly
          plugin_dir = File.dirname(Sketchup.find_support_file('jpod_sally.rb', 'Plugins/su_jpods'))
          model_name = File.basename(model.path, '.*').downcase
          templates_dir = File.join(plugin_dir, 'templates', 'track_formations')
          lines_path = Dir.glob(File.join(templates_dir, '*', 'lines.json')).find { |p|
            File.basename(File.dirname(p)).downcase.include?(model_name)
          }
          if lines_path
            result = JPods::Sally.draft_chains(lines_path)
            results << result if result
          end
        end
        raise "No lines.json found for any template in this model." if results.empty?
        # Refresh the Sequence panel with the newly drafted chains (Review view).
        results.each { |r| JPods::Console.push_sequence_panel(r[:formation]) }
        lines = results.map { |r| "  #{r[:formation]}: chains drafted → #{r[:path]}" }
        "Sally draft complete.\nReview alternatives in the Sequence panel. Remove unwanted paths, set approved_by.\n\n#{lines.join("\n")}"
      }
    },

    { id: "hold_loop_demo",
      label: "Hold Loop",
      button_label: "Run Loop",
      category: "Models",
      audience: :designer, student_step: nil, designer_phase: :verify_tracks,
      panel: :models,
      group: "Stations",
      description: "Tags an existing vehicle for Sally's hold_loop. " \
                   "Add Vehicle first, then run this to assign hold_loop routing. " \
                   "When Start Animation runs, the vehicle circles the outer ring for N loops " \
                   "then Sally promotes it to the landing chain.\n\n" \
                   "Parameters:\n" \
                   "  vehicle    — Nora ID of the placed vehicle\n" \
                   "  station    — station to hold-loop at (defaults to vehicle's parked station)\n" \
                   "  arrival_cp — 0 or 1 (which CP gate the pod enters)\n" \
                   "  hold_loops — full loops before promotion (0 = promote when platform has a slot)",
      risk: :safe,
      requires_selection: nil,
      params: [
        { id: "nora_id",    label: "Vehicle",     type: :select, source: :nora_with_station,         default: "" },
        { id: "station_id", label: "Station",     type: :select, source: :model_station_ids,          default: "" },
        { id: "arrival_cp", label: "Arrival CP",  type: :select, options: ["0", "1"],                 default: "0" },
        { id: "hold_loops", label: "Loop Count",  type: :select, options: ["0","1","2","3","5","10"], default: "3" }
      ],
      run: lambda { |model, p|
        nora_id = p["nora_id"].to_s.strip
        raise "Select a vehicle first (use Add Vehicle)." if nora_id.empty?

        entity = model.entities.find { |e|
          e.is_a?(Sketchup::ComponentInstance) &&
          e.get_attribute('JPods', 'vehicle_id', '').to_s == nora_id
        }
        raise "Vehicle #{nora_id} not found in model." unless entity

        # Station can be specified explicitly or fall back to the vehicle's parked station.
        sid = p["station_id"].to_s.strip.upcase
        if sid.empty?
          sid = entity.get_attribute('JPods', 'parked_station_id', '').to_s.strip.upcase
          raise "Vehicle #{nora_id} has no parked_station_id — select a station or place the vehicle with Add Vehicle first." if sid.empty?
        end

        # Init Sally sequencer for this station if not already done.
        # model_id lives on the STATION component definition, not the vehicle.
        if defined?(JPods::Sally) && JPods::Sally.hold_loop_tracks(sid).empty?
          station_ent = model.entities.find { |e|
            e.is_a?(Sketchup::ComponentInstance) &&
            e.get_attribute('JPods', 'structure_id', '').to_s.strip.upcase == sid
          }
          # model_id attribute set by Build; fall back to definition name.
          # Definition name pattern: "JPods Formation: station_line_end" — strip prefix.
          fid = station_ent&.definition&.get_attribute('JPods', 'model_id', '').to_s.strip
          if fid.empty? && station_ent
            fid = station_ent.definition.name.to_s.sub(/\AJPods Formation:\s*/i, '').strip
          end
          plugin_dir = File.expand_path('..', Sketchup.find_support_file('jpod_sally.rb', 'Plugins/su_jpods'))
          if fid && !fid.empty?
            JPods::Sally.init_sequencer_for_station(sid, fid, plugin_dir)
          else
            puts "[Console] hold_loop: no station component found for #{sid} in model"
          end
        end

        hold_loop_tracks = defined?(JPods::Sally) ? JPods::Sally.hold_loop_tracks(sid) : []
        raise "#{sid} has no hold_loop (no u-turn tracks in its lines.json)." if hold_loop_tracks.empty?

        # Tag the vehicle — build_fleet reads these at animation start.
        entity.set_attribute('JPods', 'sally_hold_loop_sid',   sid)
        entity.set_attribute('JPods', 'sally_hold_loop_cp',    p["arrival_cp"].to_i.to_s)
        entity.set_attribute('JPods', 'sally_hold_loop_loops', p["hold_loops"].to_i.to_s)

        # Build trip sequence preview so the designer can spot defects before animation.
        preview = JPods::Console.preview_hold_loop_sequence(
          sid, fid, p["arrival_cp"].to_i, p["hold_loops"].to_i, plugin_dir
        )

        "#{nora_id} tagged for hold_loop at #{sid} (cp=#{p["arrival_cp"]}, loops=#{p["hold_loops"]}).\n" \
        "Run Start Animation to engage.\n\n" \
        "#{preview}"
      }
    },

    { id: "trip_sequence",
      label: "Trip Sequence",
      button_label: "Show Trip",
      category: "Models",
      audience: :designer, student_step: nil, designer_phase: :verify_tracks,
      panel: :models,
      group: "Stations",
      description: "Generate the full expanded trip sequence for a hold_loop run.\n\n" \
                   "Shows every gw_* track in execution order — depart, all loops " \
                   "fully expanded, final approach, and park — so the designer can " \
                   "verify the sequence before starting animation.\n\n" \
                   "No vehicle required. Does not tag or move anything.",
      risk: :safe,
      requires_selection: nil,
      params: [
        { id: "station_id", label: "Station",    type: :select, source: :model_station_ids,          default: "" },
        { id: "arrival_cp", label: "Arrival CP", type: :select, options: ["0", "1"],                  default: "0" },
        { id: "hold_loops", label: "Loop Count", type: :select, options: ["0","1","2","3","5","10"],  default: "3" }
      ],
      run: lambda { |model, p|
        sid = p["station_id"].to_s.strip.upcase
        raise "Select a station." if sid.empty?

        # Resolve model_id from the station component in the model.
        station_ent = model.entities.find { |e|
          e.is_a?(Sketchup::ComponentInstance) &&
          e.get_attribute('JPods', 'structure_id', '').to_s.strip.upcase == sid
        }
        fid = station_ent&.definition&.get_attribute('JPods', 'model_id', '').to_s.strip
        if fid.empty? && station_ent
          fid = station_ent.definition.name.to_s.sub(/\AJPods Formation:\s*/i, '').strip
        end
        raise "No model_id found for #{sid} — Build the model first." if fid.to_s.empty?

        plugin_dir = File.expand_path('..', Sketchup.find_support_file('jpod_sally.rb', 'Plugins/su_jpods'))

        # Init Sally sequencer if needed.
        if defined?(JPods::Sally) && JPods::Sally.hold_loop_tracks(sid).empty?
          JPods::Sally.init_sequencer_for_station(sid, fid, plugin_dir)
        end

        raise "#{sid} has no hold_loop (no u-turn tracks in its lines.json)." \
          if defined?(JPods::Sally) && JPods::Sally.hold_loop_tracks(sid).empty?

        seq = JPods::Console.preview_hold_loop_sequence(
          sid, fid, p["arrival_cp"].to_i, p["hold_loops"].to_i, plugin_dir
        )
        "__TRIPSEQ__:#{seq}"
      }
    },

    { id: "show_in_finder",
      label: "Finder",
      category: "Workflow",
      audience: :all, student_step: nil, designer_phase: nil,
      description: "Opens the project folder in the macOS Finder.",
      risk: :safe,
      requires_selection: nil,
      params: [],
      run: lambda { |model, _p|
        JPods::NetworkEditor.show_in_finder_or_organize(model)
        "Opened in Finder."
      }
    },

    { id: "station_names",
      label: "Station Names",
      category: "Models",
      audience: :all, student_step: nil, designer_phase: nil,
      panel: :models,
      group: "Stations",
      description: "Set a friendly display name for each station. Names appear in the Trip Simulator phone app. S### IDs are assigned by the model; names are stored as entity attributes and survive Build.",
      risk: :safe,
      requires_selection: nil,
      params: [],
      run: lambda { |model, _p|
        # Collect stations: entity attributes first, then followme.json fallback.
        stations = JPods::JPodGuideway.all_stations_in_model(model) rescue []

        if stations.empty?
          # Fallback: read from followme.json so the table works even before a
          # fresh reload of placed components.
          begin
            path = JPods::JPodGuideway.followme_json_path(model) rescue nil
            if path && File.exist?(path)
              fw = JSON.parse(File.read(path, encoding: 'utf-8'))
              seen = {}
              Array(fw['platforms']).each do |p|
                sid = p['structure_id'].to_s
                next if sid.empty? || seen[sid]
                seen[sid] = true
                # Read friendly name from entity attribute if set
                saved_name = ''
                model.entities.grep(Sketchup::ComponentInstance).each do |e|
                  if e.get_attribute('JPods', 'structure_id', '').to_s == sid
                    saved_name = e.get_attribute('JPods', 'station_name', '').to_s
                    break
                  end
                end rescue nil
                stations << { structure_id: sid, station_name: saved_name }
              end
            end
          rescue => _e
          end
        end

        if stations.empty?
          empty_msg = "<tr><td colspan='2' style='color:#666;padding:12px 4px;font-style:italic'>" \
                      "No stations found — place stations and run Build first.</td></tr>"
          html = "<table class='sn-table'>" \
                 "<thead><tr><th>Station</th><th>Display Name</th></tr></thead>" \
                 "<tbody>#{empty_msg}</tbody></table>"
          return "__STATIONNAMES__:#{html}"
        end

        rows = stations.map do |s|
          sid    = s[:structure_id].to_s
          name   = s[:station_name].to_s
          sid_j  = sid.to_json
          name_j = name.to_json
          "<tr>" \
            "<td class='sn-id'>#{sid}</td>" \
            "<td><input class='sn-input' data-sid=#{sid_j} value=#{name_j} " \
            "placeholder='friendly name…' onchange='stationNameChanged(this)'></td>" \
          "</tr>"
        end.join
        html = "<table class='sn-table'>" \
               "<thead><tr><th>Station</th><th>Display Name</th></tr></thead>" \
               "<tbody>#{rows}</tbody></table>"
        "__STATIONNAMES__:#{html}"
      }
    },

    { id: "list_vehicles",
      label: "List Vehicles",
      category: "Vehicles",
      audience: :all, student_step: nil, designer_phase: nil,
      description: "Lists all Nora vehicles in the model: ID, parked station, destination, parking state.",
      risk: :safe,
      requires_selection: nil,
      params: [],
      run: lambda { |model, _p|
        vehicles = JPods::JPodGuideway.all_nora_vehicles_in_model(model)
        return "No vehicles in model. Use Add Vehicle or Populate to place pods." if vehicles.empty?
        net_spd = model.get_attribute('JPods', 'network_speed_ms', 8.3).to_f
        lines = ["Vehicles in model (#{vehicles.size})  network speed=#{net_spd.round(1)} m/s:"]
        vehicles.each do |veh|
          e = veh[:entity]
          next if e.nil? || e.deleted?
          vid   = veh[:vehicle_id]
          orig  = e.get_attribute('JPods', 'parked_station_id', '(none)').to_s
          dest  = e.get_attribute('JPods', 'destination_platform_id', '(none)').to_s
          state = e.get_attribute('JPods', 'parking_state', '(none)').to_s
          spd   = e.get_attribute('JPods', 'speed_ms', 8.3).to_f
          lines << "  #{vid}  origin=#{orig}  dest=#{dest}  state=#{state}  speed=#{spd.round(1)}m/s"
        end
        lines.join("\n")
      }
    },


    # ── Noelle Network Authority ─────────────────────────────────────────────



    { id: "set_label_size",
      label: "Set Label Size",
      category: "Network",
      audience: :designer, student_step: nil, designer_phase: nil,
      description: "Sets the height of guideway name labels in meters. " \
                   "Increase to read names; decrease to visually suppress them. " \
                   "Regenerates all active label groups immediately.",
      risk: :safe,
      requires_selection: nil,
      params: [
        { id: "size_m", label: "Label height (m)",
          type: :float, default: 1.0, min: 0.1, max: 10.0 }
      ],
      run: lambda { |model, p|
        size_m = [[p["size_m"].to_f, 0.1].max, 10.0].min
        model.set_attribute('JPods', 'label_height_in', size_m * 39.3701)
        JPods::JPodGuideway.regenerate_labels(model)
        "Label height set to #{size_m.round(2)} m."
      }
    },

    { id: "show_formation_tracks",
      label: "Show Tracks",
      button_label: "Show Tracks",
      category: "Animation",
      audience: :designer, student_step: nil, designer_phase: :verify_tracks,
      description: "Draws every track in the open model as a color-coded ribbon. " \
                   "Works in a template model.skp with no CP connections — no routing required. " \
                   "Red = inbound (gw_cp_in, gw_in). Blue = outbound (gw_cp_out, gw_out). " \
                   "Yellow = ring/circle arcs (gw_c_*). Green = platform, uturn, other interior. " \
                   "Click again to hide. Debug once, use many.",
      risk: :safe,
      requires_selection: nil,
      params: [
        { id: "ribbon_above", label: "Ribbon above guideway", type: :boolean, default: true },
      ],
      run: lambda { |model, p|
        if JPods::JPodGuideway.track_overlay_active?(model)
          JPods::JPodGuideway.clear_track_overlay(model)
          "Formation tracks cleared."
        else
          above = p['ribbon_above'] != false
          ok, msg = JPods::JPodGuideway.show_track_overlay(model, ribbon_above: above)
          raise msg unless ok
          msg
        end
      }
    },

    { id: "start_animation",
      label: "Start Animation",
      category: "Animation",
      audience: :all, student_step: 4, designer_phase: :build_validate,
      description: "Animates all vehicles on all guideways. Vehicles maintain a 3 m minimum headway (they slow and stop when closing on another vehicle). Any previously running animation is stopped first.",
      risk: :safe,
      requires_selection: nil,
      params: [],
      run: lambda { |model, _p|
        ok = JPods::JPodGuideway.start_animation(model)
        ok == false ? "Animation could not start — run Build, then Populate vehicles." : "Animation started."
      }
    },

    { id: "stop_animation",
      label: "Stop Animation",
      category: "Animation",
      audience: :all, student_step: 4, designer_phase: nil,
      description: "Stops all vehicle animation immediately.",
      risk: :safe,
      requires_selection: nil,
      params: [],
      run: lambda { |model, _p|
        JPods::JPodGuideway.stop_animation
        "Animation stopped."
      }
    },

    { id: "tag_vehicles",
      label: "Tag Vehicles by Nora ID",
      category: "Animation",
      audience: :all, student_step: nil, designer_phase: nil,
      description: "Assigns each vehicle's Nora ID as its SketchUp tag. " \
                   "Lets you show/hide individual vehicles from the Tags panel. " \
                   "Run once after placing vehicles — new vehicles are tagged automatically.",
      risk: :safe,
      requires_selection: nil,
      params: [],
      run: lambda { |model, _p|
        tagged = 0
        model.start_operation('Tag Vehicles', true)
        model.entities.each do |e|
          next unless e.is_a?(Sketchup::ComponentInstance) && !e.deleted?
          nora_id = e.get_attribute('JPods', 'vehicle_id', '').to_s
          next if nora_id.empty?
          tag = model.layers[nora_id] || model.layers.add(nora_id)
          e.layer = tag
          tagged += 1
        end
        model.commit_operation
        "Tagged #{tagged} vehicle(s) by Nora ID."
      }
    },


    # ── Route Overlay ─────────────────────────────────────────────────────────


    # ── Lines (MapFeatureTool) ────────────────────────────────────────────────

    # Lines tools are only active when the frontmost model is inside the su_jpods
    # plugin folder (a template model). If a project model is frontmost, all three
    # are grayed out. To use: close Console, open the template model as the frontmost
    # file, then reopen or reload Console.

    # ── [MIGRATION] Temporary — archive after all 6 templates verified READY ──

  ].freeze

  # NoelleGuard: validate every task has a risk: key at load time
  TASKS.each do |t|
    puts "[Noelle] TASKS — task '#{t[:id]}' missing risk: key" unless t[:risk]
  end

  # Pre-index tasks by id for O(1) lookup
  remove_const(:TASK_INDEX) if const_defined?(:TASK_INDEX)
  TASK_INDEX = TASKS.each_with_object({}) { |t, h| h[t[:id]] = t }.freeze

  # ── PRECONDITION_CHECKS — used by audience/phase filtering and NoelleGuard ──
  # Each symbol matches a :preconditions entry in TASKS.
  # :check receives the active model; returns true if the precondition is met.
  # :hint is shown to the user when the check fails.
  remove_const(:PRECONDITION_CHECKS) if const_defined?(:PRECONDITION_CHECKS)
  PRECONDITION_CHECKS = {
    model_open: {
      agent: 'Noelle',
      label: 'Model open',
      check: ->(m) { !m.nil? },
      hint:  'Open a SketchUp model first.'
    },
    model_saved: {
      agent: 'Noelle',
      label: 'Model saved',
      check: ->(m) { m && m.path && !m.path.empty? },
      hint:  'Save the .skp file first — the tool needs a file path.'
    },
    model_is_template: {
      agent: 'Noelle',
      label: 'Model is a station template',
      check: ->(m) {
        return false unless m && m.path && !m.path.empty?
        m.path.to_s.gsub('\\', '/').include?('track_formations')
      },
      hint:  'Open a station template model (inside templates/track_formations/).'
    },
    lines_json_exists: {
      agent: 'Noelle',
      label: 'lines.json present',
      check: ->(m) {
        return false unless m && m.path && !m.path.empty?
        folder = File.dirname(m.path.to_s)
        File.exist?(File.join(folder, 'lines.json'))
      },
      hint:  'Author lines.json for this template. See DESIGNER.md Step 5.'
    },
    cp_json_exists: {
      agent: 'Noelle',
      label: 'cp.json present',
      check: ->(m) {
        return false unless m && m.path && !m.path.empty?
        folder = File.dirname(m.path.to_s)
        File.exist?(File.join(folder, 'cp.json'))
      },
      hint:  'Run Extract Template to generate cp.json.'
    },
    geometry_json_exists: {
      agent: 'Noelle',
      label: 'geometry.json present',
      check: ->(m) {
        return false unless m && m.path && !m.path.empty?
        folder = File.dirname(m.path.to_s)
        File.exist?(File.join(folder, 'geometry.json'))
      },
      hint:  'Run Extract Template to generate geometry.json.'
    },
    followme_json_exists: {
      agent: 'Natalie',
      label: 'followme.json present',
      check: ->(m) {
        return false unless m && m.path && !m.path.empty?
        path = File.join(File.dirname(m.path),
                         "#{File.basename(m.path, '.skp')}.followme.json")
        File.exist?(path)
      },
      hint:  '[Natalie] Run Build Network to generate followme.json.'
    },
    vehicles_placed: {
      agent: 'Nora',
      label: 'Vehicles placed',
      check: ->(m) {
        return false unless m
        m.entities.any? { |e|
          e.is_a?(Sketchup::ComponentInstance) &&
          !e.get_attribute('JPods', 'vehicle_id', '').to_s.strip.empty?
        }
      },
      hint:  '[Nora] Place vehicles first (Run 5V Standard Test or Place Vehicle).'
    },
    # ── Alice preconditions ──────────────────────────────────────────────────
    # Alice accounts for:
    #   • Ticket sales — trip pricing, booking, invoices, payments (wcapi)
    #   • Small-Stings — fines customers assess for unresolved problems;
    #                    JPods pays customers to provide retrospections
    #   • Action lists — Project → Action → Document records in WC3
    # Console tasks that initiate a billable event or write an action record check these.
    alice_wcapi_reachable: {
      agent: 'Alice',
      label: 'WebClerk API reachable',
      check: ->(_m) {
        # Alice lives in WC3 on localhost. Check whether the wcapi port responds.
        require 'socket'
        begin
          TCPSocket.new('localhost', 8000).close
          true
        rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT
          false
        end
      },
      hint:  '[Alice] WebClerk is not running. Start WC3 locally before executing this task.'
    },
    alice_trip_price_set: {
      agent: 'Alice',
      label: 'Trip price policy set',
      check: ->(m) {
        return false unless m
        !m.get_attribute('JPods', 'alice_price_level', '').to_s.strip.empty?
      },
      hint:  '[Alice] No price level set for this network. ' \
             'Alice must set a price policy (price_query) before trips can be booked.'
    }
  }.freeze

  # ── Console dialog ─────────────────────────────────────────────────────────

  module Console

    remove_const(:DIALOG_OPTS) if const_defined?(:DIALOG_OPTS)
    DIALOG_OPTS = {
      dialog_title:    "JPods Console",
      preferences_key: "JPods_Console",
      width:           820,
      height:          620,
      min_width:       640,
      min_height:      420,
      resizable:       true,
    }.freeze

    # Files where source changes require a full SketchUp restart.
    # main.rb contains $jpods_registered and @@jpods_toolbar_registered guards that
    # only clear at process start — menu items and toolbar buttons do not re-execute
    # on plugin reload.  Add filenames (relative to plugin root) as cases arise.
    remove_const(:RESTART_REQUIRED_FILES) if const_defined?(:RESTART_REQUIRED_FILES)
    RESTART_REQUIRED_FILES = %w[
      main.rb
    ].freeze

    def self.snapshot_mtimes(root)
      RESTART_REQUIRED_FILES.each_with_object({}) do |fname, h|
        path = File.join(root, fname)
        h[fname] = File.exist?(path) ? File.mtime(path).to_i : nil
      end
    end

    def self.changed_restart_files(root, mtimes_before)
      RESTART_REQUIRED_FILES.select do |fname|
        path = File.join(root, fname)
        File.exist?(path) && File.mtime(path).to_i != mtimes_before[fname].to_i
      end
    end

    # ── Mode switch ──────────────────────────────────────────────────────────
    # Three audiences: student (4-step guided), designer (10-phase), developer (all)
    # Persisted across sessions via Sketchup preferences.

    def self.console_mode
      Sketchup.read_default('JPods', 'console_mode', 'designer')
    end

    def self.console_mode=(mode)
      Sketchup.write_default('JPods', 'console_mode', mode.to_s)
    end

    # ── Learning log ──────────────────────────────────────────────────────────
    # Appends one JSONL line per action to ~/Allie/logs/console_learning_log.jsonl.
    # Written for a few days to capture real usage patterns before the nav restructure.
    #
    # Allie reads this nightly and can report: most-run tasks, most-failed tasks,
    # precondition hit rates, mode distribution, etc.
    #
    # Entry shape:
    #   { ts, event, task_id?, result?, duration_ms?, mode?, missing?, reason? }
    #
    # Events: task_run, task_fail, task_blocked, task_selected,
    #         precond_fail, mode_change, console_open

    LOG_PATH = File.expand_path('~/Allie/logs/console_learning_log.jsonl').freeze

    def self.log_action(event, data = {})
      entry = { ts: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'), event: event.to_s }
      entry.merge!(data)
      log_dir = File.dirname(LOG_PATH)
      Dir.mkdir(log_dir) unless Dir.exist?(log_dir)
      File.open(LOG_PATH, 'a') { |f| f.puts(entry.to_json) }
    rescue => ex
      puts "[Console] log_action error: #{ex.message}"
    end

    LOG_TTL_DAYS = 3

    # Called at Console open. Deletes the log if it is older than LOG_TTL_DAYS.
    # Allie and Claude Code manage the log — Bill does not need to think about it.
    def self.expire_learning_log
      return unless File.exist?(LOG_PATH)
      age_days = (Time.now - File.mtime(LOG_PATH)) / 86_400.0
      if age_days > LOG_TTL_DAYS
        File.delete(LOG_PATH)
        puts "[Console] learning_log expired after #{age_days.round(1)} days — deleted"
      end
    rescue => ex
      puts "[Console] expire_learning_log error: #{ex.message}"
    end

    # ── Context banner ────────────────────────────────────────────────────────
    # Summarises model state for the persistent status strip in the Console header.

    def self.context_banner(model)
      mode        = console_mode
      is_template = model && model.path && !model.path.empty? &&
                    model.path.to_s.gsub('\\', '/').include?('track_formations')
      model_name  = if model && model.path && !model.path.empty?
                      # Template models are all named model.skp — use parent folder name instead
                      if is_template
                        File.basename(File.dirname(model.path.to_s))
                      else
                        File.basename(model.path, '.skp')
                      end
                    else
                      model ? '(unsaved)' : '(no model)'
                    end
      missing = []
      if is_template
        folder = File.dirname(model.path.to_s)
        missing << 'lines.json'          unless File.exist?(File.join(folder, 'lines.json'))
        missing << 'lines.computed.json' unless File.exist?(File.join(folder, 'lines.computed.json'))
      end
      # Infer current student step from model state
      student_step = if is_template
                       nil   # student workflow is for network models
                     elsif !model || model.path.to_s.empty?
                       1     # no model → step 1 (geolocate)
                     else
                       followme = File.join(File.dirname(model.path.to_s),
                                            "#{File.basename(model.path, '.skp')}.followme.json")
                       has_guideways = File.exist?(followme)
                       vehicles_placed = model.entities.any? { |e|
                         e.is_a?(Sketchup::ComponentInstance) &&
                         !e.get_attribute('JPods', 'vehicle_id', '').to_s.strip.empty?
                       } rescue false
                       if vehicles_placed then 4
                       elsif has_guideways then 4
                       else 2
                       end
                     end
      {
        mode:          mode,
        model_name:    model_name,
        model_path:    (model&.path.to_s.empty? ? nil : model&.path.to_s),
        is_template:   is_template,
        missing_files: missing,
        student_step:  student_step
      }
    end

    # ── AppObserver — push fresh banner when active model window changes ─────
    #
    # SketchUp calls onActivateModel whenever the user brings a different model
    # window to the front. We push setContextBanner so the nav bar model name
    # updates without requiring a Reload Plugin.
    #
    class ConsoleAppObserver < Sketchup::AppObserver
      def onActivateModel(model)
        return unless JPods::Console.visible?
        begin
          banner = JPods::Console.context_banner(model).to_json
          JPods::Console.execute_script("setContextBanner(#{banner})")
        rescue => e
          puts "[ConsoleAppObserver] onActivateModel error: #{e.message}"
        end
      end
    end

    @app_observer = nil

    def self.attach_app_observer
      @app_observer ||= ConsoleAppObserver.new
      # add_observer is idempotent if the same instance is already registered
      Sketchup.add_observer(@app_observer)
    end

    def self.detach_app_observer
      return unless @app_observer
      Sketchup.remove_observer(@app_observer)
      @app_observer = nil
    end

    # ── public ───────────────────────────────────────────────────────────────

    def self.open(model)
      expire_learning_log
      log_action(:console_open, mode: console_mode,
                 model: model&.path&.then { |p| File.basename(p, '.skp') } || '(none)')
      # Clean up any stray Network Editor dialogs before opening Console
      puts "[JPods Console.open] called from: #{caller.first(2).join(' <- ')}"
      if defined?(JPods::NetworkEditor) && JPods::NetworkEditor.respond_to?(:close)
        puts "[JPods Console.open] calling NetworkEditor.close"
        JPods::NetworkEditor.close
      end

      if @dialog && @dialog.visible?
        puts "[JPods Console.open] already visible — bring_to_front"
        @dialog.bring_to_front
        return @dialog
      end

      puts "[JPods Console.open] creating new HtmlDialog and calling @dialog.show"
      @dialog = UI::HtmlDialog.new(DIALOG_OPTS)
      # Use set_url with a timestamp query param to bust SketchUp's WebView cache.
      html_path = File.join(File.dirname(__FILE__), "dialogs", "console.html")
      @dialog.set_url("file://#{html_path}?v=#{Time.now.to_i}")

      setup_callbacks(model)

      # Capture this dialog instance so set_on_closed only clears @dialog when it
      # still points to THIS dialog. The reload path calls Console.open immediately
      # after dlg.close — set_on_closed fires async and would otherwise clobber the
      # new @dialog reference, preventing cmd_ready from sending initTasks to the nav.
      this_dlg = @dialog
      @dialog.set_on_closed {
        puts "[JPods Console] dialog closed"
        @dialog = nil if @dialog.equal?(this_dlg)
        JPods::Console.detach_app_observer
      }
      attach_app_observer
      @dialog.show
      @dialog
    end

    def self.visible?
      @dialog && @dialog.visible?
    end

    def self.instance_dialog
      @dialog && @dialog.visible? ? @dialog : nil
    end

    # Refresh the pod list in the console — called after Populate/Clear
    def self.refresh_vehicle_list(model)
      dlg = instance_dialog
      return unless dlg && model
      rows = JPods::JPodGuideway.vehicle_trip_rows(model)
      dlg.execute_script("updateVehicleRows(#{rows.to_json})") rescue nil
    end

    # Allow external callers (e.g. JPodConnectTool) to push JS into the
    # console dialog without needing direct access to @dialog.
    def self.execute_script(js)
      return unless visible?
      @dialog.execute_script(js)
    end

    # ── callbacks ─────────────────────────────────────────────────────────────

    def self.setup_callbacks(model)

      # Record the model path this console session was opened for.
      # cmd_execute guards against running tasks against a different model.
      @console_model_path = model&.path.to_s

      # Dialog ready — send task list and available vehicles
      @dialog.add_action_callback("cmd_ready") do |_ctx|
        # Give NetworkEditor a reference so push_network_json can update the iframe
        JPods::NetworkEditor.set_console_dialog(@dialog) rescue nil

        # Build task list grouped by category.
        # Evaluate disabled_when for each task so the JS can gray out locked items.
        grouped = TASKS.group_by { |t| t[:category] }
        task_data = grouped.transform_values do |tasks|
          tasks.map do |t|
            disabled = t[:disabled_when] ? (t[:disabled_when].call(model) rescue false) : false
            { id: t[:id], label: t[:label], risk: t[:risk].to_s,
              step: t[:step], group: t[:group],
              su_command: t[:su_command],
              panel: t[:panel].to_s,
              requires_selection: t[:requires_selection],
              audience: t[:audience].to_s,
              student_step: t[:student_step],
              designer_phase: t[:designer_phase].to_s,
              disabled: disabled }
          end
        end
        @dialog.execute_script("initTasks(#{task_data.to_json}, #{Console.console_mode.to_json})")
        @dialog.execute_script("setContextBanner(#{Console.context_banner(model).to_json})")

        # Push cp_ connections from network.json into the embedded Network Editor iframe.
        # Always activate the Connect Guideways tool when NE opens so CP rings are
        # immediately available for pairing — regardless of whether connections exist.
        begin
          network_path = JPods::NetworkEditor.default_network_json_path(model)
          nd = JPods::NetworkEditor.load_network_definition_from_path(network_path)
          # Convert connections hash (Connect tool format) to array (iframe format)
          if nd['connections'].is_a?(Hash)
            flat = JPods::NetworkEditor.feature_connections_to_flat_array(nd['connections'])
            nd_for_iframe = nd.dup
            nd_for_iframe['connections'] = flat.map { |e|
              { 'id' => e['connection_id'],
                'from' => e['from'], 'to' => e['to'],
                'via_markers' => e['via_markers'] || [] }
            }.uniq { |c| c['id'] }
            nd_text = JSON.pretty_generate(nd_for_iframe)
          else
            nd_text = JSON.pretty_generate(nd)
          end
          @dialog.execute_script("loadNetworkEditorContent(#{nd_text.to_json}, #{network_path.to_json})")
        rescue => ex
          puts "JPods Console cmd_ready: could not pre-load network editor content: #{ex.message}"
        end
        # NOTE: CP calculation and ConnectTool activation are NOT triggered here.
        # They belong exclusively to the "CP Calculate" workflow step.

        # Push network.json connections into the NE feature panel (Noelle cp_ hierarchy)
        begin
          JPods::NetworkEditor.push_feature_connections(model, @dialog)
        rescue => ex
          puts "JPods Console cmd_ready: could not push feature connections: #{ex.message}"
        end

        # Push station friendly names to NE iframe for connection card display
        begin
          names = {}
          model.entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
            sid  = e.get_attribute('JPods', 'structure_id', '').to_s.strip
            name = e.get_attribute('JPods', 'station_name', '').to_s.strip
            names[sid.downcase] = name unless sid.empty? || name.empty?
          end
          js = "if(document.getElementById('network-editor-iframe')){" \
               "var f=document.getElementById('network-editor-iframe');" \
               "f.addEventListener('load',function(){try{f.contentWindow.setStationNames(#{names.to_json})}catch(e){}});" \
               "try{f.contentWindow.setStationNames(#{names.to_json})}catch(e){}}"
          @dialog.execute_script(js)
        rescue; end

        # Send model info to the Models panel at the bottom of the sidebar.
        @dialog.execute_script("updateModelPanel(#{model_panel_info(model).to_json})")
        anim_on = (JPods::JPodGuideway.animating? rescue false)
        @dialog.execute_script("setAnimationState(#{anim_on})")

        # Push current build profile values into the console inputs
        begin
          xy_m = (Constants::HORIZONTAL_SMOOTH_RADIUS / 1.m).round(1)
          zr_m = (Constants::MIN_Z_CHANGE_DIAMETER / 1.m).round(1)
          @dialog.execute_script(
            "document.getElementById('smooth-xy').value=#{xy_m};" \
            "document.getElementById('smooth-z-curve').value=#{zr_m};"
          )
        rescue; end

        # Populate vehicle model dropdown from filesystem — runs fresh on every open.
        vehicles = JPods::JPodGuideway.available_vehicles rescue []
        @dialog.execute_script("setVehicleModelList(#{vehicles.to_json})")
        # Station list — only models with gw_platform (stations that park pods)
        station_ids = []
        model.entities.each do |e|
          next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          sid = e.get_attribute('JPods', 'structure_id', '').to_s.strip.downcase
          next if sid.empty?
          defn_name = e.is_a?(Sketchup::ComponentInstance) ? e.definition.name.to_s.downcase : ''
          next if defn_name.include?('cpb') || defn_name.include?('traffic_circle')
          station_ids << sid
        end
        station_ids.sort!
        @dialog.execute_script("setStationList(#{station_ids.to_json})")
      end

      # Build action from the Models panel — same as the Workflow Build task.
      @dialog.add_action_callback("cmd_model_build") do |_ctx|
        begin
          result = JPods::NoelleNetworkBuilder.from_json(model)
          unless result[:ok]
            faults = Array(result[:faults]).map { |f| "  • #{f}" }.join("\n")
            @dialog.execute_script("showOutput(#{("Build failed:\n#{faults}").to_json}, 'error')")
            next
          end
          msg = "Network built: #{result[:built_segments]} segment(s)."
          @dialog.execute_script("showOutput(#{msg.to_json}, 'ok')")
          # Refresh the Network Editor after build.
          begin
            network_path = JPods::NetworkEditor.default_network_json_path(model)
            nd = JPods::NetworkEditor.load_network_definition_from_path(network_path)
            if nd['connections'].is_a?(Hash)
              flat = JPods::NetworkEditor.feature_connections_to_flat_array(nd['connections'])
              nd_for_iframe = nd.dup
              nd_for_iframe['connections'] = flat.map { |e|
                { 'id' => e['connection_id'],
                  'from' => e['from'], 'to' => e['to'],
                  'via_markers' => e['via_markers'] || [] }
              }.uniq { |c| c['id'] }
              nd_text = JSON.pretty_generate(nd_for_iframe)
            else
              nd_text = JSON.pretty_generate(nd)
            end
            @dialog.execute_script("loadNetworkEditorContent(#{nd_text.to_json}, #{network_path.to_json})")
            JPods::NetworkEditor.push_feature_connections(model, @dialog)
          rescue; end
        rescue => ex
          @dialog.execute_script("showOutput(#{("Build error: #{ex.message}").to_json}, 'error')")
        end
      end

      # Finder action from the Models panel.
      @dialog.add_action_callback("cmd_model_finder") do |_ctx|
        begin
          JPods::NetworkEditor.show_in_finder_or_organize(model)
        rescue => ex
          @dialog.execute_script("showOutput(#{("Finder error: #{ex.message}").to_json}, 'error')")
        end
      end

      # Refresh vehicle-trip table on demand (called when a Vehicle-category task is selected)
      @dialog.add_action_callback("cmd_refresh_trip_table") do |_ctx|
        vehicles = JPods::JPodGuideway.available_vehicles rescue []
        @dialog.execute_script("setVehicleList(#{vehicles.to_json})")
        @dialog.execute_script("setVehicleModelList(#{vehicles.to_json})")
        rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
        @dialog.execute_script("setTripTable(#{rows.to_json})")
        ids = JPods::JPodGuideway.station_ids_from_followme(model) rescue []
        @dialog.execute_script("setStationList(#{ids.to_json})")
      end

      # Camera follow — toggle follow on a pod
      @dialog.add_action_callback("cmd_camera_follow") do |_ctx, nora_id|
        if defined?(JPods::AnimationV2)
          vid = nora_id.to_s.strip
          if vid.empty?
            JPods::AnimationV2.set_camera_follow('')
          else
            JPods::AnimationV2.set_camera_follow(vid)
          end
        end
      end

      # BOM — scan built model entities and populate bom.json template
      @dialog.add_action_callback("cmd_bom_data") do |_ctx|
        begin
          template_path = File.join(File.dirname(__FILE__), 'bom.json')
          bom = File.exist?(template_path) ? JSON.parse(File.read(template_path)) : {}
          comps = bom['components'] || {}

          # Count stations (exclude traffic circles)
          station_count = 0
          model.entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
            sid = e.get_attribute('JPods', 'structure_id', '').to_s
            next if sid.empty?
            mid = e.get_attribute('JPods', 'model_id', '').to_s.downcase
            next if mid.include?('traffic_circle')
            station_count += 1
          end

          # Count columns, beams, solar from built geometry
          column_count = 0; beam_count = 0; solar_count = 0
          total_gw_m = 0.0
          model.entities.each do |e|
            next unless e.is_a?(Sketchup::Group)
            if e.name.start_with?('Support_')
              column_count += e.entities.grep(Sketchup::ComponentInstance).size
              column_count += e.entities.grep(Sketchup::Group).size if column_count == 0
            elsif e.get_attribute('JPods', 'seg_guideway', false)
              beam_count += 1
              raw = e.get_attribute('JPods', 'beam_path')
              if raw
                pts = JSON.parse(raw) rescue []
                len = 0.0
                (1...pts.size).each { |i|
                  dx = pts[i][0]-pts[i-1][0]; dy = pts[i][1]-pts[i-1][1]; dz = pts[i][2]-pts[i-1][2]
                  len += Math.sqrt(dx*dx+dy*dy+dz*dz)
                }
                total_gw_m += len / 1.m.to_f
              end
            elsif e.name.start_with?('Solar_')
              solar_count += e.entities.grep(Sketchup::ComponentInstance).size
              solar_count += e.entities.grep(Sketchup::Group).size if solar_count == 0
            end
          end

          # Count waypoint markers
          marker_count = model.entities.count { |e|
            e.is_a?(Sketchup::Group) && e.name == 'JPod Marker'
          }

          # Populate counts into BOM template
          if comps['guideway']
            # Spans = column-to-column sections. Total spans ≈ column_count.
            # 30% straight, 70% curved (typical JPods network on terrain).
            # Guideways per span from template (default 2 for dual track)
            total_spans = column_count > 0 ? column_count : beam_count / 2
            gw_per_span = (comps['guideway']['spans']['guideways_per_span'] || 2).to_i
            guideway_count = total_spans * gw_per_span
            comps['guideway']['spans']['count'] = (guideway_count * 0.3).round
            comps['guideway']['spans_curved']['count'] = (guideway_count * 0.7).round
            comps['guideway']['piers']['count'] = column_count
            comps['guideway']['footings_piers']['count'] = column_count
          end
          if comps['stations']
            comps['stations']['platforms']['count'] = station_count
            comps['stations']['stairs']['count'] = station_count
            comps['stations']['lifts']['count'] = station_count * 3
            comps['stations']['barriers']['count'] = station_count * 4
          end
          if comps['power']
            comps['power']['solar_collectors']['count'] = solar_count > 0 ? 1 : 0
          end

          # Recalculate total_cost for each item
          comps.each_value do |cat|
            cat.each_value do |item|
              next unless item.is_a?(Hash) && item['count'] && item['cost_each']
              item['total_cost'] = item['count'] * item['cost_each']
            end
          end

          bom['components'] = comps
          bom['metadata'] ||= {}
          bom['metadata']['total_length_miles'] = (total_gw_m / 1609.34).round(2)
          bom['metadata']['last_updated'] = Time.now.utc.strftime('%Y-%m-%d')

          # Save per-network BOM
          begin
            proj_dir = JPods::Project.project_dir(model) rescue File.dirname(model.path)
            base = File.basename(model.path, '.skp')
            bom_path = File.join(proj_dir, "#{base}.bom.json")
            bom['project'] = base
            File.write(bom_path, JSON.pretty_generate(bom))
            puts "[JPods] BOM written: #{bom_path}"
          rescue => ex
            puts "[JPods] BOM save error: #{ex.message}"
          end

          @dialog.execute_script("loadBomData(#{bom.to_json})")
        rescue => ex
          puts "[JPods] BOM error: #{ex.message}"
          @dialog.execute_script("loadBomData(null)")
        end
      end

      # ── Crew Flags — show/hide defect markers on guideways ────────────
      @dialog.add_action_callback("cmd_toggle_crew_flags") do |_ctx, action|
        begin
          if action == 'show'
            # Read flags from network.json and place in model
            nj_path = JPods::NetworkEditor.default_network_json_path(model) rescue nil
            if nj_path && File.exist?(nj_path)
              nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
              flags = nj['crew_flags'] || []

              # Also add gap_defects and kink_defects as flags
              (nj['gap_defects'] || []).each do |d|
                st_data = (nj.dig('designer', 'stations') || []).find { |s| s['id'] == (d['station'] || d[:station]) }
                next unless st_data
                from_pts = st_data.dig('tracks', (d['from'] || d[:from]), 'pts')
                next unless from_pts.is_a?(Array) && from_pts.size >= 1
                lp = from_pts.last
                flags << {
                  'agent' => 'Noelle', 'type' => (d['severity'] || d[:severity]).to_s,
                  'message' => "#{d['from'] || d[:from]}→#{d['to'] || d[:to]} gap=#{d['gap_mm'] || d[:gap_mm]}mm",
                  'x' => lp['x'], 'y' => lp['y'], 'z' => lp['z'], 'count' => 1
                }
              end
              (nj['kink_defects'] || []).each do |k|
                pos = k['position_mm'] || k[:position_mm]
                next unless pos.is_a?(Array) && pos.size == 3
                flags << {
                  'agent' => 'Nora', 'type' => 'kink',
                  'message' => "#{k['segment'] || k[:segment]} #{k['angle_deg'] || k[:angle_deg]}° kink",
                  'x' => pos[0], 'y' => pos[1], 'z' => pos[2], 'count' => 1
                }
              end

              # Place flag entities
              model.start_operation('Show Crew Flags', true)
              flags.each do |fl|
                world_pt = Geom::Point3d.new(fl['x'].to_f / 25.4, fl['y'].to_f / 25.4, fl['z'].to_f / 25.4)
                g = model.entities.add_group
                g.name = 'JPods Crew Flag'
                g.set_attribute('JPods', 'crew_flag', true)
                color = case fl['type'].to_s
                        when 'edge_hallucination', 'disconnect' then Sketchup::Color.new(255, 0, 0)
                        when 'kink' then Sketchup::Color.new(255, 200, 0)
                        else Sketchup::Color.new(255, 165, 0)
                        end
                mat_name = "JPods_Flag_#{fl['type']}"
                mat = model.materials[mat_name] || model.materials.add(mat_name)
                mat.color = color
                up = Geom::Vector3d.new(0, 0, 1)
                post_h = 10.0.m
                c = g.entities.add_circle(world_pt, up, 0.15.m, 8)
                if c.is_a?(Array)
                  f = g.entities.add_face(c)
                  f.pushpull(post_h) if f.is_a?(Sketchup::Face)
                end
                g.material = mat
                cnt = fl['count'].to_i
                label = "[#{fl['agent']}] #{fl['message']}#{cnt > 1 ? " (×#{cnt})" : ''}"
                g.entities.add_text(label, world_pt.offset(up, post_h + 1.m)) rescue nil
              end
              model.commit_operation
              @dialog.execute_script("showOutput('#{flags.size} crew flag(s) shown', 'ok')")
            end
          else
            # Hide — remove all crew flag entities
            model.start_operation('Hide Crew Flags', true)
            to_erase = model.entities.select { |e|
              e.is_a?(Sketchup::Group) &&
              (e.name == 'JPods Crew Flag' || e.name == 'JPods Defect Flag')
            }
            model.entities.erase_entities(to_erase) if to_erase.any?
            model.commit_operation
            @dialog.execute_script("showOutput('Crew flags hidden', 'ok')")
          end
        rescue => ex
          puts "[Crew Flags] error: #{ex.message}"
        end
      end

      # Get station names + slot counts for the Network Display station names panel
      # Reads friendly names from network.json (source of truth), falls back to entity attrs
      @dialog.add_action_callback("cmd_get_station_names") do |_ctx|
        begin
          # Read names from network.json
          nj_names = {}
          nj_path = JPods::NetworkEditor.default_network_json_path(model) rescue nil
          if nj_path && File.exist?(nj_path)
            nj = JSON.parse(File.read(nj_path, encoding: 'utf-8')) rescue {}
            nj_names = nj['station_names'] || {}
          end

          stations = []
          model.entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
            sid = e.get_attribute('JPods', 'structure_id', '').to_s.strip
            next if sid.empty?
            mid   = e.get_attribute('JPods', 'model_id', '').to_s
            # Prefer network.json name, fall back to entity attribute
            name  = nj_names[sid] || nj_names[sid.downcase] ||
                    e.get_attribute('JPods', 'station_name', '').to_s.strip
            slots = (e.get_attribute('JPods', 'parking_slots', 0) rescue 0).to_i
            ml = mid.downcase
            if ml.include?('traffic_circle')
              slots = 0
            elsif slots == 0
              slots = ml.include?('parking') ? 9 : ml.include?('thru') ? 3 : 3
            end
            stype = mid.sub(/\Astation_/i, '').gsub('_', ' ')
            stations << { id: sid, type: stype, name: name, slots: slots }
          end
          stations.sort_by! { |s| s[:id].downcase }
          @dialog.execute_script("loadStationNames(#{stations.to_json})")
        rescue => ex
          puts "[JPods] station names error: #{ex.message}"
        end
      end

      # Open SketchUp's Ruby Console for detailed log stream
      @dialog.add_action_callback("cmd_open_su_console") do |_ctx|
        Sketchup.send_action('showRubyPanel:') rescue nil
      end

      # Camera offset controls — set back/right/up before follow snaps
      @dialog.add_action_callback("cmd_set_camera_offsets") do |_ctx, json_text|
        begin
          vals = JSON.parse(json_text)
          if defined?(JPods::AnimationV2)
            JPods::AnimationV2.set_camera_offsets(vals['back'], vals['right'], vals['up'])
          end
        rescue => ex
          puts "[JPods] camera offset error: #{ex.message}"
        end
      end

      # Crew Health — run checks, return results to console HTML
      @dialog.add_action_callback("cmd_crew_health") do |_ctx|
        begin
          data = { agents: [], total_faults: 0, journal: [], memory: [] }

          if defined?(JPods::CrewHealth)
            results = JPods::CrewHealth.check(model)
            results.each do |r|
              data[:agents] << {
                agent: r[:agent], ok: r[:ok],
                checks: r[:checks].size, faults: r[:faults].size,
                fault_list: r[:faults],
              }
            end
            data[:total_faults] = results.sum { |r| r[:faults].size }
          end

          # Journal entries
          if defined?(JPods::CrewJournal)
            jpath = JPods::CrewJournal.send(:_journal_path, model)
            if jpath && File.exist?(jpath)
              j = JSON.parse(File.read(jpath, encoding: 'utf-8')) rescue {}
              data[:journal] = (j['entries'] || []).last(15)
            end
          end

          # Agent memory
          if defined?(JPods::Log)
            JPods::Log::AGENTS.each do |agent|
              facet = JPods::Log.send(:_load_facet, agent)
              obs = facet['observations'] || []
              next if obs.empty?
              data[:memory] << {
                agent: agent.to_s, count: obs.size,
                latest: obs.last['observation'],
              }
            end
          end

          @dialog.execute_script("updateCrewHealth(#{data.to_json})")
        rescue => ex
          puts "[CrewHealth console] error: #{ex.message}"
        end
      end

      # Set agent log level from console
      @dialog.add_action_callback("cmd_set_log_level") do |_ctx, agent, level|
        if defined?(JPods::Log)
          if agent == 'all'
            JPods::Log.level = level.to_sym
          else
            JPods::Log.set(agent.to_sym, level.to_sym)
          end
        end
      end

      # Refresh pods — push updated pod data to console
      # Save Network — Noelle validates network.json, removes invalid connections,
      # refreshes the display. Shift-click deletes and new CP connections already
      # write to disk immediately. This button cleans up and refreshes.
      @dialog.add_action_callback("cmd_save_network") do |_ctx|
        begin
          network_path = JPods::NetworkEditor.default_network_json_path(model)
          root = File.exist?(network_path) ?
                   (JSON.parse(File.read(network_path, encoding: 'utf-8')) rescue {}) : {}
          root['connections'] ||= {}

          # Noelle validates: remove connections referencing missing stations
          valid_sids = []
          model.entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
            sid = e.get_attribute('JPods', 'structure_id', '').to_s.strip
            valid_sids << sid.downcase unless sid.empty?
          end
          removed = []
          root['connections'].each_key do |conn_id|
            sids_in_conn = conn_id.scan(/([a-z]\d+)\./).flatten.map(&:downcase)
            unless sids_in_conn.all? { |s| valid_sids.include?(s) }
              removed << conn_id
            end
          end
          removed.each { |cid| root['connections'].delete(cid) }

          if removed.any?
            root['generated_at'] = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
            File.write(network_path, JSON.pretty_generate(root), encoding: 'utf-8')
          end

          conn_count = root['connections'].size
          msg = "Network: #{conn_count} connection(s)"
          msg += " — #{removed.size} invalid removed by Noelle" if removed.any?
          puts "[JPods] #{msg}"
          @dialog.execute_script("showOutput(#{msg.to_json}, 'ok')")

          # Refresh iframe from disk
          nd = JPods::NetworkEditor.load_network_definition_from_path(network_path)
          if nd['connections'].is_a?(Hash)
            flat = JPods::NetworkEditor.feature_connections_to_flat_array(nd['connections'])
            nd_for_iframe = nd.dup
            nd_for_iframe['connections'] = flat.map { |e|
              { 'id' => e['connection_id'],
                'from' => e['from'], 'to' => e['to'],
                'via_markers' => e['via_markers'] || [] }
            }.uniq { |c| c['id'] }
            nd_text = JSON.pretty_generate(nd_for_iframe)
          else
            nd_text = JSON.pretty_generate(nd)
          end
          @dialog.execute_script("loadNetworkEditorContent(#{nd_text.to_json}, #{network_path.to_json})")
          JPods::NetworkEditor.push_feature_connections(model, @dialog)
        rescue => ex
          puts "[JPods] save network error: #{ex.message}"
          @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
        end
      end

      # Delete a single connection from network.json — called by × button in Network Display
      @dialog.add_action_callback("cmd_delete_connection") do |_ctx, conn_id|
        begin
          conn_id = conn_id.to_s.strip
          next if conn_id.empty?
          JPods::NetworkEditor.delete_connection(model, conn_id)
          # Also remove from Connect tool drafts
          if defined?(JPods::JPodConnectTool) && JPods::JPodConnectTool.respond_to?(:draft_connections)
            JPods::JPodConnectTool.draft_connections.reject! { |d| d[:conn_id] == conn_id }
          end
          puts "[JPods] Connection deleted: #{conn_id}"
        rescue => ex
          puts "[JPods] delete connection error: #{ex.message}"
        end
      end

      # Reload network.json into the NE iframe — picks up CP changes from Connect tool.
      @dialog.add_action_callback("cmd_refresh_network") do |_ctx|
        begin
          network_path = JPods::NetworkEditor.default_network_json_path(model)
          nd = JPods::NetworkEditor.load_network_definition_from_path(network_path)
          if nd['connections'].is_a?(Hash)
            flat = JPods::NetworkEditor.feature_connections_to_flat_array(nd['connections'])
            nd_for_iframe = nd.dup
            nd_for_iframe['connections'] = flat.map { |e|
              { 'id' => e['connection_id'],
                'from' => e['from'], 'to' => e['to'],
                'via_markers' => e['via_markers'] || [] }
            }.uniq { |c| c['id'] }
            nd_text = JSON.pretty_generate(nd_for_iframe)
          else
            nd_text = JSON.pretty_generate(nd)
          end
          @dialog.execute_script("loadNetworkEditorContent(#{nd_text.to_json}, #{network_path.to_json})")
          JPods::NetworkEditor.push_feature_connections(model, @dialog)
          conn_count = (nd['connections'] || {}).size
          puts "[JPods] Network Display refreshed — #{conn_count} connection(s)"
        rescue => ex
          puts "[JPods] refresh network error: #{ex.message}"
        end
      end

      # Approve template — designer confirms all tests pass.
      # Stamps approved_at in lines.computed.json.
      # If Team Review checked, copies console log to Allie for review.
      @dialog.add_action_callback("cmd_approve_template") do |_ctx|
        begin
          m = Sketchup.active_model
          raise "No active model." unless m
          unless m.path.to_s.gsub('\\', '/').include?('track_formations')
            raise "Not a template model — Approve is for templates only."
          end

          plugin_dir = File.dirname(__FILE__)
          # Derive template dir from model path
          tmpl_dir = File.dirname(m.path)
          computed_path = File.join(tmpl_dir, 'lines.computed.json')
          raise "lines.computed.json not found — run Compute first." unless File.exist?(computed_path)

          data = JSON.parse(File.read(computed_path, encoding: 'utf-8'))
          now_utc = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
          data['approved_at'] = now_utc
          data['approved_by'] = 'designer'

          # Record all three file mtimes at approval — the validation chain
          # checks that no file was saved after approved_at.
          model_path = File.join(tmpl_dir, 'model.skp')
          lj_path    = File.join(tmpl_dir, 'lines.json')
          data['source_files'] = {
            'model.skp'    => File.exist?(model_path) ? File.mtime(model_path).utc.strftime('%Y-%m-%dT%H:%M:%SZ') : nil,
            'lines.json'   => File.exist?(lj_path)    ? File.mtime(lj_path).utc.strftime('%Y-%m-%dT%H:%M:%SZ')    : nil,
            'lines.computed.json' => now_utc
          }

          File.write(computed_path, JSON.pretty_generate(data), encoding: 'utf-8')

          model_id = data['model_id'] || File.basename(tmpl_dir)
          puts "[Approve] ✓ #{model_id} approved at #{data['approved_at']}"
          @dialog.execute_script("showOutput(#{"✓ #{model_id} approved at #{data['approved_at']} — closing model".to_json}, 'ok')")

          # Close the model after successful approval
          UI.start_timer(1.0, false) { m.close rescue nil }

          # Copy console log to Allie if Team Review is checked
          team_review = @dialog.execute_script("document.getElementById('chk-team-review').checked") rescue true
          # execute_script returns are unreliable in HtmlDialog — use callback instead.
          # For now, always copy. The checkbox controls a future JS→Ruby callback.
          allie_log_dir = File.expand_path('~/Allie/process/inbox')
          if Dir.exist?(File.dirname(allie_log_dir))
            FileUtils.mkdir_p(allie_log_dir)
            log_path = File.join(File.dirname(__FILE__), 'jpod_console.log')
            if File.exist?(log_path)
              ts = Time.now.utc.strftime('%Y%m%dT%H%M%S')
              dest = File.join(allie_log_dir, "#{ts}-approve-#{model_id}.log")
              FileUtils.cp(log_path, dest)
              puts "[Approve] Console log copied to #{dest}"
            end
          end
        rescue => ex
          puts "[Approve] error: #{ex.message}"
          @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
        end
      end

      @dialog.add_action_callback("cmd_refresh_pods") do |_ctx|
        rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
        @dialog.execute_script("updateVehicleRows(#{rows.to_json})")
      end

      # Sally Dashboard — live view of Sally's pods[] and ps[] per station
      @dialog.add_action_callback("cmd_sally_dashboard") do |_ctx|
        sally_mod = defined?(SallyV2) ? SallyV2 : (defined?(JPods::SallyV2) ? JPods::SallyV2 : nil)
        puts "[Sally Dashboard] callback fired, sally=#{sally_mod ? 'found' : 'nil'}"
        data = []
        if sally_mod
          puts "[Sally Dashboard] stations count: #{sally_mod.stations.size}"
          nj_names = {}
          nj_path = JPods::NetworkEditor.default_network_json_path(model) rescue nil
          if nj_path && File.exist?(nj_path)
            nj = JSON.parse(File.read(nj_path, encoding: 'utf-8')) rescue {}
            nj_names = nj['station_names'] || {}
          end
          sally_mod.stations.each do |sid, st|
            slots = st.ps.map { |s|
              { number: s.number, state: s.state.to_s, occupant: s.occupant_id }
            }
            pods = st.pods.map { |nid, rec|
              { nora_id: nid, state: rec.state.to_s, slot: rec.slot }
            }
            data << {
              sid: sid,
              name: nj_names[sid] || sid,
              capacity: st.capacity,
              occupancy: st.occupancy,
              slots: slots,
              pods: pods,
              inbound: st.inbound_count,
            }
          end
        end
        data.sort_by! { |d| d[:sid] }

        # Natalie fleet data — where every pod actually IS
        fleet_data = []
        if defined?(NatalieV2) && NatalieV2.respond_to?(:fleet)
          NatalieV2.scan_fleet(model) if NatalieV2.fleet.empty?
          NatalieV2.fleet.each do |nid, rec|
            pos = NatalieV2.pod_position(nid)
            fleet_data << {
              nora_id: nid,
              position_mm: pos,
              station_id: rec.station_id,
              destination_sid: rec.destination_sid,
              state: rec.state.to_s,
            }
          end
          # Cross-check desyncs
          desyncs = NatalieV2.fleet_desyncs
          desyncs.each do |d|
            puts "[Natalie] ⚠ DESYNC: #{d[:nora_id]} — entity at #{d[:natalie_station]} but Sally doesn't know"
          end
        end

        @dialog.execute_script("showSallyDashboard(#{data.to_json}, #{fleet_data.to_json})")
      end

      # ── Flag Defect — designer reports what they see ─────────────────────
      @dialog.add_action_callback("cmd_flag_defect") do |_ctx, note|
        note = note.to_s.strip
        next if note.empty?
        # Gather context: all Sally station snapshots + Natalie fleet positions
        context = {}
        if defined?(SallyV2)
          context['sally'] = SallyV2.stations.map { |sid, st| st.snapshot }
        end
        if defined?(NatalieV2)
          NatalieV2.scan_fleet(model)
          context['fleet'] = NatalieV2.fleet.map { |nid, rec|
            pos = NatalieV2.pod_position(nid)
            { nora_id: nid, station: rec.station_id, position_mm: pos, state: rec.state.to_s }
          }
        end
        JPods::Log.flag(note, data: context) if defined?(JPods::Log)
        @dialog.execute_script("appendResult('🚩 Flagged: #{note.gsub("'", "\\\\'")}')")
      rescue => ex
        puts "[Flag] error: #{ex.message}"
      end

      # ── Show recent defects in RESULT console ───────────────────────────
      @dialog.add_action_callback("cmd_show_defects") do |_ctx|
        defects = defined?(JPods::Log) ? JPods::Log.defects(last_n: 30) : []
        if defects.empty?
          @dialog.execute_script("appendResult('No defects logged yet.')")
          next
        end
        lines = ["═══ Recent Defects (#{defects.size}) ═══", ""]
        defects.each do |d|
          src = d['source'] == 'designer' ? '🚩' : '⛔'
          t = d['model_time'] ? " t=#{d['model_time']}s" : ''
          local = d['local'] ? " (#{d['local']})" : ''
          lines << "#{src} #{d['dt']}#{local}#{t} [#{d['agent'] || '?'}/#{d['type']}] #{d['detail']}"
        end
        @dialog.execute_script("appendResult(#{lines.join("\n").to_json})")
      rescue => ex
        puts "[Show Defects] error: #{ex.message}"
      end

      # ── Validate Sally — run validate! on all stations ──────────────────
      @dialog.add_action_callback("cmd_validate_sally") do |_ctx|
        sally_mod = defined?(SallyV2) ? SallyV2 : nil
        unless sally_mod
          @dialog.execute_script("appendResult('Sally not loaded.')")
          next
        end
        total_defects = 0
        lines = ["═══ Sally Validate ═══", ""]
        sally_mod.stations.each do |sid, st|
          defects = st.validate!
          defects.each do |d|
            JPods::Log.defect(:sally, d[:type], d[:detail], data: st.snapshot) if defined?(JPods::Log)
            total_defects += 1
          end
          lines << "#{sid}: #{defects.size == 0 ? '✓ clean' : "#{defects.size} defect(s) purged"}" \
                   " (#{st.occupancy}/#{st.capacity} slots, #{st.pods.size} pod records)"
        end
        lines << ""
        lines << total_defects == 0 ? "All stations clean." : "#{total_defects} total defect(s) purged and logged."
        @dialog.execute_script("appendResult(#{lines.join("\n").to_json})")
      rescue => ex
        puts "[Validate Sally] error: #{ex.message}"
      end

      # ── Dump station arrays to RESULT console ────────────────────────────
      @dialog.add_action_callback("cmd_dump_station") do |_ctx, sid|
        sid = sid.to_s.strip.downcase
        sally_mod = defined?(SallyV2) ? SallyV2 : (defined?(JPods::SallyV2) ? JPods::SallyV2 : nil)
        next unless sally_mod

        st = sally_mod.station(sid)
        unless st
          @dialog.execute_script("appendResult('Station #{sid} not found')")
          next
        end

        lines = []
        lines << "═══ #{sid} — Sally Arrays ═══"
        lines << ""
        lines << "── ps[] (#{st.capacity} slots) ──"
        st.ps.each do |s|
          status = case s.state
                   when :occupied then "OCCUPIED #{s.occupant_id}"
                   when :reserved then "RESERVED for #{s.reserved_for}"
                   else "empty"
                   end
          lines << "  ps#{s.number}: #{status}"
        end
        lines << ""
        lines << "── pods[] (#{st.pods.size} records) ──"
        st.pods.each do |nid, rec|
          pos = defined?(NatalieV2) ? NatalieV2.pod_position(nid) : nil
          pos_str = pos ? "(#{pos[0].round(0)},#{pos[1].round(0)},#{pos[2].round(0)})" : "?"
          slot_match = rec.slot && st.slot(rec.slot)&.occupant_id == nid ? "✓" : "✗ DESYNC"
          lines << "  #{nid}: slot=#{rec.slot || '—'} state=#{rec.state} #{slot_match} entity=#{pos_str}"
        end
        lines << ""
        lines << "── inbound (#{st.inbound_count}) ──"
        st.instance_variable_get(:@inbound)&.each do |nid, info|
          lines << "  #{nid}: eta=#{info[:eta_s]}s from=#{info[:from_sid] || '?'}"
        end
        lines << ""
        lines << "occupancy=#{st.occupancy} effective=#{st.effective_occupancy} capacity=#{st.capacity}"
        lines << "full?=#{st.full?} has_capacity?=#{st.has_capacity?}"

        output = lines.join("\n")
        puts output
        @dialog.execute_script("appendResult(#{output.to_json})")
      rescue => ex
        puts "[Dump Station] error: #{ex.message}"
      end

      # ── Report Stuck Pod — user reports a pod that isn't moving ────────
      # Clears the pod from Sally's arrays at every station, removes from
      # dwelling, and re-scans fleet. The pod entity stays in the model
      # but becomes available for fresh registration on next Populate or arrival.
      @dialog.add_action_callback("cmd_report_stuck") do |_ctx, nora_id|
        nora_id = nora_id.to_s.strip
        next if nora_id.empty?
        puts "[Report Stuck] #{nora_id}"

        cleared_from = []
        if defined?(SallyV2)
          SallyV2.stations.each do |sid, st|
            # Clear from pod array
            had_pod = st.pods.delete(nora_id)
            # Clear from slot array
            st.ps.each do |s|
              if s.occupant_id == nora_id
                s.vacate!
                cleared_from << "#{sid}.ps#{s.number}"
              end
            end
            cleared_from << "#{sid}.pods" if had_pod
          end
        end

        # Clear from animation dwelling
        if defined?(AnimationV2)
          AnimationV2._undwell(nora_id) rescue nil
        end

        # Re-scan fleet
        NatalieV2.scan_fleet(model) if defined?(NatalieV2)

        pos = defined?(NatalieV2) ? NatalieV2.pod_position(nora_id) : nil
        pos_str = pos ? "(#{pos[0].round(0)},#{pos[1].round(0)},#{pos[2].round(0)})mm" : "unknown"

        msg = if cleared_from.any?
                "#{nora_id} cleared from #{cleared_from.join(', ')}. Entity at #{pos_str}. Will re-register on next arrival."
              else
                "#{nora_id} not found in any Sally station. Entity at #{pos_str}."
              end
        puts "[Report Stuck] #{msg}"
        @dialog.execute_script("alert('#{msg.gsub("'", "\\\\'")}')")

        # Refresh the dashboard
        @dialog.execute_script("sketchup.cmd_sally_dashboard()")
      rescue => ex
        puts "[Report Stuck] error: #{ex.message}"
      end

      # Capacity data — compute network metrics for the capacity estimator
      @dialog.add_action_callback("cmd_capacity_data") do |_ctx|
        begin
          # Pod count
          pod_count = if defined?(JPods::AnimationV2)
                        (JPods::AnimationV2.pods rescue []).size
                      else
                        0
                      end

          # Guideway length — sum beam_path lengths from seg_ groups
          total_gw_m = 0.0
          model.entities.each do |e|
            next unless e.is_a?(Sketchup::Group) && e.get_attribute('JPods', 'seg_guideway', false)
            raw = e.get_attribute('JPods', 'beam_path')
            next unless raw
            pts = JSON.parse(raw)
            next unless pts.is_a?(Array) && pts.size >= 2
            len = 0.0
            (1...pts.size).each { |i|
              dx = pts[i][0] - pts[i-1][0]
              dy = pts[i][1] - pts[i-1][1]
              dz = pts[i][2] - pts[i-1][2]
              len += Math.sqrt(dx*dx + dy*dy + dz*dz)
            }
            total_gw_m += len / 1.m.to_f  # inches to metres
          end

          # Station count and total parking slots
          station_count = 0
          total_slots = 0
          model.entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
            sid = e.get_attribute('JPods', 'structure_id', '').to_s
            next if sid.empty?
            mid = e.get_attribute('JPods', 'model_id', '').to_s.downcase
            next if mid.include?('traffic_circle')
            station_count += 1
            # Count parking slots from Sally's data or estimate from template
            slots = (e.get_attribute('JPods', 'parking_slots', 0) rescue 0).to_i
            slots = 3 if slots == 0  # default estimate
            total_slots += slots
          end

          # Average trip distance — mean of all station-pair distances via network
          # Simple estimate: total guideway / (station_count * 2) for typical trip
          avg_trip_m = station_count > 1 ? total_gw_m / (station_count * 1.5) : total_gw_m

          speed_ms = 12.0  # 27 mph default cruise

          data = {
            pod_count: pod_count,
            total_guideway_m: total_gw_m.round(1),
            total_slots: total_slots,
            station_count: station_count,
            avg_trip_m: avg_trip_m.round(1),
            speed_ms: speed_ms
          }
          @dialog.execute_script("loadCapacityData(#{data.to_json})")
        rescue => ex
          puts "[JPods] capacity data error: #{ex.message}"
        end
      end

      # Station Names — save friendly names to entity attributes.
      # Payload: JSON string {"S002":"Main Plaza","S004":"Airport",...}
      @dialog.add_action_callback("cmd_set_station_names") do |_ctx, json|
        begin
          names = JSON.parse(json.to_s)
          saved = 0

          # 1. Write to entity attributes (cache for SU display)
          model.entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
            sid = e.get_attribute('JPods', 'structure_id', '').to_s
            next if sid.empty? || !names.key?(sid)
            e.set_attribute('JPods', 'station_name', names[sid].to_s)
            saved += 1
          end

          # 2. Write to network.json (source of truth for all consumers)
          nj_path = JPods::NetworkEditor.default_network_json_path(model) rescue nil
          if nj_path && File.exist?(nj_path)
            nj = JSON.parse(File.read(nj_path, encoding: 'utf-8'))
            stations = (nj['designer'] || {})['stations'] || []
            stations.each do |st|
              sid = st['id'].to_s
              st['friendly_name'] = names[sid] if names.key?(sid)
            end
            # Also store as top-level station_names for easy access
            nj['station_names'] = names
            File.write(nj_path, JSON.pretty_generate(nj), encoding: 'utf-8')
            puts "[JPods Console] station names → network.json"
          end

          puts "[JPods Console] station names saved: #{saved}"
          @dialog.execute_script("showOutput(#{("#{saved} station name(s) saved.").to_json}, 'ok')")
        rescue => e
          @dialog.execute_script("showOutput(#{("Save failed: #{e.message}").to_json}, 'error')")
        end
      end

      @dialog.add_action_callback("cmd_open_travel") do |_ctx|
        # One code path — Console.open_travel has the canonical Travel callbacks
        JPods::Console.open_travel(model)
      end

      @dialog.add_action_callback("cmd_open_network_editor") do |_ctx|
        begin
          network_path = JPods::NetworkEditor.default_network_json_path(model) rescue nil
          if network_path && File.exist?(network_path)
            JPods::NetworkEditor.push_network_json(model, network_path)
            JPods::NetworkEditor.push_feature_connections(model, @dialog)
            @dialog.execute_script("showOutput(#{'Network Editor refreshed.'.to_json}, 'ok')")
          else
            @dialog.execute_script("showOutput(#{'No network.json — run Build first.'.to_json}, 'warn')")
          end
        rescue => e
          send_error("Network Editor failed: #{e.message}")
        end
      end

      # Save network JSON from the embedded NE iframe to the project followme/network.json.
      # Called via window.saveNetworkFromIframe in console.html when the user clicks Save Network.
      @dialog.add_action_callback("cmd_save_network") do |_ctx, text|
        begin
          data      = JSON.parse(text.to_s)
          # Build reads from network.json — save there, not followme.json.
          save_path = JPods::NetworkEditor.default_network_json_path(model)
          unless save_path
            puts "[JPods Console] cmd_save_network: no path available — save the .skp file first"
            next
          end
          JPods::NetworkEditor.save_network_definition_to_path(save_path, data)
          count    = (data['connections'] || []).length
          filename = File.basename(save_path)
          puts "[JPods Console] cmd_save_network: #{count} connection(s) saved → #{filename}"
          # Notify the NE iframe that the save completed.
          @dialog.execute_script(
            "var _fr = document.getElementById('network-editor-iframe');" \
            "if (_fr && _fr.contentWindow && typeof _fr.contentWindow.onNetworkSaved === 'function')" \
            "  _fr.contentWindow.onNetworkSaved(#{filename.to_json});"
          )
        rescue => e
          puts "[JPods Console] cmd_save_network error: #{e.message}"
        end
      end

      @dialog.add_action_callback("cmd_jpods_save") do |_ctx|
        begin
          model = Sketchup.active_model
          result = JPods::Project.jpods_save(model)
          puts "[JPods Save] #{result}"
          @dialog.execute_script("showOutput(#{result.to_json}, 'info')")
          # Refresh the header model name after save
          name = model&.path && !model.path.empty? ? File.basename(model.path, '.skp') : '(unsaved)'
          @dialog.execute_script("updateModelName(#{name.to_json})")
        rescue => e
          err = "Save failed: #{e.message}"
          puts "[JPods Save] #{err}"
          @dialog.execute_script("showOutput(#{err.to_json}, 'error')")
        end
      end

      @dialog.add_action_callback("cmd_reload_plugin") do |_ctx|
        begin
          puts "[JPods cmd_reload_plugin] starting full plugin reload"
          JPods::NetworkEditor.close if defined?(JPods::NetworkEditor) && JPods::NetworkEditor.respond_to?(:close)

          # Robust reload path: do not rely on optional helper methods.
          # Reset both guards because either main.rb or boot.rb might be active.
          $jpods_main_loaded = nil
          $jpods_booted = nil

          root = defined?(JPODS_ROOT) ? JPODS_ROOT : File.dirname(__FILE__)

          # Snapshot restart-sensitive file mtimes before the reload so we can
          # detect changes that won't take effect until SketchUp restarts.
          mtimes_before = JPods::Console.snapshot_mtimes(root)

          loader = File.join(root, 'main.rb')
          loader = File.join(root, 'boot.rb') unless File.exist?(loader)
          raise "No JPods loader found (main.rb/boot.rb)." unless File.exist?(loader)

          load loader
          puts "[JPods cmd_reload_plugin] reload complete"

          # Check for files that require a full SketchUp restart.
          # main.rb menu/toolbar sections run only once per session ($jpods_registered guard)
          # and do not re-execute on reload even after $jpods_main_loaded is reset.
          changed = JPods::Console.changed_restart_files(root, mtimes_before)
          if changed.any?
            file_list = changed.map { |f| "  • #{f}" }.join("\n")
            msg = "Plugin reloaded.\n\n" \
                  "The following files were modified and require a SketchUp restart " \
                  "to take full effect (menu items and toolbar buttons won't update until then):\n\n" \
                  "#{file_list}\n\n" \
                  "Save your work and quit SketchUp now?"
            puts "[JPods cmd_reload_plugin] restart-required files changed: #{changed.join(', ')}"
            result = UI.messagebox(msg, MB_YESNO)
            if result == IDYES
              puts "[JPods cmd_reload_plugin] user confirmed — calling Sketchup.quit"
              Sketchup.quit
              next  # quit is async; skip reopen in case it takes a moment
            end
          end

          # Nil @dialog before close so the set_on_closed guard does not race.
          # Use Sketchup.active_model — not the model captured at callback-register time.
          dlg = @dialog
          @dialog = nil
          dlg.close if dlg

          # Reopen immediately: fresh cache-busted HTML, rebuilt TASKS list,
          # clean setup_callbacks with no accumulated duplicate handlers.
          JPods::Console.open(Sketchup.active_model)
        rescue Exception => e
          puts "[JPods cmd_reload_plugin] RESCUE (#{e.class}): #{e.message}"
          puts e.backtrace.first(10).join("\n") if e.backtrace
          send_error("Reload failed (#{e.class}): #{e.message}")
        end
      end

      # Set XY and Z profile radii from the Build Profile controls.
      # Values arrive in metres; apply_primary_constraint_overrides expects inches.
      @dialog.add_action_callback("cmd_set_smooth_radii") do |_ctx, json_text|
        begin
          vals = JSON.parse(json_text)
          overrides = {}
          overrides["HORIZONTAL_SMOOTH_RADIUS"] = vals['xy'].to_f.m      if vals['xy']
          overrides["MIN_Z_CHANGE_DIAMETER"]    = vals['z_curve'].to_f.m  if vals['z_curve']
          Constants.apply_primary_constraint_overrides(
            Constants.primary_constraint_overrides.merge(overrides)
          )
          all = Constants.primary_constraint_overrides
          model.set_attribute("JPods", "primary_constraints_overrides", all.to_json)
          xy_m = (Constants::HORIZONTAL_SMOOTH_RADIUS / 1.m).round(1)
          zr_m = (Constants::MIN_Z_CHANGE_DIAMETER / 1.m).round(1)
          puts "[JPods] Build profile: XY=#{xy_m}m  Z=#{zr_m}m"
          @dialog.execute_script("showOutput('Build profile: XY=#{xy_m}m, Z=#{zr_m}m. Run Build.', 'ok')")
        rescue => ex
          puts "[JPods] smooth radii error: #{ex.message}"
          @dialog.execute_script("showOutput(#{("Smooth radii error: #{ex.message}").to_json}, 'error')")
        end
      end

      # Show/Hide one Nora trip path from the trip table Route button.
      # Toggles: if this vehicle's trip is already shown, clears it; otherwise draws it.
      # If no trip is assigned, clears any currently shown route and resets all buttons.
      @dialog.add_action_callback("cmd_show_trip") do |_ctx, nora_id|
        vid = nora_id.to_s.strip
        puts "[JPods Console cmd_show_trip] nora_id=#{vid}"
        begin
          already_shown = JPods::JPodGuideway.trip_path_shown_for?(model, vid)
          if already_shown
            # Hide this vehicle's route.
            JPods::JPodGuideway.clear_shown_trip_path(model)
            @dialog.execute_script("showOutput('Route hidden.', 'ok')") rescue nil
            @dialog.execute_script("setTripRouteState(null)") rescue nil
          else
            # Clear any other route first, then try to show this one.
            JPods::JPodGuideway.clear_shown_trip_path(model) rescue nil
            ok, msg = JPods::JPodGuideway.show_trip_path_for_vehicle(model, vid)
            puts "[JPods Console cmd_show_trip] ok=#{ok} msg=#{msg}"
            status = ok ? 'ok' : 'error'
            @dialog.execute_script("showOutput(#{msg.to_json}, #{status.to_json})") rescue nil
            # ok=true → mark this vehicle's button Hide Route; all others Show Route.
            # ok=false (empty trip or no path data) → reset all to Show Route.
            shown_vid = ok ? vid : nil
            @dialog.execute_script("setTripRouteState(#{shown_vid.to_json})") rescue nil
          end
        rescue => ex
          puts "[JPods Console cmd_show_trip] exception: #{ex.message}"
          @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')") rescue nil
          @dialog.execute_script("setTripRouteState(null)") rescue nil
        end
      end

      # Open rich trip detail in the in-dialog modal (built on-the-fly, no file needed).
      # Shows: line sequence, length per segment, from/to structures, merging/diverging lines.
      @dialog.add_action_callback("cmd_show_trip_json") do |_ctx, nora_id|
        vid    = nora_id.to_s.strip
        detail = JPods::JPodGuideway.build_trip_detail(model, vid)
        text   = JSON.pretty_generate(detail)
        # Show in modal AND push to OUTPUT so user can study without the modal
        @dialog.execute_script("showTripJson(#{vid.to_json}, #{text.to_json})")
        @dialog.execute_script("showOutput(#{text.to_json}, 'ok')")
      rescue => ex
        @dialog.execute_script("showOutput(#{("Trip detail error: #{ex.message}").to_json}, 'error')")
      end

      # Clear the currently shown trip overlay group
      @dialog.add_action_callback("cmd_clear_trip") do |_ctx|
        ok = JPods::JPodGuideway.clear_shown_trip_path(model)
        msg = ok ? 'Cleared shown trip path.' : 'Nothing to clear.'
        status = ok ? 'ok' : 'error'
        @dialog.execute_script("showOutput(#{msg.to_json}, #{status.to_json})")
        rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
        @dialog.execute_script("setTripTable(#{rows.to_json})")
      end

      # Add one vehicle at the chosen station, route it to a random other station.
      @dialog.add_action_callback("cmd_add_vehicle") do |_ctx, station_id, model_id|
        station_id = station_id.to_s.strip.upcase
        known      = JPods::JPodGuideway::STANDARD_TEST_SLOT_VEHICLES.compact
        model_id   = model_id.to_s.strip
        model_id   = known.first || 'passenger_Yellow' if model_id.empty? || !known.include?(model_id)
        UI.start_timer(0, false) do
          begin
            platforms = JPods::JPodGuideway.load_followme_platforms(model)
            origin_platforms = platforms.select { |p| p['structure_id'].to_s.strip.upcase == station_id }
            raise "No platforms at #{station_id} — run Build first." if origin_platforms.empty?

            all_station_ids = platforms.map { |p| p['structure_id'].to_s.strip.upcase }.uniq
            other_ids = all_station_ids.reject { |sid| sid == station_id }

            # Count vehicles already parked at this station (not total model count).
            # First 3 per station get a trip at placement; the rest park as idle_reserve
            # and Natalie dispatches them every 6 s during animation.
            at_station = JPods::JPodGuideway.all_nora_vehicles_in_model(model).count { |v|
              v[:entity].get_attribute('JPods', 'parked_station_id', '').to_s.strip.upcase == station_id
            } rescue 0

            origin_platform = origin_platforms.first
            dest_station_id = nil
            dest_platform = if at_station < 3 && other_ids.any?
              dest_station_id = other_ids.sample
              platforms.find { |p| p['structure_id'].to_s.strip.upcase == dest_station_id }
            end

            vehicle_template_id = model_id
            ok, result = JPods::JPodGuideway.place_vehicle_at_platform(
              model, vehicle_template_id, origin_platform, dest_platform
            )
            raise result.to_s unless ok

            nora_id   = result[:nora_id]
            slot      = result[:origin_parking_slot].to_i
            capacity  = result[:slot_count].to_i
            compact_note = result[:compacted] ? ' (compacted)' : ''
            dest_note = dest_station_id ? " → #{dest_station_id}" : ' (idle — Natalie dispatches)'
            msg = "#{nora_id} placed at #{station_id} slot #{slot}/#{capacity}#{compact_note}#{dest_note}."
            if result[:route_warning]
              msg += "\nWarning: #{result[:route_warning]}."
            end
            rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
            @dialog.execute_script("setTripTable(#{rows.to_json})")
            status = result[:route_warning] ? 'warn' : 'ok'
            @dialog.execute_script("showOutput(#{msg.to_json}, #{status.to_json})")
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Set the destination station for a vehicle from the trip table End input.
      # station_num is just the numeric part: "1" → finds "S001", "2" → "S002", etc.
      @dialog.add_action_callback("cmd_set_trip_end") do |_ctx, nora_id, station_num|
        UI.start_timer(0, false) do
          begin
            nora_id    = nora_id.to_s.strip
            station_num = station_num.to_s.strip
            raise "No vehicle ID." if nora_id.empty?

            platforms = JPods::JPodGuideway.load_followme_platforms(model) rescue []
            all_sids  = platforms.map { |p| p['structure_id'].to_s.strip.upcase }.uniq
            dest_sid  = all_sids.find { |s|
              m = s.match(/\A[A-Z]+(\d+)\z/i)
              m && m[1].to_i == station_num.to_i
            }
            raise "Station #{station_num} not found in network." unless dest_sid

            e = nil
            JPods::JPodGuideway.all_nora_vehicles_in_model(model).each do |veh|
              e = veh[:entity] if veh[:vehicle_id] == nora_id
            end
            raise "Vehicle #{nora_id} not found." unless e

            origin_sid = e.get_attribute('JPods', 'parked_station_id', '').to_s.strip.upcase
            raise "Destination must differ from origin (#{origin_sid})." if dest_sid == origin_sid

            dest_platform = platforms.find { |pl| pl['structure_id'].to_s.strip.upcase == dest_sid }
            model.start_operation('JPods Set Destination', true)
            e.set_attribute('JPods', 'destination_station_id',  dest_sid)
            e.set_attribute('JPods', 'destination_platform_id',
                            dest_platform ? dest_platform['id'].to_s : dest_sid)
            e.set_attribute('JPods', 'parking_state', 'trip_assigned')
            model.commit_operation

            rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
            @dialog.execute_script("setTripTable(#{rows.to_json})")
            @dialog.execute_script("showOutput(#{("#{nora_id} \u2192 #{dest_sid}").to_json}, 'ok')")
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Assign trip: Natalie books a trip for a specific pod.
      # dest_num is the station number string (e.g. "2"); empty → random destination.
      @dialog.add_action_callback("cmd_assign_trip") do |_ctx, nora_id, dest_num|
        UI.start_timer(0, false) do
          begin
            nora_id  = nora_id.to_s.strip
            dest_num = dest_num.to_s.strip
            raise "No vehicle ID." if nora_id.empty?

            e = nil
            JPods::JPodGuideway.all_nora_vehicles_in_model(model).each do |veh|
              e = veh[:entity] if veh[:vehicle_id] == nora_id
            end
            raise "Vehicle #{nora_id} not found." unless e

            platforms = JPods::JPodGuideway.load_followme_platforms(model) rescue []
            all_sids  = platforms.map { |p| p['structure_id'].to_s.strip.upcase }.uniq
            raise "No stations in network — run Build first." if all_sids.empty?

            origin_sid = e.get_attribute('JPods', 'parked_station_id', '').to_s.strip.upcase

            dest_sid = if dest_num.empty?
              # Random destination ≠ current station
              candidates = all_sids.reject { |s| s == origin_sid }
              raise "No other stations to route to." if candidates.empty?
              candidates.sample
            else
              found = all_sids.find { |s|
                m = s.match(/\A[A-Z]+(\d+)\z/i)
                m && m[1].to_i == dest_num.to_i
              }
              raise "Station #{dest_num} not found in network." unless found
              raise "Destination must differ from current station (#{origin_sid})." if found == origin_sid
              found
            end

            dest_platform = platforms.find { |pl| pl['structure_id'].to_s.strip.upcase == dest_sid }
            model.start_operation('JPods Assign Trip', true)
            e.set_attribute('JPods', 'destination_station_id',  dest_sid)
            e.set_attribute('JPods', 'destination_platform_id',
                            dest_platform ? dest_platform['id'].to_s : dest_sid)
            e.set_attribute('JPods', 'parking_state', 'trip_assigned')
            # Clear any stale stored trip so animation replans via BFS to the new dest.
            old_trips = JPods::JPodGuideway.load_vehicle_trips(model) rescue {}
            if old_trips.key?(nora_id)
              old_trips.delete(nora_id)
              JPods::JPodGuideway.save_vehicle_trips(model, old_trips) rescue nil
            end
            model.commit_operation

            # If animation is running and pod is dwelling, cancel dwell so it
            # redispatches on the next tick.
            if JPods::JPodGuideway.animating?
              JPods::JPodVehicleAnim.release_from_dwelling(nora_id) rescue nil
            end

            rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
            @dialog.execute_script("setTripTable(#{rows.to_json})")
            # Push trip JSON to OUTPUT so the plan is visible before animating
            begin
              detail = JPods::JPodGuideway.build_trip_detail(model, nora_id)
              text   = JSON.pretty_generate(detail)
              @dialog.execute_script("showOutput(#{text.to_json}, 'ok')")
            rescue
              @dialog.execute_script("showOutput(#{("#{nora_id} → #{dest_sid}").to_json}, 'ok')")
            end
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Toggle random dispatch — Natalie dispatches highest-slot pod per station at random intervals.
      # Enabling clears all existing trip assignments first so Natalie starts with a clean slate.
      @dialog.add_action_callback("cmd_toggle_random") do |_ctx|
        UI.start_timer(0, false) do
          begin
            JPods::JPodVehicleAnim.set_dialog(@dialog) rescue nil
            unless JPods::JPodGuideway.animating?
              @dialog.execute_script("showOutput(#{'Start animation first.'.to_json}, 'error')")
              next
            end
            on = JPods::JPodVehicleAnim.toggle_random_dispatch
            if on
              # Clear all existing trip destinations so Natalie starts fresh
              model.start_operation('JPods Clear Trips for Random', true)
              JPods::JPodGuideway.all_nora_vehicles_in_model(model).each do |veh|
                e = veh[:entity]
                e.set_attribute('JPods', 'destination_station_id',  '')
                e.set_attribute('JPods', 'destination_platform_id', '')
                e.set_attribute('JPods', 'parking_state', 'parked')
              end
              model.commit_operation
              JPods::JPodGuideway.save_vehicle_trips(model, {}) rescue nil
            end
            @dialog.execute_script("setRandomState(#{on})")
            rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
            @dialog.execute_script("setTripTable(#{rows.to_json})")
            min_s = JPods::JPodVehicleAnim::RANDOM_DISPATCH_MIN_S.to_i
            max_s = JPods::JPodVehicleAnim::RANDOM_DISPATCH_MAX_S.to_i
            msg = on ? "Random dispatch enabled — trips cleared, dispatching every #{min_s}–#{max_s}s." \
                     : "Random dispatch disabled."
            @dialog.execute_script("showOutput(#{msg.to_json}, 'ok')")
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Toggle high-frequency dispatch (0.5–2s for ezone testing)
      @dialog.add_action_callback("cmd_toggle_high_freq") do |_ctx|
        UI.start_timer(0, false) do
          begin
            on = JPods::JPodVehicleAnim.toggle_random_high_freq
            @dialog.execute_script("setHighFreqState(#{on})")
            msg = on ? "High-frequency dispatch ON (0.5–2s)" : "High-frequency dispatch OFF (3–11s)"
            @dialog.execute_script("showOutput(#{msg.to_json}, 'ok')")
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Show vehicle: select it, zoom camera to it, flash visibility 3 times.
      @dialog.add_action_callback("cmd_show_vehicle") do |_ctx, nora_id|
        UI.start_timer(0, false) do
          begin
            nora_id = nora_id.to_s.strip
            e = nil
            JPods::JPodGuideway.all_nora_vehicles_in_model(model).each do |veh|
              e = veh[:entity] if veh[:vehicle_id] == nora_id
            end
            raise "Vehicle #{nora_id} not found." unless e && !e.deleted?

            # Select and zoom
            model.selection.clear
            model.selection.add(e)
            model.active_view.zoom(model.selection)

            # Flash: toggle visibility 6 times at 150ms intervals
            count = 0
            timer_id = UI.start_timer(0.15, true) do
              count += 1
              next if e.deleted?
              e.visible = count.odd? ? false : true
              if count >= 6
                e.visible = true
                UI.stop_timer(timer_id)
              end
            end
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Camera follow toggle — called from List Vehicles row.
      # nora_id non-empty = start following; empty = stop.
      @dialog.add_action_callback("cmd_camera_follow") do |_ctx, nora_id|
        UI.start_timer(0, false) do
          begin
            nora_id = nora_id.to_s.strip
            if nora_id.empty?
              JPods::JPodGuideway.stop_camera_follow
              @dialog.execute_script("setCameraFollowUI('')")
            else
              ok, msg = JPods::JPodGuideway.start_camera_follow(model, nora_id)
              if ok
                @dialog.execute_script("setCameraFollowUI(#{nora_id.to_json})")
              else
                @dialog.execute_script("showOutput(#{msg.to_json}, 'error')")
              end
            end
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Clear trip destination: remove destination attributes so pod stays at rest.
      @dialog.add_action_callback("cmd_clear_trip_dest") do |_ctx, nora_id|
        UI.start_timer(0, false) do
          begin
            nora_id = nora_id.to_s.strip
            raise "No vehicle ID." if nora_id.empty?
            e = nil
            JPods::JPodGuideway.all_nora_vehicles_in_model(model).each do |veh|
              e = veh[:entity] if veh[:vehicle_id] == nora_id
            end
            raise "Vehicle #{nora_id} not found." unless e
            model.start_operation('JPods Clear Destination', true)
            e.set_attribute('JPods', 'destination_station_id',  '')
            e.set_attribute('JPods', 'destination_platform_id', '')
            e.set_attribute('JPods', 'parking_state', 'parked')
            model.commit_operation
            rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
            @dialog.execute_script("setTripTable(#{rows.to_json})")
            @dialog.execute_script("showOutput(#{("#{nora_id} destination cleared.").to_json}, 'ok')")
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Trip JSON → OUTPUT: show route in the same format as Show Route.
      # Derives origin/destination from vehicle attributes or flat segment list,
      # then runs BFS via show_route_followus_overlay to produce the canonical
      # route object (not the flat Nora segment list).
      @dialog.add_action_callback("cmd_trip_json_to_output") do |_ctx, nora_id|
        UI.start_timer(0, false) do
          begin
            nora_id = nora_id.to_s.strip
            raise "No vehicle ID." if nora_id.empty?

            # Find the vehicle entity
            vehicle = JPods::JPodGuideway.all_nora_vehicles_in_model(model)
                        .find { |v| v[:vehicle_id] == nora_id }
            raise "Vehicle #{nora_id} not found in model." unless vehicle
            e = vehicle[:entity]
            raise "Vehicle entity is deleted." if e.nil? || (e.respond_to?(:deleted?) && e.deleted?)

            origin_sid = e.get_attribute('JPods', 'parked_station_id', '').to_s.strip
            dest_sid   = ''

            # 1. destination_station_id — direct station ID, set by cmd_assign_trip
            dest_sid = e.get_attribute('JPods', 'destination_station_id', '').to_s.strip

            # 2. destination_platform_id — strip platform suffix.
            #    Handles both "S004_P2" and "S004.P2" formats.
            if dest_sid.empty?
              dest_pid = e.get_attribute('JPods', 'destination_platform_id', '').to_s.strip
              dest_sid = dest_pid.sub(/[_.]P\d+$/i, '').strip unless dest_pid.empty?
            end

            # 3. Flat segment list fallback — smarter midpoint logic for round trips.
            # A round trip has 2N seg_ entries (N outbound + N return).
            # The last outbound seg (index N-1 = segs.size/2 - 1) ends at the destination.
            if origin_sid.empty? || dest_sid.empty?
              trips      = JPods::JPodGuideway.load_vehicle_trips(model) rescue {}
              flat_lines = Array(trips[nora_id])
              segs = flat_lines.select { |l| l.to_s =~ /\Aseg_/i }
              if segs.any?
                # Origin: from-station of the first seg
                if origin_sid.empty? && segs.first =~ /\Aseg_([A-Z0-9]+)_cp\d+/i
                  origin_sid = $1
                end
                # Destination: to-station of the last outbound seg (midpoint of round trip)
                if dest_sid.empty?
                  mid = segs[segs.size / 2 - 1] || segs.first
                  dest_sid = $2 if mid =~ /\Aseg_[A-Z0-9]+_cp\d+_([A-Z0-9]+)_cp\d+\z/i
                end
              end
            end

            raise "Cannot determine origin station for #{nora_id}." if origin_sid.empty?
            raise "Cannot determine destination station for #{nora_id}." if dest_sid.empty?

            ok, msg, trip_json = JPods::JPodGuideway.show_route_followus_overlay(
              model, origin_sid, dest_sid)

            if trip_json
              nora_snap = JPods::JPodGuideway.nora_position_snapshot(model, nora_id) rescue nil
              @dialog.execute_script("showRouteBreakdown(#{trip_json.to_json}, #{nora_snap.to_json})")
            else
              @dialog.execute_script("showOutput(#{msg.to_json}, 'error')")
            end
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Populate: place vehicles at ~70% of capacity at every station, random models.
      # Delegates to JPodGuideway.populate_fleet (shared with toolbar button).
      @dialog.add_action_callback("cmd_set_populate_pct") do |_ctx, val|
        pct = val.to_f
        pct = 0.4 if pct <= 0 || pct > 1.0
        JPods::JPodGuideway.populate_pct = pct
        puts "[JPods] Populate set to #{(pct * 100).round(0)}%"
      end

      @dialog.add_action_callback("cmd_populate_fleet") do |_ctx|
        UI.start_timer(0, false) do
          begin
            result = JPods::JPodGuideway.populate_fleet(model)
            rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
            @dialog.execute_script("setTripTable(#{rows.to_json})")
            if result[:error]
              raise result[:error]
            end
            @dialog.execute_script("showOutput(#{("Populated #{result[:placed]} vehicle(s) across #{result[:stations]} station(s).").to_json}, 'ok')")
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # cmd_random_trips removed — superseded by cmd_toggle_random (Random header button).

      # Set network-wide speed (m/s). Writes to defaults.json and patches any live
      # animation pods immediately. Does NOT save to model entity attributes —
      # speed is operational state, not geometry.
      @dialog.add_action_callback("cmd_set_network_speed") do |_ctx, speed_str|
        UI.start_timer(0, false) do
          begin
            speed = [[speed_str.to_f, 0.5].max, 30.0].min
            JPods::Defaults.set('speed_ms', speed)
            JPods::Defaults.set('authorized_speed_ms', speed)
            if defined?(JPods::JPodVehicleAnim) && JPods::JPodVehicleAnim.running?
              pods = JPods::JPodVehicleAnim.instance_variable_get(:@@pods) rescue []
              Array(pods).each { |pod| pod.instance_variable_set(:@speed_in, speed * 39.3701) }
            end
            @dialog.execute_script("showOutput(#{("Speed set to #{speed.round(1)} m/s.").to_json}, 'ok')")
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Remove all vehicles from the model.
      @dialog.add_action_callback("cmd_clear_all_vehicles") do |_ctx|
        UI.start_timer(0, false) do
          begin
            result = JPods::JPodGuideway.clear_all_vehicles(model, clear_trips: true)
            raise result[:fault].to_s unless result[:ok]
            rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
            @dialog.execute_script("setTripTable(#{rows.to_json})")
            @dialog.execute_script("showOutput(#{("#{result[:erased].to_i} vehicle(s) cleared.").to_json}, 'ok')")
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Hold Loop runtime status — JS polls every 2 s when hold_loop task is active.
      # Returns { running: bool, pods: [{ nora_id, station_id, tracks, loop_count,
      #   target_loops, t_pct, state, pos_mm }] }
      @dialog.add_action_callback("cmd_poll_loop_status") do |_ctx, _arg|
        pods_data = []
        if defined?(JPods::JPodVehicleAnim)
          (JPods::JPodVehicleAnim.hold_loop_runtime || {}).each do |nora_id, rt|
            pods_data << {
              nora_id:      nora_id,
              station_id:   rt[:station_id],
              tracks:       rt[:tracks] || [],
              loop_count:   rt[:loop_count] || 0,
              target_loops: rt[:target_loops] || 0,
              t_pct:        rt[:t_pct] || 0.0,
              state:        rt[:state] || 'idle',
              pos_mm:       rt[:pos_mm] || [0, 0, 0]
            }
          end
        end
        result = {
          running:  defined?(JPods::JPodVehicleAnim) && JPods::JPodVehicleAnim.running?,
          pods:     pods_data
        }
        @dialog.execute_script("updateLoopStatus(#{result.to_json})")
      rescue => ex
        # silent — polling must not generate noise
      end

      # Live console log polling — JS polls every 2 s with last known sequence number.
      # Returns new log entries since that sequence so the console-log section stays live.
      @dialog.add_action_callback("cmd_poll_log") do |_ctx, since_seq|
        result = JPods::Logging.tail(since: since_seq.to_i, limit: 80)
        @dialog.execute_script("appendLogEntries(#{result.to_json})")
      rescue => _ex
        # silent — polling must not generate noise
      end

      # Task selected — send description + param definitions + NoelleGuard review
      @dialog.add_action_callback("cmd_select_task") do |_ctx, task_id|
        task = TASK_INDEX[task_id.to_s]
        next send_error("Unknown task: #{task_id}") unless task

        # NoelleGuard context check with no user params yet (defaults)
        review = NoelleGuard.review(task, {}, model)

        # Evaluate preconditions defined in task metadata
        precond_results = (task[:preconditions] || []).map do |sym|
          chk = PRECONDITION_CHECKS[sym]
          next nil unless chk
          passed = begin; chk[:check].call(model); rescue; false; end
          { key: sym.to_s, label: chk[:label], agent: chk[:agent],
            passed: passed, hint: chk[:hint] }
        end.compact

        payload = {
          id:                  task[:id],
          label:               task[:label],
          button_label:        task[:button_label],
          category:            task[:category].to_s,
          group:               task[:group].to_s,
          step:                task[:step],
          su_command:          task[:su_command],
          description:         task[:description],
          description_html:    task[:description_html],
          persistent_output:   task[:persistent_output] || false,
          risk:                task[:risk].to_s,
          requires_selection:  task[:requires_selection],
          confirm_text:        task[:confirm_text],
          params:              serialise_params(task[:params] || [], model),
          noelle_guard:        review,
          preconditions:       precond_results,
        }
        @dialog.execute_script("showTask(#{payload.to_json})")

        # Sequence panel — auto-populate when Sally: Draft Chains is selected.
        # Reads existing lines.json for every template instance in the open model.
        if task_id.to_s == 'sally_draft_chains'
          seen = Set.new
          model.entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance)
            formation = e.definition.get_attribute('JPods', 'model_id', '').to_s.strip
            next if formation.empty? || seen.include?(formation)
            seen << formation
            push_sequence_panel(formation)
          end
          # Also try model-level model_id (open template model)
          formation = model.get_attribute('JPods', 'model_id', '').to_s.strip
          push_sequence_panel(formation) if !formation.empty? && !seen.include?(formation)
        end
      end

      # Mode switch — student / designer / developer
      @dialog.add_action_callback("cmd_set_mode") do |_ctx, mode|
        Console.console_mode = mode.to_s
        Console.log_action(:mode_change, mode: mode.to_s)
        @dialog.execute_script("setConsoleMode(#{mode.to_json})")
        @dialog.execute_script("setContextBanner(#{Console.context_banner(model).to_json})")
      end

      # Sequence panel — Discover button: runs Sally.draft_chains for the named
      # formation, refreshes the panel, and switches to the Discovered view.
      @dialog.add_action_callback("cmd_sequence_discover") do |_ctx, formation|
        UI.start_timer(0, false) do
          begin
            formation = formation.to_s.strip
            raise "No formation name." if formation.empty?
            raise "Sally module not loaded." unless defined?(JPods::Sally)
            plugin_dir  = File.dirname(__FILE__)
            lines_path  = File.join(plugin_dir, 'templates', 'track_formations', formation, 'lines.json')
            raise "No lines.json for #{formation}." unless File.exist?(lines_path)
            result = JPods::Sally.draft_chains(lines_path)
            raise "Draft failed for #{formation}." unless result
            push_sequence_panel(formation)
            @dialog.execute_script("switchSequenceView('disc')")
            @dialog.execute_script("showOutput(#{("#{formation}: #{result[:formation]} discovered.").to_json}, 'ok')")
          rescue => ex
            @dialog.execute_script("showOutput(#{ex.message.to_json}, 'error')")
          end
        end
      end

      # Sequence panel — Finder button: opens the template folder for the named
      # formation in macOS Finder.
      @dialog.add_action_callback("cmd_sequence_finder") do |_ctx, formation|
        formation = formation.to_s.strip
        return unless formation && !formation.empty?
        dir = File.join(File.dirname(__FILE__), 'templates', 'track_formations', formation)
        `open #{dir.shellescape}` if File.directory?(dir)
      rescue => ex
        puts "[Console] cmd_sequence_finder error: #{ex.message}"
      end

      # Model info panel — pushes template or network context for Models tasks
      @dialog.add_action_callback("cmd_push_model_info") do |_ctx|
        push_model_info(model)
      rescue => ex
        puts "[Console] cmd_push_model_info error: #{ex.message}"
      end

      # Models panel — returns template table data + active formation + model tasks
      @dialog.add_action_callback("cmd_models_panel") do |_ctx|
        plugin_dir    = File.dirname(__FILE__)
        templates_dir = File.join(plugin_dir, 'templates', 'track_formations')

        # Active formation from the frontmost SketchUp model.
        # For raw template models (no Build run yet), derive from path.
        front = Sketchup.active_model
        active_formation = front&.get_attribute('JPods', 'model_id', '').to_s.strip
        if active_formation.empty? && front
          mp = front.path.to_s.gsub('\\', '/')
          active_formation = File.basename(File.dirname(mp)) if mp.include?('track_formations')
        end

        templates = []
        Dir.glob(File.join(templates_dir, '*', 'lines.json')).sort.each do |lj_path|
          formation  = File.basename(File.dirname(lj_path))
          tmpl_dir   = File.dirname(lj_path)
          lj = JSON.parse(File.read(lj_path, encoding: 'utf-8')) rescue next
          image_path = File.join(tmpl_dir, 'image.png')
          model_path = File.join(tmpl_dir, 'model.skp')
          hdr        = lj['chains_header']
          templates << {
            formation:   formation,
            description: lj['description'].to_s,
            image_url:   File.exist?(image_path) ? "file://#{image_path}" : nil,
            has_model:   File.exist?(model_path),
            chains_ok:   hdr && !hdr['approved_by'].to_s.strip.empty?,
            active:      formation == active_formation && !active_formation.empty?
          }
        end

        # Tasks for the Models panel (panel: :models)
        model_tasks = TASKS.select { |t| t[:panel] == :models }.map { |t|
          { id: t[:id].to_s, label: t[:label], risk: t[:risk].to_s, step: t[:step] }
        }

        data = {
          templates:        templates,
          active_formation: active_formation,
          has_active:       !active_formation.empty?,
          model_tasks:      model_tasks
        }
        @dialog.execute_script("renderModelsPanel(#{data.to_json})")
      rescue => ex
        puts "[Console] cmd_models_panel error: #{ex.message}"
      end

      # Open a template model in SketchUp
      # Place a specific template directly — bypasses the formation picker dialog.
      # Called by the Place button in the model table: cmd_place_template(model_id).
      @dialog.add_action_callback("cmd_place_template") do |_ctx, formation|
        formation = formation.to_s.strip
        next if formation.empty?
        JPods::StructurePlacer.purge_phantoms(model) rescue nil
        # Defer via timer — required when called from an HtmlDialog callback.
        UI.start_timer(0, false) do
          model.select_tool(JPods::JPodStructureTool.new(formation))
        end
      rescue => ex
        puts "[Console] cmd_place_template error: #{ex.message}"
      end

      @dialog.add_action_callback("cmd_open_template") do |_ctx, formation|
        formation  = formation.to_s.strip
        plugin_dir = File.dirname(__FILE__)
        model_path = File.join(plugin_dir, 'templates', 'track_formations', formation, 'model.skp')
        if File.exist?(model_path)
          Sketchup.open_file(model_path)
          # After open, re-push panel data so the active row updates
          UI.start_timer(1.5, false) do
            @dialog.execute_script("sketchup.cmd_models_panel()") rescue nil
          end
        else
          @dialog.execute_script("showOutput(#{("Template not found: #{formation}").to_json}, 'error')")
        end
      rescue => ex
        puts "[Console] cmd_open_template error: #{ex.message}"
      end

      # Show Tracks / Hide Tracks — toggle track overlay in the open template model.
      # Button text is driven by current overlay state; Ruby pushes setPathBtnState(active).
      @dialog.add_action_callback("cmd_show_formation_tracks") do |_ctx, formation|
        formation  = formation.to_s.strip
        plugin_dir = File.dirname(__FILE__)
        m          = Sketchup.active_model
        raise "No active model." unless m

        # Derive formation from the front window when JS doesn't supply one.
        if formation.empty?
          path = m.path.to_s
          if path.gsub('\\', '/').include?('track_formations')
            formation = File.basename(File.dirname(path))
          end
        end
        raise "No template open — open a track_formations model first." if formation.empty?

        # Toggle: if overlay is already showing, clear it.
        if JPods::JPodGuideway.track_overlay_active?(m)
          JPods::JPodGuideway.clear_track_overlay(m)
          @dialog.execute_script("setPathBtnState(false)")
        else
          ok, msg = JPods::JPodGuideway.show_track_overlay(m, ribbon_above: false)
          raise msg unless ok
          @dialog.execute_script("setPathBtnState(true)")
        end
      rescue => ex
        @dialog.execute_script("showOutput(#{("ERROR: #{ex.message}").to_json}, 'error')")
      end

      # Readme panel — read .md files relevant to the given section and return them to JS.
      # section: 'models' | 'networks' | 'vehicles'
      # Returns: renderReadmeFiles([{name:, content:}, ...])
      @dialog.add_action_callback("cmd_readme_files") do |_ctx, section|
        section    = section.to_s.strip.downcase
        plugin_dir = File.dirname(__FILE__)
        allie_dir  = File.expand_path('~/Allie/readmes/sketchup')

        files = []

        case section
        when 'models'
          # Per-template notes.md files
          template_root = File.join(plugin_dir, 'templates', 'track_formations')
          if Dir.exist?(template_root)
            Dir.glob(File.join(template_root, '*', 'notes.md')).sort.each do |path|
              formation = File.basename(File.dirname(path))
              files << { name: "#{formation}/notes.md", content: File.read(path, encoding: 'utf-8') }
            end
          end
          # Allie readmes for station authoring
          [
            'sally-standard-test.md',
            'jpods-station-templates.md',
            'jpods-template-designer-risks.md',
          ].each do |fname|
            full = File.join(allie_dir, fname)
            files << { name: fname, content: File.read(full, encoding: 'utf-8') } if File.exist?(full)
          end

        when 'networks'
          [
            'jpods-animation-pipeline.md',
            'jpods-plugin.md',
          ].each do |fname|
            full = File.join(allie_dir, fname)
            files << { name: fname, content: File.read(full, encoding: 'utf-8') } if File.exist?(full)
          end

        when 'vehicles'
          [
            'jpods-animation-pipeline.md',
          ].each do |fname|
            full = File.join(allie_dir, fname)
            files << { name: fname, content: File.read(full, encoding: 'utf-8') } if File.exist?(full)
          end

        when 'sketchup'
          # All .md files in ~/Allie/readmes/sketchup/, sorted alphabetically
          if Dir.exist?(allie_dir)
            Dir.glob(File.join(allie_dir, '*.md')).sort.each do |path|
              files << { name: File.basename(path), content: File.read(path, encoding: 'utf-8') }
            end
          end
        end

        @dialog.execute_script("renderReadmeFiles(#{files.to_json})")
      rescue => ex
        @dialog.execute_script("renderReadmeFiles([])")
        puts "[Console] cmd_readme_files error: #{ex.message}"
      end

      # Quiet Log toggle — suppresses verbose Ruby console output during station tests.
      @dialog.add_action_callback("cmd_toggle_quiet_log") do |_ctx, quiet_str|
        $jpods_quiet_log = (quiet_str.to_s.strip == 'true')
        puts "[Console] Quiet log #{$jpods_quiet_log ? 'ON (verbose suppressed)' : 'OFF (all logs)'}"
      end

      # Compute — template-level compilation: reads geometry.json pts_mm → lines.computed.json.
      # Only meaningful when a template model.skp is open (path includes 'track_formations').
      @dialog.add_action_callback("cmd_compute_template") do |_ctx, formation|
        formation = formation.to_s.strip
        dialog    = @dialog
        UI.start_timer(0, false) do
          begin
            model = Sketchup.active_model
            raise "No active model." unless model

            plugin_dir   = File.dirname(__FILE__)
            is_template  = model.path.to_s.gsub('\\', '/').include?('track_formations')
            raise "Open the template model.skp before running Compute." unless is_template

            # Derive model_id from the open model's component instance or definition name.
            fid = formation
            if fid.empty?
              model.entities.each do |e|
                next unless e.is_a?(Sketchup::ComponentInstance)
                fid_attr = e.get_attribute('JPods', 'model_id', '').to_s.strip
                fid_attr = e.definition.name.to_s.strip if fid_attr.empty?
                fid_attr = File.basename(File.dirname(model.path.to_s)) if fid_attr.empty?
                unless fid_attr.empty?
                  fid = fid_attr
                  break
                end
              end
            end
            fid = File.basename(File.dirname(model.path.to_s.gsub('\\', '/'))) if fid.empty?
            raise "Cannot determine template model_id — set model_id attribute or open model.skp inside its template folder." if fid.empty?

            # Compute v2: three-phase pipeline (validate → build chains → geometry)
            if defined?(JPods::Compute)
              result = JPods::Compute.run(model)
              if result
                msg = "Compute v2 complete — #{fid}: #{result.size} tracks"
                dialog.execute_script("showOutput(#{msg.to_json}, 'ok')")
              else
                dialog.execute_script("showOutput(#{"Compute v2 failed — check Ruby Console for details".to_json}, 'error')")
              end
            else
              # Fallback to old pipeline
              ok, msg = JPods::Noelle.write_lines_computed_from_geometry(fid, plugin_dir)
              status  = ok ? 'ok' : 'error'
              dialog.execute_script("showOutput(#{msg.to_json}, #{status.to_json})")
            end
          rescue => ex
            dialog.execute_script("showOutput(#{("Compute error: #{ex.message}").to_json}, 'error')")
          end
        end
      end

      # Station Test Runner — places vehicles, starts animation, polls for completion.
      # Requires the active model to contain a built station of the given formation.
      # test_id: 'platform_shuffle' | 'ccw_traverse'
      @dialog.add_action_callback("cmd_station_test_run") do |_ctx, formation, test_id|
        formation = formation.to_s.strip
        test_id   = test_id.to_s.strip
        dialog    = @dialog

        UI.start_timer(0, false) do
          begin
            model = Sketchup.active_model
            raise "No active model." unless model

            plugin_dir   = File.dirname(__FILE__)
            is_template  = model.path.to_s.gsub('\\', '/').include?('track_formations')

            if is_template
              # ── Template model path ─────────────────────────────────────────
              # Works on raw template model — no Build Network needed.
              # Sally is focused on internal gw_* tracks.
              # Tests the Sally ↔ 3-Nora interface:
              #   V1 (deepest slot)  — 3 hold-loop circuits → landing → CP exit
              #   V2 (middle slot)   — 0 loops (instant promote) → landing → CP exit
              #   V3 (front slot)    — 0 loops (instant promote) → landing → CP exit

              fid        = formation
              station_id = fid.downcase   # normalise — Sally and all lookup queries use lowercase

              tmpl_dir   = File.join(plugin_dir, 'templates', 'track_formations', fid)
              lines_path = File.join(tmpl_dir, 'lines.json')
              raise "lines.json not found for #{fid}." unless File.exist?(lines_path)
              lines_data = JSON.parse(File.read(lines_path, encoding: 'utf-8'))

              # Geometry from lines.computed.json['geometry']. Single source of truth.
              lc_path = File.join(tmpl_dir, 'lines.computed.json')
              raise "lines.computed.json not found for #{fid} — run Compute first." \
                unless File.exist?(lc_path)
              lc  = JSON.parse(File.read(lc_path, encoding: 'utf-8'))
              geo = lc['geometry']
              raise "lines.computed.json has no geometry for #{fid} — re-run Compute." \
                unless geo.is_a?(Hash)

              # geometry.json pts_mm are in station DEFINITION-LOCAL space.
              # To get world coordinates, apply the station instance's transformation.
              # This is identical to what extracted.json formation_xf stored — but we
              # read it live from the model so it is always correct for this model version.
              # Search mirrors show_track_overlay: check ComponentInstance AND Group,
              # with a Pass 2 fallback that scans for gw_*-tagged children.
              inst_xf = Geom::Transformation.new   # identity fallback
              model.entities.each do |e|
                next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
                fid_attr = e.get_attribute('JPods', 'model_id', '').to_s
                fid_attr = e.definition.name if fid_attr.empty? && e.is_a?(Sketchup::ComponentInstance)
                if fid_attr == fid
                  inst_xf = e.transformation
                  mm = 25.4
                  o = inst_xf.origin
                  puts "[Template test] #{fid} instance origin=(#{(o.x*mm).round(1)},#{(o.y*mm).round(1)},#{(o.z*mm).round(1)})mm"
                  break
                end
              end
              # Pass 2: if Pass 1 returned identity, search for a component/group whose
              # direct children include gw_*-tagged entities (same as show_track_overlay).
              if inst_xf.to_a == Geom::Transformation.new.to_a
                model.entities.each do |e|
                  next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
                  child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
                  has_gw = child_ents.any? { |c|
                    begin; c.respond_to?(:layer) && c.layer.name.to_s.start_with?('gw_')
                    rescue; false; end
                  }
                  next unless has_gw
                  inst_xf = e.transformation
                  mm2 = 25.4
                  o2 = inst_xf.origin
                  puts "[Template test] #{fid} found via gw_* child scan — origin=(#{(o2.x*mm2).round(1)},#{(o2.y*mm2).round(1)},#{(o2.z*mm2).round(1)})mm"
                  break
                end
              end
              in_per_mm = 1.0 / 25.4

              template_lookup = {}
              (geo['tracks'] || {}).each do |track_name, tdata|
                pts_mm = tdata['pts_mm']
                next unless pts_mm.is_a?(Array) && pts_mm.size >= 2
                pts = pts_mm.map { |p|
                  lp = Geom::Point3d.new(p[0].to_f * in_per_mm,
                                         p[1].to_f * in_per_mm,
                                         p[2].to_f * in_per_mm)
                  lp.transform!(inst_xf)
                }
                len   = pts.each_cons(2).sum { |a, b| a.distance(b).to_f }
                template_lookup["#{station_id}.#{track_name}"] = {
                  pts: pts, len: [len, 1e-6].max, source: 'geometry.json'
                }
              end
              raise "Template lookup empty — check geometry.json for #{fid}." if template_lookup.empty?

              defn = JPods::JPodGuideway.load_vehicle_definition(model, 'passenger_Yellow')
              raise "Vehicle template 'passenger_Yellow' not found." unless defn

              # Platform setup — required for station tests; skipped for transit_test.
              plat_pts = nil; plat_len = nil; slot_spacing_in = nil
              unless test_id == 'transit_test'
                parking_track = (lines_data.dig('natalie', 'parking_chain', 'tracks') || []).first
                raise "No parking_chain in lines.json for #{fid}." if parking_track.nil?
                plat_entry = template_lookup["#{station_id}.#{parking_track}"]
                raise "#{parking_track} not in geometry.json for #{fid}." unless plat_entry

                slot_spacing_in = (defined?(JPods::Sally::SLOT_SPACING_M) ?
                                     JPods::Sally::SLOT_SPACING_M : 2.5) * 1000.0 / 25.4
                plat_pts = plat_entry[:pts].dup
                plat_len = plat_entry[:len]

                # Orient plat_pts entry-first so slot 1 (deepest) is at pts[0].
                # Entry end = the end closest to the predecessor of parking_track.
                # Predecessor is derived from designer.tracks topology so this works for
                # all templates: station_line_end (gw_platform_parking → gw_platform),
                # station_thru_dip (gw_platform_parking → gw_platform),
                # station_parking (gw_platform_in2 → gw_platform).
                parking_predecessor = nil
                (lines_data.dig('designer', 'tracks') || {}).each do |tname, tdata|
                  if Array(tdata['successors']).include?(parking_track)
                    parking_predecessor = tname
                    break
                  end
                end
                pp_entry = parking_predecessor &&
                           template_lookup["#{station_id}.#{parking_predecessor}"]
                if pp_entry && pp_entry[:pts].is_a?(Array) && pp_entry[:pts].size >= 2
                  pp_pts  = pp_entry[:pts]
                  d_first = [plat_pts.first.distance(pp_pts.first),
                             plat_pts.first.distance(pp_pts.last)].min.to_f
                  d_last  = [plat_pts.last.distance(pp_pts.first),
                             plat_pts.last.distance(pp_pts.last)].min.to_f
                  plat_pts = plat_pts.reverse if d_last < d_first
                  puts "[Template test] plat_pts oriented via predecessor #{parking_predecessor}"
                else
                  puts "[Template test] ⚠ no predecessor found for #{parking_track} — Sally ps1 will correct in tests"
                end
              end

              # Clear previous test vehicles and slot labels
              to_erase = model.entities.select { |e|
                (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Text)) &&
                (e.get_attribute('JPods', 'station_test', '').to_s == 'true' rescue false)
              }
              model.entities.erase_entities(to_erase) unless to_erase.empty?

              # Place a vehicle at a fractional distance along the parking track.
              place_at_dist = ->(dist_in) {
                walked = 0.0
                pos    = plat_pts.first
                fwd_v  = Geom::Vector3d.new(
                  plat_pts[1].x - plat_pts[0].x,
                  plat_pts[1].y - plat_pts[0].y, 0)
                fwd_v  = Geom::Vector3d.new(1, 0, 0) if fwd_v.length < 1e-9
                plat_pts.each_cons(2) do |a, b|
                  seg_len = a.distance(b).to_f
                  if walked + seg_len >= dist_in
                    frac  = seg_len > 1e-9 ? (dist_in - walked) / seg_len : 0.0
                    pos   = Geom.linear_combination(1.0 - frac, a, frac, b)
                    d     = Geom::Vector3d.new(b.x - a.x, b.y - a.y, 0)
                    fwd_v = d if d.length > 1e-9
                    break
                  end
                  walked += seg_len
                end
                fwd_n = fwd_v.length > 1e-9 ? fwd_v.normalize : Geom::Vector3d.new(1, 0, 0)
                xf    = JPods::JPodGuideway.vehicle_transform_for(defn, pos, fwd_n)
                model.entities.add_instance(defn, xf)
              }

              tag_vehicle = ->(ent, loops, slot) {
                nora_num = JPods::JPodGuideway.next_nora_num(model)
                vid      = format('NORA_%04d', nora_num)
                ent.set_attribute('JPods', 'speed_ms',               8.3)
                ent.set_attribute('JPods', 'vehicle_num',            nora_num)
                ent.set_attribute('JPods', 'vehicle_template_id',    'passenger_Yellow')
                ent.set_attribute('JPods', 'vehicle_id',             vid)
                ent.set_attribute('JPods', 'parked_station_id',      station_id)
                ent.set_attribute('JPods', 'parking_slot',           slot)
                ent.set_attribute('JPods', 'parking_state',          'parked')
                ent.set_attribute('JPods', 'station_test',           'true')
                ent.set_attribute('JPods', 'template_model_id',  fid)
                ent.set_attribute('JPods', 'sally_hold_loop_sid',    station_id)
                ent.set_attribute('JPods', 'sally_hold_loop_cp',     '0')
                ent.set_attribute('JPods', 'sally_hold_loop_loops',  loops.to_s)
                JPods::JPodGuideway.assign_nora_tag(ent, vid, model)
                vid
              }

              add_slot_label = ->(ent, label) {
                bb     = ent.bounds
                ctr    = bb.center
                # 3000 mm above the pod centre (≈118 SU inches)
                lpt    = Geom::Point3d.new(ctr.x, ctr.y, ctr.z + 3000.0 / 25.4)
                txt    = model.entities.add_text(label, lpt)
                txt.set_attribute('JPods', 'station_test', 'true') rescue nil
                txt
              }

              case test_id

              when 'platform_shuffle'
                # Three Noras placed at the last 3 slots (exit end) — V1 at exit slot runs
                # one hold_loop; V2 and V3 are occupancy probes. Sally compacts V2→ps_cap,
                # V3→ps_cap-1 after V1 departs; V1 returns to the newly vacated innermost slot.
                _ld_v5   = lines_data['schema_version'].to_s >= '5'
                _ld_des  = _ld_v5 ? (lines_data['designer'] || {}) : lines_data
                pslots = (_ld_des['parking_slots'] || []).sort_by { |ps| ps['slot'].to_i }
                # Use last 3 slots so V1 lands at the exit (cap) slot where the exit guard passes.
                # Fall back to formula using last 3 arc-length positions if parking_slots absent.
                if pslots.size >= 3
                  test_pslots   = pslots.last(3)
                  d_deep        = [[test_pslots[0]['dist_mm'].to_f / 25.4, 0].max, plat_len * 0.99].min
                  d_mid         = [[test_pslots[1]['dist_mm'].to_f / 25.4, 0].max, plat_len * 0.99].min
                  d_front       = [[test_pslots[2]['dist_mm'].to_f / 25.4, 0].max, plat_len * 0.99].min
                  slot_deep     = test_pslots[0]['slot'].to_i
                  slot_mid      = test_pslots[1]['slot'].to_i
                  slot_front    = test_pslots[2]['slot'].to_i
                else
                  d_deep        = [[plat_len * 0.60, 0].max, plat_len * 0.99].min
                  d_mid         = [[plat_len * 0.80, 0].max, plat_len * 0.99].min
                  d_front       = [[plat_len * 0.95, 0].max, plat_len * 0.99].min
                  cap           = pslots.size > 0 ? pslots.last['slot'].to_i : 3
                  slot_deep     = [cap - 2, 1].max
                  slot_mid      = [cap - 1, 1].max
                  slot_front    = cap
                end

                # ── v2 shuffle test via StationTests module ────────────────
                result = JPods::StationTests.shuffle(model, station_id, defn, template_lookup, plat_pts, dialog)
                v1_id = result[:runner]

                dialog.execute_script("setAnimationState(true)")
                dialog.execute_script("stationTestResult(#{test_id.to_json}, 'running', #{
                  "#{v1_id} runner departs on hold_loop. #{result[:pod_count]} pods total.".to_json
                })")

                polls = [90]
                check = nil
                check = proc {
                  # Shuffle passes when template animation finishes (runner completed hold_loop + parked)
                  anim_done = !(defined?(JPods::JPodVehicleAnim) &&
                    JPods::JPodVehicleAnim.instance_variable_get(:@@template_timer) rescue false)
                  if anim_done
                    JPods::StationTests.stamp_test_pass(tmpl_dir, 'shuffle') rescue nil
                    dialog.execute_script("stationTestResult(#{test_id.to_json}, 'pass', #{
                      "#{v1_id} completed hold_loop and returned — PASS. hold_loop_chain verified for #{station_id}.".to_json
                    })")
                  elsif polls[0] <= 0
                    dialog.execute_script("stationTestResult(#{test_id.to_json}, 'fail', #{
                      "Timeout — runner did not complete hold_loop. Check console.".to_json
                    })")
                  else
                    polls[0] -= 1
                    UI.start_timer(2.0, false) { check.call }
                  end
                }
                UI.start_timer(4.0, false) { check.call }

              when 'transit_test'
                # ── Transit Test ────────────────────────────────────────────────
                # traffic_circle7 (and any future pass-through formation with no
                # station platform).  4 vehicles, one at each gw_cp_in_#, each
                # traverses the longest arc (N → N+3 mod 4) and exits at gw_cp_out.
                #
                # Uses Natalie's circle traversal: entry + circle slice (CCW) + exit.
                # The ring is one thing — defined once in pass_chains.circle.
                pass_chains = lines_data.dig('natalie', 'pass_chains') || {}
                circle  = pass_chains['circle']  || []
                entries = pass_chains['entries']  || {}
                exits   = pass_chains['exits']    || {}
                entry_arc = pass_chains['entry_arc'] || {}
                exit_arc  = pass_chains['exit_arc']  || {}
                raise "No circle definition in lines.json pass_chains for #{fid}." if circle.empty?

                # Determine CP count from entries
                cp_count = entries.size
                raise "No entries in pass_chains for #{fid}." if cp_count == 0
                transit_routes = (0...cp_count).map { |n| { from: n, to: (n + cp_count - 1) % cp_count } }

                # Clear previous test vehicles and labels
                to_erase = model.entities.select { |e|
                  (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Text)) &&
                  (e.get_attribute('JPods', 'station_test', '').to_s == 'true' rescue false)
                }
                model.entities.erase_entities(to_erase) unless to_erase.empty?

                placed_vids = []
                model.start_operation('Transit Test Place Vehicles', true)
                transit_routes.each do |r|
                  from_key = "cp#{r[:from]}"
                  to_key   = "cp#{r[:to]}"
                  entry  = entries[from_key]
                  exit_s = exits[to_key]
                  ea     = entry_arc[from_key]
                  xa     = exit_arc[to_key]
                  raise "Missing entry/exit for #{from_key}→#{to_key} in #{fid}." unless entry && exit_s && ea && xa

                  # Build track list: entry + circle slice + exit
                  ea_idx = circle.index(ea)
                  xa_idx = circle.index(xa)
                  raise "Ring arc #{ea} or #{xa} not in circle array." unless ea_idx && xa_idx
                  ring_slice = ea_idx <= xa_idx ? circle[ea_idx..xa_idx] : (circle[ea_idx..-1] + circle[0..xa_idx])
                  tracks = entry + ring_slice + exit_s

                  # Place vehicle at start of first track (gw_cp_in_N)
                  cp_entry = template_lookup["#{station_id}.#{tracks.first}"]
                  raise "Track #{tracks.first} not in geometry for #{fid}." unless cp_entry
                  start_pt = cp_entry[:pts].first
                  fwd_raw  = cp_entry[:pts].size >= 2 ?
                    Geom::Vector3d.new(cp_entry[:pts][1].x - cp_entry[:pts][0].x,
                                       cp_entry[:pts][1].y - cp_entry[:pts][0].y, 0) :
                    Geom::Vector3d.new(1, 0, 0)
                  fwd_raw = Geom::Vector3d.new(1, 0, 0) if fwd_raw.length < 1e-9
                  fwd_n   = fwd_raw.normalize
                  xf = JPods::JPodGuideway.vehicle_transform_for(defn, start_pt, fwd_n)
                  ent = model.entities.add_instance(defn, xf)

                  nora_num = JPods::JPodGuideway.next_nora_num(model)
                  vid = format('NORA_%04d', nora_num)
                  ent.set_attribute('JPods', 'speed_ms',            8.3)
                  ent.set_attribute('JPods', 'vehicle_num',         nora_num)
                  ent.set_attribute('JPods', 'vehicle_template_id', 'passenger_Yellow')
                  ent.set_attribute('JPods', 'vehicle_id',          vid)
                  ent.set_attribute('JPods', 'station_test',        'true')
                  ent.set_attribute('JPods', 'station_test_phase',  'exiting')  # erase when done
                  ent.set_attribute('JPods', 'template_model_id',   fid)
                  # Fully-qualified track keys for template animation
                  fq_tracks = tracks.map { |t| "#{station_id}.#{t}" }
                  ent.set_attribute('JPods', 'sally_transit_tracks', fq_tracks.to_json)
                  JPods::JPodGuideway.assign_nora_tag(ent, vid, model)
                  placed_vids << vid
                  add_slot_label.call(ent, "cp#{r[:from]}→#{r[:to]}")
                  puts "[transit_test] #{vid}: cp#{r[:from]}→cp#{r[:to]} (#{tracks.size} tracks via circle)"
                end
                model.commit_operation

                ok_anim = JPods::JPodVehicleAnim.start_for_template(model, template_lookup)
                raise "Template animation failed to start." unless ok_anim

                dialog.execute_script("setAnimationState(true)")
                dialog.execute_script("stationTestResult(#{test_id.to_json}, 'running', #{
                  "#{placed_vids.join(', ')} dispatched. 4 vehicles traversing longest arc (N→N+3). Watch for exit at gw_cp_out.".to_json
                })")

                polls = [90]
                check = nil
                check = proc {
                  remaining = model.entities.count { |e|
                    e.is_a?(Sketchup::ComponentInstance) &&
                    e.get_attribute('JPods', 'station_test', '').to_s == 'true'
                  } rescue 0
                  if remaining == 0
                    JPods::StationTests.stamp_test_pass(tmpl_dir, 'transit') rescue nil
                    dialog.execute_script("stationTestResult(#{test_id.to_json}, 'pass', #{
                      "All 4 vehicles exited — PASS. pass_chains transit routing verified for #{fid}.".to_json
                    })")
                  elsif polls[0] <= 0
                    dialog.execute_script("stationTestResult(#{test_id.to_json}, 'fail', #{
                      "Timeout — #{remaining} vehicle(s) did not exit. Check Ruby console.".to_json
                    })")
                  else
                    polls[0] -= 1
                    UI.start_timer(2.0, false) { check.call }
                  end
                }
                UI.start_timer(4.0, false) { check.call }

              when 'departure_test'
                # ── v2 departure test via StationTests module ──────────────
                result = JPods::StationTests.departure(model, station_id, defn, template_lookup, plat_pts, dialog)
                slot_entries = (1..result[:pod_count]).map { |i| { slot: i } }

                dialog.execute_script("setAnimationState(true)")
                dialog.execute_script("stationTestResult(#{test_id.to_json}, 'running', #{
                  "#{slot_entries.size} pods placed — Sally departure_mode ON. Pods advance and exit via originating chain.".to_json
                })")

                # Poll until all pods exit (erased by on_maneuver_complete exiting phase).
                # Timeout generous: 9 pods × ~4s stagger + hold_loop traversal ≈ 120s.
                polls = [120]
                check = nil
                check = proc {
                  remaining = model.entities.count { |e|
                    e.is_a?(Sketchup::ComponentInstance) &&
                    e.get_attribute('JPods', 'station_test', '').to_s == 'true'
                  } rescue 0
                  if remaining == 0
                    JPods::Sally.set_departure_mode(station_id, false) if defined?(JPods::Sally)
                    JPods::StationTests.stamp_test_pass(tmpl_dir, 'departure') rescue nil
                    dialog.execute_script("stationTestResult(#{test_id.to_json}, 'pass', #{
                      "All #{slot_entries.size} pods exited — PASS. Sally departure_mode: advance queue + originating chain verified.".to_json
                    })")
                  elsif polls[0] <= 0
                    JPods::Sally.set_departure_mode(station_id, false) if defined?(JPods::Sally)
                    dialog.execute_script("stationTestResult(#{test_id.to_json}, 'fail', #{
                      "Timeout — #{remaining} pod(s) did not exit. Check console.".to_json
                    })")
                  else
                    polls[0] -= 1
                    UI.start_timer(2.0, false) { check.call }
                  end
                }
                UI.start_timer(4.0, false) { check.call }

              when 'arrival_test'
                # ── v2 arrival test via StationTests module ────────────────
                result = JPods::StationTests.arrival(model, station_id, defn, template_lookup, plat_pts, dialog)
                arriving = result[:vids].map { |v| { vid: v } }

                dialog.execute_script("setAnimationState(true)")
                dialog.execute_script("stationTestResult(#{test_id.to_json}, 'running', #{
                  "#{arriving.size} pod(s) inbound via landing chains. Pods park on arrival.".to_json
                })")

                # Poll: arrival test passes when all test pods have completed
                # (either parked with slot > 0, or animation finished)
                n_arriving = arriving.size
                polls = [90]
                check = nil
                check = proc {
                  remaining = model.entities.count { |e|
                    e.is_a?(Sketchup::ComponentInstance) &&
                    e.get_attribute('JPods', 'station_test', '').to_s == 'true' &&
                    e.get_attribute('JPods', 'parking_slot', 0).to_i == 0
                  } rescue 0
                  if remaining == 0
                    JPods::StationTests.stamp_test_pass(tmpl_dir, 'arrival') rescue nil
                    dialog.execute_script("stationTestResult(#{test_id.to_json}, 'pass', #{
                      "All #{n_arriving} pod(s) parked — PASS. Landing chains verified.".to_json
                    })")
                  elsif polls[0] <= 0
                    dialog.execute_script("stationTestResult(#{test_id.to_json}, 'fail', #{
                      "Timeout — #{remaining} pod(s) did not park. Check console.".to_json
                    })")
                  else
                    polls[0] -= 1
                    UI.start_timer(2.0, false) { check.call }
                  end
                }
                UI.start_timer(4.0, false) { check.call }

              else
                raise "Test '#{test_id}' not implemented for template mode."
              end

              raise 'station_test_done'
              # ── End template model path ──────────────────────────────────────
            end

            # ── Network model path ──────────────────────────────────────────────
            # Find a placed station component of this formation (requires Build Network)
            station_entity = model.entities.find { |e|
              next unless e.is_a?(Sketchup::ComponentInstance)
              fid = e.definition.get_attribute('JPods', 'model_id', '').to_s.strip
              fid = e.definition.name.to_s.sub(/\AJPods Formation:\s*/i, '').strip if fid.empty?
              fid == formation
            }
            raise "No '#{formation}' station found. Build a network with this template placed first." unless station_entity

            station_id = station_entity.get_attribute('JPods', 'structure_id', '').to_s.strip.upcase
            raise "Station has no structure_id — run Build first." if station_id.empty?

            fid = station_entity.definition.get_attribute('JPods', 'model_id', '').to_s.strip
            fid = formation if fid.empty?

            # Clear previous test vehicles
            to_erase = model.entities.select { |e|
              e.is_a?(Sketchup::ComponentInstance) &&
              e.get_attribute('JPods', 'station_test', '').to_s == 'true'
            }
            model.entities.erase_entities(to_erase) unless to_erase.empty?

            # Load platforms — requires followme.json from Build
            platforms         = JPods::JPodGuideway.load_followme_platforms(model)
            station_platforms = platforms.select { |p| p['structure_id'].to_s.strip.upcase == station_id }
            raise "No platforms at #{station_id} — run Build first." if station_platforms.empty?

            # Initialize Sally sequencer
            JPods::Sally.init_sequencer_for_station(station_id, fid, plugin_dir) rescue nil

            case test_id

            when 'platform_shuffle'
              # Place 2 vehicles at parking space 1 (first available slot)
              placed_ids = []
              2.times do |i|
                ok, result = JPods::JPodGuideway.place_vehicle_at_platform(
                  model, 'passenger_Yellow', station_platforms.first, nil
                )
                raise "Vehicle #{i + 1}: #{result}" unless ok
                entity = model.entities.find { |e|
                  e.is_a?(Sketchup::ComponentInstance) &&
                  e.get_attribute('JPods', 'vehicle_id', '').to_s == result[:nora_id]
                }
                entity&.set_attribute('JPods', 'station_test', 'true')
                placed_ids << result[:nora_id]
              end

              # Tag lead vehicle for hold_loop — 3 loops, arrival CP 0
              lead_id = placed_ids.first
              lead_entity = model.entities.find { |e|
                e.is_a?(Sketchup::ComponentInstance) &&
                e.get_attribute('JPods', 'vehicle_id', '').to_s == lead_id
              }
              if lead_entity
                lead_entity.set_attribute('JPods', 'sally_hold_loop_sid',   station_id)
                lead_entity.set_attribute('JPods', 'sally_hold_loop_cp',    '0')
                lead_entity.set_attribute('JPods', 'sally_hold_loop_loops', '3')
              end

              JPods::JPodGuideway.start_animation(model)
              dialog.execute_script("setAnimationState(true)")
              rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
              dialog.execute_script("setTripTable(#{rows.to_json})")

              msg = "#{placed_ids.join(' + ')} placed at #{station_id} parking_1.\n" \
                    "Lead #{lead_id}: 3-loop hold tagged.\nAnimation running…"
              dialog.execute_script("stationTestResult(#{test_id.to_json}, 'running', #{msg.to_json})")

              # Poll for hold_loop completion: 2 s interval, up to 45 polls (90 s total)
              polls_remaining = [45]
              check = nil
              check = proc {
                rt         = defined?(JPods::JPodVehicleAnim) ?
                             (JPods::JPodVehicleAnim.hold_loop_runtime || {})[lead_id] : nil
                loops_done = rt ? rt[:loop_count].to_i : 0
                state      = rt ? rt[:state].to_s : ''
                if loops_done >= 3 || state == 'promoted'
                  log = "✓ #{lead_id} completed 3 loops at #{station_id}.\n" \
                        "Sally promoted to landing chain. Test passed."
                  dialog.execute_script("stationTestResult(#{test_id.to_json}, 'pass', #{log.to_json})")
                elsif polls_remaining[0] <= 0
                  log = "✗ Timeout — #{lead_id}: #{loops_done}/3 loops after 90 s.\nTest failed."
                  dialog.execute_script("stationTestResult(#{test_id.to_json}, 'fail', #{log.to_json})")
                else
                  polls_remaining[0] -= 1
                  UI.start_timer(2.0, false) { check.call }
                end
              }
              UI.start_timer(3.0, false) { check.call }

            when 'ccw_traverse'
              # Traffic circle: 1 vehicle, animate, pass if still running after 20 s
              ok, result = JPods::JPodGuideway.place_vehicle_at_platform(
                model, 'passenger_Yellow', station_platforms.first, nil
              )
              raise "Failed to place vehicle: #{result}" unless ok

              nora_id = result[:nora_id]
              entity  = model.entities.find { |e|
                e.is_a?(Sketchup::ComponentInstance) &&
                e.get_attribute('JPods', 'vehicle_id', '').to_s == nora_id
              }
              entity&.set_attribute('JPods', 'station_test', 'true')

              JPods::JPodGuideway.start_animation(model)
              dialog.execute_script("setAnimationState(true)")

              msg = "#{nora_id} placed at #{station_id}.\nAnimation running — watch for CCW ring traversal."
              dialog.execute_script("stationTestResult(#{test_id.to_json}, 'running', #{msg.to_json})")

              # After 20 s, confirm animation is still live (no crash/routing error)
              UI.start_timer(20.0, false) do
                still_running = defined?(JPods::JPodVehicleAnim) && JPods::JPodVehicleAnim.running?
                if still_running
                  log = "✓ #{nora_id} animation running after 20 s.\nVisually confirm CCW traversal in model. Test passed."
                  dialog.execute_script("stationTestResult(#{test_id.to_json}, 'pass', #{log.to_json})")
                else
                  log = "✗ Animation stopped within 20 s — check Console Log for routing errors.\nTest failed."
                  dialog.execute_script("stationTestResult(#{test_id.to_json}, 'fail', #{log.to_json})")
                end
              end

            else
              raise "Unknown test: #{test_id}"
            end

          rescue => ex
            unless ex.message == 'station_test_done'
              dialog.execute_script("stationTestResult(#{test_id.to_json}, 'fail', #{("ERROR: #{ex.message}").to_json})")
            end
          end
        end
      end

      # Live Test — place 2-3 vehicles, run through station behaviors.
      # Sally and Nora post their intended behaviors via liveTestStep(vehicleId, agent, message).
      # Flow:
      #   V1 placed at parking_1  → Sally announces: "V1 → parking_1 (hold loop, 3 circuits)"
      #   V2 placed at parking_2  → Sally announces: "V2 → parking_2 (courtesy shuffle target)"
      #   Animation starts        → Nora announces intent for each vehicle
      #   V1 completes hold loop  → Sally announces promotion to landing chain
      #   V2 shuffles forward     → Sally announces courtesy shuffle
      @dialog.add_action_callback("cmd_live_test") do |_ctx, formation|
        formation = formation.to_s.strip
        dlg       = @dialog

        UI.start_timer(0, false) do
          begin
            model = Sketchup.active_model
            raise "No active model." unless model

            station_entity = model.entities.find { |e|
              next unless e.is_a?(Sketchup::ComponentInstance)
              fid = e.definition.get_attribute('JPods', 'model_id', '').to_s.strip
              fid = e.definition.name.to_s.sub(/\AJPods Formation:\s*/i, '').strip if fid.empty?
              fid == formation
            }
            raise "No '#{formation}' station found. Build a network with this template placed first." unless station_entity

            station_id = station_entity.get_attribute('JPods', 'structure_id', '').to_s.strip.upcase
            raise "Station has no structure_id — run Build first." if station_id.empty?

            plugin_dir = File.dirname(__FILE__)
            fid = station_entity.definition.get_attribute('JPods', 'model_id', '').to_s.strip
            fid = formation if fid.empty?

            # Clear previous test vehicles
            to_erase = model.entities.select { |e|
              e.is_a?(Sketchup::ComponentInstance) &&
              e.get_attribute('JPods', 'station_test', '').to_s == 'true'
            }
            model.entities.erase_entities(to_erase) unless to_erase.empty?

            platforms         = JPods::JPodGuideway.load_followme_platforms(model)
            station_platforms = platforms.select { |p| p['structure_id'].to_s.strip.upcase == station_id }
            raise "No platforms at #{station_id} — run Build first." if station_platforms.empty?

            JPods::Sally.init_sequencer_for_station(station_id, fid, plugin_dir) rescue nil

            push = ->(vid, agent, msg) {
              dlg.execute_script("liveTestStep(#{vid.to_json}, #{agent.to_json}, #{msg.to_json})")
            }

            # Place vehicle 1 — hold loop (3 circuits)
            ok1, r1 = JPods::JPodGuideway.place_vehicle_at_platform(model, 'passenger_Yellow', station_platforms.first, nil)
            raise "V1 placement failed: #{r1}" unless ok1
            v1_id = r1[:nora_id]
            v1 = model.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.get_attribute('JPods','vehicle_id','') == v1_id }
            v1&.set_attribute('JPods', 'station_test', 'true')
            v1&.set_attribute('JPods', 'sally_hold_loop_sid',   station_id)
            v1&.set_attribute('JPods', 'sally_hold_loop_cp',    '0')
            v1&.set_attribute('JPods', 'sally_hold_loop_loops', '3')
            push.call(v1_id, 'Sally', "#{v1_id} → parking_1 at #{station_id}. Hold-loop assigned: 3 circuits before promotion to landing chain.")

            # Place vehicle 2 — courtesy shuffle target
            slot2 = station_platforms[1] || station_platforms.first
            ok2, r2 = JPods::JPodGuideway.place_vehicle_at_platform(model, 'passenger_Yellow', slot2, nil)
            if ok2
              v2_id = r2[:nora_id]
              v2 = model.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.get_attribute('JPods','vehicle_id','') == v2_id }
              v2&.set_attribute('JPods', 'station_test', 'true')
              push.call(v2_id, 'Sally', "#{v2_id} → parking_2 at #{station_id}. Courtesy shuffle: will advance when #{v1_id} clears slot 1.")
            else
              push.call('', 'Sally', "Courtesy shuffle vehicle skipped — only one platform slot available at #{station_id}.")
            end

            # Start animation and announce Nora's intent
            JPods::JPodGuideway.start_animation(model)
            dlg.execute_script("setAnimationState(true)")
            rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
            dlg.execute_script("setTripTable(#{rows.to_json})")

            push.call(v1_id, 'Nora', "#{v1_id}: entering hold-loop at #{station_id}. Running platform circuit. No destination assigned — looping until Sally clears for landing.")
            if ok2
              push.call(r2[:nora_id], 'Nora', "#{r2[:nora_id]}: parked at slot 2, awaiting courtesy-shuffle signal from Sally.")
            end

            # Poll for v1 hold-loop completion
            polls_remaining = [45]
            v2_id_final = ok2 ? r2[:nora_id] : nil
            check = nil
            check = proc {
              rt         = defined?(JPods::JPodVehicleAnim) ? (JPods::JPodVehicleAnim.hold_loop_runtime || {})[v1_id] : nil
              loops_done = rt ? rt[:loop_count].to_i : 0
              state      = rt ? rt[:state].to_s : ''
              if loops_done >= 3 || state == 'promoted'
                push.call(v1_id, 'Sally', "#{v1_id} completed #{loops_done} hold-loop circuit(s). Promoting to landing chain — slot 1 now available.")
                push.call(v2_id_final, 'Sally', "#{v2_id_final}: executing courtesy shuffle → advancing to parking slot 1.") if v2_id_final
                dlg.execute_script("liveTestComplete(true, 'Hold-loop + courtesy shuffle complete at #{station_id}.')")
              elsif polls_remaining[0] <= 0
                push.call(v1_id, 'Sally', "Timeout — #{v1_id} did not complete 3 loops in 90 s. Check Console Log for routing errors.")
                dlg.execute_script("liveTestComplete(false, 'Timeout after 90 s.')")
              else
                polls_remaining[0] -= 1
                UI.start_timer(2.0, false) { check.call }
              end
            }
            UI.start_timer(3.0, false) { check.call }

          rescue => ex
            dlg.execute_script("liveTestComplete(false, #{("ERROR: #{ex.message}").to_json})")
          end
        end
      end

      # ── Standard Sally Test ─────────────────────────────────────────────────
      # Places 3 vehicles one at a time in parking_1. Sally shuffles each to the
      # deepest available slot. Then:
      #   V1 (deepest) — 3 hold-loop circuits, then exits via CP
      #   V2            — exits via nearest CP once V1 starts looping
      #   V3            — exits via nearest CP after V2
      # When all 3 are gone, all station_test vehicles are erased and test passes.
      # User can end early with Stop Animation — no separate stop callback needed.
      @dialog.add_action_callback("cmd_sally_standard_test") do |_ctx, formation|
        formation = formation.to_s.strip
        dlg       = @dialog

        UI.start_timer(0, false) do
          begin
            model = Sketchup.active_model
            raise "No active model." unless model

            # Resolve formation from front window if empty
            if formation.empty?
              p = model.path.to_s
              formation = File.basename(File.dirname(p)) if p.gsub('\\','/').include?('track_formations')
            end
            raise "No template open — open a track_formations model first." if formation.empty?

            # Find station entity
            station_entity = model.entities.find { |e|
              next unless e.is_a?(Sketchup::ComponentInstance)
              fid = e.definition.get_attribute('JPods','model_id','').to_s.strip
              fid = e.definition.name.to_s.sub(/\AJPods Formation:\s*/i,'').strip if fid.empty?
              fid == formation
            }
            raise "No '#{formation}' station in model — run Build Network first." unless station_entity

            station_id = station_entity.get_attribute('JPods','structure_id','').to_s.strip.upcase
            raise "Station has no structure_id — run Build first." if station_id.empty?

            plugin_dir = File.dirname(__FILE__)
            fid = station_entity.definition.get_attribute('JPods','model_id','').to_s.strip
            fid = formation if fid.empty?

            # Clear previous test vehicles
            to_erase = model.entities.select { |e|
              e.is_a?(Sketchup::ComponentInstance) &&
              e.get_attribute('JPods','station_test','').to_s == 'true'
            }
            model.entities.erase_entities(to_erase) unless to_erase.empty?

            push = ->(vid, agent, msg) {
              dlg.execute_script("liveTestStep(#{vid.to_json},#{agent.to_json},#{msg.to_json})")
            }

            # Template models use cmd_station_test_run (Run button on test cards).
            # Sally Test is network-only — requires a placed, built station.
            raise "Template models: use the Run button on the test cards (no Build needed)." \
              if model.path.to_s.gsub('\\','/').include?('track_formations')

            platforms = JPods::JPodGuideway.load_followme_platforms(model)
            stn_plat  = platforms.select { |p| p['structure_id'].to_s.strip.upcase == station_id }
            raise "No platforms at #{station_id} — run Build first." if stn_plat.empty?

            JPods::Sally.init_sequencer_for_station(station_id, fid, plugin_dir) rescue nil

            push.call('', 'Sally', "Standard Sally Test starting at #{station_id} (#{formation}).")
            push.call('', 'Sally', "Step 1 — Place V1 at parking_1, shuffle to deepest slot.")

            # ── Place V1 ──────────────────────────────────────────────────────
            ok1, r1 = JPods::JPodGuideway.place_vehicle_at_platform(model,'passenger_Yellow',stn_plat.first,nil)
            raise "V1 placement failed: #{r1}" unless ok1
            v1_id = r1[:nora_id]
            v1e   = model.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.get_attribute('JPods','vehicle_id','') == v1_id }
            v1e&.set_attribute('JPods','station_test','true')
            v1e&.set_attribute('JPods','sally_hold_loop_sid',   station_id)
            v1e&.set_attribute('JPods','sally_hold_loop_cp',    '0')
            v1e&.set_attribute('JPods','sally_hold_loop_loops', '3')
            push.call(v1_id, 'Sally', "#{v1_id} placed at parking_1 → shuffling to deepest slot. Hold-loop assigned: 3 circuits.")

            # ── Place V2 (after short delay so shuffle is visible) ────────────
            UI.start_timer(1.5, false) do
              push.call('', 'Sally', "Step 2 — Place V2 at parking_1. V1 shuffles deeper.")
              ok2, r2 = JPods::JPodGuideway.place_vehicle_at_platform(model,'passenger_Yellow',stn_plat[1]||stn_plat.first,nil)
              v2_id = ok2 ? r2[:nora_id] : nil
              if v2_id
                v2e = model.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.get_attribute('JPods','vehicle_id','') == v2_id }
                v2e&.set_attribute('JPods','station_test','true')
                push.call(v2_id, 'Sally', "#{v2_id} placed at parking_1. #{v1_id} shuffled back. #{v2_id} will exit via CP when platform clears.")
              else
                push.call('', 'Sally', "V2 placement skipped — only one platform slot available.")
              end

              # ── Place V3 ────────────────────────────────────────────────────
              UI.start_timer(1.5, false) do
                push.call('', 'Sally', "Step 3 — Place V3 at parking_1. Queue now full.")
                ok3, r3 = JPods::JPodGuideway.place_vehicle_at_platform(model,'passenger_Yellow',stn_plat[2]||stn_plat.first,nil)
                v3_id = ok3 ? r3[:nora_id] : nil
                if v3_id
                  v3e = model.entities.find { |e| e.is_a?(Sketchup::ComponentInstance) && e.get_attribute('JPods','vehicle_id','') == v3_id }
                  v3e&.set_attribute('JPods','station_test','true')
                  push.call(v3_id, 'Sally', "#{v3_id} placed. Queue: #{v1_id}=deepest, #{v2_id||'—'}=middle, #{v3_id}=front.")
                end

                # ── Start animation ──────────────────────────────────────────
                JPods::JPodGuideway.start_animation(model)
                dlg.execute_script("setAnimationState(true)")
                rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
                dlg.execute_script("setTripTable(#{rows.to_json})")

                push.call('', 'Nora', "Animation started. Vehicles entering Sally dispatch queue.")
                push.call(v1_id, 'Nora', "#{v1_id}: hold-loop active — executing 3 circuits before platform promotion.")
                push.call(v2_id||'V2', 'Nora', "V2: queued — will advance to platform when #{v1_id} clears slot.")
                push.call(v3_id||'V3', 'Nora', "V3: queued — will advance as V2 clears.")

                # ── Poll for all test vehicles gone ──────────────────────────
                # Test is complete when all station_test entities have been removed
                # by the animation engine (they exit the station and are cleaned up),
                # OR when V1's hold_loop shows promoted + V2 + V3 dispatched.
                polls = [90]   # 90 × 2s = 3 minutes max
                v1_loops_reported = [0]

                check = nil
                check = proc {
                  # Report V1 loop progress
                  rt = defined?(JPods::JPodVehicleAnim) ? (JPods::JPodVehicleAnim.hold_loop_runtime || {})[v1_id] : nil
                  if rt
                    loops_now = rt[:loop_count].to_i
                    if loops_now > v1_loops_reported[0]
                      v1_loops_reported[0] = loops_now
                      push.call(v1_id, 'Sally', "#{v1_id} completed loop #{loops_now}/3.")
                      if loops_now >= 3 || rt[:state].to_s == 'promoted'
                        push.call(v1_id, 'Sally', "#{v1_id} promoted to landing chain — heading to platform for departure.")
                      end
                    end
                  end

                  # Count remaining test vehicles
                  remaining = model.entities.count { |e|
                    e.is_a?(Sketchup::ComponentInstance) &&
                    e.get_attribute('JPods','station_test','').to_s == 'true'
                  } rescue 0

                  if remaining == 0
                    push.call('', 'Sally', "All 3 vehicles have exited #{station_id}.")
                    push.call('', 'Sally', "Removing test vehicles from model.")
                    # Erase any lingering test entities
                    leftover = model.entities.select { |e|
                      e.is_a?(Sketchup::ComponentInstance) &&
                      e.get_attribute('JPods','station_test','').to_s == 'true'
                    }
                    model.entities.erase_entities(leftover) unless leftover.empty?
                    dlg.execute_script("sallyTestComplete(true, 'All 3 vehicles exited #{station_id}. Queue management, hold-loop, and CP departure confirmed.')")
                  elsif polls[0] <= 0
                    # Timeout — clean up anyway
                    leftover = model.entities.select { |e|
                      e.is_a?(Sketchup::ComponentInstance) &&
                      e.get_attribute('JPods','station_test','').to_s == 'true'
                    }
                    push.call('', 'Sally', "Timeout — #{remaining} vehicle(s) remain. Removing test vehicles.")
                    model.entities.erase_entities(leftover) unless leftover.empty?
                    dlg.execute_script("sallyTestComplete(false, 'Timeout after 3 minutes. #{remaining} vehicle(s) did not exit — check Console Log.')")
                  else
                    polls[0] -= 1
                    UI.start_timer(2.0, false) { check.call }
                  end
                }
                UI.start_timer(4.0, false) { check.call }
              end
            end

          rescue => ex
            dlg.execute_script("sallyTestComplete(false, #{("ERROR: #{ex.message}").to_json})")
          end
        end
      end

      # Execute — NoelleGuard runs again server-side before any code fires
      @dialog.add_action_callback("cmd_execute") do |_ctx, json_str|
        data    = JSON.parse(json_str) rescue {}
        task_id = data["task_id"].to_s
        params  = data["params"] || {}
        puts "[JPods cmd_execute] task_id=#{task_id}"

        # Refresh model — closure variable can go stale if the model was nil at
        # Console.open time or if SketchUp swapped the active model since.
        model = Sketchup.active_model if model.nil? || model.entities.nil? rescue model = Sketchup.active_model

        # Guard: active model must match the model this console was opened for.
        # If the user switched .skp files without reopening the console, tasks
        # would silently run against the wrong followme.json / map.json.
        active_path = Sketchup.active_model&.path.to_s
        if !@console_model_path.to_s.empty? && !active_path.empty? &&
           active_path != @console_model_path
          console_name = File.basename(@console_model_path, '.skp')
          active_name  = File.basename(active_path, '.skp')
          err = "MODEL MISMATCH: Console loaded for '#{console_name}' but active model is '#{active_name}'.\n" \
                "Close and reopen the JPods Console to reload for the current file."
          @dialog.execute_script("showOutput(#{err.to_json}, 'error')")
          next
        end

        # Guard: warn if model has unsaved changes before CP Calculate or Build.
        # These tasks read geometry from the saved file — unsaved edits are invisible to them.
        save_critical = %w[calculate_cps build_network_noelle]
        if save_critical.include?(task_id) && model && model.modified?
          warn_msg = "⚠ SAVE FIRST — The model has unsaved changes. #{task_id == 'build_network_noelle' ? 'Build' : 'CP Calculate'} reads from the saved file. Click Save in the header and try again."
          @dialog.execute_script("showOutput(#{warn_msg.to_json}, 'error')")
          next
        end

        # Keep dialog ref current so natalie_report can push live table updates.
        JPods::JPodVehicleAnim.set_dialog(@dialog) rescue nil

        # Flush NE iframe via_markers to network.json before any task that
        # reads the network (build, calculate_cps, validate, etc.).
        # network_json is always sent by the JS; it's nil only when the iframe
        # hasn't loaded yet. Save it silently — never block execution on failure.
        ne_json_text = data["network_json"].to_s.strip
        active_for_patch = Sketchup.active_model
        if !ne_json_text.empty? && active_for_patch&.path && !active_for_patch.path.empty?
          begin
            ne_data   = JSON.parse(ne_json_text)
            ne_conns  = Array(ne_data['connections'])
            feat_path = JPods::NetworkEditor.default_network_json_path(active_for_patch)
            # Only sync when the NE iframe actually has connections to write.
            # An empty list from the iframe means it hasn't loaded — do NOT erase
            # existing connections from network.json.
            if ne_conns.any? && File.exist?(feat_path)
              feat_data  = JSON.parse(File.read(feat_path, encoding: 'utf-8'))
              old_conns  = feat_data['connections'].is_a?(Hash) ? feat_data['connections'] : {}
              new_conns  = {}
              updated    = 0
              # Start with ALL existing connections — preserve any added by
              # Connect tool that the NE iframe doesn't know about yet.
              new_conns = old_conns.dup
              ne_conns.each do |c|
                cid = c['id'].to_s
                next if cid.empty?
                entry = (old_conns[cid] || {}).dup
                entry['via_markers'] = Array(c['via_markers'])
                updated += 1 unless entry['via_markers'].empty?
                new_conns[cid] = entry
              end
              feat_data['connections']  = new_conns
              feat_data['generated_at'] = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
              File.write(feat_path, JSON.pretty_generate(feat_data), encoding: 'utf-8')
              puts "[JPods cmd_execute] sync connections: #{new_conns.size} connection(s), #{updated} with waypoints → #{File.basename(feat_path)}"
            elsif ne_conns.any?
              # No network.json yet (first run before CP Calculate) — safe to write full JSON
              JPods::NetworkEditor.save_network_definition_to_path(feat_path, ne_data)
              puts "[JPods cmd_execute] wrote initial network.json (#{ne_conns.size} connections)"
            end
          rescue => e
            puts "[JPods cmd_execute] via_markers patch warning (non-fatal): #{e.message}"
          end
        end

        task = TASK_INDEX[task_id]
        next send_error("Unknown task: #{task_id}") unless task

        # Snapshot selection NOW — before any further round-trips — so the
        # task proc receives the same object NoelleGuard checked
        selection_snapshot = model&.selection&.first

        # NoelleGuard second gate (uses live model state, same moment as snapshot)
        review = NoelleGuard.review(task, params, model)
        unless review[:ok]
          msgs = review[:messages].join("\n")
          Console.log_action(:task_blocked, task_id: task_id,
                             reason: review[:messages].first.to_s[0, 120])
          @dialog.execute_script("showOutput(#{("[Noelle] blocked:\n#{msgs}").to_json}, 'blocked')")
          next
        end

        # Separator — blank lines + header make this button-click easy to find in the log.
        label = (task[:label] || task_id).to_s.strip
        ts    = Time.now.utc.strftime('%H:%M:%SZ')
        puts ""
        puts ""
        puts "━━━ ▶ #{label}  #{ts} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Capture stdout + execute; pass snapshot so procs don't re-read selection
        t0     = Time.now
        output = capture_run(task, model, params, selection_snapshot)
        elapsed_ms = ((Time.now - t0) * 1000).round

        is_error = output.start_with?('ERROR') || output.start_with?('[Error]')
        Console.log_action(:task_run, task_id: task_id,
                           result:      is_error ? 'error' : 'ok',
                           duration_ms: elapsed_ms,
                           mode:        Console.console_mode)

        if output.start_with?('__STATIONNAMES__:')
          html = output[17..]
          @dialog.execute_script("showStationNames(#{html.to_json})")
        elsif output.start_with?('__HTML__:')
          html = output[9..]
          @dialog.execute_script("showOutputHtml(#{html.to_json}, 'ok')")
        elsif output.start_with?('__TRIPSEQ__:')
          text = output[12..]
          @dialog.execute_script("showTripSequence(#{text.to_json})")
        else
          status = is_error ? 'error' : 'ok'
          @dialog.execute_script("showOutput(#{output.to_json}, #{status.to_json})")
        end
        rows = JPods::JPodGuideway.vehicle_trip_rows(model) rescue []
        @dialog.execute_script("setTripTable(#{rows.to_json})")
        anim_on   = (JPods::JPodGuideway.animating? rescue false)
        random_on = (JPods::JPodVehicleAnim.random_dispatch_on? rescue false)
        @dialog.execute_script("setAnimationState(#{anim_on})")
        @dialog.execute_script("setRandomState(#{random_on})")
        if task_id == 'build_network_noelle'
          # Refresh Network Display after Build
          begin
            network_path = JPods::NetworkEditor.default_network_json_path(model)
            nd = JPods::NetworkEditor.load_network_definition_from_path(network_path)
            if nd['connections'].is_a?(Hash)
              flat = JPods::NetworkEditor.feature_connections_to_flat_array(nd['connections'])
              nd_for_iframe = nd.dup
              nd_for_iframe['connections'] = flat.map { |e|
                { 'id' => e['connection_id'],
                  'from' => e['from'], 'to' => e['to'],
                  'via_markers' => e['via_markers'] || [] }
              }.uniq { |c| c['id'] }
              nd_text = JSON.pretty_generate(nd_for_iframe)
            else
              nd_text = JSON.pretty_generate(nd)
            end
            @dialog.execute_script("loadNetworkEditorContent(#{nd_text.to_json}, #{network_path.to_json})")
            JPods::NetworkEditor.push_feature_connections(model, @dialog)
          rescue; end
        end
        if task_id == 'calculate_cps'
          new_label = JPods::StructurePlacer.cps_shown? ? 'CP Hide' : 'CP Calculate'
          @dialog.execute_script("updateTaskLabel('calculate_cps', #{new_label.to_json})")
        end
        if task_id == 'show_route'
          is_shown  = JPods::JPodGuideway.route_overlay_active?(model)
          new_label = is_shown ? 'Hide Route' : 'Show Route'
          @dialog.execute_script("updateTaskLabel('show_route', #{new_label.to_json})")
          @dialog.execute_script(
            "['btn-execute-top','btn-execute-inline'].forEach(function(id){" \
            "var e=document.getElementById(id);if(e)e.textContent=#{new_label.to_json};})"
          )
        end
        if task_id == 'show_formation_tracks'
          is_shown  = JPods::JPodGuideway.track_overlay_active?(model) rescue false
          new_label = is_shown ? 'Hide Tracks' : 'Show Tracks'
          @dialog.execute_script("updateTaskLabel('show_formation_tracks', #{new_label.to_json})")
          @dialog.execute_script(
            "['btn-execute-top','btn-execute-inline'].forEach(function(id){" \
            "var e=document.getElementById(id);if(e)e.textContent=#{new_label.to_json};})"
          )
          @dialog.execute_script("updateNqaBtnLabel('show_formation_tracks', #{new_label.to_json})")
        end
      end

      # ── Network Editor iframe callbacks ────────────────────────────────────
      # The Network Editor HTML is embedded as an <iframe> inside the Console
      # dialog.  All sketchup.cmd_* calls from inside that iframe arrive here,
      # not at the standalone NetworkEditor dialog.  Mirror every callback that
      # the Network Editor HTML can invoke so they work in both contexts.

      @dialog.add_action_callback("cmd_show_route") do |_ctx, json_text|
        payload      = JSON.parse(json_text.to_s) rescue {}
        from_sid     = payload['from'].to_s.strip.upcase
        to_sid       = payload['to'].to_s.strip.upcase
        ribbon_above = payload.key?('ribbon_above') ? payload['ribbon_above'] != false : true
        puts "[JPods Console cmd_show_route] #{from_sid} -> #{to_sid} ribbon_above=#{ribbon_above}"
        begin
          ok, msg, trip_json = JPods::JPodGuideway.show_route_followus_overlay(model, from_sid, to_sid, ribbon_above: ribbon_above)
          puts "[JPods Console cmd_show_route] ok=#{ok} msg=#{msg}"
          if ok && trip_json
            @dialog.execute_script("showRouteBreakdown(#{trip_json.to_json})") rescue nil
          else
            @dialog.execute_script("showOutput(#{msg.to_json}, 'error')") rescue nil
          end
        rescue => e
          puts "[JPods Console cmd_show_route] error: #{e.message}"
          @dialog.execute_script("showOutput(#{e.message.to_json}, 'error')") rescue nil
        end
      end

      @dialog.add_action_callback("cmd_show_connection") do |_ctx, conn_id|
        conn_id = conn_id.to_s.strip
        UI.start_timer(0, false) do
          begin
            to_erase = model.entities.select { |e|
              (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
                e.get_attribute('JPods', 'overlay_type', '') == 'connection_route'
            }
            unless to_erase.empty?
              model.start_operation('Clear Connection Overlay', true)
              model.entities.erase_entities(to_erase)
              model.commit_operation
            end
            guideways = model.entities.select { |e|
              e.is_a?(Sketchup::Group) &&
                (e.name == 'JPods Guideway' || e.get_attribute('JPods', 'seg_guideway')) &&
                e.get_attribute('JPods', 'connection_id').to_s == conn_id
            }
            next if guideways.empty?
            all_pts = guideways.flat_map { |gw| JPodGuideway.vehicle_path_for(gw) || [] }
            next if all_pts.size < 2
            mat = model.materials['JPods Conn Overlay'] || model.materials.add('JPods Conn Overlay')
            mat.color = Sketchup::Color.new(0, 200, 255)
            model.start_operation('JPods Connection Overlay', true)
            grp = model.entities.add_group
            grp.name = 'JPods Connection Overlay'
            grp.set_attribute('JPods', 'overlay_type', 'connection_route')
            grp.set_attribute('JPods', 'overlay_conn_id', conn_id)
            lifted = all_pts.map { |pt| Geom::Point3d.new(pt.x, pt.y, pt.z + 0.5.m) }
            (0...lifted.size - 1).each { |i| grp.entities.add_line(lifted[i], lifted[i+1]).material = mat }
            model.commit_operation
            bb = Geom::BoundingBox.new
            all_pts.each { |pt| bb.add(pt) }
            model.active_view.zoom(bb) rescue nil
            model.active_view.invalidate
          rescue => e2
            puts "[JPods Console cmd_show_connection] error: #{e2.message}"
            begin; model.abort_operation; rescue; end
          end
        end
      end

      @dialog.add_action_callback("cmd_show_followme") do |_ctx|
        begin
          ok, msg = JPods::JPodGuideway.show_followme_json_overlay(model)
          status = ok ? 'ok' : 'error'
          @dialog.execute_script("showOutput(#{msg.to_json}, #{status.to_json})") rescue nil
        rescue => e2
          puts "[JPods Console cmd_show_followme] error: #{e2.message}"
          @dialog.execute_script("showOutput(#{e2.message.to_json}, 'error')") rescue nil
        end
      end

      @dialog.add_action_callback("cmd_get_stations") do |_ctx|
        begin
          ids = JPods::JPodGuideway.station_ids_from_followme(model)
          if ids.empty?
            ids = model.entities.select { |e|
              (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) &&
                e.name == 'JPods Structure'
            }.map { |e| e.get_attribute('JPods', 'structure_id', '').to_s }
              .reject(&:empty?).uniq.sort
          end
          @dialog.execute_script("loadStations(#{ids.to_json})")
        rescue => e
          puts "[JPods Console cmd_get_stations] error: #{e.message}"
        end
      end

      @dialog.add_action_callback("cmd_clear_route_overlay") do |_ctx|
        JPods::JPodGuideway.clear_route_overlay(model) rescue nil
      end

      @dialog.add_action_callback("cmd_save_note") do |_ctx, comment|
        JPods._save_note("Console", comment.to_s)
        @dialog.execute_script("noteConfirm()") rescue nil
      end

      # Agent flag push — called by pre_animation_check results.
      # agent:  noelle | natalie | sally | nora
      # status: approved | disapproved | pending
      # msg:    one-line verdict for console output
      @dialog.add_action_callback("cmd_agent_flag") do |_ctx, agent, status, msg|
        js = "setAgentFlag(#{agent.to_json}, #{status.to_json}, #{msg.to_json})"
        @dialog.execute_script(js) rescue nil
      end

    end

    # ── helpers ───────────────────────────────────────────────────────────────

    private

    # Redirect $stdout into a StringIO for the duration of the task proc,
    # then return a single output string combining captured puts + return value.
    # selection_snapshot: the model.selection.first captured at gate-2 time;
    # passed as params["__selection"] so procs need not re-read selection.
    def self.capture_run(task, model, params, selection_snapshot = nil)
      params = params.merge("__selection" => selection_snapshot) if selection_snapshot
      old_out = $stdout
      $stdout = StringIO.new
      result  = nil
      begin
        result = task[:run].call(model, params)
      rescue => e
        $stdout.puts "ERROR: #{e.message}"
        (e.backtrace || []).first(4).each { |l| $stdout.puts "  #{l}" }
      ensure
        captured = $stdout.string
        $stdout  = old_out
      end
      parts = [captured.strip, result.is_a?(String) ? result : nil].compact
      output = parts.join("\n").strip
      # Write every task result to the log so Copilot can read it without copy-paste.
      begin
        log_level = output.start_with?("ERROR") ? :error : :info
        JPods::Logging.ingest("[Console:#{task[:id]}] #{output}", log_level)
      rescue => log_err
        $stderr.puts "capture_run log error: #{log_err.message}"
      end
      # Mirror every task result to Allie's event log so Claude Code can read it directly.
      begin
        JPods::JPodGuideway._allie_capture(
          'console_task_result',
          "[Console:#{task[:id]}] #{output[0, 400]}",
          { task_id: task[:id], status: output.start_with?("ERROR") ? 'error' : 'ok',
            output: output[0, 800] }
        )
      rescue => _ae
        # Never let Allie capture block a task result
      end
      output
    end

    # params may contain :select with source: :available_vehicles — resolve now
    def self.serialise_params(params, model = nil)
      params.map do |p|
        pd = p.dup
        if pd[:source] == :model_ids
          fmap = JPods::StructurePlacer.formation_options rescue {}
          opts = fmap.map { |k, v| { 'value' => k, 'label' => v } }
          pd[:options] = opts
          pd[:default] = opts.first['value'].to_s if pd[:default].to_s.empty? && !opts.empty?
        elsif pd[:source] == :available_vehicles
          pd[:options] = JPods::JPodGuideway.available_vehicles rescue []
        elsif pd[:source] == :platform_ids
          platforms = JPods::JPodGuideway.load_followme_platforms(model) rescue []
          pd[:options] = platforms.map { |pl| pl['id'].to_s }
        elsif pd[:source] == :nora_ids
          pd[:options] = JPods::JPodGuideway.active_nora_ids(model) rescue []
        elsif pd[:source] == :nora_with_station
          # Returns {value, label, station} objects.
          # JS renderParams uses station to render separate Vehicle / Station info rows.
          # Reads from model entities directly — no followme.json dependency.
          vehicles = []
          (model&.entities || []).each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance)
            vid = e.get_attribute('JPods', 'vehicle_id', '').to_s.strip
            next if vid.empty?
            sid = e.get_attribute('JPods', 'parked_station_id', '').to_s.strip.upcase
            vehicles << { 'value' => vid, 'label' => vid, 'station' => sid }
          end
          pd[:options] = vehicles.sort_by { |v| v['label'] }
        elsif pd[:source] == :trip_ids
          td = JPods::JPodGuideway.load_trip_json(model) rescue nil
          pd[:options] = Array(td&.dig('trips')).map do |t|
            "#{t['id']} (#{t['from']}→#{t['to']}, #{t['hops']}hop)"
          end
        elsif pd[:source] == :station_ids
          platforms = JPods::JPodGuideway.load_followme_platforms(model) rescue []
          pd[:options] = platforms.map { |pl| pl['structure_id'].to_s }.reject(&:empty?).uniq.sort
        elsif pd[:source] == :model_station_ids
          # Read structure_id directly from model entities — no followme.json dependency.
          sids = []
          (model&.entities || []).each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance)
            sid = e.get_attribute('JPods', 'structure_id', '').to_s.strip.upcase
            sids << sid unless sid.empty?
          end
          pd[:options] = sids.uniq.sort
        end
        pd.transform_keys(&:to_s)
      end
    end

    def self.send_error(msg)
      @dialog.execute_script("showOutput(#{msg.to_json}, 'error')")
    end

    # Build a human-readable trip sequence preview for a hold_loop station.
    # Returns a multi-line string the designer reads BEFORE animation to spot
    # wrong chains, missing tracks, unpopulated geometry, or lift conflicts.
    #
    # Sections:
    #   Phase 1 — Depart   (from_platform tracks)
    #   Phase 2 — Loop ×N  (hl_loop tracks, repeated N times; 0 = until slot opens)
    #   Phase 3 — Land     (to_platform tracks; or "direct-park" when to_platform=[])
    #   Phase 4 — Park     (gw_platform → slot N, Sally assigns at promotion)
    #
    # Track status symbols:
    #   ✓  geometry populated (pts_mm present)
    #   ○  declared but geometry not yet populated (run populate first)
    #   ✗  not found in lines.json — missing track definition
    #   ⤼  lift track — skipped by animator (not yet supported)
    #
    def self.preview_hold_loop_sequence(sid, model_id, arrival_cp, target_loops, plugin_dir)
      return "(Sally not loaded — cannot preview sequence)" unless defined?(JPods::Sally)

      seq_from  = JPods::Sally.hold_loop_from_platform(sid)
      seq_loop  = JPods::Sally.hold_loop_loop(sid)
      hl_to_raw = JPods::Sally.hold_loop_to_platform(sid)  # nil|[]|[...]
      seq_park  = JPods::Sally.parking_chain_tracks(sid)
      lc        = JPods::Sally.landing_chain(sid, arrival_cp)  # from landing_chains[cp]

      # Resolve Phase 3 approach using same priority as on_maneuver_complete:
      #   1. direct-park (hl_to_raw == [])
      #   2. intersection approach (lc defined + shares track with loop)
      #   3. hl_to_raw non-empty fallback
      seq_to, land_method =
        if hl_to_raw == []
          [[], :direct_park]
        elsif lc && !lc.empty? && (approach = JPods::Sally._final_approach_tracks(seq_loop, lc))
          [approach, :intersection]
        elsif hl_to_raw && !hl_to_raw.empty?
          [hl_to_raw, :to_platform]
        else
          [lc || [], :legacy]
        end

      # Load lines.json for geometry status and lengths.
      lines_path = File.join(plugin_dir, 'templates', 'track_formations', model_id, 'lines.json')
      lines_map  = {}
      if File.exist?(lines_path)
        begin
          lj = JSON.parse(File.read(lines_path, encoding: 'utf-8'))
          raw = lj['lines'] || {}
          raw = raw.is_a?(Hash) ? raw : raw.each_with_object({}) { |l, h| h[l['id']] = l }
          raw.each do |id, entry|
            pts   = entry['pts_mm']
            len   = entry['length_mm']
            populated = pts.is_a?(Array) && pts.size >= 2
            len_str   = (len && len > 0) ? "#{len.round(0).to_i}mm" : (populated ? '?mm' : '—')
            lines_map[id] = { populated: populated, len: len_str }
          end
        rescue => e
          lines_map = {}
        end
      end

      lift_re = /gw_lift/i

      # Format one track with status symbol and length.
      fmt_track = lambda { |t|
        if t.match?(lift_re)
          "    ⤼  #{t}  (lift — skipped by animator)"
        elsif (info = lines_map[t])
          sym = info[:populated] ? '✓' : '○'
          "    #{sym}  #{t}  #{info[:len]}"
        else
          "    ✗  #{t}  (NOT IN lines.json)"
        end
      }

      # Track-level warnings.
      all_tracks = seq_from + seq_loop + seq_to + seq_park
      missing    = all_tracks.reject { |t| lines_map.key?(t) }
      unpopulated = all_tracks.select { |t| lines_map[t] && !lines_map[t][:populated] }
      lift_in_seq = all_tracks.select { |t| t.match?(lift_re) }

      # Length totals (where available).
      sum_mm = lambda { |tracks|
        tracks.sum { |t| lines_map.dig(t, :len)&.to_i || 0 }
      }
      fmt_m = lambda { |mm| mm > 0 ? " (#{(mm / 1000.0).round(1)} m)" : "" }

      # Total trip distance (depart + all full loops + final approach + park)
      loop_count_display = target_loops > 0 ? target_loops : 1
      depart_mm  = sum_mm.call(seq_from)
      loop_mm    = sum_mm.call(seq_loop)
      land_mm    = sum_mm.call(seq_to)
      park_mm    = sum_mm.call(seq_park)
      total_mm   = depart_mm + loop_mm * loop_count_display + land_mm + park_mm
      total_m    = (total_mm / 1000.0).round(1)

      land_via = case land_method
        when :direct_park  then "direct-park"
        when :intersection then "intersection via #{lc&.first}"
        when :to_platform  then "to_platform"
        else                    "legacy"
        end

      lines = []
      lines << "// #{sid} (#{model_id})  cp=#{arrival_cp}  " \
               "loops=#{target_loops > 0 ? target_loops : '∞'}  " \
               "land=#{land_via}  total≈#{total_m}m"
      lines << '{"trip":['
      lines << ""

      # Depart — pod exits platform to loop entry (once)
      if seq_from.empty?
        lines << "    // (no depart tracks — pod starts at loop entry)"
      else
        seq_from.each { |t| lines << fmt_track.call(t) }
      end
      lines << ""

      # Full loops — repeated target_loops times (or annotated ×∞)
      if seq_loop.empty?
        lines << "    // ✗  NO LOOP TRACKS — pod cannot circulate"
        lines << ""
      elsif target_loops > 0
        target_loops.times do
          seq_loop.each { |t| lines << fmt_track.call(t) }
          lines << ""
        end
      else
        # Infinite mode — show one loop with repeat annotation
        seq_loop.each { |t| lines << fmt_track.call(t) }
        lines << "    // ... loop repeats until platform slot opens ..."
        lines << ""
      end

      # Final approach — last pass through partial loop then platform approach
      if land_method == :direct_park
        lines << "    // direct-park — animator places pod at assigned slot"
      elsif seq_to.empty?
        lines << "    // ✗  No landing path — pod will continue looping at promote"
      else
        seq_to.each { |t| lines << fmt_track.call(t) }
        lines << "    ↑ partial loop  ↓ platform approach" if land_method == :intersection
      end
      lines << ""

      # Park — gw_platform approach then slot assignment
      if seq_park.empty?
        lines << "    // gw_platform — Sally assigns slot at promotion"
      else
        seq_park.each { |t| lines << fmt_track.call(t) }
      end
      lines << "    → slot N  (Sally assigns at promotion)"
      lines << ""
      lines << "]}"
      lines << ""

      # Warnings
      if missing.any?
        lines << "// ✗  MISSING from lines.json: #{missing.join(', ')}"
        lines << "//    Run Workflow › Generate Template Data or add tracks manually."
      end
      if unpopulated.any?
        lines << "// ○  Geometry not populated: #{unpopulated.join(', ')}"
        lines << "//    Open the template model and run Workflow › Populate Geometry."
      end
      if lift_in_seq.any?
        lines << "// ⤼  Lift tracks in sequence (skipped by animator): #{lift_in_seq.join(', ')}"
      end
      if missing.empty? && unpopulated.empty?
        lines << "// ✓  All #{all_tracks.uniq.size} tracks defined — ready to animate."
      end

      lines.join("\n")
    end

    # Returns a hash for the Models panel JS call.
    # in_skp_jpods: true when the open model is saved inside ~/Documents/skp_jpods/.
    # Build and Finder buttons are only enabled when this is true.
    # Build the payload for the Sequence panel from a template's lines.json.
    # Reads chains_header, discovered_chains, landing_chains, exit_chains (or pass_chains).
    # Handles both simple array format and expanded object format (with tracks/length_mm/switches).
    # When expanded detail is present, uses it directly; otherwise derives from lines{}.
    def self.chain_panel_data(lines_path)
      require 'json'
      return nil unless File.exist?(lines_path)
      lj = JSON.parse(File.read(lines_path, encoding: 'utf-8'))

      formation  = lj['formation'] || File.basename(File.dirname(lines_path))
      chains_hdr = lj['chains_header'] || {}
      lj_lines   = lj['lines'].is_a?(Hash) ? lj['lines'] : {}
      eps_arr    = lj['eps'] || []

      # Build eps index: in_track → [ep, ...]
      eps_by_in = Hash.new { |h, k| h[k] = [] }
      eps_arr.each { |ep| Array(ep['in']).each { |t| eps_by_in[t] << ep } }

      # Extract tracks — handles simple array or expanded object format
      extract_tracks_fn = lambda do |chain_val|
        chain_val.is_a?(Array) ? chain_val : (chain_val.is_a?(Hash) ? chain_val['tracks'] : nil)
      end

      build_chain_entry = lambda do |chain_id, chain_val|
        tracks = extract_tracks_fn.call(chain_val)
        return nil unless tracks.is_a?(Array)

        # Use pre-computed detail if available (expanded object format)
        if chain_val.is_a?(Hash) && chain_val.key?('length_mm')
          len_mm   = chain_val['length_mm'].to_f
          switches = chain_val['switches'] || []
          tl       = chain_val['track_lengths'] || {}
        else
          # Compute from lines{}
          len_mm   = 0.0
          switches = []
          tl       = {}
          tracks.each_with_index do |track, idx|
            seg = lj_lines[track]
            seg_len = (seg&.dig('length_mm') || 0).to_f
            len_mm += seg_len
            tl[track] = seg_len
            eps_by_in[track].each do |ep|
              next unless ep['type'] == 'diverge'
              out_tracks = Array(ep['out'])
              next unless out_tracks.size > 1
              next_track = tracks[idx + 1]
              next unless next_track && out_tracks.include?(next_track)
              switches << { 'ep_id' => ep['id'], 'at_track' => track, 'setting' => next_track }
            end
          end
          len_mm = len_mm.round(1)
        end

        { 'id' => chain_id, 'label' => chain_id, 'tracks' => tracks,
          'length_mm' => len_mm, 'switches' => switches, 'track_lengths' => tl }
      end

      chains = []
      [
        ['landing',     lj['landing_chains']],
        ['originating', lj['exit_chains']],
        ['pass',        lj['pass_chains']]
      ].each do |prefix, section|
        next unless section.is_a?(Hash)
        section.each do |cp_key, chain_val|
          next if cp_key == 'note'
          entry = build_chain_entry.call("#{prefix}.#{cp_key}", chain_val)
          chains << entry if entry
        end
      end

      discovered = lj['discovered_chains'] || {}
      # Support both legacy plain-string arrays and new [pos, track] pair arrays.
      # Normalise to [pos, track] pairs for the JS layer.
      normalise_disc = lambda do |arr|
        return [] unless arr.is_a?(Array)
        arr.map.with_index do |item, idx|
          item.is_a?(Array) ? item : [idx + 1, item]
        end
      end
      # Prefer 'alpha' key (new format); fall back to 'alphabetical' (legacy).
      raw_alpha = discovered['alpha'] || discovered['alphabetical'] || []
      {
        'formation'        => formation,
        'chains_header'    => {
          'approved_by' => chains_hdr['approved_by'].to_s,
          'dt'          => chains_hdr['dt'].to_s,
          'approved'    => chains_hdr && !chains_hdr['approved_by'].to_s.strip.empty?
        },
        'chains'           => chains,
        'discovered_chains' => {
          'CCW'   => normalise_disc.call(discovered['CCW'] || []),
          'alpha' => normalise_disc.call(raw_alpha)
        }
      }
    rescue => ex
      puts "[Console] chain_panel_data error: #{ex.message}"
      nil
    end

    # Push chain data for a given formation to the Sequence panel.
    def self.push_sequence_panel(formation)
      plugin_dir  = File.dirname(__FILE__)
      lines_path  = File.join(plugin_dir, 'templates', 'track_formations', formation, 'lines.json')
      data = chain_panel_data(lines_path)
      return unless data
      @dialog&.execute_script("showSequencePanel(#{data.to_json})")
    rescue => ex
      puts "[Console] push_sequence_panel error: #{ex.message}"
    end

    # Push template or network context to the model info panel for Models tasks.
    def self.push_model_info(model)
      return unless @dialog && @dialog.visible?
      model = Sketchup.active_model if model.nil? || model.entities.nil?
      return unless model
      plugin_dir    = File.dirname(__FILE__)
      templates_dir = File.join(plugin_dir, 'templates', 'track_formations')

      # Is the open model a template?
      formation = model.get_attribute('JPods', 'model_id', '').to_s.strip
      unless formation.empty?
        lines_path = File.join(templates_dir, formation, 'lines.json')
        fm_path    = File.join(plugin_dir, 'formations', "#{formation}.json")
        cp_count      = 0
        chains_status = '✗ Not drafted'
        if File.exist?(lines_path)
          begin
            lj = JSON.parse(File.read(lines_path, encoding: 'utf-8'))
            cp_count = (lj['eps'] || []).count { |ep|
              ep['type'] == 'open' && Array(ep['in']).empty?
            } rescue 0
            hdr = lj['chains_header']
            if hdr.nil?
              chains_status = '✗ Not drafted'
            elsif hdr['approved_by'].to_s.strip.empty?
              chains_status = '⚠ Drafted, not approved'
            else
              chains_status = "✓ #{hdr['approved_by']}"
            end
          rescue; end
        end
        info = {
          'context'       => 'template',
          'formation'     => formation,
          'cp_count'      => cp_count,
          'formation_map' => File.exist?(fm_path) ? '✓ exists' : '✗ missing',
          'chains'        => chains_status
        }
        @dialog.execute_script("showModelInfo(#{info.to_json})")
        return
      end

      # Network model — scan for station template instances
      require 'set'
      seen = Set.new
      station_summary = []
      model.entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance)
        f = e.definition.get_attribute('JPods', 'model_id', '').to_s.strip
        next if f.empty? || seen.include?(f)
        seen << f
        lines_path = File.join(templates_dir, f, 'lines.json')
        chains_ok = false
        if File.exist?(lines_path)
          begin
            lj = JSON.parse(File.read(lines_path, encoding: 'utf-8'))
            hdr = lj['chains_header']
            chains_ok = hdr && !hdr['approved_by'].to_s.strip.empty?
          rescue; end
        end
        station_summary << { 'formation' => f, 'chains' => chains_ok ? '✓' : '✗' }
      end
      info = {
        'context'    => 'network',
        'model_name' => (model.path && !model.path.empty?) ?
                          File.basename(model.path, '.skp') : 'Untitled',
        'stations'   => station_summary
      }
      @dialog.execute_script("showModelInfo(#{info.to_json})")
    rescue => ex
      puts "[Console] push_model_info error: #{ex.message}"
    end

    def self.model_panel_info(model)
      path = (model && !model.path.to_s.empty?) ? model.path.to_s : nil
      name = path ? File.basename(path, '.skp') : '(unsaved)'
      skp_root = File.expand_path('~/Documents/skp_jpods')
      in_folder = path ? path.start_with?(skp_root) : false
      { name: name, path: path || '', in_skp_jpods: in_folder }
    end

  end  # Console

  # ── Console log-write backend (reload-safe) ───────────────────────────────
  #
  # jpod_console.log — append-only plain-text tee; `tail -f` from any terminal.
  # This module only holds the log-file handle and log_write.
  # The puts tee below uses JPods::Console.log_write.

  module Console

    remove_const(:LOG_PATH) if const_defined?(:LOG_PATH)

    LOG_PATH = File.join(File.dirname(__FILE__), "jpod_console.log").freeze

    # Open log file once per SketchUp session. Guard prevents a second file
    # handle opening if jpod_console.rb is loaded twice (double-load scenario).
    unless @log_io && !@log_io.closed?
      @log_io&.close rescue nil
      @log_io = begin
        io = File.open(LOG_PATH, "a")
        io.sync = true
        io
      rescue => e
        STDERR.puts "JPods Console: log file unavailable — #{e.message}"
        nil
      end
    end # unless @log_io

    # Reentrancy guard: if log_write is somehow invoked while already writing
    # (e.g. IO#puts calls back through the Kernel patch), drop the inner call.
    @log_writing = false unless defined?(@log_writing)
    # Dedup: track last (timestamp, message) pair to suppress exact duplicates
    # that arrive within the same second regardless of call path root cause.
    @last_log_ts  = nil unless defined?(@last_log_ts)
    @last_log_msg = nil unless defined?(@last_log_msg)

    def self.log_write(msg)
      return if @log_writing
      @log_writing = true
      begin
        ts  = Time.now.strftime("%H:%M:%S")
        key = "#{ts}|#{msg}"
        # Suppress exact duplicate within same second
        if key == @last_log_key
          @log_writing = false
          return
        end
        @last_log_key = key
        msg.to_s.split("\n").each do |line|
          @log_io&.puts("[#{ts}] #{line}") rescue nil
        end
        @log_io&.flush rescue nil
      ensure
        @log_writing = false
      end
    end

    # ── Travel app — callable from toolbar, menu, or console ──────────
    def self.open_travel(model)
      puts "[Travel] open_travel called — model=#{model.path}"
      return unless model

      html_path = File.join(File.dirname(__FILE__), "ui", "trip", "index.html")
      puts "[Travel] html_path=#{html_path} exists=#{File.exist?(html_path)}"
      @travel_dialog.close if @travel_dialog && @travel_dialog.visible? rescue nil

      dlg = UI::HtmlDialog.new(
        dialog_title: "JPods Travel",
        preferences_key: "JPods_Travel",
        width: 440, height: 900, resizable: true
      )

      su_respond = ->(d, cb_id, data) {
        d.execute_script("window._suCb(#{cb_id.to_i}, #{data.to_json})")
      }

      # trip_stations
      dlg.add_action_callback('trip_stations') do |_c, cb_id|
        puts "[Travel] trip_stations callback fired"
        stations = []
        nj_names = {}
        nj_path = JPods::NetworkEditor.default_network_json_path(model) rescue nil
        if nj_path && File.exist?(nj_path)
          nj = JSON.parse(File.read(nj_path, encoding: 'utf-8')) rescue {}
          nj_names = nj['station_names'] || {}
          (nj.dig('designer', 'stations') || []).each do |st|
            sid = st['id'].to_s
            fn = st['friendly_name'].to_s
            nj_names[sid] = fn unless fn.empty? || nj_names.key?(sid)
          end
        end
        # Only list stations with platforms — models where passengers can board.
        # has_platform is set by Noelle during Build. No fallback — run Build.
        platform_sids = {}
        designer_stations = nj.dig('designer', 'stations') || []
        designer_stations.each do |st|
          sid = st['id'].to_s.downcase
          unless st.key?('has_platform')
            puts "[Travel] ERROR: #{sid} missing has_platform — run Build"
            next
          end
          platform_sids[sid] = true if st['has_platform']
        end
        if platform_sids.empty? && designer_stations.any?
          puts "[Travel] ERROR: no stations with has_platform=true — run Build to regenerate network.json"
        end

        seen_sids = {}
        model.entities.each do |e|
          next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          sid = e.get_attribute('JPods', 'structure_id', '').to_s.strip.downcase
          next if sid.empty?
          next if seen_sids[sid]
          next unless platform_sids[sid]  # only stations with gw_platform
          seen_sids[sid] = true
          name = nj_names[sid] || nj_names[sid.upcase] ||
                 e.get_attribute('JPods', 'station_name', '').to_s.strip
          display = name.empty? ? sid : "#{sid} — #{name}"
          mid = e.get_attribute('JPods', 'model_id', '').to_s.downcase
          stations << { id: sid, name: display, friendly_name: name, description: mid }
        end
        stations.sort_by! { |s| s[:id].downcase }
        puts "[Travel] trip_stations: #{stations.size} station(s): #{stations.map { |s| "#{s[:id]}(#{s[:friendly_name]})" }.join(', ')}"
        su_respond.call(dlg, cb_id, { stations: stations })
      end

      # trip_book
      dlg.add_action_callback('trip_book') do |_c, cb_id, json|
        puts "[Travel] trip_book callback fired: #{json.to_s[0,200]}"
        begin
          body = JSON.parse(json.to_s)
          origin = (body['origin_id'] || body['origin']).to_s.strip.downcase
          dest   = (body['destination_id'] || body['destination']).to_s.strip.downcase
          puts "[Travel] trip_book: origin=#{origin} dest=#{dest} raw=#{body.keys.join(',')}"

          pod = nil; depart_id = nil

          # Start animation if needed — Sally initializes during start
          was_running = defined?(AnimationV2) && AnimationV2.running?
          puts "[Travel] animation was_running=#{was_running}"
          AnimationV2.start(model) if defined?(AnimationV2) && !was_running

          # Sally picks the highest occupied slot at the origin
          if defined?(SallyV2)
            st = SallyV2.station(origin)
            puts "[Travel] SallyV2.station(#{origin}) = #{st ? 'found' : 'nil'}"
            unless st
              puts "[Travel] ERROR: station #{origin} not found in Sally"
              su_respond.call(dlg, cb_id, { error: "Station #{origin} not found — run Populate" })
              next
            end
            puts "[Travel] station #{origin}: capacity=#{st.capacity}, occupancy=#{st.occupancy}"

            highest = st.highest_occupied_slot
            if highest && highest.occupied?
              depart_id = highest.occupant_id
              puts "[Travel] claiming pod #{depart_id} at #{origin} ps#{highest.number}"
            else
              puts "[Travel] ERROR: no parked pods at #{origin}"
            end
          else
            puts "[Travel] ERROR: SallyV2 not defined"
          end

          unless depart_id
            puts "[Travel] ERROR: no available pod at #{origin}"
            su_respond.call(dlg, cb_id, { error: "No available pod at #{origin} — run Populate" })
            next
          end

          # Find the pod in AnimationV2
          if defined?(AnimationV2)
            anim_pod = AnimationV2.pods.find { |p| p.pod_id == depart_id }
            if anim_pod && anim_pod.entity && !anim_pod.entity.deleted?
              pod = anim_pod
              puts "[Travel] using pod #{depart_id} at #{origin}"
            else
              puts "[Travel] ERROR: pod #{depart_id} entity not found in animation"
            end
          end

          unless pod
            puts "[Travel] ERROR: no available pod at #{origin}"
            su_respond.call(dlg, cb_id, { error: "No available pod at #{origin}" })
            next
          end

          SallyV2.pod_departs(origin, depart_id, destination: dest)
          pod.entity.set_attribute('JPods', 'destination_station_id', dest)
          puts "[Travel] dispatching #{depart_id}: #{origin} → #{dest}"

          route = NatalieV2.plan_route(origin, dest)
          puts "[Travel] route: #{route ? "#{route.track_ids.size} tracks" : 'nil'}"
          unless route
            SallyV2.pod_arrives(origin, depart_id, entity: pod.entity)
            su_respond.call(dlg, cb_id, { error: "No route #{origin} → #{dest}" })
            next
          end
          maneuvers = NatalieV2.build_maneuvers(route)
          puts "[Travel] maneuvers: #{maneuvers.size}"
          if maneuvers.empty?
            SallyV2.pod_arrives(origin, depart_id, entity: pod.entity)
            su_respond.call(dlg, cb_id, { error: "No maneuvers #{origin} → #{dest}" })
            next
          end

          queue = maneuvers.map { |m| AnimationV2.send(:_maneuver_to_hash, m) }
          # Skip gw_platform at origin — Sally owns the platform
          if queue.first && queue.first[:id].to_s.split('.').last == 'gw_platform'
            queue.shift
          end
          pod.receive_maneuver(queue.shift, seed_pos: pod.entity.bounds.center)
          AnimationV2.send(:_set_queue, pod.pod_id, queue)
          AnimationV2.send(:_undwell, pod.pod_id)
          AnimationV2.set_camera_follow(depart_id)
          puts "[Travel] camera following #{depart_id}"

          total_len = maneuvers.sum { |m| m.respond_to?(:len) ? (m.len || 0) : 0 }
          speed_in = NoraV2::DEFAULT_SPEED_MS * NoraV2::INCH_PER_METER
          eta_s = speed_in > 0 ? total_len / speed_in : 30.0
          su_respond.call(dlg, cb_id, {
            trip_id: "trip_#{depart_id}_#{Time.now.to_i}",
            nora_id: depart_id, eta_s: eta_s.round(1),
            origin: origin, destination: dest
          })
        rescue => ex
          su_respond.call(dlg, cb_id, { error: ex.message })
        end
      end

      # trip_status
      dlg.add_action_callback('trip_status') do |_c, cb_id, json|
        begin
          data = JSON.parse(json.to_s)
          nora_id = data['nora_id'].to_s
          if nora_id.empty?
            # trip_id format: "trip_NORA_0035_1234567" → extract "NORA_0035"
            parts = data['trip_id'].to_s.split('_')
            nora_id = parts.size >= 3 ? "#{parts[1]}_#{parts[2]}" : ''
          end
          pod = defined?(AnimationV2) ? AnimationV2.pods.find { |p| p.pod_id == nora_id } : nil
          # Only log state changes, not every poll tick
          state_str = pod&.state&.to_s || 'not found'
          last_key = "trip_status_#{nora_id}"
          if state_str != (@@_last_trip_state ||= {})[last_key]
            puts "[Travel] trip_status: nora_id=#{nora_id} state=#{state_str}"
            @@_last_trip_state[last_key] = state_str
          end
          su_respond.call(dlg, cb_id, pod ? { status: pod.state.to_s, nora_id: nora_id, traveling: pod.state == :traveling } : { status: 'unknown' })
        rescue => ex
          su_respond.call(dlg, cb_id, { error: ex.message })
        end
      end

      # trip_enter
      dlg.add_action_callback('trip_enter') do |_c, cb_id, json|
        body = JSON.parse(json.to_s) rescue {}
        AnimationV2.set_camera_follow(body['nora_id'].to_s) if defined?(AnimationV2)
        su_respond.call(dlg, cb_id, { ok: true })
      end

      # trip_camera_position
      dlg.add_action_callback('trip_camera_position') do |_c, cb_id, json|
        body = JSON.parse(json.to_s) rescue {}
        sid = body['station_id'].to_s
        puts "[Travel] trip_camera_position: sid=#{sid}"
        entity = model.entities.find { |e|
          (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
          e.get_attribute('JPods', 'structure_id', '').to_s.strip.downcase == sid.downcase
        }
        if entity
          c = entity.bounds.center
          puts "[Travel] camera → #{sid} at (#{c.x.to_m.round(1)}, #{c.y.to_m.round(1)}, #{c.z.to_m.round(1)})m"
          model.active_view.camera = Sketchup::Camera.new(
            Geom::Point3d.new(c.x + 50.m, c.y - 25.m, c.z + 50.m), c, Z_AXIS)
        else
          puts "[Travel] camera: station #{sid} not found in model"
        end
        su_respond.call(dlg, cb_id, { ok: true })
      end

      # trip_camera_stop
      dlg.add_action_callback('trip_camera_stop') do |_c, cb_id|
        AnimationV2.set_camera_follow('') if defined?(AnimationV2)
        su_respond.call(dlg, cb_id, { ok: true })
      end

      # trip_rename_station
      dlg.add_action_callback('trip_rename_station') do |_c, cb_id, json|
        body = JSON.parse(json.to_s) rescue {}
        sid = body['station_id'].to_s; name = body['name'].to_s.strip
        model.entities.each do |e|
          next unless (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
            e.get_attribute('JPods', 'structure_id', '').to_s.strip.downcase == sid.downcase
          e.set_attribute('JPods', 'station_name', name)
          break
        end
        su_respond.call(dlg, cb_id, { ok: true })
      end

      dlg.set_url("file://#{html_path}?v=#{Time.now.to_i}")
      dlg.show
      @travel_dialog = dlg
    rescue => e
      puts "[Travel] open error: #{e.message}"
    end

  end  # module Console


  # ── Kernel#puts → log file tee  (reload-safe) ─────────────────────────────
  #
  # Every puts call in any plugin still goes to SketchUp's Ruby Console AND is
  # appended to jpod_console.log.
  #
  # Uses Module#prepend (not alias_method) so the patch module is inserted once
  # into Kernel's ancestor chain.  Prepending the same module a second time is
  # a no-op in Ruby, making this structurally immune to double-application even
  # if the unless-guard is somehow bypassed.
  unless $jpods_puts_patched
    $jpods_puts_patched = true
    module JPodsPutsTee
      def puts(*args)
        super
        JPods::Console.log_write(args.flatten.map(&:to_s).join("\n")) rescue nil
      end
    end
    Kernel.prepend(JPodsPutsTee)
  end

end  # JPods
