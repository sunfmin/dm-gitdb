=== Features


== Synopsis

  DataMapper.logger.set_log(STDOUT, :debug)
  
  FileUtils.rm_rf('/git_repo1')
  FileUtils.rm_rf('/git_repo2')
  FileUtils.rm_rf('/git_repo3')
  DataMapper.setup(:master1, "mysql://localhost/gitdb_master1").config_git(
    :local => "/git_repo1", 
    :as_url => "ssh://sunfmin@localhost/git_repo1", 
    :increment_offset => 1, 
    :origin => true 
  )  # make sure origin db with data, others db are empty.
  DataMapper.setup(:master2, "mysql://localhost/gitdb_master2").config_git(
    :local => "/git_repo2", 
    :increment_offset => 2, 
    :as_url => "ssh://sunfmin@localhost/git_repo2"
  )
  DataMapper.setup(:master3, "mysql://localhost/gitdb_master3").config_git(
    :local => "/git_repo3", 
    :increment_offset => 3, 
    :as_url => "ssh://sunfmin@localhost/git_repo3"
  )

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

  DataMapper::GitDb.build

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

  repository(:master2) do 
    MyModel.first(:name => "master1 #2").update_attributes(:name => "master1 #2 edited in master2")
  end
  repository(:master2).commit("edited in master2")



  repository(:master1).pull(:master3)

  repository(:master1) do 
    MyModel.first(:name => "master3 #1").should_not be_nil
  end




