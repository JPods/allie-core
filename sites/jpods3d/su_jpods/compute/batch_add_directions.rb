# ── Batch Add Direction Vectors + Successors ─────────────────────────────────
#
# Adds 'direction' vectors and 'successors' to all tracks in lines.computed.json.
# Direction: computed from first two pts_mm — authoritative flow direction.
# Successors: copied from lines.json designer.tracks — human-readable topology.
#
# Run from SketchUp Ruby console:
#   JPods::Compute::BatchDirections.run
#
# Or as a standalone script (no SketchUp needed):
#   ruby batch_add_directions.rb

require 'json'

module JPods
  module Compute
    module BatchDirections

      def self.run
        plugin_dir = File.dirname(File.dirname(__FILE__))
        templates_dir = File.join(plugin_dir, 'templates', 'track_formations')

        updated = 0
        Dir.glob(File.join(templates_dir, '*', 'lines.computed.json')).each do |path|
          template_dir = File.dirname(path)
          template = File.basename(template_dir)
          data = JSON.parse(File.read(path, encoding: 'utf-8'))

          # Read successors from lines.json
          lj_path = File.join(template_dir, 'lines.json')
          designer_tracks = {}
          if File.exist?(lj_path)
            lj = JSON.parse(File.read(lj_path, encoding: 'utf-8')) rescue {}
            designer_tracks = lj.dig('designer', 'tracks') || {}
          end

          geo_tracks = data.dig('geometry', 'tracks') || {}
          changed = false

          # has_platform — does this template have a gw_platform track?
          unless data.key?('has_platform')
            data['has_platform'] = geo_tracks.key?('gw_platform')
            changed = true
          end

          geo_tracks.each do |tag, td|
            # Direction vector from pts_mm
            pts = td['pts_mm']
            if pts.is_a?(Array) && pts.size >= 2
              p0 = pts[0]; p1 = pts[1]
              dx = p1[0].to_f - p0[0].to_f
              dy = p1[1].to_f - p0[1].to_f
              dz = p1[2].to_f - p0[2].to_f
              mag = Math.sqrt(dx*dx + dy*dy + dz*dz)
              if mag > 0.001
                td['direction'] = {
                  'x' => (dx/mag).round(6),
                  'y' => (dy/mag).round(6),
                  'z' => (dz/mag).round(6)
                }
                changed = true
              end
            end

            # Successors from lines.json
            succs = designer_tracks.dig(tag, 'successors')
            if succs.is_a?(Array)
              td['successors'] = succs
              changed = true
            end
          end

          if changed
            File.write(path, JSON.pretty_generate(data), encoding: 'utf-8')
            puts "[BatchDirections] #{template}: #{geo_tracks.size} tracks — directions + successors added"
            updated += 1
          else
            puts "[BatchDirections] #{template}: no changes needed"
          end
        end

        puts "[BatchDirections] done — #{updated} file(s) updated"
        updated
      end

    end
  end
end

# Auto-run when loaded
JPods::Compute::BatchDirections.run
