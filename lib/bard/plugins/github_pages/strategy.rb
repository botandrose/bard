require "bard/plugins/deploy/strategy"
require "bard/plugins/git"
require "fileutils"
require "socket"
require "uri"

module Bard
  class DeployStrategy
    class GithubPages < DeployStrategy
      def initialize(target, url = nil, **options)
        super(target)
        @url = url || target.github_pages
        @options = options

        target.url(url) if url
      end

      def deploy
        @sha = Git.sha_of(Git.current_branch)
        @build_dir = "tmp/github-build-#{@sha}"
        @branch = "gh-pages"
        @domain = extract_domain
        @port = pick_free_port

        puts "Starting deployment to GitHub Pages..."

        build_site
        tree_sha = create_tree_from_build
        new_commit = create_commit(tree_sha)
        commit_and_push(new_commit)
      end

      private

      def extract_domain
        return nil unless @url
        domain = @url
        domain = URI.parse(domain).hostname if domain =~ /^http/
        domain
      end

      def pick_free_port
        server = TCPServer.new("127.0.0.1", 0)
        port = server.addr[1]
        server.close
        port
      end

      def build_site
        system "rm -rf #{@build_dir.sub(@sha, "*")}"
        run! <<~SH
          set -e
          PORT=#{@port}

          OUTPUT=$(bundle exec rake assets:clean assets:precompile 2>&1) || echo "$OUTPUT"

          BUILD=#{@build_dir}
          rm -rf $BUILD
          mkdir -p $BUILD
          cp -R public/assets $BUILD/

          # Start rails in the foreground, backgrounded — NOT as a daemon —
          # so a port-bind failure surfaces instead of being swallowed by fork.
          rm -f tmp/pids/server.pid
          RAILS_ENV=production bundle exec rails s -p $PORT -P tmp/pids/server.pid >tmp/pids/server.log 2>&1 &
          RAILS_PID=$!

          echo waiting...
          for i in $(seq 1 30); do
            if ! kill -0 $RAILS_PID 2>/dev/null; then
              echo "Rails server failed to start on port $PORT:"
              cat tmp/pids/server.log
              exit 1
            fi
            curl -sf http://localhost:$PORT >/dev/null 2>&1 && break
            sleep 1
          done

          cd $BUILD
          echo copying...
          wget -nv -r -l inf --no-remove-listing -FEnH --reject-regex "(\\.*)\\?(.*)" http://localhost:$PORT/ 2>&1

          echo #{@domain} > CNAME
        SH
      ensure
        # cleanup
        run! <<~SH
          PID=$(cat tmp/pids/server.pid 2>/dev/null)
          if [ -n "$PID" ]; then
            kill $PID 2>/dev/null
            for i in 1 2 3 4 5; do
              kill -0 $PID 2>/dev/null || break
              sleep 1
            done
            kill -9 $PID 2>/dev/null || true
          fi
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

      def create_commit(tree_sha)
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

      def commit_and_push(commit_sha)
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

      def cleanup
        # Cleanup method for tests
      end
    end
  end
end
