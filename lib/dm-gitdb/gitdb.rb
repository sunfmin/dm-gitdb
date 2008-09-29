module DataMapper
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
        ver = repository(self.name) {version}
        if ver.blank?
          adapter.full_db_update
        else
          adapter.diff_db_update(ver, 'HEAD')
        end
        update_version
      end
    end

    def clone(source)
      self.auto_upgrade!
      adapter.git_clone(repository(source).adapter)
      adapter.full_db_update
      update_version
    end

    def commit(message)
      adapter.git_commit(message)
      update_version
    end

    private
    def other_remote_names
      Repository.adapters.collect{|ad| ad[0].to_s}.reject{|n| n == self.name || n == :default }
    end

    def update_version
      repository(self.name) {Gitversion.update_version(adapter.git.gcommit('HEAD').sha)}
    end
    
    def version
      Gitversion.version
    end
    
    def self.require_gitversion
      unless const_defined?('Gitversion')
        require Pathname(__FILE__).dirname.expand_path / 'gitversion'
      end
    end
  end


  class GitDbConfig
    def self.setup(options, &blk)

      db = {}
      git = {}
      blk.call(db, git)
      DataMapper.setup(options[:name], db.dup).config_git(git)

      if options[:default_when].call
        DataMapper.setup(:default, db).config_git(git)
      end

    end
  end


  module GitDb

    @gitified_models = []
    def self.build(repo_name)
      adapters = Repository.adapters.collect{|ad| ad[1]}
      origin_adapter = adapters.detect{|adapter| adapter.name == repo_name}
      if origin_adapter.nil?
        raise ArgumentError, %Q|Can not find repository with name: #{repo_name}|
      end
      repository(origin_adapter.name).auto_upgrade!

      origin_adapter.git_initialize
      repository(origin_adapter.name){@gitified_models.each{|mod| mod.all.each{|record| record.update_git_file! }}}
      repository(origin_adapter.name).commit("initialized repository #{origin_adapter.name}")
      other_adapters = adapters.reject{|ad| ad == origin_adapter || ad.name == :default }
      other_adapters.each do |adapter|
        repository(adapter.name).clone(origin_adapter.name)
      end
      adapters.each {|adapter| adapter.config_remotes(adapters)}
      other_adapters.each do |adapter|
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

    module ClassMethods
      def transaction(&block)
        super(&block)
        repository.commit("committed with transaction")
      end
    end

    def self.included(mod)
      @gitified_models << mod
      mod.extend(ClassMethods)
      mod.send(:include, InstanceMethods)
      mod.before(:create) { set_increment_offset }
      mod.after(:create) { update_git_file! }
      mod.after(:update) { update_git_file!}
      mod.before(:destroy) { git_rm! }
      ::DataMapper::Repository.require_gitversion

    end

  end
end
