class DropComments < ActiveRecord::Migration[8.1]
  def change
    drop_table :comments do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :commentable, null: false, polymorphic: true, index: false
      t.text :body, null: false, limit: 5000
      t.timestamps

      t.index [:commentable_type, :commentable_id, :created_at],
              name: "index_comments_on_commentable_and_created_at"
      t.check_constraint "length(body) BETWEEN 1 AND 5000", name: "comments_body_length"
      t.check_constraint "commentable_type IN ('Issue', 'Task')", name: "comments_commentable_type"
    end
  end
end
