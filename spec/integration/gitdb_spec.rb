require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe 'DataMapper::GitDb' do
  before :all do
    DataMapper.setup(:master1, "mysql://localhost/gitdb_master1").git(:repo => "/git_repo1")  # make sure the first db with data, others db are empty.
    DataMapper.setup(:master2, "mysql://localhost/gitdb_master2").git(:repo => "/git_repo2")
    DataMapper.setup(:master3, "mysql://localhost/gitdb_master3").git(:repo => "/git_repo3")

    class MyModel
      include DataMapper::Resource
      include DataMapper::GitDb

      property :id, Serial
      property :name, String
    end

    MyModel.auto_migrate!(:master1)
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

    repository(:master3) do 
      MyModel.create(:name => "master3 #1")
    end

    repository(:master2) do 
      MyModel.first(:name => "master1 #2").update_attributes(:name => "master1 #2 edited in master2")
    end

  end

  it "should be able to push" do
    repository(:master1).push

    repository(:master3) do 
      MyModel.get(2).name.should == "master1 #2 edited"
    end
  end

  it "should be able to pull" do
    repository(:master1).pull(:master3)

    repository(:master1) do 
      MyModel.first(:name => "master3 #1").should not_be_nil
    end
  end

  it "should overwrite target if conflict" do
    repository(:master2).pull(:master1)

    repository(:master2) do
      MyModel.first(:name => "master1 #2").should not_be_nil
    end
  end

end
