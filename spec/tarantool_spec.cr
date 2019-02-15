require "./spec_helper"

describe Tarantool do
  context "initilization with zero connect timeout" do
    it "raises IO::Timeout" do
      expect_raises IO::Timeout do
        db = Tarantool::Connection.new("localhost", 3301, connect_timeout: 0.seconds)
      end
    end
  end

  context "initialization with zero read timeout" do
    it "raises IO::Timeout" do
      expect_raises IO::Timeout do
        db = Tarantool::Connection.new("localhost", 3301, read_timeout: 0.seconds)
      end
    end
  end

  context "request with read timeout" do
    it "raises IO::Timeout" do
      db = Tarantool::Connection.new("localhost", 3301, read_timeout: 1.second)

      expect_raises IO::Timeout do
        db.eval("fiber = require('fiber'); fiber.sleep(5)")
      end
    end
  end

  db = Tarantool::Connection.new("localhost", 3301)

  describe "#eval" do
    helpers = File.read(File.expand_path("helpers.lua", "spec"))

    it do
      db.eval(helpers).success?.should be_true
    end
  end

  describe "#call" do
    it do
      db.call(:setup).success?.should be_true
      db.call(:reset).success?.should be_true
    end
  end

  describe "#parse_schema" do
    it "raises before call" do
      expect_raises ArgumentError do
        db.insert(:examples, {2, "raj", 10}).success?.should be_true
      end
    end

    it do
      db.parse_schema
      db.schema.should eq ({"examples" => {id: 999, indexes: {"wage" => 2, "primary" => 0, "name" => 1}}})
    end
  end

  describe "#authenticate" do
    it do
      db.authenticate("jake", "qwerty").success?.should be_true
    end

    it "succeeds on initialization" do
      Tarantool::Connection.new("localhost", 3301, "jake", "qwerty").should be_truthy
    end
  end

  describe "#insert" do
    it do
      db.insert(999, {1, "vlad", 50}).success?.should be_true
      db.insert(:examples, {2, "raj", 10}).success?.should be_true
    end

    it "raises Response::Error on response error" do
      expect_raises Tarantool::Response::Error do
        db.insert(-1, {1, "jake", 1_000_000})
      end
    end
  end

  describe "#update" do
    it "numeric field assert" do
      db.update(999, 0, {1}, [{:+, 2, 25}]).success?.should be_true
    end

    it "string field assert" do
      db.update(:examples, :name, {"raj"}, [{":", 1, 3, 0, "esh"}]).success?.should be_true
    end
  end

  describe "#select" do
    it "by primary index assert" do
      db.select(999, 0, {1}).body.data.should eq [[1, "vlad", 75]]
    end

    it "by secondary index assert" do
      db.select(:examples, :name, {"rajesh"}).body.data.should eq [[2, "rajesh", 10]]
    end

    it "with iterator assert " do
      db.select("examples", "wage", {75}, :>=).body.data.should eq [[1, "vlad", 75]]
    end
  end

  describe "#get" do
    it do
      db.get(:examples, {1}).body.data.should eq [[1, "vlad", 75]]
    end
  end

  describe "#replace" do
    db.replace("examples", {1, "vladfaust", 50})
  end

  describe "#delete" do
    it do
      db.delete(:examples, 0, {2}).success?.should be_true
    end
  end

  describe "#upsert" do
    it do
      # Update 2nd entry name to "rahul" or if it doesn't exist, insert a new entry named "shamim"
      db.upsert(:examples, {2, "shamim", 5}, [{"=", 1, "rahul"}])
    end
  end
end
