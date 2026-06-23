require 'base64'
require 'rspec'

require_relative 'spec_helper'
require_relative '../lib/github'
require_relative '../cleanup'

class CleanupDummyItem
  attr_reader :name, :path, :sha, :type

  def initialize(type, path, sha = 'sha')
    @type = type
    @path = path
    @name = File.basename(path)
    @sha = sha
  end
end

class CleanupDummyBlob
  attr_reader :content

  def initialize(content)
    @content = Base64.encode64(content)
  end
end

class CleanupDummyBranch
  attr_reader :name

  def initialize(name)
    @name = name
  end
end

class CleanupDummyClient
  attr_reader :deleted_files, :branch_pages

  def initialize(result_branch_name)
    @result_file = CleanupDummyItem.new('file', '_posts/UCRM/result.html', 'result-sha')
    @result_branch_name = result_branch_name
    @deleted_files = []
    @branch_pages = []
  end

  def contents(_repository, options)
    return [@result_file] if options[:path] == '_posts'

    []
  end

  def blob(_repository, _sha)
    CleanupDummyBlob.new(
      {
        'title' => 'EnergyPlus result',
        'date' => DateTime.now.strftime('%F %T'),
        'pending' => false,
        'branch_name' => @result_branch_name,
        'pull_request_issue_id' => '',
        'device_id' => 'linux-gcc',
        'commit_sha' => 'abc123'
      }.to_yaml
    )
  end

  def branches(_repository, options)
    @branch_pages << options[:page]

    case options[:page]
    when 1
      (1..options[:per_page]).map { |i| CleanupDummyBranch.new("old-branch-#{i}") }
    when 2
      [CleanupDummyBranch.new(@result_branch_name)]
    else
      []
    end
  end

  def releases(_repository, options)
    options[:page] == 1 ? [] : []
  end

  def pull_requests(_repository, options)
    options[:page] == 1 ? [] : []
  end

  def delete_contents(_repository, path, _message, _sha)
    @deleted_files << path
  end
end

describe 'Cleanup Testing' do
  context 'when calling clean_up' do
    it 'does not delete branch results when the branch appears after the first GitHub page' do
      branch_name = 'update-csv-rvi-mvi'
      client = CleanupDummyClient.new(branch_name)

      limits = {
        'history_total_file_limit' => 5000,
        'history_long_running_branch_names' => ['develop', 'master'],
        'history_feature_branch_file_limit' => 5,
        'history_long_running_branch_file_limit' => 20
      }

      clean_up(client, 'NatLabRockies/EnergyPlus', 'Myoldmopar/EnergyPlusBuildResults', '_posts', 30, limits)

      expect(client.branch_pages).to eql [1, 2]
      expect(client.deleted_files).to be_empty
    end
  end
end
