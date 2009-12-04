class TaskList < RoleRecord
  default_scope :order => 'created_at DESC'

  belongs_to :page
  
  has_many :tasks, :order => 'position', :dependent => :destroy
  has_many :comments, :as => :target, :order => 'created_at DESC', :dependent => :destroy

  named_scope :with_archived_tasks, :conditions => 'archived_tasks_count > 0'
  named_scope :archived, :conditions => {:archived => true}
  named_scope :unarchived, :conditions => {:archived => false}
  
  acts_as_list :scope => :project
  attr_accessible :name, :start_on, :finish_on

  validates_length_of :name, :within => 1..255
  
  serialize :watchers_ids

  def new_task(user, task=nil)
    self.tasks.new(task) do |task|
      task.project_id = self.project_id
      task.user_id = user.id
    end
  end
  
  def before_save
    unless self.position
      first_task_list = self.project.task_lists.first(:select => 'position')
      if first_task_list
        last_position = first_task_list.position
        self.position = last_position.nil? ? 1 : last_position.succ
      else
        self.position = 0
      end
    end
  end
      
  def after_create
    self.project.log_activity(self,'create')
    self.add_watcher(self.user) 
  end
  
  def notify_new_comment
    comment ||= self.comments.last
    self.watchers.each do |user|
      unless user == comment.user
        Emailer.deliver_notify_task_list(user, self.project, self)
      end
    end
  end
end