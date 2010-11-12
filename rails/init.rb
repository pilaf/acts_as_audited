require 'acts_as_audited'
require 'acts_as_audited/audit_sweeper'

#if Rails.env.development?
#  ActiveSupport::Dependencies.load_once_paths -= ActiveSupport::Dependencies.load_once_paths.grep(/acts_as_audited\/lib/)
#end

ActiveRecord::Base.send :include, ActsAsAudited
