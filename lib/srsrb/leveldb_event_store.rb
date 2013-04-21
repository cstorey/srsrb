require 'snappy'
require 'leveldb'

module SRSRB
  class LevelDbEventStore
    EVENT_PREFIX = 'event/'
    GLOBAL_VERSION_KEY = 'global_sequence'
    STREAM_VERSION_KEY_FMT = 'stream/%s/version'

    def initialize storedir
      self.db = LevelDB::DB.new storedir
      self.recipients = Set.new
    end

    def current_version
      seqid, _ = db.get(GLOBAL_VERSION_KEY, nil)
      if seqid
        decode_id(seqid)
      else
        -1
      end
    end

    def count
      current_version + 1
    end

    def record! id, event, expected_version
      stream_version = db.get(stream_version_key(id), nil)

      if stream_version
        stream_version = Integer(stream_version, 16)
      end

      expected_version = nil if expected_version.nil?

      raise WrongEventVersionError, "expecting: #{expected_version.inspect}; stream version: #{stream_version.inspect}" if expected_version != stream_version

      event_id = current_version.succ
      key = encode_id(event_id)
      val = dump(id, event)

      db.batch do |batch|
        batch.put(key, val)
        batch.put(stream_version_key(id), "%016x" % [event_id])
        batch.put(GLOBAL_VERSION_KEY, key)
      end

      notify_recipients id, event, event_id
      event_id
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
      db.each(from: EVENT_PREFIX, to: last_event) do |seqid, blob|
        id, event = undump(blob)
        version = decode_id(seqid)
        pp seqid => [id.to_guid, event, version]
        yield id, event, version
      end
    end

    def dump id, event
      Marshal.dump([id, event])
    end

    def undump blob
      Marshal.load(StringIO.new(blob))
    end

    def nextid
      encode_id(count)
    end

    def encode_id(n)
      "%s%016x" % [EVENT_PREFIX, n]
    end

    def decode_id seqid
      fail "Not an event key!: #{seqid.inspect}" unless seqid.start_with? 'event/'
      Integer(seqid[EVENT_PREFIX.size..-1], 16)
    end
    def stream_version_key id
      STREAM_VERSION_KEY_FMT % id.to_guid
    end
    attr_accessor :db, :recipients
  end
end
