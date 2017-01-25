require 'spec_helper'

describe 'POST /datasets/:id/files' do

  before(:each) do
    Sidekiq::Testing.inline!
    skip_callback_if_exists(Dataset, :create, :after, :create_repo_and_populate)

    @user = create(:user, name: "User McUser", email: "user@user.com")
    @dataset = create(:dataset, name: "Dataset", user: @user, dataset_files: [
      create(:dataset_file, filename: 'test-data.csv')
    ])

    @repo = double(GitData)
    expect(GitData).to receive(:find).with(@user.github_username, @dataset.name, client: a_kind_of(Octokit::Client)) { @repo }
  end

  after(:each) do
    Sidekiq::Testing.fake!
    Dataset.set_callback(:create, :after, :create_repo_and_populate)
  end

  it 'creates a new file' do
    filename = 'test-data.csv'
    path = File.join(Rails.root, 'spec', 'fixtures', filename)

    expect(@repo).to receive(:add_file).with("data/my-single-file.csv", File.read(path))
    expect(@repo).to receive(:add_file).with("data/my-single-file.md", instance_of(String))
    allow(DatasetFile).to receive(:read_file_with_utf_8).and_return(File.read(path))

    post "/api/datasets/#{@dataset.id}/files", params: {
      file: {
        :title => 'My single file',
        :description => 'My super descriptive description',
        :file => fixture_file_upload(path)
      }
    },
    headers: {'Authorization' => "Token token=#{@user.api_key}" }

    json = JSON.parse(response.body)

    expect(json['job_url']).to match /\/api\/jobs\/(.+)\.json/
    expect(response.code).to eq("202")

    @dataset.reload

    expect(@dataset.dataset_files.count).to eq(2)
    expect(@dataset.dataset_files.last.title).to eq('My single file')
    expect(@dataset.dataset_files.last.description).to eq('My super descriptive description')
  end

  it 'errors if the csv does not match the schema' do
    stub_request(:get, /schema\.json/).to_return(body: File.read(File.join(Rails.root, 'spec', 'fixtures', 'schemas', 'good-schema.json')))

    path = File.join(Rails.root, 'spec', 'fixtures', 'invalid-schema.csv')
    allow(DatasetFile).to receive(:read_file_with_utf_8).and_return(File.read(path))

    post "/api/datasets/#{@dataset.id}/files", params: {
      file: {
        :title => 'My single file',
        :description => 'My super descriptive description',
        :file => fixture_file_upload(path)
      }
    },
    headers: { 'Authorization' => "Token token=#{@user.api_key}" }

    expect(Error.count).to eq(1)
    expect(Error.first.messages).to eq([
      "Dataset files is invalid",
      "Your file 'My single file' does not match the schema you provided"
    ])
  end

end