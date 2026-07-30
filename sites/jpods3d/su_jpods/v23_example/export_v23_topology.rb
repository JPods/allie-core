# frozen_string_literal: true

# v23 topology + runtime exporter for SketchUp Ruby Console.
#
# Usage in SketchUp Ruby Console:
#   load '/Users/williamjames/Library/Application Support/SketchUp 2026/SketchUp/Plugins/JPods/v23_example/export_v23_topology.rb'
#   V23Export.export_topology
#   V23Export.start_runtime_log(duration_s: 60, interval_s: 0.5)
#
# Optional custom output folder:
#   V23Export.export_topology('/path/to/output')
#   V23Export.start_runtime_log(output_dir: '/path/to/output', duration_s: 90)

require 'json'
require 'fileutils'

module V23Export
  module_function

  KEY_HINTS = %w[
    connection_id line_id segment_id segment sid id
    next next_cid next_options connections myPath
    track_index track lane direction
    beam_path path points centerline
  ].freeze

  SEGMENT_KEYS = %w[
    connection_id line_id segment_id sid id
  ].freeze

  def export_topology(output_dir = nil)
    model = Sketchup.active_model
    out_dir = ensure_output_dir(output_dir)

    records = collect_track_like_entities(model)
    edges = infer_edges(records)

    payload = {
      generated_at: utc_now,
      model_name: model.title,
      model_path: model.path,
      entity_count: records.size,
      edge_count: edges.size,
      entities: records,
      inferred_edges: edges,
      notes: [
        'Entities are selected by name/attribute hints to avoid hard-coding ene_railroad internals.',
        'inferred_edges comes from next/next_options/connections/myPath style attributes when present.'
      ]
    }

    json_path = File.join(out_dir, 'v23_topology.json')
    File.write(json_path, JSON.pretty_generate(payload), encoding: 'utf-8')

    summary_path = File.join(out_dir, 'v23_topology_summary.txt')
    File.write(summary_path, build_summary(payload), encoding: 'utf-8')

    puts "V23Export: wrote #{json_path}"
    puts "V23Export: wrote #{summary_path}"
    json_path
  rescue => e
    puts "V23Export export_topology error: #{e.class}: #{e.message}"
    nil
  end

  def start_runtime_log(output_dir: nil, duration_s: 60.0, interval_s: 0.5)
    stop_runtime_log

    @runtime_out_dir = ensure_output_dir(output_dir)
    @runtime_path = File.join(@runtime_out_dir, 'v23_runtime.log')
    @runtime_started_at = Time.now
    @runtime_last_state = {}

    header = []
    header << "V23 runtime log"
    header << "started_at=#{utc_now}"
    header << "model=#{Sketchup.active_model.title}"
    header << "duration_s=#{duration_s} interval_s=#{interval_s}"
    header << '-' * 60
    File.write(@runtime_path, header.join("\n") + "\n", encoding: 'utf-8')

    @runtime_timer = UI.start_timer(interval_s, true) do
      begin
        tick_runtime_log
      rescue => e
        append_runtime("ERROR #{e.class}: #{e.message}")
      end

      if (Time.now - @runtime_started_at) >= duration_s
        append_runtime('completed by duration')
        stop_runtime_log
      end
    end

    puts "V23Export: runtime log started -> #{@runtime_path}"
    @runtime_path
  rescue => e
    puts "V23Export start_runtime_log error: #{e.class}: #{e.message}"
    nil
  end

  def stop_runtime_log
    if @runtime_timer
      UI.stop_timer(@runtime_timer) rescue nil
      @runtime_timer = nil
      puts "V23Export: runtime log stopped -> #{@runtime_path}" if @runtime_path
    end
  end

  def output_dir_default
    File.expand_path(__dir__)
  end

  def ensure_output_dir(path)
    out = path && !path.to_s.strip.empty? ? File.expand_path(path) : output_dir_default
    FileUtils.mkdir_p(out)
    out
  end

  def collect_track_like_entities(model)
    out = []
    walk_entities(model.entities, Geom::Transformation.new, [], out)
    out
  end

  def walk_entities(entities, xf, path_stack, out)
    entities.each do |e|
      next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)

      name = entity_name(e)
      attrs = attribute_hash(e)
      child_xf = xf * e.transformation
      path_here = path_stack + [name.empty? ? e.entityID.to_s : name]

      if track_like?(name, attrs)
        out << build_record(e, name, attrs, child_xf, path_here)
      end

      child_entities = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
      walk_entities(child_entities, child_xf, path_here, out)
    end
  end

  def track_like?(name, attrs)
    low_name = name.to_s.downcase
    return true if low_name.match?(/track|guide|rail|segment|line/)

    flat_keys = attrs.values.flat_map(&:keys).map(&:downcase)
    KEY_HINTS.any? { |hint| flat_keys.any? { |k| k.include?(hint.downcase) } }
  end

  def build_record(entity, name, attrs, xf, path_here)
    points = extract_points(attrs, xf)
    seg_id = logical_segment_id(entity, attrs)

    {
      entity_id: entity.entityID,
      name: name,
      segment_id: seg_id,
      path_hint: path_here.join(' > '),
      track_index: attr_lookup(attrs, %w[track_index track lane direction]),
      next: attr_lookup(attrs, %w[next next_cid]),
      next_options: normalize_connection_value(attr_lookup(attrs, %w[next_options])),
      connections: normalize_connection_value(attr_lookup(attrs, %w[connections myPath])),
      start_xyz: points && !points.empty? ? points.first : nil,
      end_xyz: points && !points.empty? ? points.last : nil,
      point_count: points ? points.size : 0,
      raw_attributes: attrs
    }
  end

  def infer_edges(records)
    by_id = {}
    records.each do |r|
      sid = r[:segment_id].to_s
      by_id[sid] = r if !sid.empty? && sid != "E#{r[:entity_id]}"
    end

    edges = []
    records.each do |r|
      from = r[:segment_id].to_s
      next if from.empty?

      extract_targets(r[:next]).each { |to| edges << edge_row(from, to, 'next') }
      extract_targets(r[:next_options]).each { |to| edges << edge_row(from, to, 'next_options') }
      extract_targets(r[:connections]).each { |to| edges << edge_row(from, to, 'connections') }
    end

    edges.uniq { |e| [e[:from], e[:to], e[:source]] }
  end

  def edge_row(from, to, source)
    { from: from.to_s, to: to.to_s, source: source }
  end

  def extract_targets(value)
    case value
    when nil
      []
    when String
      v = value.strip
      v.empty? ? [] : [v]
    when Numeric
      [value.to_s]
    when Array
      value.flat_map { |x| extract_targets(x) }
    when Hash
      value.values.flat_map { |x| extract_targets(x) }
    else
      []
    end
  end

  def extract_points(attrs, xf)
    raw = attr_lookup(attrs, %w[beam_path path points centerline])
    arr = normalize_point_array(raw)
    return nil if arr.nil? || arr.empty?

    arr.map do |xyz|
      pt = Geom::Point3d.new(xyz[0].to_f, xyz[1].to_f, xyz[2].to_f)
      w = xf * pt
      [w.x.to_f, w.y.to_f, w.z.to_f]
    end
  rescue
    nil
  end

  def normalize_point_array(raw)
    parsed = parse_maybe_json(raw)
    arr = parsed.is_a?(Array) ? parsed : nil
    return nil unless arr
    return nil if arr.empty?

    first = arr.first
    if first.is_a?(Array) && first.size >= 3
      arr.map { |p| [p[0], p[1], p[2]] }
    elsif first.is_a?(Hash)
      # common forms: {x:,y:,z:} or {'x'=>...}
      arr.map do |h|
        [h['x'] || h[:x], h['y'] || h[:y], h['z'] || h[:z]]
      end
    else
      nil
    end
  end

  def parse_maybe_json(v)
    return v if v.is_a?(Array) || v.is_a?(Hash)
    return nil if v.nil?
    s = v.to_s.strip
    return nil if s.empty?
    return nil unless s.start_with?('[', '{')
    JSON.parse(s)
  rescue
    nil
  end

  def normalize_connection_value(v)
    parsed = parse_maybe_json(v)
    return parsed unless parsed.nil?
    v
  end

  def logical_segment_id(entity, attrs)
    SEGMENT_KEYS.each do |k|
      val = attr_lookup(attrs, [k])
      next if val.nil?
      s = val.to_s.strip
      return s unless s.empty?
    end
    "E#{entity.entityID}"
  end

  def attr_lookup(attrs, keys)
    keys.each do |k|
      attrs.each_value do |dict|
        dict.each do |name, value|
          return value if name.to_s.casecmp(k.to_s).zero?
        end
      end
    end
    nil
  end

  def attribute_hash(entity)
    out = {}
    dicts = entity.attribute_dictionaries
    return out unless dicts

    dicts.each do |d|
      next unless d
      vals = {}
      d.each_pair { |k, v| vals[k.to_s] = ruby_safe(v) }
      out[d.name.to_s] = vals
    end
    out
  end

  def ruby_safe(v)
    case v
    when Geom::Point3d
      [v.x.to_f, v.y.to_f, v.z.to_f]
    when Geom::Vector3d
      [v.x.to_f, v.y.to_f, v.z.to_f]
    when Array
      v.map { |x| ruby_safe(x) }
    when Hash
      v.transform_values { |x| ruby_safe(x) }
    when Numeric, String, TrueClass, FalseClass, NilClass
      v
    else
      v.to_s
    end
  end

  def entity_name(e)
    n = e.respond_to?(:name) ? e.name.to_s : ''
    return n unless n.empty?
    if e.is_a?(Sketchup::ComponentInstance)
      e.definition.name.to_s
    else
      ''
    end
  end

  def tick_runtime_log
    model = Sketchup.active_model
    moving = collect_moving_candidates(model)

    moving.each do |e|
      state = current_motion_state(e)
      prev = @runtime_last_state[e.entityID]

      if prev
        if state[:segment] != prev[:segment] && !state[:segment].to_s.empty?
          append_runtime("TRANSITION entity=#{e.entityID} #{prev[:segment]} -> #{state[:segment]}")
        end

        dist = distance3(prev[:xyz], state[:xyz])
        if dist > 0.01
          append_runtime("MOVE entity=#{e.entityID} segment=#{state[:segment]} d=#{dist.round(3)}")
        end
      else
        append_runtime("SEEN entity=#{e.entityID} segment=#{state[:segment]} xyz=#{state[:xyz].map { |n| n.round(3) }}")
      end

      @runtime_last_state[e.entityID] = state
    end
  end

  def collect_moving_candidates(model)
    out = []
    walk_for_movers(model.entities, out)
    out
  end

  def walk_for_movers(entities, out)
    entities.each do |e|
      if e.is_a?(Sketchup::ComponentInstance)
        n = entity_name(e).downcase
        attrs = attribute_hash(e)
        if n.match?(/vehicle|pod|train|car/) || has_motion_attrs?(attrs)
          out << e
        end
      end

      if e.is_a?(Sketchup::Group)
        walk_for_movers(e.entities, out)
      elsif e.is_a?(Sketchup::ComponentInstance)
        walk_for_movers(e.definition.entities, out)
      end
    end
  end

  def has_motion_attrs?(attrs)
    keys = attrs.values.flat_map(&:keys).map(&:downcase)
    keys.any? { |k| k.include?('anim') || k.include?('speed') || k.include?('vehicle') || k.include?('segment') }
  end

  def current_motion_state(entity)
    attrs = attribute_hash(entity)
    seg = attr_lookup(attrs, %w[anim_gw connection_id line_id segment_id next_cid]).to_s
    pt = entity.transformation.origin
    {
      segment: seg,
      xyz: [pt.x.to_f, pt.y.to_f, pt.z.to_f]
    }
  end

  def distance3(a, b)
    dx = a[0] - b[0]
    dy = a[1] - b[1]
    dz = a[2] - b[2]
    Math.sqrt(dx * dx + dy * dy + dz * dz)
  end

  def append_runtime(line)
    ts = utc_now
    File.open(@runtime_path, 'a:utf-8') { |f| f.puts("#{ts} #{line}") }
  rescue
    nil
  end

  def utc_now
    Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  end

  def build_summary(payload)
    lines = []
    lines << "generated_at: #{payload[:generated_at]}"
    lines << "model_name: #{payload[:model_name]}"
    lines << "model_path: #{payload[:model_path]}"
    lines << "entity_count: #{payload[:entity_count]}"
    lines << "edge_count: #{payload[:edge_count]}"
    lines << ''
    lines << 'Top entities:'
    payload[:entities].first(50).each do |e|
      lines << "- #{e[:segment_id]}  name='#{e[:name]}'  track=#{e[:track_index]}  points=#{e[:point_count]}"
    end
    lines.join("\n") + "\n"
  end
end

puts 'V23Export loaded. Run: V23Export.export_topology'
