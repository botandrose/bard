require 'delegate'
require 'fileutils'
require 'bard/git'

module Bard
  class GithubPages < SimpleDelegator
    def deploy server
      @sha = Git.sha_of(Git.current_branch)
      @build_dir = "tmp/github-build-#{@sha}"
      @branch = "gh-pages"
      @domain = server.ping.first

      puts "Starting deployment to GitHub Pages..."

      build_site
      tree_sha = create_tree_from_build
      new_commit = create_commit(tree_sha)
      commit_and_push new_commit
    end

    private

    def build_site
      FileUtils.rm_rf "tmp/github-build-".sub(@sha, "*")
      run! <<~BASH
        set -e
        RAILS_ENV=production bundle exec rails s -p 3000 -d --pid tmp/pids/server.pid
        bundle exec rake assets:clean assets:precompile

        # Create the output directory and enter it
        BUILD=#{@build_dir}
        rm -rf $BUILD
        mkdir -p $BUILD
        cp -R public/assets $BUILD/
        cd $BUILD

        # wait until server responds
        echo waiting...
        curl --retry 5 --retry-delay 2 http://localhost:3000

        echo copying...
        # Mirror the site to the build folder, ignoring links with query params
        wget --reject-regex "(.*)\\?(.*)" -FEmnH http://localhost:3000/
        echo #{@domain} > CNAME
      BASH
    ensure # cleanup
      run! <<~BASH
        cat tmp/pids/server.pid | xargs -I {} kill {}
        rm -rf public/assets
      BASH
    end

    def create_tree_from_build
      # Create temporary index
      git_index_file = ".git/tmp-index"
      git = "GIT_INDEX_FILE=#{git_index_file} git"
      run! "#{git} read-tree --empty"

      # Add build files to temporary index
      Dir.chdir(@build_dir) do
        Dir.glob('**/*', File::FNM_DOTMATCH).each do |file|
          next if file == '.' || file == '..'
          if File.file?(file)
            run! "#{git} update-index --add --cacheinfo 100644 $(#{git} hash-object -w #{file}) #{file}"
          end
        end
      end

      # Create tree object from index
      tree_sha = `#{git} write-tree`.chomp

      # Clean up temporary index
      FileUtils.rm_f(git_index_file)

      tree_sha
    end

    def create_commit tree_sha
      # Get parent commit if branch exists
      parent = get_parent_commit

      # Create commit object
      message = "'Deploying to #{@branch} from @ #{@sha} 🚀'"
      args = ['commit-tree', tree_sha]
      args += ['-p', parent] if parent
      args += ['-m', message]

      commit_sha = `git #{args.join(' ')}`.chomp

      commit_sha
    end

    def get_parent_commit
      sha = Git.sha_of("#{@branch}^{commit}")
      return sha if $?.success?
      nil # Branch doesn't exist yet
    end

    def commit_and_push commit_sha
      if branch_exists?
        run! "git update-ref refs/heads/#{@branch} #{commit_sha}"
      else
        run! "git branch #{@branch} #{commit_sha}"
      end
      run! "git push -f origin #{@branch}:refs/heads/#{@branch}"
    end

    def branch_exists?
      system("git show-ref --verify --quiet refs/heads/#{@branch}")
    end
  end
end

