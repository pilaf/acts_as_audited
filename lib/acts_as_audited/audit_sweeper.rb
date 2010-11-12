class ActsAsAudited::AuditSweeper < ActionController::Caching::Sweeper #:nodoc:
  cattr_accessor :current_user_method
  self.current_user_method = :current_user

  def before_create(audit)
    audit.user ||= current_user
  end

  def current_user
    controller.send self.class.current_user_method if controller.respond_to?(self.class.current_user_method, true)
  end
end

ActionController::Base.class_eval do
  cache_sweeper ActsAsAudited::AuditSweeper
end
ActsAsAudited.audit_class.add_observer(ActsAsAudited::AuditSweeper.instance)
