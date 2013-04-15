require 'snappy'
require 'leveldb'

module SRSRB
  class LevelDbEventStore
    def initialize storedir
      self.db = LevelDB::DB.new storedir
      self.recipients = Set.new
    end

    def count
      seqid, _ = db.each(reversed:true).first
      if seqid
        decode_id(seqid) + 1
      else
        0
      end
    end

    def record! id, event
      # BER encoded; lexicographically sorted.
      db.put nextid, dump(id, event), sync: true

      notify_recipients id, event
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
      db.each do |seqid, blob|
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
      [n].pack('w')
    end

    def decode_id seqid
      seqid.unpack('w').first
    end

    attr_accessor :db, :recipients
  end
end
