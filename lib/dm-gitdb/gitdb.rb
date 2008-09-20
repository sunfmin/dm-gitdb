module DataMapper
  def self.set_default_repository(name)
    raise ArgumentError, "You can not set default repository inside repository block" unless Repository.context.empty?
    Repository.context << repository(name)
  end
  
  def self.set_auto_increment(auto_increment)
    return if auto_increment.to_i < @auto_increment.to_i
    @auto_increment = auto_increment.to_i
  end
  
  def self.auto_increment
    @auto_increment
  end

  class Repository
    def push(*targets)
      
    end

    def pull(*sources)
      sources = other_remote_names if sources.empty?
      sources.each do |remote|
        adapter.git_pull(remote, "#{remote}/master")
        ver = repository(self.name) {Gitversion.version}
        if ver.blank?
          adapter.full_db_update
        else
          adapter.diff_db_update(ver, 'HEAD')
        end
        adapter.update_version
      end
    end

    def clone(source)
      self.auto_upgrade!
      adapter.git_clone(repository(source).adapter)
      adapter.full_db_update
      adapter.update_version
    end

    def commit(message)
      adapter.git_commit(message)
      adapter.update_version
    end

    private
    def other_remote_names
      Repository.adapters.collect{|ad| ad[0].to_s}.reject{|n| n == self.name}
    end
    
  end

  module GitDb

    @gitified_models = []
    def self.build
      adapters = Repository.adapters.collect{|ad| ad[1]}
      origin_adapter = adapters.detect{|adapter| adapter.git_config[:origin]}
      if origin_adapter.nil?
        raise ArgumentError, %Q|One of your repositories must be origin repository, use: DataMapper.setup(:master1, "mysql://localhost/gitdb_master1").git(:repo => "/git_repo1", :origin => true )|
      end
      repository(origin_adapter.name).auto_upgrade!

      origin_adapter.git_initialize
      repository(origin_adapter.name){@gitified_models.each{|mod| mod.all.each{|record| record.update_git_file! }}}
      repository(origin_adapter.name).commit("initialized repository #{origin_adapter.name}")

      adapters.each do |adapter|
        next if adapter.git_config[:origin]
        repository(adapter.name).clone(origin_adapter.name)
      end
      adapters.each {|adapter| adapter.config_remotes(adapters)}
      adapters.each do |adapter|
        next if adapter.git_config[:origin]
        repository(adapter.name).pull(origin_adapter.name)
      end

    end


    module InstanceMethods
      def git_rm!
        self.repository.adapter.git_remove(self)
      end
      def update_git_file!
        self.repository.adapter.git_update(self)
      end

      def set_increment_offset
        self.repository.adapter.execute("SET @@auto_increment_offset=#{self.repository.adapter.git_config[:increment_offset]}, @@auto_increment_increment=#{DataMapper.auto_increment}")
      end
    end

    def self.included(mod)
      @gitified_models << mod
      mod.send(:include, InstanceMethods)
      mod.before(:create) { set_increment_offset }
      mod.after(:create) { update_git_file! }
      mod.after(:update) { update_git_file!}
      mod.before(:destroy) { git_rm! }
    end

  end
end
