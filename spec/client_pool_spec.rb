require "spec_helper"

describe ClientPool do

  it "should fail to create a pool of uninitializable objects" do
    lambda {ClientPool.new(100,{})}.should raise_error(ArgumentError)
  end

  it "should create a pool of objects" do
    cp = ClientPool.new(GoodObject,"Smith",{})
    cp.instanciatable.should == GoodObject
    obj = cp.checkout
    obj.name.should == "Smith"
    cp.checkin(obj)
  end

  it "should create a pool of objects by calling a no parameter lambda" do
    lamb = lambda{GoodObject.new(%W[Alice Bob Carol Derek Eric Fred George].choice)}
    cp = ClientPool.new(lamb,{})
    obj = cp.checkout
    obj.class.should == GoodObject
    %W[Alice Bob Carol Derek Eric Fred George].member?(obj.name).should be_true
    cp.checkin(obj)
  end

  it "should create a pool of objects by calling a parameterized lambda" do
    lamb = lambda{|x| GoodObject.new("George " + x)}
    cp = ClientPool.new(lamb,"Washington",{})
    obj = cp.checkout
    obj.class.should == GoodObject
    obj.name.should == "George Washington"
    cp.checkin(obj)
  end
end


