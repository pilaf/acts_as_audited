require 'set'

module ActsAsAudited
  # Audit saves the changes to ActiveRecord models.  It has the following attributes:
  #
  # * <tt>auditable</tt>: the ActiveRecord model that was changed
  # * <tt>user</tt>: the user that performed the change; a string or an ActiveRecord model
  # * <tt>action</tt>: one of create, update, or delete
  # * <tt>changes</tt>: a serialized hash of all the changes
  # * <tt>created_at</tt>: Time that the change was performed
  #
  class Audit < ActiveRecord::Base
    belongs_to :auditable, :polymorphic => true
    belongs_to :association, :polymorphic => true
    belongs_to :user, :class_name => ActsAsAudited::Configuration.user_class_name

    before_create :set_version_number, :set_audit_user

    # ActiveRecord::Base#changes is an existing method, so before serializing the +changes+ column,
    # the existing +changes+ method is undefined. The overridden +changes+ method pertained to 
    # dirty attributes, but will not affect the partial updates functionality as that's based on
    # an underlying +changed_attributes+ method, not +changes+ itself.
    undef_method :changes
    serialize :changes, Hash

    cattr_accessor :audited_class_names
    self.audited_class_names = Set.new

    def self.audited_classes
      self.audited_class_names.map(&:constantize)
    end

    # All audits made during the block called will be recorded as made
    # by +user+. This method is hopefully threadsafe, making it ideal
    # for background operations that require audit information.
    def self.as_user(user, &block)
      Thread.current[:acts_as_audited_user] = user

      yield

      Thread.current[:acts_as_audited_user] = nil
    end

    # Allows user to be set to either a string or an ActiveRecord object
    def user_as_string=(user) #:nodoc:
      # reset both either way
      self.user_as_model = self.username = nil
      user.is_a?(ActiveRecord::Base) ?
        self.user_as_model = user :
        self.username = user
    end
    alias_method :user_as_model=, :user=
    alias_method :user=, :user_as_string=

    def user_as_string #:nodoc:
      self.user_as_model || self.username
    end
    alias_method :user_as_model, :user
    alias_method :user, :user_as_string

    def revision
      clazz = auditable_type.constantize
      returning clazz.find_by_id(auditable_id) || clazz.new do |m|
        self.class.assign_revision_attributes(m, self.class.reconstruct_attributes(ancestors).merge({:version => version}))
      end
    end

    def ancestors
      self.class.find(:all, :order => 'version',
        :conditions => ['auditable_id = ? and auditable_type = ? and version <= ?',
        auditable_id, auditable_type, version])
    end

    # Returns a hash of the changed attributes with the new values
    def new_attributes
      (changes || {}).inject({}.with_indifferent_access) do |attrs,(attr,values)|
        attrs[attr] = values.is_a?(Array) ? values.last : values
        attrs
      end
    end

    # Returns a hash of the changed attributes with the old values
    def old_attributes
      (changes || {}).inject({}.with_indifferent_access) do |attrs,(attr,values)|
        attrs[attr] = Array(values).first
        attrs
      end
    end

    def self.reconstruct_attributes(audits)
      attributes = {}
      result = audits.collect do |audit|
        attributes.merge!(audit.new_attributes).merge!(:version => audit.version)
        yield attributes if block_given?
      end
      block_given? ? result : attributes
    end
    
    def self.assign_revision_attributes(record, attributes)
      attributes.each do |attr, val|
        if record.respond_to?("#{attr}=")
          record.attributes.has_key?(attr.to_s) ?
            record[attr] = val :
            record.send("#{attr}=", val)
        end
      end
      record
    end

  private

    def set_version_number
      max = self.class.maximum(:version,
        :conditions => {
          :auditable_id => auditable_id,
          :auditable_type => auditable_type
        }) || 0
      self.version = max + 1
    end

    def set_audit_user
      self.user = Thread.current[:acts_as_audited_user] if Thread.current[:acts_as_audited_user]
      nil # prevent stopping callback chains
    end

  end
end
