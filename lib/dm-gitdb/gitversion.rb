class Gitversion
  include DataMapper::Resource
  property :version, String, :nullable => false, :length => 50, :key => true 
  def self.update_version(ver)
    all.destroy!
    create(:version => ver)
  end
  
  def self.version
    first.version if first
  end
end
