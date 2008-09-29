=== Features


== Synopsis
describe 'DataMapper::GitDb' do
  before :all do
    DataMapper.logger.set_log(STDOUT, :debug)
    
    FileUtils.rm_rf('/git_repo1')
    FileUtils.rm_rf('/git_repo2')
    FileUtils.rm_rf('/git_repo3')

    DataMapper::GitDbConfig.setup(:name => :master1, :default_when => lambda{ true }) do |db, git|
      db[:adapter] = "mysql"
      db[:database] = "gitdb_master1"
      db[:username] = "root"
      db[:host] = "localhost"

      git[:local] = "/git_repo1"
      git[:as_url] = "ssh://sunfmin@localhost/git_repo1"
      git[:increment_offset] = 1
    end
    DataMapper::GitDbConfig.setup(:name => :master2, :default_when => lambda{ false }) do |db, git|
      db[:adapter] = "mysql"
      db[:database] = "gitdb_master2"
      db[:username] = "root"
      db[:host] = "localhost"

      git[:local] = "/git_repo2"
      git[:as_url] = "ssh://sunfmin@localhost/git_repo2"
      git[:increment_offset] = 2
    end
    DataMapper::GitDbConfig.setup(:name => :master3, :default_when => lambda{ false }) do |db, git|
      db[:adapter] = "mysql"
      db[:database] = "gitdb_master3"
      db[:username] = "root"
      db[:host] = "localhost"

      git[:local] = "/git_repo3"
      git[:as_url] = "ssh://sunfmin@localhost/git_repo3"
      git[:increment_offset] = 3
    end


    #DataMapper.set_default_repository(:master1)

    class MyModel
      include DataMapper::Resource
      include DataMapper::GitDb

      property :id, Serial
      property :name, String
    end

    repository(:master1).auto_migrate!
    repository(:master2).auto_migrate!
    repository(:master3).auto_migrate!

    repository(:master1) do 
      MyModel.create(:name => "master1 #1")
      MyModel.create(:name => "master1 #2")
    end
    DataMapper::GitDb.build(:master1)

    repository(:master1) do 
      MyModel.first(:name => "master1 #1").destroy
      MyModel.first(:name => "master1 #2").update_attributes(:name => "master1 #2 edited")
      MyModel.create(:name => "master1 #3")
    end
    repository(:master1).commit("edited in master1")

    repository(:master3) do 
      MyModel.create(:name => "master3 #1")
    end
    repository(:master3).commit("edited in master3")

  end


  it "should be able to pull from each other" do
    repository(:master1).pull(:master3)

    repository(:master1) do 
      MyModel.first(:name => "master3 #1").should_not be_nil
    end

    repository(:master3).pull(:master1)
    repository(:master3) do 
      MyModel.first(:name => "master1 #1").should be_nil
    end

  end


  it "should be able to pull with lots of record" do
    repository(:master2) do 
      100.times do |i|
        MyModel.create(:name => "master2 #{i}/100")
      end
    end
    repository(:master2).commit("added 100 record in master2")

    repository(:master3).pull(:master2)
    repository(:master1).pull(:master2)

    repository(:master3) { MyModel.all.size.should > 100 }
    repository(:master1) { MyModel.all.size.should > 100 }
  end


end




