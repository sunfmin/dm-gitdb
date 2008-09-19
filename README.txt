=== Features


== Synopsis

  require 'rubygems'
  require 'dm-core'
  require 'dm-gitdb'

  DataMapper.setup(:master1, "mysql://localhost/db_master1").git(:repo => "/git_repo1")  # make sure the first db with data, others db are empty.
  DataMapper.setup(:master2, "mysql://localhost/db_master2").git(:repo => "/git_repo2")
  DataMapper.setup(:master3, "mysql://localhost/db_master3").git(:repo => "/git_repo3")


  class MyModel
    include DataMapper::Resource
    include DataMapper::GitDb

    property :id, Serial
    property :name, String
  end

  DataMapper::GitDb.build

  repository(:master1) do 
    MyModel.get(1).destroy!
    MyModel.get(2).update_attributes(:name => "Edited Record in master1")
    MyModel.create(:name => "New Record")
  end

  repository(:master3) do 
    MyModel.create(:name => "New Record in master3")
  end

  repository(:master2) do 
    MyModel.get(2).update_attributes(:name => "Edited Record in master2")
  end

  repository(:master1).push

  # the same with
  # repository(:master1).push(:master3)
  # repository(:master2).pull(:master1)

  repository(:master3) do 
    MyModel.get(2).name.should == "Edited Record in master1"
  end

  repository(:master1) do 
    MyModel.first(:name => "New Record in master3").should_be_nil
  end

  repository(:master1).pull(:master3)
  repository(:master1) do 
    MyModel.first(:name => "New Record in master3").should_not_be_nil
  end

  # conflicts is overwrite with push or pull
  repository(:master2) do
    MyModel.get(2).name.should == "Edited Record in master2"
  end



