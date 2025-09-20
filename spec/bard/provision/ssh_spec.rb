require "spec_helper"
require "bard/provision"
require "bard/provision/ssh"

describe Bard::Provision::SSH do
  let(:ssh_uri) { double("ssh_uri", host: "example.com", port: 2222) }
  let(:provision_ssh_uri) { double("provision_ssh_uri", host: "example.com", port: nil) }
  let(:server) { double("server", ssh_uri: ssh_uri) }
  let(:config) { { production: server } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server", ssh_uri: provision_ssh_uri) }
  let(:ssh_provisioner) { Bard::Provision::SSH.new(config, ssh_url) }

  before do
    allow(ssh_provisioner).to receive(:server).and_return(server)
    allow(ssh_provisioner).to receive(:provision_server).and_return(provision_server)
    allow(ssh_provisioner).to receive(:print)
    allow(ssh_provisioner).to receive(:puts)
    allow(ssh_provisioner).to receive(:system)
  end

  describe "#call" do
    context "when SSH is already available on target port" do
      it "skips port reconfiguration but checks known hosts" do
        allow(ssh_provisioner).to receive(:ssh_available?).with(provision_ssh_uri, port: 2222).and_return(true)
        allow(ssh_provisioner).to receive(:ssh_known_host?).with(provision_ssh_uri).and_return(true)

        expect(provision_server).not_to receive(:run!)

        ssh_provisioner.call
      end

      it "adds to known hosts if not present" do
        allow(ssh_provisioner).to receive(:ssh_available?).with(provision_ssh_uri, port: 2222).and_return(true)
        allow(ssh_provisioner).to receive(:ssh_known_host?).with(provision_ssh_uri).and_return(false)

        expect(ssh_provisioner).to receive(:add_ssh_known_host!).with(provision_ssh_uri)

        ssh_provisioner.call
      end
    end

    context "when SSH is not available on target port but available on default port" do
      it "reconfigures SSH port and adds to known hosts" do
        allow(ssh_provisioner).to receive(:ssh_available?).with(provision_ssh_uri, port: 2222).and_return(false)
        allow(ssh_provisioner).to receive(:ssh_available?).with(provision_ssh_uri).and_return(true)
        allow(ssh_provisioner).to receive(:ssh_known_host?).with(provision_ssh_uri).and_return(false)

        expect(ssh_provisioner).to receive(:add_ssh_known_host!).with(provision_ssh_uri).twice
        expect(provision_server).to receive(:run!).with(
          'echo "Port 2222" | sudo tee /etc/ssh/sshd_config.d/port_2222.conf; sudo service ssh restart',
          home: true
        )

        ssh_provisioner.call
      end

      it "prints status messages during reconfiguration" do
        allow(ssh_provisioner).to receive(:ssh_available?).with(provision_ssh_uri, port: 2222).and_return(false)
        allow(ssh_provisioner).to receive(:ssh_available?).with(provision_ssh_uri).and_return(true)
        allow(ssh_provisioner).to receive(:ssh_known_host?).and_return(false)
        allow(ssh_provisioner).to receive(:add_ssh_known_host!)
        allow(provision_server).to receive(:run!)

        expect(ssh_provisioner).to receive(:print).with("SSH:")
        expect(ssh_provisioner).to receive(:print).with(" Adding known host,")
        expect(ssh_provisioner).to receive(:print).with(" Reconfiguring port to 2222,")
        expect(ssh_provisioner).to receive(:print).with(" Adding known host,")
        expect(ssh_provisioner).to receive(:puts).with(" ✓")

        ssh_provisioner.call
      end
    end

    context "when SSH is not available on either port" do
      it "raises an error" do
        allow(ssh_provisioner).to receive(:ssh_available?).with(provision_ssh_uri, port: 2222).and_return(false)
        allow(ssh_provisioner).to receive(:ssh_available?).with(provision_ssh_uri).and_return(false)

        expect { ssh_provisioner.call }.to raise_error("can't find SSH on port 2222 or 22")
      end
    end

    it "updates the SSH URL with the target port" do
      allow(ssh_provisioner).to receive(:ssh_available?).with(provision_ssh_uri, port: 2222).and_return(true)
      allow(ssh_provisioner).to receive(:ssh_known_host?).and_return(true)

      ssh_provisioner.call
    end
  end

  describe "private methods" do
    describe "#target_port" do
      it "returns the server's SSH port" do
        expect(ssh_provisioner.send(:target_port)).to eq(2222)
      end

      it "defaults to 22 if no port is specified" do
        allow(ssh_uri).to receive(:port).and_return(nil)
        expect(ssh_provisioner.send(:target_port)).to eq(22)
      end
    end

    describe "#ssh_available?" do
      it "tests SSH connectivity on specified port" do
        expect(ssh_provisioner).to receive(:system).with("nc -zv example.com 2222 2>/dev/null")

        ssh_provisioner.send(:ssh_available?, provision_ssh_uri, port: 2222)
      end

      it "uses SSH URI port if no port specified" do
        allow(provision_ssh_uri).to receive(:port).and_return(2222)
        expect(ssh_provisioner).to receive(:system).with("nc -zv example.com 2222 2>/dev/null")

        ssh_provisioner.send(:ssh_available?, provision_ssh_uri)
      end

      it "defaults to port 22 if no port in URI or parameter" do
        expect(ssh_provisioner).to receive(:system).with("nc -zv example.com 22 2>/dev/null")

        ssh_provisioner.send(:ssh_available?, provision_ssh_uri)
      end
    end

    describe "#ssh_known_host?" do
      it "checks if host is in known_hosts file" do
        expected_command = 'grep -q "$(ssh-keyscan -t ed25519 -p22 example.com 2>/dev/null | cut -d \' \' -f 2-3)" ~/.ssh/known_hosts'
        expect(ssh_provisioner).to receive(:system).with(expected_command)

        ssh_provisioner.send(:ssh_known_host?, provision_ssh_uri)
      end
    end

    describe "#add_ssh_known_host!" do
      it "adds host to known_hosts file" do
        expected_command = "ssh-keyscan -p22 -H example.com >> ~/.ssh/known_hosts 2>/dev/null"
        expect(ssh_provisioner).to receive(:system).with(expected_command)

        ssh_provisioner.send(:add_ssh_known_host!, provision_ssh_uri)
      end
    end
  end
end