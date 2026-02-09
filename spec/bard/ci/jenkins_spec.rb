require "spec_helper"
require "bard/ci/jenkins"

RSpec.describe Bard::CI::Jenkins do
  let(:jenkins) { described_class.new("test-project", "master", "abc123") }

  before do
    allow(Bard::Secrets).to receive(:fetch).with("jenkins-user").and_return("micah")
    allow(Bard::Secrets).to receive(:fetch).with("jenkins-token").and_return("fake-token")
  end

  describe "#get_last_time_elapsed" do
    it "returns the duration in seconds from the last stable build" do
      xml = "<build><duration>120000</duration></build>"
      allow(jenkins).to receive(:`).with("curl -s http://micah:fake-token@ci.botandrose.com/job/test-project/lastStableBuild/api/xml").and_return(xml)

      result = jenkins.send(:get_last_time_elapsed)
      expect(result).to eq 120
    end
  end

  describe "#run" do
    let(:ci_url) { "http://micah:fake-token@ci.botandrose.com/job/test-project" }

    before do
      allow(jenkins).to receive(:sleep)
      state = instance_double(Bard::CI::State, save: nil, delete: nil)
      allow(jenkins).to receive(:state).and_return(state)
    end

    it "waits until the build has started before polling" do
      allow(jenkins).to receive(:`).with("curl -s -I -X POST -L '#{ci_url}/buildWithParameters?GIT_REF=master'").and_return("Location: http://ci.botandrose.com/queue/item/99/\r\n")
      allow(jenkins).to receive(:`).with("curl -s #{ci_url}/lastStableBuild/api/xml").and_return("<build><duration>60000</duration></build>")
      allow(jenkins).to receive(:`).with("curl -s -g '#{ci_url}/api/json?depth=1&tree=builds[queueId,number]'").and_return(
        '{"builds":[{"queueId":1,"number":1}]}',
        '{"builds":[{"queueId":99,"number":5}]}',
        '{"builds":[{"queueId":99,"number":5}]}'
      )
      allow(jenkins).to receive(:`).with("curl -s #{ci_url}/5/api/json?tree=building,result").and_return('{"building":false,"result":"SUCCESS"}')

      result = jenkins.run { |elapsed, last_time| }
      expect(result).to eq true
    end
  end

  describe "#building? and #success?" do
    before do
      jenkins.instance_variable_set(:@job_id, 42)
    end

    it "detects a successful build" do
      allow(jenkins).to receive(:`).with("curl -s http://micah:fake-token@ci.botandrose.com/job/test-project/42/api/json?tree=building,result").and_return('{"building":false,"result":"SUCCESS"}')

      expect(jenkins.send(:building?)).to eq false
      expect(jenkins.send(:success?)).to eq true
    end

    it "detects a failed build" do
      allow(jenkins).to receive(:`).with("curl -s http://micah:fake-token@ci.botandrose.com/job/test-project/42/api/json?tree=building,result").and_return('{"building":false,"result":"FAILURE"}')

      expect(jenkins.send(:building?)).to eq false
      expect(jenkins.send(:success?)).to eq false
    end

    it "detects a build in progress" do
      allow(jenkins).to receive(:`).with("curl -s http://micah:fake-token@ci.botandrose.com/job/test-project/42/api/json?tree=building,result").and_return('{"building":true,"result":null}')

      expect(jenkins.send(:building?)).to eq true
    end

    it "handles JSON with spaces in keys" do
      allow(jenkins).to receive(:`).with("curl -s http://micah:fake-token@ci.botandrose.com/job/test-project/42/api/json?tree=building,result").and_return('{"_class":"hudson.model.FreeStyleBuild","building":false,"result":"SUCCESS"}')

      expect(jenkins.send(:building?)).to eq false
      expect(jenkins.send(:success?)).to eq true
    end

    it "success? reflects the last response from building?" do
      allow(jenkins).to receive(:`).with("curl -s http://micah:fake-token@ci.botandrose.com/job/test-project/42/api/json?tree=building,result").and_return(
        '{"building":true,"result":null}',
        '{"building":false,"result":"SUCCESS"}'
      )

      jenkins.send(:building?) # first call — still building
      jenkins.send(:building?) # second call — done
      expect(jenkins.send(:success?)).to eq true
    end
  end
end
