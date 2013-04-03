class Object
  def into &block
    block.call self
  end
end
