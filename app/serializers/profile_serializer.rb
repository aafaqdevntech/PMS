class ProfileSerializer < ActiveModel::Serializer
    attributes :id, :user_id, :full_name, :phone, :address, :city, :country, :image_url
end
