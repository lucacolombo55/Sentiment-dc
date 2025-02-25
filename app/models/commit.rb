class Commit < ApplicationRecord
  belongs_to :user
  belongs_to :task
  belongs_to :branch

  scope :for_task, ->(tid) {where('task_id = ?',  tid)}

  include HTTParty
  base_uri "https://api.github.com/repos"

  def self.details(branch_name)
    hash= ApplicationRecord.authenticate_gitHub
    username= PropertySetting.where(company: "GitHub", key_name: "username").first.value_text
    repo_name= PropertySetting.where(company: "GitHub", key_name: "repo_name").first.value_text

    response = get("/#{username}/#{repo_name}/commits?sha=#{branch_name}", query: hash[:query], headers: hash[:headers])
    JSON.parse(response.body)
  end

  def self.update
    Branch.all.each do |branch|
      response = Commit.details(branch.name)
      response.each do |commit|
        time = commit['commit']['author']['date'][0..18]
        c_created= DateTime.new(time[0..3].to_i, time[5..6].to_i, time[8..9].to_i, time[11..12].to_i, time[14..15].to_i, time[17..18].to_i)
        Branch.find(branch.id)
        if Commit.where(cid: commit['sha']).count == 0
          @commit = Commit.new(cid: commit['sha'], message: commit['commit']['message'], url: commit['html_url'],
          user_id: User.where(gid: commit['author']['id'].to_s).first, branch_id: branch.id, commit_date: c_created)
          if !@commit.save
            return false, "Error: Commit creation failed"
          end
        else
          @commit = Commit.where(cid: commit['sha']).first
          @commit.user_id = User.where(gid: commit['author']['id'].to_s).first.id
          if !@commit.save
            return false, "Error: Commit update failed"
          end
        end
      end
    end
  end

  def self.last_commit_at_in_branch(bid)
    Commit.where(branch_id: bid).sort_by(&:commit_date).last.format_commit_date
  end

  def self.last_commit_by_in_branch(bid)
    Commit.where(branch_id: bid).sort_by(&:commit_date).last.user.username
  end

  def self.commit_count_in_30d(bid)
    now = Time.zone.now
    thirty_days_ago = (now - 30.days)
    Commit.where(branch_id: bid, commit_date: thirty_days_ago..now).count
  end

  def format_commit_date
    self.commit_date.present? ? self.commit_date.strftime('%m-%d-%Y %l:%M %p') : nil
  end

end
