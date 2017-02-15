class RepoService

  attr_accessor :repo

  def initialize(repo)
    @repo = repo
  end

  def self.create_repo(repo_owner, name, restricted, user)
    GitData.create(repo_owner, name, restricted: restricted, client: user.octokit_client)
  end

  def add_file(filename, file)
    p "BARK"
    p filename
    ap file
    @repo.add_file(filename, file) if @repo
  end



  def update_file(filename, file)
    @repo.update_file(filename, file) if @repo
  end
  def save
    @repo.save
  end

end
