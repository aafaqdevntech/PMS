class DashboardCounts
  def self.for(user)
    new(user).to_h
  end

  def initialize(user)
    @user = user
  end

  def to_h
    if user.admin?
      { role: "admin", counts: admin_counts }
    elsif (team = user.led_team)
      { role: "team_lead", counts: team_lead_counts(team) }
    else
      { role: "member", counts: member_counts }
    end
  end

  private

  attr_reader :user

  def admin_counts
    {
      teams: Team.count,
      projects: Project.count,
      tasks: Task.count,
      issues: Issue.count
    }
  end

  # "Team lead" here means teams.team_lead_id, the same designation Task/Issue
  # authorization keys off of — not employment_detail.role, which can name a
  # team_lead who isn't actually anyone's designated lead.
  def team_lead_counts(team)
    {
      projects: Project.where(team_id: team.id).count,
      tasks: Task.joins(:project).where(projects: { team_id: team.id }).count,
      issues: Issue.joins(:project).where(projects: { team_id: team.id }).count,
      team_members: team.employment_details.count
    }
  end

  def member_counts
    team_id = user.employment_detail&.team_id
    {
      projects: team_id ? Project.where(team_id: team_id).count : 0,
      my_tasks: Task.where(assigned_to_id: user.id).count,
      issues: Issue.where(raised_by_id: user.id).count,
      due_today_tasks: Task.where(assigned_to_id: user.id, due_date: Date.current).count,
      team_members: team_id ? EmploymentDetail.where(team_id: team_id).count : 0
    }
  end
end
