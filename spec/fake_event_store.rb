require 'rspec/matchers'

class FakeEventStore
  include RSpec::Matchers
  def subscribe block
    expect(block).to respond_to :call
    self.subscribe_callback = block
  end

  def record! id, event
    subscribe_callback.call id, event
  end

  private
  attr_accessor :subscribe_callback
end
