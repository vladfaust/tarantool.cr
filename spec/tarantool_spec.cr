require "./spec_helper"

db = Tarantool::Connection.new("localhost", 3301)

describe Tarantool do
  describe "#call" do
    it do
      db.call(:reset)
    end
  end

  describe "#insert" do
    it do
      db.insert(999, {1, "vlad", 50}).success?.should be_true
      db.insert(999, {2, "raj", 10}).success?.should be_true
    end
  end

  describe "#update" do
    it "numeric field assert" do
      db.update(999, 0, {1}, [{:+, 2, 25}]).success?.should be_true
    end

    it "string field assert" do
      db.update(999, 1, {"raj"}, [{":", 1, 3, 0, "esh"}]).success?.should be_true
    end
  end

  describe "#select" do
    it "by primary index assert" do
      db.select(999, 0, {1}).body.data.should eq [[1, "vlad", 75]]
    end

    it "by secondary index assert" do
      db.select(999, 1, {"rajesh"}).body.data.should eq [[2, "rajesh", 10]]
    end

    it "with iterator assert " do
      db.select(999, 2, {75}, Tarantool::Iterator::GreaterThanOrEqual).body.data.should eq [[1, "vlad", 75]]
    end
  end

  describe "#replace" do
    db.replace(999, {1, "vladfaust", 50})
  end

  describe "#delete" do
    it do
      db.delete(999, 0, {2}).success?.should be_true
    end
  end

  describe "#upsert" do
    it do
      # Update 2nd entry name to "rahul" or if it doesn't exist, insert a new entry named "shamim"
      db.upsert(999, {2, "shamim", 5}, [{"=", 1, "rahul"}])
    end
  end

  describe "#eval" do
    it do
      db.eval("local a, b = ... ; return a + b", {1, 2}).body.data.should eq [3]
    end
  end
end
