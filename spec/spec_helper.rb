$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

%W(rspec ostruct client_pool).each do |lib|
  require lib
end

class BadObject
attr_accessor :name, :age
  def initialize(name)
    @name = _name
  end
end

class GoodObject
  attr_accessor :name, :age
  def initialize(name)
    @name = name
  end
end
