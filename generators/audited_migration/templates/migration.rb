class <%= class_name %> < ActiveRecord::Migration
  def self.up
    create_table :audits, :force => true do |t|
      t.references :auditable, :association, :polymorphic => true
      t.column :user_id, :integer
      t.column :username, :string
      t.column :action, :string
      t.column :changes, :text
      t.column :version, :integer, :default => 0
      t.column :comment, :string
      t.column :created_at, :datetime
    end
    
    add_index :audits, [:auditable_id, :auditable_type]
    add_index :audits, [:association_id, :association_type]
    add_index :audits, :user_id
    add_index :audits, :created_at  
  end

  def self.down
    drop_table :audits
  end
end
