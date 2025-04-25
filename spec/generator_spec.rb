# frozen_string_literal: true

# This is used to check the generated files all at once.
class MultiFileSerializer
  def process_string(s)
    # Ruby 3.4 changes how hashes are printed
    if Gem::Version.new(RUBY_VERSION) > Gem::Version.new('3.4.0')
      s.gsub(/{"(.*)" => /, '{"\1"=>')
    else
      s
    end
  end

  def dump(value)
    value.keys.sort.map { |k| "#{k}:\n#{process_string(value[k])}\n" }.join("\n")
  end
end

# The easiest way to test a protoc plugin is by actually running protoc. Here we are specifying
# the binary to use for the rails plugin and passing in the dependency paths and the
# place to find the generated Ruby files (which we generated in advance and live inside `spec/gen`.)
def protoc(files)
  `bundle exec protoc \
      --proto_path=#{__dir__} \
     --proto_path=#{__dir__}/google-deps \
     --plugin=protoc-gen-rails=#{__dir__}/../bin/protoc-gen-rails \
     --rails_out=#{__dir__}/app \
     --rails_opt=require=#{__dir__}/gen #{files.join(' ')}`
end

RSpec.describe 'protoc-gen-rails' do
  let(:files) { Dir['spec/app/**/*.rb'].map { |f| [f, File.read(f)] }.to_h }
  before(:each) do
    FileUtils.mkdir('spec/app') unless File.exist?('spec/app')
  end
  after(:each) do
    FileUtils.rm_rf('spec/app') if File.exist?('spec/app')
  end

  it 'should generate for a service' do
    protoc(%w[testdata/test.proto testdata/test_service.proto])
    expect(files).to match_snapshot('service', snapshot_serializer: MultiFileSerializer)
  end

  it 'should not generate if no services' do
    protoc(%w[testdata/test.proto])
    expect(files).to match_snapshot('no_service', snapshot_serializer: MultiFileSerializer)
  end
end
