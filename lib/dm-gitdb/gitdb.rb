module DataMapper
  def self.set_default_repository(name)
    raise ArgumentError, "You can not set default repository inside repository block" unless Repository.context.empty?
    Repository.context << repository(name)
  end

  module GitDb

    @gitified_models = []
    def self.build
      adapters = Repository.adapters.collect{|ad| ad[1]}
      origin_adapter = adapters.detect{|adapter| adapter.git_config[:origin]}
      if origin_adapter.nil?
        raise ArgumentError, %Q|One of your repositories must be origin repository, use: DataMapper.setup(:master1, "mysql://localhost/gitdb_master1").git(:repo => "/git_repo1", :origin => true )|
      end
      origin_adapter.git_initialize
      repository(origin_adapter.name){@gitified_models.each{|mod| mod.all.each{|record| record.update_git_file! }}}
      origin_adapter.git_commit("initialized from repository #{origin_adapter.name}")

      adapters.each do |adapter| 
        next if adapter.git_config[:origin]
        repository(adapter.name).auto_upgrade!
        adapter.git_clone(origin_adapter)
      end

    end


    module InstanceMethods
      def git_rm!
        self.repository.adapter.git_remove(self)
      end
      def update_git_file!
        self.repository.adapter.git_update(self)
      end
    end

    def self.included(mod)
      @gitified_models << mod
      mod.send(:include, InstanceMethods)
      mod.after(:create) { update_git_file! }
      mod.after(:update) { update_git_file!}
      mod.before(:destroy) { git_rm! }
    end

  end
end
