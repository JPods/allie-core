# ── Compute Pipeline v2 — Orchestrator ────────────────────────────────────────
#
# One button. Three phases. Math only.
#
# Phase 1: Validate designer topology (accept or reject)
# Phase 2: Build Natalie chains from successor graph
# Phase 3: Extract geometry from CP markers + chain-walk
#
# See: compute/README.md
#
# ── su-real ──────────────────────────────────────────────────────────────────
# Compute produces the geometry that ALL downstream systems consume:
#   - SU animation reads pts_mm polylines for Nora interpolation
#   - Physical mapSM.json lines are the SAME topology expressed as
#     segments with length, radius, direction cosines (dx, dy)
#   - lines.computed.json is the bridge: its tracks map 1:1 to physical
#     lines. track_lengths_mm → line.length. Bezier radius → segment.radius.
#
# To generate a physical map from Compute output:
#   1. Each natalie chain → ordered list of line IDs
#   2. Each track in chain → one physical line with:
#      - length from track_lengths_mm
#      - segments decomposed from pts_mm (straight runs + arcs)
#      - speedMin/speedMax from curve radius → maxLateralG constraint
#      - servo setting from chain's switch at diverge EPs
#   3. Each ezone from merge/diverge EPs → inPoint1/inPoint2/outPoint
#      with distFrom/distTo computed from chain geometry
#
# The Compute → mapSM.json converter is a planned tool. When built,
# students design in SketchUp → Compute → convert → deploy to Pi fleet.
# Same topology, same chains, different coordinate representation.
#
# SU models are the authority for guideway IDs. Physical networks will
# use SU-generated IDs (seg_s001_1_s003_1, gw_platform, gw_c_0_1, etc.)
# rather than hand-numbered line IDs. This eliminates the mapping layer
# between SU simulation and physical deployment — same names everywhere.
#
# seg_ in physical: a single SU seg_ (inter-station connection) becomes
# MANY physical segments — straights, curves, grade changes, each with
# its own length, radius, speedMin/Max, and servo setting. The SU polyline
# pts_mm decompose into physical segments at the converter step.
# Example: seg_s001_1_s003_1 (one SU track, 12 pts_mm) →
#   seg_s001_1_s003_1.0 (straight, 2400mm)
#   seg_s001_1_s003_1.1 (curve, r=3500mm, 1800mm)
#   seg_s001_1_s003_1.2 (straight, 4100mm)
#   seg_s001_1_s003_1.3 (grade, -2%, 3200mm)
# Physical Nora traverses sub-segments sequentially; SU Nora interpolates
# the polyline continuously. Same path, different granularity.
# ─────────────────────────────────────────────────────────────────────────────

require 'json'
require_relative 'compute_validator'
require_relative 'compute_chain_builder'
require_relative 'compute_geometry'
require_relative 'compute_writer'

module JPods
  module Compute

    # Run the full three-phase Compute pipeline on the currently open template model.
    # Called from the Console "Compute" task.
    #
    # @param model [Sketchup::Model] the active model (must be a template model.skp)
    # @return [Hash, false] tracks hash on success, false on failure
    def self.run(model = nil)
      model ||= Sketchup.active_model
      model_path = model.path.to_s

      if model_path.empty?
        puts "[Compute] model not saved — save it to the template folder first"
        return false
      end

      model_id = File.basename(File.dirname(model_path))
      plugin_dir = File.dirname(__FILE__)
      lj_path = File.join(File.dirname(plugin_dir), 'templates', 'track_formations',
                           model_id, 'lines.json')

      unless File.exist?(lj_path)
        puts "[Compute] no lines.json at #{lj_path}"
        return false
      end

      template_data = JSON.parse(File.read(lj_path, encoding: 'utf-8'))

      puts ""
      puts "═══ Compute v2 — #{model_id} ═══"
      puts ""

      # ── Phase 1: Validate ─────────────────────────────────────────────────
      puts "── Phase 1: Validate ──"
      defects = Validator.check(template_data, model_id: model_id)
      unless defects.empty?
        Validator.report(defects, model_id)
        return false
      end
      puts "[Compute] Phase 1: ✓ designer topology valid"
      puts ""

      # ── Phase 2: Build Chains ─────────────────────────────────────────────
      puts "── Phase 2: Build Chains ──"
      chain_result = ChainBuilder.build(template_data, model_id: model_id)
      unless chain_result[:failures].empty?
        puts ""
        puts "⚠ [Natalie] Chain building had #{chain_result[:failures].size} failure(s):"
        chain_result[:failures].each { |f| puts "   • #{f}" }
        puts "   These routes will not be available until the topology is fixed."
        puts ""
      end
      # Merge computed chains into template_data natalie section
      template_data['natalie'] ||= {}
      template_data['natalie'].merge!(chain_result[:natalie])
      puts ""

      # ── Phase 3: Extract Geometry ─────────────────────────────────────────
      puts "── Phase 3: Extract Geometry ──"
      geo_result = Geometry.extract(model, template_data, model_id: model_id)
      unless geo_result[:failures].empty?
        puts ""
        puts "⚠ [Compute] #{geo_result[:failures].size} track(s) have no geometry:"
        geo_result[:failures].each { |f| puts "   • #{f}" }
        puts ""
      end
      puts ""

      # ── Write ─────────────────────────────────────────────────────────────
      puts "── Write ──"
      Writer.write(model_id, template_data, geo_result)

      # Write computed chains to lines.json — but NEVER overwrite existing
      # hand-curated chains. The designer's natalie section is authoritative.
      # Only add chains that don't already exist in lines.json.
      begin
        lj_data = JSON.parse(File.read(lj_path, encoding: 'utf-8'))
        lj_data['natalie'] ||= {}
        existing = lj_data['natalie']
        added = 0
        skipped = 0
        chain_result[:natalie].each do |key, val|
          if existing.key?(key)
            skipped += 1
          else
            existing[key] = val
            added += 1
          end
        end
        File.write(lj_path, JSON.pretty_generate(lj_data), encoding: 'utf-8')
        puts "[Compute] lines.json natalie: #{added} chain(s) added, #{skipped} existing preserved"
      rescue => ex
        puts "[Compute] ⚠ lines.json update failed: #{ex.message}"
      end

      puts ""
      puts "═══ Compute v2 complete — #{model_id} ═══"
      puts ""

      geo_result[:tracks]
    rescue => ex
      puts "[Compute] error: #{ex.message}"
      puts ex.backtrace.first(5).join("\n")
      false
    end

  end
end
