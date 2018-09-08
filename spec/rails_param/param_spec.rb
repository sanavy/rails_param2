require 'rails_param/param'
require 'action_controller'

class MyController
  include RailsParam::Param

  attr_accessor :params
end

describe RailsParam::Param do
  describe ".param!" do
    let(:controller) { MyController.new }

    it "defines the method" do
      expect(controller).to respond_to(:param!)
    end

    describe "transform" do
      context "with a method" do
        it "transforms the value" do
          controller.params = {"word" => "foo"}
          controller.param! :word, String, transform: :upcase
          expect(controller.params["word"]).to eql("FOO")
        end
      end

      context "with a block" do
        it "transforms the value" do
          controller.params = {"word" => "FOO"}
          controller.param! :word, String, transform: lambda { |n| n.downcase }
          expect(controller.params["word"]).to eql("foo")
        end
      end
    end

    describe "default" do
      context "with a value" do
        it "defaults to the value" do
          controller.params = {}
          controller.param! :word, String, default: "foo"
          expect(controller.params["word"]).to eql("foo")
        end
      end

      context "with a block" do
        it "defaults to the block value" do
          controller.params = {}
          controller.param! :foo, :boolean, default: lambda { false }
          expect(controller.params["foo"]).to eql(false)
        end
      end
    end

    describe "coerce" do
      it "converts to String" do
        controller.params = {"foo" => :bar}
        controller.param! :foo, String
        expect(controller.params["foo"]).to eql("bar")
      end

      it "converts to Integer" do
        controller.params = {"foo" => "42"}
        controller.param! :foo, Integer
        expect(controller.params["foo"]).to eql(42)
      end

      it "converts to Float" do
        controller.params = {"foo" => "42.22"}
        controller.param! :foo, Float
        expect(controller.params["foo"]).to eql(42.22)
      end

      it "converts to Array" do
        controller.params = {"foo" => "2,3,4,5"}
        controller.param! :foo, Array
        expect(controller.params["foo"]).to eql(["2", "3", "4", "5"])
      end

      it "converts to Hash" do
        controller.params = {"foo" => "key1:foo,key2:bar"}
        controller.param! :foo, Hash
        expect(controller.params["foo"]).to eql({"key1" => "foo", "key2" => "bar"})
      end

      it "converts to Date" do
        controller.params = {"foo" => "1984-01-10"}
        controller.param! :foo, Date
        expect(controller.params["foo"]).to eql(Date.parse("1984-01-10"))
      end

      it "converts to Time" do
        controller.params = {"foo" => "2014-08-07T12:25:00.000+02:00"}
        controller.param! :foo, Time
        expect(controller.params["foo"]).to eql(Time.parse("2014-08-07T12:25:00.000+02:00"))
      end

      it "converts to DateTime" do
        controller.params = {"foo" => "2014-08-07T12:25:00.000+02:00"}
        controller.param! :foo, DateTime
        expect(controller.params["foo"]).to eql(DateTime.parse("2014-08-07T12:25:00.000+02:00"))
      end

      describe "BigDecimals" do
        it "converts to BigDecimal using default precision" do
          controller.params = {"foo" => 12345.67890123456}
          controller.param! :foo, BigDecimal
          expect(controller.params["foo"]).to eql 12345.678901235
        end

        it "converts to BigDecimal using precision option" do
          controller.params = {"foo" => 12345.6789}
          controller.param! :foo, BigDecimal, precision: 6
          expect(controller.params["foo"]).to eql 12345.7
        end

        it "converts formatted currency string to big decimal" do
          controller.params = {"foo" => "$100,000"}
          controller.param! :foo, BigDecimal
          expect(controller.params["foo"]).to eql 100000.0
        end

      end

      describe "booleans" do
        it "converts 1/0" do
          controller.params = {"foo" => "1"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(true)

          controller.params = {"foo" => "0"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(false)
        end

        it "converts true/false" do
          controller.params = {"foo" => "true"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(true)

          controller.params = {"foo" => "false"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(false)
        end

        it "converts t/f" do
          controller.params = {"foo" => "t"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(true)

          controller.params = {"foo" => "f"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(false)
        end

        it "converts yes/no" do
          controller.params = {"foo" => "yes"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(true)

          controller.params = {"foo" => "no"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(false)
        end

        it "converts y/n" do
          controller.params = {"foo" => "y"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(true)

          controller.params = {"foo" => "n"}
          controller.param! :foo, TrueClass
          expect(controller.params["foo"]).to eql(false)
        end

        it "return InvalidParameterError if value not boolean" do
          controller.params = {"foo" => "1111"}
          expect { controller.param! :foo, :boolean }.to raise_error(RailsParam::Param::InvalidParameterError)
        end
        it "set default boolean" do
          controller.params = {}
          controller.param! :foo, :boolean, default: false
          expect(controller.params["foo"]).to eql(false)
        end
      end

      it "raises InvalidParameterError if the value is invalid" do
        controller.params = {"foo" => "1984-01-32"}
        expect { controller.param! :foo, Date }.to raise_error(RailsParam::Param::InvalidParameterError)
      end

    end

    describe 'validating nested hash' do
      it 'typecasts nested attributes' do
        controller.params = {'foo' => {'bar' => 1, 'baz' => 2}}
        controller.param! :foo, Hash do |p|
          p.param! :bar, BigDecimal
          p.param! :baz, Float
        end
        expect(controller.params['foo']['bar']).to be_instance_of BigDecimal
        expect(controller.params['foo']['baz']).to be_instance_of Float
      end

      it 'does not raise exception if hash is not required but nested attributes are, and no hash is provided' do
        controller.params = {foo: nil}
        controller.param! :foo, Hash do |p|
          p.param! :bar, BigDecimal, required: true
          p.param! :baz, Float, required: true
        end
        expect(controller.params['foo']).to be_nil
      end

      it 'raises exception if hash is required, nested attributes are not required, and no hash is provided' do
        controller.params = {foo: nil}
        expect {
          controller.param! :foo, Hash, required: true do |p|
            p.param! :bar, BigDecimal
            p.param! :baz, Float
          end
        }.to raise_exception
      end

      it 'raises exception if hash is not required but nested attributes are, and hash has missing attributes' do
        controller.params = {'foo' => {'bar' => 1, 'baz' => nil}}
        expect {
          controller.param! :foo, Hash do |p|
            p.param! :bar, BigDecimal, required: true
            p.param! :baz, Float, required: true
          end
        }.to raise_exception
      end
    end

    describe 'validating arrays' do
      it 'typecasts array of primitive elements' do
        controller.params = {'array' => ['1', '2']}
        controller.param! :array, Array do |a, i|
          a.param! i, Integer, required: true
        end
        expect(controller.params['array'][0]).to be_a Integer
        expect(controller.params['array'][1]).to be_a Integer
      end

      it 'validates array of hashes' do
        controller.params = {'array' => [{'object'=>{ 'num' => '1', 'float' => '1.5' }},{'object'=>{ 'num' => '2', 'float' => '2.3' }}]}
        controller.param! :array, Array do |a|
          a.param! :object, Hash do |h|
            h.param! :num, Integer, required: true
            h.param! :float, Float, required: true
          end
        end
        expect(controller.params['array'][0]['object']['num']).to be_a Integer
        expect(controller.params['array'][0]['object']['float']).to be_instance_of Float
        expect(controller.params['array'][1]['object']['num']).to be_a Integer
        expect(controller.params['array'][1]['object']['float']).to be_instance_of Float
      end

      it 'validates an array of arrays' do
        controller.params = {'array' => [[ '1', '2' ],[ '3', '4' ]]}
        controller.param! :array, Array do |a, i|
          a.param! i, Array do |b, e|
            b.param! e, Integer, required: true
          end
        end
        expect(controller.params['array'][0][0]).to be_a Integer
        expect(controller.params['array'][0][1]).to be_a Integer
        expect(controller.params['array'][1][0]).to be_a Integer
        expect(controller.params['array'][1][1]).to be_a Integer
      end

      it 'raises exception when primitive element missing' do
        controller.params = {'array' => ['1', nil]}
        expect {
          controller.param! :array, Array do |a, i|
            a.param! i, Integer, required: true
          end
        }.to raise_exception
      end

      it 'raises exception when nested hash element missing' do
        controller.params = {'array' => [{'object'=>{ 'num' => '1', 'float' => nil }}, {'object'=>{ 'num' => '2', 'float' => '2.3' }}]}
        expect {
          controller.param! :array, Array do |a|
            a.param! :object, Hash do |h|
              h.param! :num, Integer, required: true
              h.param! :float, Float, required: true
            end
          end
        }.to raise_exception
      end

      it 'raises exception when nested array element missing' do
        controller.params = {'array' => [[ '1', '2' ],[ '3', nil ]]}
        expect {
          controller.param! :array, Array do |a, i|
            a.param! i, Array do |b, e|
              b.param! e, Integer, required: true
            end
          end
        }.to raise_exception
      end

      it 'does not raise exception if array is not required but nested attributes are, and no array is provided' do
        controller.params = {foo: nil}
        controller.param! :foo, Array do |p|
          p.param! :bar, BigDecimal, required: true
          p.param! :baz, Float, required: true
        end
        expect(controller.params['foo']).to be_nil
      end

      it 'raises exception if array is required, nested attributes are not required, and no array is provided' do
        controller.params = {foo: nil}
        expect {
          controller.param! :foo, Array, required: true do |p|
            p.param! :bar, BigDecimal
            p.param! :baz, Float
          end
        }.to raise_exception
      end
    end

    describe "validation" do
      describe "required parameter" do
        it "succeeds" do
          controller.params = {"price" => "50"}
          expect { controller.param! :price, Integer, required: true }.to_not raise_error
        end

        it "raises" do
          controller.params = {}
          expect { controller.param! :price, Integer, required: true }.to raise_error(RailsParam::Param::InvalidParameterError, "Parameter price is required")
        end

        it "raises custom message" do
          controller.params = {}
          expect { controller.param! :price, Integer, required: true, message: "No price specified" }.to raise_error(RailsParam::Param::InvalidParameterError, "No price specified")
        end
      end

      describe "blank parameter" do
        it "succeeds" do
          controller.params = {"price" => "50"}
          expect { controller.param! :price, String, blank: false }.to_not raise_error
        end

        it "raises" do
          controller.params = {"price" => ""}
          expect { controller.param! :price, String, blank: false }.to raise_error(RailsParam::Param::InvalidParameterError, "Parameter price cannot be blank")
        end
      end

      describe "format parameter" do
        it "succeeds" do
          controller.params = {"price" => "50$"}
          expect { controller.param! :price, String, format: /[0-9]+\$/ }.to_not raise_error
        end

        it "raises" do
          controller.params = {"price" => "50"}
          expect { controller.param! :price, String, format: /[0-9]+\$/ }.to raise_error(RailsParam::Param::InvalidParameterError, "Parameter price must match format #{/[0-9]+\$/}")
        end
      end

      describe "is parameter" do
        it "succeeds" do
          controller.params = {"price" => "50"}
          expect { controller.param! :price, String, is: "50" }.to_not raise_error
        end

        it "raises" do
          controller.params = {"price" => "51"}
          expect { controller.param! :price, String, is: "50" }.to raise_error(RailsParam::Param::InvalidParameterError, "Parameter price must be 50")
        end
      end

      describe "min parameter" do
        it "succeeds" do
          controller.params = {"price" => "50"}
          expect { controller.param! :price, Integer, min: 50 }.to_not raise_error
        end

        it "raises" do
          controller.params = {"price" => "50"}
          expect { controller.param! :price, Integer, min: 51 }.to raise_error(RailsParam::Param::InvalidParameterError, "Parameter price cannot be less than 51")
        end
      end

      describe "max parameter" do
        it "succeeds" do
          controller.params = {"price" => "50"}
          expect { controller.param! :price, Integer, max: 50 }.to_not raise_error
        end

        it "raises" do
          controller.params = {"price" => "50"}
          expect { controller.param! :price, Integer, max: 49 }.to raise_error(RailsParam::Param::InvalidParameterError, "Parameter price cannot be greater than 49")
        end
      end

      describe "min_length parameter" do
        it "succeeds" do
          controller.params = {"word" => "foo"}
          expect { controller.param! :word, String, min_length: 3 }.to_not raise_error
        end

        it "raises" do
          controller.params = {"word" => "foo"}
          expect { controller.param! :word, String, min_length: 4 }.to raise_error(RailsParam::Param::InvalidParameterError, "Parameter word cannot have length less than 4")
        end
      end

      describe "max_length parameter" do
        it "succeeds" do
          controller.params = {"word" => "foo"}
          expect { controller.param! :word, String, max_length: 3 }.to_not raise_error
        end

        it "raises" do
          controller.params = {"word" => "foo"}
          expect { controller.param! :word, String, max_length: 2 }.to raise_error(RailsParam::Param::InvalidParameterError, "Parameter word cannot have length greater than 2")
        end
      end

      describe "in, within, range parameters" do
        before { controller.params = {"price" => "50"} }

        it "succeeds in the range" do
          controller.param! :price, Integer, in: 1..100
          expect(controller.params["price"]).to eql(50)
        end

        it "raises outside the range" do
          expect { controller.param! :price, Integer, in: 51..100 }.to raise_error(RailsParam::Param::InvalidParameterError, "Parameter price must be within 51..100")
        end
      end
    end

    describe 'renaming' do
      it 'changes parameters key' do
        controller.params = {'delete' => '1'}
        controller.param! :delete, :boolean, rename_to: :_destroy
        expect(controller.params[:_destroy]).to eql(true)
        expect(controller.params).not_to be_key :delete
      end
    end
  end
end
