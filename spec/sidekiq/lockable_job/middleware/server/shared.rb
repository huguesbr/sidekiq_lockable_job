RSpec.shared_examples 'it yield' do
  it do
    yielded = false
    worker = worker_class.new
    described_class.new.call(worker, {}, nil) do
      yielded = true
    end
    expect(yielded).to eq(true)
  end
end

RSpec.shared_examples 'perform the job' do
  it do
    subject
  end
end
