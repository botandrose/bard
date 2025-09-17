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
      @domain = URI.parse(@domain).hostname if @domain

      puts "Starting deployment to GitHub Pages..."

      build_site
      tree_sha = create_tree_from_build
      new_commit = create_commit(tree_sha)
      commit_and_push new_commit
    end

    private

    def build_site
      system "rm -rf #{@build_dir.sub(@sha, "*")}"
      run! <<~SH
        set -e
        RAILS_ENV=production bundle exec rails s -p 3000 -d --pid tmp/pids/server.pid
        OUTPUT=$(bundle exec rake assets:clean assets:precompile 2>&1) || echo "$OUTPUT"

        # Create the output directory and enter it
        BUILD=#{@build_dir}
        rm -rf $BUILD
        mkdir -p $BUILD
        cp -R public/assets $BUILD/
        cd $BUILD

        # wait until server responds
        echo waiting...
        curl -s --retry 5 --retry-delay 2 http://localhost:3000 >/dev/null 2>&1

        echo copying...
        # Mirror the site to the build folder, ignoring links with query params
        wget -nv -r -l inf --no-remove-listing -FEnH --reject-regex "(\\.*)\\?(.*)" http://localhost:3000/ 2>&1

        echo #{@domain} > CNAME
      SH
    ensure # cleanup
      run! <<~SH
        cat tmp/pids/server.pid | xargs -I {} kill {}
        rm -rf public/assets
      SH
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
      Git.sha_of("#{@branch}^{commit}")
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

