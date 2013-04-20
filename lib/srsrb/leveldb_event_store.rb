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

    def count
      seqid, _ = db.get(GLOBAL_VERSION_KEY, nil)
      if seqid
        decode_id(seqid) + 1
      else
        0
      end
    end

    alias_method :current_version, :count

    UNDEFINED = Object.new
    def record! id, event, expected_version=UNDEFINED
      stream_version = db.get(stream_version_key(id), nil)

      if stream_version
        stream_version = Integer(stream_version, 16)
      else
        stream_version = current_version
      end

      raise WrongEventVersionError if expected_version != UNDEFINED && expected_version != current_version
      $stderr.puts "No version passed to #{self.class.name}#record! at #{caller[0]}" if expected_version == UNDEFINED

      key = nextid; val = dump(id, event)
      db.batch do |batch|
        batch.put(key, val)
        batch.put(stream_version_key(id), "%016x" % [stream_version])
        batch.put(GLOBAL_VERSION_KEY, key)
      end

      notify_recipients id, event
      current_version
    end

    def subscribe recipient
      recipients << recipient
      each_event do |id, event|
        recipient.handle_event id, event
      end
    end


    def close
      db.close
    end

    private

    def notify_recipients id, event
      recipients.each do |r|
        r.handle_event id, event
      end
    end

    def each_event
      last_event = db.get(GLOBAL_VERSION_KEY)
      return if not last_event
      db.each(from: EVENT_PREFIX, to: last_event) do |seqid, blob|
        id, event = undump(blob)
        yield id, event
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
