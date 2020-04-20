require 'fake_redis'

RSpec.describe SidekiqLockableJob do
  it "has a version number" do
    expect(SidekiqLockableJob::VERSION).not_to be nil
  end
end
