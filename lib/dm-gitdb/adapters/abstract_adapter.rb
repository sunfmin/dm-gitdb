module DataMapper
  module Adapters
    module GitDb
      def git(git_config)
        raise git_config.inspect
        @git_config = git_config
      end

      def git_path
        @git_config[:repo]
      end
    end
    AbstractAdapter.extend GitDb
    # class MysqlAdapter
    #   include GitDb
    # end
  end # module Adapters
end # module DataMapper
