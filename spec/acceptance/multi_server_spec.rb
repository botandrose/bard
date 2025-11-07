# Proof of Concept: Multi-Server Testing with Docker Compose
#
# This demonstrates testing workflows that involve multiple servers,
# such as deploying from staging to production, or syncing data between environments.

require 'spec_helper'
require 'open3'

RSpec.describe "Multi-server Bard workflows", type: :acceptance do
  before(:all) do
    # Start both staging and production containers
    Dir.chdir("spec/acceptance/docker") do
      system("docker-compose up -d")
    end

    # Wait for both servers to be ready
    ["2222", "2223"].each do |port|
      30.times do
        break if system("ssh -o StrictHostKeyChecking=no -p #{port} deploy@localhost -i spec/acceptance/docker/test_key 'echo ready' 2>/dev/null")
        sleep 0.5
      end
    end

    # Setup directories on both servers
    ["2222", "2223"].each do |port|
      system("ssh -o StrictHostKeyChecking=no -p #{port} deploy@localhost -i spec/acceptance/docker/test_key 'mkdir -p testproject'")
    end

    # Create bard config with both servers
    File.write("tmp/test_bard_multi.rb", <<~RUBY)
      server :staging do
        ssh "deploy@localhost:2222"
        path "testproject"
        ssh_key "spec/acceptance/docker/test_key"
        ping false
      end

      server :production do
        ssh "deploy@localhost:2223"
        path "testproject"
        ssh_key "spec/acceptance/docker/test_key"
        ping false
      end
    RUBY
  end

  after(:all) do
    Dir.chdir("spec/acceptance/docker") do
      system("docker-compose down")
    end
    FileUtils.rm_f("tmp/test_bard_multi.rb")
  end

  describe "bard run" do
    it "runs commands on production server" do
      system("ssh -o StrictHostKeyChecking=no -p 2223 deploy@localhost -i spec/acceptance/docker/test_key 'touch testproject/production.txt'")

      Dir.chdir("tmp") do
        File.write("bard.rb", File.read("test_bard_multi.rb"))
        output, status = Open3.capture2e("bard run ls")
        File.delete("bard.rb")

        expect(status.success?).to be true
        expect(output).to include("production.txt")
        expect(output).not_to include("staging.txt")
      end
    end
  end

  describe "file copying between servers" do
    it "can copy files from staging to production" do
      # Create a file on staging
      system("ssh -o StrictHostKeyChecking=no -p 2222 deploy@localhost -i spec/acceptance/docker/test_key 'echo staging-content > testproject/sync-test.txt'")

      # Use scp to copy (simulating what bard does internally)
      system("ssh -o StrictHostKeyChecking=no -p 2222 deploy@localhost -i spec/acceptance/docker/test_key 'cat testproject/sync-test.txt' | ssh -o StrictHostKeyChecking=no -p 2223 deploy@localhost -i spec/acceptance/docker/test_key 'cat > testproject/sync-test.txt'")

      # Verify file exists on production
      output = `ssh -o StrictHostKeyChecking=no -p 2223 deploy@localhost -i spec/acceptance/docker/test_key 'cat testproject/sync-test.txt'`
      expect(output).to include("staging-content")
    end
  end

  describe "environment-specific operations" do
    it "maintains separate state between environments" do
      # Setup different files on each server
      system("ssh -o StrictHostKeyChecking=no -p 2222 deploy@localhost -i spec/acceptance/docker/test_key 'echo staging > testproject/env.txt'")
      system("ssh -o StrictHostKeyChecking=no -p 2223 deploy@localhost -i spec/acceptance/docker/test_key 'echo production > testproject/env.txt'")

      # Verify staging
      staging_content = `ssh -o StrictHostKeyChecking=no -p 2222 deploy@localhost -i spec/acceptance/docker/test_key 'cat testproject/env.txt'`
      expect(staging_content.strip).to eq("staging")

      # Verify production
      production_content = `ssh -o StrictHostKeyChecking=no -p 2223 deploy@localhost -i spec/acceptance/docker/test_key 'cat testproject/env.txt'`
      expect(production_content.strip).to eq("production")
    end
  end

  # Example of testing deployment workflow
  describe "deployment workflow" do
    it "can deploy code from local to staging" do
      # Create a "release" file locally
      FileUtils.mkdir_p("tmp/testproject")
      File.write("tmp/testproject/RELEASE", "v1.0.0")

      # Copy to staging using scp (simulating bard stage/deploy)
      system("scp -o StrictHostKeyChecking=no -P 2222 -i spec/acceptance/docker/test_key tmp/testproject/RELEASE deploy@localhost:testproject/")

      # Verify on staging
      output = `ssh -o StrictHostKeyChecking=no -p 2222 deploy@localhost -i spec/acceptance/docker/test_key 'cat testproject/RELEASE'`
      expect(output).to include("v1.0.0")

      # Cleanup
      FileUtils.rm_rf("tmp/testproject")
    end
  end

  # Example testing database operations (would need MySQL in container)
  describe "database operations", skip: "requires MySQL in container" do
    it "can sync database from staging to local" do
      # This would test `bard data staging`
      # - Create test data on staging
      # - Run bard data staging
      # - Verify data locally
    end
  end
end
