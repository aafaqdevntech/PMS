class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :full_name, null: false
      t.string :phone
      t.string :address
      t.string :city
      t.string :country
      t.string :image_url

      t.timestamps
    end
  end
end
