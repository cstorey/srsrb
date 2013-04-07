require 'rspec/matchers'

class FakeEventStore
  include RSpec::Matchers
  def subscribe listener
    expect(listener).to respond_to :handle_event
    self.listener = listener
  end

  def record! id, event
    listener.handle_event id, event
  end

  private
  attr_accessor :listener
end
