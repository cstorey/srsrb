require 'snappy'
require 'leveldb'

module SRSRB
  class LevelDbEventStore
    GLOBAL_VERSION_KEY = 'global_sequence'
    STREAM_VERSION_KEY_FMT = 'stream/%s/version'

    def initialize storedir
      self.db = LevelDB::DB.new storedir
      self.recipients = Set.new
    end

    def current_version
      seqid, _ = db.get(GLOBAL_VERSION_KEY, nil)
      if seqid
        LevelDbEventKey.from_bytes(seqid)
      else
        LevelDbEventKey.none
      end
    end

    def count
      current_version.seqid + 1
    end

    def record! id, event, expected_version
      stream_version = db.get(stream_version_key(id), nil)

      if stream_version
        stream_version = LevelDbEventKey.from_bytes(stream_version).seqid
      end

      expected_version = nil if expected_version.nil?

      raise WrongEventVersionError, "expecting: #{expected_version.inspect}; stream version: #{stream_version.inspect}" if expected_version != stream_version

      key = current_version.succ
      val = dump(id, event)

      db.batch do |batch|
        batch.put(key.as_bytes, val)
        batch.put(stream_version_key(id), key.as_bytes)
        batch.put(GLOBAL_VERSION_KEY, key.as_bytes)
      end

      notify_recipients id, event, key.seqid
      key.seqid
    end

    def subscribe recipient
      recipients << recipient
      each_event do |id, event, version|
        recipient.handle_event id, event, version
      end
    end

    def events_for_stream stream_id
      each_event do |id, event, version|
        yield event, version if id == stream_id
      end
    end

    def close
      db.close
    end

    private

    def notify_recipients id, event, version
      recipients.each do |r|
        r.handle_event id, event, version
      end
    end

    def each_event
      last_event = db.get(GLOBAL_VERSION_KEY)
      return if not last_event
      db.each(from: LevelDbEventKey::EVENT_PREFIX, to: last_event) do |seqid, blob|
        id, event = undump(blob)
        version = LevelDbEventKey.decode_id(seqid)
        yield id, event, version
      end
    end

    def dump id, event
      Marshal.dump([id, event])
    end

    def undump blob
      Marshal.load(StringIO.new(blob))
    end

    def stream_version_key id
      STREAM_VERSION_KEY_FMT % id.to_guid
    end
    attr_accessor :db, :recipients
  end

  class LevelDbEventKey
    EVENT_PREFIX = 'event/'

    def initialize seqid
      self.seqid = seqid
    end

    def as_bytes
      "%s%016x" % [EVENT_PREFIX, seqid]
    end

    def succ
      self.class.new(seqid.succ)
    end

    def self.decode_id bytes
      self.from_bytes(bytes).seqid
    end

    def self.from_bytes bytes
      fail "Not an event key!: #{bytes.inspect}" unless bytes.start_with? EVENT_PREFIX
      self.new(Integer(bytes[EVENT_PREFIX.size..-1], 16))
    end

    def self.none
      self.new -1
    end

    attr_reader :seqid

    private
    attr_writer :seqid
  end
end
