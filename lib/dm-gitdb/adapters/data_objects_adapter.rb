require 'fileutils'
module DataMapper
  module Adapters
    module GitDb
      include FileUtils
      
      attr_accessor :git
      def config_git(git_config)
        @git_config = git_config
      end

      def git_config
        @git_config
      end
      
      def git_initialize
        mkdir_p(git_config[:repo]) unless File.exists?(git_config[:repo])
        begin
          self.git = Git.open(git_config[:repo])
        rescue ArgumentError => e
          self.git = Git.init(git_config[:repo])
        end
      end
      
      def git_file(record, absolute=false)
        return if git.nil?
        pdir = record.class.storage_name(self.name)
        mkdir_p(git_config[:repo] / pdir) unless File.exists?(git_config[:repo] / pdir)
        return git_config[:repo] / pdir / record.id.to_s if absolute
        pdir / record.id.to_s
      end
      
      def git_update(record)
        return if record.new_record? || git.nil?
        File.open(git_file(record, true), "w") {|f| f.puts(record.to_json)}
        git.add(git_file(record))
      end
      
      def git_remove(record)
        return if record.new_record? || git.nil?
        begin
          self.git.remove(git_file(record))
          rm_f(git_file(record, true))
        rescue Git::GitExecuteError => e
          raise e unless e.message.include?("did not match any files")
        end
      end
      
      def git_commit(message)
        return if self.git.nil?
        begin
          self.git.add('.')
          self.git.commit_all(message)
        rescue Git::GitExecuteError => e
          raise e unless e.message.include?("nothing to commit")
        end
      end
      
      def git_clone(from)
        begin
          self.git = Git.open(git_config[:repo])
        rescue ArgumentError => e
          self.git = Git.clone(from.git_config[:repo], self.git_config[:repo])
        end
      end
    end
    class DataObjectsAdapter
      include GitDb
    end
  end # module Adapters
end # module DataMapper
