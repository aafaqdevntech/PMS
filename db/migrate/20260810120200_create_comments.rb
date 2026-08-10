class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true, index: true
      # Polymorphic: an Issue or a Task, never both. A polymorphic parent
      # can't carry a real foreign key, so the type is fenced by the check
      # constraint below and the id by Comment#commentable_exists.
      #
      # index: false because the default [type, id] index would be a strict
      # prefix of the one added below, which serves both lookups.
      t.references :commentable, null: false, polymorphic: true, index: false
      t.text :body, null: false, limit: 5000

      t.timestamps
    end

    # Listing a parent's comments oldest-first is the only read path, so the
    # index carries created_at rather than leaving it to a filesort.
    add_index :comments, [:commentable_type, :commentable_id, :created_at],
              name: "index_comments_on_commentable_and_created_at"

    # SQLite ignores text(5000), so the limit above is only documentation —
    # these constraints are what actually enforce it. As elsewhere, they are
    # never stricter than the model validations, so input that passes
    # validation can never trip a constraint.
    add_check_constraint :comments, "length(body) BETWEEN 1 AND 5000", name: "comments_body_length"
    add_check_constraint :comments, "commentable_type IN ('Issue', 'Task')", name: "comments_commentable_type"
  end
end
