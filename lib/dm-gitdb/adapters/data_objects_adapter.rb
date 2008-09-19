module DataMapper
  module Adapters
    module GitDb
      def git(git_config)
        @git_config = git_config
      end

      def git_path
        @git_config[:repo]
      end
    end
    class DataObjectsAdapter
      include GitDb
    end
  end # module Adapters
end # module DataMapper
