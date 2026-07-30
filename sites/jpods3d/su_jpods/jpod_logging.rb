require 'fileutils'
require 'thread'
require 'json'

module JPods
  module Logging
    MAX_LINES = 4000 unless defined?(MAX_LINES)

    class TeeIO
      def initialize(original, level)
        @original = original
        @level = level
        @carry = +""
      end

      def write(str)
        text = str.to_s
        @original.write(text) if @original.respond_to?(:write)
        @carry << text

        while (idx = @carry.index("\n"))
          line = @carry.slice!(0..idx)
          Logging.ingest(line.chomp, @level)
        end

        text.bytesize
      rescue
        text.to_s.bytesize
      end

      def flush
        @original.flush if @original.respond_to?(:flush)
      end

      def tty?
        @original.respond_to?(:tty?) ? @original.tty? : false
      end

      def sync=(value)
        @original.sync = value if @original.respond_to?(:sync=)
      end

      def sync
        @original.respond_to?(:sync) ? @original.sync : nil
      end

      def method_missing(name, *args, &block)
        return super unless @original.respond_to?(name)
        @original.public_send(name, *args, &block)
      end

      def respond_to_missing?(name, include_private = false)
        @original.respond_to?(name, include_private) || super
      end
    end

    class << self
      def install!
        return if @installed

        @mutex = Mutex.new
        @buffer = []
        @seq = 0

        @original_stdout = $stdout
        @original_stderr = $stderr
        $stdout = TeeIO.new(@original_stdout, :info)
        $stderr = TeeIO.new(@original_stderr, :error)

        @installed = true
        ingest('JPods logger installed', :system)
        true
      rescue
        false
      end

      def ingest(line, level = :info)
        return if line.nil? || line.empty?

        entry = nil
        @mutex.synchronize do
          @seq += 1
          entry = {
            seq: @seq,
            ts: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
            level: level.to_s,
            msg: line,
          }
          @buffer << entry
          @buffer.shift while @buffer.size > MAX_LINES
        end

        append_to_file(entry)
        entry
      rescue
        nil
      end

      def tail(since: 0, limit: 250)
        since_i = since.to_i
        lines = []
        seq = 0

        @mutex.synchronize do
          seq = @seq
          lines = @buffer.select { |entry| entry[:seq] > since_i }
          lines = lines.last(limit.to_i) if limit.to_i > 0
        end

        {
          seq: seq,
          lines: lines,
          path: log_path,
        }
      rescue
        {
          seq: 0,
          lines: [],
          path: log_path,
        }
      end

      def clear!
        @mutex.synchronize do
          @buffer = []
          @seq = 0
        end

        write_log_document([])
        true
      rescue
        false
      end

      def log_path
        @log_path ||= begin
          FileUtils.mkdir_p(log_dir)
          File.join(log_dir, "jpods-log-#{Time.now.strftime('%Y-%m-%d')}.log.json")
        end
      end

      private

      def log_dir
        File.join(Dir.home, 'Documents', 'JPods Logs')
      end

      def read_log_document
        return base_log_document([]) unless File.exist?(log_path)

        raw = JSON.parse(File.read(log_path, encoding: 'utf-8'))
        return base_log_document([]) unless raw.is_a?(Hash)

        entries = Array(raw['entries']).select { |entry| entry.is_a?(Hash) }
        base_log_document(entries).merge(raw)
      rescue
        base_log_document([])
      end

      def base_log_document(entries)
        {
          'schema' => 'jpods-log-v1',
          'generated_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
          'entries' => entries,
        }
      end

      def write_log_document(entries)
        doc = base_log_document(entries)
        File.write(log_path, JSON.pretty_generate(doc), encoding: 'utf-8')
      end

      def append_to_file(entry)
        doc = read_log_document
        entries = Array(doc['entries'])
        entries << {
          'seq' => entry[:seq],
          'ts' => entry[:ts],
          'level' => entry[:level],
          'msg' => entry[:msg],
        }
        entries = entries.last(MAX_LINES)
        write_log_document(entries)
      rescue
        nil
      end
    end
  end
end
