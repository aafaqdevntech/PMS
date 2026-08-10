# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Bootstrap admin account. Every other user must be created by an admin
# (there's no public sign-up), so at least one admin has to be seeded.
admin = User.find_or_create_by!(username: "admin") do |u|
  u.email = "aafaq@devntech.com"
  u.password = "ChangeMe123!"
  u.password_confirmation = "ChangeMe123!"
end

Profile.find_or_create_by!(user: admin) do |p|
  p.full_name = "Admin"
end

# Admins aren't part of any team.
EmploymentDetail.find_or_create_by!(user: admin) do |e|
  e.role = :admin
  e.job_position = "Administrator"
  e.joined_at = Time.current
end

puts "Seeded admin user: username=admin password=ChangeMe123! (change this immediately in any real environment)"
