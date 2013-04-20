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

    alias_method :current_version, :count

    UNDEFINED = Object.new
    def record! id, event, expected_version=UNDEFINED
      raise WrongEventVersionError if expected_version != UNDEFINED && expected_version != current_version
      $stderr.puts "No version passed to #{self.class.name}#record! at #{caller[0]}" if expected_version == UNDEFINED

      db.put nextid, dump(id, event), sync: true

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
      [ n << 32, n ].pack('NN')
    end

    def decode_id seqid
      seqid.unpack('NN').inject(0) { |acc, n| (acc << 32) + n }
    end

    attr_accessor :db, :recipients
  end
end
